Step11.3 beamspace ML search acceleration
=========================================

Step11.3 studies search-complexity reduction for the fixed Step11.1
controlled pair2d beamspace ML backend.

Scope
-----

- The backend remains controlled pair2d beamspace ML.
- The default W is the Step11.2 final recommendation:
  `greedy_combined_B7`.
- The beamspace data model remains `Z = W' * Y`.
- The search manifold remains `G = W' * A_cyl`.
- This step only changes how candidate angles are searched.
- This step is not AP, not full4D, not a new ML model, and not element-domain
  ML.
- This step does not modify Step11.1, Step11.2, Step9, Step10, or
  `step_11_supersolution_ml`.

Frontend prior interpretation
-----------------------------

The front-end 2D/three-beam logic provides a coarse center and search window.
Step11.3 runs coarse-to-fine ML inside that local window. Simulation uses
`nominal center + bias` to emulate front-end coarse-angle error. The search
center is not derived from the true target angles.

Stages
------

- Stage1: coarse-to-fine sanity against the full fine grid.
- Stage2: topK and grid-step sweep.
- Stage3: frontend-prior bias robustness.

Run entries
-----------

```matlab
run('setup_paths.m')
run('steps/step_11_3_beamspace_ml_search_acceleration/stage1_coarse_to_fine_sanity/run_stage1_coarse_to_fine_sanity.m')
run('steps/step_11_3_beamspace_ml_search_acceleration/stage2_topk_grid_sweep/run_stage2_topk_grid_sweep.m')
run('steps/step_11_3_beamspace_ml_search_acceleration/stage3_frontend_prior_bias_robustness/run_stage3_frontend_prior_bias_robustness.m')
```

Outputs
-------

- `results_step11_3_stage1_coarse_to_fine_sanity/`
- `results_step11_3_stage2_topk_grid_sweep/`
- `results_step11_3_stage3_frontend_prior_bias_robustness/`

Current Status
--------------

The Step11.3 implementation is self-contained under this directory:

- `common/search_pair2d_coarse_grid_topk.m` keeps the topK coarse ML
  candidates without modifying the Step11.1 baseline search routine.
- `common/search_pair2d_local_refine_from_topk.m` evaluates local fine grids
  around every retained coarse candidate.
- `common/evaluate_search_acceleration_backend.m` records success, RMSE,
  `num_pairs`, reduction ratio, full-grid match, topK miss, and boundary-hit
  metrics.
- `common/summarize_search_acceleration_keypoints.m` selects the Stage2
  recommended topK and grid steps using the full fine-grid baseline constraints.

Stage Outputs
-------------

Stage1 writes:

- `step11_3_stage1_trial.csv`
- `step11_3_stage1_summary.csv`
- `step11_3_stage1_keypoints.csv`
- `step11_3_stage1_result.mat`
- `step11_3_stage1.log`
- PNG plots for success, RMSE, candidate counts, reduction ratio,
  full-grid match, and topK miss.

Stage2 writes the same file family with `stage2` names and reports:

- `recommended_topK`
- `recommended_coarse_az_step`
- `recommended_coarse_el_step`
- `recommended_fine_az_step`
- `recommended_fine_el_step`
- `complexity_reduction_ratio`
- `full_grid_match_rate`
- `topK_miss_rate`

Stage3 loads the Stage2 recommendation when available. If Stage2 has not been
run yet, it uses the conservative Stage1 default:
`topK=5`, coarse step `[0.16, 0.24] deg`, fine step `[0.04, 0.06] deg`.
It reports zero-bias success, maximum bias success drop, maximum topK miss,
boundary-hit risk, valid bias range, and the frontend-prior robustness pass flag.
