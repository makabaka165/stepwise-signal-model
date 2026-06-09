# Metkl=30 Repeat-Seed Recheck

## Setup

- base_seed_list = `[20260609, 20260610, 20260611]`
- Metkl = `30`
- scenarios = `easy_noncoherent`, `strong_coherent`, `hard_phase`, `weak_secondary`, `low_snr_hard`
- policy = fixed Stage2 selected `C05_easy_very_aggressive`

## Pass/fail

- metkl30_repeat_pass_flag = 1
- failed seed groups = ``
- max pair count ratio = 0.715079432344
- min full-grid match rate = 1

## Per seed group

| summary_scope | scenario_name | policy_name | fail_reason | seed_group_id | base_seed | n_trials | fixed_success | adaptive_success | full_success | fixed_rmse | adaptive_rmse | full_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | adaptive_full_grid_match_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | max_policy_rate | policy_degeneracy_flag | easy_policy_rate | normal_policy_rate | score_ambiguous_policy_rate | boundary_policy_rate | ill_conditioned_policy_rate | metkl30_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| seed_group |  |  |  | 1 | 20260609 | 150 | 1 | 1 | 1 | 0.0765589261214 | 0.0550088138633 | 0.0765589261214 | 19150.02 | 13668.3 | 0.713748601829 | 1 | 0 | 0 | 0.6 | 0 | 0.6 | 0.4 | 0 | 0 | 0 | 1 |
| seed_group |  |  |  | 2 | 20260610 | 150 | 1 | 1 | 1 | 0.0765589261214 | 0.0550088138633 | 0.0765589261214 | 19114.38 | 13668.3 | 0.715079432344 | 1 | 0 | 0 | 0.6 | 0 | 0.6 | 0.4 | 0 | 0 | 0 | 1 |
| seed_group |  |  |  | 3 | 20260611 | 150 | 1 | 1 | 1 | 0.0765589261214 | 0.0550088138633 | 0.0765589261214 | 19150.02 | 13668.3 | 0.713748601829 | 1 | 0 | 0 | 0.6 | 0 | 0.6 | 0.4 | 0 | 0 | 0 | 1 |

## Overall

| summary_scope | scenario_name | policy_name | fail_reason | seed_group_id | base_seed | n_trials | fixed_success | adaptive_success | full_success | fixed_rmse | adaptive_rmse | full_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | adaptive_full_grid_match_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | max_policy_rate | policy_degeneracy_flag | easy_policy_rate | normal_policy_rate | score_ambiguous_policy_rate | boundary_policy_rate | ill_conditioned_policy_rate | metkl30_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| overall |  |  |  | NaN | NaN | 450 | 1 | 1 | 1 | 0.0765589261214 | 0.0550088138633 | 0.0765589261214 | 19138.14 | 13668.3 | 0.714191661259 | 1 | 0 | 0 | 0.6 | 0 | 0.6 | 0.4 | 0 | 0 | 0 | 1 |

## Per scenario

| summary_scope | scenario_name | policy_name | fail_reason | seed_group_id | base_seed | n_trials | fixed_success | adaptive_success | full_success | fixed_rmse | adaptive_rmse | full_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | adaptive_full_grid_match_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | max_policy_rate | policy_degeneracy_flag | easy_policy_rate | normal_policy_rate | score_ambiguous_policy_rate | boundary_policy_rate | ill_conditioned_policy_rate | metkl30_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| scenario | easy_noncoherent |  |  | NaN | NaN | 90 | 1 | 1 | 1 | 0.0595818764391 | 0.0282488937837 | 0.0595818764391 | 17764.2 | 9729 | 0.547674536427 | 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | NaN |
| scenario | strong_coherent |  |  | NaN | NaN | 90 | 1 | 1 | 1 | 0.054313902456 | 0.0140712472795 | 0.054313902456 | 19998 | 9729 | 0.486498649865 | 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | NaN |
| scenario | hard_phase |  |  | NaN | NaN | 90 | 1 | 1 | 1 | 0.0561248608016 | 0.0199499373433 | 0.0561248608016 | 18774 | 9729 | 0.518216682646 | 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | NaN |
| scenario | weak_secondary |  |  | NaN | NaN | 90 | 1 | 1 | 1 | 0.106386995455 | 0.106386995455 | 0.106386995455 | 18513 | 18513 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | NaN |
| scenario | low_snr_hard |  |  | NaN | NaN | 90 | 1 | 1 | 1 | 0.106386995455 | 0.106386995455 | 0.106386995455 | 20641.5 | 20641.5 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | NaN |

## Per policy

| summary_scope | scenario_name | policy_name | fail_reason | seed_group_id | base_seed | n_trials | fixed_success | adaptive_success | full_success | fixed_rmse | adaptive_rmse | full_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | adaptive_full_grid_match_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | max_policy_rate | policy_degeneracy_flag | easy_policy_rate | normal_policy_rate | score_ambiguous_policy_rate | boundary_policy_rate | ill_conditioned_policy_rate | metkl30_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| policy |  | EASY |  | NaN | NaN | 270 | 1 | 1 | 1 | 0.0566735465656 | 0.0207566928021 | 0.0566735465656 | 18845.4 | 9729 | 0.516253303193 | 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | NaN |
| policy |  | NORMAL |  | NaN | NaN | 180 | 1 | 1 | 1 | 0.106386995455 | 0.106386995455 | 0.106386995455 | 19577.25 | 19577.25 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | NaN |
| policy |  | SCORE_AMBIGUOUS | empty_subset | NaN | NaN | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| policy |  | BOUNDARY | empty_subset | NaN | NaN | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| policy |  | ILL_CONDITIONED | empty_subset | NaN | NaN | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |

## Interpretation

Metkl=30 repeat-seed evidence strengthens the Stage2/Stage3 C05 positive result under larger representative-scenario sampling.
