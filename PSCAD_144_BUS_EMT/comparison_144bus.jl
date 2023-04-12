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

# Params
tspan=(0.0, 20.0) # Time duration of simualtion (Not-ML)
tripTime = 20.0

# Build System
#sys = System(joinpath(pwd(), "PSCAD_144_BUS_EMT", "psid_files", "144bus.json"))
sys = System(joinpath(pwd(), "PSCAD_144_BUS_EMT", "psid_files", "9bus.json"))
#run_powerflow(sys)["flow_results"]
#genTrip = GeneratorTrip(tripTime, PSY.get_component(PSY.DynamicInverter, sys, "generator-2-1"))
#lineTrip = BranchTrip(tripTime, Line, "Bus_7-Bus_5-i_1" )
#g = get_component(DynamicInverter, sys, "GFL_Battery_2")
#crc = ControlReferenceChange(tripTime, g, :P_ref, 0.2)

sim = Simulation(
        MassMatrixModel,
        sys,
        pwd(),
        tspan,
       all_branches_dynamic = false,
    )

    # Run Small Signal Analysis
#sm = small_signal_analysis(sim)

# Show eigenvalue statistics summary_eigenvalues(sm)
# Run Perturbation
execute!(sim, Rodas5P())
results = read_results(sim)

pscad_results = CSV.read(joinpath(pwd(), "PSCAD_144_BUS_EMT", "results",  "GFL_Battery_2.csv"), DataFrame) #  /Users/jlara/cache/PSIDValidation/PSCAD_144_BUS_EMT/PSCAD_144bus_results/GFM_Battery_31/", DataFrame)

p1 = PlotlyJS.scatter()
traces = GenericTrace{Dict{Symbol, Any}}[]
for i in get_number.(get_components(Bus, sys))
    p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "v_Bus_$i"], name = "PSCAD_v_$i")
    t, voltage = get_voltage_magnitude_series(results, i)
    p2 = PlotlyJS.scatter(x = t, y = voltage, name = "PSID_v_$i")
    push!(traces, p1, p2)
end
PlotlyJS.plot(traces)

include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion","simulation_extras.jl"))
traces = GenericTrace{Dict{Symbol, Any}}[]
for d in get_components(DynamicInjection, sys)
    scale_pscad = get_base_power(d) /100.0
    psid_name = get_name(d)
    pscad_name =  pscad_compat_name(psid_name)
    p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y = scale_pscad .* pscad_results[!, "P_$pscad_name"], name = "PSCAD_$pscad_name")
    t, P = get_activepower_series(results, psid_name)
    p2 = PlotlyJS.scatter(x = t, y = P, name = "P_$psid_name")
    push!(traces, p1, p2)
end
PlotlyJS.plot(traces)

traces = GenericTrace{Dict{Symbol, Any}}[]
for d in get_components(DynamicInjection, sys)
    scale_pscad = get_base_power(d) /100.0
    scale_psid = 100.0/get_base_power(d)
    psid_name = get_name(d)
    pscad_name =  pscad_compat_name(psid_name)
    p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y =  pscad_results[!, "Q_$pscad_name"], name = "PSCAD_$pscad_name")
    t, P = get_reactivepower_series(results, psid_name)
    p2 = PlotlyJS.scatter(x = t, y = P .* scale_psid, name = "Q_$psid_name")
    push!(traces, p1, p2)
end
PlotlyJS.plot(traces)

traces = GenericTrace{Dict{Symbol, Any}}[]
for d in get_components(DynamicInjection, sys)
    if typeof(d) !== DynamicInverter{AverageConverter, OuterControl{ActivePowerPI, ReactivePowerPI}, CurrentModeControl, FixedDCSource, KauraPLL, LCLFilter}
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y =  pscad_results[!, "f_$pscad_name"], name = "PSCAD_$pscad_name")
        t, f = get_frequency_series(results, psid_name)
        p2 = PlotlyJS.scatter(x = t, y = f, name = "f_$psid_name")
        push!(traces, p1, p2)
    end 
end
PlotlyJS.plot(traces)
