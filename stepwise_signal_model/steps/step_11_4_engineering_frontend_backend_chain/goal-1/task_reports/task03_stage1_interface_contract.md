# Task 03 Report: Stage1 Interface Contract

## Expected Result

Implement and run Stage1 interface-contract code for `frontend_out` and
`backend_in`. Required pass flags: `frontend_out_fields_ok = 1`,
`backend_in_fields_ok = 1`, and `interface_contract_pass_flag = 1`.

## Actual Result

Implemented the Stage1 MATLAB contract helpers and runner. MATLAB R2022b ran
the stage successfully and wrote summary CSV, keypoints CSV, result MAT, log,
and README status artifacts.

## Checks and Tests

- `matlab -batch "run('.../run_stage1_interface_contract.m')"`
- `frontend_out_fields_ok = 1`
- `backend_in_fields_ok = 1`
- `backend_dimension_ok = 1`
- `coarse_center_alignment_ok = 1`
- `truth_guard_ok = 1`
- `search_cfg_fields_ok = 1`
- `recommended_search_values_ok = 1`
- `interface_contract_pass_flag = 1`

## Key Outputs

- `common/make_frontend_out_struct.m`
- `common/build_step11_backend_config_from_frontend.m`
- `common/make_backend_in_from_frontend_out.m`
- `stage1_interface_contract/run_stage1_interface_contract.m`
- `results_step11_4_stage1_interface_contract/step11_4_stage1_summary.csv`
- `results_step11_4_stage1_interface_contract/step11_4_stage1_keypoints.csv`
- `results_step11_4_stage1_interface_contract/step11_4_stage1_result.mat`
- `results_step11_4_stage1_interface_contract/step11_4_stage1.log`

## Pass/Fail Analysis

Task3 passes. The interface contract is executable and the generated
`backend_in` preserves the frontend coarse center as a local prior while
keeping truth as metrics-only metadata.

## Risks

This task does not validate frontend coarse-angle accuracy or backend
performance. Stage2 and Stage3 must continue those checks.

## Decision

GO

## Git Commit

Recorded in the Task 03 Stage1 commit.
