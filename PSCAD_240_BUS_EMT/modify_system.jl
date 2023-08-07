# Adapted from modifiy_system.jl

using PowerSystems
using PowerSimulationsDynamics
using PowerFlows
using NLsolve
using CSV
using Plots
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
        @info "Line $(get_name(br)) has voltage  $(get_base_voltage(get_from(get_arc(br)))) and x = $(get_x(br))"
        voltage = get_base_voltage(get_from(get_arc(br)))
        new_r = get_x(br)/(line_params[voltage].xr_ratio[2]) # divide reactance by median x/r ratio to get r value.
        set_r!(br, new_r)
    end
end


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
        push!(df_gens, (name, bus, bool_split, capacity, vmag, vang, p, q, qmin, qmax, qfrac, bool_vmag_violated, bool_vang_violated, bool_q_violated, bool_violated, status))
    end
    return df_gens
end


# --------------------------------------------------------------
# *FOR TESTING* Find a bus with gens close to their Q limit
# --------------------------------------------------------------

# Build dataframe with generator info prior to splitting generators
df_gens_pre_split = build_gen_info_dataframe(sys)

# Show all gens at >0.95 of their reactive power limit
show(sort!(filter(:QFrac => n -> n > 0.95 && n <= 1, df_gens_pre_split[!,[:GenName, :StatusAvailable,:Capacity,:GenBus, :Q, :Qmin, :Qmax,:QFrac]]),:GenBus), allrows=true)
buses_hitting_Q_limit = unique(filter(:QFrac => n -> n > 0.95 && n <= 1, df_gens_pre_split[!,[:GenBus, :QFrac]]).GenBus)

# Show full set of generators for each bus that has one or more gens at/close to their reactive power limit
for bus in buses_hitting_Q_limit
    show(sort!(filter(:GenBus => n -> n == bus, df_gens_pre_split[!,[:GenName, :StatusAvailable,:Capacity,:GenBus, :Q, :Qmin, :Qmax,:QFrac]]), :Capacity, rev=true),allrows=true)
end


# --------------------------------------------------------------
# Split multi-gen buses so each gen has it's own transformer
# --------------------------------------------------------------
##
const MULTI_GEN_BUSES = [
    #4031
    4231
]
bus = get_components(x -> get_number(x) == 4031, Bus, sys)
#bus_xtrs = get_bus_transformer(sys, bus)
println("Mag at 4031 = $(get_magnitude(first(bus)))")
bus = get_components(x -> get_number(x) == 4001, Bus, sys)
println("Mag at 4001 = $(get_magnitude(first(bus)))")

##

bus_numbers = get_number.(get_components(Bus, sys))
for b in MULTI_GEN_BUSES
    
    # Get info about the bus this generator is attached to
    buses = get_components(x -> get_number(x) == b, Bus, sys)
    if length(buses) == 1
        bus = first(buses)
    end # TODO: add error handling
    bus_xfr = get_bus_transformer(sys, bus)

    # Loop through all generator components attached to bus b
    th = get_components(x -> get_number(get_bus(x)) == b, ThermalStandard, sys)
    number_of_gens_at_bus = length(th)
    for g in th

        # ------------------ CREATE NEW BUS

        # Get the generator info we need for the new bus
        unit_type = split(get_name(g), "-")[end]
        pv_setpoint = 1 # TODO: CHANGE THIS VALUE, maybe to get_magnitude(g)

        # Get next un-used bus number to assign to the new bus we will create for this generator 
        next_bus_number = get_next_bus_number(bus_numbers, b) # Q: may want to look over how get_next_bus_number works
        push!(bus_numbers, next_bus_number)
        
        # Create new bus for this individual generator
        new_bus = Bus(
            name = "B$(next_bus_number)_$unit_type", # Q: are the buses always labeled by the generator type...?
            number = next_bus_number,
            bustype = "PV",
            angle = get_angle(bus),
            magnitude = pv_setpoint,
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
        dyn_gen = get_dynamic_injector(g)
        remove_component!(sys, dyn_gen)
        remove_component!(sys, g)

        # Update generator component parameters before adding it back into the system
        set_bus!(g, new_bus) # Q: I think g is still the same object, just not attached?
        @info "setting gen name generator-$(next_bus_number)-$unit_type"
        set_name!(g, "generator-$(next_bus_number)-$unit_type")

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
            r = get_r(bus_xfr), #MULTIPLY BY 2?
            x = get_x(bus_xfr), #MULTIPLY BY 2?
            primary_shunt = 0.0,
            rate = get_base_power(g)*1.1,
        )

        # Add new transformer to system
        @info "adding transformer $(get_name(new_xfr))"
        add_component!(sys, new_xfr)
        
    end

    # Change old bus to PQ bus since it no longer has any gens attached to it
    # TODO: this allows powerflow to solve, but figure out if there is anything else we need to change
    set_bustype!(bus, "PQ")

    # After adding the new transformers, adjust (or delete?) original transformer
    # TODO: decide this after confirming the subtransmission issue

end


##
# Re-solve powerflow with new topology
solve_powerflow!(sys)


# --------------------------------------------------------------
# *FOR TESTING* Look at reactive power after splitting bus
# --------------------------------------------------------------

# Build dataframe with generator info after to splitting generators
df_gens_post_split = build_gen_info_dataframe(sys)

# Create plotting dataframe with Qpre-Qpost to interpret reactive power changes
df_plot = leftjoin(df_gens_pre_split[!,[:GenName,:Q]], df_gens_post_split[!,[:GenName, :Q]], on = :GenName, makeunique=true)
df_plot = insertcols!(df_plot, :QDiff => df_plot.Q - df_plot.Q_1)
show(sort!(df_plot, :QDiff, rev=true), allrows=true)
p1 = plot(
    df_plot[!, :GenName], # convert radians to degrees
    df_plot[!, :QDiff], 
    seriestype=:scatter, 
    title="Difference in Q pre/post bus split",
    xlabel="GenName", 
    ylabel="Q_pre - Q_post"
    )

# --------------------------------------------------------------
# Plot impedances of zero resistance lines.
# --------------------------------------------------------------
#=
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

=#