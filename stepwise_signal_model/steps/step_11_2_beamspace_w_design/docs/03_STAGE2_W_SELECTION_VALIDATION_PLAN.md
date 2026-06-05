Stage2 W selection validation plan
==================================

Stage2 runs the fixed Step11.1 controlled pair2d beamspace ML backend with
different W choices.

Methods
-------

- `regular_3dB_grid`
- `greedy_projection`
- `greedy_lowcorr`
- `svd_upper_bound`
- `random_pool_baseline`

Scenarios
---------

| scenario | rho | phase_deg | beta | az_sep | el_sep | snr_db |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| easy_noncoherent | 0.00 | 0 | 1.0 | 1.27 | 0.67 | 30 |
| strong_coherent | 0.99 | 5 | 1.0 | 1.27 | 0.37 | 30 |
| hard_phase | 0.99 | 150 | 1.0 | 0.83 | 0.37 | 30 |
| weak_secondary | 0.99 | 150 | 0.3 | 0.83 | 0.37 | 30 |
| low_snr_hard | 1.00 | 150 | 0.3 | 0.83 | 0.37 | 20 |

Common settings
---------------

```text
B_list = [9, 15, 25]
Metkl = 5
L = 64
```

Metrics
-------

- joint success rate
- azimuth RMSE
- elevation RMSE
- worst-case success
- projection loss
- max beamspace manifold correlation
- `cond(W'W)`
- selected `cond(G'G)`
- beam count
- backend candidate count

Outputs
-------

- `step11_2_w_selection_validation_trial.csv`
- `step11_2_w_selection_validation_summary.csv`
- `step11_2_w_selection_validation_keypoints.csv`
- `step11_2_w_selection_validation_result.mat`
- `step11_2_w_selection_validation.log`
- `w_method_success_compare.png`
- `w_method_rmse_compare.png`
- `w_method_worst_case_compare.png`
- `w_method_projection_vs_success.png`
- `w_method_corr_vs_success.png`
- `w_method_complexity_compare.png`

