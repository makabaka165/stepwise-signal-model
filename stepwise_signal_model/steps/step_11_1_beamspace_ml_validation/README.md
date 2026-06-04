# Step11.1 Beamspace ML Validation

Step11.1 is a validation extension for the existing Step11 beamspace ML route. It does not replace or rewrite any original Step11 files. Stage1 only studies one-dimensional ULA beamspace ML prior ablation; later stages may migrate the validated idea to cylindrical-array beamspace ML.

## Scope

This stage answers three narrow questions:

- Does the original Step11 left/right partitioned search create an optimistic result?
- If `beam_c` is not exactly the true two-target center, does performance degrade gracefully or collapse?
- After weakening the search prior, does ULA beamspace ML still work?

The implementation uses the common complex-signal notation `Z = W' * Y` and `G(Theta) = W' * A(Theta)`. Some original Step11 code uses transposed storage forms such as `A1.' * steering_vector_s` and `temp1 * A`; those are orientation-specific forms of the same beamspace mapping. In this folder, all new functions check matrix dimensions explicitly and use conjugate transpose notation for complex snapshots and manifolds.

## Run

```matlab
run('stepwise_signal_model/setup_paths.m')
run('stepwise_signal_model/steps/step_11_1_beamspace_ml_validation/stage1_ula_prior_ablation/run_stage1_ula_prior_ablation.m')
```

When running from the repository root, this equivalent entry is also valid:

```matlab
run('setup_paths.m')
run('steps/step_11_1_beamspace_ml_validation/stage1_ula_prior_ablation/run_stage1_ula_prior_ablation.m')
```

## Output

Results are written under:

```text
results_step11_1_ula_prior_ablation/
```

## Stage1 Current Status

Stage1 has a direct run entry:

```matlab
run('stepwise_signal_model/setup_paths.m')
run('stepwise_signal_model/steps/step_11_1_beamspace_ml_validation/stage1_ula_prior_ablation/run_stage1_ula_prior_ablation.m')
```

The result directory is `results_step11_1_ula_prior_ablation/`, and the main decision file is `step11_1_ula_prior_ablation_keypoints.csv`.

The current generated keypoints report `prior_dependency_flag = 0` for this Stage1 parameter set, with `recommended_next_step = proceed_to_cylindrical_azonly_beamspace_ml`.

Any conclusion from this stage applies only to ULA beamspace ML prior ablation. It must not be read as a completed cylindrical-array beamspace ML result, and it must not be read as an AP validation. The next stage is cylindrical-array az-only beamspace ML migration, not AP.

## Stage2 Current Status

Stage2 has a direct run entry:

```matlab
run('stepwise_signal_model/setup_paths.m')
run('stepwise_signal_model/steps/step_11_1_beamspace_ml_validation/stage2_cyl_azonly_beamspace_ml/run_stage2_cyl_azonly_beamspace_ml.m')
```

The result directory is `results_step11_1_cyl_azonly_beamspace_ml/`, and the main decision file is `step11_1_cyl_azonly_keypoints.csv`.

The current generated keypoints report `cyl_azonly_pass_flag = 1` with `recommended_next_step = proceed_to_cylindrical_2d_beamspace_ml_or_coherence_stress`.

Stage2 only validates cylindrical-array az-only beamspace ML with fixed `el0`. It is not a complete 2D az/el result, not an AP validation, not a strong-coherence final solution, and not a final thesis conclusion.

## Stage3 Current Status

Stage3 has a direct run entry:

```matlab
run('setup_paths.m')
run('steps/step_11_1_beamspace_ml_validation/stage3_cyl_common_el_2d_beamspace_ml/run_stage3_cyl_common_el_2d_beamspace_ml.m')
```

The result directory is `results_step11_1_cyl_common_el_2d_beamspace_ml/`, and the main decision file is `step11_1_cyl_common_el_2d_keypoints.csv`.

The current generated keypoints report `cyl_common_el_2d_pass_flag = 1` with `recommended_next_step = proceed_to_cylindrical_el_separation_or_coherence_stress`.

Stage3 validates cylindrical-array common-el 2D beamspace ML under a shared-elevation assumption. It is not a complete 4D pair az/el search, not an AP validation, not a strong-coherence final solution, and not a final thesis conclusion.

## Stage4 Current Status

Stage4 has a direct run entry:

```matlab
run('setup_paths.m')
run('steps/step_11_1_beamspace_ml_validation/stage4_cyl_el_separation_beamspace_ml/run_stage4_cyl_el_separation_beamspace_ml.m')
```

The result directory is `results_step11_1_cyl_el_separation_beamspace_ml/`, and the main decision file is `step11_1_cyl_el_separation_keypoints.csv`.

The current generated keypoints report `cyl_el_separation_pass_flag = 1` with `recommended_next_step = proceed_to_cylindrical_coherence_stress_or_model_selection`.

Stage4 validates a controlled el-separated pair beamspace ML model with `[az1, az2, el_center, el_sep, orientation]`. It is not a complete unconstrained 4D pair az/el search, not an AP validation, not a strong-coherence final solution, and not a final thesis conclusion.

## Stage5 Current Status

Stage5 has a direct run entry:

```matlab
run('setup_paths.m')
run('steps/step_11_1_beamspace_ml_validation/stage5_cyl_coherence_stress/run_stage5_cyl_coherence_stress.m')
```

The result directory is `results_step11_1_cyl_coherence_stress/`, and the main decision file is `step11_1_cyl_coherence_stress_keypoints.csv`.

The current generated keypoints report `coherence_stress_pass_flag = 1` with `recommended_next_step = proceed_to_model_selection_and_confidence_boundary`.

Important Stage5 keypoints from the completed run:

- `pass_rate_moderate_coherence = 0.993055555555556`
- `pass_rate_strong_coherence = 0.951388888888889`
- `pair2d_white_success_rho0 = 1`
- `pair2d_white_success_rho09 = 0.986111111111111`
- `pair2d_white_success_rho099 = 0.956018518518518`
- `pair2d_white_success_rho1 = 0.946759259259259`
- `worst_case_joint_success_pair2d_white = 0`
- `max_boundary_hit_rate_pair2d_white = 0`
- `max_false_el_split_rate_true_sep0_pair2d_white = 0`
- `pair2d_minus_common_mean_success_gap = 0.657696759259259`
- `whitening_gain_mean_pair2d = 0`

Stage5 is a coherence and strong-coherence pressure validation for the Stage4 controlled el-separated pair beamspace ML model. It is not AP, not a final engineering closed loop, and not a claim that every strong-coherence scenario succeeds. The `worst_case_joint_success_pair2d_white = 0` and `max_false_high_like_rate = 1` results should be treated as boundary and confidence-risk evidence for later model-selection work.

## Stage6 Current Status

Stage6 has a direct run entry:

```matlab
run('setup_paths.m')
run('steps/step_11_1_beamspace_ml_validation/stage6_full4d_beamspace_ml_comparison/run_stage6_full4d_beamspace_ml_comparison.m')
```

The result directory is `results_step11_1_full4d_beamspace_ml_comparison/`, and the main decision file is `step11_1_full4d_comparison_keypoints.csv`.

The current generated keypoints report `full4d_pass_flag = 1` with `recommended_next_step = proceed_to_final_paper_evidence_summary`.

Important Stage6 keypoints from the completed run:

- `best_full4d_joint_success = 1`
- `best_pair2d_joint_success = 1`
- `best_common_joint_success = 0.5625`
- `full4d_minus_pair2d_success_gap = 0`
- `full4d_minus_common_success_gap = 0.4375`
- `pair2d_minus_common_success_gap = 0.4375`
- `complexity_ratio_full4d_over_pair2d = 3.95890410958904`
- `full4d_recommended_role = upper_bound_only_pair2d_is_sufficient`

Stage6 compares common-el, controlled pair2d, and local full4d beamspace ML. Full4d is treated as a local upper-bound comparison, not as the default main algorithm. In the current representative scenarios, full4d does not improve controlled pair2d, while its candidate-count proxy is about 3.96 times larger.

## Stage7 Current Status

Stage7 has a direct run entry:

```matlab
run('setup_paths.m')
run('steps/step_11_1_beamspace_ml_validation/stage7_final_paper_evidence_summary/run_stage7_final_paper_evidence_summary.m')
```

The result directory is `results_step11_1_final_paper_evidence_summary/`.

The current generated final recommendation is:

```text
use_controlled_pair2d_beamspace_ml_as_main_thesis_route_with_full4d_upper_bound
```

Stage7 generates final paper evidence CSVs, Markdown writing notes, and overview PNGs. It is a paper-level result organization stage only: it adds no new algorithm, does not validate AP, does not complete an engineering confidence boundary, and does not claim that every strong-coherence scenario succeeds.
