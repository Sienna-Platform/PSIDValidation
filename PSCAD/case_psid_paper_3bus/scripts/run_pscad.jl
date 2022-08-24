#TODO
#1. Write a function to apply project settings dictionary to a case
#2. Write a function to enable/disable layers.
#3. Document installation process (conda, pscad automation library, etc.)

#Julia Packages
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
using Arrow

perturbation_type =  "LineTrip"     #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]  

include(joinpath(@__DIR__, "..", "..", "_pscad_psid_conversion", "PSCAD_PSID.jl"))
include(joinpath(@__DIR__, "..", "..", "_pscad_psid_conversion", "collect_data.jl"))

# Issue with path in windows per: https://github.com/JuliaPy/PyCall.jl/issues/730
ENV["PATH"] = Conda.bin_dir(Conda.ROOTENV) * ";" * ENV["PATH"]

#Set build PyCall to use the pscadV5 python environment
ENV["PYTHON"] =   "C:\\Users\\Matt Bossart\\.conda\\envs\\pscad_v5\\python.exe"# "C:\\ProgramData\\Anaconda3\\python.exe"# "C:\\Program Files\\Python37\\python.exe" #"C:\\anaconda\\envs\\pscadV5\\python.exe"  
Pkg.build("PyCall") 

mhi = pyimport("mhi.pscad")
sys = pyimport("sys")
logging = pyimport("logging")
os = pyimport("os")
time = pyimport("time")
win32 = pyimport("win32com.shell")
pyimport("sys")."path"
pushfirst!(PyVector(pyimport("sys")."path"), joinpath("PSCAD", "_pscad_psid_conversion")) #add automation_code directory to path
PP = pyimport("PSCAD_Python")

################################################################################
#USER INPUT
psid_system_path = joinpath(@__DIR__, "..", "psid_files",  "ThreeBusVSM_Droop.json") #serialized file from a PSID test
pscad_workspace = joinpath(@__DIR__, "..", "pscad_files", "psid_paper_3bus.pswx")
pscad_case = "psid_paper_3bus" #the pscad case corresponding to the psid test
pscad_output_folder_path =
    joinpath(@__DIR__, "..", "pscad_files", string(pscad_case, ".gf46"))
rm(pscad_output_folder_path, recursive=true, force=true)
rm(joinpath(@__DIR__, "..", "pscad_files", "pscad_outputs"), force=true)

pscad = PP.basic_pscad_startup()
sleep(2)
pscad.load(PyObject(pscad_workspace))
project = pscad.project(pscad_case)
sys = System(psid_system_path)
solve_powerflow(sys)["bus_results"]
sim = Simulation!(MassMatrixModel, sys, pwd(), (0.0, 0.0))
#ss = small_signal_analysis(sim)
x0_dict = read_initial_conditions(sim)
setpoints_dict = get_setpoints(sim)


thermal = collect(get_components(ThermalStandard, sys))
for t in thermal
    @show get_name(t)
    write_initial_conditions(t, get_name(t), project, x0_dict)
end

injectors = collect(get_components(DynamicInjection, sys))
for i in injectors
    write_setpoints(i, get_name(i), project, setpoints_dict)
    write_initial_conditions(i, get_name(i), project, x0_dict)
end

buses = collect(get_components(Bus, sys))
for b in buses
    write_initial_conditions(b, get_name(b), project, x0_dict)
end

components = collect(get_components(Component, sys))
for c in components
    @show get_name(c)
    write_parameters(c, get_name(c), project)
end

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


pscad_output_name = "pscad_outputs_linetrip"
sleep(1)
project.run()
sleep(1)
pscad.quit()
logging.shutdown()
sleep(1)

df1 = collect_pscad_outputs(pscad_output_folder_path)[1]
df_filt = df1[df1[!,:time].>=2.4, : ]       #CHANGE BACK 

open(joinpath(@__DIR__, "..", "pscad_files", string("pscad_outputs_", perturbation_type)), "w") do io
    CSV.write(io, df_filt)
end