# Step09 Step87 Backend Bridge

This bridge does not change the Step 09 thesis line. It only checks whether the verified Step 8.7 cascade can sit behind the Step 09 interface as a backend implementation.

The current run fixes the Step 09-to-Step 8.7 reference-frame adapter and recovers the large-elevation case, but it still does not lift close-coherent cases enough to satisfy the bridge pass threshold.

## Keypoints

| keypoint | value | note |
|---|---:|---|
| `step87_backend_callable` | 1 | bridge callable flag |
| `total_trials` | 80 | bridge trial rows |
| `light_success_rate` | 0.25 | step09_light |
| `ref_success_rate` | 0.25 | step87_reference |
| `success_gain_ref_minus_light` | 0 | reference minus light success |
| `light_false_high_rate` | 0 | step09_light |
| `ref_false_high_rate` | 0 | step87_reference |
| `light_boundary_missed_rate` | 0 | step09_light |
| `ref_boundary_missed_rate` | 0 | step87_reference |
| `close_coherent_light_success` | 0 | close coherent |
| `close_coherent_ref_success` | 0 | close coherent |
| `large_el_light_success` | 1 | large elevation |
| `large_el_ref_success` | 1 | large elevation |
| `near_antiphase_ref_false_high` | 0 | near anti-phase |
| `weak_target_ref_false_high` | 0 | weak target |
| `two_separated_ref_reject_rate` | 1 | out-of-scope reject rate |
| `bridge_pass_flag` | 0 | pass/fail |
| `blocker_if_any` | bridge_threshold_failed | bridge blocker |

## Summary

| scenario_name | total_trials | light_success_rate | ref_success_rate | success_gain_ref_minus_light | light_false_high_rate | ref_false_high_rate | light_boundary_missed_rate | ref_boundary_missed_rate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `overall` | 80 | 0.250000 | 0.250000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `single_target_sanity` | 10 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `close_coherent_pair` | 10 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `medium_beta_pair` | 10 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `weak_target_boundary` | 10 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `near_antiphase_boundary` | 10 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `large_el_pair` | 10 | 1.000000 | 1.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `two_separated_coarse_peaks` | 10 | 1.000000 | 1.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `center_wraparound_case` | 10 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
