using Revise
using PowerSystems
using PowerSimulationsDynamics
using OrdinaryDiffEq
using Sundials
using Logging
using CSV
using PowerFlows
using DataFrames
using LinearAlgebra
using DiffEqDevTools

system = System("PSCAD_VALIDATION_RAW.raw", "PSCAD_VALIDATION_DYR.dyr";
bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]), runchecks = false)

for l in get_components(PowerLoad, system)
    set_model!(l, LoadModels.ConstantImpedance)
end

th = get_dynamic_injector(get_component(ThermalStandard, system, "generator-1431-N"))

sim_ref = Simulation(
        MassMatrixModel,
        system,
        "WORK_PRECISION_DIAGRAMS",
        (0.0, 10.0),
        GeneratorTrip(0.1, th);
        file_level = Logging.Error,
        console_level = Logging.Info
        )
execute!(sim_ref, Rodas5P(), abstol = 1e-12)
res_ref = read_results(sim_ref)
ref_sol = res_ref.solution

sim_mm = Simulation(
        MassMatrixModel,
        system,
        "WORK_PRECISION_DIAGRAMS",
        (0.0, 10.0),
        GeneratorTrip(0.1, th);
        file_level = Logging.Error,
        console_level = Logging.Info
        )


probs = [sim_mm.problem]
refs = [ref_sol]
abstols = 1.0 ./ 10.0 .^ (6:9)
reltols = 1.0 ./ 10.0 .^ (2:5)

setups = [Dict(:prob_choice => 1, :alg=>Rodas5P(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>Rodas4(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>Rodas4P2(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>Rodas42(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>Rodas5(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>Ros4LStab(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),

          Dict(:prob_choice => 1, :alg=>ABDF2(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>FBDF(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>QNDF(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>QNDF1(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>QNDF2(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>QBDF1(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>QBDF2(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),

          Dict(:prob_choice => 1, :alg=>Rosenbrock23(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>Rosenbrock32(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>RosenbrockW6S4OS(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>ROS34PW1a(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>ROS34PW1b(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>ROS34PW2(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>ROS34PW3(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit()),

          Dict(:prob_choice => 1, :alg=>RadauIIA5(), :callback => SciMLBase.CallbackSet((), tuple(sim_mm.callbacks...)), :tstops => sim_mm.tstops, :initializealg => SciMLBase.NoInit())
]

wp = WorkPrecisionSet(probs, abstols, reltols, setups; print_names=true, parallel_type = :threads,
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10,
                      )

res = wp_to_dict(wp)
open("mm_wp_results.json") do io
      JSON.print(io, res)
end

sim_res = Simulation(
        ResidualModel,
        system,
        "WORK_PRECISION_DIAGRAMS",
        (0.0, 10.0),
        GeneratorTrip(0.1, th)
        ;
        file_level = Logging.Error,
        console_level = Logging.Info,
        )

probs = [sim_res.problem]
refs = [ref_sol]
abstols = 1.0 ./ 10.0 .^ (6:9)
reltols = 1.0 ./ 10.0 .^ (2:5)

setups = [Dict(:prob_choice => 1, :alg=>IDA(), :callback => SciMLBase.CallbackSet((), tuple(sim_res.callbacks...)), :tstops => sim_res.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>IDA(linear_solver = :LapackDense), :callback => SciMLBase.CallbackSet((), tuple(sim_res.callbacks...)), :tstops => sim_res.tstops, :initializealg => SciMLBase.NoInit()),
          # Requires Fix in Sundials.jl
          #Dict(:prob_choice => 1, :alg=>IDA(linear_solver = :BCG), :callback => SciMLBase.CallbackSet((), tuple(sim_res.callbacks...)), :tstops => sim_res.tstops, :initializealg => SciMLBase.NoInit()),
          Dict(:prob_choice => 1, :alg=>IDA(linear_solver = :KLU), :callback => SciMLBase.CallbackSet((), tuple(sim_res.callbacks...)), :tstops => sim_res.tstops, :initializealg => SciMLBase.NoInit())
]
wp = WorkPrecisionSet(probs, abstols, reltols, setups; print_names=true,
                       names = ["Dense" "LapackDense" "KLU"],
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10,
                      )

res = wp_to_dict(wp)

open("sundials_wp_results.json") do io
      JSON.print(io, res)
end


#=
ix = findall(x -> get_name(x) == "generator-1431-N", sim_run.inputs.dynamic_injectors)[1]
wrapped_device = sim_res.inputs.dynamic_injectors[ix]
ix_range = PowerSimulationsDynamics.get_ix_range(wrapped_device)
before_fault_x0[ix_range] .= 0.0
PowerSimulationsDynamics.set_connection_status(wrapped_device, 0)

execute!(sim_res, IDA())
=#
