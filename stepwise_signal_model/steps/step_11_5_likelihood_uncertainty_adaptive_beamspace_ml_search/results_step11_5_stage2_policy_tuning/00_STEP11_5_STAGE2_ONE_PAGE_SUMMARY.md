# Step11.5 Stage2 One-Page Summary

## Stage label

Step11.5 Stage2: calibrated search-budget policy tuning

## Stage1 preserved result

Step11.5 Stage1: original uncertainty policy negative result / safety passed but complexity failed

- Stage1 fixed_topK3_mean_num_pairs = 19126.26
- Stage1 adaptive_mean_num_pairs = 38749.86
- Stage1 adaptive safety passed, but complexity failed because all samples entered HARD policy.

## Stage2 diagnosis

Stage1 failed because `H_norm` was near 1 and `gap_13` was smaller than the original 0.02 calibration scale. This pushed `U` above 0.55 for nearly every sample, so the policy became 100% HARD with topK=5 and 1.5x local windows.

## Stage2 modification

Stage2 decouples `U_search` from `U_confidence`. `H_norm` and `cond_risk` no longer dominate search budget; boundary risk controls window expansion, score gap controls topK growth, and fixed topK3 is the NORMAL default.

## Selected recommendation

- selected_config_name = `C05_easy_very_aggressive`
- selection_reason = `calibration_safety_and_non_degenerate_min_candidate_count`
- stage2_adaptive_pass_flag = 1
- recommended_next_step = `use_step11_5_stage2_as_positive_adaptive_enhancement`

## Validation metrics

- validation_fixed_success = 1
- validation_adaptive_success = 1
- validation_fixed_rmse = 0.0743030112986
- validation_adaptive_rmse = 0.0527528990405
- validation_fixed_mean_num_pairs = 18558
- validation_adaptive_mean_num_pairs = 13242.6
- validation_pair_count_ratio = 0.713579049467
- validation_policy_degeneracy_flag = 0

## Bias robustness

- bias_robustness_pass_flag = 1
- valid_bias_range_text = `az_bias=[-0.20,0.20], el_bias=[-0.20,0.20]`
