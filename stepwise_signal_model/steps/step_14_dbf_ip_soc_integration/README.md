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
- Step14.2b: Custom IP provenance, status semantics, and directed hardening.
- Step14.3a: board-independent Reference Block Design integration.
- Step14.3b: Reference BD 200 MHz post-route timing closure.
- Step14.3c+: AXI DMA DDR replay reference design only after platform-freeze gate.
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
    08_STATUS_AND_AUDIT_HARDENING.md
    09_REFERENCE_BD_INTEGRATION.md
    10_REFERENCE_BD_TIMING_CLOSURE.md
  rtl/
  tb/
  sim/
  matlab_vectors/
  vivado/
    reference_bd/
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

## Current Step14.2b Hardening

Step14.2b strengthens Step14.2a without changing DBF mathematics or AXI4-Stream
protocols:

- `status_busy` now remains high from the first accepted Y beat through DRAIN,
  TX, and output backpressure, then drops after the final Z beat is accepted.
- Raw baseline, optimized raw top, and packaged-IP TBs record five busy
  semantic checks in their summary CSVs.
- `dbf_w_provider_rom_opt` response validity/data are range-aligned to the
  registered one-cycle request.
- New directed XSim tests cover split W ROM boundary addresses and pipelined
  quantizer equivalence against Step13.
- DRC counts are parsed from the summary table and cross-checked against detail
  headings; expected counts are baseline 42/28/28/1 and optimized 0/14/0/1 for
  DPIP-1/DPOP-1/DPOP-2/ZPS7-1.
- Package manifests now record source/package size and SHA256 provenance.

Step14.2b still contains no DMA, PS, Block Design, AXI-Lite, bitstream, board
validation, implementation closure claim, or formal closure claim.

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

## Step14.3a Reference Block Design Integration

Step14.3a introduces the first board-independent Vivado Block Design around the
already packaged Custom IP. It uses the fixed VLNV `user.org:radar:dbf_axis:1.0`
as an IP Integrator cell, not a Module Reference:

```text
S_AXIS_Y
-> axis_in_fifo_0
-> dbf_axis_0 (user.org:radar:dbf_axis:1.0)
-> axis_out_fifo_0
-> M_AXIS_Z
```

The reference BD exposes only `aclk`, active-low `aresetn`, `S_AXIS_Y`,
`M_AXIS_Z`, and DBF status outputs. It intentionally contains no Zynq PS, AXI
DMA, DDR, AXI-Lite, SmartConnect, bitstream, XSA, HWH, board target, or CPU ML
integration.

Current Step14.3a evidence:

- Vivado version: 2024.2.
- Reference part: `xc7z020clg400-1`, `reference_device_only=true`.
- BD validate and wrapper generation: pass.
- Reference BD XSim: pass.
- Case A exact compare: 14/14 rows matched.
- Case B FIFO/backpressure stress exact compare: 28/28 rows matched.
- Synthesis: pass.
- Route completed: true.
- Post-route resources: LUT 2097, FF 5112, DSP 42, BRAM18 1, BRAM36 16.
- Post-route timing at 200 MHz: not met, `WNS_ns=-0.076`, `TNS_ns=-0.079`,
  setup failing endpoints = 2.
- Hold timing: met, `WHS_ns=0.096`, hold failing endpoints = 0.
- DRC: error 0, critical warning 0, warning 34; expected reference warnings
  only, unexpected DRC error count = 0.

The final Step14.3a gate is therefore:

```text
step14_3a_reference_bd_pass_flag=false
proceed_to_platform_freeze_flag=false
proceed_to_target_board_dma_flag=false
proceed_to_board_validation_flag=false
proceed_to_full_fpga_backend_flag=false
formal_result_claimed=false
blocker_if_any=post_route_timing_200MHz_not_met
```

The Reference BD functional chain is validated, but the 200 MHz post-route
timing gate is not closed. This is not a DMA, PS, board, bitstream, or full FPGA
backend claim.

## Step14.3b Reference BD Timing Closure

Step14.3b closes the Step14.3a 200 MHz post-route timing blocker using a
two-phase rule:

- Phase A: implementation strategy sweep on the same RTL, Custom IP, Reference
  BD topology, FIFO sizes, 200 MHz clock, and XDC constraints.
- Phase B: a single local DBF complex-MAC operand input pipeline stage only if
  Phase A cannot reach `WNS >= 0.100 ns`.

Phase A does not modify DBF math, AXI4-Stream protocol, Custom IP VLNV,
component packaging, W coefficients, FIFO parameters, or clock target. If Phase
A sweep and independent clean rerun both satisfy the 0.100 ns margin, Phase B is
not triggered and no RTL/package refresh is performed.

Step14.3b also records external clock metadata for the Reference BD:

```text
CONFIG.ASSOCIATED_BUSIF = S_AXIS_Y:M_AXIS_Z
CONFIG.ASSOCIATED_RESET = aresetn
CONFIG.FREQ_HZ = 200000000
```

The final Step14.3b gate requires Step14.2b hardening, Step14.3a functional
evidence, expected-only methodology classification, routed setup/hold timing,
and `WNS >= 0.100 ns`. It still does not create DMA, PS, AXI-Lite, bitstream,
XSA, HWH, board validation, full FPGA backend, or formal closure claims.
