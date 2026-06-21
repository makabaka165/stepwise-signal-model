# Vivado

This directory contains the Step14.2/Step14.2a Vivado package and validation
wrappers.

Run from `steps/step_14_dbf_ip_soc_integration/`:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/package_dbf_axis_ip.ps1
powershell -ExecutionPolicy Bypass -File vivado/validate_dbf_axis_ip.ps1
```

The `.bat` wrappers provide the same flow for `cmd.exe`.

`package_dbf_axis_ip.tcl` rebuilds `ip_repo/dbf_axis_ip_1_0/`, stages the
optimized Step14 HDL and 28 split W ROM `.mem` files, creates `component.xml`,
declares `S_AXIS_Y`, `M_AXIS_Z`, `ACLK`, `ARESETN`, runs IP integrity, and
writes package summaries. Step14.2b package provenance records source/package
size and SHA256 for every staged HDL/MEM file and fails on nonempty-file hash or
content mismatches.

`validate_dbf_axis_ip.tcl` registers the generated repository, checks
`user.org:radar:dbf_axis:1.0`, runs `create_ip` and `generate_target`, executes
packaged-IP XSim, and runs OOC synthesis for the reference part
`xc7z020clg400-1`. Step14.2b parses DRC counts from the summary table and
cross-checks detail headings; optimized counts should be DPIP-1=0, DPOP-1=14,
DPOP-2=0, ZPS7-1=1.

Current Step14.2a reference result:

```text
WNS_ns=0.377
TNS_ns=0.000
failing_endpoints=0
BRAM36_equiv=14.000
timing_200MHz_met_flag=true
```

Generated Vivado work directories are ignored by Git. The flow does not create
Block Design, DMA, PS, bitstream, DCP for tracking, XSA, HWH, or board
validation artifacts.

## Step14.3a Reference BD

`vivado/reference_bd/` contains the board-independent Reference BD flow. It
registers `ip_repo/dbf_axis_ip_1_0`, creates `dbf_axis_0` as
`user.org:radar:dbf_axis:1.0`, inserts AXIS input/output FIFOs, runs BD-level
XSim, then runs OOC synthesis and route for `xc7z020clg400-1`.

Current result:

```text
reference_bd_xsim_pass_flag=true
reference_bd_compare_pass_flag=true
synthesis_status=pass
route_completed_flag=true
post_route_timing_200MHz_met_flag=false
WNS_ns=-0.076
TNS_ns=-0.079
failing_endpoints=2
blocker_if_any=post_route_timing_200MHz_not_met
```

The flow writes no bitstream, XSA, HWH, PS, DMA, AXI-Lite, SmartConnect, board
target, or full backend claim.

## Step14.3b Reference BD Timing Closure

`vivado/reference_bd_timing/` contains the timing-closure flow for the
Step14.3a Reference BD.

Run the strategy sweep:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd_timing/run_reference_bd_strategy_sweep.ps1
```

Run the full closure wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd_timing/run_reference_bd_timing_closure.ps1
```

The closure wrapper performs Phase A implementation strategy sweep on the same
RTL/IP/BD and then runs an independent clean rerun of the best strategy when the
sweep reaches `WNS >= 0.100 ns`. It does not generate a bitstream and does not
create PS, DMA, AXI-Lite, SmartConnect, XSA, HWH, board constraints, or CPU
software artifacts.
