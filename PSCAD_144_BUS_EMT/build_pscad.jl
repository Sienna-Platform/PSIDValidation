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

include(joinpath(@__DIR__, "..", "PSID2PSCAD", "_pscad_psid_conversion", "PSCAD_PSID.jl"))
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

sys = System(joinpath(@__DIR__, "psid_files", "144Bus.json"), bus_name_formatter = x->string(x["name"]))  
pscad_workspace_name = "workspace_144bus.pswx"
pscad_case_name = "case_144bus"

############# PARAMETERIZE EXISTING SYSTEM #######################################
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  #load workspace 
project = pscad.project(pscad_case_name) #load existing project 
parameterize_system(sys, project)   #parameterize each component 

##
############# BUILD AND SAVE A NEW SYSTEM #######################################
include(joinpath(@__DIR__, "psid_files", "bus_details.jl")) #define bus_coords_144 
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  #load workspace 
project =
    pscad.create_project(1, pscad_case_name, PyObject(joinpath(@__DIR__, "pscad_files"))) #create new project (1 for case, 2 for library)
build_system(sys, project, bus_coords_144) #build the system (place the components)
project.save()
