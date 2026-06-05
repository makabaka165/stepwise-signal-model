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

- Stage1/common now use degree-based controlled pair2d elevation separation:
  `el_sep_deg_list` / `fine_el_sep_deg_list`. The old index-based
  `el_sep_index_list` path remains only as a legacy fallback in grid building,
  not as the Stage1 default.
- `common/search_pair2d_coarse_grid_topk.m` keeps the topK coarse ML
  candidates without modifying the Step11.1 baseline search routine.
- `common/search_pair2d_local_refine_from_topk.m` evaluates local fine grids
  around every retained coarse candidate.
- `common/evaluate_search_acceleration_backend.m` records success, RMSE,
  `num_pairs`, reduction ratio, full-grid match, topK miss, and boundary-hit
  metrics.
- `common/summarize_search_acceleration_keypoints.m` selects the Stage2
  recommended topK and grid steps using the full fine-grid baseline constraints.

Latest Stage1 keypoints after the degree-based el-separation correction:

- `full_fine_success = 1`
- `coarse_only_success = 0.6`
- `coarse_to_fine_success = 1`
- `full_fine_rmse = 0.0770101090859`
- `coarse_to_fine_rmse = 0.0182032989911`
- `complexity_reduction_ratio = 1.11896672474`
- `topK_miss_rate = 0`
- `search_acceleration_pass_flag = 0`
- `recommended_next_step = tune_topK_or_refine_window`

Interpretation: the degree-based correction fixes the topK miss and
coarse-to-fine success problem, but the default Stage1 topK/window setting is
not yet a passing acceleration configuration because the complexity reduction
ratio is below the `>= 2` gate. Stage2 should sweep topK and refine-window
settings to recover enough reduction while preserving the restored success
rate.

Latest Stage2 status after the two-phase screening + confirmation sweep:

- `recommended_config_name = coarse_016_024_minsep__topK3__refine_safe_fullsep`
- `recommended_topK = 3`
- coarse grid: `az_step=0.16`, `el_step=0.24`,
  `el_sep_deg_list=[0, 0.36, 0.72]`
- refine grid: `fine_az_step=0.08`, `fine_el_step=0.12`,
  local half-width `[0.32, 0.48] deg`,
  `fine_el_sep_deg_list=[0, 0.24, 0.36, 0.48, 0.60, 0.72]`
- `coarse_to_fine_success = 1`
- `coarse_to_fine_rmse = 0.0765589261214`
- `complexity_reduction_ratio = 6.86054096932`
- `topK_miss_rate = 0`
- `boundary_hit_rate = 0`
- `search_acceleration_pass_flag = 1`
- `recommended_next_step = run_stage3_frontend_prior_bias_with_recommended_config`

Stage3 has been rerun with the Stage2 recommended config and passes the
frontend-prior robustness check:

- `zero_bias_success = 1`
- `max_bias_success_drop = 0.06`
- `max_bias_topK_miss_rate = 0`
- `max_bias_boundary_hit_rate = 0`
- `valid_bias_range_text = az_bias=[-0.20,0.20], el_bias=[-0.20,0.20]`
- `frontend_prior_robustness_pass_flag = 1`

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

Stage2 writes screening and confirmation outputs:

- `step11_3_stage2_screening_trial.csv`
- `step11_3_stage2_screening_summary.csv`
- `step11_3_stage2_confirmation_trial.csv`
- `step11_3_stage2_confirmation_summary.csv`
- `step11_3_stage2_config_table.csv`
- `step11_3_stage2_keypoints.csv`
- `step11_3_stage2_result.mat`
- `step11_3_stage2.log`
- PNG plots, including Stage2 config success/reduction, topK, refine-window,
  RMSE, topK-miss, and recommended-config views.

Stage3 loads the Stage2 recommendation only when Stage2 passes. If Stage2 has
not been run or does not pass, it uses the corrected degree-based Stage1
default:
`topK=10`, coarse step `[0.16, 0.24] deg`, fine step `[0.04, 0.06] deg`,
coarse `el_sep_deg_list=[0, 0.36, 0.48, 0.72]`, fine
`el_sep_deg_list=[0, 0.24, 0.36, 0.48, 0.60, 0.72]`, and local half-width
`[0.32, 0.48] deg`.
It reports zero-bias success, maximum bias success drop, maximum topK miss,
boundary-hit risk, valid bias range, and the frontend-prior robustness pass flag.

Final Evidence Summary
----------------------

Stage4 collects the existing Stage1--Stage3 outputs and produces final
evidence tables, figures, and thesis-writing Markdown. It does not rerun the
Stage1/Stage2/Stage3 searches and does not change the search logic.

Run entry:

```matlab
run('setup_paths.m')
run('steps/step_11_3_beamspace_ml_search_acceleration/stage4_final_search_acceleration_evidence_summary/run_stage4_final_search_acceleration_evidence_summary.m')
```

Result directory:

- `results_step11_3_final_search_acceleration_evidence_summary/`

Final recommendation:

- `use_degree_based_coarse_to_fine_topK3_for_controlled_pair2d_beamspace_ml`

Key metrics:

- `complexity_reduction_ratio = 6.86054096932`
- `full_grid_match_rate = 1`
- `topK_miss_rate = 0`
- `frontend_prior_robustness_pass_flag = 1`

Interpretation: Step11.3 is a search-acceleration contribution for the fixed
controlled pair2d beamspace ML backend. It is not AP, not a new W design, not a
new ML model, and not element-domain ML.
