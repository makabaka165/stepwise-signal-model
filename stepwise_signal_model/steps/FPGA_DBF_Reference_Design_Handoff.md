# stepwise-signal-model：FPGA DBF Reference Design 收束与交接文档

> **项目**：`makabaka165/stepwise-signal-model`  
> **当前工作分支**：`codex/step14-dbf-ip-soc-integration`  
> **当前状态基线提交**：`61eba29 Complete Step14.3b reference BD timing closure`  
> **上游已冻结分支**：`codex/step13-fpga-soc`  
> **本文用途**：供新的 ChatGPT / Codex 对话快速接手当前 FPGA、Verilog、Vivado Custom IP 与 Reference Block Design 的完整推进状态。  
> **重要边界**：当前 FPGA 只实现 DBF 数据通路；`Rz / G_cache / 2D ML / topK / C05 / confidence / boundary / fallback` 始终由 CPU/SoC 负责。
> **当前收束决策**：若项目目标截止于 DBF RTL、Vivado XSim、Custom IP、板卡无关 Reference BD、参考器件综合/布局布线及时序闭合，则硬件主线已在 `61eba29` 达到阶段性最终收束；目标板 PS/DMA/DDR、bitstream 与上板验证属于可选后续扩展，不是当前收束的缺口。

---

## 1. 一分钟接手摘要

当前项目已经完成以下工程链路：

```text
Step11-compatible W / Y_work
    ↓
MATLAB DBF fixed-point / quantization
    ↓
Verilog DBF arithmetic RTL
    ↓
ACC48 -> fixed shift 20 -> round -> saturate -> Z24
    ↓
Vivado XSim bit-exact regression
    ↓
Vivado Custom IP：user.org:radar:dbf_axis:1.0
    ↓
AXI4-Stream input / output
    ↓
W coefficient ROM
    ↓
Board-independent Vivado Reference Block Design
    ↓
AXIS input FIFO -> DBF IP -> AXIS output FIFO
    ↓
XSim FIFO/backpressure system regression
    ↓
Reference-device synth / place / route
    ↓
200 MHz timing closure with Performance_NetDelay_high
```

当前最终 reference-device 结果：

```text
Vivado                 = 2024.2
Reference part         = xc7z020clg400-1
Clock                  = 200 MHz
Final WNS              = +0.205 ns
Final TNS              = 0.000 ns
Setup failing endpoints= 0
Final WHS              = +0.093 ns
Hold failing endpoints = 0

LUT                    = 2096
FF                     = 5031
DSP                    = 42
BRAM18                 = 1
BRAM36                 = 16
```

当前最终 gates：

```text
step14_3b_reference_bd_timing_closure_flag = true
step14_reference_bd_integration_pass_flag  = true
proceed_to_platform_freeze_flag             = true

proceed_to_target_board_dma_flag            = false
proceed_to_board_validation_flag            = false
proceed_to_full_fpga_backend_flag            = false
bitstream_generated_flag                    = false
xsa_generated_flag                          = false
hwh_generated_flag                          = false
formal_result_claimed                       = false
```

**含义**：

- 当前“FPGA DBF Reference Design”范围已经完成，可以冻结当前硬件主线；
- `proceed_to_platform_freeze_flag=true` 只表示未来若决定上板，可以进入平台选择；不是当前必须继续执行的任务；
- 还不能声称真实开发板、PS、DMA、DDR、bitstream 或板级验证已经完成；
- `proceed_to_full_fpga_backend_flag=false` 是导师确定的架构边界，不是失败：完整 ML 搜索本来就不放 FPGA。

### 1.1 当前范围的正式收束结论

本项目若以以下目标为截止点：

```text
DBF 定点方案
Verilog RTL
full-N bit-exact 验证
AXI4-Stream 数据面
W ROM
Vivado Custom IP
板卡无关 Reference BD
参考器件 synth/place/route
200 MHz timing closure
```

则所有目标均已完成。当前分支可作为：

```text
FPGA DBF Reference Design Integration Closure
```

冻结保存。

以下项目属于**可选后续产品化/板级扩展**，不作为当前收束失败项：

```text
具体开发板
Zynq PS
DDR
AXI DMA
AXI-Lite
Processor System Reset
bitstream
XSA/HWH
上板测试
CPU/SoC 软件联调
```

---

## 2. 总体 FPGA / CPU-SoC 架构边界

### 2.1 FPGA 负责

```text
Y / Y_work 输入流
W coefficient 存储与读取
conj(W) × Y 复数乘法
2080 阵元相干累加
B=7 beam-parallel DBF
ACC48
固定右移 20 bit
对称舍入
signed int24 饱和
clip / overflow
AXI4-Stream Z 输出
```

数学核心：

```text
Z = W^H Y
```

单 beam：

```text
z_b(t) = w_b^H x(t)
```

### 2.2 CPU / SoC 负责

```text
Rz = Z Z^H
G_cache management
beamspace ML 2D candidate search
score ranking
topK
C05 policy
confidence
boundary
fallback
logging
final output wrapper
```

### 2.3 明确不做

当前 FPGA 主线不做：

```text
完整二维 ML 搜索 RTL
G_cache RTL
C05 policy RTL
confidence / boundary / fallback RTL
Step11.7 full backend RTL
完整 FPGA backend
```

---

## 3. Step12 与当前主线的关系

Step12 曾完成 Step11 beamspace ML score-core 的 fixed-point 可行性边界验证：

```text
formal observations        = 1200 / 1200
minimum passing mode       = combined_int24
engineering recommendation = mixed_Z16_G24_Rz24
```

该结论只说明未来可以考虑 ML score-core accelerator，**不是当前 FPGA 实现格式**。

导师后续明确调整工程边界：

```text
FPGA：DBF
CPU/SoC：ML 搜索和策略
```

因此 Step13、Step14 的主线不再是 ML score-core RTL，而是 FPGA DBF + CPU/SoC ML。

---

## 4. 分支关系与冻结规则

```text
codex/step5-fixes
    ↓
codex/step13-fpga-soc
    ↓
codex/step14-dbf-ip-soc-integration
```

规则：

- `codex/step13-fpga-soc` 是 DBF arithmetic engineering closure 基线；
- 当前继续开发分支为 `codex/step14-dbf-ip-soc-integration`；
- Step13 tracked RTL 不应被 Step14 静默修改；
- Step11.7 backend 默认行为从未修改；
- 旧 `codex/step12-fpga-soc` 未迁移进当前实现；
- 不碰 `master`。

---

## 5. 关键提交时间线

### 5.1 Step13：FPGA DBF arithmetic / fixed-point / RTL closure

| Commit | 作用 |
|---|---|
| `f300b3e` | 创建 Step13 FPGA/SoC DBF boundary 与 synthetic quick smoke |
| `ec109c9` | 接入 Step11-compatible `W/Y_work`，得到 `N=2080, B=7, W_method=greedy_combined_B7` |
| `50cc1a1` | 新增 DBF accumulator-level Verilog prototype 与 MATLAB golden |
| `763e7bd` | 增加 Windows 仿真入口与工具链记录 |
| `d819fae` | 使用 Vivado XSim 跑通 raw accumulator；RTL 与 MATLAB exact match |
| `baed3f1` | 实现 Z24 shift / round / saturate RTL，XSim 与 MATLAB exact match |
| `1637556` | 完成 Step13.4 full-N、ACC48、fixed shift、OOC synthesis 工程收束 |

### 5.2 Step14：AXI、Custom IP、Reference BD

| Commit | 作用 |
|---|---|
| `f50723e` | 创建 Step14 DBF IP / SoC integration framework |
| `55ecb06` | Step14.1 纯 RTL AXI4-Stream DBF system smoke |
| `270debf` | Step14.2 Vivado Custom IP packaging |
| `f2b7d58` | Step14.2a 200 MHz timing 与 W ROM 资源优化 |
| `1812da9` | Step14.2b status / boundary / audit hardening 源码提交 |
| `399ae1f` | 刷新 Custom IP package provenance 与验证证据 |
| `5b1b97b` | Step14.3a board-independent Reference BD；功能通过但 200 MHz route timing 差 76 ps |
| `61eba29` | Step14.3b strategy sweep 完成 200 MHz Reference BD timing closure |

---

## 6. Step13 最终工程参数

### 6.1 数据规模

```text
N input channels / elements = 2080
B output beams              = 7
W method                    = greedy_combined_B7
```

### 6.2 定点格式

```text
W       = signed complex int18
Y       = signed complex int16
ACC     = signed complex int48
Z       = signed complex int24
Z shift = 20
```

最终推荐：

```text
engineering_recommended_dbf_format = mixed_W18_Y16_Z24
fallback_dbf_format                = mixed_W24_Y16_Z24
accumulator_width                  = 48
engineering_Z_shift_bits           = 20
```

### 6.3 Step13.4 fixed-shift sweep

```text
planned observations     = 84
completed observations   = 84
headroom bits            = 1
clip count               = 0
overflow count           = 0
worst Z_rel_l2_error     = 4.6644661874251108e-05
worst beam power error   = 1.3554578191520584e-05
worst Rz relative error  = 2.0234182961274521e-05
```

### 6.4 Full-N RTL

```text
N      = 2080
B      = 7
L      = 2
ACC    = 48 bit
Z      = 24 bit
no-gap = pass
gap    = pass
ACC exact match = true
Z24 exact match = true
missing / mismatch = 0 / 0
```

---

## 7. Step13 RTL 模块

目录：

```text
stepwise_signal_model/steps/step_13_fpga_soc_dbf_boundary/rtl/
```

主要模块：

```text
dbf_complex_mac.v
    conj(W) * Y

dbf_beam_accum_core.v
    单 beam、单 snapshot 流式累加

dbf_core_accum.v
    accumulator wrapper

dbf_z24_quantizer.v
    ACC -> shift -> symmetric round -> int24 saturate

dbf_core_z24.v
    单 lane accumulator + Z24

dbf_core_z24_bparallel.v
    B=7 parallel arithmetic top
```

Step13 完成的是：

```text
DBF arithmetic core
```

不是可直接连接 PS/DMA 的完整系统 IP。

---

## 8. Step13 验证链

```text
Step11-compatible MATLAB context
    ↓
W / Y_work
    ↓
integer golden
    ↓
Verilog RTL
    ↓
Vivado XSim
    ↓
CSV
    ↓
MATLAB exact compare
    ↓
Vivado OOC synthesis
```

Step13 最终 B=7 arithmetic reference top（参考器件 `xc7z020clg400-1`）：

```text
LUT      = 3376
FF       = 1345
DSP      = 28
BRAM36   = 0
WNS      = +1.675 ns
```

这里 BRAM 为 0，是因为当时 W 从顶层端口输入，没有包含 W memory subsystem。

---

## 9. Step14.1：AXI4-Stream 数据通路

### 9.1 Y 输入协议

```text
Interface: S_AXIS_Y
TDATA width: 32 bit

bits [15:0]  = signed int16 y_re
bits [31:16] = signed int16 y_im

1 snapshot = 2080 beats
TLAST at element_index = 2079
TKEEP = 4'hF
```

只有：

```text
TVALID && TREADY
```

时：

- element index 推进；
- W address 推进；
- DBF 接受样本。

### 9.2 Z 输出协议

```text
Interface: M_AXIS_Z
TDATA width: 64 bit

bits [23:0]  = signed int24 z_re
bits [47:24] = signed int24 z_im
bit  [48]    = clip_re
bit  [49]    = clip_im
bit  [50]    = overflow_re
bit  [51]    = overflow_im
bits [54:52] = beam_id
bits [63:55] = reserved 0

1 output frame = 7 beats
order = beam 0 ... beam 6
TLAST on beam 6
TKEEP = 8'hFF
```

### 9.3 Step14.1 通过项

```text
normal frame
input valid gap
output backpressure
backpressure signal stability
two consecutive frames
input ready lockout
beam order
early TLAST detection
missing TLAST detection
bad TKEEP detection
14 / 14 exact compare
```

---

## 10. Step14.2：Vivado Custom IP

### 10.1 IP 身份

```text
VLNV         = user.org:radar:dbf_axis:1.0
display name = Step14 DBF AXI Stream
```

目录：

```text
stepwise_signal_model/steps/step_14_dbf_ip_soc_integration/
  ip_repo/dbf_axis_ip_1_0/
```

包含：

```text
component.xml
hdl/
data/
xgui/
source_manifest.csv
package_manifest.csv
```

### 10.2 接口

```text
S_AXIS_Y : AXI4-Stream slave, 32 bit
M_AXIS_Z : AXI4-Stream master, 64 bit
ACLK     : 200 MHz advertised clock
ARESETN  : active-low
```

状态端口：

```text
status_busy
status_frame_count
status_protocol_error
status_early_tlast
status_missing_tlast
status_bad_tkeep
status_clip_seen
status_overflow_seen
```

### 10.3 IP packaging evidence

```text
integrity errors   = 0
integrity warnings = 0
IP Catalog         = pass
create_ip          = pass
generate_target    = pass
packaged XSim      = pass
MATLAB compare     = 14 / 14
```

---

## 11. Step14.2a：流水化与 W ROM 优化

### 11.1 流水化

新增 Step14 integration-specific modules：

```text
dbf_complex_mac_pipe.v
dbf_beam_accum_core_pipe.v
dbf_z24_quantizer_pipe.v
dbf_core_z24_pipe.v
dbf_core_z24_bparallel_pipe.v
dbf_axis_datapath_pipe.v
dbf_axis_system_top_opt.v
```

流水目标：

```text
registered W/Y
-> registered real multipliers
-> registered complex add/sub
-> ACC48
-> pipelined Z24 quantizer
```

吞吐保持：

```text
1 accepted Y sample / cycle
```

### 11.2 W ROM

原始结构：

```text
14 × 2080×18 ROM
```

由于 2080 超过 2048 深度，每个 ROM 占两个 BRAM36：

```text
28 BRAM36
```

优化结构：

```text
每个 component:
  main = 2048×18 block ROM
  tail = 32×18 distributed tail
```

总计：

```text
14 BRAM36
```

W 文件：

```text
7 beams × real/imag × main/tail = 28 .mem files
```

### 11.3 优化后 packaged IP OOC

```text
LUT      ≈ 2059
FF       ≈ 4696
DSP      = 42
BRAM36   = 14
WNS      = +0.377 ns at 200 MHz
```

资源变化属于正常工程权衡：

```text
更多 FF / DSP
换取更短关键路径
同时 BRAM 减半
```

---

## 12. Step14.2b：hardening 与审计

修正和新增：

```text
status_busy 完整 frame 生命周期语义
W provider range / response 对齐
W provider 边界 test
pipelined Z24 quantizer directed + random equivalence
DRC parser 精确统计
source/package SHA256 provenance
```

验证：

```text
status_busy semantics       = pass
W provider boundary         = pass
quantizer equivalence       = pass
random cases                = 1000
source/package hash match   = pass
source worktree dirty       = false
source base commit          = 1812da9
```

正确 optimized DRC count：

```text
DPIP-1 = 0
DPOP-1 = 14
DPOP-2 = 0
ZPS7-1 = 1
```

---

## 13. Step14.3a：Reference Block Design

### 13.1 拓扑

```text
external S_AXIS_Y
    ↓
axis_in_fifo_0
    ↓
dbf_axis_0
    ↓
axis_out_fifo_0
    ↓
external M_AXIS_Z
```

IP cells：

```text
axis_in_fifo_0  = xilinx.com:ip:axis_data_fifo:2.0
dbf_axis_0      = user.org:radar:dbf_axis:1.0
axis_out_fifo_0 = xilinx.com:ip:axis_data_fifo:2.0
```

FIFO：

```text
input FIFO  = 32 bit, depth 64
output FIFO = 64 bit, depth 16
```

没有：

```text
PS
DMA
DDR
AXI-Lite
SmartConnect
bitstream
board constraints
```

### 13.2 Reference BD functional tests

Case A：

```text
2 frames
14 outputs
input gap
output backpressure
exact compare
```

Case B：

```text
4 frames
28 outputs
output initially blocked
backpressure propagates through:
output FIFO -> DBF -> input FIFO -> external source
exact compare
```

结果：

```text
Case A = 14 / 14
Case B = 28 / 28
missing = 0
duplicate = 0
mismatch = 0
input backpressure propagation = true
```

### 13.3 初始 post-route

```text
WNS  = -0.076 ns
TNS  = -0.079 ns
setup failing endpoints = 2
WHS  = +0.096 ns
hold failing endpoints = 0
```

功能通过，timing 未通过，因此提交使用 `Add`，未伪装为 `Complete`。

---

## 14. Step14.3b：Reference BD 200 MHz timing closure

### 14.1 原则

先不改 RTL，针对同一个：

```text
RTL
Custom IP
BD topology
FIFO size
clock
constraints
```

执行 implementation strategy sweep。

只有 sweep 无法达到：

```text
WNS >= +0.100 ns
```

才允许增加 operand pipeline。

### 14.2 实际 sweep

共 9 个 run：

```text
baseline_step14_3a                     WNS -0.076
Performance_Explore                    WNS +0.006
Performance_ExplorePostRoutePhysOpt    WNS +0.006
Performance_Retiming                   WNS -0.226
Performance_NetDelay_high              WNS +0.205
Performance_ExtraTimingOpt             WNS -0.009
Performance_RefinePlacement            WNS -0.091
Performance_WLBlockPlacement           WNS -0.007
Performance_WLBlockPlacementFanoutOpt  WNS -0.052
```

最佳：

```text
Performance_NetDelay_high
```

独立 clean rerun：

```text
pass
```

因此：

```text
Phase A success
Phase B not triggered
operand pipeline added = false
extra latency cycles   = 0
throughput             = 1 sample/cycle
```

### 14.3 最终 post-route

```text
WNS                     = +0.205 ns
TNS                     = 0.000 ns
setup failing endpoints = 0
WHS                     = +0.093 ns
hold failing endpoints  = 0

LUT                     = 2096
FF                      = 5031
DSP                     = 42
BRAM18                  = 1
BRAM36                  = 16
URAM                    = 0
```

当前 Reference BD timing closure 已完成。

### 14.4 Vivado 波形与功能仿真证据

当前已经实际运行 Vivado XSim，并不是只完成了静态代码或综合：

```text
raw accumulator RTL
Z24 quantizer RTL
AXI4-Stream raw top
packaged Custom IP
Reference BD + AXIS FIFO
```

均经过自检 testbench。Reference BD 最终覆盖：

```text
Case A：14 / 14 exact match
Case B：28 / 28 exact match
input gap
output backpressure
backpressure 稳定保持
FIFO 压力与反压传播
连续多帧
TLAST / TKEEP / beam order
```

当前功能正确性的主要证据是：

```text
XSim 输出逐 beat 与 MATLAB golden 精确比较
```

而不是仅靠人工观察波形。

仓库没有长期跟踪：

```text
.wdb
.vcd
xsim.dir
```

这是 artifact 管理策略，不代表没有运行波形仿真。若论文或答辩需要可视化证据，可选补充少量关键波形 PNG，但这不影响当前功能收束结论。

---

## 15. 当前目录导航

### 15.1 Step13

```text
stepwise_signal_model/steps/step_13_fpga_soc_dbf_boundary/
  run_step13_fpga_soc_dbf_boundary.m
  run_step13_4_dbf_engineering_closure.m
  rtl/
  tb/
  sim/
  matlab_golden/
  results_step13_fpga_soc_dbf_boundary/
  README.md
  第13步_DBF工程边界收束报告.md
```

### 15.2 Step14

```text
stepwise_signal_model/steps/step_14_dbf_ip_soc_integration/
  rtl/
  tb/
  sim/
  matlab_vectors/

  ip_repo/
    dbf_axis_ip_1_0/

  vivado/
    package_dbf_axis_ip.*
    validate_dbf_axis_ip.*
    reference_bd/
    reference_bd_timing/

  constraints/

  docs/
    00_SCOPE_AND_STAGE_PLAN.md
    01_MINIMAL_SYSTEM_VALIDATION_CHAIN.md
    02_AXIS_FRAME_PROTOCOL.md
    03_W_MEMORY_AND_COEFFICIENT_LAYOUT.md
    04_MIGRATION_AND_MODEL_NESTING.md
    05_STEP13_REUSE_RULES.md
    06_CUSTOM_IP_PACKAGING.md
    07_TIMING_AND_W_MEMORY_OPTIMIZATION.md
    08_STATUS_AND_AUDIT_HARDENING.md
    09_REFERENCE_BD_INTEGRATION.md
    10_REFERENCE_BD_TIMING_CLOSURE.md

  results_step14_dbf_ip_soc_integration/
    axis_vectors/
    axis_sim/
    axis_opt_sim/
    axis_compare/
    ip_package/
    ip_xsim/
    ip_synth/
    ip_compare/
    reference_bd/
    reference_bd_timing/

  README.md
  第14步_一页式结论摘要.md
```

---

## 16. 主要复现入口

### 16.1 Step13 full engineering closure

```matlab
run('setup_paths.m')
cd('steps/step_13_fpga_soc_dbf_boundary')
run_step13_4_dbf_engineering_closure
```

### 16.2 Step14.1 AXIS smoke

```powershell
cd stepwise_signal_model/steps/step_14_dbf_ip_soc_integration
powershell -ExecutionPolicy Bypass -File sim/run_xsim_step14_1_axis.ps1
```

MATLAB compare：

```matlab
run('setup_paths.m')
cd('steps/step_14_dbf_ip_soc_integration')
run_step14_1_axis_system_validation
```

### 16.3 Custom IP package / validate

```powershell
powershell -ExecutionPolicy Bypass -File vivado/package_dbf_axis_ip.ps1
powershell -ExecutionPolicy Bypass -File vivado/validate_dbf_axis_ip.ps1
```

MATLAB aggregate：

```matlab
run('setup_paths.m')
cd('steps/step_14_dbf_ip_soc_integration')
run_step14_2a_timing_memory_optimization
```

### 16.4 Reference BD

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd/run_step14_3a_reference_bd.ps1
```

MATLAB aggregate：

```matlab
run('setup_paths.m')
cd('steps/step_14_dbf_ip_soc_integration')
run_step14_3a_reference_bd_validation
```

### 16.5 Reference BD timing closure

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd_timing/run_reference_bd_strategy_sweep.ps1
```

MATLAB aggregate：

```matlab
run('setup_paths.m')
cd('steps/step_14_dbf_ip_soc_integration')
run_step14_3b_reference_bd_timing_validation
```

Vivado 2024.2 当前安装入口示例：

```text
E:\Xilinx\Vivado\2024.2\settings64.bat
```

---

## 17. 当前结果的可信层级

### 已完成

```text
MATLAB fixed-point validation
Step11-compatible DBF input
Verilog arithmetic RTL
full-N ACC48 / Z24 verification
Vivado XSim exact compare
AXI4-Stream RTL integration
W ROM
Vivado Custom IP packaging
IP Catalog / create_ip / generate_target
packaged-IP XSim
board-independent Reference BD
AXIS FIFO / backpressure integration
reference-device synth
reference-device place / route
reference-device 200 MHz timing closure
```

### 未完成但属于可选后续扩展

以下内容只有在项目明确要求真实上板或产品化时才需要继续，不阻塞当前 Reference Design 收束：

```text
真实目标开发板冻结
真实 target part 验证
Zynq PS
DDR
AXI DMA
AXI-Lite control/status
Processor System Reset
Clocking Wizard / board clocks
bitstream
XSA / HWH
bare-metal / Linux software
cache coherency
PS-visible DMA loopback
target-board timing
JTAG / hardware manager
ILA
板级 golden compare
CPU/SoC ML 软件接入
```

---

## 18. 当前 flags 的正确解释

```text
proceed_to_platform_freeze_flag=true
```

说明可以开始确定真实平台参数。

```text
proceed_to_target_board_dma_flag=false
```

说明还没有确定和验证真实开发板、PS、DDR 和 DMA 系统。

```text
proceed_to_board_validation_flag=false
```

说明没有 bitstream 和真实板卡运行。

```text
proceed_to_full_fpga_backend_flag=false
```

这是工程边界：完整 ML backend 不放 FPGA，不应为了“变 true”而继续增加 ML RTL。

```text
formal_result_claimed=false
```

说明当前证据是工程仿真、综合和 route，不是形式化证明。

---

## 19. 可选未来扩展：平台冻结与板级集成

当前硬件主线可以在 `61eba29` 收束。只有在后续明确要求：

```text
真实开发板演示
PS/DDR/DMA 联调
bitstream
板级运行
```

时，才需要进入平台冻结。

届时需确定：

```text
1. 开发板精确型号
2. FPGA / SoC part
3. Zynq-7000 或 Zynq UltraScale+
4. Vivado board file
5. PS DDR
6. PS FCLK 与 PL DBF clock
7. bare-metal 或 Linux
8. AXI DMA simple mode 或 scatter-gather
9. MM2S / S2MM buffer layout
10. cache flush / invalidate 或 Linux DMA API
11. interrupt 或 polling
12. Y 来自 DDR replay 还是 PL 前端实时流
```

平台冻结后才建议：

```text
新建板卡专用分支：
codex/step14-<board-name>-dma

新增：
steps/step_14_dbf_ip_soc_integration/platforms/<board-name>/
  vivado/
  constraints/
  software/
  results/
```

第一条可选真实平台链路：

```text
PS/DDR 保存 Y test vector
    ↓
AXI DMA MM2S
    ↓
DBF IP
    ↓
AXI DMA S2MM
    ↓
PS/DDR Z buffer
    ↓
CPU / host 与 MATLAB golden 比较
```

该链路通过后，CPU/SoC 才继续执行：

```text
Z -> Rz -> G_cache -> 2D ML -> topK -> C05 -> confidence/boundary/fallback
```

如果论文/项目范围不要求上板，则本节全部作为 future work，不需要继续执行。

---

## 20. 不应做的下一步

不要在平台未确定时：

```text
硬编码某块开发板
生成 bitstream
假定 PS preset
假定 DDR 地址
写不可迁移 DMA 驱动
把 ML 搜索加入 FPGA RTL
修改 Step13 closed arithmetic core
修改 Step11.7 backend 默认行为
```

---

## 20.1 已知非阻塞审计注意事项

以下内容不推翻当前 timing closure，但新对话应避免误读：

1. `Performance_ExplorePostRoutePhysOpt` 对应 run 只执行到 `route_design`，不能仅凭策略名称声称实际执行了 post-route phys-opt。
2. Phase B 没有触发，因此当前 `mac_pipe_equivalence_pass_flag=true` 的工程含义是“该项不适用且不阻塞 gate”，不是新 MAC RTL 再次运行 equivalence test。
3. Reference BD 的 200 MHz closure 是 `xc7z020clg400-1` reference-device 内部逻辑 closure；外部 AXIS 尚无真实平台 I/O delay。
4. 未来换真实 FPGA part 或开发板后必须重新 synth/place/route，不得直接继承 `+0.205 ns`。
5. 证据优先级：

```text
step14_3b_reference_bd_timing_keypoints.csv
    >
step14_3b_best_strategy_clean_rerun_summary.csv
    >
step14_3b_strategy_sweep.csv
    >
Markdown 描述
```

---

## 21. Artifact 与仓库卫生

截至 `61eba29`：

```text
git status --short = clean
```

没有 tracked：

```text
.xpr
.bd
.dcp
.bit
.xsa
.hwh
.wdb
.vcd
.runs
.cache
.gen
.Xil
```

没有：

```text
>10MB tracked file
>50MB tracked artifact
```

Vivado 工程和 run directory 均应通过 Tcl 重建，不应直接提交。

---

## 22. 当前最重要的证据文件

### Step13

```text
steps/step_13_fpga_soc_dbf_boundary/
  results_step13_fpga_soc_dbf_boundary/
    step13_4_closure/step13_4_closure_keypoints.csv
    step13_4_shift_policy/step13_4_shift_keypoints.csv
    rtl_fulln_sim/step13_4_fulln_compare_summary.csv
    synth/step13_4_ooc_synthesis_summary.csv
```

### Step14

```text
steps/step_14_dbf_ip_soc_integration/
  results_step14_dbf_ip_soc_integration/
    axis_compare/step14_1_axis_keypoints.csv
    ip_compare/step14_2a_optimized_ip_keypoints.csv
    reference_bd/step14_3a_reference_bd_keypoints.csv
    reference_bd_timing/step14_3b_reference_bd_timing_keypoints.csv
    reference_bd_timing/step14_3b_strategy_sweep.csv
```

最终状态优先以：

```text
reference_bd_timing/step14_3b_reference_bd_timing_keypoints.csv
```

为准。

---

## 23. 可直接粘贴给新对话的接手提示

```text
请继续分析 GitHub 项目 makabaka165/stepwise-signal-model。

当前工作分支：
codex/step14-dbf-ip-soc-integration

当前状态基线提交：
61eba29 Complete Step14.3b reference BD timing closure

请不要切分支，不要碰 master，不要修改 Step13 frozen RTL，也不要修改 Step11.7 backend 默认行为。

当前工程边界：
- FPGA 只做 DBF：Z = W^H Y
- 格式：W18 / Y16 / ACC48 / Z24
- fixed shift = 20
- N=2080, B=7
- CPU/SoC 负责 Rz、G_cache、2D ML、topK、C05、confidence、boundary、fallback

已完成：
- Step11-compatible MATLAB fixed-point
- full-N Verilog DBF
- XSim exact compare
- AXI4-Stream Y/Z
- W ROM
- Vivado Custom IP user.org:radar:dbf_axis:1.0
- board-independent Reference BD
- input FIFO -> DBF IP -> output FIFO
- Case A 14/14、Case B 28/28 exact compare
- Reference-device synth/place/route
- 200 MHz timing closure

最终 Reference BD：
- part = xc7z020clg400-1 reference only
- strategy = Performance_NetDelay_high
- WNS = +0.205 ns
- TNS = 0
- setup failures = 0
- WHS = +0.093 ns
- LUT=2096, FF=5031, DSP=42, BRAM18=1, BRAM36=16

最终 flags：
- step14_reference_bd_integration_pass_flag=true
- proceed_to_platform_freeze_flag=true
- proceed_to_target_board_dma_flag=false
- proceed_to_board_validation_flag=false
- proceed_to_full_fpga_backend_flag=false
- formal_result_claimed=false

当前硬件主线已经在 Reference Design 范围内收束。请先读取：
- Step14 README
- docs/10_REFERENCE_BD_TIMING_CLOSURE.md
- reference_bd_timing/step14_3b_reference_bd_timing_keypoints.csv
- reference_bd_timing/step14_3b_best_strategy_clean_rerun_summary.csv
- reference_bd_timing/step14_3b_strategy_sweep.csv

除非用户明确要求真实上板、PS/DMA/DDR 或 bitstream，否则不要继续推进平台冻结或板卡集成。若用户要求上板，在开发板、part、PS/DDR、FCLK、OS 和 DMA 模式未明确前，不要生成目标板 bitstream，不要直接写板卡 DMA 集成。
```

---

## 24. 当前最终结论

### 当前范围已经完成

项目已经完成：

> **FPGA DBF arithmetic、full-N Verilog bit-exact 验证、AXI4-Stream 数据面、Vivado Custom IP、板卡无关 Reference Block Design，以及 reference-device 200 MHz post-route timing closure。**

因此，如果当前项目目标截止于：

```text
仿真
RTL
IP 封装
Reference BD
参考器件实现与时序
```

则可以在 `61eba29` 正式收束，不需要为了“完整”而继续做开发板、DMA 或 bitstream。

### 可选但尚未完成的扩展

```text
真实开发板平台
PS/DDR/DMA
AXI-Lite
bitstream
XSA/HWH
板级运行
CPU/SoC 软件与 ML 联调
```

这些属于 future work，不是当前 FPGA DBF Reference Design 的缺口。

### 准确阶段名称

```text
FPGA DBF Reference Design Integration Closure
```

不得夸大为：

```text
Complete FPGA backend
Target-board validation
Full FPGA/SoC system complete
Formal closure
```

