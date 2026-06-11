# 第12步 波束级ML FPGA可行性边界验证记录

## 本轮目的

本轮围绕第11.x beamspace ML 后端，验证有限字长对 score ranking consistency、topK preservation、score gap stability 以及 cache/storage/bandwidth 的影响。

本步骤不是完整 FPGA RTL，不是 bit-true HDL 仿真，不是完整 FPGA backend 或下板验证结论，也不复用 Step8.9 的结果或 pass/fail 标准。

## 第11.x Adapter 来源

- final 入口: `step11_7_final_cached_c05_beamspace_ml_backend`
- score 函数: `beamspace_dml_score`
- candidate 范围: Step11.7 C05 coarse-stage controlled pair2d candidate table
- adapter found flag: 1
- uses_step89_results_flag: 0
- blocker: `none`

## Formal / Chunk 状态

- run_tag: `formal_tps30`
- quick_mode_flag: 0
- chunked_run_flag: 1
- formal_trial_count: 300
- min_formal_obs: 300
- formal_plan_total_obs: 1200
- formal_plan_completed_obs: 300
- formal_plan_complete_flag: 0
- formal_min_obs_satisfied_flag: 1
- chunks_detected: 30
- chunks_completed: 30

## Chunked Formal Validation

formal_tps30 曾受交互窗口限制，本轮新增 chunked formal validation、checkpoint/resume、aggregate-only、formal_core mode set 和 profiling 输出。aggregate-only 只读取 chunk partial CSV，不重新运行 Step11 observation 或 score recomputation。

正式 proceed_to_rtl_score_core_flag 只能在非 quick、满足 min formal obs、uses_step89_results_flag=0 且 ranking/topK formal gate 通过时置 1。

## Quantization Modes

mode_set 为 `formal_core`。formal_core 至少包含 double_baseline、float32_all、combined_int14、combined_int16、combined_int18、combined_int24、mixed_Z16_G24_Rz24 和 W_int18_G24_Z16。float32_all 仅为诊断参考，不作为 fixed-point pass candidate。

## Score Ranking / TopK Pass-Fail 标准

正式 fixed-point pass/fail 只由 ML score ranking consistency 和 topK preservation 决定。policy/confidence/fallback/boundary 仅作为工程风险诊断。

- ranking_pass_flag: reliable_top1_preservation_rate >= 0.999, reliable_score_gap_sign_flip_rate == 0, argmax_changed_rate_on_reliable_margin <= 0.001。
- topK_pass_flag: reliable_topK_set_preservation_rate >= 0.995, overall_topK_set_preservation_rate >= 0.980, reliable_topK_miss_rate <= 0.005。
- formal fixed_point_pass_flag 还要求 quick_mode_flag=0 且 formal_trial_count >= min_formal_obs。

## 总体结果表

| quant_mode | is_fixed_candidate | recommendation_candidate_flag | num_trials | reliable_trial_count | overall_top1_preservation_rate | overall_topK_set_preservation_rate | overall_topK_miss_rate | reliable_top1_preservation_rate | reliable_topK_set_preservation_rate | reliable_topK_miss_rate | argmax_changed_rate_on_reliable_margin | reliable_score_gap_sign_flip_rate | mean_score_rank_spearman | min_score_rank_spearman | max_candidate_score_rel_l2_error | max_score_gap_rel_error | same_policy_rate | same_estimate_rate | same_confidence_rate | same_fallback_rate | boundary_state_same_rate | max_clip_rate | max_overflow_rate | ranking_pass_flag | topK_pass_flag | fixed_point_pass_flag | mode_storage_cost_bits |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | 0 | 0 | 300 | 185 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| float32_all | 0 | 0 | 300 | 185 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 9.85384e-07 | 0.00114912 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| combined_int16 | 1 | 1 | 300 | 185 | 0.92 | 0.993333 | 0.000666667 | 0.945946 | 0.994595 | 0.000540541 | 0.0540541 | 0 | 1 | 1 | 4.38601e-05 | 0.101385 | 1 | 0.92 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 16 |
| combined_int18 | 1 | 1 | 300 | 185 | 0.983333 | 1 | 0 | 0.994595 | 1 | 0 | 0.00540541 | 0 | 1 | 1 | 1.08498e-05 | 0.0149798 | 1 | 0.983333 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 18 |
| combined_int24 | 1 | 1 | 300 | 185 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.64558e-07 | 0.000255016 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |
| mixed_Z16_G24_Rz24 | 1 | 1 | 300 | 185 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 5.26286e-06 | 0.00261169 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |
| combined_int14 | 1 | 1 | 300 | 185 | 0.71 | 0.98 | 0.002 | 0.821622 | 0.978378 | 0.00216216 | 0.178378 | 0 | 1 | 1 | 0.000211591 | 0.265671 | 1 | 0.71 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 16 |
| W_int18_G24_Z16 | 1 | 1 | 300 | 185 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 5.47666e-06 | 0.00332874 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |

## Mode Selection

| quant_mode | is_fixed_candidate | is_recommendation_candidate | component_bits | formal_trial_count | ranking_pass_flag | topK_pass_flag | fixed_point_pass_flag | reliable_top1_preservation_rate | reliable_topK_set_preservation_rate | overall_topK_set_preservation_rate | reliable_topK_miss_rate | argmax_changed_rate_on_reliable_margin | reliable_score_gap_sign_flip_rate | max_candidate_score_rel_l2_error | max_score_gap_rel_error | max_clip_rate | max_overflow_rate | estimated_total_MB | estimated_BRAM36 | estimated_URAM288 | engineering_rank | selection_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | 0 | 0 | 16 | 300 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | not_fixed_candidate |
| float32_all | 0 | 0 | 16 | 300 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 9.85384e-07 | 0.00114912 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | not_fixed_candidate |
| combined_int16 | 1 | 1 | 16 | 300 | 0 | 0 | 0 | 0.945946 | 0.994595 | 0.993333 | 0.000540541 | 0.0540541 | 0 | 4.38601e-05 | 0.101385 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | ranking_not_closed |
| combined_int18 | 1 | 1 | 18 | 300 | 0 | 1 | 0 | 0.994595 | 1 | 1 | 0 | 0.00540541 | 0 | 1.08498e-05 | 0.0149798 | 0 | 0 | 0.0848737 | 20 | 3 | NaN | ranking_not_closed |
| combined_int24 | 1 | 1 | 24 | 300 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 1.64558e-07 | 0.000255016 | 0 | 0 | 0.113165 | 26 | 4 | 1 | formal_ranking_topK_passed |
| mixed_Z16_G24_Rz24 | 1 | 1 | 24 | 300 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 5.26286e-06 | 0.00261169 | 0 | 0 | 0.113165 | 26 | 4 | 2 | formal_ranking_topK_passed |
| combined_int14 | 1 | 1 | 16 | 300 | 0 | 0 | 0 | 0.821622 | 0.978378 | 0.98 | 0.00216216 | 0.178378 | 0 | 0.000211591 | 0.265671 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | ranking_not_closed |
| W_int18_G24_Z16 | 1 | 1 | 24 | 300 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 5.47666e-06 | 0.00332874 | 0 | 0 | 0.113165 | 26 | 4 | 3 | formal_ranking_topK_passed |

## combined_int16 状态

- combined_int16_formal_pass_flag: 0
- combined_int16_blocker_if_any: `reliable_argmax_changed`
- combined_int16_reliable_top1_preservation: 0.945945945946
- combined_int16_reliable_topK_preservation: 0.994594594595

## Score Gap Stress Bins

| quant_mode | gap_bin | num_trials | top1_preservation_rate | topK_set_preservation_rate | topK_miss_rate | argmax_changed_rate | score_gap_sign_flip_rate | mean_score_gap_rel_error | p95_score_gap_rel_error | max_score_gap_rel_error | same_policy_rate | same_confidence_rate | same_boundary_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| double_baseline | gap_bin_weak | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| double_baseline | gap_bin_transition | 114 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| double_baseline | gap_bin_reliable | 185 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| float32_all | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| float32_all | gap_bin_weak | 1 | 1 | 1 | 0 | 0 | 0 | 0.000593273 | 0.000593273 | 0.000593273 | 1 | 1 | 1 |
| float32_all | gap_bin_transition | 114 | 1 | 1 | 0 | 0 | 0 | 0.000212036 | 0.000961369 | 0.00114912 | 1 | 1 | 1 |
| float32_all | gap_bin_reliable | 185 | 1 | 1 | 0 | 0 | 0 | 4.00487e-05 | 0.000105653 | 0.000128441 | 1 | 1 | 1 |
| combined_int16 | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int16 | gap_bin_weak | 1 | 1 | 1 | 0 | 0 | 0 | 0.101385 | 0.101385 | 0.101385 | 1 | 1 | 1 |
| combined_int16 | gap_bin_transition | 114 | 0.877193 | 0.991228 | 0.000877193 | 0.122807 | 0 | 0.0137895 | 0.0475951 | 0.0863009 | 1 | 1 | 1 |
| combined_int16 | gap_bin_reliable | 185 | 0.945946 | 0.994595 | 0.000540541 | 0.0540541 | 0 | 0.00249269 | 0.00515914 | 0.0081717 | 1 | 1 | 1 |
| combined_int18 | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int18 | gap_bin_weak | 1 | 1 | 1 | 0 | 0 | 0 | 0.00958473 | 0.00958473 | 0.00958473 | 1 | 1 | 1 |
| combined_int18 | gap_bin_transition | 114 | 0.964912 | 1 | 0 | 0.0350877 | 0 | 0.00338291 | 0.0110749 | 0.0149798 | 1 | 1 | 1 |
| combined_int18 | gap_bin_reliable | 185 | 0.994595 | 1 | 0 | 0.00540541 | 0 | 0.000650775 | 0.00141633 | 0.00189677 | 1 | 1 | 1 |
| combined_int24 | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int24 | gap_bin_weak | 1 | 1 | 1 | 0 | 0 | 0 | 0.000255016 | 0.000255016 | 0.000255016 | 1 | 1 | 1 |
| combined_int24 | gap_bin_transition | 114 | 1 | 1 | 0 | 0 | 0 | 5.17115e-05 | 0.000166667 | 0.0002499 | 1 | 1 | 1 |
| combined_int24 | gap_bin_reliable | 185 | 1 | 1 | 0 | 0 | 0 | 1.04715e-05 | 2.31667e-05 | 3.22019e-05 | 1 | 1 | 1 |

_Only first 20 rows shown; see CSV for full table._

- reliable_margin_instability_flag: 0
- failures_limited_to_low_margin_cases: 0
- worst_gap_bin_for_recommended_mode: `gap_bin_weak`

## Cache Storage 估算

- cache_estimate_scope: `both_working_set_and_full_cache`
- working-set cache estimate: 0.113164901733 MB, BRAM36=31, URAM288=9
- full-cache estimate if available: 5.2387046814 MB, BRAM36=1193, URAM288=150

| object_name | num_complex | component_bits | bits_per_complex | total_bits | total_MB | BRAM36_equivalent | URAM288_equivalent | read_complex_per_candidate | read_bits_per_candidate | comment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W | 84 | 24 | 48 | 4032 | 0.000480652 | 1 | 1 | 7 | 336 | beamforming projection matrix W |
| G_cache | 4816 | 24 | 48 | 231168 | 0.0275574 | 7 | 1 | 14 | 672 | Step11.6 canonical beamspace G cache |
| Z_buffer | 112 | 24 | 48 | 5376 | 0.000640869 | 1 | 1 | 7 | 336 | beamspace snapshot buffer after Step11 whitening |
| Rz_buffer | 49 | 24 | 48 | 2352 | 0.00028038 | 1 | 1 | 49 | 2352 | Step11 score covariance uses unnormalized Z*Z' |
| score_buffer | 7353 | 24 | 48 | 352944 | 0.0420742 | 10 | 2 | 0 | 48 | real score values stored with conservative complex-slot accounting |
| topK_buffer | 10 | 24 | 48 | 480 | 5.72205e-05 | 1 | 1 | 0 | 96 | topK candidate id plus score metadata estimate |
| candidate_table_minimal | 7353 | 24 | 48 | 352944 | 0.0420742 | 10 | 2 | 0 | 192 | az/el/sep/orientation/index metadata estimate |

## Bandwidth / Score Lane 估算

| stage_name | num_candidates | topK | G_vectors_per_candidate | G_complex_per_vector | Rz_dim | complex_read_per_candidate | bits_read_per_candidate | estimated_complex_mac_per_candidate | score_lanes | II_assumed | cycles_score_map | cycles_topK | cycles_total_est | throughput_candidate_per_cycle | comment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| coarse_stage | 7353 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 1 | 1 | 7353 | 25438 | 32791 | 1 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| coarse_stage | 7353 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 4 | 1 | 1839 | 6360 | 8199 | 4 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| coarse_stage | 7353 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 8 | 1 | 920 | 3180 | 4100 | 8 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| fine_stage_typical_if_available | 5147 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 1 | 1 | 5147 | 17806 | 22953 | 1 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| fine_stage_typical_if_available | 5147 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 4 | 1 | 1287 | 4452 | 5739 | 4 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| fine_stage_typical_if_available | 5147 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 8 | 1 | 644 | 2226 | 2870 | 8 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| worst_case | 11030 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 1 | 1 | 11030 | 38158 | 49188 | 1 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| worst_case | 11030 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 4 | 1 | 2758 | 9540 | 12298 | 4 | score core estimate for Step11 controlled pair2d DML candidate scoring |
| worst_case | 11030 | 10 | 2 | 7 | 7 | 63 | 3024 | 140 | 8 | 1 | 1379 | 4770 | 6149 | 8 | score core estimate for Step11 controlled pair2d DML candidate scoring |

## Profiling 摘要

| stage_name | total_elapsed_sec | mean_elapsed_sec | p95_elapsed_sec | max_elapsed_sec | num_calls |
| --- | --- | --- | --- | --- | --- |
| score_recompute | 931.504 | 0.388127 | 0.535957 | 0.950302 | 2400 |
| ranking_compare | 471.905 | 0.196627 | 0.278058 | 0.492329 | 2400 |
| build_candidate_score_pack | 293.061 | 0.97687 | 1.29662 | 1.60671 | 300 |
| build_step11_input | 3.27194 | 0.0109065 | 0.0264069 | 0.0658347 | 300 |
| run_step11_backend | 0 | 0 | 0 | 0 | 300 |

## Worst Cases 总结

| case_type | trial_index | scenario_name | quant_mode | metric_name | metric_value | topK_miss_count | argmax_changed_flag | score_gap_norm_baseline | score_gap_rel_error | max_clip_rate | note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| max_topK_miss_count | 1086 | medium_beta_coherent | combined_int16 | topK_miss_count | 1 | 1 | 1 | 0.000453774 | 0.00927453 | 0 | see trial CSV for full fields |
| argmax_changed_largest_baseline_gap | 390 | hard_phase | combined_int16 | score_gap_norm_baseline | 0.00256089 | 0 | 1 | 0.00256089 | 0.00360831 | 0 | see trial CSV for full fields |
| max_score_gap_rel_error | 611 | easy_noncoherent | combined_int14 | score_gap_rel_error | 0.265671 | 0 | 0 | 8.31342e-05 | 0.265671 | 0 | see trial CSV for full fields |
| policy_changed_sample | NaN |  |  | same_policy_flag | NaN | NaN | 0 | NaN | NaN | NaN | no matching sample |
| max_clip_or_overflow_sample | 1 | easy_noncoherent | double_baseline | max_clip_rate | 0 | 0 | 0 | 0.00110155 | 0 | 0 | see trial CSV for full fields |

## Recommendation

| recommendation | rationale | recommended_fixed_point_format | proceed_to_rtl_score_core_flag | proceed_to_rtl_score_core_smoke_flag | proceed_to_full_fpga_backend_flag |
| --- | --- | --- | --- | --- | --- |
| proceed_to_rtl_score_core_prototype_only | ranking and topK preservation passed for the recommended fixed-point score-core mode | mixed_Z16_G24_Rz24 | 1 | 0 | 0 |

## Golden Vectors

- exported: 1
- manifest: `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_12_beamspace_ml_fpga_boundary\results_step12_beamspace_ml_fpga_boundary\formal_tps30\aggregate\step12_ml_fpga_boundary_golden_vector_manifest.md`

## 最终判断

- minimum_passing_mode: `combined_int24`
- engineering_recommended_fixed_point_format: `mixed_Z16_G24_Rz24`
- fixed_point_pass_flag: 1
- blocker_if_any: `none`
- proceed_to_rtl_score_core_flag: 1
- proceed_to_full_fpga_backend_flag: 0

## 下一步建议

formal ranking/topK gate 已对工程推荐 fixed-point mode 关闭。下一步只建议进入 RTL score core prototype；这仍不代表完整 FPGA backend 通过。
