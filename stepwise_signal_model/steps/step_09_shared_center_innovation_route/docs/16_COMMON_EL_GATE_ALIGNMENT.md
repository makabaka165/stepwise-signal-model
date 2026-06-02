# Common-El Gate Alignment

## Motivation

Commit `d4d025d` showed that the Step09 `step87_reference` backend is callable and recovers the large-elevation bridge case, but close-coherent trials still collapse to low confidence. The focused diagnostics reported `rank1_truth_top3_rate = 0.70439`, `refocus_truth_top3_rate = 0.68684`, `common_el_proxy_pass_rate = 0`, and `rank1_route_reliable_rate = 0.91491`. That points to a common-el gate mismatch rather than a pure candidate-generation failure.

## Answers

1. Candidate generation fails: no.
2. Truth enters top-K: rank1 top3 = 0.555560, refocus top3 = 0.547920.
3. Gate that rejects it: the current common-el proxy pass rate is 0.000000 and close-coherent success under Gate 0 is 0.000000; Gate 2 replaces only the rank1 fallback gate with rank1/refocus consensus.
4. Common-el proxy pass rate: 0.000000.
5. Rank1 route reliable rate: 0.809720.
6. Main blocker: `gate_alignment_failed_false_high`.
7. Next step: freeze Step09 backend tuning and fall back to the original Step8.7 verified lazy cascade as final backend evidence.

## Gate Definitions

- Gate 0, `current_common_el_proxy`: the historical common-el proxy remains unchanged and is the default.
- Gate 1, `rank1_reliable_without_common_el_proxy`: rank1 can pass when rank1 reliability, finite pair, separation, and boundary guards pass, without using the common-el proxy.
- Gate 2, `rank1_refocus_consensus_gate`: rank1 can pass only when rank1 and refocus are both reliable, both pairs are valid, boundary guards pass, and swap-invariant pair disagreement is <= `0.12 deg`.

Result directory: `E:\matlab_code\bishe_quanxi\stepwise_signal_model\steps\step_09_shared_center_innovation_route\results_step09_common_el_gate_alignment`.

## Result

## Keypoints

| keypoint | value | note |
|---|---:|---|
| `total_trials` | 4320 | trial rows across all gate modes |
| `Metkl` | 30 | Monte Carlo trials per scenario point |
| `gate_modes` | current_common_el_proxy,rank1_reliable_without_common_el_proxy,rank1_refocus_consensus_gate | tested gate modes |
| `current_close_coherent_success_rate` | 0 | Gate 0 current common-el proxy |
| `gate1_close_coherent_success_rate` | 0.87333 | rank1 without common-el proxy |
| `gate2_close_coherent_success_rate` | 0.87333 | rank1/refocus consensus gate |
| `gate2_close_improvement_over_current` | 0.87333 | Gate 2 minus Gate 0 |
| `gate1_overall_false_high_rate` | 0.034722 | safety diagnostic |
| `gate2_overall_false_high_rate` | 0.034722 | must be <= 0.01 |
| `gate2_weak_false_high_rate` | 0 | must be <= 0.01 |
| `gate2_near_antiphase_false_high_rate` | 0 | must be <= 0.01 |
| `gate2_near_antiphase_boundary_missed_rate` | 0 | diagnostic |
| `gate2_single_target_false_split_rate` | 0.83333 | must be <= 0.01 |
| `gate2_two_separated_reject_out_of_scope_rate` | 1 | must be >= 0.99 |
| `current_common_el_proxy_pass_rate` | 0 | current common-el proxy pass |
| `gate2_rank1_route_reliable_rate` | 0.80972 | rank1 route reliable |
| `gate2_rank1_refocus_consensus_gate_pass_rate` | 0.73681 | shadow/selected gate pass |
| `gate2_truth_rank1_top3_rate` | 0.55556 | truth-only diagnostic |
| `gate2_truth_refocus_top3_rate` | 0.54792 | truth-only diagnostic |
| `gate_alignment_pass_flag` | 0 | Gate 2 pass/fail |
| `main_blocker_type` | gate_alignment_failed_false_high | rule-based blocker classification |
| `blocker_if_any` | gate_alignment_failed_false_high | rule-based blocker |
| `final_recommendation` | freeze_step09_backend_use_step87_verified_lazy_cascade | decision |

## Scenario Summary

| gate_mode | scenario_name | az_sep_deg | SNR_dB | trials | success_rate | false_high_rate | false_split_rate | low_confidence_rate | out_of_scope_reject_rate | selected_gate_pass_rate | route_distribution |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `current_common_el_proxy` | `overall` | NaN | NaN | 1440 | 0.041667 | 0.000000 | 0.000000 | 1.000000 | 0.041667 | 0.000000 | `low_confidence:1088;boundary_unreliable:292;frontend_reject:60` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.15 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:48;boundary_unreliable:12` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.25 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:54;boundary_unreliable:6` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.4 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:53;boundary_unreliable:7` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.6 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:46;boundary_unreliable:14` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.8 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:22;low_confidence:38` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.15 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:60` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.25 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:60` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.4 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:60` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.6 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:55;boundary_unreliable:5` |
| `current_common_el_proxy` | `close_coherent_pair` | 0.8 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:58;boundary_unreliable:2` |
| `current_common_el_proxy` | `medium_beta_pair` | 0.25 | 8 | 90 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:68;boundary_unreliable:22` |
| `current_common_el_proxy` | `medium_beta_pair` | 0.4 | 8 | 90 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:62;boundary_unreliable:28` |
| `current_common_el_proxy` | `medium_beta_pair` | 0.6 | 8 | 90 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:77;boundary_unreliable:13` |
| `current_common_el_proxy` | `medium_beta_pair` | 0.25 | 16 | 90 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:88;boundary_unreliable:2` |
| `current_common_el_proxy` | `medium_beta_pair` | 0.4 | 16 | 90 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:90` |
| `current_common_el_proxy` | `medium_beta_pair` | 0.6 | 16 | 90 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:72;boundary_unreliable:18` |
| `current_common_el_proxy` | `weak_target_boundary` | 0.25 | 8 | 30 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:12;low_confidence:18` |
| `current_common_el_proxy` | `weak_target_boundary` | 0.25 | 16 | 30 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:29;boundary_unreliable:1` |
| `current_common_el_proxy` | `near_antiphase_boundary` | 0.25 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:60` |
| `current_common_el_proxy` | `near_antiphase_boundary` | 0.25 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:60` |
| `current_common_el_proxy` | `single_target_sanity` | NaN | 8 | 30 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:22;boundary_unreliable:8` |
| `current_common_el_proxy` | `single_target_sanity` | NaN | 16 | 30 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `low_confidence:30` |
| `current_common_el_proxy` | `two_separated_coarse_peaks` | 4 | 8 | 30 | 1.000000 | 0.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | `frontend_reject:30` |
| `current_common_el_proxy` | `two_separated_coarse_peaks` | 4 | 16 | 30 | 1.000000 | 0.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | `frontend_reject:30` |
| `rank1_reliable_without_common_el_proxy` | `overall` | NaN | NaN | 1440 | 0.717361 | 0.034722 | 0.034722 | 0.263194 | 0.041667 | 0.736806 | `common_el_rank1_refocus:1061;boundary_unreliable:228;low_confidence:91;frontend_reject:60` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.15 | 8 | 60 | 0.800000 | 0.000000 | 0.000000 | 0.200000 | 0.000000 | 0.800000 | `common_el_rank1_refocus:48;boundary_unreliable:12` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.25 | 8 | 60 | 0.866667 | 0.000000 | 0.000000 | 0.133333 | 0.000000 | 0.866667 | `common_el_rank1_refocus:52;boundary_unreliable:6;low_confidence:2` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.4 | 8 | 60 | 0.833333 | 0.000000 | 0.000000 | 0.166667 | 0.000000 | 0.833333 | `common_el_rank1_refocus:50;low_confidence:3;boundary_unreliable:7` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.6 | 8 | 60 | 0.850000 | 0.000000 | 0.000000 | 0.150000 | 0.000000 | 0.850000 | `common_el_rank1_refocus:51;boundary_unreliable:7;low_confidence:2` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.8 | 8 | 60 | 0.966667 | 0.000000 | 0.000000 | 0.033333 | 0.000000 | 0.966667 | `common_el_rank1_refocus:58;low_confidence:2` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.15 | 16 | 60 | 0.800000 | 0.000000 | 0.000000 | 0.200000 | 0.000000 | 0.800000 | `common_el_rank1_refocus:48;low_confidence:12` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.25 | 16 | 60 | 0.783333 | 0.000000 | 0.000000 | 0.216667 | 0.000000 | 0.783333 | `common_el_rank1_refocus:47;low_confidence:13` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.4 | 16 | 60 | 0.900000 | 0.000000 | 0.000000 | 0.100000 | 0.000000 | 0.900000 | `common_el_rank1_refocus:54;low_confidence:6` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.6 | 16 | 60 | 0.983333 | 0.000000 | 0.000000 | 0.016667 | 0.000000 | 0.983333 | `common_el_rank1_refocus:59;low_confidence:1` |
| `rank1_reliable_without_common_el_proxy` | `close_coherent_pair` | 0.8 | 16 | 60 | 0.950000 | 0.000000 | 0.000000 | 0.050000 | 0.000000 | 0.950000 | `common_el_rank1_refocus:57;low_confidence:3` |
| `rank1_reliable_without_common_el_proxy` | `medium_beta_pair` | 0.25 | 8 | 90 | 0.733333 | 0.000000 | 0.000000 | 0.266667 | 0.000000 | 0.733333 | `common_el_rank1_refocus:66;boundary_unreliable:17;low_confidence:7` |
| `rank1_reliable_without_common_el_proxy` | `medium_beta_pair` | 0.4 | 8 | 90 | 0.633333 | 0.000000 | 0.000000 | 0.366667 | 0.000000 | 0.633333 | `common_el_rank1_refocus:57;boundary_unreliable:28;low_confidence:5` |
| `rank1_reliable_without_common_el_proxy` | `medium_beta_pair` | 0.6 | 8 | 90 | 0.844444 | 0.000000 | 0.000000 | 0.155556 | 0.000000 | 0.844444 | `common_el_rank1_refocus:76;boundary_unreliable:13;low_confidence:1` |
| `rank1_reliable_without_common_el_proxy` | `medium_beta_pair` | 0.25 | 16 | 90 | 0.911111 | 0.000000 | 0.000000 | 0.088889 | 0.000000 | 0.911111 | `low_confidence:8;common_el_rank1_refocus:82` |
| `rank1_reliable_without_common_el_proxy` | `medium_beta_pair` | 0.4 | 16 | 90 | 0.888889 | 0.000000 | 0.000000 | 0.111111 | 0.000000 | 0.888889 | `common_el_rank1_refocus:80;low_confidence:10` |
| `rank1_reliable_without_common_el_proxy` | `medium_beta_pair` | 0.6 | 16 | 90 | 0.977778 | 0.000000 | 0.000000 | 0.022222 | 0.000000 | 0.977778 | `common_el_rank1_refocus:88;low_confidence:2` |
| `rank1_reliable_without_common_el_proxy` | `weak_target_boundary` | 0.25 | 8 | 30 | 0.000000 | 0.000000 | 0.000000 | 0.433333 | 0.000000 | 0.566667 | `common_el_rank1_refocus:17;low_confidence:3;boundary_unreliable:10` |
| `rank1_reliable_without_common_el_proxy` | `weak_target_boundary` | 0.25 | 16 | 30 | 0.000000 | 0.000000 | 0.000000 | 0.300000 | 0.000000 | 0.700000 | `common_el_rank1_refocus:21;low_confidence:9` |
| `rank1_reliable_without_common_el_proxy` | `near_antiphase_boundary` | 0.25 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:60` |
| `rank1_reliable_without_common_el_proxy` | `near_antiphase_boundary` | 0.25 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:60` |
| `rank1_reliable_without_common_el_proxy` | `single_target_sanity` | NaN | 8 | 30 | 0.000000 | 0.733333 | 0.733333 | 0.266667 | 0.000000 | 0.733333 | `common_el_rank1_refocus:22;boundary_unreliable:8` |
| `rank1_reliable_without_common_el_proxy` | `single_target_sanity` | NaN | 16 | 30 | 0.000000 | 0.933333 | 0.933333 | 0.066667 | 0.000000 | 0.933333 | `common_el_rank1_refocus:28;low_confidence:2` |
| `rank1_reliable_without_common_el_proxy` | `two_separated_coarse_peaks` | 4 | 8 | 30 | 1.000000 | 0.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | `frontend_reject:30` |
| `rank1_reliable_without_common_el_proxy` | `two_separated_coarse_peaks` | 4 | 16 | 30 | 1.000000 | 0.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | `frontend_reject:30` |
| `rank1_refocus_consensus_gate` | `overall` | NaN | NaN | 1440 | 0.717361 | 0.034722 | 0.034722 | 0.263194 | 0.041667 | 0.736806 | `common_el_rank1_refocus:1061;boundary_unreliable:228;low_confidence:91;frontend_reject:60` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.15 | 8 | 60 | 0.800000 | 0.000000 | 0.000000 | 0.200000 | 0.000000 | 0.800000 | `common_el_rank1_refocus:48;boundary_unreliable:12` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.25 | 8 | 60 | 0.866667 | 0.000000 | 0.000000 | 0.133333 | 0.000000 | 0.866667 | `common_el_rank1_refocus:52;boundary_unreliable:6;low_confidence:2` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.4 | 8 | 60 | 0.833333 | 0.000000 | 0.000000 | 0.166667 | 0.000000 | 0.833333 | `common_el_rank1_refocus:50;low_confidence:3;boundary_unreliable:7` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.6 | 8 | 60 | 0.850000 | 0.000000 | 0.000000 | 0.150000 | 0.000000 | 0.850000 | `common_el_rank1_refocus:51;boundary_unreliable:7;low_confidence:2` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.8 | 8 | 60 | 0.966667 | 0.000000 | 0.000000 | 0.033333 | 0.000000 | 0.966667 | `common_el_rank1_refocus:58;low_confidence:2` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.15 | 16 | 60 | 0.800000 | 0.000000 | 0.000000 | 0.200000 | 0.000000 | 0.800000 | `common_el_rank1_refocus:48;low_confidence:12` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.25 | 16 | 60 | 0.783333 | 0.000000 | 0.000000 | 0.216667 | 0.000000 | 0.783333 | `common_el_rank1_refocus:47;low_confidence:13` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.4 | 16 | 60 | 0.900000 | 0.000000 | 0.000000 | 0.100000 | 0.000000 | 0.900000 | `common_el_rank1_refocus:54;low_confidence:6` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.6 | 16 | 60 | 0.983333 | 0.000000 | 0.000000 | 0.016667 | 0.000000 | 0.983333 | `common_el_rank1_refocus:59;low_confidence:1` |
| `rank1_refocus_consensus_gate` | `close_coherent_pair` | 0.8 | 16 | 60 | 0.950000 | 0.000000 | 0.000000 | 0.050000 | 0.000000 | 0.950000 | `common_el_rank1_refocus:57;low_confidence:3` |
| `rank1_refocus_consensus_gate` | `medium_beta_pair` | 0.25 | 8 | 90 | 0.733333 | 0.000000 | 0.000000 | 0.266667 | 0.000000 | 0.733333 | `common_el_rank1_refocus:66;boundary_unreliable:17;low_confidence:7` |
| `rank1_refocus_consensus_gate` | `medium_beta_pair` | 0.4 | 8 | 90 | 0.633333 | 0.000000 | 0.000000 | 0.366667 | 0.000000 | 0.633333 | `common_el_rank1_refocus:57;boundary_unreliable:28;low_confidence:5` |
| `rank1_refocus_consensus_gate` | `medium_beta_pair` | 0.6 | 8 | 90 | 0.844444 | 0.000000 | 0.000000 | 0.155556 | 0.000000 | 0.844444 | `common_el_rank1_refocus:76;boundary_unreliable:13;low_confidence:1` |
| `rank1_refocus_consensus_gate` | `medium_beta_pair` | 0.25 | 16 | 90 | 0.911111 | 0.000000 | 0.000000 | 0.088889 | 0.000000 | 0.911111 | `low_confidence:8;common_el_rank1_refocus:82` |
| `rank1_refocus_consensus_gate` | `medium_beta_pair` | 0.4 | 16 | 90 | 0.888889 | 0.000000 | 0.000000 | 0.111111 | 0.000000 | 0.888889 | `common_el_rank1_refocus:80;low_confidence:10` |
| `rank1_refocus_consensus_gate` | `medium_beta_pair` | 0.6 | 16 | 90 | 0.977778 | 0.000000 | 0.000000 | 0.022222 | 0.000000 | 0.977778 | `common_el_rank1_refocus:88;low_confidence:2` |
| `rank1_refocus_consensus_gate` | `weak_target_boundary` | 0.25 | 8 | 30 | 0.000000 | 0.000000 | 0.000000 | 0.433333 | 0.000000 | 0.566667 | `common_el_rank1_refocus:17;low_confidence:3;boundary_unreliable:10` |
| `rank1_refocus_consensus_gate` | `weak_target_boundary` | 0.25 | 16 | 30 | 0.000000 | 0.000000 | 0.000000 | 0.300000 | 0.000000 | 0.700000 | `common_el_rank1_refocus:21;low_confidence:9` |
| `rank1_refocus_consensus_gate` | `near_antiphase_boundary` | 0.25 | 8 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:60` |
| `rank1_refocus_consensus_gate` | `near_antiphase_boundary` | 0.25 | 16 | 60 | 0.000000 | 0.000000 | 0.000000 | 1.000000 | 0.000000 | 0.000000 | `boundary_unreliable:60` |
| `rank1_refocus_consensus_gate` | `single_target_sanity` | NaN | 8 | 30 | 0.000000 | 0.733333 | 0.733333 | 0.266667 | 0.000000 | 0.733333 | `common_el_rank1_refocus:22;boundary_unreliable:8` |
| `rank1_refocus_consensus_gate` | `single_target_sanity` | NaN | 16 | 30 | 0.000000 | 0.933333 | 0.933333 | 0.066667 | 0.000000 | 0.933333 | `common_el_rank1_refocus:28;low_confidence:2` |
| `rank1_refocus_consensus_gate` | `two_separated_coarse_peaks` | 4 | 8 | 30 | 1.000000 | 0.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | `frontend_reject:30` |
| `rank1_refocus_consensus_gate` | `two_separated_coarse_peaks` | 4 | 16 | 30 | 1.000000 | 0.000000 | 0.000000 | 1.000000 | 1.000000 | 0.000000 | `frontend_reject:30` |

## Gate 2 Decision

Gate 2 did not pass the requested decision rule. Main blocker: `gate_alignment_failed_false_high`. The next route is to stop tuning the Step09 backend and use the Step8.7 verified lazy cascade as the final backend evidence, while Step09 remains the interface/documentation layer.
