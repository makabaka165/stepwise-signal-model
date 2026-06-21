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

## Step14.1 Migration Boundary

Step14.1 keeps dbf_axis_system_top free of DMA, PS, AXI-Lite, Block Design, FIFO IP, ILA, and board clock IP. Future IP Packager or user-model nesting should wrap this top rather than changing the Step13 arithmetic core.

## Step14.3a Reference BD Boundary

Step14.3a wraps the packaged Custom IP in a minimal IP Integrator design:

```text
S_AXIS_Y
-> axis_in_fifo_0
-> dbf_axis_0 (user.org:radar:dbf_axis:1.0)
-> axis_out_fifo_0
-> M_AXIS_Z
```

This stage proves the Custom IP can be nested as a BD IP cell and can pass
AXIS functional regression with FIFO buffering. It still keeps PS, DMA, DDR,
AXI-Lite, SmartConnect, board clocks, bitstream, XSA, HWH, and CPU ML outside
the design. The `dbf_status_busy` signal remains the DBF Custom IP frame
activity status; it is not a global FIFO occupancy or whole-BD busy signal.

The Step14.3a Reference BD currently has a functional pass but a 200 MHz
post-route setup timing blocker on the reference device. Later migration stages
must not start from it as a platform-freeze point until
`post_route_timing_200MHz_met_flag=true`.
