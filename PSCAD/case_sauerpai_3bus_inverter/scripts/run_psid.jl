using Revise
using Logging
using OrdinaryDiffEq
using PowerSystems
using PowerSimulationsDynamics
using Plots
using DataFrames
using Sundials
using CSV
const PSY = PowerSystems

######################################################################
####################### USER INPUT ###################################
######################################################################
     
rawfile = "ThreeBusPSCAD.raw"
perturbation_type = "LoadStepDown"    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]
line_to_trip = "BUS 1-BUS 2-i_1"  
line_type = "Dynamic"                 #Options: ["Dynamic" "Algebraic"]   
recorded_voltages = [101, 102, 103]   # Bus numbers to record voltage  
recorded_states = [("generator-101-1",:ω)]#, ("generator-102-1",:θ_oc)] 
saveat = 5e-5
tspan = (0.0, 3.0)
ref_bus_number = 101
frequency_reference = "ReferenceBus" #["ReferenceBus, "ConstantFrequency"]
solver = "Rodas5"
abstol = 1e-14
output_csv_name = "psid_Rodas5" #
######################################################################
######################################################################
######################################################################

include(joinpath(@__DIR__, "..", "psid_files", "dynamic_test_data.jl") )   
sys = System( joinpath(@__DIR__, "..", "psid_files", rawfile ) , runchecks = false)

for l in get_components(PSY.PowerLoad, sys)
    PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
end

for g in get_components(Generator, sys)
    if get_number(get_bus(g)) == 101
        case_gen = dyn_gen_sauerpai(g)
        add_component!(sys, case_gen, g)
    elseif get_number(get_bus(g)) == 102
        case_gen = dyn_gen_sauerpai(g)   #inv_case78(g)  inv_gfoll(g) inv_darco_droop(g) #dyn_gen_sauerpai(g)
        add_component!(sys, case_gen, g)
    end
end

for b in get_components(Bus, sys)
    if (get_number(b) == ref_bus_number) && (get_bustype(b) == BusTypes.REF) 
        @info "Indicated bus is already reference --leaving as is"
    end 
    if (get_number(b) !== ref_bus_number)  && (get_bustype(b) == BusTypes.REF) 
        @warn "Setting the previous reference bus ($(get_number(b))) to PV"
        set_bustype!(b, BusTypes.PV)
    end 
    if (get_number(b) == ref_bus_number) && (get_bustype(b) !== BusTypes.REF)
        @warn "Setting the indicated bus ($(get_number(b))) to be the reference bus."
        set_bustype!(b, BusTypes.REF)
    end 
end 

to_json(sys, joinpath(@__DIR__, "..", "psid_files", "system.json"), force=true)

sys = System(joinpath(@__DIR__, "..", "psid_files", "system.json")  )

if perturbation_type == "LoadStepDown"
        load = get_component(PowerLoad, sys, "load1032")
        perturbation = LoadTrip(0.1, load)
elseif perturbation_type == "LoadStepUp"
        load = get_component(PowerLoad, sys, "load1032")
        perturbation1 = LoadChange(0.1, load, :P_ref, 1.0)
        perturbation2 = LoadChange(0.1, load, :Q_ref, 0.1)
        perturbation = [perturbation1, perturbation2]
elseif perturbation_type == "LineTrip"
        perturbation = BranchTrip(0.1, Line,  line_to_trip)
else
        @error "Provided perturbation not found!"
end 


if line_type == "Dynamic" && perturbation_type == "LineTrip"
        for b in get_components(Line, sys)
            if get_name(b) != line_to_trip
                dyn_branch = PowerSystems.DynamicBranch(b)
                add_component!(sys, dyn_branch) 
            end 
        end 
elseif line_type == "Dynamic"
    for b in get_components(Line, sys)
        dyn_branch = PowerSystems.DynamicBranch(b)
        add_component!(sys, dyn_branch) 
    end 
end 

if frequency_reference == "ReferenceBus"
    if solver == "IDA"
        sim = Simulation!(
            ResidualModel,
            sys,
            pwd(),
            tspan, 
            perturbation;
            file_level = Logging.Error,
            frequency_reference = ReferenceBus
            )
    elseif solver == "Rodas5"
        sim = Simulation!(
            MassMatrixModel,
            sys,
            pwd(),
            tspan, 
            perturbation;
            file_level = Logging.Error,
            frequency_reference = ReferenceBus
            )
    else 
        @error "invalid solver choice"
    end 
elseif frequency_reference == "ConstantFrequency"
    if solver == "IDA"
        sim = Simulation!(
            ResidualModel,
            sys,
            pwd(),
            tspan, 
            perturbation;
            file_level = Logging.Error,
            frequency_reference = ConstantFrequency
            )
    elseif solver == "Rodas5"
        sim = Simulation!(
            MassMatrixModel,
            sys,
            pwd(),
            tspan, 
            perturbation;
            file_level = Logging.Error,
            frequency_reference = ConstantFrequency
            )
    else 
        @error "invalid solver choice"
    end 
else 
    @error "invalid input for frequency_reference"
end 

ss = small_signal_analysis(sim) #fieldnames(ss)
if ss.stable == false 
    @error "System is not small-signal stable"
    display(ss.eigenvalues)
    @assert false 
end 
display(solve_powerflow(sim.sys)["bus_results"])
if solver == "IDA"
    execute!(sim, IDA(), saveat=saveat, abstol = abstol) #dtmax = 1e-5,
elseif solver == "Rodas5"
    execute!(sim, Rodas5(), saveat=saveat, abstol = abstol) #dtmax = 1e-5,
end 
display(solve_powerflow(sys)["bus_results"])    #Is this the powerflow after the simulation ran? 
result_psid = read_results(sim)

df = DataFrame()
df[!, "time"] =  get_voltage_magnitude_series(result_psid, 101)[1]

for v in recorded_voltages
        df[!, string("V_", v)] = get_voltage_magnitude_series(result_psid, v)[2]
end 
for s in recorded_states
        df[!, string(s[1], s[2])] = get_state_series(result_psid, s)[2]
end 

open(joinpath(@__DIR__, "..", "psid_files",  string(output_csv_name,".csv")), "w") do io
        CSV.write(io, df)       
end  




