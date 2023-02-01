#@testset "psid_fixedsauerpai_gfl_3bus" begin
    sys, result_psid = run_3bus_psid(
        rawfile = "ThreeBusPSCAD.raw",
        perturbation_type = "LoadStepDown",    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]
        line_to_trip = "BUS 1-BUS 2-i_1",
        line_type = "Dynamic",
        bus_1_device = "fixed_sauerpai",       #fixed_classic
        bus_2_device = "gfl",
        saveat = 5e-5,
        tspan = (0.0, 5.0),
        ref_bus_number = 101,
        frequency_reference = "ReferenceBus", #["ConstantFrequency, "ConstantFrequency"]
        solver = "Rodas5",
        abstol = 1e-14,
    )

    record_3bus_psid(
        result_psid;
        recorded_voltages = [101, 102, 103],   # Bus numbers to record voltage  
        recorded_states = [
                        ], 
        recorded_P = [ "generator-102-1"],
        recorded_Q = ["generator-102-1"],
        recorded_ω = ["generator-102-1"],
        output_csv_name = "psid_output",
    )

    run_3bus_pscad(
        sys;
        t_GEN = 2.0, #release time for generators 
        t_INV = 5.0, #release time for inverters 
        perturbation_type = "LoadStepDown",  #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
        pscad_workspace = "workspace_3bus.pswx",
        pscad_case = "case_3bus",           #the pscad case corresponding to the psid test
        t_offset = 10.0,                    #only collect data starting at t_offset
        saveat = 5e-5,
        time_step = 5e-6,
        t_span = (0.0, 5.0),
        output_csv_name = "pscad_output",
    ) 


    psid_result = read_csv_file_to_dataframe(
        joinpath(pwd(), "PSCAD_3bus_EMT", "psid_files", "psid_output.csv"),
    )
    pscad_result = read_csv_file_to_dataframe(
        joinpath(pwd(), "PSCAD_3bus_EMT", "pscad_files", "pscad_output.csv"),
    )

    inf_norm, two_norm = compare_traces(
        pscad_result,
        psid_result,
        1.615,
        1.635,
        10.0,
        "P_102",
        "P_generator-102-1";
        display_plot = true,
    )
    @test inf_norm <= 0.02    
    @test two_norm <= 0.22

    inf_norm, two_norm = compare_traces(
        pscad_result,
        psid_result,
        1.615,
        1.635,
        10.0,
        "f_out_102",
        "ω_generator-102-1";
        display_plot = true,
    )
    @test inf_norm <= 0.02
    @test two_norm <= 0.22
#end 