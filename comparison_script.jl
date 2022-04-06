using Revise
using PowerSystems
using PowerSimulationsDynamics
using OrdinaryDiffEq
using Sundials
using Logging
using KLU
using LinearSolve
using CSV
using PowerFlows
using DataFrames
using LinearAlgebra

using PlotlyJS

system = System("/Users/jdlara/cache/psid_speed_test/WECC240_v04_DPV_RE20_v33_6302_xfmr_DPbuscode_PFadjusted_V32_noRemoteVctrl.raw",
"WECC240_dynamics_UPV_v04_psid.dyr";
bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]), runchecks = false)

sim_ida = Simulation(
        MassMatrixModel,
        system,
        pwd(),
        (0.0, 20.0), #time span
        BranchTrip(1.0, Line, "FOURCORN-1001-MOENKOPI-1201-i_1");
        console_level = Logging.Error,
        )

execute!(sim_ida, FBDF(), abstol = 1e-10)
result_psid = read_results(sim_ida)

result = CSV.read("/Users/jdlara/cache/psid_speed_test/results-3.csv", DataFrame; header=2)
filter!(row -> 20 >= row["Time(s)"] >= 0, result)
unique!(result, "Time(s)")

slack = result[!, " ANGL 3933 [TESLA 20.000]"].*(π/180)

#t, series = get_voltage_angle_series(result_psid, 2332, dt = 0.005)
#res = read_results(sim_ida)
errors = Dict()
for n in names(result)[2:end]
    if occursin("ANGL ", n)
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

psid = PlotlyJS.scatter(;x = collect(vals[1]), y= collect(vals[2]), name = "PSID")
psse = PlotlyJS.scatter(;x = t, y = (result[!, " ANGL 2332 [IMPRLVLY 20.000]"].*(π/180) .- slack), name = "PSSe", mode = "lines")
plot([psid, psse])

errors = Dict()
for n in names(result)[2:end]
    if occursin("POWR ", n)
        res = result[!, n]
        first_split = split(strip(n), '[')
        second_split = split.(first_split, " ")
        third_split = split.(second_split[end], "]")
        gen_name = "generator-" * "$(second_split[1][2])" * "-" * third_split[end][end]
        _, p_series = get_activepower_series(result_psid, gen_name, dt = 0.005)
        ini_error = p_series[1]- res[1]
        if abs(ini_error) > 1e-5
            @warn(gen_name, ini_error)
        end
        errors[gen_name] = (total = norm(p_series - res, 2)/length(res), ini = ini_error)
    end
end

#system = System("240busWECC_2018_PSS32_fixed_shunts.raw",
#"240busWECC_2018_PSS.dyr";
#bus_name_formatter = x -> string(x["name"]) * "-" * string(x["index"]), runchecks = false)

pf = run_powerflow!(system)
pf = run_powerflow(system)
pf_result = CSV.read("pf_bus_results.csv", DataFrame)
pf["bus_results"].θ = pf["bus_results"].θ/(π/180)

v_diff = Float64[]
angle_diff = Float64[]
for (ix, n) in enumerate(eachrow(pf_result))
        bus_number = n."Bus  Number"
        push!(v_diff, pf["bus_results"][ix,:].Vm - n."Voltage (pu)")
        push!(angle_diff, pf["bus_results"][ix,:].θ - n."Angle (deg)")
end

plot(histogram(x = v_diff, name = "Voltage Difference"), Layout(title = "Voltage Manitude Error [pu]"))
plot(histogram(x = angle_diff, name = "Angle Difference"), Layout(title = "Voltage Angle Error [deg]"))


pf_result_gen = CSV.read("pf_gen_results.csv", DataFrame)

p_diff = []
q_diff = []
gen_names = []
for row in eachrow(pf_result_gen)
    if ismissing(row."Bus  Number")
        continue
    end
    gen_name = "generator-" * "$(row."Bus  Number")" * "-" * row."Id"
    push!(gen_names, gen_name)
    gen = get_component(ThermalStandard, system, gen_name)
    ap = get_active_power(gen)
    rp = get_reactive_power(gen)
    push!(p_diff, ap - row."PGen (MW)"/100)
    push!(q_diff, rp - row."QGen (Mvar)"/100)
end

plot(histogram(x=p_diff, name = "P Difference"), Layout(title = "Active Power Manitude Error [pu]"))
plot(histogram(x=q_diff, name = "Q Difference"), Layout(title = "Reactive Power Manitude Error [pu]"))



speed_results = Dict()

for solver in (IDA(), IDA(linear_solver = :LapackDense), IDA(linear_solver = :KLU)), tol in (1e-6, 1e-8, 1e-10)
        try
        sim_ida = Simulation(
                ResidualModel,
                system,
                pwd(),
                (0.0, 20.0), #time span
                BranchTrip(1.0, Line, "CORONADO    -1101-PALOVRDE    -1401-i_10");
                console_level = Logging.Info,
                )

        execute!(sim_ida, solver, abstol = tol, reltol = tol)
        results = read_results(sim_ida)
        speed_results[(solver, tol)] = results.time_log
        catch e
                speed_results[(solver, tol)] = "failed"
        end
end

sim = Simulation(
        MassMatrixModel,
        system,
        pwd(),
        (0.0, 20.0), #time span
        BranchTrip(1.0, Line, "CORONADO    -1101-PALOVRDE    -1401-i_10");
        console_level = Logging.Info,
        )

execute!(sim, Rodas4())

speed_results = Dict()
for solver in (Rodas4(), Rodas4(linsolve = KLUFactorization()), Rodas4P(), Rodas4P(linsolve = KLUFactorization())), tol in (1e-6, 1e-8, 1e-10)
        try
        sim = Simulation(
                MassMatrixModel,
                system,
                pwd(),
                (0.0, 20.0), #time span
                BranchTrip(1.0, Line, "CORONADO    -1101-PALOVRDE    -1401-i_10");
                console_level = Logging.Info,
                )

        execute!(sim, solver, abstol = tol, reltol = tol)
        results = read_results(sim)
        @show (solver, tol), results.time_log
        speed_results[(solver, tol)] = results.time_log
              catch e
                speed_results[(solver, tol)] = "failed"
        end
end


results_ida = read_results(sim_ida)
results = read_results(sim)


vals_ida = get_voltage_magnitude_series(results_ida, 6333)
