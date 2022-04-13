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
using Plots
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

execute!(sim_ida, IDA(), dtmax = 1e-4, saveat=1e-4, abstol = 1e-8)
result_psid = read_results(sim_ida)


v101_psid = get_voltage_magnitude_series(result_psid, 101)
v102_psid = get_voltage_magnitude_series(result_psid, 102)
#plot(v102_psid)

v103_psid = get_voltage_magnitude_series(result_psid, 103)
#plot(v103_psid)


sim_ida_dyn = Simulation(
        ResidualModel,
        system,
        pwd(),
        (0.0, 0.2), #time span
        load_trip;
        file_level = Logging.Error,
        all_lines_dynamic = true
        )

execute!(sim_ida_dyn, IDA(), dtmax = 1e-5, saveat=1e-5)
result_psid_dyn = read_results(sim_ida_dyn)

v101_psid_dyn = get_voltage_magnitude_series(result_psid_dyn, 101)
v102_psid_dyn = get_voltage_magnitude_series(result_psid_dyn, 102)

function get_zoom_plot(series, tmin, tmax)
    return [
        (series[1][ix], series[2][ix]) for
        (ix, s) in enumerate(series[1]) if (s > tmin && s < tmax)
    ]
end

v101_dyn_zoom = get_zoom_plot(v101_psid_dyn, 0.09, 0.11)
v101_zoom = get_zoom_plot(v101_psid, 0.09, 0.11)


plot(v101_psid_dyn, label = "DynLines")
plot!(v101_psid, label = "AlgLines", dpi = 150, title = "Voltage Bus 1")

plot(v101_dyn_zoom, label = "DynLines")
plot!(v101_zoom, label = "AlgLines", dpi = 150, title = "Voltage Bus 1")

v102_dyn_zoom = get_zoom_plot(v102_psid_dyn, 0.09, 0.11)
v102_zoom = get_zoom_plot(v102_psid, 0.09, 0.11)

plot(v102_psid_dyn, label = "DynLines")
plot!(v102_psid, label = "AlgLines", dpi = 150, title = "Voltage Bus 2")

plot(v102_dyn_zoom, label = "DynLines")
plot!(v102_zoom, label = "AlgLines", dpi = 150, title = "Voltage Bus 2")
