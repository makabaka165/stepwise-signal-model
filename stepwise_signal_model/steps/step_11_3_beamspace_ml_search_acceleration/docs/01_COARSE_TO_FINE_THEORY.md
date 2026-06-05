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

Elevation separation must be a physical angular parameter, not a grid-index
offset. The old index-based form used `el_sep_index_list` and mapped
`iEl1 = iElCenter - sep_index`, `iEl2 = iElCenter + sep_index`. That made the
actual physical separation depend on the current elevation grid step:

- full fine `el_step=0.12`, `sep_index=2` -> `el_sep=0.48` deg;
- coarse `el_step=0.24`, `sep_index=2` -> `el_sep=0.96` deg;
- refine `el_step=0.06`, `sep_index=2` -> `el_sep=0.24` deg.

This means full, coarse, and refine stages were not searching the same
physical hypothesis family. Step11.3 now uses degree-based lists:
`el_sep_deg_list` for full/coarse grids and `fine_el_sep_deg_list` for local
refine. For each candidate,

```text
orientation = +1:
  el1 = el_center - el_sep_deg/2
  el2 = el_center + el_sep_deg/2

orientation = -1:
  el1 = el_center + el_sep_deg/2
  el2 = el_center - el_sep_deg/2
```

When `el_sep_deg = 0`, only one orientation is retained to avoid duplicate
same-elevation candidates. The ML objective is unchanged; only the controlled
pair2d candidate parameterization is corrected.

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
- refine windows too wide or topK too large can erase the complexity reduction;
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
