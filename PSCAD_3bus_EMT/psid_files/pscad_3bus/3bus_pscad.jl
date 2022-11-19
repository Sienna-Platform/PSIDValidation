using Revise
using PowerSystems
using PowerSimulationsDynamics
using OrdinaryDiffEq
using Sundials
using Logging
using PowerFlows
using CSV
using DataFrames
using LinearAlgebra
using PlotlyJS
const PSY = PowerSystems

include("../PSCAD_3BUS/dynamic_test_data.jl")
threebus_file_dir = "PSCAD_3BUS/ThreeBusPSCAD.raw"
system = System(threebus_file_dir, runchecks = false)

for l in get_components(PSY.PowerLoad, system)
    PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
end

## Define Inverters: Parameters in dynamic_test_data.jl

function inv_darco(static_device)
    return PSY.DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter_low_power(), #converter
        outer_control(), #outercontrol
        inner_control(), #inner_control
        dc_source_lv(),
        pll(),
        filt(),
    ) #pss
end

function inv_darco_droop(static_device)
    return PSY.DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter_low_power(), #converter
        outer_control_droop(), #outercontrol
        inner_control(), #inner_control
        dc_source_lv(),
        no_pll(),
        filt(),
    ) #pss
end

function dyn_gen_genrou(generator)
    return PSY.DynamicGenerator(
        name = get_name(generator),
        ω_ref = 1.0, #ω_ref
        machine = machine_genrou(), #machine
        shaft = shaft_genrou(), #shaft
        avr = avr_type1(), #avr
        prime_mover = tg_none(), #tg
        pss = pss_none(),
    ) #pss
end

function dyn_gen_marconato(generator)
    return PSY.DynamicGenerator(
        name = get_name(generator), #static generator
        ω_ref = 1.0, # ω_ref
        machine = machine_marconato(), #machine
        shaft = shaft_no_damping(), #shaft
        avr = avr_type1(), #avr
        prime_mover = tg_none(), #tg
        pss = pss_none(),
    ) #pss
end

for g in get_components(Generator, system)
    if get_number(get_bus(g)) == 101
        case_gen = inv_darco(g)
        add_component!(system, case_gen, g)
    elseif get_number(get_bus(g)) == 102
        #case_gen = dyn_gen_genrou(g)
        #case_gen = dyn_gen_marconato(g)
        case_gen = inv_darco_droop(g)
        add_component!(system, case_gen, g)
    end
end

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

plot(v101_dyn_zoom, label = "DynLines")
plot!(v101_zoom, label = "AlgLines", dpi = 150, title = "Voltage Bus 1")

v102_dyn_zoom = get_zoom_plot(v102_psid_dyn, 0.09, 0.11)
v102_zoom = get_zoom_plot(v102_psid, 0.09, 0.11)


plot(v102_psid_dyn, label = "DynLines")
plot!(v102_psid, label = "AlgLines", dpi = 150, title = "Voltage Bus 2")

plot(v102_dyn_zoom, label = "DynLines")
plot!(v102_zoom, label = "AlgLines", dpi = 150, title = "Voltage Bus 2")
