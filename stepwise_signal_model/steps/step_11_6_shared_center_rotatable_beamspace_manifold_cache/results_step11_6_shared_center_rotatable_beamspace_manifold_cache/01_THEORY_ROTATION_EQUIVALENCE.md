# Rotation Equivalence Theory

Let the actual shared-center local subarray be `r_m(theta_c)=R_z(theta_c) r'_m` and the target direction be `u(theta_c+delta, el)=R_z(theta_c)u(delta, el)`. Then

`r_m(theta_c)^T u(theta_c+delta, el) = (R_z r'_m)^T(R_z u(delta, el)) = r'_m^T u(delta, el)`.

Therefore the element-domain steering vector at an actual center is numerically equal to the canonical steering vector at local delta azimuth when the 65-column by 32-layer order is the same.

The cached object stores `a_cache(delta,el)` implicitly through `G_cache(delta,el)=W'a_cache(delta,el)`. It is valid only when W corresponds to the canonical local order. If W encodes an absolute global-coordinate ordering, the array data and W must be rotated/reordered together and verified again.
