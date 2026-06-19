# Migration And Model Nesting

Step14 is organized so the DBF AXIS datapath can move from simulation to IP
packaging and then to SoC integration without being tied to a board-specific
design.

## Design Principles

- `dbf_axis_datapath` does not depend on a development board.
- `dbf_axis_datapath` does not instantiate Zynq PS.
- `dbf_axis_datapath` does not instantiate AXI DMA.
- W provider is replaceable.
- AXIS source and sink are replaceable.
- MATLAB BFM is replaceable by a user-owned frontend model.
- Board-specific configuration belongs in `vivado/` and `constraints/`.
- The DBF arithmetic core continues to use Step13 as the source of truth.

## Replaceable Output Consumers

`m_axis_z` may connect to:

- testbench sink
- AXI DMA S2MM
- AXIS FIFO
- user-owned SoC bridge

## Replaceable Input Producers

`s_axis_y` may connect to:

- testbench replay
- AXI DMA MM2S
- FPGA frontend `Y_work` generator
- user-owned array model

## Replaceable W Sources

The W provider may be:

- `.mem` ROM in simulation
- BRAM controller
- AXI-Lite coefficient loader
- double-buffer coefficient bank
- user-owned W model
- real-time W generation module

## Nesting Rule

Keep the core nesting shallow and portable:

```text
dbf_axis_system_top
  dbf_axis_datapath
    Step13 B=7 DBF arithmetic core
    Z output serializer
  W provider
```

The system top may change for testbench, IP packaging, or board integration.
The datapath contract should remain stable.

## Board And Backend Claims

Step14.0 and Step14.1 do not make a board-validation claim. They also do not
claim a complete FPGA backend. The first claim is only that a portable AXIS
system boundary can drive the closed Step13 DBF core and compare Z against
MATLAB golden output.
