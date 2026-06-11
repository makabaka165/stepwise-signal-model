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

Formal `fixed_point_pass_flag` additionally requires `quick_mode_flag = 0` and `formal_trial_count >= STEP12_MIN_FORMAL_OBS`.

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

Formal mode omits `STEP12_QUICK_MODE=1` and uses:

- `center_az_list = [0, 4, 8, 15]`
- all Step12 scenarios
- `STEP12_FORMAL_TRIALS_PER_SCENARIO`, default `30`
- `STEP12_MIN_FORMAL_OBS`, default `300`

Pilot and formal wrappers:

```matlab
run_step12_pilot_validation
run_step12_formal_validation
```

`run_step12_pilot_validation` sets `STEP12_RUN_TAG=pilot_tps10`, `STEP12_FORMAL_TRIALS_PER_SCENARIO=10`, and `STEP12_MIN_FORMAL_OBS=100`.

`run_step12_formal_validation` sets `STEP12_RUN_TAG=formal_tps30`, `STEP12_FORMAL_TRIALS_PER_SCENARIO=30`, and `STEP12_MIN_FORMAL_OBS=300`.

For a shorter formal run, set for example:

```matlab
setenv('STEP12_FORMAL_TRIALS_PER_SCENARIO','10')
setenv('STEP12_FORMAL_SCENARIO_LIMIT','2')
setenv('STEP12_RUN_TAG','pilot_custom')
run_step12_beamspace_ml_fpga_boundary
```

Formal environment variables:

- `STEP12_FORMAL_TRIALS_PER_SCENARIO`: trials per scenario and center, default `30`.
- `STEP12_FORMAL_CENTER_AZ_LIST`: comma-separated center azimuth list, default `0,4,8,15`.
- `STEP12_FORMAL_SCENARIO_LIMIT`: optional scenario count cap; unset means all Step12 scenarios.
- `STEP12_MIN_FORMAL_OBS`: minimum observation count required before formal pass can be asserted, default `300`.
- `STEP12_RUN_TAG`: optional result subdirectory under `results_step12_beamspace_ml_fpga_boundary/`.
- `STEP12_EXPORT_GOLDEN_VECTORS`: set to `1` to export compact RTL score-core golden vectors after a formal fixed-point pass.
- `STEP12_GOLDEN_VECTOR_LIMIT`: maximum candidate subset per golden case, default `256`.
- `STEP12_SAVE_FULL_MAT`: set to `1` to save the ignored local full MAT.
- `STEP12_RUN_FULL_STEP11_BACKEND`: set to `1` to run the full Step11.7 backend for formal diagnostics; default formal mode uses the non-invasive Step12 score-core adapter with the same Step11 score objective.

The current tracked pilot artifact `pilot_min_fast_path` is a formal-path smoke run with `formal_trial_count=12` and `blocker_if_any=formal_trial_count_below_minimum`. It is not a formal validation conclusion. The requested `pilot_tps10` was attempted but did not complete within the interactive execution window; `formal_tps30` was not run in this commit.

## Mode Selection

Step12 writes `step12_ml_fpga_boundary_mode_selection.csv`.

- `combined_int16` is evaluated as a candidate. It is not forced as the final recommendation.
- `minimum_passing_mode` is the lowest-cost fixed candidate that passes formal ranking/topK gates.
- `engineering_recommended_fixed_point_format` is selected from formal ranking/topK preservation and resource estimates, preferring practical modes such as `combined_int16`, `combined_int18`, `mixed_Z16_G24_Rz24`, and `combined_int24`.

Proceed to RTL score core prototype only when formal `fixed_point_pass_flag=1`. Proceeding to RTL score core does not imply full FPGA backend validation.

## Score Gap Stress

Step12 writes `step12_ml_fpga_boundary_score_gap_bins.csv` with bins:

- `gap_bin_very_weak`: `score_gap_norm < 1e-5`
- `gap_bin_weak`: `1e-5 <= score_gap_norm < 1e-4`
- `gap_bin_transition`: `1e-4 <= score_gap_norm < 1e-3`
- `gap_bin_reliable`: `score_gap_norm >= 1e-3`

The keypoints include `reliable_margin_instability_flag`, `failures_limited_to_low_margin_cases`, and `worst_gap_bin_for_recommended_mode`.

If a run is quick mode, `quick_mode_flag=1`; it is a smoke test and must not be written as a formal FPGA feasibility conclusion. In quick mode, the script writes `smoke_fixed_point_pass_flag` and `smoke_recommended_fixed_point_format`, while formal `fixed_point_pass_flag` stays `0`, `recommended_fixed_point_format` is `not_recommended_until_formal_validation`, and `blocker_if_any` is `formal_validation_not_run`.

Full MAT output is disabled by default. To regenerate it locally:

```matlab
setenv('STEP12_SAVE_FULL_MAT','1')
run_step12_beamspace_ml_fpga_boundary
```

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
- `step12_ml_fpga_boundary_mode_selection.csv`
- `step12_ml_fpga_boundary_score_gap_bins.csv`

Golden vector outputs, when enabled after formal pass:

- `step12_ml_fpga_boundary_golden_vector_manifest.md`
- `golden_vectors/case_*/case_manifest.csv`
- compact CSV files for candidate subset, topK scores, fixed/baseline expected scores, scales, `Rz_q`, and `G_pair_subset_q`

Figures:

- `topK_preservation_by_quant_mode.png`
- `ranking_consistency_by_quant_mode.png`
- `score_gap_error_by_quant_mode.png`
- `argmax_change_vs_score_gap.png`
- `cache_storage_by_object.png`
- `cache_bandwidth_by_parallel_lanes.png`
- `fixed_point_recommended_modes.png`

MAT output:

- `step12_ml_fpga_boundary_result_light.mat`, tracked-friendly light MAT without full observations, context, cache, or candidate-table payloads
- `step12_ml_fpga_boundary_result_full.mat`, optional local full MAT only when `STEP12_SAVE_FULL_MAT=1`; ignored by Git by default
- `step12_ml_fpga_boundary_mat_manifest.md`, manifest explaining light/full MAT policy and quick-vs-formal semantics
