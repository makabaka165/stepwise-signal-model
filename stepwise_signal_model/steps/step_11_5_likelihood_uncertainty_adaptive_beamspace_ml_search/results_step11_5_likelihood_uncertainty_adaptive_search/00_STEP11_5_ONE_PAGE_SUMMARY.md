# Step11.5 One-Page Summary

## Method name
中文：基于似然地形不确定度的自适应 TopK-窗口波束级最大似然搜索方法

English: Likelihood-Uncertainty-Aware Adaptive TopK-Window Beamspace ML Search

## Positioning
Step11.5 fixes the Step11.1 controlled pair2d beamspace DML score, fixes the Step11.2 greedy_combined_B7 beam matrix, and wraps the Step11.3 degree-based coarse-to-fine search with an uncertainty-aware adaptive topK/window budget allocator.

## Algorithm inputs
- Beamspace data: `Z = W'Y`.
- Step11.3 coarse candidates from degree-based `el_sep_deg_list`.
- Coarse likelihood scores, top-score gaps, boundary margin, and `cond(G'G + reg I)`.
- Base Step11.3 refine settings: `topK=3`, local window `[0.32, 0.48] deg`, fine steps `[0.08, 0.12] deg`.

## Adaptive policy table
| Policy | Condition | adaptive_topK | window scale | confidence |
|---|---:|---:|---:|---|
| EASY | `U < 0.30`, no boundary risk, `cond_risk < 0.55` | 1 | 0.75 | high |
| NORMAL | `0.30 <= U < 0.55`, no boundary risk | 3 | 1.00 | medium |
| HARD | `0.55 <= U < 0.80` or boundary risk | 5 | 1.50 | medium_low |
| UNSAFE | `U >= 0.80` or `cond_risk >= 0.85` | 7 | 2.00 | low |

## Key metrics
- full_fine_success = 1
- fixed_topK3_success = 1
- adaptive_success = 1
- full_fine_rmse = 0.0765589261214
- fixed_topK3_rmse = 0.0765589261214
- adaptive_rmse = 0.0765589261214
- full_fine_mean_num_pairs = 131461
- fixed_topK3_mean_num_pairs = 19126.26
- adaptive_mean_num_pairs = 38749.86
- adaptive_full_grid_match_rate = 1
- adaptive_topK_miss_rate = 0
- adaptive_boundary_hit_rate = 0

## Pass/fail conclusion
- adaptive_pass_flag = 0
- recommended_next_step = `tune_policy_thresholds_for_more_complexity_reduction`

## Usage boundary
Low confidence and boundary flags are safety outputs, not new ML scores. Samples outside the verified bias range should enlarge the local window or fall back to fixed topK3/full fine search.
