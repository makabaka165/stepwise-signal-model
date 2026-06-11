# 第12步 波束级ML FPGA可行性边界验证记录

## 本轮目的

第12步用于第11.x波束级ML的FPGA feasibility boundary validation，重点验证有限字长下ML score ranking consistency和fixed-point topK preservation。

本步骤不是完整FPGA RTL，不是bit-true HDL仿真，也不是完整纯FPGA backend通过声明。

## 第11.x adapter来源

- final入口：`step11_7_final_cached_c05_beamspace_ml_backend`
- score函数：`beamspace_dml_score`
- candidate范围：Step11.7 C05 coarse-stage controlled pair2d candidate table
- adapter found flag：1
- blocker：`none`

## quantization modes

包含 double_baseline、float32_all、W/G_cache/Z/Rz单对象整数模式、combined_int16/int18/int24以及mixed_Z16_G24系列。float32_all仅作诊断参考，不参与fixed-point pass候选。

## score ranking / topK pass/fail标准

正式fixed-point pass/fail只由ML score ranking consistency和topK preservation决定。policy是工程风险诊断，正式fixed-point pass/fail由ML score ranking consistency和topK preservation决定。

- ranking_pass_flag：reliable_top1_preservation_rate >= 0.999，reliable_score_gap_sign_flip_rate == 0，argmax_changed_rate_on_reliable_margin <= 0.001。
- topK_pass_flag：reliable_topK_set_preservation_rate >= 0.995，overall_topK_set_preservation_rate >= 0.980，reliable_topK_miss_rate <= 0.005。
- fixed_point_pass_flag = ranking_pass_flag AND topK_pass_flag。

## 总体结果表

| quant_mode | is_fixed_candidate | recommendation_candidate_flag | num_trials | reliable_trial_count | overall_top1_preservation_rate | overall_topK_set_preservation_rate | overall_topK_miss_rate | reliable_top1_preservation_rate | reliable_topK_set_preservation_rate | reliable_topK_miss_rate | argmax_changed_rate_on_reliable_margin | reliable_score_gap_sign_flip_rate | mean_score_rank_spearman | min_score_rank_spearman | max_candidate_score_rel_l2_error | max_score_gap_rel_error | same_policy_rate | same_estimate_rate | same_confidence_rate | same_fallback_rate | boundary_state_same_rate | max_clip_rate | max_overflow_rate | ranking_pass_flag | topK_pass_flag | fixed_point_pass_flag | mode_storage_cost_bits |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | 0 | 0 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| float32_all | 0 | 0 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 8.18813e-07 | 3.26438e-05 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| W_int16_only | 1 | 0 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 3.65443e-07 | 8.87137e-06 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 16 |
| Gcache_int16_only | 1 | 0 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 2.44258e-05 | 0.000823271 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 16 |
| Z_int16_only | 1 | 0 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.63788e-06 | 8.2871e-05 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 16 |
| Rz_int18_only | 1 | 0 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 2.88655e-06 | 0.000378362 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 18 |
| combined_int16 | 1 | 1 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 3.07573e-05 | 0.00524399 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 16 |
| combined_int18 | 1 | 1 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 7.37581e-06 | 0.00154342 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 18 |
| combined_int24 | 1 | 1 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.32877e-07 | 2.13144e-05 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |
| mixed_Z16_G24_score_float | 0 | 0 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.64587e-06 | 0.000105623 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |
| mixed_Z16_G24_Rz24 | 1 | 1 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.63889e-06 | 9.64215e-05 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |
| combined_int14 | 1 | 1 | 2 | 2 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 0.000125479 | 0.00813459 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 16 |

_Only first 12 rows shown; see CSV for full table._

## cache storage估算

| object_name | num_complex | component_bits | bits_per_complex | total_bits | total_MB | BRAM36_equivalent | URAM288_equivalent | read_complex_per_candidate | read_bits_per_candidate | comment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W | 14560 | 16 | 32 | 465920 | 0.055542 | 13 | 2 | 7 | 224 | beamforming projection matrix W |
| G_cache | 1.3733e+06 | 16 | 32 | 4.39454e+07 | 5.2387 | 1193 | 150 | 14 | 448 | Step11.6 canonical beamspace G cache |
| Z_buffer | 448 | 16 | 32 | 14336 | 0.00170898 | 1 | 1 | 7 | 224 | beamspace snapshot buffer after Step11 whitening |
| Rz_buffer | 49 | 16 | 32 | 1568 | 0.00018692 | 1 | 1 | 49 | 1568 | Step11 score covariance uses unnormalized Z*Z' |
| score_buffer | 7353 | 16 | 32 | 235296 | 0.0280495 | 7 | 1 | 0 | 32 | real score values stored with conservative complex-slot accounting |
| topK_buffer | 10 | 16 | 32 | 320 | 3.8147e-05 | 1 | 1 | 0 | 64 | topK candidate id plus score metadata estimate |
| candidate_table_minimal | 7353 | 16 | 32 | 235296 | 0.0280495 | 7 | 1 | 0 | 128 | az/el/sep/orientation/index metadata estimate |

## bandwidth / score lane估算

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

## worst cases总结

| case_type | trial_index | scenario_name | quant_mode | metric_name | metric_value | topK_miss_count | argmax_changed_flag | score_gap_norm_baseline | score_gap_rel_error | max_clip_rate | note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| max_topK_miss_count | 1 | easy_noncoherent | double_baseline | topK_miss_count | 0 | 0 | 0 | 0.00110155 | 0 | 0 | see trial CSV for full fields |
| argmax_changed_largest_baseline_gap | NaN |  |  | score_gap_norm_baseline | NaN | NaN | 0 | NaN | NaN | NaN | no matching sample |
| max_score_gap_rel_error | 2 | strong_coherent | combined_int14 | score_gap_rel_error | 0.00813459 | 0 | 0 | 0.00115181 | 0.00813459 | 0 | see trial CSV for full fields |
| policy_changed_sample | NaN |  |  | same_policy_flag | NaN | NaN | 0 | NaN | NaN | NaN | no matching sample |
| max_clip_or_overflow_sample | 1 | easy_noncoherent | double_baseline | max_clip_rate | 0 | 0 | 0 | 0.00110155 | 0 | 0 | see trial CSV for full fields |

## 最终判断

- quick_mode_flag：1
- fixed_point_pass_flag：1
- recommended_fixed_point_format：`combined_int16`
- proceed_to_rtl_score_core_flag：1
- proceed_to_full_fpga_backend_flag：0

本次为quick smoke test，不能写成正式FPGA可行性结论。

## 下一步建议

若fixed_point_pass_flag为1，下一步只建议进入RTL score core prototype；仍需独立完成bit-true HDL仿真、接口时序、cache访问调度和板级验证。
