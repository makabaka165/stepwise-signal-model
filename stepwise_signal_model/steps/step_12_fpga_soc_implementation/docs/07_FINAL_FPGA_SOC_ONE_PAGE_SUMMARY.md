# 07 Final FPGA/SoC One Page Summary

## 一句话定位

Step12 是“面向 shared-center 局部增强测角链路的 FPGA/SoC 协同实现框架”，服务于论文第二创新点的工程落地论证。

## 已收束算法路线

Frontend detection / coarse angle -> shared-center 65-column local work subarray -> Y_work construction -> Step8.7 verified lazy cascade backend -> confidence / boundary output -> FPGA/SoC implementation boundary。

## FPGA 侧职责

FPGA 负责规则、高吞吐、可流水和可并行模块：pulse compression、MTD_FFT、CFAR、coarse_beamforming、shared_center_column_selection、Y_work_packing、steering_LUT 和 projection_score_acceleration。

## SoC/CPU 侧职责

SoC/CPU 负责复杂分支和数值敏感模块：Step8.7 lazy cascade scheduler、EVD/SVD、rank1 decision、local 2D / pair-local decision、route selection、confidence / boundary state machine 和 logging / tracking interface。

## 为什么不是纯 FPGA

Step8.9 / Step10 evidence 显示 fixed-point not closed，推荐定点格式为 not_recommended，blocker 为 quantization_not_closed。因此第一版不承诺完整纯 FPGA 定点算法，而采用 FPGA/SoC 协同。

## 当前可验证产物

本目录提供 3 个 RTL 原型：shared_center_column_selector、y_work_packer、projection_score_core；提供 3 个 testbench；提供 iverilog/xsim 仿真入口；提供 MATLAB golden vector 生成和仿真输出比较脚本。

## 当前是否需要硬件

不需要。当前阶段先做 MATLAB golden data + Verilog testbench / xsim / iverilog 模块级仿真验证。
