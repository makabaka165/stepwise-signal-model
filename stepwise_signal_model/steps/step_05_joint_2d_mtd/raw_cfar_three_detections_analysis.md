# 第 5 步 raw CFAR 检测结果分析

链路：

```text
阵元级回波 -> 距离脉压 -> 局部五波束形成 -> 五波束 MTD -> 中心束距离向 CFAR
```

其中：

- MTD 对局部五波束全部处理。
- CFAR 只取中心束处理。

## 当前运行结果

当前 MATLAB MCP 运行输出为：

```text
raw=3

[1] R=3200.0 m, v=56.2 m/s, metric=11.6925, threshold=10.1918, ratio=1.1473
[2] R=3200.0 m, v=46.9 m/s, metric=125.9486, threshold=111.6883, ratio=1.1277
[3] R=3200.0 m, v=37.5 m/s, metric=48.6376, threshold=44.0545, ratio=1.1040
```

目标真值为：

```text
R = 3200.0 m
v = 45.0 m/s
az = 8.0 deg
el = 10.0 deg
```

所以当前结果不是检测出 3 个物理目标，而是同一个目标在中心束 RD 图上形成了 3 个过门限的离散检测单元。

## MTD 处理的是哪些波束

局部五波束的顺序是：

```text
1 方位左束
2 中心束
3 方位右束
4 俯仰下束
5 俯仰上束
```

波束形成后的数据维度是：

$$
\text{beamCube} \in \mathbb{C}^{5 \times N_R \times N_p}
$$

其中第 1 维是波束，第 2 维是距离采样，第 3 维是脉冲慢时间。

MTD 对五个波束全部做 Doppler FFT：

$$
\text{rdCube} = \operatorname{fftshift}
\left\{
\operatorname{FFT}_{p}
\left[
\text{beamCube} \cdot w_{\text{slow}}(p)
\right]
\right\}
$$

输出维度是：

$$
\text{rdCube} \in \mathbb{C}^{5 \times N_R \times N_D}
$$

也就是：

```text
rdCube: [波束 x 距离 x Doppler]
```

因此 MTD 不是只针对中心束，而是对五个局部波束都做了处理。

## CFAR 针对哪个波束

当前 CFAR 只取中心束：

```matlab
rdCtr = squeeze(rdCube(2, :, :));
CFARInput = rdCtr.';
```

其中 `rdCube(2, :, :)` 表示第 2 个波束，即中心束。

转置后：

$$
\text{CFARInput} \in \mathbb{C}^{N_D \times N_R}
$$

也就是：

```text
CFARInput: [Doppler x Range]
```

所以 CFAR 的处理含义是：

```text
每一行固定一个 Doppler bin，沿距离维做 1D CFAR。
```

## CFAR 判决公式

当前配置是：

```matlab
TypeCase = 'CA';
DeTypeCase = 'Square';
nGuard = 2;
nRef = 8;
Pfa = 1e-7;
```

### 平方律检测

`DeTypeCase = 'Square'` 时，检测量是功率：

$$
Z(k,r) = |X(k,r)|^2
$$

其中：

- \(k\) 是 Doppler bin 索引。
- \(r\) 是距离 bin 索引。
- \(X(k,r)\) 是中心束 RD 图上的复数值。

代码对应：

```matlab
CFARInput = abs(CFARInput) .^ 2;
```

### CA-CFAR 背景估计

对某个待检测单元 CUT：

$$
Z_{\text{CUT}} = Z(k,r)
$$

保护单元数量为 \(G\)，单侧参考单元数量为 \(M\)。当前：

$$
G = 2,\quad M = 8
$$

在中间区域，左右两侧参考窗分别为：

$$
\mathcal{R}_{L}
= \{r-G-M,\ldots,r-G-1\}
$$

$$
\mathcal{R}_{R}
= \{r+G+1,\ldots,r+G+M\}
$$

左侧平均背景：

$$
\mu_L(k,r)
= \frac{1}{M}\sum_{i \in \mathcal{R}_{L}} Z(k,i)
$$

右侧平均背景：

$$
\mu_R(k,r)
= \frac{1}{M}\sum_{i \in \mathcal{R}_{R}} Z(k,i)
$$

`TypeCase = 'CA'` 时，左右平均：

$$
\mu(k,r)
= \frac{\mu_L(k,r) + \mu_R(k,r)}{2}
$$

### 门限因子

代码中的：

```matlab
D_Threshold = 2 * ReferenCell * (Pfa ^ (-1 / (2 * ReferenCell)) - 1);
```

是门限因子，通常记作：

$$
\alpha
$$

CA-CFAR 平方律检测中，如果总参考单元数为：

$$
N = 2M
$$

则门限因子为：

$$
\alpha = N\left(P_{\mathrm{fa}}^{-1/N} - 1\right)
$$

当前 \(M = \text{ReferenCell}\)，所以：

$$
N = 2\,\text{ReferenCell}
$$

代入得到：

$$
\alpha
= 2\,\text{ReferenCell}
\left(
P_{\mathrm{fa}}^{-1/(2\,\text{ReferenCell})}
- 1
\right)
$$



### 最终门限

每个 CUT 的最终门限是：

$$
T(k,r) = \alpha \, \mu(k,r)
$$

判决条件是：

$$
Z(k,r) \ge T(k,r)
$$

也就是：

$$
\frac{Z(k,r)}{\alpha \, \mu(k,r)} \ge 1
$$

代码中：

```matlab
y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
temp = find(y2(:, jj) >= 1);
```

其中：

- `CFARInput(:, jj)` 是 \(Z(k,r)\)。
- `miu` 是 \(\mu(k,r)\)。
- `D_Threshold` 是 \(\alpha\)。
- `y2` 是检测量与门限的比值。

因此：

$$
y2(k,r)
= \frac{Z(k,r)}{T(k,r)}
= \frac{Z(k,r)}{\alpha \mu(k,r)}
$$

当 \(y2(k,r) \ge 1\) 时，该单元就是 raw CFAR 检测单元。

门限图由下面这句反推：

```matlab
thrMap = CFARInput ./ y2;
```

因为：

$$
y2 = \frac{Z}{T}
$$

所以：

$$
T = \frac{Z}{y2}
$$

也就是：

$$
\text{thrMap} = T
$$

## 为什么不是 1 个检测单元

关键原因是：

```text
CFAR 检测的是 RD 网格上的离散单元，不是直接检测物理目标个数。
```

一个真实目标经过 MTD 后，在 RD 图上不是理想的一个孤立点，而是一个二维主瓣。只要主瓣内多个离散 bin 都超过各自 CFAR 门限，它们都会被作为 raw 检测单元输出。

当前 3 个 raw 点的距离都是：

$$
R = 3200\ \mathrm{m}
$$

但 Doppler 速度分别是：

$$
37.5,\quad 46.875,\quad 56.25\ \mathrm{m/s}
$$

这说明目标主要在同一个距离 bin 上，但在 Doppler 方向扩展到了相邻 3 个 bin。

## Doppler bin 间隔

速度轴由代码计算：

```matlab
fdAxis = ((0:nfft - 1) - floor(nfft / 2)) / (nfft * PRI);
vAxis = -fdAxis * lambda / 2;
```

Doppler 频率分辨率是：

$$
\Delta f_D = \frac{1}{N_p \cdot PRI}
$$

速度分辨率是：

$$
\Delta v
= \frac{\lambda}{2}\Delta f_D
= \frac{\lambda}{2N_p PRI}
$$

当前参数：

$$
\lambda = 0.03\ \mathrm{m}
$$

$$
N_p = 32
$$

$$
PRI = 50\times 10^{-6}\ \mathrm{s}
$$

所以：

$$
\Delta v
= \frac{0.03}{2 \times 32 \times 50\times 10^{-6}}
= 9.375\ \mathrm{m/s}
$$

目标速度真值：

$$
v_{\mathrm{tgt}} = 45\ \mathrm{m/s}
$$

而速度 bin 附近为：

$$
37.5,\quad 46.875,\quad 56.25\ \mathrm{m/s}
$$

目标速度没有正好落在 FFT bin 中心上。最接近的是：

$$
46.875\ \mathrm{m/s}
$$

偏差为：

$$
46.875 - 45 = 1.875\ \mathrm{m/s}
$$

相对于 bin 间隔：

$$
\frac{1.875}{9.375} = 0.2
$$

也就是说，目标 Doppler 是 off-grid 的，不在整数 Doppler bin 上。

## off-grid Doppler 导致频谱泄漏

慢时间信号可以写成：

$$
x[p] = A e^{j2\pi f_D p PRI},\quad p=0,1,\ldots,N_p-1
$$

MTD 对慢时间加窗并做 FFT：

$$
X[k]
= \sum_{p=0}^{N_p-1}
x[p]\,w[p]\,
e^{-j2\pi kp/N_p}
$$

代入 \(x[p]\)：

$$
X[k]
= A \sum_{p=0}^{N_p-1}
w[p]\,
e^{j2\pi (f_D - f_k)pPRI}
$$

其中：

$$
f_k = \frac{k}{N_p PRI}
$$

如果 \(f_D = f_k\)，目标 Doppler 正好落在某个 FFT bin 上，能量会最集中。

但当前：

$$
f_D \ne f_k
$$

所以能量不会只落在一个 Doppler bin，而会按照窗函数频响分布到相邻 bin。

当前代码还使用 Hamming 慢时间窗：

```matlab
slowWin = hamming(nPulse);
```

Hamming 窗的特点是：

- 降低远旁瓣。
- 主瓣比矩形窗更宽。

因此目标能量在 Doppler 方向会覆盖多个相邻 bin。当前就表现为同一距离 bin 上有 3 个 Doppler bin 超过 CFAR 门限。

## 为什么距离方向只有一个 bin

当前 3 个 raw 点的距离索引相同：

```text
rangeIdx = 1251
R = 3200.0 m
```

说明距离脉压后，目标在距离维主要集中在这个 range bin。

相邻距离 bin 虽然也可能有脉压主瓣或旁瓣能量，但没有超过对应的 CFAR 门限，因此没有被输出为 raw 检测单元。

换句话说，当前现象是：

```text
距离维：只有 1 个 bin 过门限
Doppler 维：有 3 个 bin 过门限
```

所以最终 raw CFAR 检测数量是：

```text
1 x 3 = 3
```

## 3 个 raw 点对应的判决

这次输出中，三个点的比值分别是：

| 速度 | metric | threshold | ratio |
|---:|---:|---:|---:|
| 56.2 m/s | 11.6925 | 10.1918 | 1.1473 |
| 46.9 m/s | 125.9486 | 111.6883 | 1.1277 |
| 37.5 m/s | 48.6376 | 44.0545 | 1.1040 |

三者都满足：

$$
\frac{\text{metric}}{\text{threshold}} > 1
$$

因此三者都会被输出为 raw CFAR 检测单元。

其中 `46.9 m/s` 这一项最接近真值速度 `45 m/s`，而且 metric 最大。但当前脚本已经不再把它单独选为最终目标。

## raw 检测单元与目标个数的关系

raw CFAR 输出的是：

```text
哪些 RD 网格单元超过门限
```

它不等价于：

```text
物理目标个数
```

当前应该理解为：

```text
1 个物理目标
-> 在中心束 RD 图上形成一个主瓣
-> 主瓣覆盖同一距离上的 3 个 Doppler bin
-> 3 个 Doppler bin 都超过 CFAR 门限
-> raw CFAR 输出 3 个检测单元
```

## 如果后续需要 1 个目标结果

如果最终需要输出 1 个目标，而不是 raw 检测单元，需要在 CFAR 后面再做后处理，例如：

- 取局部峰值。
- 非极大值抑制。
- 聚类后取簇中心或簇内最大值。
- 在同一距离附近合并相邻 Doppler 检测。
- 在同一目标门限范围内取最大 metric 单元。

但这些都属于 raw CFAR 之后的目标级处理，不是当前 raw CFAR 检测本身。

当前脚本按照“直接输出 raw 检测目标”的要求，没有执行这些后处理。
