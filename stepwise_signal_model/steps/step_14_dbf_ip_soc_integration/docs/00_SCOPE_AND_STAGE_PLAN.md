# Step14 Scope And Stage Plan

Step14 is the DBF IP packaging and FPGA/SoC data-path integration step. It
inherits the Step13 DBF arithmetic closure and defines the system-facing
boundary around it.

Step14 source-of-truth arithmetic:

```text
W18 / Y16 / ACC48 / Z24
engineering_Z_shift_bits = 20
N = 2080
B = 7
Z = W^H Y
```

Step14 does not modify the DBF mathematics, fixed-point word lengths, or fixed
shift. Step13 remains frozen as the arithmetic source of truth.

## FPGA Scope

Step14 FPGA-side work is scoped to:

- W coefficient memory/provider
- AXI4-Stream Y ingress
- Step13 B=7 DBF core
- AXI4-Stream Z egress
- frame/protocol checking
- status/error reporting
- custom IP packaging
- later DMA/PS integration

Step14 is not a complete FPGA backend. It is a system integration framework
around the Step13 DBF core.

## CPU/SoC Scope

The CPU/SoC remains responsible for:

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

CPU/SoC ML modules are not future FPGA RTL tasks.

## Stage Plan

Step14.0:

- create the directory structure
- freeze the AXI4-Stream frame protocol
- freeze W provider and coefficient layout rules
- document Step13 reuse boundaries
- document migration and nesting rules

Step14.1:

- pure RTL/XSim AXI4-Stream data-path loop closure
- AXIS Y source BFM
- replaceable W provider model
- DBF AXIS wrapper
- AXIS Z sink/scoreboard
- CSV export and MATLAB golden comparison

Step14.2:

- Vivado custom IP packaging
- packaging scripts and component metadata
- no manual duplicate maintenance of Step13 arithmetic RTL

Step14.3:

- AXI DMA DDR replay reference design
- DMA is introduced only after the pure AXIS loop is closed

Step14.4:

- CPU/SoC loopback software
- Z golden comparison from software-visible output

Step14.5:

- connect to CPU/SoC ML software
- CPU/SoC ML remains software/control side, not FPGA RTL

## Explicit Non-Goals For Step14.0 And Step14.1

Step14.0 and Step14.1 do not perform board validation. They also do not create
Block Design, instantiate AXI DMA, generate bitstreams, or claim a complete
FPGA backend.

## Step14.1 Notes

Step14.1 adds pure RTL/XSim AXI4-Stream data-path loop closure, including source BFM, replaceable W ROM provider, DBF AXIS datapath, Z serializer, sink scoreboard, CSV export, MATLAB compare, protocol error checks, output backpressure stability checks, and two consecutive frames without reset.

Step14.1 pass is the gate before Step14.2 IP Packager work. Even when it passes, proceed_to_dma_reference_design_flag, proceed_to_board_validation_flag, and proceed_to_full_fpga_backend_flag remain false.
