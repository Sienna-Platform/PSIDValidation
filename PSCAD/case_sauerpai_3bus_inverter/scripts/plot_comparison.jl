using Arrow
using DataFrames
using Plots 

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
pscad_offset = 10.0
voltage_plot_zoom = (0.09, 0.12)
state_plot_zoom = (0.0,3.0)
#(pscad_name, psid_name)
voltage_names = [("V_101","V_101") , ("V_102","V_102") ,("V_103","V_103") ]      
state_names = [("Freq_out", "generator-101-1ω"), ("delta_theta_olc", "generator-102-1θ_oc")]  #[ ("delta_theta_olc", "generator-102-1θ_oc") ]    
################


all_psid_filepaths = readdir(joinpath(@__DIR__, "..",  "psid_files"), join=true)
all_pscad_filepaths = readdir(joinpath(@__DIR__, "..",  "pscad_files"), join=true)
psid_csvs = filter(f->endswith(".csv")(f), all_psid_filepaths)
pscad_csvs = filter(f->endswith(".csv")(f), all_pscad_filepaths)
psid_csv_names = [a[end] for a in split.(psid_csvs, "\\")]
pscad_csv_names =  [a[end] for a in split.(pscad_csvs, "\\")]
psid_dfs = [read_csv_file_to_dataframe(csv) for csv in psid_csvs]
pscad_dfs = [read_csv_file_to_dataframe(csv) for csv in pscad_csvs]


for voltage_name in voltage_names
    pscad_name = voltage_name[1]
    psid_name = voltage_name[2]
    p1 = plot()
    for (ix, df) in enumerate(pscad_dfs)
        v_pscad = get_zoom_plot([df[!,"time"].-pscad_offset, df[!,pscad_name]], voltage_plot_zoom[1], voltage_plot_zoom[2])
        plot!(p1, v_pscad, title = pscad_name, label = pscad_csv_names[ix], dpi=200) #
    end 
    for (ix, df) in enumerate(psid_dfs) 
        v_psid = get_zoom_plot([df[!,"time"], df[!,psid_name]], voltage_plot_zoom[1], voltage_plot_zoom[2])
        plot!(p1, v_psid, title = psid_name, label = psid_csv_names[ix], dpi=200) #
    end 
    png(p1, joinpath(@__DIR__, "..", "figs", string(pscad_name)))
end 

for state_name in state_names
    pscad_name = state_name[1]
    psid_name = state_name[2]
    p1 = plot()
    for (ix, df) in enumerate(pscad_dfs)
        v_pscad = get_zoom_plot([df[!,"time"].-pscad_offset, df[!,pscad_name]], state_plot_zoom[1], state_plot_zoom[2])
        plot!(p1, v_pscad, title = pscad_name, label = pscad_csv_names[ix], dpi=200) #
    end 
    for (ix, df) in enumerate(psid_dfs) 
        v_psid = get_zoom_plot([df[!,"time"], df[!,psid_name]], state_plot_zoom[1], state_plot_zoom[2])
        plot!(p1, v_psid, title = psid_name, label = psid_csv_names[ix], dpi=200) #
    end 
    png(p1, joinpath(@__DIR__, "..", "figs", string(pscad_name)))
end 
