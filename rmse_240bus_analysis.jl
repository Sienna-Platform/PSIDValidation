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
using Plots
const PSY = PowerSystems

system = System("test/benchmarks/psse/240WECC/PSCAD_VALIDATION_RAW.raw",
"test/benchmarks/psse/240WECC/PSCAD_VALIDATION_DYR.dyr";
bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]), runchecks = false)

for l in get_components(PSY.PowerLoad, system)
    PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
end

sim_ida = Simulation(
        MassMatrixModel,
        system,
        pwd(),
        (0.0, 20.0), #time span
        BranchTrip(1.0, Line, "WILLAMET-4203-MERIDIAN-4204-i_274");
        file_level = Logging.Error,
        )

execute!(sim_ida, Rodas4(), abstol = 1e-7)
result_psid = read_results(sim_ida)

## Plot Comparison

result = CSV.read("test/benchmarks/psse/240WECC/psse_results_line_trip/results_psse.csv", DataFrame, header = 2) 
hdr = names(volts_psse)
ix = findall(x -> occursin("ANGL 8034 ", x), hdr)[1];
#ix = findall(x -> occursin("VOLT 8034 ", x), hdr)[1];
v1032_psse = result[!, ix][4:end-1] * (π/180);
#angl_slack = volts_psse[!, 506][4:end-1] * (π/180)
#v1032_psse = result[!, ix][4:end-1] #* (π/180);
angl_slack = result[!, 506][4:end-1] * (π/180)
time_psse = result[!, 1][4:end-1];
v1032_psid = get_voltage_angle_series(result_psid, 8034)#, dt = 0.005)
#v1032_psid = get_voltage_magnitude_series(result_psid, 8034, dt = 0.005)
plot(time_psse, v1032_psse - angl_slack)
plot!(v1032_psid)

ix = findall(x -> occursin("SPD 6235", x), hdr)[1];
w_psse = result[!, ix][4:end-1]
time_psse = result[!, 1][4:end-1];
w_psid = get_state_series(result_psid, ("generator-6235-G", :ω))
plot(time_psse, w_psse .+ 1.0)
plot!(w_psid)



### Store Errors in Dictionaries ###

dict_voltages = Dict()
dict_angles = Dict()
dict_speed = Dict()
angle_slack = result[!, 506][4:end-1] * (π/180)
angle_slack = vcat(angle_slack[1:203], angle_slack[205:end]);

for (ix, n) in enumerate(names(result))
    if occursin("ANGL ", n) && n[end] == ']'
        res_old = result[!, n][4:end-1] * (π/180)
        res_old = vcat(res_old[1:203], res_old[205:end])
        res = res_old - angle_slack
        first_split = split(strip(n), '[')
        second_split = split.(first_split, " ")
        name = join(second_split[2][1:end-1], " ") * "-" * second_split[1][2]
        #@show second_split
        #if second_split[2][end] == "]"
            bus = get_component(Bus, system, name)
            bus_number = parse(Int, second_split[1][2])
            _, voltage_series = get_voltage_angle_series(result_psid, bus_number, dt = 0.005)
            if isnothing(bus)
                @error(name)
            end
            ini_error = voltage_series[1]- res[1]
            #if ini_error < -π
            #        ini_error += π
            #end
            ini_error += angle_slack[1]
            if abs(ini_error) > 1e-4
                @warn(name, n,  ix, bus_number, ini_error, voltage_series[1], res[1], res_old[1])
            end
            dict_angles[bus_number] = norm(voltage_series - res, 2)/length(res)
        #end
    end
    if occursin("VOLT ", n)
        res = result[!, n]
        res = vcat(res[4:203], res[205:end-1])
        first_split = split(strip(n), '[')
        second_split = split.(first_split, " ")
        name = join(second_split[2][1:end-1], " ") * "-" * second_split[1][2]
        bus = get_component(Bus, system, name)
        bus_number = parse(Int, second_split[1][2])
        _, voltage_series = get_voltage_magnitude_series(result_psid, bus_number, dt = 0.005)
        if isnothing(bus)
            @error(name)
        end
        ini_error = voltage_series[1]- res[1]
        if abs(ini_error) > 1e-4
            @warn(name, ini_error)
        end
       dict_voltages[bus_number] = norm(voltage_series - res, 2)/length(res)
    end
    if occursin("SPD ", n)
        res = result[!, n]
        res = vcat(res[4:203], res[205:end-1]) .+ 1.0
        first_split = split(strip(n), '[')
        second_split = split.(first_split, " ")
        third_split = split.(second_split[end], "]")
        gen_name = "generator-" * "$(second_split[1][2])" * "-" * third_split[end][end]
        if typeof(get_component(ThermalStandard, system, gen_name).dynamic_injector) <: DynamicGenerator
            _, p_series = get_state_series(result_psid, (gen_name, :ω), dt = 0.005)
            ini_error = p_series[1]- res[1]
            if abs(ini_error) > 1e-5
                @warn(gen_name, "speed", ini_error)
            end
            dict_speed[gen_name] = norm(p_series - res, 2)/length(res)
        end
    end
end

function find_max_key(d::Dict)

    maxval = first(values(d))
    maxkey = first(keys(d))
    for key in keys(d)
        if d[key] >= maxval
            maxkey = key
            maxval = d[key]
        end
    end

    return maxkey, maxval
end

function find_min_key(d::Dict)

    minval = first(values(d))
    minkey = first(keys(d))
    for key in keys(d)
        if d[key] <= minval
            minkey = key
            minval = d[key]
        end
    end

    return minkey, minval
end


## Gen Trip

dyn_gen = get_component(DynamicInverter, system, "generator-1431-S")
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

    #execute!(sim_ida, IDA(), dtmax = 0.02)
    execute!(sim_ida, solver, abstol = 1e-8)
    result_psid = read_results(sim_ida)
    v1032_psid = get_voltage_magnitude_series(result_psid, 1032, dt = 0.005);
    dict_voltages[solver_string[ix]] = v1032_psid
    dict_time[solver_string[ix]] = result_psid.time_log[:timed_solve_time]
end

result = CSV.read("test/benchmarks/psse/240WECC/psse_results_gen_trip/results_psse.csv", DataFrame; header = 2)
hdr = names(result)
ix = findall(x -> occursin("VOLT 1032 ", x), hdr)[1];
v1032_psse = result[!, ix][4:end-1];
time_psse = result[!, 1][4:end-1];
time_psse = vcat(time_psse[1:200], time_psse[202:end])
v1032_psse = vcat(v1032_psse[1:200], v1032_psse[202:end])
using Plots
plot(time_psse, v1032_psse)
for (k, v) in dict_voltages
    plot!(v)
end


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
