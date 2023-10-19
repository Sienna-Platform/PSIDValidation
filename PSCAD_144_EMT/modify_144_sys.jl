using PowerSystems
using Random
using PowerSimulationsDynamics
using Sundials
using Logging
using PowerFlows

sys = System("/Users/jlara/cache/PSIDValidation/PSCAD_144_EMT/144Bus.json")

for b in get_components(Bus, sys)
    @show get_name(b)
    dev = get_components(x -> get_bus(x) == b && get_dynamic_injector(x) !== nothing, StaticInjection, sys)
    if isempty(dev)
        continue
    end
    base_power = sum(get_base_power(x) for x in dev)
    dev_ = collect(dev)
    @show length(dev_)
    choosen_ix = max(1, sum(bitrand(length(dev_))))
    @show choosen_ix
    for (ix, d) in enumerate(dev_)
        if ix != choosen_ix
            remove_component!(sys, get_dynamic_injector(d))
            remove_component!(sys, d)
        end
    end
    set_base_power!(dev_[choosen_ix], base_power)
    set_base_power!(get_dynamic_injector(dev_[choosen_ix]), base_power)
end

for b in get_components(DynamicGenerator, sys)
    static = get_component(ThermalStandard, sys, get_name(b))
    machine = get_machine(b)
    set_R!(machine, get_Xd_pp(machine)/50.0) # X/R ratio of 50.
    bus = get_bus(static)
    shunt = FixedAdmittance("FA_$(get_name(bus))", true, bus, 0.1+0.0*im)
    add_component!(sys, shunt)
end

solve_powerflow!(sys)

line_to_trip = "Bus_7-Bus_5-i_1"
t_sample =  5.0e-4 #* 1e6
t_dynamic_sim = 5.0
time_step_pscad = 25e-6 * 1e6

for b in get_components(Line, sys)
    if get_name(b) != line_to_trip
        dyn_branch = PowerSystems.DynamicBranch(b)
        add_component!(sys, dyn_branch)
    end
end

perturbation = BranchTrip(0.1, Line, line_to_trip)
sim = Simulation(
    ResidualModel,
    sys,
    pwd(),
    (0.0, t_dynamic_sim),
    perturbation;
    file_level =  Logging.Debug,
    frequency_reference = ReferenceBus(),
)
# IDA won't work with KLU in this properly due to the use of random in the same script
execute!(sim, IDA())

to_json(sys, "/Users/jlara/cache/PSIDValidation/PSCAD_144_EMT/144Bus_with_shunts.json"; force = true)
