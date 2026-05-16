# 第 7.5 步 A0 / A1 / B SNR 蒙特卡洛结果说明

## 1. 结论

在当前第 7.5 步的相干双目标模型、阵元域输入 SNR 加噪口径、`theta_sep = bw_64 / 1`、`T_snap = 260` 的验证条件下：

- `A0` 旧受限搜索路线表现为系统性失效；
- `A1` 旧 `beam-index smoothing` 诊断路线表现为稳定系统性谱峰偏差；
- `B` 的阵元域 `FBSS + centerT beamspace MUSIC` 路线表现正常。

因此，当前阶段的结论是：

> `A0 / A1` 不再作为后续主线，仅保留为历史备份与反例诊断；  
> `B` 作为后续第 7.5 步分辨极限实验的主算法路线。

---

## 2. 公共实验模型

### 2.1 公共参数

三条路线在第 7.5 步中共用以下基础设置：

```matlab
rng(20260515, 'twister');
snr_list = -10:2:30;
Metkl = 200;
T_snap = 260;
theta_sep = bw_64 / 1;
tol_deg = 0.1;
theta_c = 13;
```

当前 `bw_64 = 2.8 deg`，因此：

$$
\theta_{\mathrm{sep}} = 2.8^\circ
$$

$$
\theta_a = \theta_c - \frac{\theta_{\mathrm{sep}}}{2} = 11.6^\circ
$$

$$
\theta_b = \theta_c + \frac{\theta_{\mathrm{sep}}}{2} = 14.4^\circ
$$

### 2.2 相干双目标阵元域模型

阵元 steering 向量为：

$$
a(\theta)
=
\begin{bmatrix}
1,
e^{-j\frac{2\pi d}{\lambda}\sin\theta},
\ldots,
e^{-j\frac{2\pi d}{\lambda}(N-1)\sin\theta}
\end{bmatrix}^T
$$

代码中对应：

```matlab
A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);
```

两个目标信号完全相干：

```matlab
s1 = exp(j * 2 * pi * fc * t);
s2 = exp(j * 2 * pi * fc * t);
```

因此无噪声阵元域数据为：

$$
Y_{\mathrm{clean}}
=
a(\theta_a)s + a(\theta_b)s
=
\left[a(\theta_a)+a(\theta_b)\right]s
$$

代码中对应：

```matlab
s11 = A_a.' * s1;
s21 = A_b.' * s2;
y_clean = s11 + s21;
```

### 2.3 SNR 加噪口径

三条路线统一按阵元域总输入功率自适应生成复高斯白噪声：

$$
\sigma_n^2
=
\frac{\operatorname{mean}(|Y_{\mathrm{clean}}|^2)}
{10^{\mathrm{SNR}/10}}
$$

$$
N
=
\sqrt{\frac{\sigma_n^2}{2}}
\left(N_r + jN_i\right)
$$

$$
Y = Y_{\mathrm{clean}} + N
$$

代码中对应：

```matlab
noise_power = mean(abs(y_clean(:)).^2) / 10^(snr / 10);
noise = sqrt(noise_power / 2) * ...
    (randn(size(y_clean)) + j * randn(size(y_clean)));
y = y_clean + noise;
```

这点很重要：`A0 / A1 / B` 的差异不是由 SNR 加噪方式造成的。`B` 在同一加噪口径下表现正常，说明蒙特卡洛框架本身是合理的。

---

## 3. 评价指标

### 3.1 `raw_success`

只要求算法输出两个有限 DOA：

$$
\mathrm{raw\_ok} = \mathrm{all}(\mathrm{isfinite}(\hat{\theta}))
$$

它回答的是：算法是否给出了两个有限角度。

### 3.2 `tol_success`

将估计角和真实角排序后逐一比较，阈值为 `tol_deg = 0.1`：

$$
|\hat{\theta}_{(1)} - \theta_{(1)}| \le 0.1^\circ
$$

$$
|\hat{\theta}_{(2)} - \theta_{(2)}| \le 0.1^\circ
$$

它回答的是：算法是否在 `0.1 deg` 容差内正确估计两个目标。

### 3.3 `RMSE`

只对 `raw_success` 有效样本统计：

$$
\mathrm{sqerr}
=
\sum_{k=1}^{2}
\left(
\hat{\theta}_{(k)} - \theta_{(k)}
\right)^2
$$

$$
\mathrm{RMSE}
=
\sqrt{
\frac{
\sum \mathrm{sqerr}
}{
2N_{\mathrm{valid}}
}
}
$$

因此，当某个 SNR 下 `raw_success = 0` 时，`RMSE = NaN`，并不是误差无限大，而是没有有效样本。

---

## 4. Route A0：受限搜索旧路线

### 4.1 算法结构

`A0` 的流程为：

```text
阵元域数据 y
  -> A0_beam_matrix.' * y
  -> beam-domain 数据
  -> beam-index smoothing
  -> 中间 beam 子阵 manifold
  -> MUSIC 谱搜索
```

其内部关键参数为：

```matlab
routeA0_beam_span = bw_64;
M_old_A0 = 50;
theta_search_A0 = theta_sep;
```

即：

- beam grid 覆盖 `[theta_c - bw_64/2, theta_c + bw_64/2]`
- 搜索宽度等于目标间隔

### 4.2 A0 的结构性问题

当前有：

$$
\Theta_{\mathrm{search}}
=
\left[
\theta_c - \frac{\theta_{\mathrm{sep}}}{2},
\theta_c + \frac{\theta_{\mathrm{sep}}}{2}
\right]
=
[\theta_a,\theta_b]
$$

这意味着真实目标正好位于搜索窗口两个端点，而不是窗口内部。

由此带来三个问题：

1. 真实峰落在扫描边界，局部峰提取不稳定；
2. beam grid 也只覆盖同一窄范围，而 smoothing 后又只使用中心连续 beam；
3. 搜索窗口没有任何裕量，无法容忍峰位偏移或谱形展宽。

### 4.3 A0 的蒙特卡洛结果

来自 [space_smooth_music_A0_snr_eval.log](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_5_space_smooth_beamspace_MUSIC_monte_carlo/space_smooth_music_A0_snr_eval.log) 与 [A0_snr_summary.csv](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_5_space_smooth_beamspace_MUSIC_monte_carlo/A0_snr_summary.csv)：

| SNR (dB) | raw | tol | RMSE | boundary_like |
|---|---:|---:|---:|---:|
| -10 | 200 | 0 | 0.2142 | 0.00 |
| -2 | 200 | 0 | 0.5032 | 0.00 |
| 0 | 196 | 0 | 0.7687 | 0.00 |
| 2 | 4 | 0 | 1.0413 | 0.00 |
| 4 及以上 | 0 | 0 | NaN | 0.00 |

### 4.4 A0 结果解释

`A0` 不是随 SNR 升高而变好，而是随 SNR 升高逐步崩掉：

- 低 SNR 下，噪声造成额外随机局部峰，因此 `raw_success` 仍高；
- 这些峰不对应真实目标，因此 `tol_success` 始终为 0；
- 高 SNR 下，噪声峰减少，算法自身的受限搜索问题暴露出来；
- 最终在 `SNR >= 4 dB` 时直接无法输出两个有限角度。

同时，`boundary_like_hit_rate` 全程为 0，说明它并不是“靠边界命中才显得有效”，而是整体谱结构在当前条件下就是错的。

### 4.5 A0 结论

> `A0` 在当前第 7.5 步验证条件下表现为系统性失效。  
> 它不适合作为后续主线，只能保留为旧路线备份与反例诊断。

---

## 5. Route A1：放宽搜索后的 beam-index smoothing 诊断路线

### 5.1 算法目的

`A1` 的目标是检查：当去掉 `A0` 的强边界约束后，旧 `beam-index smoothing` 路线是否仍可恢复正常。

核心变化是：

$$
\text{search width} = 4\theta_{\mathrm{sep}}
$$

也就是把目标从搜索边界移回搜索窗口内部。

### 5.2 A1 的两种谱构造

`A1` 在 `DOA_three_music_hecheng_fangzhen_eval.m` 中测试两种谱构造。

#### `center` 模式

只取中心连续 `celln` 个 beam 构造导向矢量：

$$
a_c(\theta) = T_{\mathrm{center}}^T a(\theta)
$$

对应谱函数：

$$
P_{\mathrm{center}}(\theta)
=
\frac{
a_c^H(\theta)a_c(\theta)
}{
a_c^H(\theta)E_nE_n^Ha_c(\theta)
}
$$

#### `manifold` 模式

先构造完整 beamspace steering：

$$
g(\theta) = T^T a(\theta)
$$

再按相同的 beam-index 滑窗构造：

$$
H(\theta) =
\left[
g_1(\theta),
g_2(\theta),
\ldots,
g_P(\theta)
\right]
$$

对应谱函数：

$$
P_{\mathrm{manifold}}(\theta)
=
\frac{
\|H(\theta)\|_F^2
}{
\|E_n^H H(\theta)\|_F^2
}
$$

这比 `center` 更接近 smoothing 协方差的构造方式，但实验表明仍不能解决根本问题。

### 5.3 A1 的高 SNR 诊断结果

`A1` 当前固定：

```matlab
snr = 30;
Metkl = 20;
theta_sep = bw_64 / 1;
qSmoothRatio_A1 = [0.02, 0.05, 0.10, 0.20];
SpectrumMode = {'center', 'manifold'};
```

来自 [space_smooth_music_A1_eval.log](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_5_space_smooth_beamspace_MUSIC_monte_carlo/space_smooth_music_A1_eval.log)：

| SpectrumMode | qSmoothRatio | raw | tol | RMSE |
|---|---:|---:|---:|---:|
| center | 0.02 | 20 | 0 | 1.3445 |
| center | 0.05 | 20 | 0 | 1.3537 |
| center | 0.10 | 20 | 0 | 1.3913 |
| center | 0.20 | 20 | 0 | 1.5012 |
| manifold | 0.02 | 20 | 0 | 1.3415 |
| manifold | 0.05 | 20 | 0 | 1.3464 |
| manifold | 0.10 | 20 | 0 | 1.3637 |
| manifold | 0.20 | 20 | 0 | 1.4569 |

### 5.4 A1 结果解释

`A1` 的特征很明确：

- `raw=20`：总能输出两个角；
- `tol=0`：这两个角总是错的；
- `RMSE` 长期稳定在约 `1.34 ~ 1.50 deg`；
- `manifold` 略优于 `center`，但没有本质改善；
- `qSmoothRatio` 从 `0.02` 到 `0.20` 都不能修复问题。

这说明 `A1` 不是随机失败，也不是单个参数没调好，而是存在稳定系统偏差。

### 5.5 A1 的根本问题

传统空间平滑成立的前提是：在物理 ULA 阵元坐标下，重叠子阵满足平移不变性。

但 `A1` 做的是：

```text
先投影到 beam index
再在 beam index 上滑窗做 smoothing
```

beam index 并不是物理阵元坐标，它不满足阵元 steering 的 Vandermonde 平移结构。因此：

> `beam-index smoothing` 不是严格意义上的空间平滑。  
> 它缺少传统 FBSS 成立所依赖的物理子阵平移不变性。

这就是为什么 `A1` 在高 SNR、宽搜索窗、不同 `Q` 和不同谱构造下仍然稳定失败。

### 5.6 A1 结论

> `A1` 证明旧 `beam-index smoothing` 路线在一般搜索条件下存在系统性谱峰偏差，不适合作为后续主线。

---

## 6. Route B：阵元域 FBSS + centerT beamspace MUSIC 主线

### 6.1 算法结构

`B` 的流程为：

```text
阵元域数据 y
  -> 阵元域协方差 Rxx
  -> 阵元域 FBSS 得到 Rss
  -> centerT beamspace 投影
  -> beamspace MUSIC
  -> 峰值提取
```

其内部关键参数为：

```matlab
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
search_scale_B = 4;
```

### 6.2 阵元域 FBSS

`B` 在阵元域先做真正的前后向空间平滑：

$$
R_{xx} = \frac{1}{T}YY^H
$$

对所有长度为 `K` 的物理重叠子阵做平均：

$$
R_f
=
\frac{1}{P}
\sum_{p=1}^{P}
R_{xx}[p:p+K-1,\,p:p+K-1]
$$

其中：

$$
P = N-K+1
$$

再做前后向平均：

$$
R_{\mathrm{fbss}}
=
\frac{1}{2}
\left(
R_f + JR_f^*J
\right)
$$

这一步发生在物理阵元域，因此满足 ULA 子阵平移不变性，是严格空间平滑。

### 6.3 centerT 投影

在得到已解相干的阵元域平滑协方差后，再做 beamspace 投影：

$$
R_b = T_k^T R_{ss} T_k^*
$$

这里 `centerT` 的作用是：

1. 降维；
2. 聚焦局部角域；
3. 降低后续 MUSIC 搜索复杂度。

它不承担“解相干”的主任务，因此不会破坏 FBSS 的核心作用。

### 6.4 B 的蒙特卡洛结果

来自 [space_smooth_music_new_route_centerT.log](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_5_space_smooth_beamspace_MUSIC_monte_carlo/space_smooth_music_new_route_centerT.log)：

| SNR (dB) | raw | tol | RMSE |
|---|---:|---:|---:|
| -10 | 200 | 161 | 0.0666 |
| -8 | 200 | 192 | 0.0455 |
| -6 | 200 | 198 | 0.0345 |
| -4 | 200 | 200 | 0.0259 |
| 0 | 200 | 200 | 0.0162 |
| 12 | 200 | 200 | 0.0040 |
| 20 | 200 | 200 | 0.0005 |
| 22 及以上 | 200 | 200 | 0.0000 |

### 6.5 B 结果解释

`B` 的结果符合正常 DOA 算法直觉：

- SNR 越高，`tol_success` 越高；
- SNR 越高，RMSE 越低；
- 高 SNR 下稳定满成功。

高 SNR 下 `RMSE = 0.0000` 的原因是：当前搜索步长为 `0.01 deg`，而真实角 `11.6 / 14.4 deg` 正好落在搜索网格点上，因此估计可达到网格精度。

### 6.6 B 结论

> `B` 的“阵元域 FBSS -> centerT beamspace MUSIC”流程与相干双目标的 DOA 数据模型匹配良好，应作为后续第 7.5 步主线。

---

## 7. 三条路线的最终判断

### A0

- 搜索区间正好卡在真实目标端点；
- beam grid 也只覆盖同一窄区间；
- 高 SNR 下 raw 输出塌陷；
- `tol_success` 全程为 0。

**结论：A0 当前不可用。**

### A1

- 去掉了 A0 的边界限制；
- 测了 `center / manifold`；
- 扫了多组 `qSmoothRatio`；
- 但高 SNR 下仍稳定输出错误角度。

**结论：A1 存在系统性谱峰偏差。**

### B

- 真正的解相干步骤发生在阵元域；
- `FBSS + centerT beamspace MUSIC` 的流程与模型匹配；
- SNR sweep 结果正常。

**结论：B 是当前正确主线。**

---

## 8. 是否需要 A0 / A1 / B 联合对比脚本

当前阶段不建议再写 A0 / A1 / B 联合蒙特卡洛脚本。

原因很简单：

- `A0` 在完整 SNR sweep 下失败；
- `A1` 在高 SNR 参数诊断下失败；
- `B` 在完整 SNR sweep 下正常。

三条路线的角色已经非常明确，再做联合脚本不会增加有效结论，只会增加维护成本。

当前更合适的做法是：

1. 保留本目录下各自独立脚本和日志；
2. 保留本文档作为结论说明；
3. 后续只围绕 `B` 继续做分辨极限实验。

---

## 9. 后续 B 主线建议

建议下一步直接做 `B` 的二维参数实验：

```matlab
theta_sep_list = [bw_64/1, bw_64/2, bw_64/3, bw_64/4];
snr_list = -10:2:30;
Metkl = 200;
T_snap = 260;
```

建议输出：

1. 每个 `theta_sep` 下的 `tol_success_rate vs SNR`
2. 每个 `theta_sep` 下的 `RMSE vs SNR`
3. 每个 `theta_sep` 达到 `90% tol_success` 所需的 SNR 阈值

这会直接给出：

> `B` 路线在不同目标角间隔下的 SNR 分辨极限。

---

## 10. 最终结论

当前第 7.5 步对 `A0 / A1 / B` 三条路线进行了固定角间隔、固定快拍数下的 SNR Monte Carlo 验证。

- `A0`：高 SNR 下 raw 输出塌陷，`tol_success` 全程为 0；
- `A1`：去除边界约束后，在 `center / manifold` 和多组 `qSmoothRatio` 下仍表现出稳定系统性偏差；
- `B`：SNR 趋势正常，高 SNR 下稳定满成功。

因此：

> `A0 / A1` 不再作为后续主线，仅保留为历史备份与反例诊断；  
> `B` 作为第 7.5 步后续分辨极限验证的主算法路线。

