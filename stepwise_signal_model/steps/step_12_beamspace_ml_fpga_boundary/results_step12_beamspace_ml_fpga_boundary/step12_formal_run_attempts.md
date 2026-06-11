# Step12 Formal Run Attempts

## 2026-06-11

- `pilot_tps10` command was attempted with `STEP12_FORMAL_TRIALS_PER_SCENARIO=10`, `STEP12_FORMAL_CENTER_AZ_LIST=0,4,8,15`, `STEP12_MIN_FORMAL_OBS=100`, and `STEP12_RUN_TAG=pilot_tps10`.
- The interactive command timed out before producing result CSV/MAT artifacts, so no `pilot_tps10` pass/fail conclusion is recorded.
- `formal_tps30` was not run in this commit.
- `pilot_min_fast_path` was run as a smaller formal-path smoke run to verify formal fields, mode selection, score gap bins, storage/bandwidth tables, plots, light MAT, and documentation output.
- `pilot_min_fast_path` is not a formal validation conclusion because `formal_trial_count=12 < STEP12_MIN_FORMAL_OBS=100`.
