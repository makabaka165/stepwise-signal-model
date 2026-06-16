# 第13步 DBF定点验证与资源估算记录

## 当前运行状态

本文件用于记录 Step13 MATLAB quick/smoke 运行情况。quick/smoke 只验证 DBF 边界：

```text
Z = W^H Y
```

它不是 formal closure，不伪造 formal 结果，也不把 quick 结果写成完整 ML backend FPGA 化结论。

Initial status before local execution:

```text
MATLAB quick/smoke not run in this environment.
```

运行后应以 `results_step13_fpga_soc_dbf_boundary/` 下 CSV 和图表为准。

## 验证范围

验证对象：

- DBF W/Y/Z 定点量化
- Z误差
- beam power误差和排名保持
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

Step12的 `mixed_Z16_G24_Rz24` 是未来 ML score-core accelerator 的定点证据，不是 Step13 DBF W/Y/Z 默认推荐格式。

## 资源估算记录字段

资源估算至少记录：

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

建议比较：

- `one_complex_mac_lane`
- `beam_parallel_B_lanes`
- `full_BxN_parallel`

当前工程建议从 `beam_parallel_B_lanes` 进入后续 RTL DBF prototype。

## 运行命令

```matlab
run('setup_paths.m')
cd('steps/step_13_fpga_soc_dbf_boundary')
setenv('STEP13_QUICK_MODE','1')
run_step13_fpga_soc_dbf_boundary
```

如果本环境没有 MATLAB，则不要生成伪结果；最终报告中明确写：

```text
MATLAB quick/smoke not run in this environment.
```
