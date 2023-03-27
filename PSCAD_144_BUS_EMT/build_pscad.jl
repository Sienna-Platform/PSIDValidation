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

sys = System(joinpath(@__DIR__, "psid_files", "144Bus.json"))
pscad_workspace_name = "workspace_144bus.pswx"
pscad_case_name = "case_144bus"

#=  ############# BUILD AND SAVE A NEW SYSTEM #######################################
include(joinpath(@__DIR__, "psid_files", "bus_details.jl")) #define bus_coords_144 
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))
project =
    pscad.create_project(1, pscad_case_name, PyObject(joinpath(@__DIR__, "pscad_files"))) #create new project (1 for case, 2 for library)
build_system(
    sys,
    project,
    bus_coords_144;
    add_gen_breakers = true,
    add_load_breakers = true,
    add_line_breakers = true,
    add_multimeters = true,
)
project.save()

############# PARAMETERIZE EXISTING SYSTEM ####################################
parameterize_system(sys, project) 
project.save()  =#

pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  #load workspace 
project = pscad.project(pscad_case_name) #load existing project 


############# SETUP OUTPUT CHANNELS ###########################################
#quantities_to_record = [(:V, "Bus_53")]  #Note: Add more signals to save here (:P, pscad_compat_name("generator-13-1")),
#setup_output_channnels(project, quantities_to_record, (15, 2))
project = pscad.project(pscad_case_name) #load existing project 

buses = collect(get_components(Bus, sys))
quantities_to_record = []
for b in buses
    push!(quantities_to_record,[(:v, get_name(b))])
    push!(quantities_to_record,[(:ph, get_name(b))])  #Note: Add more signals to save here (:P, pscad_compat_name("generator-13-1")),
end
quantities_to_record
x = 6
y = 445
i = 0
for q in quantities_to_record
    setup_output_channnels(project, q, (x, y))
    y += 3 
    i += 1
    if i % 25 == 0
        y = 445
        x += 4 
    end
end

##
############# SETUP INITIALIZATION CHANNELS ###################################
project = pscad.project(pscad_case_name) #load existing project 

PP.update_parameter_by_name(project.find("master:const", "t_INV"), "Value", 0.5)
PP.update_parameter_by_name(project.find("master:const", "t_GEN"), "Value", 0.5)
PP.update_parameter_by_name(project.find("master:const", "t_RAMP"), "Value", 0.1)

############ RUN TO STEADY STATE, RECORD DATA, CHECK SS CONDITIONS ############
snapshot_name = "snap_short"
snapshot_path_for_startup  = joinpath(@__DIR__, "pscad_files", "case_144bus.gf46", string(snapshot_name, ".snp"))#  "snapshot_2.snp")

from_snap = true    #false -> save a snapshot during run; true -> start from snapshot 

if from_snap 
    set_project_parameters!(
        project;
        startup_filename = snapshot_path_for_startup,
        SnapType = 0,
        StartType = 1,
        time_duration = 0.015,
        sample_step = 1e-3 * 1e6,
        time_step = 25e-6 * 1e6,
    ) 
else 
    set_project_parameters!(
        project;
        snapshot_filename = snapshot_name,
        SnapType = 1,
        SnapTime = 0.025,
        time_duration = 0.027, 
        sample_step = 1e-3 * 1e6,
        time_step = 20e-6 * 1e6, 
    )
end 

pscad_output_folder_path = joinpath(@__DIR__, "pscad_files", string(pscad_case_name, ".gf46"))
foreach(rm, filter(!endswith(".snp"), readdir(pscad_output_folder_path,join=true))) #Don't delete snapshot file.

sim_time = @timed project.run()

sim = Simulation!(MassMatrixModel, sys, pwd(), (0.0, 0.0))
x0_dict = read_initial_conditions(sim)
snapshot_dict = Dict(read_initial_conditions(sim) => snapshot_name) # set snapshot name
Serialization.serialize("snapshot_dict", snapshot_dict)
save_directory = joinpath(@__DIR__, "results", "initialization")
mkpath(save_directory)

df = collect_pscad_outputs(pscad_output_folder_path)[1]  
open(joinpath(save_directory, "pscad_output.csv"), "w") do io
    CSV.write(io, df)
end
 
p = plot()
plotlyjs()
for signal_name in filter!(x-> x !== "time",names(df))
    plot!(p, df[1:end, "time"], df[1:end, signal_name], label = signal_name) #ylim=(0.9,1.1), xlim=(3.0,3.2))
end
display(p)
#TODO - CHECK INITIALIZATION WORKED AND SYSTEM IS IN STEADY STATE.
##
########### RUN SIMS AND SAVE DATA ############################################
project = pscad.project(pscad_case_name)
snapshot_dict = Serialization.deserialize("snapshot_dict")

set_project_parameters!(
    project;
    time_duration = 10.0,
    sample_step = 2e-4 * 1e6,
    time_step = 10e-6 * 1e6,
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
