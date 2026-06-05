W selection theory
==================

Local dictionary
----------------

Build a local cylindrical-array steering dictionary:

```text
A_patch = [a_cyl(az_i, el_j)]
```

The patch is centered at the Step11.1 working center and covers the local
angular region used by the pair2d backend.

Projection loss
---------------

For a candidate W:

```text
P_W = W (W'W)^(-1) W'
L_proj = ||A_patch - P_W A_patch||_F / ||A_patch||_F
```

Smaller projection loss means W preserves more local manifold energy.

Beamspace manifold correlation
------------------------------

For a local two-target test pair:

```text
g1 = W' a(theta1)
g2 = W' a(theta2)
corr = |g1' g2| / (||g1|| ||g2||)
```

Stage1 reports mean, median, p90, and max correlation across a fixed local
pair set.

Condition metrics
-----------------

Step11.2 records:

```text
cond_WHW = cond(W'W)
cond_GHG = cond(G'G)
```

`cond_GHG` is evaluated over local two-target pair tests in Stage1 and over
the selected backend candidate in Stage2.

SVD upper bound
---------------

The local dictionary SVD is:

```text
A_patch = U S V'
W_svd = U(:, 1:B)
```

`W_svd` is an information-retention upper bound. It is not treated as a direct
FPGA or engineering beam implementation.

Greedy pool selection
---------------------

Greedy selection chooses B columns from an existing or compatible 2D beam
pool. The combined objective is:

```text
score = alpha * projection_loss
      + beta  * max_corr
      + gamma * log10(cond_WHW)
```

Default weights are:

```text
alpha = 1.0
beta  = 1.0
gamma = 0.05
```

Random selection is only a sanity baseline.

