# FPGA/SoC Implementation Boundary

The final thesis route should describe a practical FPGA/SoC split rather than claiming that the full Step8.7 backend is already a pure fixed-point FPGA pipeline.

FPGA is suitable for:

- LFM and pulse compression;
- MTD / FFT;
- CFAR;
- coarse beamforming;
- 65-column work subarray extraction;
- steering LUT access;
- projection or spectrum acceleration.

SoC / CPU / DSP / floating IP is suitable for:

- EVD;
- route decision;
- rank1 fallback decision;
- pair-local decision;
- confidence and boundary state machine;
- logging and tracking interface.

The thesis should state explicitly that a complete Step8.7 backend fixed-point FPGA flow is not yet closed. Step8.9 is hardware boundary evidence, not a full hardware implementation success.

