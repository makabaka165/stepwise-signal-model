function out = step11_7_direct_reference_c05_backend(input, context, opts)
%STEP11_7_DIRECT_REFERENCE_C05_BACKEND Run direct Step11.5 C05 backend.
%
% This is the direct precompute reference path used to verify the cached
% final route.  It keeps the same W, same C05 policy, and same controlled
% pair2d DML score.

if nargin < 3
    opts = struct();
end
if ~isfield(opts, 'runtime_timing')
    opts.runtime_timing = true;
end
total_tic = tic;
out = step11_7_make_backend_output();
out.method_name = 'direct_reference_c05_beamspace_ml_backend';
out.used_cache = false;
out.cache_miss_count = 0;

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
    out.runtime_total_sec = toc(total_tic);
    return;
end

try
    search_tic = tic;
    geom = build_step11_6_canonical_geometry(context.cfg, input.selectedCenterAz);
    [grid_cfg_coarse, base_refine_cfg] = make_search_configs_local(input.coarseAz, input.coarseEl, context);
    manifold_opts = context.manifold_opts;
    search_opts = context.search_opts;
    search_opts.cache_fallback_direct = true;
    Z = context.W' * validation.Y;
    [top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, context.W, geom.x_actual, geom.y_actual, geom.z_actual, ...
        context.lambda, grid_cfg_coarse, manifold_opts, search_opts, context.C05_policy_cfg.topK_max);
    [est, debug] = search_pair2d_adaptive_topk_window_v2(Z, context.W, geom.x_actual, geom.y_actual, geom.z_actual, ...
        context.lambda, grid_cfg_coarse, base_refine_cfg, manifold_opts, search_opts, context.C05_policy_cfg, top_candidates, coarse_debug);
    out.runtime_search_sec = toc(search_tic);
    out = fill_success_output_local(out, est, debug, input, validation, Z);
catch ME
    out.status = 'direct_backend_error';
    out.confidence = 'low';
    out.error_message = ME.message;
    out.debug.exception = ME;
end
out.runtime_total_sec = toc(total_tic);
end

function [grid_cfg_coarse, base_refine_cfg] = make_search_configs_local(coarseAz, coarseEl, context)
grid_cfg_coarse = build_pair2d_search_grids(coarseAz, coarseEl, context.coarse_search_cfg);
full_grid_cfg = build_pair2d_search_grids(coarseAz, coarseEl, context.full_search_cfg);
base_refine_cfg = context.base_refine_cfg;
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;
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
