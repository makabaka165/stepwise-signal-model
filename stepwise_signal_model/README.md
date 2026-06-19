# 分步信号模型

## 1. 目的

`stepwise_signal_model` 将主雷达处理链拆成可以独立验证的多个步骤。当前重点是把下面这条链路做得清晰、可运行、可检查：

```text
LFM 发射 -> 回波建模 -> 距离压缩 -> 阵元级建模 -> 方位接收波束形成 -> 俯仰接收波束形成 -> 二维联合波束形成 + MTD + CFAR
第 6 步 -> 在第 5 步检测单元上做三波束比幅测角
第 7 步 -> 空间平滑 MUSIC 超分辨测角
第 8 步 -> 虚拟阵元的波束级 MUSIC 构造
第 9 步（偏跟踪扩展） -> 跨 CPI 局部跟踪与波束调度
```

代码按两层组织：

- `core/`：按功能划分的可复用函数
- `steps/`：各步骤的演示脚本入口，每一步只保留自己的 demo

## 2. 目录结构

```text
stepwise_signal_model/
  setup_paths.m
  README.md
  docs/
    STEP_MAP.md
  core/
    config/
      sim_cfg.m
    array/
      arr_cyl.m
    waveform/
      tx_lfm.m
    echo/
      echo_1ch.m
      echo_elem.m
      echo_elem_cube.m
    range/
      pc_range.m
      pc_range_cube.m
    beamforming/
      bf_azimuth.m
      bf_elevation.m
      bf_joint_2d_step5.m
      bf_joint_2d.m
      build_sector_beam_grid.m
      build_joint_beam_grid.m
      analyze_reference_beam.m
      measure_scan_3db_width.m
    doppler/
      mtd_process.m
    detect/
      FuncCFARBase.m
      detect_rd_cfar_1d.m
    tracking/
      run_track_loop_single_target.m
  steps/
    step_01_lfm_pc/
      demo_lfm_pc.m
    step_02_elem_pc/
      demo_elem_pc.m
    step_03_az_bf/
      demo_az_bf.m
    step_04_el_bf/
      demo_el_bf.m
    step_05_joint_2d_mtd/
      demo_joint_2d_mtd.m
    step_05_5_joint_2d_mtd/
      demo_joint_2d_mtd.m
    step_06_three_beam_angle/
      demo_three_beam_angle_standalone.m
    step_07_space_smooth_music/
      space_smooth_music.m
      mssp.m
      FindLocalPeak_Fun.m
      DOA_three_music_hecheng_fangzhen.m
    step_08_virtual_array_beamspace_MUSIC/
    step_09_cpi_track/
      demo_cpi_track.m
```

## 3. 运行方式

方式 1：先运行 `setup_paths.m`，再运行目标 demo。

```matlab
run('E:\matlab_code\bishe_quanxi\stepwise_signal_model\setup_paths.m')
demo_joint_2d_mtd
```

方式 2：直接打开 `steps/` 下的某个 demo 运行。独立脚本不依赖路径设置；调用 `core/` 函数的 demo 会在开头调用 `setup_paths.m`。

## 4. 步骤概览

- `step_01_lfm_pc`：单通道 `LFM + 回波 + 脉压`
- `step_02_elem_pc`：阵元级单脉冲回波与脉压验证
- `step_03_az_bf`：方位接收波束形成验证
- `step_04_el_bf`：俯仰接收波束形成验证
- `step_05_joint_2d_mtd`：二维联合波束形成、`MTD` 与 `1D CA-CFAR` 粗检测
- `step_05_5_joint_2d_mtd`：本次修改前的第 5 步目录备份，默认不加入 MATLAB 路径
- `step_06_three_beam_angle`：在第 5 步最强检测单元上做三波束比幅测角
- `step_07_space_smooth_music`：空间平滑 `MUSIC` 超分辨测角
- `step_08_virtual_array_beamspace_MUSIC`：虚拟阵元的波束级 `MUSIC` 构造与路线整理
- `step_09_cpi_track`：跨 `CPI` 的单目标局部跟踪与下一 `CPI` 波束调度
  （偏跟踪扩展，当前不作为全息凝视探测主流程的必需步骤）

详细的“步骤 - 脚本 - 函数”对应关系见 [docs/STEP_MAP.md](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/docs/STEP_MAP.md)。

## 5. 第 1 步到第 9 步

说明：

- 编号为 `x.5` 的部分用于记录修改、分析、拓展或工作量补充内容。
- `x.5` 部分不默认视为当前主链中的必需步骤。

### 5.1 第 1 步：LFM 发射与单通道脉压

相关文件：

- `core/config/sim_cfg.m`
- `core/waveform/tx_lfm.m`
- `core/echo/echo_1ch.m`
- `core/range/pc_range.m`
- `steps/step_01_lfm_pc/demo_lfm_pc.m`

本步实现内容：

- 基本波形参数配置
- 单通道目标回波模型
- 距离压缩与距离轴验证

核心想法：

- 先用最简单的单通道形式把距离链路验证清楚

操作流程概览：

- 先生成一个发射 `LFM` 脉冲
- 再生成单通道目标回波
- 再对回波做距离向脉压
- 最后检查距离像主峰位置和距离轴是否正确

如果把第 1 步浓缩成一句话

第 1 步是在做：

- 先生成单个发射 `LFM`
- 再生成单通道目标回波
- 再做距离向脉压
- 最后验证距离像主峰位置和距离轴是否正确

### 5.2 第 2 步：阵元级单脉冲回波与脉压

相关文件：

- `core/array/arr_cyl.m`
- `core/echo/echo_elem.m`
- `core/range/pc_range.m`
- `steps/step_02_elem_pc/demo_elem_pc.m`

本步实现内容：

- 圆柱阵几何建模
- 各阵元到目标的距离、双程时延与双程相位
- 阵元级回波矩阵 `echoMat(element, fast-time)`
- 阵元级脉压矩阵 `pcMat(element, range)`

核心想法：

- 在做任何波束形成之前，先确认阵元级建模是正确的

操作流程概览：

- 先生成圆柱阵的当前工作子阵几何
- 再按阵元差异生成单脉冲阵元级回波
- 再组成 `echoMat(element, fast-time)`
- 再逐阵元做距离向脉压
- 最后得到后续波束形成要用的 `pcMat(element, range)`

如果把第 2 步浓缩成一句话

第 2 步是在做：

- 先生成当前工作子阵的阵列几何
- 再生成单脉冲阵元级回波
- 再组成 `阵元 × 快时间` 的回波矩阵
- 再逐阵元做距离向脉压
- 最后得到 `阵元 × 距离` 的脉压结果，供后续波束形成使用

### 5.3 第 3 步：方位接收波束形成

相关文件：

- `core/beamforming/bf_azimuth.m`
- `core/beamforming/build_sector_beam_grid.m`
- `steps/step_03_az_bf/demo_az_bf.m`

本步实现内容：

- 在当前工作子阵扇区内做方位粗扫描
- 用幅度窗和导向相位构造接收权值
- 沿阵元维做相干叠加
- 形成波束域距离图 `beamMat(beam, range)`
- 在最强粗波束附近选取三波束候选组

核心想法：

- 把 `pcMat(element, range)` 转成 `beamMat(beam, range)`
- 在固定工作子阵内部完成波束搜索

操作流程概览：

- 先测扇区中心参考方位波束的 `3 dB` 宽度
- 再把这个宽度作为方位波束间隔 `dAz`
- 再从当前方位扫描边界的左侧开始按固定间隔生成方位波束网格
- 再用幅度加权和导向相位构造方位接收权
- 再沿阵元维做相干叠加
- 最后得到方位波束域距离图，并选出最强波束附近的候选波束

如果把第 3 步浓缩成一句话

第 3 步是在做：

- 先测扇区中心参考方位波束的 `3 dB` 宽度
- 再用这个宽度作为相邻方位波束间隔
- 再从当前方位扫描边界的左侧开始按固定间隔排布方位波束网格
- 再对 `阵元 × 距离` 数据做方位接收波束形成
- 最后得到 `方位波束 × 距离` 的结果，并找出最强波束附近的候选波束

### 5.4 第 4 步：俯仰接收波束形成

相关文件：

- `core/beamforming/bf_elevation.m`
- `core/beamforming/build_sector_beam_grid.m`
- `steps/step_04_el_bf/demo_el_bf.m`

本步实现内容：

- 在 `u = sin(theta)` 域生成俯仰波束网格
- 在方位处理之后继续做俯仰接收波束形成
- 比较俯仰候选波束

核心想法：

- 在方位波束形成之后继续完成空间链路
- 为二维空间处理做准备

操作流程概览：

- 先测扇区中心参考俯仰波束在 `u = sin(theta)` 域里的宽度
- 再把这个宽度作为俯仰波束间隔 `dU`
- 再从当前俯仰扫描边界的左侧开始在 `u` 域按固定间隔生成俯仰波束网格
- 再做俯仰接收波束形成
- 最后比较俯仰候选波束并完成二维空间处理前的准备

如果把第 4 步浓缩成一句话

第 4 步是在做：

- 先测扇区中心参考俯仰波束在 `u` 域里的 `3 dB` 宽度
- 再用这个宽度作为相邻俯仰波束间隔
- 再从当前俯仰扫描边界的左侧开始按固定间隔排布俯仰波束网格
- 再做俯仰接收波束形成
- 最后完成二维空间处理前的俯仰维准备

### 5.5 第 5 步：二维联合波束形成、MTD 与 CFAR

相关文件：

- `core/echo/echo_elem_cube.m`
- `core/range/pc_range_cube.m`
- `core/beamforming/bf_joint_2d_step5.m`
- `core/beamforming/build_joint_beam_grid.m`
- `core/beamforming/build_sector_beam_grid.m`
- `core/doppler/mtd_process.m`
- `core/detect/FuncCFARBase.m`
- `core/detect/detect_rd_cfar_1d.m`
- `steps/step_05_joint_2d_mtd/demo_joint_2d_mtd.m`

本步实现内容：

- 阵元级多脉冲回波立方体
- 回波立方体上的距离压缩
- 二维联合波束形成
- 跨脉冲的多普勒处理
- 基于 `1D CA-CFAR` 的粗距离-多普勒检测

核心想法：

- 在一个 `CPI` 内固定工作子阵
- 把单脉冲空间链路扩展成多脉冲数据立方体
- 再在波束域输出上做 `MTD` 和检测
- 当前第 5 步和第 6 步使用可读性优先的独立脚本；第 9 步继续使用 `core/beamforming/bf_joint_2d.m` 作为跨 `CPI` 先验引导前端。
- 当前可读性优先的实现说明：第 5 步独立脚本一次性计算局部五波束，没有使用 block 处理。如果后续波束数、脉冲数或处理距离窗变大，可以再引入 block 方案降低峰值内存。
- 当前验证流程说明：第 5 步 demo 和 `bf_joint_2d_step5` 按单目标场景处理，中心束 `CFAR` 后不做检测单元聚类，直接取 raw CFAR 中 `metric` 最大的单点。
- 当前 `CFAR` 门限系数由 `alpha = Nref * (Pfa^(-1/Nref) - 1)` 计算，默认 `Pfa = 1e-6`。

操作流程概览：

- 先生成原始多脉冲阵元回波立方体 `echoCube(element, fast-time, pulse)`
- 再逐脉冲做距离压缩，得到 `pcCube(element, range, pulse)`
- 再围绕中心束构造局部五个唯一二维接收权
- 再做局部五波束形成，得到 `beamCube(beam, range, pulse)`
- 再沿脉冲维做 `MTD`，得到 `rdCube(beam, range, doppler)`
- 再对中心束 `RD` 图做沿距离维的 `1D CA-CFAR`
- 最后取 raw CFAR 中 `metric` 最大的检测单元作为第 5 步输出

如果把整个第 5 步浓缩成一句话

第 5 步是在做：

- 先生成 `阵元 × 快时间 × 脉冲` 的原始多脉冲数据
- 再做脉压，变成 `阵元 × 距离 × 脉冲`
- 再做二维联合波束形成，变成 `二维波束 × 距离 × 脉冲`
- 再沿脉冲做 `MTD`，变成 `二维波束 × 距离 × 多普勒`
- 再对每个二维波束的 `RD` 图做 `1D CA-CFAR`
- 最后同时给你看：
- 不加 `CFAR` 时，纯幅度最强的结果
- 加了 `CFAR` 后，检测意义下最强的结果

### 5.6 第 6 步：三波束比幅测角

相关文件：

- `steps/step_06_three_beam_angle/demo_three_beam_angle_standalone.m`

本步实现内容：

- 沿用第 5 步的阵元回波、脉压、局部五波束、`MTD` 和中心束 `CFAR`
- 从 raw `CFAR` 中选取 `metric` 最大的检测单元
- 在这个距离-多普勒单元上读取方位 `[左, 中, 右]` 三束幅度
- 在同一个单元上读取俯仰 `[下, 中, 上]` 三束幅度
- 构造方位和俯仰的鉴角曲线，并按实测比幅量反查角度

核心比幅量为：

$$
\rho_{az} = \frac{A_R - A_L}{A_R + A_L}
$$

$$
\rho_{el} = \frac{A_U - A_D}{A_U + A_D}
$$

其中 `A_L / A_R` 是方位左/右束幅度，`A_D / A_U` 是俯仰下/上束幅度。

### 5.7 第 7 步：空间平滑 MUSIC 超分辨测角

相关文件：

- `steps/step_07_space_smooth_music/space_smooth_music.m`
- `steps/step_07_space_smooth_music/mssp.m`
- `steps/step_07_space_smooth_music/FindLocalPeak_Fun.m`
- `steps/step_07_space_smooth_music/DOA_three_music_hecheng_fangzhen.m`

本步实现内容：

- 构造双目标仿真场景并评估不同角间隔下的超分辨测角效果
- 对波束级合成数据执行空间平滑 `MUSIC`
- 用局部峰值搜索从空间谱中提取主峰方向

核心想法：

- 先通过波束合成把目标限制在局部角域
- 再用 `MSSP` 空间平滑缓解相干信号导致的协方差矩阵退化
- 最后在局部搜索区间内用 `MUSIC` 谱峰完成超分辨角度估计

### 5.8 第 8 步：虚拟阵元的波束级 MUSIC 构造

当前状态说明：

- 第 8 步用于承接 `virtual_array_beamspace_MUSIC` 这一路线
- 当前定位是“虚拟阵元 + 波束级 `MUSIC`”相关处理思路的独立步骤编号
- 重点是把局部角域内的虚拟阵元构造、波束域投影与 `MUSIC` 测角路线单独列出来
- 它与第 7 步的空间平滑 `MUSIC` 路线相邻，但更强调虚拟阵元和波束级构造含义

相关文件关系：

- 当前步骤目录是 `steps/step_08_virtual_array_beamspace_MUSIC/`
- 步骤名称用于表示“virtual array beamspace MUSIC”这一类方法

本部分关注的扩展目标：

- 在步骤编号上单独留出“虚拟阵元的波束级 `MUSIC` 构造”位置
- 便于后续把相关脚本、说明和实验结果逐步归并到这一目录下
- 让后续文档中的 `beamspace MUSIC` 路线表达更清晰

如果把整个第 8 步浓缩成一句话

第 8 步是在做：

- 面向虚拟阵元构造与波束级 `MUSIC` 测角路线的独立步骤整理

### 5.9 第 9 步：跨 CPI 的局部跟踪与波束调度

当前状态说明：

- 第 9 步当前保留为最小可运行版本
- 入口脚本是 `steps/step_09_cpi_track/demo_cpi_track.m`
- 核心函数是 `core/tracking/run_track_loop_single_target.m`
- 当前版本先实现“真值生成 + 上一 CPI 结果指导下一 CPI 局部处理 + 当前量测直接更新”
- 这一部分更偏向跨 `CPI` 跟踪/调度闭环
- 对当前全息凝视式探测而言，每个 `CPI` 可视为独立处理单元；进入新的 `CPI` 后，继续执行第 5 步即可
- 因此它作为第 9 步保留，供后续扩展与工作量补充
- 当前版本暂不引入卡尔曼滤波和多目标航迹管理

相关文件关系：

- 第 9 步的“当前 `CPI` 量测前端”直接复用局部五波束量测前端
- 也就是继续使用 `core/beamforming/bf_joint_2d.m`
- 与第 5 步不同，这里的 `bf_joint_2d.m` 会显式使用上一 `CPI` 给出的角度/距离速度先验来做局部粗选束
- 当前 `CPI` 的检测与精测角结果，来自第 5 步输出的 `bestRange / bestVel / bestAz / bestEl` 或目标列表
- 第 9 步新增的部分，不是重新做一遍单 `CPI` 检测，而是在 `core/tracking/run_track_loop_single_target.m` 中做 `CPI` 之间的信息传递与下一 `CPI` 的辅助调度

本部分关注的扩展目标：

- 在连续多个 `CPI` 上维护同一个目标的局部航迹
- 用上一 `CPI` 的估计结果去预测下一 `CPI` 的目标位置
- 用预测结果辅助下一 `CPI` 的工作子阵选择和局部波束中心选择
- 在当前 `CPI` 上形成新的 `(range, velocity, azimuth, elevation)` 量测
- 把当前量测和上一 `CPI` 的预测结果做关联
- 更新当前目标状态，并为下一 `CPI` 提供新的预测起点

核心想法：

- 仿真中的“回波生成”仍然由目标真值模型推进
- 工程上的“处理决策”则由上一 `CPI` 的估计状态来引导
- 真值负责生成当前 `CPI` 的真实回波
- 预测负责决定当前 `CPI` 应该看哪里、用哪组局部波束、接受哪些量测
- 第 5 步负责“单个 `CPI` 内的局部检测”
- 第 6 步负责“检测单元上的三波束比幅精测角”
- 第 9 步负责“不同 `CPI` 之间的信息传递与闭环”

推荐状态量定义：

- 推荐第 1 版把跟踪状态写成
  `x_k = [R_k, v_k, az_k, u_k]^T`
- 其中 `u_k = sin(el_k)`
- 对外展示时再把 `u_k` 转回 `el_k = asind(u_k)`

这样定义的原因是：

1. 距离和速度天然就在 `RD` 域里
2. 方位直接用角度更直观
3. 俯仰维当前本来就是在 `u = sin(theta)` 域排布波束和做局部处理
4. 第 9 步内部继续用 `u`，和第 4 步、第 5 步的俯仰处理更一致

推荐量测量定义：

- 当前 `CPI` 的量测可写成
  `z_k = [R̂_k, v̂_k, aẑ_k, û_k]^T`
- `R̂_k`、`v̂_k` 来自第 5 步检测出的目标单元
- `aẑ_k` 来自方位三波束比幅测角
- `û_k = sin(el̂_k)`，其中 `el̂_k` 来自俯仰三波束比幅测角

推荐预测模型：

第 1 版建议先用一个足够简单、便于验证的跨 `CPI` 模型：

$$
R_{k|k-1} = R_{k-1|k-1} + v_{k-1|k-1} T_{cpi}
$$

$$
v_{k|k-1} = v_{k-1|k-1}
$$

$$
az_{k|k-1} = az_{k-1|k-1}
$$

$$
u_{k|k-1} = u_{k-1|k-1}
$$

也就是说，第 1 版先采用：

- 距离按速度做一步外推
- 速度保持不变
- 方位先按慢变处理
- 俯仰先按慢变处理

后续如果确实需要，再往状态里补角速度或更复杂的机动模型。

操作流程概览：

1. 初始化阶段：第 1 个 `CPI` 没有上一时刻航迹时，仍然允许沿用当前第 5 步的初始化方式，也就是先在一个已知起始扇区内完成首次局部检测和三波束精测角，再用首次确认的目标量测初始化跟踪状态 `x_1`。
2. 真值推进当前 `CPI`：在仿真里，目标的真实 `R / v / az / el` 先按真值模型推进到当前 `CPI`，再用这个真值去生成当前 `CPI` 的 `echoCube`。这一层属于“数据生成”。
3. 由上一 `CPI` 做状态预测：用上一 `CPI` 的更新状态 `x_{k-1|k-1}` 预测当前 `CPI` 的 `x_{k|k-1}`，得到当前 `CPI` 的预测距离、预测速度、预测方位和预测俯仰。这一层属于“处理引导”。
4. 用预测结果决定当前 `CPI` 的局部处理上下文：用预测的 `az / u` 决定当前工作子阵中心，用预测的方位中心和俯仰中心决定当前局部三波束或五波束中心；如有需要，也可以用预测的 `R / v` 形成距离门和速度门。
5. 在当前 `CPI` 上运行局部量测前端：按 `pcCube -> 局部波束形成 -> MTD -> 中心束 CFAR -> 最强 metric 检测单元 -> 三波束比幅测角` 得到目标量测候选。
6. 做量测关联：第 1 版先按单目标局部链路处理，也就是只在预测门内找“最像当前航迹”的那个量测。关联判据建议优先使用 `|ΔR|`、`|Δv|`、`|Δaz|`、`|Δu|`；如果门内出现多个候选，则优先选归一化偏差最小或检测度量最强的那个。
7. 做状态更新：若当前 `CPI` 找到有效关联量测，则用该量测更新 `x_{k|k-1}`，得到更新状态 `x_{k|k}`；若当前 `CPI` 没找到有效量测，则暂时保留预测状态，并把该 `CPI` 记为一次失配。
8. 向下一 `CPI` 传递辅助信息：把更新后的 `R / v / az / u` 作为下一 `CPI` 的预测起点，并把下一 `CPI` 预计使用的工作子阵中心、局部波束中心、距离门和速度门一并传下去。

如果把整个第 9 步浓缩成一句话

第 9 步是在做：

- 先用上一 `CPI` 的结果预测当前目标大概在哪里
- 再用这个预测值去决定当前 `CPI` 看哪一片局部角域和哪一段距离速度区域
- 再在当前 `CPI` 上运行第 5 步得到量测
- 最后用当前量测更新航迹，并把结果传给下一 `CPI`

第 9 步与第 5/6 步的边界：

- 第 5 步回答的是“当前这个 `CPI` 里，在已经选定的局部波束上下文中，检测到了什么”。
- 第 6 步回答的是“对这个检测单元，三波束比幅精测角结果是多少”。
- 第 9 步回答的是“连续多个 `CPI` 之间，应该如何利用上一时刻结果去指导下一时刻处理，并把单 `CPI` 量测串成一条连续航迹”。

第 9 步的推荐输入输出：

- 输入：上一 `CPI` 的更新状态 `x_{k-1|k-1}`、当前 `CPI` 的仿真真值生成结果、当前 `CPI` 的局部量测前端输出。
- 输出：当前 `CPI` 的预测状态 `x_{k|k-1}`、当前 `CPI` 的关联量测 `z_k`、当前 `CPI` 的更新状态 `x_{k|k}`、下一 `CPI` 的工作子阵中心和局部波束辅助信息，以及 `K` 个 `CPI` 上的 `trackHistory`。

推荐第 1 版的实现定位：

- 先做单目标局部跟踪闭环
- 先不扩展到多目标航迹管理
- 先不引入复杂的全局数据关联
- 先把“第 5/6 步局部量测前端 + 第 9 步跨 `CPI` 预测更新闭环”跑通

这样做的原因是：

1. 它和当前第 5 步的局部单目标验证链路能够自然衔接
2. 它比直接上多目标航迹管理更容易解释和调试
3. 它更贴近工程上“上一时刻结果指导下一时刻处理”的闭环思路
4. 同时又不需要在当前阶段一下子引入太多复杂模块

## 6. 角度与波束间隔说明

- `cfg.tgt.az` 和 `cfg.tgt.el` 是目标真值角。当前默认值分别为 `8 deg` 和 `10 deg`。
- `cfg.beam.azSectorCenter` 和 `cfg.beam.elSectorCenter` 是当前扇区中心，用来选取工作子阵，并作为参考方向测量波束宽度。
- 当前验证默认把扇区中心设成目标真值角。
- 工程应用中，扇区中心应由粗搜索或扇区调度模块给出。
- `cfg.beam.elSteer` 是方位波束形成时固定使用的俯仰导向角，默认等于 `cfg.beam.elSectorCenter`。
- `core/beamforming/build_sector_beam_grid.m` 是第 3 步和第 4 步共用的网格生成入口：先测扇区中心参考波束宽度，再从扫描边界左侧开始按固定间隔排布波束。
- 方位间隔规则：先在方位扫描轴上测扇区中心参考方位波束的 `3 dB` 主瓣宽度，再直接把它作为 `dAz`。
- 俯仰间隔规则：先在 `u = sin(theta)` 域直接测扇区中心参考俯仰波束的 `3 dB` 主瓣宽度，再直接把它作为 `dU`。
- 当前实现中，`3 dB` 边界是通过扫描网格上的离散阈值法估计出来的，没有做线性插值。
- 第 5 步的二维联合波束网格沿用同样的规则：方位用 `dAz`，俯仰用 `dU`，两个维度都从各自扫描边界的左侧开始按固定间隔排布。

## 7. 波束宽度测量规则

当前 `3 dB` 波束宽度估计是一个有意保持简单的粗测量。

在 `core/beamforming/measure_scan_3db_width.m` 中：

- 从主瓣峰值开始分别向左、向右搜索
- 找到第一个跌破 `-3 dB` 的区域
- 直接取相邻的扫描网格点作为左、右 `3 dB` 边界
- 计算 `bw3dB = rightCross - leftCross`

这意味着：

- 测得的宽度是基于扫描网格的估计值
- 对当前验证流程已经足够
- 它不是亚网格精度的插值波束宽度测量

## 8. 当前处理上下文

当前波束形成链路默认满足：

- 当前 `CPI` 的工作子阵已经固定
- 目标位于这个工作子阵的覆盖范围内
- 方位粗扫描和三波束判决都在这个固定子阵内部完成

因此，当前代码验证的是“固定工作扇区内部”的处理链路，还不是完整的全空间盲搜索实现。

## 9. 关键数据形状

- `echoMat(element, fast-time)`：阵元级原始回波矩阵
- `pcMat(element, range)`：阵元级脉压距离像矩阵
- `beamMat(beam, range)`：波束域距离像矩阵

方位波束形成满足：

$$
\mathrm{beamMat}(b, ir) = \mathbf{w}_b^H \, \mathrm{pcMat}(:, ir)
$$

它表示：

- 固定一个距离单元 `ir`
- 取出这个距离处所有阵元的输出
- 乘上波束 `b` 的权向量
- 沿阵元维做相干求和
- 对全部距离单元重复，就得到一个波束的距离像
- 对全部波束重复，就得到完整的 `beamMat`

## 10. 关键公式

### 10.1 LFM 信号

$$
s_{tx}(t) = \exp\left(j \pi K t^2\right), \quad |t| \leq \frac{T_p}{2}
$$

### 10.2 单通道回波

$$
R_p = R_0 + v t_p
$$

$$
\tau_p = \frac{2R_p}{c}
$$

$$
s_{rx}(t, p) = A \cdot \exp\left(j\pi K (t-\tau_p)^2\right)
\cdot \operatorname{rect}\left(\frac{t-\tau_p}{T_p}\right)
\cdot \exp\left(-j\frac{4\pi R_p}{\lambda}\right)
$$

### 10.3 距离压缩

$$
h[n] = \operatorname{conj}\left(\operatorname{flip}(s[n])\right)
$$

$$
y[n] = x[n] * h[n]
$$

### 10.4 阵元级回波

$$
R_m = \left\| \mathbf{r}_t - \mathbf{r}_m \right\|
$$

$$
\tau_m = \frac{2R_m}{c}
$$

$$
s_m(t) = A \cdot \exp\left(j\pi K (t-\tau_m)^2\right)
\cdot \operatorname{rect}\left(\frac{t-\tau_m}{T_p}\right)
\cdot \exp\left(-j\frac{4\pi R_m}{\lambda}\right)
$$
# Current Final Thesis Route

The current thesis-facing route is documented in:

```text
steps/step_10_final_thesis_route/
```

Final route:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

Current Step positioning:

- Step8.7: verified lazy cascade backend and final performance evidence.
- Step8.8: frontend-to-shared-center closure evidence.
- Step8.9: hardware boundary and fixed-point limitation evidence.
- Step8.10: negative unified model selection evidence.
- Step9: archived diagnostics and thesis-interface notes, not a final backend.
- Step10: final thesis route, evidence tables, figure list, and defense materials.
- Step12: 第 12 步针对第 11.x 波束级 ML 后端建立 FPGA/SoC 协同实现前的硬件可行性边界，重点验证有限字长下 score ranking 和 topK 保持率，并估算 cache 存储与访问复杂度。
- Step13: FPGA/SoC 协同边界收束与 DBF 硬件实现方案；入口为 `steps/step_13_fpga_soc_dbf_boundary/run_step13_fpga_soc_dbf_boundary.m`。FPGA 做 `Z = W^H Y`，CPU/SoC 做 `Rz` / `G_cache` / 2D ML / topK / C05 / confidence / fallback。Step13 不修改 Step11.7 backend 默认行为，不是完整 FPGA backend，也不是 ML score core RTL 主线。
- Step14: DBF IP 封装为 FPGA/SoC 数据通路集成，当前先建立 AXI4-Stream 系统验证框架；入口目录为 `steps/step_14_dbf_ip_soc_integration/`。Step14 继承 Step13 已闭合的 DBF arithmetic core，不重新修改 DBF 数学、位宽或 fixed shift；当前没有 board validation，没有 DMA/PS/Block Design，也不声明完整 FPGA backend。

Do not continue Step09 backend tuning for the final thesis route. Step14 extends
the FPGA/SoC implementation boundary as a separate DBF IP integration framework.

## Step14 DBF IP / SoC Integration Framework

Step14 wraps the closed Step13 DBF arithmetic boundary for FPGA/SoC data-path
integration. The first milestone is an AXI4-Stream system validation framework:

```text
MATLAB Step11-compatible Y/W vectors
-> AXI4-Stream Y replay source BFM
-> W ROM/provider model
-> DBF AXI wrapper
-> Step13 B=7 DBF core
-> AXI4-Stream Z serializer
-> AXI4-Stream sink/scoreboard
-> CSV
-> MATLAB golden comparison
```

Current Step14 status:

- uses ordinary branch development from `codex/step13-fpga-soc`
- creates only framework and protocol documents
- keeps Step13 as the DBF arithmetic source of truth
- keeps Step11.7 backend default behavior unchanged
- does not implement AXI RTL in Step14.0
- does not create DMA, PS software, Block Design, IP, bitstream, or board validation
- does not move CPU/SoC ML modules into FPGA RTL
