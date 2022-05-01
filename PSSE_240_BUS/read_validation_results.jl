using JSON
using DataFrames

include("../utils.jl")

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


dir = "/Users/jdlara/cache/PSIDValidation/PSSE_240_BUS/gen_validation_output"
gen_df, failed_gens = get_error_metrics(dir)

plot(scatter(x = gen_df[!, "fault"], y = gen_df[!, "speed"], name="Max speed error"))
plot(scatter(x = gen_df[!, "fault"], y = gen_df[!, "angle"], name="Max angle error"))
plot(scatter(x = gen_df[!, "fault"], y = gen_df[!, "voltage"], name="Max voltage error"))


 "generator-1333-G__H ALLEN-1333" # Singular Exception
 "generator-2030-G__MEXICO-2030" # Singular Exception
 "generator-2438-WG__MESA CAL-2438"
 "generator-2630-G__HAYNES3G-2630"
 "generator-3931-NH__ROUND MT-3931"
 "generator-3933-ND__TESLA-3933"
 "generator-4131-H__COULEE-4131"
 "generator-5031-H__CANAD G1-5031" # Unstable
 "generator-5032-C__CMAIN GM-5032"
 "generator-6235-H__MONTA G1-6235" # Singular Exception
 "generator-6333-C__BRIDGER-6333"
 "generator-6335-C__NAUGHT-6335" # Unstable
 "generator-6533-C__EMERY-6533" # Singular Exception
 "generator-7031-G__COLOEAST-7031"  # Singular Exception
 "generator-7032-C__CRAIG-7032" # Unstable
 "generator-8034-G__RNCHSECO-8034" # Singular Exception


"BORAH-6104-NAUGHTON-6305-i_1" # unstable
 "BURNS-4003-MIDPOINT-6101-i_1"
 "COLOEAST-7001-CRAIG-7002-i_1"
 "COLSTRP-6201-GARRISON-6202-i_1"
 "FOURCORN-1002-SAN JUAN-1004-i_1"
 "GARRISON-6204-MONTANA-6205-i_1"
 "LARAMIE-6302-COLOEAST-7001-i_1"
 "LITEHIPE-2407-MESA CAL-2408-i_1"
 "MARTIN-3104-POTRERO-3105-i_1"
 "NAUGHTON-6305-BENLOMND-6510-i_1"
 "NAUGHTON-6305-BENLOMND-6510-i_2"
 "SUMMER L-4002-BURNS-4003-i_1"
 "TABLE MT-3905-ROUND MT-3906-i_9"
 "VACA-DIX-3904-TABLE MT-3905-i_9"
 "WCASCADE-4202-WILLAMET-4203-i_1"
