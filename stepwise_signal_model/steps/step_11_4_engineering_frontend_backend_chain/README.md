# Step11.4 Engineering Frontend-Backend Chain

This step validates an interface-level chain between a synthetic frontend
coarse beam scan and the Step11 backend.

The intended chain is:

frontend coarse beam scan -> frontend_out -> backend_in -> W = greedy_combined_B7
-> Z = W'Y -> controlled pair2d beamspace ML -> degree-based coarse-to-fine
search -> local unresolved-pair enhanced angle output.

## Positioning

Step11.4 is not a full radar engineering closure. It is a scoped validation of
whether a frontend coarse peak can provide a useful local prior for the
existing Step11 pair2d backend.

The frontend single peak is treated as an engineering observation, not as a
physical single-target decision. The backend pair2d mode is treated as an
enhanced local unresolved-cluster mode, not as a replacement for CFAR or for
complete automatic target-count selection.

## Protected Dependencies

The following directories are read-only dependencies for this goal:

- `steps/step_11_1_beamspace_ml_validation/`
- `steps/step_11_2_beamspace_w_design/`
- `steps/step_11_3_beamspace_ml_search_acceleration/`
- `steps/step_09_cpi_track/`
- `steps/step_10_final_thesis_route/`
- `steps/step_11_supersolution_ml/`

Step11.4 may add its own wrappers, docs, and result files under this directory,
but it must not modify the protected dependencies above.

## Stages

- Stage1 defines and checks `frontend_out` and `backend_in`.
- Stage2 estimates a coarse frontend angle from synthetic beam energy, without
  using truth to construct the coarse center.
- Stage3 drives the Step11 backend from the synthetic frontend interface and
  compares it with an oracle-center backend.
- Stage4 diagnoses why ordinary single-target cases should not be forced into
  pair2d by default.

Each stage writes CSV, MAT, log, keypoints, and status artifacts when executed.

