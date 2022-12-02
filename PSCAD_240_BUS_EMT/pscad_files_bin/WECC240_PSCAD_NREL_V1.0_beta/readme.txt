
240-bus WECC System PSCAD Model V1.0_beta
2022-06-06

NREL: Bin Wang, Richard Wallace Kenyon, Shuan Dong, and Jin Tan.
Contact: Jin Tan, Jin.Tan@nrel.gov

This PSCAD 240-bus WECC test system was developed by National Renewable Energy Laboratory [1][2]. The network of the test system was partitioned into eight areas (called namespaces in PSCAD) connected by Bergeron transmission lines. Such a split allows for (but does not require) the use of multiple cores on a computer for the parallel computing of the model, leveraging the PSCAD Parallel Network Interface (PNI). The simulation of this test system in PSCAD is independent of any third-party libraries, since each dynamic component model used by the system (except for the synchronous machine, which directly uses the Synchronous Machine model in PSCAD) was built as a new component in PSCAD using basic components from the Master Library. Ideally, you would need PSCAD V5 and Intel Fortran Compiler to run the model. Please see more details in [1].

[1] Bin Wang, Richard Wallace Kenyon, Jin Tan, "Developing a PSCAD Model of the Reduced 240-Bus WECC Test System," 2022 KPEC.
[2] Jin Tan, Bin Wang, Haoyu Yuan, ect. "Development of a Reduced 240-Bus Western Electricity Coordinating Council (WECC) Test System", NREL Technical Report (in development)