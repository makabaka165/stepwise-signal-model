function out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, opts)
%STEP11_7_FINAL_CACHED_C05_BEAMSPACE_ML_BACKEND Final cached C05 backend wrapper.
%
% The wrapper validates frontend-like local input, constructs Z=W'*Y_work,
% runs the Step11.5 C05 adaptive backend through the Step11.6 exact-grid
% cache, and records fallback/debug/runtime fields.

if nargin < 3
    opts = struct();
end
opts = fill_opts_local(opts);
total_tic = tic;
out = step11_7_make_backend_output();
out.used_cache = logical(opts.use_cache);

validation = validate_step11_7_backend_input(input, context);
out.selectedCenterColumn = safe_input_field_local(input, 'selectedCenterColumn', NaN);
out.selectedCenterAz = safe_input_field_local(input, 'selectedCenterAz', NaN);
out.input_shape = validation.input_shape;
out.debug.validation = validation;
if ~validation.valid
    out.status = validation.status;
    out.confidence = 'low';
    out.boundary_flag = validation.boundary_flag;
    out.error_message = validation.error_message;
    out.used_cache = false;
    out.cache_miss_count = 0;
    out.runtime_total_sec = toc(total_tic);
    return;
end

cache_check = validate_cache_metadata_local(context);
use_cache_now = opts.use_cache && cache_check.cache_valid;
if opts.use_cache && ~cache_check.cache_valid
    if opts.allow_cache_fallback
        use_cache_now = false;
        out.fallback_used = true;
        out.used_cache = false;
        out.debug.cache_validation = cache_check;
    else
        out.status = 'cache_metadata_error';
        out.confidence = 'low';
        out.boundary_flag = 'cache_metadata_mismatch';
        out.cache_miss_count = 1;
        out.fallback_used = false;
        out.error_message = cache_check.error_message;
        out.debug.cache_validation = cache_check;
        out.runtime_total_sec = toc(total_tic);
        return;
    end
end

try
    search_tic = tic;
    geom = build_step11_6_canonical_geometry(context.cfg, input.selectedCenterAz);
    [grid_cfg_coarse, base_refine_cfg] = make_search_configs_local(input.coarseAz, input.coarseEl, context);
    Z = context.W' * validation.Y;
    if use_cache_now
        manifold_opts = context.manifold_opts;
        manifold_opts.actual_center_az_deg = geom.actual_center_az_deg;
        search_opts = context.search_opts;
        search_opts.cache_fallback_direct = logical(opts.allow_cache_fallback);
        [~, score_info_cached, coarse_cached0] = search_pair2d_degree_grid_cached(Z, context.W, geom.x_actual, geom.y_actual, geom.z_actual, ...
            context.lambda, grid_cfg_coarse, manifold_opts, search_opts, context.cache, 'ReturnTopK', true, 'TopK', context.C05_policy_cfg.topK_max);
        coarse_cached = make_cached_coarse_debug_local(coarse_cached0, context.C05_policy_cfg.topK_max);
        [est, debug] = search_pair2d_adaptive_c05_cached(Z, context.W, geom.x_actual, geom.y_actual, geom.z_actual, ...
            context.lambda, grid_cfg_coarse, base_refine_cfg, manifold_opts, search_opts, context.C05_policy_cfg, context.cache, ...
            score_info_cached.top_candidates, coarse_cached);
        out.used_cache = ~logical(debug.direct_fallback_used);
        out.fallback_used = logical(debug.direct_fallback_used);
        out.cache_miss_count = debug.cache_miss_count;
        out.runtime_cache_lookup_sec = debug.cached_lookup_time_sec;
    else
        direct_opts = struct('runtime_timing', opts.runtime_timing);
        direct_out = step11_7_direct_reference_c05_backend(input, context, direct_opts);
        out = copy_direct_to_cached_out_local(out, direct_out);
        out.fallback_used = opts.use_cache;
        out.used_cache = false;
        out.debug.cache_validation = cache_check;
        out.runtime_search_sec = direct_out.runtime_search_sec;
        out.runtime_total_sec = toc(total_tic);
        return;
    end
    out.runtime_search_sec = toc(search_tic);
    out = fill_success_output_local(out, est, debug, input, validation, Z);
catch ME
    if opts.use_cache && opts.allow_cache_fallback && contains(lower(ME.message), 'cache')
        direct_out = step11_7_direct_reference_c05_backend(input, context, struct('runtime_timing', opts.runtime_timing));
        out = copy_direct_to_cached_out_local(out, direct_out);
        out.status = direct_out.status;
        out.used_cache = false;
        out.fallback_used = true;
        out.cache_miss_count = max(1, finite_or_zero_local(direct_out.cache_miss_count));
        out.error_message = sprintf('cache path failed and direct fallback was used: %s', ME.message);
    else
        out.status = 'cache_miss_error';
        out.confidence = 'low';
        out.boundary_flag = 'cache_lookup_failed';
        out.cache_miss_count = max(1, finite_or_zero_local(out.cache_miss_count));
        out.fallback_used = false;
        out.error_message = ME.message;
        out.debug.exception = ME;
    end
end

if opts.run_direct_reference && strcmp(out.status, 'ok')
    direct_out = step11_7_direct_reference_c05_backend(input, context, struct('runtime_timing', opts.runtime_timing));
    out.debug.direct_reference = direct_out;
end
out.runtime_total_sec = toc(total_tic);
end

function opts = fill_opts_local(opts)
if ~isfield(opts, 'use_cache')
    opts.use_cache = true;
end
if ~isfield(opts, 'run_direct_reference')
    opts.run_direct_reference = false;
end
if ~isfield(opts, 'allow_cache_fallback')
    opts.allow_cache_fallback = true;
end
if ~isfield(opts, 'truth_for_eval')
    opts.truth_for_eval = [];
end
if ~isfield(opts, 'runtime_timing')
    opts.runtime_timing = true;
end
end

function cache_check = validate_cache_metadata_local(context)
cache_check = struct('cache_valid', false, 'error_message', '');
if ~isfield(context, 'cache') || isempty(context.cache) || ~isstruct(context.cache)
    cache_check.error_message = 'missing context.cache';
    return;
end
cache = context.cache;
required_ok = isfield(cache, 'cache_type') && strcmp(cache.cache_type, 'canonical_beamspace_G_cache') && ...
    isfield(cache, 'W_method') && strcmp(cache.W_method, context.W_method) && ...
    isfield(cache, 'valid_center_rule') && strcmp(cache.valid_center_rule, 'shared_center_nearest_column_canonical_order') && ...
    isfield(cache, 'supports_interpolation') && ~logical(cache.supports_interpolation) && ...
    isfield(cache, 'default_lookup_mode') && strcmp(cache.default_lookup_mode, 'exact_grid_lookup');
if ~required_ok
    cache_check.error_message = 'cache metadata mismatch: type/W_method/order/lookup/interpolation check failed';
    return;
end
if ~isfield(context, 'cache_metadata') || isempty(context.cache_metadata) || ~isstruct(context.cache_metadata)
    cache_check.error_message = 'missing context.cache_metadata';
    return;
end
metadata = context.cache_metadata;
metadata_ok = isfield(metadata, 'cache_type') && strcmp(metadata.cache_type, 'canonical_beamspace_G_cache') && ...
    isfield(metadata, 'W_method') && strcmp(metadata.W_method, context.W_method) && ...
    isfield(metadata, 'valid_center_rule') && strcmp(metadata.valid_center_rule, 'shared_center_nearest_column_canonical_order') && ...
    isfield(metadata, 'supports_interpolation') && ~logical(metadata.supports_interpolation) && ...
    isfield(metadata, 'default_lookup_mode') && strcmp(metadata.default_lookup_mode, 'exact_grid_lookup');
if ~metadata_ok
    cache_check.error_message = 'context.cache_metadata mismatch: type/W_method/order/lookup/interpolation check failed';
    return;
end
cache_check.cache_valid = true;
cache_check.error_message = '';
end

function [grid_cfg_coarse, base_refine_cfg] = make_search_configs_local(coarseAz, coarseEl, context)
grid_cfg_coarse = build_pair2d_search_grids(coarseAz, coarseEl, context.coarse_search_cfg);
full_grid_cfg = build_pair2d_search_grids(coarseAz, coarseEl, context.full_search_cfg);
base_refine_cfg = context.base_refine_cfg;
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;
end

function coarse_debug = make_cached_coarse_debug_local(debug0, topK)
coarse_debug = struct();
coarse_debug.search_mode = 'coarse_degree_grid_topk_cached';
coarse_debug.whitening_mode = debug0.whitening_mode;
coarse_debug.num_pairs = debug0.num_pairs;
coarse_debug.topK_requested = topK;
coarse_debug.topK_returned = debug0.topK_returned;
coarse_debug.max_score = debug0.max_score;
coarse_debug.best_i_az1 = debug0.best_i_az1;
coarse_debug.best_i_az2 = debug0.best_i_az2;
coarse_debug.best_i_el_center = debug0.best_i_el_center;
coarse_debug.best_el_sep_deg = debug0.best_el_sep_deg;
coarse_debug.best_orientation = debug0.best_orientation;
coarse_debug.cond_best_GHG = debug0.cond_best_GHG;
coarse_debug.rank_best_G = debug0.rank_best_G;
coarse_debug.cond_WHW = debug0.cond_WHW;
coarse_debug.whitening_info = debug0.whitening_info;
coarse_debug.grid_cfg = debug0.grid_cfg;
coarse_debug.cache_miss_count = debug0.cache_miss_count;
coarse_debug.cached_lookup_time_sec = debug0.cached_lookup_time_sec;
coarse_debug.direct_fallback_used = debug0.direct_fallback_used;
end

function out = fill_success_output_local(out, est, debug, input, validation, Z)
out.status = 'ok';
out.confidence = safe_field_local(debug, 'confidence', 'low');
out.boundary_flag = safe_field_local(debug, 'boundary_flag', '');
out.az_hat = est.az_hat;
out.el_hat = est.el_hat;
out.el_center_hat = est.el_center_hat;
out.el_sep_hat = est.el_sep_hat;
out.orientation_hat = est.orientation_hat;
out.max_score = est.max_score;
out.policy_name = safe_policy_field_local(debug, 'policy_name', 'UNKNOWN');
out.adaptive_topK = safe_field_local(debug, 'adaptive_topK', NaN);
out.window_scale_az = safe_policy_field_local(debug, 'az_window_scale', NaN);
out.window_scale_el = safe_policy_field_local(debug, 'el_window_scale', NaN);
out.num_pairs_total = safe_field_local(debug, 'num_pairs_total', safe_field_local(debug, 'num_pairs', NaN));
out.num_pairs_coarse = safe_field_local(debug, 'num_pairs_coarse', NaN);
out.num_pairs_refine = safe_field_local(debug, 'num_pairs_refine', NaN);
out.selectedCenterColumn = input.selectedCenterColumn;
out.selectedCenterAz = input.selectedCenterAz;
out.input_shape = validation.input_shape;
out.Z_shape = shape_text_local(size(Z));
out.debug = debug;
out.debug.validation = validation;
out.error_message = '';
end

function out = copy_direct_to_cached_out_local(out, direct_out)
names = fieldnames(direct_out);
for idx = 1:numel(names)
    out.(names{idx}) = direct_out.(names{idx});
end
out.method_name = 'final_cached_c05_beamspace_ml_backend';
end

function value = safe_input_field_local(input, field, fallback)
if isstruct(input) && isfield(input, field)
    value = input.(field);
else
    value = fallback;
end
end

function value = safe_field_local(s, field, fallback)
if isstruct(s) && isfield(s, field)
    value = s.(field);
else
    value = fallback;
end
end

function value = safe_policy_field_local(debug, field, fallback)
value = fallback;
if isstruct(debug) && isfield(debug, 'policy') && isstruct(debug.policy) && isfield(debug.policy, field)
    value = debug.policy.(field);
end
end

function text = shape_text_local(sz)
parts = cell(1, numel(sz));
for idx = 1:numel(sz)
    parts{idx} = sprintf('%d', sz(idx));
end
text = strjoin(parts, 'x');
end

function value = finite_or_zero_local(value)
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    value = 0;
end
end
