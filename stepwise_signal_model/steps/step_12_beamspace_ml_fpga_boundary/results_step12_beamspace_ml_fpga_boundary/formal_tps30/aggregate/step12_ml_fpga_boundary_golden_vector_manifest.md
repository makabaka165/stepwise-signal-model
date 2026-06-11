# Step12 Golden Vector Manifest

- Golden vectors are compact RTL score-core testbench evidence, not a full FPGA backend validation.
- They cover the Step11 beamspace ML score core for the formal recommended fixed-point mode.
- Full candidate streams are not exported by default and `golden_vectors_full/` is ignored by Git.
- recommended fixed-point format: `mixed_Z16_G24_Rz24`
- case count: 5

| case | role | mode | trial | scenario | subset_candidates | path |
| --- | --- | --- | --- | --- | --- | --- |
| case_0001 | best_reliable_case | mixed_Z16_G24_Rz24 | 501 | medium_beta_coherent | 64 | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_12_beamspace_ml_fpga_boundary\results_step12_beamspace_ml_fpga_boundary\formal_tps30\aggregate\golden_vectors\case_0001` |
| case_0002 | worst_score_gap_rel_error_case | mixed_Z16_G24_Rz24 | 1174 | low_margin_score_gap | 64 | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_12_beamspace_ml_fpga_boundary\results_step12_beamspace_ml_fpga_boundary\formal_tps30\aggregate\golden_vectors\case_0002` |
| case_0003 | smallest_reliable_margin_case | mixed_Z16_G24_Rz24 | 907 | easy_noncoherent | 64 | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_12_beamspace_ml_fpga_boundary\results_step12_beamspace_ml_fpga_boundary\formal_tps30\aggregate\golden_vectors\case_0003` |
| case_0004 | topK_boundary_case | mixed_Z16_G24_Rz24 | 1 | easy_noncoherent | 64 | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_12_beamspace_ml_fpga_boundary\results_step12_beamspace_ml_fpga_boundary\formal_tps30\aggregate\golden_vectors\case_0004` |
| case_0005 | combined_int16_worst_case | combined_int16 | 872 | low_margin_score_gap | 64 | `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_12_beamspace_ml_fpga_boundary\results_step12_beamspace_ml_fpga_boundary\formal_tps30\aggregate\golden_vectors\case_0005` |
