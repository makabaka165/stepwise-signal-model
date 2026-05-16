# 第 7.5 步 B 路线 SNR 分辨极限实验说明

## 1. 为什么不再联合对比 A0 / A1 / B

第 7.5 步前面的诊断已经给出明确结论：

- `A0` 在固定角间隔、固定快拍数的 SNR 蒙特卡洛中表现为系统性失效；
- `A1` 在高 SNR 参数诊断下仍表现出稳定系统性谱峰偏差；
- `B` 的阵元域 `FBSS + centerT beamspace MUSIC` 路线表现正常。

因此，本实验不再把 `A0 / A1` 作为候选主路线，也不再写三路线联合对比脚本。

> 本实验的目标只剩一个：  
> 在不同目标角间隔下，验证 `Route B` 的 SNR 分辨极限。

---

## 2. Route B 的算法流程

当前 `B` 路线为：

```text
阵元域数据 y
  -> 阵元域协方差 Rxx
  -> 阵元域 FBSS 得到 Rss
  -> centerT beamspace 投影
  -> 1D MUSIC
  -> 峰值提取
```

关键点有两个：

1. **解相干步骤发生在阵元域**  
   这一步使用真正的物理子阵 `FBSS`，满足 ULA 子阵平移不变性。

2. **beamspace 投影发生在 FBSS 之后**  
   `centerT` 只承担降维与局部角域聚焦，不承担解相干主任务。

这也是当前 `B` 路线能够稳定工作的根本原因。

---

## 3. 当前实验参数

新脚本：

- [space_smooth_music_B_snr_resolution_limit.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_5_space_smooth_beamspace_MUSIC_monte_carlo/space_smooth_music_B_snr_resolution_limit.m)

固定公共参数：

```matlab
rng(20260515, 'twister');

snr_list = -10:2:30;
Metkl = 200;
T_snap = 260;
tol_deg = 0.1;

sep_factor_list = [1, 2, 3, 4];
```

`B` 路线内部参数保持不变：

```matlab
search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
```

---

## 4. SNR 加噪方式

本实验统一采用已经在第 7.5 步中验证过的阵元域输入 SNR 定义。

相干双目标信号：

```matlab
s1 = exp(1j * 2 * pi * fc * t);
s2 = exp(1j * 2 * pi * fc * t);
```

阵元 steering：

```matlab
A_a = exp(-1j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
A_b = exp(-1j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);
```

无噪声阵元域数据：

```matlab
s11 = A_a.' * s1;
s21 = A_b.' * s2;
y_clean = s11 + s21;
```

按 `y_clean` 平均功率自适应生成复高斯白噪声：

$$
\sigma_n^2
=
\frac{\operatorname{mean}(|Y_{\mathrm{clean}}|^2)}
{10^{\mathrm{SNR}/10}}
$$

```matlab
noise_power = mean(abs(y_clean(:)).^2) / 10^(snr / 10);
noise = sqrt(noise_power / 2) * ...
    (randn(size(y_clean)) + 1j * randn(size(y_clean)));

y = y_clean + noise;
```

这里不再使用旧写法：

```matlab
s1 = sqrt(10^(snr/10)) * exp(...)
```

统一采用 `y_clean` 功率自适应加噪，保证不同角间隔下阵元域输入 SNR 定义一致。

---

## 5. `sep_factor_list = [1, 2, 3, 4]` 的含义

本实验测试四个目标角间隔：

$$
\theta_{\mathrm{sep}} = \frac{bw_{64}}{\mathrm{sep\_factor}}
$$

对应为：

- `sep_factor = 1`：`bw/1`
- `sep_factor = 2`：`bw/2`
- `sep_factor = 3`：`bw/3`
- `sep_factor = 4`：`bw/4`

也就是说，本实验是在逐步减小目标角间隔，观察 `B` 路线在不同分辨难度下所需的 SNR。

预期趋势是：

> 角间隔越小，达到高成功率所需的 SNR 越高。

---

## 6. 输出指标

每个 `(sep_factor, snr)` 组合统计：

### 6.1 `raw_success`

只要求输出两个有限角度：

```matlab
raw_ok = all(isfinite(doa_B));
```

### 6.2 `tol_success`

要求两个 DOA 都落在 `tol_deg = 0.1` 容差内：

```matlab
tol_ok = is_valid_doa_success(doa_B, target_theta, tol_deg);
```

### 6.3 `RMSE`

只对 `raw_success` 有效样本统计：

```matlab
sqerr = sum((sort(doa_B(:).') - sort(target_theta(:).')).^2);
```

```matlab
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ ...
    (2 * rmse_valid_count(valid_mask)));
```

### 6.4 `mean_num_peaks`

记录当前 1D MUSIC 后端平均提取到的局部峰数：

```matlab
sum_num_peaks(iSep, iSNR) = sum_num_peaks(iSep, iSNR) + debug_B.num_peaks;
mean_num_peaks = sum_num_peaks / Metkl;
```

### 6.5 `snr90`

对每个角间隔提取达到 `90% tol success` 所需的最小 SNR：

```matlab
idx = find(tol_success_rate(iSep, :) >= 0.9, 1, 'first');
```

如果在 `30 dB` 内仍未达到 `90%`，则保留 `NaN`。

---

## 7. 输出文件

本实验要求生成以下结果文件：

- `B_snr_resolution_limit.log`
- `B_snr_resolution_limit_summary.csv`
- `B_snr_resolution_limit_result.mat`
- `B_tol_success_vs_snr_by_sep.png`
- `B_rmse_vs_snr_by_sep.png`
- `B_snr90_vs_sep.png`
- `B_raw_success_vs_snr_by_sep.png`
- `B_mean_num_peaks_vs_snr_by_sep.png`

其中：

- `csv` 用于结构化结果汇总；
- `mat` 用于后续 MATLAB 复用；
- `log` 用于直接阅读实验过程；
- `png` 用于画出主结果趋势。

---

## 8. 后续计划

本轮实验只验证：

> 严格 `B` 前端 + 当前 `1D MUSIC` 后端

本轮不引入 `2D pair-MUSIC`。

未来如果当前 `B` 的 SNR 分辨极限结果稳定，可新增一条对照路线：

> 严格 `B` 前端 + `2D pair-MUSIC` 后端

用于比较在小角间隔场景下，二维角度对搜索是否能进一步改善分辨性能。

---

## 9. 当前阶段结论

本实验不再以 `A0 / A1` 作为候选路线。`A0 / A1` 已在第 7.5 步诊断中表现出系统性失效，因此后续主线集中验证 `B` 的 SNR 分辨极限。

