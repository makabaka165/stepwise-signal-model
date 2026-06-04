function [theta_hat, score_map, debug] = search_pair_grid_ordered(Z, W, cfg)
%SEARCH_PAIR_GRID_ORDERED Search all ordered theta1 < theta2 pairs.

required_fields = {'beam_c', 'beam_width', 'grid_step_deg', 'array_num', 'd', 'lambda'};
check_cfg_local(cfg, required_fields);
check_dims_local(Z, W, cfg.array_num);

theta_grid = cfg.beam_c - cfg.beam_width/2 : cfg.grid_step_deg : cfg.beam_c + cfg.beam_width/2;
if numel(theta_grid) < 2
    error('search_pair_grid_ordered:EmptyGrid', 'theta_grid must contain at least two points.');
end

reg = get_reg_local(cfg);
[score_map, max_score, best_i, best_j, num_pairs] = score_ordered_grid_local(Z, W, theta_grid, cfg, reg);
theta_hat = [theta_grid(best_i), theta_grid(best_j)];

debug = struct();
debug.theta_grid = theta_grid;
debug.max_score = max_score;
debug.search_mode = 'ordered';
debug.num_pairs = num_pairs;
end

function [score_map, max_score, best_i, best_j, num_pairs] = score_ordered_grid_local(Z, W, theta_grid, cfg, reg)
A = build_grid_manifold_local(theta_grid, cfg.array_num, cfg.d, cfg.lambda);
G = W' * A;
Rz = Z * Z';

S = G' * G;
Q = G' * Rz * G;

sdiag = real(diag(S)) + reg;
qdiag = real(diag(Q));

Sii = repmat(sdiag, 1, numel(theta_grid));
Sjj = repmat(sdiag.', numel(theta_grid), 1);
Qii = repmat(qdiag, 1, numel(theta_grid));
Qjj = repmat(qdiag.', numel(theta_grid), 1);

den = Sii .* Sjj - abs(S).^2;
score_map = real((Qii .* Sjj + Sii .* Qjj - S .* Q.' - conj(S) .* Q) ./ den);
mask = triu(true(numel(theta_grid)), 1);
score_map(~mask) = NaN;
score_map(~isfinite(score_map) & mask) = -Inf;

score_for_max = score_map;
score_for_max(~mask) = -Inf;
[max_score, linear_idx] = max(score_for_max(:));
[best_i, best_j] = ind2sub(size(score_map), linear_idx);
num_pairs = nnz(mask);

if ~isfinite(max_score)
    error('search_pair_grid_ordered:NoFiniteScore', 'No finite DML score was found.');
end
end

function A = build_grid_manifold_local(theta_grid, array_num, d, lambda)
position = d * (0:array_num-1).';
A = exp(-1j * 2*pi/lambda * position * sind(theta_grid(:).'));
if size(A, 1) ~= array_num || size(A, 2) ~= numel(theta_grid)
    error('search_pair_grid_ordered:GridManifoldShapeMismatch', 'Grid manifold shape mismatch.');
end
end

function check_cfg_local(cfg, required_fields)
if ~isstruct(cfg)
    error('search_pair_grid_ordered:InvalidCfg', 'cfg must be a struct.');
end
for idx = 1:numel(required_fields)
    if ~isfield(cfg, required_fields{idx})
        error('search_pair_grid_ordered:MissingCfgField', 'Missing cfg.%s.', required_fields{idx});
    end
end
if ~(cfg.grid_step_deg > 0 && cfg.beam_width > 0)
    error('search_pair_grid_ordered:InvalidGrid', 'grid_step_deg and beam_width must be positive.');
end
end

function check_dims_local(Z, W, array_num)
if ndims(Z) ~= 2 || ndims(W) ~= 2
    error('search_pair_grid_ordered:InvalidDims', 'Z and W must be matrices.');
end
if size(W, 1) ~= array_num
    error('search_pair_grid_ordered:WArrayMismatch', 'size(W,1) must equal cfg.array_num.');
end
if size(Z, 1) ~= size(W, 2)
    error('search_pair_grid_ordered:BeamDimMismatch', 'size(Z,1) must equal size(W,2).');
end
end

function reg = get_reg_local(cfg)
reg = 1e-10;
if isfield(cfg, 'reg')
    reg = cfg.reg;
end
if ~(isscalar(reg) && isfinite(reg) && reg >= 0)
    error('search_pair_grid_ordered:InvalidReg', 'cfg.reg must be a non-negative finite scalar.');
end
end
