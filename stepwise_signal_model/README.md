# 分步信号模型

## 1. 目的

`stepwise_signal_model` 将主雷达处理链拆成可以独立验证的多个步骤。当前重点是把下面这条链路做得清晰、可运行、可检查：

```text
LFM 发射 -> 回波建模 -> 距离压缩 -> 阵元级建模 -> 方位接收波束形成 -> 俯仰接收波束形成 -> 二维联合波束形成 + MTD + CFAR
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
```

## 3. 运行方式

方式 1：先运行 `setup_paths.m`，再运行目标 demo。

```matlab
run('E:\matlab_code\bishe_quanxi\stepwise_signal_model\setup_paths.m')
demo_joint_2d_mtd
```

方式 2：直接打开 `steps/` 下的某个 demo 运行。每个 demo 开头都会先调用 `setup_paths.m`。

## 4. 步骤概览

- `step_01_lfm_pc`：单通道 `LFM + 回波 + 脉压`
- `step_02_elem_pc`：阵元级单脉冲回波与脉压验证
- `step_03_az_bf`：方位接收波束形成验证
- `step_04_el_bf`：俯仰接收波束形成验证
- `step_05_joint_2d_mtd`：二维联合波束形成、`MTD` 与 `1D CA-CFAR` 粗检测

详细的“步骤 - 脚本 - 函数”对应关系见 [docs/STEP_MAP.md](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/docs/STEP_MAP.md)。

## 5. 第 1 步到第 5 步

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
- `core/beamforming/bf_joint_2d.m`
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
- 当前可读性优先的实现说明：`core/beamforming/bf_joint_2d.m` 一次性计算全部二维波束，没有使用 block 处理。如果后续波束数、脉冲数或处理距离窗变大，可以再引入 block 方案降低峰值内存。
- 当前验证流程说明：第 5 步 demo 和 `bf_joint_2d` 默认目标能够被 `CFAR` 检出，因此去掉了“检测不到目标”时的回退分支，以便让主路径更短、更直观。

操作流程概览：

- 先生成原始多脉冲阵元回波立方体 `echoCube(element, fast-time, pulse)`
- 再逐脉冲做距离压缩，得到 `pcCube(element, range, pulse)`
- 再构造二维联合波束网格和全部二维接收权
- 再做二维联合波束形成，得到 `beamCube(beam, range, pulse)`
- 再沿脉冲维做 `MTD`，得到 `rdCube(beam, range, doppler)`
- 再对每个二维波束的 `RD` 图做 `1D CA-CFAR`
- 最后分别展示未加 `CFAR` 的纯峰值结果和加了 `CFAR` 的最优检测结果

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
