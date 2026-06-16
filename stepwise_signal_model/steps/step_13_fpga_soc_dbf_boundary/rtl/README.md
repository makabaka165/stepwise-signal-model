# Step13.2 DBF RTL Prototype

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

This is not a complete FPGA backend. It does not implement `Rz`, `G_cache`,
2D ML search, topK, C05, confidence, fallback, board IO, or timing closure.
The first smoke checks raw accumulator equivalence against MATLAB compact
golden vectors.

