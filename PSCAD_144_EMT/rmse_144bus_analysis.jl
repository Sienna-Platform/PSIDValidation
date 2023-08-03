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
t_dynamic_sim = 5.0
time_step_pscad = 25e-6 * 1e6  

sys = System(joinpath(@__DIR__, string("144Bus", ".json")), runchecks = false)

for b in get_components(Line, sys)
    if get_name(b) != line_to_trip
        dyn_branch = PowerSystems.DynamicBranch(b)
        add_component!(sys, dyn_branch)
    end
end

perturbation = BranchTrip(0.1, Line, line_to_trip)
sim = Simulation(
    ResidualModel,
    sys,
    pwd(),
    (0.0, t_dynamic_sim),
    perturbation;
    file_level =  Logging.Error,
    frequency_reference = ReferenceBus(),
)

#Run simulation with dtmax matching PSCAD timestep and saveat matching save interval from PSCAD
sim_time_fixed = @timed execute!(sim, IDA(linear_solver = :KLU), maxiters=Int(1e6), dtmax = 25e-6, saveat=500e-6)
@show sim_time_fixed
result_psid_fixed = read_results(sim)
##
#Run simulation with adaptive timestepping and small tolerance and save interval mathcing PSCAD. 
sim_time_adaptive = @timed execute!(sim, IDA(linear_solver = :KLU), saveat=500e-6, abstol=1e-9, reltol=1e-9)
@show sim_time_adaptive
result_psid_adaptive = read_results(sim)

pscad_results_file = joinpath(@__DIR__, "pscad_results_dynamics.csv")
pscad_results = CSV.read(pscad_results_file, DataFrame)  #header =2? 

### Store Errors in Dictionaries ###
dict_voltage_fixed = Dict()
dict_speed_fixed = Dict()
dict_activepower_fixed = Dict() 
dict_reactivepower_fixed = Dict()
dict_voltage_adaptive = Dict()
dict_speed_adaptive = Dict()
dict_activepower_adaptive = Dict() 
dict_reactivepower_adaptive = Dict()

function pscad_compat_name(psid_name)
    return replace(psid_name, "-" => "_")
end 


#Section for storing RMSE for all traces 
for bus in get_components(Bus, sys)
    bus_number = get_number(bus)
    bus_name = get_name(bus)
    voltage_pscad  = pscad_results[!, "v_$bus_name"]
    #Compare for dtfixed
    t_psid, voltage_psid_fixed = get_voltage_magnitude_series(result_psid_fixed, bus_number)
    res_V_fixed = voltage_psid_fixed[2:end] .- voltage_pscad   #Don't have t=0 for PSCAD
    dict_voltage_fixed[bus_name] =  LinearAlgebra.norm(res_V_fixed) / length(res_V_fixed) 

    #Compare for adaptive
    t_psid, voltage_psid_adaptive = get_voltage_magnitude_series(result_psid_adaptive, bus_number)
    res_V_adaptive = voltage_psid_adaptive[2:end] .- voltage_pscad  #Don't have t=0 for PSCAD
    dict_voltage_adaptive[bus_name] =  LinearAlgebra.norm(res_V_adaptive) / length(res_V_adaptive)
end

for d in get_components(DynamicInjection, sys)
    scale_pscad = get_base_power(d) /100.0
    psid_name = get_name(d)
    pscad_name =  pscad_compat_name(psid_name)
    P_pscad = pscad_results[!, "P_$pscad_name"] ./ 100.0
    Q_pscad = pscad_results[!, "Q_$pscad_name"] ./ 100.0
    f_pscad = pscad_results[!, "f_$pscad_name"]

    #Compare for dtfixed
    _, P_psid_fixed = get_activepower_series(result_psid_fixed, psid_name)
    _, Q_psid_fixed = get_reactivepower_series(result_psid_fixed, psid_name)
    _, f_psid_fixed = get_frequency_series(result_psid_fixed, psid_name)
    res_P_fixed = P_psid_fixed[2:end]  .- P_pscad
    res_Q_fixed = Q_psid_fixed[2:end]  .- Q_pscad
    res_f_fixed = f_psid_fixed[2:end]  .- f_pscad
    dict_activepower_fixed[psid_name] = LinearAlgebra.norm(res_P_fixed) / length(res_P_fixed)
    dict_reactivepower_fixed[psid_name] = LinearAlgebra.norm(res_Q_fixed) / length(res_Q_fixed) 
    dict_speed_fixed[psid_name] =  LinearAlgebra.norm(res_f_fixed) / length(res_f_fixed) 

    #Compare for adaptive
    _, P_psid_adaptive = get_activepower_series(result_psid_adaptive, psid_name)
    _, Q_psid_adaptive = get_reactivepower_series(result_psid_adaptive, psid_name)
    _, f_psid_adaptive = get_frequency_series(result_psid_adaptive, psid_name)
    res_P_adaptive = P_psid_adaptive[2:end]  .- P_pscad
    res_Q_adaptive = Q_psid_adaptive[2:end]  .- Q_pscad
    res_f_adaptive = f_psid_adaptive[2:end]  .- f_pscad
    dict_activepower_adaptive[psid_name] = LinearAlgebra.norm(res_P_adaptive) / length(res_P_adaptive)
    dict_reactivepower_adaptive[psid_name] = LinearAlgebra.norm(res_Q_adaptive) / length(res_Q_adaptive) 
    dict_speed_adaptive[psid_name] =  LinearAlgebra.norm(res_f_adaptive) / length(res_f_adaptive)
end

p = plot(dict_speed_adaptive, label ="adaptive", title = "speed")
plot!(p, dict_speed_fixed, label = "fixed")
display(p)

p = plot(dict_voltage_adaptive, label ="adaptive", title = "votage")
plot!(p, dict_voltage_fixed, label = "fixed")
display(p)

p = plot(dict_activepower_adaptive, label ="adaptive", title = "P")
plot!(p, dict_activepower_fixed, label = "fixed")
display(p)

p = plot(dict_reactivepower_adaptive, label ="adaptive", title = "Q")
plot!(p, dict_reactivepower_fixed, label = "fixed")
display(p)

