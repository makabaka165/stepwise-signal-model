# Task 04 Report: Stage2 Synthetic Frontend Coarse Angle

## Expected Result

Estimate frontend coarse az/el from synthetic two-dimensional beam energy
without using truth to construct the coarse center. Generate CSV, MAT, log,
keypoints, README, and PNG artifacts.

## Actual Result

MATLAB R2022b ran Stage2 successfully. The best method was `centroid_top9`, but
`frontend_coarse_angle_pass_flag = 0`.

## Checks and Tests

- `matlab -batch "run('.../run_stage2_synthetic_frontend_coarse_angle.m')"`
- trial rows = 150.
- best_method = `centroid_top9`
- best_within_pm02deg_rate = 0.6
- best_az_rmse_deg = 0.340822201375
- best_el_rmse_deg = 0.114006308123
- best_used_truth_for_center_rate = 0
- frontend_coarse_angle_pass_flag = 0

## Key Outputs

- `common/build_frontend_beam_pool_from_existing_layout.m`
- `common/run_synthetic_frontend_beam_scan.m`
- `common/estimate_coarse_angle_from_frontend_beams.m`
- `common/compute_frontend_cluster_indicators.m`
- `stage2_synthetic_frontend_coarse_angle/run_stage2_synthetic_frontend_coarse_angle.m`
- `results_step11_4_stage2_synthetic_frontend_coarse_angle/step11_4_stage2_trial.csv`
- `results_step11_4_stage2_synthetic_frontend_coarse_angle/step11_4_stage2_summary.csv`
- `results_step11_4_stage2_synthetic_frontend_coarse_angle/step11_4_stage2_keypoints.csv`
- `results_step11_4_stage2_synthetic_frontend_coarse_angle/step11_4_stage2_result.mat`
- `results_step11_4_stage2_synthetic_frontend_coarse_angle/frontend_coarse_angle_summary.png`

## Pass/Fail Analysis

Stage2 does not fully pass. Easy, strong coherent, and hard phase cases are
within the +/-0.2 deg coarse-angle envelope for centroid methods, but
`weak_secondary` and `low_snr_hard` bias the frontend azimuth center by about
0.53 deg. This raises best azimuth RMSE to 0.340822 deg.

## Risks

The synthetic frontend prior may be too biased for the backend in weak-secondary
or low-SNR hard cases. This is exactly the risk Task05 must test against oracle
backend.

## Decision

CONTINUE_WITH_RISK

## Git Commit

Recorded in the Task 04 Stage2 commit.
