using JSON
using PlotlyJS

results = open("WORK_PRECISION_DIAGRAMS/mm_wp_results.json", "r") do io
    JSON.parse(io; dicttype=Dict)
end

traces = GenericTrace{Dict{Symbol, Any}}[]
for (k, v) in results
    push!(traces, scatter(x = results[k]["error"], y = results[k]["times"], name = k))
end
plot(traces, Layout(xaxis_type = "log", yaxis_type = "log"))
