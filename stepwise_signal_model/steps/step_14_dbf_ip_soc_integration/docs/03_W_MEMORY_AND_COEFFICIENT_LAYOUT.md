# W Memory And Coefficient Layout

Step14 uses the Step13 closed DBF format:

```text
N = 2080
B = 7
complex W18
```

Each input element needs weights for seven beams:

```text
7 beams x complex(18 + 18) = 252 bits
```

## Replaceable W Provider Interface

The first-stage datapath sees W through a replaceable provider interface:

```text
element_index
-> packed w_re_bus[7*18-1:0]
-> packed w_im_bus[7*18-1:0]
```

Lane packing:

```text
lane 0 is in the lowest valid slice
bus[0 +: 18]
```

For beam `b`, the provider exposes:

```text
w_re_bus[b*18 +: 18]
w_im_bus[b*18 +: 18]
```

The provider must align the returned W lanes to the accepted Y element index.
The index advances only on:

```text
s_axis_y_tvalid && s_axis_y_tready
```

## First Simulation Provider

The first simulation stage uses a `.mem`-initialized ROM provider:

```text
dbf_w_provider_rom
```

This is a simulation and RTL smoke provider. It is not the only intended
coefficient-loading mechanism.

## Layering

The first Step14 modules are layered as:

```text
dbf_w_provider_rom
dbf_axis_datapath
dbf_axis_system_top
```

`dbf_axis_datapath` must not depend on a specific board, PS, DMA, or Vivado
Block Design. It consumes accepted Y samples, receives W from a provider, and
emits serialized Z beats.

## Future Provider Replacements

Future work may replace the ROM provider without changing the DBF datapath:

- BRAM controller
- AXI-Lite coefficient loader
- double-buffer W bank
- user-owned W model
- real-time weight generation module

The replacement boundary is the W provider interface, not the Step13 arithmetic
core.
