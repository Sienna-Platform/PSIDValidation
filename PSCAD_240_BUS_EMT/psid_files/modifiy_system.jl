using PowerSystems
using PowerSimulationsDynamics

sys = System(
    joinpath(@__DIR__, "PSCAD_VALIDATION_RAW.raw"),
    joinpath(@__DIR__, "PSCAD_VALIDATION_DYR.dyr");
    bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]),
    runchecks = false,
)

# Remove lines with negatie impedances

for br in get_components(Line, sys)
    if get_x(br) < 0
        @error "Line $(get_name(br)) has negative impedance"
    end
end
