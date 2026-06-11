# Step12 Beamspace ML FPGA Boundary

Step 12 is the FPGA feasibility boundary validation for the Step 11.x beamspace ML backend.

It focuses on Step11 ML-specific objects and decisions:

- `W`
- `G_cache`
- `Y_work`
- `Z = W'Y_work`
- `Rz = Z*Z'` in the Step11 score path
- candidate score
- topK
- C05 policy diagnostics

## Relationship To Step8.9

Step8.9 is only a project-local fixed-point validation workflow reference. Step 12 does not use Step8.9 results, does not inherit Step8.9 pass/fail standards, and does not reuse Step8.9 fields such as `fixed_point_pass_flag`, `recommended_fixed_point_format`, or `quantization_not_closed` as conclusions.

`uses_step89_results_flag` is always written as `0`.

## Step11 Adapter

The Step12 adapter uses the final Step11 engineering route:

- Final backend entry: `step11_7_final_cached_c05_beamspace_ml_backend(input, context, opts)`
- Context/input builders: `build_step11_7_runtime_context`, `build_step11_7_frontend_like_input`
- Score objective: Step11.1 `beamspace_dml_score(Z, G, 'reg', reg)`, equivalent to `J(Theta)=trace(P_G Z Z')`
- W source: Step11.7 context, `greedy_combined_B7`
- G cache source: Step11.7 / Step11.6 `canonical_beamspace_G_cache`
- Policy diagnostic source: Step11.5 C05 policy logic, through `compute_likelihood_landscape_features_v2` and `select_adaptive_topk_window_policy_v2`

The script builds a non-invasive Step12 candidate-score adapter. It does not change the default Step11.7 backend output.

If the Step11 score path cannot be found or called, the script still writes blocker outputs with:

- `step11_adapter_found_flag = 0`
- `fixed_point_pass_flag = 0`
- `blocker_if_any = step11_score_function_not_exposed` or the adapter runtime blocker

## Formal Criterion

Primary pass/fail is determined only by ML score ranking consistency and fixed-point topK preservation.

`ranking_pass_flag` requires:

- `reliable_top1_preservation_rate >= 0.999`
- `reliable_score_gap_sign_flip_rate == 0`
- `argmax_changed_rate_on_reliable_margin <= 0.001`

`topK_pass_flag` requires:

- `reliable_topK_set_preservation_rate >= 0.995`
- `overall_topK_set_preservation_rate >= 0.980`
- `reliable_topK_miss_rate <= 0.005`

`fixed_point_pass_flag = ranking_pass_flag AND topK_pass_flag`.

`float32_all` is only a diagnostic reference and is not a fixed-point pass candidate.

Policy is engineering risk diagnostics. Formal fixed-point pass/fail is decided by ML score ranking consistency and topK preservation.

## What This Step Is Not

Step 12 is not:

- a complete FPGA RTL implementation
- bit-true HDL simulation
- a full pure-FPGA backend claim
- reuse of Step8.9 results
- algorithm performance retuning

Even when `proceed_to_rtl_score_core_flag = 1`, `proceed_to_full_fpga_backend_flag` remains `0`.

## Quantization Modes

Required modes include:

- `double_baseline`
- `float32_all`
- `W_int16_only`
- `Gcache_int16_only`
- `Z_int16_only`
- `Rz_int18_only`
- `combined_int16`
- `combined_int18`
- `combined_int24`
- `mixed_Z16_G24_score_float`
- `mixed_Z16_G24_Rz24`

Additional diagnostic modes may be present. Quantization is pure MATLAB round/clip/scale simulation and does not require Fixed-Point Designer.

## Run

Quick smoke test:

```matlab
setenv('STEP12_QUICK_MODE','1')
run_step12_beamspace_ml_fpga_boundary
```

From the project root:

```matlab
matlab -batch "setenv('STEP12_QUICK_MODE','1'); run('setup_paths.m'); cd('steps/step_12_beamspace_ml_fpga_boundary'); run_step12_beamspace_ml_fpga_boundary"
```

Formal mode omits `STEP12_QUICK_MODE=1` and uses the script's non-quick trial settings. If a run is quick mode, `quick_mode_flag=1`; it is a smoke test and must not be written as a formal FPGA feasibility conclusion.

## Outputs

Results are written to:

`steps/step_12_beamspace_ml_fpga_boundary/results_step12_beamspace_ml_fpga_boundary/`

CSV outputs:

- `step12_ml_fpga_boundary_trial.csv`
- `step12_ml_fpga_boundary_summary.csv`
- `step12_ml_fpga_boundary_keypoints.csv`
- `step12_ml_fpga_boundary_score_gap.csv`
- `step12_ml_fpga_boundary_topk.csv`
- `step12_ml_fpga_boundary_storage_estimate.csv`
- `step12_ml_fpga_boundary_bandwidth_estimate.csv`
- `step12_ml_fpga_boundary_worst_cases.csv`
- `step12_ml_fpga_boundary_recommendations.csv`

Figures:

- `topK_preservation_by_quant_mode.png`
- `ranking_consistency_by_quant_mode.png`
- `score_gap_error_by_quant_mode.png`
- `argmax_change_vs_score_gap.png`
- `cache_storage_by_object.png`
- `cache_bandwidth_by_parallel_lanes.png`
- `fixed_point_recommended_modes.png`

MAT output:

- `step12_ml_fpga_boundary_result.mat`
