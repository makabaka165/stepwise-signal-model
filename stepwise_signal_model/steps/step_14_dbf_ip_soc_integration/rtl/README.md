# RTL

This directory contains the Step14 AXI4-Stream DBF RTL.

Step14.1 modules:

- `dbf_w_provider_rom.v`
- `dbf_axis_z_serializer.v`
- `dbf_axis_datapath.v`
- `dbf_axis_system_top.v`

Step14.2 adds:

- `dbf_axis_ip_top.v`

`dbf_axis_ip_top` is the Vivado Custom IP top. It wraps
`dbf_axis_system_top`, fixes the Step14 parameters, binds the 14 basename W ROM
files, exposes `S_AXIS_Y` and `M_AXIS_Z`, and preserves discrete status outputs.
It does not instantiate DMA, PS, AXI-Lite, FIFO IP, ILA, Clocking Wizard, or
Block Design logic.

The W provider now uses XPM single-port ROM instances so OOC synthesis infers
memory resources. The current reference-device synthesis maps the 14 W ROMs to
BRAM36 resources.

Step13 arithmetic RTL remains the source of truth. It is referenced directly in
Step14.1 XSim and copied only into the Step14.2 generated IP staging tree for
Vivado IP self-containment.
