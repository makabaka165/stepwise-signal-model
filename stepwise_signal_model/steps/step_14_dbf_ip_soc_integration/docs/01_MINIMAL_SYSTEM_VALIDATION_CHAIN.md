# Minimal System Validation Chain

The first Step14 runnable chain is a system-interface smoke around the Step13
DBF core. It validates framing, handshaking, coefficient alignment, output
serialization, and golden comparison plumbing.

It is not DMA validation, PS validation, or board-level validation.

## Chain

```text
AXIS Y source BFM
    -> DBF AXIS wrapper
        -> W provider
        -> Step13 B=7 DBF core
        -> Z output serializer
    -> AXIS Z sink BFM
    -> MATLAB compare
```

The external data flow is:

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

The chain does not use DMA and does not depend on a real board.

## Validation Targets

The first smoke must check:

- AXI `TVALID` / `TREADY` handshake behavior
- input valid gaps
- output backpressure
- `TLAST` frame boundary
- exact count of 2080 accepted input samples
- W address alignment to Y element index
- B=7 output order
- two consecutive frames
- automatic accumulator clear between frames
- clip and overflow status propagation
- malformed `TLAST` detection
- exact RTL Z match against MATLAB golden output

## Frame Meaning

One input snapshot is one frame of 2080 accepted Y samples. The frame is accepted
only on `s_axis_y_tvalid && s_axis_y_tready`.

One output frame is seven Z beats, ordered from beam 0 through beam 6. The output
`TLAST` marks beam 6.

## Boundary Of This Smoke

This smoke proves that the system interface can wrap and exercise the closed
Step13 arithmetic core. It does not prove:

- DMA correctness
- PS software correctness
- board timing
- bitstream validity
- complete FPGA backend closure

## Step14.1 Implementation Notes

The first implementation contains dbf_w_provider_rom, dbf_axis_datapath, dbf_axis_z_serializer, dbf_axis_system_top, and tb_dbf_axis_system_top. The testbench records only the two good-path frame outputs in step14_1_axis_output.csv; malformed protocol cases validate sticky status bits and do not contribute to the golden-output CSV.
