Stage4 recommended W robustness confirmation plan
================================================

Positioning
-----------

Stage4 confirms the Stage3 recommendation `greedy_combined_B7` with a higher
Monte Carlo count. It does not introduce a new W strategy, a new backend, AP,
full4D, model selection, or element-domain ML.

The backend remains the Step11.1 controlled pair2d beamspace ML route:

```text
Z = W' * Y
G = W' * A_cyl
```

Compared W cases
----------------

Stage4 only compares the key cases needed to validate the Stage3 recommendation:

- `regular_B7`
- `greedy_combined_B7`
- `greedy_combined_B9`
- `greedy_combined_B15`
- `greedy_combined_B25`
- `greedy_lowcorr_B25`

Validation scenarios
--------------------

The five representative Stage3 scenarios are reused:

- `easy_noncoherent`
- `strong_coherent`
- `hard_phase`
- `weak_secondary`
- `low_snr_hard`

Monte Carlo settings
--------------------

- `Metkl = 30`
- `L = 64`
- `base_seed = 20260623`

Pass rule
---------

`greedy_combined_B7` is confirmed if all conditions hold:

- B7 success is at least 95% of the best overall success;
- B7 combined RMSE is at most 105% of the best overall RMSE;
- B7 worst-case success is no more than 0.1 below the best worst-case success.

If the rule passes, the final recommendation is:

- `recommended_final_W = greedy_combined`
- `recommended_final_B = 7`
- `recommended_next_step = finalize_step11_2_w_design_evidence_summary`

If it does not pass, Stage4 chooses the smallest B satisfying the same
near-best criteria. If no such B exists, it recommends the best overall method.

Interpretation guardrails
-------------------------

Stage4 can confirm `greedy_combined_B7` only for the current candidate pool,
representative scenarios, and fixed pair2d backend. It should not be written as
a universal optimum or as proof that W selection solves every worst-case
coherent/weak-target boundary.

