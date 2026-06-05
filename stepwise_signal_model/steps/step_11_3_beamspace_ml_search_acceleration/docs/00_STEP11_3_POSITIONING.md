Step11.3 positioning
====================

Step11.1 established controlled pair2d beamspace ML as the main backend.
Step11.2 established `greedy_combined_B7` as the current W recommendation.

Step11.3 addresses the remaining backend cost: angle-candidate enumeration.
The full fine controlled pair2d search evaluates many candidates:

```text
C(N_az, 2) * N_el * N_sep * N_orientation_eff
```

Coarse-to-fine reduces the candidate count by scoring a coarse grid first,
keeping topK coarse candidates, then refining only local fine windows:

```text
C(N_az_coarse, 2) * N_el_coarse * N_sep * N_orientation_eff
+ topK * N_local_refine
```

The ML objective and W are unchanged. The innovation is the solver schedule and
candidate-count reduction.

This step does not claim AP validation, a complete engineering loop, a
full4D replacement, or that every hard coherent/weak-target case is solved.

