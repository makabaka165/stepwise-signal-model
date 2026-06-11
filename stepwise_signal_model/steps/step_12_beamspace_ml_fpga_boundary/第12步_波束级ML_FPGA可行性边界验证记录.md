# 第12步 波束级ML FPGA可行性边界验证记录

## 本轮目的

本轮围绕第11.x beamspace ML 后端，验证有限字长对 score ranking consistency、topK preservation、score gap stability 以及 cache/storage/bandwidth 的影响。

本步骤不是完整 FPGA RTL、不是 bit-true HDL 仿真、不是完整 FPGA backend 或下板验证结论，也不复用 Step8.9 的结果或 pass/fail 标准。

## 第11.x adapter 来源

- final 入口：`step11_7_final_cached_c05_beamspace_ml_backend`
- score 函数：`beamspace_dml_score`
- candidate 范围：Step11.7 C05 coarse-stage controlled pair2d candidate table
- adapter found flag：1
- uses_step89_results_flag：0
- blocker：`formal_trial_count_below_minimum`

## Formal / Quick 状态

- run_tag：`pilot_min_fast_path`
- quick_mode_flag：0
- formal_trial_count：12
- min_formal_obs：100
- reliable_margin_threshold：0.001

运行备注：本轮是较小的 formal-path pilot，用于验证 Step12 formal 输出链路。用户请求的 `pilot_tps10` 在当前交互执行窗口内超时，`formal_tps30` 未完成，因此本记录不构成正式 FPGA 可行性结论。

## Quantization Modes

包含 double baseline、float32 diagnostic、W/G_cache/Z/Rz 单对象整数模式、combined_int16/int18/int24、mixed_Z16_G24_Rz24 等。float32_all 仅作诊断参考，不参与 fixed-point pass candidate。

## Score Ranking / TopK Pass-Fail 标准

正式 fixed-point pass/fail 只由 ML score ranking consistency 和 topK preservation 决定。policy/confidence/fallback/boundary 仅作为工程风险诊断。

- ranking_pass_flag：reliable_top1_preservation_rate >= 0.999，reliable_score_gap_sign_flip_rate == 0，argmax_changed_rate_on_reliable_margin <= 0.001。
- topK_pass_flag：reliable_topK_set_preservation_rate >= 0.995，overall_topK_set_preservation_rate >= 0.980，reliable_topK_miss_rate <= 0.005。
- formal fixed_point_pass_flag 还要求 quick_mode_flag=0 且 formal_trial_count >= min_formal_obs。

## 总体结果表

| quant_mode | is_fixed_candidate | recommendation_candidate_flag | num_trials | reliable_trial_count | overall_top1_preservation_rate | overall_topK_set_preservation_rate | overall_topK_miss_rate | reliable_top1_preservation_rate | reliable_topK_set_preservation_rate | reliable_topK_miss_rate | argmax_changed_rate_on_reliable_margin | reliable_score_gap_sign_flip_rate | mean_score_rank_spearman | min_score_rank_spearman | max_candidate_score_rel_l2_error | max_score_gap_rel_error | same_policy_rate | same_estimate_rate | same_confidence_rate | same_fallback_rate | boundary_state_same_rate | max_clip_rate | max_overflow_rate | ranking_pass_flag | topK_pass_flag | fixed_point_pass_flag | mode_storage_cost_bits |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | 0 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| float32_all | 0 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 7.40456e-07 | 0.000486515 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| W_int16_only | 1 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 5.44022e-07 | 2.51749e-05 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| Gcache_int16_only | 1 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.88279e-05 | 0.00185253 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| Z_int16_only | 1 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 3.87221e-06 | 0.000402015 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| Rz_int18_only | 1 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 4.79783e-06 | 0.000378362 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 18 |
| combined_int16 | 1 | 1 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 3.14639e-05 | 0.0181721 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| combined_int18 | 1 | 1 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 7.79465e-06 | 0.00592834 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 18 |
| combined_int24 | 1 | 1 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.17995e-07 | 5.19644e-05 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |
| mixed_Z16_G24_score_float | 0 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 3.86923e-06 | 0.000367324 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |
| mixed_Z16_G24_Rz24 | 1 | 1 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 3.82754e-06 | 0.000396011 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |
| combined_int14 | 1 | 1 | 12 | 6 | 0.833333 | 1 | 0 | 0.833333 | 1 | 0 | 0.166667 | 0 | 1 | 1 | 0.000114626 | 0.0354613 | 1 | 0.833333 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 16 |
| Gcache_int24_only | 1 | 0 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 7.4861e-08 | 3.24692e-06 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |
| W_int18_G24_Z16 | 1 | 1 | 12 | 6 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 3.69233e-06 | 0.000396097 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |

## Mode Selection

| quant_mode | is_fixed_candidate | is_recommendation_candidate | component_bits | formal_trial_count | ranking_pass_flag | topK_pass_flag | fixed_point_pass_flag | reliable_top1_preservation_rate | reliable_topK_set_preservation_rate | overall_topK_set_preservation_rate | reliable_topK_miss_rate | argmax_changed_rate_on_reliable_margin | reliable_score_gap_sign_flip_rate | max_candidate_score_rel_l2_error | max_score_gap_rel_error | max_clip_rate | max_overflow_rate | estimated_total_MB | estimated_BRAM36 | estimated_URAM288 | engineering_rank | selection_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | 0 | 0 | 16 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 5.35228 | 1218 | 153 | NaN | not_fixed_candidate |
| float32_all | 0 | 0 | 16 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 7.40456e-07 | 0.000486515 | 0 | 0 | 5.35228 | 1218 | 153 | NaN | not_fixed_candidate |
| W_int16_only | 1 | 0 | 16 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 5.44022e-07 | 2.51749e-05 | 0 | 0 | 5.35228 | 1218 | 153 | NaN | formal_trial_count_below_minimum |
| Gcache_int16_only | 1 | 0 | 16 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 1.88279e-05 | 0.00185253 | 0 | 0 | 5.35228 | 1218 | 153 | NaN | formal_trial_count_below_minimum |
| Z_int16_only | 1 | 0 | 16 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 3.87221e-06 | 0.000402015 | 0 | 0 | 5.35228 | 1218 | 153 | NaN | formal_trial_count_below_minimum |
| Rz_int18_only | 1 | 0 | 18 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 4.79783e-06 | 0.000378362 | 0 | 0 | 6.02131 | 1371 | 172 | NaN | formal_trial_count_below_minimum |
| combined_int16 | 1 | 1 | 16 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 3.14639e-05 | 0.0181721 | 0 | 0 | 5.35228 | 1218 | 153 | NaN | formal_trial_count_below_minimum |
| combined_int18 | 1 | 1 | 18 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 7.79465e-06 | 0.00592834 | 0 | 0 | 6.02131 | 1371 | 172 | NaN | formal_trial_count_below_minimum |
| combined_int24 | 1 | 1 | 24 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 1.17995e-07 | 5.19644e-05 | 0 | 0 | 8.02842 | 1827 | 229 | NaN | formal_trial_count_below_minimum |
| mixed_Z16_G24_score_float | 0 | 0 | 24 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 3.86923e-06 | 0.000367324 | 0 | 0 | 8.02842 | 1827 | 229 | NaN | not_fixed_candidate |
| mixed_Z16_G24_Rz24 | 1 | 1 | 24 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 3.82754e-06 | 0.000396011 | 0 | 0 | 8.02842 | 1827 | 229 | NaN | formal_trial_count_below_minimum |
| combined_int14 | 1 | 1 | 16 | 12 | 0 | 1 | 0 | 0.833333 | 1 | 1 | 0 | 0.166667 | 0 | 0.000114626 | 0.0354613 | 0 | 0 | 5.35228 | 1218 | 153 | NaN | formal_trial_count_below_minimum |
| Gcache_int24_only | 1 | 0 | 24 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 7.4861e-08 | 3.24692e-06 | 0 | 0 | 8.02842 | 1827 | 229 | NaN | formal_trial_count_below_minimum |
| W_int18_G24_Z16 | 1 | 1 | 24 | 12 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 3.69233e-06 | 0.000396097 | 0 | 0 | 8.02842 | 1827 | 229 | NaN | formal_trial_count_below_minimum |

## combined_int16 状态

- combined_int16_formal_pass_flag：0
- combined_int16_blocker_if_any：`formal_trial_count_below_minimum`
- combined_int16_reliable_top1_preservation：1
- combined_int16_reliable_topK_preservation：1

## Score Gap Stress Bins

| quant_mode | gap_bin | num_trials | top1_preservation_rate | topK_set_preservation_rate | topK_miss_rate | argmax_changed_rate | score_gap_sign_flip_rate | mean_score_gap_rel_error | p95_score_gap_rel_error | max_score_gap_rel_error | same_policy_rate | same_confidence_rate | same_boundary_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| double_baseline | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| double_baseline | gap_bin_transition | 6 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| double_baseline | gap_bin_reliable | 6 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| float32_all | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| float32_all | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| float32_all | gap_bin_transition | 6 | 1 | 1 | 0 | 0 | 0 | 0.000118196 | 0.000486515 | 0.000486515 | 1 | 1 | 1 |
| float32_all | gap_bin_reliable | 6 | 1 | 1 | 0 | 0 | 0 | 3.74397e-05 | 0.000105623 | 0.000105623 | 1 | 1 | 1 |
| W_int16_only | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| W_int16_only | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| W_int16_only | gap_bin_transition | 6 | 1 | 1 | 0 | 0 | 0 | 1.12558e-05 | 2.51749e-05 | 2.51749e-05 | 1 | 1 | 1 |
| W_int16_only | gap_bin_reliable | 6 | 1 | 1 | 0 | 0 | 0 | 3.28255e-06 | 4.6845e-06 | 4.6845e-06 | 1 | 1 | 1 |
| Gcache_int16_only | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| Gcache_int16_only | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| Gcache_int16_only | gap_bin_transition | 6 | 1 | 1 | 0 | 0 | 0 | 0.00100731 | 0.00185253 | 0.00185253 | 1 | 1 | 1 |
| Gcache_int16_only | gap_bin_reliable | 6 | 1 | 1 | 0 | 0 | 0 | 0.000488979 | 0.000623369 | 0.000623369 | 1 | 1 | 1 |
| Z_int16_only | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| Z_int16_only | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| Z_int16_only | gap_bin_transition | 6 | 1 | 1 | 0 | 0 | 0 | 0.00014 | 0.000402015 | 0.000402015 | 1 | 1 | 1 |
| Z_int16_only | gap_bin_reliable | 6 | 1 | 1 | 0 | 0 | 0 | 6.27663e-05 | 0.00010173 | 0.00010173 | 1 | 1 | 1 |

_Only first 20 rows shown; see CSV for full table._

- reliable_margin_instability_flag：0
- failures_limited_to_low_margin_cases：0
- worst_gap_bin_for_recommended_mode：`gap_bin_transition`

## Cache Storage 估算

| object_name | num_complex | component_bits | bits_per_complex | total_bits | total_MB | BRAM36_equivalent | URAM288_equivalent | read_complex_per_candidate | read_bits_per_candidate | comment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W | 14560 | 16 | 32 | 465920 | 0.055542 | 13 | 2 | 7 | 224 | beamforming projection matrix W |
| G_cache | 1.3733e+06 | 16 | 32 | 4.39454e+07 | 5.2387 | 1193 | 150 | 14 | 448 | Step11.6 canonical beamspace G cache |
| Z_buffer | 448 | 16 | 32 | 14336 | 0.00170898 | 1 | 1 | 7 | 224 | beamspace snapshot buffer after Step11 whitening |
| Rz_buffer | 49 | 16 | 32 | 1568 | 0.00018692 | 1 | 1 | 49 | 1568 | Step11 score covariance uses unnormalized Z*Z' |
| score_buffer | 7353 | 16 | 32 | 235296 | 0.0280495 | 7 | 1 | 0 | 32 | real score values stored with conservative complex-slot accounting |
| topK_buffer | 10 | 16 | 32 | 320 | 3.8147e-05 | 1 | 1 | 0 | 64 | topK candidate id plus score metadata estimate |
| candidate_table_minimal | 7353 | 16 | 32 | 235296 | 0.0280495 | 7 | 1 | 0 | 128 | az/el/sep/orientation/index metadata estimate |

## Bandwidth / Score Lane 估算

| stage_name | num_candidates | topK | G_vectors_per_candidate | G_complex_per_vector | Rz_dim | complex_read_per_candidate | bits_read_per_candidate | estimated_complex_mac_per_candidate | score_lanes | II_assumed | cycles_score_map | cycles_topK | cycles_total_est | throughput_candidate_per_cycle | comment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| coarse_stage | 7353 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 1 | 1 | 7353 | 25438 | 32791 | 1 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| coarse_stage | 7353 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 4 | 1 | 1839 | 6360 | 8199 | 4 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| coarse_stage | 7353 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 8 | 1 | 920 | 3180 | 4100 | 8 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| fine_stage_typical_if_available | 5147 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 1 | 1 | 5147 | 17806 | 22953 | 1 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| fine_stage_typical_if_available | 5147 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 4 | 1 | 1287 | 4452 | 5739 | 4 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| fine_stage_typical_if_available | 5147 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 8 | 1 | 644 | 2226 | 2870 | 8 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| worst_case | 11030 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 1 | 1 | 11030 | 38158 | 49188 | 1 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| worst_case | 11030 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 4 | 1 | 2758 | 9540 | 12298 | 4 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| worst_case | 11030 | 10 | 2 | 7 | 7 | 63 | 2016 | 140 | 8 | 1 | 1379 | 4770 | 6149 | 8 | score core estimate for Step11 controlled pair2d DML candidate scoring |

## Worst Cases 总结

| case_type | trial_index | scenario_name | quant_mode | metric_name | metric_value | topK_miss_count | argmax_changed_flag | score_gap_norm_baseline | score_gap_rel_error | max_clip_rate | note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| max_topK_miss_count | 1 | easy_noncoherent | double_baseline | topK_miss_count | 0 | 0 | 0 | 0.00110155 | 0 | 0 | see trial CSV for full fields |
| argmax_changed_largest_baseline_gap | 11 | easy_noncoherent | combined_int14 | score_gap_norm_baseline | 0.00155735 | 0 | 1 | 0.00155735 | 0.0185308 | 0 | see trial CSV for full fields |
| max_score_gap_rel_error | 7 | easy_noncoherent | combined_int14 | score_gap_rel_error | 0.0354613 | 0 | 0 | 0.000823416 | 0.0354613 | 0 | see trial CSV for full fields |
| policy_changed_sample | NaN |  |  | same_policy_flag | NaN | NaN | 0 | NaN | NaN | NaN | no matching sample |
| max_clip_or_overflow_sample | 1 | easy_noncoherent | double_baseline | max_clip_rate | 0 | 0 | 0 | 0.00110155 | 0 | 0 | see trial CSV for full fields |

## Recommendation

| recommendation | rationale | recommended_fixed_point_format | proceed_to_rtl_score_core_flag | proceed_to_rtl_score_core_smoke_flag | proceed_to_full_fpga_backend_flag |
| --- | --- | --- | --- | --- | --- |
| do_not_proceed_to_rtl_score_core_until_score_ranking_or_topK_closes | formal_trial_count_below_minimum | not_recommended | 0 | 0 | 0 |

## Golden Vectors

- exported：0
- reason：需要 formal fixed-point pass 且 `STEP12_EXPORT_GOLDEN_VECTORS=1`。

## 最终判断

- minimum_passing_mode：`none`
- engineering_recommended_fixed_point_format：`not_recommended`
- fixed_point_pass_flag：0
- blocker_if_any：`formal_trial_count_below_minimum`
- proceed_to_rtl_score_core_flag：0
- proceed_to_full_fpga_backend_flag：0

## 下一步建议

本次为 pilot formal-path run，用于检查运行时间、结果字段和 mode selection 链路；不作为论文正式结论。若字段稳定，下一步运行 formal_tps30。
