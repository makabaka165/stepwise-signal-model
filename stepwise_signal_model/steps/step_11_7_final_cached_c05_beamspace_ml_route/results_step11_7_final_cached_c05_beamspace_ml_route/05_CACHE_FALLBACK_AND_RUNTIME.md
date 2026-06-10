# Cache Fallback And Runtime

Cache miss/mismatch cases are explicitly recorded. Missing or mismatched cache metadata falls back to direct precompute only when `allow_cache_fallback=true`.

Fallback behavior pass: 1.

Fallback expected case pass rate: 1.000000.

Median final-route runtime reduction: 0.618403.

Runtime packaging pass: 1.

MATLAB caveat: total runtime includes function dispatch and DML scoring; functional correctness is not invalidated if total MATLAB runtime gain is limited.
