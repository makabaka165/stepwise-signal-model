# 第 8 步 Route B 创新实验记录

本文档只记录第 8 步中每次新增或修改的原型、对应实验结果、是否保留，以及是否适合作为后续创新点继续推进。

## 目录说明

- 当前主线脚本保留在 `step_08_routeB_innovation` 根目录。
- 已判定失败或不再继续推进的原型脚本、结果目录统一移入：
  - [archive_failed_prototypes/scripts](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/scripts)
  - [archive_failed_prototypes/results](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results)
- 结果目录统一按 `results_step8_*` 命名。
- 第 8 步的文字入口以后只保留本文档，不再单独保留 README。

---

## 2026-05-20 目录清理记录

本轮按照 [第8步改进方向.md](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/第8步改进方向.md) 执行了一次正式清理，并完成了 `Prototype 6` 的落地。

### 已删除

- `space_smooth_music_B_fft_guided_adaptive_window_piecewise_prototype4e2.m`
- `results_step8_routeB_fft_guided_adaptive_window_piecewise_proto4e2/`
- `space_smooth_music_B_fft_guided_adaptive_window_piecewise_scan_prototype4e2.m`
- `results_step8_routeB_fft_guided_adaptive_window_piecewise_scan_proto4e2/`
- `results_step8_routeB_fftii_known2_proto5a/`
- `results_step8_routeB_fftii_known2_proto5a_refined2/`

以上对象的实验结论都已经固化在本文档中，删除不影响论文证据链。

### 已归档

- [space_smooth_music_B_fftii_known2_prototype5a.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/scripts/space_smooth_music_B_fftii_known2_prototype5a.m)

归档原因：

- `FFT-II` 路线到 `5a-refined2` 为止没有复现论文第 4 章收益；
- 唯一稳定成立的强结论其实是其中的 `Root-MUSIC` 参考线；
- 因此第 8 步主线已从 `FFT-II` 切换到 `Prototype 6: FBSS + Root-MUSIC`。

### 当前主目录保留项

- `prototype4`
- `prototype4b`
- `prototype4e`
- `prototype4 fair compare`
- `prototype6`
- 本实验记录

---

## 阶段性结论

截至当前，第 8 步已经完成从 `Prototype 1` 到 `Prototype 6` 的多轮迭代。

1. `Prototype 1`：自适应加权 `centerT`
2. `Prototype 2`：双中心假设 `beamspace`
3. `Prototype 3`：协方差残差对消二次细化

阶段性结论如下：

- **三者都不适合作为当前有效创新点直接保留。**
- `Prototype 1` 与 `Prototype 2` 没有带来稳定的 `SNR90` 下移；
- `Prototype 3` 在 `bw/8 ~ bw/10` 上出现了系统性劣化；
- 因此，当前更合理的判断是：
  - **Route B 基线本身仍然稳定有效；**
  - **前三个原型只保留为失败原型记录和后续对照参考；**
  - **第 8 步后续创新不宜继续在这三条原型上直接深挖。**

当前更值得继续推进的方向，已经收敛到 FFT 引导的 `Route B` 主线，具体为：

1. **`Prototype 4`：FFT 引导基线**
2. **`Prototype 4b`：FWHM 自适应局部窗**
3. **`Prototype 4e`：分段饱和 FWHM 映射，作为 FFT 引导 Route B 的最终保留版本**
4. **`Prototype 6`：FBSS + Root-MUSIC，当前第 8 步主创新版本**

需要补充一条方法学说明：

- 第 4 线与原始稳定 `Route B` 的比较，必须控制在同一批样本、同一参数、同一 `(sep_factor, snr_db, metkl_num)` 随机种子下进行。
- 之前那版跨脚本的 `4e fullscan` 因未锁定独立 seed，不再作为正式结论使用，相关脚本与结果已删除。

### 目录整理结果

- 根目录保留：
  - `prototype4`
  - `prototype4b`
  - `prototype4e`
  - `prototype4 fair compare`
  - `prototype6`
  - 本实验记录
- `prototype1/2/3/4a/4c/5a` 失败脚本已归档。
- `prototype4e2 / prototype4e2 scan / 5a-v1 / 5a-refined2` 的脚本或结果已删除，结论仅保留在本文档。
- 临时 runner 已删除，不再保留在主目录。

---

## Prototype 1：自适应加权 centerT

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_adaptive_weighted_centerT_prototype1.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/scripts/space_smooth_music_B_adaptive_weighted_centerT_prototype1.m)

新增结果目录：

- [results_step8_routeB_adaptive_weighted_centerT_proto1](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results/results_step8_routeB_adaptive_weighted_centerT_proto1)

本次原型严格保持第 7.5 步 `Route B` 主体不变，仅修改 `centerT` 的构造方式：

1. 保留：
   - 真值中心 `RecvbeamC = mean(target_theta)`
   - 固定局部窗口 `theta_search_B`
   - 阵元域 `FBSS`
   - 后端 `DOA_three_music_new_route_centerT`
2. 在同一批 Monte Carlo 数据上同时跑：
   - `baseline_centerT`
   - `adaptive_weighted_centerT`
3. `adaptive_weighted_centerT` 的权重来源于：
   - baseline 局部粗 `MUSIC` 谱
   - 在中心 beam grid 上插值
   - `[1 2 1]/4` 平滑
   - `5%` 底噪下限
   - 列加权构造 `Tk_weighted`

### 实验参数

- `sep_factor_list = [8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`

### 结果

两条路线的 `SNR90` 完全一致：

- `bw/8`: baseline `18 dB`，weighted `18 dB`
- `bw/9`: baseline `22 dB`，weighted `22 dB`
- `bw/10`: baseline `24 dB`，weighted `24 dB`

门槛附近的代表性结果：

- `bw/8`, `16 dB`
  - baseline `tol_rate = 0.580`
  - weighted `tol_rate = 0.580`
- `bw/9`, `20 dB`
  - baseline `tol_rate = 0.815`
  - weighted `tol_rate = 0.820`
- `bw/10`, `22 dB`
  - baseline `tol_rate = 0.700`
  - weighted `tol_rate = 0.695`

整体表现为：

1. 个别点有极小波动；
2. 没有出现稳定、显著的 `tol_success_rate` 提升；
3. 没有带来 `SNR90` 下移。

### 结论

结论：**当前这版“平滑粗 MUSIC 直接权重”的自适应加权 centerT 不适合作为单独创新点保留。**

原因：

1. 它没有改变 `bw/8 ~ bw/10` 的分辨门槛；
2. 收益量级基本处于 Monte Carlo 波动范围内；
3. 单纯修改列权重，无法触及当前 `Route B` 在近间隔场景下的主要瓶颈。

### 保留建议

- **脚本保留**：作为失败原型与后续对照基线保留；
- **创新点不单独保留**：不建议将这一版“加权 centerT”单独写成有效创新点；
- **后续用途**：可作为 `Prototype 2`、`Prototype 3` 的对照参考。

---

## Prototype 2：双中心假设 beamspace

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_dual_center_beamspace_prototype2.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/scripts/space_smooth_music_B_dual_center_beamspace_prototype2.m)

新增结果目录：

- [results_step8_routeB_dual_center_beamspace_proto2](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results/results_step8_routeB_dual_center_beamspace_proto2)

本次原型保持第 7.5 步 `Route B` 主体不变，仅在局部 beamspace 构造阶段增加双中心候选：

1. 先用 baseline `centerT` 生成局部粗 `MUSIC` 谱；
2. 从粗谱提取：
   - `mu_hat`
   - `sigma_hat`
   - `peak_width_deg`
   - `asym_ratio`
3. 当粗谱主峰“过宽或不对称”时触发双中心：
   - `mu1 = mu_hat - gamma_sigma * sigma_hat`
   - `mu2 = mu_hat + gamma_sigma * sigma_hat`
4. 分别构造两个候选 `Tk1`、`Tk2`
5. 分别跑 `Route B`
6. 用噪声子空间一致性评分选择更优候选

本次固定触发规则：

- `peak_width_deg > 0.20`
  或
- `asym_ratio > 0.15`

固定偏移：

- `gamma_sigma = 0.60`

### 实验参数

- `sep_factor_list = [8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`

### 结果

两条路线的 `SNR90` 仍然完全一致：

- `bw/8`: baseline `18 dB`，dual `18 dB`
- `bw/9`: baseline `22 dB`，dual `22 dB`
- `bw/10`: baseline `24 dB`，dual `24 dB`

门槛附近的代表性结果：

- `bw/8`, `18 dB`
  - baseline `tol_rate = 0.920`
  - dual `tol_rate = 0.925`
- `bw/9`, `20 dB`
  - baseline `tol_rate = 0.815`
  - dual `tol_rate = 0.825`
- `bw/10`, `22 dB`
  - baseline `tol_rate = 0.700`
  - dual `tol_rate = 0.705`

触发情况：

- `bw/8` 在低中 SNR 区触发率较高；
- `bw/9`、`bw/10` 在门槛附近也有较高触发率；
- 但触发本身没有转化为 `SNR90` 下移。

### 结论

结论：**当前这版“双中心假设 beamspace”也不适合作为单独创新点保留。**

原因：

1. 它只带来极小的局部 `tol_rate` 波动；
2. 所有小间隔档位的 `SNR90` 都没有变化；
3. 说明当前 `Route B` 的主要瓶颈并不只是“局部中心偏置”，或者这版双中心机制还不足以真正改善近间隔分离能力。

### 保留建议

- **脚本保留**：作为失败原型与后续对照参考保留；
- **创新点不单独保留**：不建议将这版双中心 beamspace 单独作为有效创新点；
- **后续用途**：如果继续推进第 8 步，更值得转向“后端二次细化 / 残差对消”类改进。

---

## Prototype 3：协方差残差对消二次细化

### 本次新增/修改

新增脚本：
- [space_smooth_music_B_cov_residual_refine_prototype3.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/scripts/space_smooth_music_B_cov_residual_refine_prototype3.m)

新增结果目录：
- [results_step8_routeB_cov_residual_refine_proto3](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results/results_step8_routeB_cov_residual_refine_proto3)

本次原型保持第 7.5 步 `Route B` 前端不变，仅修改后端估计策略：

1. 先用 baseline `centerT` 计算第一轮局部 `MUSIC` 谱与双峰结果；
2. 按第一轮两个谱峰的峰值高度判定主导分量 `theta_dom`；
3. 在 beamspace 协方差 `Rb` 上，用秩 1 主导分量模型估计并对消：
   - `R_dom = alpha_dom * b_dom * b_dom'`
4. 对残差协方差做：
   - Hermitian 化
   - PSD 投影
5. 在同一局部搜索窗口内、带主导峰保护带地做第二轮单目标细化；
6. 最终输出固定为：
   - `sort([theta_dom, theta_refined])`

### 实验参数

- `sep_factor_list = [8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`

### 结果

`SNR90` 结果如下：

- `bw/8`: baseline `18 dB`，proto3 `NaN`
- `bw/9`: baseline `22 dB`，proto3 `NaN`
- `bw/10`: baseline `24 dB`，proto3 `NaN`

也就是说，这一版原型不是“没有改善”，而是对 `bw/8 ~ bw/10` 全部出现了系统性劣化。

代表性结果：

- `bw/8`, `18 dB`
  - baseline `tol_rate = 0.920`
  - proto3 `tol_rate = 0.000`
- `bw/9`, `22 dB`
  - baseline `tol_rate = 0.970`
  - proto3 `tol_rate = 0.000`
- `bw/10`, `24 dB`
  - baseline `tol_rate = 0.960`
  - proto3 `tol_rate = 0.000`

典型输出表明，proto3 会稳定把第二轮细化结果拉回到主导峰同侧。例如：

- `bw/8`, `16 dB`
  - baseline `doa = [12.81, 13.09]`
  - proto3 `doa = [13.09, 13.15]`
- `bw/10`, `20 dB`
  - baseline `doa = [12.93, 13.10]`
  - proto3 `doa = [12.88, 12.93]`

同时，残差协方差在典型样本中持续出现：

1. `alpha_dom` 估计稳定为较大的正值；
2. `min_eig_before_psd` 显著为负；
3. `num_negative_eigs` 基本为 `1`；
4. PSD 投影后虽然数值稳定，但第二轮峰结构已明显偏向主导峰同侧。

### 结论

结论：**当前这版“beamspace 协方差残差对消 + 单目标二次细化”不适合作为有效创新点保留。**

原因：

1. 它没有降低任何一个小间隔档位的 `SNR90`；
2. 它在 `bw/8 ~ bw/10` 上把 `tol_success_rate` 系统性打到 `0`；
3. 说明当前这版秩 1 主导分量对消过强，破坏了双目标共享的有效结构；
4. 在相干双目标场景下，直接按单峰主导项做 beamspace 协方差对消，会把第二轮残差谱推向主导峰同侧伪解。

### 保留建议

- **脚本保留**：作为失败原型与后续对照参考保留；
- **创新点不单独保留**：不建议将这版残差对消二次细化单独作为有效创新点；
- **后续用途**：如果继续推进第 8 步，更适合转向“弱对消 / 联合细化 / 成对约束”的路线，而不是继续沿这版单峰秩 1 强对消直接深挖。

---

## Prototype 4：FFT 引导的 Route B 数据驱动基线

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_fft_guided_centerT_prototype4.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_fft_guided_centerT_prototype4.m)

新增结果目录：

- [results_step8_routeB_fft_guided_centerT_proto4](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_fft_guided_centerT_proto4)

本次原型与前 3 个原型不同，不再试图直接做新创新，而是先建立一个**数据驱动版的 Route B 参考基线**：

1. 保留第 7.5 步 `Route B` 主体不变：
   - 阵元域协方差
   - 阵元域 FBSS
   - centerT beamspace 投影
   - 1D MUSIC
2. 与当前稳定 baseline 并行对比：
   - `baseline_true_centerT`
   - `fft_guided_centerT`
3. `fft_guided_centerT` 的唯一改动是：
   - 不再使用 `RecvbeamC = mean(target_theta)`
   - 改为从 `y_mean = mean(y, 2)` 的空间 FFT 粗谱中，取最大 bin 对应角度作为 `RecvbeamC_fft`
4. 其余参数全部保持不变：
   - `theta_search_B`
   - `routeB_beam_span`
   - `K_fbss`
   - `center_beam_count`
   - 后端 `DOA_three_music_new_route_centerT`

### 实验参数

- `sep_factor_list = [8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`

### 结果

`SNR90` 结果如下：

- `bw/8`: baseline `18 dB`，fft-guided `18 dB`
- `bw/9`: baseline `22 dB`，fft-guided `22 dB`
- `bw/10`: baseline `24 dB`，fft-guided `24 dB`

也就是说，在当前仿真口径下：

> **仅用 FFT 粗中心替换真值中心，并没有破坏 Route B 的小间隔门槛。**

代表性结果：

- `bw/8`, `18 dB`
  - baseline `tol_rate = 0.920`
  - fft-guided `tol_rate = 0.905`
- `bw/9`, `20 dB`
  - baseline `tol_rate = 0.815`
  - fft-guided `tol_rate = 0.825`
- `bw/10`, `22 dB`
  - baseline `tol_rate = 0.700`
  - fft-guided `tol_rate = 0.695`

FFT 中心误差表现为：

1. 在较低 SNR 下，粗中心偶尔会跳到明显错误的角度，导致均值和标准差很大；
2. 一旦进入有效分辨区间，FFT 中心误差迅速收敛；
3. 在门槛附近和门槛之上，`std_fft_center_error_deg` 已下降到较小量级，足以支撑当前 Route B 的局部 beamspace 搜索。

典型样本说明：

- `bw/8`, `14 dB`
  - `center_true = 13.0000`
  - `center_fft = -0.5622`
  - 该样本 FFT 粗中心明显失真，fft-guided 也随之失败
- `bw/8`, `18 dB`
  - `center_true = 13.0000`
  - `center_fft = 13.0763`
  - baseline 与 fft-guided 输出基本一致
- `bw/10`, `20 dB`
  - `center_true = 13.0000`
  - `center_fft = 13.2121`
  - 尽管中心存在偏移，fft-guided 仍维持与 baseline 近似一致的成功率

### 结论

结论：**Prototype 4 成立，适合作为第 8 步继续推进的参考基线保留。**

原因：

1. 它回答了一个关键问题：把 `Route B` 从“真值中心版”改成“FFT 数据驱动中心版”后，主分辨门槛没有被破坏；
2. 它证明后续创新可以围绕“FFT 先验 + Route B”继续展开，而不必继续围绕前 3 个失败原型修补；
3. 它也暴露了新的可优化点：
   - 低 SNR 时 FFT 粗中心偶发跳变；
   - 目前只取最大 bin，仍有明显的量化误差与离散峰抖动。

### 保留建议

- **脚本保留**：作为后续 `FFT + Route B` 主线的参考基线保留；
- **基线保留，不直接当创新点**：它本身更适合视为“数据驱动版参考线”，而不是最终创新点；
- **后续用途**：优先继续推进：
  - `proto4a`：FFT 主峰三点抛物线插值 / 亚波束中心修正
  - `proto4b`：FFT 置信度驱动的自适应局部搜索窗

---

## Prototype 4a：FFT 主峰三点抛物线中心修正

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_fft_guided_centerT_parabolic_prototype4a.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/scripts/space_smooth_music_B_fft_guided_centerT_parabolic_prototype4a.m)

新增结果目录：

- [results_step8_routeB_fft_guided_centerT_parabolic_proto4a](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results/results_step8_routeB_fft_guided_centerT_parabolic_proto4a)

本次原型沿着 `prototype4` 的 FFT 主线继续推进，但只优化 FFT 中心本身，不改搜索窗：

1. 三路线并行对比：
   - `baseline_true_centerT`
   - `fft_guided_centerT`
   - `fft_guided_centerT_parabolic`
2. `fft_guided_centerT` 保持 `prototype4` 的最大 bin 粗中心不变；
3. `fft_guided_centerT_parabolic` 在最大 bin 的基础上，使用主峰三点抛物线插值得到 `RecvbeamC_fft_parabolic`；
4. 其余 Route B 结构全部保持不变：
   - `FBSS`
   - `theta_search_B`
   - `routeB_beam_span`
   - `center_beam_count`
   - 1D MUSIC 后端

### 实验参数

- `sep_factor_list = [6, 7, 8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`

### 结果

三条路线的 `SNR90` 结果如下：

- `bw/6`: baseline `14 dB`，fft-guided `16 dB`，parabolic `16 dB`
- `bw/7`: baseline `16 dB`，fft-guided `18 dB`，parabolic `18 dB`
- `bw/8`: baseline `20 dB`，fft-guided `20 dB`，parabolic `20 dB`
- `bw/9`: baseline `22 dB`，fft-guided `22 dB`，parabolic `22 dB`
- `bw/10`: baseline `24 dB`，fft-guided `24 dB`，parabolic `24 dB`

结论上最关键的是：

> **三点抛物线中心修正没有进一步降低 fft-guided 路线的 `SNR90`。**

也就是说，它没有带来门槛级收益。

代表性结果：

- `bw/6`, `16 dB`
  - fft-guided `tol_rate = 0.900`
  - parabolic `tol_rate = 0.900`
- `bw/7`, `18 dB`
  - fft-guided `tol_rate = 0.975`
  - parabolic `tol_rate = 0.980`
- `bw/10`, `22 dB`
  - fft-guided `tol_rate = 0.720`
  - parabolic `tol_rate = 0.720`

可以看到，个别点位存在轻微波动，但没有转化为 `SNR90` 下移。

从中心误差角度看，parabolic 版本的确做到了很小幅的修正：

1. 在中高 SNR 下，`mean_fft_center_error_refined_deg` 与 `std_fft_center_error_refined_deg` 往往略优于 coarse；
2. 修正量通常是“小修小补”，而不是结构性改变；
3. 在低 SNR 下，如果粗 FFT 主峰已经跳错到错误角度，三点抛物线无法从根本上纠正该错误。

典型样本说明：

- `bw/6`, `16 dB`
  - `center_fft = 13.0763`
  - `center_para = 13.0621`
  - `doa_fft` 与 `doa_para` 都与 baseline 基本一致
- `bw/8`, `16 dB`
  - `center_fft = 12.9745`
  - `center_para = 12.9647`
  - parabolic 仅带来极小中心修正，门槛未变
- `bw/10`, `18 dB`
  - `center_fft = 13.0084`
  - `center_para = 13.0009`
  - 虽然 refined center 更接近真值，但该样本仍未转化为整体门槛改善

### 结论

结论：**Prototype 4a 可保留为有效的“微修正尝试”，但不适合作为单独创新点继续深挖。**

原因：

1. 它验证了一个事实：coarse FFT 最大 bin 的离散量化误差并不是当前 FFT 主线的主要瓶颈；
2. 抛物线修正对中心误差有轻微改善，但不足以带来 `SNR90` 的门槛级变化；
3. 当前 FFT 主线的主要问题仍然是：
   - 低 SNR 时粗主峰偶发跳错；
   - 搜索窗与 beam span 仍是固定的，并没有利用 FFT 粗谱的宽度与置信度信息。

### 保留建议

- **脚本保留**：作为 FFT 主线下的已验证微修正版本保留；
- **不单独作为核心创新点**：不建议把“三点抛物线中心修正”单独写成主创新点；
- **后续用途**：下一步更值得转向：
  - `proto4b`：FFT 置信度驱动的自适应局部搜索窗
  - 或者将 `parabolic center` 作为 `proto4b` 的默认中心估计组件继续复用

---

## Prototype 4b：FFT FWHM 驱动的自适应局部搜索窗

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_fft_guided_adaptive_window_prototype4b.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_fft_guided_adaptive_window_prototype4b.m)

新增结果目录：

- [results_step8_routeB_fft_guided_adaptive_window_proto4b](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_fft_guided_adaptive_window_proto4b)

本次原型沿着 `prototype4` 的 FFT 主线继续推进，但先只改局部搜索窗与 beam span，不改 FFT 中心估计方式：

1. 三路线并行对比：
   - `baseline_true_centerT`
   - `fft_guided_centerT`
   - `fft_guided_centerT_adaptive_window`
2. `baseline_true_centerT` 保持真值中心 + 固定窗；
3. `fft_guided_centerT` 保持 coarse FFT 中心 + 固定窗；
4. `fft_guided_centerT_adaptive_window` 使用 coarse FFT 主峰的 `FWHM` 估计局部窗宽，再映射为：
   - `theta_search_B_adapt`
   - `routeB_beam_span_adapt`
5. 其余 Route B 结构全部保持不变：
   - 阵元域 `FBSS`
   - 固定 `center_beam_count`
   - 1D MUSIC 后端

### 实验参数

- `sep_factor_list = [6, 7, 8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`
- `Nfft_spatial = 4096`

自适应窗映射参数：

- `gamma_search = 1.20`
- `gamma_span = 1.50`
- `search_lower_ratio = 0.60`
- `search_upper_ratio = 1.60`
- `span_lower_ratio = 0.80`
- `span_upper_ratio = 1.60`

### 结果

三条路线的 `SNR90` 结果如下：

- `bw/6`: baseline `14 dB`，fft-guided `16 dB`，adaptive-window `16 dB`
- `bw/7`: baseline `16 dB`，fft-guided `18 dB`，adaptive-window `16 dB`
- `bw/8`: baseline `20 dB`，fft-guided `20 dB`，adaptive-window `20 dB`
- `bw/9`: baseline `22 dB`，fft-guided `22 dB`，adaptive-window `22 dB`
- `bw/10`: baseline `24 dB`，fft-guided `24 dB`，adaptive-window `24 dB`

从 `SNR90` 看，`adaptive-window` 在 `bw/7` 这一档位上，把 `fft-guided` 的门槛从 `18 dB` 降回到了 `16 dB`，其余档位保持不变。

代表性结果：

- `bw/6`, `16 dB`
  - fft-guided `tol_rate = 0.900`
  - adaptive-window `tol_rate = 0.930`
- `bw/7`, `14 dB`
  - fft-guided `tol_rate = 0.495`
  - adaptive-window `tol_rate = 0.510`
- `bw/7`, `16 dB`
  - fft-guided `tol_rate = 0.880`
  - adaptive-window `tol_rate = 0.900`
- `bw/8`, `16 dB`
  - fft-guided `tol_rate = 0.555`
  - adaptive-window `tol_rate = 0.570`
- `bw/10`, `22 dB`
  - fft-guided `tol_rate = 0.720`
  - adaptive-window `tol_rate = 0.725`

可以看到，它的收益比较局部，主要集中在 `bw/7` 这一档附近；在更小间隔的 `bw/8~bw/10` 上，还没有把门槛进一步往下推。

### 修复后的实现状态

本轮对 `estimate_fft_fwhm(...)` 做了定点修复，核心是：

1. 修复了半高宽交点在递减角度网格上的宽度符号问题；
2. 增加了半高交点的线性插值；
3. 使 `FWHM` 真正成为样本级数据驱动量，而不再大面积回退到固定窗。

修复后，日志中 `fallback_fwhm=0`，并且 `mean_fwhm_fft_deg` 不再等于固定 `theta_search_B_fixed`。典型统计如下：

- `bw/7`, `16 dB`
  - `mean_fwhm_fft_deg = 2.1213`
  - `mean_theta_search_adapt_deg = 2.3731`
  - `mean_routeB_beam_span_adapt_deg = 3.5597`
- `bw/8`, `18 dB`
  - `mean_fwhm_fft_deg = 1.9824`
  - `mean_theta_search_adapt_deg = 2.2136`
  - `mean_routeB_beam_span_adapt_deg = 3.3204`
- `bw/10`, `24 dB`
  - `mean_fwhm_fft_deg = 1.9472`
  - `mean_theta_search_adapt_deg = 1.7920`
  - `mean_routeB_beam_span_adapt_deg = 2.6880`

这说明当前版本已经是一次有效的“真实自适应窗”验证，而不再只是固定窗放大版。

### 当前版本的限制

虽然 `FWHM` 估计已经工作起来，但还存在两个明显问题：

1. 自适应窗整体偏宽，尤其在 `bw/9`、`bw/10` 下经常触及上限裁剪；
2. 在低 SNR、粗中心明显跳错时，放宽搜索窗会放大误检风险，导致个别样本出现很大的条件 RMSE。

### 结论

结论：**Prototype 4b 修复后可以保留为一个有继续价值的小创新方向。**

更准确地说：

1. 修复后的 `adaptive-window` 已经不再是伪自适应，而是真正由 FFT 主峰宽度驱动；
2. 它在 `bw/7` 这一档位上带来了明确的 `2 dB` 门槛回收：`18 dB -> 16 dB`；
3. 但它的收益目前还不够广泛，在 `bw/8~bw/10` 上尚未继续压低 `SNR90`；
4. 因此它适合作为“可继续优化的小创新点”保留，而不是直接定稿为最终主创新点。

### 保留建议

- **脚本保留**：作为 `FFT + Route B` 主线下第一个真正跑通的自适应窗版本保留；
- **可继续作为创新点打磨**：优先围绕窗宽映射与置信度门控继续优化；
- **后续优先事项**：
  - 对 `FWHM -> theta_search_B / beam_span` 的映射做收缩，避免在小间隔区长期顶到上限；
  - 增加 FFT 置信度门控，在粗中心明显失真时避免盲目放宽窗口；
  - 再考虑把 `parabolic center` 与 `adaptive-window` 组合为下一版。

---

## Prototype 4c：FFT 置信度门控的自适应局部搜索窗

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_fft_confidence_gated_adaptive_window_prototype4c.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/scripts/space_smooth_music_B_fft_confidence_gated_adaptive_window_prototype4c.m)

新增结果目录：

- [results_step8_routeB_fft_confidence_gated_adaptive_window_proto4c](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results/results_step8_routeB_fft_confidence_gated_adaptive_window_proto4c)

为绕开 MATLAB 对超长脚本名的执行限制，额外新增一个同目录短 runner：

- [run_proto4c.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/run_proto4c.m)

本次原型直接基于修复后的 `prototype4b`，只新增一层“低置信回退”门控：

1. 四路线并行对比：
   - `baseline_true_centerT`
   - `fft_guided_centerT`
   - `fft_guided_centerT_adaptive_window`
   - `fft_confidence_gated_adaptive_window`
2. `fft_confidence_gated_adaptive_window` 的规则固定为：
   - 先算 coarse FFT center；
   - 再提取 `fwhm_fft_deg` 与 `peak_ratio`；
   - 若满足门控阈值，则启用 `prototype4b` 的 adaptive-window；
   - 否则回退到 `fft_guided_centerT` 的 fixed-window。

### 实验参数

- `sep_factor_list = [6, 7, 8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`
- `Nfft_spatial = 4096`

门控阈值固定为：

- `fwhm_gate_upper_deg = 2.05`
- `peak_ratio_gate = 1.80`

### 结果

四条路线的 `SNR90` 结果如下：

- `bw/6`: baseline `14 dB`，fft-guided `16 dB`，adaptive-window `16 dB`，gated-window `16 dB`
- `bw/7`: baseline `16 dB`，fft-guided `18 dB`，adaptive-window `16 dB`，gated-window `18 dB`
- `bw/8`: baseline `20 dB`，fft-guided `20 dB`，adaptive-window `20 dB`，gated-window `20 dB`
- `bw/9`: baseline `22 dB`，fft-guided `22 dB`，adaptive-window `22 dB`，gated-window `22 dB`
- `bw/10`: baseline `24 dB`，fft-guided `24 dB`，adaptive-window `24 dB`，gated-window `24 dB`

从 `SNR90` 看，`gated-window` 没有带来新的门槛收益，而且丢掉了 `prototype4b` 在 `bw/7` 上拿到的 `16 dB`。

代表性结果：

- `bw/6`, `14 dB`
  - adaptive-window `RMSE = 3.8126`
  - gated-window `RMSE = 0.0330`
  - `adaptive_use_rate = 0.185`
- `bw/7`, `16 dB`
  - fft-guided `tol_rate = 0.880`
  - adaptive-window `tol_rate = 0.900`
  - gated-window `tol_rate = 0.890`
  - `adaptive_use_rate = 0.400`
- `bw/8`, `16 dB`
  - fft-guided `tol_rate = 0.555`
  - adaptive-window `tol_rate = 0.570`
  - gated-window `tol_rate = 0.565`
  - `adaptive_use_rate = 0.410`
- `bw/10`, `14 dB`
  - adaptive-window `raw_rate = 0.005`
  - gated-window `raw_rate = 0.000`
  - `adaptive_use_rate = 0.175`

### 门控行为观察

这版门控不是空转，`adaptive_use_rate` 在不同 `snr` 和 `sep_factor` 下明显变化：

- `bw/6`
  - `14 dB`: `adaptive_use_rate = 0.185`
  - `28 dB`: `adaptive_use_rate = 0.955`
- `bw/7`
  - `16 dB`: `adaptive_use_rate = 0.400`
  - `28 dB`: `adaptive_use_rate = 0.985`
- `bw/10`
  - `14 dB`: `adaptive_use_rate = 0.175`
  - `28 dB`: `adaptive_use_rate = 0.980`

说明：

1. 当前固定阈值门控确实能识别一部分低置信样本并回退；
2. 随 SNR 升高，更多样本会切换到 adaptive-window；
3. 门控逻辑本身是工作的，但阈值位置不够合适。

### 结论

结论：**Prototype 4c 这版“固定阈值 + 硬回退”门控，不适合作为当前最佳创新版本保留。**

更准确地说：

1. 它的优点是明确的：
   - 在 `bw/6, 14 dB` 这类低置信场景中，显著抑制了 `prototype4b` 的极端条件 RMSE 爆点；
   - 说明“置信度门控”这个方向在机制上是合理的。
2. 但它的缺点同样明确：
   - 它没能保住 `prototype4b` 在 `bw/7` 上拿到的 `16 dB`；
   - 在当前固定阈值下，门控偏保守，把一部分本来应该走 adaptive-window 的有效样本挡掉了。

因此，这一版不能作为主保留版本，但它证明了：

> **问题不在“要不要门控”，而在“当前这组固定阈值门控太保守”。**

### 保留建议

- **脚本保留**：作为 `FFT + Route B` 主线下的门控失败原型保留；
- **不作为当前最佳创新点**：因为它破坏了 `prototype4b` 在 `bw/7` 上的门槛回收；
- **后续用途**：
  - 若继续做 `proto4c` 方向，应优先改为更柔和的连续门控或更合理的阈值映射；
  - 当前阶段更值得优先回到 `prototype4b`，继续优化 `FWHM -> 窗宽` 的映射收缩，而不是先深挖固定阈值硬回退。

---

## Prototype 4d：FWHM 映射收缩优化

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_fft_guided_adaptive_window_prototype4d.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_fft_guided_adaptive_window_prototype4d.m)

新增结果目录：

- [results_step8_routeB_fft_guided_adaptive_window_proto4d](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results/results_step8_routeB_fft_guided_adaptive_window_proto4d)

为绕开 MATLAB 对超长脚本名的执行限制，额外新增一个同目录短 runner：

- [run_proto4d.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/run_proto4d.m)

本次原型回到 `prototype4b` 主线，只修改 `FWHM -> theta_search_B / beam_span` 的映射参数，不叠加门控，不改 FFT 中心，不改 Route B 后端。

正式收缩参数固定为：

- `gamma_search = 1.05`
- `gamma_span = 1.35`
- `search_lower_ratio = 0.60`
- `search_upper_ratio = 1.40`
- `span_lower_ratio = 0.80`
- `span_upper_ratio = 1.40`

### 实验参数

- `sep_factor_list = [6, 7, 8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`
- `Nfft_spatial = 4096`

三路线并行对比：

- `baseline_true_centerT`
- `fft_guided_centerT`
- `fft_guided_centerT_adaptive_window_shrunk`

### 结果

三条路线的 `SNR90` 结果如下：

- `bw/6`: baseline `14 dB`，fft-guided `16 dB`，adaptive-window-shrunk `16 dB`
- `bw/7`: baseline `16 dB`，fft-guided `18 dB`，adaptive-window-shrunk `18 dB`
- `bw/8`: baseline `20 dB`，fft-guided `20 dB`，adaptive-window-shrunk `20 dB`
- `bw/9`: baseline `22 dB`，fft-guided `22 dB`，adaptive-window-shrunk `22 dB`
- `bw/10`: baseline `24 dB`，fft-guided `24 dB`，adaptive-window-shrunk `24 dB`

关键结论是：

> **这组“强收缩”参数没有保住 `prototype4b` 在 `bw/7` 上的 `16 dB`，因此不能作为正式替代版本。**

代表性结果：

- `bw/7`, `16 dB`
  - fft-guided `tol_rate = 0.880`
  - prototype4b `tol_rate = 0.900`
  - prototype4d `tol_rate = 0.895`
- `bw/8`, `16 dB`
  - fft-guided `tol_rate = 0.555`
  - prototype4b `tol_rate = 0.570`
  - prototype4d `tol_rate = 0.570`
- `bw/10`, `24 dB`
  - fft-guided `tol_rate = 0.955`
  - prototype4b `tol_rate = 0.955`
  - prototype4d `tol_rate = 0.945`

### 映射收缩效果

虽然这组参数没有改善最终门槛，但它确实做到了预期的“窗宽收缩”：

- `bw/7`, `16 dB`
  - prototype4b `mean_theta_search_adapt_deg = 2.3731`
  - prototype4d `mean_theta_search_adapt_deg = 2.0765`
- `bw/9`, `22 dB`
  - prototype4b `mean_theta_search_adapt_deg = 1.9911`
  - prototype4d `mean_theta_search_adapt_deg = 1.7422`
- `bw/10`, `24 dB`
  - prototype4b `mean_theta_search_adapt_deg = 1.7920`
  - prototype4d `mean_theta_search_adapt_deg = 1.5680`

也就是说，收缩是生效的，只是这版收缩幅度偏大，已经开始损失 `bw/7` 的有效样本。

### 结论

结论：**Prototype 4d 当前这组“强收缩”参数不适合作为新的主保留版本。**

更准确地说：

1. 它证明了“通过直接收缩映射参数，确实可以显著压低实际窗宽”；
2. 但它同时证明了“如果收缩过度，会先伤到 `bw/7` 这类最先受益的档位”；
3. 因此，这组 4d 参数不能直接替代 `prototype4b`。

### 保留建议

- **脚本保留**：作为“强收缩失败原型”保留；
- **不作为当前主创新点版本**：因为它丢掉了 `bw/7` 的 `16 dB`；
- **后续用途**：
  - 只能结合 mapping scan 继续反推更合适的中间收缩量；
  - 当前仍以 `prototype4b` 作为主保留版本。

---

## Prototype 4d mapping scan：小范围三档映射扫描

### 本次新增/修改

新增脚本：

- [space_smooth_music_B_fft_guided_adaptive_window_mapping_scan_prototype4d.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_fft_guided_adaptive_window_mapping_scan_prototype4d.m)

新增结果目录：

- [results_step8_routeB_fft_guided_adaptive_window_mapping_scan_proto4d](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/archive_failed_prototypes/results/results_step8_routeB_fft_guided_adaptive_window_mapping_scan_proto4d)

新增同目录短 runner：

- [run_proto4d_mapping_scan.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/run_proto4d_mapping_scan.m)

本轮扫描只比较三组小范围映射：

- `config_A_current4b`
  - `gamma_search = 1.20`
  - `gamma_span = 1.50`
  - `search_upper_ratio = 1.60`
  - `span_upper_ratio = 1.60`
- `config_B_moderate_shrink`
  - `gamma_search = 1.10`
  - `gamma_span = 1.40`
  - `search_upper_ratio = 1.50`
  - `span_upper_ratio = 1.50`
- `config_C_strong_shrink`
  - `gamma_search = 1.05`
  - `gamma_span = 1.35`
  - `search_upper_ratio = 1.40`
  - `span_upper_ratio = 1.40`

### 扫描参数

- `sep_factor_list = [7, 8, 9, 10]`
- `snr_list = [16, 18, 20, 22, 24]`
- `Metkl = 200`
- `T_snap = 260`

### 结果

各配置的 `SNR90` 结果如下：

- `bw/7`
  - `config_A_current4b = 18 dB`
  - `config_B_moderate_shrink = 18 dB`
  - `config_C_strong_shrink = 18 dB`
- `bw/8`
  - `config_A_current4b = 18 dB`
  - `config_B_moderate_shrink = 20 dB`
  - `config_C_strong_shrink = 18 dB`
- `bw/9`
  - 三组都为 `22 dB`
- `bw/10`
  - 三组都为 `24 dB`

这里要注意一个事实：

> **在这组 `[16,18,20,22,24]` 的局部扫描口径下，并没有出现“中等收缩优于 current4b”的结果。**

反而：

1. `config_B_moderate_shrink` 把 `bw/8` 从 `18 dB` 推到了 `20 dB`；
2. `config_C_strong_shrink` 也没有在 `bw/7` 上恢复到 `16 dB`；
3. `bw/9~bw/10` 三组门槛保持一致，没有出现新的收益。

### 结论

结论：**本轮三档小范围映射扫描，没有找到一个比 current4b 更优的收缩配置。**

更准确地说：

1. “收缩方向”本身不是错的，但本轮测试的两档收缩都没有带来更好的整体平衡；
2. `current4b` 在当前已测三档中，仍然是最稳的参考点；
3. 至少基于这次 scan，不能把“继续收缩映射”视为当前最优推进方向。

### 保留建议

- **脚本保留**：作为映射扫描记录保留；
- **结论保留**：当前三档扫描未找到优于 `current4b` 的替代配置；
- **后续用途**：
  - 若后续还要继续沿窗映射方向深挖，需要改成更细粒度、更定向的局部搜索，而不是继续线性整体收缩；
  - 当前阶段，`prototype4b` 仍是最适合继续保留的主版本。

---

## Prototype 4e：分段饱和 FWHM 映射

### 本次新增/修改

新增脚本：
- [space_smooth_music_B_fft_guided_adaptive_window_piecewise_prototype4e.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_fft_guided_adaptive_window_piecewise_prototype4e.m)

新增结果目录：
- [results_step8_routeB_fft_guided_adaptive_window_piecewise_proto4e](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_fft_guided_adaptive_window_piecewise_proto4e)

这次不再继续做整体线性收缩，也不继续做固定阈值硬门控，而是直接基于 prototype4b 改 FWHM -> theta_search_B / beam span 的映射形态。

核心修改只有一处：
- 保留 FFT coarse center；
- 保留修复后的 FWHM 估计；
- 保留 Route B 前后端主体；
- 仅把线性映射改成分段饱和映射，只压缩大 FWHM 区域。

本次固定参数：
- gamma_search = 1.20
- eta_span = 1.45
- search_lower_ratio = 0.60
- search_upper_ratio = 1.45
- span_lower_ratio = 0.80
- span_upper_ratio = 1.45

搜索比值采用三段映射：
- _raw <= 1.05：保持原行为
- 1.05 < r_raw <= 1.35：中段轻度压缩
- _raw > 1.35：高段进一步饱和

### 实验参数

- sep_factor_list = [7, 8, 9, 10]
- snr_list = 14:2:28
- Metkl = 200
- T_snap = 260
- Nfft_spatial = 4096

三路线并行对比：
- aseline_true_centerT
- ft_guided_centerT
- ft_guided_centerT_adaptive_window_piecewise

### 结果

SNR90 结果如下:
- bw/7: prototype4b 16 dB，prototype4e 16 dB
- bw/8: prototype4b 20 dB，prototype4e 18 dB
- bw/9: prototype4b 22 dB，prototype4e 22 dB
- bw/10: prototype4b 24 dB，prototype4e 24 dB

这说明：
- prototype4e **保住了** prototype4b 在 bw/7 上已经拿到的 16 dB；
- prototype4e **已经把收益从 bw/7 扩展到了 bw/8**；
- 当前瓶颈是如何在不损伤 bw/7 的前提下继续推进 bw/9 和 bw/10。

门槛附近的代表性结果：
- w/7, 16 dB
  - prototype4b tol_rate = 0.900
  - prototype4e tol_rate = 0.915
- w/8, 18 dB
  - prototype4b tol_rate = 0.870
  - prototype4e tol_rate = 0.930
- w/9, 20 dB
  - prototype4b tol_rate = 0.810
  - prototype4e tol_rate = 0.815
- w/10, 22 dB
  - prototype4b tol_rate = 0.725
  - prototype4e tol_rate = 0.735

也就是说，prototype4e 在门槛附近不仅有局部改善，而且已经在当前离散网格上把 bw/8 的 SNR90 从 20 dB 压到了 18 dB；当前还未突破的是 bw/9 和 bw/10。

### 映射收缩效果

和 prototype4b 相比，prototype4e 的窗宽明显更收敛：

- w/7, 16 dB
  - prototype4b mean_theta_search_adapt_deg = 2.3731
  - prototype4e mean_theta_search_adapt_deg = 1.9769
- w/8, 18 dB
  - prototype4b mean_theta_search_adapt_deg = 2.2136
  - prototype4e mean_theta_search_adapt_deg = 1.7806
- w/9, 22 dB
  - prototype4b mean_theta_search_adapt_deg = 1.9911
  - prototype4e mean_theta_search_adapt_deg = 1.6269
- w/10, 24 dB
  - prototype4b mean_theta_search_adapt_deg = 1.7920
  - prototype4e mean_theta_search_adapt_deg = 1.5092

从日志和 CSV 看，prototype4e 的样本大多进入高 FWHM 区域，但分段饱和后没有出现 w/7 回退，这说明：

> **问题确实不是必须做整体线性收缩，而是应该只对大 FWHM 区域做定向压缩。**

### 结论

结论：**Prototype 4e 是当前第 8 步 FFT 主线中的主保留版本，但它的定位应明确为“近间隔定向增强分支”。**

更准确地说：
1. 它证明了“分段饱和映射”比“整体线性收缩”更合理；
2. 它保住了 w/7 = 16 dB，没有重演 prototype4d 的回退；
3. 它已经把收益从 `bw/7` 扩展到了 `bw/8`；
4. 当前这组参数还没有继续突破 `bw/9 ~ bw/10`；
5. 当前对 `4e` 的保留依据，仍然只来自第 4 线内部相邻原型之间的局部比较；它与原始稳定 `Route B` 的关系需要在公平对比脚本中重新判断。

### 保留建议

- **脚本保留**：作为 `prototype4b` 之后最值得继续深化的一条主分支保留；
- **结果保留**：它已经证明“非线性、只压大 FWHM 区域”的方向成立；
- **当前主版本保持 4e**：因为在第 4 线内部现有实验里，它仍然是比 `4b` 更值得保留的一版；
- **后续优先方向**：继续围绕 `4e` 做更定向的验证与解释，而不是回到整体收缩或固定阈值硬门控。


---

## Prototype 4e2 scan：高段起点后移与高段斜率扫描

### 本次新增/修改

当时新增脚本：
- `space_smooth_music_B_fft_guided_adaptive_window_piecewise_scan_prototype4e2.m`

当时新增结果目录：
- `results_step8_routeB_fft_guided_adaptive_window_piecewise_scan_proto4e2/`

说明：上述脚本与结果目录已在 `2026-05-20` 清理中删除，保留结论，不再保留文件副本。

这轮扫描不再做整体收缩，只围绕 prototype4e 继续微调两类参数：
- piecewise_break2
- piecewise_high_slope

固定不变：
- gamma_search = 1.20
- eta_span = 1.45
- piecewise_break1 = 1.05
- piecewise_mid_slope = 0.50
- 其余 Route B 参数全部保持不变

扫描配置：
- config_A_current4e: reak2 = 1.35, high_slope = 0.20
- config_B_delay_high: reak2 = 1.50, high_slope = 0.18
- config_C_delay_high_stronger: reak2 = 1.55, high_slope = 0.12

并且所有配置的 piecewise_high_anchor 都按中段连续性自动生成，不手写常数。

### 扫描参数

- sep_factor_list = [7, 8, 9, 10]
- snr_list = [16, 18, 20, 22, 24]
- Metkl = 200
- T_snap = 260

### 结果

扫描结果比原先判断更苛刻：
- 在这轮 scan 口径下，三组配置都没有把 w/7 保持在 16 dB
- 三组配置的 w/7 SNR90 都表现为 18 dB

三组 SNR90 对比如下：
- config_A_current4e: w/7=18, w/8=20, w/9=22, w/10=24
- config_B_delay_high: w/7=18, w/8=18, w/9=22, w/10=24
- config_C_delay_high_stronger: w/7=18, w/8=18, w/9=22, w/10=24

也就是说：
- 后移高段起点确实把 w/8 从 20 dB 拉回到了 18 dB
- 但并没有继续突破 w/9 或 w/10
- 同时，在这轮 scan 口径下，没有任何一组通过“w/7 <= 16 dB”这一硬门槛

自动选优因此退化成“在都没通过 w/7 约束时，选整体更优的一组”，最终选中：
- config_C_delay_high_stronger
- piecewise_break2 = 1.55
- piecewise_high_slope = 0.12
- piecewise_high_anchor = 1.30

### 结论

结论：**这轮 4e2 scan 没有找到一个明确优于当前 prototype4e 的新配置。**

更准确地说：
1. “高段起点后移”这件事本身是合理的；
2. 它可以帮助把 w/8 维持在 18 dB；
3. 但这轮三组配置都没有继续压低 w/9 或 w/10 的门槛；
4. 并且在扫描口径下，它们对 w/7 也没有表现出比当前 4e 更稳的优势。

### 保留建议

- **脚本保留**：作为 4e 后续微调的扫描记录保留；
- **结果保留**：说明“仅靠继续后移高段起点 + 调高段斜率”暂时没有突破 w/9~bw/10；
- **当前不升级主版本**：因为 scan 没有给出一个明确超越 4e 的配置。

---

## Prototype 4e2：分段映射 v2

### 本次新增/修改

当时新增脚本：
- `space_smooth_music_B_fft_guided_adaptive_window_piecewise_prototype4e2.m`

当时新增结果目录：
- `results_step8_routeB_fft_guided_adaptive_window_piecewise_proto4e2/`

说明：上述脚本与结果目录已在 `2026-05-20` 清理中删除，保留结论，不再保留文件副本。

这版正式原型直接固化 scan 自动选出的配置：
- piecewise_break2 = 1.55
- piecewise_high_slope = 0.12
- piecewise_high_anchor = 1.30

三路线并行对比：
- aseline_true_centerT
- ft_guided_centerT
- ft_guided_centerT_adaptive_window_piecewise_v2

### 实验参数

- sep_factor_list = [7, 8, 9, 10]
- snr_list = 14:2:28
- Metkl = 200
- T_snap = 260
- Nfft_spatial = 4096

### 结果

正式 4e2 的 SNR90 结果如下：
- w/7: baseline 16 dB，fft-guided 18 dB，piecewise-v2 16 dB
- w/8: baseline 18 dB，fft-guided 18 dB，piecewise-v2 18 dB
- w/9: baseline 22 dB，fft-guided 22 dB，piecewise-v2 22 dB
- w/10: baseline 24 dB，fft-guided 24 dB，piecewise-v2 24 dB

和当前 prototype4e 相比：
- w/7 仍然保住了 16 dB
- w/8 仍然保住了 18 dB
- w/9、w/10 仍然没有新突破

门槛附近的代表性对比如下：
- w/7, 16 dB
  - prototype4e tol_rate = 0.915
  - prototype4e2 tol_rate = 0.915
- w/8, 18 dB
  - prototype4e tol_rate = 0.930
  - prototype4e2 tol_rate = 0.930
- w/9, 20 dB
  - prototype4e tol_rate = 0.815
  - prototype4e2 tol_rate = 0.815
- w/10, 22 dB
  - prototype4e tol_rate = 0.735
  - prototype4e2 tol_rate = 0.735

从结果上看，4e2 基本与 4e 持平，没有形成新的门槛收益。

### 结论

结论：**Prototype 4e2 与当前的 Prototype 4e 基本持平，没有形成升级。**

更准确地说：
1. 它说明后移高段起点后的这组更强压缩参数，在完整实验口径下可以维持 `4e` 已有收益；
2. 但它没有把收益继续推进到 `bw/9~bw/10`；
3. 也没有在门槛附近形成比 `4e` 更明显的 `tol_success_rate` 提升。

### 保留建议

- **脚本保留**：作为 4e 的一次正式后续迭代保留；
- **结果保留**：它说明当前 piecewise 方向继续微调后，已经接近平台；
- **主版本仍保持 4e**：当前最合适的主保留版本仍是 prototype4e，而不是 prototype4e2。

---

## 已撤回记录：Prototype 4e fullscan

此前曾新增过一版 `4e` 对稳定 `Route B` 的 `bw/1~bw/10` fullscan，对比脚本和结果现已删除。

撤回原因：

1. 当时的 fullscan 没有把 `(sep_factor, snr_db, metkl_num)` 绑定为独立固定 seed；
2. 因而它与前面局部 `bw/7~bw/10` 脚本之间并不是严格同条件对比；
3. 该结论容易把“跨脚本随机数状态差异”误判成“算法性能退化”。

处理决定：

- **脚本删除**：不再保留该 fullscan 脚本；
- **结果删除**：不再保留该 fullscan 结果目录；
- **结论撤回**：不再用该 fullscan 结论评价 `4e` 相对稳定 `Route B` 的优劣。

---

## Prototype 4 line fair compare：固定独立 seed 的公平对比

### 本次新增/修改

新增脚本：
- [space_smooth_music_B_fft_guided_fair_compare_prototype4_line.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_fft_guided_fair_compare_prototype4_line.m)

新增结果目录：
- [results_step8_routeB_fft_guided_fair_compare_proto4_line](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_fft_guided_fair_compare_proto4_line)

这轮对比的目的不是继续扩展新原型，而是先把第 4 线内部现有保留路线放在**严格同条件**下重比一遍。

并行路线：

- `baseline_true_centerT`
- `fft_guided_centerT_proto4`
- `fft_guided_centerT_adaptive_window_proto4b`
- `fft_guided_centerT_piecewise_proto4e`

公平性规则：

- 对每个 `(sep_factor, snr_db, metkl_num)` 单独固定随机种子；
- 也就是每条路线都吃到**完全同一批** `y`；
- 避免跨脚本、跨循环范围导致随机数状态漂移。

本次固定参数：

- `sep_factor_list = [7, 8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`
- `tol_deg = 0.1`
- `base_seed = 20260520`

### 结果

公平对比后的 `SNR90` 为：

- `bw/7`:
  - baseline `16 dB`
  - proto4 `18 dB`
  - proto4b `18 dB`
  - proto4e `18 dB`
- `bw/8`:
  - 四条路线全部为 `18 dB`
- `bw/9`:
  - 四条路线全部为 `22 dB`
- `bw/10`:
  - 四条路线全部为 `24 dB`

门槛附近代表点如下：

- `bw/7, 14 dB`
  - baseline `0.815`
  - proto4 `0.515`
  - proto4b `0.570`
  - proto4e `0.565`
- `bw/7, 16 dB`
  - baseline `1.000`
  - proto4 `0.855`
  - proto4b `0.880`
  - proto4e `0.870`
- `bw/8, 16 dB`
  - baseline `0.590`
  - proto4 `0.500`
  - proto4b `0.550`
  - proto4e `0.535`
- `bw/9, 18 dB`
  - baseline `0.425`
  - proto4 `0.425`
  - proto4b `0.425`
  - proto4e `0.435`
- `bw/10, 22 dB`
  - baseline `0.745`
  - proto4 `0.745`
  - proto4b `0.735`
  - proto4e `0.735`

### 结论

结论：**第 4 线内部确实存在局部优化差异，但这些优化没有把 FFT 线整体拉回到真值中心 baseline 之上。**

更准确地说：

1. 公平对比后，可以确认之前“跨脚本随机数状态不同”确实会影响判断；
2. 但把随机性锁严之后，`proto4b/4e` 仍然没有在 `SNR90` 上超越 baseline；
3. `4b/4e` 的收益主要表现为：
   - 在部分低中 SNR 点，较 `proto4` 有小幅补偿；
   - 但补偿幅度不足以改变 `bw/7~bw/10` 的整体门槛；
4. 因此第 4 线当前的主瓶颈，不是窗宽映射，而是 **FFT coarse center 本身**。

### 保留建议

- **`proto4` 保留**：作为 FFT 引导基线保留；
- **`proto4b` / `proto4e` 保留**：作为“对 FFT center 误差做后续补偿”的证据保留；
- **不再把第 4 线当作已成立创新点**：目前更适合将其视为“FFT 先验替代真值中心”的探索分支；
- **下一步若继续**：优先检查和优化 FFT 中心估计本身，而不是继续在 `4b/4e` 的窗映射上细调。

---

## Prototype 5a：贴近论文第 4 章的 FFT-II 已知双目标原型

### 本次新增

新增脚本：
- [space_smooth_music_B_fftii_known2_prototype5a.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_fftii_known2_prototype5a.m)

新增结果目录：
- [results_step8_routeB_fftii_known2_proto5a](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_fftii_known2_proto5a)

这一版的目的，不再是继续细调 `Route B + FFT centerT` 的窗口映射，而是先按论文第 4 章的主骨架，在当前数据模型下落一个**已知双目标**的 `FFT-II` 原型。

并且这次把比较条件锁严为同样本、同 seed 的公平对照。

### 公平对照设置

同一批样本并跑 6 条路线：

- `baseline_true_centerT`
- `fft_guided_centerT_proto4`
- `fft_guided_centerT_adaptive_window_proto4b`
- `fft_guided_centerT_piecewise_proto4e`
- `root_music_reference`
- `fftii_known2_proto5a`

公平性规则：

- 对每个 `(sep_factor, snr_db, metkl_num)` 单独固定随机种子；
- 本次使用 `base_seed = 20260521`；
- 所有路线共享完全同一批 `y`；
- 不再使用跨脚本继承随机数状态的方式比较。

实验参数：

- `sep_factor_list = [7, 8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`
- `tol_deg = 0.1`

### 实现口径

#### 1. Route B 系列路线

`baseline / proto4 / proto4b / proto4e` 直接复用了当前公平对比脚本中的定义与统计口径。

这一步的作用是：

- 保证第 5 步论文线和第 4 步主线是严格同条件下比较；
- 同时也能用来反查新脚本是否把样本生成和对照口径跑偏。

#### 2. Root-MUSIC 参考线

脚本内本地实现了一条 `root_music_reference`：

- 先由 `y` 构造阵元域协方差 `Rxx = y*y'/T_snap`
- 再用 [mssp_array_fb.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_07_5_space_smooth_beamspace_MUSIC_monte_carlo/mssp_array_fb.m) 做 `K_fbss = 56` 的 FBSS
- 在 `R_ss` 上按 `D = 2` 做 Root-MUSIC 求根

这一条参考线的意义是：

- 它更贴近论文第 4 章里的对照结构；
- 也能用来判断当前工程参数下，迭代类 FFT-II 是否真的比常规子空间超分辨更强。

#### 3. FFT-II 已知双目标 v1

这版 `fftii_known2_proto5a` 固定为：

1. `y_mean = mean(y,2)` 做空间 FFT；
2. 基于 FFT 粗谱做双目标初始化；
3. 若找不到稳定双峰，则退化为单峰左右对称扰动初始化；
4. 用 `y_mean` 上的最小二乘复幅度做“其他目标分量对消”；
5. 对每个目标做三点抛物线式局部 FFT 插值细化；
6. 采用交替外层迭代；
7. 按角度更新量和残余功率变化率停止。

也就是说：

- **已知目标数 = 2**
- **不做 MDL/BIC**
- **不做 RELAX**
- **不回写第 7 / 7.5 步稳定函数**

### 结果检查

先看最关键的口径校验：

#### 1. 旧路线的公平对照结果对齐成功

`prototype5a` 脚本中的前 4 条老路线，已经与前面的 fair compare 结果对齐：

- `bw/7`: baseline `16 dB`, proto4 `18 dB`, proto4b `18 dB`, proto4e `18 dB`
- `bw/8`: baseline `18 dB`, proto4 `18 dB`, proto4b `18 dB`, proto4e `18 dB`
- `bw/9`: baseline `22 dB`, proto4 `22 dB`, proto4b `22 dB`, proto4e `22 dB`
- `bw/10`: baseline `24 dB`, proto4 `24 dB`, proto4b `24 dB`, proto4e `24 dB`

这说明：

- 新脚本里的样本生成和统计口径是对的；
- 第 5 步这轮对照已经建立在与第 4 线一致的公平条件上。

#### 2. Root-MUSIC 参考线结果

`root_music_reference` 的 `SNR90` 为：

- `bw/7`: `14 dB`
- `bw/8`: `16 dB`
- `bw/9`: `20 dB`
- `bw/10`: `22 dB`

对比同脚本下的 `baseline_true_centerT`：

- `bw/7`: baseline `16 dB`
- `bw/8`: baseline `18 dB`
- `bw/9`: baseline `22 dB`
- `bw/10`: baseline `24 dB`

说明在当前这套工程参数下：

- FBSS 协方差上的 `Root-MUSIC` 参考线明显强于当前 Step 08 的 `Route B` 主线；
- 这也再次说明，Step 08 第 4 线目前没有建立起“比经典超分辨参考更强”的优势。

#### 3. FFT-II v1 结果

当前 `fftii_known2_proto5a` 的结果是：

- `bw/7 ~ bw/10` 全部没有达到 `tol_success_rate >= 0.9`
- 因而 `SNR90` 全部为 `NaN`
- 门槛附近代表点全部为 `0.000`

例如：

- `bw/7, 18 dB`: `0.000`
- `bw/8, 18 dB`: `0.000`
- `bw/9, 20 dB`: `0.000`
- `bw/10, 22 dB`: `0.000`

RMSE 也明显异常大，例如：

- `bw/7, 20 dB`: `1.2001 deg`
- `bw/8, 20 dB`: `1.2154 deg`
- `bw/9, 20 dB`: `1.3312 deg`
- `bw/10, 22 dB`: `1.3444 deg`

这已经不是“略差于参考线”，而是**当前 FFT-II v1 实现还没有跑对**。

### 失败模式分析

从日志和调试量看，当前失败主要集中在前端初始化与细化骨架：

1. `fftii_init_two_peak_rate` 几乎为 `0`
   - 除 `bw/7` 的个别低 SNR 样本外，几乎全部退化为 `single_peak_fallback`

2. `fftii_init_single_peak_fallback_rate` 几乎为 `1`
   - 也就是当前 FFT-II 实际上并没有稳定地从 FFT 粗谱中找到“两目标可分的初始化”

3. 单峰 fallback 的左右对称扰动，配合当前的三点局部插值，容易把两个目标拉成：
   - 一个留在主峰附近
   - 另一个被残余谱或旁瓣拖走

4. 典型样本里经常出现：
   - `theta_init` 非常贴近主峰中心
   - 但细化后的 `theta_final_fftii` 仍然被拉到偏离真实双目标的位置

因此，这一版的问题不是“公平对照做错了”，而是：

- **FFT-II v1 的当前实现骨架，还没有复现论文中真正有效的初始化 + 对消 + 插值链条。**

### 结论

结论：**Prototype 5a 已经完成了公平对照框架的搭建，但当前 FFT-II v1 没有复现论文第 4 章声称的收益。**

更准确地说：

1. 本轮最重要的正结果是：
   - 第 5 步论文线已经被放到与 `baseline / proto4 / proto4b / proto4e` 完全同条件的比较框架里；
2. `Root-MUSIC` 参考线在当前参数下明显优于 Step 08 的 Route B 主线；
3. 当前 `FFT-II known2` 实现没有优于 `proto4/proto4b/proto4e`，也没有优于 `Root-MUSIC`；
4. 因而这版 `5a` 暂时只能记为：
   - **“贴近论文主线的第一版实现已完成，但当前实现未复现论文收益。”**

### 保留建议

- **脚本保留**：它已经建立了 Step 5 的公平评测框架；
- **结果保留**：它说明失败发生在 FFT-II 当前实现本身，而不是比较口径；
- **后续若继续 5b/5a-refine**：
  - 优先检查 FFT-II 的双峰初始化与泄漏/对消公式；
  - 再检查当前三点局部插值是否过于粗糙；
  - 不建议在当前这版结果基础上直接推进源数自估计。

### 5a-v1 与 5a-refined 的补充修正

在继续第 5 步前，需要把 `SNR90` 的使用口径再明确一次：

- `SNR90` 不是错误指标；
- 它的语义一直是：
  - 在当前离散 `snr_list` 上，首次满足 `tol_success_rate >= 0.9` 的 SNR；
- 例如 `bw/7: 16 / 18 / 18 / 18 dB` 表示：
  - `baseline / proto4 / proto4b / proto4e`
  - 在 `sep_factor = 7` 时，各自第一次达到 `90%` 成功率的离散门槛分别为 `16 / 18 / 18 / 18 dB`。

但从 `Prototype 5a` 开始，不能再只用 `SNR90` 下结论，因此修正版额外增加了：

- 绝对容差主口径：`tol_deg_abs = 0.1 deg`
- 相对容差辅口径：`tol_deg_rel = 0.25 * theta_sep`
- 代表性门槛点 `keypoints.csv`

也就是说，第 5 步之后的结论要同时看：

1. `SNR90_abs01`
2. `SNR90_rel025`
3. 门槛附近固定代表点成功率
4. `RMSE`

#### Prototype 5a refined

修正版继续使用同样本、同 seed 的 6 路公平对照，并保留旧目录：

- `5a-v1` 结果目录：
  - [results_step8_routeB_fftii_known2_proto5a](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_fftii_known2_proto5a)
- `5a-refined` 结果目录：
  - [results_step8_routeB_fftii_known2_proto5a_refined](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_fftii_known2_proto5a_refined)

本轮修正只动 `FFT-II`，不动：

- `baseline`
- `proto4`
- `proto4b`
- `proto4e`
- `Root-MUSIC`

具体改动为：

1. 初始化改成“主峰 + 一次对消后找次峰”
2. 幅度估计改成双目标联合 LS
3. 对消逻辑改成“减其他目标，不减当前目标”
4. 局部细化改成“本地角度搜索 + 三点抛物线修正”
5. 增加最小间隔 guard，避免两目标坍缩

#### 5a-refined 的结果

先看公平性回归检查：

- `baseline / proto4 / proto4b / proto4e` 的 `SNR90_abs01` 仍为：
  - `bw/7`: `16 / 18 / 18 / 18`
  - `bw/8`: `18 / 18 / 18 / 18`
  - `bw/9`: `22 / 22 / 22 / 22`
  - `bw/10`: `24 / 24 / 24 / 24`

说明：

- 修正版脚本没有把第 4 线公平对照框架跑偏；
- 这次对 `FFT-II` 的修改没有污染老路线结果。

`Root-MUSIC` 参考线仍然明显更强：

- `SNR90_abs01`
  - `bw/7 = 14 dB`
  - `bw/8 = 16 dB`
  - `bw/9 = 20 dB`
  - `bw/10 = 22 dB`
- `SNR90_rel025`
  - `bw/7 = 14 dB`
  - `bw/8 = 18 dB`
  - `bw/9 = 20 dB`
  - `bw/10 = 22 dB`

`FFT-II refined` 相比 `5a-v1` 的确不再是全零失败，但仍远没达到可保留标准：

- `bw/7 ~ bw/10` 的 `SNR90_abs01` 仍全部为 `NaN`
- `SNR90_rel025` 也仍全部为 `NaN`
- 说明即使修正后，它仍没有在当前离散 SNR 网格上达到 `90%` 成功率门槛

不过它比 `5a-v1` 确实有实质改善，门槛附近已经出现非零成功率。例如：

- `bw/7, 18 dB`
  - `tol_abs01 = 0.150`
  - `tol_rel025 = 0.150`
- `bw/8, 18 dB`
  - `tol_abs01 = 0.210`
  - `tol_rel025 = 0.155`
- `bw/9, 22 dB`
  - `tol_abs01 = 0.410`
  - `tol_rel025 = 0.295`
- `bw/10, 24 dB`
  - `tol_abs01 = 0.425`
  - `tol_rel025 = 0.275`

这说明：

- `5a-refined` 相比 `5a-v1` 已经从“几乎完全跑歪”变成“开始有部分正确样本”；
- 但距离 `Root-MUSIC` 仍然差得很远。

代表点上可以看得更清楚：

- `bw/8, 18 dB`
  - `Root-MUSIC`: `tol_abs01 = 0.990`
  - `FFT-II refined`: `0.210`
- `bw/9, 20 dB`
  - `Root-MUSIC`: `0.990`
  - `FFT-II refined`: `0.265`
- `bw/10, 22 dB`
  - `Root-MUSIC`: `1.000`
  - `FFT-II refined`: `0.385`

所以第 5 步当前的主判断应改成：

- `FFT-II refined` 相比 `v1` 已经有真实改进；
- 但它仍然**系统性弱于 `Root-MUSIC`**；
- 还不能说已经复现论文第 4 章的收益。

#### 当前瓶颈判断

`5a-refined` 最关键的诊断量是初始化模式：

- `fftii_init_two_stage_cancel_rate` 仍然接近 `0`
- `fftii_init_single_peak_fallback_rate` 仍然几乎总是接近 `1`

这说明虽然已经把初始化逻辑改成“主峰 + 对消后找次峰”，但在当前实现下：

- 一次对消残差上的第二峰仍然极少被稳定识别；
- 当前 `FFT-II` 实际上大多数样本仍在依赖单峰 fallback 起步。

因此现阶段的主瓶颈，不在 `SNR90` 指标本身，而在算法前端：

1. 两目标初始化仍然不够像论文里的有效 FFT-II 初始化
2. 当前阵列向量域对消模型仍可能过于粗糙
3. 本地搜索 + 抛物线修正虽然比 `v1` 好，但还不足以把错误初始化真正拉回正确轨道

#### 结论更新

结论应修正为：

- `5a-v1` 是失败版，问题在于初始化几乎完全退化；
- `5a-refined` 已经带来真实改进，但改进幅度仍不足以达到 `Root-MUSIC` 水平；
- 当前不应直接进入 `5b` 的源数自估计版；
- 更合理的下一步，是回头重审论文里的 FFT-II 对消与插值公式，尤其是：
  - 第二目标初始化的形成方式
  - 泄漏/干扰对消的计算域
  - 插值修正是否还需要更贴近论文原式

#### Prototype 5a refined2：FFT 域泄漏减法与空间频率插值

在 `5a-refined` 的基础上，又做了一轮更贴论文 `(4-12) ~ (4-20)` 的修正。

当时的结果目录为：

- `results_step8_routeB_fftii_known2_proto5a_refined2/`

说明：该结果目录已在 `2026-05-20` 清理中删除，保留诊断结论，不再保留结果副本。

这一轮的出发点很明确：不再只在 `theta` 域做经验修补，而是尝试把 FFT-II 的主路径回正到论文描述的实现形态：

1. 对消从阵列快拍域改回 FFT 域残差
2. 细化从 `theta` 局部搜索改为空间频率 `mu` 域插值
3. 第二目标初始化从“只拿 residual 最强峰”改成“扫描多个 residual 候选峰”

##### 结果

公平性框架仍然保持正确：

- `baseline / proto4 / proto4b / proto4e / Root-MUSIC` 的 `SNR90` 与前两版完全一致

说明：

- 这轮修改仍只影响 `FFT-II` 路线；
- 第 4 线和 `Root-MUSIC` 没有被改坏。

但是，`5a-refined2` 并没有带来想要的提升，反而整体弱于 `5a-refined`：

- `SNR90_abs01` 仍全部为 `NaN`
- `SNR90_rel025` 仍全部为 `NaN`
- keypoint 成功率多数点低于 `5a-refined`

例如：

- `bw/8, 18 dB`
  - `5a-refined`: `tol_abs01 = 0.210`
  - `5a-refined2`: `0.095`
- `bw/9, 22 dB`
  - `5a-refined`: `0.410`
  - `5a-refined2`: `0.120`
- `bw/10, 24 dB`
  - `5a-refined`: `0.425`
  - `5a-refined2`: `0.130`

与 `Root-MUSIC` 的差距仍然非常大：

- `bw/8, 18 dB`
  - `Root-MUSIC`: `0.990`
  - `5a-refined2`: `0.095`
- `bw/9, 20 dB`
  - `Root-MUSIC`: `0.990`
  - `5a-refined2`: `0.060`
- `bw/10, 22 dB`
  - `Root-MUSIC`: `1.000`
  - `5a-refined2`: `0.080`

##### 诊断判断

这轮最大的正面信息不是性能，而是**排除了一个错误方向**：

- 单纯把更新变量切回 `mu`
- 单纯把对消写成 FFT 域 Dirichlet 残差

并不会自动复现论文的 FFT-II 收益。

从诊断量看：

- `fftii_init_two_stage_cancel_rate` 虽然不再严格接近 0，但仍然很低，通常只在 `0 ~ 0.065`
- `second_peak_ratio` 长期稳定在 `0.969` 左右，说明 residual 中最强“第二峰”几乎总是紧贴主峰泄漏，而不是真正被显露出的次目标
- `single_peak_fallback` 仍然是绝对主流

这说明当前实现的核心瓶颈进一步聚焦到了：

1. **主峰泄漏模型仍不对**
   - 当前 Dirichlet 残差减法虽然形式上更接近论文，但还没有真实显露次目标
2. **第二目标初始化机制仍不对**
   - 候选扫描做了，但候选本身还是被主峰残留旁瓣主导
3. **插值公式本身不是第一瓶颈**
   - 因为在第二峰根本没有被正确显露出来之前，后续 `mu` 域细化很难救回来

##### 当前结论

`5a-refined2` 不作为升级版保留，只作为失败证据保留。

它的价值在于：

- 证明了“把实现形式表面上拉回 FFT 域”还不够；
- 当前更该重审的是论文 `(4-14) ~ (4-19)` 里的**泄漏项建模、主峰剥离方式、次峰显露机制**；
- 下一步如果继续做 `5a`，应优先针对：
  - 主峰泄漏模型
  - residual 候选峰的形成与筛选
  - 是否需要在主峰处先做更稳定的单目标插值细化后再对消

而不是继续扩大外层迭代、继续加 guard、或者直接进入 `5b`。

## Prototype 6：FBSS + Root-MUSIC 主创新

### 本次新增

新增脚本：

- [space_smooth_music_B_root_music_prototype6.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_root_music_prototype6.m)
- [doa_root_music_array.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/doa_root_music_array.m)
- [doa_root_music_beamspace.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/doa_root_music_beamspace.m)

新增结果目录：

- [results_step8_routeB_root_music_proto6](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_root_music_proto6)

### 设计动机

`proto5a-refined2` 里最稳定、最有解释力的结论，不是 `FFT-II` 本身，而是其中的 `root_music_reference`：

- `bw/7 = 14 dB`
- `bw/8 = 16 dB`
- `bw/9 = 20 dB`
- `bw/10 = 22 dB`

相对第 7.5 步稳定 Route B 的：

- `16 / 18 / 22 / 24 dB`

它在四个近间隔档位上都稳定下降了 `2 dB`。因此第 8 步主线不再继续深挖 `FFT-II`，而是把这条线正式化为 `Prototype 6`。

### 公平对照设置

本轮严格按同样本、同 seed 的公平对照执行：

- 4 条路线：
  - `baseline_routeB_centerT_grid_music`
  - `proto4e_fft_piecewise_grid_music`
  - `proto6_array_root_music`
  - `proto6_beamspace_root_music`
- 固定参数：
  - `sep_factor_list = [7, 8, 9, 10]`
  - `snr_list = 14:2:28`
  - `Metkl = 200`
  - `T_snap = 260`
  - `tol_deg = 0.1`
  - `tol_rel_ratio = 0.25`
- 随机种子规则：
  - `base_seed = 20260522`
  - `seed_now = base_seed + 100000*iSep + 1000*iSNR + metkl_num`

### 结果

`SNR90_abs01` 结果如下：

- `baseline_routeB_centerT_grid_music`
  - `bw/7 = 16 dB`
  - `bw/8 = 18 dB`
  - `bw/9 = 22 dB`
  - `bw/10 = 24 dB`
- `proto4e_fft_piecewise_grid_music`
  - `bw/7 = 18 dB`
  - `bw/8 = 18 dB`
  - `bw/9 = 22 dB`
  - `bw/10 = 24 dB`
- `proto6_array_root_music`
  - `bw/7 = 14 dB`
  - `bw/8 = 16 dB`
  - `bw/9 = 20 dB`
  - `bw/10 = 22 dB`
- `proto6_beamspace_root_music`
  - `bw/7 = 14 dB`
  - `bw/8 = 16 dB`
  - `bw/9 = 20 dB`
  - `bw/10 = 22 dB`

`SNR90_rel025` 结果如下：

- `baseline`: `16 / 18 / 22 / 24 dB`
- `proto4e`: `18 / 18 / 22 / 24 dB`
- `proto6_array`: `14 / 18 / 20 / 22 dB`
- `proto6_beamspace`: `14 / 18 / 20 / 22 dB`

门槛附近代表点也保持了与 `SNR90` 一致的趋势。例如：

- `bw/7, 14 dB`
  - baseline `tol_abs01 = 0.820`
  - proto4e `tol_abs01 = 0.570`
  - proto6_array `tol_abs01 = 0.995`
  - proto6_beam `tol_abs01 = 0.995`
- `bw/8, 16 dB`
  - baseline `tol_abs01 = 0.590`
  - proto4e `tol_abs01 = 0.530`
  - proto6_array `tol_abs01 = 0.935`
  - proto6_beam `tol_abs01 = 0.945`
- `bw/9, 18 dB`
  - baseline `tol_abs01 = 0.430`
  - proto4e `tol_abs01 = 0.440`
  - proto6_array `tol_abs01 = 0.890`
  - proto6_beam `tol_abs01 = 0.895`

### 诊断判断

1. `baseline` 与 `proto4e` 的 `SNR90_abs01` 没有漂移，说明公平对照框架和旧路线实现没有被改坏。
2. `proto6_array_root_music` 完整复现了此前 `root_music_reference` 的 `2 dB` 系统性优势。
3. `proto6_beamspace_root_music` 没有比 array 版本更差，说明：
   - `Q = conj(Tk) * (En_b * En_b') * Tk.'` 的映回写法是成立的；
   - 当前 beamspace 投影没有引入额外门槛损失。
4. 从第 8 步的证据链看，真正可靠的改进不是 FFT 中心或窗映射本身，而是：
   - `FBSS + Root-MUSIC`
   - 在相同样本条件下，相对 Route B grid-MUSIC 后端带来的稳定门槛下移

### 当前结论

`Prototype 6` 现在应作为第 8 步的主创新版本保留。

更具体地说：

- 如果目标是保留 `Route B` 的局部 beamspace 思路，`proto6_beamspace_root_music` 已经给出了与 array Root-MUSIC 持平的结果；
- 如果目标是论文里强调的“在相同数据模型和公平条件下获得更低门槛”，当前最直接、最强的结论就是：
  - 把第 7.5 步后端从 grid-MUSIC/peak-picking 换成 `Root-MUSIC`，比继续微调 `proto4e` 更有效；
- 因此后续若继续做 `Step 8`，更合理的主线应是：
  - 以 `Prototype 6` 为基线
  - 再考虑文档中提到的下一步方向，例如 Toeplitz 投影等结构化增强

## Prototype 7：Toeplitz-FBSS + Root-MUSIC 组合创新

### 本次新增

新增脚本：

- [space_smooth_music_B_toeplitz_root_music_prototype7.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/space_smooth_music_B_toeplitz_root_music_prototype7.m)
- [toeplitz_project.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/toeplitz_project.m)
- [doa_root_music_array_toeplitz.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/doa_root_music_array_toeplitz.m)
- [doa_root_music_beamspace_toeplitz.m](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/doa_root_music_beamspace_toeplitz.m)

新增结果目录：

- [results_step8_routeB_toeplitz_root_music_proto7](/E:/matlab_code/bishe_quanxi/stepwise_signal_model/steps/step_08_routeB_innovation/results_step8_routeB_toeplitz_root_music_proto7)

### 设计动机

`Prototype 6` 已经证明了 `FBSS + Root-MUSIC` 相对稳定 Route B 能系统性下移 `2 dB`。`Prototype 7` 的目标是在此基础上再叠加一次 Toeplitz 结构投影，验证两件事：

1. `SNR90` 能否在 `bw/9` 或 `bw/10` 再下移至少 1 档；
2. 即便门槛不降，`lambda2/noise_floor` 或 `RMSE` 是否能持续改善，从而作为「数值稳定性增强」保留。

动机本身是合理的：

- ULA + 时间平稳条件下，真协方差应满足 Toeplitz；
- 有限快拍与 FBSS 残留的非 Toeplitz 分量可以看作噪声扰动；
- 强制 Toeplitz 化相当于做一次额外平均。

### 实验参数

- `sep_factor_list = [7, 8, 9, 10]`
- `snr_list = 14:2:28`
- `Metkl = 200`
- `T_snap = 260`
- `base_seed = 20260523`
- 5 条路线：
  - `baseline_routeB_centerT_grid_music`
  - `proto4e_fft_piecewise_grid_music`
  - `proto6_array_root_music`
  - `proto7_toeplitz_array_root_music`
  - `proto7_toeplitz_beamspace_root_music`

### 6.7.1 公平性回归

这一关通过。

`SNR90_abs01` 回归结果为：

- baseline: `16 / 18 / 22 / 24 dB`
- proto4e: `18 / 18 / 22 / 24 dB`
- proto6_array: `14 / 16 / 20 / 22 dB`

与第六章 6.7.1 的强制回归线完全一致，说明：

- `space_smooth_music_B_toeplitz_root_music_prototype7.m` 没有改坏原有公平性框架；
- `mssp_array_fb`、噪声功率计算、`centerT` 构造、`proto4e` 与 `proto6` 的调用语义都保持正确。

### 结果

`proto7` 两条 Toeplitz 路线的主结果如下：

- `proto7_toeplitz_array_root_music`
  - `bw/7 = NaN`
  - `bw/8 = NaN`
  - `bw/9 = NaN`
  - `bw/10 = NaN`
- `proto7_toeplitz_beamspace_root_music`
  - `bw/7 = NaN`
  - `bw/8 = NaN`
  - `bw/9 = NaN`
  - `bw/10 = NaN`

这里的 `NaN` 不是“没有输出角度”，而是更糟的情况：

- `raw_success_rate` 基本为 `1.0`
- 但 `tol_success_rate_abs01` 与 `tol_success_rate_rel025` 基本为 `0`

也就是说，Toeplitz 版几乎总是给出两个有限 DOA，但这两个 DOA 在统计上系统性偏离真值。

典型样本（`bw/7`, `14 dB`）：

- 目标真值：`[12.8, 13.2]`
- `proto6_array`: `[12.7653, 13.1166]`
- `proto7_array`: `[12.9076, 13.0166]`
- `proto7_beam`: `[12.9076, 13.0166]`

可以看到 Toeplitz 版明显把两个估计角向中间拉拢，导致双目标间隔被压缩，最终整体判错。

### 诊断判断

这轮结果最值得注意的地方是：**Toeplitz 投影把诊断量抬高了，但把 DOA 结果做坏了。**

典型样本（`bw/7`, `14 dB`）中：

- `lambda2_over_noise_before_tp = 2.8732`
- `lambda2_over_noise_after_tp = 8.9531`
- `toeplitz_residual_norm = 0.0093`

这说明：

1. Toeplitz 投影确实在数值上强烈改变了 `Rss` 的谱结构；
2. 改动幅度并不大到像是数值爆炸，残差范数比只有 `0.0093`；
3. 但对 Root-MUSIC 多项式而言，这个投影把原本正确的双根结构推向了“更靠中间、更紧凑”的错误解。

因此当前失败不是：

- 公平性框架错了；
- 没有输出；
- 或者 beamspace 顺序写反了。

而是更实质的算法问题：

- **在当前 FBSS + coherent equal-amplitude + small-separation 场景下，直接对 `Rss` 做 Toeplitz 投影后再走当前 Root-MUSIC 根选取流程，会系统性压缩两目标间距。**

并且 array / beamspace Toeplitz 版一起失败，也进一步说明：

- 问题不是 beamspace 特有；
- 问题更可能来自 `Rss -> Toeplitz(Rss)` 之后，多项式根结构的物理含义已经偏离了当前这组目标场景。

### 结论

按第六章 6.7.2 的处置表，本轮明确归入 **C：失败**。

原因不是“没有改善”，而是：

- `proto7_array` 的 `SNR90` 比 `proto6` 还差，已经退化到全 `NaN`；
- `proto7_beam` 与 `proto7_array` 同步失败；
- 因此它不能作为「组合创新点」保留，也不能作为「数值稳定性增强」附加创新点保留。

### 保留建议

- **脚本保留**：作为失败原型证据保留；
- **结果保留**：因为它展示了一个重要反例：
  - `lambda2/noise` 变好并不等于 DOA 判决会更好；
  - 当前 Toeplitz 投影会把双目标间距往中间挤压，导致系统性误判；
- **当前不继续沿 proto7 深挖**：除非后续明确重审：
  - Toeplitz 投影是否该作用于别的协方差形式；
  - Root-MUSIC 的根选取规则是否需要针对 Toeplitz 后结构重写；
  - 或者是否应先做别的结构化预处理，再决定是否引入 Toeplitz。
