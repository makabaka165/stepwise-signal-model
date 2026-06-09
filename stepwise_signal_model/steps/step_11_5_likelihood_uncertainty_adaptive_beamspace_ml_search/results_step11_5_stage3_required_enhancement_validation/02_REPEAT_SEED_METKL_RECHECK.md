# Repeat-Seed Larger-Metkl Recheck

## Purpose

This check fixes Stage2 selected C05 and reruns the representative scenarios with larger Metkl and repeated deterministic seed groups. It verifies that C05 is not a small Metkl=10 or single-seed artifact.

## Key metrics

- seed groups = 3
- Metkl per seed group = 20
- min adaptive success = 1
- max adaptive RMSE = 0.0553221436898
- max pair count ratio = 0.719279670986
- min full-grid match rate = 1
- max topK miss rate = 0
- max boundary hit rate = 0
- max policy degeneracy flag = 0
- repeat_seed_metkl_recheck_pass_flag = 1

## Seed-group summary rows

| summary_scope | run_label | split_scheme | split_name | seed_group_id | n_trials | fixed_success | adaptive_success | fixed_rmse | adaptive_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | adaptive_full_grid_match_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | max_policy_rate | policy_degeneracy_flag | safety_pass_flag | complexity_pass_flag | stage3_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| seed_group_all | repeat_seed_metkl_recheck | all | all | 1 | 100 | 1 | 1 | 0.0765589261214 | 0.0550088138633 | 19108.44 | 13668.3 | 0.715301720078 | 1 | 0 | 0 | 0.6 | 0 | 1 | 1 | 1 |
| seed_group_all | repeat_seed_metkl_recheck | all | all | 2 | 100 | 1 | 1 | 0.0765589261214 | 0.0553221436898 | 19126.26 | 13757.13 | 0.719279670986 | 1 | 0 | 0 | 0.59 | 0 | 1 | 1 | 1 |
| seed_group_all | repeat_seed_metkl_recheck | all | all | 3 | 100 | 1 | 1 | 0.0765589261214 | 0.0550088138633 | 19161.9 | 13668.3 | 0.713306091776 | 1 | 0 | 0 | 0.6 | 0 | 1 | 1 | 1 |

## Overall summary

| summary_scope | run_label | split_scheme | split_name | seed_group_id | n_trials | fixed_success | adaptive_success | fixed_rmse | adaptive_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | adaptive_full_grid_match_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | max_policy_rate | policy_degeneracy_flag | safety_pass_flag | complexity_pass_flag | stage3_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| overall | repeat_seed_metkl_recheck | all | all | NaN | 300 | 1 | 1 | 0.0765589261214 | 0.0551132571388 | 19132.2 | 13697.91 | 0.715961049958 | 1 | 0 | 0 | 0.596666666667 | 0 | 1 | 1 | 1 |
