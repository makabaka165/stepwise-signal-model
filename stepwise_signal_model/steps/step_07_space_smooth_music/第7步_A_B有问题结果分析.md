# 第7步 A/B 结果与代码逻辑分析

## 1. 文档目的

本文用于整理第 7 步 `Route A` 与 `Route B` 的对比结果、现象解释以及对应代码逻辑。重点回答以下两个问题：

1. 为什么 `Route A` 在大角间隔时会出现无法检测，而在小角间隔时 `RMSE` 反而迅速下降，甚至接近 `0`。
2. 为什么 `Route B` 呈现出相反趋势，即大角间隔通常正常，而在小角间隔、尤其快拍数较少时更容易退化甚至出现 `NaN`。

本文同时将分析中涉及的公式整理为可直接被 Markdown 渲染的形式。

---

## 2. 对比实验背景

主脚本为 [compare_step07_AB_only.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_space_smooth_music/compare_step07_AB_only.m)。

两条路线分别是：

- `Route A`：旧路线，先到波束域，再在波束域内做平滑和 `MUSIC`
- `Route B`：新路线，先在阵元域构造协方差，再投影到 `centerT` 波束域后做 `MUSIC`

### 2.1 关键参数

- 阵元数：`array_num = 64`
- 子阵长度：`subarray_num = 59`
- 中心角：`theta_c = 13 deg`
- 快拍数：`T_snap_list = [130, 260, 520]`
- 角间隔档位：`bw_index_list = 1:10`

参考波束宽度定义为：

```matlab
bw_64 = 50.8 * 1.45 * lambda / (array_num - 1) / d;
bw_64 = roundn(bw_64, -1);
```

角间隔档位定义为：

```matlab
theta_bw = [bw_64/1, bw_64/2, ..., bw_64/10];
```

双目标角度定义为：

```matlab
theta_a = theta_c - theta_bw(angle_grid_num) / 2;
theta_b = theta_c + theta_bw(angle_grid_num) / 2;
```

因此第 `k` 个档位的目标间隔为：

$$
\Delta \theta_k = \frac{\mathrm{bw}_{64}}{k}
$$

这意味着：

- `bw/1` 是最大角间隔
- `bw/10` 是最小角间隔

这个点非常重要，因为后面对“大小角间隔”的解释都基于这个定义。

---

## 3. 现象汇总

从当前结果看，可以先概括成四条：

1. `Route A` 并不是全区间最强，它在 `bw/1`、`bw/2` 会失败。
2. `Route A` 在 `bw/3 ~ bw/10` 上 `RMSE` 极低，甚至接近 `0`。
3. `Route B` 在 `bw/1 ~ bw/10` 都能工作，但随着目标间隔变小，`RMSE` 通常增大。
4. `Route B` 对快拍数很敏感，`T_snap` 从 `130` 增大到 `520` 后，小间隔端明显变稳。

从表面现象看，似乎是：

- `Route A`：小间隔表现更强
- `Route B`：大间隔更稳，小间隔更难

但如果直接这样解释，会掩盖代码里的两个关键实验设计因素：

1. `Route A` 的搜索窗口刚好等于真实双目标间隔，真实角落在搜索边界。
2. 峰值检测函数允许边界点被判定为峰值。

这两个因素会让 `Route A` 在小间隔时出现明显的“边界锁定”效应，从而人为压低 `RMSE`。

---

## 4. Route A 的代码逻辑与异常趋势来源

`Route A` 的核心函数为 [DOA_three_music_hecheng_fangzhen.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_space_smooth_music/DOA_three_music_hecheng_fangzhen.m)。

### 4.1 搜索窗口与真实目标完全重合

主脚本中调用方式为：

```matlab
doa_old = DOA_three_music_hecheng_fangzhen( ...
    sr_DBF_boshu, array_num, A_old, RecvbeamC, theta_bw(angle_grid_num));
```

在 `Route A` 内部，搜索区间定义为：

```matlab
angle_search = angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2;
```

而真实目标角定义为：

$$
\theta_1 = \theta_c - \frac{\Delta\theta}{2}, \qquad
\theta_2 = \theta_c + \frac{\Delta\theta}{2}
$$

又因为这里传入的 `theta_bw` 正好就是当前双目标间隔 `\Delta\theta`，所以 `Route A` 的搜索区间实际就是：

$$
[\theta_c - \frac{\Delta\theta}{2}, \ \theta_c + \frac{\Delta\theta}{2}]
=
[\theta_1, \theta_2]
$$

也就是说，两个真实目标角正好落在搜索窗口的左右端点。

### 4.2 峰值函数允许边界点成为峰值

峰值检测函数为 [FindLocalPeak_Fun.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_space_smooth_music/FindLocalPeak_Fun.m)。

其中两端点会被单独判定：

```matlab
if x1(1) > x1(2)
    r3(1) = 1;
end

if x1(L) > x1(L-1)
    r3(L) = 1;
end
```

这意味着：

- 只要谱函数在左边界高于第二个采样点，左边界就会被视为局部峰；
- 只要谱函数在右边界高于倒数第二个采样点，右边界也会被视为局部峰。

由于 `Route A` 的真实目标恰好就在搜索边界，因此当谱在边界附近抬高时，算法会非常容易把这两个边界直接选成估计结果。

### 4.3 为什么小间隔时 RMSE 会异常接近 0

`Route A` 在 `bw/3 ~ bw/10` 上的超低 `RMSE`，不能直接解释成“目标越近越容易分辨”。更准确地说，它同时受到了以下三个机制的影响：

1. 搜索范围使用了真实目标间隔；
2. 真实目标正好位于搜索边界；
3. 峰值检测允许边界点成为峰值。

因此，一旦边界点被识别为峰，输出角度就天然非常接近真实值，导致：

$$
\mathrm{RMSE} \approx 0
$$

甚至在某些档位上直接为 `0`。

这更像是一种由搜索窗口设计引入的“实验伪优势”，而不是严格意义上的分辨性能提升。

### 4.4 为什么大间隔时 `bw/1`、`bw/2` 会失败

这部分主要和波束域平滑后只保留中间波束有关。

`Route A` 中有如下逻辑：

```matlab
Q = 10;
celln = size(Xc, 1) - Q;
beam_start = floor((size(A, 2) - celln) / 2) + 1;
beam_ind = beam_start : beam_start + celln - 1;
```

当前 `A_old` 一共是 `51` 个波束，`celln = 41`，因此最终只保留中间连续的 `41` 个波束，相当于左右两端各丢掉 `5` 个边缘波束。

而在 `bw/1` 时，真实目标位于：

$$
\theta_c \pm \frac{\mathrm{bw}_{64}}{2}
$$

这正好对应完整局部扇区的两端边界。此时如果又丢掉边缘波束，那么真实目标对应的波束域 steering 信息会出现明显失配，结果就是：

- 大角间隔时，两个目标更靠近旧路线扇区边缘；
- 平滑后又只取中心波束；
- 因而更难形成两个稳定谱峰；
- 最终出现 `bw/1`、`bw/2` 检测失败。

所以 `Route A` 的真实规律更接近：

- `bw/1`、`bw/2`：边缘失配主导，导致失败
- `bw/3 ~ bw/10`：目标进入中心波束区，同时叠加边界锁定效应，`RMSE` 被异常压低

### 4.5 Route A 的 RMSE 统计还有一个隐藏偏置

主脚本中 `RMSE` 的累计逻辑为：

```matlab
if raw_ok
    sqerr = sum((sort(doa_est(:).') - sort(target_theta(:).')).^2);
    rmse_sum_sqerr = rmse_sum_sqerr + sqerr;
    rmse_valid_count = rmse_valid_count + 1;
end
```

对应公式为：

$$
\mathrm{RMSE} =
\sqrt{
\frac{\sum (\hat{\theta}_1-\theta_1)^2 + (\hat{\theta}_2-\theta_2)^2}
{2N_{\mathrm{valid}}}
}
$$

其中 `N_valid` 只统计 `raw_ok` 的样本。

这意味着失败样本不会拉高 `RMSE`，而只会体现在 `raw_success` 和 `tol_success` 上。因此像 `Route A` 这种“失败时直接记为 `NaN`，成功时误差又极小”的情况，会让 `RMSE` 显得特别漂亮，但它并不代表整档位总体风险很低。

---

## 5. Route B 的代码逻辑与趋势来源

`Route B` 的核心函数为 [DOA_three_music_new_route_centerT.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_space_smooth_music/DOA_three_music_new_route_centerT.m)。

### 5.1 Route B 的搜索窗口更宽，没有边界锁定优势

主脚本中：

```matlab
theta_search_new = search_scale * theta_bw(angle_grid_num);
search_scale = 4;
```

随后传入 `Route B`：

```matlab
doa_center_1d = DOA_three_music_new_route_centerT( ...
    y_sub, subarray_num, T_center, RecvbeamC, theta_search_new);
```

而 `Route B` 内部同样使用：

```matlab
angle_search = angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2;
```

注意这里传入的 `theta_bw` 已经不是原始双目标间隔，而是：

$$
\theta_{\mathrm{search}} = 4 \Delta\theta
$$

因此 `Route B` 的实际搜索区间为：

$$
[\theta_c - 2\Delta\theta, \ \theta_c + 2\Delta\theta]
$$

而真实目标位于：

$$
[\theta_c - \frac{\Delta\theta}{2}, \ \theta_c + \frac{\Delta\theta}{2}]
$$

所以真实目标是在搜索窗口内部，而不是边界上。这样一来，`Route B` 必须真的在谱内部形成两个局部峰，不能像 `Route A` 那样天然占据边界位置。

### 5.2 当前 Route B 不是严格意义上的完整 FBSS

`Route B` 中协方差处理逻辑为：

```matlab
Rxx = y * y' / n;
Rx = mssp(Rxx, subarray_num);
Rb = T_center.' * Rx * conj(T_center);
```

其中 [mssp.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_space_smooth_music/mssp.m) 定义为：

```matlab
[M, ~] = size(cr);
N = M - k + 1;
```

当前调用时：

- `Rxx` 的维度就是 `subarray_num x subarray_num`
- `k = subarray_num`

所以：

$$
N = M - k + 1 = 1
$$

这说明当前 `Route B` 并没有实际对多个重叠子阵做平均，而是退化成了：

1. 前后向平均；
2. 直接输出整个协方差矩阵；
3. 再做 `centerT` 投影与波束域 `MUSIC`。

因此它更准确的描述应当是：

$$
\text{阵元域前后向平均} \rightarrow \text{centerT 投影} \rightarrow \text{beamspace MUSIC}
$$

而不是严格意义上的“完整空间平滑后再做 MUSIC”。

### 5.3 为什么小间隔时 Route B 更容易退化

对于两个完全相干源，可以写成：

$$
y(t) = \left[a(\theta_1) + a(\theta_2)\right] s(t) + n(t)
$$

其理想信号协方差近似为：

$$
R_s =
\sigma_s^2
\left[a(\theta_1)+a(\theta_2)\right]
\left[a(\theta_1)+a(\theta_2)\right]^H
$$

它本质上接近秩 `1`。

严格空间平滑的目的，是通过多个重叠子阵求均值，恢复相干源的有效秩：

$$
R_{\mathrm{ss}} =
\frac{1}{P}
\sum_{p=1}^{P}
J_p R_x J_p^H
$$

其中 `P` 是可用子阵数。

但在当前 `Route B` 中，实际上相当于：

$$
P = 1
$$

所以并没有真正形成完整的去相干平滑效果。于是当目标越来越近时：

$$
\theta_2 - \theta_1 \downarrow
$$

两个导向矢量会越来越接近：

$$
a(\theta_1) \approx a(\theta_2)
$$

信号子空间之间更难分开，噪声和有限快拍带来的协方差估计误差也会更容易破坏峰值分离。因此 `Route B` 在小间隔端表现为：

- `RMSE` 增大
- `tol_success` 下降
- 快拍数不足时更容易出现 `NaN`

这反而更符合常规 DOA 分辨理论的直觉。

### 5.4 为什么增大 `T_snap` 对 Route B 改善明显

样本协方差定义为：

$$
\hat{R}_x = \frac{1}{T_{\mathrm{snap}}} Y Y^H
$$

当 `T_snap` 增大时，样本协方差会更接近真实协方差，其估计误差通常随快拍数增加而降低，可写成：

$$
\left\|\hat{R}_x - R_x\right\| = O\left(T_{\mathrm{snap}}^{-1/2}\right)
$$

因此：

- `T_snap = 130`：协方差波动大，小间隔端最不稳定
- `T_snap = 260`：有明显改善
- `T_snap = 520`：近间隔端进一步稳定

这与当前结果一致。例如在小间隔端，`Route B` 的 `tol_success` 会随 `T_snap` 提升而明显改善，`RMSE` 也同步下降。

---

## 6. A/B 对比为什么目前并不完全公平

当前两条路线最重要的不公平点在于搜索窗口设计不同。

### 6.1 Route A

搜索区间：

$$
[\theta_c - \frac{\Delta\theta}{2}, \ \theta_c + \frac{\Delta\theta}{2}]
$$

真实目标恰好在边界。

### 6.2 Route B

搜索区间：

$$
[\theta_c - 2\Delta\theta, \ \theta_c + 2\Delta\theta]
$$

真实目标在内部。

因此当前对比中：

- `Route A` 更容易享受边界锁定带来的低 `RMSE`
- `Route B` 更接近真实搜索问题

所以不能简单根据当前结果下结论说：

- `Route A` 天生比 `Route B` 更擅长小间隔

更合理的结论应当是：

- `Route A` 的小间隔超低 `RMSE` 明显受实验窗口设计影响；
- `Route B` 的趋势更能反映真实分辨难度随间隔缩小而上升的规律。

---

## 7. 对两个问题的直接回答

### 问题 1：为什么 Route A 在大角间隔有两个档位失效，而在小角间隔时 RMSE 反而迅速下降？

原因不是单一的，而是两个机制叠加：

1. 大角间隔时，目标更靠近旧路线波束扇区边缘，而 `Route A` 平滑后只保留中间波束，导致边缘失配变重，所以 `bw/1`、`bw/2` 失败。
2. 小角间隔时，目标进入中心波束区域，同时搜索窗口又恰好把真实角放在边界，边界点可直接被判成峰值，因此 `RMSE` 被异常压低，甚至接近 `0`。

所以 `Route A` 的结果不能直接解释成“目标越近越容易分辨”，它更多体现的是当前实验设计中的边界效应。

### 问题 2：为什么 Route B 则相反，大角间隔没问题，小角间隔反而更容易出问题？

原因主要有三点：

1. `Route B` 的搜索窗口更宽，真实目标不在边界上，没有边界锁定优势。
2. 当前 `Route B` 的 `mssp(Rxx, subarray_num)` 实际上退化为前后向平均，并没有真正利用多个重叠子阵做完整空间平滑。
3. 在相干双目标下，小角间隔本来就更难分辨；快拍数不足时，协方差估计误差会进一步放大这个问题。

因此 `Route B` 的趋势更符合通常的 DOA 分辨直觉：目标越近，越难分开；快拍越多，估计越稳定。

---

## 8. 当前阶段的合理结论

结合代码和结果，当前更稳妥的结论是：

1. `Route A` 的小间隔超低 `RMSE` 不能直接视为真实性能优势，它明显受搜索边界与峰值判定逻辑影响。
2. `Route A` 在大间隔端失败，主要与边缘目标在波束域平滑后发生失配有关。
3. `Route B` 的结果趋势整体更符合物理直觉，但当前实现还不是严格完整的空间平滑版本。
4. `T_snap` 的提升对 `Route B` 有明显帮助，这说明其主要瓶颈之一确实是有限快拍下的协方差估计误差。
5. 如果要做更公平的 A/B 对比，下一步应统一两条路线的搜索窗口设计，并避免把真实目标固定放在 `Route A` 的搜索边界上。

---

## 9. 建议的后续检查方向

如果后续要继续验证，建议优先检查以下几点：

1. 让 `Route A` 和 `Route B` 使用同尺度的搜索窗口，避免边界锁定偏置。
2. 修改峰值检测逻辑，避免默认允许边界点直接作为峰值。
3. 将 `Route B` 改成真正的多重叠子阵空间平滑，而不是当前的退化 `mssp` 调用方式。
4. 在统计指标中区分“成功样本 RMSE”和“包含失败惩罚的综合指标”，避免单看 `RMSE` 产生误判。

以上几点如果不先统一，当前 A/B 数值对比仍然带有较强的实验设置偏置。
