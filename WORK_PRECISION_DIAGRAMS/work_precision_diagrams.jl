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

system = System("PSSE_240_BUS/PSCAD_VALIDATION_RAW.raw", "PSSE_240_BUS/PSCAD_VALIDATION_DYR.dyr";
bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]), runchecks = false)

for l in get_components(PSY.PowerLoad, system)
    PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
end

sim_ida = Simulation(
        MassMatrixModel,
        system,
        "WORK_PRECISION_DIAGRAMS",
        (0.0, 20.0);
        file_level = Logging.Error,
        console_level = Logging.Info
        )
