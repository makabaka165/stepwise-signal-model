# Step11.5 Stage2 Policy Tuning Results

## Selected config

- selected_config_name = `C05_easy_very_aggressive`
- stage2_adaptive_pass_flag = 1
- recommended_next_step = `use_step11_5_stage2_as_positive_adaptive_enhancement`

## Calibration split

- fixed_success = 1
- adaptive_success = 1
- fixed_rmse = 0.0788148409442
- adaptive_rmse = 0.0572647286861
- fixed_mean_num_pairs = 19623.24
- adaptive_mean_num_pairs = 14094
- pair_count_ratio = 0.718230017061
- policy_degeneracy_flag = 0

## Validation split

- fixed_success = 1
- adaptive_success = 1
- fixed_rmse = 0.0743030112986
- adaptive_rmse = 0.0527528990405
- fixed_mean_num_pairs = 18558
- adaptive_mean_num_pairs = 13242.6
- pair_count_ratio = 0.713579049467
- policy_degeneracy_flag = 0

## Config summary table

| config_id | config_name | calibration_fixed_success | calibration_adaptive_success | calibration_fixed_rmse | calibration_adaptive_rmse | calibration_fixed_mean_num_pairs | calibration_adaptive_mean_num_pairs | calibration_pair_count_ratio | calibration_adaptive_full_grid_match_rate | calibration_adaptive_topK_miss_rate | calibration_adaptive_boundary_hit_rate | calibration_policy_degeneracy_flag | calibration_safety_pass | calibration_selectable_pass | validation_fixed_success | validation_adaptive_success | validation_fixed_rmse | validation_adaptive_rmse | validation_fixed_mean_num_pairs | validation_adaptive_mean_num_pairs | validation_pair_count_ratio | validation_adaptive_full_grid_match_rate | validation_adaptive_topK_miss_rate | validation_adaptive_boundary_hit_rate | validation_policy_degeneracy_flag | validation_stage2_pass | overall_fixed_mean_num_pairs | overall_adaptive_mean_num_pairs | overall_pair_count_ratio | max_policy_rate | policy_degeneracy_flag | is_control_config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | C01_normal_only_control | 1 | 1 | 0.0788148409442 | 0.0788148409442 | 19623.24 | 19623.24 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 1 | 1 | 0.0743030112986 | 0.0743030112986 | 18558 | 18558 | 1 | 1 | 0 | 0 | 1 | 0 | 19090.62 | 19090.62 | 1 | 1 | 1 | 1 |
| 2 | C02_easy_conservative | 1 | 1 | 0.0788148409442 | 0.0788148409442 | 19623.24 | 16655.96 | 0.848787458136 | 1 | 0 | 0 | 0 | 1 | 1 | 1 | 1 | 0.0743030112986 | 0.0743030112986 | 18558 | 17276.4 | 0.930940834142 | 1 | 0 | 0 | 0 | 1 | 19090.62 | 16966.18 | 0.888718124398 | 0.66 | 0 | 0 |
| 3 | C03_easy_moderate | 1 | 1 | 0.0788148409442 | 0.069257327554 | 19623.24 | 16272 | 0.82922086261 | 0.4 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0.0743030112986 | 0.0683474244553 | 18558 | 16502 | 0.88921219959 | 0.6 | 0 | 0 | 0 | 0 | 19090.62 | 16387 | 0.858379664987 | 0.5 | 0 | 0 |
| 4 | C04_easy_aggressive | 1 | 1 | 0.0788148409442 | 0.069257327554 | 19623.24 | 14932.2 | 0.760944675803 | 0.4 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0.0743030112986 | 0.0683474244553 | 18558 | 15855.2 | 0.85435930596 | 0.6 | 0 | 0 | 0 | 0 | 19090.62 | 15393.7 | 0.806348877093 | 0.5 | 0 | 0 |
| 5 | C05_easy_very_aggressive | 1 | 1 | 0.0788148409442 | 0.0572647286861 | 19623.24 | 14094 | 0.718230017061 | 1 | 0 | 0 | 0 | 1 | 1 | 1 | 1 | 0.0743030112986 | 0.0527528990405 | 18558 | 13242.6 | 0.713579049467 | 1 | 0 | 0 | 0 | 1 | 19090.62 | 13668.3 | 0.715969413251 | 0.6 | 0 | 0 |
| 6 | C06_no_window_expand | 1 | 1 | 0.0788148409442 | 0.069257327554 | 19623.24 | 16272 | 0.82922086261 | 0.4 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0.0743030112986 | 0.0683474244553 | 18558 | 16502 | 0.88921219959 | 0.6 | 0 | 0 | 0 | 0 | 19090.62 | 16387 | 0.858379664987 | 0.5 | 0 | 0 |
| 7 | C07_topK_only | 1 | 1 | 0.0788148409442 | 0.0788148409442 | 19623.24 | 16302.8 | 0.830790430123 | 1 | 0 | 0 | 0 | 1 | 1 | 1 | 1 | 0.0743030112986 | 0.0743030112986 | 18558 | 16413.84 | 0.884461687682 | 1 | 0 | 0 | 0 | 1 | 19090.62 | 16358.32 | 0.856877356524 | 0.5 | 0 | 0 |
| 8 | C08_safe_default | 1 | 1 | 0.0788148409442 | 0.0788148409442 | 19623.24 | 16841 | 0.858217093609 | 1 | 0 | 0 | 0 | 1 | 1 | 1 | 1 | 0.0743030112986 | 0.0743030112986 | 18558 | 17276.4 | 0.930940834142 | 1 | 0 | 0 | 0 | 1 | 19090.62 | 17058.7 | 0.8935644835 | 0.68 | 0 | 0 |
| 9 | C09_gap_low | 1 | 1 | 0.0788148409442 | 0.069257327554 | 19623.24 | 16272 | 0.82922086261 | 0.4 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0.0743030112986 | 0.0647454979084 | 18558 | 15235.8 | 0.820982864533 | 0.4 | 0 | 0 | 0 | 0 | 19090.62 | 15753.9 | 0.825216781854 | 0.6 | 0 | 0 |
| 10 | C10_easy_top1_window075 | 1 | 1 | 0.0788148409442 | 0.0788148409442 | 19623.24 | 15830.52 | 0.806723048793 | 1 | 0 | 0 | 0 | 1 | 1 | 1 | 1 | 0.0743030112986 | 0.0743030112986 | 18558 | 17060.8 | 0.919323202931 | 1 | 0 | 0 | 0 | 1 | 19090.62 | 16445.66 | 0.861452378184 | 0.66 | 0 | 0 |
| 11 | C11_default_plus_low_conf | 1 | 1 | 0.0788148409442 | 0.0788148409442 | 19623.24 | 19623.24 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 1 | 1 | 0.0743030112986 | 0.0743030112986 | 18558 | 18558 | 1 | 1 | 0 | 0 | 1 | 0 | 19090.62 | 19090.62 | 1 | 1 | 1 | 1 |
| 12 | C12_balanced_candidate | 1 | 1 | 0.0788148409442 | 0.080063875347 | 19623.24 | 16741.52 | 0.853147594383 | 0.48 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0.0743030112986 | 0.0752486918464 | 18558 | 16502 | 0.88921219959 | 0.6 | 0 | 0 | 0 | 0 | 19090.62 | 16621.76 | 0.870676803582 | 0.54 | 0 | 0 |

## Selected policy distribution

| policy_name | n_trials | policy_rate | success_rate | mean_num_pairs | mean_U_search | mean_U_confidence |
| --- | --- | --- | --- | --- | --- | --- |
| EASY | 207 | 0.5175 | 1 | 9729 | 0.058703016072 | 0.367152648505 |
| NORMAL | 146 | 0.365 | 0.986301369863 | 18717.1575342 | 0.409190767718 | 0.507262992742 |
| SCORE_AMBIGUOUS | 47 | 0.1175 | 1 | 20621.1276596 | 0.548092158942 | 0.562101008362 |
| BOUNDARY | 0 | 0 | NaN | NaN | NaN | NaN |
| ILL_CONDITIONED | 0 | 0 | NaN | NaN | NaN | NaN |

## Bias robustness

| bias_case_id | az_center_bias_deg | el_center_bias_deg | n_trials | fixed_success | adaptive_success | adaptive_success_drop_vs_zero | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | adaptive_full_grid_match_rate | adaptive_mean_num_pairs | bias_robustness_pass_020 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | -0.2 | -0.2 | 50 | 1 | 1 | 0 | 0 | 0 | 0.46 | 13350.14 | 1 |
| 2 | -0.2 | 0 | 50 | 1 | 1 | 0 | 0 | 0 | 0.6 | 14688.18 | 1 |
| 3 | 0 | -0.2 | 50 | 0.96 | 0.96 | 0.04 | 0 | 0 | 0.2 | 11180.6 | 1 |
| 4 | 0 | 0 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 13668.3 | 1 |
| 5 | 0 | 0.2 | 50 | 1 | 1 | 0 | 0 | 0 | 1 | 17063.58 | 1 |
| 6 | 0.2 | 0 | 50 | 1 | 1 | 0 | 0 | 0 | 0.5 | 14112.72 | 1 |
| 7 | 0.2 | 0.2 | 50 | 1 | 1 | 0 | 0 | 0 | 0.7 | 16584.2 | 1 |
