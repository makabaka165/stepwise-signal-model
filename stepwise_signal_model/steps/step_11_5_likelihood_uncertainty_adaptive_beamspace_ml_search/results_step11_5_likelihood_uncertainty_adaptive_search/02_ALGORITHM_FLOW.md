# Step11.5 Algorithm Flow

## Text flow

1. Build `Z = W'Y` with fixed `greedy_combined_B7`.
2. Run Step11.3 degree-based coarse grid topK search with `topK_max = 7`.
3. Compute coarse likelihood-landscape features: entropy, gaps, boundary risk, condition risk, and uncertainty `U`.
4. Select EASY/NORMAL/HARD/UNSAFE deterministic policy.
5. Retain only the prefix of the already sorted coarse top candidates.
6. Scale Step11.3 base local half-widths and clamp windows to global local-search bounds.
7. Run Step11.3 local refine from the retained topK candidates.
8. Output best ML estimate plus confidence, boundary flag, feature, policy, and candidate-count debug fields.

## Pseudocode

```text
input Z, W, array coordinates, lambda, coarse_cfg, base_refine_cfg
top_candidates, coarse_debug = Step11.3.coarse_grid_topk(topK_max=7)
features = compute_likelihood_landscape_features(top_candidates, coarse_debug)
policy = select_adaptive_topk_window_policy(features, base_refine_cfg)
selected = top_candidates[1:policy.adaptive_topK]
adaptive_refine_cfg = scale(base_refine_cfg, policy.window_scale)
est, refine_debug = Step11.3.local_refine_from_topk(selected, adaptive_refine_cfg)
return est, features, policy, coarse_debug, refine_debug, num_pairs
```

## Input fields

- `Z, W, x, y, z, lambda`: beamspace data and array geometry.
- `grid_cfg_coarse`: degree-based coarse grid with `coarse_el_sep_deg_list = [0, 0.36, 0.72]`.
- `base_refine_cfg`: Step11.3 base fine settings with `[0, 0.24, 0.36, 0.48, 0.60, 0.72]` fine elevation separations.
- `manifold_opts`, `search_opts`: same phase and regularization options used by Step11.3.
- `policy_cfg`: `topK_max = 7`, `tau = 0.02`.

## Output fields

- `est_adaptive`: `az_hat`, `el_hat`, `el_center_hat`, `el_sep_hat`, `orientation_hat`, and ML score.
- `debug_adaptive.features`: `H_norm`, `gap_13`, `gap_17`, `boundary_margin`, `boundary_risk`, `cond_risk`, `U`, top scores, softmax weights.
- `debug_adaptive.policy`: policy name, adaptive topK, scaled windows, confidence, boundary flag.
- `debug_adaptive.num_pairs_total`: coarse plus adaptive-refine candidate count.
- `debug_adaptive.failure_reason`: low-confidence failure text if all refine windows produce no candidate rows.
