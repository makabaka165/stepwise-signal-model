# Stage5 Cylindrical Coherence Stress Plan

## Positioning

Stage5 is a stress validation for the Stage4 el-separated pair beamspace ML model. It keeps the same controlled pair parameterization and uses coherence, strong coherence, small phase difference, small angular separation, weak secondary targets, SNR, beam layout, and whitening mode as pressure variables.

Stage5 is not a new main model line, not AP, not a full final thesis conclusion, and not a claim that all strongly coherent cases are solved. The allowed output is a boundary map: which combinations remain usable under the current beam layout and search window, and which combinations should be treated as difficult, low-confidence, or boundary-risk cases.

## Correlated Source Model

Given the first source `s1(t)` and an independent component `u2(t)`, Stage5 constructs the second source as:

```text
s2(t) = beta * [rho * exp(j*phi) * s1(t) + sqrt(1-rho^2) * u2(t)]
```

where:

- `rho = 0` is the noncoherent or weakly correlated baseline.
- `rho -> 1` is the strongly coherent limit.
- `phi` is the phase difference between the two target signals.
- `beta` is the second target amplitude ratio.

For the special case `rho = 1`:

```text
s2(t) = beta * exp(j*phi) * s1(t)
```

The implementation records both the construction parameter `rho` and the finite-snapshot empirical correlation.

## Pressure Variables

Stage5 sweeps:

- source coherence `rho`;
- phase difference `phi`;
- amplitude ratio `beta`;
- azimuth separation `az_sep`;
- elevation separation `el_sep`;
- SNR;
- beam layout;
- whitening mode.

The main model is `pair2d`, which is the Stage4 controlled el-separated pair search. The `common_el_restricted` model is retained only as a baseline.

## Beamspace Backend

All main ML results remain in beamspace:

```text
Z = W' * Y_work
```

and the search manifold is also beamspace:

```text
G(Theta) = W' * [a_cyl(az1, el1), a_cyl(az2, el2)]
```

The DML score is:

```text
J(Theta) = trace(P_G * Z * Z')
```

Whitening is a diagnostic branch:

```text
Cb = W' * W
Z_w = Cb^(-1/2) Z
G_w = Cb^(-1/2) G
```

No Stage5 main result may use element-domain ML directly on `Y_work`.

## Recorded Diagnostics

Stage5 records:

- joint success;
- azimuth RMSE;
- elevation RMSE;
- elevation-separation error;
- false elevation split;
- boundary hit;
- truth manifold correlation;
- pair2d-minus-common score margin;
- whitening effect.

The current `false_high_like_rate` is only a risk proxy: a trial is counted when joint tolerance fails, the pair2d score is above the common-el score, and no boundary hit is detected. It is not a final confidence metric.

## Pass Interpretation

Stage5 does not require all strongly coherent cases to pass. The pass flag only checks that the moderate-coherence subset remains usable and that obvious boundary or false-split risks stay bounded:

- for `pair2d + white + bias0 + snr30`, mean joint success for `rho <= 0.9` should be at least `0.75`;
- for true `el_sep = 0`, false split rate should be at most `0.2`;
- across all `pair2d + white` cases, maximum boundary-hit rate should be at most `0.3`.

Strong coherence cases with `rho >= 0.99` are reported as degradation-boundary evidence, not as mandatory full-success evidence.

## Allowed Conclusion

Stage5 may conclude:

> Under the current beam layout and search window, specific `rho`, `phase`, `beta`, `sep`, and SNR combinations remain reliable, while others enter an unreliable or boundary-risk region.

Stage5 must not conclude:

> Strong coherence is completely solved.

> All coherent scenarios are reliable.

> The final engineering algorithm is closed.
