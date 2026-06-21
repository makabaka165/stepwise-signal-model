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
