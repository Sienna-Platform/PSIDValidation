using Test
using Revise
import LinearAlgebra
include(joinpath(@__DIR__, "..", "psid_files", "dynamic_test_data.jl"))
include(joinpath(@__DIR__, "..", "..", "PSID2PSCAD", "_pscad_psid_conversion", "PSCAD_PSID.jl"))
include(joinpath(@__DIR__, "..", "..", "PSID2PSCAD", "_pscad_psid_conversion", "collect_data.jl"))
include(joinpath(@__DIR__, "..", "constants.jl"))
include(joinpath(@__DIR__, "..", "src", "run_psid.jl"))       
include(joinpath(@__DIR__, "..", "src", "run_pscad.jl"))
include(joinpath(@__DIR__, "..", "src", "plot_utils.jl"))

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

#include(joinpath(@__DIR__, "test_psid_paper_3bus.jl"))
#include(joinpath(@__DIR__, "test_fixedsauerpai_gfl_3bus.jl"))   #TODO - debug state limit gets hit later than test window
#TODO - add more tests for machine/mixed devices 
