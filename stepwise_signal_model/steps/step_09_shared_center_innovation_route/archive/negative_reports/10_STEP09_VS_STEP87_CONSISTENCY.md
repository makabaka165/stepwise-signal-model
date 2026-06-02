# Step09 vs Step87 Consistency

## Keypoints

| keypoint | value | note |
|---|---:|---|
| `old_route_callable` | 0 | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\..\step_08_7_routeB_array_level3\space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m |
| `attempted_old_entry` | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\..\step_08_7_routeB_array_level3\space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m | first historical Step 8.7/8.8 candidate found |
| `total_trials` | 120 | consistency trial rows |
| `route_agreement_rate` | 0 | old vs new route_name agreement |
| `status_agreement_rate` | 0 | old vs new status agreement |
| `confidence_agreement_rate` | 0 | old vs new confidence agreement |
| `success_gap_new_minus_old` | 0.083333 | new minus old success rate |
| `false_high_gap_new_minus_old` | 0.025 | new minus old false-high rate |
| `boundary_missed_gap_new_minus_old` | 0 | new minus old boundary missed rate |
| `mean_az_diff_when_both_success` | NaN | not available unless old route is callable |
| `mean_el_diff_when_both_success` | NaN | not available unless old route is callable |
| `consistency_pass_flag` | 0 | pass/fail |
| `blocker_if_any` | step87_reference_not_functionalized | clear blocker if old route cannot be called |
| `failure_reason` | step87_reference_not_functionalized | same as blocker_if_any for non-callable old route |
| `fallback_policy` | Step09 formal MC is used as final validation | policy when old Step 8.7 is not callable |

## Summary

| total_trials | old_callable | route_agreement_rate | status_agreement_rate | confidence_agreement_rate | success_gap_new_minus_old | false_high_gap_new_minus_old | boundary_missed_gap_new_minus_old | mean_az_diff_when_both_success | mean_el_diff_when_both_success |
|---|---|---|---|---|---|---|---|---|---|
| 120 | 0 | 0 | 0 | 0 | 0.083333 | 0.025 | 0 | NaN | NaN |

If `old_route_callable = 0`, Step 8.7 was found as script-oriented historical code rather than a directly callable reference route. In that case Step 09 formal MC is the final statistical validation basis.
