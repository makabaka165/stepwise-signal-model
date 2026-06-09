# Step11.5 Stage2 Thesis Writing Text

本文在 Step11.3 固定 topK3 粗到细 beamspace ML 搜索基础上，进一步提出一种经策略标定的似然地形感知自适应搜索预算分配方法。该方法将粗网格似然地形特征拆分为搜索预算不确定度和置信度不确定度，使 H_norm 与条件数风险主要用于置信输出，而将边界风险和 score gap 用于 topK/window 调整。实验表明，在保持 full-grid match、topK miss 和 boundary hit 不恶化的前提下，该方法较固定 topK3 进一步降低平均候选评分数量，可作为 controlled pair2d beamspace ML 的低复杂度增强策略。
