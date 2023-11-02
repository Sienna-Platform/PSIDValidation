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
line_to_trip = "Bus_7-Bus_5-i_1" 
t_sample =  5.0e-4 #* 1e6 
t_dynamic_sim = 10.0
time_step_pscad = 25e-6 * 1e6  
pscad_dynamic_file = "pscad_results_dynamics.csv"
pscad_init_file = "pscad_results_init.csv"
sys = System(joinpath(@__DIR__, string("144Bus_with_shunts", ".json")), runchecks = false)

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
sim_time_adaptive = @timed execute!(sim, IDA(),abstol=1e-9, reltol=1e-9) # IDA(linear_solver = :KLU) errors 
@show sim_time_adaptive
result_psid_adaptive = read_results(sim)


##
#Compare dyanmic results in PSID and PSCAD 
bus_names_to_plot = ["Bus_1", "Bus_5", "Bus_144"]
traces = GenericTrace[]
case_pscad = CSV.read(joinpath(@__DIR__, "pscad_results_dynamics.csv"), DataFrame) 
for bus_name in bus_names_to_plot
    bus = get_component(Bus, sys, bus_name)
    bus_number = get_number(bus)
    t_psid_0, voltage_psid_0 = get_voltage_magnitude_series(result_psid_adaptive, bus_number)
    trace_psid = PlotlyJS.scatter(x=t_psid_0, y=voltage_psid_0,  name="psid, $bus_name")
    trace_pscad = PlotlyJS.scatter(x=case_pscad[!, "time"], y=case_pscad[!, "v_$bus_name"], name="pscad, $bus_name")
    push!(traces, trace_psid)
    push!(traces, trace_pscad)
end 
display(PlotlyJS.plot(traces, Layout(xaxis = attr(title = "t"), yaxis = attr(title = "v_$bus_name"))))

function pscad_compat_name(psid_name)
    return replace(psid_name, "-" => "_")
end
generator_freq_to_plot = ["generator-33-1", "GFM_Battery_43", "GFL_Battery_153"]
traces = GenericTrace[]
case_pscad = CSV.read(joinpath(@__DIR__, "pscad_results_dynamics.csv"), DataFrame) 
for generator_name in generator_freq_to_plot
    t_psid_0, voltage_psid_0 = get_frequency_series(result_psid_adaptive, generator_name)
    trace_psid = PlotlyJS.scatter(x=t_psid_0, y=voltage_psid_0,  name="psid, $generator_name")
    trace_pscad = PlotlyJS.scatter(x=case_pscad[!, "time"], y=case_pscad[!, "f_$(pscad_compat_name(generator_name))"], name="pscad, $(pscad_compat_name(generator_name))")
    push!(traces, trace_psid)
    push!(traces, trace_pscad)
end 
PlotlyJS.plot(traces, Layout(xaxis = attr(title = "t"), yaxis = attr(title = "frequency")))

##
#Plot initialization of PSCAD
bus = get_component(Bus, sys, "Bus_2")
bus_number = get_number(bus)
bus_name = get_name(bus)
case_1 =  CSV.read(joinpath(@__DIR__, "pscad_results_init.csv"), DataFrame)  
trace_1 = PlotlyJS.scatter(x=case_1[!, "time"], y=case_1[!, "v_Bus_1"], name="v_$bus_name")
trace_2 = PlotlyJS.scatter(x=case_1[!, "time"], y=case_1[!, "v_Bus_2"], name="v_$bus_name")
trace_3 = PlotlyJS.scatter(x=case_1[!, "time"], y=case_1[!, "v_Bus_7"], name="v_$bus_name")
PlotlyJS.plot([trace_1, trace_2, trace_3], Layout(xaxis = attr(title = "t"), yaxis = attr(title = "V")))
##
