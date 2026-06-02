# Step8.7 Backend Summary

Source path:

```text
steps/step_08_7_routeB_array_level3/
```

Core script:

```text
space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m
```

Backend structure:

- level2 MUSIC;
- common-el refocus;
- rank1 fallback;
- 2D MUSIC;
- pair-local refinement;
- low_confidence / boundary_unreliable output;
- lazy early stop.

Key metrics from `results_step8_7_7b_lazy_runtime_wallclock_cleanup_check`:

| metric | value |
| --- | ---: |
| lazy_success_rate_all | 0.764705882352941 |
| lazy_false_high_confidence_rate_all | 0 |
| lazy_boundary_missed_rate_all | 0 |
| lazy_low_confidence_rate_all | 0.209150326797386 |
| lazy_boundary_unreliable_rate_all | 0.0915032679738562 |
| mean_runtime_reduction_all | 0.376998770503756 |
| execution_rate_2dmusic_all | 0.562091503267974 |
| execution_rate_pair_local_all | 0.352941176470588 |
| large_el_lazy_success_rate | 1 |

Thesis interpretation: Step8.7 is not perfect, but it is the only route in the current evidence set that combines successful local enhanced DOA behavior with zero false-high and zero boundary-missed rates in the cited validation.

