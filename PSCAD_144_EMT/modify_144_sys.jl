using PowerSystems


sys = System("/Users/jlara/cache/PSIDValidation/PSCAD_144_EMT/144Bus.json")

for b in get_components(DynamicGenerator, sys)
    static = get_component(ThermalStandard, sys, get_name(b))
    machine = get_machine(b)
    set_R!(machine, get_Xd_pp(machine)/50.0) # X/R ratio of 50.
    bus = get_bus(static)
    shunt = FixedAdmittance("FA_$(get_name(bus))", true, bus, 0.1+0.0*im)
    add_component!(sys, shunt)
end

to_json(sys, "/Users/jlara/cache/PSIDValidation/PSCAD_144_EMT/144Bus_with_shunts.json")
