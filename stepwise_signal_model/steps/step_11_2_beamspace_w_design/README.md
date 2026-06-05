Step11.2 beamspace W design
===========================

Step11.2 is a follow-up to Step11.1. It keeps the controlled pair2d
beamspace ML backend fixed and studies how to choose the beamspace
transform matrix W.

Scope
-----

- This step is not a new ML backend.
- The backend remains the Step11.1 controlled pair2d beamspace ML route.
- The beamspace data model remains `Z = W' * Y` and
  `G(theta) = W' * A_cyl(theta)`.
- This step does not modify Step11.1, Step9, Step10, or
  `step_11_supersolution_ml`.
- This step does not rerun full4D, AP, model-selection boundaries, or
  element-domain ML.

Relation to the old 2D beam layout
----------------------------------

The old 2D beams were used by the front-end for coverage, detection, coarse
angle estimation, and beam-ratio logic. Step11.2 uses a compatible candidate
pool based on those 2D beam-center ideas, then selects a lower-dimensional W
for the fixed pair2d ML backend.

If a direct reusable old beam-center pool is not available, Step11.2 uses a
local fallback grid:

- azimuth offsets: `-2.4:0.4:2.4` deg
- elevation offsets: `-1.6:0.4:1.6` deg

This fallback is documented as a compatible replication of the existing
3dB-overlap 2D beam layout idea, not as a new front-end beam design.

Compared W choices
------------------

- `regular_3dB_grid`
- `greedy_projection`
- `greedy_lowcorr`
- `greedy_combined` for Stage1 diagnostics
- `svd_upper_bound`
- `random_pool_baseline`

Run entries
-----------

From the repository root:

```matlab
run('setup_paths.m')
run('steps/step_11_2_beamspace_w_design/stage1_w_pool_diagnostics/run_stage1_w_pool_diagnostics.m')
run('steps/step_11_2_beamspace_w_design/stage2_w_selection_validation/run_stage2_w_selection_validation.m')
```

Current status
--------------

Stage1 and Stage2 have been run. Results are generated under:

- `results_step11_2_w_pool_diagnostics/`
- `results_step11_2_w_selection_validation/`

Stage1 keypoints:

- B25 regular projection loss: `0.121341194434`
- B25 best greedy projection loss: `0.186246043264`
- B25 SVD projection loss: `0.0027693581663`
- B25 regular max correlation: `0.476965684438`
- B25 best greedy max correlation: `0.250602286634`
- B25 SVD max correlation: `0.323886368776`

Stage2 keypoints:

- B25 regular success: `0.4`
- B25 greedy success: `0.6`
- B25 SVD success: `0.4`
- B25 regular worst-case success: `0`
- B25 greedy worst-case success: `0`
- B25 regular combined RMSE: `0.106144402704`
- B25 greedy combined RMSE: `0.09888964751`

Current recommendation:

- Use `greedy_lowcorr_B25` as the best backend W candidate in this limited
  validation because it improves average success and combined RMSE.
- Document that the hardest scenarios still have zero worst-case success, so W
  selection alone does not solve the weak/low-SNR coherent pair case.
- Keep SVD as an upper-bound diagnostic, not as an engineering beam.
- The next step is writing and evidence整理, not AP/full4D/model-selection reruns.
