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

The current framework intentionally contains no board validation and makes no
full FPGA backend claim.

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
