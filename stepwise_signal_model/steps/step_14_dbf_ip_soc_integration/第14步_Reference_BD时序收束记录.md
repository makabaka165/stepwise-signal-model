# 第14步 Reference BD 时序收束记录

## 背景

Step14.3a 已证明 Reference BD 功能链路可运行：

```text
S_AXIS_Y
-> axis_in_fifo_0
-> dbf_axis_0
-> axis_out_fifo_0
-> M_AXIS_Z
```

功能证据包括 BD validate、wrapper generation、Reference BD XSim、Case A
14/14 exact match、Case B 28/28 exact match、input backpressure propagation、
synthesis pass 和 route completed。

Step14.3a 的 blocker 是 200 MHz post-route setup timing 未闭合：

```text
WNS = -0.076 ns
TNS = -0.079 ns
setup failing endpoints = 2
WHS = 0.096 ns
hold failing endpoints = 0
blocker_if_any = post_route_timing_200MHz_not_met
```

## 本轮策略

本轮按两级策略执行：

1. Phase A：不修改 RTL、不修改 Custom IP、不修改 Reference BD 拓扑、不修改 FIFO
   参数、不修改合法约束，只做 Vivado implementation strategy sweep。
2. Phase B：仅当 Phase A 无法达到 `WNS >= 0.100 ns` 工程 margin 时，才允许给
   `dbf_complex_mac_pipe` 增加一个局部 operand input pipeline stage。

本轮不降低时钟、不改 advertised ACLK、不添加 data false path、不添加 multicycle
path、不放宽 `set_max_delay`，也不通过修改 summary CSV 伪造 timing pass。

## 固定边界

保持不变：

```text
Z = W^H Y
W18 / Y16 / ACC48 / Z24
SHIFT_BITS = 20
N = 2080
B = 7
VLNV = user.org:radar:dbf_axis:1.0
S_AXIS_Y = 32 bit, 2080 beats/frame
M_AXIS_Z = 64 bit, 7 beats/frame
clock = 200 MHz
clock_period_ns = 5.000
```

仍不包含：

```text
Zynq PS
AXI DMA
DDR
AXI-Lite
SmartConnect
ILA
bitstream
XSA
HWH
board constraints
CPU/SoC ML RTL
完整 FPGA backend
formal closure
```

## Phase A 结果

Vivado 2024.2 strategy sweep 输出到：

```text
results_step14_dbf_ip_soc_integration/reference_bd_timing/
```

实际运行：

```text
phase_a_strategy_count = 9
best_strategy = Performance_NetDelay_high
best_implementation_stop_step = route_design
best_post_route_phys_opt_executed_flag = false
best_WNS_ns = 0.205
best_TNS_ns = 0.000
best_setup_failing_endpoints = 0
best_WHS_ns = 0.093
best_hold_failing_endpoints = 0
phase_a_strategy_sweep_pass_flag = true
```

本轮 sweep 统一使用 `launch_runs ... -to_step route_design`。因此
`Performance_ExplorePostRoutePhysOpt` 这一行表示 Vivado 接受该 implementation
strategy 并完成 route，不表示额外的 post-route phys-opt step 已完整执行。CSV 中用
`implementation_stop_step` 和 `post_route_phys_opt_executed_flag` 显式记录该边界。

独立 clean rerun 结果：

```text
phase_a_clean_rerun_pass_flag = true
final_strategy = Performance_NetDelay_high
final_WNS_ns = 0.205
final_TNS_ns = 0.000
final_setup_failing_endpoints = 0
final_WHS_ns = 0.093
final_hold_failing_endpoints = 0
```

因此 Phase B 未触发：

```text
phase_b_required_flag = false
operand_pipeline_added_flag = false
operand_pipeline_extra_latency_cycles = 0
input_throughput_samples_per_cycle = 1
mac_pipe_equivalence_applicable_flag = false
mac_pipe_equivalence_status = not_applicable
mac_pipe_equivalence_gate_pass_flag = true
```

这里的 MAC equivalence gate pass 只表示 Phase B 未触发时“不适用且不阻塞”，不是
`tb_dbf_complex_mac_pipe_equiv` 已运行通过。

## 资源

```text
baseline_post_route:
  LUT = 2097
  FF = 5112
  DSP = 42
  BRAM18 = 1
  BRAM36 = 16
  WNS = -0.076

final_post_route:
  LUT = 2096
  FF = 5031
  DSP = 42
  BRAM18 = 1
  BRAM36 = 16
  WNS = 0.205
```

## DRC 与 Methodology

Reference BD 是板卡无关 OOC wrapper，外部 AXIS 端口没有真实板级 IO delay。
因此 `TIMING-18` 作为 expected methodology warning 记录；其他 methodology
Error 或 Critical Warning 不允许被忽略。

最终记录：

```text
DPIP_1_count = 14
DPOP_1_count = 14
DPOP_2_count = 0
ZPS7_1_count = 1
TIMING_18_count = 153
unexpected_drc_error_count = 0
unexpected_methodology_violation_count = 0
external_clock_association_pass_flag = true
reference_methodology_expected_only_flag = true
```

## 回归证据

Step14.3b 没有修改 DBF RTL。最终聚合脚本逐项读取原始 CSV，而不是用 Step14.2b
总 gate 代替所有子项：

```text
step14_2b_hardening_pass_flag = true
step14_3a_functional_evidence_pass_flag = true
baseline_axis_regression_pass_flag = true
optimized_raw_top_xsim_pass_flag = true
packaged_ip_xsim_pass_flag = true
packaged_ip_exact_compare_pass_flag = true
reference_bd_xsim_pass_flag = true
reference_bd_exact_compare_pass_flag = true
```

Reference BD Case A/B 仍以 Step14.3a 证据为准：

```text
Case A exact compare = 14/14
Case B FIFO/backpressure stress compare = 28/28
input backpressure propagation = pass
```

## Final Gate

最终 keypoints：

```text
step14_3b_post_route_timing_pass_flag = true
step14_3b_timing_margin_pass_flag = true
step14_3b_reference_bd_timing_closure_flag = true
step14_reference_bd_integration_pass_flag = true
proceed_to_platform_freeze_flag = true
proceed_to_target_board_dma_flag = false
proceed_to_board_validation_flag = false
proceed_to_full_fpga_backend_flag = false
bitstream_generated_flag = false
xsa_generated_flag = false
hwh_generated_flag = false
formal_result_claimed = false
blocker_if_any =
```

结论：Step14.3b 在不触发 Phase B、不新增 operand pipeline、不改 DBF 数学和 AXI
协议的前提下，通过 Vivado 2024.2 implementation strategy sweep 与独立 clean
rerun 完成 Reference BD 200 MHz post-route timing closure。
