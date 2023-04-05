using Revise
using PowerSystems
using PowerSimulationsDynamics
using Sundials
using PlotlyJS
using PowerFlows
using Logging
using DataFrames
using CSV
using OrdinaryDiffEq

const PSID = PowerSimulationsDynamics
const PSY = PowerSystems

## Params
tspan=(0.0, 5.0) # Time duration of simualtion (Not-ML)
tripTime = 0.1

# Build System
sys = System("/Users/jlara/cache/PSIDValidation/PSCAD_144_BUS_EMT/psid_files/144Bus.json")

genTrip = GeneratorTrip(tripTime, PSY.get_component(PSY.DynamicInverter, sys, "GFM_Battery_31"))

sim = Simulation(
        MassMatrixModel,
        sys,
        pwd(),
        tspan,
        genTrip,
        all_branches_dynamic = true,
    )

    # Run Small Signal Analysis
sm = small_signal_analysis(sim)

# Show eigenvalue statistics
summary_eigenvalues(sm)


# Run Perturbation
execute!(sim, Rodas5P())
results = read_results(sim)

pscad_results = CSV.read("/Users/jlara/cache/PSIDValidation/PSCAD_144_BUS_EMT/PSCAD_144bus_results/GFM_Battery_31/GFM_Battery_31.csv", DataFrame)
t, voltage = get_voltage_magnitude_series(results, 125)
t, freq = get_state_series(results, ("generator-93-1", :ω))

p1 = scatter(x = pscad_results[!, :time], y = pscad_results[!, :f_generator_93_1], name = "PSCAD")
p2 = scatter(x = t, y = freq, name = "PSID")
plot([p1, p2])


traces = GenericTrace{Dict{Symbol, Any}}[]
for i in get_number.(get_components(Bus, sys))
    p1 = scatter(x = pscad_results[!, :time], y = pscad_results[!, "v_Bus_$i"], name = "PSCAD_v_$i")
    t, voltage = get_voltage_magnitude_series(results, i)
    p2 = scatter(x = t, y = voltage, name = "PSID_v_$i")
    push!(traces, p1, p2)
end
plot(traces)

i = 72
