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
pushfirst!(PyVector(pyimport("sys")."path"), joinpath("PSID2PSCAD", "_pscad_psid_conversion"))
PP = pyimport("PSCAD_Python")

sys = System(joinpath(@__DIR__, "psid_files" , "144Bus.json"))

pscad_workspace = "workspace_144bus.pswx"
pscad_case = "case_144bus"
pscad = PP.basic_pscad_startup()
sleep(3)
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace)))
@warn joinpath(@__DIR__,  "pscad_files", pscad_workspace)
PyObject(joinpath(@__DIR__, "pscad_files"))
pscad.create_project(1, pscad_case, PyObject(joinpath(@__DIR__, "pscad_files")))
project = pscad.project(pscad_case)

centerpoints = Dict()

centerpoints["Bus 53"] = (20,40), "wide", "n" 
centerpoints["Bus 59"] = (20,60), "wide", "none" 
centerpoints["Bus 56"] = (50,80), "tall", "e"

centerpoints["Bus 51"] = (80,115), "tall", "e"
centerpoints["Bus 54"] = (70,115), "tall", "none"
centerpoints["Bus 58"] = (20,110), "wide", "s"
centerpoints["Bus 55"] = (50,140), "tall", "e"
centerpoints["Bus 57"] = (20,160), "wide", "none" 
centerpoints["Bus 52"] = (20,180), "wide", "s" 
centerpoints["Bus 45"] = (60,180), "wide", "none"

centerpoints["Bus 41"] = (100,150), "wide", "n"
centerpoints["Bus 44"] = (100,170), "wide", "none"
centerpoints["Bus 46"] = (130,180), "wide", "s"

centerpoints["Bus 42"] = (30,220), "tall", "w"
centerpoints["Bus 47"] = (50,220), "tall", "none"
centerpoints["Bus 2"] = (30,250), "tall", "w"
centerpoints["Bus 7"] = (50,250), "tall", "none"
centerpoints["Bus 12"] = (20,290), "wide", "n" 
centerpoints["Bus 5"] = (60,290), "wide", "s"

centerpoints["Bus 17"] = (20,310), "wide", "none" 
centerpoints["Bus 15"] = (50,325), "tall", "e"
centerpoints["Bus 18"] = (20,360), "wide", "s"
centerpoints["Bus 14"] = (70,360), "tall", "none"
centerpoints["Bus 11"] = (80,360), "tall", "e"
centerpoints["Bus 16"] = (50,390), "tall", "e"

centerpoints["Bus 19"] = (20,410), "wide", "none" 
centerpoints["Bus 13"] = (20,430), "wide", "s" 

centerpoints["Bus 48"] = (100,220), "tall", "e"
centerpoints["Bus 49"] = (150,220), "tall", "none"
centerpoints["Bus 43"] = (170,220), "tall", "e"
centerpoints["Bus 8"] = (100,260), "tall", "e"
centerpoints["Bus 9"] = (150,260), "tall", "none"
centerpoints["Bus 3"] = (170,260), "tall", "e"
centerpoints["Bus 6"] = (130,290), "wide", "s"

centerpoints["Bus 4"] = (100,310), "wide", "none"
centerpoints["Bus 1"] = (100,320), "wide", "s"

centerpoints["Bus 61"] = (290,150), "wide", "n"
centerpoints["Bus 64"] = (290,160), "wide", "none"
centerpoints["Bus 66"] = (250,180), "wide", "s"

centerpoints["Bus 63"] = (220,220), "tall", "w"
centerpoints["Bus 69"] = (240,220), "tall", "none"
centerpoints["Bus 68"] = (290,220), "tall", "e"
centerpoints["Bus 23"] = (220,260), "tall", "w"
centerpoints["Bus 29"] = (240,260), "tall", "none"
centerpoints["Bus 28"] = (290,260), "tall", "e"
centerpoints["Bus 26"] = (250,290), "wide", "s"

centerpoints["Bus 24"] = (285,310), "wide", "none"
centerpoints["Bus 21"] = (285,320), "wide", "s"

centerpoints["Bus 73"] = (370,40), "wide", "n" 
centerpoints["Bus 79"] = (370,70), "wide", "none" 
centerpoints["Bus 76"] = (330,80), "tall", "w"

centerpoints["Bus 71"] = (300,110), "tall", "w"
centerpoints["Bus 74"] = (310,110), "tall", "none"
centerpoints["Bus 78"] = (370,110), "wide", "n"
centerpoints["Bus 75"] = (330,150), "tall", "w"
centerpoints["Bus 77"] = (370,160), "wide", "none" 
centerpoints["Bus 72"] = (370,180), "wide", "s" 
centerpoints["Bus 65"] = (320,180), "wide", "s"

centerpoints["Bus 67"] = (330,220), "tall", "none"
centerpoints["Bus 62"] = (360,220), "tall", "e"
centerpoints["Bus 27"] = (330,260), "tall", "none"
centerpoints["Bus 22"] = (360,260), "tall", "e"
centerpoints["Bus 25"] = (320,290), "wide", "s"
centerpoints["Bus 32"] = (370,290), "wide", "n" 

centerpoints["Bus 37"] = (370,310), "wide", "none" 
centerpoints["Bus 35"] = (330,325), "tall", "w"
centerpoints["Bus 34"] = (310,360), "tall", "none"
centerpoints["Bus 31"] = (300,360), "tall", "w"
centerpoints["Bus 38"] = (370,360), "wide", "s"
centerpoints["Bus 36"] = (330,390), "tall", "w"

centerpoints["Bus 39"] = (370,410), "wide", "none" 
centerpoints["Bus 33"] = (370,430), "wide", "s" 

centerpoints["Bus 133"] = (430,40), "wide", "n" 
centerpoints["Bus 139"] = (430,70), "wide", "none" 
centerpoints["Bus 136"] = (470,80), "tall", "e"

centerpoints["Bus 131"] = (490,110), "tall", "e"
centerpoints["Bus 134"] = (480,110), "tall", "none"
centerpoints["Bus 138"] = (430,110), "wide", "n"
centerpoints["Bus 135"] = (470,150), "tall", "w"
centerpoints["Bus 137"] = (430,160), "wide", "none" 
centerpoints["Bus 132"] = (430,180), "wide", "s" 
centerpoints["Bus 125"] = (480,190), "wide", "s"

centerpoints["Bus 122"] = (440,220), "tall", "w"
centerpoints["Bus 127"] = (460,220), "tall", "none"
centerpoints["Bus 82"] = (440,260), "tall", "w"
centerpoints["Bus 87"] = (460,260), "tall", "none"
centerpoints["Bus 92"] = (430,290), "wide", "n" 
centerpoints["Bus 85"] = (470,290), "wide", "s"

centerpoints["Bus 97"] = (430,320), "wide", "none" 
centerpoints["Bus 95"] = (460,330), "tall", "e"
centerpoints["Bus 98"] = (430,370), "wide", "s"
centerpoints["Bus 94"] = (480,370), "tall", "none"
centerpoints["Bus 91"] = (490,370), "tall", "e"
centerpoints["Bus 96"] = (460,400), "tall", "e"

centerpoints["Bus 99"] = (430,410), "wide", "none" 
centerpoints["Bus 93"] = (430,430), "wide", "s"  

centerpoints["Bus 121"] = (510,160), "wide", "n"
centerpoints["Bus 124"] = (510,170), "wide", "none"
centerpoints["Bus 126"] = (540,190), "wide", "s"

centerpoints["Bus 128"] = (510,220), "tall", "e"
centerpoints["Bus 129"] = (550,220), "tall", "none"
centerpoints["Bus 123"] = (580,220), "tall", "e"
centerpoints["Bus 88"] = (510,260), "tall", "e"
centerpoints["Bus 89"] = (550,260), "tall", "none"
centerpoints["Bus 83"] = (580,260), "tall", "e"
centerpoints["Bus 86"] = (540,290), "wide", "s"

centerpoints["Bus 84"] = (510,310), "wide", "none"
centerpoints["Bus 81"] = (510,320), "wide", "s"

centerpoints["Bus 141"] = (690,160), "wide", "n"
centerpoints["Bus 144"] = (690,170), "wide", "none"
centerpoints["Bus 146"] = (660,190), "wide", "s"

centerpoints["Bus 143"] = (630,220), "tall", "w"
centerpoints["Bus 149"] = (650,220), "tall", "none"
centerpoints["Bus 148"] = (690,220), "tall", "w"
centerpoints["Bus 103"] = (630,260), "tall", "w"
centerpoints["Bus 109"] = (650,260), "tall", "none"
centerpoints["Bus 108"] = (690,260), "tall", "e"
centerpoints["Bus 106"] = (660,290), "wide", "s"

centerpoints["Bus 104"] = (690,310), "wide", "none"
centerpoints["Bus 101"] = (690,320), "wide", "s"

centerpoints["Bus 153"] = (780,40), "wide", "n" 
centerpoints["Bus 159"] = (780,60), "wide", "none" 
centerpoints["Bus 156"] = (740,80), "tall", "w"

centerpoints["Bus 151"] = (710,110), "tall", "w"
centerpoints["Bus 154"] = (720,110), "tall", "none"
centerpoints["Bus 158"] = (780,120), "wide", "s"
centerpoints["Bus 155"] = (740,150), "tall", "w"
centerpoints["Bus 157"] = (780,160), "wide", "none" 
centerpoints["Bus 152"] = (780,180), "wide", "s" 
centerpoints["Bus 145"] = (730,190), "wide", "s"

centerpoints["Bus 147"] = (740,220), "tall", "none"
centerpoints["Bus 142"] = (760,220), "tall", "e"
centerpoints["Bus 107"] = (740,260), "tall", "none"
centerpoints["Bus 102"] = (760,260), "tall", "e"
centerpoints["Bus 105"] = (730,290), "wide", "s"
centerpoints["Bus 112"] = (780,290), "wide", "n"

centerpoints["Bus 117"] = (780,320), "wide", "none" 
centerpoints["Bus 115"] = (740,330), "tall", "w"
centerpoints["Bus 118"] = (780,370), "wide", "s"
centerpoints["Bus 114"] = (720,370), "tall", "none"
centerpoints["Bus 111"] = (710,370), "tall", "w"
centerpoints["Bus 116"] = (740,400), "tall", "w"

centerpoints["Bus 119"] = (780,410), "tall", "none" 
centerpoints["Bus 113"] = (780,430), "wide", "s" 

build_system(sys, project, centerpoints)



