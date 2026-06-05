Stage3 B-budget strategy tradeoff plan
======================================

Positioning
-----------

Stage3 is not a new W design method and not a new ML backend. It extends the
Stage1/Stage2 evidence by sweeping the beam budget B and asking the engineering
question: how many beamspace channels are enough for the fixed Step11.1
controlled pair2d beamspace ML backend?

Stage3 does not run AP, full4D, model selection, confidence boundaries, or
element-domain ML. The data and backend remain:

```text
Z = W' * Y
G = W' * A_cyl
```

Why Stage3 is needed
--------------------

Stage2 showed that:

- `greedy_lowcorr_B25` is the current best backend W candidate;
- `greedy_projection` is the best B15 method;
- worst-case success remains zero.

Stage3 therefore sweeps B to decide whether B25 is truly needed, whether
B15/B19/B21 can be close enough, and whether strategy preference changes from
small B to large B.

Strategy axes
-------------

Information retention:

- lower `projection_loss` is better;
- higher `projected_energy_ratio` is better;
- represented by `greedy_projection` and the non-engineering `svd_upper_bound`.

Pair separability:

- lower beamspace manifold `max_corr` is better;
- represented by `greedy_lowcorr`.

Balanced design:

- combines projection loss, max correlation, and condition penalty;
- represented by `greedy_combined`.

Backend performance:

- `joint_success_rate`, RMSE, and `worst_case_success`;
- this is the primary recommendation basis.

Important interpretation
------------------------

Projection loss being smallest does not guarantee the highest pair2d ML
success rate. SVD is an information-retention upper bound, not necessarily a
pair2d backend performance upper bound. Greedy low-correlation designs can help
the backend but may sacrifice projection information. Greedy combined is a
candidate compromise, and Stage3 decides whether it is robust across B.

Recommendation outputs
----------------------

Stage3 reports:

- `min_B_for_information_retention`
- `min_B_for_low_correlation`
- `min_B_for_backend_performance`
- `recommended_engineering_B`
- `recommended_high_performance_B`
- `recommended_W_strategy`
- `recommended_fallback_strategy`

