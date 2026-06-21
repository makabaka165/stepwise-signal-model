# 第14步 Custom IP 时序与 W 存储优化记录

## 目标

Step14.2a 在不修改 Step13 tracked RTL、不引入 DMA/PS/Block Design/bitstream
的前提下，对 Step14.2 已封装的 DBF AXI4-Stream Custom IP 做 200 MHz OOC
时序和 W ROM 资源优化。

## 实现

- 新增 pipelined MAC：输入、乘法、复数加减分阶段寄存。
- 新增 pipelined Z24 quantizer：保持 Step13 rounding/saturation 数值规则，
  将 abs、round/shift、clip 判定、输出 mux 分阶段。
- 新增 split W ROM：每个 beam real/imag 分成 2048-row main 和 32-row tail。
- Custom IP 顶层仍为 `user.org:radar:dbf_axis:1.0`，内部改接
  `dbf_axis_system_top_opt`。
- packaged W `.mem` 文件数从 14 改为 28。

## 验证

```text
optimized_raw_top_xsim_pass_flag=true
packaged_ip_xsim_pass_flag=true
packaged_ip_output_match_flag=true
expected_rows=14
actual_rows=14
matched_rows=14
w_split_reconstruction_match_flag=true
```

参考器件 OOC synthesis：

```text
part=xc7z020clg400-1
old_WNS_ns=-8.586
new_WNS_ns=0.377
new_TNS_ns=0.000
new_failing_endpoints=0
old_BRAM36_equiv=28
new_BRAM36_equiv=14.000
old_LUT=3594
new_LUT=2155
old_FF=1810
new_FF=4695
old_DSP=28
new_DSP=42
```

## 结论

```text
step14_2a_optimization_pass_flag=true
proceed_to_reference_bd_design_flag=true
proceed_to_target_board_dma_flag=false
proceed_to_board_validation_flag=false
proceed_to_full_fpga_backend_flag=false
custom_ip_packaged_flag=true
formal_result_claimed=false
block_design_created_flag=false
bitstream_generated_flag=false
xsa_generated_flag=false
hwh_generated_flag=false
```

本记录不声明 DMA、PS、DDR、Block Design、bitstream、XSA、HWH、板级验证、
完整 FPGA backend、implementation closure 或 formal closure。
