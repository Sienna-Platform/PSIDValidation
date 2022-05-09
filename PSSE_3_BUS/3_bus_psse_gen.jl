using Revise
using PowerSystems
using PowerSimulationsDynamics
using Logging
using OrdinaryDiffEq
using PlotlyJS
templates.default = "plotly_white"
using CSV
using DataFrames
include("../utils.jl")

# Load system data
sys = System("PSSE_3_BUS/FourBusMulti.raw", "PSSE_3_BUS/FourBus_multigen.dyr"; runchecks = false)

# Convert Loads to constant impedance
for l in get_components(PowerLoad, sys)
    set_model!(l, LoadModels.ConstantImpedance)
end

dc = get_dynamic_injector(get_component(ThermalStandard, sys, "generator-102-SW"))
sim_alg = Simulation(
    MassMatrixModel,
    sys, #system
    "PSSE_3_BUS",
    (0.0, 20.0), #time span
    GeneratorTrip(1.0, dc);
    console_level = Logging.Info
)

execute!(sim_alg, Rodas5P(), abstol = 1e-10)
results_alg = read_results(sim_alg)

psse_results = CSV.read("PSSE_3_BUS/generator-102-SW__BUS 2 LV/results.csv", DataFrame, header = 2)
# Clean up PSSe results
hdr = names(psse_results)

# Speed comparison
ix = findall(x -> occursin("SPD", x), hdr)
ω_psse = psse_results[!, [1, ix...]]
speed_traces = GenericTrace{Dict{Symbol, Any}}[]
speed_plots = []
for (ix, n) in enumerate(["ND", "SG", "RG", "SH", "EG", "WG",])
    color = D3Colors[ix]
    x_alg, y_alg = get_state_series(results_alg, ("generator-102-$(n)", :ω))
    # x_dyn, y_dyn = get_state_series(results_dyn, ("generator-102-$(n)", :ω))
    ω_psse_gen = ω_psse[!, " SPD 102[BUS 2 LV 20.000]$n"] .+ 1.0
    psse_line = scatter(x = ω_psse[!, 1], y =ω_psse_gen, name = "PSS/e", line_color = "black", line_dash = "dot", line_width = 0.7)
    psid_line_alg = scatter(x = x_alg, y =y_alg, name = "PSID-QSP-GEN-$n", line_color = color)
    # psid_line_dyn = scatter(x = x_dyn, y =y_dyn, name = "PSID-EMT", line_color = color)
    if ix < 2
        push!(speed_traces, [psid_line_alg, psse_line]...)
    else
        push!(speed_traces, psid_line_alg)
    end
    p = plot([psid_line_alg, psse_line], Layout(;title="GEN-$n",
                                                            xaxis_title = "Time [s]",
                                                            yaxis_title = "Speed [p.u.]",
                                                            ))
    savefig(p, "psse_speed_$ix.pdf"; height = 400, width = 600)
    push!(speed_plots, p)
end
p = plot(speed_traces, Layout(;xaxis_title = "Time [s]",
                            yaxis_title = "Speed [p.u.]",
                                                            ))

savefig(p, "psse_speed_all.pdf"; height = 400, width = 600)

speeds = [speed_plots[1] speed_plots[2]
speed_plots[3] speed_plots[4]
speed_plots[5] speed_plots[6]]


# Terminal Voltage Comparison
ix = findall(x -> occursin("VOLT", x), hdr)
volt_psse = psse_results[!, [1, ix...]]

voltage_plots = []
voltage_traces = GenericTrace{Dict{Symbol, Any}}[]
for (ix, n) in enumerate(101:104)
    color = D3Colors[ix]
    x_alg, y_alg = get_voltage_magnitude_series(results_alg, n)
    volt_psse_gen = volt_psse[!, ix+1]
    psse_line = scatter(x = volt_psse[!, 1], y =volt_psse_gen, name = "PSS/e-Bus-$n", line_color = "black", line_dash = "dot", line_width = 0.7)
    psid_line_alg = scatter(x = x_alg, y =y_alg, name = "PSID-QSP-Bus-$n", line_color = color)
    push!(voltage_traces, [psid_line_alg, psse_line]...)
    p = plot([psid_line_alg, psse_line], Layout(;title="BUS-$n",
                                                xaxis_title = "Time [s]",
                                                yaxis_title = "Voltage [p.u.]"))
    savefig(p, "psse_volt_line_trip_$ix.pdf"; height = 400, width = 600)
    push!(voltage_plots, p)
end

p = plot(voltage_traces, Layout(xaxis_title = "Time [s]", yaxis_title = "Voltage [p.u.]"))
savefig(p, "psse_volt_gen_trip_all_buses.pdf"; height = 400, width = 600)
voltages = [voltage_plots[1] voltage_plots[2]
voltage_plots[3] voltage_plots[4]]


# Active Power Comparison
ix = findall(x -> occursin("POWR", x), hdr)
power_psse = psse_results[!, [1, ix...]]


power_plots = []
power_traces = GenericTrace{Dict{Symbol, Any}}[]
color = D3Colors[1]
x_alg, y_alg = get_activepower_series(results_alg, "generator-101-1")
power_psse_gen = power_psse[!, " POWR 101[BUS 1 230.00]1"]
psse_line = scatter(x = power_psse[!, 1], y =power_psse_gen, name = "PSS/e", line_color = "black", line_dash = "dot")
psid_line_alg = scatter(x = x_alg, y =y_alg, name = "PSID-QSP-Bus1", line_color = color)
push!(power_traces, [psid_line_alg, psse_line]...)
push!(power_plots, plot([psid_line_alg,
                        psse_line], Layout(;title="GEN-101",
                                                        xaxis_title = "Time [s]",
                                                        yaxis_title = "Power [p.u.]",
                                                        )))

for (ix, n) in enumerate(["SG", "RG", "SH", "EG", "WG",])
    color = D3Colors[ix + 1]
    x_alg, y_alg = get_activepower_series(results_alg, "generator-102-$(n)")
    power_psse_gen = power_psse[!, " POWR 102[BUS 2 LV 20.000]$n"]
    psse_line = scatter(x = power_psse[!, 1], y =power_psse_gen, name = "PSS/e", line_color = "black", line_dash = "dot")
    psid_line_alg = scatter(x = x_alg, y =y_alg, name = "PSID-QSP-$n", line_color = color)
    push!(power_traces, [psid_line_alg, psse_line]...)
    push!(power_plots, plot([psid_line_alg,
                            psse_line], Layout(;title="GEN-102-$n",
                                                            xaxis_title = "Time [s]",
                                                            yaxis_title = "Power [p.u.]",
                                                            )))
end

p = plot(power_traces, Layout(xaxis_title = "Time [s]", yaxis_title = "Power [p.u.]"))
savefig(p, "psse_power_gen_trip_all_gens.pdf"; height = 400, width = 600)


powers = [power_plots[1] power_plots[2]
power_plots[3] power_plots[4]
power_plots[5] power_plots[6]]
