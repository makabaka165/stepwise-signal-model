# Simulation

This directory contains Step14 Vivado XSim wrappers. If XSim tools are
unavailable, wrappers write an unavailable summary rather than a false pass.
These simulations are not DMA, PS, Block Design, board validation, bitstream, or
formal closure.

Step14.2b source hardening:

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_xsim_step14_2b_hardening.ps1
```

It runs the W provider boundary test and the quantizer pipeline equivalence test
and writes `results_step14_dbf_ip_soc_integration/hardening/`.
