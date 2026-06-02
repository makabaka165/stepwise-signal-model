# Modeling Improvement Plan from Coherent-MUSIC Literature

## 1. Current Model Position

The current Step 8.7-8.10 result should remain a conservative engineering cascade:

`frontend single coarse peak -> shared-center local subarray -> Y_work -> route dispatch -> MUSIC / rank1 fallback / common-el refocus / 2D MUSIC / boundary output`.

Do not replace this with a single residual-scored model selector. Step 8.10 already showed that direct H1/H2/H3/H0 residual model selection is unsafe.

The literature should be used to improve the covariance model, route diagnostics, and branch-specific rank restoration.

## 2. A Better Mathematical Framing

Keep the physical source model:

```text
x(t) = A(theta, el) s(t) + n(t)
s2(t) = beta * exp(j phi) * (rho s1(t) + sqrt(1-rho^2) v(t))
Rxx = A Rs A^H + sigma^2 I
```

For coherent sources, `Rs` is rank-deficient or nearly rank-deficient. Instead of asking one global model selector to solve all cases, define branch-specific covariance restoration operators:

```text
R_route = D_route(Rxx)
```

where `D_route` can be:

- `D_fbss`: forward/backward spatial smoothing for level-2 MUSIC;
- `D_refocus`: common-elevation refocus followed by level-2 rank1 fallback;
- `D_2d`: 2D subarray smoothing/differencing for large elevation separation;
- `D_toeplitz`: Toeplitz/covariance reconstruction for close coherent sources;
- `D_cross`: cross-covariance or equivalent covariance reconstruction from array partitions.

Then route selection is based on observable diagnostics of the restored covariance, not only on residual error.

## 3. Improvement Route A: Toeplitz-Reconstructed Level-2 MUSIC

Purpose: improve Branch A/B around close coherent pairs before falling back to rank1.

Idea:

1. Use the already constructed level-2 data `Y_level2` or focused `Y_q(t)`.
2. Estimate sample covariance `R = YY^H / T`.
3. In the local shared-center `Delta theta` coordinate, approximate the 65-column arc as a local ULA only inside a narrow ROI.
4. Reconstruct a Hermitian Toeplitz covariance by diagonal averaging or structured fitting.
5. Run MUSIC/root-MUSIC on the reconstructed covariance.
6. Use it as an optional route:

```text
if regular MUSIC is unreliable and Toeplitz-restored MUSIC gives stable two peaks:
    use toeplitz_restored_music
else:
    continue to rank1/refocus cascade
```

Expected benefit:

- May recover rank in coherent close-pair cases without full 2D search.
- Can reduce false single-peak behavior before rank1 fallback.

Risk:

- The cylindrical arc is only locally ULA-like. Restrict this to small `Delta theta` and validate against true cylindrical steering.

Recommended experiment:

`Step 8.12A toeplitz_restored_level2_music_validation`

Metrics:

- close coherent success;
- route agreement with Step 8.7 baseline;
- false-high rate;
- boundary-missed rate;
- runtime;
- failure cases when local ULA approximation is invalid.

## 4. Improvement Route B: 2D Smoothed/Differenced Covariance for Large-El Branch

Purpose: improve Branch C, especially large-elevation or layer-2 compression failure cases.

Idea:

1. Keep the 65 x 32 cylindrical observation.
2. Build 2D overlapping subarrays over column and layer dimensions.
3. Apply 2D FBSS or a spatial-differencing covariance operator before 2D MUSIC.
4. Run 2D MUSIC only inside the shared-center ROI.
5. Pair-local refinement remains optional after the 2D peaks.

Expected benefit:

- More literature-consistent coherent-source 2D route.
- May improve large-el separation and low-SNR 2D branch stability.

Risk:

- Extra smoothing reduces effective aperture.
- Full 2D grid remains expensive.

Recommended experiment:

`Step 8.12B improved_2d_smoothing_branch_validation`

Metrics:

- large-el success;
- 2D peak count stability;
- pair-local trigger rate;
- p90/p95 runtime;
- effect on near anti-phase and weak-target boundaries.

## 5. Improvement Route C: Cross-Covariance Refocus for Common-El Branch

Purpose: make common-el refocus more robust and less dependent on a single power peak.

Idea:

Borrow the cross-covariance/equivalent-covariance idea from 2D coherent-source literature:

1. Partition the 65 x 32 local array into two or more overlapping column/layer blocks.
2. Use cross-correlation matrices between blocks, or between different reference layers/columns.
3. Construct an equivalent covariance whose coherent components are less rank-collapsed.
4. Estimate `el_hat` from this reconstructed covariance.
5. Feed `el_hat` into the existing common-el refocus + rank1 fallback.

Expected benefit:

- More stable `el_hat` when plain power refocus is flat or ambiguous.
- Could reduce refocus-stage route flips observed in Step 8.9E.

Risk:

- Cross-covariance construction must respect cylindrical geometry and snapshot alignment.
- More metrics mean more calibration burden.

Recommended experiment:

`Step 8.12C crosscov_common_el_refocus_validation`

Metrics:

- common-el close-pair success;
- `el_hat` error;
- refocus sharpness;
- rank1 score-gap stability;
- fixed-point route-equivalence under `y16_coeff24_all`.

## 6. Improvement Route D: Synthetic Aperture / Multi-CPI Augmentation

Purpose: borrow the "moving array / enlarged aperture" idea without physically moving the array.

Possible local equivalent:

- combine adjacent CPI observations if the target cluster is stable;
- combine adjacent shared-center selections if the coarse center drifts slowly;
- use tracking prediction to accumulate multiple local `Y_work` blocks after phase/Doppler alignment.

Expected benefit:

- Better low-SNR and weak-target behavior;
- more snapshots and a larger effective aperture.

Risk:

- Requires motion/phase compensation and target stationarity.
- Can be invalid under fast target motion or Doppler mismatch.

Recommended status:

Future work, not immediate mainline.

## 7. Improvement Route E: Replace Step 8.10 with Evidence-Gated Selection, Not Residual-Only Selection

Step 8.10 failed because unified residual scoring selected physically wrong models and introduced false-high outputs.

Better replacement:

Construct an evidence vector:

```text
z = [
  music_peak_count,
  music_peak_separation,
  peak_prominence,
  eig_rank_proxy,
  fbss_rank_gain,
  refocus_power_sharpness,
  refocus_lambda1_sharpness,
  rank1_residual_norm,
  rank1_score_gap,
  rank1_pair_sep,
  toeplitz_reconstruction_residual,
  crosscov_consistency,
  music2d_peak_count,
  music2d_el_sep,
  pair_local_residual,
  route_margin_min
]
```

Then keep a constrained cascade:

```text
if evidence supports reliable 2D separation:
    Branch C
elif evidence supports reliable regular MUSIC:
    Branch A
elif evidence supports common-el coherent close pair:
    Branch B
elif evidence supports rank1 fallback:
    rank1 fallback
else:
    low_confidence / boundary_unreliable
```

This keeps the safety behavior of Step 8.7 while making the gates more literature-informed.

## 8. Fixed-Point Modeling Improvement

Step 8.9E showed fixed-point divergence mainly around refocus metrics and candidate ties.

Use this in the model:

- store normalized and unnormalized rank1/refocus metrics;
- avoid thresholds on raw score alone;
- add candidate-tie flags when top candidates are too close;
- define an uncertainty zone that lowers confidence only for boundary-risk samples;
- keep steering/template/cache at higher precision than `Y_work`;
- keep EVD and route decision on software/floating-point side for the first hardware version.

Do not claim full fixed-point closure until route-equivalence and output-equivalence pass.

## 9. Recommended Priority

1. `Step 8.12A`: Toeplitz-restored level-2 MUSIC, because it is narrow and directly targets close coherent pairs.
2. `Step 8.12C`: Cross-covariance common-el refocus, because it targets the Step 8.9E refocus route-flip blocker.
3. `Step 8.12B`: Improved 2D smoothing branch, because large-el already works but may need runtime/robustness improvement.
4. Evidence-gated Step 8.10 replacement, after 8.12A-C provide new diagnostics.
5. Multi-CPI/synthetic aperture and weak-target SIC, as future work.

## 10. Thesis Position

The literature supports writing the algorithm as:

`A shared-center local enhanced DOA chain for unresolved coherent target clusters, combining MUSIC-family rank restoration, common-elevation refocus, 2D coherent-source processing, and conservative observable dispatch.`

Avoid writing:

`A universal MUSIC improvement for all coherent sources.`
