# Goal Records: Step11.4 Continuous Gated Engineering Chain

## Record Format

Each task records expected result, actual result, alignment, cause analysis,
checks, risks, decision, and commit reference.

## Task 01: Goal Initialization

### Expected Result

Create `steps/step_11_4_engineering_frontend_backend_chain/goal-1/` with
`input.md`, `plan.md`, `tasks.md`, `context.md`, `records.md`, and
`task_reports/`. Preserve the full raw prompt in `input.md`. Do not modify
existing Step11.1/11.2/11.3/Step9/Step10/step_11_supersolution_ml or add
algorithm code before the goal files exist.

### Actual Result

Created the Step11.4 directory and `goal-1` management directory. Copied the
pasted prompt byte-for-byte to `input.md`. Extracted `plan.md` from the
provided markers. Initialized `tasks.md` from the provided tasks section and
appended an actionable task list derived from the supplied Stage1-4 plan
because the pasted prompt ended before `END tasks.md`. Initialized
`context.md` and `records.md` from the supplied goal/plan content because
standalone `BEGIN context.md` and `BEGIN records.md` sections were not present.

### Alignment

Aligned with the directory and preservation requirements. The only deviation is
recovery from an incomplete pasted `tasks.md` section and missing standalone
`context.md`/`records.md` sections. This is explicitly documented and does not
change the preserved raw input.

### Cause Analysis

The source attachment has 660 lines and ends at `## Git Commit` inside the task
report template. It contains `BEGIN plan.md`/`END plan.md` and `BEGIN tasks.md`,
but no `END tasks.md`, `BEGIN context.md`, or `BEGIN records.md` markers.

### Checks

- Step11.4 directory exists.
- `goal-1` directory exists.
- `task_reports/` directory exists.
- `input.md` byte content matches the pasted attachment.
- `plan.md`, `tasks.md`, `context.md`, and `records.md` exist.
- Existing protected Step directories were not modified.

### Risks

The explicit tasks/context/records sections were not fully present in the
pasted prompt. Risk is low for Task2 continuation because `plan.md` includes
the Stage1-4 implementation scope and pass criteria.

### Decision

GO

### Git Commit

`f9df5f4`

## Task 02: Step11.4 Skeleton and Positioning

### Expected Result

Create Step11.4 README/docs and implementation skeleton directories without
modifying protected prior steps. Record reusable Step11.1/11.2/11.3 interfaces
as read-only dependencies.

### Actual Result

Created Step11.4 README, positioning/interface/stage plan documents, empty
tracked `common/`, stage, and result directories. Fixed Task1 management-doc
control-character damage caused by PowerShell backtick interpolation; the raw
`input.md` was already byte-preserved and was not changed.

### Alignment

Aligned with the Task2 scope. No algorithm code was added in this task, and no
protected dependency was modified.

### Cause Analysis

The skeleton follows the structure proposed in `plan.md`. The management-doc
fix was needed because Task1 used a double-quoted PowerShell here-string where
Markdown backticks were interpreted as escape prefixes.

### Checks

- Step11.4 README exists.
- Docs `00` through `06` exist.
- `common/`, stage directories, and result directories exist and are tracked.
- `context.md` and `records.md` no longer contain the observed control-character
  corruption.
- Protected prior steps remain untouched.

### Risks

Task2 adds only documentation and skeleton directories, so runtime risk is low.
The next real risk appears in Task3 when interface structs become executable
MATLAB code.

### Decision

GO

### Git Commit

`dfd63ad`

## Task 03: Stage1 Interface Contract

### Expected Result

Implement and run Stage1 interface-contract code for `frontend_out` and
`backend_in`. Generate CSV, MAT, log, keypoints, and README status artifacts.
Pass criteria are `frontend_out_fields_ok = 1`, `backend_in_fields_ok = 1`, and
`interface_contract_pass_flag = 1`.

### Actual Result

Implemented `make_frontend_out_struct.m`,
`build_step11_backend_config_from_frontend.m`,
`make_backend_in_from_frontend_out.m`, `append_log_local.m`, and
`stage1_interface_contract/run_stage1_interface_contract.m`. Ran MATLAB R2022b
successfully. Stage1 wrote summary/keypoints/MAT/log/README artifacts.

### Alignment

Aligned with Stage1 scope. The script checks interface fields, `Y/W/Z`
dimensions, coarse-center handoff, truth-guard policy, and Step11.3 recommended
search values. It does not run pair2d search or claim measurement performance.

### Cause Analysis

Stage1 passes because the frontend and backend contract fields are explicit,
the backend config is derived from the observable frontend coarse center, and
the recommended Step11.3 search constants are preserved in the generated
backend config.

### Checks

- MATLAB command: `matlab -batch "run('.../run_stage1_interface_contract.m')"`
- `frontend_out_fields_ok = 1`
- `backend_in_fields_ok = 1`
- `backend_dimension_ok = 1`
- `coarse_center_alignment_ok = 1`
- `truth_guard_ok = 1`
- `search_cfg_fields_ok = 1`
- `recommended_search_values_ok = 1`
- `interface_contract_pass_flag = 1`

### Risks

Task3 validates structure and handoff only. It does not yet prove frontend
coarse-angle accuracy or backend chain performance; those remain for Stage2 and
Stage3.

### Decision

GO

### Git Commit

`a183eda`

## Review A: Broad Review After Tasks 01-03

### Expected Result

Run the required broad review/debug gate after Tasks 01-03. Check protected
scope, truth leakage, frontend/backend layer wording, result completeness,
reproducibility evidence, and git rollback safety before continuing to Task4.

### Actual Result

Review A passed. The last three commits modify only
`steps/step_11_4_engineering_frontend_backend_chain/`. Stage1 keypoints show
all contract pass flags equal to 1. `input.md` remains byte-for-byte identical
to the pasted attachment. The code carries truth only as `truth_for_metrics`
metadata and builds backend search config from `frontend_out.coarse_*` fields.
Docs explicitly deny complete automatic target-count selection and full
engineering closure.

### Alignment

Aligned with the review gate. No protected prior step was modified, no truth
value is used to construct frontend coarse center, and Stage1 does not claim
backend performance.

### Cause Analysis

The initial Step11.4 scope is isolated in its own directory and Stage1 is a
contract test only. The pass result is therefore sufficient to continue into
Stage2, where actual frontend coarse-angle quality becomes testable.

### Checks

- `git status --short` was clean before review report edits.
- `git diff --name-only HEAD~3..HEAD` listed only Step11.4 paths.
- `input.md` byte match: true, 20022 bytes.
- Stage1 `interface_contract_pass_flag = 1`.
- Stage1 `truth_guard_ok = 1`.
- Stage1 `recommended_search_values_ok = 1`.
- `rg` review found truth references only in metrics/guard paths.
- wording review found only boundary statements, not positive overclaims.
- rollback points: `f9df5f4`, `dfd63ad`, `a183eda`.

### Risks

Review A does not validate Stage2 coarse-angle accuracy. That remains the next
required risk gate.

### Decision

GO

### Git Commit

`c8562c8`

## Task 04: Stage2 Synthetic Frontend Coarse Angle

### Expected Result

Implement and run a synthetic frontend two-dimensional beam scan and estimate
coarse az/el without using truth to construct the coarse center. Produce CSV,
MAT, log, keypoints, README, and PNG artifacts. Report whether the coarse angle
is accurate enough to serve as a Step11 backend prior.

### Actual Result

Implemented `build_frontend_beam_pool_from_existing_layout.m`,
`run_synthetic_frontend_beam_scan.m`,
`estimate_coarse_angle_from_frontend_beams.m`,
`compute_frontend_cluster_indicators.m`, and
`stage2_synthetic_frontend_coarse_angle/run_stage2_synthetic_frontend_coarse_angle.m`.
MATLAB R2022b ran successfully and generated Stage2 artifacts. The best method
was `centroid_top9`, but the pass flag was 0.

### Alignment

The implementation aligns with the no-truth-center rule. Truth is carried only
for offline error metrics, and `used_truth_for_center_rate = 0` for all methods.
The frontend coarse center is estimated from beam energy.

### Cause Analysis

The best methods pass easy, strong coherent, and hard phase scenarios, but weak
secondary and low-SNR hard scenarios bias the beam-energy centroid toward the
dominant return. This raises azimuth RMSE above the Stage2 pass threshold.

### Checks

- MATLAB command: `matlab -batch "run('.../run_stage2_synthetic_frontend_coarse_angle.m')"`
- rows = 150.
- best_method = `centroid_top9`.
- best_within_pm02deg_rate = 0.6.
- best_az_rmse_deg = 0.340822201375.
- best_el_rmse_deg = 0.114006308123.
- best_used_truth_for_center_rate = 0.
- frontend_coarse_angle_pass_flag = 0.
- PNG artifact exists: `frontend_coarse_angle_summary.png`, 30271 bytes.

### Risks

The Stage2 frontend prior is not uniformly within the Step11.3 +/-0.2 deg
robustness envelope. The risk is mainly weak-secondary/low-SNR azimuth bias.

### Decision

CONTINUE_WITH_RISK

### Why This Does Not Block Continuation

Stage3 is explicitly designed to compare synthetic frontend backend against
oracle backend. A frontend coarse-angle risk should therefore be propagated into
Stage3 rather than stopping here.

### Follow-Up Verification

Task05 must verify whether the biased synthetic frontend prior causes backend
success to fall below the oracle-relative gate, and if it does, identify
frontend coarse angle as the bottleneck rather than hiding the failure.

### Git Commit

`86b0be7`

## Task 05: Stage3 Frontend-to-Backend Chain Validation

### Expected Result

Use the synthetic frontend coarse center to drive the Step11 backend and compare
against an oracle-center backend. Pass gate: synthetic success >= 0.85 * oracle
success, `topK_miss_rate <= 0.1`, and `boundary_hit_rate <= 0.2`.

### Actual Result

Implemented `run_step11_pair2d_backend_from_interface.m`,
`evaluate_frontend_backend_chain_metrics.m`, and
`stage3_frontend_to_backend_chain_validation/run_stage3_frontend_to_backend_chain_validation.m`.
MATLAB R2022b ran successfully. Stage3 generated CSV, MAT, log, keypoints,
README, and PNG artifacts. The chain validation pass flag is 1.

### Alignment

Aligned with the interface-level chain goal. Synthetic frontend backend uses
beam-energy-derived coarse centers. Oracle center is used only as a backend
comparison baseline.

### Cause Analysis

Although Stage2 showed frontend azimuth coarse-center bias in weak-secondary
and low-SNR hard cases, the Step11.4 local backend search window was wide enough
for the degree-based coarse-to-fine backend to recover the pair estimates in
this Stage3 trial set.

### Checks

- MATLAB command: `matlab -batch "run('.../run_stage3_frontend_to_backend_chain_validation.m')"`
- rows = 50.
- oracle_success_rate = 1.
- synthetic_success_rate = 1.
- synthetic_to_oracle_success_ratio = 1.
- synthetic_topK_miss_rate = 0.
- synthetic_boundary_hit_rate = 0.
- chain_validation_pass_flag = 1.
- failure_reason = `none`.
- PNG artifact exists: `frontend_backend_chain_summary.png`, 25505 bytes.

### Risks

Stage3 uses a scoped synthetic frontend and a local search window. It validates
interface-level chaining under the tested scenarios, but it does not prove a
complete real CFAR/MTD engineering closure or automatic trigger policy.

### Decision

GO

### Git Commit

`a5a844f`

## Task 06: Stage4 Single-vs-Pair Module Diagnostics

### Expected Result

Diagnose whether ordinary single targets should be forced into pair2d by
default, while confirming pair2d remains useful for unresolved pair cases.
Produce `single_target_false_split_rate`, `pair_target_success_rate`, and
`recommended_trigger_policy_text`.

### Actual Result

Implemented and ran
`stage4_single_vs_pair_module_diagnostics/run_stage4_single_vs_pair_module_diagnostics.m`.
MATLAB R2022b ran successfully and generated CSV, MAT, log, keypoints, README,
and PNG artifacts. Stage4 pass flag is 1.

### Alignment

Aligned with the theoretical boundary. The result supports pair2d as a local
unresolved-cluster enhanced mode and does not claim complete automatic model
selection.

### Cause Analysis

Forced pair2d produces separated pair estimates on ordinary single-target cases
in this diagnostic, while pair scenarios still succeed. This supports using
pair2d only when frontend indicators suggest unresolved local cluster
ambiguity.

### Checks

- MATLAB command: `matlab -batch "run('.../run_stage4_single_vs_pair_module_diagnostics.m')"`
- rows = 40.
- single_target_false_split_rate = 1.
- pair_target_success_rate = 1.
- pair_boundary_hit_rate = 0.
- pair_topK_miss_rate = 0.
- stage4_module_diagnostics_pass_flag = 1.
- PNG artifact exists: `single_vs_pair_diagnostics_summary.png`, 21851 bytes.

### Risks

The trigger policy is a recommendation, not a complete automatic target-count
classifier. Real frontend CFAR/MTD closure remains out of scope.

### Decision

GO

### Git Commit

Recorded in the Task 06 Stage4 commit.

