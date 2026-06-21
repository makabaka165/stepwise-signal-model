# Testbench

This directory contains self-checking XSim testbenches.

`tb_dbf_axis_system_top.v` is the Step14.1 raw RTL system smoke. It checks normal
frame output, input gaps, output backpressure, two consecutive frames, ready
lockout, beam order, early TLAST, missing TLAST, bad TKEEP, and Step14.2b
`status_busy` semantics.

`tb_dbf_axis_system_top_opt.v` is the Step14.2a optimized raw-top regression. It
checks the optimized provider/core/top before IP packaging, including the same
Step14.2b busy semantics.

`tb_dbf_axis_packaged_ip.v` is the Step14.2/Step14.2a packaged-IP regression. It
instantiates Vivado-generated `dbf_axis_0`, reuses the Step14.1 Y/Z vectors,
checks two good frames, applies input gaps and output backpressure, verifies
backpressure stability, checks beam order and status, and writes:

- `results_step14_dbf_ip_soc_integration/ip_xsim/step14_2_packaged_ip_output.csv`
- `results_step14_dbf_ip_soc_integration/ip_xsim/step14_2_packaged_ip_tb_summary.csv`

The packaged-IP testbench does not repeat malformed TLAST/TKEEP cases; those are
already covered by the raw RTL Step14.1 smoke.

Step14.2b adds:

- `tb_dbf_w_provider_rom_opt_boundary.v`
- `tb_dbf_z24_quantizer_pipe_equiv.v`

These write summaries under
`results_step14_dbf_ip_soc_integration/hardening/`.
