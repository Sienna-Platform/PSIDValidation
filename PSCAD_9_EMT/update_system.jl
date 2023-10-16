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

################ OPTIONS #################
#GENERAL PARAMETERS WHICH APPLY TO BOTH PSID AND PSCAD 
line_to_trip = "Bus_8-Bus_9-i_1" 
t_sample =  5.0e-4 #* 1e6 
t_dynamic_sim = 5.0
time_step_pscad = 25e-6 * 1e6  

sys = System(joinpath(@__DIR__, string("nine_bus_inv_gen", ".json")), runchecks = false)

gen_names = ["generator-1-1", "generator-2-1", "generator-3-Trip"]
gfl_names = ["GFL_Battery_2", "GFL_Battery_3"]
gfm_names = ["GFM_Battery_2", "GFM_Battery_3"]

set_units_base_system!(sys, "SYSTEM_BASE")

#Add shunt resistance:
b = get_component(Bus, sys, "Bus_1")
gen_shunt = FixedAdmittance(name="gen-shunt", available=true, bus = b, Y =0.1+0.0*im, dynamic_injector=nothing)
add_component!(sys, gen_shunt)

# Replace Bus 2:
gfm_2 = get_component(GenericBattery, sys, "GFM_Battery_2")
gfl_2 = get_component(GenericBattery, sys, "GFL_Battery_2")
gen_2 = get_component(ThermalStandard, sys, "generator-2-1")

tot_base_power = get_base_power(gfm_2) + get_base_power(gfl_2) + get_base_power(gen_2)
tot_active_power = get_active_power(gfm_2) + get_active_power(gfl_2) + get_active_power(gen_2)
set_base_power!(gfm_2, tot_base_power / 2)
set_base_power!(get_dynamic_injector(gfm_2), tot_base_power / 2)
set_active_power!(gfm_2, tot_active_power / 2)
set_reactive_power_limits!(gfm_2, (min = -99.99, max = 99.99))

remove_component!(sys, get_component(DynamicInjection, sys, "GFL_Battery_2"))
remove_component!(sys, get_component(DynamicInjection, sys, "generator-2-1"))
remove_component!(sys, gfl_2)
remove_component!(sys, gen_2)

# Replace Bus 3
gfm_3 = get_component(GenericBattery, sys, "GFM_Battery_3")
gfl_3 = get_component(GenericBattery, sys, "GFL_Battery_3")
gen_3 = get_component(ThermalStandard, sys, "generator-3-Trip")


tot_base_power = get_base_power(gfm_3) + get_base_power(gfl_3) + get_base_power(gen_3)
tot_active_power = get_active_power(gfm_3) + get_active_power(gfl_3) + get_active_power(gen_3)
set_base_power!(gfl_3, tot_base_power / 4)
set_base_power!(get_dynamic_injector(gfl_3), tot_base_power / 4)
set_active_power!(gfl_3, tot_active_power / 4)
set_reactive_power_limits!(gfl_3, (min = -99.99, max = 99.99))

remove_component!(sys, get_component(DynamicInjection, sys, "GFM_Battery_3"))
remove_component!(sys, get_component(DynamicInjection, sys, "generator-3-Trip"))
remove_component!(sys, gfm_3)
remove_component!(sys, gen_3)

set_units_base_system!(sys, "DEVICE_BASE")
Simulation!(MassMatrixModel, sys, pwd(), (0.0, 1.0))
to_json(sys, joinpath(@__DIR__, "nine_bus_single_device.json"), force = true)