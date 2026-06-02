# Final Thesis Route

This directory is the final thesis-facing route for the shared-center enhanced DOA method. It does not introduce a new backend experiment and does not claim that Step09-light passed final validation.

Method name:

```text
面向全息凝视圆柱阵局部未分辨目标簇的 shared-center 增强测角方法
```

Final route:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

Final decision:

- Step09-light backend is not adopted.
- Step09-Step87 bridge backend is not adopted as the default backend.
- common-el gate alignment is not adopted.
- Step8.7 verified lazy cascade is the final algorithm backend and performance evidence.
- Step09 remains an interface layer, thesis framing layer, and negative-evidence archive.

Recommended next action: do not continue Step09 backend experiments. Move to thesis writing, figure preparation, and defense material cleanup.

Required reading:

- [docs/00_FINAL_ROUTE_POSITIONING.md](docs/00_FINAL_ROUTE_POSITIONING.md)
- [docs/03_FINAL_ALGORITHM_PSEUDOCODE.md](docs/03_FINAL_ALGORITHM_PSEUDOCODE.md)
- [docs/05_EXPERIMENT_EVIDENCE_TABLES.md](docs/05_EXPERIMENT_EVIDENCE_TABLES.md)
- [docs/10_FINAL_ROUTE_ONE_PAGE_SUMMARY.md](docs/10_FINAL_ROUTE_ONE_PAGE_SUMMARY.md)

