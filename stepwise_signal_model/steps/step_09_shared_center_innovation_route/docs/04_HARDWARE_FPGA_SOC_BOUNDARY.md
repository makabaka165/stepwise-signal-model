# FPGA / SoC 边界

## 不承诺完整纯 FPGA 定点实现

本路线不把 Step 8.9 写成完整纯 FPGA 定点闭合结果。Step 8.9 的作用是暴露量化敏感性、数据通路边界和 FPGA/SoC 分工，而不是证明完整 Step 8.7 算法已经能直接定点流水化。

## FPGA 适合承担的部分

- LFM 产生。
- 脉冲压缩。
- MTD/FFT。
- CFAR。
- coarse beamforming 或三波束比幅。
- 65 列抽取与地址映射。
- steering LUT。
- refocus power / projection score 加速。
- MUSIC/2D projection 的矩阵向量乘加速。

## CPU / ARM / DSP / 浮点 IP 适合承担的部分

- EVD/SVD。
- rank1 fallback 是否启用的决策。
- pair-local / local 2D refinement 决策。
- confidence / boundary 状态机。
- route selection 和日志整理。

## Step 8.9 的证据定位

Step 8.9、8.9B、8.9C 说明定点影响不是简单位宽增加即可完全闭合。最终论文中应写成硬件部署边界和混合精度建议，而不是完整 FPGA 定点成功承诺。
