# Final Step11.3 one-page summary

## Method name

Degree-based coarse-to-fine controlled pair2d beamspace ML search acceleration

中文建议：基于物理俯仰分离参数的波束级 ML 粗到细搜索加速方法。

## One-sentence position

在固定 W=greedy_combined_B7 和 controlled pair2d beamspace ML 后端下，用 coarse topK + local refine 降低角度候选评分数。

## Final recommended configuration

- topK = 3
- coarse_az_step = 0.16 deg
- coarse_el_step = 0.24 deg
- fine_az_step = 0.08 deg
- fine_el_step = 0.12 deg
- coarse_el_sep = [0,0.36,0.72]
- fine_el_sep = [0,0.24,0.36,0.48,0.6,0.72]
- W = greedy_combined_B7

## Key results

- full_fine_success = 1
- coarse_to_fine_success = 1
- full_grid_match_rate = 1
- topK_miss_rate = 0
- complexity_reduction_ratio = 6.86054096932
- frontend_prior_robustness_pass_flag = 1

## Boundary statement

The evidence is limited to the current representative scenarios, current W, and current controlled pair2d model. It does not claim AP, global full-space search, complete engineering closure, or that every strong-coherence boundary case is solved.

Final recommendation: `use_degree_based_coarse_to_fine_topK3_for_controlled_pair2d_beamspace_ml`.

## Missing source files

None.
