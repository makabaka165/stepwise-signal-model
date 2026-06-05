# Algorithm logic and formulation

The fixed data model is

```text
Y = A_cyl(Theta) S + N
Z = W'Y
G(Theta) = W'A_cyl(Theta)
J(Theta) = trace(P_G Z Z')
P_G = G (G'G)^(-1) G'
```

Each `Theta` is one angle candidate pair state evaluated by the same controlled pair2d beamspace ML score. The full fine grid enumerates every fine-grid `Theta` inside the local search region.

The coarse-to-fine strategy first evaluates a coarser candidate grid, keeps the topK coarse ML-score candidates, constructs local refine windows around those retained candidates, and evaluates fine candidates only inside those windows.

The degree-based `el_sep` parameterization is necessary because elevation separation is a physical angular separation. Using an index-based separation can silently mix grid index spacing with physical degrees and can make coarse topK behavior inconsistent with the full fine baseline.

The ML model and score are unchanged. Only the number and ordering of candidate angle evaluations are changed.
