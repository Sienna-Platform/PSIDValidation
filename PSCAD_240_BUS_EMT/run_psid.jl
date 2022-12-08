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

system = System(joinpath(@__DIR__, "psid_files", "system.json"))
run_powerflow!(system)

th = get_dynamic_injector(get_component(ThermalStandard, system, "generator-1431-N"))

sim_ref = Simulation(
        MassMatrixModel,
        system,
        "PSCAD_240_BUS_EMT",
        (0.0, 20.0),
        GeneratorTrip(1.0, th);
        file_level = Logging.Error,
        console_level = Logging.Debug
        )

ss = small_signal_analysis(sim_ref)
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

for i in findall(x -> real(x) > 0, ss.eigenvalues)
    @show eig_state_map[i]
end
