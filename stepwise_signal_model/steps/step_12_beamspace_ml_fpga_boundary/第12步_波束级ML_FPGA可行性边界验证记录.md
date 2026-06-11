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
- blocker: `formal_trial_count_below_minimum`

## Formal / Chunk 状态

- run_tag: `formal_tps30`
- quick_mode_flag: 0
- chunked_run_flag: 1
- formal_trial_count: 100
- min_formal_obs: 300
- formal_plan_total_obs: 1200
- formal_plan_completed_obs: 100
- formal_plan_complete_flag: 0
- formal_min_obs_satisfied_flag: 0
- chunks_detected: 10
- chunks_completed: 10

formal_tps30 still incomplete。本次 aggregate 尚未达到 STEP12_MIN_FORMAL_OBS，因此 formal conclusion not yet available，不能进入 RTL score core prototype。

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
| double_baseline | 0 | 0 | 100 | 61 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| float32_all | 0 | 0 | 100 | 61 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 9.35095e-07 | 0.00114912 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 16 |
| combined_int16 | 1 | 1 | 100 | 61 | 0.93 | 0.98 | 0.002 | 0.934426 | 0.983607 | 0.00163934 | 0.0655738 | 0 | 1 | 1 | 4.38601e-05 | 0.0863009 | 1 | 0.93 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 16 |
| combined_int18 | 1 | 1 | 100 | 61 | 0.99 | 1 | 0 | 0.983607 | 1 | 0 | 0.0163934 | 0 | 1 | 1 | 1.08498e-05 | 0.0149798 | 1 | 0.99 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 18 |
| combined_int24 | 1 | 1 | 100 | 61 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 1.52e-07 | 0.000201085 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |
| mixed_Z16_G24_Rz24 | 1 | 1 | 100 | 61 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 5.13777e-06 | 0.000662525 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |
| combined_int14 | 1 | 1 | 100 | 61 | 0.72 | 0.98 | 0.002 | 0.786885 | 0.983607 | 0.00163934 | 0.213115 | 0 | 1 | 1 | 0.000158012 | 0.144116 | 1 | 0.72 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 16 |
| W_int18_G24_Z16 | 1 | 1 | 100 | 61 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 5.47666e-06 | 0.00066245 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 24 |

## Mode Selection

| quant_mode | is_fixed_candidate | is_recommendation_candidate | component_bits | formal_trial_count | ranking_pass_flag | topK_pass_flag | fixed_point_pass_flag | reliable_top1_preservation_rate | reliable_topK_set_preservation_rate | overall_topK_set_preservation_rate | reliable_topK_miss_rate | argmax_changed_rate_on_reliable_margin | reliable_score_gap_sign_flip_rate | max_candidate_score_rel_l2_error | max_score_gap_rel_error | max_clip_rate | max_overflow_rate | estimated_total_MB | estimated_BRAM36 | estimated_URAM288 | engineering_rank | selection_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | 0 | 0 | 16 | 100 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | not_fixed_candidate |
| float32_all | 0 | 0 | 16 | 100 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 9.35095e-07 | 0.00114912 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | not_fixed_candidate |
| combined_int16 | 1 | 1 | 16 | 100 | 0 | 0 | 0 | 0.934426 | 0.983607 | 0.98 | 0.00163934 | 0.0655738 | 0 | 4.38601e-05 | 0.0863009 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | formal_trial_count_below_minimum |
| combined_int18 | 1 | 1 | 18 | 100 | 0 | 1 | 0 | 0.983607 | 1 | 1 | 0 | 0.0163934 | 0 | 1.08498e-05 | 0.0149798 | 0 | 0 | 0.0848737 | 20 | 3 | NaN | formal_trial_count_below_minimum |
| combined_int24 | 1 | 1 | 24 | 100 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 1.52e-07 | 0.000201085 | 0 | 0 | 0.113165 | 26 | 4 | NaN | formal_trial_count_below_minimum |
| mixed_Z16_G24_Rz24 | 1 | 1 | 24 | 100 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 5.13777e-06 | 0.000662525 | 0 | 0 | 0.113165 | 26 | 4 | NaN | formal_trial_count_below_minimum |
| combined_int14 | 1 | 1 | 16 | 100 | 0 | 0 | 0 | 0.786885 | 0.983607 | 0.98 | 0.00163934 | 0.213115 | 0 | 0.000158012 | 0.144116 | 0 | 0 | 0.0754433 | 18 | 3 | NaN | formal_trial_count_below_minimum |
| W_int18_G24_Z16 | 1 | 1 | 24 | 100 | 1 | 1 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 5.47666e-06 | 0.00066245 | 0 | 0 | 0.113165 | 26 | 4 | NaN | formal_trial_count_below_minimum |

## combined_int16 状态

- combined_int16_formal_pass_flag: 0
- combined_int16_blocker_if_any: `formal_trial_count_below_minimum`
- combined_int16_reliable_top1_preservation: 0.934426229508
- combined_int16_reliable_topK_preservation: 0.983606557377

## Score Gap Stress Bins

| quant_mode | gap_bin | num_trials | top1_preservation_rate | topK_set_preservation_rate | topK_miss_rate | argmax_changed_rate | score_gap_sign_flip_rate | mean_score_gap_rel_error | p95_score_gap_rel_error | max_score_gap_rel_error | same_policy_rate | same_confidence_rate | same_boundary_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| double_baseline | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| double_baseline | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| double_baseline | gap_bin_transition | 39 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| double_baseline | gap_bin_reliable | 61 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| float32_all | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| float32_all | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| float32_all | gap_bin_transition | 39 | 1 | 1 | 0 | 0 | 0 | 0.000228206 | 0.00104071 | 0.00114912 | 1 | 1 | 1 |
| float32_all | gap_bin_reliable | 61 | 1 | 1 | 0 | 0 | 0 | 4.38284e-05 | 0.000105818 | 0.000128441 | 1 | 1 | 1 |
| combined_int16 | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int16 | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int16 | gap_bin_transition | 39 | 0.923077 | 0.974359 | 0.0025641 | 0.0769231 | 0 | 0.0133852 | 0.0477345 | 0.0863009 | 1 | 1 | 1 |
| combined_int16 | gap_bin_reliable | 61 | 0.934426 | 0.983607 | 0.00163934 | 0.0655738 | 0 | 0.0024013 | 0.00495433 | 0.00622723 | 1 | 1 | 1 |
| combined_int18 | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int18 | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int18 | gap_bin_transition | 39 | 1 | 1 | 0 | 0 | 0 | 0.00397974 | 0.0141658 | 0.0149798 | 1 | 1 | 1 |
| combined_int18 | gap_bin_reliable | 61 | 0.983607 | 1 | 0 | 0.0163934 | 0 | 0.000612914 | 0.00148355 | 0.00156651 | 1 | 1 | 1 |
| combined_int24 | gap_bin_very_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int24 | gap_bin_weak | 0 | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN | NaN |
| combined_int24 | gap_bin_transition | 39 | 1 | 1 | 0 | 0 | 0 | 4.8352e-05 | 0.000166667 | 0.000201085 | 1 | 1 | 1 |
| combined_int24 | gap_bin_reliable | 61 | 1 | 1 | 0 | 0 | 0 | 9.57485e-06 | 2.23125e-05 | 2.50681e-05 | 1 | 1 | 1 |

_Only first 20 rows shown; see CSV for full table._

- reliable_margin_instability_flag: 1
- failures_limited_to_low_margin_cases: 0
- worst_gap_bin_for_recommended_mode: `gap_bin_transition`

## Cache Storage 估算

- cache_estimate_scope: `both_working_set_and_full_cache`
- working-set cache estimate: 0.0754432678223 MB, BRAM36=23, URAM288=7
- full-cache estimate if available: 5.2387046814 MB, BRAM36=1193, URAM288=150

| object_name | num_complex | component_bits | bits_per_complex | total_bits | total_MB | BRAM36_equivalent | URAM288_equivalent | read_complex_per_candidate | read_bits_per_candidate | comment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W | 84 | 16 | 32 | 2688 | 0.000320435 | 1 | 1 | 7 | 224 | beamforming projection matrix W |
| G_cache | 4816 | 16 | 32 | 154112 | 0.0183716 | 5 | 1 | 14 | 448 | Step11.6 canonical beamspace G cache |
| Z_buffer | 112 | 16 | 32 | 3584 | 0.000427246 | 1 | 1 | 7 | 224 | beamspace snapshot buffer after Step11 whitening |
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

## Profiling 摘要

| stage_name | total_elapsed_sec | mean_elapsed_sec | p95_elapsed_sec | max_elapsed_sec | num_calls |
| --- | --- | --- | --- | --- | --- |
| score_recompute | 277.099 | 0.346374 | 0.504845 | 0.703461 | 800 |
| ranking_compare | 138.565 | 0.173206 | 0.254756 | 0.350128 | 800 |
| build_candidate_score_pack | 87.769 | 0.87769 | 1.19662 | 1.41195 | 100 |
| build_step11_input | 1.47107 | 0.0147107 | 0.0412187 | 0.0551428 | 100 |
| run_step11_backend | 0 | 0 | 0 | 0 | 100 |

## Worst Cases 总结

| case_type | trial_index | scenario_name | quant_mode | metric_name | metric_value | topK_miss_count | argmax_changed_flag | score_gap_norm_baseline | score_gap_rel_error | max_clip_rate | note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| max_topK_miss_count | 1086 | medium_beta_coherent | combined_int16 | topK_miss_count | 1 | 1 | 1 | 0.000453774 | 0.00927453 | 0 | see trial CSV for full fields |
| argmax_changed_largest_baseline_gap | 366 | hard_phase | combined_int14 | score_gap_norm_baseline | 0.00255128 | 0 | 1 | 0.00255128 | 0.00743589 | 0 | see trial CSV for full fields |
| max_score_gap_rel_error | 726 | low_snr_hard | combined_int14 | score_gap_rel_error | 0.144116 | 0 | 0 | 0.000142666 | 0.144116 | 0 | see trial CSV for full fields |
| policy_changed_sample | NaN |  |  | same_policy_flag | NaN | NaN | 0 | NaN | NaN | NaN | no matching sample |
| max_clip_or_overflow_sample | 1 | easy_noncoherent | double_baseline | max_clip_rate | 0 | 0 | 0 | 0.00110155 | 0 | 0 | see trial CSV for full fields |

## Recommendation

| recommendation | rationale | recommended_fixed_point_format | proceed_to_rtl_score_core_flag | proceed_to_rtl_score_core_smoke_flag | proceed_to_full_fpga_backend_flag |
| --- | --- | --- | --- | --- | --- |
| do_not_proceed_to_rtl_score_core_until_score_ranking_or_topK_closes | formal_trial_count_below_minimum | not_recommended | 0 | 0 | 0 |

## Golden Vectors

- exported: 0
- reason: 需要 formal fixed-point pass 且 STEP12_EXPORT_GOLDEN_VECTORS=1。

## 最终判断

- minimum_passing_mode: `none`
- engineering_recommended_fixed_point_format: `not_recommended`
- fixed_point_pass_flag: 0
- blocker_if_any: `formal_trial_count_below_minimum`
- proceed_to_rtl_score_core_flag: 0
- proceed_to_full_fpga_backend_flag: 0

## 下一步建议

formal_tps30 仍未完成最低正式样本量。下一步继续从 chunk 11 开始运行，直到 formal_plan_completed_obs >= 300 后再重新 aggregate 判定最低成本有限字长方案。
