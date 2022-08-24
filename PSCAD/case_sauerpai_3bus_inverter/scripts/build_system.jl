using Revise
using PowerSystems
using PowerSimulationsDynamics
using Plots
const PSY = PowerSystems


threebus_rawfile_dir = joinpath(@__DIR__, "..", "psid_files", "ThreeBusPSCAD.raw") 
include(joinpath(@__DIR__, "..", "psid_files", "dynamic_test_data.jl"))   
system_name =  joinpath(@__DIR__, "..", "psid_files", "ThreeBus_SauerPai_Droop.json")  

system = System(threebus_rawfile_dir, runchecks = false)
for l in get_components(PSY.PowerLoad, system)
    PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
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

function dyn_gen_sauerpai(generator)
    return PSY.DynamicGenerator(
        name = get_name(generator), #static generator
        ω_ref = 1.0, # ω_ref
        machine = machine_sauerpai(), #machine
        shaft = shaft_no_damping(), #shaft
        avr = avr_none(), #avr
        prime_mover = tg_none(), #tg
        pss = pss_none(),
    ) #pss
end

for g in get_components(Generator, system)
    if get_number(get_bus(g)) == 101
        case_gen = dyn_gen_sauerpai(g)
        add_component!(system, case_gen, g)
    elseif get_number(get_bus(g)) == 102
        case_gen = inv_darco_droop(g)
        add_component!(system, case_gen, g)
    end
end

solve_powerflow(system)["bus_results"]
to_json(system,system_name, force=true)

