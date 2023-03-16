using Pkg
Pkg.activate(".")
using Test
using Revise
import LinearAlgebra
using PowerSystems
using PowerSimulationsDynamics
using PyCall
using Serialization
using Conda
using UnPack
using DataFrames
using CSV
using Plots


include(joinpath(@__DIR__, "..", "PSID2PSCAD", "_pscad_psid_conversion", "build_system.jl"))
include(
    joinpath(
        @__DIR__,
        "..",
        "PSID2PSCAD",
        "_pscad_psid_conversion",
        "parameterize_system.jl",
    ),
)
include(
    joinpath(
        @__DIR__,
        "..",
        "PSID2PSCAD",
        "_pscad_psid_conversion",
        "simulation_extras.jl",
    ),
)
include(joinpath(@__DIR__, "..", "PSID2PSCAD", "_pscad_psid_conversion", "collect_data.jl"))
include(joinpath(@__DIR__, "constants.jl"))

# Issue with path in windows per: https://github.com/JuliaPy/PyCall.jl/issues/730
ENV["PATH"] = Conda.bin_dir(Conda.ROOTENV) * ";" * ENV["PATH"]

#Set build PyCall to use the pscadV5 python environment (name of environment could change)
ENV["PYTHON"] = PYTHON_PATH
Pkg.build("PyCall")

#import python packages
mhi = pyimport("mhi.pscad")
sys = pyimport("sys")
logging = pyimport("logging")
os = pyimport("os")
time = pyimport("time")
win32 = pyimport("win32com.shell")

#add PSCAD_Python library directory to path
pyimport("sys")."path"
pushfirst!(
    PyVector(pyimport("sys")."path"),
    joinpath("PSID2PSCAD", "_pscad_psid_conversion"),
)

PP = pyimport("PSCAD_Python")
pscad = PP.basic_pscad_startup()
sleep(3)    #need to let the default files load in pscad before loading the workspace you want 

sys = System(joinpath(@__DIR__, "psid_files", "2bus.json"))
pscad_workspace_name = "workspace_2bus.pswx"
pscad_case_name = "case_2bus"

  ############# BUILD AND SAVE A NEW SYSTEM #######################################
#= include(joinpath(@__DIR__, "psid_files", "bus_details.jl")) #define bus_coords_144 
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))
project =
    pscad.create_project(1, pscad_case_name, PyObject(joinpath(@__DIR__, "pscad_files"))) #create new project (1 for case, 2 for library)
build_system(
    sys,
    project,
    bus_coords_2;
    add_gen_breakers = true,
    add_load_breakers = true,
    add_line_breakers = true,
    add_multimeters = true,
)
project.save() 
############# PARAMETERIZE EXISTING SYSTEM ####################################
parameterize_system(sys, project) 
project.save()      =#


pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  #load workspace 
project = pscad.project(pscad_case_name) #load existing project 

############# SETUP OUTPUT CHANNELS ###########################################
quantities_to_record = [ (:V, "Bus_53")]  #Note: Add more signals to save here
setup_output_channnels(project, quantities_to_record, (15, 2))

############# SETUP INITIALIZATION CHANNELS ###################################
PP.update_parameter_by_name(project.find("master:const", "t_INV"), "Value", 5.0)
PP.update_parameter_by_name(project.find("master:const", "t_GEN"), "Value", 1.0)
PP.update_parameter_by_name(project.find("master:const", "t_RAMP"), "Value", 0.1)

############ RUN TO STEADY STATE, RECORD DATA, CHECK SS CONDITIONS ############
snapshot_name = "snapshot_1" # set snapshot name
set_project_parameters!(
    project;
    snapshot_filename = snapshot_name,
    SnapType = 1,
    SnapTime = 4.0,
    time_duration = 30.0,
    sample_step = 50e-6 * 1e6,
    time_step = 40e-6 * 1e6,
)
pscad_output_folder_path = joinpath(@__DIR__, "pscad_files", string(pscad_case_name, ".gf46"))
rm(pscad_output_folder_path, recursive = true, force = true)     #Delete pscad_outputs from previous run 
using Sundials
sim_time = @timed project.run()
show_components(sys, ThermalStandard, [:active_power])
gen = get_component(DynamicGenerator, sys, "generator-13-1")
pert = ControlReferenceChange(0.1, gen, :P_ref, 0.7)
pert2 = GeneratorTrip(0.5, gen)
sim = Simulation!(ResidualModel, sys, pwd(), (0.0, 0.2), pert2)

execute!(sim, IDA())
res = read_results(sim)
display(filter(x-> x>0.05 && x<0.11,get_voltage_magnitude_series(res, 1)[1] ))
x0_dict = read_initial_conditions(sim)
snapshot_dict = Dict(read_initial_conditions(sim) => snapshot_name) # set snapshot name
Serialization.serialize("snapshot_dict", snapshot_dict)
save_directory = joinpath(@__DIR__, "results", "initialization")
mkpath(save_directory)





# Set the global logger
#global_logger(ConsoleLogger(stderr, Logging.Info))
df = collect_pscad_outputs(pscad_output_folder_path)[1]  
open(joinpath(save_directory, "pscad_output.csv"), "w") do io
    CSV.write(io, df)
end
for signal_name in filter!(x-> x !== "time",names(df))
    display(plot(df[5:end, "time"], df[5:end, signal_name], label = signal_name, width = 2, ylim = (0.9,1.1),xlim=(0.0,30.0), dpi = 5000))
end
#TODO - Plot some quantities to see if in steady state. 
#TODO - CHECK INITIALIZATION WORKED AND SYSTEM IS IN STEADY STATE.
#project.save()
##
########### RUN SIMS AND SAVE DATA ############################################
project = pscad.project(pscad_case_name)
snapshot_dict = Serialization.deserialize("snapshot_dict")

set_project_parameters!(
    project;
    time_duration = 10.0,
    sample_step = 2e-4 * 1e6,
    time_step = 10e-5 * 1e6,
)

perturbations = [BranchTrip(1.0, Line, "Bus_56-Bus_54-i_1")]      #Note: Add more perturbations here 
for p in perturbations
    folder_name = p.branch_name
    mkpath(folder_name)
    setup_breaker_operations(project, p)
    xo_dict = read_initial_conditions(Simulation!(MassMatrixModel, sys, pwd(), (0.0, 0.0)))
    if haskey(snapshot_dict, xo_dict)
        snapshot_file_name = snapshot_dict[xo_dict]
        set_project_parameters!(
            project;
            StartType = 1,
            startup_filename = snapshot_file_name,
        )
        PP.update_parameter_by_name(project.find("master:const", "t_INV"), "Value", 0.0)
        PP.update_parameter_by_name(project.find("master:const", "t_GEN"), "Value", 0.0)
        PP.update_parameter_by_name(project.find("master:const", "t_RAMP"), "Value", 0.0)
    else
        @error "Snapshot file for given operating condition not found."
    end
    set_project_parameters!(
        project;
        time_duration = 10.0,
        sample_step = 2e-4 * 1e6,
        time_step = 10e-5 * 1e6,
    )
    project.run()
    #TODO - make folder structure for systematic saving (name of folder = fault ran)
    df = collect_pscad_outputs(pscad_output_folder_path)[1]
    open(
        joinpath(@__DIR__, "..", "pscad_files", string(output_csv_name, ".csv")),
        "w",
    ) do io
        CSV.write(io, df)
    end
end

pscad.quit()
logging.shutdown()
