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

const PSY = PowerSystems

system = System("PSCAD_VALIDATION_RAW.raw", "PSCAD_VALIDATION_DYR.dyr";
bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]), runchecks = false)

for l in get_components(PSY.PowerLoad, system)
    PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
end

sim_ida = Simulation(
        MassMatrixModel,
        system,
        pwd(),
        (0.0, 20.0), #time span
        BranchTrip(1.0, Line, "BORAH-6104-NAUGHTON-6305-i_1");
        file_level = Logging.Error,
        console_level = Logging.Info
        )

execute!(sim_ida, Rodas5P())
result_psid = read_results(sim_ida)

v1032_psid = get_voltage_magnitude_series(result_psid, 6104, dt = 0.005);


volts_psse = CSV.read("test/benchmarks/psse/240WECC/psse_results_line_trip/VOLT_csv.csv", DataFrame)


## Gen Trip

dyn_gen = get_component(DynamicInverter, system, "generator-1431-S")
#dyn_gen = get_dynamic_injector(gen)
gen_trip = GeneratorTrip(1.0, dyn_gen)


sim_ida = Simulation(
        ResidualModel,
        system,
        pwd(),
        (0.0, 20.0), #time span
        gen_trip;
        )

solver_string = ["Rodas4", "Rodas5", "Rodas5P", "QNDF", "FBDF"]
dict_voltages = Dict()
dict_time = Dict()
for (ix, solver) in enumerate([Rodas4(), Rodas5(), Rodas5P(), QNDF(), FBDF()])
    sim_ida = Simulation(
        MassMatrixModel,
        system,
        pwd(),
        (0.0, 20.0), #time span
        gen_trip;
        )

    try
        #execute!(sim_ida, IDA(), dtmax = 0.02)
        execute!(sim_ida, solver, abstol = 1e-8)
        result_psid = read_results(sim_ida)
        v1032_psid = get_voltage_magnitude_series(result_psid, 1032, dt = 0.005);
        dict_voltages[solver_string[ix]] = v1032_psid
        dict_time[solver_string[ix]] = result_psid.time_log[:timed_solve_time]
    catch e
        dict_time[solver_string[ix]] = NaN
        dict_voltages[solver_string[ix]] = ([NaN], [NaN])
        continue
    end
end

result = CSV.read("/Users/jdlara/cache/PSIDValidation/line_6104_6305-1/results.csv", DataFrame; header = 2)
hdr = names(result)
ix = findall(x -> occursin("VOLT 6104 ", x), hdr)[1];
v1032_psse = result[!, ix][4:end-1];
time_psse = result[!, 1][4:end-1];
time_psse = vcat(time_psse[1:200], time_psse[202:end])
v1032_psse = vcat(v1032_psse[1:200], v1032_psse[202:end])

plot([scatter(x = v1032_psid[1], y = v1032_psid[2], name = "PSID"), scatter(x = time_psse, y = v1032_psse, name = "PSSe")])

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
