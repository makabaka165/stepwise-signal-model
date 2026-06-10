function [est, score_info, debug] = search_pair2d_degree_grid_cached(Z, W, x, y, z, lambda, grid_cfg, manifold_opts, search_opts, cache, varargin)
%SEARCH_PAIR2D_DEGREE_GRID_CACHED Controlled pair2d grid search using Step11.6 cache.
%
% This function mirrors Step11.3 search_pair2d_degree_grid_precomputed after
% G_grid construction.  It never interpolates cache misses; if fallback is
% enabled it records the miss and uses the direct precompute path.

if nargin < 10
    error('search_pair2d_degree_grid_cached:NotEnoughInputs', ...
        'Z, W, x, y, z, lambda, grid_cfg, manifold_opts, search_opts, and cache are required.');
end
opts = parse_opts_local(varargin{:});
grid_cfg = normalize_grid_cfg_local(grid_cfg);
manifold_opts = fill_manifold_opts_local(manifold_opts);
search_opts = fill_search_opts_local(search_opts);

explicit_rows_mode = isfield(grid_cfg, 'candidate_rows') && ~isempty(grid_cfg.candidate_rows);
if explicit_rows_mode
    candidate_rows = normalize_candidate_rows_local(grid_cfg.candidate_rows);
    az_grid = unique(round(reshape(candidate_rows(:, 1:2), 1, []) * 1e10) / 1e10);
    el_center_grid = unique(round(candidate_rows(:, 5).' * 1e10) / 1e10);
    el_sep_deg_list = unique(round(candidate_rows(:, 6).' * 1e10) / 1e10);
else
    az_grid = grid_cfg.az_grid(:).';
    el_center_grid = grid_cfg.el_center_grid(:).';
    el_sep_deg_list = grid_cfg.el_sep_deg_list(:).';
end
B = size(W, 2);
if size(Z, 1) ~= B
    error('search_pair2d_degree_grid_cached:ShapeMismatch', 'size(Z,1) must equal size(W,2).');
end

if explicit_rows_mode
    [valid_rows, el_info] = make_explicit_el_rows_local(candidate_rows, el_center_grid, el_sep_deg_list, grid_cfg);
else
    [~, ~, ~, el_info] = make_el_pair_list_degree_based(el_center_grid, el_sep_deg_list, ...
        grid_cfg.search_orientations, grid_cfg.el_bounds);
    valid_rows = el_info.rows([el_info.rows.valid]);
    if isempty(valid_rows)
        error('search_pair2d_degree_grid_cached:NoValidElPair', 'No valid degree-based elevation pair exists.');
    end
end

el_values = unique(round([[valid_rows.el1], [valid_rows.el2]] * 1e10) / 1e10);
center_az = get_center_az_local(manifold_opts, grid_cfg);
[G_grid, lookup_info] = lookup_step11_6_beamspace_cache(cache, az_grid, el_values, ...
    'CenterAzDeg', center_az, 'InputAzMode', 'global', 'ErrorOnMiss', false);
direct_fallback_used = false;
direct_manifold_time_sec = 0;
if lookup_info.cache_miss_count > 0
    if search_opts.cache_fallback_direct
        tic;
        grid = precompute_beamspace_azel_grid(W, x, y, z, az_grid, el_values, lambda, ...
            'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);
        direct_manifold_time_sec = toc;
        G_grid = grid.G_grid;
        direct_fallback_used = true;
        lookup_info.fallback_used = true;
    else
        error('search_pair2d_degree_grid_cached:CacheMiss', ...
            'Exact cache lookup missed %d entries. Interpolation is disabled.', lookup_info.cache_miss_count);
    end
end

N_az = numel(az_grid);
N_el_values = numel(el_values);
if size(G_grid, 1) ~= B || size(G_grid, 2) ~= N_az || size(G_grid, 3) ~= N_el_values
    error('search_pair2d_degree_grid_cached:GridShapeMismatch', 'Cached G grid has unexpected dimensions.');
end

[Z_use, G_grid_flat, winfo] = apply_beamspace_whitening(Z, reshape(G_grid, B, N_az * N_el_values), W, search_opts.whitening_mode, ...
    'eps_reg', max(search_opts.reg, 1e-12));
G_use_grid = reshape(G_grid_flat, B, N_az, N_el_values);

max_score = -Inf;
tie_count = 0;
num_pairs = 0;
top_candidates = repmat(make_candidate_template_local(), 0, 1);
best = make_candidate_template_local();

for iRow = 1:numel(valid_rows)
    row = valid_rows(iRow);
    iEl1 = find(abs(el_values - row.el1) < 1e-10, 1);
    iEl2 = find(abs(el_values - row.el2) < 1e-10, 1);
    if isempty(iEl1) || isempty(iEl2)
        error('search_pair2d_degree_grid_cached:ElLookupFailed', 'Could not locate el values in cached grid.');
    end
    G1 = G_use_grid(:, :, iEl1);
    G2 = G_use_grid(:, :, iEl2);
    if explicit_rows_mode
        az_pair_indices = lookup_explicit_az_pair_indices_local(row.az_pair_list, az_grid);
    else
        az_pair_indices = [];
    end
    [score_map, slice_pairs] = score_ordered_cross_el_local(Z_use, G1, G2, search_opts.reg, az_pair_indices);
    num_pairs = num_pairs + slice_pairs;

    [slice_candidates, slice_max, slice_ties] = extract_candidates_local(score_map, opts.topK, az_grid, row, iEl1, iEl2);
    if ~isempty(slice_candidates)
        top_candidates = merge_topk_candidates_local(top_candidates, slice_candidates, opts.topK);
    end
    if slice_max > max_score
        max_score = slice_max;
        tie_count = slice_ties;
        best = slice_candidates(1);
    elseif slice_max == max_score
        tie_count = tie_count + slice_ties;
    end
end

if ~isfinite(max_score)
    error('search_pair2d_degree_grid_cached:NoFiniteScore', 'No finite degree-based DML score was found.');
end
top_candidates = sort_candidates_local(top_candidates);
if isempty(top_candidates)
    top_candidates = best;
end
best = top_candidates(1);

est = struct();
est.az_hat = best.az_hat;
est.el_hat = best.el_hat;
est.el_center_hat = best.el_center_hat;
est.el_sep_hat = best.el_sep_hat;
est.orientation_hat = best.orientation_hat;
est.max_score = best.score;
est.score = best.score;

G_best = [G_use_grid(:, best.iAz1, best.iEl1), G_use_grid(:, best.iAz2, best.iEl2)];
[~, best_debug] = beamspace_dml_score(Z_use, G_best, 'reg', search_opts.reg);

score_info = struct();
score_info.best_score = best.score;
score_info.top_candidates = top_candidates;
score_info.el_pair_info = el_info;

debug = struct();
debug.search_mode = 'degree_based_pair2d_grid_cached';
debug.num_pairs = num_pairs;
debug.max_score = best.score;
debug.tie_count = tie_count;
debug.best_i_az1 = best.iAz1;
debug.best_i_az2 = best.iAz2;
debug.best_i_el_center = best.iElCenter;
debug.best_el_sep_deg = best.el_sep_hat;
debug.best_i_el_sep = best.iElSep;
debug.best_orientation = best.orientation_hat;
debug.best_i_el1 = best.iEl1;
debug.best_i_el2 = best.iEl2;
debug.cond_best_GHG = best_debug.cond_GHG;
debug.rank_best_G = best_debug.rank_G;
debug.cond_WHW = cond(W' * W + max(search_opts.reg, 1e-12) * eye(B));
debug.grid_cfg = grid_cfg;
debug.el_values = el_values;
debug.whitening_mode = lower(char(search_opts.whitening_mode));
debug.whitening_info = winfo;
debug.return_topK = opts.returnTopK;
debug.topK_requested = opts.topK;
debug.topK_returned = numel(top_candidates);
debug.cache_lookup_info = lookup_info;
debug.cache_miss_count = lookup_info.cache_miss_count;
debug.cached_lookup_time_sec = lookup_info.lookup_time_sec;
debug.direct_fallback_used = direct_fallback_used;
debug.direct_manifold_time_sec = direct_manifold_time_sec;
debug.center_az_deg = center_az;
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.returnTopK = false;
opts.topK = 1;
opts.keepScoreMap = false;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('search_pair2d_degree_grid_cached:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'returntopk'
            opts.returnTopK = logical(value);
        case 'topk'
            opts.topK = max(1, floor(value));
        case 'keepscoremap'
            opts.keepScoreMap = logical(value);
        otherwise
            error('search_pair2d_degree_grid_cached:UnknownOption', 'Unknown option: %s', name);
    end
end
opts.topK = max(1, opts.topK);
end

function grid_cfg = normalize_grid_cfg_local(grid_cfg)
explicit_rows_mode = isfield(grid_cfg, 'candidate_rows') && ~isempty(grid_cfg.candidate_rows);
if ~explicit_rows_mode && (~isfield(grid_cfg, 'az_grid') || isempty(grid_cfg.az_grid))
    error('search_pair2d_degree_grid_cached:MissingAzGrid', 'grid_cfg.az_grid is required.');
end
if explicit_rows_mode
    candidate_rows = normalize_candidate_rows_local(grid_cfg.candidate_rows);
    grid_cfg.az_grid = unique(round(reshape(candidate_rows(:, 1:2), 1, []) * 1e10) / 1e10);
    grid_cfg.el_center_grid = unique(round(candidate_rows(:, 5).' * 1e10) / 1e10);
    grid_cfg.el_sep_deg_list = unique(round(candidate_rows(:, 6).' * 1e10) / 1e10);
elseif isfield(grid_cfg, 'el_center_grid')
    grid_cfg.el_center_grid = grid_cfg.el_center_grid(:).';
elseif isfield(grid_cfg, 'el_grid')
    grid_cfg.el_center_grid = grid_cfg.el_grid(:).';
else
    error('search_pair2d_degree_grid_cached:MissingElGrid', 'grid_cfg.el_center_grid or grid_cfg.el_grid is required.');
end
if ~isfield(grid_cfg, 'el_sep_deg_list')
    error('search_pair2d_degree_grid_cached:MissingElSepDegList', 'grid_cfg.el_sep_deg_list is required.');
end
if ~isfield(grid_cfg, 'search_orientations')
    grid_cfg.search_orientations = [1, -1];
end
if ~isfield(grid_cfg, 'el_bounds')
    grid_cfg.el_bounds = [min(grid_cfg.el_center_grid) - max(grid_cfg.el_sep_deg_list) / 2, ...
        max(grid_cfg.el_center_grid) + max(grid_cfg.el_sep_deg_list) / 2];
end
if ~isfield(grid_cfg, 'az_bounds')
    grid_cfg.az_bounds = [min(grid_cfg.az_grid), max(grid_cfg.az_grid)];
end
grid_cfg.el_grid = grid_cfg.el_center_grid;
grid_cfg.mode = 'degree_based_el_sep';
end

function manifold_opts = fill_manifold_opts_local(manifold_opts)
if ~isfield(manifold_opts, 'phase_factor')
    manifold_opts.phase_factor = 1;
end
if ~isfield(manifold_opts, 'phase_sign')
    manifold_opts.phase_sign = 1;
end
end

function search_opts = fill_search_opts_local(search_opts)
if ~isfield(search_opts, 'whitening_mode')
    error('search_pair2d_degree_grid_cached:MissingWhiteningMode', 'search_opts.whitening_mode is required.');
end
if ~isfield(search_opts, 'reg')
    search_opts.reg = 1e-10;
end
if ~isfield(search_opts, 'cache_fallback_direct')
    search_opts.cache_fallback_direct = true;
end
end

function center_az = get_center_az_local(manifold_opts, grid_cfg)
if isfield(manifold_opts, 'actual_center_az_deg')
    center_az = manifold_opts.actual_center_az_deg;
elseif isfield(manifold_opts, 'center_az_deg')
    center_az = manifold_opts.center_az_deg;
elseif isfield(grid_cfg, 'az_center')
    center_az = grid_cfg.az_center;
else
    error('search_pair2d_degree_grid_cached:MissingCenterAz', ...
        'manifold_opts.actual_center_az_deg or grid_cfg.az_center is required for cache lookup.');
end
end

function [score_map, num_pairs] = score_ordered_cross_el_local(Z, G1, G2, reg, az_pair_indices)
if nargin < 5
    az_pair_indices = [];
end
Ngrid = size(G1, 2);
Rz = Z * Z';
S12 = G1' * G2;
Q12 = G1' * Rz * G2;
Q21 = (G2' * Rz * G1).';

s11 = real(sum(conj(G1) .* G1, 1)).' + reg;
s22 = real(sum(conj(G2) .* G2, 1)) + reg;
q11 = real(diag(G1' * Rz * G1));
q22 = real(diag(G2' * Rz * G2)).';

den = s11 * s22 - abs(S12).^2;
score_map = real(((q11 * s22) + (s11 * q22) - S12 .* Q21 - conj(S12) .* Q12) ./ den);
if isempty(az_pair_indices)
    mask = triu(true(Ngrid), 1);
else
    mask = false(Ngrid);
    pair_linear_idx = sub2ind([Ngrid, Ngrid], az_pair_indices(:, 1), az_pair_indices(:, 2));
    mask(pair_linear_idx) = true;
end
score_map(~mask) = NaN;
score_map(~isfinite(score_map) & mask) = -Inf;
num_pairs = nnz(mask);
end

function [candidates, slice_max, tie_count] = extract_candidates_local(score_map, topK, az_grid, el_row, iEl1, iEl2)
score_for_sort = score_map;
score_for_sort(~isfinite(score_for_sort)) = -Inf;
[scores_sorted, order] = sort(score_for_sort(:), 'descend');
finite_mask = isfinite(scores_sorted) & scores_sorted > -Inf;
scores_sorted = scores_sorted(finite_mask);
order = order(finite_mask);
keep_n = min(topK, numel(scores_sorted));
candidates = repmat(make_candidate_template_local(), keep_n, 1);
slice_max = -Inf;
tie_count = 0;
if keep_n == 0
    return;
end
slice_max = scores_sorted(1);
tie_count = nnz(scores_sorted == slice_max);
for idx = 1:keep_n
    [iAz1, iAz2] = ind2sub(size(score_map), order(idx));
    row = make_candidate_template_local();
    row.az_hat = [az_grid(iAz1), az_grid(iAz2)];
    row.el_hat = [el_row.el1, el_row.el2];
    row.el_center_hat = el_row.el_center;
    row.el_sep_hat = el_row.el_sep_deg;
    row.orientation_hat = el_row.orientation;
    row.score = scores_sorted(idx);
    row.iAz1 = iAz1;
    row.iAz2 = iAz2;
    row.iElCenter = el_row.i_el_center;
    row.iElSep = el_row.i_el_sep;
    row.iEl1 = iEl1;
    row.iEl2 = iEl2;
    row.el1_value = el_row.el1;
    row.el2_value = el_row.el2;
    candidates(idx) = row;
end
end

function merged = merge_topk_candidates_local(a, b, topK)
merged = [a; b];
merged = sort_candidates_local(merged);
if numel(merged) > topK
    merged = merged(1:topK);
end
end

function sorted = sort_candidates_local(candidates)
[~, order] = sort([candidates.score], 'descend');
sorted = candidates(order);
end

function row = make_candidate_template_local()
row = struct();
row.az_hat = [NaN, NaN];
row.el_hat = [NaN, NaN];
row.el_center_hat = NaN;
row.el_sep_hat = NaN;
row.orientation_hat = NaN;
row.score = -Inf;
row.iAz1 = NaN;
row.iAz2 = NaN;
row.iElCenter = NaN;
row.iElSep = NaN;
row.iEl1 = NaN;
row.iEl2 = NaN;
row.el1_value = NaN;
row.el2_value = NaN;
end

function candidate_rows = normalize_candidate_rows_local(candidate_rows)
if ~isnumeric(candidate_rows) || size(candidate_rows, 2) < 7
    error('search_pair2d_degree_grid_cached:InvalidCandidateRows', ...
        'grid_cfg.candidate_rows must be numeric with columns [az1 az2 el1 el2 el_center el_sep_deg orientation].');
end
candidate_rows = candidate_rows(:, 1:7);
finite_mask = all(isfinite(candidate_rows), 2);
ordered_mask = candidate_rows(:, 1) < candidate_rows(:, 2);
candidate_rows = candidate_rows(finite_mask & ordered_mask, :);
candidate_rows(:, 1:6) = round(candidate_rows(:, 1:6) * 1e10) / 1e10;
candidate_rows(:, 7) = sign(candidate_rows(:, 7));
candidate_rows = unique(candidate_rows, 'rows', 'stable');
if isempty(candidate_rows)
    error('search_pair2d_degree_grid_cached:NoExplicitCandidateRows', ...
        'No valid explicit degree-based candidate rows remain after normalization.');
end
end

function [valid_rows, el_info] = make_explicit_el_rows_local(candidate_rows, el_center_grid, el_sep_deg_list, grid_cfg)
el_key = candidate_rows(:, 3:7);
[unique_el_key, ~, group_idx] = unique(el_key, 'rows', 'stable');
valid_rows = repmat(make_explicit_el_row_local(), size(unique_el_key, 1), 1);
for idx = 1:size(unique_el_key, 1)
    group_mask = group_idx == idx;
    valid_rows(idx).el1 = unique_el_key(idx, 1);
    valid_rows(idx).el2 = unique_el_key(idx, 2);
    valid_rows(idx).el_center = unique_el_key(idx, 3);
    valid_rows(idx).el_sep_deg = unique_el_key(idx, 4);
    valid_rows(idx).orientation = unique_el_key(idx, 5);
    valid_rows(idx).i_el_center = find(abs(el_center_grid - valid_rows(idx).el_center) < 1e-10, 1);
    valid_rows(idx).i_el_sep = find(abs(el_sep_deg_list - valid_rows(idx).el_sep_deg) < 1e-10, 1);
    valid_rows(idx).valid = true;
    valid_rows(idx).az_pair_list = candidate_rows(group_mask, 1:2);
end
el_info = struct();
el_info.num_candidates = size(candidate_rows, 1);
el_info.num_valid = size(candidate_rows, 1);
el_info.el_sep_deg_list = el_sep_deg_list;
el_info.orientation_list = grid_cfg.search_orientations;
el_info.el_bounds = grid_cfg.el_bounds;
el_info.el_center_grid = el_center_grid;
el_info.rows = valid_rows;
end

function row = make_explicit_el_row_local()
row = struct();
row.el1 = NaN;
row.el2 = NaN;
row.el_center = NaN;
row.el_sep_deg = NaN;
row.orientation = NaN;
row.i_el_center = NaN;
row.i_el_sep = NaN;
row.valid = false;
row.az_pair_list = zeros(0, 2);
end

function az_pair_indices = lookup_explicit_az_pair_indices_local(az_pair_list, az_grid)
[tf1, iAz1] = ismember(round(az_pair_list(:, 1) * 1e10) / 1e10, az_grid);
[tf2, iAz2] = ismember(round(az_pair_list(:, 2) * 1e10) / 1e10, az_grid);
if any(~tf1 | ~tf2)
    error('search_pair2d_degree_grid_cached:AzLookupFailed', ...
        'Could not locate explicit az pair values in the precomputed az grid.');
end
az_pair_indices = [iAz1, iAz2];
az_pair_indices = az_pair_indices(az_pair_indices(:, 1) < az_pair_indices(:, 2), :);
az_pair_indices = unique(az_pair_indices, 'rows', 'stable');
end
