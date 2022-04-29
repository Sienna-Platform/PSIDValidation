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
using PlotlyJS
const PSY = PowerSystems

system = System("ThreeBusVSM_Droop.json")

load2 = get_component(PowerLoad, system, "load1032")
load_trip = LoadTrip(0.1, load2)

sim_ida = Simulation(
        ResidualModel,
        system,
        pwd(),
        (0.0, 0.2), #time span
        load_trip;
        file_level = Logging.Error,
        )

execute!(sim_ida, IDA(), dtmax = 1e-4, saveat=1e-4, abstol = 1e-12)
result_psid = read_results(sim_ida)

set_available!(load2, true)
sim_ida_dyn = Simulation(
        ResidualModel,
        system,
        pwd(),
        (0.0, 0.2), #time span
        load_trip;
        file_level = Logging.Error,
        all_lines_dynamic = true
        )

execute!(sim_ida_dyn, IDA(), dtmax = 1e-5, saveat=1e-5, abstol = 1e-14)
result_psid_dyn = read_results(sim_ida_dyn)

v101_psid = get_voltage_magnitude_series(result_psid, 101)
v102_psid = get_voltage_magnitude_series(result_psid, 102)

v101_psid_dyn = get_voltage_magnitude_series(result_psid_dyn, 101)
v102_psid_dyn = get_voltage_magnitude_series(result_psid_dyn, 102)

pscad_results = CSV.read("PSCAD_3BUS/data/pscad_outputs_LoadStepDown", DataFrame)
filter!(row -> row.time .>= 10, pscad_results)
pscad_results.time .-= 10.0
trace1 = scatter(x = v101_psid_dyn[1], y = v101_psid_dyn[2], name = "DynLines")
trace2 = scatter(x = v101_psid[1], y = v101_psid[2], name = "AlgLines")
trace3 = scatter(x = pscad_results[!, "time"], y =  pscad_results[!, "V_101"], name = "PSCAD")
plot([trace1, trace2, trace3], Layout(title = "Voltage Bus 1", xaxis_range=[0.09, 0.11]))
