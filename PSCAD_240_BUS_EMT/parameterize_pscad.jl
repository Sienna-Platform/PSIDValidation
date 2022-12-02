
#TODO - error when reading serialized system due to invalid field 
#sys = System(joinpath(@__DIR__, "psid_files", "system.json"))

using Test
using Revise
import LinearAlgebra
using Conda
using Pkg
using PyCall


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
pushfirst!(PyVector(pyimport("sys")."path"), joinpath("PSID2PSCAD", "_pscad_psid_conversion"))
PP = pyimport("PSCAD_Python")

function run_240bus_pscad(
    sys;
    t_GEN = 2.0, #release time for generators 
    t_INV = 5.0, #release time for inverters 
    perturbation_type = "LoadStepDown",  #Op,tions: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
    pscad_workspace = "workspace_3bus.pswx",
    pscad_case = "case_3bus",           #the pscad case corresponding to the psid test
    t_offset = 10.0,                    #only collect data starting at t_offset
    saveat = 5e-5,
    time_step = 5e-6,
    t_span = (0.0, 10.0),
    output_csv_name = "pscad_sauerpai_gfl",
)

    #Delete pscad output folder from a previous run
    pscad_output_folder_path =
        joinpath(@__DIR__, "..", "pscad_files", string(pscad_case, ".gf46"))
    rm(pscad_output_folder_path, recursive = true, force = true)

    #Start up PSCAD and read the PSID system
    pscad = PP.basic_pscad_startup()
    sleep(3)    #Need to wait for the last closed workspace to load and then load the one below
    pscad.load(PyObject(joinpath(@__DIR__, "..", "pscad_files", pscad_workspace)))
    @warn joinpath(@__DIR__, "..", "pscad_files", pscad_workspace)
    project = pscad.project(pscad_case)
    sys = System(joinpath(@__DIR__, "..", "psid_files", "system.json"))

    buses = collect(get_components(Bus, sys))
    for b in buses
        @info "writing Bus initial conditions and setpoints: $(get_name(b))"
        # TODO - add code for parameterizing all of the buses
    end 
end 
#Code to check if bus names all match and can be parameterized


run_240bus_pscad(sys)
