# Stage4 Cylindrical El-Separated Pair Beamspace ML Plan

## Positioning

Stage4 validates cylindrical-array el-separated pair beamspace ML. It extends Stage3 common-el 2D beamspace ML by allowing the two targets to have different elevations:

```text
Theta = [az1, az2, el_center, el_sep, orientation]
```

This is a controlled parameterization, not a fully unconstrained four-dimensional search over

```text
[az1, el1, az2, el2]
```

Stage4 is not AP, not a strong-coherence final validation, and not a final thesis conclusion.

## Signal Model

The local work-subarray snapshot model is

```text
Y = A_cyl(Theta) S + N
```

where

```text
Theta = [az1, el1, az2, el2]
A_cyl(Theta) = [a_cyl(az1, el1), a_cyl(az2, el2)]
```

## Controlled Elevation Separation

The Stage4 search constrains the pair as:

```text
az1 < az2
el_center = (el1 + el2) / 2
el_sep = |el2 - el1|
```

For `orientation = +1`:

```text
el1 = el_center - el_sep/2
el2 = el_center + el_sep/2
```

For `orientation = -1`:

```text
el1 = el_center + el_sep/2
el2 = el_center - el_sep/2
```

When `el_sep = 0`, this model reduces to the Stage3 common-el case. Stage4 therefore reports both the el-separated model and a common-el baseline.

## Beamspace Backend

The backend remains beam-level:

```text
Z = W' * Y
```

and the search manifold is reduced in beamspace:

```text
G(Theta) = W' * A_cyl(Theta)
```

No Stage4 main result may use element-domain ML directly on `Y_work`.

## Whitening And DML

Whitening is retained as a diagnostic:

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

The implementation uses regularized right-division rather than explicit matrix inversion.

## Stage3 Relationship

Stage3 common-el is the `el_sep = 0` special case. Stage4 must compare:

- whether the el-separated model improves joint success or elevation RMSE when true `el_sep > 0`;
- whether the el-separated model avoids false elevation splitting when true `el_sep = 0`;
- whether the extra search freedom introduces boundary hits or worse conditioning.

## Allowed Conclusion

Stage4 is only allowed to answer:

> Whether controlled el-separated pair beamspace ML can handle small elevation differences in the local cylindrical-array beamspace.

It is not allowed to answer:

> Full unconstrained 4D cylindrical-array two-target angle estimation is complete.

> Strongly coherent cylindrical-array two-target estimation has been solved.

> AP has been validated.
