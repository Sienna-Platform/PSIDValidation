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

function compare_traces(
    pscad_df,
    psid_df,
    tstart,
    tend,
    toffset,
    pscad_signal,
    psid_signal;
    display_plot = false,
)
    signal_psid = [
        x[2] for x in get_zoom_plot(
            [psid_df[!, "time"], psid_df[!, psid_signal]],
            tstart,
            tend,
        )
    ]
    t_psid = [
        x[1] for x in get_zoom_plot(
            [psid_df[!, "time"], psid_df[!, psid_signal]],
            tstart,
            tend,
        )
    ]
    signal_pscad = [
        x[2] for x in get_zoom_plot(
            [pscad_df[!, "time"] .- toffset, pscad_df[!, pscad_signal]],
            tstart,
            tend,
        )
    ]
    t_pscad = [
        x[1] for x in get_zoom_plot(
            [pscad_df[!, "time"] .- toffset, pscad_df[!, pscad_signal]],
            tstart,
            tend,
        )
    ]
    if length(t_pscad) == length(t_psid) + 1 
        t_pscad = t_pscad[1:end-1]
        signal_pscad = signal_pscad[1:end-1]
    end 
    if display_plot == true
        p1 = plot(t_psid, signal_psid, label = "PSID-- $(psid_signal)")
        display(plot!(p1, t_pscad, signal_pscad, label = "PSCAD-- $(pscad_signal)"))
    end
    @assert LinearAlgebra.norm(t_psid - round.(t_pscad, digits = 6)) == 0.0
    return LinearAlgebra.norm(signal_psid .- signal_pscad, Inf),
    LinearAlgebra.norm(signal_psid .- signal_pscad, 2)
end

