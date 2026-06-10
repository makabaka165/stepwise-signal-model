# Limitations And Usage Boundary

This is not a new ML model and does not modify the controlled pair2d DML score.

It does not modify Step11.5 C05 parameters, topK/window rules, or policy decisions.

Default lookup mode is exact grid lookup only. Non-grid interpolation is future work and is not part of the passing result.

The cache is valid only under shared-center canonical local order. Each actual working subarray must be reordered to the same 65-column by 32-layer order before using the cache.

W must match the canonical local order. If W carries absolute global-coordinate assumptions, rotate/reorder W and validate again.

If a cache miss occurs, the implementation records it and falls back to direct precompute; no silent interpolation is allowed.

No arbitrary full-field claim is made. Stage4 tested centers=6, passed centers=6, cross-center pass=1.
