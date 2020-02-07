using System;

using Microsoft.Quantum.Simulation.Simulators;
using Microsoft.Quantum.Simulation.Core;

namespace FTEC
{
    class Driver
    {
        static void Main(string[] args)
        {
            using var fsim = new FaultySimulator();
            VerifyEC.Run(fsim).Wait();
        }
    }
}