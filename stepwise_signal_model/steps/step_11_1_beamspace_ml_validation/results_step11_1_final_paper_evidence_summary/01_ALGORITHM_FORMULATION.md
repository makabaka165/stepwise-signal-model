# Algorithm Formulation

The local cylindrical-array snapshot model is:

```text
Y = A_cyl(Theta) S + N
```

The beamspace observation is:

```text
Z = W'Y
```

The beamspace manifold is:

```text
G(Theta) = W'A_cyl(Theta)
```

The deterministic ML score is:

```text
J(Theta) = trace(P_G Z Z')
P_G = G(G'G)^(-1)G'
```

## Controlled Pair2D Parameterization

```text
az1 < az2
el_center = (el1 + el2) / 2
el_sep = |el2 - el1|
orientation in {+1, -1}
```

This parameterization is lower-dimensional than full4d while retaining small separated-elevation modeling.

## Full4D Upper-Bound Parameterization

```text
az1 < az2
el1 arbitrary local grid value
el2 arbitrary local grid value
```

Full4d is used as a local upper-bound comparison, not as the default final algorithm.