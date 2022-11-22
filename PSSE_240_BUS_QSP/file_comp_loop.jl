using Distributed
addprocs(36, exeflags=`--project=$@__DIR__`)
@everywhere begin
using Pkg
Pkg.instantiate()
using PowerSystems
using PowerSimulationsDynamics
using OrdinaryDiffEq
using Sundials
using Logging
using CSV
using PowerFlows
using DataFrames
using LinearAlgebra
using Statistics
using JSON

const PSY = PowerSystems

include("utils.jl")

# Lines

function run_line(l, system)
    result = Dict()
    name = get_name(l)
    file_output = "./line_validation_output/results_$(name).json"
    try
        vals = split(name, "-")
        id = split(vals[end], "_")[end]
        psse_name = "line_$(vals[2])_$(vals[end-1])-$(id)"
        psse_results_file = joinpath("line_results", psse_name, "results.csv")
        psse_results = CSV.read(psse_results_file, DataFrame, header = 2)
        if any(any.(eachcol(isnan.(psse_results))))
           error()
        end

        sim_ida = Simulation(
            MassMatrixModel,
            system,
            mktempdir(),
            (0.0, 20.0), #time span
            BranchTrip(1.0, Line, name);
            file_level = Logging.Error,
            console_level = Logging.Error,
        )

        res = execute!(sim_ida, Rodas5P(), enable_progress_bar = false, abstol = 1e-6, dt = 0.01, initializealg = NoInit())

        if res !=  PowerSimulationsDynamics.SIMULATION_FINALIZED
            return error()
        end

        result_psid_ida = read_results(sim_ida)

        dict_voltages = Dict()
        dict_angles = Dict()
        dict_speed = Dict()
        angle_slack = psse_results[!, 506][4:end-1] * (π / 180)
        angle_slack = vcat(angle_slack[1:203], angle_slack[205:end])

        for (ix, n) in enumerate(names(psse_results))
            if occursin("ANGL ", n) && n[end] == ']'
                res_old = psse_results[!, n][4:end-1] * (π / 180)
                res_old = vcat(res_old[1:203], res_old[205:end])
                res = res_old - angle_slack
                first_split = split(strip(n), '[')
                second_split = split.(first_split, " ")
                name = join(second_split[2][1:end-1], " ") * "-" * second_split[1][2]
                #@show second_split
                #if second_split[2][end] == "]"
                bus = get_component(Bus, system, name)
                bus_number = parse(Int, second_split[1][2])
                _, voltage_series =
                    get_voltage_angle_series(result_psid_ida, bus_number, dt = 0.005)
                if isnothing(bus)
                    @error(name)
                    continue
                end
                ini_error = voltage_series[1] - res[1]
                #if ini_error < -π
                #        ini_error += π
                #end
                ini_error += angle_slack[1]
                if abs(ini_error) > 1e-4
                    @warn(
                        name,
                        n,
                        ix,
                        bus_number,
                        ini_error,
                        voltage_series[1],
                        res[1],
                        res_old[1]
                    )
                end
                dict_angles[bus_number] = (error = norm(voltage_series - res, 2) / length(res),
                                            error_std = std(voltage_series - res),
                                            mean_error = mean(voltage_series - res))
                #end
            end
            if occursin("VOLT ", n)
                res = psse_results[!, n]
                res = vcat(res[4:203], res[205:end-1])
                first_split = split(strip(n), '[')
                second_split = split.(first_split, " ")
                name = join(second_split[2][1:end-1], " ") * "-" * second_split[1][2]
                bus = get_component(Bus, system, name)
                bus_number = parse(Int, second_split[1][2])
                _, voltage_series =
                    get_voltage_magnitude_series(result_psid_ida, bus_number, dt = 0.005)
                if isnothing(bus)
                    @error(name)
                end
                ini_error = voltage_series[1] - res[1]
                if abs(ini_error) > 1e-4
                    @warn(name, ini_error)
                end
                dict_voltages[bus_number] = (error = norm(voltage_series - res, 2) / length(res),
                                            error_std = std(voltage_series - res),
                                            mean_error = mean(voltage_series - res))
            end
            if occursin("SPD ", n)
                res = psse_results[!, n]
                res = vcat(res[4:203], res[205:end-1]) .+ 1.0
                first_split = split(strip(n), '[')
                second_split = split.(first_split, " ")
                third_split = split.(second_split[end], "]")
                gen_name =
                    "generator-" * "$(second_split[1][2])" * "-" * third_split[end][end]
                if typeof(
                    get_component(ThermalStandard, system, gen_name).dynamic_injector,
                ) <: DynamicGenerator
                    _, p_series =
                        get_state_series(result_psid_ida, (gen_name, :ω), dt = 0.005)
                    ini_error = p_series[1] - res[1]
                    if abs(ini_error) > 1e-5
                        @warn(gen_name, "speed", ini_error)
                    end
                    dict_speed[gen_name] = (error = norm(p_series - res, 2) / length(res),
                                            error_std = std(p_series - res),
                                            mean_error = mean(p_series - res))
                end
            end
        end

        result["volt"] = dict_voltages
        result["angles"] = dict_angles
        result["speed"] = dict_speed

    catch err
    end
    open(file_output, "w") do io
        JSON.print(io, result)
    end
    return result
end

function run_gen(l, system)
    result = Dict()
    gen_name = get_name(l)
    bus_name = get_name(get_bus(l))
    file_output = "./gen_validation_output/results_$(gen_name)__$(bus_name).json"
    try
    vals = split(bus_name, "-")
    gen_type = split(gen_name, "-")[end]
    spacer = length(gen_type) == 1 ? " " : ""
    bus_name = join(vals[1:end-1], "-")
    psse_name = "$(gen_name)$(spacer)__$(bus_name)"
    psse_results_file = joinpath("gen_results", psse_name, "results.csv")
    isfile(psse_results_file)
    psse_results = CSV.read(psse_results_file, DataFrame, header = 2)
    if any(any.(eachcol(isnan.(psse_results))))
        error()
    end
        sim_ida = Simulation(
            MassMatrixModel,
            system,
            mktempdir(),
            (0.0, 20.0), #time span
            GeneratorTrip(1.0, get_dynamic_injector(l));
            file_level = Logging.Error,
            console_level = Logging.Error,
        )

        res = execute!(sim_ida, Rodas5P(), enable_progress_bar = false, abstol = 1e-6, dt = 0.01, initializealg = NoInit())

        if res !=  PowerSimulationsDynamics.SIMULATION_FINALIZED
            result["all failed"] = res
            return error()
        end

        result_psid_ida = read_results(sim_ida)

        dict_voltages = Dict()
        dict_angles = Dict()
        dict_speed = Dict()
        angle_slack = psse_results[!, 506][4:end-1] * (π / 180)
        angle_slack = vcat(angle_slack[1:203], angle_slack[205:end])

        for (ix, n) in enumerate(names(psse_results))
            if occursin("ANGL ", n) && n[end] == ']'
                res_old = psse_results[!, n][4:end-1] * (π / 180)
                res_old = vcat(res_old[1:203], res_old[205:end])
                res = res_old - angle_slack
                first_split = split(strip(n), '[')
                second_split = split.(first_split, " ")
                name = join(second_split[2][1:end-1], " ") * "-" * second_split[1][2]
                #@show second_split
                #if second_split[2][end] == "]"
                bus = get_component(Bus, system, name)
                bus_number = parse(Int, second_split[1][2])
                _, voltage_series =
                    get_voltage_angle_series(result_psid_ida, bus_number, dt = 0.005)
                if isnothing(bus)
                    @error(name)
                    continue
                end
                ini_error = voltage_series[1] - res[1]
                #if ini_error < -π
                #        ini_error += π
                #end
                ini_error += angle_slack[1]
                if abs(ini_error) > 1e-4
                    @warn(
                        name,
                        n,
                        ix,
                        bus_number,
                        ini_error,
                        voltage_series[1],
                        res[1],
                        res_old[1]
                    )
                end
                dict_angles[bus_number] = (error = norm(voltage_series - res, 2) / length(res),
                                            error_std = std(voltage_series - res),
                                            mean_error = mean(voltage_series - res))
                #end
            end
            if occursin("VOLT ", n)
                res = psse_results[!, n]
                res = vcat(res[4:203], res[205:end-1])
                first_split = split(strip(n), '[')
                second_split = split.(first_split, " ")
                name = join(second_split[2][1:end-1], " ") * "-" * second_split[1][2]
                bus = get_component(Bus, system, name)
                bus_number = parse(Int, second_split[1][2])
                _, voltage_series =
                    get_voltage_magnitude_series(result_psid_ida, bus_number, dt = 0.005)
                if isnothing(bus)
                    @error(name)
                end
                ini_error = voltage_series[1] - res[1]
                if abs(ini_error) > 1e-4
                    @warn(name, ini_error)
                end
                dict_voltages[bus_number] = (error = norm(voltage_series - res, 2) / length(res),
                                            error_std = std(voltage_series - res),
                                            mean_error = mean(voltage_series - res))
            end
            if occursin("SPD ", n)
                res = psse_results[!, n]
                res = vcat(res[4:203], res[205:end-1]) .+ 1.0
                first_split = split(strip(n), '[')
                second_split = split.(first_split, " ")
                third_split = split.(second_split[end], "]")
                gen_name =
                    "generator-" * "$(second_split[1][2])" * "-" * third_split[end][end]
                if typeof(
                    get_component(ThermalStandard, system, gen_name).dynamic_injector,
                ) <: DynamicGenerator
                    _, p_series =
                        get_state_series(result_psid_ida, (gen_name, :ω), dt = 0.005)
                    ini_error = p_series[1] - res[1]
                    if abs(ini_error) > 1e-5
                        @warn(gen_name, "speed", ini_error)
                    end
                    dict_speed[gen_name] = (error = norm(p_series - res, 2) / length(res),
                                            error_std = std(p_series - res),
                                            mean_error = mean(p_series - res))
                end
            end
        end

        result["volt"] = dict_voltages
        result["angles"] = dict_angles
        result["speed"] = dict_speed

    catch err
        @error err
    end
    open(file_output, "w") do io
        JSON.print(io, result)
    end
    return result
end
end


system = System(
    "PSCAD_VALIDATION_RAW.raw",
    "PSCAD_VALIDATION_DYR.dyr";
    bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]),
    runchecks = false,
)

for l in get_components(PSY.PowerLoad, system)
    PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
end


res = pmap(x -> run_gen(x, system), collect(get_components(ThermalStandard, system, x -> get_status(x))); on_error = x -> Dict(get_name(x) => "failed"))

res = pmap(x -> run_line(x, system), collect(get_components(Line, system)); on_error = x -> Dict(get_name(x) => "failed"))

# run_line(get_component(Line, system, "WILLAMET-4203-MERIDIAN-4204-i_1"), system)
for l in get_components(Line, system)
    result = Dict()
           name = get_name(l)
            @info name
           file_output = "./line_validation_output/results_$(name).json"
    try
           vals = split(name, "-")
           id = split(vals[end], "_")[end]
           psse_name = "line_$(vals[2])_$(vals[end-1])-$(id)"
           psse_results_file = joinpath("gen_results", psse_name, "results.csv")
           psse_results = CSV.read(psse_results_file, DataFrame, header = 2)
           @show psse_results[220, 1:20]
       if any(any.(eachcol(isnan.(psse_results))))
       @error name
       end
    catch err
        continue
    end
 end

       name = "VACA-DIX-3904-TABLE MT-3905-i_9"
