# 第14步 Custom IP封装与回归验证记录

## 目标

Step14.2 将 Step14.1 已验证的纯 RTL AXI4-Stream DBF 数据通路封装成 Vivado
Custom IP，并验证封装后的 IP 可以被 Vivado IP Catalog 识别、实例化、仿真和
OOC 综合。

本轮不创建 DMA、Zynq PS、DDR、Block Design、AXI-Lite、bitstream、XSA、HWH、
软件驱动、板级验证、完整 FPGA backend 或 formal closure。

## IP 身份

```text
VLNV = user.org:radar:dbf_axis:1.0
package_dir = ip_repo/dbf_axis_ip_1_0
display_name = Step14 DBF AXI Stream
reference_part = xc7z020clg400-1
```

`component.xml` 已生成。IP staging 由 `vivado/package_dbf_axis_ip.tcl` 自动重建，
不手工维护 staging RTL 副本。

## Package 内容

- Step13 arithmetic RTL：5 个文件。
- Step14 AXIS/IP RTL：5 个文件。
- W ROM `.mem`：14 个文件，beam-separated real/imag，来自 Step14.1 vectors。
- packaged HDL file count：10。
- packaged W mem file count：14。

Step13 tracked 文件未修改；Step11.7 backend 默认行为未修改；未迁移旧 Step12
FPGA 分支。

## Vivado IP Packager

Package summary：

```text
vivado_version = 2024.2
component_xml_created = true
ip_package_integrity_pass_flag = true
integrity_error_count = 0
integrity_warning_count = 0
absolute_path_scan_pass_flag = true
formal_result_claimed = false
```

接口识别：

```text
S_AXIS_Y recognized = true
M_AXIS_Z recognized = true
ACLK recognized = true
ARESETN recognized = true
axis_clock_association_pass_flag = true
reset_polarity_pass_flag = true
```

`S_AXIS_Y` 为 32-bit AXI4-Stream slave，`M_AXIS_Z` 为 64-bit AXI4-Stream
master。`ACLK` 关联 `S_AXIS_Y:M_AXIS_Z`，`ARESETN` 为 active-low。

## IP Catalog 验证

```text
ip_catalog_registration_pass_flag = true
ipdef_count = 1
create_ip_pass_flag = true
generate_target_pass_flag = true
generated_module_name = dbf_axis_0
simulation_target_generated_flag = true
synthesis_target_generated_flag = true
```

## Packaged-IP XSim 回归

封装后 testbench 实例化 Vivado 生成的 `dbf_axis_0`，复用 Step14.1 Y/Z vectors。

```text
packaged_ip_normal_frame_pass = true
packaged_ip_input_gap_pass = true
packaged_ip_backpressure_pass = true
packaged_ip_backpressure_stability_pass = true
packaged_ip_two_frame_pass = true
packaged_ip_beam_order_pass = true
packaged_ip_status_pass = true
expected_output_rows = 14
actual_output_rows = 14
timeout_flag = false
packaged_ip_tb_pass_flag = true
```

XSim summary：

```text
compile_status = pass
elaboration_status = pass
simulation_status = pass
packaged_ip_xsim_pass_flag = true
```

## MATLAB Exact Compare

Compare 按 `frame_index + beam_id` 对齐封装后 XSim 输出和 Step14.1 expected Z。

```text
comparison_status = pass
expected_rows = 14
actual_rows = 14
matched_rows = 14
missing_count = 0
duplicate_count = 0
tdata_mismatch_count = 0
z_value_mismatch_count = 0
flag_mismatch_count = 0
tlast_mismatch_count = 0
beam_order_mismatch_count = 0
packaged_ip_output_match_flag = true
packaged_ip_compare_pass_flag = true
```

## OOC 综合

Reference device only：

```text
fpga_part = xc7z020clg400-1
clock_MHz = 200
packaged_ip_ooc_synthesis_status = pass
LUT = 3594
FF = 1810
DSP = 28
BRAM18 = 0
BRAM36 = 28
URAM = 0
distributed_RAM = 0
WNS_ns = -8.586
timing_200MHz_met_flag = false
w_memory_inferred_flag = true
implementation_closure_claimed = false
board_validation_flag = false
```

200 MHz post-synthesis timing estimate 未通过，因此不进入 reference BD。

## 最终 Keypoints

```text
custom_ip_packaged_flag = true
step14_2_custom_ip_pass_flag = true
proceed_to_reference_bd_design_flag = false
proceed_to_target_board_dma_flag = false
proceed_to_board_validation_flag = false
proceed_to_full_fpga_backend_flag = false
formal_result_claimed = false
block_design_created_flag = false
bitstream_generated_flag = false
```

Step14.2 pass 表示 custom IP 封装、catalog、封装后 AXI 回归、exact compare、OOC
synthesis 和 W memory inference 通过；它不表示 DMA、PS、BD、bitstream、board、
full backend 或 timing closure 已完成。
