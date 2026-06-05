Stage1 coarse-to-fine sanity plan
=================================

Stage1 checks whether a simple coarse-to-fine configuration tracks the full
fine grid on representative scenarios.

Fixed:

- `W = greedy_combined_B7`
- backend: controlled pair2d beamspace ML
- whitening: `white`

Full fine grid:

- az step: `0.08` deg
- el step: `0.12` deg
- el sep index list: `[0, 1, 2]`

Coarse grid:

- az step: `0.16` deg
- el step: `0.24` deg
- el sep index list: `[0, 1, 2]`

Refinement:

- fine az step: `0.04` deg
- fine el step: `0.06` deg
- local az half-width: `0.16` deg
- local el half-width: `0.24` deg
- topK: `5`

Outputs include full fine, coarse only, and coarse-to-fine success/RMSE,
candidate counts, reduction ratio, full-grid match rate, and topK miss rate.

