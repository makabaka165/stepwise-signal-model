function [est, score_info, debug] = search_pair_grid_el_separation_precomputed(Z, W, grid, cfg)
%SEARCH_PAIR_GRID_EL_SEPARATION_PRECOMPUTED Controlled el-separated pair search.

if nargin < 4
    error('search_pair_grid_el_separation_precomputed:NotEnoughInputs', 'Z, W, grid, and cfg are required.');
end
required_fields = {'G_grid', 'az_grid_deg', 'el_grid_deg'};
for idx = 1:numel(required_fields)
    if ~isfield(grid, required_fields{idx})
        error('search_pair_grid_el_separation_precomputed:InvalidGrid', 'grid.%s is required.', required_fields{idx});
    end
end
if ~isfield(cfg, 'whitening_mode')
    error('search_pair_grid_el_separation_precomputed:MissingWhiteningMode', 'cfg.whitening_mode is required.');
end

reg = 1e-10;
if isfield(cfg, 'reg')
    reg = cfg.reg;
end
el_sep_index_list = [0, 1, 2];
if isfield(cfg, 'el_sep_index_list')
    el_sep_index_list = cfg.el_sep_index_list;
end
search_orientations = [1, -1];
if isfield(cfg, 'search_orientations')
    search_orientations = cfg.search_orientations;
end
keep_score_cube = false;
if isfield(cfg, 'keep_score_cube')
    keep_score_cube = logical(cfg.keep_score_cube);
end

az_grid = grid.az_grid_deg(:).';
el_grid = grid.el_grid_deg(:).';
G_grid = grid.G_grid;
N_az = numel(az_grid);
N_el = numel(el_grid);
B = size(W, 2);
if size(Z, 1) ~= B || size(G_grid, 1) ~= B || size(G_grid, 2) ~= N_az || size(G_grid, 3) ~= N_el
    error('search_pair_grid_el_separation_precomputed:ShapeMismatch', 'Z, W, and grid dimensions must agree.');
end
if any(el_sep_index_list < 0) || any(el_sep_index_list ~= floor(el_sep_index_list))
    error('search_pair_grid_el_separation_precomputed:InvalidElSepIndex', 'el_sep_index_list must contain non-negative integers.');
end
if any(~ismember(search_orientations, [-1, 1]))
    error('search_pair_grid_el_separation_precomputed:InvalidOrientation', 'search_orientations must contain +1 and/or -1.');
end

[Z_use, G_grid_flat, winfo] = apply_beamspace_whitening(Z, reshape(G_grid, B, N_az*N_el), W, cfg.whitening_mode, ...
    'eps_reg', max(reg, 1e-12));
G_use_grid = reshape(G_grid_flat, B, N_az, N_el);

if keep_score_cube
    score_records = [];
else
    score_records = [];
end

max_score = -Inf;
tie_count = 0;
num_pairs = 0;
best = struct('iAz1', NaN, 'iAz2', NaN, 'iElCenter', NaN, 'sepIndex', NaN, 'orientation', NaN, ...
    'iEl1', NaN, 'iEl2', NaN);

for iElCenter = 1:N_el
    for iSep = 1:numel(el_sep_index_list)
        sep_index = el_sep_index_list(iSep);
        orientations_now = search_orientations;
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
            [score_map, slice_max, iAz1, iAz2, slice_pairs, slice_ties] = score_ordered_cross_el_local(Z_use, G1, G2, reg);
            num_pairs = num_pairs + slice_pairs;
            if keep_score_cube
                score_records = [score_records; iElCenter, sep_index, orientation, slice_max]; %#ok<AGROW>
            end
            if slice_max > max_score
                max_score = slice_max;
                tie_count = slice_ties;
                best.iAz1 = iAz1;
                best.iAz2 = iAz2;
                best.iElCenter = iElCenter;
                best.sepIndex = sep_index;
                best.orientation = orientation;
                best.iEl1 = iEl1;
                best.iEl2 = iEl2;
            elseif slice_max == max_score
                tie_count = tie_count + slice_ties;
            end
        end
    end
end

if ~isfinite(max_score)
    error('search_pair_grid_el_separation_precomputed:NoFiniteScore', 'No finite DML score was found.');
end

est = struct();
est.az_hat = [az_grid(best.iAz1), az_grid(best.iAz2)];
est.el_hat = [el_grid(best.iEl1), el_grid(best.iEl2)];
est.el_center_hat = el_grid(best.iElCenter);
est.el_sep_hat = abs(el_grid(best.iEl2) - el_grid(best.iEl1));
est.orientation_hat = best.orientation;

G_best = [G_use_grid(:, best.iAz1, best.iEl1), G_use_grid(:, best.iAz2, best.iEl2)];
[~, best_debug] = beamspace_dml_score(Z_use, G_best, 'reg', reg);

score_info = struct();
score_info.best_score = max_score;
score_info.score_records = score_records;

debug = struct();
debug.search_mode = 'el_separation_ordered_precomputed';
debug.whitening_mode = lower(char(cfg.whitening_mode));
debug.num_pairs = num_pairs;
debug.max_score = max_score;
debug.tie_count = tie_count;
debug.best_i_az1 = best.iAz1;
debug.best_i_az2 = best.iAz2;
debug.best_i_el_center = best.iElCenter;
debug.best_el_sep_index = best.sepIndex;
debug.best_orientation = best.orientation;
debug.cond_best_GHG = best_debug.cond_GHG;
debug.rank_best_G = best_debug.rank_G;
debug.cond_WHW = cond(W' * W + max(reg, 1e-12) * eye(B));
debug.whitening_info = winfo;
end

function [score_map, max_score, best_i, best_j, num_pairs, tie_count] = score_ordered_cross_el_local(Z, G1, G2, reg)
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

score_for_max = score_map;
score_for_max(~mask) = -Inf;
[max_score, linear_idx] = max(score_for_max(:));
[best_i, best_j] = ind2sub(size(score_map), linear_idx);
num_pairs = nnz(mask);
tie_count = nnz(score_for_max(:) == max_score);
end
