using PowerSystems

const sys_frequency = 2.0 * π * 60.0
const device_mapping = Dict(
    "B" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "C" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "CE" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "CG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "DG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "DP" => (RenewableFix, PrimeMovers.PVe, missing),
    "E" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "EG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "G" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "H" => (HydroDispatch, PrimeMovers.HY, missing),
    "MG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "N" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "NB" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "ND" => (Source, missing, missing), # DC Source
    "NE" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.NATURAL_GAS),
    "NG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "NH" => (HydroDispatch, PrimeMovers.HY, missing),
    "NN" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "NP" => (HydroPumpedStorage, PrimeMovers.HY, missing),
    "NW" => (RenewableDispatch, PrimeMovers.WT, missing),
    "P" => (HydroPumpedStorage, PrimeMovers.HY, missing),
    "R" => (ThermalStandard, PrimeMovers.IC, ThermalFuels.DISTILLATE_FUEL_OIL),
    "RG" => (ThermalStandard, PrimeMovers.IC, ThermalFuels.NATURAL_GAS),
    "S" => (RenewableDispatch, PrimeMovers.PVe, missing),
    "SC" => (ThermalStandard, PrimeMovers.OT, ThermalFuels.OTHER),
    "SG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "SH" => (HydroDispatch, PrimeMovers.HY, missing),
    "SW" => (RenewableDispatch, PrimeMovers.WT, missing),
    "TG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "W" => (RenewableDispatch, PrimeMovers.WT, missing),
    "WG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
)

const SPLIT_BUSES = [
    1032
    1034
    1131
    1232
    1331
    1333
    1431
    2030
    2130
    2233
    2438
    3133
    3135
    3234
    3333
    3531
    3631
    3931
    3933
    4031
    4035
    4039
    4131
    4132
    4231
    4232
    5031
    5032
    6132
    6231
    6235
    6335
    6433
    6533
    7031
    7032
    8034
]

const DANGLING_BUSES = [
    "B1131_CORONADO",
    "B1232_NAVAJO_2",
    "B1331_HOOVER",
    "B2030_MEXICO",
    "B2233_MISSION",
    "B3135_POTRERO",
    "B3333_METCALF",
    "B3531_FULTON",
    "B3631_HUMBOLDT",
    "B3931_ROUND_MT"
]

######################################
############ Generators ##############
######################################

######## Machine Data #########
function make_dynamic_gen(gen::DynamicGenerator{RoundRotorQuadratic, T, U, V, W}) where {T, U, V, W}
    old_machine = get_machine(gen)
    new_machine =  SauerPaiMachine(
            max(get_R(old_machine), 0.008),
            get_Xd(old_machine),
            get_Xq(old_machine),
            get_Xd_p(old_machine),
            get_Xq_p(old_machine),
            get_Xd_pp(old_machine),
            get_Xd_pp(old_machine), # Field corresponds to Xq_pp, we assume the same value
            get_Xl(old_machine),
            get_Td0_p(old_machine),
            get_Tq0_p(old_machine),
            get_Td0_pp(old_machine),
            get_Tq0_pp(old_machine),
            )


    new_shaft = deepcopy(get_shaft(gen))
    gens_require_damping = ["generator-5032-C", "generator-5032-G", "generator-4031-G"]
    if get_name(gen) ∈ gens_require_damping
        set_D!(new_shaft, 2.0)
    else
        set_D!(new_shaft, max(0.1, get_D(new_shaft)))
    end
    return DynamicGenerator(
            get_name(gen),
            get_ω_ref(gen),
            new_machine,
            new_shaft,
            deepcopy(get_avr(gen)),
            deepcopy(get_prime_mover(gen)),
            get_name(gen) == "generator-5032-C" ? get_pss(gen) : PSSFixed(0.0),
            get_base_power(gen),
    )
end

function make_dynamic_gen(gen::DynamicGenerator{RoundRotorQuadratic, T, V, HydroTurbineGov, W}) where {T, V, W}
    old_machine = get_machine(gen)
    new_machine =  SauerPaiMachine(
            max(get_R(old_machine), 0.025),
            get_Xd(old_machine),
            get_Xq(old_machine),
            get_Xd_p(old_machine),
            get_Xq_p(old_machine),
            get_Xd_pp(old_machine),
            get_Xd_pp(old_machine), # Field corresponds to Xq_pp, we assume the same value
            get_Xl(old_machine),
            get_Td0_p(old_machine),
            get_Tq0_p(old_machine),
            get_Td0_pp(old_machine),
            get_Tq0_pp(old_machine),
            )


    new_shaft = deepcopy(get_shaft(gen))
    set_D!(new_shaft, 2.0)
    return DynamicGenerator(
            get_name(gen),
            get_ω_ref(gen),
            new_machine,
            new_shaft,
            deepcopy(get_avr(gen)),
            deepcopy(get_prime_mover(gen)),
            get_name(gen) == "generator-4131-H" ? get_pss(gen) : PSSFixed(0.0),
            get_base_power(gen),
    )
end

######################################
############# Inverters ##############
######################################

###### Converter Data ######
const converter_base_voltage = 690.0
const converter_base_power = 2.75*1e6
const converter_base_current = (1/sqrt(3))*converter_base_power/converter_base_voltage
const converter_base_impedance = converter_base_voltage/converter_base_current
const converter_base_inductance = converter_base_impedance/(2*π*50.0)
const converter_base_capacitance = 1/((2*π*50.0)*(converter_base_impedance))
const converter_current_voltage_ratio = converter_base_current/converter_base_voltage
const converter_voltage_current_ratio = converter_base_voltage/converter_base_current

const gfl_converter_base_voltage = 18.0*1e3
const gfl_converter_base_power = 200*1e6
const gfl_converter_base_current = (1/sqrt(3))*gfl_converter_base_power/gfl_converter_base_voltage
const gfl_converter_base_impedance = gfl_converter_base_voltage/gfl_converter_base_current
const gfl_converter_base_inductance = gfl_converter_base_impedance/(2*π*60.0)
const gfl_converter_base_capacitance = 1/((2*π*60.0)*(gfl_converter_base_impedance))
const gfl_converter_current_voltage_ratio = gfl_converter_base_current/gfl_converter_base_voltage
const gfl_converter_voltage_current_ratio = gfl_converter_base_voltage/gfl_converter_base_current

converter() = AverageConverter(rated_voltage = converter_base_voltage, rated_current = 1.1*converter_base_current)

###### DC Source Data ######
dc_source() = FixedDCSource(voltage = 600.0) #Not in the original data, guessed.

###### Filter Data ######

function filt(device_base_power::Float64, device_base_voltage::Float64)
    device_base_current = (1/sqrt(3))*device_base_power/device_base_voltage
    device_base_impedance = device_base_voltage/device_base_current
    device_base_inductance = device_base_impedance/(sys_frequency)
    device_base_capacitance =  1/((sys_frequency)*(device_base_impedance))

    impedance_ratio = converter_base_impedance/device_base_impedance
    inductance_ratio = converter_base_inductance/device_base_inductance
    capacitance_ratio = converter_base_capacitance/device_base_capacitance
    @assert impedance_ratio < 1e6
    @assert inductance_ratio < 1e6
    @assert capacitance_ratio < 1e6 device_base_impedance
    return LCLFilter(lf = 0.08, #*inductance_ratio,
                     rf = 0.003, #*impedance_ratio,
                     cf = 0.074, #*capacitance_ratio,
                     lg = 0.2, #*inductance_ratio,
                     rg = 0.01, #*impedance_ratio
                     )
end

function filt_gfoll(device_base_power::Float64, device_base_voltage::Float64)
    device_base_current = (1/sqrt(3))*device_base_power/device_base_voltage
    device_base_impedance = device_base_voltage/device_base_current
    device_base_inductance = device_base_impedance/(sys_frequency)
    device_base_capacitance =  1/((sys_frequency)*(device_base_impedance))

    impedance_ratio = gfl_converter_base_impedance/device_base_impedance
    inductance_ratio = gfl_converter_base_inductance/device_base_inductance
    capacitance_ratio = gfl_converter_base_capacitance/device_base_capacitance

    return LCLFilter(
        lf = 0.08, #*inductance_ratio,
        rf = 0.003, #*impedance_ratio,
        cf = 0.074, #*capacitance_ratio,
        lg = 0.2, #*inductance_ratio,
        rg = 0.01, #*impedance_ratio
        )
end

###### PLL Data ######
pll() = KauraPLL(
    ω_lp = (10.0/(2*π))*sys_frequency, #Cut-off frequency for LowPass filter of PLL filter.
    kp_pll = 0.084,  #PLL proportional gain
    ki_pll = 4.69,   #PLL integral gain
)

reduced_pll() = ReducedOrderPLL(
    ω_lp = 1.32*sys_frequency, # *sys_frequency,
    kp_pll = 0.4,  #PLL proportional gain
    ki_pll = 4.69,   #PLL integral gain
)

no_pll() = FixedFrequency()

###### Outer Control ######
function outer_control()
    function virtual_inertia()
        return VirtualInertia(Ta = 2.0, kd = 400.0, kω = 20.0)
    end
    function reactive_droop()
        return ReactivePowerDroop(kq = 0.2, ωf = 1000.0)
    end
    return OuterControl(virtual_inertia(), reactive_droop())
end

function outer_control_droop()
    function active_droop()
        return ActivePowerDroop(Rp = 0.05, ωz = 0.1 * sys_frequency)
    end
    function reactive_droop()
        return ReactivePowerDroop(kq = 0.2, ωf = 1000.0)
    end
    return OuterControl(active_droop(), reactive_droop())
end

function outer_control_gfoll()
    function active_pi()
        return ActivePowerPI(Kp_p = 1.5, Ki_p = 20.90, ωz = 0.132 * sys_frequency)
    end
    function reactive_pi()
        return ReactivePowerPI(Kp_q = 1.5, Ki_q = 20.90, ωf = 0.132 * sys_frequency)
    end
    return OuterControl(active_pi(), reactive_pi())
end


######## Inner Control ######
function inner_control(device_base_power::Float64, device_base_voltage::Float64)

    device_base_current = (1/sqrt(3))*device_base_power/device_base_voltage
    device_base_impedance = device_base_voltage^2/device_base_power
    device_base_inductance = device_base_impedance/(sys_frequency)
    device_current_voltage_ratio = device_base_current/device_base_voltage
    device_voltage_current_ratio = device_base_voltage/device_base_current

    impedance_ratio = converter_base_impedance/device_base_impedance
    inductance_ratio = converter_base_inductance/device_base_inductance # Frequencies don't match so this is needed
    kpc_ratio = converter_voltage_current_ratio/device_voltage_current_ratio
    kpv_ratio = converter_current_voltage_ratio/device_current_voltage_ratio

    return VoltageModeControl(
        kpv = 0.59, #*kpv_ratio,     #Voltage controller proportional gain
        kiv = 736.0, #*kpv_ratio,    #Voltage controller integral gain
        kffv = 0.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
        rv = 0.0, #*impedance_ratio, #Virtual resistance in pu
        lv = 0.2, #*inductance_ratio, #Virtual inductance in pu
        kpc = 1.27, #*kpc_ratio,     #Current controller proportional gain
        kic = 14.3, #*kpc_ratio,     #Current controller integral gain
        kffi = 0.0,     #Binary variable enabling the current feed-forward in output of current controllers
        ωad = (1/(2*π)), #*sys_frequency,     #Active damping low pass filter cut-off frequency
        kad = 0.2,
    )
end

function current_mode_inner(device_base_power::Float64, device_base_voltage::Float64)
    device_base_current = (1/sqrt(3))*device_base_power/device_base_voltage
    device_voltage_current_ratio = device_base_voltage/device_base_current
    kpc_ratio = converter_voltage_current_ratio/device_voltage_current_ratio

    return CurrentModeControl(
        kpc = 4.0, #*kpc_ratio,     #Current controller proportional gain
        kic = 410.0, #*kpc_ratio,     #Current controller integral gain
        kffv = 0.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
    )

end

function update_inverter_to_vsm(static_device)
    base_power = get_base_power(static_device)*1e6
    base_voltage = get_base_voltage(get_bus(static_device))*1e3
    return DynamicInverter(
        name = get_name(static_device),
        ω_ref = 1.0, # ω_ref,
        converter = converter(), #converter
        outer_control = outer_control(), #outer control
        inner_control = inner_control(base_power, base_voltage), #inner control voltage source
        dc_source = dc_source(), #dc source
        freq_estimator = pll(), #pll
        filter = filt(base_power, base_voltage), #filter
    )
end

function update_inverter_to_droop(static_device)
    base_power = get_base_power(static_device)*1e6
    base_voltage = get_base_voltage(get_bus(static_device))*1e3
    return DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter(), #converter
        outer_control_droop(), #outercontrol
        inner_control(base_power, base_voltage), #inner_control
        dc_source(),
        no_pll(),
        filt(base_power, base_voltage),
    )
end

function update_inverter_to_grid_following(static_device)
    base_power = get_base_power(static_device)*1e6
    base_voltage = get_base_voltage(get_bus(static_device))*1e3
    return DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter(), #converter
        outer_control_gfoll(), #outercontrol
        current_mode_inner(base_power, base_voltage), #inner_control
        dc_source(),
        reduced_pll(),
        filt_gfoll(base_power, base_voltage),
    )
end

function update_gen_to_machine_sauerpai(sys, static_device::ThermalStandard)
    old_dyn_device = get_dynamic_injector(static_device)
    remove_component!(typeof(old_dyn_device), sys, get_name(old_dyn_device))
    new_dyn_device = make_dynamic_gen(old_dyn_device)
    add_component!(sys, new_dyn_device, static_device)
    active_power = min(get_active_power(static_device), get_max_active_power(static_device))
    set_active_power!(static_device, active_power)
    return
end

function update_gen_data(g::ThermalStandard, sys, ::Type{ThermalStandard}, pm, fuel)
    set_prime_mover!(g, pm)
    set_fuel!(g, fuel)
    update_gen_to_machine_sauerpai(sys, g)
    return
end

function update_gen_data(g::ThermalStandard, sys, ::Type{HydroDispatch}, pm, fuel::Missing)
    old_dyn_device = get_dynamic_injector(g)
    new_dyn_device = make_dynamic_gen(old_dyn_device)
    new_gen = HydroDispatch(
        name = get_name(g),
        available = get_available(g),
        bus = get_bus(g),
        active_power = min(get_active_power(g), get_max_active_power(g)*0.9),
        reactive_power = get_reactive_power(g),
        rating = get_rating(g),
        prime_mover = pm,
        active_power_limits = get_active_power_limits(g),
        reactive_power_limits = get_reactive_power_limits(g),
        ramp_limits = get_ramp_limits(g),
        time_limits = get_time_limits(g),
        base_power = get_base_power(g),
    )
    remove_component!(typeof(old_dyn_device), sys, get_name(old_dyn_device))
    remove_component!(ThermalStandard, sys, get_name(g))
    add_component!(sys, new_gen)
    add_component!(sys, new_dyn_device, new_gen)
    return
end

function update_gen_data(g::ThermalStandard, sys, ::Type{HydroPumpedStorage}, pm, fuel::Missing)
    old_dyn_device = get_dynamic_injector(g)
    new_dyn_device = make_dynamic_gen(old_dyn_device)
    new_gen = HydroPumpedStorage(
        name = get_name(g),
        available = get_available(g),
        bus = get_bus(g),
        rating_pump = -1.0*get_active_power_limits(g).min,
        active_power = min(get_active_power(g) + 0.03, get_max_active_power(g)*0.9),
        reactive_power = get_reactive_power(g),
        rating = get_rating(g),
        prime_mover = pm,
        active_power_limits = (min = 0.0, max = get_active_power_limits(g).max),
        active_power_limits_pump = (min = 0.0, max = -1*get_active_power_limits(g).min),
        reactive_power_limits = get_reactive_power_limits(g),
        reactive_power_limits_pump = get_reactive_power_limits(g),
        ramp_limits_pump = (up = 1.0, down = 1.0),
        time_limits_pump = (up = 100.0, down = 100.0),
        ramp_limits = get_ramp_limits(g),
        time_limits = get_time_limits(g),
        base_power = get_base_power(g),
        storage_capacity = (up = get_active_power_limits(g).max, down = get_active_power_limits(g).max*300.0),
        inflow = 0.5,
        outflow = 0.0,
        initial_storage = (up = 0.5, down = 0.5)
    )
    remove_component!(typeof(old_dyn_device), sys, get_name(old_dyn_device))
    remove_component!(ThermalStandard, sys, get_name(g))
    add_component!(sys, new_gen)
    add_component!(sys, new_dyn_device, new_gen)
    return
end

const control_map = Dict(
    "vsm" => update_inverter_to_vsm,
    "droop" => update_inverter_to_droop,
    "gfl" => update_inverter_to_grid_following,
)

function update_gen_data(g::ThermalStandard, sys::System, ::Type{Source}, ::Missing, ::Missing)
    old_dyn_device = get_dynamic_injector(g)
    remove_component!(typeof(old_dyn_device), sys, get_name(old_dyn_device))
    remove_component!(sys, g)
    new_source = Source(
        name = get_name(g),
        available = get_available(g),
        bus = get_bus(g),
        active_power = min(get_active_power(g), get_max_active_power(g)*0.9),
        reactive_power = get_reactive_power(g),
        R_th = 0.0,
        X_th = 0.001,
        internal_voltage = 1.1,
        internal_angle = 0.0,
    )
    add_component!(sys, new_source)
end

function update_gen_data(g::ThermalStandard, sys::System, ::Type{RenewableDispatch}, pm, fuel::Missing)
    old_dyn_device = get_dynamic_injector(g)
    remove_component!(typeof(old_dyn_device), sys, get_name(old_dyn_device))
    remove_component!(sys, g)
    for control_type in ["vsm", "droop", "gfl"]
        base_power = get_base_power(g)
        if base_power < 1.1
            continue
        end
        new_gen = RenewableDispatch(
            name = join(push!(split(get_name(g), "-"), control_type), "-"),
            available = control_type == "droop" ? get_available(g) : false,
            bus = get_bus(g),
            active_power = get_active_power(g),
            reactive_power = get_reactive_power(g),
            rating = get_rating(g),
            prime_mover = pm,
            reactive_power_limits = get_reactive_power_limits(g),
            power_factor = sin(atan(get_active_power(g), get_reactive_power(g))),
            base_power = base_power,
            operation_cost = TwoPartCost(nothing)
        )
        add_component!(sys, new_gen)
        add_component!(sys, control_map[control_type](new_gen), new_gen)
    end
end

function update_gen_data(g::ThermalStandard, sys::System, ::Type{RenewableFix}, pm, fuel::Missing)
    old_dyn_device = get_dynamic_injector(g)
    remove_component!(typeof(old_dyn_device), sys, get_name(old_dyn_device))
    remove_component!(sys, g)
    base_power = get_base_power(g)
    if base_power < 1.1
        return
    end
    control_type = "gfl"
    if get_name(g) in ["generator-3923-DP", "generator-6401-DP"]
        control_type = "droop"
        new_gen = RenewableDispatch(
            name = join(push!(split(get_name(g), "-"), control_type), "-"),
            available = get_available(g),
            bus = get_bus(g),
            active_power = get_active_power(g),
            reactive_power = get_reactive_power(g),
            rating = get_rating(g),
            prime_mover = pm,
            reactive_power_limits = (min = -0.1, max = 0.1),
            power_factor = cos(atan(get_active_power(g), abs(get_reactive_power(g)))),
            base_power = base_power,
            operation_cost = TwoPartCost(nothing)
        )
        add_component!(sys, new_gen)
        add_component!(sys, control_map[control_type](new_gen), new_gen)
        return
    end
    new_gen = RenewableFix(
        name = join(push!(split(get_name(g), "-"), control_type), "-"),
        available = get_available(g),
        bus = get_bus(g),
        active_power = get_active_power(g),
        reactive_power = get_reactive_power(g),
        rating = get_rating(g),
        prime_mover = pm,
        power_factor = cos(atan(get_active_power(g), abs(get_reactive_power(g)))),
        base_power = base_power,
    )
    add_component!(sys, new_gen)
    add_component!(sys, control_map[control_type](new_gen), new_gen)
    return
end

function update_generation_units!(sys::System)
    for g in get_components(ThermalStandard, sys)
        gen_type = split(get_name(g), "-")[3]
        gen_cat = device_mapping[gen_type]
        update_gen_data(g, sys, gen_cat...)
    end
    return
end

function _find_area(num::Int)::Int
    n = round(Int, num / (10^3))
    return n
end

function get_next_bus_number(bus_numbers::Vector{Int}, current_bus::Int)
    area = _find_area(current_bus) + 1
    return maximum(bus_numbers[findall(x -> x < area*1000, bus_numbers)]) + 1
end

function get_bus_transformer(sys::System, bus::Bus)
    xtr = get_components(Transformer2W, sys, x -> get_arc(x).to == bus)
    if isempty(xtr)
        xtr = get_components(Transformer2W, sys, x -> get_arc(x).from == bus)
    end

    if isempty(xtr)
        error("xtr for bus $(get_name(bus)) not found")
    end
    if length(xtr) == 1
        return first(xtr)
    else
        error("more than one xtr for bus $(get_name(bus))")
    end
end

function _split_generation_units(sys::System, bus_number::Int)
    th = get_components(ThermalStandard, sys, x -> get_number(get_bus(x)) == bus_number)
    hy = get_components(HydroGen, sys, x -> get_number(get_bus(x)) == bus_number)
    machines = Iterators.flatten((th, hy))
    bus_numbers = get_number.(get_components(Bus, sys))
    bus = first(get_components(Bus, sys, x -> get_number(x) == bus_number))
    xfr = get_bus_transformer(sys, bus)
    for gen in machines
        dyn_gen = get_dynamic_injector(gen)
        bus = get_bus(gen)
        next_bus_number = get_next_bus_number(bus_numbers, get_number(bus))
        push!(bus_numbers, next_bus_number)
        remove_component!(sys, dyn_gen)
        remove_component!(sys, gen)
        unit_type = split(get_name(gen), "-")[end]
        new_bus = Bus(
            name = "B$(next_bus_number)_$unit_type",
            number = next_bus_number,
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
        set_name!(gen, "generator-$(next_bus_number)-$unit_type")
        set_name!(dyn_gen, "generator-$(next_bus_number)-$unit_type")
        add_component!(sys, gen)
        add_component!(sys, dyn_gen, gen)
        new_xfr = Transformer2W(
            name = "B$(get_number(get_arc(xfr).from))_$(get_name(get_arc(xfr).from))-B$(next_bus_number)_$(get_name(bus))_$unit_type-i_1",
            available = true,
            active_power_flow = get_active_power(gen),
            reactive_power_flow = get_reactive_power(gen),
            arc = Arc(from = get_arc(xfr).from, to = new_bus),
            r = get_x(xfr)*2/10,
            x = get_x(xfr)*2,
            primary_shunt = 0.0,
            rate = get_base_power(gen)*1.1,
        )
        add_component!(sys, new_xfr)
    end
    set_magnitude!(bus, get_magnitude(bus)*0.96)
    return
end

function split_generation_units(sys::System)
    for b in SPLIT_BUSES
        _split_generation_units(sys, b)
    end
    for g in get_components(Generator, sys, x -> get_number(get_bus(x)) == 3933)
        new_inj = deepcopy(get_dynamic_injector(g))
        new_inj.internal = PSY.IS.InfrastructureSystemsInternal()
        new_g = deepcopy(g)
        new_g.time_series_container = PSY.IS.TimeSeriesContainer()
        new_g.internal = PSY.IS.InfrastructureSystemsInternal()
        set_dynamic_injector!(new_g, nothing)
        set_name!(new_g, "$(get_name(new_g))_2")
        set_name!(new_inj, get_name(new_g))
        set_bus!(new_g, get_bus(g))
        add_component!(sys, new_g)
        add_component!(sys, new_inj, new_g)
    end
    return
end

function _remove_dangling_buses(sys::System, bus_name::String)
    bus = get_component(Bus, sys, bus_name)
    xfr = get_bus_transformer(sys, bus)
    remove_component!(sys, xfr)
    remove_component!(sys, get_arc(xfr))
    remove_component!(sys, bus)
    return
end


function remove_dangling_buses(sys::System)
    for b in DANGLING_BUSES
        _remove_dangling_buses(sys, b)
    end
    return
end
