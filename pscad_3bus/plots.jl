using CSV
using DataFrames
using PlotlyJS
templates.default = "plotly_white"
include("../utils.jl")

pscad_results = CSV.read("PSCAD_3BUS/data/pscad_outputs_LineTrip", DataFrame)
filter!(row -> row.time .>= 10, pscad_results)
pscad_results.time .-= 10.0

psid_results_dyn = CSV.read("PSCAD_3BUS/data/psid_outputs_LineTrip_Dynamic", DataFrame)
psid_results_alg = CSV.read("PSCAD_3BUS/data/psid_outputs_LineTrip_Algebraic", DataFrame)

plots = []
for (ix, p) in enumerate(["V_101", "V_102", "V_103"])
    trace_pscad = scatter(x = pscad_results[!, 1], y = pscad_results[!, p], name = "PSCAD", line_color = "black", line_dash = "dot")
    trace_psid_d = scatter(x = psid_results_dyn[!, 1], y = psid_results_dyn[!, p], name = "PSID - EMT", line_color = D3Colors[1])
    trace_psid_a = scatter(x = psid_results_alg[!, 1], y = psid_results_alg[!, p], name = "PSID - QSP", line_color = D3Colors[2])
    p = plot([trace_psid_d, trace_pscad, trace_psid_a], Layout(title = "Voltage Bus $ix",
                                                               xaxis_title = "Time [s]",
                                                               yaxis_title = "Voltage [p.u.]",
                                                               xaxis_range=[0.095, 0.12]))
    push!(plots, p)
    savefig(p, "pscad_voltages_$ix.pdf"; height = 400, width = 600)
end

p_v = [plots[1] plots[2]]

savefig(p_v, "pscad_voltages.pdf"; height = 500, width = 1300)

signals_map = Dict(
    "delta_theta_pll" => "generator-101-1θ_pll",
    "epsilon_pll" => "generator-101-1ε_pll",
    "v_q_pll" => "generator-101-1vq_pll",
    "v_d_pll" => "generator-101-1vd_pll",
    "w_olc" => "generator-101-1ω_oc",
    "delta_theta_olc" => "generator-102-1θ_oc"
)

signals_map = Dict(
    "delta_theta_pll" => "δθ\_{pll}   ",
    "epsilon_pll" => "generator-101-1ε_pll",
    "v_q_pll" => "generator-101-1vq_pll",
    "v_d_pll" => "generator-101-1vd_pll",
    "w_olc" => "generator-101-1ω_oc",
    "delta_theta_olc" => "generator-102-1θ_oc"
)

plots = []
for (ix, p) in enumerate(["delta_theta_pll", "epsilon_pll", "v_q_pll", "v_d_pll", "w_olc", "delta_theta_olc"])
    max_lim = occursin("delta", p) ? 0.25 : 0.12
    psid_name = signals_map[p]
    col = clamp(ix ÷ 2, 1, 2)
    row = ix - (col - 1) * 3
    trace_pscad = scatter(x = pscad_results[!, 1], y = pscad_results[!, p], name = "PSCAD", line_color = "black", line_dash = "dot", line_width = 0.7)
    trace_psid_d = scatter(x = psid_results_dyn[!, 1], y = psid_results_dyn[!, psid_name], name = "PSID - EMT", line_color = D3Colors[1])
    trace_psid_a = scatter(x = psid_results_alg[!, 1], y = psid_results_alg[!, psid_name], name = "PSID - QSP", line_color = D3Colors[2])
    p = plot([trace_psid_d, trace_pscad, trace_psid_a,], Layout(title = "$p",
                                                        xaxis_title = "Time [s]",
                                                          xaxis_range=[0.095, max_lim]))
    savefig(p, "pscad_states_$ix.pdf"; height = 400, width = 600)
    push!(plots, p)
end

p_s = [plots[1] plots[2]
plots[3] plots[4]
plots[5] plots[6]]

savefig(p_s, "pscad_states.pdf"; height = 1500, width = 1300)
