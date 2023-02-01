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

function run_3bus_pscad(
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

    ########################################################################################
    #Generic Parameterization Based on PSID System (should run this function for every case)
    ########################################################################################
    bus_coordinates = Dict{String, Tuple{Int64, Int64}}("bus_name" => (1,2))
    #build_pscad_network(sys::System, bus_coordinates)
    enable_dynamic_injection_by_type(sys, project)
    parameterize_system(sys, project)

    ########################################################################################
    #Special Parameterizations for this particular system/study
    ########################################################################################
    PP.update_parameter_by_name(project.find("t_INV_constant"), "Value", t_INV)
    PP.update_parameter_by_name(project.find("t_GEN_constant"), "Value", t_GEN)
    if perturbation_type == "LoadStepDown"
        PP.update_parameter_by_name(project.find("t_LoadStepDownConstant"), "Value", t_offset + 0.1)
        PP.update_parameter_by_name(project.find("t_LoadStepUpConstant"), "Value", 100.0)
        PP.update_parameter_by_name(project.find("t_LineTripConstant"), "Value", 100.0)
    elseif perturbation_type == "LoadStepUp"
        PP.update_parameter_by_name(project.find("t_LoadStepDownConstant"), "Value", 100.0)
        PP.update_parameter_by_name(project.find("t_LoadStepUpConstant"), "Value", t_offset + 0.1)
        PP.update_parameter_by_name(project.find("t_LineTripConstant"), "Value", 100.0)
    elseif perturbation_type == "LineTrip"
        PP.update_parameter_by_name(project.find("t_LoadStepDownConstant"), "Value", 100.0)
        PP.update_parameter_by_name(project.find("t_LoadStepUpConstant"), "Value", 100.0)
        PP.update_parameter_by_name(project.find("t_LineTripConstant"), "Value",  t_offset + 0.1)
    else
        @error "Provided perturbation not found!"
    end

    #See https://www.pscad.com/webhelp-v5-al/reference/project.html#properties for additional keywords
    set_project_parameters!(
        project;
        time_duration = t_span[2] + t_offset,
        sample_step = saveat * 1e6,
        time_step = time_step * 1e6,
    )
    @warn pscad_output_folder_path

    ##
    #Run PSCAD, quit when finished, and shutdown logging 
    project.run()
    #pscad.quit()
    #logging.shutdown()

    #Collect pscad outputs and write as dataframe to csv
    df1 = collect_pscad_outputs(pscad_output_folder_path)[1]
    df_filt = df1[df1[!, :time] .>= t_offset, :]
    open(
        joinpath(@__DIR__, "..", "pscad_files", string(output_csv_name, ".csv")),
        "w",
    ) do io
        CSV.write(io, df_filt)
    end
end

#run_3bus_pscad(sys)
