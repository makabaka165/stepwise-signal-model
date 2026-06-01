# Ablation Study Results

Modes: `music_only`, `music_plus_rank1`, `music_plus_2d`, `full_step09`, `full_without_rejector`.

## Keypoints

| keypoint | value | note |
|---|---:|---|
| `music_only_close_coherent_success` | 0 | close coherent success |
| `music_plus_rank1_close_coherent_success` | 0 | close coherent success |
| `rank1_gain_close_coherent` | 0 | rank1 gain |
| `music_plus_rank1_large_el_success` | 0 | large-el success without 2-D refinement |
| `music_plus_2d_large_el_success` | 0 | large-el success |
| `full_step09_large_el_success` | 0 | large-el success |
| `twoD_gain_large_el` | 0 | 2D gain relative to no-2D mode |
| `full_without_rejector_false_high` | 0.42857 | false-high without rejector |
| `full_step09_false_high` | 0.021429 | false-high with rejector |
| `rejector_false_high_reduction` | 0.40714 | rejector reduction |
| `full_without_rejector_boundary_missed` | 0.14286 | boundary missed without rejector |
| `full_step09_boundary_missed` | 0 | boundary missed with rejector |
| `rejector_boundary_missed_reduction` | 0.14286 | rejector reduction |
| `full_step09_success_rate` | 0.14286 | overall full Step 09 |
| `full_step09_safe_rate` | 0.97857 | overall full Step 09 |
| `full_step09_low_confidence_rate` | 0.97857 | overall full Step 09 |
| `ablation_pass_flag` | 0 | pass/fail |
| `blocker_if_any` | rank1_gain_close_coherent_low,local_2d_gain_large_el_low,full_step09_false_high_gt_0p01 | comma-separated blocker list |

## Summary

| ablation_mode | scenario_name | trials | success_rate | safe_rate | false_high_rate | boundary_missed_rate | low_confidence_rate | out_of_scope_rate | mean_az_error_success | mean_el_error_success | median_runtime_sec | mean_runtime_sec | route_distribution | confidence_distribution |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| music_only | single_target_sanity | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0099755 | 0.009933 | low_confidence:1.000 | low:1.000 |
| music_only | close_coherent_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0097257 | 0.0097166 | low_confidence:1.000 | low:1.000 |
| music_only | medium_beta_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0094208 | 0.0095482 | low_confidence:1.000 | low:1.000 |
| music_only | weak_target_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.009787 | 0.0099647 | low_confidence:1.000 | low:1.000 |
| music_only | near_antiphase_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.010027 | 0.010005 | boundary_unreliable:1.000 | low:1.000 |
| music_only | large_el_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0098709 | 0.010042 | low_confidence:1.000 | low:1.000 |
| music_only | two_separated_coarse_peaks | 60 | 1 | 1 | 0 | 0 | 1 | 1 | NaN | NaN | 0.0001665 | 0.00017025 | frontend_reject:1.000 | low:1.000 |
| music_plus_rank1 | single_target_sanity | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0094406 | 0.0096592 | low_confidence:1.000 | low:1.000 |
| music_plus_rank1 | close_coherent_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0095992 | 0.009665 | low_confidence:1.000 | low:1.000 |
| music_plus_rank1 | medium_beta_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0095558 | 0.0098865 | low_confidence:1.000 | low:1.000 |
| music_plus_rank1 | weak_target_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0097057 | 0.0097955 | low_confidence:1.000 | low:1.000 |
| music_plus_rank1 | near_antiphase_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.010116 | 0.010457 | boundary_unreliable:1.000 | low:1.000 |
| music_plus_rank1 | large_el_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.010016 | 0.010202 | low_confidence:1.000 | low:1.000 |
| music_plus_rank1 | two_separated_coarse_peaks | 60 | 1 | 1 | 0 | 0 | 1 | 1 | NaN | NaN | 0.00016085 | 0.00016069 | frontend_reject:1.000 | low:1.000 |
| music_plus_2d | single_target_sanity | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0098323 | 0.010039 | low_confidence:1.000 | low:1.000 |
| music_plus_2d | close_coherent_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0092161 | 0.0092323 | low_confidence:1.000 | low:1.000 |
| music_plus_2d | medium_beta_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0091305 | 0.0094067 | low_confidence:1.000 | low:1.000 |
| music_plus_2d | weak_target_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0093901 | 0.0095852 | low_confidence:1.000 | low:1.000 |
| music_plus_2d | near_antiphase_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0095108 | 0.0098521 | boundary_unreliable:1.000 | low:1.000 |
| music_plus_2d | large_el_pair | 60 | 0 | 0.85 | 0.15 | 0 | 0.85 | 0 | NaN | NaN | 0.13526 | 0.13614 | low_confidence:0.850;local_2d_pair_refinement:0.150 | low:0.850;medium:0.150 |
| music_plus_2d | two_separated_coarse_peaks | 60 | 1 | 1 | 0 | 0 | 1 | 1 | NaN | NaN | 0.00015255 | 0.0001547 | frontend_reject:1.000 | low:1.000 |
| full_step09 | single_target_sanity | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0097786 | 0.0097533 | low_confidence:1.000 | low:1.000 |
| full_step09 | close_coherent_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0096437 | 0.0098083 | low_confidence:1.000 | low:1.000 |
| full_step09 | medium_beta_pair | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0096261 | 0.0097914 | low_confidence:1.000 | low:1.000 |
| full_step09 | weak_target_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0096013 | 0.0096443 | low_confidence:1.000 | low:1.000 |
| full_step09 | near_antiphase_boundary | 60 | 0 | 1 | 0 | 0 | 1 | 0 | NaN | NaN | 0.0096919 | 0.0098052 | boundary_unreliable:1.000 | low:1.000 |
| full_step09 | large_el_pair | 60 | 0 | 0.85 | 0.15 | 0 | 0.85 | 0 | NaN | NaN | 0.13736 | 0.138 | low_confidence:0.850;local_2d_pair_refinement:0.150 | low:0.850;medium:0.150 |
| full_step09 | two_separated_coarse_peaks | 60 | 1 | 1 | 0 | 0 | 1 | 1 | NaN | NaN | 0.00016045 | 0.00016199 | frontend_reject:1.000 | low:1.000 |
| full_without_rejector | single_target_sanity | 60 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0094469 | 0.010177 | no_rejector_music_candidate:1.000 | medium:1.000 |
| full_without_rejector | close_coherent_pair | 60 | 0 | 0 | 1 | 0 | 0 | 0 | NaN | NaN | 0.0093519 | 0.0094174 | no_rejector_music_candidate:1.000 | medium:1.000 |
| full_without_rejector | medium_beta_pair | 60 | 0 | 0 | 0 | 0 | 0 | 0 | NaN | NaN | 0.0092307 | 0.0093737 | no_rejector_music_candidate:1.000 | medium:1.000 |
| full_without_rejector | weak_target_boundary | 60 | 0 | 0 | 0 | 0 | 0 | 0 | NaN | NaN | 0.009196 | 0.0092093 | no_rejector_music_candidate:1.000 | medium:1.000 |
| full_without_rejector | near_antiphase_boundary | 60 | 0 | 0 | 1 | 1 | 0 | 0 | NaN | NaN | 0.0092743 | 0.0093385 | no_rejector_music_candidate:1.000 | medium:1.000 |
| full_without_rejector | large_el_pair | 60 | 0 | 0 | 1 | 0 | 0 | 0 | NaN | NaN | 0.13366 | 0.13474 | no_rejector_2d_candidate:0.850;local_2d_pair_refinement:0.150 | medium:1.000 |
| full_without_rejector | two_separated_coarse_peaks | 60 | 1 | 1 | 0 | 0 | 1 | 1 | NaN | NaN | 0.00015545 | 0.00015779 | frontend_reject:1.000 | low:1.000 |

## Figures

- `../results_step09_ablation/ablation_success_by_scenario.png`
- `../results_step09_ablation/ablation_false_high_by_scenario.png`
- `../results_step09_ablation/ablation_boundary_missed_by_scenario.png`
- `../results_step09_ablation/ablation_runtime_by_mode.png`
- `../results_step09_ablation/ablation_low_confidence_by_mode.png`
