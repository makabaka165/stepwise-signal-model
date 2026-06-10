# Limitations And Usage Boundary

Step11.7 is not the full LFM, pulse compression, MTD, or CFAR frontend chain.

It is not a new ML model, does not change C05, does not redesign W, and does not change the controlled pair2d beamspace ML score.

Lookup is exact-grid only. Interpolation is not part of the default route.

The shared-center canonical local order is required, and cache metadata must match W method, canonical order, lookup mode, and interpolation flag.

Full-field arbitrary multi-target search and fixed-point FPGA implementation are not claimed here.
