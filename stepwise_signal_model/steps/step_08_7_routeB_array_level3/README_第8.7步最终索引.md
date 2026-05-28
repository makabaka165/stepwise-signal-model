# 第 8.7 步最终索引

## 1. 最终定位

第 8.7 的最终定位不是单一 2D-MUSIC 算法，而是：

```text
层次三二维信息
+ 层次二成熟 fallback
+ 观测量驱动工程分流
```

当前阶段性结论是：

- 大俯仰差 -> `2D-MUSIC / pair-el local covfit`
- 同俯仰但 `el_assumed` 错误 -> `common-el refocus + layer2 rank1 fallback`
- 弱目标 / 近反相 -> `boundary_unreliable / low_confidence`

第 6B 最终指标：

- `observable dispatch success = 0.732`
- `oracle dispatch success = 0.798`
- `gap = -0.066`
- `false-high-confidence = 0`
- `boundary-missed = 0`

因此当前第 8.7 已可定位为“保守工程分流雏形”。

## 2. 必读文档

1. `第8.7步_层次三与观测量工程分流总结报告.md`
2. `第8.7步_6B_观测量分流去真值化与置信度校准记录.md`
3. `第8.7步_4_common-el重聚焦与层次二fallback验证记录.md`
4. `第8.7步_5_一般源模型分流边界验证记录.md`

## 3. 主线脚本

- `space_smooth_music_B_cylindrical_level3_minimal_validation.m`
- `space_smooth_music_B_cylindrical_level3_rank1_covfit_minimal.m`
- `space_smooth_music_B_cylindrical_level3_common_el_stability.m`
- `space_smooth_music_B_cylindrical_level3_common_el_refocus.m`
- `space_smooth_music_B_cylindrical_level3_general_model_dispatch_boundary.m`
- `space_smooth_music_B_cylindrical_level3_observable_dispatch_demo.m`
- `space_smooth_music_B_cylindrical_level3_observable_dispatch_calibrated.m`

## 4. 主线结果目录

- `results_step8_7_level3_minimal_validation/`
- `results_step8_7_level3_rank1_covfit_minimal/`
- `results_step8_7_level3_common_el_stability/`
- `results_step8_7_4_common_el_refocus/`
- `results_step8_7_5_general_model_dispatch_boundary/`
- `results_step8_7_6_observable_dispatch_demo/`
- `results_step8_7_6b_observable_dispatch_calibrated/`

## 5. 当前不建议继续的方向

- V2 constrained covariance fitting
- complex-gain q 优化
- 完整 4D global covfit
- fullscan 式继续堆搜索

## 6. 后续未来工作

优先级建议：

1. 弱目标 / SIC / 残差检测
2. 近反相 derivative-steering 边界模型
3. 更大 Monte Carlo 复核 6B 指标
4. 与真实 Route-B 流水线联动
5. 最后再考虑 V2 / general $R_s$
