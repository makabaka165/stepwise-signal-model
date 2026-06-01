# Supplementary Experiment Overview

- run_mode: `quick`
- overview_csv: `../results_step09_supplementary_overview.csv`

| experiment_name | status | pass_flag | blocker_if_any | result_dir | elapsed_sec |
|---|---|---:|---|---|---:|
| `smoke_validation` | completed | 1 | none | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\results` | 11.053 |
| `formal_mc` | completed | 0 | overall_false_high_rate_gt_0p01,close_coherent_success_low,large_el_success_low | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\results_step09_formal_mc` | 73.163 |
| `ablation` | completed | 0 | rank1_gain_close_coherent_low,local_2d_gain_large_el_low,full_step09_false_high_gt_0p01 | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\results_step09_ablation` | 73.070 |
| `step09_vs_step87_consistency` | completed | 0 | step87_reference_not_functionalized | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\results_step09_vs_step87_consistency` | 5.990 |

Formal MC and ablation blockers are reported as validation evidence, not hidden by retuning. If the Step 8.7 route is not callable, the Step 09 formal MC remains the final statistical validation basis.
