Step11.2 beamspace W design
===========================

Step11.2 is a follow-up to Step11.1. It keeps the controlled pair2d
beamspace ML backend fixed and studies how to choose the beamspace transform
matrix W.

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
- `greedy_combined`
- `svd_upper_bound`
- `random_pool_baseline`

Run entries
-----------

From the repository root:

```matlab
run('setup_paths.m')
run('steps/step_11_2_beamspace_w_design/stage1_w_pool_diagnostics/run_stage1_w_pool_diagnostics.m')
run('steps/step_11_2_beamspace_w_design/stage2_w_selection_validation/run_stage2_w_selection_validation.m')
run('steps/step_11_2_beamspace_w_design/stage3_b_budget_strategy_tradeoff/run_stage3_b_budget_strategy_tradeoff.m')
run('steps/step_11_2_beamspace_w_design/stage4_recommended_w_robustness_confirmation/run_stage4_recommended_w_robustness_confirmation.m')
```

Current status
--------------

Stage1, Stage2, Stage3, and Stage4 have been run. Results are generated under:

- `results_step11_2_w_pool_diagnostics/`
- `results_step11_2_w_selection_validation/`
- `results_step11_2_b_budget_strategy_tradeoff/`
- `results_step11_2_recommended_w_robustness_confirmation/`

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

Stage3 keypoints:

- best backend method: `greedy_combined`
- best backend B: `7`
- best backend success: `1`
- best backend worst-case success: `1`
- recommended engineering B: `7`
- recommended high-performance B: `7`
- recommended W strategy: `greedy_combined`
- fallback strategy: `regular_3dB_grid_if_greedy_selection_is_not_available`

Stage4 keypoints:

- robustness pass flag: `1`
- B7 success: `1`
- B7 combined RMSE: `0.0991391728928`
- B7 worst-case success: `1`
- best method overall: `greedy_combined_B7`
- B25 combined success: `0.8`
- B25 lowcorr success: `0.8`
- recommended final W: `greedy_combined`
- recommended final B: `7`

Current recommendation
----------------------

- Stage2 recommended `greedy_lowcorr_B25` inside the B25-only validation
  because it improves average success and combined RMSE.
- Stage3 is the broader B-budget tradeoff and recommends
  `greedy_combined_B7` for the representative Metkl=3 sweep.
- Stage4 confirms `greedy_combined_B7` with Metkl=30 over the same
  representative scenarios. It should be written as the current engineering
  recommendation for this candidate pool and fixed pair2d backend, not as a
  universal optimum.
- Stage3 is not a new ML backend, AP, full4D, element-domain ML, or engineering
  closed loop.
- Keep SVD as an upper-bound diagnostic, not as an engineering beam.
- The next step is writing and evidence organization, not AP/full4D/model-selection reruns.
