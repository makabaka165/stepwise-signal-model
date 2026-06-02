# 实验证据整理

## Step 8.7 lazy cascade

来自 `step_08_7_routeB_array_level3/results_step8_7_7b_lazy_runtime_wallclock_cleanup_check`：

| 指标 | 数值 |
|---|---:|
| full_success_rate_all | 0.764705882352941 |
| lazy_success_rate_all | 0.764705882352941 |
| lazy_false_high_confidence_rate_all | 0 |
| lazy_boundary_missed_rate_all | 0 |
| mean_runtime_reduction_all | 0.376998770503756 |
| early_stop_rate_all | 0.790849673202614 |

结论：剪枝 cascade 没有损失 full route success，false-high 和 boundary-missed 保持为 0，平均运行时间下降约 37.7%。

## Step 8.8 frontend closure

来自 `step_08_8_frontend_to_shared_center_closure/results_step8_8_frontend_shared_center_closure_state_cleanup_check`：

| 指标 | 数值 |
|---|---:|
| cfar_detection_rate_overall | 1 |
| single_coarse_peak_rate_overall | 0.916666666666667 |
| in_scope_shared_center_rate | 0.916666666666667 |
| two_coarse_peak_rate_overall | 0.0833333333333333 |
| false_high_rate_in_scope | 0 |
| boundary_missed_rate_in_scope | 0 |
| center_selection_success_rate_overall | 0.916666666666667 |

结论：前端状态机可以把单粗峰/未分辨簇安全送入 shared-center 主线，并把两粗峰场景挡在主线外。

## Step 8.8B de-rotation 无收益

`success_no_derotation = success_derotation_minus = success_derotation_plus = 0.486363636363636`，route/confidence agreement 均为 1，最大方位和俯仰差为 0。因此主线默认不启用 Doppler de-rotation。

## Step 8.9 定点量化未闭合

来自 `step_08_9_shared_center_fixed_point_validation`：

- `fixed_point_pass_flag = 0`
- `recommended_fixed_point_format = not_recommended`
- `fixed_point_blocker_if_any = quantization_not_closed`
- combined int16/int18/int24 route agreement 仍低于可直接承诺完整定点闭合的标准。

结论：Step 8.9 作为硬件边界证据，而不是纯 FPGA 定点成功结果。

## Step 8.10 unified model selection 失败

来自 `step_08_10_unified_model_selection_validation`：

| 指标 | 数值 |
|---|---:|
| unified_success_overall | 0.0850290697674419 |
| cascade_success_overall | 0.494186046511628 |
| success_gap_unified_vs_cascade | -0.409156976744186 |
| unified_false_high | 0.222383720930233 |
| cascade_false_high | 0 |
| threshold_default_pass_flag | 0 |
| threshold_sweep_best_pass_flag | 0 |

结论：H1/H2/H3 统一残差评分不能替代 cascade，保留为 negative result。

## 为什么保留剪枝版 shared-center cascade

剪枝 cascade 是唯一同时满足以下条件的路线：

- 前端接口闭环清楚。
- 65 列 shared-center 流形固定。
- MUSIC / rank1 / 2D 分支各自有明确触发条件。
- false-high 和 boundary-missed 受控。
- 旧路线中的 unified selection、fixed-point hardening、dual-center、complex-gain 都不再作为主线。

## Step09 common-el gate alignment decision

Source: `steps/step_09_shared_center_innovation_route/results_step09_common_el_gate_alignment/`.

The focused Gate 2 experiment did not pass the final backend adoption rule. `rank1_refocus_consensus_gate` recovered close-coherent success to `0.87333`, but safety failed: `overall_false_high_rate = 0.034722` and `single_target_false_split_rate = 0.83333`. The final recommendation is to freeze Step09 backend tuning and keep the original Step8.7 verified lazy cascade as the final backend evidence.
