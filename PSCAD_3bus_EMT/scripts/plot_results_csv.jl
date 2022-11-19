using Arrow
using DataFrames
using Plots
using CSV
#Just plot each quantity in a results csv file and save to a separate png. 
#Additionally save a png with all of the plots together. 
#Allow for a variable offset for pscad settling time (but not required)
#User input should just be the name of the csv file. 

function read_csv_file_to_dataframe(file::AbstractString)
    return open(file, "r") do io
        CSV.read(io, DataFrame)
    end
end
function get_zoom_plot(series, tmin, tmax)
    return [
        (series[1][ix], series[2][ix]) for
        (ix, s) in enumerate(series[1]) if (s > tmin && s < tmax)
    ]
end
###USER INPUT 
csv = joinpath(@__DIR__, "..", "psid_files", "psid_sauerpai_sauerpai.csv")
plot_tspan = (0.0, 10.0)
df = read_csv_file_to_dataframe(csv)

#for column in dataframe 

for (ix, c) in enumerate(eachcol(df))
    if ix > 1
        p = plot(
            get_zoom_plot([df[!, "time"], c], plot_tspan[1], plot_tspan[2]),
            title = names(df)[ix],
        )
        mkpath(joinpath(@__DIR__, "..", "figs", split(splitdir(csv)[2], ".")[1]))
        png(
            p,
            joinpath(
                @__DIR__,
                "..",
                "figs",
                split(splitdir(csv)[2], ".")[1],
                names(df)[ix],
            ),
        )
    end
end
