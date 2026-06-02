# Step09 Close-Coherent Gate Diagnostics

This run is diagnostic only. It uses `cfg.backend_mode = 'step87_reference'` as the primary backend and does not tune route thresholds.

## Keypoints

| keypoint | value | note |
|---|---:|---|
| `total_trials` | 1140 | diagnostic trial rows |
| `success_rate` | 0 | step87_reference |
| `low_confidence_rate` | 1 | step87_reference |
| `boundary_unreliable_rate` | 0.13509 | step87_reference |
| `false_high_rate` | 0 | step87_reference |
| `rank1_truth_top1_rate` | 0.59825 | truth-only diagnostic |
| `rank1_truth_top3_rate` | 0.70439 | truth-only diagnostic |
| `rank1_truth_top5_rate` | 0.72719 | truth-only diagnostic |
| `refocus_truth_top1_rate` | 0.59825 | truth-only diagnostic |
| `refocus_truth_top3_rate` | 0.68684 | truth-only diagnostic |
| `refocus_truth_top5_rate` | 0.70702 | truth-only diagnostic |
| `rank1_correct_but_rejected_rate` | 0.70439 | truth-only diagnostic |
| `refocus_correct_but_rejected_rate` | 0.68684 | truth-only diagnostic |
| `common_el_proxy_pass_rate` | 0 | route gate |
| `rank1_route_reliable_rate` | 0.91491 | route gate |
| `main_blocker_type` | rank1_gate_too_strict_or_common_el_proxy_mismatch | rule-based blocker classification |

## Summary

| scenario_name | az_sep_deg | SNR_dB | trials | success_rate | low_confidence_rate | boundary_unreliable_rate | rank1_truth_top3_rate | refocus_truth_top3_rate | common_el_proxy_pass_rate | rank1_route_reliable_rate | dominant_failure_reason |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `close_coherent_pair` | 0.15 | 8 | 60 | 0.000000 | 1.000000 | 0.150000 | 1.000000 | 0.950000 | 0.000000 | 0.916667 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.15 | 16 | 60 | 0.000000 | 1.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.766667 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.25 | 8 | 60 | 0.000000 | 1.000000 | 0.183333 | 0.983333 | 0.983333 | 0.000000 | 0.983333 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.25 | 16 | 60 | 0.000000 | 1.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.666667 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.4 | 8 | 60 | 0.000000 | 1.000000 | 0.083333 | 1.000000 | 1.000000 | 0.000000 | 0.983333 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.4 | 16 | 60 | 0.000000 | 1.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.883333 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.6 | 8 | 60 | 0.000000 | 1.000000 | 0.200000 | 1.000000 | 1.000000 | 0.000000 | 1.000000 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.6 | 16 | 60 | 0.000000 | 1.000000 | 0.100000 | 1.000000 | 1.000000 | 0.000000 | 0.950000 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.8 | 8 | 60 | 0.000000 | 1.000000 | 0.333333 | 1.000000 | 0.916667 | 0.000000 | 0.966667 | `no_reliable_observable_route` |
| `close_coherent_pair` | 0.8 | 16 | 60 | 0.000000 | 1.000000 | 0.016667 | 1.000000 | 1.000000 | 0.000000 | 0.983333 | `no_reliable_observable_route` |
| `medium_beta_pair` | 0.25 | 8 | 90 | 0.000000 | 1.000000 | 0.222222 | 0.444444 | 0.433333 | 0.000000 | 0.911111 | `no_reliable_observable_route` |
| `medium_beta_pair` | 0.25 | 16 | 90 | 0.000000 | 1.000000 | 0.077778 | 0.522222 | 0.444444 | 0.000000 | 0.877778 | `no_reliable_observable_route` |
| `medium_beta_pair` | 0.4 | 8 | 90 | 0.000000 | 1.000000 | 0.244444 | 0.322222 | 0.333333 | 0.000000 | 0.911111 | `no_reliable_observable_route` |
| `medium_beta_pair` | 0.4 | 16 | 90 | 0.000000 | 1.000000 | 0.000000 | 0.333333 | 0.333333 | 0.000000 | 0.844444 | `no_reliable_observable_route` |
| `medium_beta_pair` | 0.6 | 8 | 90 | 0.000000 | 1.000000 | 0.255556 | 0.322222 | 0.277778 | 0.000000 | 0.988889 | `no_reliable_observable_route` |
| `medium_beta_pair` | 0.6 | 16 | 90 | 0.000000 | 1.000000 | 0.200000 | 0.322222 | 0.311111 | 0.000000 | 0.988889 | `no_reliable_observable_route` |

## Figures

- `step09_rank1_truth_error_hist.png`
- `step09_rank1_score_vs_error.png`
- `step09_refocus_score_vs_rank1_score.png`
- `step09_gate_failure_distribution.png`
