using Pkg
Pkg.activate(".")
using Revise
using PowerSystems
using PowerSimulationsDynamics
using PyCall
using Conda
using UnPack
using DataFrames
using CSV

######################################################################
####################### USER INPUT ###################################
######################################################################
perturbation_type =  "LoadStepDown"     #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
pscad_workspace = "sauerpai_3bus_infinitebus.pswx"
pscad_case = "sauerpai_3bus_infinitebus" #the pscad case corresponding to the psid test
t_offset = 10.0                          #only collect data starting at t_offset
saveat = 5e-5
time_step = 5e-6 
t_span = (0.0, 3.0)
######################################################################
######################################################################
######################################################################

#Include Julia source code for conversion
include(joinpath(@__DIR__, "..", "..", "_pscad_psid_conversion", "PSCAD_PSID.jl"))
include(joinpath(@__DIR__, "..", "..", "_pscad_psid_conversion", "collect_data.jl"))

# Issue with path in windows per: https://github.com/JuliaPy/PyCall.jl/issues/730
ENV["PATH"] = Conda.bin_dir(Conda.ROOTENV) * ";" * ENV["PATH"] 

#Set build PyCall to use the pscadV5 python environment (name of environment could change)
ENV["PYTHON"] =   "C:\\Users\\Matt Bossart\\.conda\\envs\\pscad_v5\\python.exe"
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
pushfirst!(PyVector(pyimport("sys")."path"), joinpath("PSCAD", "_pscad_psid_conversion"))
PP = pyimport("PSCAD_Python")

#Delete pscad output folder from a previous run
pscad_output_folder_path =
    joinpath(@__DIR__, "..", "pscad_files", string(pscad_case, ".gf46"))
rm(pscad_output_folder_path, recursive=true, force=true)

#Start up PSCAD and read the PSID system
pscad = PP.basic_pscad_startup()
sleep(2)    #Need to wait for the last closed workspace to load and then load the one below
pscad.load(PyObject(joinpath(@__DIR__, "..", "pscad_files", pscad_workspace)))
project = pscad.project(pscad_case)
sys = System(joinpath(@__DIR__, "..", "psid_files", "system.json"))

#Generic Parameterization (should run this function for every case)
parameterize_system(sys, project)       

#Special Parameterizations for this particular system/study
PP.update_parameter_by_name(project.find("generator-102-1"), "omega_ref", "Freq_out")
if perturbation_type == "LoadStepDown"
    PP.update_parameter_by_name(project.find("t_LoadStepDownConstant"), "Value", 10.1 )
    PP.update_parameter_by_name(project.find("t_LoadStepUpConstant"), "Value", 100.0 )
    PP.update_parameter_by_name(project.find("t_LineTripConstant"), "Value", 100.0 )
elseif perturbation_type == "LoadStepUp"
    PP.update_parameter_by_name(project.find("t_LoadStepDownConstant"), "Value", 100.0 )
    PP.update_parameter_by_name(project.find("t_LoadStepUpConstant"), "Value", 10.1 )
    PP.update_parameter_by_name(project.find("t_LineTripConstant"), "Value", 100.0 )
elseif perturbation_type == "LineTrip"
    PP.update_parameter_by_name(project.find("t_LoadStepDownConstant"), "Value", 100.0 )
    PP.update_parameter_by_name(project.find("t_LoadStepUpConstant"), "Value", 100.0 )
    PP.update_parameter_by_name(project.find("t_LineTripConstant"), "Value", 10.1 )
else
    @error "Provided perturbation not found!"
end 
#See https://www.pscad.com/webhelp-v5-al/reference/project.html#properties for additional keywords
set_project_parameters!(project; time_duration = tspan[2] + t_offset, sample_step = saveat*1e6, time_step = time_step*1e6,)   

#Run PSCAD, quit when finished, and shutdown logging 
project.run()
pscad.quit()
logging.shutdown()

#Collect pscad outputs and write as dataframe to csv
df1 = collect_pscad_outputs(pscad_output_folder_path)[1]
df_filt = df1[df1[!,:time].>=t_offset, : ]   
open(joinpath(@__DIR__, "..", "pscad_files", string("pscad_outputs_", perturbation_type)), "w") do io
    CSV.write(io, df_filt)
end