# Complexity And Beamspace Dimension

The active cylindrical work subarray has `N_elem = 2080` elements.
Stage6 beam layouts use `B = 25` (`az5_el5`) or `B = 15` (`az5_el3`) beam channels, so the DML projection is evaluated in a much lower-dimensional beamspace.

Candidate-count scaling:

```text
common-el          ~ C(N_az, 2) * N_el
controlled pair2d  ~ C(N_az, 2) * N_el * N_sep * N_orientation_eff
full4d             ~ C(N_az, 2) * N_el^2
```

In Stage6, the measured full4d/pair2d runtime proxy ratio is `3.9589`.

Since Stage6 reports no success-rate gap between full4d and controlled pair2d in the main comparison subset, controlled pair2d is the better complexity-performance default. Full4d remains useful as an upper-bound diagnostic or future small-window refinement.