Stage2 topK and grid sweep plan
===============================

Stage2 searches for a passing coarse-to-fine acceleration configuration after
the degree-based `el_sep` correction. The goal is to reduce refine candidate
count without sacrificing full fine-grid success, RMSE, or topK coverage.

Fixed:

- `W = greedy_combined_B7`
- backend: controlled pair2d beamspace ML
- beamspace model: `Z = W' * Y`
- manifold: `G = W' * A_cyl`
- whitening: `white`
- center prior: nominal center plus configured bias, never true-angle center
- scenarios: the same five representative scenarios as Stage1
- full fine baseline: `az_step=0.08`, `el_step=0.12`,
  `el_sep_deg_list=[0, 0.24, 0.36, 0.48, 0.60, 0.72]`

Two-phase tuning:

- Screening uses `Metkl=3` over a compact set of coarse/refine/topK
  configurations. It filters out configurations with high topK miss or weak
  reduction.
- Confirmation reruns at most five selected configurations with `Metkl=10`
  and the full five-scenario set.

Screening candidates:

- coarse configs: compact/minsep variants at `[0.16, 0.24]` and `[0.20, 0.30]`
  degree steps
- topK: `[3, 5, 7, 10]`
- refine configs: small/mid/safe windows with compact or full physical
  `fine_el_sep_deg_list`

Screening score:

```text
score =
  coarse_to_fine_success
  - 2 * max(0, 0.95 * full_fine_success - coarse_to_fine_success)
  - topK_miss_rate
  + 0.1 * log10(max(complexity_reduction_ratio, 1))
  - 0.2 * boundary_hit_rate
```

Screening pass requires:

- `coarse_to_fine_success >= 0.95 * full_fine_success`
- `topK_miss_rate <= 0.10`
- `coarse_to_fine_worst_case_success >= 0.8`
- `complexity_reduction_ratio >= 1.5`

Final confirmation pass requires:

- `coarse_to_fine_success >= 0.95 * full_fine_success`
- `coarse_to_fine_rmse <= 1.05 * full_fine_rmse`, or
  `coarse_to_fine_rmse <= full_fine_rmse + 0.02`
- `topK_miss_rate <= 0.05`
- `boundary_hit_rate <= 0.2`
- `complexity_reduction_ratio >= 2`

The recommended config is the passing confirmation config with the largest
complexity reduction ratio. If no config passes, Stage2 reports the nearest
configuration and keeps `search_acceleration_pass_flag = 0`.
