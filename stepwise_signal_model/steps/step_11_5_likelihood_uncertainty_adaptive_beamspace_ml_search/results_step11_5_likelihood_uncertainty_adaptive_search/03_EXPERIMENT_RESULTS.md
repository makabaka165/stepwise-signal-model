# Step11.5 Experiment Results

## Full fine vs fixed topK3 vs adaptive comparison

- full_fine_success = 1
- fixed_topK3_success = 1
- adaptive_success = 1
- full_fine_rmse = 0.0765589261214
- fixed_topK3_rmse = 0.0765589261214
- adaptive_rmse = 0.0765589261214
- full_fine_mean_num_pairs = 131461
- fixed_topK3_mean_num_pairs = 19126.26
- adaptive_mean_num_pairs = 38749.86
- adaptive_vs_fixed_pair_count_ratio = 2.02600299274
- adaptive_full_grid_match_rate = 1
- adaptive_topK_miss_rate = 0
- adaptive_boundary_hit_rate = 0

## Policy distribution

| policy_name | n_trials | policy_rate | success_rate | mean_num_pairs | mean_U | mean_topK |
| --- | --- | --- | --- | --- | --- | --- |
| EASY | 0 | 0 | NaN | NaN | NaN | NaN |
| NORMAL | 0 | 0 | NaN | NaN | NaN | NaN |
| HARD | 350 | 1 | 0.994285714286 | 37291.9085714 | 0.671325180666 | 5 |
| UNSAFE | 0 | 0 | NaN | NaN | NaN | NaN |

## Candidate count reduction

Fixed topK3 reduction ratio is 6.87332494696; adaptive reduction ratio is 3.39255419245. The adaptive-vs-fixed reduction gain is 0.493582686492.

## RMSE/success comparison

The adaptive pass flag is `0`. Recommended next step: `tune_policy_thresholds_for_more_complexity_reduction`.

## Bias robustness

| bias_case_id | az_center_bias_deg | el_center_bias_deg | n_trials | fixed_success | adaptive_success | adaptive_success_drop_vs_zero | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | adaptive_full_grid_match_rate | adaptive_mean_num_pairs | bias_robustness_pass_020 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | -0.2 | -0.2 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 33585.8 | 1 |
| 2 | -0.2 | 0 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 37507 | 1 |
| 3 | 0 | -0.2 | 50 | 0.96 | 0.96 | 0.04 | 0 | 0 | 1 | 33958.48 | 1 |
| 4 | 0 | 0 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 38749.86 | 1 |
| 5 | 0 | 0.2 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 39431.1 | 1 |
| 6 | 0.2 | 0 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 37344 | 1 |
| 7 | 0.2 | 0.2 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 40467.12 | 1 |

- max_bias_adaptive_topK_miss_rate = 0
- max_bias_adaptive_boundary_hit_rate = 0
- max_bias_adaptive_success_drop = 0.04
- valid_bias_range_text = `az_bias=[-0.20,0.20], el_bias=[-0.20,0.20]`
