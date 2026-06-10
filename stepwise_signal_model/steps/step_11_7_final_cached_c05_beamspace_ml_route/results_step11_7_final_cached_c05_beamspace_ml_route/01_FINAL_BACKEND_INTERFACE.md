# Final Backend Interface

Function: `out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, opts)`.

Input fields: `Y_work`, `frontend_state`, `coarseAz`, `coarseEl`, `rangeIdx`, `dopplerIdx`, `selectedCenterColumn`, `selectedCenterAz`, `method_tag`.

Context fields: `cfg`, `arrInfo` or `geometry`, `W`, `w_info`, `cache`, `cache_metadata`, `manifold_opts`, `search_opts`, `C05_policy_cfg`, `full_search_cfg`, `coarse_search_cfg`, `base_refine_cfg`, `lambda`, `phase_factor`, `phase_sign`.

Opts fields: `use_cache`, `run_direct_reference`, `allow_cache_fallback`, optional `truth_for_eval`, and `runtime_timing`.

Output fields include status, route/method names, cache/fallback flags, confidence, boundary flag, az/el estimates, C05 policy/window fields, pair counts, runtime, input/Z shapes, debug, and error message.

Unsupported frontend states return `out_of_scope` with low confidence and do not run high-confidence ML.
