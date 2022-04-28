using JSON
using DataFrames

include("utils.jl")

dir = "/Users/jdlara/cache/PSIDValidation/line_validation_output"

function get_error_metrics(dir::String)
    volt = []
    volt_names = []
    speed = []
    speed_names = []
    ang = []
    ang_names = []
    line_names = []
    failed_names = []
    for f in readdir(dir)
        json_path = joinpath(dir, f)
        res_dict = open(json_path, "r") do io
            JSON.parse(io)
        end
        @info f
        if !haskey(res_dict, "volt")
            @error res_dict
            push!(failed_names, join(split(split(f, ".")[1], "_")[2:end], "_"))
            continue
        end
        volt_val, volt_name = find_max_key(res_dict["volt"], "error")
        push!(volt, volt_val)
        push!(volt_names, volt_name)
        speed_val, speed_name = find_max_key(res_dict["speed"], "error")
        push!(speed, speed_val)
        push!(speed_names, speed_name)
        ang_val, ang_name = find_max_key(res_dict["angles"], "error")
        push!(ang, ang_val)
        push!(ang_names, ang_name)
        push!(line_names, join(split(split(f, ".j")[1], "_")[2:end], "_"))
    end

    return DataFrame("fault" => line_names,
                        "gen name" => speed_names,
                        "speed" => speed,
                        "bus name angle" => ang_names,
                        "angle" => ang,
                        "bus name voltage" => volt_names,
                        "voltage" => volt), failed_names
end

line_df, failed_lines = get_error_metrics(dir)

using PlotlyJS
plot(scatter(x = line_df[!, "fault"], y = line_df[!, "speed"], name="Max speed error"))
plot(scatter(x = line_df[!, "fault"], y = line_df[!, "angle"], name="Max angle error"))
plot(scatter(x = line_df[!, "fault"], y = line_df[!, "voltage"], name="Max voltage error"))


dir = "/Users/jdlara/cache/PSIDValidation/gen_validation_output"
gen_df, failed_gens = get_error_metrics(dir)

plot(scatter(x = gen_df[!, "fault"], y = gen_df[!, "speed"], name="Max speed error"))
plot(scatter(x = gen_df[!, "fault"], y = gen_df[!, "angle"], name="Max angle error"))
plot(scatter(x = gen_df[!, "fault"], y = gen_df[!, "voltage"], name="Max voltage error"))
