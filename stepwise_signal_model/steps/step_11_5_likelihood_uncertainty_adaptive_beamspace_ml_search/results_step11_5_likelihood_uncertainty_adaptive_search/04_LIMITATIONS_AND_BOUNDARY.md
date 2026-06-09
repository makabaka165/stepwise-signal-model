# Step11.5 Limitations And Boundary

1. 本方法不是新的 ML score。Step11.5 只改变 coarse-to-fine 搜索预算分配，不改变 `J(Theta) = trace(P_G Z Z')`。
2. 本方法不是 AP。它不构造 AP 空间谱，也不采用 AP 判决。
3. 本方法不是 element-domain ML。观测与搜索均保持 Step11.3 beamspace 形式。
4. 本方法依赖前端粗中心在局部窗口内。若前端中心偏差超出局部窗口保护范围，应扩大窗口或回退。
5. 本方法的自适应阈值只在当前 representative scenarios 验证。
6. 对超出 bias range 的样本，必须扩大窗口或退回 fixed/full fine search。
7. low confidence / boundary flag 不是算法失败，而是安全输出策略。
