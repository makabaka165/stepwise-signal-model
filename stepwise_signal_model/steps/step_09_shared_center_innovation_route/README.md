# Step 09: shared-center MUSIC 增强测角最终路线

本目录收束最终论文/答辩主线：面向全息凝视圆柱阵局部未分辨目标簇的 shared-center MUSIC 增强测角方法。方法不追求全场普适多目标分辨，而是在前端检测获得 `single_peak_in_scope` / unresolved local cluster 后，利用 shared-center 65 列局部圆柱阵流形、局部 MUSIC 判别、相干秩亏 fallback 和低置信拒判实现保守增强测角。

## 方法名称

面向全息凝视圆柱阵局部未分辨目标簇的 shared-center MUSIC 增强测角方法。

## 适用场景

- 前端链路已经完成 LFM、脉压、MTD/FFT、CFAR 和粗角估计。
- 前端只把 `rangeIdx`、`dopplerIdx`、`coarseAz`、`coarseEl`、`frontend_state` 交给增强测角。
- 默认只处理 `single_peak_in_scope` 或可解释为局部未分辨簇的单粗峰单元。
- two separated coarse peaks、weak secondary candidate、near anti-phase boundary 不在主线强行高置信求解。

## 最终算法链路

```text
frontend detection / coarse angle
-> shared-center 65-column work subarray
-> Y_work construction, default no_derotation
-> local cylindrical MUSIC test
-> common-el rank1 refocus fallback when coherent rank loss is observed
-> local 2-D pair refinement when elevation mismatch is indicated
-> low_confidence / boundary_unreliable rejection
```

## 运行入口

在 MATLAB 中进入本目录或工程根目录后运行：

```matlab
run('steps/step_09_shared_center_innovation_route/run_final_shared_center_demo.m')
run('steps/step_09_shared_center_innovation_route/run_final_shared_center_validation.m')
```

核心算法入口为：

```matlab
out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
```

## Supplementary validation

`run_final_shared_center_validation.m` 是 interface-level smoke test，只验证文件、接口、65 列 shared-center 选阵、`Y_work` 形状和前端拒判是否跑通。正式统计验证由下面的补充实验给出：

```matlab
run('steps/step_09_shared_center_innovation_route/run_step09_formal_monte_carlo.m')
run('steps/step_09_shared_center_innovation_route/run_step09_vs_step87_consistency_check.m')
run('steps/step_09_shared_center_innovation_route/run_step09_ablation_study.m')
run('steps/step_09_shared_center_innovation_route/run_step09_all_supplementary_experiments.m')
```

- formal MC 直接调用 `shared_center_enhanced_doa()`，覆盖 SNR、角间隔、相干度、幅度比、俯仰差、粗角误差和边界场景。
- Step09-vs-Step87 consistency 用于检查新目录是否只是对 8.7 / 8.8 主线的结构化整理；若旧 8.7 不是可调用函数，则明确记录 blocker，并以 Step 09 formal MC 作为最终统计依据。
- ablation study 比较 `music_only`、`music_plus_rank1`、`music_plus_2d`、`full_step09` 和 `full_without_rejector`，用于说明 rank1 fallback、local 2D refinement、confidence/boundary rejector 的必要性。
- optional learning 不属于默认主线，只作为 future work 的 route/confidence calibration 候选。

默认快速模式为 `Metkl = 30`、`SNR = [8, 16]`。可通过环境变量 `STEP09_MC_MODE=quick|formal|stress` 切换 formal MC / 总入口的运行规模。

## Backend mode

```matlab
cfg.backend_mode = 'step09_light';      % lightweight reimplementation, diagnostic only
cfg.backend_mode = 'step87_reference';  % verified Step 8.7 cascade backend, if bridge passes
```

Bridge validation:

```matlab
run('steps/step_09_shared_center_innovation_route/run_step09_step87_backend_bridge_validation.m')
```

Step09 light backend 已经暴露 blocker；Step87 backend bridge 用于确认最终实现是否应采用 8.7 verified cascade。它不改变 Step 09 的论文创新点，只改变算法后端实现。

当前 bridge 结果为 callable 但未通过：large-el 场景已由 reference backend 恢复，close-coherent 场景仍未获得增益，因此后续 formal MC 暂不建议直接改用 `backend_mode='step87_reference'`。

## 不解决的问题

- 不解决全场任意多目标分辨。
- 不把 two separated coarse peaks 纳入当前默认主线。
- 不承诺 weak target 或 near anti-phase 场景的高置信求解。
- 不采用 Step 8.10 的 H1/H2/H3 统一残差评分替代 cascade。
- 不承诺完整 Step 8.7 已经适合纯 FPGA 定点流水实现。

## 与 8.7 / 8.8 / 8.9 / 8.10 的关系

- Step 8.7 提供剪枝 cascade、rank1 fallback、2D refinement 和拒判证据，是本目录主线的算法来源。
- Step 8.8 提供前端到 shared-center 的接口闭环和 in-scope/out-of-scope 状态机。
- Step 8.8B 验证 `no_derotation`、`derotation_minus`、`derotation_plus` 输出一致，因此默认不启用 Doppler de-rotation。
- Step 8.9 降级为硬件量化敏感性和 FPGA/SoC 分工边界证据，不作为纯 FPGA 定点成功结果。
- Step 8.10 降级为 negative result，不进入最终 route selection。

## Backend Decision Status

Run the focused gate-alignment decision experiment with:

```matlab
run('steps/step_09_shared_center_innovation_route/run_step09_common_el_gate_alignment.m')
```

Current decision: Gate 2 (`rank1_refocus_consensus_gate`) recovered close-coherent success (`0.87333`) but failed the safety rule because `overall_false_high_rate = 0.034722` and `single_target_false_split_rate = 0.83333`.

Final recommendation: freeze Step09 backend tuning and use the original Step8.7 verified lazy cascade as the final backend evidence. Step09 remains the interface/documentation layer and `step87_reference` is not promoted to the default backend.
