# Close-Coherent Gate Diagnostics

This note records a focused diagnostic run for Step 09 close-coherent and medium-beta cases using `cfg.backend_mode = 'step87_reference'`. It does not modify thresholds, default backend selection, or the thesis route.

Result directory: `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\archive\diagnostic_results\results_step09_close_coherent_gate_diagnostics`.

## Answers

1. Candidate generation failure: not primarily, based on the rule-based blocker classification. Truth reaches rank1/refocus top-K often enough that candidate generation is not the primary blocker.
2. Truth pair top-K entry: rank1 top3 rate = 0.704390, refocus top3 rate = 0.686840.
3. Rejection gate: rank1 correct-but-rejected rate = 0.704390; common-el proxy pass rate = 0.000000; main blocker = `rank1_gate_too_strict_or_common_el_proxy_mismatch`.
4. Common-el proxy pass rate: 0.000000.
5. Rank1 route reliable rate: 0.914910.
6. Main blocker: `rank1_gate_too_strict_or_common_el_proxy_mismatch`.
7. Next step: do not tune thresholds from this run alone. The immediate action is to inspect the rank1/common-el gate mismatch; only if top-K rates were low would reference-frame/data repair move ahead of gate analysis.

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

## Summary CSV Scope

Summary rows are grouped by `scenario_name`, `az_sep_deg`, and `SNR_dB`. `medium_beta_pair` uses the requested Cartesian product of azimuth separation and beta values.

| scenario_name | az_sep_deg | SNR_dB | trials | success_rate | rank1_truth_top3_rate | refocus_truth_top3_rate | common_el_proxy_pass_rate | rank1_route_reliable_rate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `close_coherent_pair` | 0.15 | 8 | 60 | 0.000000 | 1.000000 | 0.950000 | 0.000000 | 0.916667 |
| `close_coherent_pair` | 0.15 | 16 | 60 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.766667 |
| `close_coherent_pair` | 0.25 | 8 | 60 | 0.000000 | 0.983333 | 0.983333 | 0.000000 | 0.983333 |
| `close_coherent_pair` | 0.25 | 16 | 60 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.666667 |
| `close_coherent_pair` | 0.4 | 8 | 60 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.983333 |
| `close_coherent_pair` | 0.4 | 16 | 60 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.883333 |
| `close_coherent_pair` | 0.6 | 8 | 60 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 1.000000 |
| `close_coherent_pair` | 0.6 | 16 | 60 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.950000 |
| `close_coherent_pair` | 0.8 | 8 | 60 | 0.000000 | 1.000000 | 0.916667 | 0.000000 | 0.966667 |
| `close_coherent_pair` | 0.8 | 16 | 60 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | 0.983333 |
| `medium_beta_pair` | 0.25 | 8 | 90 | 0.000000 | 0.444444 | 0.433333 | 0.000000 | 0.911111 |
| `medium_beta_pair` | 0.25 | 16 | 90 | 0.000000 | 0.522222 | 0.444444 | 0.000000 | 0.877778 |
| `medium_beta_pair` | 0.4 | 8 | 90 | 0.000000 | 0.322222 | 0.333333 | 0.000000 | 0.911111 |
| `medium_beta_pair` | 0.4 | 16 | 90 | 0.000000 | 0.333333 | 0.333333 | 0.000000 | 0.844444 |
| `medium_beta_pair` | 0.6 | 8 | 90 | 0.000000 | 0.322222 | 0.277778 | 0.000000 | 0.988889 |
| `medium_beta_pair` | 0.6 | 16 | 90 | 0.000000 | 0.322222 | 0.311111 | 0.000000 | 0.988889 |
