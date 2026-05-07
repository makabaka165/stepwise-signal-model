# 第6步三波束比幅测角蒙特卡洛说明

本文档只针对第6步独立链路：

```text
阵元级多脉冲回波
-> 距离脉压
-> 局部五波束形成
-> MTD
-> 中心束 CFAR 选最强单元
-> 三波束比幅精测角
```

当前版本只保留前两层蒙特卡洛：

1. 第1层：输出端 SNR 扫描
2. 第2层：目标在局部波束内偏移

不再保留第三层距离/速度偏移蒙特卡洛。

## 1. 当前场景定位

当前假定场景是单目标、白噪声、无复杂杂波、无真实数据集的简化链路。  
蒙特卡洛的目标是看趋势是否合理，而不是做严格的检测概率或置信区间统计。

当前固定目标参数：

```text
R0     = 3200 m
vTgt   = 45 m/s
azTgt  = 8 deg
elTgt  = 10 deg
ampTgt = 0.01
Pfa    = 1e-7
Np     = 32
CFAR   = CA-Square
```

## 2. 第1层：输出端 SNR 扫描

### 2.1 定义

第1层现在不再使用“阵元级输入 SNR”作为横轴，而是使用输出端功率 SNR：

```text
SNR_out = 10*log10(PsOut / PnOut)
```

其中：

- `PsOut`：signal-only 情况下，中心束目标 RD 峰值单元的信号功率
- `PnOut`：noise-only 情况下，中心束 RD 图背景噪声平均功率

脚本先做一次输出端标定，再按目标 `SNR_out` 反推每个扫描点应使用的 `sigmaN`。

### 2.2 当前扫描参数

```text
snrOutDbList = [12, 15, 20, 25, 30, 35, 40]
nTrial       = 100
```

这一层总计：

```text
7 x 100 = 700 次主循环
外加 signal-only / noise-only 两次标定
```

### 2.3 当前标定结果

当前输出端标定结果为：

```text
peakRIdx = 1251
peakDIdx = 12
PsOut    = 124.822
PnOutRef = 0.997031
```

对应的输出 SNR、噪声标准差和等效输入 SNR 关系为：

```text
snrOutDb   sigmaN    snrInEqDb
12         2.8105    -48.976
15         1.9897    -45.976
20         1.1189    -40.976
25         0.6292    -35.976
30         0.35383   -30.976
35         0.19897   -25.976
40         0.11189   -20.976
```

这里的 `snrInEqDb` 只用于和旧版本“输入端 SNR”口径对照，不作为当前正式横轴。

### 2.4 当前结果

输出文件：

```text
layer_1_snr/snr_monte_carlo_summary.csv
layer_1_snr/snr_monte_carlo_result.mat
```

汇总表字段：

```text
snrOutDb
snrInEqDb
azRmseDeg
elRmseDeg
```

当前结果为：

```text
snrOutDb   snrInEqDb   azRmseDeg   elRmseDeg
12         -48.976     0.26431     0.24586
15         -45.976     0.26682     0.22728
20         -40.976     0.24328     0.19729
25         -35.976     0.16204     0.16716
30         -30.976     0.06780     0.03865
35         -25.976     0.02983     0.02032
40         -20.976     0.01957     0.01098
```

### 2.5 结果解释

这组结果说明：

- `12~20 dB`：低输出 SNR 区，测角误差明显偏大
- `25~30 dB`：过渡区，RMSE 快速下降
- `35~40 dB`：高输出 SNR 区，进入稳定平台

因此第1层当前已经可以用来说明：

```text
测角误差随输出端 SNR 提升而下降
```

## 3. 第2层：目标在局部波束内偏移

### 3.1 目的

验证三波束比幅测角在局部主瓣内不同位置的误差分布。

### 3.2 当前扫描参数

固定噪声配置沿用当前代码版本：

```text
snrDb = -14 dB  （第2层仍按原脚本现状保留）
```

扫描参数：

```text
azOffset = [-0.5*dAz, 0, +0.5*dAz]
uOffset  = [-0.5*dU,  0, +0.5*dU]
nTrial   = 3
```

其中俯仰偏移在 `u = sin(el)` 域内定义，再映射回物理俯仰角：

```matlab
targetEl = asind(sind(centerEl) + uOffset);
```

这一层总计：

```text
3 x 3 x 3 = 27 次单次仿真
```

输出文件：

```text
layer_2_angle_offset/angle_offset_monte_carlo_summary.csv
layer_2_angle_offset/angle_offset_monte_carlo_result.mat
```

汇总表字段：

```text
azOffsetDeg
uOffset
azRmseDeg
elRmseDeg
```

### 3.3 当前结果

当前结果表明：

- 中心点 `(azOffset=0, uOffset=0)` 误差最小  
  `azRmse = 0.00153 deg`，`elRmse = 0.00470 deg`
- 方位偏移到 `azOffset = +-0.62 deg` 后，方位 RMSE 大约增大到 `0.431~0.439 deg`
- 俯仰偏移到 `uOffset = +-0.014609` 后，俯仰 RMSE 大约增大到 `0.200~0.233 deg`

因此第2层已经足够支撑：

```text
中心最好，靠近主瓣边界时误差明显增大
```

## 4. 结果查看建议

CSV 文件保存的是每个扫描点的汇总统计，适合直接用 Excel 或 MATLAB `readtable` 查看。  
MAT 文件保存的是 `summaryTable`、`trialTable` 以及相关配置参数，适合进一步分析。

示例：

```matlab
T1 = readtable(fullfile('layer_1_snr', 'snr_monte_carlo_summary.csv'));
T2 = readtable(fullfile('layer_2_angle_offset', 'angle_offset_monte_carlo_summary.csv'));

S1 = load(fullfile('layer_1_snr', 'snr_monte_carlo_result.mat'));
S2 = load(fullfile('layer_2_angle_offset', 'angle_offset_monte_carlo_result.mat'));
```

## 5. 图形查看建议

建议重点看这些图：

```text
第1层：输出 SNR - 方位/俯仰 RMSE 折线图
第2层：方位偏移/u 偏移 - 方位 RMSE 热力图
第2层：方位偏移/u 偏移 - 俯仰 RMSE 热力图
第2层：固定 u 偏移时，方位 RMSE 随方位偏移变化的折线图
第2层：固定方位偏移时，俯仰 RMSE 随 u 偏移变化的折线图
```

绘图脚本：

```text
plot/plot_monte_carlo_trends.m
```

该脚本只读取前两层 CSV，不重新运行蒙特卡洛。

## 6. 当前代码布局

单次链路演示脚本：

```text
demo_three_beam_angle_standalone.m
```

当前蒙特卡洛脚本：

```text
layer_1_snr/run_snr_monte_carlo.m
layer_2_angle_offset/run_angle_offset_monte_carlo.m
```

这样每个实验目标清晰，结果文件也方便独立保存和复现。
