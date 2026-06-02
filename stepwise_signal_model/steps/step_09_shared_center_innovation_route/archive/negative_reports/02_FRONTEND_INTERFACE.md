# 前端接口

## frontend_out 字段

主线只要求前端提供以下字段：

| 字段 | 含义 |
|---|---|
| `rangeIdx` | RD 检测单元的距离索引 |
| `dopplerIdx` | RD 检测单元的多普勒索引 |
| `coarseAz` | 前端粗方位，单位 deg |
| `coarseEl` | 前端粗俯仰，单位 deg |
| `frontend_state` | 前端状态机输出 |

可选诊断字段包括 `unresolved_cluster_flag`、`need_2d_refinement`、`boundary_unreliable_flag`。这些字段不改变主线接口，只帮助工程状态机更早拒判。

## frontend_state 状态机

| frontend_state | 处理方式 |
|---|---|
| `single_peak_in_scope` | 进入 shared-center 主线 |
| `two_close_peaks_merge_candidate` | 暂不作为默认高置信输出，可转人工/未来验证 |
| `two_separated_peaks_out_of_scope` | out-of-scope，不进入当前主线 |
| `weak_secondary_low_confidence` | low-confidence，不强行求弱目标 |
| `near_antiphase_boundary` | boundary_unreliable |

## single_peak_in_scope 如何进入主线

`single_peak_in_scope` 表示前端没有稳定分开两个粗峰，且目标能落入一个 shared-center 局部工作子阵。主线用 `coarseAz` 吸附最近物理阵元列，构造 65 x 32 x Np 的 `Y_work`，再进行局部 MUSIC / fallback / 拒判。

## two separated peaks 为什么 out-of-scope

two separated coarse peaks 已经是前端多粗峰问题。当前创新点不是多粗峰融合，而是局部未分辨簇增强测角，因此该状态应交给未来 dual-center 或多前端分支。

## weak secondary 为什么 low-confidence

弱次峰可能来自旁瓣、噪声、相干相消或真实弱目标。当前路线不承诺弱目标高置信求解，只保守输出 low-confidence，避免 false-high。

## Y_work 为什么默认 no_derotation

Step 8.8B 的验证显示 `no_derotation`、`derotation_minus`、`derotation_plus` 在当前验证中 success、false-high、boundary-missed、route agreement 和估计值一致。因此默认 `derotation_mode = none`，de-rotation 仅保留为工程可选字段。
