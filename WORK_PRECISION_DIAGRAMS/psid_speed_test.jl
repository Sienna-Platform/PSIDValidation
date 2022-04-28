using Revise
using PowerSystems
using PowerSimulationsDynamics
using OrdinaryDiffEq
using Sundials
using Logging
using KLU
using LinearSolve
using CSV
using PowerFlows
using DataFrames
using LinearAlgebra

using PlotlyJS


speed_results = Dict()

for solver in (IDA(), IDA(linear_solver = :LapackDense), IDA(linear_solver = :KLU)), tol in (1e-6, 1e-8, 1e-10)
        try
        sim_ida = Simulation(
                ResidualModel,
                system,
                pwd(),
                (0.0, 20.0), #time span
                BranchTrip(1.0, Line, "CORONADO    -1101-PALOVRDE    -1401-i_10");
                console_level = Logging.Info,
                )

        execute!(sim_ida, solver, abstol = tol, reltol = tol)
        results = read_results(sim_ida)
        speed_results[(solver, tol)] = results.time_log
        catch e
                speed_results[(solver, tol)] = "failed"
        end
end

sim = Simulation(
        MassMatrixModel,
        system,
        pwd(),
        (0.0, 20.0), #time span
        BranchTrip(1.0, Line, "CORONADO    -1101-PALOVRDE    -1401-i_10");
        console_level = Logging.Info,
        )

execute!(sim, Rodas4())

speed_results = Dict()
for solver in (Rodas4(), Rodas4(linsolve = KLUFactorization()), Rodas4P(), Rodas4P(linsolve = KLUFactorization())), tol in (1e-6, 1e-8, 1e-10)
        try
        sim = Simulation(
                MassMatrixModel,
                system,
                pwd(),
                (0.0, 20.0), #time span
                BranchTrip(1.0, Line, "CORONADO    -1101-PALOVRDE    -1401-i_10");
                console_level = Logging.Info,
                )

        execute!(sim, solver, abstol = tol, reltol = tol)
        results = read_results(sim)
        @show (solver, tol), results.time_log
        speed_results[(solver, tol)] = results.time_log
              catch e
                speed_results[(solver, tol)] = "failed"
        end
end


results_ida = read_results(sim_ida)
results = read_results(sim)


vals_ida = get_voltage_magnitude_series(results_ida, 6333)
