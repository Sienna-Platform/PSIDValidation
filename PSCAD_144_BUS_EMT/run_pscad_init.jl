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
pscad_case_name = "case_9bus"
output_csv_filename = "9bus.csv"
build_from_scratch = true  
sample_step =  5.0e-3 * 1e6
time_step = 20e-6 * 1e6
time_duration = 10.0
t_inv = 2.0
t_gen = 2.0
save_snapshot = 1 # 0: no snapshot, 1: single snapshot, 2: multiple snapshots (same file), 3:  multiple snapshots (separate files)  
save_snapshot_name = "snap_9bus_10s"
save_snapshot_time = 10.0    #if saving one snapshot, occurs at this time. If multiple, this is the interval between saves 
load_snapshot = false   
load_snapshot_name = "snap_ss_19s"
load_snapshot_path  = joinpath(@__DIR__, "pscad_files", string(pscad_case_name, ".gf46"), string(load_snapshot_name, ".snp"))

############################################################################################
############################################################################################

if build_from_scratch 
    include(joinpath(@__DIR__, "psid_files", "bus_details.jl")) #define bus_coords_144 
    pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))
    project =
        pscad.create_project(1, pscad_case_name, PyObject(joinpath(@__DIR__, "pscad_files"))) #create new project (1 for case, 2 for library)
    canvas = project.canvas("Main")
    set_project_parameters!(canvas; size = "100X100")
    set_project_parameters!(project; PlotType = "OUT")
    for c in canvas.find_all()
        canvas.delete(c)
    end 
    build_system(
        sys,
        project,
        bus_coords_9;
        add_gen_breakers = true,
        add_load_breakers = true,
        add_line_breakers = true,
        add_multimeters = true,
    )
    project.save()
    parameterize_system(sys, project) 
    project.save()
    quantities_to_record = Tuple{Symbol, String}[]

    buses = collect(get_components(Bus, sys))
    for b in buses
        push!(quantities_to_record,(:v, get_name(b)))
        push!(quantities_to_record,(:ph, get_name(b))) 
    end
    for g in collect(get_components(DynamicInjection, sys))
        push!(quantities_to_record, (:f, pscad_compat_name(get_name(g))))
        push!(quantities_to_record, (:P, pscad_compat_name(get_name(g))))
        push!(quantities_to_record, (:Q, pscad_compat_name(get_name(g))))
    end 
    setup_output_channnels(project, quantities_to_record, (15, 2)) 
    project.save()   
end 

pscad.load(PyObject(joinpath(@__DIR__, "pscad_files", pscad_workspace_name)))  
project = pscad.project(pscad_case_name)

PP.update_parameter_by_name(project.find("master:const", "t_INV"), "Value", t_inv)
PP.update_parameter_by_name(project.find("master:const", "t_GEN"), "Value", t_gen)
PP.update_parameter_by_name(project.find("master:const", "t_RAMP"), "Value", 0.1)

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

pscad_output_folder_path = joinpath(@__DIR__, "pscad_files", string(pscad_case_name, ".gf46"))

if isdir(pscad_output_folder_path)
    foreach(rm, filter(!endswith(".snp") , readdir(pscad_output_folder_path,join=true))) #Don't delete snapshot file.
end 
sim_time = @timed project.run()

save_directory = joinpath(@__DIR__, "results", "initialization")
mkpath(save_directory)

df = collect_pscad_outputs(pscad_output_folder_path)[1]  
open(joinpath(save_directory, output_csv_filename), "w") do io
    CSV.write(io, df)
end
pscad.release_all_certificates() 
pscad.quit()    
logging.shutdown()

#= df = CSV.read(joinpath(@__DIR__, "results", "Bus_56-Bus_54-i_1", "Bus_56-Bus_54-i_1.csv"), DataFrame)
plotlyjs()
#Plot all voltage magnitudes
p = plot(size=(1000,1000), hovermode = :closest)
for signal_name in filter!(x-> (x !== "time") && contains(x, "v_") , names(df))
    plot!(p, df[1:end, "time"], df[1:end, signal_name], legend = false, label = replace(signal_name, "Generator" => "") )
end

#Plot all voltage phases
p = plot(size=(1000,1000))
for signal_name in filter!(x-> (x !== "time") && contains(x, "ph_") , names(df))
    plot!(p, df[1:end, "time"], df[1:end, signal_name], legend=false, label = signal_name) 
end

#Plot all P 
p = plot(size=(1000,1000))
for signal_name in filter!(x-> (x !== "time") && contains(x, "P_") , names(df))
    plot!(p, df[1:end, "time"], df[1:end, signal_name], legend=false, label = replace(replace(signal_name, "generator" => "gen"),  "Battery" => "bat"))
end

#Plot all Q
p = plot(size=(1000,1000))
for signal_name in filter!(x-> (x !== "time") && contains(x, "Q_") , names(df))
    plot!(p, df[1:end, "time"], df[1:end, signal_name], legend = false,label = replace(replace(signal_name, "generator" => "gen"),  "Battery" => "bat"))
end


p = plot(size=(1000,1000))
for signal_name in filter!(x-> (x !== "time") && contains(x, "f_GFL") , names(df))
    plot!(p, df[1:end, "time"], df[1:end, signal_name], legend = true, label = replace(replace(signal_name, "generator" => "gen"),  "Battery" => "bat"))
end =#