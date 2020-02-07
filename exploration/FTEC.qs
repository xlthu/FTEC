namespace FTEC {
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.ErrorCorrection;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Measurement;
    
    // The operations is the same as `RecoverCSS` in the Q# ErrorCorrection package
    // except that we comment the `Message` lines.
    operation _RecoverCSS (code : CSS, fnX : RecoveryFn, fnZ : RecoveryFn, logicalRegister : LogicalRegister) : Unit {
        let (encode, decode, syndMeasX, syndMeasZ) = code!;
        let syndromeX = syndMeasX!(logicalRegister);
        let recoveryOpX = fnX!(syndromeX);
        // Message($"X: {syndromeX} → {recoveryOpX}");
        ApplyPauli(recoveryOpX, logicalRegister!);
        let syndromeZ = syndMeasZ!(logicalRegister);
        let recoveryOpZ = fnZ!(syndromeZ);
        // Message($"Z: {syndromeZ} → {recoveryOpZ}");
        ApplyPauli(recoveryOpZ, logicalRegister!);
    }

    // Only to detect if there is any error but not to correct it.
    operation _DetectCSS (code : CSS, logicalRegister : LogicalRegister) : Bool {
        let (encode, decode, syndMeasX, syndMeasZ) = code!;
        let syndromeX = syndMeasX!(logicalRegister);
        let syndromeZ = syndMeasZ!(logicalRegister);
        return ResultArrayAsInt(syndromeX!) == 0 and ResultArrayAsInt(syndromeZ!) == 0;
    }

    // Apply a single qubit error (ZX) to `qubit`
    operation ApplyError(qubit : Qubit) : Unit {
        X(qubit);
        Z(qubit);
    }

    // Convert binary array to int
    // Binary array: [0, 1, 0, 1, ...]
    function BinaryArrayAsInt(binary : Int[]) : Int {
        mutable res = 0;
        mutable n = 1;
        for (i in IndexRange(binary)) {
            set res = res + n * binary[i];
            set n = n * 2;
        }
        return res;
    }

    // The parity check matrix of Steane Code
    function SteaneCodeParity() : Int[] {
        let sx = [
            [1, 0, 1, 0, 1, 0, 1],
            [0, 1, 1, 0, 0, 1, 1],
            [0, 0, 0, 1, 1, 1, 1]
        ];
        return Mapped(BinaryArrayAsInt, sx);
    }

    // Calculate the parity with one row in the parity check matrix `parity` and the `codeword`
    function ParityCheck(parity : Int, codeword : Int) : Result {
        return (Parity(parity &&& codeword) == 1) ? One | Zero;
    }

    // Prepare state |+> for bit lip error correction in a non-fault-tolerant way
    operation BFE_StatePrepare(encode : EncodeOp, ancillaQubits : Qubit[]) : LogicalRegister {
        H(ancillaQubits[0]);
        return encode!([ancillaQubits[0]], ancillaQubits[1..6]);
    }

    // Detect any bit lip error
    operation BFE_Detect(codeword : LogicalRegister, ancilla : LogicalRegister) : Syndrome {
        // Transversal CNOT from codeword to ancilla qubits
        for (i in IndexRange(codeword!)) {
            CNOT(codeword![i], ancilla![i]);
        }

        // Measure ancilla qubits to get a classical codeword
        let results = ForEach(MResetZ, ancilla!);
        let ccodeword = ResultArrayAsInt(results);

        // Compute the syndrome by multiplying the parity check matrix with the classical codeword
        let parity = SteaneCodeParity();
        let syndrome = Mapped(ParityCheck(_, ccodeword), parity); // Multiply each row of the matrix with the classical codeword
        
        return Syndrome(syndrome);
    }

    // Correct bit lip errors
    operation BFE_Correct(codeword : LogicalRegister, syndrome : Syndrome) : Unit {
        // Mapping from the syndrome to error correcting operations (Mc)
        let recoverOp = SteaneCodeRecoveryZ(syndrome);
        // Correcting bit flip errors (C)
        ApplyPauli(recoverOp, codeword!);
    }

    // Prepare state |0> for phase lip error correction in a non-fault-tolerant way
    operation PFE_StatePrepare(encode : EncodeOp, ancillaQubits : Qubit[]) : LogicalRegister {
        return encode!([ancillaQubits[0]], ancillaQubits[1..6]);
    }

    // Detect any phase lip error
    operation PFE_Detect(codeword : LogicalRegister, ancilla : LogicalRegister) : Syndrome {
        for (i in IndexRange(ancilla!)) {
            CNOT(ancilla![i], codeword![i]);
        }
        for (i in IndexRange(ancilla!)) {
            H(ancilla![i]);
        }

        let results = ForEach(MResetZ, ancilla!);
        let ccodeword = ResultArrayAsInt(results);

        let parity = SteaneCodeParity();
        let syndrome = Mapped(ParityCheck(_, ccodeword), parity);
        
        return Syndrome(syndrome);
    }

    // Correct phase lip errors
    operation PFE_Correct(codeword : LogicalRegister, syndrome : Syndrome) : Unit {
        let recoverOp = SteaneCodeRecoveryX(syndrome);
        ApplyPauli(recoverOp, codeword!);
    }
    
    // All 0 syndrome represents no error
    function isNoError(syndrome : Syndrome) : Bool {
        return ResultArrayAsInt(syndrome!) == 0;
    }

    // Fault-tolerant state preparation
    // For generalization, `FTStatePreparation` isolates the states to prepare by accepting a `statePrepare` operation as input.
    operation FTStatePreparation(statePrepare : ((EncodeOp, Qubit[]) => LogicalRegister), encode : EncodeOp, ancillaQubits : Qubit[]) : LogicalRegister {
        mutable satisfied = true;
        repeat {
            // Step 1: We first prepare the target state using the given `statePrepare` operation
            let ancilla = statePrepare(encode, ancillaQubits);
            
            // Step 2: We detect if any errors in the prepared state.
            // The detection reuses the error correction procedure.
            using (auxQubits = Qubit[7]) {
                let aux = BFE_StatePrepare(encode, auxQubits);
                let syndrome = BFE_Detect(ancilla, aux);
                set satisfied = satisfied and isNoError(syndrome);
            }

            using (auxQubits = Qubit[7]) {
                let aux = PFE_StatePrepare(encode, auxQubits);
                let syndrome = PFE_Detect(ancilla, aux);
                set satisfied = satisfied and isNoError(syndrome);
            }

        } until (satisfied)
        fixup {
            // Step 3: If any error, we discard the prepared state and repeat.
            ResetAll(ancillaQubits);
            set satisfied = true;
        }
        return LogicalRegister(ancillaQubits);
    }

    // The theoretical implementation of error correction using Steane Code
    operation TheoreticalSteaneEC(codeword : LogicalRegister) : Unit {
        let code = SteaneCode();
        let (encode, decode, syndMeasX, syndMeasZ) = code!;
        let (fnX, fnZ) = SteaneCodeRecoveryFns();

        _RecoverCSS(code, fnX, fnZ, codeword);
    }

    // Fault-tolerant Steane Error Correction Scheme
    operation FTSteaneEC(codeword : LogicalRegister) : Unit {
        let (encode, decode, syndMeasX, syndMeasZ) = (SteaneCode())!;

        // For bit flip errors
        using (ancillaQubits = Qubit[7]) {
            // Prepare initial state for ancilla qubits in a fault-tolerant way
            let ancilla = FTStatePreparation(BFE_StatePrepare, encode, ancillaQubits);
            // Syndrome computation
            let syndrome = BFE_Detect(codeword, ancilla);
            // Mapping and error correcting
            BFE_Correct(codeword, syndrome);
        }

        // For phase flip errors
        using (ancillaQubits = Qubit[7]) {
            let ancilla = FTStatePreparation(PFE_StatePrepare, encode, ancillaQubits);
            let syndrome = PFE_Detect(codeword, ancilla);
            PFE_Correct(codeword, syndrome);
        }
    }

    // A verification version of FTSteaneEC
    // Replace the `FTStatePreparation` with perfect state preparation
    operation FTSteaneEC_ForVerification(codeword : LogicalRegister, errorDuringEC : Bool) : Unit {
        let (encode, decode, syndMeasX, syndMeasZ) = (SteaneCode())!;

        using (ancillaQubits = Qubit[7]) {
            if (errorDuringEC) { Message("FaultyDisabled"); }
            let ancilla = BFE_StatePrepare(encode, ancillaQubits);
            if (errorDuringEC) { Message("FaultyEnabled"); }
            let syndrome = BFE_Detect(codeword, ancilla);
            // Message($"BFE: {syndrome}");
            BFE_Correct(codeword, syndrome);
        }

        using (ancillaQubits = Qubit[7]) {
            if (errorDuringEC) { Message("FaultyDisabled"); }
            let ancilla = PFE_StatePrepare(encode, ancillaQubits);
            if (errorDuringEC) { Message("FaultyEnabled"); }
            let syndrome = PFE_Detect(codeword, ancilla);
            // Message($"PFE: {syndrome}");
            PFE_Correct(codeword, syndrome);
        }
    }

    operation GetFailRatio(ec : (LogicalRegister => Unit), errorInInput : Bool, errorDuringEC : Bool) : Unit {
        let N = 100;
        mutable nFail = 0;

        for (i in 0..N-1) {
            using ((data, auxQubits) = (Qubit(), Qubit[6])) {
                Rx(PI() / 3.0, data);
            
                let code = SteaneCode();
                let (encode, decode, syndMeasX, syndMeasZ) = code!;
                let codeword = encode!([data], auxQubits);

                if (errorInInput) { ApplyError(codeword![1]); }

                if (errorDuringEC) { Message("FaultyEnabled"); }
                ec(codeword);
                if (errorDuringEC) { Message("FaultyDisabled"); }

                // Strict state check
                TheoreticalSteaneEC(codeword);
                let (decodedData, decodedAux) = decode!(codeword);

                Adjoint Rx(PI() / 3.0, data);
                let noError = (M(data) == Zero);

                if (not noError) {
                    set nFail = nFail + 1;
                }

                ResetAll([data] + auxQubits);
            }

            if (i != 0 and i % 10 == 0) {
                Message($"[{i} / {N}] Fail Ratio: {IntAsDouble(nFail) / IntAsDouble(i)}");
            }
        }
        Message($"Total Fail Ratio: {IntAsDouble(nFail) / IntAsDouble(N)}");
    }

    // Compare TheoreticalSteaneEC and FTSteaneEC
    operation Comparison() : Unit {
        Message("TheoreticalSteaneEC");
        GetFailRatio(TheoreticalSteaneEC, true, true);
        Message("FTSteaneEC");
        GetFailRatio(FTSteaneEC, true, true);
    }
}

