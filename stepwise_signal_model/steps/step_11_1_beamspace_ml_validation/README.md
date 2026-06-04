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
