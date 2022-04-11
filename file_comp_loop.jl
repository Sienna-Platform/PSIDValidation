using Distributed
addprocs(20, exeflags=`--project=$@__DIR__`)
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

const PSY = PowerSystems

include("utils.jl")

# Lines

function run_line(l, system)
    result = Dict()
    try
        name = get_name(l)
        sim_ida = Simulation(
            ResidualModel,
            system,
            pwd(),
            (0.0, 20.0), #time span
            BranchTrip(1.0, Line, name);
            file_level = Logging.Error,
            console_level = Logging.Error,
        )

        execute!(sim_ida, IDA(linear_solver = :KLU), enable_progress_bar = false, abstol = 1e-6, dt = 0.005)
        result_psid_ida = read_results(sim_ida)

        vals = split(name, "-")
        id = split(vals[end], "_")[end]
        psse_name = "line_$(vals[2])_$(vals[4])-$(id)"
        psse_results_file = joinpath("line_results", psse_name, "results.csv")
        psse_results = CSV.read(psse_results_file, DataFrame)
        dict_voltages = Dict()
        dict_angles = Dict()
        dict_speed = Dict()
        angle_slack = result[!, 506][4:end-1] * (π / 180)
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
                dict_angles[bus_number] = norm(voltage_series - res, 2) / length(res)
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
                dict_voltages[bus_number] = norm(voltage_series - res, 2) / length(res)
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
                    dict_speed[gen_name] = norm(p_series - res, 2) / length(res)
                end
            end
        end

        result["volt"] = dict_voltages
        result["angles"] = dict_angles
        result["speed"] = dict_speed

    catch e
        result["error"] = string(e)
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

res = pmap(x -> run_line(x, system), collect(get_components(Line, system))[1:10])
