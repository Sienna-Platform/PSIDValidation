import DataStructures: OrderedDict

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
    #set_bustype!(bus, BusTypes.PQ)
    set_bus!(old_gen, bus)
    add_component!(small_system, old_gen)
    add_component!(small_system, dev, old_gen)
    #set_reactive_power!(old_gen, 0.0)
    total_power = get_active_power(old_gen)
    for l in get_components(PSY.PowerLoad, small_system)
        PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
        set_active_power!(l, total_power/1.8 + 0.1)
    end
    run_powerflow!(small_system)

    return small_system
end

function exchange_device_ib(device_name::String, large_system_file = "PSCAD_240_BUS_EMT/psid_files/system.json", small_system_file = "PSCAD_3bus_EMT/psid_files/system.json")
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

    remove_component!(DynamicInverter{AverageConverter, OuterControl{VirtualInertia, ReactivePowerDroop}, VoltageModeControl, FixedDCSource, KauraPLL, LCLFilter}, small_system, "generator-101-1")
    remove_component!(ThermalStandard, small_system, "generator-101-1")

    add_component!(small_system,
            Source(
                name = "generator-101-1",
                available = true,
                bus = get_component(Bus, small_system, "BUS 1"),
                active_power = 0.1,
                reactive_power = 0.0,
                R_th = 0.0,
                X_th = 0.001,
                internal_voltage = 1.1,
                internal_angle = 0.0,
            )
            )

    total_power = get_active_power(old_gen)
    for l in get_components(PSY.PowerLoad, small_system)
        PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
        set_active_power!(l, total_power/1.8 + 0.1)
    end
    run_powerflow!(small_system)

    return small_system
end

function summary_participation_factors(pf::Dict{String, Dict{Symbol, Array{Float64}}}, eigs::Vector{ComplexF64})
    pf_ord = sort(OrderedDict(pf))
    names = ["λ_$(k)" for k in 1:length(eigs)]
    names = vcat(["Name"], names)
    df = DataFrame([name => [] for name in names])

    for (device, dict_pfs) in pf_ord
        ord_dict_pfs = sort(OrderedDict(dict_pfs))
        for (state, state_pf) in ord_dict_pfs
            row = vcat(device*" "*String(state), round.(state_pf, digits = 8))
            push!(df, row)
        end
    end
    return df
end

function summary_participation_factors(sm::PowerSimulationsDynamics.SmallSignalOutput)
    eigs = sm.eigenvalues
    pf = sm.participation_factors
    return summary_participation_factors(pf, eigs)
end

function summary_eigenvalues(pf::Dict{String, Dict{Symbol, Array{Float64}}}, eigs::Vector{ComplexF64})
    df = summary_participation_factors(pf, eigs)
    df_noname = df[!, 2:end]
    most_associated = Vector{Int}(undef, length(eigs))
    for (ix, col_pfs) in enumerate(eachcol(df_noname))
        most_associated[ix] = findfirst(==(maximum(col_pfs)), col_pfs)
    end
    col_names = ["Most Associated", "Part. Factor", "Real Part", "Imag. Part", "Damping", "Freq [Hz]"]
    df_summary = DataFrame([name => [] for name in col_names])
    for (ix, eig) in enumerate(eigs)
        eig_associated = most_associated[ix]
        state_name = df[ix, "Name"]
        pf_val = df_noname[eig_associated, ix]
        freq_rad = abs(eig)
        damping = - real(eig) / freq_rad
        row = [state_name, pf_val, real(eig), imag(eig), damping, freq_rad / (2pi)]
        push!(df_summary, row)
    end
    return df_summary
end

function summary_eigenvalues(sm::PowerSimulationsDynamics.SmallSignalOutput)
    eigs = sm.eigenvalues
    pf = sm.participation_factors
    return summary_eigenvalues(pf, eigs)
end
