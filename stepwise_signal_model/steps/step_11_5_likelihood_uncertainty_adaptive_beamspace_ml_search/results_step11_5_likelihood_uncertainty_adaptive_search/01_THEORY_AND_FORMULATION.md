# Step11.5 Theory And Formulation

## Fixed beamspace DML model

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

`el_sep_deg` 是物理角度分离，不是 grid index difference。Step11.5 不修改上述 ML score。

## Coarse likelihood-landscape uncertainty

粗搜索阶段先使用 `topK_max = 7` 运行 Step11.3 degree-based coarse grid ML scoring，保留 top 7 coarse candidates:

`C_i = {Theta_i, J_i}, i = 1,...,Kmax`, where `J_1 >= J_2 >= ... >= J_Kmax`.

稳定归一化：

`s_i = (J_i - J_1) / max(abs(J_1), eps)`

max-shift softmax likelihood weights:

`p_i = exp((s_i/tau) - max_k(s_k/tau)) / sum_k exp((s_k/tau) - max_k(s_k/tau))`

默认 `tau = 0.02`。

似然熵：

`H_J = -sum_i p_i log(p_i + eps)`

归一化熵：

`H_norm = H_J / log(Kmax)`

top-score gap:

`gap_13 = (J_1 - J_3) / max(abs(J_1), eps)`

`gap_17 = (J_1 - J_7) / max(abs(J_1), eps)`

边界距离：

`d_az = min(az1-az_min, az_max-az1, az2-az_min, az_max-az2)`

`d_el = min(el_center-el_min, el_max-el_center)`

`boundary_margin = min(d_az / max(coarse_az_step, eps), d_el / max(coarse_el_step, eps))`

`boundary_risk = 1 if boundary_margin < 1.5 else 0`

条件数风险：

`kappa_G = cond(G_best'G_best + reg I)`

`cond_risk = min(log10(kappa_G) / 8, 1)`

综合不确定度：

`U = 0.45 H_norm + 0.25 (1 - min(gap_13 / 0.02, 1)) + 0.15 boundary_risk + 0.15 cond_risk`

`U` is clipped to `[0, 1]`.

## Policy mapping

- EASY: `U < 0.30`, `boundary_risk == 0`, `cond_risk < 0.55`; use `adaptive_topK = 1`, scale `0.75`, confidence high.
- NORMAL: `0.30 <= U < 0.55`, `boundary_risk == 0`; use `adaptive_topK = 3`, scale `1.00`, confidence medium.
- HARD: `0.55 <= U < 0.80` or `boundary_risk == 1`; use `adaptive_topK = 5`, scale `1.50`, confidence medium_low.
- UNSAFE: `U >= 0.80` or `cond_risk >= 0.85`; use `adaptive_topK = 7`, scale `2.00`, confidence low and boundary flag `search_uncertain_or_ill_conditioned`.

All policies still execute fine refine with the same Step11.3 controlled pair2d beamspace DML scoring function.
