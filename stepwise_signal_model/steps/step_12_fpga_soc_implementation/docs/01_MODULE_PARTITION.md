# 01 Module Partition

## FPGA / SoC 分工表

| Module | Preferred Side | Reason | Notes |
|---|---|---|---|
| pulse compression | FPGA | 高吞吐规则卷积或 FFT 结构 | 适合流水和并行 MAC |
| MTD_FFT | FPGA | 慢时间 FFT 结构规则 | 可复用 FFT IP |
| CFAR | FPGA | 窗口统计和阈值比较规则 | 可流式实现 |
| coarse_beamforming | FPGA | 多波束功率可并行计算 | 输出 coarse angle / center_col |
| shared_center_column_selection | FPGA_or_SoC | 小控制逻辑，可硬件化抽取 | 当前提供 RTL 原型 |
| Y_work_packing | FPGA | 固定局部张量构造 | 当前提供 RTL 原型 |
| steering_LUT | FPGA | 局部模板预计算和查表 | 需评估 LUT 精度 |
| projection_score_acceleration | FPGA_accelerated | dot-product / projection 可并行 | 当前提供简化 RTL 原型 |
| Step8.7 lazy cascade scheduler | SoC | 路由调度和分支控制复杂 | 不修改 Step8.7 |
| EVD/SVD | SoC_or_float_IP | 数值敏感，第一版不建议纯定点 | 可使用 CPU/ARM/DSP/浮点 IP |
| rank1 decision | SoC | 依赖 route 和阈值判据 | 保留解释性 |
| local 2D / pair-local decision | SoC_or_float_IP | 分支小但复杂 | 可按需触发 |
| route selection | SoC | 控制密集 | 与 lazy cascade 绑定 |
| confidence / boundary state machine | SoC | 解释性状态和边界输出 | 便于日志追踪 |
| logging / tracking interface | SoC | 系统集成接口 | 输出 route log |

## 分工原则

规则、可流水、可并行、重复度高的模块优先放 FPGA；数值敏感、分支复杂、需要解释和日志的模块优先放 SoC/CPU。projection score 可作为可选加速核，而不是第一版完整算法替代。
