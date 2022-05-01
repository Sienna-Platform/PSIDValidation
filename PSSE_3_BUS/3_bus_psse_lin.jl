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

sim_alg = Simulation(
    MassMatrixModel,
    sys, #system
    "PSSE_3_BUS",
    (0.0, 20.0), #time span
    BranchTrip(1.0, Line, "BUS 1-BUS 3-i_1"); #Type of Fault
    console_level = Logging.Info
)

execute!(sim_alg, Rodas5P(), abstol = 1e-10)
results_alg = read_results(sim_alg)

psse_results = CSV.read("PSSE_3_BUS/line_101_104-1/results.csv", DataFrame, header = 2)
# Clean up PSSe results
hdr = names(psse_results)

# Terminal Voltage Comparison
ix = findall(x -> occursin("VOLT", x), hdr)
volt_psse = psse_results[!, [1, ix...]]


voltage_plots = []
for (ix, n) in enumerate(101:104)
    color = D3Colors[ix]
    x_alg, y_alg = get_voltage_magnitude_series(results_alg, n)
    # x_dyn, y_dyn = get_voltage_magnitude_series(results_dyn, n; dt = 0.005)
    volt_psse_gen = volt_psse[!, ix+1]
    psse_line = scatter(x = volt_psse[!, 1], y =volt_psse_gen, name = "PSSE", line_color = "black", line_dash = "dot")
    psid_line_alg = scatter(x = x_alg, y =y_alg, name = "PSID-QSP", line_color = color, line_dash = "dot")
    # psid_line_dyn = scatter(x = x_dyn, y =y_dyn, name = "PSID-EMT", line_color = color)
    push!(voltage_plots, plot([psid_line_alg,
                               # psid_line_dyn,
                               psse_line], Layout(;title="BUS-$n",
                                                            xaxis_title = "Time [s]",
                                                            yaxis_title = "Voltage [p.u.]",
                                                            )))
end

voltages = [voltage_plots[1] voltage_plots[2]
voltage_plots[3] voltage_plots[4]]

# Active Power Comparison
ix = findall(x -> occursin("POWR", x), hdr)
power_psse = psse_results[!, [1, ix...]]

power_plots = []
for (ix, n) in enumerate(["ND", "SG", "RG", "SH", "EG", "WG",])
    color = D3Colors[ix]
    x_alg, y_alg = get_activepower_series(results_alg, "generator-102-$(n)")
    power_psse_gen = power_psse[!, " POWR 102[BUS 2 LV 20.000]$n"]
    psse_line = scatter(x = power_psse[!, 1], y =power_psse_gen, name = "PSSE", line_color = "black", line_dash = "dot")
    psid_line_alg = scatter(x = x_alg, y =y_alg, name = "PSID-QSP", line_color = color, line_dash = "dot")
    push!(power_plots, plot([psid_line_alg,
                            # psid_line_dyn,
                            psse_line], Layout(;title="GEN-$n",
                                                            xaxis_title = "Time [s]",
                                                            yaxis_title = "Power [p.u.]",
                                                            )))
end

powers = [power_plots[1] power_plots[2]
power_plots[3] power_plots[4]
power_plots[5] power_plots[6]]

# Field Current Comparison
ix = findall(x -> occursin("IFD", x), hdr)
ifd_psse = psse_results[!, [1, ix...]]

ifd_plots = []
for (ix, n) in enumerate(["ND", "SG", "RG", "SH", "EG", "WG",])
    color = D3Colors[ix]
    x_alg, y_alg = get_field_current_series(results_alg, "generator-102-$(n)")
    ifd_psse_gen = ifd_psse[!, " IFD 102[BUS 2 LV 20.000]$n"]
    psse_line = scatter(x = ifd_psse[!, 1], y =ifd_psse_gen, name = "PSSE", line_color = "black", line_dash = "dot")
    psid_line_alg = scatter(x = x_alg, y =y_alg, name = "PSID-QSP", line_color = color, line_dash = "dot")
    push!(ifd_plots, plot([psid_line_alg,
                            # psid_line_dyn,
                            psse_line], Layout(;title="GEN-$n",
                                                            xaxis_title = "Time [s]",
                                                            yaxis_title = "Field Current [p.u.]",
                                                            )))
end

ifd = [ifd_plots[1] ifd_plots[2]
ifd_plots[3] ifd_plots[4]
ifd_plots[5] ifd_plots[6]]
