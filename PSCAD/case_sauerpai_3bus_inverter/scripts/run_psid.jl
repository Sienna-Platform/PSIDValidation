using Logging
using PowerSystems
using PowerSimulationsDynamics
using DataFrames
using Sundials
using CSV
system_file = joinpath(@__DIR__, "..", "psid_files", "ThreeBus_SauerPai_Droop.json")        
perturbation_type = "LineTrip"    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
line_type = "Dynamic"             #Options: ["Dynamic" "Algebraic"]   
recorded_voltages = [101, 102, 103]     
recorded_states = [ ("generator-102-1",:θ_oc)] 
system = System(system_file)
tspan = (0.0, 1.0)

if perturbation_type == "LoadStepDown"
        load = get_component(PowerLoad, system, "load1032")
        perturbation = LoadTrip(0.1, load)
elseif perturbation_type == "LoadStepUp"
        load = get_component(PowerLoad, system, "load1032")
        perturbation1 = LoadChange(0.1, load, :P_ref, 1.0)
        perturbation2 = LoadChange(0.1, load, :Q_ref, 0.1)
        perturbation = [perturbation1, perturbation2]
elseif perturbation_type == "LineTrip"
        perturbation = BranchTrip(0.1, Line,  "BUS 1-BUS 2-i_1")
else
        @error "Provided perturbation not found!"
end 

if line_type == "Algebraic"
        sim_ida = Simulation(
                ResidualModel,
                system,
                pwd(),
                tspan, 
                perturbation;
                file_level = Logging.Error,
                )
elseif line_type == "Dynamic" && perturbation_type == "LineTrip"
        for b in get_components(Line, system)
                if get_name(b) != "BUS 1-BUS 2-i_1"
                @warn b 
                        dyn_branch = PowerSystems.DynamicBranch(b)
                        add_component!(system, dyn_branch) 
                end 
        end 
        sim_ida = Simulation(
                ResidualModel,
                system,
                pwd(),
                tspan, 
                perturbation;
                file_level = Logging.Error,
                frequency_reference = ConstantFrequency,
                )
elseif line_type == "Dynamic"
        sim_ida = Simulation(
                ResidualModel,
                system,
                pwd(),
                tspan, 
                perturbation;
                file_level = Logging.Error,
                all_lines_dynamic = true
                )

else 
        @error "Provided line type not found!"
end 

ss = small_signal_analysis(sim_ida)
ss.eigenvalues
execute!(sim_ida, IDA(), dtmax = 1e-5, saveat=5e-5, abstol = 1e-14)
result_psid = read_results(sim_ida)

df = DataFrame()
df[!, "time"] =  get_voltage_magnitude_series(result_psid, 101)[1]

for v in recorded_voltages
        df[!, string("V_", v)] = get_voltage_magnitude_series(result_psid, v)[2]
end 
for s in recorded_states
        df[!, string(s[1], s[2])] = get_state_series(result_psid, s)[2]
end 

open(joinpath(@__DIR__, "..", "psid_files",  string("psid_outputs_", perturbation_type, "_", line_type)), "w") do io
        CSV.write(io, df)       
end  

