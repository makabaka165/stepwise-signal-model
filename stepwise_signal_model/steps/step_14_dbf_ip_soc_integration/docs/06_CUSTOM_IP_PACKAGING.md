# Step14.2 Custom IP Packaging

Step14.2 packages the Step14.1 AXI4-Stream DBF data path as a Vivado Custom IP.
It does not change the DBF arithmetic, frame protocol, or CPU/SoC partition.

## Source Of Truth

The generated IP staging tree is rebuilt by `vivado/package_dbf_axis_ip.tcl`.
Do not manually edit staged HDL under `ip_repo/dbf_axis_ip_1_0/hdl/`.

Step14.2 baseline source inputs:

- Step13 arithmetic RTL: `dbf_complex_mac.v`, `dbf_beam_accum_core.v`,
  `dbf_z24_quantizer.v`, `dbf_core_z24.v`, `dbf_core_z24_bparallel.v`.
- Step14 AXIS RTL: `dbf_w_provider_rom.v`, `dbf_axis_z_serializer.v`,
  `dbf_axis_datapath.v`, `dbf_axis_system_top.v`, `dbf_axis_ip_top.v`.
- Step14.1 W ROM data: 14 beam-separated `.mem` files.

Step14.2a rebuilds the same IP identity with optimized Step14 RTL:

- Pipelined MAC, accumulator wrapper, and Z24 quantizer equivalent.
- Split W ROM provider using 28 main/tail `.mem` files.
- `dbf_axis_ip_top.v` wrapping `dbf_axis_system_top_opt`.

The package does not include Y replay vectors or Z expected vectors. Those stay
in the validation results area and are used only by testbenches and MATLAB
compare scripts.

## Fixed IP Identity

```text
vendor  = user.org
library = radar
name    = dbf_axis
version = 1.0
VLNV    = user.org:radar:dbf_axis:1.0
```

The packaged directory is:

```text
ip_repo/dbf_axis_ip_1_0/
  component.xml
  hdl/
  data/
  xgui/
  source_manifest.csv
  package_manifest.csv
```

## Bus Interfaces

The package script explicitly declares:

- `S_AXIS_Y`: AXI4-Stream slave, 32-bit `TDATA`, `TKEEP`, `TLAST`, `TREADY`.
- `M_AXIS_Z`: AXI4-Stream master, 64-bit `TDATA`, `TKEEP`, `TLAST`, `TREADY`.
- `ACLK`: associated with `S_AXIS_Y:M_AXIS_Z`, `FREQ_HZ=200000000`.
- `ARESETN`: active-low reset.

The custom IP top exposes discrete status ports for protocol, clip, overflow,
and frame-count reporting. It intentionally does not add AXI-Lite in Step14.2.

## Validation Flow

Run from `steps/step_14_dbf_ip_soc_integration/`:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/package_dbf_axis_ip.ps1
powershell -ExecutionPolicy Bypass -File vivado/validate_dbf_axis_ip.ps1
```

Then aggregate MATLAB compare/keypoints from the repository root:

```matlab
run('setup_paths.m')
cd('steps/step_14_dbf_ip_soc_integration')
run_step14_2_custom_ip_validation
```

Validation writes:

- `results_step14_dbf_ip_soc_integration/ip_package/`
- `results_step14_dbf_ip_soc_integration/ip_xsim/`
- `results_step14_dbf_ip_soc_integration/ip_synth/`
- `results_step14_dbf_ip_soc_integration/ip_compare/`

## Step14.2 Baseline Result

Step14.2 currently passes the custom-IP gate:

- `component.xml` generated: true.
- IP integrity: pass, 0 errors, 0 warnings.
- `S_AXIS_Y`, `M_AXIS_Z`, `ACLK`, `ARESETN`: recognized.
- Clock association and reset polarity: pass.
- Packaged HDL files: 10.
- Packaged W ROM files: 14.
- Absolute-path scan for tracked package metadata/results: pass.
- IP Catalog registration, `create_ip`, and `generate_target`: pass.
- Packaged-IP XSim: pass.
- MATLAB exact compare: 14 expected, 14 actual, 14 matched, 0 mismatches.
- OOC synthesis: pass.
- W memory inference: true, implemented as BRAM resource.

Reference device result:

```text
part = xc7z020clg400-1
LUT = 3594
FF = 1810
DSP = 28
BRAM18 = 0
BRAM36 = 28
URAM = 0
distributed_RAM = 0
WNS_ns = -8.586
timing_200MHz_met_flag = false
```

The baseline custom IP is package/catalog/simulation/synthesis valid, but the
200 MHz post-synthesis timing estimate is not met. Step14.2a closes this
follow-up.

## Step14.2a Optimized Result

The optimized Custom IP keeps the same VLNV and passes the Step14.2a gate:

- Packaged HDL files: 11.
- Packaged W ROM files: 28.
- Packaged-IP XSim: pass.
- MATLAB exact compare: pass, 14 expected, 14 actual, 14 matched.
- W split reconstruction: pass.
- OOC synthesis: pass.
- W memory inferred: true.
- W memory resource gate: pass, `BRAM36_equiv=14.000`.
- Advertised clock: `ACLK FREQ_HZ=200000000`.
- 200 MHz timing estimate: pass, `WNS_ns=0.377`, `TNS_ns=0.000`,
  failing endpoints = 0.

Reference optimized result:

```text
part = xc7z020clg400-1
LUT = 2155
FF = 4695
DSP = 42
BRAM18 = 0
BRAM36 = 14
BRAM36_equiv = 14.000
WNS_ns = 0.377
TNS_ns = 0.000
failing_endpoints = 0
timing_200MHz_met_flag = true
```

Therefore:

```text
step14_2a_optimization_pass_flag=true
proceed_to_reference_bd_design_flag=true
proceed_to_target_board_dma_flag=false
proceed_to_board_validation_flag=false
proceed_to_full_fpga_backend_flag=false
```

## Explicit Non-Claims

Step14.2 does not create or validate DMA, Zynq PS, DDR, Block Design, AXI-Lite,
bitstream, XSA, HWH, software drivers, board execution, implementation timing
closure, full FPGA backend, or formal closure.
