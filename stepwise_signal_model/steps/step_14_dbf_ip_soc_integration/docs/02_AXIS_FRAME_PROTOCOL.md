# AXI4-Stream Frame Protocol

This document freezes the first Step14 AXI4-Stream protocol. It is intentionally
minimal and avoids DMA descriptor metadata.

## Y Input Interface

Interface name:

```text
s_axis_y
```

Data width:

```text
32 bit
```

Packing:

```text
s_axis_y_tdata[15:0]  = signed int16 y_re
s_axis_y_tdata[31:16] = signed int16 y_im
```

Each AXI beat represents one complex array-element sample.

Frame definition:

```text
one snapshot = 2080 beats
```

`TLAST`:

```text
assert on the accepted beat where element_index = 2079
```

`TKEEP`:

```text
4'b1111
```

Handshake:

```text
sample_accept = s_axis_y_tvalid && s_axis_y_tready
```

Only when `sample_accept` is true may the design:

- increment the element index
- increment the W address
- feed the DBF accumulator

## Z Output Interface

Interface name:

```text
m_axis_z
```

Data width:

```text
64 bit
```

Each beat represents one beam's complex Z output.

Packing:

```text
m_axis_z_tdata[23:0]  = signed int24 z_re
m_axis_z_tdata[47:24] = signed int24 z_im
m_axis_z_tdata[48]    = clip_re
m_axis_z_tdata[49]    = clip_im
m_axis_z_tdata[50]    = overflow_re
m_axis_z_tdata[51]    = overflow_im
m_axis_z_tdata[54:52] = beam_id, 0..6
m_axis_z_tdata[63:55] = reserved, must be zero
```

One output frame:

```text
7 beats
```

Output order:

```text
beam 0, beam 1, ..., beam 6
```

`TLAST`:

```text
assert when beam_id = 6
```

`TKEEP`:

```text
8'hFF
```

When:

```text
m_axis_z_tvalid = 1
m_axis_z_tready = 0
```

the implementation must hold `tdata`, `tlast`, and `tkeep` stable.

## First-Version Flow-Control Rule

To avoid output-buffer overflow in the first version, from the time the last
input beat of a frame is accepted until all seven Z beats are transmitted:

```text
s_axis_y_tready must remain 0
```

This makes the first implementation simple and deterministic. A later version
may relax this with an explicit output buffer or frame FIFO.

## Undefined In Version One

Version one does not define:

- `TUSER`
- DMA descriptor metadata
- packet side-channel policy
