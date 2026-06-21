# Step14.3a Reference BD Integration

Step14.3a validates that the Step14 Custom IP can be instantiated as a Vivado
Block Design IP cell and exercised through AXI4-Stream FIFOs. It uses the
packaged IP identity:

```text
VLNV = user.org:radar:dbf_axis:1.0
BD cell = dbf_axis_0
```

The BD cell must be created as an IP Integrator IP cell, not as Module
Reference.

## BD Topology

```text
external S_AXIS_Y
-> axis_in_fifo_0  (xilinx.com:ip:axis_data_fifo:2.0, 32-bit, depth 64)
-> dbf_axis_0      (user.org:radar:dbf_axis:1.0)
-> axis_out_fifo_0 (xilinx.com:ip:axis_data_fifo:2.0, 64-bit, depth 16)
-> external M_AXIS_Z
```

External ports are limited to `aclk`, active-low `aresetn`, `S_AXIS_Y`,
`M_AXIS_Z`, and DBF status outputs. The design intentionally excludes PS, DMA,
DDR, AXI-Lite, SmartConnect, bitstream, XSA, HWH, board-specific clocking, and
CPU ML integration.

## Validation Flow

Run from the Step14 directory:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd/run_step14_3a_reference_bd.ps1
```

Then aggregate MATLAB compare/keypoints:

```matlab
run('setup_paths.m');
cd('steps/step_14_dbf_ip_soc_integration');
run_step14_3a_reference_bd_validation
```

The Vivado flow validates BD structure, generates the wrapper, runs BD-level
XSim, runs OOC synthesis, routes on the reference part, writes timing/resource
reports, and records CSV summaries.

## Current Evidence

```text
Vivado = 2024.2
part = xc7z020clg400-1
reference_device_only = true
BD validate = pass
wrapper generation = pass
BD XSim = pass
Case A exact compare = pass, 14/14 rows
Case B FIFO/backpressure stress compare = pass, 28/28 rows
synthesis = pass
route_completed_flag = true
```

Post-route resources:

```text
LUT = 2097
FF = 5112
DSP = 42
BRAM18 = 1
BRAM36 = 16
```

Post-route timing:

```text
clock_MHz = 200
WNS_ns = -0.076
TNS_ns = -0.079
setup_failing_endpoints = 2
WHS_ns = 0.096
hold_failing_endpoints = 0
post_route_timing_200MHz_met_flag = false
```

DRC classification:

```text
DRC_error_count = 0
DRC_critical_warning_count = 0
DRC_warning_count = 34
ZPS7_1_count = 1
DPIP_1_count = 19
DPOP_1_count = 14
unexpected_drc_error_count = 0
reference_expected_drc_only_flag = true
```

## Gate

Step14.3a does not pass because the 200 MHz post-route timing gate is not met:

```text
step14_3a_reference_bd_pass_flag=false
proceed_to_platform_freeze_flag=false
proceed_to_target_board_dma_flag=false
proceed_to_board_validation_flag=false
proceed_to_full_fpga_backend_flag=false
formal_result_claimed=false
blocker_if_any=post_route_timing_200MHz_not_met
```

The functional Reference BD evidence is useful and retained, but it is not a
platform freeze, DMA validation, PS validation, board validation, bitstream
claim, implementation closure claim, or formal closure claim.

## Step14.3b Timing Closure Handoff

Step14.3b consumes the Step14.3a functional evidence and closes only the
post-route 200 MHz timing blocker. It first runs an implementation strategy
sweep on the exact same Reference BD:

```text
same RTL
same Custom IP VLNV user.org:radar:dbf_axis:1.0
same S_AXIS_Y -> FIFO -> dbf_axis_0 -> FIFO -> M_AXIS_Z topology
same input FIFO depth 64
same output FIFO depth 16
same 200 MHz clock
same legal XDC constraints
```

The Step14.3b gate requires `WNS >= 0.100 ns`, not merely nonnegative WNS. If
the strategy sweep and clean best-strategy rerun both meet that margin, no DBF
RTL change, Custom IP repackaging, or pipeline latency change is made.

Reference BD external clock metadata is now explicitly recorded when supported:

```text
ASSOCIATED_BUSIF = S_AXIS_Y:M_AXIS_Z
ASSOCIATED_RESET = aresetn
FREQ_HZ = 200000000
```

This remains a board-independent reference-device timing closure. It is not a
target-board DMA design, PS integration, bitstream, XSA/HWH, or full FPGA
backend claim.
