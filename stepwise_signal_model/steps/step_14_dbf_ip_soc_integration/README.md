# Step14 DBF IP SoC Integration Framework

Step14 is the DBF IP packaging and FPGA/SoC data-path integration step. Its
scope is to wrap the closed Step13 FPGA-side DBF arithmetic core in a
migration-friendly AXI4-Stream system boundary, then prepare the route toward
custom IP packaging and later DMA/PS integration.

Step14 inherits the closed Step13 DBF arithmetic source of truth:

```text
W18 / Y16 / ACC48 / Z24
engineering_Z_shift_bits = 20
N = 2080
B = 7
Z = W^H Y
```

Step14 does not reopen, retune, or revalidate the DBF mathematics, fixed-point
word lengths, or fixed engineering shift. Step13 remains the arithmetic closure
record.

## FPGA / CPU-SoC Partition

FPGA-side target:

- W coefficient memory/provider
- AXI4-Stream Y ingress
- Step13 B=7 DBF core
- AXI4-Stream Z egress
- frame/protocol checking
- status/error reporting
- custom IP packaging
- later DMA/PS integration

CPU/SoC-side responsibilities remain:

- `Rz`
- `G_cache`
- 2D ML search
- topK
- C05
- confidence
- boundary
- fallback
- logging
- final output

CPU/SoC ML modules are not future FPGA RTL tasks. They remain software/control
responsibilities by partition choice.

Step14 is also not a complete FPGA backend. It is the interface, packaging, and
minimal system-validation framework around the already closed Step13 DBF core.

## First Minimal Validation Chain

The first runnable chain is a system-interface smoke, not DMA, PS, or board
validation:

```text
MATLAB Step11-compatible Y/W vectors
-> AXI4-Stream Y replay source BFM
-> W ROM/provider model
-> DBF AXI wrapper
-> Step13 B=7 DBF core
-> AXI4-Stream Z serializer
-> AXI4-Stream sink/scoreboard
-> CSV
-> MATLAB golden comparison
```

This chain does not use DMA and does not depend on real hardware.

## Stage Route

- Step14.0: directory and protocol freeze.
- Step14.1: pure RTL/XSim AXI4-Stream data-path loop closure.
- Step14.2: Vivado custom IP packaging.
- Step14.2a: custom IP 200 MHz timing and W ROM resource optimization.
- Step14.3: AXI DMA DDR replay reference design.
- Step14.4: CPU/SoC loopback software plus Z golden comparison.
- Step14.5: connect to CPU/SoC ML software.

No board validation is planned in Step14.0 or Step14.1.

## Directory Structure

```text
step_14_dbf_ip_soc_integration/
  .gitignore
  README.md
  docs/
    00_SCOPE_AND_STAGE_PLAN.md
    01_MINIMAL_SYSTEM_VALIDATION_CHAIN.md
    02_AXIS_FRAME_PROTOCOL.md
    03_W_MEMORY_AND_COEFFICIENT_LAYOUT.md
    04_MIGRATION_AND_MODEL_NESTING.md
    05_STEP13_REUSE_RULES.md
    06_CUSTOM_IP_PACKAGING.md
    07_TIMING_AND_W_MEMORY_OPTIMIZATION.md
  rtl/
  tb/
  sim/
  matlab_vectors/
  vivado/
  ip_repo/
  software/
  constraints/
  results_step14_dbf_ip_soc_integration/
```

## Current Step14.2a Result

Step14.2a keeps the Step14.2 Custom IP identity and replaces the internal
implementation with a timing/resource optimized equivalent:

- Pipelined complex MAC and ACC-to-Z quantization.
- Split W ROM layout: 2048-row XPM block ROM main segment plus 32-row tail.
- 28 packaged W `.mem` files: real/imag, beam 0..6, main/tail.
- Packaged HDL files: 11 Step14 RTL files.
- Packaged-IP XSim: pass.
- MATLAB exact compare: pass, 14/14 rows matched.
- OOC synthesis on reference `xc7z020clg400-1`: pass.
- 200 MHz timing estimate: pass, `WNS_ns=0.377`, `TNS_ns=0.000`,
  failing endpoints = 0.
- W memory resources: `BRAM36_equiv=14.000`, reduced from 28.

The current Step14.2a gate sets:

```text
step14_2a_optimization_pass_flag=true
proceed_to_reference_bd_design_flag=true
proceed_to_target_board_dma_flag=false
proceed_to_board_validation_flag=false
proceed_to_full_fpga_backend_flag=false
formal_result_claimed=false
```

The current framework intentionally contains no DMA, PS, Block Design,
bitstream, XSA, HWH, board validation, or full FPGA backend claim.

## What This Step Is Not

Step14.0 does not create or run:

- AXI RTL implementation
- Vivado Block Design
- AXI DMA instance or DMA Tcl
- PS software
- Vivado or MATLAB execution
- generated IP
- bitstream, DCP, XSA, HWH, or large artifacts
- board validation
- complete FPGA backend closure

## Step14.1 RTL/XSim AXI4-Stream Smoke

Step14.1 implements the first pure RTL AXI4-Stream DBF system data path:

```text
Step11-compatible Y/W vectors
-> AXI4-Stream Y source BFM
-> replaceable W ROM provider
-> DBF AXI datapath
-> Step13 B=7 DBF arithmetic core
-> AXI4-Stream Z serializer
-> AXI4-Stream sink/scoreboard
-> CSV
-> MATLAB golden comparison
```

The W provider, input source, and output sink are intentionally replaceable. The Step13 arithmetic RTL remains the source of truth and is referenced by XSim through relative paths; it is not copied into Step14.

This smoke checks AXI handshaking, fixed 2080-sample frame boundaries, W/Y alignment, B=7 Z serialization order, output backpressure stability, two consecutive frames without reset, and protocol error reporting for early TLAST, missing TLAST, and bad TKEEP.

Step14.1 is not DMA, PS, DDR, Block Design, IP Packager, board validation, bitstream generation, full FPGA backend closure, or formal closure. CPU/SoC ML modules remain outside FPGA RTL.

## Step14.2 Vivado Custom IP Packaging

Step14.2 packages the closed Step14.1 AXI data path as a Vivado Custom IP:

```text
Step13 arithmetic RTL
+ Step14 AXIS RTL
+ 14 Step14.1 W ROM .mem files
-> ip_repo/dbf_axis_ip_1_0/component.xml
-> Vivado IP Catalog
-> create_ip / generate_target
-> packaged-IP XSim regression
-> MATLAB exact compare
-> packaged-IP OOC synthesis
```

Fixed IP identity:

```text
VLNV = user.org:radar:dbf_axis:1.0
display_name = Step14 DBF AXI Stream
part = xc7z020clg400-1 reference device
```

The packaged IP explicitly declares `S_AXIS_Y`, `M_AXIS_Z`, `ACLK`, and
active-low `ARESETN`. The staged IP contains 10 HDL files and 14 W ROM memory
files. The package is self-contained under `ip_repo/dbf_axis_ip_1_0/`, while
source-of-truth RTL remains Step13/Step14 source files and the package script
regenerates the staging tree.

Step14.2 validation results:

- IP integrity: pass, 0 errors, 0 warnings.
- IP Catalog registration, `create_ip`, and `generate_target`: pass.
- Packaged-IP XSim: pass.
- MATLAB exact compare: expected/actual/matched rows = 14/14/14.
- OOC synthesis: pass on `xc7z020clg400-1`.
- Resource estimate: LUT 3594, FF 1810, DSP 28, BRAM18 0, BRAM36 28, URAM 0,
  distributed RAM 0.
- W memory resource inference: true.
- 200 MHz post-synthesis timing estimate: not met, WNS = -8.586 ns.

`step14_2_custom_ip_pass_flag=true` because packaging, catalog, packaged XSim,
exact compare, OOC synthesis, and W memory inference all pass. However
`proceed_to_reference_bd_design_flag=false` because the 200 MHz timing estimate
is not met. Target-board DMA, board validation, full FPGA backend closure, and
formal closure remain false.

Step14.2 still does not create DMA, PS, DDR, Block Design, bitstream, XSA, HWH,
software drivers, board validation, or a complete FPGA backend.
