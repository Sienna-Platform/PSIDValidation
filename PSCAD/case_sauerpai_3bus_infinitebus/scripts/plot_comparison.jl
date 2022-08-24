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

perturbation_type = "LoadStepDown"    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
pscad_offset = 10.0
voltage_plot_zoom = (0.09, 0.13)

#(pscad_name, psid_name)
voltage_names = [("V_101","V_101") , ("V_102","V_102") ,("V_103","V_103") ]      
state_names = []#[ ("delta_theta_olc", "generator-102-1θ_oc") ]    
state_plot_zoom = (0.0,1.0)


df_pscad = read_csv_file_to_dataframe(joinpath(@__DIR__, "..",  "pscad_files", string("pscad_outputs_", perturbation_type)))
df_psid_dyn = read_csv_file_to_dataframe(joinpath(@__DIR__, "..",  "psid_files", string("psid_outputs_", perturbation_type, "_Dynamic")))
#df_psid_alg= read_csv_file_to_dataframe(joinpath(@__DIR__, "..",  "psid_files", string("psid_outputs_", perturbation_type, "_Algebraic")))

for voltage_name in voltage_names
    pscad_name = voltage_name[1]
    psid_name = voltage_name[2]
    v_pscad = get_zoom_plot([df_pscad[!,"time"].-pscad_offset, df_pscad[!,pscad_name]], voltage_plot_zoom[1], voltage_plot_zoom[2])
    #v_psid_alg = get_zoom_plot([df_psid_alg[!,"time"], df_psid_alg[!,psid_name]], voltage_plot_zoom[1], voltage_plot_zoom[2])
    v_psid_dyn = get_zoom_plot([df_psid_dyn[!,"time"], df_psid_dyn[!,psid_name]], voltage_plot_zoom[1], voltage_plot_zoom[2])
    p1 = plot(v_pscad, title = pscad_name, label = "pscad", dpi=200)
    #plot!(v_psid_alg, label = "psid-algebraic")
    plot!(v_psid_dyn, label = "psid-dynamic", color=:black, style=:dash)
    png(p1, joinpath(@__DIR__, "..", "figs", string(pscad_name, perturbation_type)))
end 


for state_name in state_names
    pscad_name = state_name[1]
    psid_name = state_name[2]
    s_pscad = get_zoom_plot([df_pscad[!,"time"].-pscad_offset, df_pscad[!,pscad_name]], state_plot_zoom[1], state_plot_zoom[2])
    #s_psid_alg = get_zoom_plot([df_psid_alg[!,"time"], df_psid_alg[!,psid_name]], state_plot_zoom[1], state_plot_zoom[2])
    s_psid_dyn = get_zoom_plot([df_psid_dyn[!,"time"], df_psid_dyn[!,psid_name]], state_plot_zoom[1], state_plot_zoom[2])
    p1 = plot(s_pscad, title = pscad_name, label = "pscad", dpi=200)
    #plot!(s_psid_alg, label = "psid-algebraic")
    plot!(s_psid_dyn, label = "psid-dynamic", color=:black, style=:dash)
    png(p1, joinpath(@__DIR__, "..", "figs", string(pscad_name, perturbation_type)))
end 
