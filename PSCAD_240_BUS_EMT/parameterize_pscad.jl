using Test
using Revise
import LinearAlgebra
using Conda
using Pkg
using PyCall

#DOCUMENTATION FOR AUTOMATION LIBRARY: https://www.pscad.com/webhelp/al-help/index.html#

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

sys = System(joinpath(@__DIR__, "psid_files", "system.json"))
t_GEN = 2.0 #release time for generators 
t_INV = 5.0 #release time for inverters 
perturbation_type = "LoadStepDown"  #Op,tions: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
pscad_workspace = "workspace_240bus.pswx"
pscad_case = "case_240bus"           #the pscad case corresponding to the psid test
t_offset = 10.0              #only collect data starting at t_offset
saveat = 5e-5
time_step = 5e-6
t_span = (0.0, 10.0)
output_csv_name = "pscad_sauerpai_gfl"

#Delete pscad output folder from a previous run
pscad_output_folder_path =
    joinpath(@__DIR__, "..", "pscad_files", string(pscad_case, ".gf46"))
rm(pscad_output_folder_path, recursive = true, force = true)

#Start up PSCAD and read the PSID system
pscad = PP.basic_pscad_startup()
sleep(3)    #Need to wait for the last closed workspace to load and then load the one below
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace)))

#project = pscad.project(pscad_case)
sim = Simulation!(MassMatrixModel, sys, pwd(), (0.0, 0.0))
ss = small_signal_analysis(sim)
@warn ss.stable
x0_dict = read_initial_conditions(sim)
setpoints_dict = get_setpoints(sim)
buses = collect(get_components(Bus, sys))

#= #Programmatically Remove "_1" and "_2" from bus names 
for p in pscad.projects()
    project = pscad.project(p["name"])
    buses = project.find_all("Bus")
    for b in buses
        pscad_params = b.parameters()
        name  = pscad_params["Name"]
        #println(name)
        if endswith(name, r"_1|_2")
            newname = chop(name, tail = 2)
            pscad_params["Name"] = newname
            println(newname)
            PP.update_parameter_by_dictionary(b, pscad_params)
        else 
            println(name)
        end 
    end 
end  =#


#WRITE INITIAL CONDITIONS FOR BUSES (WORKING)
#= for (ix,b) in enumerate(collect(buses))
    @error  "writing Bus initial conditions and setpoints: $(get_name(b))"
    println("ADD $(ix-1)")
    project = find_project_bus(pscad, get_name(b))  #Find the project where the component can be found
    write_initial_conditions(b, get_name(b), project, x0_dict)
end =#

#PRINT NAMES OF LINES IN PSCAD
for p in pscad.projects()
    project = pscad.project(p["name"])
    lines = project.find_all("master:newpi")
    for l in lines
        pscad_params = l.parameters()
        name  = pscad_params["Name"]
        #LOGIC FOR CHANGING LINE NAMES

        println(name)
    end 
end 

#PRINT NAMES OF LINES IN PSID 
for l in get_components(Line, sys)
    println(get_name(l))
end 

function find_project_bus(pscad_workspace, component_name)
    project = nothing 
    for p in pscad_workspace.projects()
        project = pscad.project(p["name"])
        component = project.find("Bus", component_name)
        if typeof(component) !== Nothing
            return project 
        end  
    end 
    @error "Did not find component"
    return false 
end   


#TODO - made changes to the pscad system so that these two functions run and parameterize the entire system... 
    #parameterize_system(sys, project)
    #enable_dynamic_injection_by_type(sys, project)

