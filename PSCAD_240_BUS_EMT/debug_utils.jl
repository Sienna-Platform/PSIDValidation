function exchange_device(device_name::String, large_system_file = "PSCAD_240_BUS_EMT/psid_files/system.json", small_system_file = "PSCAD_3bus_EMT/psid_files/system.json")
    small_system = System(small_system_file)
    large_system = System(large_system_file)

    dev = first(get_components(PSY.DynamicInjection, large_system, x -> get_name(x) == device_name))
    old_gen = first(get_components(PSY.Generator, large_system, x -> get_name(x) == device_name))
    remove_component!(typeof(dev), large_system, device_name)
    remove_component!(typeof(old_gen), large_system, device_name)

    remove_component!(DynamicInverter{AverageConverter, OuterControl{ActivePowerDroop, ReactivePowerDroop}, VoltageModeControl, FixedDCSource, FixedFrequency, LCLFilter}, small_system, "generator-102-1")
    remove_component!(ThermalStandard, small_system, "generator-102-1")
    bus = get_component(Bus, small_system, "BUS 2")
    set_bus!(old_gen, bus)
    add_component!(small_system, old_gen)
    add_component!(small_system, dev, old_gen)

    total_power = get_active_power(old_gen)
    for l in get_components(PSY.PowerLoad, small_system)
        PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
        set_active_power!(l, total_power/3.0 + 0.1)
    end
    run_powerflow!(small_system)

    return small_system
end
