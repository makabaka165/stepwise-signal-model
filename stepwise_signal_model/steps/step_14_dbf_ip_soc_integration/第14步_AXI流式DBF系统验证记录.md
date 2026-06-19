# 第14步 AXI流式DBF系统验证记录

## 定位

Step14.1 实现纯 RTL / Vivado XSim 的 AXI4-Stream DBF 系统数据通路闭环：

```text
Step11-compatible Y/W vectors
-> AXI4-Stream Y source BFM
-> replaceable W ROM provider
-> DBF AXI datapath
-> Step13 B=7 DBF arithmetic core
-> AXI4-Stream Z serializer
-> AXI4-Stream sink/scoreboard
-> CSV
-> MATLAB golden comparison
```

Step13 DBF arithmetic core 仍是 source of truth。Step14.1 不复制、不修改 Step13 RTL，只在 XSim 编译脚本中按相对路径引用稳定 RTL。

## 验证内容

- AXI TVALID/TREADY 握手。
- 输入 valid gap 下 element index 与 W request index 不推进。
- 输出 backpressure 下 tdata/tkeep/tlast 保持稳定。
- TLAST 固定 2080-sample frame 边界。
- W 地址与 Y element index 对齐。
- B=7 输出顺序为 beam 0 到 beam 6。
- 连续两帧之间不 reset，accumulator 自动清零。
- clip/overflow 状态传递。
- early TLAST、missing TLAST、bad TKEEP sticky error 检测。
- RTL Z 输出与 MATLAB golden 精确比较。

## 非目标

本轮不使用 AXI DMA、Zynq PS、DDR、Vivado Block Design、IP Packager、AXI4-Lite、bitstream 或实际开发板。

本轮不声明 DMA 验证、PS 验证、Vivado custom IP 完成、Block Design 完成、板级验证、完整 FPGA backend、CPU ML 接入或 formal closure。

固定记录：

```text
formal_result_claimed=false
dma_validation_flag=false
ps_validation_flag=false
board_validation_flag=false
custom_ip_packaged_flag=false
```

## 下一阶段门禁

只有当 step14_1_axis_system_pass_flag=true 时，才允许进入 Step14.2 IP Packager。DMA reference design、board validation 和 full FPGA backend 仍保持 false。
