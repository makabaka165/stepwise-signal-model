# Step11.5 Thesis Writing Text

## 方法介绍

本文提出基于似然地形不确定度的自适应 TopK-窗口波束级最大似然搜索方法。该方法以 Step11.3 的 degree-based coarse-to-fine beamspace ML 为基线，在不改变 ML 评分函数和波束组合矩阵的前提下，根据粗搜索阶段的候选分数地形动态分配细搜索预算。

## 理论建模

阵元域观测写为 `Y = A_cyl(Theta)S + N`，波束域观测为 `Z = W'Y`，波束域流形为 `G(Theta) = W'A_cyl(Theta)`。对每个 controlled pair2d 候选状态，仍采用 `P_G = G(G'G+regI)^(-1)G'` 与 `J = trace(P_GZZ')` 作为确定性 ML 评分。

## 自适应搜索策略

粗网格先保留 top 7 候选，通过归一化分数 softmax 权重计算似然熵，同时结合 `gap_13`、`gap_17`、边界距离和 `cond(G'G+regI)` 形成综合不确定度 `U`。根据 `U` 和风险项，样本被确定性地分配为 EASY、NORMAL、HARD 或 UNSAFE，并分别采用 topK=1/3/5/7 与 0.75/1.00/1.50/2.00 的局部窗口尺度。

## 复杂度分析

在代表性 zero-bias 场景中，full fine 平均候选数为 131461，固定 topK3 平均候选数为 19126.26，自适应方案平均候选数为 38749.86。固定 topK3 降低比例为 6.87332494696，自适应降低比例为 3.39255419245。

## 实验结果描述

自适应方法 success=1、RMSE=0.0765589261214、full-grid match rate=1、topK miss rate=0、boundary hit rate=0，pass flag=0。

## 与 Step11.3 fixed topK3 的区别

Step11.3 使用固定 topK=3 和固定局部 refine window。Step11.5 不改变 Step11.3 的后端评分和 degree-based 候选定义，而是在粗搜索后增加可观测的似然地形不确定度判别，并据此自适应选择 topK 与窗口尺度。

## 创新点表述

本文进一步尝试了基于似然地形不确定度的自适应搜索预算分配策略。实验表明，该策略在当前代表性场景中保持了与固定 topK3 方案相近的安全性，但复杂度收益未超过固定 topK3 基线，因此最终默认工程配置仍采用 Step11.3 固定 topK3 粗到细 beamspace ML 搜索，Step11.5 作为自适应搜索策略的边界验证与未来扩展方向保留。
