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
- el sep degree list: `[0, 0.24, 0.36, 0.48, 0.60, 0.72]`

Coarse grid:

- az step: `0.16` deg
- el step: `0.24` deg
- el sep degree list: `[0, 0.36, 0.48, 0.72]`

Refinement:

- fine az step: `0.04` deg
- fine el step: `0.06` deg
- local az half-width: `0.32` deg
- local el-center half-width: `0.48` deg
- fine el sep degree list: `[0, 0.24, 0.36, 0.48, 0.60, 0.72]`
- topK: `10`

The elevation-separation list is degree-based in every stage. It is no longer
derived from `el_step`, so changing full/coarse/refine grid spacing does not
change the physical `el_sep` hypotheses.

Latest Stage1 result after rerun:

- `full_fine_success = 1`
- `coarse_only_success = 0.6`
- `coarse_to_fine_success = 1`
- `complexity_reduction_ratio = 1.11896672474`
- `topK_miss_rate = 0`
- `search_acceleration_pass_flag = 0`

Stage1 therefore verifies the degree-based correction and topK coverage, but
the default configuration still needs Stage2 topK/refine-window tuning to meet
the complexity gate.

Outputs include full fine, coarse only, and coarse-to-fine success/RMSE,
candidate counts, reduction ratio, full-grid match rate, and topK miss rate.
