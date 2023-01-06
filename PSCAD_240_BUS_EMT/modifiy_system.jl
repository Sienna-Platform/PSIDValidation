using PowerSystems
using PowerSimulationsDynamics
using PowerFlows

include("new_system_data.jl")

sys = System(
    joinpath(@__DIR__, "psid_files", "PSCAD_VALIDATION_RAW.raw"),
    joinpath(@__DIR__, "psid_files", "PSCAD_VALIDATION_DYR.dyr");
    bus_name_formatter = x -> "B" * strip(string(x["index"])) * "_" * replace(strip(string(x["name"])),  "." => "_", "-" =>"_", " " => "_"),
    runchecks = false,
)

run_powerflow!(sys)

###### Correct Line Data to avoid lines with negative impedances ######

for br in get_components(Line, sys)
    if get_x(br) < 0
        @info "Line $(get_name(br)) has negative impedance"
    end
end

from_line = get_component(Line, sys, "B2404_VINCENT-B3897_MIDWAY6-i_1")
remove_component!(Line, sys, "B2404_VINCENT-B3897_MIDWAY6-i_1")
remove_component!(Arc, sys, get_name(get_arc(from_line)))
to_line = get_component(Line, sys, "B3803_MIDWAY-B3896_MIDWAY5-i_1")
remove_component!(Line, sys, "B3803_MIDWAY-B3896_MIDWAY5-i_1")
remove_component!(Arc, sys, get_name(get_arc(to_line)))
line = get_component(Line, sys,  "B3896_MIDWAY5-B3897_MIDWAY6-i_1")
remove_component!(Line, sys, "B3896_MIDWAY5-B3897_MIDWAY6-i_1")
remove_component!(Arc, sys, get_name(get_arc(line)))

new_line = Line(
    name = "B2404_VINCENT-B3803_MIDWAY-i_1",
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

from_line = get_component(Line, sys, "B2404_VINCENT-B3893_MIDWAY2-i_1")
remove_component!(Line, sys, "B2404_VINCENT-B3893_MIDWAY2-i_1")
remove_component!(Arc, sys, get_name(get_arc(from_line)))
to_line = get_component(Line, sys, "B3803_MIDWAY-B3894_MIDWAY3-i_1")
remove_component!(Line, sys, "B3803_MIDWAY-B3894_MIDWAY3-i_1")
remove_component!(Arc, sys, get_name(get_arc(to_line)))
line = get_component(Line, sys,  "B3892_MIDWAY1-B3893_MIDWAY2-i_1")
remove_component!(Line, sys, "B3892_MIDWAY1-B3893_MIDWAY2-i_1")
remove_component!(Arc, sys, get_name(get_arc(line)))

new_line = Line(
    name = "B2404_VINCENT-B3803_MIDWAY-i_2",
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

from_line = get_component(Line, sys, "B2404_VINCENT-B3895_MIDWAY4-i_1")
remove_component!(Line, sys, "B2404_VINCENT-B3895_MIDWAY4-i_1")
remove_component!(Arc, sys, get_name(get_arc(from_line)))
to_line = get_component(Line, sys, "B3803_MIDWAY-B3892_MIDWAY1-i_1")
remove_component!(Line, sys, "B3803_MIDWAY-B3892_MIDWAY1-i_1")
remove_component!(Arc, sys, get_name(get_arc(to_line)))
line = get_component(Line, sys,  "MIDWAY3-3894-MIDWAY4-3895-i_1")
line = get_component(Line, sys,  "B3894_MIDWAY3-B3895_MIDWAY4-i_1")
remove_component!(Line, sys, "B3894_MIDWAY3-B3895_MIDWAY4-i_1")
remove_component!(Arc, sys, get_name(get_arc(line)))

new_line = Line(
    name = "B2404_VINCENT-B3803_MIDWAY-i_3",
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

mid_line1 = get_component(Line, sys, "B4096_GRIZZLY6-B4097_GRIZZLY7-i_1")
remove_component!(Line, sys, "B4096_GRIZZLY6-B4097_GRIZZLY7-i_1")
remove_component!(Arc, sys, get_name(get_arc(mid_line1)))
mid_line2 = get_component(Line, sys, "B4095_GRIZZLY5-B4096_GRIZZLY6-i_1")
remove_component!(Line, sys, "B4095_GRIZZLY5-B4096_GRIZZLY6-i_1")
remove_component!(Arc, sys, get_name(get_arc(mid_line2)))
line_from = get_component(Line, sys,  "B4001_MALIN-B4097_GRIZZLY7-i_1")
remove_component!(Line, sys, "B4001_MALIN-B4097_GRIZZLY7-i_1")
remove_component!(Arc, sys, get_name(get_arc(line_from)))
line_to = get_component(Line, sys,  "B4004_GRIZZLY-B4095_GRIZZLY5-i_1")
remove_component!(Line, sys, "B4004_GRIZZLY-B4095_GRIZZLY5-i_1")
remove_component!(Arc, sys, get_name(get_arc(line_to)))

new_line = Line(
    name = "B4001_MALIN-B4004_GRIZZLY-i_1",
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


mid_line1 = get_component(Line, sys, "B4092_GRIZZLY2-B4093_GRIZZLY3-i_1")
remove_component!(Line, sys, "B4092_GRIZZLY2-B4093_GRIZZLY3-i_1")
remove_component!(Arc, sys, get_name(get_arc(mid_line1)))
mid_line2 = get_component(Line, sys, "B4093_GRIZZLY3-B4094_GRIZZLY4-i_1")
remove_component!(Line, sys, "B4093_GRIZZLY3-B4094_GRIZZLY4-i_1")
remove_component!(Arc, sys, get_name(get_arc(mid_line2)))
line_from = get_component(Line, sys, "B4001_MALIN-B4094_GRIZZLY4-i_1")
remove_component!(Line, sys, "B4001_MALIN-B4094_GRIZZLY4-i_1")
remove_component!(Arc, sys, get_name(get_arc(line_from)))
line_to = get_component(Line, sys,  "B4004_GRIZZLY-B4092_GRIZZLY2-i_1")
remove_component!(Line, sys, "B4004_GRIZZLY-B4092_GRIZZLY2-i_1")
remove_component!(Arc, sys, get_name(get_arc(line_to)))

new_line = Line(
    name = "B4001_MALIN-B4004_GRIZZLY-i_2",
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

line_from = get_component(Line, sys,  "B3803_MIDWAY-B3891_GATES1-i_1")
remove_component!(Arc, sys, get_name(get_arc(line_from)))
remove_component!(Line, sys, "B3803_MIDWAY-B3891_GATES1-i_1")
line_to = get_component(Line, sys,  "B3802_GATES-B3891_GATES1-i_1")
remove_component!(Arc, sys, get_name(get_arc(line_to)))
remove_component!(Line, sys, "B3802_GATES-B3891_GATES1-i_1")
new_line = Line(
    name = "B3803_MIDWAY-B3802_GATES-i_1",
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
remove_component!(Bus, sys, "B3891_GATES1")
add_component!(sys, new_line,)

existing_line = get_component(Line, sys, "B6305_NAUGHTON-B6510_BENLOMND-i_2")
set_x!(existing_line, get_x(existing_line)*0.8)
set_r!(existing_line, get_x(existing_line)*0.8)
new_line = Line(
    name = "B6305_NAUGHTON-B6510_BENLOMND-i_3",
    available = true,
    active_power_flow = get_active_power_flow(existing_line),
    reactive_power_flow = get_reactive_power_flow(existing_line),
    arc = get_arc(existing_line),
    r = get_r(existing_line),
    x = get_x(existing_line),
    b = get_b(existing_line),
    rate = get_rate(existing_line),
    angle_limits = get_angle_limits(existing_line)
)
add_component!(sys, new_line,)

new_line = Line(
    name = "B6305_NAUGHTON-B6510_BENLOMND-i_4",
    available = true,
    active_power_flow = get_active_power_flow(existing_line),
    reactive_power_flow = get_reactive_power_flow(existing_line),
    arc = get_arc(existing_line),
    r = get_r(existing_line),
    x = get_x(existing_line),
    b = get_b(existing_line),
    rate = get_rate(existing_line),
    angle_limits = get_angle_limits(existing_line)
)
add_component!(sys, new_line,)

existing_line = get_component(Line, sys, "B6104_BORAH-B6305_NAUGHTON-i_1")
set_x!(existing_line, get_x(existing_line)*0.8)
set_r!(existing_line, get_x(existing_line)*0.8)
new_line = Line(
    name = "B6104_BORAH-B6305_NAUGHTON-i_2",
    available = true,
    active_power_flow = get_active_power_flow(existing_line),
    reactive_power_flow = get_reactive_power_flow(existing_line),
    arc = get_arc(existing_line),
    r = get_r(existing_line),
    x = get_x(existing_line),
    b = get_b(existing_line),
    rate = get_rate(existing_line),
    angle_limits = get_angle_limits(existing_line)
)
add_component!(sys, new_line,)

existing_line = get_component(Line, sys, "B6303_BRIDGER2-B6305_NAUGHTON-i_1")
set_x!(existing_line, get_x(existing_line)*0.8)
set_r!(existing_line, get_x(existing_line)*0.8)
new_line = Line(
    name = "B6303_BRIDGER2-B6305_NAUGHTON-i_3",
    available = true,
    active_power_flow = get_active_power_flow(existing_line),
    reactive_power_flow = get_reactive_power_flow(existing_line),
    arc = get_arc(existing_line),
    r = get_r(existing_line),
    x = get_x(existing_line),
    b = get_b(existing_line),
    rate = get_rate(existing_line),
    angle_limits = get_angle_limits(existing_line)
)
add_component!(sys, new_line,)

existing_line = get_component(Line, sys, "B6104_BORAH-B6204_GARRISON-i_1")
new_line = Line(
    name = "B6104_BORAH-B6204_GARRISON-i_2",
    available = true,
    active_power_flow = get_active_power_flow(existing_line),
    reactive_power_flow = get_reactive_power_flow(existing_line),
    arc = get_arc(existing_line),
    r = get_r(existing_line),
    x = get_x(existing_line),
    b = get_b(existing_line),
    rate = get_rate(existing_line),
    angle_limits = get_angle_limits(existing_line)
)
add_component!(sys, new_line,)

### Change some components settings
gen = get_component(ThermalStandard, sys, "generator-4231-H")
set_active_power!(gen, get_active_power(gen) - 1.5)

gen = get_component(ThermalStandard, sys, "generator-4231-C")
set_active_power!(gen, get_active_power(gen) - 0.75)
set_reactive_power_limits!(gen, (min = -7.35, max = 7.35))

gen = get_component(ThermalStandard, sys, "generator-4231-S")
set_status!(gen, true)
set_base_power!(gen, 292.0)
set_rating!(gen, 1.0)
set_active_power!(gen, 2.25)
set_reactive_power!(gen, 1.0)
set_active_power_limits!(gen, (min = 0.0, max = 2.5))
set_reactive_power_limits!(gen, (min = -1.6, max = 1.6))

gen = get_component(ThermalStandard, sys, "generator-4039-H")
set_active_power!(gen, get_active_power(gen) - 2.0)

gen = get_component(ThermalStandard, sys, "generator-4039-S")
set_status!(gen, true)
set_base_power!(gen, 447.0)
set_rating!(gen, 1.0)
set_active_power!(gen, 2.00)
set_reactive_power!(gen, 1.2)
set_active_power_limits!(gen, (min = 0.0, max = 4.0))
set_reactive_power_limits!(gen, (min = -2.0, max = 2.0))

gen = get_component(ThermalStandard, sys, "generator-4039-W")
set_reactive_power_limits!(gen, (min = -5.1, max = 5.1))

gen = get_component(ThermalStandard, sys, "generator-4035-G")
set_reactive_power_limits!(gen, (min = -3.3, max = 3.3))

gen = get_component(ThermalStandard, sys, "generator-6333-W")
set_reactive_power_limits!(gen, (min = -3.51, max = 3.51))

gen = get_component(ThermalStandard, sys, "generator-6235-H")
set_active_power!(gen, get_active_power(gen) - 1.0)

gen = get_component(ThermalStandard, sys, "generator-6235-S")
set_status!(gen, true)
set_base_power!(gen, 111.0)
set_rating!(gen, 1.0)
set_active_power!(gen, 1.0)
set_reactive_power!(gen, 0.1)
set_active_power_limits!(gen, (min = 0.0, max = 1.0))
set_reactive_power_limits!(gen, (min = -0.4, max = 0.4))

gen = get_component(ThermalStandard, sys, "generator-4035-G")
set_active_power!(gen, get_active_power(gen) - 1.0)

gen = get_component(ThermalStandard, sys, "generator-4035-H")
set_active_power!(gen, get_active_power(gen) + 0.5)

gen = get_component(ThermalStandard, sys, "generator-4035-W")
set_active_power!(gen, get_active_power(gen) + 0.5)

gen = get_component(ThermalStandard, sys, "generator-6132-G")
set_active_power!(gen, get_active_power(gen) - 1.5)

gen = get_component(ThermalStandard, sys, "generator-6132-S")
set_active_power!(gen, get_active_power(gen) + 1.5)

gen = get_component(ThermalStandard, sys, "generator-6533-W")
set_active_power!(gen, get_active_power(gen) - 0.75)

gen = get_component(ThermalStandard, sys, "generator-4031-G")
set_reactive_power_limits!(gen, (min = -5.1, max = 5.1))
set_active_power!(gen, get_active_power(gen) - 1.2)

load = get_component(PowerLoad, sys, "load40081")
set_active_power!(load, get_active_power(load) + 2.8)

gen = get_component(ThermalStandard, sys, "generator-4031-W")
set_active_power!(gen, get_active_power(gen) + 1.25)

gen = get_component(ThermalStandard, sys, "generator-4031-H")
set_active_power!(gen, get_active_power(gen) + 1.25)

gen = get_component(ThermalStandard, sys, "generator-4031-S")
set_active_power!(gen, get_active_power(gen) + 0.7)

gen = get_component(ThermalStandard, sys, "generator-6533-H")
set_active_power!(gen, get_active_power(gen) + 0.65)

gen = get_component(ThermalStandard, sys, "generator-6533-S")
set_active_power!(gen, get_active_power(gen) + 1.1)

gen = get_component(ThermalStandard, sys, "generator-3133-S")
set_status!(gen, true)
set_base_power!(gen, 292.0)
set_rating!(gen, 1.0)
set_active_power!(gen, 1.0)
set_reactive_power!(gen, 0.0)
set_active_power_limits!(gen, (min = 0.0, max = 2.5))
set_reactive_power_limits!(gen, (min = -1.6, max = 1.6))

gen = get_component(ThermalStandard, sys, "generator-3133-NG")
set_active_power!(gen, 0.3)

load = get_component(PowerLoad, sys, "load31031")
set_active_power!(load, get_active_power(load) + 1.8)

gen = get_component(ThermalStandard, sys, "generator-6433-E")
set_active_power!(gen, get_active_power(gen) - 1.1)

gen = get_component(ThermalStandard, sys, "generator-6303-DP")
set_status!(gen, true)
set_base_power!(gen, 170.0)
set_rating!(gen, 1.0)
set_active_power!(gen, 1.0)
set_reactive_power!(gen, 0.0)
set_active_power_limits!(gen, (min = 0.0, max = 1.0))
set_reactive_power_limits!(gen, (min = -0.0, max = 0.0))

xfr = get_component(Transformer2W, sys, "B6205_MONTANA-B6235_MONTA_G1-i_1")
set_x!(xfr, get_x(xfr)*3)

load = get_component(PowerLoad, sys, "load39231")
set_active_power!(load, 7.3)
set_reactive_power!(load, 2.82)

fxa = get_component(FixedAdmittance, sys, "6")
set_Y!(fxa, get_Y(fxa) - 1.88im)

###### Update Generation Data to match prime mover and fuel ######
run_powerflow!(sys)
set_units_base_system!(sys, "DEVICE_BASE")
update_generation_units!(sys)

gen = get_component(HydroDispatch, sys, "generator-4231-H")
bus = get_bus(gen)
new_bus = Bus(
    name = "$(get_name(bus))_H",
    number = 4233,
    bustype = "PV",
    angle = get_angle(bus),
    magnitude = get_magnitude(bus),
    voltage_limits = get_voltage_limits(bus),
    base_voltage = get_base_voltage(bus),
    area = get_area(bus),
    load_zone = get_load_zone(bus),
)
add_component!(sys, new_bus,)
set_bus!(gen, new_bus)
xfr = get_component(Transformer2W, sys, "B4201_NORTH-B4231_NORTH_G3-i_1")
new_xfr = Transformer2W(
    name = "B4201_NORTH-B4231_NORTH_G3_H-i_1",
    available = true,
    active_power_flow = get_active_power(gen),
    reactive_power_flow = get_reactive_power(gen),
    arc = Arc(from = get_arc(xfr).from, to = new_bus),
    r = get_r(xfr),
    x = get_x(xfr),
    primary_shunt = 0.0,
    rate = get_base_power(xfr),
)
add_component!(sys, new_xfr)
set_units_base_system!(sys, "SYSTEM_BASE")
run_powerflow!(sys)

for b in get_components(Bus, sys)
    if abs(get_angle(b)) > 1.5
        @error get_name(b) get_angle(b)
    end
    set_voltage_limits!(b, (min = -0.8, max = 1.2))
end

# Make proper load model
for l in get_components(PowerLoad, sys)
    set_model!(l, LoadModels.ConstantImpedance)
end

avr = get_avr(get_dynamic_injector(get_component(HydroDispatch, sys, "generator-4131-H")))
set_K!(avr, 700.0)

pss = get_pss(get_dynamic_injector(get_component(HydroDispatch, sys, "generator-4131-H")))
set_Ks!(pss, 40.0)
set_T1!(pss, 10.0)

avr = get_avr(get_dynamic_injector(get_component(ThermalStandard, sys, "generator-5032-C")))
set_K!(avr, 50.0)

#Serialize deseralize system
to_json(sys, joinpath(@__DIR__, "psid_files", "system.json"), force = true)
System(joinpath(@__DIR__, "psid_files", "system.json"))
