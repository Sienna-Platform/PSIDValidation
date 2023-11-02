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
pscad_dynamic_file = "pscad_results_dynamics.csv"
pscad_init_file = "pscad_results_init.csv"
sys = System(joinpath(@__DIR__, string("nine_bus_single_device", ".json")), runchecks = false)

for b in get_components(Line, sys)
    if get_name(b) != line_to_trip
        dyn_branch = PowerSystems.DynamicBranch(b)
        add_component!(sys, dyn_branch)
    end
end

perturbation = BranchTrip(0.1, Line, line_to_trip)
sim = Simulation!(
    ResidualModel,
    sys,
    pwd(),
    (0.0, t_dynamic_sim),
    perturbation;
    file_level =  Logging.Error,
    frequency_reference = ReferenceBus(),
)

#Run simulation with adaptive timestepping and small tolerance and save interval mathcing PSCAD. 
sim_time_adaptive = @timed execute!(sim, IDA(linear_solver = :KLU),abstol=1e-9, reltol=1e-9)
@show sim_time_adaptive
result_psid_0 = read_results(sim)

#Add resistances to the machine
machine_1 =  get_machine(get_dynamic_injector(get_component(ThermalStandard, sys, "generator-1-1")))
Xd = get_Xd(machine_1)
Xq = get_Xq(machine_1)
set_R!(machine_1, ((Xd+Xq)/2)/20) 

sim = Simulation!(
    ResidualModel,
    sys,
    pwd(),
    (0.0, t_dynamic_sim),
    perturbation;
    file_level =  Logging.Error,
    frequency_reference = ReferenceBus(),
)
#Run simulation with adaptive timestepping and small tolerance and save interval mathcing PSCAD. 
sim_time_adaptive = @timed execute!(sim, IDA(linear_solver = :KLU), saveat=500e-6, abstol=1e-9, reltol=1e-9)
@show sim_time_adaptive
result_psid_R = read_results(sim)


#Compare dyanmic results in PSID and PSCAD 
bus = get_component(Bus, sys, "Bus_1")
bus_number = get_number(bus)
bus_name = get_name(bus)
t_psid_0, voltage_psid_0 = get_voltage_magnitude_series(result_psid_0, bus_number)
t_psid_R, voltage_psid_R = get_voltage_magnitude_series(result_psid_R, bus_number)
trace_1 = PlotlyJS.scatter(x=t_psid_0, y=voltage_psid_0,  name="psid: R=0.0")
trace_2 = PlotlyJS.scatter(x=t_psid_R, y=voltage_psid_R,  name="psid: R=0.0385975")

case_100 =  CSV.read(joinpath(@__DIR__, "pscad_results_dynamics_100.csv"), DataFrame) 
case_100_R =  CSV.read(joinpath(@__DIR__, "pscad_results_dynamics_100_R.csv"), DataFrame)   
case_500 =  CSV.read(joinpath(@__DIR__, "pscad_results_dynamics_500.csv"), DataFrame)  
case_60Hz =  CSV.read(joinpath(@__DIR__, "pscad_results_dynamics_60Hz.csv"), DataFrame)  

trace_3 = PlotlyJS.scatter(x=case_100[!, "time"], y=case_100[!, "v_$bus_name"], name="pscad: 100us sample, 25us timestep")
trace_4 = PlotlyJS.scatter(x=case_500[!, "time"], y=case_500[!, "v_$bus_name"], name="pscad: 500us sample, 25us timestep")
trace_5 = PlotlyJS.scatter(x=case_100_R[!, "time"], y=case_100_R[!, "v_$bus_name"], name="pscad: 100us sample, 25us timestep, R=0.0385")
trace_6 = PlotlyJS.scatter(x=case_60Hz[!, "time"], y=case_60Hz[!, "v_$bus_name"], name="pscad: 500us sample, 25us timestep, 60Hz measurement, R=0.0385")

PlotlyJS.plot([trace_1, trace_2, trace_3, trace_4, trace_5, trace_6], Layout(xaxis = attr(title = "t"), yaxis = attr(title = "v_$bus_name")))

##
#Plot initialization of PSCAD
bus = get_component(Bus, sys, "Bus_1")
bus_number = get_number(bus)
bus_name = get_name(bus)
case_1 =  CSV.read(joinpath(@__DIR__, "pscad_results_init_0.csv"), DataFrame)  
trace_1 = PlotlyJS.scatter(x=case_1[!, "time"], y=case_1[!, "v_$bus_name"], name="v_$bus_name")
PlotlyJS.plot([trace_1], Layout(xaxis = attr(title = "t"), yaxis = attr(title = "V")))
##
