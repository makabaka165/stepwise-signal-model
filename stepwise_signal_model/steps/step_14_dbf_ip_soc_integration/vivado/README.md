# Vivado

This directory contains the Step14.2 Vivado package and validation wrappers.

Run from `steps/step_14_dbf_ip_soc_integration/`:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/package_dbf_axis_ip.ps1
powershell -ExecutionPolicy Bypass -File vivado/validate_dbf_axis_ip.ps1
```

The `.bat` wrappers provide the same flow for `cmd.exe`.

`package_dbf_axis_ip.tcl` rebuilds `ip_repo/dbf_axis_ip_1_0/`, stages the
required Step13/Step14 HDL and 14 W ROM `.mem` files, creates
`component.xml`, declares `S_AXIS_Y`, `M_AXIS_Z`, `ACLK`, `ARESETN`, runs IP
integrity, and writes package summaries.

`validate_dbf_axis_ip.tcl` registers the generated repository, checks
`user.org:radar:dbf_axis:1.0`, runs `create_ip` and `generate_target`, executes
packaged-IP XSim, and runs OOC synthesis for the reference part
`xc7z020clg400-1`.

Generated Vivado work directories are ignored by Git. The flow does not create
Block Design, DMA, PS, bitstream, DCP for tracking, XSA, HWH, or board
validation artifacts.
