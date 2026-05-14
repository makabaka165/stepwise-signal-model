# 第 8 步：虚拟阵列插值 + 空间平滑 + Beamspace MUSIC

## 1. 文档目的

本文整理“虚拟阵列插值后平滑”的完整分析、算法思路、公式、实现路径和参数建议，用于在当前工程中新增一条比“直接把波束编号当阵元编号”更严格、又比“beamspace 协方差重构”更容易落地的相干源 DOA 超分辨路线。

这条路线的核心思想可以概括为：

1. 先把局部波束域响应线性变换成一个**近似虚拟 ULA 响应**；
2. 再在这个虚拟 ULA 上做 **FBSS / MSSP**；
3. 最后对平滑后的虚拟阵列协方差做 **MUSIC**。

---

## 2. 当前问题与路线选择

当前旧代码中的关键处理是：

```matlab
sr_DBF_boshu = A.' * y;
```

然后直接把 `sr_DBF_boshu` 的每一行当成“相邻阵元”，继续做 MSSP 或 FBSS。

这一点理论上不严格。原因在于：

- 空间平滑成立的根基是**物理子阵平移不变性**；
- 但 `A.' * y` 得到的是**波束输出**，不是 ULA 阵元输出；
- 相邻波束索引并不等价于相邻阵元索引。

如果导向向量是物理 ULA 的

$$
\mathbf{a}_N(\theta) =
\begin{bmatrix}
1 & e^{-jku} & e^{-j2ku} & \cdots & e^{-j(N-1)ku}
\end{bmatrix}^{T},
$$

其中

$$
u = \frac{d \sin\theta}{\lambda}, \qquad k = 2\pi,
$$

则对真实子阵选择矩阵 $\mathbf{J}_\ell$ 有

$$
\mathbf{J}_\ell \mathbf{a}_N(\theta)
= e^{-jk(\ell-1)u}\,\mathbf{a}_L(\theta).
$$

这就是空间平滑所依赖的“移位只带来相位因子”的结构。

但波束域响应是

$$
\mathbf{b}(\theta) = \mathbf{W}^{H}\mathbf{a}(\theta),
$$

或者在当前工程实现里写成

$$
\mathbf{b}(\theta) = \mathbf{A}^{T}\mathbf{a}(\theta).
$$

这里的 $\mathbf{b}(\theta)$ 是一组波束响应，不再自动满足上面的 ULA 平移不变性。

因此，当前路线的问题不是 MUSIC 本身，而是：

> 先做局部 beamforming，再把相邻波束当相邻阵元去平滑，这一步缺少严格理论基础。

---

## 3. 为什么优先选“虚拟阵列插值”而不是“beamspace 矩阵重构”

对于“第二条路线：beamspace covariance / matrix reconstruction”和“第三条路线：虚拟阵列插值后平滑”，当前更建议先做第三条路线，原因如下。

### 3.1 第二条路线的特点

第二条路线试图从

$$
\mathbf{R}_b = \mathbf{W}^{H}\mathbf{R}_x\mathbf{W}
$$

反推或重构阵元域协方差 $\mathbf{R}_x$，然后再在重构后的矩阵上做 Toeplitz 约束、空间平滑、MUSIC。

这条路线的主要难点是：

1. 本质上是一个**结构化逆问题**；
2. 需要同时处理 Hermitian、Toeplitz、半正定、秩特征等约束；
3. 对当前这种**窄扇区局部 beam bank**，信息量未必足以稳定重构整个阵元域协方差；
4. 更像一条独立算法分支，不是现有脚本上的轻量修改。

### 3.2 第三条路线的特点

第三条路线不试图重构完整阵元域协方差，而是直接在局部 beamspace 中设计一个插值矩阵，把 beamspace steering 变成近似 ULA steering：

$$
\mathbf{X}\mathbf{b}(\theta) \approx \mathbf{a}_v(\theta).
$$

这样做的优点是：

1. 与当前 `A.' * y` 的局部 beamspace 框架高度兼容；
2. 不需要回退到完整阵元域协方差重构；
3. 数学结构更清晰，便于写出自己的推导；
4. 适合作为当前工程中的实验版和论文解释版。

因此，本文重点整理第三条路线。

---

## 4. 虚拟阵列插值路线的总思路

一句话概括：

> 把 beamspace 响应向量线性变形成一个近似虚拟 ULA 导向向量，再在这个虚拟 ULA 上做 FBSS / MSSP 和 MUSIC。

整体流程可以写成：

$$
\text{阵元快拍 } \mathbf{y}(t)
\;\to\;
\text{局部 beamspace 快拍 } \mathbf{b}(t)
\;\to\;
\text{虚拟阵列快拍 } \mathbf{x}_v(t)
\;\to\;
\mathbf{R}_v
\;\to\;
\mathbf{R}_{\mathrm{ss}}
\;\to\;
\text{MUSIC 谱搜索}.
$$

更具体地说：

1. 构造局部波束形成矩阵 $\mathbf{A}$；
2. 形成 beamspace 快拍
   $$
   \mathbf{b}(t) = \mathbf{A}^{T}\mathbf{y}(t);
   $$
3. 设计插值矩阵 $\mathbf{X}$，使得
   $$
   \mathbf{X}\mathbf{b}(\theta) \approx \mathbf{a}_v(\theta);
   $$
4. 用 $\mathbf{X}$ 生成虚拟阵列快拍
   $$
   \mathbf{x}_v(t) = \mathbf{X}\mathbf{b}(t);
   $$
5. 在虚拟阵列上做空间平滑，得到
   $$
   \mathbf{R}_{\mathrm{ss}};
   $$
6. 对 $\mathbf{R}_{\mathrm{ss}}$ 做 MUSIC 谱搜索并找峰值。

---

## 5. 信号模型与 beamspace 模型

设阵元域接收模型为

$$
\mathbf{y}(t)=\sum_{q=1}^{Q}\mathbf{a}(\theta_q)s_q(t)+\mathbf{n}(t).
$$

对 $T$ 个快拍记为矩阵形式：

$$
\mathbf{Y}=
\begin{bmatrix}
\mathbf{y}(1) & \mathbf{y}(2) & \cdots & \mathbf{y}(T)
\end{bmatrix}
=
\mathbf{A}_s(\Theta)\mathbf{S}+\mathbf{N}.
$$

其中：

- $\mathbf{A}_s(\Theta)$ 为阵元域 steering matrix；
- $\mathbf{S}$ 为源信号矩阵；
- $\mathbf{N}$ 为噪声矩阵。

阵元域协方差为

$$
\mathbf{R}_x = \mathbb{E}[\mathbf{y}(t)\mathbf{y}^{H}(t)]
= \mathbf{A}_s\mathbf{R}_s\mathbf{A}_s^{H} + \sigma^2 \mathbf{I}.
$$

进入局部 beamspace 后：

$$
\mathbf{b}(t)=\mathbf{W}^{H}\mathbf{y}(t),
$$

在当前工程代码里可等价理解为

$$
\mathbf{b}(t)=\mathbf{A}^{T}\mathbf{y}(t).
$$

于是 beamspace 协方差为

$$
\mathbf{R}_b = \mathbb{E}[\mathbf{b}(t)\mathbf{b}^{H}(t)]
= \mathbf{W}^{H}\mathbf{R}_x\mathbf{W}.
$$

对于单个方向 $\theta$，beamspace steering 为

$$
\mathbf{g}(\theta)=\mathbf{W}^{H}\mathbf{a}(\theta),
$$

在当前脚本中可直接写成

$$
\mathbf{g}(\theta)=\mathbf{A}^{T}\mathbf{a}(\theta).
$$

下面的插值目标就是让 $\mathbf{g}(\theta)$ 在线性变换后近似成为虚拟 ULA steering。

---

## 6. 虚拟阵列模型

设计一个长度为 $L_v$ 的虚拟 ULA，其导向向量定义为

$$
\mathbf{a}_v(\theta)=
\begin{bmatrix}
1 & e^{-jku} & e^{-j2ku} & \cdots & e^{-j(L_v-1)ku}
\end{bmatrix}^{T},
$$

其中

$$
u=\frac{d\sin\theta}{\lambda}.
$$

我们的目标是找到一个插值矩阵 $\mathbf{X}\in\mathbb{C}^{L_v\times B}$，使得对扇区内感兴趣角度 $\theta$ 有

$$
\mathbf{X}\mathbf{g}(\theta)\approx \mathbf{a}_v(\theta).
$$

也就是

$$
\mathbf{X}\mathbf{A}^{T}\mathbf{a}(\theta)\approx \mathbf{a}_v(\theta).
$$

如果这个近似足够好，那么经过变换后的虚拟阵列快拍

$$
\mathbf{x}_v(t)=\mathbf{X}\mathbf{b}(t)
$$

就可以被当成一个近似 ULA 的接收快拍来处理。

---

## 7. 为什么插值后可以做空间平滑

虚拟 ULA 满足标准的平移不变性。

若虚拟阵列长度为 $L_v$，从中取长度为 $K$ 的重叠子阵，令 $\mathbf{J}_p$ 为第 $p$ 个子阵的选择矩阵，则有

$$
\mathbf{J}_p \mathbf{a}_v(\theta)
= e^{-jk(p-1)u}\mathbf{a}_K(\theta),
$$

其中 $\mathbf{a}_K(\theta)$ 是长度为 $K$ 的虚拟子阵导向向量。

这正是 FBSS / MSSP 能恢复相干源秩的根基。

因此，这条路线并不是声称“波束编号就是阵元编号”，而是说：

1. beamspace 本身不具备 ULA 平移结构；
2. 通过插值矩阵 $\mathbf{X}$，把 beamspace steering 近似变成虚拟 ULA steering；
3. 然后在这个虚拟 ULA 上合法地做空间平滑。

需要注意的是，这里成立的是近似关系：

$$
\mathbf{X}\mathbf{g}(\theta)=\mathbf{a}_v(\theta)+\mathbf{e}(\theta),
$$

其中 $\mathbf{e}(\theta)$ 是插值误差。误差越小，后续平滑和 MUSIC 越可靠。

---

## 8. 插值矩阵的设计

### 8.1 扇区内最小二乘拟合

在感兴趣扇区内选取一组训练角度

$$
\Theta_{\mathrm{in}}=\{\theta_1,\theta_2,\ldots,\theta_G\}.
$$

对每个训练角度构造：

$$
\mathbf{g}(\theta_i)=\mathbf{A}^{T}\mathbf{a}(\theta_i),
$$

$$
\mathbf{a}_v(\theta_i).
$$

把它们拼成矩阵：

$$
\mathbf{G}_{\mathrm{in}}=
\begin{bmatrix}
\mathbf{g}(\theta_1) & \mathbf{g}(\theta_2) & \cdots & \mathbf{g}(\theta_G)
\end{bmatrix}
\in\mathbb{C}^{B\times G},
$$

$$
\mathbf{A}_v=
\begin{bmatrix}
\mathbf{a}_v(\theta_1) & \mathbf{a}_v(\theta_2) & \cdots & \mathbf{a}_v(\theta_G)
\end{bmatrix}
\in\mathbb{C}^{L_v\times G}.
$$

最基础的插值设计是解下面的 Frobenius 范数最小二乘问题：

$$
\min_{\mathbf{X}}
\left\|
\mathbf{X}\mathbf{G}_{\mathrm{in}}-\mathbf{A}_v
\right\|_F^2.
$$

其闭式解可写为

$$
\mathbf{X}
=
\mathbf{A}_v\mathbf{G}_{\mathrm{in}}^{H}
\left(
\mathbf{G}_{\mathrm{in}}\mathbf{G}_{\mathrm{in}}^{H}
\right)^{-1},
$$

或者更稳妥地通过广义逆实现。

### 8.2 加正则化的拟合

由于该问题往往病态，工程上更建议解

$$
\min_{\mathbf{X}}
\left\|
\mathbf{X}\mathbf{G}_{\mathrm{in}}-\mathbf{A}_v
\right\|_F^2
\;+\;
\lambda
\left\|
\mathbf{X}
\right\|_F^2,
$$

其中 $\lambda > 0$ 是正则化参数。

闭式解为

$$
\mathbf{X}
=
\mathbf{A}_v\mathbf{G}_{\mathrm{in}}^{H}
\left(
\mathbf{G}_{\mathrm{in}}\mathbf{G}_{\mathrm{in}}^{H}
\;+\;
\lambda\mathbf{I}
\right)^{-1}.
$$

这一步的作用是抑制病态逆带来的噪声增强。

### 8.3 加入扇区外抑制

仅做扇区内拟合还不够，因为最小二乘可能会把扇区外响应放大得很厉害。为了抑制扇区外泄漏，可在扇区外选取训练网格

$$
\Theta_{\mathrm{out}}=\{\phi_1,\phi_2,\ldots,\phi_M\},
$$

构造

$$
\mathbf{G}_{\mathrm{out}}=
\begin{bmatrix}
\mathbf{g}(\phi_1) & \mathbf{g}(\phi_2) & \cdots & \mathbf{g}(\phi_M)
\end{bmatrix}.
$$

然后解下面的问题：

$$
\min_{\mathbf{X}}
\left\|
\mathbf{X}\mathbf{G}_{\mathrm{in}}-\mathbf{A}_v
\right\|_F^2
\;+\;
\mu
\left\|
\mathbf{X}\mathbf{G}_{\mathrm{out}}
\right\|_F^2
\;+\;
\lambda
\left\|
\mathbf{X}
\right\|_F^2,
$$

其中：

- 第一项保证扇区内逼近虚拟 ULA；
- 第二项抑制扇区外响应；
- 第三项抑制插值矩阵本身过度放大。

对应闭式解为

$$
\mathbf{X}
=
\mathbf{A}_v\mathbf{G}_{\mathrm{in}}^{H}
\left(
\mathbf{G}_{\mathrm{in}}\mathbf{G}_{\mathrm{in}}^{H}
\;+\;
\mu\mathbf{G}_{\mathrm{out}}\mathbf{G}_{\mathrm{out}}^{H}
\;+\;
\lambda\mathbf{I}
\right)^{-1}.
$$

这是一个非常适合工程实现的版本。

### 8.4 可选的加权版本

如果更关心扇区中心而不是边缘，也可以对扇区内训练角度加权：

$$
\min_{\mathbf{X}}
\left\|
\left(
\mathbf{X}\mathbf{G}_{\mathrm{in}}-\mathbf{A}_v
\right)\mathbf{\Omega}^{1/2}
\right\|_F^2
\;+\;
\mu
\left\|
\mathbf{X}\mathbf{G}_{\mathrm{out}}
\right\|_F^2
\;+\;
\lambda
\left\|
\mathbf{X}
\right\|_F^2,
$$

其中 $\mathbf{\Omega}$ 是对训练角度的对角权矩阵。

---

## 9. 从 beamspace 快拍到虚拟阵列快拍

一旦插值矩阵 $\mathbf{X}$ 设计好，就可以直接对 beamspace 快拍做线性变换：

$$
\mathbf{x}_v(t)=\mathbf{X}\mathbf{b}(t).
$$

对所有快拍写成矩阵形式：

$$
\mathbf{X}_v
=
\mathbf{X}\mathbf{B},
$$

其中

$$
\mathbf{B}=
\begin{bmatrix}
\mathbf{b}(1) & \mathbf{b}(2) & \cdots & \mathbf{b}(T)
\end{bmatrix}.
$$

于是虚拟阵列协方差可由样本协方差估计为

$$
\mathbf{R}_v
=
\frac{1}{T}\mathbf{X}_v\mathbf{X}_v^{H}.
$$

如果只保留 beamspace 协方差，也可写成

$$
\mathbf{R}_v
=
\mathbf{X}\mathbf{R}_b\mathbf{X}^{H}.
$$

在当前工程里，保留快拍并直接使用

$$
\mathbf{X}_v=\mathbf{X}\,\mathbf{sr\_DBF\_boshu}
$$

是最自然的实现方式。

---

## 10. 虚拟阵列域的空间平滑

设虚拟阵列长度为 $L_v$，平滑子阵长度为 $K$，则重叠子阵个数为

$$
P = L_v - K + 1.
$$

### 10.1 前向空间平滑

第 $p$ 个子阵的选择矩阵记为 $\mathbf{J}_p$，则前向平滑协方差为

$$
\mathbf{R}_f
=
\frac{1}{P}
\sum_{p=1}^{P}
\mathbf{J}_p \mathbf{R}_v \mathbf{J}_p^{H}.
$$

### 10.2 前后向空间平滑

令反序矩阵为

$$
\mathbf{J}=
\begin{bmatrix}
0 & \cdots & 0 & 1\\
0 & \cdots & 1 & 0\\
\vdots & \iddots & \vdots & \vdots\\
1 & \cdots & 0 & 0
\end{bmatrix},
$$

则前后向平滑可写为

$$
\mathbf{R}_{\mathrm{fb}}
=
\frac{1}{2}
\left(
\mathbf{R}_f
\;+\;
\mathbf{J}\mathbf{R}_f^{*}\mathbf{J}
\right).
$$

在当前仓库中，已有的 `mssp.m` 已经实现了“前后向平均 + 重叠子阵平均”的处理思想，因此第三路线完全可以继续复用该函数。

---

## 11. 平滑后的 MUSIC 谱搜索

对平滑后的协方差 $\mathbf{R}_{\mathrm{ss}}$（可取前向平滑结果或前后向平滑结果）进行特征分解：

$$
\mathbf{R}_{\mathrm{ss}}
=
\mathbf{E}\mathbf{\Lambda}\mathbf{E}^{H}.
$$

若已知信号数为 $Q$，则噪声子空间记为

$$
\mathbf{E}_n=
\begin{bmatrix}
\mathbf{e}_{Q+1} & \mathbf{e}_{Q+2} & \cdots
\end{bmatrix}.
$$

对搜索角度 $\theta$，构造长度为 $K$ 的虚拟子阵导向向量：

$$
\mathbf{a}_K(\theta)=
\begin{bmatrix}
1 & e^{-jku} & e^{-j2ku} & \cdots & e^{-j(K-1)ku}
\end{bmatrix}^{T}.
$$

MUSIC 空间谱为

$$
P_{\mathrm{MUSIC}}(\theta)=
\frac{1}{
\mathbf{a}_K^{H}(\theta)
\mathbf{E}_n\mathbf{E}_n^{H}
\mathbf{a}_K(\theta)
}.
$$

在离散搜索区间内找到两个主峰，即可得到两个 DOA 估计。

---

## 12. 噪声有色化问题与白化

这是第三路线里很容易被忽略、但非常重要的一点。

### 12.1 beamspace 后噪声不再白

若阵元域噪声满足

$$
\mathbf{R}_n = \sigma^2 \mathbf{I},
$$

则进入 beamspace 后噪声协方差变为

$$
\mathbf{R}_{n,b}
=
\sigma^2 \mathbf{W}^{H}\mathbf{W}.
$$

在当前工程里，若把局部 beamforming 矩阵写成 $\mathbf{A}$，则可近似理解为

$$
\mathbf{R}_{n,b}
\propto
\mathbf{A}^{T}\mathbf{A}^{*}.
$$

由于当前局部 beam bank 不是严格酉变换，因此噪声通常不是白噪声。

### 12.2 虚拟阵列后噪声继续有色

再经过插值矩阵 $\mathbf{X}$ 后，虚拟阵列噪声协方差变为

$$
\mathbf{R}_{n,v}
=
\mathbf{X}\mathbf{R}_{n,b}\mathbf{X}^{H}.
$$

因此，虚拟阵列域的噪声一般仍是有色的。

### 12.3 白化思路

如果要更严谨，可对白化后的虚拟阵列协方差做处理。

设

$$
\mathbf{C}_n = \mathbf{R}_{n,v},
$$

则可构造白化矩阵 $\mathbf{C}_n^{-1/2}$，得到

$$
\widetilde{\mathbf{x}}_v(t)=\mathbf{C}_n^{-1/2}\mathbf{x}_v(t),
$$

协方差为

$$
\widetilde{\mathbf{R}}_v
=
\mathbf{C}_n^{-1/2}\mathbf{R}_v\mathbf{C}_n^{-1/2}.
$$

若先平滑再白化，也可对平滑后的噪声协方差 $\mathbf{C}_{\mathrm{ss}}$ 做白化：

$$
\widetilde{\mathbf{R}}_{\mathrm{ss}}
=
\mathbf{C}_{\mathrm{ss}}^{-1/2}
\mathbf{R}_{\mathrm{ss}}
\mathbf{C}_{\mathrm{ss}}^{-1/2}.
$$

对应的 steering 向量也同步白化：

$$
\widetilde{\mathbf{a}}_K(\theta)
=
\mathbf{C}_{\mathrm{ss}}^{-1/2}\mathbf{a}_K(\theta).
$$

在实验原型阶段，可以先不加白化；但如果后续要提升理论严谨性，建议把这一步补上。

---

## 13. 当前工程中的变量对应关系

为便于实现，这里把理论记号和当前仓库中的变量对齐。

### 13.1 当前旧路线入口

旧路线中的关键代码是：

```matlab
sr_DBF_boshu = A.' * y;
```

可以对应为

$$
\mathbf{B} = \mathbf{A}^{T}\mathbf{Y}.
$$

这里：

- `y` 对应阵元域快拍矩阵 $\mathbf{Y}$；
- `A` 对应局部 beamforming 矩阵；
- `sr_DBF_boshu` 对应 beamspace 快拍矩阵 $\mathbf{B}$。

### 13.2 当前已有的两个参考函数

- 旧函数：`steps/step_07_space_smooth_music/DOA_three_music_hecheng_fangzhen.m`
- 新函数：`steps/step_07_space_smooth_music/DOA_three_music_array_ss_beamspace.m`

第三路线建议新增独立函数，不直接混进上述两个函数内部。

---

## 14. 建议的模块划分

建议至少拆成两个函数。

### 14.1 插值矩阵设计函数

建议函数名：

```matlab
build_virtual_interp_matrix.m
```

建议输入：

- `A`：当前局部 beamforming 矩阵；
- `array_num`：阵元数；
- `lambda`：波长；
- `d`：阵元间距；
- `theta_in_grid`：扇区内训练角度网格；
- `theta_out_grid`：扇区外训练角度网格；
- `Lv`：虚拟阵列长度；
- `lambda_reg`：正则化参数；
- `mu`：扇区外抑制权重。

建议输出：

- `X`：插值矩阵；
- `diag_info`：拟合误差、条件数、扇区外增益等诊断指标。

### 14.2 虚拟阵列空间平滑 MUSIC 主函数

建议函数名：

```matlab
DOA_three_music_virtual_ss.m
```

建议输入：

- `sr_DBF_boshu`
- `A`
- `angle_recv`
- `theta_bw`
- `Lv`
- `K`
- `X`
- 其它与阵列参数有关的量

建议流程：

1. `Xv = X * sr_DBF_boshu`
2. `Rv = Xv * Xv' / T`
3. `Rss = mssp(Rv, K)`
4. `eig(Rss)`
5. 构造虚拟子阵 steering
6. 做 MUSIC 谱搜索
7. 找峰并输出 DOA

---

## 15. MATLAB 伪代码骨架

### 15.1 插值矩阵设计

```matlab
function [X, info] = build_virtual_interp_matrix(A, array_num, lambda, d, theta_in, theta_out, Lv, lambda_reg, mu)
    pos  = d * (0:array_num-1).';
    posv = d * (0:Lv-1).';

    Gin = zeros(size(A,2), numel(theta_in));
    Av  = zeros(Lv, numel(theta_in));

    for k = 1:numel(theta_in)
        a = exp(-1j * 2*pi * pos  / lambda * sind(theta_in(k)));
        Gin(:,k) = A.' * a;
        Av(:,k)  = exp(-1j * 2*pi * posv / lambda * sind(theta_in(k)));
    end

    Gout = zeros(size(A,2), numel(theta_out));
    for k = 1:numel(theta_out)
        a = exp(-1j * 2*pi * pos / lambda * sind(theta_out(k)));
        Gout(:,k) = A.' * a;
    end

    X = Av * Gin' / (Gin * Gin' + mu * (Gout * Gout') + lambda_reg * eye(size(Gin,1)));

    Av_hat = X * Gin;
    err_col = vecnorm(Av_hat - Av) ./ vecnorm(Av);
    info.err_mean = mean(err_col);
    info.err_max  = max(err_col);
    info.condX    = cond(X);
end
```

### 15.2 虚拟阵列 + 空间平滑 + MUSIC

```matlab
function doa_value = DOA_three_music_virtual_ss(sr_DBF_boshu, X, Lv, K, angle_recv, theta_bw, lambda, d)
    Xv  = X * sr_DBF_boshu;
    Rv  = Xv * Xv' / size(Xv, 2);
    Rss = mssp(Rv, K);

    [EV, D] = eig(Rss);
    [~, idx] = sort(diag(D), 'descend');
    EV = EV(:, idx);

    Lc = 2;
    En = EV(:, Lc+1:end);

    angle_search = angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2;
    posk = d * (0:K-1).';
    SP = zeros(1, numel(angle_search));

    for i = 1:numel(angle_search)
        a = exp(-1j * 2*pi * posk / lambda * sind(angle_search(i)));
        SP(i) = 1 / real(a' * En * En' * a);
    end

    [~, peak_ind] = FindLocalPeak_Fun(abs(SP));
    if numel(peak_ind) < 2
        doa_value = [nan nan];
    else
        doa_value = sort(angle_search(peak_ind(1:2)));
    end
end
```

以上伪代码足以作为第一版工程原型。

---

## 16. 参数选择建议

### 16.1 虚拟阵列长度 $L_v$

不要一开始取得过大。原因是：

- $L_v$ 越大，理论上分辨力越高；
- 但 $L_v$ 越大，插值问题越病态，噪声增强越严重；
- 对当前局部 beamspace 设置来说，中等维度通常比“尽量大”更稳。

建议第一版优先尝试：

$$
L_v \in \{12,16,20,24\}.
$$

### 16.2 平滑子阵长度 $K$

满足

$$
K < L_v
$$

并保证有足够的重叠子阵个数

$$
P = L_v - K + 1.
$$

对于双目标相干源，第一版可先试：

$$
K = 10 \text{ 或 } 12.
$$

### 16.3 扇区内训练网格

建议围绕局部搜索中心选择较密网格，例如

$$
\theta_{\mathrm{in}}
:\;
\theta_c - 1.5\,\Delta\theta
\;\text{到}\;
\theta_c + 1.5\,\Delta\theta,
$$

步长可取

$$
0.01^\circ \sim 0.05^\circ.
$$

### 16.4 扇区外训练网格

建议两层设计：

1. 扇区边缘附近的近邻外侧；
2. 更大范围的外部角域。

这样既能抑制边缘泄漏，也能避免远处响应异常放大。

### 16.5 正则化参数

第一版可从与 Gram 矩阵量级相关的值起步，例如

$$
\lambda
\approx
10^{-3}\sim10^{-1}
\cdot
\frac{\operatorname{tr}(\mathbf{G}_{\mathrm{in}}\mathbf{G}_{\mathrm{in}}^{H})}{B}.
$$

扇区外抑制系数可先试

$$
\mu \approx 0.1\lambda \sim 10\lambda.
$$

---

## 17. 需要重点监视的诊断指标

在这条路线中，不能只看最终 RMSE。建议至少跟踪下面三类量。

### 17.1 扇区内插值误差

定义

$$
\varepsilon_{\mathrm{in}}(\theta)
=
\frac{
\left\|
\mathbf{X}\mathbf{g}(\theta)-\mathbf{a}_v(\theta)
\right\|_2
}{
\left\|
\mathbf{a}_v(\theta)
\right\|_2
}.
$$

若该误差在整个扇区内都较小，说明“虚拟 ULA 近似”是可信的。

### 17.2 扇区外增益

定义

$$
\gamma_{\mathrm{out}}(\theta)
=
\left\|
\mathbf{X}\mathbf{g}(\theta)
\right\|_2.
$$

若该量过大，说明扇区外噪声、旁瓣或干扰会被插值矩阵异常放大。

### 17.3 插值矩阵病态程度

可以监视

$$
\kappa(\mathbf{X}) = \operatorname{cond}(\mathbf{X})
$$

以及虚拟阵列噪声总功率，例如

$$
\operatorname{tr}(\mathbf{R}_{n,v})
=
\operatorname{tr}(\mathbf{X}\mathbf{R}_{n,b}\mathbf{X}^{H}).
$$

常见现象是：

- 扇区内拟合误差很小，但条件数极大：无噪声时好看，带噪时容易失稳；
- 拟合误差略大，但条件数适中：反而整体更稳；
- 扇区外增益过大：边界外污染明显。

因此，不宜只追求扇区内误差最小。

---

## 18. 这条路线的优势与局限

### 18.1 优势

1. 与当前 beamspace 框架高度兼容；
2. 不需要重构完整阵元域协方差；
3. 比“直接在 beam 索引上做平滑”更有理论基础；
4. 便于做“第一路线 vs 第三路线”的对比实验；
5. 便于解释误差来源：插值误差、扇区外泄漏、噪声有色化。

### 18.2 局限

1. 平移不变性不是原生的，而是插值后近似得到的；
2. 性能很依赖训练扇区、正则化和虚拟阵长度选择；
3. 噪声会有色化，严格实现中最好考虑白化；
4. 若目标偏离设计扇区或模型失配较大，性能可能下降较快。

因此，第三路线适合被表述为：

> 在局部 beamspace 中构造近似虚拟 ULA，再在虚拟 ULA 上做空间平滑和 MUSIC。

而不应表述为：

> 波束输出天然就是阵元输出。

---

## 19. 与第一路线的关系

第一路线“阵元域先平滑，再 beamspace MUSIC”的逻辑是：

$$
\text{真实阵列}
\to
\text{真实子阵}
\to
\text{真实平移不变性}
\to
\text{空间平滑}
\to
\text{beamspace 投影}
\to
\text{MUSIC}.
$$

第三路线的逻辑是：

$$
\text{beamspace}
\to
\text{线性插值}
\to
\text{虚拟 ULA}
\to
\text{空间平滑}
\to
\text{MUSIC}.
$$

所以第三路线的“严格性”来自以下前提：

1. 扇区内插值误差足够小；
2. 扇区外泄漏被抑制；
3. 噪声增强可接受；
4. 虚拟阵列维度和子阵长度选择合理。

---

## 20. 建议的实现顺序

为了降低实现风险，建议按下面顺序推进。

### 阶段 1：最基础原型

只做扇区内正则化最小二乘插值：

$$
\min_{\mathbf{X}}
\left\|
\mathbf{X}\mathbf{G}_{\mathrm{in}}-\mathbf{A}_v
\right\|_F^2
\;+\;
\lambda\left\|\mathbf{X}\right\|_F^2.
$$

然后直接：

1. 生成虚拟阵列快拍；
2. 做 `mssp`；
3. 做 MUSIC；
4. 看双峰成功率和 RMSE。

### 阶段 2：加入扇区外抑制

在原有基础上加入

$$
\mu\left\|\mathbf{X}\mathbf{G}_{\mathrm{out}}\right\|_F^2.
$$

重点观察：

- 双峰成功率是否更稳；
- 边界处误差是否更小；
- 扇区外响应是否下降。

### 阶段 3：加入噪声白化

当基础实验已经跑通后，再考虑对虚拟阵列噪声协方差进行白化处理，使整套理论更完整。

---

## 21. 一句话总结

这条路线不是在证明“波束编号可以直接当阵元编号”，而是在做下面这件事：

> 通过插值矩阵把局部 beamspace 数据映射成一个近似虚拟 ULA，在这个虚拟 ULA 上恢复空间平滑成立所需的移位结构，再用 MUSIC 完成相干源超分辨测角。

从当前工程出发，这是一条：

- 比旧路线更严格，
- 比矩阵重构路线更容易落地，
- 适合继续往代码实现推进

的折中方案。

---

## 22. 扩展讨论：当阵列不是 ULA 时

上文主要按“局部 beamspace 映射到虚拟 ULA，再做空间平滑和 MUSIC”的思路展开。这一节进一步讨论：

1. `MUSIC` 是否只适用于 ULA；
2. `空间平滑 MUSIC` 是否只适用于 ULA；
3. 当阵列变为 `UPA / URA / 圆柱扇面阵 / 共形阵 / 不规则阵` 时，模型、参数、复杂度和实现难度如何变化。

先给出结论：

- **普通 MUSIC 不只适用于 ULA**；
- **空间平滑 MUSIC 也不只适用于 ULA**，但它需要某种“可分解为重叠同构子阵”的结构；
- **ULA 最自然、最标准**；
- **UPA / URA 可以扩展到 2D 空间平滑**；
- **圆柱阵、共形阵、不规则阵通常不能直接套标准空间平滑公式**，一般需要先做虚拟阵列化、阵列插值、manifold separation 或其它预处理。

---

### 22.1 不同阵列条件下的快速对照表

| 阵列类型 | 普通 MUSIC | 标准空间平滑 MUSIC | 常见待估参数 | 是否天然具备规则子阵结构 | 常见补救/扩展手段 | 复杂度特点 | 典型参考 |
|---|---|---|---|---|---|---|---|
| `ULA` | 可以直接做 | 最自然、最标准 | 1D 角度 | 是 | 通常不需要额外虚拟化 | 建模和谱搜索最简单 | Pillai and Kwon；Roy and Kailath |
| `UPA / URA` | 可以直接做 2D MUSIC | 可以扩展为 2D smoothing | 方位 + 俯仰 | 是，重叠矩形子阵 | 2D ESPRIT / 2D MUSIC / 2D smoothing | 由 1D 搜索升到 2D 搜索，计算量明显增加 | Zoltowski et al.；Shi et al. |
| `UCA / 完整圆阵` | 可以直接做 | 不直接照搬 ULA 公式，常借助 phase-mode / 虚拟化 | 常见为 1D 方位或 2D 方位-俯仰 | 具有圆对称，但不是线性平移不变 | phase-mode excitation、UCA-ESPRIT、虚拟插值、子阵旋转 | 建模比 ULA 更复杂，但可借助 mode-space 降维 | Mathews and Zoltowski；Liang et al. |
| `圆柱阵（整圆或多环）` | 可以做 | 一般不直接使用标准 ULA 型平滑 | 常见为 2D 方位-俯仰 | 轴向可能有平移结构，周向更多体现为旋转/圆对称 | phase-mode + 轴向结构、子阵划分、插值到虚拟 ULA / UPA | 比平面规则阵更复杂，往往需要分步建模 | Yang et al. 2010；2020 Def. Tech.；2021 Signal Processing |
| `圆柱扇面阵 / 局部扇区阵元` | 可以做局部 MUSIC | 通常不能直接用标准空间平滑 | 常见先压成局部 1D，再扩到 2D | 局部扇区通常不再保留完整圆对称 | 局部 beamspace、虚拟 ULA、子阵旋转近似、插值 ESPRIT、MST | 局部模型更容易做，但严格性依赖拟合/插值误差 | Yang et al. 2010；Liang et al.；Belloni et al. |
| `不规则阵 / 共形阵` | 原则上可以做 | 一般不能直接套标准公式 | 常见为 2D 或更广义参数 | 否 | manifold separation、插值、协方差重构、稀疏/ML 方法 | 建模、校准、数值稳定性都更难 | Belloni et al.；Yang et al. 2010 |

从这个表可以看出：

1. `MUSIC` 的适用范围明显比“空间平滑 MUSIC”更广；
2. 越偏离 `ULA / URA` 这种规则阵列，越需要先把阵列流形变形成“适合高分辨算法”的虚拟规则结构；
3. 对 `UCA / 圆柱阵 / 共形阵` 来说，常见主线不是直接照搬“平移不变子阵”，而是先做 `phase-mode`、`虚拟插值`、`子阵划分` 或 `manifold separation`。

对应参考：

- `ULA / FBSS / ESPRIT`：Pillai and Kwon；Roy and Kailath  
- `UPA / URA / 2D ESPRIT`：Zoltowski et al.；Shi et al.  
- `UCA / phase-mode / UCA-ESPRIT`：Mathews and Zoltowski  
- `UCA / subarray rotation`：Liang et al.  
- `Cylindrical conformal array / subarray division + interpolation`：Yang et al. 2010；2020 Def. Tech.；2021 Signal Processing

---

## 23. MUSIC 与空间平滑 MUSIC 的适用范围

### 23.1 普通 MUSIC 不只针对 ULA

普通 MUSIC 的基本模型是

$$
\mathbf{y}(t)=\mathbf{A}(\Theta)\mathbf{s}(t)+\mathbf{n}(t),
$$

其中：

- $\mathbf{A}(\Theta)$ 是阵列流形矩阵；
- $\Theta$ 表示待估计的角参数集合；
- $\mathbf{n}(t)$ 是噪声。

只要满足：

1. 阵列流形已知或可校准；
2. 协方差矩阵可以分解出信号子空间与噪声子空间；
3. 信号数不超过阵列自由度；

则普通 MUSIC 原则上都可以做。

因此：

- ULA 可以做；
- UPA / URA 可以做；
- 圆阵、圆柱阵、共形阵可以做；
- 不规则阵也可以做；

区别主要在于 steering vector 的建模复杂度，以及谱搜索是 1D 还是 2D，或者更高维。

对应参考：

- 普通 MUSIC / 阵列几何不受限这一层，可参考任意已知 manifold 条件下的子空间方法综述思路；
- `ESPRIT` 的经典“旋转不变子空间”框架可参考 Roy and Kailath, *ESPRIT—Estimation of Signal Parameters via Rotational Invariance Techniques*。

### 23.2 空间平滑 MUSIC 不是只针对 ULA，但对阵列结构要求更高

空间平滑的目标是处理**相干源导致的协方差退秩**问题。

其核心前提不是“必须 ULA”，而是：

> 阵列能够分解成多个重叠、同构、并且在几何上满足某种平移不变关系的子阵。

经典一维 ULA 场景下，这个条件最容易满足，因此最常见。

对 ULA，若取长度为 $L$ 的重叠子阵，则有

$$
\mathbf{J}_\ell \mathbf{a}_N(\theta)
=
e^{-jk(\ell-1)d\sin\theta}\mathbf{a}_L(\theta).
$$

这就是标准空间平滑成立的根基。

所以更准确的说法应是：

- `MUSIC` 本身不限定 ULA；
- `空间平滑 + MUSIC` 依赖子阵间的移位结构；
- ULA 是最典型场景，但不是唯一场景。

对应参考：

- Pillai and Kwon, *Forward/backward spatial smoothing techniques for coherent signal identification*  
- Roy and Kailath, *ESPRIT—Estimation of Signal Parameters via Rotational Invariance Techniques*

---

## 24. 考虑 UPA / URA 情况

### 24.1 UPA / URA 可以做普通 MUSIC

对均匀平面阵，远场窄带 steering 通常可写成

$$
a_{m,n}(\theta,\phi)
=
e^{-jk\left[(m-1)d_x u_x + (n-1)d_y u_y\right]},
$$

其中常取

$$
u_x = \sin\theta\cos\phi,
\qquad
u_y = \sin\theta\sin\phi.
$$

因此，平面阵通常会引入两个角参数，例如：

- 方位角 $\phi$；
- 俯仰角 $\theta$。

所以与 ULA 相比：

- 参数不再只有 1 个角；
- steering 不再是一维 Vandermonde，而是二维可分离或近似可分离结构；
- MUSIC 谱搜索通常从一维变成二维。

### 24.2 UPA / URA 也可以做空间平滑

如果阵列是规则平面阵，并且能切成多个重叠矩形子阵，那么仍可做 2D 空间平滑。

这时：

- 子阵不再是“滑动线段”，而是“滑动矩形块”；
- 导向向量通常写成二维 Kronecker 结构；
- 平滑可在两个方向上同时进行，或转化为二维子阵平均。

例如，若虚拟或真实平面阵 steering 可以写成

$$
\mathbf{a}_{\mathrm{UPA}}(\theta,\phi)
=
\mathbf{a}_y(\theta,\phi)\otimes \mathbf{a}_x(\theta,\phi),
$$

则二维子阵选择矩阵可以按两个方向分别构造，再做二维形式的空间平滑。

### 24.3 与 ULA 相比，UPA / URA 的复杂度会上升

复杂度上升主要体现在：

1. **参数维度上升**  
   从一维角参数变成二维角参数。

2. **谱搜索维度上升**  
   从
   $$
   P(\theta)
   $$
   变成
   $$
   P(\theta,\phi).
   $$

3. **子阵构造更复杂**  
   从重叠线子阵变成重叠矩形子阵。

4. **计算量明显增大**  
   尤其在二维细网格搜索下，MUSIC 谱计算量会明显增加。

因此，UPA / URA 上的“空间平滑 MUSIC”是成立的，但它已经不是简单照搬 ULA 代码就能完成的版本，而是一个二维扩展版本。

对应参考：

- Michael D. Zoltowski, Martin Haardt, and Cherian P. Mathews, *Closed-form 2-D angle estimation with rectangular arrays in element space or beamspace via unitary ESPRIT*  
- Shi et al., coherent 2D DOA estimation for rectangular arrays, *Sensors*, 2017

---

## 25. 考虑圆柱扇面阵、共形阵与不规则阵情况

### 25.1 普通 MUSIC 仍然可以做

对任意三维阵列几何，只要阵列流形已知，普通 MUSIC 原理上仍然成立。

更一般地，第 $p$ 个阵元的 steering 可写成

$$
a_p(\theta,\phi)
=
g_p(\theta,\phi)\,
e^{-jk\,\mathbf{r}_p^{T}\mathbf{u}(\theta,\phi)},
$$

其中：

- $\mathbf{r}_p$ 是第 $p$ 个阵元的位置向量；
- $\mathbf{u}(\theta,\phi)$ 是入射方向单位向量；
- $g_p(\theta,\phi)$ 是该阵元的方向图、极化或姿态相关响应。

因此，普通 MUSIC 的困难不在于“能不能做”，而在于：

- 阵列流形建模是否准确；
- 是否需要二维角度联合估计；
- 是否存在阵元方向图不一致、共形姿态不同等因素。

### 25.2 标准空间平滑通常不能直接套用

对圆柱扇面阵、共形阵、不规则阵，最大的问题不只是参数多，而是：

> 阵列流形通常不再具有简单的 Vandermonde 结构，也往往难以直接分解出一组只差平移的重叠同构子阵。

这意味着经典 ULA/UPA 风格的空间平滑根基会变弱，甚至直接失效。

常见原因包括：

1. 阵元位置不是均匀线性或均匀矩形采样；
2. 阵元朝向不同，方向图不一致；
3. 子阵之间不再只是平移，可能还夹带旋转、法向变化、方向图变化；
4. 因此无法直接写出
   $$
   \mathbf{J}_\ell \mathbf{a}(\theta,\phi)
   =
   c_\ell(\theta,\phi)\mathbf{a}_{\mathrm{sub}}(\theta,\phi)
   $$
   这样的标准平移关系。

### 25.3 相位参数不只是“变多”，而是模型整体更复杂

对 ULA，经常只需一个角参数，且 steering 相位具有简单线性形式：

$$
e^{-jknd\sin\theta}.
$$

而对圆柱阵、共形阵或不规则阵，通常至少变成二维角参数：

$$
(\theta,\phi),
$$

相位项则变成与三维位置向量有关的形式：

$$
e^{-jk\,\mathbf{r}_p^{T}\mathbf{u}(\theta,\phi)}.
$$

如果再考虑阵元方向图、极化或姿态，则模型会进一步扩展为

$$
g_p(\theta,\phi)\,
e^{-jk\,\mathbf{r}_p^{T}\mathbf{u}(\theta,\phi)}.
$$

所以更准确的说法不是“相位参数简单地多几个”，而是：

> 阵列流形从单参数、统一结构的 Vandermonde 模型，升级为多参数、阵元相关、可能还需要校准的广义 manifold 模型。

### 25.4 复杂度会在哪些地方上升

对圆柱扇面阵、共形阵和不规则阵，复杂度通常会从以下几方面一起上升。

#### 1. 建模复杂度

需要明确：

- 每个阵元的三维坐标；
- 每个阵元的朝向；
- 每个阵元的方向图；
- 必要时还要做实测或仿真校准。

#### 2. 算法构造复杂度

不能直接照搬 ULA 的平滑方式，通常需要：

- 阵列插值；
- 虚拟阵列映射；
- manifold separation；
- 或者换成其它去相干方法。

#### 3. 谱搜索复杂度

大多会从一维谱搜索变成二维谱搜索：

$$
P(\theta) \;\to\; P(\theta,\phi).
$$

#### 4. 数值稳定性复杂度

插值、映射、虚拟化步骤会带来：

- 有色噪声；
- 条件数恶化；
- 对阵列校准误差更敏感；
- 对扇区外目标和模型失配更敏感。

对应参考：

- Belloni et al., *DoA Estimation via Manifold Separation for Arbitrary Array Structures*  
- Yang et al., *DOA estimation with sub-array divided technique and interpolated ESPRIT algorithm on a cylindrical conformal array antenna*  
- 2020 Def. Tech. cylindrical conformal array interpolation / ESPRIT work  
- 2021 *Signal Processing* cylindrical nested conformal array work

---

## 26. 对圆柱扇面阵的实用理解

如果当前工程背景接近“圆柱扇面阵”或“局部共形子阵”，那么可以分三层理解。

### 26.1 只做单维局部超分辨时

如果前级处理已经通过俯仰波束形成、扇区裁剪等方式，把问题压缩为一个局部方位子问题，那么可以把问题近似看成：

- 在局部扇区内只估一个主角参数；
- 用局部 beamspace 响应去拟合一个**虚拟 ULA**；
- 再做一维空间平滑与 MUSIC。

这正是本文主线讨论的“虚拟阵列插值 + 空间平滑 + beamspace MUSIC”路线。

这时虽然真实阵列不是 ULA，但只要局部 beamspace 到虚拟 ULA 的拟合足够好，就仍然可以在近似模型上建立可用的空间平滑结构。

### 26.2 如果要做方位-俯仰联合超分辨

如果要同时估计两个角参数，那么更自然的做法通常是：

- 不是映射到虚拟 ULA，
- 而是映射到虚拟 UPA / URA。

即构造

$$
\mathbf{X}\mathbf{g}(\theta,\phi)
\approx
\mathbf{a}_{v,\mathrm{UPA}}(\theta,\phi),
$$

然后在虚拟平面阵上做二维空间平滑与二维 MUSIC。

这条路线理论上更完整，但复杂度明显更高。

### 26.3 如果阵列几何很不规则

如果阵列几何不规则、阵元姿态差异大、方向图明显不一致，则标准空间平滑通常不是最省力的主线。

这时更常见的路线包括：

1. **阵列插值 / interpolated array**  
   先变成虚拟规则阵，再套规则阵算法；

2. **Manifold Separation Technique (MST)**  
   把任意阵列流形分解成“阵列相关部分 × 规则结构部分”；

3. **矩阵重构 / covariance reconstruction**  
   通过结构化重构得到更适合后续估计的协方差；

4. **稀疏重构 / 最大似然 / 优化类方法**  
   直接绕开标准空间平滑。

对应参考：

- Friedlander and Weiss, *Direction Finding Using Spatial Smoothing With Interpolated Arrays*  
- Belloni et al., *DoA Estimation via Manifold Separation for Arbitrary Array Structures*  
- Yang et al., 2010 cylindrical conformal array interpolation / ESPRIT

### 26.4 对“圆柱阵局部扇区能否利用旋转不变子阵”的专门讨论

这个问题要分成三层来回答。

#### 第一层：圆形/圆柱形几何确实带有“旋转对称性”

如果阵列是完整的 `UCA` 或完整周向采样的圆柱阵，那么从几何上说，它确实具有周向旋转对称性。  
这类对称性常被用于：

1. `phase-mode excitation`；
2. `mode-space beamforming`；
3. `UCA-ESPRIT`；
4. 把圆阵或圆柱阵变换成具有 `Vandermonde` 结构的虚拟阵列。

也就是说：

> 对圆对称阵列，相关研究并不是没有“旋转不变性”这个概念，而是通常不会直接把它写成 ULA 那种简单的“平移不变子阵”形式，而是先经过 mode-space 或虚拟插值变换。

对应参考：

- Mathews and Zoltowski, *Eigenstructure Techniques for 2-D Angle Estimation with Uniform Circular Arrays*  
- Mathews and Zoltowski, *Performance Analysis of the UCA-ESPRIT Algorithm for Circular Ring Arrays*  
- Xie et al., `UCA` 相位模态 / 虚拟阵列相关方法综述型工作

#### 第二层：如果“每次只选某一段方位区间的阵元去工作”，完整旋转对称性会被破坏

一旦不是使用完整圆周，而是只取某个局部扇区，那么问题会发生变化：

1. 全圆阵的严格循环对称性不再完整保留；
2. 当前局部扇区更像一个“弧阵”或“局部共形子阵”；
3. 两个局部扇区之间未必还能形成简单、严格、全频一致的旋转不变关系；
4. 尤其在圆柱平台、遮挡、方向图不一致时，这种“旋转对应关系”会进一步失真。

因此，对“局部扇区阵元”来说，不能简单地把：

$$
\text{完整圆阵的旋转对称性}
$$

直接等同为：

$$
\text{局部扇区子阵之间可直接用于 ESPRIT 的严格旋转不变性}.
$$

更准确地说：

> 局部扇区通常只保留了部分几何对称性，因此更适合被看作“可插值、可虚拟化、可局部建模”的子阵，而不是天然满足经典 ESPRIT 的规则阵。

#### 第三层：工程上可以“借助旋转思想”，但常见做法是把它转化成可计算的虚拟不变结构

当前文献里更常见的不是直接在原始局部圆柱扇区上写一个“旋转不变子阵公式”，而是下面几类做法。

##### 做法 A：`phase-mode` / `mode-space` 变换

对完整 `UCA` 或接近完整周向采样的阵列，利用相位模态激励把圆阵 manifold 变成类 `ULA` 的 `Vandermonde` 结构，再做 `MUSIC / Root-MUSIC / ESPRIT`。

这条路线的本质是：

$$
\text{圆对称几何}
\to
\text{phase-mode 变换}
\to
\text{虚拟规则阵}
\to
\text{高分辨 DOA}.
$$

也就是说，圆对称性并没有被浪费，但它是通过 `mode-space` 被“变成”了更适合线性子空间算法的结构。

对应参考：

- Mathews and Zoltowski, *Eigenstructure Techniques for 2-D Angle Estimation with Uniform Circular Arrays*  
- Xie et al., `UCA` 通过 phase-mode excitation 获得虚拟 `ULA` 型 steering 的综述/扩展工作  
- Sensors 2019, *A Robust Direction of Arrival Estimation Method for Uniform Circular Array*

##### 做法 B：虚拟插值 + 子阵旋转

这类方法与用户的问题非常接近。

相关工作已经明确提出：

> 对 `UCA` 可先做虚拟插值，再将对称划分的子阵按参考点旋转，构造新的等效子阵关系，最后用 `ESPRIT` 做估计。

这一类代表性工作是：

- Liang et al., *A DOA Estimation Method for Uniform Circular Array Based on Virtual Interpolation and Subarray Rotation*, IEEE Access, 2021.

它的要点不是“直接拿原始圆阵局部扇区就做标准 ESPRIT”，而是：

1. 对圆阵做虚拟插值；
2. 对称划分子阵；
3. 通过子阵旋转构造更合适的不变关系；
4. 最后再做基于 `ESPRIT` 的闭式估计。

因此，从思想上讲：

- **可以借助旋转不变性思路**；
- 但通常要配合**插值**和**子阵重构**；
- 很少是“原始局部扇区直接代入标准平移不变公式”。

##### 做法 C：圆柱共形阵上的“子阵划分 + 插值 ESPRIT”

对于圆柱共形阵，更贴近工程阵列的做法是：

1. 先按方位把阵列划分为多个子阵；
2. 每个子阵对应一个观测扇区；
3. 把该子阵插值成虚拟 `ULA` 或虚拟 `UPA`；
4. 再在对应虚拟阵上应用 `ESPRIT` 或其它高分辨方法。

这正是以下工作所采用的主线：

- Yang, Yang, Nie, *DOA estimation with sub-array divided technique and interpolated ESPRIT algorithm on a cylindrical conformal array antenna*, PIER, 2010.

这篇工作非常直接地说明：

> 对圆柱共形阵，常见思路不是直接在原几何上寻找传统 ULA 的移位不变子阵，而是把局部子阵通过插值变成虚拟规则阵，再应用 ESPRIT。

##### 做法 D：更进一步的圆柱阵虚拟化与协方差构造

更近一些的工作还包括：

- 2020 年的 *A novel DOA estimation algorithm using directional antennas in cylindrical conformal arrays*：  
  通过子阵划分和改进插值，把方向性圆柱子阵变成虚拟嵌套阵，再构造等效协方差并用 `Unitary ESPRIT`。

- 2021 年的 *Two-dimensional direction-of-arrival estimation for cylindrical nested conformal arrays*：  
  通过插值把圆柱嵌套共形阵映射到虚拟平面阵，并构造增强协方差与 3D 空间平滑。

这些工作说明：

> 对圆柱阵来说，研究是有的，而且相当明确；但主流不是直接在原始局部扇区上做“裸旋转不变子阵”，而是通过子阵划分、插值、虚拟阵列化，把几何对称性转化成可用于 `ESPRIT / MUSIC / smoothing` 的代数结构。

#### 小结

所以，对用户这个问题，一个比较准确的回答是：

1. **可以借助圆柱/圆阵的旋转对称思想**；
2. **但若每次只使用某个局部方位扇区，严格的全局旋转不变性往往已经被破坏**；
3. **相关研究通常不是直接在原局部扇区上套标准 ESPRIT，而是通过 `phase-mode`、`虚拟插值`、`子阵旋转`、`subarray division + interpolated ESPRIT` 来“制造”可用的不变结构**。

如果回到当前工程，这条结论非常重要：

> 对圆柱扇面局部工作阵元，最务实的路线依然是“局部 beamspace -> 虚拟 ULA / UPA -> 空间平滑 / ESPRIT / MUSIC”，而不是期待原始局部扇区天然满足完整的旋转不变子阵模型。

---

## 27. 从本文主线回看：为什么当前仍建议先做“虚拟 ULA”

对当前工程而言，如果目标是：

- 保留现有局部 beamspace 框架；
- 主要解决局部双目标相干分辨；
- 先做可实现、可解释、可验证的版本；

那么把当前问题尽量压成：

$$
\text{局部 beamspace}
\to
\text{虚拟 ULA}
\to
\text{1D 空间平滑}
\to
\text{MUSIC}
$$

通常是最务实的。

原因在于：

1. 比直接把 beam 索引当阵元编号更严格；
2. 比一步到位做虚拟 UPA / 共形二维插值更容易实现；
3. 比完整的协方差重构路线更贴近现有代码；
4. 更容易先跑出可对比的 RMSE、双峰成功率和谱图结果。

因此，本文主线方法并不是声称“真实阵列本身是 ULA”，而是利用局部 beamspace 建立一个**可用于空间平滑的虚拟 ULA 近似模型**。

---

## 28. 一句话总结这部分扩展讨论

可以把结论总结为三句话：

1. **普通 MUSIC 不只属于 ULA，任意已知阵列流形原则上都可做 MUSIC。**
2. **空间平滑 MUSIC 不只属于 ULA，但它需要规则、可重叠、可建立移位关系的子阵结构。**
3. **对于 UPA 可以扩展到二维平滑；对于圆柱阵、共形阵和不规则阵，通常要先做虚拟阵列化、插值或 manifold 建模，复杂度会明显上升。**

---

## 29. 参考文献方向

1. Yang et al., *DOA estimation for coherent sources in beamspace using spatial smoothing*  
   [https://ieeexplore.ieee.org/document/1292615/](https://ieeexplore.ieee.org/document/1292615/)

2. Pillai and Kwon, *Forward/backward spatial smoothing techniques for coherent signal identification*  
   [https://doi.org/10.1109/29.17496](https://doi.org/10.1109/29.17496)

3. Beamspace matrix reconstruction 方向论文  
   [https://www.sciencedirect.com/science/article/pii/S0165168421003868](https://www.sciencedirect.com/science/article/pii/S0165168421003868)

4. Friedlander and Weiss, *Direction Finding Using Spatial Smoothing With Interpolated Arrays*  
   [https://cris.tau.ac.il/en/publications/direction-finding-using-spatial-smoothing-with-interpolated-array/](https://cris.tau.ac.il/en/publications/direction-finding-using-spatial-smoothing-with-interpolated-array/)

5. Lau et al., *An improved interpolated array approach to DOA estimation in correlated signal environments*  
   [https://lucris.lub.lu.se/ws/files/45966079/lau_icassp_2004.pdf](https://lucris.lub.lu.se/ws/files/45966079/lau_icassp_2004.pdf)

6. Shi et al., coherent 2D DOA estimation for rectangular arrays  
   [https://www.mdpi.com/1424-8220/17/9/1956](https://www.mdpi.com/1424-8220/17/9/1956)

7. Belloni et al., *DoA Estimation via Manifold Separation for Arbitrary Array Structures*  
   [https://www.researchgate.net/publication/3320451_DoA_Estimation_Via_Manifold_Separation_for_Arbitrary_Array_Structures](https://www.researchgate.net/publication/3320451_DoA_Estimation_Via_Manifold_Separation_for_Arbitrary_Array_Structures)

8. Roy and Kailath, *ESPRIT—Estimation of Signal Parameters via Rotational Invariance Techniques*  
   [https://doi.org/10.1109/29.32276](https://doi.org/10.1109/29.32276)

9. Mathews and Zoltowski, *Eigenstructure Techniques for 2-D Angle Estimation with Uniform Circular Arrays*  
   [https://doi.org/10.1109/78.317861](https://doi.org/10.1109/78.317861)

10. Mathews and Zoltowski, *Performance Analysis of the UCA-ESPRIT Algorithm for Circular Ring Arrays*  
   [https://doi.org/10.1109/78.317881](https://doi.org/10.1109/78.317881)

11. Zoltowski, Haardt, and Mathews, *Closed-form 2-D angle estimation with rectangular arrays in element space or beamspace via unitary ESPRIT*  
   [https://doi.org/10.1109/78.485927](https://doi.org/10.1109/78.485927)

12. Liang et al., *A DOA Estimation Method for Uniform Circular Array Based on Virtual Interpolation and Subarray Rotation*  
   [https://doi.org/10.1109/ACCESS.2021.3106671](https://doi.org/10.1109/ACCESS.2021.3106671)

13. Yang, Yang, and Nie, *DOA estimation with sub-array divided technique and interpolated ESPRIT algorithm on a cylindrical conformal array antenna*  
   [https://doi.org/10.2528/PIER10011904](https://doi.org/10.2528/PIER10011904)

14. *A novel DOA estimation algorithm using directional antennas in cylindrical conformal arrays*  
   [https://doi.org/10.1016/j.dt.2020.06.010](https://doi.org/10.1016/j.dt.2020.06.010)

15. *Two-dimensional direction-of-arrival estimation for cylindrical nested conformal arrays*  
   [https://doi.org/10.1016/j.sigpro.2020.107838](https://doi.org/10.1016/j.sigpro.2020.107838)
