# Step13 DBF RTL Prototype

This RTL folder contains a small accumulator-level prototype for the DBF
kernel:

```text
Z = W^H Y
```

The multiply is `conj(W) * Y`:

```text
p_re = w_re * y_re + w_im * y_im
p_im = w_re * y_im - w_im * y_re
```

Modules:

- `dbf_complex_mac.v`: combinational signed complex multiply.
- `dbf_beam_accum_core.v`: one beam, one snapshot streaming accumulator.
- `dbf_core_accum.v`: thin wrapper around one accumulator core.
- `dbf_z24_quantizer.v`: shift/round/saturate signed Z24 output quantizer.

Step13.3 adds the output datapath:

```text
ACC raw accumulator -> shift -> round -> saturate -> signed int24 Z output
```

The quantizer uses symmetric round-to-nearest by applying the shift to
`abs(acc)`, adding `2^(SHIFT_BITS-1)` before the right shift, restoring the
sign, and saturating to the signed int24 range. This is a hardware-friendly
shift-based fixed-point rule, not a runtime floating-point scale divide.

This is not a complete FPGA backend. It does not implement `Rz`, `G_cache`,
2D ML search, topK, C05, confidence, boundary, fallback, board IO, or timing
closure. Those functions remain CPU/SoC-side responsibilities by design. The
current smoke checks raw accumulator equivalence and Z24 output equivalence
against MATLAB compact golden vectors.

## Step13.4 Full-N Reference Tops

Step13.4 adds synthesizable Verilog-2001 reference tops for the final FPGA DBF
engineering boundary:

- `dbf_core_z24.v`: one DBF lane with ACC48 raw accumulator plus Z24 output.
- `dbf_core_z24_bparallel.v`: B-lane beam-parallel wrapper. Lane 0 is packed
  in the least-significant bus slice, `bus[0 +: WIDTH]`.
- `dbf_core_z24_ref_top.v`: fixed W18/Y16/ACC48/Z24 single-lane OOC synthesis
  top.
- `dbf_core_z24_b7_ref_top.v`: fixed B=7 beam-parallel OOC synthesis top.
- `step13_4_shift_params.vh`: generated engineering shift parameter. Current
  value is `STEP13_4_ENGINEERING_Z_SHIFT_BITS = 20`.

The closed datapath is still only FPGA DBF:

```text
Y stream -> W input/read -> conj(W)*Y -> full-N accumulation -> fixed shift
-> symmetric rounding -> signed int24 saturation -> Z output + clip/overflow flags
```

Vivado OOC synthesis on reference part `xc7z020clg400-1` reports 4 DSP per
complex lane and 28 DSP for the B=7 top. This is post-synthesis OOC evidence,
not implementation or board closure.
