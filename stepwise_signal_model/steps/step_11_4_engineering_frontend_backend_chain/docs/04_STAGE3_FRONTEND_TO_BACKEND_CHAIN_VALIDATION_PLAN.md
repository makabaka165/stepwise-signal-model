# Stage3 Frontend-to-Backend Chain Validation Plan

## Goal

Drive the existing Step11 backend using the synthetic frontend coarse center and
compare it against an oracle-center backend.

## Backend Dependencies

- `steps/step_11_3_beamspace_ml_search_acceleration/common/build_recommended_w_from_step11_2.m`
- `steps/step_11_3_beamspace_ml_search_acceleration/common/search_pair2d_coarse_to_fine.m`
- `steps/step_11_1_beamspace_ml_validation/common/make_cyl_pair2d_correlated_snapshots.m`
- `steps/step_11_1_beamspace_ml_validation/common/eval_el_separation_pair_metrics.m`

## Pass Gate

- synthetic success >= 0.85 * oracle success
- `topK_miss_rate <= 0.1`
- `boundary_hit_rate <= 0.2`

## Failure Output

If the pass gate fails, report `failure_reason` and identify whether the likely
cause is frontend coarse error, backend search configuration, or interface
serialization.

