# Testbench

This directory contains self-checking XSim testbenches.

`tb_dbf_axis_system_top.v` is the Step14.1 raw RTL system smoke. It checks normal
frame output, input gaps, output backpressure, two consecutive frames, ready
lockout, beam order, early TLAST, missing TLAST, and bad TKEEP.

`tb_dbf_axis_packaged_ip.v` is the Step14.2 packaged-IP regression. It
instantiates Vivado-generated `dbf_axis_0`, reuses the Step14.1 Y/Z vectors,
checks two good frames, applies input gaps and output backpressure, verifies
backpressure stability, checks beam order and status, and writes:

- `results_step14_dbf_ip_soc_integration/ip_xsim/step14_2_packaged_ip_output.csv`
- `results_step14_dbf_ip_soc_integration/ip_xsim/step14_2_packaged_ip_tb_summary.csv`

The Step14.2 packaged-IP testbench does not repeat malformed TLAST/TKEEP cases;
those are already covered by the raw RTL Step14.1 smoke.
