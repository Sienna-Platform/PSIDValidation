# Adapted from modifiy_system.jl

using PowerSystems
using PowerSimulationsDynamics
using PowerFlows
using NLsolve
using CSV
using PlotlyJS
using DataFrames

include("new_system_data.jl")

# Load .raw and .dyr files
sys = System(
    joinpath(@__DIR__, "psid_files", "PSCAD_VALIDATION_RAW.raw"),
    joinpath(@__DIR__, "psid_files", "PSCAD_VALIDATION_DYR.dyr");
    bus_name_formatter = x -> "B" * strip(string(x["index"])) * "_" * replace(strip(string(x["name"])),  "." => "_", "-" =>"_", " " => "_"),
    runchecks = false,
)

solve_powerflow!(sys)

#for b in get_components(Bus, sys)
#    println("$(get_name(b)) - Magnitude $(get_magnitude(b)) - Angle (rad) $(get_angle(b))")
#end

         
# Code for exporting powerflow results
#= 
res = run_powerflow(sys)
df = res["flow_results"]
open(joinpath(@__DIR__, string("flow_results", ".csv")), "w") do io
    CSV.write(io, df)
end
df = res["bus_results"]
open(joinpath(@__DIR__, string("bus_results", ".csv")), "w") do io
    CSV.write(io, df)
end
=#

# Print names of lines with negative impedances
#for br in get_components(Line, sys)
#    if get_x(br) < 0
        #@info "Line $(get_name(br)) has negative impedance"
#    end
#end

line_params = Dict(
    #https://www.mdpi.com/1996-1073/10/8/1233/htm
    345.0 => ( 
        impedance = (0.000198, 0.000360, 0.000518), #impedance or reactance?
        xr_ratio = (16.0, 12.0 ,9.0),
        limits = (1494, 1195, 897),
        # Couldn't find z_c = (),
    ),
    500.0 => (
        impedance = (0.000121, 0.000155, 0.000210), #"Transmission line per-km, per-unit X"
        xr_ratio = (26.0, 17.0, 11.0),
        limits = (3464, 2598, 1732),
        #z_c = (233, 294), 
    ),
)

# Correct lines with zero resistance but postive reactance. 
for br in get_components(Line, sys)
    if get_r(br) <= 0 && get_x(br) > 0
        voltage = get_base_voltage(get_from(get_arc(br)))
        new_r = get_x(br)/(line_params[voltage].xr_ratio[2]) # divide reactance by median x/r ratio to get r value.
        set_r!(br, new_r)
    end
end
#= # Code to print rate for lines connected to 500kV lines
for l in get_components(Line, sys)
    if get_base_voltage(get_arc(l).to)== 500
        println(get_rate(l))
    end
end
=#

# Network changes to shorten lines
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
line = get_component(Line, sys,  "B3894_MIDWAY3-B3895_MIDWAY4-i_1") #re-defining line?
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

# Note: all lines with negative impedance have been removed

# --------------------------------------------------------------
# *FOR TESTING* Creating Data Frame of Generators with Strange Device Mixes
# --------------------------------------------------------------

println("---------------------------------------------------------------------------------------------------------------- *TESTING* Creating dataframe of buses with strange device mixes")

# Only includes buses with the following combinations: SG+SC, SG+Inv, SC+Inv
df_buses_with_gens = DataFrame(
        BusName=String[],
        BusNumber=Int[],
        BusType=Int[],
        SC=Bool[],
        SG=Bool[],
        Inv=Bool[],
        StrangeMix=Bool[]
)

for b in get_components(Bus, sys)
    th = get_components(x -> get_bus(x) == b, ThermalStandard, sys)
    number_of_gens_at_bus = length(th)

    # Start by assuming none of the device types are present at this bus
    SC_flag = false
    SG_flag = false
    INV_flag = false

    # If any of the device types are found at this bus, toggle the relevant flag
    for g in th
        unit_type = split(get_name(g), "-")[end]
        if unit_type == "S"||unit_type == "W"||unit_type == "DP"||unit_type == "NW"||unit_type == "SW"
            INV_flag = true
        elseif unit_type == "SC"
            SC_flag = true
        else
            SG_flag = true
        end
    end

    # Add to data frame if this bus has generators
    if (SC_flag && SG_flag) || (SC_flag && INV_flag) || (SG_flag && INV_flag)
        # Buses with strange devices mixes: SG+SC, SG+Inv, SC+Inv (Note this also includes the case of SC+SG+INV)
        push!(df_buses_with_gens, (get_name(b), get_number(b), get_bustype(b).value, SC_flag, SG_flag, INV_flag, true))
    elseif SC_flag || SG_flag || INV_flag
        # Buses with a only one type of generator
        push!(df_buses_with_gens, (get_name(b), get_number(b), get_bustype(b).value, SC_flag, SG_flag, INV_flag, false))
    end
end

# Grab subset of buses that have a strange  mix of generators
df_buses_with_gens_strange_mix = filter(:StrangeMix => n -> n == true, df_buses_with_gens)

# Store list of unique buses to be used for split bus procedure
bus_numbers_with_gens_strange_mix = sort!(unique((df_buses_with_gens_strange_mix[!,[:BusNumber]]).BusNumber))


# Export strange mix subset to a CSV
open(joinpath(@__DIR__, string("multi_gen_buses", ".csv")), "w") do io
    CSV.write(io, df_buses_with_gens_strange_mix)
end

# Grab subset of buses that have only one type of generator (just for reference, not used anywhere)
df_buses_with_gens_single_type = filter(:StrangeMix => n -> n == false, df_buses_with_gens)


# --------------------------------------------------------------
# *FOR TESTING* Multiply Q limit of every gen by 10 
# --------------------------------------------------------------

# This will make it easier to see when there is a "run-away" reactive power problem 
for gen in get_components(ThermalStandard, sys)
    new_min = get_reactive_power_limits(gen).min
    new_max = get_reactive_power_limits(gen).max * 10
    set_reactive_power_limits!(gen, (min = new_min, max = new_max))
end

# --------------------------------------------------------------
# *FOR TESTING* Build Dataframe with info about each generator
# --------------------------------------------------------------

function build_gen_info_dataframe(sys)
    df_gens = DataFrame(
        GenName=String[],
        GenBus=Integer[],
        SplitBus=Bool[],
        Capacity=Float64[],
        VMag=Float64[],
        VAng=Float64[],
        P=Float64[],
        Q=Float64[],
        PowerFactor=Float64[],
        Qmin=Float64[],
        Qmax=Float64[],
        QFrac=Float64[],
        VMagViolated=Bool[],
        VAngViolated=Bool[],
        QViolated=Bool[],
        LimitReached=Bool[],
        StatusAvailable=[]
        )
    for gen in get_components(ThermalStandard, sys)
        # Get basic information about generator
        name = get_name(gen)
        bus = get_number(get_bus(gen))
        capacity = get_rating(gen)
        vmag = get_magnitude(get_bus(gen))
        vang = get_angle(get_bus(gen))
        p = get_active_power(gen)
        q = get_reactive_power(gen)
        power_factor = p / sqrt((p^2) + (q^2))
        qmin = get_reactive_power_limits(gen).min
        qmax = get_reactive_power_limits(gen).max
        qfrac = abs(q) / broadcast(abs, qmax)
        bool_split = bus in SPLIT_BUSES
        status = get_status(gen) && get_available(gen)
        
        # Check voltage mag/ang and reactive power against limits
        bool_vmag_violated = false
        bool_vang_violated = false
        bool_q_violated = false
        if qfrac >= 0.95
            bool_q_violated = true
        end
        if vmag <= 0.95 || vmag >= 1.05
            bool_vmag_violated = true
        end
        if (vang - (pi/2*0.9)) >= 0
            bool_vang_violated = true
        end
        bool_violated = bool_q_violated||bool_vmag_violated||bool_vang_violated # are any of the limits violated?
        
        # Create row in dataframe for this generator
        push!(df_gens, (name, bus, bool_split, capacity, vmag, vang, p, q, power_factor, qmin, qmax, qfrac, bool_vmag_violated, bool_vang_violated, bool_q_violated, bool_violated, status))
    end
    return df_gens
end


# --------------------------------------------------------------
# *FOR TESTING* Find a bus with gens close to their Q limit
# --------------------------------------------------------------

# Build dataframe with generator info prior to splitting generators
df_gens_pre_split = build_gen_info_dataframe(sys)

# Show all gens at >0.95 of their reactive power limit
show(sort!(filter(:QFrac => n -> n > 0.095 && n <= 0.1, df_gens_pre_split[!,[:GenName, :StatusAvailable,:Capacity,:GenBus, :PowerFactor, :Q, :Qmin, :Qmax,:QFrac]]),:GenBus), allrows=true)
buses_hitting_Q_limit = unique(filter(:QFrac => n -> n > 0.95 && n <= 1, df_gens_pre_split[!,[:GenBus, :QFrac]]).GenBus)

# Show full set of generators for each bus that has one or more gens at/close to their reactive power limit
for bus in buses_hitting_Q_limit
    show(sort!(filter(:GenBus => n -> n == bus, df_gens_pre_split[!,[:GenName, :StatusAvailable,:Capacity,:GenBus, :PowerFactor, :Q, :Qmin, :Qmax,:QFrac]]), :Capacity, rev=true),allrows=true)
end

##
# --------------------------------------------------------------
# Split multi-gen buses so each gen has it's own transformer
# --------------------------------------------------------------

const MULTI_GEN_BUSES = [
    6433
    6132
    4231
    4035
    4031
    6333
    4039
    6235
]

#= Print voltage magnitude of the split bus (B) and the bus on the high side of the original transformer (A)
bus = first(get_components(x -> get_number(x) == 4001, Bus, sys))
println("Voltage magnitude of bus 4001 before split: $(get_magnitude(bus))")
bus = first(get_components(x -> get_number(x) == 4031, Bus, sys))
println("Voltage magnitude of bus 4031 before split: $(get_magnitude(bus))")
=#

bus_numbers = get_number.(get_components(Bus, sys))
bus_numbers_new = []
for b in bus_numbers_with_gens_strange_mix

    # *TESTING* There is an issue with 3933
    # - splitting 3933 with the following procedure causes the powerflow to break
    # - I think it is because it is *not* a PV bus, despite having generators...
    if b == 3933 
        @info "......skipping $b"
        continue
    end

    # Get info about the bus this generator is attached to
    bus = first(get_components(x -> get_number(x) == b, Bus, sys))
    # Get bus transformer (will through error if more than one)
    bus_xfr = get_bus_transformer(sys, bus)

    # Loop through all generator components attached to bus b
    th = get_components(x -> get_number(get_bus(x)) == b, ThermalStandard, sys)
    number_of_gens_at_bus = length(th)
    for g in th
        # ------------------ CREATE NEW BUS
        q = get_reactive_power(g)
        qmax = get_reactive_power_limits(g).max
        qfrac = abs(q) / abs(qmax) * 10
        println("The pre-split Q frac of $(get_name(g)) is $qfrac")
        
        # Get the generator info we need for the new bus
        unit_type = split(get_name(g), "-")[end]
        v_mag_setpoint = get_magnitude(bus) # TODO: Change this value to be magnitude of the other bus bus_xfr is connected to?

        # Get next un-used bus number to assign to the new bus we will create for this generator 
        next_bus_number = get_next_bus_number(bus_numbers, b) # Q: may want to look over how get_next_bus_number works
        push!(bus_numbers, next_bus_number)
        push!(bus_numbers_new, next_bus_number)

        # Get whether this is a grid-forming gen (PV bus) or grid-following gen (PQ bus) from dyn_gen attributes
        # TODO: find a more robust way to check for this
        dyn_gen = get_dynamic_injector(g)
        if hasproperty(dyn_gen, :freq_estimator) 
            new_bustype = "PQ"  # "DynamicInverter"
        else 
            new_bustype = "PV"  # "DynamicGenerator"
        end
        
        # Create new bus for this individual generator
        new_bus = Bus(
            name = "B$(next_bus_number)_$unit_type", # Q: are the buses always labeled by the generator type...?
            number = next_bus_number,
            bustype = new_bustype,
            angle = get_angle(bus), # NOTE: for both PV and PQ buses, this will get overwritten, that's fine!
            magnitude = v_mag_setpoint, # NOTE: for PQ buses, this will get overwritten, that's fine!
            voltage_limits = get_voltage_limits(bus),
            base_voltage = get_base_voltage(bus),
            area = get_area(bus),
            load_zone = get_load_zone(bus),
        )   

        # Add new bus to system
        @info "adding bus $(get_name(new_bus))"
        add_component!(sys, new_bus)

        # ------------------ UPDATE GEN

        # Remove this generator (i.e. detach from grid)
        remove_component!(sys, dyn_gen)
        remove_component!(sys, g)

        # Update generator component parameters before adding it back into the system
        set_bus!(g, new_bus) # Q: I think g is still the same object, just not attached?
        @info "setting gen name generator-$(next_bus_number)-$unit_type"
        set_name!(g, "generator-$(next_bus_number)-$unit_type")

        # If our new bus is a PQ bus, define Q (powerflow input)
        # TODO: decide which setpoint to use
        if new_bustype == "PQ"
            #set_reactive_power!(g, get_reactive_power(g))
            set_reactive_power!(g, 0.0)
        end

        # Add generator back into system (i.e. attach to grid)
        add_component!(sys, g)
         
        #TODO: add dynamic component to gen?

        # ------------------ CREATE NEW TRANSFORMER

        # Create new transformer between new bus (where this gen will be attached) and original bus 
        # (where this gen used to be attached and what will become PQ bus at the end of this loop)
        new_xfr = Transformer2W( 
            name = "$(get_name(bus))-$(get_name(new_bus))-i_1",
            available = true,
            active_power_flow = -get_active_power(g),
            reactive_power_flow = -get_reactive_power(g),
            arc = Arc(to = bus, from = new_bus),
            r = get_r(bus_xfr), #Always 0?
            x = number_of_gens_at_bus * get_x(bus_xfr), 
            primary_shunt = 0.0,
            rate = get_base_power(g)*1.1,
        )
        # Add new transformer to system
        @info "adding transformer $(get_name(new_xfr))"
        add_component!(sys, new_xfr)
        
    end

    # Change old bus to PQ bus since it no longer has any gens attached to it
    # TODO: this allows powerflow to solve, but figure out if there is anything else we need to change
    # TODO: check whether this assumes that P=0 and Q=0 (what we want) or if we need to define a StaticInjection (StandardLoad?) of 0
    set_bustype!(bus, "PQ")

    # Change base voltage of the split bus (B) to be the same as the bus on the high side of this transformer (A)
    if get_arc(bus_xfr).from == bus
        bus_high_side = get_arc(bus_xfr).to
    else 
        bus_high_side = get_arc(bus_xfr).from
    end
    set_base_voltage!(bus, get_base_voltage(bus_high_side))

    # ------------------ REMOVE OLD TRANSFORMER AND REPLACE WITH LINE

    # Create new line object
    # TODO: check that we should indeed be removing this (related to question about subtransmission)
    # TODO: figure out how to assign values to some line params
    new_line = Line(
        name = "$(get_name(get_arc(bus_xfr).from))-$(get_name(get_arc(bus_xfr).to))-i_1",
        available = true,
        active_power_flow = get_active_power_flow(bus_xfr),
        reactive_power_flow = get_reactive_power_flow(bus_xfr),
        arc = get_arc(bus_xfr),
        r = 0,
        x = 0.0001, # random small number
        b = (from = 0.0, to = 0.0), # taken from another line
        rate = 1000, # random large number (should change)
        angle_limits = (min = -1.0472, max = 1.0472) # taken from another line
    )

    # Swap out transformer for line
    remove_component!(sys, bus_xfr)
    add_component!(sys, new_line)

end

# Re-solve powerflow with new topology
solve_powerflow!(sys)

#= Print voltage magnitude of the split bus (B) and the bus on the high side of the original transformer (A)
bus = first(get_components(x -> get_number(x) == 4001, Bus, sys))
@info("Voltage magnitude of bus 4001 after split: $(get_magnitude(bus))")
bus = first(get_components(x -> get_number(x) == 4031, Bus, sys))
@info("Voltage magnitude of bus 4031 after split: $(get_magnitude(bus))")

# Print Qfrac of new buses (should be zero for IBRs)
for b in bus_numbers_new
    th = first(get_components(x -> get_number(get_bus(x)) == b, ThermalStandard, sys))
    q = get_reactive_power(th)
    qmax = get_reactive_power_limits(th).max
    qfrac = abs(q) / abs(qmax) * 10
    println("The post-split Qfrac of $(get_name(th)) is $qfrac")
end
=#

##
# --------------------------------------------------------------
# *FOR TESTING* Look at reactive power after splitting bus
# --------------------------------------------------------------

# Build dataframe with generator info after to splitting generators
df_gens_post_split = build_gen_info_dataframe(sys)

# Build comparison dataframe for plotting
df_plot = leftjoin(df_gens_post_split[!,[:GenName, :PowerFactor, :QFrac]], df_gens_pre_split[!,[:GenName,:PowerFactor, :QFrac]], on = :GenName, makeunique=true)

# Plot Power Factor (post vs. pre)
plot(
    df_plot, x=:PowerFactor_1, y=:PowerFactor, text=:GenName,
    mode="markers", size_max=60,
    kind="scatter",
    labels=Dict(
        :PowerFactor_1 => "PF (pre-split)",
        :PowerFactor => "PF (post-split)",
    ),
    Layout(
        title_text="Comparison of Power Factor before/after splitting bus",
        annotations=[
            attr(text="Worse (further from PF=1)",
            xref="paper", yref="paper",
            x=0.9, y=0.1, showarrow=false),
            attr(text="Better (closer to PF=1)",
            xref="paper", yref="paper",
            x=0.1, y=0.9, showarrow=false),
        ]        
    )
)

##
# Plot Q Fraction (post vs. pre)
plot(
    df_plot, x=:QFrac_1, y=:QFrac, text=:GenName,
    mode="markers", size_max=60,
    kind="scatter",
    labels=Dict(
        :QFrac_1 => "Q / QLimit (pre-split)",
        :Q_Frac => "Q / QLimit (post-split)",
    ),
    Layout(
        title_text="Comparison of Q/QLimit before/after splitting bus",
        annotations=[
            attr(text="Better (further from Q limit)",
            #xref="paper", yref="paper",
            x=0.1, y=0.02, showarrow=false),
            attr(text="Worse (closer to Q limit)",
            #xref="paper", yref="paper",
            x=0.02, y=0.1, showarrow=false),
            attr(text="Run-away",
            #xref="paper", yref="paper",
            x=0.05, y=0.45, showarrow=false),
        ]
    )
)

##
# --------------------------------------------------------------
# Plot impedances of zero resistance lines.
# --------------------------------------------------------------

x_500 = []
x_500_0r = []
for br in get_components(Line,sys)
    if get_base_voltage(get_from(get_arc(br))) == 500 && get_r(br)>0 
        push!(x_500,get_x(br))
    elseif get_base_voltage(get_from(get_arc(br))) == 500
        push!(x_500_0r,get_x(br))
    end
end

x_345 = []
x_345_0r = []
for br in get_components(Line,sys)
    if get_base_voltage(get_from(get_arc(br))) == 345 && get_r(br)>0 
        push!(x_345,get_x(br))
    elseif get_base_voltage(get_from(get_arc(br))) == 345
        push!(x_345_0r,get_x(br))
    end
end

p345 = plot(x_345, label="x_345")
scatter!(x_345_0r, label="0r x values")

p500 = plot(x_500, label="x_500")
scatter!(x_500_0r, label="0r x values")

p = plot(p345, p500, layout=(2,1), label=["345kV" "345kV" "500kV" "500kV"])

display(p)

# Plotting Q fraction, V mag, and V ang. Create dataframe.
gens_adjusted = [
    "generator-4231-H",
    "generator-4231-C",
    "generator-4231-S",
    "generator-4039-H",
    "generator-4039-S",
    "generator-4039-W",
    "generator-4035-G",
    "generator-6333-W",
    "generator-6235-H",
    "generator-6235-S",
    "generator-4035-H",
    "generator-4035-W",
    "generator-6132-G",
    "generator-6132-S",
    "generator-6533-W",
    "generator-4031-G",
    "generator-4031-W",
    "generator-4031-H",
    "generator-4031-S",
    "generator-6533-H",
    "generator-6533-S",
    "generator-3133-S",
    "generator-3133-NG",
    "generator-6433-E",
    "generator-6303-DP", 
]

# Define empty arrays that will be populated inside the loop below
gen_voltage_mag = zeros(0)
gen_voltage_mag_adjusted = zeros(0)
gen_voltage_angle = zeros(0)
gen_voltage_angle_adjusted = zeros(0)
gen_q_fraction = zeros(0)
gen_q_fraction_adjusted = zeros(0)
gen_cap = zeros(0)
gen_cap_adjusted = zeros(0)
adjusted_gens_df = DataFrame(AdjGenNames=String[], VMag=Float64[], VAng=Float64[], QFrac=Float64[], MagLimit=Bool[], AngLimit=Bool[], QLimit=Bool[], LimitReached=Bool[])

# Loop through all thermal generators (I think there are others that are not ThermalStandard? not sure if we want those too)
for gen in get_components(ThermalStandard, sys)
    # Print names of generators that are over reactive limit
    #if (get_reactive_power(gen) > get_reactive_power_limits(gen).max) || (get_reactive_power(gen) < get_reactive_power_limits(gen).min)
    #    @info "Gen $(get_name(gen)) - reactive power $(get_reactive_power(gen)) - limits $(get_reactive_power_limits(gen))"
    #end
    if get_name(gen) in gens_adjusted
        # Append to JD-adjusted arrays for plotting
        name = get_name(gen)
        vmag = get_magnitude(get_bus(gen))
        vang = get_angle(get_bus(gen))
        qfrac = abs(get_reactive_power(gen)) / broadcast(abs, get_reactive_power_limits(gen).max)
        capacity = get_rating(gen)
        println(capacity)
        magbool = false
        angbool = false
        qbool = false
        if qfrac >= 0.95
            qbool = true
        elseif vmag <= 0.95 || vmag >= 1.05
            magbool = true
        elseif (vang - (pi/2*0.9)) >= 0 
            angbool = true
        end
        limitbool = qbool||magbool||angbool
        push!(adjusted_gens_df, (name,vmag,vang,qfrac,magbool,angbool,qbool,limitbool))
        append!(gen_voltage_mag_adjusted, vmag)
        append!(gen_voltage_angle_adjusted, vang)
        append!(gen_q_fraction_adjusted, qfrac)
        append!(gen_cap_adjusted, capacity)
    else
        # Append to non-JD-adjusted arrays for plotting
        append!(gen_voltage_mag, get_magnitude(get_bus(gen)))
        append!(gen_voltage_angle, get_angle(get_bus(gen)))
        append!(gen_q_fraction, abs(get_reactive_power(gen)) / broadcast(abs, get_reactive_power_limits(gen).max))
        println(get_rating(gen))
        append!(gen_cap, get_rating(gen))
    end
end


# Plot Q fraction vs bus voltage mag (p1) and Q fraction vs. bus voltage angle (p2)
p1 = plot(
    gen_voltage_angle*(180/pi), # convert radians to degrees
    gen_q_fraction, 
    seriestype=:scatter, 
    title="Q Fraction vs. Voltage Angle",
    label="Not adjusted",
    xlabel="Voltage Angle (degs)", 
    ylabel="abs(Q)/abs(Q limit)"
    )
plot!(
    gen_voltage_angle_adjusted*(180/pi), # convert radians to degrees
    gen_q_fraction_adjusted, 
    seriestype=:scatter, 
    label="Adjusted"
    )
p2 = plot(
    gen_voltage_mag, 
    gen_q_fraction, 
    seriestype=:scatter,
    title="Q Fraction vs. Voltage Mag", 
    label="Not adjusted",
    xlabel="Voltage Mag (p.u.)", 
    ylabel="abs(Q)/abs(Q limit)"
    )
plot!(
    gen_voltage_mag_adjusted, 
    gen_q_fraction_adjusted, 
    seriestype=:scatter, 
    label="Adjusted"
    )
p3 = plot(
    gen_cap, 
    #gen_q_fraction, 
    seriestype=:scatter,
    title="Capacity", 
    label="Not adjusted",
    yaxis=:log
    #xlabel="Capacity (?)", 
    #ylabel="abs(Q)/abs(Q limit)"
    )
plot!(
    gen_cap_adjusted, 
    #gen_q_fraction_adjusted, 
    seriestype=:scatter, 
    label="Adjusted",
    yaxis=:log
    )
plot(p1, p2, p3, layout = (3, 1), size = (600, 700))

