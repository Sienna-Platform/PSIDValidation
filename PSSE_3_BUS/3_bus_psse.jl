using Revise
using PowerSystems
using PowerSimulationsDynamics
using Logging
using OrdinaryDiffEq
using Sundials
using PlotlyJS

sys = System("/Users/jdlara/.julia/dev/PowerSimulationsDynamics/test/benchmarks/psse/MultiGen/FourBusMulti.raw",
"/Users/jdlara/.julia/dev/PowerSimulationsDynamics/test/benchmarks/psse/MultiGen/ThreeBus_multigen.dyr"; runchecks = false)

for l in get_components(PowerLoad, sys)
    set_model!(l, LoadModels.ConstantImpedance)
end

sim = Simulation(
    ResidualModel,
    sys, #system
    pwd(),
    (0.0, 20.0), #time span
    BranchTrip(1.0, Line, "BUS 1-BUS 2 HV-i_1"),
)

execute!(sim, IDA(), abstol = 1e-10)
results = read_results(sim)

v104_current = get_voltage_magnitude_series(results, 104)
plot(scatter(x = v104_current[1], y =  v104_current[2]))

a104_current = get_voltage_angle_series(results, 104)
plot(scatter(x = a104_current[1], y =  a104_current[2]))

using CSV
using DataFrames
psse_results = CSV.read("/Users/jdlara/.julia/dev/PowerSimulationsDynamics/test/benchmarks/psse/MultiGen/line_trip_results.csv", DataFrame, header = 2)
hdr = names(psse_results)
ix = findall(x -> occursin("SPD 102", x), hdr)
w_psse_ = psse_results[4:end-1, [1, ix...]]
w_psse = deleteat!(w_psse_, 202)

speeds = Vector{GenericTrace{Dict{Symbol, Any}}}()
for n in ["generator-102-ND",
          "generator-102-SG",
          "generator-102-RG",
          "generator-102-SH",
          "generator-102-EG",
          "generator-102-WG"]

    x, y = get_state_series(results, (n, :ω))
    push!(speeds, scatter(x = x, y =y, name = n))
end
plot(speeds)

speeds = Vector{GenericTrace{Dict{Symbol, Any}}}()
for n in ["ND",
          "SG",
          "RG",
          "SH",
          "EG",
          "WG"]

    x, y = get_state_series(results, ("generator-102-$(n)", :ω), dt = 0.005)
    w_psse_gen = w_psse[!, " SPD 102[BUS 2 LV 20.000]$n"]
    error_v = w_psse_gen .- y .+ 1.0
    push!(speeds, scatter(x = x, y =error_v, name = "generator-102-$(n)"))
end

plot(speeds)

ix = findall(x -> occursin("VOLT", x), hdr)
volt_psse_ = psse_results[4:end-1, [1, ix...]]
volt_psse = deleteat!(volt_psse_, 202)

speeds = Vector{GenericTrace{Dict{Symbol, Any}}}()
for (ix, n) in enumerate(101:104)
    x, y = get_voltage_magnitude_series(results, n, dt = 0.005)
    volt_psse_gen = volt_psse[!, ix+1]
    error_v = volt_psse_gen .- y
    push!(speeds, scatter(x = x, y =error_v, name = n))
end
plot(speeds)

x, y = get_voltage_magnitude_series(results, 101, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 2], name = "PSSe")])

x, y = get_voltage_magnitude_series(results, 102, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 3], name = "PSSe")])

x, y = get_voltage_magnitude_series(results, 103, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 4], name = "PSSe")])

x, y = get_voltage_magnitude_series(results, 104, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 5], name = "PSSe")])


dc = get_dynamic_injector(get_component(ThermalStandard, sys, "generator-102-SW"))
sim = Simulation(
    MassMatrixModel,
    sys, #system
    pwd(),
    (0.0, 20.0), #time span
    GeneratorTrip(1.0, dc),
)

execute!(sim, Rodas5P(), abstol = 1e-6)
results = read_results(sim)

using CSV
using DataFrames

psse_results = CSV.read("/Users/jdlara/.julia/dev/PowerSimulationsDynamics/test/benchmarks/psse/MultiGen/gen_trip_results_with_names.csv", DataFrame, header = 2)
hdr = names(psse_results)
ix = findall(x -> occursin("SPD", x), hdr)
w_psse_ = psse_results[4:end-1, [1, ix...]]
w_psse = deleteat!(w_psse_, 201)

speeds = Vector{GenericTrace{Dict{Symbol, Any}}}()
for n in ["generator-102-ND",
          "generator-102-SG",
          "generator-102-RG",
          "generator-102-SH",
          "generator-102-EG",
          "generator-102-WG",]

    x, y = get_state_series(results, (n, :ω))
    push!(speeds, )
end
plot(speeds)

plots = []
for n in ["ND",
          "SG",
          "RG",
          "SH",
          "EG",
          "WG",]

    x, y = get_state_series(results, ("generator-102-$(n)", :ω), dt = 0.005)
    w_psse_gen = w_psse[!, " SPD 102[BUS 2 LV 20.000]$n"]
    error_v = w_psse_gen .+ 1.0
    push!(plots, plot([scatter(x = x, y =error_v, name = " SPD 102[BUS 2 LV 20.000]$n"),
                    scatter(x = x, y =y, name = "generator-102-$(n)")]))
end

[plots[1] plots[2]
plots[3] plots[4]
plots[5] plots[6]]

plot(speeds)

ix = findall(x -> occursin("VOLT", x), hdr)
volt_psse_ = psse_results[4:end-1, [1, ix...]]
volt_psse = deleteat!(volt_psse_, 201)

speeds = Vector{GenericTrace{Dict{Symbol, Any}}}()
for (ix, n) in enumerate(101:104)
    x, y = get_voltage_magnitude_series(results, n, dt = 0.005)
    volt_psse_gen = volt_psse[!, ix+1]
    error_v = volt_psse_gen .- y
    push!(speeds, scatter(x = x, y =error_v, name = n))
end
plot(speeds)

x, y = get_voltage_magnitude_series(results, 101, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 2], name = "PSSe")])

x, y = get_voltage_magnitude_series(results, 102, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 3], name = "PSSe")])

x, y = get_voltage_magnitude_series(results, 103, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 4], name = "PSSe")])

x, y = get_voltage_magnitude_series(results, 104, dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = volt_psse[!, 1], y =  volt_psse[!, 5], name = "PSSe")])

ix = findall(x -> occursin("VOLT", x), hdr)
volt_psse_ = psse_results[4:end-1, [1, ix...]]
volt_psse = deleteat!(volt_psse_, 201)

ix = findall(x -> occursin("POWR", x), hdr)
power_psse_ = psse_results[4:end-1, [1, ix...]]
power_psse = deleteat!(power_psse_, 201)

x, y = get_activepower_series(results, "generator-101-1"; dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = power_psse[!, 1], y =  power_psse[!, 2], name = "PSSe")])

x, y = get_activepower_series(results, "generator-101-1"; dt = 0.005)
plot([scatter(x =x , y =y, name = "PSID"), scatter(x = power_psse[!, 1], y =  power_psse[!, 2], name = "PSSe")])

speeds = Vector{GenericTrace{Dict{Symbol, Any}}}()
total_power = 0.0
for n in ["ND",
          "SG",
          "RG",
          "SH",
          "S",
          "EG",
          "WG",
          "SW"]

    x, y = get_activepower_series(results, "generator-102-$(n)"; dt = 0.005)
    w_psse_gen = power_psse[!, " POWR 102[BUS 2 LV 20.000]$n"]
    error_v = w_psse_gen .- y
    total_power += sum(error_v)
    push!(speeds, scatter(x = x, y =y, name = "generator-102-$(n)"))
    push!(speeds, scatter(x = power_psse[!, 1], y =w_psse_gen, name = "POWR 102[BUS 2 LV 20.000]$n"))
end
plot(speeds)


sys = System("/Users/jdlara/cache/andes/andes/cases/psid_files/FourBusMulti.raw",
"/Users/jdlara/cache/andes/andes/cases/psid_files/ThreeBus_multigen.dyr"; runchecks = false)

for l in get_components(PowerLoad, sys)
    set_model!(l, LoadModels.ConstantImpedance)
end


dc = get_dynamic_injector(get_component(ThermalStandard, sys, "generator-102-5"))
sim = Simulation(
    MassMatrixModel,
    sys, #system
    pwd(),
    (0.0, 20.0), #time span
    GeneratorTrip(1.0, dc),
)

execute!(sim, Rodas5P(), abstol = 1e-10, dtmax = 0.0333333)
results = read_results(sim)

using CSV, DataFrames
andes_res = CSV.read("/Users/jdlara/cache/andes/FourBusMulti_out.csv", DataFrame)

psse_results = CSV.read("speed.csv", DataFrame, header = 2)
hdr = names(psse_results)
ix = findall(x -> occursin("SPD 102", x), hdr)
w_psse_ = psse_results[4:end-1, [1, ix...]]
w_psse = deleteat!(w_psse_, 201)

hdr = names(andes_res)
ix = findall(x -> occursin("omega", x), hdr)
andes_speed = andes_res[!, [1, ix...]]

speeds = Vector{GenericTrace{Dict{Symbol, Any}}}()
plots = Vector{PlotlyJS.SyncPlot}(undef, 1)

x, y =  get_state_series(results, ("generator-101-1", :ω), dt = 0.0333333)
plots[1] = plot([scatter(x = x, y =y, name = "PSID generator-101-1"),
                 scatter(x = andes_speed[!, 1], y =andes_speed[!, 2], name = "ANDES delta GENROU 1"),
                 scatter(x =psse_results[!, 1], y = psse_results[!, 5] .+ 1.0, name = "PSSE SPD 102-1")
                ])

for (n, lab) in enumerate(["EG",
          "ND",
          "RG",
          "SG",
          "SH",
          "WG"])
    x, y =  get_state_series(results, ("generator-102-$(n)", :ω), dt = 0.0333333)
    w_psse_gen = w_psse[!, " SPD 102[BUS 2 LV 20.000]$lab"] .+ 1.0
    push!(plots, plot([scatter(x = x, y =y, name = "PSID-generator-102-$(n)"),
                       scatter(x = andes_speed[!, 1], y =andes_speed[!, n+2], name = "ANDES delta GENROU $(n)"),
                       scatter(x =  w_psse[!, 1], y = w_psse_gen, name = "PSSE SPD 102 $lab")
                       ])
    )
end

EG = 1
ND = 2
RG = 3
SG = 4
SH = 5
WG = 6

[plots[1] plots[2]
plots[3] plots[4]
plots[5] plots[7]]
