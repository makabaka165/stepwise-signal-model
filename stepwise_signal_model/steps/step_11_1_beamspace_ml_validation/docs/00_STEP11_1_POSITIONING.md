# Step11.1 Positioning

## Relation To Step11

The existing Step11 route already contains the beamspace ML idea:

- Snapshot data are mapped from element space to beamspace.
- The element-domain manifold `A_e(Theta)` is mapped to a beamspace manifold `A_B(Theta)`.
- The deterministic ML score uses a `max trace(P_A R)` criterion.
- The current boshu route uses two-dimensional grid enumeration, not AP.

Step11.1 does not replace those files. It adds an independent validation folder that checks whether the one-dimensional ULA beamspace ML result is robust to prior weakening.

## Stage1 Boundary

Stage1 does not evaluate cylindrical arrays. It does not evaluate AP. It only evaluates whether the original Step11 ULA beamspace ML route is too dependent on:

- left/right partitioning around `beam_c`;
- `beam_c` being exactly the true two-target center;
- estimates landing close to the search-window boundary.

The new code writes the beamspace relation as `Z = W' * Y` and `G(Theta) = W' * A(Theta)`, which is the standard complex-signal convention. Older Step11 expressions such as `A1.' * steering_vector_s` and `temp1 * A` use a different storage orientation. After transposing the stored vectors/matrices into the convention used here, the physical mapping is the same: an element-domain observation/manifold is projected into beamspace. Stage1 keeps this notation explicit and performs dimension checks in every helper.

## Allowed Conclusion

Step11.1 Stage1 is only allowed to answer:

> Whether one-dimensional ULA beamspace ML is overly dependent on left/right partitioning and true-center priors.

It is not allowed to answer:

> Cylindrical-array beamspace ML has been completed.

> Strongly coherent cylindrical-array two-target estimation has been solved.

> AP is already usable.
