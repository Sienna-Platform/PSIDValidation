using PowerSystems
using PowerSimulationsDynamics
using PowerFlows

include("new_system_data.jl")

sys = System(
    joinpath(@__DIR__, "PSCAD_VALIDATION_RAW.raw"),
    joinpath(@__DIR__, "PSCAD_VALIDATION_DYR.dyr");
    bus_name_formatter = x -> strip(string(x["name"])) * "-" * string(x["index"]),
    runchecks = false,
)

run_powerflow!(sys)

###### Correct Line Data to avoid lines with negatice impedances ######

for br in get_components(Line, sys)
    if get_x(br) < 0
        @info "Line $(get_name(br)) has negative impedance"
    end
end

from_line = get_component(Line, sys, "VINCENT-2404-MIDWAY6-3897-i_1")
remove_component!(Line, sys, "VINCENT-2404-MIDWAY6-3897-i_1")
to_line = get_component(Line, sys, "MIDWAY-3803-MIDWAY5-3896-i_1")
remove_component!(Line, sys, "MIDWAY-3803-MIDWAY5-3896-i_1")
line = get_component(Line, sys,  "MIDWAY5-3896-MIDWAY6-3897-i_1")
remove_component!(Line, sys, "MIDWAY5-3896-MIDWAY6-3897-i_1")

new_line = Line(
    name = "VINCENT-2404-MIDWAY-3803-i_1",
    available = true,
    active_power_flow = get_active_power_flow(line),
    reactive_power_flow = get_reactive_power_flow(line),
    arc = Arc(from_line.arc.from, to_line.arc.from),
    r = get_r(line),
    x = get_x(line) + get_x(from_line) + get_x(to_line),
    b = get_b(line),
    rate = get_rate(line),
    angle_limits = get_angle_limits(line)
)
remove_component!(Bus, sys, get_name(line.arc.to))
remove_component!(Bus, sys, get_name(line.arc.from))
add_component!(sys, new_line,)

from_line = get_component(Line, sys, "VINCENT-2404-MIDWAY2-3893-i_1")
remove_component!(Line, sys, "VINCENT-2404-MIDWAY2-3893-i_1")
to_line = get_component(Line, sys, "MIDWAY-3803-MIDWAY3-3894-i_1")
remove_component!(Line, sys, "MIDWAY-3803-MIDWAY3-3894-i_1")
line = get_component(Line, sys,  "MIDWAY1-3892-MIDWAY2-3893-i_1")
remove_component!(Line, sys, "MIDWAY1-3892-MIDWAY2-3893-i_1")

new_line = Line(
    name = "VINCENT-2404-MIDWAY-3803-i_2",
    available = true,
    active_power_flow = get_active_power_flow(line),
    reactive_power_flow = get_reactive_power_flow(line),
    arc = Arc(from_line.arc.from, to_line.arc.from),
    r = get_r(line),
    x = get_x(line) + get_x(from_line) + get_x(to_line),
    b = get_b(line),
    rate = get_rate(line),
    angle_limits = get_angle_limits(line)
)
remove_component!(Bus, sys, get_name(line.arc.to))
remove_component!(Bus, sys, get_name(line.arc.from))
add_component!(sys, new_line,)

from_line = get_component(Line, sys, "VINCENT-2404-MIDWAY4-3895-i_1")
remove_component!(Line, sys, "VINCENT-2404-MIDWAY4-3895-i_1")
to_line = get_component(Line, sys, "MIDWAY-3803-MIDWAY1-3892-i_1")
remove_component!(Line, sys, "MIDWAY-3803-MIDWAY1-3892-i_1")
line = get_component(Line, sys,  "MIDWAY3-3894-MIDWAY4-3895-i_1")
remove_component!(Line, sys, "MIDWAY3-3894-MIDWAY4-3895-i_1")

new_line = Line(
    name = "VINCENT-2404-MIDWAY-3803-i_3",
    available = true,
    active_power_flow = get_active_power_flow(line),
    reactive_power_flow = get_reactive_power_flow(line),
    arc = Arc(from_line.arc.from, to_line.arc.from),
    r = get_r(line),
    x = get_x(line) + get_x(from_line) + get_x(to_line),
    b = get_b(line),
    rate = get_rate(line),
    angle_limits = get_angle_limits(line)
)
remove_component!(Bus, sys, get_name(line.arc.to))
remove_component!(Bus, sys, get_name(line.arc.from))
add_component!(sys, new_line,)

mid_line1 = get_component(Line, sys, "GRIZZLY6-4096-GRIZZLY7-4097-i_1")
remove_component!(Line, sys, "GRIZZLY6-4096-GRIZZLY7-4097-i_1")
mid_line2 = get_component(Line, sys, "GRIZZLY5-4095-GRIZZLY6-4096-i_1")
remove_component!(Line, sys, "GRIZZLY5-4095-GRIZZLY6-4096-i_1")
line_from = get_component(Line, sys,  "MALIN-4001-GRIZZLY7-4097-i_1")
remove_component!(Line, sys, "MALIN-4001-GRIZZLY7-4097-i_1")
line_to = get_component(Line, sys,  "GRIZZLY-4004-GRIZZLY5-4095-i_1")
remove_component!(Line, sys, "GRIZZLY-4004-GRIZZLY5-4095-i_1")

new_line = Line(
    name = "MALIN-4001-GRIZZLY-4004-i_1",
    available = true,
    active_power_flow = get_active_power_flow(mid_line1),
    reactive_power_flow = get_reactive_power_flow(mid_line1),
    arc = Arc(line_from.arc.from, line_to.arc.from),
    r = get_r(mid_line1) + get_r(mid_line2) + get_r(line_from) + get_r(line_to),
    x = get_x(mid_line1) + get_x(mid_line2) + get_x(line_from) + get_x(line_to),
    b = get_b(line_from),
    rate = get_rate(line_from),
    angle_limits = get_angle_limits(line_from)
)
remove_component!(Bus, sys, get_name(mid_line1.arc.to))
remove_component!(Bus, sys, get_name(mid_line1.arc.from))
remove_component!(Bus, sys, get_name(mid_line2.arc.from))
add_component!(sys, new_line,)


mid_line1 = get_component(Line, sys, "GRIZZLY2-4092-GRIZZLY3-4093-i_1")
remove_component!(Line, sys, "GRIZZLY2-4092-GRIZZLY3-4093-i_1")
mid_line2 = get_component(Line, sys, "GRIZZLY3-4093-GRIZZLY4-4094-i_1")
remove_component!(Line, sys, "GRIZZLY3-4093-GRIZZLY4-4094-i_1")
line_from = get_component(Line, sys,  "MALIN-4001-GRIZZLY4-4094-i_1")
remove_component!(Line, sys, "MALIN-4001-GRIZZLY4-4094-i_1")
line_to = get_component(Line, sys,  "GRIZZLY-4004-GRIZZLY2-4092-i_1")
remove_component!(Line, sys, "GRIZZLY-4004-GRIZZLY2-4092-i_1")

new_line = Line(
    name = "MALIN-4001-GRIZZLY-4004-i_2",
    available = true,
    active_power_flow = get_active_power_flow(mid_line1),
    reactive_power_flow = get_reactive_power_flow(mid_line1),
    arc = Arc(line_from.arc.from, line_to.arc.from),
    r = get_r(mid_line1) + get_r(mid_line2) + get_r(line_from) + get_r(line_to),
    x = get_x(mid_line1) + get_x(mid_line2) + get_x(line_from) + get_x(line_to),
    b = get_b(line_from),
    rate = get_rate(line_from),
    angle_limits = get_angle_limits(line_from)
)
remove_component!(Bus, sys, get_name(mid_line1.arc.to))
remove_component!(Bus, sys, get_name(mid_line1.arc.from))
remove_component!(Bus, sys, get_name(mid_line2.arc.to))
add_component!(sys, new_line,)

line_from = get_component(Line, sys,  "MIDWAY-3803-GATES1-3891-i_1")
remove_component!(Line, sys, "MIDWAY-3803-GATES1-3891-i_1")
line_to = get_component(Line, sys,  "GATES-3802-GATES1-3891-i_1")
remove_component!(Line, sys, "GATES-3802-GATES1-3891-i_1")
new_line = Line(
    name = "MIDWAY-3803-GATES-3802-i_1",
    available = true,
    active_power_flow = get_active_power_flow(line_from),
    reactive_power_flow = get_reactive_power_flow(line_from),
    arc = Arc(line_from.arc.from, line_to.arc.from),
    r = get_r(line_from) + get_r(line_to),
    x = get_x(line_from) + get_x(line_to),
    b = get_b(line_to),
    rate = get_rate(line_from),
    angle_limits = get_angle_limits(line_from)
)
remove_component!(Bus, sys, "GATES1-3891")
add_component!(sys, new_line,)

###### Update Generation Data to match prime mover and fuel ######
set_units_base_system!(sys, "DEVICE_BASE")
update_generation_units!(sys)
set_units_base_system!(sys, "SYSTEM_BASE")
run_powerflow!(sys)

# Change setpoints to avoid reactive power limitations
b = get_component(Bus, sys, "NORTH G3-4231")
set_magnitude!(b, 1.1)
run_powerflow!(sys)
