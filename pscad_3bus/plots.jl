using CSV
using DataFrames
using PlotlyJS
templates.default = "plotly_white"

pscad_results = CSV.read("PSCAD_3BUS/data/pscad_outputs_LineTrip", DataFrame)
filter!(row -> row.time .>= 10, pscad_results)
pscad_results.time .-= 10.0

psid_results_dyn = CSV.read("PSCAD_3BUS/data/psid_outputs_LineTrip_Dynamic", DataFrame)
psid_results_alg = CSV.read("PSCAD_3BUS/data/psid_outputs_LineTrip_Algebraic", DataFrame)

plots = []
for p in ["V_101", "V_102", "V_103"]
    trace_pscad = scatter(x = pscad_results[!, 1], y = pscad_results[!, p], name = "PSCAD")
    trace_psid_d = scatter(x = psid_results_dyn[!, 1], y = psid_results_dyn[!, p], name = "Dynamic Lines")
    trace_psid_a = scatter(x = psid_results_alg[!, 1], y = psid_results_alg[!, p], name = "Algebraic Lines")
    p = plot([trace_pscad, trace_psid_d, trace_psid_a], Layout(title = "Voltage Bus $p", xaxis_range=[0.095, 0.15]))
    push!(plots, p)
end

[plots[1] plots[2]]

signals_map = Dict(
    "delta_theta_pll" => "generator-101-1θ_pll",
    "epsilon_pll" => "generator-101-1ε_pll",
    "v_q_pll" => "generator-101-1vq_pll",
    "v_d_pll" => "generator-101-1vd_pll",
    "w_olc" => "generator-101-1ω_oc",
    "delta_theta_olc" => "generator-102-1θ_oc"
)

signals_map = Dict(
    "delta_theta_pll" => "generator-101-1θ_pll",
    "epsilon_pll" => "generator-101-1ε_pll",
    "v_q_pll" => "generator-101-1vq_pll",
    "v_d_pll" => "generator-101-1vd_pll",
    "w_olc" => "generator-101-1ω_oc",
    "delta_theta_olc" => "generator-102-1θ_oc"
)

plots = []
for p in ["delta_theta_pll", "epsilon_pll", "v_q_pll", "v_d_pll", "w_olc", "delta_theta_olc"]
    psid_name = signals_map[p]
    trace_pscad = scatter(x = pscad_results[!, 1], y = pscad_results[!, p], name = "PSCAD")
    trace_psid_d = scatter(x = psid_results_dyn[!, 1], y = psid_results_dyn[!, psid_name], name = "Dynamic Lines")
    trace_psid_a = scatter(x = psid_results_alg[!, 1], y = psid_results_alg[!, psid_name], name = "Algebraic Lines")
    p = plot([trace_pscad, trace_psid_d, trace_psid_a], Layout(title = "$p", xaxis_range=[0.095, 0.15]))
    push!(plots, p)
end

[plots[1] plots[2]
plots[3] plots[4]
plots[5] plots[6]]
