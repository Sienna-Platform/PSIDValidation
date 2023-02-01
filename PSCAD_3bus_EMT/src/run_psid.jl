using Revise
using Logging
using OrdinaryDiffEq
using PowerSystems
using PowerSimulationsDynamics
using Plots
using DataFrames
using Sundials
using CSV
const PSY = PowerSystems

function run_3bus_psid(;
    rawfile = "ThreeBusPSCAD.raw",
    perturbation_type = "LoadStepDown",    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]
    line_to_trip = "BUS 1-BUS 2-i_1",
    line_type = "Dynamic",
    bus_1_device = "fixed_sauerpai",
    bus_2_device = "gfl",
    saveat = 5e-5,
    tspan = (0.0, 10.0),
    ref_bus_number = 101,
    frequency_reference = "ReferenceBus", #["ConstantFrequency, "ConstantFrequency"]
    solver = "Rodas5",
    abstol = 1e-14,
)
    sys = System(joinpath(@__DIR__, "..", "psid_files", rawfile), runchecks = false)

    for l in get_components(PSY.PowerLoad, sys)
        PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
    end

    l = get_component(PSY.PowerLoad, sys, "load1032")
#=     println(l)
    PSY.set_active_power!(l, PSY.get_active_power(l)/2)
    PSY.set_reactive_power!(l, PSY.get_reactive_power(l)/2)
    println(l) =#

    #Different mechanism for adding an ideal source (IB)
    for g in get_components(Generator, sys)
        if get_number(get_bus(g)) == 101
            bus_1_device == "vsm" && add_inv_case78!(sys, g)
            bus_1_device == "droop" && add_inv_darco_droop!(sys, g)
            bus_1_device == "gfl" && add_inv_gfoll!(sys, g)
            bus_1_device == "fixed_classic" && add_dyn_gen_classic!(sys, g)
            bus_1_device == "sauerpai_sexs_gastg_ieeest" && add_sauerpai_sexs_gastg_ieeest!(sys, g)
            bus_1_device == "sauerpai_sexs_gastg_fixed" && add_sauerpai_sexs_gastg_fixed!(sys, g)
            bus_1_device == "sauerpai_sexs_hygov_ieeest" && add_sauerpai_sexs_hygov_ieeest!(sys, g)
            bus_1_device == "sauerpai_sexs_hygov_fixed" && add_sauerpai_sexs_hygov_fixed!(sys, g)
            bus_1_device == "sauerpai_sexs_tgov1_ieeest" && add_sauerpai_sexs_tgov1_ieeest!(sys, g)
            bus_1_device == "sauerpai_sexs_tgov1_fixed" && add_sauerpai_sexs_tgov1_fixed!(sys, g)
            bus_1_device == "fixed_sauerpai" && add_dyn_gen_sauerpai!(sys, g)
            bus_1_device == "ib" && replace_with_source!(sys, g)
        elseif get_number(get_bus(g)) == 102
            bus_2_device == "vsm" && add_inv_case78!(sys, g)
            bus_2_device == "droop" && add_inv_darco_droop!(sys, g)
            bus_2_device == "gfl" && add_inv_gfoll!(sys, g)
            bus_2_device == "fixed_classic" && add_dyn_gen_classic!(sys, g)
            bus_2_device == "sauerpai_sexs_gastg_ieeest" && add_sauerpai_sexs_gastg_ieeest!(sys, g)
            bus_2_device == "sauerpai_sexs_gastg_fixed" && add_sauerpai_sexs_gastg_fixed!(sys, g)
            bus_2_device == "sauerpai_sexs_hygov_ieeest" && add_sauerpai_sexs_hygov_ieeest!(sys, g)
            bus_2_device == "sauerpai_sexs_hygov_fixed" && add_sauerpai_sexs_hygov_fixed!(sys, g)
            bus_2_device == "sauerpai_sexs_tgov1_ieeest" && add_sauerpai_sexs_tgov1_ieeest!(sys, g)
            bus_2_device == "sauerpai_sexs_tgov1_fixed" && add_sauerpai_sexs_tgov1_fixed!(sys, g)
            bus_2_device == "fixed_sauerpai" && add_dyn_gen_sauerpai!(sys, g)
            bus_2_device == "ib" && replace_with_source!(sys, g)
        end
    end

    for b in get_components(Bus, sys)
        if (get_number(b) == ref_bus_number) && (get_bustype(b) == BusTypes.REF)
            @info "Indicated bus is already reference --leaving as is"
        end
        if (get_number(b) !== ref_bus_number) && (get_bustype(b) == BusTypes.REF)
            @warn "Setting the previous reference bus ($(get_number(b))) to PV"
            set_bustype!(b, BusTypes.PV)
        end
        if (get_number(b) == ref_bus_number) && (get_bustype(b) !== BusTypes.REF)
            @warn "Setting the indicated bus ($(get_number(b))) to be the reference bus."
            set_bustype!(b, BusTypes.REF)
        end
    end

    to_json(sys, joinpath(@__DIR__, "..", "psid_files", "system.json"), force = true)

    sys = System(joinpath(@__DIR__, "..", "psid_files", "system.json"))

    if perturbation_type == "LoadStepDown"
        load = get_component(PowerLoad, sys, "load1032")
        perturbation = LoadTrip(0.1, load)
    elseif perturbation_type == "LoadStepUp"
        load = get_component(PowerLoad, sys, "load1032")
        perturbation1 = LoadChange(0.1, load, :P_ref, 1.0)
        perturbation2 = LoadChange(0.1, load, :Q_ref, 0.1)
        perturbation = [perturbation1, perturbation2]
    elseif perturbation_type == "LineTrip"
        perturbation = BranchTrip(0.1, Line, line_to_trip)
    else
        @error "Provided perturbation not found!"
    end

    if line_type == "Dynamic" && perturbation_type == "LineTrip"
        for b in get_components(Line, sys)
            if get_name(b) != line_to_trip
                dyn_branch = PowerSystems.DynamicBranch(b)
                add_component!(sys, dyn_branch)
            end
        end
    elseif line_type == "Dynamic"
        for b in get_components(Line, sys)
            dyn_branch = PowerSystems.DynamicBranch(b)
            add_component!(sys, dyn_branch)
        end
    end

    if frequency_reference == "ReferenceBus"
        if solver == "IDA"
            sim = Simulation!(
                ResidualModel,
                sys,
                pwd(),
                tspan,
                perturbation;
                file_level = Logging.Error,
                frequency_reference = ReferenceBus(),
            )
        elseif solver == "Rodas5"
            sim = Simulation!(
                MassMatrixModel,
                sys,
                pwd(),
                tspan,
                perturbation;
                file_level = Logging.Error,
                frequency_reference = ReferenceBus(),
            )
        else
            @error "invalid solver choice"
        end
    elseif frequency_reference == "ConstantFrequency"
        if solver == "IDA"
            sim = Simulation!(
                ResidualModel,
                sys,
                pwd(),
                tspan,
                perturbation;
                file_level = Logging.Error,
                frequency_reference = ConstantFrequency(),
            )
        elseif solver == "Rodas5"
            sim = Simulation!(
                MassMatrixModel,
                sys,
                pwd(),
                tspan,
                perturbation;
                file_level = Logging.Error,
                frequency_reference = ConstantFrequency(),
            )
        else
            @error "invalid solver choice"
        end
    else
        @error "invalid input for frequency_reference"
    end

    ss = small_signal_analysis(sim)
    display(sort(summary_eigenvalues(ss), 5))
    display(summary_participation_factors(ss))
    display(ss.eigenvalues)
    if ss.stable == false
        @error "System is not small-signal stable"
        display(ss.eigenvalues)
        @assert ss.stable
    end

    if solver == "IDA"
        execute!(sim, IDA(), saveat = saveat, abstol = abstol) #dtmax = 1e-5,
    elseif solver == "Rodas5"
        execute!(sim, Rodas5(), saveat = saveat, abstol = abstol) #dtmax = 1e-5,
    end

    result_psid = read_results(sim)
    #show_states_initial_value(result_psid)
    display(sys)
    return sys, result_psid
end

function record_3bus_psid(
    result_psid;
    recorded_voltages = [101, 102, 103],   # Bus numbers to record voltage  
    recorded_states = [], #[("generator-101-1", :θ_pll)]
    recorded_P = ["generator-102-1"],
    recorded_Q = ["generator-102-1"],
    recorded_ω = ["generator-102-1"],
    output_csv_name = "psid_sauerpai_sauerpai",
)
    df = DataFrame()
    df[!, "time"] = get_voltage_magnitude_series(result_psid, 101)[1]
    for v in recorded_voltages
        df[!, string("V_", v)] = get_voltage_magnitude_series(result_psid, v)[2]
    end
    for s in recorded_states
        df[!, string(s[1], s[2])] = get_state_series(result_psid, s)[2]
    end
    for p in recorded_P
        df[!, string("P_", p)] = get_activepower_series(result_psid, p)[2]
    end
    for q in recorded_Q
        df[!, string("Q_", q)] = get_reactivepower_series(result_psid, q)[2]
    end
    for ω in recorded_ω
        df[!, string("ω_", ω)] = get_frequency_series(result_psid, ω)[2]
    end

    open(joinpath(@__DIR__, "..", "psid_files", string(output_csv_name, ".csv")), "w") do io
        CSV.write(io, df)
    end
end

#result_psid = run_3bus_psid()
#record_3bus_psid(result_psid)
