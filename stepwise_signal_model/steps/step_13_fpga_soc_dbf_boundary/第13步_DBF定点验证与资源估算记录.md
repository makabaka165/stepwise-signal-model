# 第13步 DBF定点验证与资源估算记录

## 当前运行状态

本文件记录 Step13 MATLAB quick/smoke 运行情况。quick/smoke 只验证 DBF 边界：

```text
Z = W^H Y
```

它不是 formal closure，不伪造 formal 结果，也不把 quick 结果写成完整 ML backend FPGA 化结论。

## Step13.0 与 Step13.1

Step13.0 synthetic smoke 已通过，但 synthetic W/Y 只作为框架自检，不作为真实 Step11/Step12 DBF boundary closure。

Step13.1 增加 `STEP13_INPUT_SOURCE`：

- `synthetic`
- `step11_light`
- `auto`

本轮实际运行了两次 quick/smoke：

| input_source | status | N | B | L | W_method | fallback_reason |
| --- | --- | ---: | ---: | ---: | --- | --- |
| synthetic | pass | 24 | 9 | 16 | synthetic_DBF_W | empty |
| step11_light | pass | 2080 | 7 | 16 | greedy_combined_B7 | empty |

`step11_light` 只构造 Step11-compatible `W` / `Y_work` 并验证 DBF：

```text
Z = W^H Y
Rz = Z Z^H
```

它不运行 Step11.7 full backend，不执行 ML score search，不执行 topK/C05 policy，不把 `G_cache` 放到 FPGA。

当前记录：

- `step11_adapter_found_flag = true`
- `step11_7_full_backend_called = false`
- `step11_7_backend_default_changed = false`
- `formal_result_claimed = false`
- `dbf_step11_compatible_smoke_pass_flag = true`

本轮结果不是 formal closure，不说明完整 FPGA backend 通过，也不说明 ML score-core RTL 主线完成。

## 验证范围

验证对象：

- DBF W/Y/Z 定点量化
- Z误差
- beam power误差和排名保持
- topK beam index set保持
- Rz形状和相对误差
- clip/overflow统计
- FPGA资源、带宽和延迟粗估

非验证对象：

- Step11.7 full backend 默认行为
- 完整 2D ML 搜索硬件化
- 完整 C05 policy / confidence / fallback / boundary 硬化
- ML score-core RTL prototype

## 推荐候选格式

Step13 DBF 初始候选：

- `mixed_W18_Y16_Z24`
- `mixed_W24_Y16_Z24`

Step12 的 `mixed_Z16_G24_Rz24` 是未来 ML score-core accelerator 的定点证据，不是 Step13 DBF W/Y/Z 默认推荐格式。

## Step13.1结果摘要

Step11-compatible smoke 中：

- `mixed_W18_Y16_Z24`: `Z_rel_l2_error = 1.1521e-06`, `beam_power_rel_error = 2.5264e-07`
- `mixed_W24_Y16_Z24`: `Z_rel_l2_error = 1.0940e-06`, `beam_power_rel_error = 2.2371e-07`
- 两者 `topK_beam_set_preservation = 1`
- 两者 `beam_power_rank_preservation = 1`
- 两者 `Z_cov_Rz_rel_error < 3e-3`
- 两者 `clip_rate = 0`
- 两者 `overflow_rate = 0`

`dbf_smoke_pass_flag = 1` 只说明 Step13 DBF smoke 通过。

## 资源估算记录字段

资源估算记录：

- `clock_Hz`
- `cycles_per_snapshot_est`
- `throughput_snapshots_per_sec_est`
- `Y_input_bits_per_snapshot`
- `Z_output_bits_per_snapshot`
- `Y_input_MBps_at_clock`
- `Z_output_MBps_at_clock`
- `W_storage_bits`
- `accumulator_width_est`
- `complex_mac_count_per_snapshot`
- `complex_lanes`
- `DSP_rough_estimate`
- `BRAM36_rough_estimate`
- `URAM288_rough_estimate`

三档架构：

- `one_complex_mac_lane`
- `beam_parallel_B_lanes`
- `full_BxN_parallel`

本轮 Step11-compatible resource estimate 中，`beam_parallel_B_lanes` 摘要为：

- `clock_Hz = 200000000`
- `cycles_per_snapshot_est = 2084`
- `throughput_snapshots_per_sec_est = 95969.2898272553`
- `Y_input_MBps_at_clock = 798.464491362764`
- `Z_output_MBps_at_clock = 4.03071017274472`
- `W_storage_bits = 524160`
- `complex_lanes = 7`
- `DSP_rough_estimate = 21`
- `BRAM36_rough_estimate = 16`
- `URAM288_rough_estimate = 2`

当前工程建议以 `beam_parallel_B_lanes` 作为后续 RTL DBF prototype 起点。

## 运行命令

Synthetic:

```matlab
run('setup_paths.m')
cd('steps/step_13_fpga_soc_dbf_boundary')
setenv('STEP13_QUICK_MODE','1')
setenv('STEP13_INPUT_SOURCE','synthetic')
run_step13_fpga_soc_dbf_boundary
```

Step11-compatible:

```matlab
run('setup_paths.m')
cd('steps/step_13_fpga_soc_dbf_boundary')
setenv('STEP13_QUICK_MODE','1')
setenv('STEP13_INPUT_SOURCE','step11_light')
run_step13_fpga_soc_dbf_boundary
```

## Step13.2a 仿真工具链闭合记录

本轮新增 Windows-friendly `iverilog` 入口：

- `sim/run_iverilog_dbf_smoke.ps1`
- `sim/run_iverilog_dbf_smoke.cmd`

脚本会从 Step13 目录或 `sim/` 目录自动定位工程根目录，检查 `iverilog` 与 `vvp`，
并写入小型 summary：

```text
results_step13_fpga_soc_dbf_boundary/rtl_sim/step13_dbf_rtl_sim_summary.csv
```

当前环境实际结果：

- `simulation_status = unavailable`
- `tool_iverilog_found = false`
- `tool_vvp_found = false`
- `dbf_core_accum_output_csv_generated = false`
- `comparison_status = unavailable`
- `accumulator_match_flag = false`

MATLAB compare 已运行，因 `dbf_core_accum_output.csv` 不存在而记录 unavailable。
tracked result 中已清除本机绝对路径，仅保留相对路径。该状态不代表 RTL smoke
通过，也不代表 formal closure、timing closure 或 board validation。

## Step13.2b Vivado XSim 仿真结果

本轮使用 Vivado 2024.2 XSim 工具链运行 Step13 DBF RTL accumulator smoke。
新增入口：

- `sim/run_xsim_dbf_smoke.tcl`
- `sim/run_xsim_dbf_smoke.ps1`
- `sim/run_xsim_dbf_smoke.bat`
- `sim/xsim_run_all.tcl`

实际运行结果：

- `tool_xvlog_found = true`
- `tool_xelab_found = true`
- `tool_xsim_found = true`
- `simulation_status = pass`
- `dbf_complex_mac_smoke = pass`
- `dbf_core_accum_smoke = pass`
- `dbf_core_accum_output_csv_created = true`
- `comparison_status = pass`
- `accumulator_match_flag = true`
- `golden_rows = 28`
- `sim_rows = 28`
- `missing_count = 0`
- `mismatch_count = 0`

该结果只验证 compact `N=64, B=7, L=4` golden slice 的 raw accumulator
`Z = W^H Y` 与 MATLAB golden 完全一致。它不是 formal closure，不是 timing
closure，不是 synthesis closure，也不是 board validation。本轮没有实现 Z24
shift/round/saturate，没有实现 `Rz/G_cache/2D ML/topK/C05/confidence/fallback`，
也没有修改 Step11.7 backend 默认行为。

这里的“没有实现”不是 FPGA RTL 缺口，而是 Step13 FPGA/SoC 分工下的设计选择。
`Rz`、`G_cache`、二维 ML 搜索、topK、C05 policy、confidence、boundary、
fallback 保留在 CPU/SoC 侧的软件/控制层；FPGA 侧只推进 DBF：

```text
Z = W^H Y
```

## Step13.3 Z24 output datapath 仿真结果

本轮在 Step13.2b 已通过的 raw accumulator 基础上，新增 FPGA DBF Z24 输出
数据通路：

```text
ACC raw accumulator -> shift -> round -> saturate -> signed int24 Z output
```

Z24 采用硬件友好的移位量化规则，不在 RTL 运行时使用任意浮点 scale 除法：

```text
rounded_abs = (abs(acc) + 2^(SHIFT_BITS-1)) >> SHIFT_BITS
rounded     = sign(acc) ? -rounded_abs : rounded_abs
z_out       = saturate_signed_int24(rounded)
```

当前真实运行配置：

- `input_source_used = step11_light`
- `W_method = greedy_combined_B7`
- `quant_mode = mixed_W18_Y16_Z24`
- compact golden: `N=64, B=7, L=4`
- full reference shape: `N=2080, B=7, L=16`
- `W_bits = 18`
- `Y_bits = 16`
- `Z_bits = 24`
- `ACC_bits = 42`
- `full_ACC_bits = 48`
- `Z_shift_bits = 12`
- `Z_shift_auto_selected = true`
- compact Z24 golden 的 clip/overflow 计数为 0

Vivado XSim 结果：

- `simulation_status = pass`
- `overall_simulation_status = pass`
- `dbf_complex_mac_smoke = pass`
- `dbf_core_accum_smoke = pass`
- `dbf_z24_quantizer_smoke = pass`
- `dbf_core_z24_smoke = pass`
- `dbf_core_accum_output_csv_created = true`
- `dbf_core_z24_output_csv_created = true`

MATLAB compare 结果：

- `comparison_status = pass`
- `accumulator_match_flag = true`
- `z24_match_flag = true`
- `accumulator_missing_count = 0`
- `accumulator_mismatch_count = 0`
- `z24_missing_count = 0`
- `z24_mismatch_count = 0`
- `formal_result_claimed = false`

这仍然不是 formal closure，不是 timing closure，不是 synthesis closure，不是
implementation closure，也不是 board validation。`Rz/G_cache/2D
ML/topK/C05/confidence/boundary/fallback` 仍然不是 FPGA RTL 待补功能，而是
CPU/SoC 侧职责；FPGA 侧当前只推进 DBF `Z = W^H Y` 及其 Z24 输出数据通路。

## Step13.2 RTL golden-vector 与 accumulator smoke

Step13.2 在 Step13.1 的 Step11-compatible DBF smoke 基础上，只新增
`Z = W^H Y` 的 DBF accumulator-level RTL prototype 和 MATLAB golden-vector
testbench。RTL 复乘公式明确使用 `conj(W) * Y`：

```text
p_re = w_re * y_re + w_im * y_im
p_im = w_re * y_im - w_im * y_re
```

本轮新增内容：

- `matlab_golden/`：生成 compact Step11-compatible golden vectors，并预留 RTL 输出比对脚本。
- `rtl/`：`dbf_complex_mac.v`、`dbf_beam_accum_core.v`、`dbf_core_accum.v`。
- `tb/`：手写 MAC testbench 与 compact golden accumulator testbench。
- `sim/`：`run_iverilog_dbf_smoke.sh`。

默认 golden-vector 配置：

- `STEP13_INPUT_SOURCE = step11_light`
- `STEP13_RTL_GOLDEN_MODE = mixed_W18_Y16_Z24`
- `STEP13_RTL_GOLDEN_N_LIMIT = 64`
- `STEP13_RTL_GOLDEN_B_LIMIT = 7`
- `STEP13_RTL_GOLDEN_L_LIMIT = 4`

完整 Step11-compatible 输入仍为 `N=2080, B=7, L=16`；RTL smoke 默认只导出
`N=64, B=7, L=4` 的 compact slice，避免产生过大的 tracked artifact。当前
accumulator width 规则为：

```text
ACC_BITS = W_BITS + Y_BITS + ceil(log2(N_LIMIT)) + 2
full_ACC_BITS = W_BITS + Y_BITS + ceil(log2(2080)) + 2
```

本轮仍然不实现：

- `Rz`
- `G_cache`
- 2D ML search
- topK / C05 / confidence / fallback
- 完整 FPGA backend
- ML score-core RTL 主线

这些 CPU/SoC 侧模块并不是 Step13 FPGA RTL 待补功能。summary CSV 中
`rz_gcache_ml_topk_c05_implemented=false` 的含义是“按分工不放在 FPGA 侧”，
不是“项目工作缺失”。

Step13.2 的 RTL simulation smoke 即使通过，也只说明 compact raw accumulator
与 MATLAB golden 一致；它不是 formal closure，不是 board validation，也不是
完整 bit-true FPGA backend closure。Step13.3 已继续推进 Z24 shift/round/saturate
数据通路；后续可扩大 Step11-compatible golden coverage 或进入更并行的 DBF 原型。
