# 第14步 Custom IP 状态语义与审计加固记录

## Step14.2b 范围

本轮只加固 Step14.2a 的状态语义、provenance 和 directed regression。

未新增：

- DMA
- Zynq PS
- Vivado Block Design
- AXI-Lite
- bitstream
- 板级验证
- full FPGA backend
- formal closure

## status_busy 修正

`dbf_axis_datapath.v` 和 `dbf_axis_datapath_pipe.v` 新增 `frame_active`：

```text
首次 sample_accept: frame_active = 1
最后一个 Z beat 被接受: frame_active = 0
status_busy = frame_active || (state != ST_RX) || serializer_busy
```

baseline、optimized raw top 和 packaged-IP TB 均记录：

- busy_low_after_reset
- busy_high_from_first_y_accept
- busy_high_during_drain
- busy_high_during_output_backpressure
- busy_low_after_final_z_accept

## W provider 边界测试

`tb_dbf_w_provider_rom_opt_boundary.v` 覆盖：

- addr 0
- addr 2047
- addr 2048
- addr 2079
- addr 2080 invalid
- request gap
- back-to-back main/tail requests

要求 response 正好一周期，invalid request 不产生有效 response。

## Quantizer pipeline 等价性

`tb_dbf_z24_quantizer_pipe_equiv.v` 同时实例化 Step13 `dbf_z24_quantizer`
和 Step14 `dbf_z24_quantizer_pipe`，用 4-cycle scoreboard 对齐。

覆盖 directed boundary、valid gaps、back-to-back valid 和 1000 个
deterministic pseudo-random ACC48 输入。

## DRC 统计口径

不再使用 rule 名称出现次数统计。新的 parser 从 summary table 读取
`Rule | Severity | Description | Checks`，并与 detail 标题 `RULE#N` 交叉检查。

正确计数：

```text
baseline:  DPIP-1=42, DPOP-1=28, DPOP-2=28, ZPS7-1=1
optimized: DPIP-1=0,  DPOP-1=14, DPOP-2=0,  ZPS7-1=1
```

## Package provenance

package manifest 新字段：

```text
source_path
packaged_path
role
source_base_commit
source_worktree_dirty
source_size_bytes
packaged_size_bytes
source_sha256
packaged_sha256
content_match
```

每个 HDL/MEM 文件 copy 后检查 source/package size 和 SHA256 完全一致。
非空文件不得出现空文件 SHA256。

第二阶段刷新 package 时必须从干净工作区运行，使：

```text
source_base_commit = 第一阶段 hardening commit
source_worktree_dirty = false
```
