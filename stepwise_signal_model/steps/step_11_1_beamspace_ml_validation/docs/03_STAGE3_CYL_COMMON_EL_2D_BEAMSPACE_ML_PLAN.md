# Stage3 Cylindrical Common-El 2D Beamspace ML Plan

## Positioning

Stage3 validates cylindrical-array common-elevation 2D beamspace ML. It extends Stage2 fixed-elevation az-only search by treating `el_common` as an unknown search variable:

```text
Theta = [az1, az2, el_common]
```

It is still not the full four-dimensional pair search

```text
[az1, el1, az2, el2]
```

and it is not AP, not a strong-coherence final validation, and not a final thesis conclusion. It is the intermediate bridge between az-only beamspace ML and full cylindrical 2D pair estimation.

## Signal Model

The local work-subarray snapshot model is

```text
Y = A_cyl(Theta) S + N
```

where

```text
Theta = [az1, az2, el_common]
A_cyl(Theta) = [a_cyl(az1, el_common), a_cyl(az2, el_common)]
```

## Cylindrical Steering

The unit direction vector is

```text
u(az, el) = [cos(el)cos(az), cos(el)sin(az), sin(el)]^T
```

For element position

```text
p_m = [x_m, y_m, z_m]^T
```

the steering vector is

```text
a_cyl(az, el) = exp(j * phase_sign * phase_factor * 2*pi/lambda * p_m^T u(az, el))
```

This stage uses the same `phase_sign` and `phase_factor` for data generation, beam construction, and ML search so that the validation is internally consistent.

## Beamspace Backend

The backend remains beam-level:

```text
Z = W' * Y
```

and the search manifold is reduced in the same beamspace:

```text
G(Theta) = W' * A_cyl(Theta)
```

No Stage3 main result may use an element-domain projection on `Y_work` and `A_cyl` directly.

## Whitening

Two beamspace modes are retained:

```text
whitening_mode = "none"
whitening_mode = "white"
```

For whitening:

```text
Cb = W' * W
Z_w = Cb^(-1/2) Z
G_w = Cb^(-1/2) G
```

The DML score is

```text
J(Theta) = trace(P_G Z Z')
```

or after whitening:

```text
J(Theta) = trace(P_Gw Z_w Z_w')
```

where the implementation uses regularized right-division instead of an explicit inverse.

## Allowed Conclusion

Stage3 is only allowed to answer:

> Under a common-elevation assumption, can cylindrical-array beamspace ML jointly estimate an azimuth pair and one common elevation?

It is not allowed to answer:

> Full 4D cylindrical-array two-target angle estimation is complete.

> Strongly coherent cylindrical-array two-target estimation has been solved.

> AP has been validated.
