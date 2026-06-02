# 05 Thesis Engineering Innovation

## 创新点标题

面向 shared-center 局部增强测角链路的 FPGA/SoC 协同实现框架。

## 创新点描述

针对 shared-center 65-column 局部增强测角链路，本文提出一种 FPGA/SoC 协同实现框架。该框架把前端高吞吐规则计算、局部工作子阵抽取、Y_work 构造和可选投影分数计算映射到 FPGA 侧，把 Step8.7 lazy cascade 的复杂 route decision、EVD/SVD、rank1 / pair-local 判断以及 confidence/boundary 输出保留在 SoC/CPU 或浮点 IP 侧，从而在不牺牲算法解释性和数值稳定性的前提下，提高工程实现的可部署性。

## 技术路线

Raw ADC / array data 经过 pulse compression、MTD / Doppler FFT、CFAR 和 coarse beamforming 得到 frontend_out；FPGA 根据 center_col 完成 shared-center 65-column extraction 和 Y_work packing；可选 projection score acceleration 为 MUSIC / projection score 提供并行 dot-product 加速；SoC/CPU 运行 Step8.7 lazy cascade scheduler、EVD/SVD、rank1 / pair-local decision、route selection 和 confidence/boundary 状态机；最终输出 az/el estimate、confidence、boundary flag 和 route log。

## 工程价值

该框架将已验证的算法链路转化为可分模块验证、可估算资源延迟、可逐步硬件化的工程路线。即使暂时没有 FPGA/SoC 硬件，也可以通过 MATLAB golden data、Verilog testbench、iverilog 和 xsim 对模块级行为进行验证。

## 边界说明

本文不声称完成纯 FPGA 全算法定点实现。Step8.9 固定点验证显示 fixed-point not closed，EVD/SVD 和 route decision 对数值扰动敏感，因此第一版采用 FPGA/SoC 协同边界。
