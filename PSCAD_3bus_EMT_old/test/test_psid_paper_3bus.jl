#@testset "psid_paper_3bus" begin

    sys, result_psid = run_3bus_psid(
        rawfile = "ThreeBusPSCAD.raw",
        perturbation_type = "LineTrip",    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]
        line_to_trip = "Bus_1-Bus_2-i_1", 
        line_type = "Dynamic",
        bus_1_device = "vsm",
        bus_2_device = "droop",
        saveat = 5e-5,
        tspan = (0.0, 10.0),
        ref_bus_number = 101,
        frequency_reference = "ReferenceBus", #["ConstantFrequency, "ConstantFrequency"]
        solver = "Rodas5",
        abstol = 1e-14,
    )
    record_3bus_psid(
        result_psid;
        recorded_voltages = [101, 102, 103],   # Bus numbers to record voltage  
        recorded_states = [("generator-101-1", :θ_pll),
                        ("generator-101-1", :ε_pll),
                        ("generator-101-1", :vq_pll),
                        ("generator-101-1", :vd_pll),
                        ("generator-101-1", :ω_oc),
                        ("generator-101-1", :θ_oc) 
                        ], 
        recorded_P = ["generator-102-1"],
        recorded_Q = ["generator-102-1"],
        recorded_ω = ["generator-102-1"],
        output_csv_name = "psid_output",
    )
    run_3bus_pscad(
        sys;
        t_GEN = 2.0, #release time for generators 
        t_INV = 5.0, #release time for inverters 
        perturbation_type = "LineTrip",  #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
        pscad_workspace = "workspace_3bus.pswx",
        pscad_case = "case_3bus",           #the pscad case corresponding to the psid test
        t_offset = 10.0000000001,                    #only collect data starting at t_offset
        saveat = 5e-5,
        time_step = 5e-6,
        t_span = (0.0, 10.0),
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
        0.09,
        0.11,
        10.0,
        "P_102",
        "P_generator-102-1";
        display_plot = true,
    )
    @test inf_norm <= 0.003    
    @test two_norm <= 0.018

    inf_norm, two_norm = compare_traces(
        pscad_result,
        psid_result,
        0.0,
        2.0,
        10.0,
        "f_out_102",
        "ω_generator-102-1";
        display_plot = true,
    )
    @test inf_norm <= 3e-6
    @test two_norm <= 8e-5
#end 