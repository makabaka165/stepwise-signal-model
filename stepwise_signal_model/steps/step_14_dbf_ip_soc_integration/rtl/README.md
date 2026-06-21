# RTL

This directory contains the Step14 AXI4-Stream DBF RTL.

Step14.1 modules:

- `dbf_w_provider_rom.v`
- `dbf_axis_z_serializer.v`
- `dbf_axis_datapath.v`
- `dbf_axis_system_top.v`

Step14.2 adds:

- `dbf_axis_ip_top.v`

Step14.2a optimized RTL adds:

- `dbf_complex_mac_pipe.v`
- `dbf_beam_accum_core_pipe.v`
- `dbf_z24_quantizer_pipe.v`
- `dbf_core_z24_pipe.v`
- `dbf_core_z24_bparallel_pipe.v`
- `dbf_w_rom18_split.v`
- `dbf_w_provider_rom_opt.v`
- `dbf_axis_datapath_pipe.v`
- `dbf_axis_system_top_opt.v`

`dbf_axis_ip_top` is the Vivado Custom IP top. It wraps the optimized
`dbf_axis_system_top_opt`, fixes the Step14 parameters, binds the 28 split W ROM
files, exposes `S_AXIS_Y` and `M_AXIS_Z`, and preserves discrete status outputs.
It does not instantiate DMA, PS, AXI-Lite, FIFO IP, ILA, Clocking Wizard, or
Block Design logic.

The optimized W provider uses XPM single-port ROM instances for each 2048-row
main segment plus distributed 32-row tails. The current reference-device
synthesis maps W storage to 14 BRAM36 equivalents.

Step13 arithmetic RTL remains the baseline source of truth and is not modified.
The Step14.2a pipelined quantizer is an integration-local timing equivalent and
is verified by raw-top XSim, packaged-IP XSim, and MATLAB exact compare.
