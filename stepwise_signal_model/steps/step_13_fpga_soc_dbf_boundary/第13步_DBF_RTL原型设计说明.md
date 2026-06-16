# 第13步 DBF RTL原型设计说明

## Step13.2a 仿真工具链闭合记录

Step13.2a 的目标不是新增算法功能，而是补齐 Windows-friendly RTL smoke
入口，让已有 raw accumulator testbench 可以在有 `iverilog/vvp` 的环境中直接运行。

新增入口：

- `sim/run_iverilog_dbf_smoke.ps1`
- `sim/run_iverilog_dbf_smoke.cmd`

脚本可从 Step13 目录或 `sim/` 目录启动，会自动定位 Step13 根目录，并写入：

```text
results_step13_fpga_soc_dbf_boundary/rtl_sim/step13_dbf_rtl_sim_summary.csv
```

当前环境检查结果：

- `tool_iverilog_found = false`
- `tool_vvp_found = false`
- `simulation_status = unavailable`
- `comparison_status = unavailable`
- `accumulator_match_flag = false`

这不是 RTL pass，也不是 formal closure；只是明确记录仿真工具不可用。tracked
summary 中不写本机绝对路径。若后续安装 `iverilog/vvp`，同一脚本会编译并运行
`tb_dbf_complex_mac.v` 与 `tb_dbf_core_accum.v`，再由 MATLAB compare 验证
`RTL acc_re/acc_im == MATLAB golden acc_re/acc_im`。

## 目标边界

Step13.2 只实现 DBF accumulator-level RTL prototype，目标公式为：

```text
Z = W^H Y
```

其中 `W^H` 表示对 `W` 做共轭转置。RTL 中每个阵元样本的复乘采用：

```text
p_re = w_re * y_re + w_im * y_im
p_im = w_re * y_im - w_im * y_re
```

随后对 `N` 个输入通道累加，得到一个 beam / snapshot 的 raw accumulator。

## 当前模块

- `rtl/dbf_complex_mac.v`：组合逻辑复乘，验证 `conj(W) * Y`。
- `rtl/dbf_beam_accum_core.v`：单 beam、单 snapshot 的流式累加器。
- `rtl/dbf_core_accum.v`：第一版薄 wrapper，复用一个 accumulator lane。

第一版选择的是可复用单 lane 原型，而不是最终全并行 `B x N` datapath。这样
可以先把数学符号、定点整数输入、accumulator bit-true 行为对齐，再进入更复杂
的多 lane RTL。

## Golden vector

`matlab_golden/generate_step13_dbf_rtl_golden.m` 默认使用：

```text
STEP13_INPUT_SOURCE = step11_light
STEP13_RTL_GOLDEN_MODE = mixed_W18_Y16_Z24
STEP13_RTL_GOLDEN_N_LIMIT = 64
STEP13_RTL_GOLDEN_B_LIMIT = 7
STEP13_RTL_GOLDEN_L_LIMIT = 4
```

完整 Step11-compatible 来源是 `N=2080, B=7, L=16`，但 RTL smoke 只导出 compact
slice，避免 tracked artifact 过大。当前默认量化：

- `W_BITS = 18`
- `Y_BITS = 16`
- `ACC_BITS = W_BITS + Y_BITS + ceil(log2(N_LIMIT)) + 2`
- `full_ACC_BITS = W_BITS + Y_BITS + ceil(log2(2080)) + 2`

本轮 golden 以 raw accumulator 为主，不把 Z24 shift / round / saturate 写成
第一版 RTL 的必选数据通路。

## 验证方式

`tb/tb_dbf_complex_mac.v` 使用手写正负数样例验证复乘公式。`tb/tb_dbf_core_accum.v`
include compact `.vh` golden vectors，并对所有 compact `B/L` pair 做 raw
accumulator 比对，输出：

```text
results_step13_fpga_soc_dbf_boundary/rtl_sim/dbf_core_accum_output.csv
```

如果 `iverilog` 和 `vvp` 可用，可在 Step13 目录运行：

```bash
bash sim/run_iverilog_dbf_smoke.sh
```

如果仿真输出存在，可以再运行：

```matlab
cd('matlab_golden')
compare_step13_dbf_rtl_outputs
```

## 明确不做的内容

Step13.2 不实现：

- `Rz`
- `G_cache`
- 2D ML search
- topK
- C05 policy
- confidence / fallback / boundary hardening
- 完整 FPGA backend
- board validation
- formal closure

本轮也不修改 Step11.7 backend 默认行为，不运行 Step11.7 full backend，不迁移或
修改 `codex/step12-fpga-soc`。

## 下一步建议

Step13.3 可以在当前 raw accumulator smoke 通过的基础上继续推进：

- Z24 shift / round / saturate 数据通路；
- 更大 `N/L` 的 Step11-compatible golden coverage；
- 从单 accumulator lane 过渡到 `beam_parallel_B_lanes` 原型；
- 后续再评估 Vivado synthesis / timing / resource 报告。
