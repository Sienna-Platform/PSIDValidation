#@testset "test_gen_droop" begin

#DEVICE OPTIONS FORE EACH BUS  
#Source (inifinite bus): "ib"
#Inverters:  "vsm", "droop", "gfl"
#Sync Gens: "fixed_sauerpai", "fixed_classic" 
    #GasTG:  "sauerpai_sexs_gastg_ieeest", "sauerpai_sexs_gastg_fixed"
    #HyGov:  "sauerpai_sexs_hygov_ieeest", "sauerpai_sexs_hygov_fixed"
    #TGOV1:  "sauerpai_sexs_tgov1_ieeest", "sauerpai_sexs_tgov1_fixed"     
##
sys, result_psid = run_3bus_psid(
    rawfile = "ThreeBusPSCAD.raw",
    perturbation_type = "LoadStepDown",    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]
    line_to_trip = "BUS 1-BUS 2-i_1",
    line_type = "Dynamic",
    bus_1_device = "sauerpai_sexs_tgov1_fixed",       #fixed_classic
    bus_2_device = "gfl",
    saveat = 5e-4,
    tspan = (0.0, 10.0),
    ref_bus_number = 101,
    frequency_reference = "ReferenceBus", #["ConstantFrequency, "ConstantFrequency"]
    solver = "Rodas5",
    abstol = 1e-14,
)

#TODO - SEE WHAT THE DAMPING LOOKS LIKE FOR THESE SYSTEMS (Change D of shaft and see)
#summary_participation_factors
#summary_eigenvalues

P1 = get_activepower_series(result_psid, "generator-101-1")
P2 = get_activepower_series( result_psid , "generator-102-1")
omega = get_frequency_series(result_psid, "generator-101-1")
p = plot()
plot!(p, omega)
plot!(p, P1, label = "P - gastg", title = "Load Step with different gens")
#plot!(p, P2, label = "P2")  

#p3 = plot(omega, label = "gastg")
#plot!(p3, omega, label = "tgov1")



record_3bus_psid(
    result_psid;
    recorded_voltages = [101, 102, 103],   # Bus numbers to record voltage  
    recorded_states = [
                    #   ("generator-101-1", :ω),
                    #   ("generator-102-1", :ω_oc),
                       ], 
    recorded_P = [ "generator-101-1", "generator-102-1"],
    recorded_Q = ["generator-102-1"],
    recorded_ω = ["generator-101-1", "generator-102-1"],
    output_csv_name = "psid_output",
)

run_3bus_pscad(
    sys;
    t_GEN = 2.0, #release time for generators 
    t_INV = 2.0, #release time for inverters 
    perturbation_type = "LoadStepDown",  #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
    pscad_workspace = "workspace_3bus.pswx",
    pscad_case = "case_3bus",           #the pscad case corresponding to the psid test
    t_offset = 20.0,                    #only collect data starting at t_offset
    saveat = 5e-4,
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
    0.0,
    10.0,
    20.0,
    "V_101",
    "V_101";
    display_plot = true,
)

inf_norm, two_norm = compare_traces(
    pscad_result,
    psid_result,
    0.0,
    10.0,
    20.0,
    "P_101",
    "P_generator-101-1";
    display_plot = true,
)
#@test inf_norm <= 0.02    
#@test two_norm <= 0.22

inf_norm, two_norm = compare_traces(
    pscad_result,
    psid_result,
    0.0,
    10.0,
    20.0,
    "f_out_102",
    "ω_generator-102-1";
    display_plot = true,
)
#@test inf_norm <= 0.02
#@test two_norm <= 0.22
