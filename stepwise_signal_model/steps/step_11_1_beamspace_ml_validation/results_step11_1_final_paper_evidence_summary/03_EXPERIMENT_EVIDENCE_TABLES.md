# Experiment Evidence Tables

## Stage Status

| stage | goal | key_pass_flag | pass_flag_value | key_metrics | conclusion | limitation | recommended_next_step | status | keypoints_path |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Stage1 ULA prior ablation | Check whether ULA beamspace ML depends on left/right partition prior. | prior_dependency_flag | 0 | prior_dependency_flag=0 | ULA beamspace ML is not obviously dependent on the left/right partition prior. | ULA-only ablation; not a cylindrical-array final result. | proceed_to_cylindrical_azonly_beamspace_ml | complete | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_11_1_beamspace_ml_validation\results_step11_1_ula_prior_ablation\step11_1_ula_prior_ablation_keypoints.csv |
| Stage2 cylindrical az-only beamspace ML | Validate the fixed-elevation cylindrical az-only beamspace ML loop. | cyl_azonly_pass_flag | 1 | cyl_azonly_pass_flag=1 | Cylindrical fixed-el az-only beamspace ML passes. | Az-only with fixed el0; not a complete 2D pair estimator. | proceed_to_cylindrical_2d_beamspace_ml_or_coherence_stress | complete | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_11_1_beamspace_ml_validation\results_step11_1_cyl_azonly_beamspace_ml\step11_1_cyl_azonly_keypoints.csv |
| Stage3 cylindrical common-el 2D beamspace ML | Validate cylindrical 2D beamspace ML under a common-elevation assumption. | cyl_common_el_2d_pass_flag | 1 | cyl_common_el_2d_pass_flag=1 | Common-el 2D beamspace ML passes as a baseline route. | Shared-elevation assumption limits separated-elevation cases. | proceed_to_cylindrical_el_separation_or_coherence_stress | complete | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_11_1_beamspace_ml_validation\results_step11_1_cyl_common_el_2d_beamspace_ml\step11_1_cyl_common_el_2d_keypoints.csv |
| Stage4 controlled el-separated pair2d beamspace ML | Validate the controlled el-separated pair parameterization. | cyl_el_separation_pass_flag | 1 | cyl_el_separation_pass_flag=1; best_sep_joint_success_bias0_snr30=1; sep_minus_common_joint_success_gap_bias0_snr30=1 | Controlled pair2d improves separated-elevation cases over common-el. | Controlled pair2d is not full unconstrained 4D. | proceed_to_cylindrical_coherence_stress_or_model_selection | complete | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_11_1_beamspace_ml_validation\results_step11_1_cyl_el_separation_beamspace_ml\step11_1_cyl_el_separation_keypoints.csv |
| Stage5 coherence stress | Stress controlled pair2d under correlated and strongly correlated sources. | coherence_stress_pass_flag | 1 | coherence_stress_pass_flag=1; pass_rate_moderate_coherence=0.993055555556; pass_rate_strong_coherence=0.951388888889; worst_case_joint_success_pair2d_white=0; max_false_high_like_rate=1 | Coherence stress passes in aggregate and exposes boundary cases. | Strong-coherence worst cases still exist; confidence boundary is not complete. | proceed_to_model_selection_and_confidence_boundary | complete | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_11_1_beamspace_ml_validation\results_step11_1_cyl_coherence_stress\step11_1_cyl_coherence_stress_keypoints.csv |
| Stage6 full4d upper-bound comparison | Compare common-el, controlled pair2d, and local full4d beamspace ML. | full4d_pass_flag | 1 | full4d_pass_flag=1; best_full4d_joint_success=1; best_pair2d_joint_success=1; full4d_minus_pair2d_success_gap=0; complexity_ratio_full4d_over_pair2d=3.95890410959; full4d_recommended_role=upper_bound_only_pair2d_is_sufficient | Full4d is an upper-bound comparison; controlled pair2d remains sufficient in tested cases. | Full4d has higher complexity and is not the default main algorithm. | proceed_to_final_paper_evidence_summary | complete | E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_11_1_beamspace_ml_validation\results_step11_1_full4d_beamspace_ml_comparison\step11_1_full4d_comparison_keypoints.csv |

## Final Key Metrics

| stage | metric | metric_value | metric_text |
| --- | --- | --- | --- |
| Stage1 ULA prior ablation | prior_dependency_flag | 0 |  |
| Stage2 cylindrical az-only beamspace ML | cyl_azonly_pass_flag | 1 |  |
| Stage3 cylindrical common-el 2D beamspace ML | cyl_common_el_2d_pass_flag | 1 |  |
| Stage4 controlled el-separated pair2d beamspace ML | cyl_el_separation_pass_flag | 1 |  |
| Stage4 controlled el-separated pair2d beamspace ML | best_sep_joint_success_bias0_snr30 | 1 |  |
| Stage4 controlled el-separated pair2d beamspace ML | sep_minus_common_joint_success_gap_bias0_snr30 | 1 |  |
| Stage5 coherence stress | coherence_stress_pass_flag | 1 |  |
| Stage5 coherence stress | pass_rate_moderate_coherence | 0.993055555556 |  |
| Stage5 coherence stress | pass_rate_strong_coherence | 0.951388888889 |  |
| Stage5 coherence stress | worst_case_joint_success_pair2d_white | 0 |  |
| Stage5 coherence stress | max_false_high_like_rate | 1 |  |
| Stage6 full4d upper-bound comparison | full4d_pass_flag | 1 |  |
| Stage6 full4d upper-bound comparison | best_full4d_joint_success | 1 |  |
| Stage6 full4d upper-bound comparison | best_pair2d_joint_success | 1 |  |
| Stage6 full4d upper-bound comparison | full4d_minus_pair2d_success_gap | 0 |  |
| Stage6 full4d upper-bound comparison | complexity_ratio_full4d_over_pair2d | 3.95890410959 |  |
| Stage6 full4d upper-bound comparison | full4d_recommended_role | NaN | upper_bound_only_pair2d_is_sufficient |

## Missing Files

_None._