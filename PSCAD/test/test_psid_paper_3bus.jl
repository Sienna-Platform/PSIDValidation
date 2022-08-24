@testset "psid_paper_3bus_all_inverters" begin 
    include(joinpath(pwd(), "PSCAD", "case_psid_paper_3bus", "scripts", "build_system.jl"))
    include(joinpath(pwd(), "PSCAD", "case_psid_paper_3bus", "scripts", "run_psid.jl"))
    include(joinpath(pwd(), "PSCAD", "case_psid_paper_3bus", "scripts", "run_pscad.jl"))
    #include(joinpath(pwd(), "PSCAD", "case_psid_paper_3bus", "scripts", "plot_comparison.jl"))
    #TODO - add a test which numerically compares the result from PSID and PSCAD for dynamic lines case 
    @test true 
end 