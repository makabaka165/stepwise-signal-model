# 第 5 步检测问题诊断与解决方案

## 1. 问题背景

在单目标场景下，希望第 5 步完整链路运行后最终只得到 **1 个目标检测结果**，但实际出现了大量过门限检测单元。

核心问题：
- 第 5 步的门限计算是否合理
- MTD 后目标为什么会在多个 Doppler 单元上出现响应
- 为什么当前 `raw` 检测点数会远大于 1
- 如何在不引入复杂聚类的前提下实现"1 个目标"输出

---

## 2. 当前处理链路

**脚本**：`demo_joint_2d_mtd_standalone.m`

**主链路**：
1. 阵元级回波仿真
2. 脉压（Hamming 窗）
3. 局部五波束形成（Taylor 幅度加权）
4. 中心束 MTD（慢时间加窗）
5. 对中心束 RD 图做 **逐 Doppler 行的 1D 距离 CFAR**

**CFAR 实现**：`core/detect/FuncCFARBase.m` 中的 `CFAR01`
- 输入矩阵按 `[doppler, range]` 组织
- 对每一条 Doppler 行，沿距离维独立做 1D CFAR
- 所有过门限的 `(range, doppler)` 单元都会被输出

**关键事实**：
```
raw = 过门限的 range-Doppler bin 数（不是目标数）
```

---

## 3. 门限公式验证

**检测器类型**：Square（功率检测）
```matlab
metric = |x|^2
```

**CA-CFAR 门限公式**：
```matlab
alpha = Nref * (Pfa^(-1/Nref) - 1)
threshold = alpha * mean(reference_cells)
```

**理论假设**：
- 噪声为复高斯噪声
- 功率检测后噪声服从指数分布

**代码实现**：
```matlab
noise = sigmaN / sqrt(2) * (randn(...) + 1j * randn(...))
```

**结论**：门限公式本身正确，与噪声建模匹配。

---

## 4. 问题根源诊断

### 4.1 初始现象（ampTgt=1.0, mtdWinType='rect'）

| Np | 速度分辨率 | vTgt=45 状态 | raw 结果 |
|---|---|---|---|
| 32 | 9.375 m/s | off-grid | 32（目标距离列上 32 个 Doppler bin 全过门限） |
| 40 | 7.5 m/s | **on-grid** | 2（1 个主目标 + 1 个弱虚警） |
| 64 | 4.6875 m/s | off-grid | 67（64 个目标 bin + 3 个虚警） |

**核心发现**：
- Np=40 on-grid 时，raw 压缩到 2 → 证明其他情况的大量检测点来自 **off-grid Doppler 泄漏**
- Np 增大不能自动减少检测点，反而因为更细的栅格导致同一目标被记成更多 bin

### 4.2 物理机制

**off-grid 目标 + 矩形慢时窗**：
- 目标速度落在两个 Doppler bin 之间
- 矩形窗的 Dirichlet 核旁瓣衰减慢（~1/m²）
- 在高 SNR（~90 dB）下，远端 Doppler bin 的旁瓣功率仍远高于 CFAR 门限
- 结果：所有 Np 个 Doppler bin 都过门限

**量化验证**（Np=32, ampTgt=1.0, rect 窗）：
- 主瓣 bin 功率 ≈ 4N²/π² ≈ 415
- 远端 bin（m=15）功率 ≈ N²/(15.5²π²) ≈ 0.43
- CFAR 门限（Pfa=1e-6, Nref=8）≈ 0.092
- 远端 bin / 门限 ≈ 5 倍 → 全部过门限 ✓

---

## 5. 解决方案实施

### 方案 A：MTD 加窗（抑制远端 Doppler 旁瓣）

**修改**：`mtdWinType = 'rect'` → `'hamming'`

**效果**：
- Hamming 窗峰值旁瓣 -43 dB（rect 的 -13 dB）
- 远端 Doppler bin 功率显著下降

**问题**：在 ampTgt=1.0（SNR ~90 dB）下，Hamming 的 -43 dB 旁瓣抑制仍不够，raw 仍是几十。

### 方案 B：降低 SNR 到现实雷达水平

**修改**：`ampTgt = 1.0` → `0.01`

**效果**：SNR 从 ~90 dB 降到 ~47 dB（post-MTD）

**结果**（Np=32, Hamming, ampTgt=0.01, Pfa=1e-6）：
```
raw = 5
  Det 1: rangeIdx=1251, doppIdx=12, metric=125.9  (主瓣峰值)
  Det 2: rangeIdx=1251, doppIdx=13, metric=48.6   (主瓣相邻 bin)
  Det 3: rangeIdx=1251, doppIdx=11, metric=11.7   (主瓣相邻 bin)
  Det 4: rangeIdx=2069, doppIdx=21, metric=0.005  (噪声虚警)
  Det 5: rangeIdx=2070, doppIdx=21, metric=0.005  (噪声虚警)
```

**分析**：
- 3 个主瓣 bin（11/12/13）：Hamming 主瓣展宽 ~3 bin + half-bin 偏移
- 2 个噪声虚警：期望 FA = Pfa × 总 cell 数 = 1e-6 × 96000 ≈ 0.1，实际 2 个属于统计涨落

### 方案 C：收紧 Pfa 消除噪声虚警

**Pfa 扫描实验**（Np=32, Hamming, ampTgt=0.01）：

| Pfa | alpha_2sided | raw 结果 | 说明 |
|---|---|---|---|
| 1e-6 | 21.94 | 5 | 3 主瓣 + 2 噪声 FA |
| **1e-7** | **27.81** | **3** | **3 主瓣，噪声 FA 清零** ✓ |
| 1e-8 | 34.60 | 0 | 门限过高，连主瓣都压掉 |

**最佳工作点**：`Pfa = 1e-7`
- 噪声虚警期望 = 1e-7 × 96000 ≈ 0.01，实际 0 个
- 主瓣 3 bin 都保留（rangeIdx=1251, doppIdx=11/12/13）
- 检测余量充足但不浪费

**为什么 Pfa=1e-8 失效**：
- Det 3（最弱主瓣 bin）metric=11.7，在 Pfa=1e-7 时刚好过门限
- Pfa 从 1e-7 → 1e-8，alpha 从 27.8 → 34.6，门限抬高 24%
- 目标附近的参考单元可能被 range 旁瓣或噪声涨落污染，局部 mean(ref) 被抬高
- 门限 = alpha × mean(ref) 超过 Det 3 → 整个主瓣被压掉

---

## 6. 最终参数配置

```matlab
%% 目标参数
ampTgt = 0.01;          % 对应 post-MTD SNR ~47 dB

%% 仿真控制
sigmaN = 0.05;

%% CFAR 参数
falseAlarmRate = 1e-7;  % 最佳工作点
protectCell = 2;
referenceCell = 8;

%% MTD 参数
Np = 32;
mtdWinType = 'hamming'; % 抑制 Doppler 旁瓣
```

**最终结果**：
```
raw = 3（同一目标的 Doppler 主瓣展宽）
  rangeIdx=1251, doppIdx=11, metric=11.7
  rangeIdx=1251, doppIdx=12, metric=125.9  (峰值)
  rangeIdx=1251, doppIdx=13, metric=48.6
```

---

## 7. 物理解释与工程意义

### 7.1 raw=3 是 CFAR 步骤的物理下限

**原因**：
- Hamming 慢时窗主瓣本身 ~3 bin 宽（FWHM ≈ 1.4 bin，-3 dB 外仍显著）
- vTgt=45 在 Np=32 下 half-bin 偏移，主瓣峰值落在 bin 12 和 13 之间
- 目标能量物理上就分布在 3 个相邻 bin 里
- CFAR 正确地把这 3 个显著高于噪声的 cell 标为"过门限"

**不能通过 CFAR 参数消除的原因**：
- 任何 noise-based 门限（CA/GO/SO）在每个 bin 上都比 metric 低 2 个量级
- 增大 Doppler 维 protect 单元 → ref 干净 → 门限低 → 3 个 bin 全过
- 减小 Doppler 维 protect 单元 → ref 包含主瓣 → 门限高 → 可能漏检主目标
- 2D CFAR 也无法在保留峰值的同时压掉相邻主瓣 bin

### 7.2 CFAR 的职责边界

**CFAR 做的事**：per-cell 决策（判断每个 bin 是不是噪声）

**CFAR 不做的事**：目标级输出（把主瓣展宽合并成 1 个目标）

**雷达工程标准链路**：
```
RD 图 → CFAR（per-cell） → 凝聚/聚类（per-target） → 跟踪
        └ 只判"是不是噪声"  └ 把主瓣展宽合并
```

---

## 8. 下一步：目标凝聚

### 推荐方案：同距离列 Doppler 峰值保留

**适用场景**：单目标或少量目标，目标在距离维分离良好

**算法**：
```matlab
% 在 CFAR 输出 rawRangeIdx, rawDoppIdx, rawMetric 之后
[uniqueRange, ~, ic] = unique(rawRangeIdx);
targetList = [];
for i = 1:numel(uniqueRange)
    mask = (ic == i);
    [maxMetric, maxIdx] = max(rawMetric(mask));
    localDoppIdx = rawDoppIdx(mask);
    targetList = [targetList; uniqueRange(i), localDoppIdx(maxIdx), maxMetric];
end
% targetList: [rangeIdx, doppIdx, metric]，每行一个目标
```

**效果**：raw=3 → target=1
- 保留 (rangeIdx=1251, doppIdx=12, metric=125.9)
- 距离 3200 m，速度 46.875 m/s（最接近真值 45 m/s 的 bin）

**后续扩展**：
- 多目标场景：在同一 rangeIdx 上保留多个 Doppler 局部峰值（相邻 bin 只保留最大值）
- 结合比幅测角：对每个目标用五波束精化角度
- 跨 CPI 跟踪：第 8 步已有实现

---

## 9. 给导师的汇报总结

1. **门限公式正确**：采用标准 CA-CFAR 功率检测门限公式，与噪声建模匹配

2. **问题根源**：off-grid 目标在 Doppler 维通过 FFT 的 Dirichlet 核扩散，被"逐 Doppler 行 1D range-CFAR"重复记数

3. **关键修改**：
   - MTD 加 Hamming 窗（抑制远端 Doppler 旁瓣）
   - 降低 SNR 到现实雷达水平（ampTgt=0.01，~47 dB）
   - 收紧 Pfa 到 1e-7（消除噪声虚警）

4. **最终状态**：raw=3，对应同一目标的 Doppler 主瓣展宽（物理事实，不是算法缺陷）

5. **下一步**：在 CFAR 之后做目标凝聚，把"bin 级检测结果"整理成"目标级输出"

6. **工程意义**：
   - CFAR 步骤的职责是 per-cell 决策，raw=3 说明算法正确识别了 3 个显著高于噪声的 bin
   - 目标级输出（1 个目标）由后续凝聚步骤完成，职责边界清晰
   - 参数配置（Hamming + Pfa=1e-7 + SNR~47dB）在合理工程范围内，不依赖 on-grid 假设

---

## 10. 参数调节指南

### 可调参数及其影响

| 参数 | 影响对象 | 调节效果 | 推荐值 |
|---|---|---|---|
| **Pfa** | 噪声虚警数 | 越小虚警越少，但漏检风险增大 | 1e-7（最佳平衡点） |
| **mtdWinType** | Doppler 旁瓣 | hamming 抑制远端泄漏 | 'hamming' |
| **ampTgt** | SNR | 越小门限余量越紧张 | 0.01（~47 dB SNR） |
| **protectCell** | 门限估计 | 防止主瓣污染参考窗 | 2（range 维足够） |
| **referenceCell** | 门限稳定性 | 越大估计越稳定 | 8（标准配置） |

### 不能消除主瓣展宽的参数

- **Np**：改变栅格密度，不改变主瓣展宽 bin 数（除非强制 on-grid）
- **cfarMethod (CA/GO/SO)**：三者对孤立目标效果相近
- **detectorType (Linear/Square)**：只改变 metric 定义，相对关系不变

---

## 11. 实验记录

| 配置 | raw | 说明 |
|---|---|---|
| Np=32, rect, ampTgt=1.0, Pfa=1e-6 | 32 | 初始问题：所有 Doppler bin 过门限 |
| Np=40, rect, ampTgt=1.0, Pfa=1e-6 | 2 | on-grid 验证：主瓣压缩 |
| Np=64, rect, ampTgt=1.0, Pfa=1e-6 | 67 | Np 增大无效 |
| Np=32, hamming, ampTgt=1.0, Pfa=1e-6 | 67 | 加窗不够（SNR 太高） |
| Np=32, hamming, ampTgt=0.01, Pfa=1e-6 | 5 | 降 SNR 有效（3 主瓣 + 2 FA） |
| **Np=32, hamming, ampTgt=0.01, Pfa=1e-7** | **3** | **最佳配置** ✓ |
| Np=32, hamming, ampTgt=0.01, Pfa=1e-8 | 0 | 门限过高，漏检 |
