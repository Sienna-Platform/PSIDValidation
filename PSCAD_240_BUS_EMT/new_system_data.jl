using PowerSystems

device_mapping = Dict(
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
    "ND" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "NE" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.NATURAL_GAS),
    "NG" => (ThermalStandard, PrimeMovers.CA, ThermalFuels.NATURAL_GAS),
    "NH" => (HydroDispatch, PrimeMovers.HY, missing),
    "NN" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.COAL),
    "NP" => (ThermalStandard, PrimeMovers.ST, ThermalFuels.DISTILLATE_FUEL_OIL),
    "NW" => (RenewableDispatch, PrimeMovers.WT, missing),
    "P" => (ThermalStandard, PrimeMovers.IC, ThermalFuels.DISTILLATE_FUEL_OIL),
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

######################################
############ Generators ##############
######################################

######## Machine Data #########
function make_dynamic_gen(gen::DynamicGenerator{RoundRotorQuadratic, T, U, V, W}) where {T, U, V, W}
    old_machine = get_machine(gen)
    new_machine =  SauerPaiMachine(
            get_R(old_machine),
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
            get_Tq0_pp(old_machine),)

    return DynamicGenerator(
            get_name(gen),
            get_ω_ref(gen),
            new_machine,
            deepcopy(get_shaft(gen)),
            deepcopy(get_avr(gen)),
            deepcopy(get_prime_mover(gen)),
            deepcopy(get_pss(gen)),
            get_base_power(gen),
    )
end

######################################
############# Inverters ##############
######################################

###### Converter Data ######
converter_low_power() = AverageConverter(rated_voltage = 690.0, rated_current = 2.75)

converter_high_power() = AverageConverter(rated_voltage = 138.0, rated_current = 100.0)

###### DC Source Data ######
dc_source_lv() = FixedDCSource(voltage = 600.0) #Not in the original data, guessed.
dc_source_hv() = FixedDCSource(voltage = 1500.0) #Not in the original data, guessed.

###### Filter Data ######
filt() = LCLFilter(lf = 0.08, rf = 0.003, cf = 0.074, lg = 0.2, rg = 0.01)
filt_gfoll() = LCLFilter(lf = 0.009, rf = 0.016, cf = 2.5, lg = 0.002, rg = 0.003)
filt_voc() = LCLFilter(lf = 0.0196, rf = 0.0139, cf = 0.1086, lg = 0.0196, rg = 0.0139)

###### PLL Data ######
pll() = KauraPLL(
    ω_lp = 500.0, #Cut-off frequency for LowPass filter of PLL filter.
    kp_pll = 0.084,  #PLL proportional gain
    ki_pll = 4.69,   #PLL integral gain
)

reduced_pll() = ReducedOrderPLL(
    ω_lp = 1.32 * 2 * pi * 60, #Cut-off frequency for LowPass filter of PLL filter.
    kp_pll = 20.0,  #PLL proportional gain
    ki_pll = 200.0,   #PLL integral gain
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

function outer_control_nopll()
    function virtual_inertia()
        return VirtualInertia(Ta = 2.0, kd = 0.0, kω = 20.0)
    end
    function reactive_droop()
        return ReactivePowerDroop(kq = 0.2, ωf = 1000.0)
    end
    return OuterControl(virtual_inertia(), reactive_droop())
end

function outer_control_droop()
    function active_droop()
        return ActivePowerDroop(Rp = 0.05, ωz = 2 * pi * 5)
    end
    function reactive_droop()
        return ReactivePowerDroop(kq = 0.2, ωf = 1000.0)
    end
    return OuterControl(active_droop(), reactive_droop())
end

function outer_control_gfoll()
    function active_pi()
        return ActivePowerPI(Kp_p = 2.0, Ki_p = 30.0, ωz = 0.132 * 2 * pi * 50)
    end
    function reactive_pi()
        return ReactivePowerPI(Kp_q = 2.0, Ki_q = 30.0, ωf = 0.132 * 2 * pi * 50.0)
    end
    return OuterControl(active_pi(), reactive_pi())
end

function outer_voc()
    function active_voc()
        return ActiveVirtualOscillator(k1 = 0.0033, ψ = pi / 4)
    end
    function reactive_voc()
        return ReactiveVirtualOscillator(k2 = 0.0796)
    end
    return OuterControl(active_voc(), reactive_voc())
end

######## Inner Control ######
inner_control() = VoltageModeControl(
    kpv = 0.59,     #Voltage controller proportional gain
    kiv = 736.0,    #Voltage controller integral gain
    kffv = 0.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
    rv = 0.0,       #Virtual resistance in pu
    lv = 0.2,       #Virtual inductance in pu
    kpc = 1.27,     #Current controller proportional gain
    kic = 14.3,     #Current controller integral gain
    kffi = 0.0,     #Binary variable enabling the current feed-forward in output of current controllers
    ωad = 50.0,     #Active damping low pass filter cut-off frequency
    kad = 0.2,
)

current_mode_inner() = CurrentModeControl(
    kpc = 0.37,     #Current controller proportional gain
    kic = 0.7,     #Current controller integral gain
    kffv = 1.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
)

function update_inverter_to_vsm(static_device)
    return DynamicInverter(
        name = get_name(static_device),
        ω_ref = 1.0, # ω_ref,
        converter = converter_high_power(), #converter
        outer_control = outer_control(), #outer control
        inner_control = inner_control(), #inner control voltage source
        dc_source = dc_source_lv(), #dc source
        freq_estimator = pll(), #pll
        filter = filt(), #filter
    )
end

function update_inverter_to_droop(static_device)
    return DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter_low_power(), #converter
        outer_control_droop(), #outercontrol
        inner_control(), #inner_control
        dc_source_lv(),
        no_pll(),
        filt(),
    )
end

function update_inverter_to_grid_following(static_device)
    return DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter_low_power(), #converter
        outer_control_gfoll(), #outercontrol
        current_mode_inner(), #inner_control
        dc_source_lv(),
        reduced_pll(),
        filt_gfoll(),
    )
end

function update_gen_to_machine_sauerpai(sys, static_device::ThermalStandard)
    old_dyn_device = get_dynamic_injector(static_device)
    remove_component!(typeof(old_dyn_device), sys, get_name(old_dyn_device))
    new_dyn_device = make_dynamic_gen(old_dyn_device)
    add_component!(sys, new_dyn_device, static_device)
end

function update_gen_data(g::ThermalStandard, sys, ::Type{ThermalStandard}, pm, fuel)
    set_prime_mover!(g, pm)
    set_fuel!(g, fuel)
    update_gen_to_machine_sauerpai(sys, g)
end

function update_gen_data(g::ThermalStandard, sys, ::Type{HydroDispatch}, pm, fuel::Missing)
    old_dyn_device = get_dynamic_injector(g)
    new_dyn_device = make_dynamic_gen(old_dyn_device)
    new_gen = HydroDispatch(
        name = get_name(g),
        available = get_available(g),
        bus = get_bus(g),
        active_power = get_active_power(g),
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

control_map = Dict(
    "vsm" => update_inverter_to_vsm,
    "droop" => update_inverter_to_droop,
    "gfl" => update_inverter_to_grid_following,
)

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
    new_gen = RenewableFix(
        name = join(push!(split(get_name(g), "-"), control_type), "-"),
        available = get_available(g),
        bus = get_bus(g),
        active_power = get_active_power(g),
        reactive_power = get_reactive_power(g),
        rating = get_rating(g),
        prime_mover = pm,
        power_factor = 1.0,
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
