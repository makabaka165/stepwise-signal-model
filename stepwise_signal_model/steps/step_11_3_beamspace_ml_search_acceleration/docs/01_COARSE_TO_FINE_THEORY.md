Coarse-to-fine theory
=====================

Beamspace DML model:

```text
Y = A_cyl(Theta) S + N
Z = W' Y
G(Theta) = W' A_cyl(Theta)
J(Theta) = trace(P_G Z Z')
P_G = G (G'G)^(-1) G'
```

Controlled pair2d parameters:

- `az1 < az2`
- `el_center`
- `el_sep`
- `orientation`

Full fine grid enumerates all candidates on the fine az/el grid. Coarse-to-fine
does the same scoring function in two passes:

1. score a coarse grid;
2. keep topK coarse candidates;
3. build local fine grids around each coarse candidate;
4. rescore and choose the maximum DML score.

Risks:

- topK too small can miss the full-grid optimum;
- coarse grid too sparse can shift the local windows;
- refine windows too narrow can miss the peak;
- frontend prior bias can move the true targets outside the local search
  window.

Metrics:

- joint success rate;
- RMSE;
- worst-case success;
- `num_pairs`;
- complexity reduction ratio;
- full-grid match rate;
- topK miss rate;
- boundary-hit rate.

