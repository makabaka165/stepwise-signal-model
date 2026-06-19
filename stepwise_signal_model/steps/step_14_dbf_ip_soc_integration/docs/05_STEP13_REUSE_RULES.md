# Step13 Reuse Rules

Step13 is frozen. Step14 reuses Step13 as the DBF arithmetic source of truth
without continuing new IP, DMA, or SoC integration work inside the Step13
directory.

## Frozen Step13 Arithmetic

Step14 inherits:

```text
W18 / Y16 / ACC48 / Z24
engineering_Z_shift_bits = 20
N = 2080
B = 7
Z = W^H Y
```

Do not modify Step13 RTL to serve Step14. Step14 integration belongs in:

```text
steps/step_14_dbf_ip_soc_integration/
```

## RTL Reuse Set

Step14 should reuse only the necessary stable DBF arithmetic RTL:

- `dbf_complex_mac.v`
- `dbf_beam_accum_core.v`
- `dbf_z24_quantizer.v`
- `dbf_core_z24.v`
- `dbf_core_z24_bparallel.v`
- fixed shift parameter

Do not directly copy the entire Step13 result directory into Step14.

## First-Stage Reference Method

During the first RTL/XSim stage, Vivado/XSim Tcl may directly reference stable
RTL paths from Step13.

During the later IP Packager stage, scripts may copy stable RTL into a temporary
staging/IP directory. Do not manually maintain two drifting copies of the DBF
arithmetic RTL.

## Step11.7 Boundary

Step14 does not change Step11.7 backend default behavior. Step11-compatible
Y/W vectors may be used as input data for the Step14 system smoke, but Step14
does not move Step11.7 ML backend modules into FPGA RTL.

## Explicit Non-Reuse

Do not reuse or migrate `codex/step12-fpga-soc`. Step14 starts from the closed
Step13 branch and only adds the Step14 integration framework.
