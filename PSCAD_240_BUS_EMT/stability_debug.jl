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
using Logging
const PSY = PowerSystems

configure_logging(console_level = Logging.Error)
include("debug_utils.jl")
include("modifiy_system.jl")
sys = exchange_device("generator-2203-DP-gfl")

sim_ref = Simulation(
        MassMatrixModel,
        sys,
        "PSCAD_240_BUS_EMT",
        (0.0, 20.0);
        file_level = Logging.Error,
        console_level = Logging.Error
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

for i in findall(x -> real(x) > -Inf, ss.eigenvalues)
    println("state $i with λ=$(ss.eigenvalues[i]) has $(eig_state_map[i])")
end

sim_ref = Simulation(
        MassMatrixModel,
        sys,
        "PSCAD_240_BUS_EMT",
        (0.0, 20.0),
        BranchTrip(1.0, Line, "BUS 1-BUS 3-i_1");
        file_level = Logging.Error,
        console_level = Logging.Error
        )

execute!(sim_ref, Rodas5P(), abstol = 1e-10)
results_ref = read_results(sim_ref)

t, v = get_voltage_magnitude_series(results_ref, 103)
plot(t, v)


include("debug_utils.jl")
include("modifiy_system.jl")
sys = exchange_device_ib("generator-2203-DP-gfl")

sim_ref = Simulation(
        MassMatrixModel,
        sys,
        "PSCAD_240_BUS_EMT",
        (0.0, 20.0);
        file_level = Logging.Error,
        console_level = Logging.Error
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

for i in findall(x -> real(x) > -Inf, ss.eigenvalues)
    println("state $i with λ=$(ss.eigenvalues[i]) has $(eig_state_map[i])")
end

sim_ref = Simulation(
        MassMatrixModel,
        sys,
        "PSCAD_240_BUS_EMT",
        (0.0, 20.0),
        BranchTrip(1.0, Line, "BUS 1-BUS 3-i_1");
        file_level = Logging.Error,
        console_level = Logging.Error
        )

execute!(sim_ref, Rodas5P(), abstol = 1e-10)
results_ref = read_results(sim_ref)

t, v = get_voltage_magnitude_series(results_ref, 103)
plot(t, v)
