# 步骤映射

| 步骤 | 目标 | 入口脚本 | 主要依赖 |
| --- | --- | --- | --- |
| 1 | 单通道 `LFM`、单目标回波与脉压 | `steps/step_01_lfm_pc/demo_lfm_pc.m` | `core/config/sim_cfg.m`、`core/waveform/tx_lfm.m`、`core/echo/echo_1ch.m`、`core/range/pc_range.m` |
| 2 | 阵元级单脉冲回波与脉压 | `steps/step_02_elem_pc/demo_elem_pc.m` | 第 1 步 + `core/array/arr_cyl.m`、`core/echo/echo_elem.m` |
| 3 | 方位粗波束形成验证 | `steps/step_03_az_bf/demo_az_bf.m` | 第 2 步 + `core/beamforming/build_sector_beam_grid.m`、`core/beamforming/bf_azimuth.m` |
| 4 | 俯仰粗波束形成验证 | `steps/step_04_el_bf/demo_el_bf.m` | 第 2 步 + `core/beamforming/build_sector_beam_grid.m`、`core/beamforming/bf_elevation.m` |
| 5 | 二维联合波束形成、`MTD` 与 `1D CA-CFAR` | `steps/step_05_joint_2d_mtd/demo_joint_2d_mtd.m` | `core/echo/echo_elem_cube.m`、`core/range/pc_range_cube.m`、`core/beamforming/build_joint_beam_grid.m`、`core/beamforming/build_sector_beam_grid.m`、`core/beamforming/bf_joint_2d.m`、`core/doppler/mtd_process.m`、`core/detect/detect_rd_cfar_1d.m` |
| 6.5 | 跨 `CPI` 的单目标局部跟踪闭环（偏跟踪扩展） | `steps/step_06_5_cpi_track/demo_cpi_track.m` | 第 5 步 + `core/tracking/run_track_loop_single_target.m` |

说明：

- 编号为 `x.5` 的部分用于记录修改、分析、拓展或工作量补充内容。
- `x.5` 部分不默认视为当前全息凝视探测主链的必需步骤。

## 核心模块

- `core/config/`：公共配置
- `core/array/`：阵列几何
- `core/waveform/`：发射波形
- `core/echo/`：回波生成
- `core/range/`：距离压缩
- `core/beamforming/`：方位、俯仰与二维联合波束形成
- `core/doppler/`：慢时间 `MTD`
- `core/detect/`：`CFAR` 检测
- `core/tracking/`：跨 `CPI` 的最小跟踪闭环扩展

## 角度与波束排布规则

- `cfg.tgt.az` 和 `cfg.tgt.el` 是目标真值角。
- `cfg.beam.azSectorCenter` 和 `cfg.beam.elSectorCenter` 是当前扇区中心，用于选择工作子阵并排布波束网格。
- 当前验证默认令扇区中心等于目标真值角。
- 工程应用中，扇区中心应来自粗搜索或扇区调度结果。
- 方位规则：测扇区中心参考方位波束的 `3 dB` 宽度，并将其作为 `dAz`。
- 俯仰规则：在 `u = sin(theta)` 域直接测扇区中心参考俯仰波束的 `3 dB` 宽度，并将其作为 `dU`。
- 网格排布规则：方位和俯仰波束网格都先测扇区中心参考波束宽度，再从各自扫描边界的左侧开始按固定间隔排布。
