function [az_hat, score_map, debug] = search_pair_grid_ordered_precomputed(Z, W, grid, cfg)
%SEARCH_PAIR_GRID_ORDERED_PRECOMPUTED Ordered pair search on precomputed beamspace steering.

if nargin < 4
    error('search_pair_grid_ordered_precomputed:NotEnoughInputs', 'Z, W, grid, and cfg are required.');
end
if ~isfield(grid, 'az_grid_deg') || ~isfield(grid, 'G_grid')
    error('search_pair_grid_ordered_precomputed:InvalidGrid', 'grid must contain az_grid_deg and G_grid.');
end
if ~isfield(cfg, 'whitening_mode')
    error('search_pair_grid_ordered_precomputed:MissingWhiteningMode', 'cfg.whitening_mode is required.');
end

reg = 1e-10;
if isfield(cfg, 'reg')
    reg = cfg.reg;
end
if ~(isscalar(reg) && isfinite(reg) && reg >= 0)
    error('search_pair_grid_ordered_precomputed:InvalidReg', 'cfg.reg must be a non-negative finite scalar.');
end

az_grid = grid.az_grid_deg(:).';
G_grid = grid.G_grid;
if size(Z, 1) ~= size(W, 2) || size(G_grid, 1) ~= size(W, 2)
    error('search_pair_grid_ordered_precomputed:BeamDimMismatch', 'Z, W, and grid.G_grid beam dimensions must agree.');
end
if size(G_grid, 2) ~= numel(az_grid)
    error('search_pair_grid_ordered_precomputed:GridShapeMismatch', 'grid.G_grid column count must equal numel(az_grid).');
end

[Z_use, G_use, winfo] = apply_beamspace_whitening(Z, G_grid, W, cfg.whitening_mode, 'eps_reg', max(reg, 1e-12));
[score_map, max_score, best_i, best_j, num_pairs] = score_ordered_grid_local(Z_use, G_use, reg);

az_hat = [az_grid(best_i), az_grid(best_j)];
G_best = [G_use(:, best_i), G_use(:, best_j)];
[~, best_debug] = beamspace_dml_score(Z_use, G_best, 'reg', reg);

debug = struct();
debug.search_mode = 'ordered_precomputed';
debug.whitening_mode = lower(char(cfg.whitening_mode));
debug.num_pairs = num_pairs;
debug.max_score = max_score;
debug.best_i = best_i;
debug.best_j = best_j;
debug.cond_best_GHG = best_debug.cond_GHG;
debug.rank_best_G = best_debug.rank_G;
debug.cond_WHW = cond(W' * W + max(reg, 1e-12) * eye(size(W, 2)));
debug.whitening_info = winfo;
end

function [score_map, max_score, best_i, best_j, num_pairs] = score_ordered_grid_local(Z, G, reg)
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

if ~isfinite(max_score)
    error('search_pair_grid_ordered_precomputed:NoFiniteScore', 'No finite DML score was found.');
end
end
