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

include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion", "build_system.jl"))
include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion", "parameterize_system.jl"))
include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion", "simulation_extras.jl"))
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
hodge_certificate = pscad.get_available_certificates()[1246234737]
pscad.get_certificate(hodge_certificate)

############################################################################################
################################### USER VARIABLES #########################################
############################################################################################
#sys = System(joinpath(@__DIR__, "psid_files", "144Bus.json"))
sys = System(joinpath(@__DIR__, "psid_files", "9bus.json"))

pscad_workspace_name = "workspace_144bus.pswx"
pscad_case_name = "case_144"
output_csv_filename = "144bus_faults.csv"
build_from_scratch = false  
sample_step =  5.0e-3 * 1e6
time_step = 20e-6 * 1e6
time_duration = 10.0
t_inv = 4.0
t_gen = 4.0
save_snapshot = 0 # 0: no snapshot, 1: single snapshot, 2: multiple snapshots (same file), 3:  multiple snapshots (separate files)  
save_snapshot_name = ""
save_snapshot_time = 3.0    #if saving one snapshot, occurs at this time. If multiple, this is the interval between saves 
load_snapshot = true   
load_snapshot_name = "snap_144bus"
fortran_version = ".gf46"
load_snapshot_path  = joinpath(@__DIR__, "pscad_files", string(pscad_case_name, fortran_version), string(load_snapshot_name, ".snp"))
perturbations = [GeneratorTrip(11.0, get_component(DynamicInjection, sys, "GFL_Battery_2" ))]  #[ BranchTrip(19.1, Line, "Bus_56-Bus_54-i_1"),  GeneratorTrip(19.1, get_component(DynamicInjection, sys, "GFL_Battery_31" ))]  

############################################################################################
############################################################################################


function _assign_perturbation_name(p)
    if typeof(p) == BranchTrip
        return p.branch_name
    elseif typeof(p) == GeneratorTrip
        return get_name(p.device) 
    else 
        @error "No method for assigning folder name for given PSID perturbation"
    end 
end 

for p in perturbations 
    #re-load for each iteration so that prior breakers are not saved
    pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  
    project = pscad.project(pscad_case_name)

    PP.update_parameter_by_name(project.find("master:const", "t_INV"), "Value", t_inv)
    PP.update_parameter_by_name(project.find("master:const", "t_GEN"), "Value", t_gen)
    PP.update_parameter_by_name(project.find("master:const", "t_RAMP"), "Value", 0.1)

    setup_breaker_operations(project, p)
    perturbation_name = _assign_perturbation_name(p)

    set_project_parameters!(
        project;
        snapshot_filename = save_snapshot_name,
        startup_filename = load_snapshot_path,
        SnapType = save_snapshot, 
        SnapTime = save_snapshot_time,
        StartType =  Int64(load_snapshot), 
        time_duration = time_duration,
        sample_step = sample_step,
        time_step =time_step,
    ) 

    pscad_output_folder_path = joinpath(@__DIR__, "pscad_files", string(pscad_case_name, fortran_version))

    if isdir(pscad_output_folder_path)
        foreach(rm, filter(!endswith(".snp") , readdir(pscad_output_folder_path,join=true))) #Don't delete snapshot file.
    end 
    sim_time = @timed project.run()
    save_directory = joinpath(@__DIR__, "results")
    df = collect_pscad_outputs(pscad_output_folder_path)[1]  
    open(joinpath(save_directory, string(perturbation_name, ".csv")), "w") do io
        CSV.write(io, df)
    end
end 

pscad.release_all_certificates() 
pscad.quit()    
logging.shutdown()


##Setup for GFL fault 
#= case_9bus = pscad.project("case_9bus")
canvas = case_9bus.canvas("Main")
const1 = canvas.create_component("master:const", )
const1.set_location(34, 234)
const1.parameters(Value="0.6583658338314021", )
const2 = canvas.create_component("master:const", )
const2.set_location(34, 232)
const2.parameters(Value="0.2", )
master = pscad.project("master")
master.navigate_to()
csmf = master.component(59167590)
master.navigate_to(csmf)
canvas2 = master.canvas("CSMF")
select = master.component(48826322)
canvas2.copy(select)
case_9bus.navigate_to()
canvas.paste()
select2 = case_9bus.component(1143510598)
select2.set_location(38, 234)
sig_1 = canvas.create_component("master:datalabel", )
sig_1.set_location(42, 234)
sig_1.parameters(Name="Pref_gfl_2", )
master.navigate_to()
master.navigate_to(csmf)
compar = master.component(25879650)
canvas2.copy(compar)
canvas.paste()
master.navigate_to()
miscellaneous = master.component(62746268)
master.navigate_to(miscellaneous)
canvas3 = master.canvas("Miscellaneous")
time_sig = master.component(44123454)
canvas3.copy(time_sig)
case_9bus.navigate_to()
canvas.paste()
compar2 = case_9bus.component(2006249007)
compar2.parameters(Pulse="0", OHi="0", OLo="1", )
wire = canvas.create_wire([(36, 237), (38, 237), (38, 236), ])
wire2 = canvas.create_wire([(40, 234), (42, 234), ])
const3 = canvas.create_component("master:const", )
const3.set_location(30, 237)
const3.parameters(Value="21.0", )
gfl_battery_2 = case_9bus.component(1748888177)
gfl_battery_2.parameters() =#
