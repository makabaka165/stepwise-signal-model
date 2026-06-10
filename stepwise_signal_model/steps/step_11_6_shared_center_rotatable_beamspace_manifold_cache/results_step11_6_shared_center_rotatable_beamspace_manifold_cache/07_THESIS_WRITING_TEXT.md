# Thesis Writing Text

Case 1, overall pass = 1 and runtime search pass = 1:
本文进一步利用全息凝视圆柱阵 shared-center 局部工作子阵的旋转等价性，提出一种 canonical beamspace manifold cache 方法。该方法将不同扇区中心下的局部导向矢量统一映射到 canonical Delta-az 坐标中，预先存储 G = W'A_cyl 的波束域流形模板，并在在线 controlled pair2d beamspace ML 搜索中进行 exact-grid lookup。实验表明，该缓存方法与 direct steering precompute 在流形、score、估计结果和 policy 分支上保持数值一致，同时降低 manifold 构造和总搜索运行时间，可作为 Step11.5 C05 自适应搜索的工程加速模块。

Case 2, overall pass = 1 and runtime search pass = 0:
本文进一步验证了 shared-center 圆柱阵局部流形的 canonical cache 复用方法。实验表明，该方法在多个中心方位下与 direct precompute 保持流形和搜索结果一致，并显著降低 manifold 构造成本；但在 MATLAB 原型中，总搜索时间仍主要受后续 DML score 计算和函数调度开销限制。因此本文将该方法作为 FPGA/SoC 友好的 manifold 构造加速模块，而不单独声称 MATLAB 总 runtime 显著下降。

Case 3, overall pass = 0:
本文尝试利用 shared-center 旋转等价性构造 canonical beamspace manifold cache，但在当前 W、局部子阵顺序或中心映射下未能完全保持 direct precompute 的数值一致性。因此本文暂不将该 cache 作为默认实现，而将其作为圆柱阵工程部署中的未来优化方向保留。
