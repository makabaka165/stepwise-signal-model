# Step14.3a Reference BD

This directory holds the board-independent Vivado Block Design flow for the
Step14 DBF AXI-Stream Custom IP.

Run from the Step14 directory:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd/run_step14_3a_reference_bd.ps1
```

The BD is fixed to:

```text
external S_AXIS_Y
-> axis_in_fifo_0
-> dbf_axis_0 (user.org:radar:dbf_axis:1.0)
-> axis_out_fifo_0
-> external M_AXIS_Z
```

This flow validates BD structure, generates a wrapper, runs BD-level XSim,
then runs synthesis and implementation through `route_design`. It does not
write a bitstream, XSA, HWH, DMA design, PS design, AXI-Lite subsystem, or
board target.

Current evidence:

```text
Vivado=2024.2
part=xc7z020clg400-1
BD validate=pass
wrapper=pass
XSim=pass
MATLAB exact compare=pass
synthesis=pass
route_completed_flag=true
post_route_timing_200MHz_met_flag=false
WNS_ns=-0.076
TNS_ns=-0.079
failing_endpoints=2
WHS_ns=0.096
hold_failing_endpoints=0
unexpected_drc_error_count=0
blocker_if_any=post_route_timing_200MHz_not_met
```

Because 200 MHz post-route timing is not met, Step14.3a does not proceed to
platform freeze, DMA reference design, board validation, or full FPGA backend
closure.

## Step14.3b Follow-Up

Step14.3b keeps this Reference BD topology fixed and closes the 200 MHz timing
blocker through `vivado/reference_bd_timing/`. The first phase is a Vivado
implementation strategy sweep using the same `dbf_axis_0` Custom IP cell,
FIFO depths, 200 MHz clock, and XDC constraints. Only if no strategy reaches
`WNS >= 0.100 ns` is a local DBF operand input pipeline stage allowed.

The Reference BD clock port now records `S_AXIS_Y:M_AXIS_Z` association,
`aresetn` association, and `FREQ_HZ=200000000` when supported by Vivado.

Step14.3b remains board-independent and still does not instantiate PS, DMA,
DDR, AXI-Lite, SmartConnect, ILA, board clocking, bitstream, XSA, HWH, or CPU
software.
