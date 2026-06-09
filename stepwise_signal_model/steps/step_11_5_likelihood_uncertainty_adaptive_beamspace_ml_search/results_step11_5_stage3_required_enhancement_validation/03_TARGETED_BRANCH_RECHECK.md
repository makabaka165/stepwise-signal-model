# Targeted Branch Recheck

## Purpose

This check fixes Stage2 selected C05 and targets the v2 policy branches that were not naturally populated in Stage2 representative trials. The purpose is branch behavior and safe output validation, not high success under stress.

## Branch criteria

- BOUNDARY must be triggerable by real-search boundary stress and must not output high confidence.
- ILL_CONDITIONED must be triggerable by real-search stress or deterministic policy guard probe and must output low confidence with unit windows.
- A triggered safety branch is considered reasonable only when it avoids high-confidence misuse.

## Key metrics

- boundary_real_trigger_count = 2
- ill_conditioned_real_trigger_count = 0
- ill_conditioned_policy_probe_trigger_count = 1
- high_confidence_misuse_rate = 0
- targeted_branch_recheck_pass_flag = 1

## Branch trial rows

| branch_case_name | branch_case_type | expected_policy_name | observed_policy_name | adaptive_confidence | adaptive_boundary_flag | failure_reason | row_id | uses_real_search | branch_triggered | reasonable_safe_output | high_confidence_misuse | seed | trial_id | az_center_bias_deg | el_center_bias_deg | truth_az1 | truth_az2 | truth_el1 | truth_el2 | true_orientation | full_success | adaptive_success | full_rmse | adaptive_rmse | full_num_pairs | adaptive_num_pairs | adaptive_full_grid_match | adaptive_topK_miss | adaptive_boundary_hit | H_norm | gap_13 | gap_17 | boundary_risk | cond_risk | U_search | U_confidence | adaptive_topK | az_window_scale | el_window_scale |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| boundary_az_lower_edge_real_search | BOUNDARY_real_search | BOUNDARY | BOUNDARY | medium_low | boundary_protected_search |  | 1 | 1 | 1 | 1 | 0 | 21411610 | 1 | 1.48 | 0 | 7.365 | 8.635 | 9.975 | 10.645 | 1 | 0 | 0 | 0.686694983235 | 0.683472018447 | 131461 | 13701 | 1 | 0 | 1 | 0.954821410651 | 0.0103769521041 | 0.0236470717445 | 1 | 0.227630306787 | 0.325 | 0.541095070424 | 5 | 1.15 | 1.15 |
| boundary_az_upper_edge_real_search | BOUNDARY_real_search | BOUNDARY | BOUNDARY | medium_low | boundary_protected_search |  | 2 | 1 | 1 | 1 | 0 | 21412611 | 2 | -1.48 | 0 | 7.365 | 8.635 | 9.975 | 10.645 | 1 | 0 | 0 | 0.689021044671 | 0.663389779843 | 131461 | 17649 | 0 | 0 | 1 | 0.927716861942 | 0.0138595612006 | 0.0329061041371 | 1 | 0.219344618583 | 0.325 | 0.529537056326 | 5 | 1.15 | 1.15 |
| ill_conditioned_near_coincident_real_search | ILL_CONDITIONED_real_search | ILL_CONDITIONED | SCORE_AMBIGUOUS | medium_low |  |  | 3 | 1 | 0 | 0 | 0 | 21413612 | 3 | 0 | 0 | 7.92 | 8.08 | 10.31 | 10.31 | 0 | 0 | 0 | 0.328785644455 | 0.328785644455 | 131461 | 18756 | 1 | 0 | 0 | 0.999986639525 | 9.00681370512e-05 | 0.000462482648353 | 0 | 0.203160669221 | 0.655485236972 | 0.643279813052 | 5 | 1 | 1 |
| ill_conditioned_policy_guard_probe | ILL_CONDITIONED_policy_probe | ILL_CONDITIONED | ILL_CONDITIONED | low | ill_conditioned_pair_manifold |  | 4 | 0 | 1 | 1 | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | 0.95 | 0.003 | 0.0045 | 0 | 0.96 | 0.12 | 0.91 | 3 | 1 | 1 |

## Branch summary rows

| summary_scope | n_cases | trigger_rate | reasonable_safe_output_rate | high_confidence_misuse_rate | boundary_real_trigger_count | ill_conditioned_real_trigger_count | ill_conditioned_policy_probe_trigger_count | targeted_branch_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BOUNDARY_real_search | 2 | 1 | 1 | 0 | 2 | 0 | 1 | 1 |
| ILL_CONDITIONED_real_search | 1 | 0 | 0 | 0 | 2 | 0 | 1 | 1 |
| ILL_CONDITIONED_policy_probe | 1 | 1 | 1 | 0 | 2 | 0 | 1 | 1 |
| all_targeted_branch_cases | 4 | 0.75 | 0.75 | 0 | 2 | 0 | 1 | 1 |
