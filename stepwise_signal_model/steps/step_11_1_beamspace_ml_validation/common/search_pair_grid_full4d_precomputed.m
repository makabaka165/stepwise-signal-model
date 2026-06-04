function [est, score_info, debug] = search_pair_grid_full4d_precomputed(Z, W, grid, cfg)
%SEARCH_PAIR_GRID_FULL4D_PRECOMPUTED Local full4d az-ordered beamspace DML search.

if nargin < 4
    error('search_pair_grid_full4d_precomputed:NotEnoughInputs', 'Z, W, grid, and cfg are required.');
end
required_fields = {'G_grid', 'az_grid_deg', 'el_grid_deg'};
for idx = 1:numel(required_fields)
    if ~isfield(grid, required_fields{idx})
        error('search_pair_grid_full4d_precomputed:InvalidGrid', 'grid.%s is required.', required_fields{idx});
    end
end
if ~isfield(cfg, 'whitening_mode')
    error('search_pair_grid_full4d_precomputed:MissingWhiteningMode', 'cfg.whitening_mode is required.');
end

reg = getfield_default_local(cfg, 'reg', 1e-10);
keep_score_tensor = logical(getfield_default_local(cfg, 'keep_score_tensor', false));
max_candidates = getfield_default_local(cfg, 'max_candidates', Inf);
topK = getfield_default_local(cfg, 'topK', 5);
if ~(isscalar(reg) && isfinite(reg) && reg >= 0)
    error('search_pair_grid_full4d_precomputed:InvalidReg', 'cfg.reg must be a non-negative finite scalar.');
end
if ~(isscalar(max_candidates) && max_candidates > 0)
    error('search_pair_grid_full4d_precomputed:InvalidMaxCandidates', 'cfg.max_candidates must be positive.');
end

az_grid = grid.az_grid_deg(:).';
el_grid = grid.el_grid_deg(:).';
G_grid = grid.G_grid;
N_az = numel(az_grid);
N_el = numel(el_grid);
B = size(W, 2);
if size(Z, 1) ~= B || size(G_grid, 1) ~= B || size(G_grid, 2) ~= N_az || size(G_grid, 3) ~= N_el
    error('search_pair_grid_full4d_precomputed:ShapeMismatch', 'Z, W, and grid dimensions must agree.');
end

num_candidates = nchoosek(N_az, 2) * N_el * N_el;
if num_candidates > max_candidates
    error('search_pair_grid_full4d_precomputed:TooManyCandidates', ...
        'full4d candidates=%d exceeds cfg.max_candidates=%g. Increase max_candidates or reduce the grid.', ...
        num_candidates, max_candidates);
end

[Z_use, G_grid_flat, winfo] = apply_beamspace_whitening(Z, reshape(G_grid, B, N_az*N_el), W, cfg.whitening_mode, ...
    'eps_reg', max(reg, 1e-12));
G_use_grid = reshape(G_grid_flat, B, N_az, N_el);
Rz = Z_use * Z_use';

max_score = -Inf;
tie_count = 0;
best = struct('iAz1', NaN, 'iAz2', NaN, 'iEl1', NaN, 'iEl2', NaN);
top_records = zeros(0, 5);
score_records = zeros(0, 5);

for iAz1 = 1:(N_az - 1)
    G1 = reshape(G_use_grid(:, iAz1, :), B, N_el);
    for iAz2 = (iAz1 + 1):N_az
        G2 = reshape(G_use_grid(:, iAz2, :), B, N_el);
        [score_map, slice_max, iEl1, iEl2, slice_ties] = score_cross_el_local(Z_use, Rz, G1, G2, reg);

        if keep_score_tensor
            [el1_idx, el2_idx] = ndgrid(1:N_el, 1:N_el);
            score_records = [score_records; ...
                repmat([iAz1, iAz2], N_el*N_el, 1), el1_idx(:), el2_idx(:), score_map(:)]; %#ok<AGROW>
        elseif topK > 0
            top_records = update_top_records_local(top_records, iAz1, iAz2, score_map, topK);
        end

        if slice_max > max_score
            max_score = slice_max;
            tie_count = slice_ties;
            best.iAz1 = iAz1;
            best.iAz2 = iAz2;
            best.iEl1 = iEl1;
            best.iEl2 = iEl2;
        elseif slice_max == max_score
            tie_count = tie_count + slice_ties;
        end
    end
end

if ~isfinite(max_score)
    error('search_pair_grid_full4d_precomputed:NoFiniteScore', 'No finite DML score was found.');
end

est = struct();
est.az_hat = [az_grid(best.iAz1), az_grid(best.iAz2)];
est.el_hat = [el_grid(best.iEl1), el_grid(best.iEl2)];

G_best = [G_use_grid(:, best.iAz1, best.iEl1), G_use_grid(:, best.iAz2, best.iEl2)];
[~, best_debug] = beamspace_dml_score(Z_use, G_best, 'reg', reg);

score_info = struct();
score_info.best_score = max_score;
score_info.optional_score_records = score_records;
score_info.top_records = top_records;
score_info.topK = topK;

debug = struct();
debug.search_mode = 'full4d_ordered_az_precomputed';
debug.whitening_mode = lower(char(cfg.whitening_mode));
debug.num_pairs = num_candidates;
debug.max_score = max_score;
debug.tie_count = tie_count;
debug.best_i_az1 = best.iAz1;
debug.best_i_az2 = best.iAz2;
debug.best_i_el1 = best.iEl1;
debug.best_i_el2 = best.iEl2;
debug.cond_best_GHG = best_debug.cond_GHG;
debug.rank_best_G = best_debug.rank_G;
debug.cond_WHW = cond(W' * W + max(reg, 1e-12) * eye(B));
debug.whitening_info = winfo;
end

function [score_map, max_score, best_i_el1, best_i_el2, tie_count] = score_cross_el_local(Z, Rz, G1, G2, reg) %#ok<INUSD>
N_el = size(G1, 2);
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
[best_i_el1, best_i_el2] = ind2sub([N_el, N_el], linear_idx);
tie_count = nnz(score_map(:) == max_score);
end

function top_records = update_top_records_local(top_records, iAz1, iAz2, score_map, topK)
if topK <= 0
    return;
end
flat = score_map(:);
finite_mask = isfinite(flat);
if ~any(finite_mask)
    return;
end
[sorted_vals, sorted_idx] = sort(flat(finite_mask), 'descend');
finite_idx = find(finite_mask);
take = min(topK, numel(sorted_vals));
linear_idx = finite_idx(sorted_idx(1:take));
[iEl1, iEl2] = ind2sub(size(score_map), linear_idx);
new_records = [repmat([iAz1, iAz2], take, 1), iEl1(:), iEl2(:), sorted_vals(1:take)];
top_records = [top_records; new_records]; %#ok<AGROW>
[~, order] = sort(top_records(:, 5), 'descend');
top_records = top_records(order(1:min(topK, numel(order))), :);
end

function value = getfield_default_local(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end
