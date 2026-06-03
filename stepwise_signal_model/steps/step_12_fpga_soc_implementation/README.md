# Step12 FPGA/SoC Implementation Framework

本目录用于论文第二创新点：“面向 shared-center 局部增强测角链路的 FPGA/SoC 协同实现框架”。

本步骤只建立工程实现边界和可验证原型，不修改 Step8.7 verified lazy cascade，不继续修改 Step9 backend，也不把 Step11 ML 纳入当前主线。当前阶段不承诺完整纯 FPGA 定点实现；目标是沉淀工程架构、模块分工、接口定义、RTL/HLS 原型和模块级仿真验证方法。

本步骤不再采用简单的“FPGA 做前端、CPU 做后端”二分，而采用三层 FPGA/SoC 协同架构：Layer 1 为 FPGA streaming frontend，Layer 2 为 FPGA local acceleration kernels，Layer 3 为 SoC route/control layer。前端、shared-center 抽取和 Y_work packing 基本适合 FPGA；Step8.7 backend 不应整体放 SoC，其中谱扫描、投影、协方差累加、refocus score、rank1 score 和 2D score 都可以由 FPGA kernel 加速；SoC 负责分支调度、EVD/SVD、峰值解释、置信拒判和系统输出。

没有硬件时，允许先使用 MATLAB golden data + Verilog testbench / xsim / iverilog 进行模块级仿真验证。该目录内的 RTL 是工程验证原型骨架，不要求直接完整替代 MATLAB 算法。

## Final Dataflow

Raw ADC / array data
-> Layer 1 FPGA streaming frontend: pulse compression
-> Layer 1 FPGA streaming frontend: MTD / Doppler FFT
-> Layer 1 FPGA streaming frontend: CFAR
-> Layer 1 FPGA streaming frontend: coarse beamforming
-> Layer 1 FPGA streaming frontend: shared-center 65-column extraction
-> Layer 1 FPGA streaming frontend: Y_work packing / DMA
-> Layer 2 FPGA local acceleration kernels: covariance / MUSIC projection / 2D score / rank1-refocus score / pair-local score
-> Layer 3 SoC route/control: Step8.7 lazy cascade scheduling
-> Layer 3 SoC route/control: EVD / SVD control, peak interpretation, confidence / boundary, route log
-> Output: az/el estimate + confidence + boundary flag + route log

## Final Module Partition

### 1. Frontend signal processing

| 模块 | FPGA | SoC/CPU |
| --- | --- | --- |
| ADC / 数据接收 | 主负责 | 配置控制 |
| LFM / 脉压 | 主负责 | 参数配置 |
| MTD / Doppler FFT | 主负责 | 参数配置 |
| CFAR | 主负责 | 阈值策略配置 |
| coarse beamforming | 主负责 | 扇区策略 / 调度 |
| frontend_state 初步生成 | 可做简单状态 | 最终解释和策略 |

结论：前端基本都适合 FPGA，SoC/CPU 主要负责配置、策略和最终解释。

### 2. shared-center interface

| 模块 | FPGA | SoC/CPU |
| --- | --- | --- |
| coarseAz 到 selectedCenterColumn | FPGA 或 SoC 都可 | 可负责策略计算 |
| 65 列索引 wrap-around | 很适合 | 可记录索引 metadata |
| 65 列数据抽取 | 主负责 | 接收结果 |
| Y_work = 65 x 32 x Np 打包 | 主负责 | 接收结果 |
| Y_work DMA 到 SoC | FPGA + DMA | DMA 接收 |
| selected metadata | 生成 | 记录 |

建议：selectedCenterColumn 可以由 SoC 算，也可以由 FPGA 算；但 65 列抽取和 Y_work packing 更适合 FPGA，因为数据在 FPGA 流水里，直接硬件抽取更自然。

### 3. Step8.7 lazy cascade backend

| Step8.7 子模块 | FPGA | SoC/CPU |
| --- | --- | --- |
| level2 MUSIC 谱扫描 | 可加速 | 触发和解释 |
| common-el refocus power | 可加速 | 是否接受 |
| rank1 candidate score | 可加速 | route reliable 判断 |
| covariance accumulation | 主负责 | EVD/SVD 控制 |
| 2D-MUSIC 谱扫描 | 强适合 | 触发、解释 |
| pair-local score grid | 可加速 | 结果选择 |
| lazy early stop | 简单 gate 可硬件化 | 总调度 |
| confidence / boundary | 不建议主负责 | 主负责 |
| reject_reason / route log | 不适合 | 主负责 |

结论：Step8.7 backend 不应整体放 SoC。谱扫描、投影、协方差累加、refocus score、rank1 score、2D score 都可以 FPGA 加速；SoC 负责分支调度、EVD/SVD、峰值解释、置信拒判和系统输出。

## Three-Layer Hardware Architecture

### Layer 1: FPGA streaming frontend

负责 pulse compression、MTD、CFAR、coarse beamforming、shared-center extraction 和 Y_work packing。其特点是固定流水、高吞吐、低延迟和实时处理。

### Layer 2: FPGA local acceleration kernels

负责 covariance accumulation、steering LUT、MUSIC projection score、2D-MUSIC spectrum grid、rank1/refocus score grid、pair-local score grid 和 top-K candidate extraction。其特点是按需触发、计算密集、并行乘加，并由 SoC 调用。

### Layer 3: SoC route/control layer

负责 lazy cascade state machine、EVD/SVD or floating IP call、route selection、candidate interpretation、confidence/boundary decision、logging 和 tracking interface。其特点是控制复杂、数值敏感、易调试和可解释。

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

## 文件存放位置：

rtl/              Verilog / SystemVerilog 源码
tb/               testbench
sim/              仿真脚本
matlab_golden/    MATLAB 生成 golden data 和结果比对
constraints/      约束文件，暂时可以空着
docs/             FPGA/SoC 文档
evidence/         分工表、边界表、验证结果表
diagrams/         图表说明或图片
