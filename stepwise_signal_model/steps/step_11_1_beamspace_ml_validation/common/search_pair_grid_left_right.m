function [theta_hat, score_map, debug] = search_pair_grid_left_right(Z, W, cfg)
%SEARCH_PAIR_GRID_LEFT_RIGHT Search theta1 < beam_c < theta2.

required_fields = {'beam_c', 'beam_width', 'grid_step_deg', 'array_num', 'd', 'lambda'};
check_cfg_local(cfg, required_fields);
check_dims_local(Z, W, cfg.array_num);

theta1_grid = cfg.beam_c - cfg.beam_width/2 : cfg.grid_step_deg : cfg.beam_c;
theta2_grid = cfg.beam_c + cfg.grid_step_deg : cfg.grid_step_deg : cfg.beam_c + cfg.beam_width/2;

if isempty(theta1_grid) || isempty(theta2_grid)
    error('search_pair_grid_left_right:EmptyGrid', 'Search grids must not be empty.');
end

reg = get_reg_local(cfg);
[score_map, max_score, best_i, best_j, num_pairs] = score_pair_grid_local(Z, W, theta1_grid, theta2_grid, cfg, reg);
theta_hat = [theta1_grid(best_i), theta2_grid(best_j)];

debug = struct();
debug.theta1_grid = theta1_grid;
debug.theta2_grid = theta2_grid;
debug.max_score = max_score;
debug.search_mode = 'left_right';
debug.num_pairs = num_pairs;
end

function [score_map, max_score, best_i, best_j, num_pairs] = score_pair_grid_local(Z, W, theta1_grid, theta2_grid, cfg, reg)
A1 = build_grid_manifold_local(theta1_grid, cfg.array_num, cfg.d, cfg.lambda);
A2 = build_grid_manifold_local(theta2_grid, cfg.array_num, cfg.d, cfg.lambda);
G1 = W' * A1;
G2 = W' * A2;
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
score_map(~isfinite(score_map)) = -Inf;

[max_score, linear_idx] = max(score_map(:));
[best_i, best_j] = ind2sub(size(score_map), linear_idx);
num_pairs = numel(score_map);

if ~isfinite(max_score)
    theta_hat_fail = [NaN, NaN]; %#ok<NASGU>
    error('search_pair_grid_left_right:NoFiniteScore', 'No finite DML score was found.');
end
end

function A = build_grid_manifold_local(theta_grid, array_num, d, lambda)
position = d * (0:array_num-1).';
A = exp(-1j * 2*pi/lambda * position * sind(theta_grid(:).'));
if size(A, 1) ~= array_num || size(A, 2) ~= numel(theta_grid)
    error('search_pair_grid_left_right:GridManifoldShapeMismatch', 'Grid manifold shape mismatch.');
end
end

function check_cfg_local(cfg, required_fields)
if ~isstruct(cfg)
    error('search_pair_grid_left_right:InvalidCfg', 'cfg must be a struct.');
end
for idx = 1:numel(required_fields)
    if ~isfield(cfg, required_fields{idx})
        error('search_pair_grid_left_right:MissingCfgField', 'Missing cfg.%s.', required_fields{idx});
    end
end
if ~(cfg.grid_step_deg > 0 && cfg.beam_width > 0)
    error('search_pair_grid_left_right:InvalidGrid', 'grid_step_deg and beam_width must be positive.');
end
end

function check_dims_local(Z, W, array_num)
if ndims(Z) ~= 2 || ndims(W) ~= 2
    error('search_pair_grid_left_right:InvalidDims', 'Z and W must be matrices.');
end
if size(W, 1) ~= array_num
    error('search_pair_grid_left_right:WArrayMismatch', 'size(W,1) must equal cfg.array_num.');
end
if size(Z, 1) ~= size(W, 2)
    error('search_pair_grid_left_right:BeamDimMismatch', 'size(Z,1) must equal size(W,2).');
end
end

function reg = get_reg_local(cfg)
reg = 1e-10;
if isfield(cfg, 'reg')
    reg = cfg.reg;
end
if ~(isscalar(reg) && isfinite(reg) && reg >= 0)
    error('search_pair_grid_left_right:InvalidReg', 'cfg.reg must be a non-negative finite scalar.');
end
end
