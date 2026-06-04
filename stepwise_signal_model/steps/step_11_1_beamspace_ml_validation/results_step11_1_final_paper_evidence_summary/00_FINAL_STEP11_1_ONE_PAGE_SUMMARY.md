# Final Step11.1 One-Page Summary

## Method Name

Beam-level controlled-parameter maximum likelihood estimation for local unresolved two-target cylindrical-array scenes.

Chinese thesis wording: 面向圆柱阵局部未分辨双目标的波束级受控参数最大似然估计方法。

## One-Sentence Positioning

Use the real cylindrical-array 3D manifold to build a low-dimensional beamspace manifold, then run controlled two-target DML search directly in beamspace.

## Final Main Algorithm

- Main route: controlled pair2d beamspace ML.
- Baseline: common-el restricted beamspace ML.
- Upper bound: local full4d beamspace ML.
- Not AP and not an engineering confidence-boundary closure.

## Stage Evidence

| stage | key_pass_flag | pass_flag_value | conclusion | limitation |
| --- | --- | --- | --- | --- |
| Stage1 ULA prior ablation | prior_dependency_flag | 0 | ULA beamspace ML is not obviously dependent on the left/right partition prior. | ULA-only ablation; not a cylindrical-array final result. |
| Stage2 cylindrical az-only beamspace ML | cyl_azonly_pass_flag | 1 | Cylindrical fixed-el az-only beamspace ML passes. | Az-only with fixed el0; not a complete 2D pair estimator. |
| Stage3 cylindrical common-el 2D beamspace ML | cyl_common_el_2d_pass_flag | 1 | Common-el 2D beamspace ML passes as a baseline route. | Shared-elevation assumption limits separated-elevation cases. |
| Stage4 controlled el-separated pair2d beamspace ML | cyl_el_separation_pass_flag | 1 | Controlled pair2d improves separated-elevation cases over common-el. | Controlled pair2d is not full unconstrained 4D. |
| Stage5 coherence stress | coherence_stress_pass_flag | 1 | Coherence stress passes in aggregate and exposes boundary cases. | Strong-coherence worst cases still exist; confidence boundary is not complete. |
| Stage6 full4d upper-bound comparison | full4d_pass_flag | 1 | Full4d is an upper-bound comparison; controlled pair2d remains sufficient in tested cases. | Full4d has higher complexity and is not the default main algorithm. |

## Key Metrics

| stage | metric | metric_value | metric_text |
| --- | --- | --- | --- |
| Stage1 ULA prior ablation | prior_dependency_flag | 0 |  |
| Stage2 cylindrical az-only beamspace ML | cyl_azonly_pass_flag | 1 |  |
| Stage3 cylindrical common-el 2D beamspace ML | cyl_common_el_2d_pass_flag | 1 |  |
| Stage4 controlled el-separated pair2d beamspace ML | cyl_el_separation_pass_flag | 1 |  |
| Stage4 controlled el-separated pair2d beamspace ML | best_sep_joint_success_bias0_snr30 | 1 |  |
| Stage4 controlled el-separated pair2d beamspace ML | sep_minus_common_joint_success_gap_bias0_snr30 | 1 |  |
| Stage5 coherence stress | coherence_stress_pass_flag | 1 |  |
| Stage5 coherence stress | pass_rate_moderate_coherence | 0.993055555556 |  |
| Stage5 coherence stress | pass_rate_strong_coherence | 0.951388888889 |  |
| Stage5 coherence stress | worst_case_joint_success_pair2d_white | 0 |  |
| Stage5 coherence stress | max_false_high_like_rate | 1 |  |
| Stage6 full4d upper-bound comparison | full4d_pass_flag | 1 |  |
| Stage6 full4d upper-bound comparison | best_full4d_joint_success | 1 |  |
| Stage6 full4d upper-bound comparison | best_pair2d_joint_success | 1 |  |
| Stage6 full4d upper-bound comparison | full4d_minus_pair2d_success_gap | 0 |  |
| Stage6 full4d upper-bound comparison | complexity_ratio_full4d_over_pair2d | 3.95890410959 |  |
| Stage6 full4d upper-bound comparison | full4d_recommended_role | NaN | upper_bound_only_pair2d_is_sufficient |

## Final Recommendation

use_controlled_pair2d_beamspace_ml_as_main_thesis_route_with_full4d_upper_bound

## Boundary Statement

Stage5 reports worst-case joint success equal to 0 and max false-high-like risk equal to 1. These results must stay visible: the route is suitable as a thesis main ML route with boundary documentation, not as a claim that every strong-coherence case is solved.