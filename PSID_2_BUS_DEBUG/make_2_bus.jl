using PowerSystems
using PowerFlows
const PSY = PowerSystems

filt() = PSY.LCLFilter(lf = 0.08, rf = 0.003, cf = 0.074, lg = 0.2, rg = 0.01)

current_mode_inner() = PSY.CurrentModeControl(
    kpc = 0.37,     #Current controller proportional gain
    kic = 0.7,     #Current controller integral gain
    kffv = 0,#1.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
    )

    pll() = PSY.KauraPLL(
        ω_lp = 500.0, #Cut-off frequency for LowPass filter of PLL filter.
        kp_pll = 0.84,  #PLL proportional gain
        ki_pll = 4.69,   #PLL integral gain
    )
function outer_control_gfoll()
    function active_pi()
        return PSY.ActivePowerPI(Kp_p = 2.0, Ki_p = 30.0, ωz = 0.132 * 2 * pi * 50)
    end
    function reactive_pi()
        return PSY.ReactivePowerPI(Kp_q = 2.0, Ki_q = 30.0, ωf = 0.132 * 2 * pi * 50)
    end
    return OuterControl(active_pi(), reactive_pi())
end

function add_grid_following(storage, capacity)
    return DynamicInverter(
        name = storage.name,
        ω_ref = 1.0, # ω_ref,
        converter = AverageConverter(rated_voltage = 138.0, rated_current = (capacity*1e3)/138.0), #converter
        outer_control = outer_control_gfoll(), #ogetuter control
        inner_control = current_mode_inner(), #inner control voltage source
        dc_source = FixedDCSource(voltage = 600.0), #dc source
        freq_estimator = pll(), #pll
        filter = filt(), #filter
    )
end
function add_source_to_ref(sys::PSY.System)
    for g in PSY.get_components(StaticInjection, sys)
        isa(g, ElectricLoad) && continue
        g.bus.bustype == BusTypes.REF &&
            error("A device is already attached to the REF bus")
    end

    slack_bus = [b for b in PSY.get_components(Bus, sys) if b.bustype == BusTypes.REF][1]
    inf_source = Source(
        name = "InfBus", #name
        available = true, #availability
        active_power = 0.0,
        reactive_power = 0.0,
        bus = slack_bus, #bus
        R_th = 0.0,
        X_th = 5e-6, #Xth
    )
    PSY.add_component!(sys, inf_source)
    return
end

file_path = joinpath(pwd(), "PSID_2_BUS_DEBUG", "2bus.raw")
sys = PSY.System(file_path)
set_units_base_system!(sys, "DEVICE_BASE")


for g in get_components(ThermalStandard, sys)
    gfl = add_grid_following(g, 100.0)
    add_component!(sys, gfl, g)
end 


add_source_to_ref(sys)


using PowerSimulationsDynamics
using Sundials

sim = Simulation(
        ResidualModel,
        sys,
        pwd(),
        (0.0, 10.0),
        all_lines_dynamic = true,
    )

run_powerflow(sys)["bus_results"]
    # Run Perturbation
#execute!(sim, IDA(); abstol = 1e-9, reltol = 1e-9)


to_json(sys, joinpath("PSID_2_BUS_DEBUG", "2bus_100MVA.json"), force =true )


file_path = joinpath(pwd(), "PSID_2_BUS_DEBUG", "2bus.raw")
sys = PSY.System(file_path)
set_units_base_system!(sys, "DEVICE_BASE")

for g in get_components(ThermalStandard, sys)
    println(get_base_power(g))
    println(get_active_power(g))
    set_base_power!(g, 25.0)
    set_active_power!(g, 4.0)
end 

for g in get_components(ThermalStandard, sys)
    gfl = add_grid_following(g, 25.0)
    add_component!(sys, gfl, g)
end 

for g in get_components(ThermalStandard, sys)
    println(get_base_power(g))
end 
for g in get_components(DynamicInverter, sys)
    println(get_base_power(g))
end 

add_source_to_ref(sys)

run_powerflow(sys)["bus_results"]

to_json(sys, joinpath("PSID_2_BUS_DEBUG", "2bus_25MVA.json"), force =true )