# 第12步 波束级ML FPGA可行性边界验证收束报告

## 1. 本步定位

第12步用于第11.x波束级ML后端进入FPGA score core之前的硬件可行性边界验证。它围绕第11.x真实score路径中的W、G_cache、Z、Rz、candidate score、topK和policy diagnostics建立有限字长验证。

第12步不复用Step8.9结果，不继承Step8.9 pass/fail标准。正式判据只由ML score ranking consistency和topK preservation决定。

本报告是`formal_tps30`完整1200 observation聚合后的收束报告。本报告不是完整FPGA RTL、不是bit-true HDL仿真、不是下板验证，也不是完整Step11.7 FPGA backend通过声明。

## 2. 验证对象

- W
- G_cache
- Z = W'Y
- Rz = Z*Z'
- candidate score
- topK
- C05 policy diagnostics

policy、confidence、fallback和boundary仅作为工程风险诊断指标，不作为primary fixed-point pass/fail依据。

## 3. formal验证设置

| 字段 | 值 |
| --- | --- |
| run tag | formal_tps30 |
| formal_plan_total_obs | 1200 |
| formal_plan_completed_obs | 1200 |
| formal_plan_complete_flag | 1 |
| formal_min_obs_satisfied_flag | 1 |
| center_az_list | 0, 4, 8, 15 |
| scenario数量 | 10 |
| trials_per_scenario | 30 |
| mode_set | formal_core |
| topK_default | 10 |
| reliable_margin_threshold | 0.001 |

本轮为full formal validation。所有120个chunk均已完成并聚合。

## 4. 位宽模式与pass/fail标准

formal_core模式包括：

- double_baseline
- float32_all
- combined_int14
- combined_int16
- combined_int18
- combined_int24
- mixed_Z16_G24_Rz24
- W_int18_G24_Z16

`float32_all`只作为诊断参考，不作为fixed-point pass candidate。

formal ranking pass要求：

- reliable_top1_preservation_rate >= 0.999
- reliable_score_gap_sign_flip_rate == 0
- argmax_changed_rate_on_reliable_margin <= 0.001

formal topK pass要求：

- reliable_topK_set_preservation_rate >= 0.995
- overall_topK_set_preservation_rate >= 0.980
- reliable_topK_miss_rate <= 0.005

formal fixed-point pass要求fixed candidate同时满足ranking_pass和topK_pass，且quick_mode_flag=0、formal_trial_count >= STEP12_MIN_FORMAL_OBS。full FPGA backend不在本步声明。

## 5. 主要结果

| quant_mode | ranking_pass | topK_pass | fixed_point_pass | reliable_top1 | reliable_topK_set | overall_topK_set | reliable_argmax_changed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| combined_int14 | 0 | 0 | 0 | 0.820846905537459 | 0.980456026058632 | 0.964166666666667 | 0.179153094462541 |
| combined_int16 | 0 | 1 | 0 | 0.965798045602606 | 0.998371335504886 | 0.991666666666667 | 0.0342019543973941 |
| combined_int18 | 0 | 1 | 0 | 0.995114006514658 | 1 | 0.999166666666667 | 0.00488599348534202 |
| combined_int24 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| mixed_Z16_G24_Rz24 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| W_int18_G24_Z16 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |

关键keypoints：

- fixed_point_pass_flag = 1
- blocker_if_any = none
- combined_int16_formal_pass_flag = 0
- combined_int16_blocker_if_any = reliable_argmax_changed
- minimum_passing_mode = combined_int24
- engineering_recommended_fixed_point_format = mixed_Z16_G24_Rz24
- recommended_fixed_point_format = mixed_Z16_G24_Rz24
- proceed_to_rtl_score_core_flag = 1
- proceed_to_full_fpga_backend_flag = 0

结论：combined_int16未闭合；combined_int24是最低通过统一位宽；mixed_Z16_G24_Rz24是工程推荐格式，后续RTL score core优先采用mixed precision数据路径。

## 6. score gap分箱分析

推荐格式`mixed_Z16_G24_Rz24`在所有gap bin中均保持top1和topK稳定：

| gap_bin | num_trials | top1_preservation_rate | topK_set_preservation_rate | argmax_changed_rate | score_gap_sign_flip_rate |
| --- | --- | --- | --- | --- | --- |
| gap_bin_very_weak | 2 | 1 | 1 | 0 | 0 |
| gap_bin_weak | 83 | 1 | 1 | 0 | 0 |
| gap_bin_transition | 501 | 1 | 1 | 0 | 0 |
| gap_bin_reliable | 614 | 1 | 1 | 0 | 0 |

全局score gap keypoints：

- reliable_margin_instability_flag = 0
- failures_limited_to_low_margin_cases = 0
- worst_gap_bin_for_recommended_mode = gap_bin_very_weak

combined_int16的主要失败来自argmax稳定性，而不是score gap sign flip：

- gap_bin_reliable: argmax_changed_rate = 0.0342019543973941
- gap_bin_transition: argmax_changed_rate = 0.165668662674651
- gap_bin_weak: argmax_changed_rate = 0.228915662650602
- gap_bin_very_weak: argmax_changed_rate = 1
- combined_int16_score_gap_flip_reliable = 0

## 7. cache/storage/bandwidth边界

cache_estimate_scope = both_working_set_and_full_cache

| scope | MB | BRAM36 | URAM288 |
| --- | --- | --- | --- |
| working set | 0.113164901733 | 31 | 9 |
| full canonical cache if available | 5.2387046814 | 1193 | 150 |

working set不是完整cache驻留资源；full G_cache是后续FPGA实现的主要存储压力。实际RTL阶段可以选择URAM、BRAM分块、DDR staged cache或片上局部cache。

score core访问估算摘要：

| stage | candidates | score_lanes | cycles_total_est | read_bits_per_candidate | complex_mac_per_candidate |
| --- | --- | --- | --- | --- | --- |
| coarse_stage | 7353 | 1 | 32791 | 3024 | 140 |
| coarse_stage | 7353 | 4 | 8199 | 3024 | 140 |
| coarse_stage | 7353 | 8 | 4100 | 3024 | 140 |
| worst_case | 11030 | 1 | 49188 | 3024 | 140 |
| worst_case | 11030 | 4 | 12298 | 3024 | 140 |
| worst_case | 11030 | 8 | 6149 | 3024 | 140 |

## 8. golden vectors

compact golden vectors已在full formal aggregate后重新导出。

- 路径：`results_step12_beamspace_ml_fpga_boundary/formal_tps30/aggregate/golden_vectors/`
- manifest：`results_step12_beamspace_ml_fpga_boundary/formal_tps30/aggregate/step12_ml_fpga_boundary_golden_vector_manifest.md`
- recommended fixed-point format：`mixed_Z16_G24_Rz24`
- case count：5

case roles：

- best_reliable_case
- worst_score_gap_rel_error_case
- smallest_reliable_margin_case
- topK_boundary_case
- combined_int16_worst_case

golden vectors仅用于RTL score core testbench，不代表full FPGA backend validation。

## 9. 最终工程判断

> 第12步已完成第11.x beamspace ML score core的FPGA可行性边界收束。推荐进入第13步RTL score core prototype。该结论不覆盖完整FPGA backend。

full formal validation通过。第11.x beamspace ML score core在推荐fixed-point格式`mixed_Z16_G24_Rz24`下满足score ranking consistency和topK preservation。`proceed_to_rtl_score_core_flag = 1`。

同时必须保留以下边界：

- proceed_to_full_fpga_backend_flag = 0
- C05 policy、fallback、confidence、boundary和完整backend wrapper仍保留在SoC/software或未来工作中
- 本步没有完成完整FPGA RTL、bit-true HDL仿真或下板验证

## 10. 下一步

- 第13步：RTL score core prototype
- 使用推荐fixed-point格式`mixed_Z16_G24_Rz24`
- 使用本步导出的compact golden vectors作为score core testbench输入
- 先实现和验证score core，不硬件化完整backend
- 在RTL阶段继续评估full G_cache的URAM/BRAM/DDR staged cache实现边界
