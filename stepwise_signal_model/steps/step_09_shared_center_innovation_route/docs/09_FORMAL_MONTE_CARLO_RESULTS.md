# Formal Monte Carlo Results

- run_mode: `quick`
- Metkl: `30`
- SNR list: `[8 16]`
- total trials: `1500`
- elapsed_sec: `73.098`

## Keypoints

| keypoint | value | note |
|---|---:|---|
| `run_mode` | quick | formal MC run mode |
| `rng_seed_base` | 902091 | base seed; each trial stores rng_seed |
| `Metkl` | 30 | Monte Carlo trials per scenario/SNR case |
| `SNR_list` | [8 16] | SNR_dB values |
| `total_trials` | 1500 | trial rows |
| `Q_work_columns` | 65 | shared-center work columns |
| `Y_work_shape_default` | 65 x 32 x Np | default formal MC cube extraction |
| `default_derotation_mode` | none | default is no Doppler de-rotation |
| `overall_success_rate` | 0.04 | overall |
| `overall_safe_rate` | 0.94467 | overall |
| `overall_false_high_rate` | 0.055333 | overall |
| `overall_boundary_missed_rate` | 0 | overall |
| `overall_low_confidence_rate` | 0.94467 | overall |
| `single_target_false_split_rate` | 0 | single target |
| `close_coherent_success_rate` | 0 | close coherent pair |
| `medium_beta_success_rate` | 0 | medium beta pair |
| `weak_target_false_high_rate` | 0 | weak target boundary |
| `near_antiphase_false_high_rate` | 0 | near anti-phase boundary |
| `near_antiphase_boundary_missed_rate` | 0 | near anti-phase boundary |
| `large_el_success_rate` | 0 | large elevation pair |
| `two_separated_out_of_scope_reject_rate` | 1 | frontend out-of-scope reject |
| `coarseAz_bias_success_min` | 0 | min success across coarseAz_error sweep |
| `coarseAz_bias_success_max` | 0 | max success across coarseAz_error sweep |
| `center_wraparound_pass_flag` | 1 | selected columns valid at wrap boundary |
| `formal_mc_pass_flag` | 0 | formal MC pass/fail |
| `blocker_if_any` | overall_false_high_rate_gt_0p01,close_coherent_success_low,large_el_success_low | comma-separated blocker list; none if pass |

## Scenario Summary

| scenario_name | trials | success_rate | safe_rate | false_high_rate | boundary_missed_rate | low_confidence_rate | out_of_scope_rate | mean_az_error_success | mean_el_error_success | median_runtime_sec | mean_runtime_sec | route_distribution | confidence_distribution |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| single_target_sanity | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0095702 | 0.010395 | low_confidence:1.000 | low:1.000 |
| close_coherent_pair | 360 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0093361 | 0.0094407 | low_confidence:1.000 | low:1.000 |
| medium_beta_pair | 180 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.009386 | 0.0094866 | low_confidence:1.000 | low:1.000 |
| weak_target_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.010102 | 0.010521 | low_confidence:1.000 | low:1.000 |
| near_antiphase_boundary | 120 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0091061 | 0.0092166 | boundary_unreliable:1.000 | low:1.000 |
| large_el_pair | 240 | 0 | 0.65417 | 0.34583 | 0 | 0.65417 | 0 | NaN | NaN | 0.13424 | 0.13606 | local_2d_pair_refinement:0.346;low_confidence:0.654 | medium:0.346;low:0.654 |
| two_separated_coarse_peaks | 60 | 1 | 1 | 0 | 0 | 1 | 1 | NaN | NaN | 0.00020095 | 0.00025068 | frontend_reject:1.000 | low:1.000 |
| coarseAz_bias_sweep | 300 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.009861 | 0.010114 | low_confidence:1.000 | low:1.000 |
| center_wraparound_case | 120 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0094955 | 0.009602 | low_confidence:1.000 | low:1.000 |

## Figures

- `../results_step09_formal_mc/step09_success_vs_snr.png`
- `../results_step09_formal_mc/step09_false_high_vs_snr.png`
- `../results_step09_formal_mc/step09_route_distribution.png`
- `../results_step09_formal_mc/step09_low_confidence_boundary_rates.png`
- `../results_step09_formal_mc/step09_coarseAz_bias_sweep.png`
- `../results_step09_formal_mc/step09_runtime_distribution.png`

## Conclusion

Step 09 formal MC found blockers. The final route remains plausible, but the blocker must be reported and the method should not overclaim beyond validated cases.
