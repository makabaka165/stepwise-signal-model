# Step12 FPGA/SoC Implementation Framework

本目录用于论文第二创新点：“面向 shared-center 局部增强测角链路的 FPGA/SoC 协同实现框架”。

本步骤只建立工程实现边界和可验证原型，不修改 Step8.7 verified lazy cascade，不继续修改 Step9 backend，也不把 Step11 ML 纳入当前主线。当前阶段不承诺完整纯 FPGA 定点实现；目标是沉淀工程架构、模块分工、接口定义、RTL/HLS 原型和模块级仿真验证方法。

FPGA 侧负责规则明确、高吞吐、可流水和可并行的计算，包括前端信号处理、shared-center 65-column 抽取、Y_work packing，以及可选的投影分数加速。SoC/CPU 侧负责复杂分支、EVD/SVD、route decision、rank1 / pair-local 判断、confidence / boundary 状态和日志接口。

没有硬件时，允许先使用 MATLAB golden data + Verilog testbench / xsim / iverilog 进行模块级仿真验证。该目录内的 RTL 是工程验证原型骨架，不要求直接完整替代 MATLAB 算法。

## Final Dataflow

Raw ADC / array data
-> FPGA: pulse compression
-> FPGA: MTD / Doppler FFT
-> FPGA: CFAR
-> FPGA: coarse beamforming
-> FPGA: shared-center 65-column extraction
-> FPGA: Y_work packing / optional projection acceleration
-> SoC: Step8.7 lazy cascade route decision
-> SoC: EVD / SVD / rank1 / pair-local / confidence
-> Output: az/el estimate + confidence + boundary flag + route log

## Directory Layout

- `docs/`: thesis-facing engineering notes.
- `diagrams/`: diagram inventory and future drawing plan.
- `evidence/`: partition and fixed-point boundary CSV evidence.
- `rtl/`: Verilog RTL prototype skeletons.
- `tb/`: module-level Verilog testbenches.
- `sim/`: iverilog and xsim simulation entry scripts.
- `matlab_golden/`: small-vector generation and comparison scripts.
- `constraints/`: future timing, pin, and clocking constraints notes.
- `build/`: ignored local build output directory.
