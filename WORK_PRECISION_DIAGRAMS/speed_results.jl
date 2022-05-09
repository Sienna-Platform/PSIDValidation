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
using JSON

system = System("PSCAD_VALIDATION_RAW.raw", "PSCAD_VALIDATION_DYR.dyr";
bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]), runchecks = false)

for l in get_components(PowerLoad, system)
    set_model!(l, LoadModels.ConstantImpedance)
end

#th = get_dynamic_injector(get_component(ThermalStandard, system, "generator-1431-N"))
th = get_component(ThermalStandard, system, "generator-2637-H")
#set_bustype!(get_bus(th), BusTypes.PQ)
#set_available!(th, false)

tolerances = [(abstol = 1e-9, reltol = 1e-9), (abstol = 1e-6, reltol = 1e-6), (abstol = 1e-3, reltol = 1e-3)]
solvers = Dict("IDA_LAPACKDENSE" => (ResidualModel, IDA(linear_solver = :LapackDense)),
                "IDA_KLU" => (ResidualModel, IDA(linear_solver = :KLU)),
                "IDA_DENSE" => (ResidualModel, IDA()),
                "FBDF" => (MassMatrixModel, FBDF()),
                "Rodas5P" => (MassMatrixModel, Rodas5P()),
                "Rodas4" => (MassMatrixModel, Rodas4()),
                "Rodas4P2" => (MassMatrixModel, Rodas4P2()),
                "Rodas42" =>(MassMatrixModel, Rodas42()),
                "Rodas5" => (MassMatrixModel, Rodas5()),
                "QNDF" => (MassMatrixModel, QNDF()),
                "QBDF" => (MassMatrixModel, QBDF()),
                "Rosenbrock23" => (MassMatrixModel, Rosenbrock23()),
                "RosenbrockW6S4OS" => (MassMatrixModel, RosenbrockW6S4OS()),
                "ROS34PW1a" => (MassMatrixModel, ROS34PW1a()),
                "ROS34PW1b" => (MassMatrixModel, ROS34PW1b()),
                "ROS34PW2" => (MassMatrixModel, ROS34PW2()),
                "ROS34PW3" => (MassMatrixModel, ROS34PW3()),
                "RadauIIA5" => (MassMatrixModel, RadauIIA5())
)

total_time_gen_trip = Dict()
for tols in tolerances
    for (name, solver) in solvers
    model, solver_ = solver
    try
        sim_ref = Simulation(
                model,
                system,
                "WORK_PRECISION_DIAGRAMS",
                (0.0, 10.0),
                GeneratorTrip(0.1, get_dynamic_injector(th))
                ;
                file_level = Logging.Error,
                console_level = Logging.Error
                )
        execute!(sim_ref, solver_, abstol = tols.abstol, reltol = tols.reltol, enable_progress_bar = false,)
        res_ref = read_results(sim_ref)

        total_time_gen_trip["$(name)_$tols"] = res_ref.time_log
    catch e
        @error e
        continue
    end
    end
end

open("total_time_gen_trip.json", "w") do io
      JSON.print(io, total_time_gen_trip)
end

total_time_line_trip = Dict()
for tols in tolerances
    for (name, solver) in solvers
    model, solver_ = solver
    try
        sim_ref = Simulation(
                model,
                system,
                "WORK_PRECISION_DIAGRAMS",
                (0.0, 10.0),
                BranchTrip(0.1, Line, "CORONADO-1101-PALOVRDE-1401-i_2")
                ;
                file_level = Logging.Error,
                console_level = Logging.Error
                )
        execute!(sim_ref, solver_, abstol = tols.abstol, reltol = tols.reltol, enable_progress_bar = false,)
        res_ref = read_results(sim_ref)

        total_time_line_trip["$(name)_$tols"] = res_ref.time_log
    catch e
        @error e
        continue
    end
    end
end

open("total_time_line_trip.json", "w") do io
      JSON.print(io, total_time_line_trip)
end

results_gen_trip = open("WORK_PRECISION_DIAGRAMS/total_time_gen_trip.json", "r") do io
    JSON.parse(io; dicttype=Dict)
end

results_line_trip = open("WORK_PRECISION_DIAGRAMS/total_time_line_trip.json", "r") do io
    JSON.parse(io; dicttype=Dict)
end
k = first(keys(results_gen_trip))

using DataFrames
df = DataFrame("name" => string.(solver_names),
  "abstol = 1.0e-9, reltol = 1.0e-9" => fill(NaN, 18),
  "abstol = 1.0e-6, reltol = 1.0e-6" => fill(NaN, 18),
  "abstol = 0.001, reltol = 0.001" => fill(NaN, 18))

for (k, v) in results_line_trip
    split1 = split(k, "(")
    @show tols = split(split1[end], ")")[1]
    solver_name = strip(replace(split1[1], "_" => " "))
    df[df.name .== solver_name, tols] .= v["timed_solve_time"]
end

n    = size(df, 1)

# Loop through the columns and convert them one at a time.
cols = []
for var in names(df)
    # If you want a different representation for missing values,
    # just change the second argument of coalesce
    push!(cols, TableCol(var, collect(1:n), coalesce.(df[!, var], "")))
end

# Assemble and print the table
table = hcat(cols...)
