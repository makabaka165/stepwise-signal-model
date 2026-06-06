# Stage1 Interface Contract Plan

## Goal

Define `frontend_out` and `backend_in` structures and verify that the required
fields can be created and checked without relying on truth-built frontend
centers.

## Planned Functions

- `common/make_frontend_out_struct.m`
- `common/make_backend_in_from_frontend_out.m`
- `common/build_step11_backend_config_from_frontend.m`
- `stage1_interface_contract/run_stage1_interface_contract.m`

## Checks

- `frontend_out_fields_ok = 1`
- `backend_in_fields_ok = 1`
- `interface_contract_pass_flag = 1`

## Outputs

- `results_step11_4_stage1_interface_contract/step11_4_stage1_summary.csv`
- `results_step11_4_stage1_interface_contract/step11_4_stage1_keypoints.csv`
- `results_step11_4_stage1_interface_contract/step11_4_stage1_result.mat`
- `results_step11_4_stage1_interface_contract/step11_4_stage1.log`

