using Test
using Revise
import LinearAlgebra
using Conda
using Pkg
using PyCall
using PowerSystems
using PowerSimulationsDynamics
using PowerFlows

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
sleep(5)    #Need to wait for the last closed workspace to load and then load the one below
pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace)))

#project = pscad.project(pscad_case)
sim = Simulation!(MassMatrixModel, sys, pwd(), (0.0, 0.0))
ss = small_signal_analysis(sim)
@warn ss.stable
x0_dict = read_initial_conditions(sim)
setpoints_dict = get_setpoints(sim)
buses = collect(get_components(Bus, sys))

function find_project_component(pscad_workspace, component_name)
    project = nothing 
    for p in pscad_workspace.projects()
        project = pscad.project(p["name"])
        component = project.find(component_name)
        if typeof(component) !== Nothing
            return project 
        end  
    end 
    @error "Did not find component"
    return false 
end 

#REMOVES _1 and _2 FROM BUS NAMES 
#= 
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

#RENAME PSCAD LINES TO MATCH PSID (INCLUDES LINES NAMES "TL_")
#=  ix = 0 
for p in pscad.projects() 
    if p["name"] !=="master"    #excludes Master library 
        project = pscad.project(p["name"])
        lines = project.find_all("master:newpi")
        for l in lines
            pscad_params = l.parameters()
            name  = pscad_params["Name"]
            if startswith(name, "TL")
                name_without_spaces = replace(name, " "=> "") #Split up the old names
                name_components = split(name_without_spaces, "_")
                @assert length(name_components) == 4 
                @assert length(collect(get_components(Bus, sys, x-> contains(get_name(x), name_components[2])))) == 1 
                @assert length(collect(get_components(Bus, sys, x-> contains(get_name(x), name_components[3])))) == 1 
                psid_from_bus_name = get_name(collect(get_components(Bus, sys, x-> contains(get_name(x), name_components[2])))[1])
                psid_to_bus_name = get_name(collect(get_components(Bus, sys, x-> contains(get_name(x), name_components[3])))[1]) 
                new_line_name = psid_from_bus_name * "-" * psid_to_bus_name * "-i_" * name_components[4]
            else 
                newname = replace(name, "." => "_", " " => "_")
                newname = split(newname, "-")
                if length(newname) == 5 
                    new_line_name = "B" * newname[2] * "_" * newname[1] * "-" * "B" * newname[4] * "_" * newname[3] * "-" *newname[5]
                else
                    new_line_name = name
                end 
            end 
            ix += 1 
            println(ix, "\told name: \t ", name, "\tnew name:\t", new_line_name)
            psid_line = get_component(Line, sys, new_line_name)
            @assert psid_line !== nothing 
            pscad_params["Name"] = new_line_name
            PP.update_parameter_by_dictionary(l, pscad_params)
        end 
    end
end =# 

#Find all multimeters, replace the "B" with "M" such that we don't have repeated component names. 
#= ix = 0 
for p in pscad.projects()
    if p["name"] == "WECC_Components" || p["name"] == "case_240bus"
        project = pscad.project(p["name"])
        buses = project.find_all("master:multimeter")
        println(pscad.project(p["name"]))
        for b in buses
            pscad_params = b.parameters()
            name  = pscad_params["Name"]
            new_name = "M" * chop(name, head = 1, tail = 0)
            ix += 1 
            println(ix, "\told name: \t ", name, "\tnew name:\t", new_name)
            pscad_params["Name"] = new_name
            PP.update_parameter_by_dictionary(b, pscad_params)
        end 
    end 
end   =#

#Find all xnode, replace the "B" with "X" such that we don't have repeated component names. 
#= ix = 0 
for p in pscad.projects()
    if p["name"] == "WECC_Components" || p["name"] == "case_240bus"
        project = pscad.project(p["name"])
        buses = project.find_all("master:xnode")
        println(pscad.project(p["name"]))
        for b in buses
            pscad_params = b.parameters()
            name  = pscad_params["Name"]
            new_name = "X" * chop(name, head = 1, tail = 0)
            ix += 1 
            println(ix, "\told name: \t ", name, "\tnew name:\t", new_name)
            pscad_params["Name"] = new_name
            PP.update_parameter_by_dictionary(b, pscad_params)
        end 
    end 
end  =#

component_types = [Bus, Line]  #TODO - once the transformers are named correctly, add Transformer2W to this list and make sure they get parameterized 
components = collect(get_components(Component, sys, x -> typeof(x) in component_types))
for (ix,c) in enumerate(components)
    println(ix, "\t", get_name(c))
    project = find_project_component(pscad, get_name(c)) 
    write_parameters(c, get_name(c), project)
end


#USEFUL CODE FOR FINDING THE COMPONENTS IN PSID THAT HAVE SOME SUBSTRING IN THEIR NAME
#= for g in get_components(Line, sys, x-> contains(get_name(x), "MESA"))
    println(get_name(g))
end =#

#WRITE INITIAL CONDITIONS FOR BUSES (WORKING)
#=for (ix,b) in enumerate(collect(buses))
    project = find_project_component(pscad, get_name(b))  #Find the project where the component can be found
    write_initial_conditions(b, get_name(b), project, x0_dict)
end =#

#TODO - made changes to the pscad system so that these two functions run and parameterize the entire system... 
    #parameterize_system(sys, project)
    #enable_dynamic_injection_by_type(sys, project)

