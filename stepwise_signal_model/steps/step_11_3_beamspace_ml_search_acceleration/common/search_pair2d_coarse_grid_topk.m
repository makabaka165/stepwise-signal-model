function [top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, x, y, z, lambda, grid_cfg_coarse, manifold_opts, search_opts, topK)
%SEARCH_PAIR2D_COARSE_GRID_TOPK Coarse controlled pair2d search with topK retention.

if nargin < 10
    error('search_pair2d_coarse_grid_topk:NotEnoughInputs', ...
        'Z, W, x, y, z, lambda, grid_cfg_coarse, manifold_opts, search_opts, and topK are required.');
end
if ~(isscalar(topK) && isfinite(topK) && topK >= 1)
    error('search_pair2d_coarse_grid_topk:InvalidTopK', 'topK must be a positive scalar.');
end
topK = floor(topK);
if ~isfield(manifold_opts, 'phase_factor')
    manifold_opts.phase_factor = 1;
end
if ~isfield(manifold_opts, 'phase_sign')
    manifold_opts.phase_sign = 1;
end
validate_grid_cfg_local(grid_cfg_coarse);
validate_opts_local(search_opts);

grid = precompute_beamspace_azel_grid(W, x, y, z, grid_cfg_coarse.az_grid, grid_cfg_coarse.el_grid, lambda, ...
    'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);

reg = search_opts.reg;
az_grid = grid.az_grid_deg(:).';
el_grid = grid.el_grid_deg(:).';
G_grid = grid.G_grid;
N_az = numel(az_grid);
N_el = numel(el_grid);
B = size(W, 2);
if size(Z, 1) ~= B || size(G_grid, 1) ~= B || size(G_grid, 2) ~= N_az || size(G_grid, 3) ~= N_el
    error('search_pair2d_coarse_grid_topk:ShapeMismatch', 'Z, W, and grid dimensions must agree.');
end

[Z_use, G_grid_flat, winfo] = apply_beamspace_whitening(Z, reshape(G_grid, B, N_az * N_el), W, search_opts.whitening_mode, ...
    'eps_reg', max(reg, 1e-12));
G_use_grid = reshape(G_grid_flat, B, N_az, N_el);

top_candidates = repmat(make_candidate_template_local(), 0, 1);
num_pairs = 0;
finite_slice_count = 0;

for iElCenter = 1:N_el
    for iSep = 1:numel(grid_cfg_coarse.el_sep_index_list)
        sep_index = grid_cfg_coarse.el_sep_index_list(iSep);
        orientations_now = grid_cfg_coarse.search_orientations;
        if sep_index == 0
            orientations_now = 1;
        end
        for iOri = 1:numel(orientations_now)
            orientation = orientations_now(iOri);
            if orientation == 1
                iEl1 = iElCenter - sep_index;
                iEl2 = iElCenter + sep_index;
            else
                iEl1 = iElCenter + sep_index;
                iEl2 = iElCenter - sep_index;
            end
            if iEl1 < 1 || iEl1 > N_el || iEl2 < 1 || iEl2 > N_el
                continue;
            end

            G1 = G_use_grid(:, :, iEl1);
            G2 = G_use_grid(:, :, iEl2);
            [score_map, slice_pairs] = score_ordered_cross_el_local(Z_use, G1, G2, reg);
            num_pairs = num_pairs + slice_pairs;
            slice_candidates = extract_topk_from_score_map_local(score_map, topK, az_grid, el_grid, ...
                iElCenter, sep_index, orientation, iEl1, iEl2);
            if ~isempty(slice_candidates)
                finite_slice_count = finite_slice_count + 1;
                top_candidates = merge_topk_candidates_local(top_candidates, slice_candidates, topK);
            end
        end
    end
end

if isempty(top_candidates)
    error('search_pair2d_coarse_grid_topk:NoFiniteScore', 'No finite coarse-grid DML score was found.');
end

top_candidates = sort_candidates_local(top_candidates);
best = top_candidates(1);
G_best = [G_use_grid(:, best.iAz1, best.iEl1), G_use_grid(:, best.iAz2, best.iEl2)];
[~, best_debug] = beamspace_dml_score(Z_use, G_best, 'reg', reg);

score_gap = 0;
if numel(top_candidates) >= 2
    score_gap = top_candidates(1).score - top_candidates(end).score;
end

coarse_debug = struct();
coarse_debug.search_mode = 'coarse_grid_topk';
coarse_debug.whitening_mode = lower(char(search_opts.whitening_mode));
coarse_debug.num_pairs = num_pairs;
coarse_debug.topK_requested = topK;
coarse_debug.topK_returned = numel(top_candidates);
coarse_debug.finite_slice_count = finite_slice_count;
coarse_debug.max_score = top_candidates(1).score;
coarse_debug.score_gap_top1_topK = score_gap;
coarse_debug.best_i_az1 = best.iAz1;
coarse_debug.best_i_az2 = best.iAz2;
coarse_debug.best_i_el_center = best.iElCenter;
coarse_debug.best_el_sep_index = best.sepIndex;
coarse_debug.best_orientation = best.orientation_hat;
coarse_debug.cond_best_GHG = best_debug.cond_GHG;
coarse_debug.rank_best_G = best_debug.rank_G;
coarse_debug.cond_WHW = cond(W' * W + max(reg, 1e-12) * eye(B));
coarse_debug.whitening_info = winfo;
coarse_debug.grid_cfg = grid_cfg_coarse;
end

function validate_grid_cfg_local(grid_cfg)
required = {'az_grid','el_grid','el_sep_index_list','search_orientations'};
for idx = 1:numel(required)
    if ~isfield(grid_cfg, required{idx})
        error('search_pair2d_coarse_grid_topk:MissingGridField', 'grid_cfg_coarse.%s is required.', required{idx});
    end
end
if numel(grid_cfg.az_grid) < 2 || numel(grid_cfg.el_grid) < 1
    error('search_pair2d_coarse_grid_topk:InvalidGrid', 'The coarse az/el grid is too small.');
end
if any(grid_cfg.el_sep_index_list < 0) || any(grid_cfg.el_sep_index_list ~= floor(grid_cfg.el_sep_index_list))
    error('search_pair2d_coarse_grid_topk:InvalidElSepIndex', 'el_sep_index_list must contain non-negative integers.');
end
if any(~ismember(grid_cfg.search_orientations, [-1, 1]))
    error('search_pair2d_coarse_grid_topk:InvalidOrientation', 'search_orientations must contain +1 and/or -1.');
end
end

function validate_opts_local(search_opts)
if ~isfield(search_opts, 'whitening_mode')
    error('search_pair2d_coarse_grid_topk:MissingWhiteningMode', 'search_opts.whitening_mode is required.');
end
if ~isfield(search_opts, 'reg')
    error('search_pair2d_coarse_grid_topk:MissingReg', 'search_opts.reg is required.');
end
end

function [score_map, num_pairs] = score_ordered_cross_el_local(Z, G1, G2, reg)
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
mask = triu(true(Ngrid), 1);
score_map(~mask) = NaN;
score_map(~isfinite(score_map) & mask) = -Inf;
num_pairs = nnz(mask);
end

function candidates = extract_topk_from_score_map_local(score_map, topK, az_grid, el_grid, iElCenter, sep_index, orientation, iEl1, iEl2)
score_for_sort = score_map;
score_for_sort(~isfinite(score_for_sort)) = -Inf;
[scores_sorted, order] = sort(score_for_sort(:), 'descend');
finite_mask = isfinite(scores_sorted) & scores_sorted > -Inf;
scores_sorted = scores_sorted(finite_mask);
order = order(finite_mask);
keep_n = min(topK, numel(scores_sorted));
candidates = repmat(make_candidate_template_local(), keep_n, 1);
for idx = 1:keep_n
    [iAz1, iAz2] = ind2sub(size(score_map), order(idx));
    row = make_candidate_template_local();
    row.az_hat = [az_grid(iAz1), az_grid(iAz2)];
    row.el_hat = [el_grid(iEl1), el_grid(iEl2)];
    row.el_center_hat = el_grid(iElCenter);
    row.el_sep_hat = abs(el_grid(iEl2) - el_grid(iEl1));
    row.orientation_hat = orientation;
    row.score = scores_sorted(idx);
    row.iAz1 = iAz1;
    row.iAz2 = iAz2;
    row.iElCenter = iElCenter;
    row.sepIndex = sep_index;
    row.iEl1 = iEl1;
    row.iEl2 = iEl2;
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
row.sepIndex = NaN;
row.iEl1 = NaN;
row.iEl2 = NaN;
end
