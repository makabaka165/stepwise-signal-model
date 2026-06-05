Stage1 W pool diagnostics plan
==============================

Stage1 only diagnoses W choices. It does not run the pair2d ML backend.

Inputs
------

- `cfg = sim_cfg()`
- active cylindrical subarray from `arr_cyl(cfg, cfg.beam.azSectorCenter)`
- `lambda = cfg.arr.lambda`
- `phase_factor = cfg.beam.spatialPhaseFactor`
- `phase_sign = +1`

Candidate pool
--------------

The candidate pool first reuses the existing cylindrical az/el beam-transform
builder. If no direct old center-pool function is callable, it uses the local
compatible fallback grid:

```text
az_pool = az_c + (-2.4:0.4:2.4)
el_pool = el_c + (-1.6:0.4:1.6)
```

Test sizes:

```text
B_list = [9, 15, 25]
```

Local patch:

```text
az_patch = az_c + (-1.5:0.15:1.5)
el_patch = el_c + (-1.0:0.15:1.0)
```

Pair test set:

```text
az_sep_list = [0.83, 1.27]
el_sep_list = [0, 0.37, 0.67]
orientation_list = [+1, -1]
```

Methods
-------

- `regular_3dB_grid`
- `greedy_projection`
- `greedy_lowcorr`
- `greedy_combined`
- `svd_upper_bound`
- `random_pool_baseline`

Outputs
-------

- `step11_2_w_pool_diagnostics_summary.csv`
- `step11_2_w_pool_diagnostics_keypoints.csv`
- `step11_2_w_pool_diagnostics_result.mat`
- `step11_2_w_pool_diagnostics.log`
- `w_projection_loss_vs_B.png`
- `w_max_corr_vs_B.png`
- `w_cond_vs_B.png`
- `w_svd_energy_curve.png`

