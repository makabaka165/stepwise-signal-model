# Thesis writing text

## Method introduction

本文在固定波束组合矩阵 W=greedy_combined_B7 以及 controlled pair2d beamspace ML 后端的条件下，提出一种基于物理俯仰分离参数的粗到细候选搜索加速方法。该方法不改变 ML 评分函数，而是在局部角度窗口内先进行粗粒度搜索，保留得分最高的 topK 候选，再围绕这些候选构造细粒度局部搜索窗口，从而降低需要评分的角度候选数量。

## Complexity reduction

在代表性场景实验中，full fine grid 的平均候选数为 131461，而推荐 coarse-to-fine 配置的平均候选数为 19161.9，复杂度降低比例为 6.86054096932。换言之，候选评分数量约减少 85.4%，同时 coarse-to-fine_success 保持为 1。

## Difference from AP

该方法不是交替投影 AP，也不是将多维搜索拆解为新的 AP 迭代过程。每一个候选仍由 controlled pair2d beamspace ML 的同一 DML 评分函数评价；粗到细流程仅改变候选集合的生成与筛选顺序。

## Relation to Step11.2 W selection

Step11.2 负责选择固定的波束组合矩阵 W，本文采用其推荐结果 greedy_combined_B7。Step11.3 不重新设计 W，而是在该固定 W 下优化后端 ML 搜索的候选数量。

## Experiment result description

Stage2 两阶段 sweep 共筛选 96 个配置，并对 5 个候选配置进行确认实验。最终推荐配置为 coarse_016_024_minsep__topK3__refine_safe_fullsep，topK=3，coarse grid=[0.16,0.24] deg，fine grid=[0.08,0.12] deg，topK_miss_rate=0，full_grid_match_rate=1。Stage3 进一步验证了前端粗角中心存在 +/-0.2 deg 偏差时的鲁棒性，frontend_prior_robustness_pass_flag=1。

## Limitation statement

上述结论基于当前代表性场景、当前 W 和当前 controlled pair2d 模型。该方法依赖前端粗中心和局部搜索窗口，不应被表述为全局全空域搜索或完整工程闭环。当粗中心偏差超过局部窗口时，需要扩大窗口或重新选择中心束。
