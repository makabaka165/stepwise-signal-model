# 第13步 FPGA/SoC协同边界与DBF硬件实现方案

## Step13.4最终边界

Step13.4 后，FPGA 侧最终收束为 DBF 数据通路：

```text
Y stream -> W input/read -> conj(W)*Y -> full-N accumulation -> fixed shift
-> symmetric rounding -> signed int24 saturation -> Z output + clip/overflow flags
```

推荐工程格式：

- recommended: `mixed_W18_Y16_Z24`
- fallback: `mixed_W24_Y16_Z24`
- `ACC_BITS=48`
- `Z_BITS=24`
- `engineering_Z_shift_bits=20`

CPU/SoC 侧继续负责 `Rz/G_cache/2D ML/topK/C05/confidence/boundary/fallback`。
这些模块不是 FPGA RTL 待补功能，而是按分工保留在 CPU/SoC 软件/控制层。

当前 flags：

- `fixed_shift_policy_pass_flag=true`
- `fulln_functional_pass_flag=true`
- `ooc_synthesis_pass_flag=true`
- `timing_200MHz_met_flag=true`
- `step13_engineering_closure_flag=true`
- `formal_result_claimed=false`
- `proceed_to_full_fpga_backend_flag=0`
- `proceed_to_board_validation_flag=0`

## 工程背景

Step13用于把论文工程实现边界从“算法可行性”推进到“FPGA/SoC分工可实现”。本步骤主线是 FPGA/SoC 协同边界收束与 FPGA DBF 硬件实现方案，不是完整 ML 后端硬件化。

## 导师边界建议转化

工程边界采用“规则高速计算放 FPGA，策略和数值敏感决策放 CPU/SoC”的原则。Step13将 FPGA 主体限定为 DBF：

```text
Z = W^H Y
```

其中 `Y` 是阵元域或局部工作子阵数据，`W` 是 DBF 权值，`Z` 是输出给 CPU/SoC 的 beamspace 数据。

## FPGA/SoC划分表

| 模块 | FPGA | CPU/SoC |
| --- | --- | --- |
| W权值存储/读取 | 主负责 | 配置、版本和策略管理 |
| Y输入流接收 | 主负责 | DMA/缓存配置 |
| 复乘加流水线 | 主负责 | 不负责 |
| scale/round/saturation | 主负责 | 读取元数据 |
| Z输出接口 | 主负责 | 接收Z |
| Rz = Z Z^H | 可选轻量支持 | 主负责 |
| G_cache | 不负责 | 主负责 |
| 2D beamspace ML/topK | 不负责完整硬化 | 主负责 |
| C05 policy/confidence/fallback/boundary | 不负责完整硬化 | 主负责 |
| 日志和最终输出 | 不负责 | 主负责 |

## DBF公式与方向图区别

DBF = Digital Beamforming，数字波束形成。DBF不是方向图本身。DBF是对多阵元信号乘复权值后相干求和的实时运算过程：

```text
z_b(t) = w_b^H x(t)
```

多波束写成：

```text
Z = W^H Y
```

方向图是权值对不同方向导向矢量的响应：

```text
B(theta, phi) = |w^H a(theta, phi)|
```

因此 DBF 是实时运算模块；方向图是权值形成的空间响应结果。方向图可以用来分析 DBF 权值效果，但不能把方向图等同于 DBF。

## Fixed-Point验证设计

Step12中的 `mixed_Z16_G24_Rz24` 是未来 ML score-core accelerator 的定点证据，不是 Step13 DBF W/Y/Z 默认推荐格式。

Step13 DBF 初始候选：

- `mixed_W18_Y16_Z24`
- `mixed_W24_Y16_Z24`

验证指标至少包括：

- `Z_rel_l2_error`
- `Z_max_abs_error`
- `beam_power_rel_error`
- `beam_power_rank_preservation`
- `top_beam_same_rate`
- `Z_cov_Rz_rel_error`
- `clip_rate`
- `overflow_rate`
- `scale_w`
- `scale_y`
- `scale_z`
- `same_backend_input_shape`
- `Rz_shape_same`
- `cpu_soc_ml_ready_flag`

Step13 DBF pass只说明 FPGA DBF 可行，不说明完整 ML backend FPGA 化。

## Resource / Bandwidth / Latency估算方法

资源估算围绕以下字段：

- `N_input_channels`
- `B_output_beams`
- `L_snapshots`
- `complex_multipliers_per_beam`
- `complex_mac_count_per_snapshot`
- `W_storage_bits`
- `Y_input_bandwidth`
- `Z_output_bandwidth`
- `accumulator_width`
- `latency_estimate`
- `throughput_estimate`
- `BRAM_rough_estimate`
- `URAM_rough_estimate`
- `DSP_rough_estimate`

三档架构：

- `one_complex_mac_lane`
- `beam_parallel_B_lanes`
- `full_BxN_parallel`

建议以 `beam_parallel_B_lanes` 作为未来 RTL DBF prototype 起点，因为它在吞吐、资源和控制复杂度之间最均衡。

## FPGA -> SoC接口字段

建议接口字段：

- `frame_id`
- `detect_id`
- `N_input_channels`
- `B_output_beams`
- `L_snapshots`
- `W_format`
- `Y_format`
- `Z_format`
- `scale_w`
- `scale_y`
- `scale_z`
- `clip_rate`
- `overflow_rate`
- `Z_payload`
- `valid_flag`

## Step12结果如何作为支撑材料

Step12保留为 ML score-core 和 topK/ranking 定点敏感性的支撑材料。它帮助说明后续 ML score accelerator 的风险，但不直接作为 Step13 DBF W/Y/Z 格式结论。

## 为什么不把完整ML搜索放FPGA

完整 2D ML 搜索、C05 policy、confidence、fallback、boundary 和日志解释具有强分支、强策略和数值敏感特征。它们更适合 CPU/SoC 管理。FPGA本轮优先收束规则、并行、流式的 DBF 运算边界。

## 是否建议进入RTL DBF prototype

若 MATLAB quick/smoke 中 `mixed_W18_Y16_Z24` 和 `mixed_W24_Y16_Z24` 均满足误差、排名和clip约束，则建议下一步进入 RTL DBF prototype。RTL 原型应从 `beam_parallel_B_lanes` 开始，而不是从完整 ML backend 硬化开始。
