# Step11.6 One-Page Summary

Method name: Shared-Center Rotatable Beamspace Manifold Cache for Cylindrical-Array Beamspace ML.

Positioning: Step11.5 C05 reduces candidate count; Step11.6 keeps the same ML score and candidates but accelerates reusable manifold construction through exact canonical cache lookup.

Fixed assumptions: shared-center canonical local order, W=greedy_combined_B7 on canonical order, exact grid lookup, no interpolation, no truth-assisted search center or policy decision.

Key metrics: manifold_pass=1, search_pass=1, cross_center_pass=1, runtime_manifold_pass=1, runtime_search_pass=1, overall_pass=1.

Max errors: max_rel_a=3.82e-14, max_rel_G=3.23e-14, max_relative_score_diff=8.3e-16, cache_miss_count=0.

Final recommendation: `use_canonical_beamspace_manifold_cache_as_default_for_step11_5_c05_runtime_acceleration`.
