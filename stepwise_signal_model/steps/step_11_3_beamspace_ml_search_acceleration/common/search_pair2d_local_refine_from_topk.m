function [est_refined, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, x, y, z, lambda, top_candidates, refine_cfg, manifold_opts, search_opts)
%SEARCH_PAIR2D_LOCAL_REFINE_FROM_TOPK Refine each coarse topK candidate on a local fine grid.

if nargin < 10
    error('search_pair2d_local_refine_from_topk:NotEnoughInputs', ...
        'Z, W, x, y, z, lambda, top_candidates, refine_cfg, manifold_opts, and search_opts are required.');
end
if isempty(top_candidates)
    error('search_pair2d_local_refine_from_topk:EmptyCandidates', 'top_candidates must not be empty.');
end
required = {'local_az_half_width','local_el_half_width','fine_az_step','fine_el_step','el_sep_index_list','search_orientations'};
for idx = 1:numel(required)
    if ~isfield(refine_cfg, required{idx})
        error('search_pair2d_local_refine_from_topk:MissingRefineField', 'refine_cfg.%s is required.', required{idx});
    end
end
if ~isfield(refine_cfg, 'az_global_bounds')
    refine_cfg.az_global_bounds = [-Inf, Inf];
end
if ~isfield(refine_cfg, 'el_global_bounds')
    refine_cfg.el_global_bounds = [-Inf, Inf];
end

best_score = -Inf;
best_idx = NaN;
est_refined = struct('az_hat', [NaN, NaN], 'el_hat', [NaN, NaN], ...
    'el_center_hat', NaN, 'el_sep_hat', NaN, 'orientation_hat', NaN);
best_debug = struct();
per_candidate_num_pairs = nan(numel(top_candidates), 1);
per_candidate_max_score = nan(numel(top_candidates), 1);
per_candidate_az_min = nan(numel(top_candidates), 1);
per_candidate_az_max = nan(numel(top_candidates), 1);
per_candidate_el_min = nan(numel(top_candidates), 1);
per_candidate_el_max = nan(numel(top_candidates), 1);
per_candidate_error_text = cell(numel(top_candidates), 1);

for idx = 1:numel(top_candidates)
    candidate = top_candidates(idx);
    az_bounds = [min(candidate.az_hat) - refine_cfg.local_az_half_width, ...
        max(candidate.az_hat) + refine_cfg.local_az_half_width];
    el_bounds = candidate.el_center_hat + [-refine_cfg.local_el_half_width, refine_cfg.local_el_half_width];
    az_bounds = clamp_bounds_local(az_bounds, refine_cfg.az_global_bounds);
    el_bounds = clamp_bounds_local(el_bounds, refine_cfg.el_global_bounds);
    per_candidate_az_min(idx) = az_bounds(1);
    per_candidate_az_max(idx) = az_bounds(2);
    per_candidate_el_min(idx) = el_bounds(1);
    per_candidate_el_max(idx) = el_bounds(2);

    grid_cfg = make_grid_cfg_local(candidate, az_bounds, el_bounds, refine_cfg);
    try
        [est_now, debug_now] = search_separable_local_grid_local(Z, W, x, y, z, lambda, grid_cfg, manifold_opts, search_opts);
        per_candidate_num_pairs(idx) = debug_now.num_pairs;
        per_candidate_max_score(idx) = debug_now.max_score;
        if debug_now.max_score > best_score
            best_score = debug_now.max_score;
            best_idx = idx;
            est_refined = est_now;
            best_debug = debug_now;
        end
    catch ME
        per_candidate_num_pairs(idx) = grid_cfg.estimated_num_candidates;
        per_candidate_error_text{idx} = ME.message;
    end
end

if ~isfinite(best_score)
    error('search_pair2d_local_refine_from_topk:NoFiniteRefineScore', 'No finite local refine score was found.');
end

refine_debug = struct();
refine_debug.search_mode = 'local_refine_from_topk';
refine_debug.topK = numel(top_candidates);
refine_debug.best_candidate_index = best_idx;
refine_debug.max_score = best_score;
refine_debug.num_pairs = sum(per_candidate_num_pairs(isfinite(per_candidate_num_pairs)));
refine_debug.total_num_pairs_raw = refine_debug.num_pairs;
refine_debug.per_candidate_num_pairs = per_candidate_num_pairs;
refine_debug.per_candidate_max_score = per_candidate_max_score;
refine_debug.per_candidate_az_bounds = [per_candidate_az_min, per_candidate_az_max];
refine_debug.per_candidate_el_bounds = [per_candidate_el_min, per_candidate_el_max];
refine_debug.per_candidate_error_text = per_candidate_error_text;
refine_debug.best_debug = best_debug;
refine_debug.cond_best_GHG = best_debug.cond_best_GHG;
refine_debug.rank_best_G = best_debug.rank_best_G;
refine_debug.grid_cfg_best = best_debug.grid_cfg;
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

function grid_cfg = make_grid_cfg_local(candidate, az_bounds, el_bounds, refine_cfg)
az_grid_1 = make_axis_local(candidate.az_hat(1) - refine_cfg.local_az_half_width, ...
    candidate.az_hat(1) + refine_cfg.local_az_half_width, refine_cfg.fine_az_step);
az_grid_2 = make_axis_local(candidate.az_hat(2) - refine_cfg.local_az_half_width, ...
    candidate.az_hat(2) + refine_cfg.local_az_half_width, refine_cfg.fine_az_step);
az_grid_1 = az_grid_1(az_grid_1 >= az_bounds(1) - 1e-9 & az_grid_1 <= az_bounds(2) + 1e-9);
az_grid_2 = az_grid_2(az_grid_2 >= az_bounds(1) - 1e-9 & az_grid_2 <= az_bounds(2) + 1e-9);
el_grid = make_axis_local(el_bounds(1), el_bounds(2), refine_cfg.fine_el_step);
num_oriented_sep = 0;
for iSep = 1:numel(refine_cfg.el_sep_index_list)
    sep_idx = refine_cfg.el_sep_index_list(iSep);
    if sep_idx == 0
        num_oriented_sep = num_oriented_sep + 1;
    else
        num_oriented_sep = num_oriented_sep + numel(refine_cfg.search_orientations);
    end
end
grid_cfg = struct();
grid_cfg.az_grid = unique([az_grid_1(:); az_grid_2(:)]).';
grid_cfg.az_grid_1 = az_grid_1;
grid_cfg.az_grid_2 = az_grid_2;
grid_cfg.el_grid = el_grid;
grid_cfg.az_step = refine_cfg.fine_az_step;
grid_cfg.el_step = refine_cfg.fine_el_step;
grid_cfg.el_sep_index_list = refine_cfg.el_sep_index_list;
grid_cfg.search_orientations = refine_cfg.search_orientations;
grid_cfg.az_bounds = az_bounds;
grid_cfg.el_bounds = el_bounds;
grid_cfg.az_center = mean(candidate.az_hat);
grid_cfg.el_center = mean(el_bounds);
az_pair_count = sum(az_grid_1(:) < az_grid_2(:).', 'all');
grid_cfg.estimated_num_candidates = az_pair_count * numel(el_grid) * num_oriented_sep;
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

function [est, debug] = search_separable_local_grid_local(Z, W, x, y, z, lambda, grid_cfg, manifold_opts, search_opts)
reg = search_opts.reg;
az_grid_1 = grid_cfg.az_grid_1(:).';
az_grid_2 = grid_cfg.az_grid_2(:).';
el_grid = grid_cfg.el_grid(:).';
N_az1 = numel(az_grid_1);
N_az2 = numel(az_grid_2);
N_el = numel(el_grid);
B = size(W, 2);
if N_az1 < 1 || N_az2 < 1 || N_el < 1
    error('search_pair2d_local_refine_from_topk:EmptyLocalGrid', 'Local refine grid is empty.');
end

grid1 = precompute_beamspace_azel_grid(W, x, y, z, az_grid_1, el_grid, lambda, ...
    'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);
grid2 = precompute_beamspace_azel_grid(W, x, y, z, az_grid_2, el_grid, lambda, ...
    'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);
G1_flat = reshape(grid1.G_grid, B, N_az1 * N_el);
G2_flat = reshape(grid2.G_grid, B, N_az2 * N_el);
[Z_use, G_both_flat, winfo] = apply_beamspace_whitening(Z, [G1_flat, G2_flat], W, search_opts.whitening_mode, ...
    'eps_reg', max(reg, 1e-12));
G1_use_grid = reshape(G_both_flat(:, 1:(N_az1 * N_el)), B, N_az1, N_el);
G2_use_grid = reshape(G_both_flat(:, (N_az1 * N_el + 1):end), B, N_az2, N_el);

max_score = -Inf;
num_pairs = 0;
best = struct('iAz1', NaN, 'iAz2', NaN, 'iElCenter', NaN, 'sepIndex', NaN, ...
    'orientation', NaN, 'iEl1', NaN, 'iEl2', NaN);
for iElCenter = 1:N_el
    for iSep = 1:numel(grid_cfg.el_sep_index_list)
        sep_index = grid_cfg.el_sep_index_list(iSep);
        orientations_now = grid_cfg.search_orientations;
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
            G1 = G1_use_grid(:, :, iEl1);
            G2 = G2_use_grid(:, :, iEl2);
            [score_map, slice_pairs] = score_rect_cross_el_local(Z_use, G1, G2, az_grid_1, az_grid_2, reg);
            num_pairs = num_pairs + slice_pairs;
            score_for_max = score_map;
            score_for_max(~isfinite(score_for_max)) = -Inf;
            [slice_max, linear_idx] = max(score_for_max(:));
            if slice_max > max_score
                [iAz1, iAz2] = ind2sub(size(score_for_max), linear_idx);
                max_score = slice_max;
                best.iAz1 = iAz1;
                best.iAz2 = iAz2;
                best.iElCenter = iElCenter;
                best.sepIndex = sep_index;
                best.orientation = orientation;
                best.iEl1 = iEl1;
                best.iEl2 = iEl2;
            end
        end
    end
end

if ~isfinite(max_score)
    error('search_pair2d_local_refine_from_topk:NoFiniteLocalScore', 'No finite separable local refine score was found.');
end

est = struct();
est.az_hat = [az_grid_1(best.iAz1), az_grid_2(best.iAz2)];
est.el_hat = [el_grid(best.iEl1), el_grid(best.iEl2)];
est.el_center_hat = el_grid(best.iElCenter);
est.el_sep_hat = abs(el_grid(best.iEl2) - el_grid(best.iEl1));
est.orientation_hat = best.orientation;

G_best = [G1_use_grid(:, best.iAz1, best.iEl1), G2_use_grid(:, best.iAz2, best.iEl2)];
[~, best_debug] = beamspace_dml_score(Z_use, G_best, 'reg', reg);

debug = struct();
debug.search_mode = 'separable_local_refine_grid';
debug.num_pairs = num_pairs;
debug.max_score = max_score;
debug.cond_best_GHG = best_debug.cond_GHG;
debug.rank_best_G = best_debug.rank_G;
debug.best_i_az1 = best.iAz1;
debug.best_i_az2 = best.iAz2;
debug.best_i_el_center = best.iElCenter;
debug.best_el_sep_index = best.sepIndex;
debug.best_orientation = best.orientation;
debug.whitening_info = winfo;
debug.grid_cfg = grid_cfg;
end

function [score_map, num_pairs] = score_rect_cross_el_local(Z, G1, G2, az_grid_1, az_grid_2, reg)
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
mask = az_grid_1(:) < az_grid_2(:).';
score_map(~mask) = NaN;
score_map(~isfinite(score_map) & mask) = -Inf;
num_pairs = nnz(mask);
end
