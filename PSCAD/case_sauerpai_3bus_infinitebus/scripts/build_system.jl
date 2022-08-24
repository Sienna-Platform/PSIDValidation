using Revise
using PowerSystems
using PowerSimulationsDynamics
using Plots
const PSY = PowerSystems

rawfile = "ThreeBusPSCAD.raw"

include(joinpath(@__DIR__, "..", "psid_files", "dynamic_test_data.jl") )   
sys = System( joinpath(@__DIR__, "..", "psid_files", rawfile ) , runchecks = false)
for l in get_components(PSY.PowerLoad, sys)
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

for g in get_components(Generator, sys)
    if get_number(get_bus(g)) == 101
        case_gen = dyn_gen_sauerpai(g)
        add_component!(sys, case_gen, g)
    end
end
for b in get_components(Bus, sys)
    if get_number(b) == 102 
        inf_source = Source(
            name = "InfBus", #name
            active_power = .500,
            available = true, #availability
            reactive_power = -.0706756,
            bus = b, #bus
            R_th = 0.0, #Rth
            X_th = 5e-6, #Xth
        )
        add_component!(sys, inf_source)
        @error "test"    
    end 
end 

for b in get_components(Bus, sys)
    @warn get_number(b)
    @warn get_bustype(b)
    if get_number(b) == 101
        set_bustype!(b, BusTypes.PV)
    end 
    if get_number(b) == 102
        set_bustype!(b, BusTypes.REF)
    end 
end 


for b in get_components(Bus, sys)
    @warn get_number(b)
    @warn get_bustype(b)
end 
solve_powerflow(sys)["bus_results"]
to_json(sys,joinpath(@__DIR__, "..", "psid_files", "system.json")  , force=true)
