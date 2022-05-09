using Revise
using PowerSystems
using PowerSimulationsDynamics
using OrdinaryDiffEq
using Sundials
using Logging
using CSV
using PowerFlows
using DataFrames
using LinearAlgebra

using PlotlyJS

system = System("PSSE_240_BUS/PSCAD_VALIDATION_RAW.raw", "PSSE_240_BUS/PSCAD_VALIDATION_DYR.dyr";
bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]), runchecks = false)

for l in get_components(PowerLoad, system)
    set_model!(l, LoadModels.ConstantImpedance)
end

th = get_dynamic_injector(get_component(ThermalStandard, system, "generator-1431-N"))

sim_ref = Simulation(
        MassMatrixModel,
        system,
        "PSSE_240_BUS",
        (0.0, 20.0),
        GeneratorTrip(1.0, th);
        file_level = Logging.Error,
        console_level = Logging.Info
        )
execute!(sim_ref, Rodas5P(), abstol = 1e-9)
res_ref = read_results(sim_ref)

v1032_psid = get_voltage_angle_series(res_ref, 5032)

result = CSV.read("results-7.csv", DataFrame; header = 2)
hdr = names(result)
angle_slack = result[!, [506]]
ix = findall(x -> occursin("SPD 1431", x), hdr)
v1032_psse = result[!, ix] .+ 1
time_psse = result[!, 1]


plot([scatter(x = v1032_psid[1], y = v1032_psid[2], name = "PSID"), scatter(x = result[!, ix], y = v1032_psse, name = "PSSe")])

for (k, v) in dict_voltages
    plot!(v)
end

traces1 = GenericTrace{Dict{Symbol, Any}}[]
for (k, v) in dict_voltages
    isnan(v[1][1]) && continue
    push!(traces1, scatter(x = v[1], y = v[2], name = "$k - $(dict_time[k]) Seconds"))
end
plot(traces1, Layout(title = "Results Comparison Mass Matrix Model - abstol 1e-8",
                     yaxis_title="Voltage Bus 1032",
                     xaxis_title="Time"))

# Compare 1032 psse run with psid
ix = findall(x -> occursin("VOLT 1032 ", x), hdr)[1];
v1032_psse = result[!, ix][4:end-1];
time_psse = result[!, 1][4:end-1];
time_psse = vcat(time_psse[1:200], time_psse[202:end])
v1032_psse = vcat(v1032_psse[1:200], v1032_psse[202:end])
v1032_psid = get_voltage_magnitude_series(result_psid, 1032, dt = 0.005);
plot(time_psse, v1032_psse)
plot!(v1032_psid)
using LinearAlgebra
histogram(v1032_psid[2] - v1032_psse)


hdr = names(result)

for n in names(result)[2:end]
    if occursin("VOLT ", n)
        res = result[!, n]*(π/180)
        first_split = split(strip(n), '[')
        second_split = split.(first_split, " ")
        name = join(second_split[2][1:end-1], " ") * "-" * second_split[1][2]
        bus = get_component(Bus, system, name)
        bus_number = parse(Int, second_split[1][2])
        _, voltage_series = get_voltage_angle_series(result_psid, bus_number, dt = 0.005)
        if isnothing(bus)
            @error(name)
        end
        ini_error = voltage_series[1]- res[3]
        if ini_error < -π
                ini_error += π
        end
        if abs(ini_error) > 1e-5
            @warn(name, ini_error)
        end
        errors[name] = (total = norm(voltage_series - res, 2)/length(res), ini = ini_error)
    end
end
