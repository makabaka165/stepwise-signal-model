function [est_adaptive, debug_adaptive] = search_pair2d_adaptive_c05_cached(Z, W, x, y, z, lambda, ...
    grid_cfg_coarse, base_refine_cfg, manifold_opts, search_opts, policy_cfg, cache, top_candidates, coarse_debug)
%SEARCH_PAIR2D_ADAPTIVE_C05_CACHED Cached Step11.5 C05 adaptive pair2d search.
%
% The controlled pair2d DML score is unchanged.  The only replacement is
% Step11.6 exact lookup of canonical cached G grids.  Set
% policy_cfg.force_fixed_topK3=true to run the fixed topK3 control path.

if nargin < 12
    error('search_pair2d_adaptive_c05_cached:NotEnoughInputs', ...
        'Z, W, x, y, z, lambda, grid_cfg_coarse, base_refine_cfg, manifold_opts, search_opts, policy_cfg, and cache are required.');
end
if nargin < 11 || isempty(policy_cfg)
    policy_cfg = struct();
end
policy_cfg = fill_policy_defaults_local(policy_cfg);

if nargin < 13 || isempty(top_candidates) || nargin < 14 || isempty(coarse_debug)
    [~, score_info, coarse_debug0] = search_pair2d_degree_grid_cached(Z, W, x, y, z, lambda, ...
        grid_cfg_coarse, manifold_opts, search_opts, cache, 'ReturnTopK', true, 'TopK', policy_cfg.topK_max);
    top_candidates = score_info.top_candidates;
    coarse_debug = make_coarse_debug_local(coarse_debug0, policy_cfg.topK_max);
end

debug_adaptive = make_debug_template_local(policy_cfg);
debug_adaptive.coarse_debug = coarse_debug;
debug_adaptive.top_candidates = top_candidates;
debug_adaptive.num_pairs_coarse = coarse_debug.num_pairs;

if isfield(policy_cfg, 'force_fixed_topK3') && policy_cfg.force_fixed_topK3
    policy = struct();
    policy.policy_name = 'FIXED_TOPK3';
    policy.adaptive_topK = min(3, numel(top_candidates));
    policy.az_window_scale = 1.0;
    policy.el_window_scale = 1.0;
    policy.adaptive_local_az_half_width = base_refine_cfg.local_az_half_width;
    policy.adaptive_local_el_center_half_width = base_refine_cfg.local_el_center_half_width;
    policy.confidence = 'control';
    policy.boundary_flag = '';
    policy.reason_text = 'fixed Step11.3 topK3 control path';
    policy.config_id = -3;
    policy.config_name = 'fixed_topK3';
    features = struct();
else
    features = compute_likelihood_landscape_features_v2(top_candidates, coarse_debug, grid_cfg_coarse, search_opts, policy_cfg);
    policy = select_adaptive_topk_window_policy_v2(features, base_refine_cfg, policy_cfg);
end

adaptive_topK = min(policy.adaptive_topK, numel(top_candidates));
selected_candidates = top_candidates(1:adaptive_topK);
adaptive_refine_cfg = base_refine_cfg;
adaptive_refine_cfg.local_az_half_width = policy.adaptive_local_az_half_width;
adaptive_refine_cfg.local_el_center_half_width = policy.adaptive_local_el_center_half_width;
if ~isfield(adaptive_refine_cfg, 'fine_el_sep_deg_list') && isfield(base_refine_cfg, 'el_sep_deg_list')
    adaptive_refine_cfg.fine_el_sep_deg_list = base_refine_cfg.el_sep_deg_list;
end

debug_adaptive.features = features;
debug_adaptive.policy = policy;
debug_adaptive.selected_candidates = selected_candidates;
debug_adaptive.adaptive_refine_cfg = adaptive_refine_cfg;
debug_adaptive.adaptive_topK = adaptive_topK;
debug_adaptive.confidence = policy.confidence;
debug_adaptive.boundary_flag = policy.boundary_flag;

try
    [est_adaptive, refine_debug] = local_refine_cached_local(Z, W, x, y, z, lambda, ...
        selected_candidates, adaptive_refine_cfg, manifold_opts, search_opts, cache);
    est_adaptive.max_score = refine_debug.max_score;
    est_adaptive.score = refine_debug.max_score;
    debug_adaptive.refine_debug = refine_debug;
    debug_adaptive.num_pairs_refine = refine_debug.num_pairs;
    debug_adaptive.num_pairs_total = coarse_debug.num_pairs + refine_debug.num_pairs;
    debug_adaptive.num_pairs = debug_adaptive.num_pairs_total;
    debug_adaptive.max_score = refine_debug.max_score;
    debug_adaptive.cond_best_GHG = refine_debug.cond_best_GHG;
    debug_adaptive.rank_best_G = refine_debug.rank_best_G;
    debug_adaptive.cache_miss_count = safe_field_local(coarse_debug, 'cache_miss_count', 0) + refine_debug.cache_miss_count;
    debug_adaptive.cached_lookup_time_sec = safe_field_local(coarse_debug, 'cached_lookup_time_sec', 0) + refine_debug.cached_lookup_time_sec;
    debug_adaptive.direct_fallback_used = logical(safe_field_local(coarse_debug, 'direct_fallback_used', false)) || refine_debug.direct_fallback_used;
catch ME
    est_adaptive = make_failed_est_local();
    debug_adaptive.refine_debug = struct();
    debug_adaptive.num_pairs_refine = 0;
    debug_adaptive.num_pairs_total = coarse_debug.num_pairs;
    debug_adaptive.num_pairs = debug_adaptive.num_pairs_total;
    debug_adaptive.failure_reason = 'adaptive_failure_no_candidate_rows';
    debug_adaptive.failure_detail = ME.message;
    debug_adaptive.confidence = 'low';
    debug_adaptive.cache_miss_count = safe_field_local(coarse_debug, 'cache_miss_count', 0);
    debug_adaptive.cached_lookup_time_sec = safe_field_local(coarse_debug, 'cached_lookup_time_sec', 0);
    debug_adaptive.direct_fallback_used = logical(safe_field_local(coarse_debug, 'direct_fallback_used', false));
    if isempty(debug_adaptive.boundary_flag)
        debug_adaptive.boundary_flag = 'adaptive_failure_no_candidate_rows';
    end
end
end

function [est_refined, refine_debug] = local_refine_cached_local(Z, W, x, y, z, lambda, top_candidates, refine_cfg, manifold_opts, search_opts, cache)
if isempty(top_candidates)
    error('search_pair2d_adaptive_c05_cached:EmptyCandidates', 'top_candidates must not be empty.');
end
refine_cfg = normalize_refine_cfg_local(refine_cfg);

per_candidate_num_pairs = nan(numel(top_candidates), 1);
per_candidate_az_min = nan(numel(top_candidates), 1);
per_candidate_az_max = nan(numel(top_candidates), 1);
per_candidate_az1_bounds = nan(numel(top_candidates), 2);
per_candidate_az2_bounds = nan(numel(top_candidates), 2);
per_candidate_el_center_min = nan(numel(top_candidates), 1);
per_candidate_el_center_max = nan(numel(top_candidates), 1);
per_candidate_error_text = cell(numel(top_candidates), 1);
candidate_rows_by_top = cell(numel(top_candidates), 1);

for idx = 1:numel(top_candidates)
    candidate = top_candidates(idx);
    az_sorted = sort(candidate.az_hat(:).');
    az1_bounds = clamp_bounds_local(az_sorted(1) + ...
        [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width], refine_cfg.az_global_bounds);
    az2_bounds = clamp_bounds_local(az_sorted(2) + ...
        [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width], refine_cfg.az_global_bounds);
    el_center_bounds = clamp_bounds_local(candidate.el_center_hat + ...
        [-refine_cfg.local_el_center_half_width, refine_cfg.local_el_center_half_width], refine_cfg.el_global_bounds);

    per_candidate_az_min(idx) = min([az1_bounds, az2_bounds]);
    per_candidate_az_max(idx) = max([az1_bounds, az2_bounds]);
    per_candidate_az1_bounds(idx, :) = az1_bounds;
    per_candidate_az2_bounds(idx, :) = az2_bounds;
    per_candidate_el_center_min(idx) = el_center_bounds(1);
    per_candidate_el_center_max(idx) = el_center_bounds(2);

    try
        az1_grid = make_axis_local(az1_bounds(1), az1_bounds(2), refine_cfg.fine_az_step);
        az2_grid = make_axis_local(az2_bounds(1), az2_bounds(2), refine_cfg.fine_az_step);
        el_center_grid = make_axis_local(el_center_bounds(1), el_center_bounds(2), refine_cfg.fine_el_step);
        rows_now = build_candidate_rows_local(az1_grid, az2_grid, el_center_grid, refine_cfg);
        candidate_rows_by_top{idx} = rows_now;
        per_candidate_num_pairs(idx) = size(rows_now, 1);
    catch ME
        candidate_rows_by_top{idx} = zeros(0, 7);
        per_candidate_num_pairs(idx) = 0;
        per_candidate_error_text{idx} = ME.message;
    end
end

candidate_rows = vertcat(candidate_rows_by_top{:});
candidate_rows = unique(candidate_rows, 'rows', 'stable');
if isempty(candidate_rows)
    error('search_pair2d_adaptive_c05_cached:NoCandidateRows', 'No valid degree-based local refine candidates were generated.');
end

grid_cfg = make_explicit_degree_grid_cfg_local(candidate_rows, top_candidates, refine_cfg);
[est_refined, ~, best_debug] = search_pair2d_degree_grid_cached(Z, W, x, y, z, lambda, ...
    grid_cfg, manifold_opts, search_opts, cache);

best_candidate_index = find_best_candidate_owner_local(est_refined, candidate_rows_by_top);
per_candidate_max_score = nan(numel(top_candidates), 1);
if isfinite(best_candidate_index)
    per_candidate_max_score(best_candidate_index) = best_debug.max_score;
end

refine_debug = struct();
refine_debug.search_mode = 'degree_based_local_refine_from_topk_cached';
refine_debug.topK = numel(top_candidates);
refine_debug.best_candidate_index = best_candidate_index;
refine_debug.max_score = best_debug.max_score;
refine_debug.num_pairs = best_debug.num_pairs;
refine_debug.total_num_pairs_raw = sum(per_candidate_num_pairs(isfinite(per_candidate_num_pairs)));
refine_debug.unique_num_pairs = best_debug.num_pairs;
refine_debug.per_candidate_num_pairs = per_candidate_num_pairs;
refine_debug.per_candidate_max_score = per_candidate_max_score;
refine_debug.per_candidate_az_bounds = [per_candidate_az_min, per_candidate_az_max];
refine_debug.per_candidate_az1_bounds = per_candidate_az1_bounds;
refine_debug.per_candidate_az2_bounds = per_candidate_az2_bounds;
refine_debug.per_candidate_el_center_bounds = [per_candidate_el_center_min, per_candidate_el_center_max];
refine_debug.per_candidate_error_text = per_candidate_error_text;
refine_debug.best_debug = best_debug;
refine_debug.cond_best_GHG = best_debug.cond_best_GHG;
refine_debug.rank_best_G = best_debug.rank_best_G;
refine_debug.grid_cfg_best = best_debug.grid_cfg;
refine_debug.cache_miss_count = best_debug.cache_miss_count;
refine_debug.cached_lookup_time_sec = best_debug.cached_lookup_time_sec;
refine_debug.direct_fallback_used = best_debug.direct_fallback_used;
end

function coarse_debug = make_coarse_debug_local(debug0, topK)
coarse_debug = struct();
coarse_debug.search_mode = 'coarse_degree_grid_topk_cached';
coarse_debug.whitening_mode = debug0.whitening_mode;
coarse_debug.num_pairs = debug0.num_pairs;
coarse_debug.topK_requested = topK;
coarse_debug.topK_returned = debug0.topK_returned;
coarse_debug.finite_slice_count = NaN;
coarse_debug.max_score = debug0.max_score;
coarse_debug.score_gap_top1_topK = NaN;
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

function policy_cfg = fill_policy_defaults_local(policy_cfg)
if ~isfield(policy_cfg, 'topK_max')
    policy_cfg.topK_max = 7;
end
if ~isfield(policy_cfg, 'tau')
    policy_cfg.tau = 0.02;
end
if ~isfield(policy_cfg, 'gap_scale')
    policy_cfg.gap_scale = 0.003;
end
if ~isfield(policy_cfg, 'config_id')
    policy_cfg.config_id = 5;
end
if ~isfield(policy_cfg, 'config_name')
    policy_cfg.config_name = 'C05_easy_very_aggressive';
end
end

function debug_adaptive = make_debug_template_local(policy_cfg)
debug_adaptive = struct();
debug_adaptive.search_mode = 'step11_6_cached_c05_adaptive_topk_window';
debug_adaptive.config_id = policy_cfg.config_id;
debug_adaptive.config_name = policy_cfg.config_name;
debug_adaptive.features = struct();
debug_adaptive.policy = struct();
debug_adaptive.coarse_debug = struct();
debug_adaptive.refine_debug = struct();
debug_adaptive.num_pairs_coarse = NaN;
debug_adaptive.num_pairs_refine = NaN;
debug_adaptive.num_pairs_total = NaN;
debug_adaptive.num_pairs = NaN;
debug_adaptive.topK_max = policy_cfg.topK_max;
debug_adaptive.adaptive_topK = NaN;
debug_adaptive.confidence = '';
debug_adaptive.boundary_flag = '';
debug_adaptive.failure_reason = '';
debug_adaptive.failure_detail = '';
debug_adaptive.top_candidates = [];
debug_adaptive.selected_candidates = [];
debug_adaptive.max_score = NaN;
debug_adaptive.cond_best_GHG = NaN;
debug_adaptive.rank_best_G = NaN;
debug_adaptive.cache_miss_count = NaN;
debug_adaptive.cached_lookup_time_sec = NaN;
debug_adaptive.direct_fallback_used = false;
end

function refine_cfg = normalize_refine_cfg_local(refine_cfg)
required = {'local_az_half_width','fine_az_step','fine_el_step','search_orientations'};
for idx = 1:numel(required)
    if ~isfield(refine_cfg, required{idx})
        error('search_pair2d_adaptive_c05_cached:MissingRefineField', 'refine_cfg.%s is required.', required{idx});
    end
end
if ~isfield(refine_cfg, 'local_el_center_half_width')
    if isfield(refine_cfg, 'local_el_half_width')
        refine_cfg.local_el_center_half_width = refine_cfg.local_el_half_width;
    else
        error('search_pair2d_adaptive_c05_cached:MissingElCenterHalfWidth', ...
            'refine_cfg.local_el_center_half_width is required.');
    end
end
if ~isfield(refine_cfg, 'fine_el_sep_deg_list')
    if isfield(refine_cfg, 'el_sep_deg_list')
        refine_cfg.fine_el_sep_deg_list = refine_cfg.el_sep_deg_list;
    else
        error('search_pair2d_adaptive_c05_cached:MissingFineElSepDegList', ...
            'refine_cfg.fine_el_sep_deg_list is required.');
    end
end
if ~isfield(refine_cfg, 'az_global_bounds')
    refine_cfg.az_global_bounds = [-Inf, Inf];
end
if ~isfield(refine_cfg, 'el_global_bounds')
    refine_cfg.el_global_bounds = [-Inf, Inf];
end
refine_cfg.fine_el_sep_deg_list = unique(round(refine_cfg.fine_el_sep_deg_list(:).' * 1e10) / 1e10);
end

function rows = build_candidate_rows_local(az1_grid, az2_grid, el_center_grid, refine_cfg)
[AZ1, AZ2] = ndgrid(az1_grid(:), az2_grid(:));
az_pair_rows = [AZ1(:), AZ2(:)];
az_pair_rows = az_pair_rows(az_pair_rows(:, 1) < az_pair_rows(:, 2), :);
az_pair_rows = unique(round(az_pair_rows * 1e10) / 1e10, 'rows', 'stable');
if isempty(az_pair_rows)
    rows = zeros(0, 7);
    return;
end

el_rows = build_el_rows_local(el_center_grid, refine_cfg.fine_el_sep_deg_list, ...
    refine_cfg.search_orientations, refine_cfg.el_global_bounds);
if isempty(el_rows)
    rows = zeros(0, 7);
    return;
end

nAz = size(az_pair_rows, 1);
nEl = size(el_rows, 1);
rows = zeros(nAz * nEl, 7);
pos = 0;
for iEl = 1:nEl
    idx = pos + (1:nAz);
    rows(idx, 1:2) = az_pair_rows;
    rows(idx, 3:7) = repmat(el_rows(iEl, :), nAz, 1);
    pos = pos + nAz;
end
end

function el_rows = build_el_rows_local(el_center_grid, el_sep_deg_list, orientation_list, el_bounds)
[~, ~, valid_mask, info] = make_el_pair_list_degree_based(el_center_grid, el_sep_deg_list, orientation_list, el_bounds);
rows = info.rows(valid_mask);
if isempty(rows)
    el_rows = zeros(0, 5);
    return;
end
el_rows = [[rows.el1].', [rows.el2].', [rows.el_center].', [rows.el_sep_deg].', [rows.orientation].'];
el_rows = unique(round(el_rows * 1e10) / 1e10, 'rows', 'stable');
end

function grid_cfg = make_explicit_degree_grid_cfg_local(candidate_rows, top_candidates, refine_cfg)
grid_cfg = struct();
grid_cfg.candidate_rows = candidate_rows;
grid_cfg.az_grid = unique(round(reshape(candidate_rows(:, 1:2), 1, []) * 1e10) / 1e10);
grid_cfg.el_grid = unique(round(candidate_rows(:, 5).' * 1e10) / 1e10);
grid_cfg.el_center_grid = grid_cfg.el_grid;
grid_cfg.az_step = refine_cfg.fine_az_step;
grid_cfg.el_step = refine_cfg.fine_el_step;
grid_cfg.el_sep_deg_list = refine_cfg.fine_el_sep_deg_list;
grid_cfg.search_orientations = refine_cfg.search_orientations;
grid_cfg.az_bounds = refine_cfg.az_global_bounds;
grid_cfg.el_bounds = refine_cfg.el_global_bounds;
grid_cfg.az_center = mean(reshape([top_candidates.az_hat], 1, []));
grid_cfg.el_center = mean([top_candidates.el_center_hat]);
grid_cfg.estimated_num_candidates = size(candidate_rows, 1);
grid_cfg.mode = 'degree_based_el_sep_explicit_local_refine_cached';
end

function best_candidate_index = find_best_candidate_owner_local(est_refined, candidate_rows_by_top)
best_row = round([est_refined.az_hat(:).', est_refined.el_hat(:).', ...
    est_refined.el_center_hat, est_refined.el_sep_hat, est_refined.orientation_hat] * 1e10) / 1e10;
best_candidate_index = NaN;
for idx = 1:numel(candidate_rows_by_top)
    rows_now = candidate_rows_by_top{idx};
    if isempty(rows_now)
        continue;
    end
    if any(all(abs(rows_now - best_row) < 1e-10, 2))
        best_candidate_index = idx;
        return;
    end
end
end

function bounds = clamp_bounds_local(bounds, global_bounds)
global_bounds = sort(global_bounds(:).');
bounds = sort(bounds(:).');
bounds(1) = max(bounds(1), global_bounds(1));
bounds(2) = min(bounds(2), global_bounds(2));
if bounds(2) < bounds(1)
    mid = mean(global_bounds);
    bounds = [mid, mid];
end
end

function axis = make_axis_local(lo, hi, step)
if ~(isfinite(lo) && isfinite(hi) && isfinite(step) && step > 0)
    error('search_pair2d_adaptive_c05_cached:InvalidAxis', 'Bounds and step must be finite.');
end
if hi < lo
    tmp = lo;
    lo = hi;
    hi = tmp;
end
axis = lo:step:hi;
if isempty(axis) || abs(axis(end) - hi) > 1e-9
    axis = [axis, hi];
end
axis = unique(round(axis * 1e10) / 1e10);
end

function value = safe_field_local(s, field, default_value)
if isstruct(s) && isfield(s, field)
    value = s.(field);
else
    value = default_value;
end
end

function est = make_failed_est_local()
est = struct();
est.az_hat = [NaN, NaN];
est.el_hat = [NaN, NaN];
est.el_center_hat = NaN;
est.el_sep_hat = NaN;
est.orientation_hat = NaN;
est.max_score = NaN;
est.score = NaN;
end
