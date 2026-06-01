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
