using Arrow
using DataFrames
using Plots
using CSV

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

###################
### USER INPUT ####
###################
pscad_offset = 10.0
plots = [
    (
        zoom = (0.095, 0.120),
        names = [("V_101", "V_101"), ("V_102", "V_102")],
        title = "Voltage_zoom",
    ),
    (
        zoom = (0.0, 2.0),
        names = [("V_101", "V_101"), ("V_102", "V_102")],
        title = "Voltage",
    ),
    (zoom = (0.0, 2.0), names = [("f_out_102", "ω_generator-102-1")], title = "Frequency"),
    #  (zoom =(0.0, 2.0), names =  [("ref_freq_out", "ω_generator-101-1"),  ("f_out_102","ω_generator-102-1")], title="Frequency2"),
    (zoom = (0.0, 2.0), names = [("P_102", "P_generator-102-1")], title = "P"),
    (zoom = (0.0, 2.0), names = [("Q_102", "Q_generator-102-1")], title = "Q"),
]

all_psid_filepaths = readdir(joinpath(@__DIR__, "..", "psid_files"), join = true)
all_pscad_filepaths = readdir(joinpath(@__DIR__, "..", "pscad_files"), join = true)
psid_csvs = filter(f -> endswith(".csv")(f), all_psid_filepaths)
pscad_csvs = filter(f -> endswith(".csv")(f), all_pscad_filepaths)
psid_csv_names = [a[end] for a in split.(psid_csvs, "\\")]
pscad_csv_names = [a[end] for a in split.(pscad_csvs, "\\")]
psid_dfs = [read_csv_file_to_dataframe(csv) for csv in psid_csvs]
pscad_dfs = [read_csv_file_to_dataframe(csv) for csv in pscad_csvs]

for p in plots
    p1 = plot()
    for name in p.names
        pscad_name = name[1]
        psid_name = name[2]
        for (ix, df) in enumerate(pscad_dfs)
            v_pscad = get_zoom_plot(
                [df[!, "time"] .- pscad_offset, df[!, pscad_name]],
                p.zoom[1],
                p.zoom[2],
            )
            plot!(
                p1,
                v_pscad,
                label = string(pscad_csv_names[ix], " --- ", pscad_name),
                dpi = 100,
                size = (400, 400),
            )
        end
        for (ix, df) in enumerate(psid_dfs)
            v_psid = get_zoom_plot([df[!, "time"], df[!, psid_name]], p.zoom[1], p.zoom[2])
            plot!(
                p1,
                v_psid,
                style = :dash,
                label = string(psid_csv_names[ix], " --- ", psid_name),
                dpi = 100,
                size = (400, 400),
            )
        end
    end
    png(p1, joinpath(@__DIR__, "..", "figs", p.title))
end
##
θ = get_zoom_plot(
    [psid_dfs[1][!, "time"], psid_dfs[1][!, "generator-101-1θ_pll"]],
    0.0,
    2.0,
)
p2 = plot(θ, label = "θ_pll after change")
θ = get_zoom_plot(
    [psid_dfs[2][!, "time"], psid_dfs[2][!, "generator-101-1θ_pll"]],
    0.0,
    2.0,
)
plot!(p2, θ, label = "θ_pll before change")
