# Supplementary Experiment Plan

## Purpose

`run_final_shared_center_validation.m` is an interface-level smoke test. It checks required files, 65-column shared-center extraction, `Y_work` shape, and frontend rejection behavior, but it is not a statistical validation of the final DOA route.

The supplementary experiments add reproducible validation for the final Step 09 entry:

```matlab
out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
```

Ground truth is used only for metrics. It is not used in route selection, candidate generation, confidence decisions, or algorithm output.

## Formal Monte Carlo

Entry:

```matlab
run('run_step09_formal_monte_carlo.m')
```

Default quick mode uses `Metkl = 30` and `SNR = [8, 16]`. Formal and stress modes are selected with `STEP09_MC_MODE=quick|formal|stress`.

The synthetic model uses a full cylindrical array response. For each target, `a_l = steering_full(array_geom, az_l, el_l)`. Slow-time signals use one coherent base tone and, when `rho < 1`, a second decorrelated tone mixed as `rho*s1 + sqrt(1-rho^2)*v`. Complex Gaussian noise is scaled by:

```text
SNR_dB = 10 log10(mean(abs(Y_clean(:)).^2) / noise_power)
```

Scenarios:

- `single_target_sanity`
- `close_coherent_pair`
- `medium_beta_pair`
- `weak_target_boundary`
- `near_antiphase_boundary`
- `large_el_pair`
- `two_separated_coarse_peaks`
- `coarseAz_bias_sweep`
- `center_wraparound_case`

Primary metrics are success rate, safe rate, false-high rate, boundary-missed rate, low-confidence rate, out-of-scope rejection rate, successful-case angle error, runtime, route distribution, and confidence distribution.

Formal pass flag requires:

- `overall_false_high_rate <= 0.01`
- `overall_boundary_missed_rate <= 0.01`
- `weak_target_false_high_rate <= 0.01`
- `near_antiphase_false_high_rate <= 0.01`
- `two_separated_out_of_scope_reject_rate >= 0.99`
- `center_wraparound_pass_flag = 1`
- `close_coherent_success_rate >= 0.50`
- `large_el_success_rate >= 0.70`

If a condition fails, the blocker is written to `step09_formal_mc_keypoints.csv` and the report. The experiment must not retune the algorithm to hide blockers.

## Step09-vs-Step87 Consistency

Entry:

```matlab
run('run_step09_vs_step87_consistency_check.m')
```

The checker searches historical Step 8.7/8.8 paths. If a callable reference function is available, it compares `route_name`, `status`, `confidence`, `az_est`, and `el_est` on the same generated trials. If only script-oriented historical code is found, it records:

```text
blocker_if_any = step87_reference_not_functionalized
fallback_policy = Step09 formal MC is used as final validation
```

No consistency pass is fabricated when the old route is not callable.

## Ablation Study

Entry:

```matlab
run('run_step09_ablation_study.m')
```

The ablation compares:

- `music_only`
- `music_plus_rank1`
- `music_plus_2d`
- `full_step09`
- `full_without_rejector`

The purpose is to show why rank1 fallback, local 2-D refinement, and confidence/boundary rejection are retained in the final route.

Ablation pass flag requires rank1 gain on close coherent pairs, 2-D gain or route share on large-elevation pairs, rejector non-regression on false-high and boundary-missed rates, and `full_step09` false-high rate no greater than `0.01`.

## Optional Learning Boundary

Learning-assisted route/confidence calibration is future work only. It is not part of the default Step 09 route and must not replace MUSIC, rank1 refocus, or local 2-D angle outputs.
