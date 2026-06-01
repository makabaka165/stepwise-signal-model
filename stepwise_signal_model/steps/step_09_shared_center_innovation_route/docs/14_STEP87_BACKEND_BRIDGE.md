# Step87 Backend Bridge

## Why this bridge exists

Step 09 light backend exposed real blockers in formal Monte Carlo: low close-coherent success, low large-elevation success, and residual false-high behavior. The goal here is not to revert the thesis line back to Step 8.7, and not to reintroduce the entire historical directory. The goal is to verify whether the verified Step 8.7 lazy cascade can be exposed as a backend behind the Step 09 interface contract.

## What this is not

This is not a new algorithmic route. It does not add dual-center, V2/complex-gain, Step 8.10 unified model selection, or learning-based end-to-end DOA.

## Backend modes

```matlab
cfg.backend_mode = 'step09_light';
cfg.backend_mode = 'step87_reference';
```

`step09_light` keeps the current Step 09 reimplementation. `step87_reference` routes the same Step 09 inputs into a functionized lazy cascade backend.

## Bridge validation

The bridge validation compares both backend modes on the same Step 09 synthetic scenarios:

- `single_target_sanity`
- `close_coherent_pair`
- `medium_beta_pair`
- `weak_target_boundary`
- `near_antiphase_boundary`
- `large_el_pair`
- `two_separated_coarse_peaks`
- `center_wraparound_case`

The bridge outputs trial CSV, summary CSV, keypoints CSV, and a markdown report under `results_step09_step87_backend_bridge/`.

Current quick bridge result:

| metric | value |
|---|---:|
| `step87_backend_callable` | 1 |
| `total_trials` | 80 |
| `light_success_rate` | 0.25 |
| `ref_success_rate` | 0.25 |
| `success_gain_ref_minus_light` | 0 |
| `light_false_high_rate` | 0 |
| `ref_false_high_rate` | 0 |
| `light_boundary_missed_rate` | 0 |
| `ref_boundary_missed_rate` | 0 |
| `close_coherent_ref_success` | 0 |
| `large_el_ref_success` | 1 |
| `two_separated_ref_reject_rate` | 1 |
| `bridge_pass_flag` | 0 |
| `blocker_if_any` | `bridge_threshold_failed` |

## Interpretation

If `step87_reference` is callable and improves the close-coherent and large-elevation cases without worsening false-high or boundary-missed rates, then future formal MC should use `backend_mode='step87_reference'` as the validated backend implementation.

If the backend cannot be functionized, the report must keep `step87_reference_not_functionalized` as the blocker and proceed with candidate diagnostics rather than pretending success.

In the current quick bridge, the backend is callable but does not pass. The Step09-to-Step87 reference-frame adapter was corrected by mapping raw Step 09 local observations into the center-referenced Step 8.7 convention before the historical lazy cascade runs. After that adapter fix, the previous large-elevation collapse is resolved: `large_el_ref_success = 1`.

The remaining blocker is narrower: close-coherent cases still do not improve over the Step09 light backend. Diagnostics show that these trials often reach a low-confidence route because the common-elevation proxy gate is not satisfied strongly enough, even when the rank-1 score finds a finite close pair. Therefore the bridge is not adopted for downstream formal MC yet.

Recommended next step: run candidate diagnostics specifically on close-coherent route gates. Inspect level2 MUSIC peak count/width, refocus sharpness, rank1 residual/gap, and the common-el proxy condition before considering any threshold change.
