# Stage2 Cylindrical Az-Only Beamspace ML Plan

## Positioning

Stage2 is the minimal cylindrical-array migration of the Step11.1 beamspace ML validation. It reuses the current project geometry from `sim_cfg.m` and `arr_cyl.m`. The full cylindrical array has `Naz x Nel = 192 x 32` elements, while the active local work subarray selected by `arr_cyl` is `subNaz x Nel = 65 x 32`.

This stage fixes elevation at `el0` and estimates only two azimuths, `az1` and `az2`. It is not a complete 2D az/el estimator, it is not AP, and it is not a final thesis conclusion.

The key validation questions are:

- whether the cylindrical 3D steering model can form a consistent beamspace manifold;
- whether the low-dimensional beam snapshots `Z` retain two-target azimuth identifiability;
- how `beam_count`, SNR, azimuth separation, and simulated front-end center bias affect success rate and RMSE;
- whether beamspace whitening is necessary;
- whether `boundary_hit` remains a risk indicator.

`beam_c = az_center_true + center_bias` is used here as a controlled simulation of front-end coarse-center error. It must not be interpreted as using target truth in an engineering pipeline.

## Cylindrical Steering

The unit direction vector is

```text
u(az, el) = [cos(el)cos(az), cos(el)sin(az), sin(el)]^T
```

For element position

```text
p_m = [x_m, y_m, z_m]^T
```

the cylindrical steering vector is

```text
a_cyl(az, el) = exp(j * phase_sign * phase_factor * 2*pi/lambda * p_m^T u(az, el))
```

`phase_factor` defaults to `cfg.beam.spatialPhaseFactor`, and this stage uses `phase_sign = +1`. The snapshot generator and ML manifold search use the same `phase_sign` and `phase_factor` so that the Stage2 sanity check is internally consistent. Alignment with the full LFM echo-chain phase convention should be checked separately in a later phase.

## Beamspace Model

The backend is beam-level only:

```text
Z = W' * Y_work
```

The search manifold is reduced with the same transform:

```text
G(az1, az2) = W' * [a_cyl(az1, el0), a_cyl(az2, el0)]
```

No Stage2 main result may compute the DML projection directly with `Y_work` and the element-domain `A_cyl_pair`.

## Whitening

Two beamspace modes are evaluated:

```text
whitening_mode = "none"
whitening_mode = "white"
```

For whitening:

```text
C_b = W' * W
Z_w = C_b^(-1/2) Z
G_w = C_b^(-1/2) G
```

The DML score is

```text
J = trace(P_G Z Z')
```

or, after whitening,

```text
J = trace(P_Gw Z_w Z_w')
```

where

```text
P_G = G * inv(G' * G) * G'
```

The implementation uses regularized right-division rather than an explicit inverse.
