# Goal Context: Step11.4 Engineering Frontend-Backend Chain

## Active Goal

Create `steps/step_11_4_engineering_frontend_backend_chain/` and validate an
interface-level frontend-to-backend chain:

frontend coarse beam scan -> `frontend_out` -> `backend_in` ->
`W = greedy_combined_B7` -> `Z = W'Y` -> controlled pair2d beamspace ML ->
degree-based coarse-to-fine search -> local unresolved-pair enhanced angle
output.

## Directory Scope

- Step directory: `steps/step_11_4_engineering_frontend_backend_chain/`
- Goal directory: `steps/step_11_4_engineering_frontend_backend_chain/goal-1/`
- Goal files: `input.md`, `plan.md`, `tasks.md`, `context.md`, `records.md`,
  `task_reports/`

## Hard Boundaries

- Do not modify Step11.1, Step11.2, Step11.3, Step9, Step10, or
  `step_11_supersolution_ml`.
- Do not use truth values to construct frontend coarse centers.
- Do not claim frontend single peak means physical single target.
- Do not claim complete automatic target-count/model selection or full
  engineering closure.
- Do not implement AP, full4D, or element-domain ML as the main result.
- If chaining fails, report `failure_reason` and modular diagnostics.

## Existing Algorithm Context

- Step11.1 validated controlled pair2d beamspace ML backend.
- Step11.2 recommended `W = greedy_combined_B7`.
- Step11.3 recommended degree-based coarse-to-fine search with `topK = 3`,
  coarse steps `0.16 deg / 0.24 deg`, fine steps `0.08 deg / 0.12 deg`, and
  `complexity_reduction_ratio = 6.86054096932`.
- Step11.3 frontend-prior robustness passed for approximately
  `az_bias=[-0.20,0.20]`, `el_bias=[-0.20,0.20]`.

## Reusable Read-Only Dependencies

- Step11.3 `build_recommended_w_from_step11_2.m` reconstructs
  `greedy_combined_B7`.
- Step11.3 `search_pair2d_coarse_to_fine.m` runs the degree-based coarse/fine
  backend.
- Step11.1 common functions provide cylindrical steering, snapshots, and pair
  metrics.
- Step11.2 common functions provide the existing two-dimensional beam pool and
  W-selection helpers.

## Prompt Integrity Note

The pasted prompt is preserved verbatim in `input.md`. The attachment ends at
the `tasks.md` report template and does not provide standalone `context.md` or
`records.md` sections. These files are initialized from the supplied goal and
`plan.md` content.

## Current Execution State

- Task 01: completed, decision GO, committed as `f9df5f4`.
- Task 02: completed, decision GO, committed as `dfd63ad`.
- Task 03: completed, decision GO, committed as `a183eda`.
- Review A: completed, decision GO, committed as `c8562c8`.
- Task 04: completed, decision CONTINUE_WITH_RISK.
- Stage2 risk: best frontend method is `centroid_top9`, but
  `frontend_coarse_angle_pass_flag = 0`, `best_within_pm02deg_rate = 0.6`,
  `best_az_rmse_deg = 0.340822201375`, and `best_el_rmse_deg = 0.114006308123`.
- Risk concentration: `weak_secondary` and `low_snr_hard` cases show azimuth
  coarse-center bias around 0.53 deg for centroid methods; easy/strong/hard
  non-weak cases pass the +/-0.2 deg check.
- Next task: Task 05, validate whether this synthetic frontend prior still
  allows the backend chain to approach oracle backend performance.
