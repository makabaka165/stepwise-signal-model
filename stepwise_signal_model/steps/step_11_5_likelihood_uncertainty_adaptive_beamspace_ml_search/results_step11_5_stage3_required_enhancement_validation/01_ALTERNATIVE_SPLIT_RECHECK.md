# Alternative Split Recheck

## Purpose

This check fixes Stage2 selected C05 and reruns the zero-bias representative trials under alternative validation splits. It verifies that the positive C05 conclusion is not only an odd/even trial_id split artifact.

## Split schemes

- `alt_mod3_validation`: validation uses trial_id divisible by 3.
- `alt_tail_block_validation`: validation uses the last 40 percent of trial_id values.

## Key metrics

- validation schemes = 2
- min adaptive success = 1
- max adaptive RMSE = 0.0557607854709
- max pair count ratio = 0.717621749704
- min full-grid match rate = 1
- max topK miss rate = 0
- max boundary hit rate = 0
- max policy degeneracy flag = 0
- alt_split_recheck_pass_flag = 1

## Validation summary rows

| summary_scope | run_label | split_scheme | split_name | seed_group_id | n_trials | fixed_success | adaptive_success | fixed_rmse | adaptive_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | adaptive_full_grid_match_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | max_policy_rate | policy_degeneracy_flag | safety_pass_flag | complexity_pass_flag | stage3_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| split_scheme_split | alt_split_recheck | alt_mod3_validation | validation | NaN | 15 | 1 | 1 | 0.077310897729 | 0.0557607854709 | 19244.4 | 13810.2 | 0.717621749704 | 1 | 0 | 0 | 0.6 | 0 | 1 | 1 | 1 |
| split_scheme_split | alt_split_recheck | alt_tail_block_validation | validation | NaN | 20 | 1 | 1 | 0.0765589261214 | 0.0550088138633 | 19072.8 | 13668.3 | 0.716638354096 | 1 | 0 | 0 | 0.6 | 0 | 1 | 1 | 1 |
