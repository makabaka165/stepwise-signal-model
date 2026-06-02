# 负结果与消融定位

## dual-center

定位为未来多粗峰前端或 two separated coarse peaks 的工程扩展。不作为当前默认主线，不出现在最终主算法流程图中。

## complex-gain / V2 / 一般源完整协方差拟合

定位为未来一般相干源扩展。不作为当前论文主线，避免把当前方法写成复杂协方差拟合路线。

## weak target

定位为边界保护。当前只输出 low-confidence 或 boundary 状态，不强行求解弱目标。

## near anti-phase

定位为边界保护。当前只输出 boundary_unreliable 或 low-confidence，不作为高置信成功样本。

## Step 8.10 unified model selection

定位为负结果。默认阈值和阈值 sweep 都没有通过安全性要求，不能替代剪枝 cascade。

## Step 8.9 fixed-point

定位为硬件边界分析。定点影响未闭合，不作为纯 FPGA 定点实现成功结果。

## Step09 common-el gate alignment negative result

Gate 2 (`rank1_refocus_consensus_gate`) is a negative result for backend adoption. It improves close-coherent recovery (`0.87333`) but violates the safety pass rule with `overall_false_high_rate = 0.034722` and `single_target_false_split_rate = 0.83333`. Therefore Step09 backend tuning is frozen; do not add threshold tuning, dual-center, V2/complex-gain, Step8.10 unified model selection, or learning to force this route through.
