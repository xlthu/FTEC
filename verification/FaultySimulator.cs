using System;

using Microsoft.Quantum.Simulation.Simulators;
using Microsoft.Quantum.Simulation.Core;

namespace FTEC {
    public class FaultySimulator : QuantumSimulator {

        public FaultySimulator() : base(throwOnReleasingQubitsNotInZeroState : false) {}

        public static System.Random rnd = new System.Random();
        const double errorProbability = 0.05; // The probability with which the error will be introduced

        bool faulty = false; // Is the faulty mechanism enabled or not
        bool errorHappened = false; // Have error happened before

        // Used in an operation to check if there should be an error
        bool isErrorHappened() {
            bool happend = !errorHappened && faulty && rnd.NextDouble() < errorProbability;
            if (happend) errorHappened = true;
            return happend;
        }

        // Apply a single qubit error to `qubit`
        // We consider X or Z Pauli error
        void applyError(Qubit qubit) {
            double p = rnd.NextDouble();
            if (p < 0.5) {
                QSimX x = new QSimX(this);
                x.Body(qubit);
            } else {
                QSimZ z = new QSimZ(this);
                z.Body(qubit);
            }
        }

        // Use Message to enable or disable the faulty mechanism 
        public class CtlMessage : Message {
            private FaultySimulator sim;
            public CtlMessage(FaultySimulator m) : base(m) { sim = m; }

            public override Func<String, QVoid> Body {
                get {
                    Func<String, QVoid> original = base.Body;

                    return (msg => {
                        if (String.Equals(msg, "FaultyEnabled")) {
                            sim.faulty = true;
                            sim.errorHappened = false;
                            return QVoid.Instance;
                        } else if (String.Equals(msg, "FaultyDisabled")) {
                            sim.faulty = false;
                            return QVoid.Instance;
                        }
                        return original(msg);
                    });
                }
            }
        } // class CtlMessage

        // Faulty H gate
        public class H : QSimH {
            private FaultySimulator sim;
            public H(FaultySimulator m) : base(m) { sim = m; }

            // Single qubit operation
            public override Func<Qubit, QVoid> Body {
                get {
                    Func<Qubit, QVoid> original = base.Body;

                    return (qubit => {
                        if (sim.isErrorHappened()) sim.applyError(qubit);
                        return original(qubit);
                    });
                }
            }
        } // class H

        // Fault Z gates
        public class Z : QSimZ {
            private FaultySimulator sim;
            public Z(FaultySimulator m) : base(m) { sim = m; }

            public override Func<Qubit, QVoid> Body {
                get {
                    Func<Qubit, QVoid> original = base.Body;

                    return (qubit => {
                        // System.Console.WriteLine("Z");
                        if (sim.isErrorHappened()) sim.applyError(qubit);
                        return original(qubit);
                    });
                }
            }
        } // class Z

        // Fault X gates
        public class X : QSimX {
            private FaultySimulator sim;
            public X(FaultySimulator m) : base(m) { sim = m; }
            
            public override Func<Qubit, QVoid> Body {
                get {
                    Func<Qubit, QVoid> original = base.Body;

                    return (qubit => {
                        // System.Console.WriteLine("X");
                        if (sim.isErrorHappened()) sim.applyError(qubit);
                        return original(qubit);
                    });
                }
            }
        } // class X

    } // class FaultySimulator

    
} // namespace FTEC