# Step11.7 Final Cached C05 Beamspace ML Route

Step11.7 is the final engineering entry point for the Step11 beamspace ML backend. It is not a new algorithmic innovation. It packages the already validated Step11 modules into one stable wrapper:

1. Step11.1 controlled pair2d beamspace ML score.
2. Step11.2 `greedy_combined_B7` W.
3. Step11.3 degree-based coarse-to-fine pair2d search.
4. Step11.5 fixed C05 likelihood-aware adaptive TopK/window policy.
5. Step11.6 shared-center canonical beamspace manifold cache.

## Goal

The final route accepts local shared-center observations, validates frontend-like state, builds `Z = W'Y_work`, runs the cached C05 beamspace ML backend, optionally compares a direct reference backend, and returns estimate, confidence, boundary, cache, runtime, and debug fields.

## Interface

Wrapper:

```matlab
out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, opts)
```

Input fields: `Y_work`, `frontend_state`, `coarseAz`, `coarseEl`, `rangeIdx`, `dopplerIdx`, `selectedCenterColumn`, `selectedCenterAz`, `method_tag`.

Context fields: `cfg`, `arrInfo` or `geometry`, `W`, `w_info`, `cache`, `cache_metadata`, `manifold_opts`, `search_opts`, `C05_policy_cfg`, `full_search_cfg`, `coarse_search_cfg`, `base_refine_cfg`, `lambda`, `phase_factor`, `phase_sign`.

Opts fields: `use_cache`, `run_direct_reference`, `allow_cache_fallback`, optional `truth_for_eval`, and `runtime_timing`.

Output fields include status, route/method names, cache/fallback flags, confidence, boundary flag, az/el estimate, C05 policy/window fields, pair counts, runtime fields, selected center fields, input/Z shape, debug, and error message.

## Run

From the `stepwise_signal_model` root:

```matlab
run('setup_paths.m')
run('steps/step_11_7_final_cached_c05_beamspace_ml_route/run_step11_7_final_cached_c05_beamspace_ml_route.m')
```

The runner fixes `rng(20260609,'twister')`, rebuilds or loads `greedy_combined_B7`, rebuilds or loads a Step11.6-compatible exact-grid canonical cache, fixes C05, and runs Stage1 through Stage5.

## Results

Outputs are written to:

`steps/step_11_7_final_cached_c05_beamspace_ml_route/results_step11_7_final_cached_c05_beamspace_ml_route/`

The result directory contains required CSV, MAT, PNG, Markdown, and log outputs.

## Pass/Fail

Overall Step11.7 passes only if interface smoke, cached/direct consistency, frontend prior bias recheck, cache fallback behavior, and required output fields all pass. Runtime packaging pass is reported but is not required for overall pass.

## Cache Fallback

Default lookup is exact grid lookup only. No interpolation is allowed. If cache metadata or exact-grid lookup fails and `allow_cache_fallback=true`, the backend records the miss/mismatch and falls back to direct precompute. If fallback is disabled, the backend returns low-confidence `cache_miss_error` or `cache_metadata_error`.

## Out-Of-Scope Handling

Supported frontend states are `single_peak_in_scope`, `unresolved_local_cluster`, and `controlled_pair2d_candidate`. Unsupported states such as `two_separated_peaks_out_of_scope`, `weak_secondary_candidate`, `invalid_input`, and `empty_detection` return low-confidence structured outputs rather than high-confidence ML estimates.

## Thesis Use

If Step11.7 passes, describe it as the final Step11 beamspace ML engineering entry point that combines Step11.5 C05 search-budget adaptation and Step11.6 canonical cache acceleration without changing the ML score, W, or C05 policy.
