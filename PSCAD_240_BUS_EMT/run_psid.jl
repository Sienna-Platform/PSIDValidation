using Revise
using Logging
using OrdinaryDiffEq
using PowerSystems
using PowerSimulationsDynamics
using Plots
using DataFrames
using Sundials
using CSV
using PowerFlows
const PSY = PowerSystems

system = System(joinpath(@__DIR__, "psid_files", "system.json"), runchecks = false)
run_powerflow!(system)

th = get_dynamic_injector(get_component(ThermalStandard, system, "generator-1431-N"))

sim_ref = Simulation(
        MassMatrixModel,
        system,
        "PSCAD_240_BUS_EMT",
        (0.0, 20.0),
        GeneratorTrip(1.0, th);
        file_level = Logging.Error,
        console_level = Logging.Debug
        )

execute!(sim_ref, Rodas5P(), abstol = 1e-9)
res_ref = read_results(sim_ref)
