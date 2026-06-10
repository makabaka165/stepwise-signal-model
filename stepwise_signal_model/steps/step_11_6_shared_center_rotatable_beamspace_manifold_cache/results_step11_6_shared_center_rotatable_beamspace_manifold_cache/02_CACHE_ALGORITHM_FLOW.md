# Cache Algorithm Flow

Offline build:
1. Build canonical shared-center geometry at the nearest 0 deg physical column.
2. Build Step11.2 `greedy_combined_B7` W on canonical local order.
3. Precompute `G(delta_az,el)=W'A_cyl(delta_az,el)` on the union exact grid needed by Stage1, coarse search, and local refine.

Online exact lookup:
1. Snap the requested center to the actual column center.
2. Reorder the actual working subarray to canonical local order.
3. Convert global azimuth grid to `delta_az=az-actual_center_az`.
4. Exact lookup cached G. Missing grid points are recorded and may fall back to direct precompute; no interpolation is used by default.

Pseudocode:

```matlab
cache = build_step11_6_canonical_beamspace_cache(W, geom0, delta_grid, el_grid, lambda);
G = lookup_step11_6_beamspace_cache(cache, az_grid, el_values, 'CenterAzDeg', center);
score = controlled_pair2d_dml_score(Z, G); % unchanged Step11.3 score path
```
