# Step11.5 Stage2 Policy Tuning Flow

1. Load fixed Step11.2 `greedy_combined_B7` and Step11.3 degree-based search helpers.
2. Build the explicit C01-C12 policy tuning config table.
3. For zero-bias representative trials, run full fine, fixed topK3, and adaptive v2 for every config.
4. Split deterministically: odd `trial_id` is calibration and even `trial_id` is validation.
5. Select the config on calibration split only. It must satisfy safety constraints and non-degenerate policy distribution.
6. Evaluate final `stage2_adaptive_pass_flag` on validation split only.
7. Run the selected config on required bias cases.
8. Write independent Stage2 CSV/MAT/PNG/Markdown outputs without overwriting Stage1 results.

## Pseudocode

```text
for each zero-bias trial:
    compute full fine baseline
    compute fixed topK3 baseline
    compute coarse top7 candidates once
    for each config C01-C12:
        compute features_v2
        select policy_v2
        run Step11.3 local refine with v2 topK/window
select config using calibration split only
compute pass/fail using validation split only
run selected config on bias cases
```
