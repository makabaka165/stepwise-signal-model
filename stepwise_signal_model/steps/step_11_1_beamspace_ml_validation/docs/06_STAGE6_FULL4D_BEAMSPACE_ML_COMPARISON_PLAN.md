# Stage6 Full4D Beamspace ML Comparison Plan

## Positioning

Stage6 adds a local full4d beamspace ML comparison as an upper-bound reference for the Stage4/Stage5 controlled pair2d model. It is not the final main algorithm, not AP, and not an engineering confidence-boundary closure.

Stage6 answers one narrow question:

```text
How large is the performance gap between controlled pair2d and local unconstrained full4d beamspace ML?
```

The default interpretation is that full4d is an upper-bound comparison. It should become a main algorithm only if it clearly improves controlled pair2d and the added complexity is acceptable.

## Compared Routes

1. `common_el_restricted`

```text
Theta = [az1, az2, el_common]
```

2. `controlled_pair2d`

```text
Theta = [az1, az2, el_center, el_sep, orientation]
```

This is the controlled el-separated parameterization used in Stage4 and Stage5.

3. `full4d`

```text
Theta = [az1, el1, az2, el2]
```

Only `az1 < az2` is enforced. `el1` and `el2` are arbitrary local-grid values.

## Beamspace ML Formulation

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

The DML score is:

```text
J(Theta) = trace(P_G Z Z')
P_G = G(G'G)^(-1)G'
```

No Stage6 main result may run ML directly in the element domain.

## Full4D Local Search

The full4d grid search is:

```text
az1_idx < az2_idx
el1_idx in all local el grid
el2_idx in all local el grid
```

This is a local search around the coarse front-end center, not a full-space search. The default implementation does not save a giant 4D score tensor; it records only the best score and a small optional top-candidate list.

## Complexity

Let:

```text
N_az = number of local az grid points
N_el = number of local el grid points
B    = number of beam channels
N    = number of active array elements
```

The element-domain manifold has dimension `N`, while the beamspace manifold has dimension `B`, with `B << N`. In the current cylindrical work subarray, `N = 2080`; typical Stage6 layouts use `B = 25` or `B = 15`.

Candidate counts are approximately:

```text
common-el:          C(N_az, 2) * N_el
controlled pair2d: C(N_az, 2) * N_el * N_sep * N_orientation_eff
full4d:            C(N_az, 2) * N_el^2
```

The controlled pair2d route lowers complexity by replacing arbitrary `(el1, el2)` combinations with a small set of symmetric local elevation separations and orientations. If controlled pair2d stays close to full4d in success rate and RMSE, it is the better complexity-performance tradeoff.

## Allowed Conclusion

Stage6 may conclude:

```text
full4d is only an upper-bound comparison, and controlled pair2d is sufficient under the tested local scenarios.
```

or:

```text
full4d improves specific hard cases and should be documented as future local refinement work.
```

Stage6 must not conclude that AP has been validated, that confidence boundary is complete, or that full4d is the default main algorithm without evidence and complexity justification.
