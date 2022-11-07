using PowerSystems
using PowerSimulationsDynamics

sys = System(
    joinpath(@__DIR__, "PSCAD_VALIDATION_RAW.raw"),
    joinpath(@__DIR__, "PSCAD_VALIDATION_DYR.dyr");
    bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]),
    runchecks = false,
)

for b in get_components(Bus, sys)
    println(get_name(b))
end

#Code to check if bus names all match and can be parameterized
#= buses = collect(get_components(Bus, sys))
for b in buses
    @info "writing Bus initial conditions and setpoints: $(get_name(b))"
    write_initial_conditions(b, get_name(b), project, x0_dict)
end =#
