# Step11.5 Stage2 Policy Tuning Theory

Stage2 keeps the Step11.3 controlled pair2d beamspace ML score unchanged:

`J(Theta) = trace(P_G(Theta) Z Z')`

The corrected theory is not a new ML backend. It is a calibration of search-budget policy.

## Stage1 failure diagnosis

`H_norm` high means the coarse top candidates have similar likelihood scores, but it does not necessarily mean fixed topK3 will fail. `cond_risk` high means the beamspace pair manifold is ill-conditioned, but it should primarily affect confidence or boundary flags rather than force wider search. Boundary risk is the main reason to expand local refine windows. Small score gap can justify larger topK, but it should not automatically enlarge windows.

## Decoupled uncertainties

`gap_risk = 1 - min(gap_13 / gap_scale, 1)`

`U_search = 0.65 gap_risk + 0.30 boundary_risk + 0.05 min(H_norm, 0.5)`

`U_confidence = 0.35 H_norm + 0.25 gap_risk + 0.25 cond_risk + 0.15 boundary_risk`

Both values are clipped to `[0, 1]`. `cond_risk` is not allowed to enter `U_search`, and entropy contributes at most 0.025 to `U_search`.

## Policy rules

- EASY: boundary free, not ill-conditioned, and `gap_13 >= easy_gap_threshold`; save compute with smaller topK/window.
- NORMAL: default fixed topK3-equivalent search.
- SCORE_AMBIGUOUS: small gap without boundary risk; increase topK only and keep window scale 1.00.
- BOUNDARY: boundary risk; allow bounded window expansion with scale at most 1.25.
- ILL_CONDITIONED: low confidence only; keep topK=3 and window scale 1.00.
