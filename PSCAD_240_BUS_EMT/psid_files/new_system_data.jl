using PowerSystems

######################################
############ Generators ##############
######################################

######## Machine Data #########
function update_gen_to_machine_sauerpai(gen::DynamicGenerator{RoundRotorQuadratic, T, U, V, W}) where {T, U, V, W}
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
    ω_lp = 1.32 * 2 * pi * 50, #Cut-off frequency for LowPass filter of PLL filter.
    kp_pll = 20.0,  #PLL proportional gain
    ki_pll = 200.0,   #PLL integral gain
)

no_pll() = PSY.FixedFrequency()

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
        return PSY.ActivePowerDroop(Rp = 0.05, ωz = 2 * pi * 5)
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
        return PSY.ActiveVirtualOscillator(k1 = 0.0033, ψ = pi / 4)
    end
    function reactive_voc()
        return PSY.ReactiveVirtualOscillator(k2 = 0.0796)
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

function update_inverter_to_vsm(sys, static_device)
    dyn_device = DynamicInverter(
        name = get_name(static_device),
        ω_ref = 1.0, # ω_ref,
        converter = converter_high_power(), #converter
        outer_control = outer_control(), #outer control
        inner_control = inner_control(), #inner control voltage source
        dc_source = dc_source_lv(), #dc source
        freq_estimator = pll(), #pll
        filter = filt(), #filter
    )
    add_component!(sys, dyn_device, static_device)
    return
end

function update_inverter_to_droop(sys, static_device)
    dyn_device = PSY.DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter_low_power(), #converter
        outer_control_droop(), #outercontrol
        inner_control(), #inner_control
        dc_source_lv(),
        no_pll(),
        filt(),
    ) #pss
    add_component!(sys, dyn_device, static_device)
end

function update_inverter_to_grid_following(sys, static_device)
    dyn_device = PSY.DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter_low_power(), #converter
        outer_control_gfoll(), #outercontrol
        current_mode_inner(), #inner_control
        dc_source_lv(),
        reduced_pll(),
        filt_gfoll(),
    ) #pss
    add_component!(sys, dyn_device, static_device)
end
