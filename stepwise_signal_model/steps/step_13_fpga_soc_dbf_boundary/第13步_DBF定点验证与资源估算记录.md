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
