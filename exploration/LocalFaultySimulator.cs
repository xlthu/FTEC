using System;

using Microsoft.Quantum.Simulation.Simulators;
using Microsoft.Quantum.Simulation.Core;

namespace FTEC {
    public class LocalFaultySimulator : QuantumSimulator {

        public LocalFaultySimulator() : base(throwOnReleasingQubitsNotInZeroState : false) {}

        public static System.Random rnd = new System.Random();
        const double errorProbability = 0.05; // Try to modify this

        bool faulty = false;
        bool errorHappened = false;

        bool isErrorHappened() {
            bool happend = !errorHappened && faulty && rnd.NextDouble() < errorProbability;
            if (happend) errorHappened = true;
            return happend;
        }
        
        // Apply a more complicated error
        void applyError(Qubit qubit) {
            QSimH h = new QSimH(this);
            h.Body(qubit);
            double p = rnd.NextDouble();
            if (p < 0.5) {
                QSimX x = new QSimX(this);
                x.Body(qubit);
            } else {
                QSimZ z = new QSimZ(this);
                z.Body(qubit);
            }
        }

        public class CtlMessage : Message {
            private LocalFaultySimulator sim;
            public CtlMessage(LocalFaultySimulator m) : base(m) { sim = m; }

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

        public class H : QSimH {
            private LocalFaultySimulator sim;
            public H(LocalFaultySimulator m) : base(m) { sim = m; }

            public override Func<Qubit, QVoid> Body {
                get {
                    Func<Qubit, QVoid> original = base.Body;

                    return (qubit => {
                        // System.Console.WriteLine("H");
                        if (sim.isErrorHappened()) sim.applyError(qubit);
                        return original(qubit);
                    });
                }
            }

            // Controlled-H
            public override Func<(IQArray<Qubit>, Qubit), QVoid> ControlledBody {
                get {
                    Func<(IQArray<Qubit>, Qubit), QVoid> original = base.ControlledBody;

                    return (args => {
                        var (ctrls, qubit) = args;
                        // System.Console.WriteLine("C H");

                        if (sim.isErrorHappened()) {
                            int idx = rnd.Next((int)(ctrls.Length + 1));
                            if (idx == ctrls.Length) sim.applyError(qubit);
                            else sim.applyError(ctrls[idx]);
                        }
                        return original(args);
                    });
                }
            }
        } // class H

        public class Z : QSimZ {
            private LocalFaultySimulator sim;
            public Z(LocalFaultySimulator m) : base(m) { sim = m; }

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

            // Controlled-Z
            public override Func<(IQArray<Qubit>, Qubit), QVoid> ControlledBody {
                get {
                    Func<(IQArray<Qubit>, Qubit), QVoid> original = base.ControlledBody;

                    return (args => {
                        var (ctrls, qubit) = args;
                        // System.Console.WriteLine("C Z");

                        if (sim.isErrorHappened()) {
                            int idx = rnd.Next((int)(ctrls.Length + 1));
                            if (idx == ctrls.Length) sim.applyError(qubit);
                            else sim.applyError(ctrls[idx]);
                        }
                        return original(args);
                    });
                }
            }
        } // class Z

        public class X : QSimX {
            private LocalFaultySimulator sim;
            public X(LocalFaultySimulator m) : base(m) { sim = m; }

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

            // Controlled-X
            public override Func<(IQArray<Qubit>, Qubit), QVoid> ControlledBody {
                get {
                    Func<(IQArray<Qubit>, Qubit), QVoid>original = base.ControlledBody;

                    return (args => {
                        var (ctrls, qubit) = args;
                        // System.Console.WriteLine("C X");

                        if (sim.isErrorHappened()) {
                            int idx = rnd.Next((int)(ctrls.Length + 1));
                            if (idx == ctrls.Length) sim.applyError(qubit);
                            else sim.applyError(ctrls[idx]);
                        }
                        return original(args);
                    });
                }
            }
        } // class X

    } // class LocalFaultySimulator

    
} // namespace FTEC