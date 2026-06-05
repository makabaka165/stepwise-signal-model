function [est_refined, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, x, y, z, lambda, top_candidates, refine_cfg, manifold_opts, search_opts)
%SEARCH_PAIR2D_LOCAL_REFINE_FROM_TOPK Degree-based local refinement around coarse topK candidates.

if nargin < 10
    error('search_pair2d_local_refine_from_topk:NotEnoughInputs', ...
        'Z, W, x, y, z, lambda, top_candidates, refine_cfg, manifold_opts, and search_opts are required.');
end
if isempty(top_candidates)
    error('search_pair2d_local_refine_from_topk:EmptyCandidates', 'top_candidates must not be empty.');
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
    error('search_pair2d_local_refine_from_topk:NoCandidateRows', 'No valid degree-based local refine candidates were generated.');
end

grid_cfg = make_explicit_degree_grid_cfg_local(candidate_rows, top_candidates, refine_cfg);
[est_refined, ~, best_debug] = search_pair2d_degree_grid_precomputed(Z, W, x, y, z, lambda, ...
    grid_cfg, manifold_opts, search_opts);

best_candidate_index = find_best_candidate_owner_local(est_refined, candidate_rows_by_top);
per_candidate_max_score = nan(numel(top_candidates), 1);
if isfinite(best_candidate_index)
    per_candidate_max_score(best_candidate_index) = best_debug.max_score;
end

refine_debug = struct();
refine_debug.search_mode = 'degree_based_local_refine_from_topk';
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
end

function refine_cfg = normalize_refine_cfg_local(refine_cfg)
required = {'local_az_half_width','fine_az_step','fine_el_step','search_orientations'};
for idx = 1:numel(required)
    if ~isfield(refine_cfg, required{idx})
        error('search_pair2d_local_refine_from_topk:MissingRefineField', 'refine_cfg.%s is required.', required{idx});
    end
end
if ~isfield(refine_cfg, 'local_el_center_half_width')
    if isfield(refine_cfg, 'local_el_half_width')
        refine_cfg.local_el_center_half_width = refine_cfg.local_el_half_width;
    else
        error('search_pair2d_local_refine_from_topk:MissingElCenterHalfWidth', ...
            'refine_cfg.local_el_center_half_width is required.');
    end
end
if ~isfield(refine_cfg, 'fine_el_sep_deg_list')
    if isfield(refine_cfg, 'el_sep_deg_list')
        refine_cfg.fine_el_sep_deg_list = refine_cfg.el_sep_deg_list;
    else
        error('search_pair2d_local_refine_from_topk:MissingFineElSepDegList', ...
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
grid_cfg.mode = 'degree_based_el_sep_explicit_local_refine';
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
    error('search_pair2d_local_refine_from_topk:InvalidAxis', 'Bounds and step must be finite.');
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
