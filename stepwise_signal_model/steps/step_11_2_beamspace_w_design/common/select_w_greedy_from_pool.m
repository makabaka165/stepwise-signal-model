function [selected_idx, W_sel, history] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, varargin)
%SELECT_W_GREEDY_FROM_POOL Greedily select W columns from a beam pool.

if nargin < 8
    error('select_w_greedy_from_pool:NotEnoughInputs', ...
        'W_pool, A_patch, pair_set, x, y, z, lambda, and B are required.');
end
opts = parse_options_local(varargin{:});
if B > size(W_pool, 2)
    error('select_w_greedy_from_pool:TooManyBeams', 'B cannot exceed pool size.');
end

K_pool = W_pool' * W_pool;
WA_pool = W_pool' * A_patch;
norm_A2 = norm(A_patch, 'fro').^2;
pair_cache = build_pair_cache_local(W_pool, pair_set, x, y, z, lambda, opts);

selected_idx = zeros(1, B);
remaining = 1:size(W_pool, 2);
history_rows = repmat(make_history_row_template_local(), B, 1);

for k = 1:B
    best_score = Inf;
    best_idx = NaN;
    best_metrics = struct();
    for iRem = 1:numel(remaining)
        idx_try = remaining(iRem);
        trial_idx = [selected_idx(1:k-1), idx_try];
        projection_loss = projection_loss_from_idx_local(trial_idx, K_pool, WA_pool, norm_A2, opts.reg);
        corr_stats = corr_stats_from_idx_local(trial_idx, pair_cache, opts.reg);
        cond_WHW = cond(K_pool(trial_idx, trial_idx) + opts.reg * eye(numel(trial_idx)));

        switch lower(opts.criterion)
            case 'projection'
                score = projection_loss + opts.gamma * log10(max(cond_WHW, 1));
            case 'lowcorr'
                score = corr_stats.max_corr + opts.gamma * log10(max(cond_WHW, 1));
            case 'combined'
                score = opts.alpha * projection_loss + opts.beta * corr_stats.max_corr + ...
                    opts.gamma * log10(max(cond_WHW, 1));
            otherwise
                error('select_w_greedy_from_pool:UnknownCriterion', 'Unknown Criterion: %s', opts.criterion);
        end

        if score < best_score
            best_score = score;
            best_idx = idx_try;
            best_metrics.projection_loss = projection_loss;
            best_metrics.max_corr = corr_stats.max_corr;
            best_metrics.mean_corr = corr_stats.mean_corr;
            best_metrics.cond_WHW = cond_WHW;
        end
    end

    selected_idx(k) = best_idx;
    remaining(remaining == best_idx) = [];
    history_rows(k).step = k;
    history_rows(k).selected_idx = best_idx;
    history_rows(k).score = best_score;
    history_rows(k).projection_loss = best_metrics.projection_loss;
    history_rows(k).max_corr = best_metrics.max_corr;
    history_rows(k).mean_corr = best_metrics.mean_corr;
    history_rows(k).cond_WHW = best_metrics.cond_WHW;
end

W_sel = W_pool(:, selected_idx);
history = struct2table(history_rows);
end

function opts = parse_options_local(varargin)
opts = struct();
opts.criterion = 'combined';
opts.alpha = 1;
opts.beta = 1;
opts.gamma = 0.05;
opts.reg = 1e-10;
opts.phase_factor = 1;
opts.phase_sign = 1;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('select_w_greedy_from_pool:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'criterion'
            opts.criterion = char(value);
        case 'alpha'
            opts.alpha = value;
        case 'beta'
            opts.beta = value;
        case 'gamma'
            opts.gamma = value;
        case 'reg'
            opts.reg = value;
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        otherwise
            error('select_w_greedy_from_pool:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function row = make_history_row_template_local()
row = struct();
row.step = NaN;
row.selected_idx = NaN;
row.score = NaN;
row.projection_loss = NaN;
row.max_corr = NaN;
row.mean_corr = NaN;
row.cond_WHW = NaN;
end

function pair_cache = build_pair_cache_local(W_pool, pair_set, x, y, z, lambda, opts)
num_pairs = size(pair_set, 1);
G1_pool = zeros(size(W_pool, 2), num_pairs);
G2_pool = zeros(size(W_pool, 2), num_pairs);
for iPair = 1:num_pairs
    a1 = build_cyl_steering_vec(x, y, z, pair_set(iPair, 1), pair_set(iPair, 2), lambda, ...
        'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    a2 = build_cyl_steering_vec(x, y, z, pair_set(iPair, 3), pair_set(iPair, 4), lambda, ...
        'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    G1_pool(:, iPair) = W_pool' * a1;
    G2_pool(:, iPair) = W_pool' * a2;
end
pair_cache.G1_pool = G1_pool;
pair_cache.G2_pool = G2_pool;
pair_cache.num_pairs = num_pairs;
end

function loss = projection_loss_from_idx_local(idx, K_pool, WA_pool, norm_A2, reg)
K = K_pool(idx, idx) + reg * eye(numel(idx));
C = WA_pool(idx, :);
projected_energy = real(trace(K \ (C * C')));
residual = max(norm_A2 - projected_energy, 0);
loss = sqrt(residual / max(norm_A2, eps));
end

function stats = corr_stats_from_idx_local(idx, pair_cache, reg)
corr_values = zeros(pair_cache.num_pairs, 1);
cond_GHG_values = zeros(pair_cache.num_pairs, 1);
for iPair = 1:pair_cache.num_pairs
    g1 = pair_cache.G1_pool(idx, iPair);
    g2 = pair_cache.G2_pool(idx, iPair);
    corr_values(iPair) = abs(g1' * g2) / max(norm(g1) * norm(g2), eps);
    G = [g1, g2];
    cond_GHG_values(iPair) = cond(G' * G + reg * eye(2));
end
stats.mean_corr = mean(corr_values);
stats.max_corr = max(corr_values);
stats.mean_cond_GHG = mean(cond_GHG_values);
stats.max_cond_GHG = max(cond_GHG_values);
end
