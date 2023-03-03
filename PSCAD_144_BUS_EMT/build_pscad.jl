using Pkg
Pkg.activate(".")
using Test
using Revise
import LinearAlgebra
using PowerSystems
using PowerSimulationsDynamics
using PyCall
using Conda
using UnPack
using DataFrames
using CSV

include(joinpath(@__DIR__, "..", "PSID2PSCAD", "_pscad_psid_conversion", "build_system.jl"))
include(joinpath(@__DIR__, "..", "PSID2PSCAD", "_pscad_psid_conversion", "parameterize_system.jl"))
include(joinpath(@__DIR__, "..", "PSID2PSCAD", "_pscad_psid_conversion", "simulation_extras.jl"))
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
##
############# BUILD AND SAVE A NEW SYSTEM #######################################
include(joinpath(@__DIR__, "psid_files", "bus_details.jl")) #define bus_coords_144 
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  #load workspace 
project =
    pscad.create_project(1, pscad_case_name, PyObject(joinpath(@__DIR__, "pscad_files"))) #create new project (1 for case, 2 for library)
build_system(sys, project, bus_coords_144; add_gen_breakers = true, add_load_breakers = true, add_line_breakers = true, add_multimeters = true) #build the system (place the components)
project.save()
##
############# PARAMETERIZE EXISTING SYSTEM #######################################
#pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  #load workspace 
#project = pscad.project(pscad_case_name) #load existing project 
parameterize_system(sys, project)   #parameterize each component 
project.save()
##
############# SETUP PERIPHERAL COMPONENTS ########################################
#Setup Output Channels
quantities_to_record = [(:P, pscad_compat_name("generator-13-1")), (:V, "Bus_53")]
setup_output_channnels(project, quantities_to_record, (15, 2))

#Setup breaker logic for perturbation (Don't save after setting breaker logic) 
perturbation = BranchTrip(1.0, Line,  "Bus_56-Bus_54-i_1")
setup_breaker_operations(project, perturbation)

PP.update_parameter_by_name(project.find("master:const", "t_INV"), "Value", 2.0)
PP.update_parameter_by_name(project.find("master:const", "t_GEN"), "Value", 2.0)
PP.update_parameter_by_name(project.find("master:const", "t_RAMP"), "Value", 2.0)

set_project_parameters!(project; time_duration =10.0, sample_step = 2e-4 * 1e6, time_step = 10e-5 * 1e6)