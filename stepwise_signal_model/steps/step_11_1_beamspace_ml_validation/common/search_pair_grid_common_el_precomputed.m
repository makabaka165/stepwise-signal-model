function [est, score_cube, debug] = search_pair_grid_common_el_precomputed(Z, W, grid, cfg)
%SEARCH_PAIR_GRID_COMMON_EL_PRECOMPUTED Search az1 < az2 and common elevation.

if nargin < 4
    error('search_pair_grid_common_el_precomputed:NotEnoughInputs', 'Z, W, grid, and cfg are required.');
end
if ~isfield(grid, 'G_grid') || ~isfield(grid, 'az_grid_deg') || ~isfield(grid, 'el_grid_deg')
    error('search_pair_grid_common_el_precomputed:InvalidGrid', 'grid must contain G_grid, az_grid_deg, and el_grid_deg.');
end
if ~isfield(cfg, 'whitening_mode')
    error('search_pair_grid_common_el_precomputed:MissingWhiteningMode', 'cfg.whitening_mode is required.');
end

reg = 1e-10;
if isfield(cfg, 'reg')
    reg = cfg.reg;
end
if ~(isscalar(reg) && isfinite(reg) && reg >= 0)
    error('search_pair_grid_common_el_precomputed:InvalidReg', 'cfg.reg must be a non-negative finite scalar.');
end

az_grid = grid.az_grid_deg(:).';
el_grid = grid.el_grid_deg(:).';
G_grid = grid.G_grid;
N_az = numel(az_grid);
N_el = numel(el_grid);
B = size(W, 2);
if size(Z, 1) ~= B || size(G_grid, 1) ~= B || size(G_grid, 2) ~= N_az || size(G_grid, 3) ~= N_el
    error('search_pair_grid_common_el_precomputed:ShapeMismatch', 'Z, W, and grid dimensions must agree.');
end

[Z_use, G_grid_flat, winfo] = apply_beamspace_whitening(Z, reshape(G_grid, B, N_az*N_el), W, cfg.whitening_mode, ...
    'eps_reg', max(reg, 1e-12));
G_use_grid = reshape(G_grid_flat, B, N_az, N_el);

score_cube = NaN(N_az, N_az, N_el);
max_score = -Inf;
best_i_az1 = NaN;
best_i_az2 = NaN;
best_i_el = NaN;
num_pairs = 0;
tie_count = 0;

for iEl = 1:N_el
    G_el = G_use_grid(:, :, iEl);
    [score_slice, slice_max, iAz1, iAz2, slice_pairs, slice_ties] = score_ordered_slice_local(Z_use, G_el, reg);
    score_cube(:, :, iEl) = score_slice;
    num_pairs = num_pairs + slice_pairs;
    if slice_max > max_score
        max_score = slice_max;
        best_i_az1 = iAz1;
        best_i_az2 = iAz2;
        best_i_el = iEl;
        tie_count = slice_ties;
    elseif slice_max == max_score
        tie_count = tie_count + slice_ties;
    end
end

if ~isfinite(max_score)
    error('search_pair_grid_common_el_precomputed:NoFiniteScore', 'No finite DML score was found.');
end

est = struct();
est.az_hat = [az_grid(best_i_az1), az_grid(best_i_az2)];
est.el_hat = el_grid(best_i_el);

G_best = [G_use_grid(:, best_i_az1, best_i_el), G_use_grid(:, best_i_az2, best_i_el)];
[~, best_debug] = beamspace_dml_score(Z_use, G_best, 'reg', reg);

debug = struct();
debug.search_mode = 'common_el_ordered_precomputed';
debug.whitening_mode = lower(char(cfg.whitening_mode));
debug.num_pairs = num_pairs;
debug.max_score = max_score;
debug.best_i_az1 = best_i_az1;
debug.best_i_az2 = best_i_az2;
debug.best_i_el = best_i_el;
debug.tie_count = tie_count;
debug.cond_best_GHG = best_debug.cond_GHG;
debug.rank_best_G = best_debug.rank_G;
debug.cond_WHW = cond(W' * W + max(reg, 1e-12) * eye(B));
debug.whitening_info = winfo;
end

function [score_map, max_score, best_i, best_j, num_pairs, tie_count] = score_ordered_slice_local(Z, G, reg)
Ngrid = size(G, 2);
Rz = Z * Z';
S = G' * G;
Q = G' * Rz * G;

sdiag = real(diag(S)) + reg;
qdiag = real(diag(Q));
Sii = repmat(sdiag, 1, Ngrid);
Sjj = repmat(sdiag.', Ngrid, 1);
Qii = repmat(qdiag, 1, Ngrid);
Qjj = repmat(qdiag.', Ngrid, 1);

den = Sii .* Sjj - abs(S).^2;
score_map = real((Qii .* Sjj + Sii .* Qjj - S .* Q.' - conj(S) .* Q) ./ den);
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
