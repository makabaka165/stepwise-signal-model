# 06 Implementation Risk and Future Work

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| fixed-point not closed | 不能声明完整纯 FPGA 定点实现 | 采用 FPGA/SoC 协同，引用 Step8.9 evidence |
| EVD/SVD IP | 资源、延迟和精度不确定 | 第一版放 SoC/CPU 或浮点 IP |
| LUT 精度 | steering/template/cache 量化可能导致 route flip | 保留高精度 LUT 或混合精度评估 |
| 数据搬运 | Y_work、LUT 和检测单元之间带宽压力 | 设计流式接口和本地缓存 |
| 实时调度 | 多检测单元触发复杂分支 | SoC 侧维护 route scheduler 和优先级 |
| 多检测单元并行 | DSP/BRAM/AXI 资源竞争 | 以检测队列和 kernel 复用控制峰值资源 |
| 无硬件验证边界 | 只能证明模块行为，不能证明板级实时性 | 先完成 iverilog/xsim，再进入 Vivado/Vitis |

## Future Work

1. 用 MATLAB golden vector 扩展小规模 bit-true 输入输出集。
2. 将 RTL 原型接入 AXI-stream 或本项目约定的 valid-ready 接口。
3. 对 projection score acceleration 做 DSP/BRAM 资源估算。
4. 在硬件可用后补充 Vivado/Vitis 综合、时序和板级延迟报告。
5. 对 EVD/SVD 浮点 IP 或 CPU fallback 做延迟剖析。
