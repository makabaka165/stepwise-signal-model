# 步骤映射

| 步骤 | 目标 | 入口脚本 | 主要依赖 |
| --- | --- | --- | --- |
| 1 | 单通道 `LFM`、单目标回波与脉压 | `steps/step_01_lfm_pc/demo_lfm_pc.m` | `core/config/sim_cfg.m`、`core/waveform/tx_lfm.m`、`core/echo/echo_1ch.m`、`core/range/pc_range.m` |
| 2 | 阵元级单脉冲回波与脉压 | `steps/step_02_elem_pc/demo_elem_pc.m` | 第 1 步 + `core/array/arr_cyl.m`、`core/echo/echo_elem.m` |
| 3 | 方位粗波束形成验证 | `steps/step_03_az_bf/demo_az_bf.m` | 第 2 步 + `core/beamforming/build_sector_beam_grid.m`、`core/beamforming/bf_azimuth.m` |
| 4 | 俯仰粗波束形成验证 | `steps/step_04_el_bf/demo_el_bf.m` | 第 2 步 + `core/beamforming/build_sector_beam_grid.m`、`core/beamforming/bf_elevation.m` |
| 5 | 局部五波束、`MTD` 与公式门限 `1D CA-CFAR`，输出最强 `metric` 检测单元 | `steps/step_05_joint_2d_mtd/demo_joint_2d_mtd.m` | 独立脚本内 local functions；`CFAR` 逻辑与 `FuncCFARBase.CFAR01` 保持一致 |
| 5.5 | 本次修改前的第 5 步目录备份（默认不加入 MATLAB 路径） | `steps/step_05_5_joint_2d_mtd/demo_joint_2d_mtd.m` | 当前第 5 步目录修改前的备份 |
| 6 | 第 5 步检测单元上的三波束比幅测角 | `steps/step_06_three_beam_angle/demo_three_beam_angle_standalone.m` | 第 5 步独立链路 + 鉴角曲线 |
| 7 | 空间平滑 `MUSIC` 超分辨测角 | `steps/step_07_space_smooth_music/space_smooth_music.m` | `steps/step_07_space_smooth_music/mssp.m`、`steps/step_07_space_smooth_music/FindLocalPeak_Fun.m`、`steps/step_07_space_smooth_music/DOA_three_music_hecheng_fangzhen.m` |
| 8 | 虚拟阵元的波束级 `MUSIC` 构造（`virtual_array_beamspace_MUSIC`） | `steps/step_08_virtual_array_beamspace_MUSIC/` | 虚拟阵元构造、波束域投影与 `beamspace MUSIC` 路线整理 |
| 9 | 跨 `CPI` 的单目标局部跟踪闭环（偏跟踪扩展） | `steps/step_09_cpi_track/demo_cpi_track.m` | 局部量测前端 + `core/tracking/run_track_loop_single_target.m` |

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
# Current Final Route Map

The final thesis-facing route is now:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

Current Step positioning:

| Step | Current role |
| --- | --- |
| Step8.7 | verified lazy cascade backend and final performance evidence |
| Step8.8 | frontend closure evidence |
| Step8.9 | hardware boundary evidence |
| Step8.10 | negative unified model selection evidence |
| Step9 | archived diagnostics / thesis interface notes |
| Step10 | final thesis route |

Step10 path:

```text
steps/step_10_final_thesis_route/
```

Step09 is no longer a backend tuning mainline.
