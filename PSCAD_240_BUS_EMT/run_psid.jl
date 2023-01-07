using Revise
using Logging
using OrdinaryDiffEq
using PowerSystems
using PowerSimulationsDynamics
using Plots
using DataFrames
using Sundials
using CSV
using PowerFlows
const PSY = PowerSystems

configure_logging(console_level = Logging.Error)
include("modifiy_system.jl")
system = System(joinpath(@__DIR__, "psid_files", "system.json"))

sim_ref = Simulation(
        MassMatrixModel,
        system,
        "PSCAD_240_BUS_EMT",
        (0.0, 20.0);
        file_level = Logging.Error,
        console_level = Logging.Error,
        #all_lines_dynamic = true,
        )

ss = small_signal_analysis(sim_ref)

df_pf = summary_participation_factors(ss)
df_ei = summary_eigenvalues(ss)

eig_state_map = Dict(1:length(ss.eigenvalues) .=> [("gen", :state, -1.0)])

for state_ix in 1:length(ss.eigenvalues)
    for (device, states) in ss.participation_factors
        for (state, factors) in states
            val = factors[state_ix]
            if eig_state_map[state_ix][3] <= val
                eig_state_map[state_ix] = (device, state, val)
            elseif eig_state_map[state_ix][3] == -1
                val, state_ix
            end
        end
    end
end

bus_eig = Dict()
for i in findall(x -> real(x) > -0.1, ss.eigenvalues)
    bus_no = split(eig_state_map[i][1], "-")[2]
    if haskey(bus_eig, bus_no)
        push!(bus_eig[bus_no], eig_state_map[i])
    else
        bus_eig[bus_no] = [eig_state_map[i]]
    end
    println("state $i with λ=$(ss.eigenvalues[i]) has $(eig_state_map[i])")
end

eig_state_map = Dict()
for (device, states) in ss.participation_factors
    for (state, factors) in states
        val = factors[end-2]
        eig_state_map[(device, state)] = val
    end
end

eigs_sorted = sort(collect(eig_state_map), by = x->x[2])
