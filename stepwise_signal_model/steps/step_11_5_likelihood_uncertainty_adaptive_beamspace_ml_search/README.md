# Step11.5 Likelihood-Uncertainty-Aware Adaptive TopK-Window Beamspace ML Search

## 1. Step11.5 目标

Step11.5 提出“基于似然地形不确定度的自适应 TopK-窗口波束级最大似然搜索方法”。它在固定 Step11.1 controlled pair2d beamspace ML 后端、固定 Step11.2 推荐 `W = greedy_combined_B7`、固定 Step11.3 degree-based coarse-to-fine 搜索框架的前提下，根据粗网格 top candidates 的 ML 分数地形自适应选择 fine refine 的 topK 数量与局部窗口尺度。

目标不是修改既有 ML 评分函数，也不是替代 Step11.3 的结论，而是在 Step11.3 fixed topK3 baseline 之上验证一种可观测、确定性的搜索预算分配增强。

## 2. 与 Step11.3 的关系

Step11.3 是 fixed topK3 coarse-to-fine：

- coarse topK 固定为 `topK = 3`。
- local refine half-width 固定为 `0.32 deg` az 与 `0.48 deg` el-center。
- fine grid step 固定为 `0.08 deg` az 与 `0.12 deg` el。
- degree-based `fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72]`。

Step11.5 是 likelihood-uncertainty-aware adaptive topK-window：

- coarse 阶段先保留 `topK_max = 7`。
- 由粗网格 ML 分数熵、top-score gap、边界距离和 `cond(G'G + reg I)` 计算综合不确定度 `U`。
- 根据 EASY/NORMAL/HARD/UNSAFE deterministic policy 选择 `adaptive_topK = 1/3/5/7` 与局部窗口尺度 `0.75/1.00/1.50/2.00`。
- 所有 policy 都真实执行 Step11.3 local refine，不使用真值筛选候选。

## 3. 固定 beamspace DML 模型

阵元域局部观测：

`Y = A_cyl(Theta) S + N`

波束域观测：

`Z = W'Y`

波束域流形：

`G(Theta) = W' A_cyl(Theta)`

投影矩阵：

`P_G(Theta) = G(Theta) [G(Theta)'G(Theta) + reg I]^(-1) G(Theta)'`

DML 评分函数：

`J(Theta) = trace(P_G(Theta) Z Z')`

其中 `Theta` 为 controlled pair2d 候选状态：

`Theta = {az1, az2, el_center, el_sep_deg, orientation}`

由 degree-based `el_sep_deg` 参数生成：

`el1 = el_center - orientation * el_sep_deg / 2`

`el2 = el_center + orientation * el_sep_deg / 2`

注意：此处 `el_sep_deg` 是物理角度分离，不是 grid index difference。

## 4. 似然地形不确定度与策略

粗搜索保留 `C_i = {Theta_i, J_i}, i=1,...,Kmax`，其中 `Kmax = 7` 且 `J_1 >= J_2 >= ... >= J_Kmax`。

稳定归一化：

`s_i = (J_i - J_1) / max(abs(J_1), eps)`

max-shift softmax：

`p_i = exp((s_i/tau) - max_k(s_k/tau)) / sum_k exp((s_k/tau) - max_k(s_k/tau))`

默认 `tau = 0.02`。

似然熵与归一化熵：

`H_J = -sum_i p_i log(p_i + eps)`

`H_norm = H_J / log(Kmax)`

top-score gap：

`gap_13 = (J_1 - J_3) / max(abs(J_1), eps)`

`gap_17 = (J_1 - J_7) / max(abs(J_1), eps)`

边界风险：

`boundary_margin = min(d_az / max(coarse_az_step, eps), d_el / max(coarse_el_step, eps))`

`boundary_risk = 1 if boundary_margin < 1.5 else 0`

条件数风险：

`kappa_G = cond(G_best'G_best + reg I)`

`cond_risk = min(log10(kappa_G) / 8, 1)`

综合不确定度：

`U = 0.45 * H_norm + 0.25 * (1 - min(gap_13 / 0.02, 1)) + 0.15 * boundary_risk + 0.15 * cond_risk`

`U` 裁剪到 `[0, 1]`。

| Policy | Trigger | adaptive_topK | window scale | confidence |
|---|---|---:|---:|---|
| EASY | `U < 0.30`, no boundary risk, `cond_risk < 0.55` | 1 | 0.75 | high |
| NORMAL | `0.30 <= U < 0.55`, no boundary risk | 3 | 1.00 | medium |
| HARD | `0.55 <= U < 0.80` or boundary risk | 5 | 1.50 | medium_low |
| UNSAFE | `U >= 0.80` or `cond_risk >= 0.85` | 7 | 2.00 | low |

## 5. 运行方式

从 `stepwise_signal_model` 根目录运行：

```matlab
run('setup_paths.m')
run('steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/run_step11_5_likelihood_uncertainty_adaptive_search.m')
```

runner 固定 `rng(20260609, 'twister')`，并自动创建 result 目录。

## 6. 输出文件

输出目录：

`steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/results_step11_5_likelihood_uncertainty_adaptive_search/`

主要文件：

- `step11_5_trial.csv`
- `step11_5_summary.csv`
- `step11_5_keypoints.csv`
- `step11_5_policy_summary.csv`
- `step11_5_bias_summary.csv`
- `step11_5_result.mat`
- `step11_5.log`
- `00_STEP11_5_ONE_PAGE_SUMMARY.md`
- `01_THEORY_AND_FORMULATION.md`
- `02_ALGORITHM_FLOW.md`
- `03_EXPERIMENT_RESULTS.md`
- `04_LIMITATIONS_AND_BOUNDARY.md`
- `05_THESIS_WRITING_TEXT.md`
- PNG figures for policy distribution, candidate count, RMSE, success, and uncertainty.

## 7. Pass/fail 判据

`adaptive_pass_flag = 1` 当且仅当：

1. `adaptive_success >= fixed_topK3_success - 1e-12`
2. `adaptive_rmse <= fixed_topK3_rmse + 1e-12`
3. `adaptive_topK_miss_rate == 0`
4. `adaptive_boundary_hit_rate == 0`
5. `adaptive_full_grid_match_rate >= 0.98`
6. `adaptive_mean_num_pairs <= 0.95 * fixed_topK3_mean_num_pairs`

如果前 5 条通过但第 6 条不通过，则 Step11.5 记录为安全但复杂度收益不足，建议 `tune_policy_thresholds_for_more_complexity_reduction`。

如果前 1-5 条任一不通过，则建议 `keep_fixed_topK3_or_add_safety_fallback`。

## 8. 约束声明

- 不修改 Step11.1 controlled pair2d beamspace ML 的评分函数定义。
- 不修改 Step11.2 最终 W 推荐，默认使用 `greedy_combined_B7`。
- 不修改 Step11.3 既有 Stage1/Stage2/Stage3/Stage4 代码和结果文件。
- 不把本方法写成 AP、full4D ML 或新的 element-domain ML。
- 不使用目标真值参与搜索中心、候选生成、topK 决策或自适应策略决策。
- 使用 degree-based `el_sep_deg_list`，不将 index-based elevation separation 作为默认实现。

## 9. 论文推荐

若 `adaptive_pass_flag = 1`，可作为 Step11.3 fixed topK3 之后的自适应搜索加速增强写入论文创新点。

若 `adaptive_pass_flag = 0` 但安全指标通过、复杂度没有提升，则默认工程配置仍建议保留 Step11.3 fixed topK3，Step11.5 作为自适应搜索策略的边界验证与未来调参方向保留。

## 10. Stage2 policy tuning

### Stage1 result summary

Stage1 已保留为：

`Step11.5 Stage1: original uncertainty policy negative result / safety passed but complexity failed`

Stage1 关键结论：

- `adaptive_success = 1`
- `adaptive_rmse = fixed_topK3_rmse = 0.0765589261214`
- `adaptive_full_grid_match_rate = 1`
- `adaptive_topK_miss_rate = 0`
- `adaptive_boundary_hit_rate = 0`
- `bias_robustness_pass_flag = 1`
- `adaptive_pass_flag = 0`
- `fixed_topK3_mean_num_pairs = 19126.26`
- `adaptive_mean_num_pairs = 38749.86`
- policy distribution: EASY=0, NORMAL=0, HARD=1, UNSAFE=0

### Stage1 failure diagnosis

Stage1 失败不是 ML 后端估计错误，也不是 adaptiveTopK 没生效，而是 policy calibration 过保守。Stage1 中 `H_norm` 在大多数样本接近 1，`gap_13` 也小于原始 `0.02` 标定尺度，导致综合不确定度 `U` 普遍大于 `0.55`，所有样本进入 HARD。HARD 同时设置 `topK=5` 和 `1.5` 倍 refine window，导致平均候选数超过 fixed topK3。

### Stage2 modified policy idea

Stage2 新增：

`Step11.5 Stage2: calibrated search-budget policy tuning`

Stage2 将 Stage1 的单一 `U` 拆成两个量：

- `U_search`: 只用于决定搜索预算 topK/window。
- `U_confidence`: 只用于决定 confidence / boundary flag。

Stage2 明确：

- `H_norm` 高说明 coarse top candidates 分数接近，但不必然意味着 fixed topK3 会失败。
- `cond_risk` 高说明 beamspace pair manifold 病态，但不直接扩大搜索窗口，只降低 confidence。
- `boundary_risk` 是扩大 refine window 的主要理由。
- score gap 小可以适度增加 topK，但不默认扩大 window。
- fixed topK3 是 NORMAL 默认策略。
- SCORE_AMBIGUOUS 只增加 topK，不扩大 window。
- BOUNDARY 才扩窗口，并限制 `boundary_window_scale <= 1.25`。
- ILL_CONDITIONED 输出低置信，但不默认 topK=7 或 window=2.0。

### Stage2 runner

从 `stepwise_signal_model` 根目录运行：

```matlab
run('setup_paths.m')
run('steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/run_step11_5_stage2_policy_tuning.m')
```

### Stage2 result directory

Stage2 独立输出目录：

`steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/results_step11_5_stage2_policy_tuning/`

该目录不会覆盖 Stage1 的 `results_step11_5_likelihood_uncertainty_adaptive_search/`。

### Stage2 selected recommendation

Stage2 runner 会生成显式 C01-C12 policy 配置表，在 zero-bias trials 上使用 deterministic split：

- calibration split: `mod(trial_id, 2) == 1`
- validation split: `mod(trial_id, 2) == 0`

配置只在 calibration split 上选择；最终 pass/fail 只看 validation split。

### Stage2 pass/fail conclusion

Stage2 通过条件是 selected config 在 validation split 上同时满足：

1. `adaptive_success >= fixed_topK3_success - 1e-12`
2. `adaptive_rmse <= fixed_topK3_rmse + 1e-12`
3. `adaptive_topK_miss_rate == 0`
4. `adaptive_boundary_hit_rate == 0`
5. `adaptive_full_grid_match_rate >= 0.98`
6. `adaptive_mean_num_pairs <= 0.95 * fixed_topK3_mean_num_pairs`
7. `policy_degeneracy_flag == 0`

若 Stage2 仍未在 validation split 上证明复杂度优势，则最终默认工程配置继续保留 Step11.3 fixed topK3，Step11.5 Stage2 作为自适应搜索策略的负结果和未来扩展依据。

## 11. Stage3 required enhancement validation

Stage3 is an enhancement validation of the existing Step11.5 Stage2 positive result.
It is not Step11.6, not a new algorithm, and not a repeated C01-C12 tuning scan.
Stage3 fixes the Stage2 selected policy:

`selected_config_name = C05_easy_very_aggressive`

The preserved Stage2 conclusion is:

- `stage2_adaptive_pass_flag = 1`
- `recommended_next_step = use_step11_5_stage2_as_positive_adaptive_enhancement`
- validation fixed/adaptive success = `1 / 1`
- validation fixed/adaptive RMSE = `0.0743030112986 / 0.0527528990405`
- validation fixed/adaptive mean pairs = `18558 / 13242.6`
- validation pair count ratio = `0.713579049467`
- adaptive full-grid match rate = `1`
- adaptive topK miss rate = `0`
- adaptive boundary hit rate = `0`
- validation policy degeneracy flag = `0`
- Stage2 selected pair count ratio = `0.715969413251`
- Stage2 +/-0.20 deg bias robustness pass flag = `1`

Stage3 adds three required rechecks:

1. Alternative split recheck: C05 is rerun under non odd/even validation splits.
2. Larger Metkl / repeat-seed recheck: C05 is rerun with `Metkl=20` and three deterministic seed groups.
3. Targeted branch recheck: BOUNDARY and ILL_CONDITIONED v2 policy branches are exercised and checked for non-high-confidence safety output.

Run from the `stepwise_signal_model` root:

```matlab
run('setup_paths.m')
run('steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/run_step11_5_stage3_required_enhancement_validation.m')
```

Stage3 writes an independent result directory:

`steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/results_step11_5_stage3_required_enhancement_validation/`

Main Stage3 output files:

- `step11_5_stage3_alt_split_trial.csv`
- `step11_5_stage3_alt_split_summary.csv`
- `step11_5_stage3_repeat_seed_metkl_trial.csv`
- `step11_5_stage3_repeat_seed_metkl_summary.csv`
- `step11_5_stage3_targeted_branch_trial.csv`
- `step11_5_stage3_targeted_branch_summary.csv`
- `step11_5_stage3_keypoints.csv`
- `step11_5_stage3_selected_c05_config.csv`
- `step11_5_stage3_stage2_reference.csv`
- `step11_5_stage3_result.mat`
- `step11_5_stage3.log`
- Stage3 Markdown summaries and PNG figures.

## 12. Stage3 supplementary rechecks

Stage3 supplementary rechecks add two focused validations after the Stage3 required enhancement pass. This stage is not Step11.6, does not rerun Stage2 tuning, and does not change C05 parameters.

The fixed policy remains:

`selected_config_name = C05_easy_very_aggressive`

### Why Metkl=30 is added

Stage3 required validation used a larger repeat-seed check with `Metkl=20`. The supplementary Metkl=30 recheck increases the representative scenario sample count to verify that C05 keeps fixed topK3 safety and candidate-count advantage under a larger multi-seed trial set.

### Why stronger ill-conditioned real-search stress is added

Stage3 required validation showed BOUNDARY real-search triggering, while ILL_CONDITIONED was validated by deterministic guard probe but did not naturally trigger in the real-search stress case. The supplementary stress set uses close same-elevation coherent pairs, anti-phase close pairs, weak secondary close pairs, and lower-SNR close pairs to test whether the fixed C05 `cond_threshold = 0.85` can be crossed naturally without forcing policy labels.

Run from the `stepwise_signal_model` root:

```matlab
run('setup_paths.m')
run('steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/run_step11_5_stage3_supplementary_rechecks.m')
```

Supplementary results are written to:

`steps/step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search/results_step11_5_stage3_supplementary_rechecks/`

Pass/fail interpretation:

- `metkl30_repeat_pass_flag = 1` means every seed group and the overall Metkl=30 set preserve safety, full-grid agreement, non-degenerate policy distribution, and candidate-count reduction.
- `illcond_real_stress_pass_flag = 1` means ILL_CONDITIONED naturally triggers in real-search stress, has no high-confidence misuse, and keeps overall stress pair-count ratio within the required bound.
- If real-search ILL_CONDITIONED does not trigger but `illcond_guard_probe_pass_flag = 1`, the result must be written as a boundary/partial result: the guard probe validates policy logic, but the thesis must not claim real-search triggering.

Main supplementary output files:

- `step11_5_stage3_supp_metkl30_repeat_trial.csv`
- `step11_5_stage3_supp_metkl30_repeat_summary.csv`
- `step11_5_stage3_supp_illcond_real_stress_trial.csv`
- `step11_5_stage3_supp_illcond_real_stress_summary.csv`
- `step11_5_stage3_supp_keypoints.csv`
- `step11_5_stage3_supp_final_recommendation.csv`
- `step11_5_stage3_supp_result.mat`
- `step11_5_stage3_supp.log`
- Stage3 supplementary PNG figures and Markdown summaries.
