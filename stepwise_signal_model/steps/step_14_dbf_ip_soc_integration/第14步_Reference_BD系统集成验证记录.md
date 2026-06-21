# 第14步 Reference BD 系统集成验证记录

本记录对应 Step14.3a：使用已封装的 Vivado Custom IP
`user.org:radar:dbf_axis:1.0` 创建板卡无关 Reference Block Design，并验证
AXI4-Stream 功能链路、综合、布线和 DRC 统计。

## 范围

BD 拓扑固定为：

```text
S_AXIS_Y
-> axis_in_fifo_0
-> dbf_axis_0 (user.org:radar:dbf_axis:1.0)
-> axis_out_fifo_0
-> M_AXIS_Z
```

本轮使用 Custom IP cell，不使用 Module Reference。外部只暴露 `aclk`、
active-low `aresetn`、`S_AXIS_Y`、`M_AXIS_Z` 和 DBF status/debug 输出。

本轮不包含 PS、DMA、DDR、AXI-Lite、SmartConnect、bitstream、XSA、HWH、
真实开发板、CPU ML、完整 FPGA backend 或 formal closure。

## 功能验证

```text
Vivado = 2024.2
part = xc7z020clg400-1
reference_device_only = true
BD validate = pass
wrapper generation = pass
Reference BD XSim = pass
Case A exact compare = pass, expected/actual/matched = 14/14/14
Case B FIFO/backpressure stress compare = pass, expected/actual/matched = 28/28/28
missing/duplicate/tdata/z/flag/tlast/beam_order mismatch = 0
```

## 实现结果

```text
synthesis_status = pass
implementation_status = pass
route_completed_flag = true
LUT = 2097
FF = 5112
DSP = 42
BRAM18 = 1
BRAM36 = 16
```

200 MHz post-route timing 未通过：

```text
WNS_ns = -0.076
TNS_ns = -0.079
failing_endpoints = 2
WHS_ns = 0.096
hold_failing_endpoints = 0
post_route_timing_200MHz_met_flag = false
```

主要 blocker：

```text
blocker_if_any = post_route_timing_200MHz_not_met
```

## DRC

```text
DRC_error_count = 0
DRC_critical_warning_count = 0
DRC_warning_count = 34
ZPS7_1_count = 1
DPIP_1_count = 19
DPOP_1_count = 14
unexpected_drc_error_count = 0
reference_expected_drc_only_flag = true
```

这些 warning 是 reference-device-only/OOC BD 记录的一部分，不构成板级验证。

## Gate

```text
step14_3a_reference_bd_pass_flag = false
proceed_to_platform_freeze_flag = false
proceed_to_target_board_dma_flag = false
proceed_to_board_validation_flag = false
proceed_to_full_fpga_backend_flag = false
formal_result_claimed = false
bitstream_generated_flag = false
xsa_generated_flag = false
hwh_generated_flag = false
```

结论：Reference BD 的 AXI4-Stream 功能链路已经通过 XSim 和 MATLAB exact
compare，但 200 MHz post-route timing 仍差 0.076 ns，不能进入 platform
freeze、DMA reference design 或板级验证。
