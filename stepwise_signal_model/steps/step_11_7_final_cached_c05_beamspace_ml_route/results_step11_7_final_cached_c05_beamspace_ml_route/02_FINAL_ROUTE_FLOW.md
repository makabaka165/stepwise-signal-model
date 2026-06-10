# Final Route Flow

1. Receive frontend-like local input and shared-center local observation `Y_work`.
2. Validate `frontend_state`, selected center, and `Y_work` shape. Reshape `65x32xT` to `N_elements x T` when needed.
3. Use fixed `greedy_combined_B7` W and fixed C05 policy.
4. Validate Step11.6 cache metadata and exact-grid coverage.
5. Build `Z = W'Y_work`.
6. Run cached C05 pair2d beamspace ML, with direct fallback only when explicitly allowed and recorded.
7. Return estimate, confidence, boundary/cache/runtime/debug fields.

Pseudocode:

```matlab
v = validate_step11_7_backend_input(input, context);
Z = context.W' * v.Y;
out = cached_c05_search(Z, context.cache, input.coarseAz, input.coarseEl);
```
