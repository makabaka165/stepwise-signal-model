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
- formal_trial_count: 1200
- min_formal_obs: 300
- formal_plan_total_obs: 1200
- formal_plan_completed_obs: 1200
- formal_plan_complete_flag: 1
- formal_min_obs_satisfied_flag: 1
- chunks_detected: 120
- chunks_completed: 120

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
| double_baseline | 0 | 0 | 1200 | 614 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| float32_all | 0 | 0 | 1200 | 614 | 0.999167 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 9.91393e-07 | 0.0429507 | 1 | 0.999167 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| combined_int16 | 1 | 1 | 1200 | 614 | 0.895833 | 0.991667 | 0.000833333 | 0.965798 | 0.998371 | 0.000162866 | 0.034202 | 0 | 1 | 1 | 4.6614e-05 | 1 | 0.999167 | 0.895833 | 0.999167 | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 16 |
| combined_int18 | 1 | 1 | 1200 | 614 | 0.973333 | 0.999167 | 8.33333e-05 | 0.995114 | 1 | 0 | 0.00488599 | 0 | 1 | 1 | 1.1336e-05 | 1 | 1 | 0.973333 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 18 |
| combined_int24 | 1 | 1 | 1200 | 614 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.69436e-07 | 0.0150665 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |
| mixed_Z16_G24_Rz24 | 1 | 1 | 1200 | 614 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 7.38896e-06 | 0.0208116 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |
| combined_int14 | 1 | 1 | 1200 | 614 | 0.6325 | 0.964167 | 0.00358333 | 0.820847 | 0.980456 | 0.0019544 | 0.179153 | 0 | 1 | 1 | 0.000211591 | 1.06944 | 0.999167 | 0.6325 | 0.999167 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 16 |
| W_int18_G24_Z16 | 1 | 1 | 1200 | 614 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 7.55914e-06 | 0.0306036 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 24 |

## Mode Selection

| quant_mode | is_fixed_candidate | is_recommendation_candidate | component_bits | formal_trial_count | ranking_pass_flag | topK_pass_flag | fixed_point_pass_flag | reliable_top1_preservation_rate | reliable_topK_set_preservation_rate | overall_topK_set_preservation_rate | reliable_topK_miss_rate | argmax_changed_rate_on_reliable_margin | reliable_score_gap_sign_flip_rate | max_candidate_score_rel_l2_error | max_score_gap_rel_error | max_clip_rate | max_overflow_rate | estimated_total_MB | estimated_BRAM36 | estimated_URAM288 | engineering_rank | selection_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | 0 | 0 | 16 | 1200 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | not_fixed_candidate |
| float32_all | 0 | 0 | 16 | 1200 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 9.91393e-07 | 0.0429507 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | not_fixed_candidate |
| combined_int16 | 1 | 1 | 16 | 1200 | 0 | 1 | 0 | 0.965798 | 0.998371 | 0.991667 | 0.000162866 | 0.034202 | 0 | 4.6614e-05 | 1 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | ranking_not_closed |
| combined_int18 | 1 | 1 | 18 | 1200 | 0 | 1 | 0 | 0.995114 | 1 | 0.999167 | 0 | 0.00488599 | 0 | 1.1336e-05 | 1 | 0 | 0 | 0.0848737 | 20 | 3 | NaN | ranking_not_closed |
| combined_int24 | 1 | 1 | 24 | 1200 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 1.69436e-07 | 0.0150665 | 0 | 0 | 0.113165 | 26 | 4 | 1 | formal_ranking_topK_passed |
| mixed_Z16_G24_Rz24 | 1 | 1 | 24 | 1200 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 7.38896e-06 | 0.0208116 | 0 | 0 | 0.113165 | 26 | 4 | 2 | formal_ranking_topK_passed |
| combined_int14 | 1 | 1 | 16 | 1200 | 0 | 0 | 0 | 0.820847 | 0.980456 | 0.964167 | 0.0019544 | 0.179153 | 0 | 0.000211591 | 1.06944 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | ranking_not_closed |
| W_int18_G24_Z16 | 1 | 1 | 24 | 1200 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 7.55914e-06 | 0.0306036 | 0 | 0 | 0.113165 | 26 | 4 | 3 | formal_ranking_topK_passed |

## combined_int16 状态

- combined_int16_formal_pass_flag: 0
- combined_int16_blocker_if_any: `reliable_argmax_changed`
- combined_int16_reliable_top1_preservation: 0.965798045603
- combined_int16_reliable_topK_preservation: 0.998371335505

## Score Gap Stress Bins

| quant_mode | gap_bin | num_trials | top1_preservation_rate | topK_set_preservation_rate | topK_miss_rate | argmax_changed_rate | score_gap_sign_flip_rate | mean_score_gap_rel_error | p95_score_gap_rel_error | max_score_gap_rel_error | same_policy_rate | same_confidence_rate | same_boundary_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | gap_bin_very_weak | 2 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| double_baseline | gap_bin_weak | 83 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| double_baseline | gap_bin_transition | 501 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| double_baseline | gap_bin_reliable | 614 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| float32_all | gap_bin_very_weak | 2 | 1 | 1 | 0 | 0 | 0 | 0.0267384 | 0.0429507 | 0.0429507 | 1 | 1 | 1 |
| float32_all | gap_bin_weak | 83 | 1 | 1 | 0 | 0 | 0 | 0.00484175 | 0.0143101 | 0.0204169 | 1 | 1 | 1 |
| float32_all | gap_bin_transition | 501 | 0.998004 | 1 | 0 | 0.00199601 | 0 | 0.000252361 | 0.000830637 | 0.00164567 | 1 | 1 | 1 |
| float32_all | gap_bin_reliable | 614 | 1 | 1 | 0 | 0 | 0 | 3.55294e-05 | 9.44001e-05 | 0.000136225 | 1 | 1 | 1 |
| combined_int16 | gap_bin_very_weak | 2 | 0 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| combined_int16 | gap_bin_weak | 83 | 0.771084 | 1 | 0 | 0.228916 | 0 | 0.0564521 | 0.136896 | 0.30692 | 1 | 1 | 1 |
| combined_int16 | gap_bin_transition | 501 | 0.834331 | 0.982036 | 0.00179641 | 0.165669 | 0 | 0.0149908 | 0.047679 | 0.0863009 | 0.998004 | 0.998004 | 1 |
| combined_int16 | gap_bin_reliable | 614 | 0.965798 | 0.998371 | 0.000162866 | 0.034202 | 0 | 0.00250003 | 0.00584819 | 0.00901686 | 1 | 1 | 1 |
| combined_int18 | gap_bin_very_weak | 2 | 1 | 1 | 0 | 0 | 0.5 | 0.626685 | 1 | 1 | 1 | 1 | 1 |
| combined_int18 | gap_bin_weak | 83 | 0.903614 | 1 | 0 | 0.0963855 | 0 | 0.0176723 | 0.0304434 | 0.0947393 | 1 | 1 | 1 |
| combined_int18 | gap_bin_transition | 501 | 0.958084 | 0.998004 | 0.000199601 | 0.0419162 | 0 | 0.00378498 | 0.0121269 | 0.0190974 | 1 | 1 | 1 |
| combined_int18 | gap_bin_reliable | 614 | 0.995114 | 1 | 0 | 0.00488599 | 0 | 0.000621516 | 0.00143506 | 0.00194674 | 1 | 1 | 1 |
| combined_int24 | gap_bin_very_weak | 2 | 1 | 1 | 0 | 0 | 0 | 0.00814762 | 0.0150665 | 0.0150665 | 1 | 1 | 1 |
| combined_int24 | gap_bin_weak | 83 | 1 | 1 | 0 | 0 | 0 | 0.000277585 | 0.000571936 | 0.000745037 | 1 | 1 | 1 |
| combined_int24 | gap_bin_transition | 501 | 1 | 1 | 0 | 0 | 0 | 5.67332e-05 | 0.000189806 | 0.000332054 | 1 | 1 | 1 |
| combined_int24 | gap_bin_reliable | 614 | 1 | 1 | 0 | 0 | 0 | 1.02231e-05 | 2.35216e-05 | 3.31253e-05 | 1 | 1 | 1 |

_Only first 20 rows shown; see CSV for full table._

- reliable_margin_instability_flag: 0
- failures_limited_to_low_margin_cases: 0
- worst_gap_bin_for_recommended_mode: `gap_bin_very_weak`

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
| score_recompute | 3557.47 | 0.37057 | 0.571134 | 1.06975 | 9600 |
| ranking_compare | 1806.95 | 0.188224 | 0.289896 | 0.592071 | 9600 |
| build_candidate_score_pack | 1134.13 | 0.945105 | 1.39158 | 1.64185 | 1200 |
| build_step11_input | 10.4719 | 0.00872655 | 0.0181917 | 0.0715528 | 1200 |
| run_step11_backend | 0 | 0 | 0 | 0 | 1200 |

## Worst Cases 总结

| case_type | trial_index | scenario_name | quant_mode | metric_name | metric_value | topK_miss_count | argmax_changed_flag | score_gap_norm_baseline | score_gap_rel_error | max_clip_rate | note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| max_topK_miss_count | 1086 | medium_beta_coherent | combined_int16 | topK_miss_count | 1 | 1 | 1 | 0.000453774 | 0.00927453 | 0 | see trial CSV for full fields |
| argmax_changed_largest_baseline_gap | 1138 | large_el_pair | combined_int14 | score_gap_norm_baseline | 0.00496799 | 0 | 1 | 0.00496799 | 0.000212347 | 0 | see trial CSV for full fields |
| max_score_gap_rel_error | 511 | large_el_pair | combined_int14 | score_gap_rel_error | 1.06944 | 0 | 0 | 2.94984e-05 | 1.06944 | 0 | see trial CSV for full fields |
| policy_changed_sample | 1119 | large_el_pair | combined_int14 | same_policy_flag | 0 | 0 | 0 | 0.000158089 | 0.158625 | 0 | see trial CSV for full fields |
| max_clip_or_overflow_sample | 1 | easy_noncoherent | double_baseline | max_clip_rate | 0 | 0 | 0 | 0.00110155 | 0 | 0 | see trial CSV for full fields |

## Recommendation

| recommendation | rationale | recommended_fixed_point_format | proceed_to_rtl_score_core_flag | proceed_to_rtl_score_core_smoke_flag | proceed_to_full_fpga_backend_flag |
| --- | --- | --- | --- | --- | --- |
| proceed_to_rtl_score_core_prototype_only | ranking and topK preservation passed for the recommended fixed-point score-core mode | mixed_Z16_G24_Rz24 | 1 | 0 | 0 |

## Golden Vectors

- exported: 1

## Full formal收束状态

详见：[第12步_波束级ML_FPGA可行性边界验证收束报告.md](第12步_波束级ML_FPGA可行性边界验证收束报告.md)

full formal关键keypoints：

- run_tag: `formal_tps30`
- formal_plan_total_obs: 1200
- formal_plan_completed_obs: 1200
- formal_plan_complete_flag: 1
- formal_min_obs_satisfied_flag: 1
- uses_step89_results_flag: 0
- quick_mode_flag: 0
- fixed_point_pass_flag: 1
- blocker_if_any: `none`
- combined_int16_formal_pass_flag: 0
- combined_int16_blocker_if_any: `reliable_argmax_changed`
- minimum_passing_mode: `combined_int24`
- engineering_recommended_fixed_point_format: `mixed_Z16_G24_Rz24`
- recommended_fixed_point_format: `mixed_Z16_G24_Rz24`
- proceed_to_rtl_score_core_flag: 1
- proceed_to_full_fpga_backend_flag: 0
- reliable_margin_instability_flag: 0
- failures_limited_to_low_margin_cases: 0
- worst_gap_bin_for_recommended_mode: `gap_bin_very_weak`

full formal结论：第12步已完成第11.x beamspace ML score core的FPGA可行性边界收束。推荐进入第13步RTL score core prototype；该结论不覆盖完整FPGA backend、bit-true HDL仿真或下板验证。
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
