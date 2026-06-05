function stats = compute_manifold_correlation_stats(W, pair_set, x, y, z, lambda, varargin)
%COMPUTE_MANIFOLD_CORRELATION_STATS Compute W-domain pair correlation stats.

if nargin < 6
    error('compute_manifold_correlation_stats:NotEnoughInputs', ...
        'W, pair_set, x, y, z, and lambda are required.');
end
opts = parse_options_local(varargin{:});
if size(pair_set, 2) ~= 4
    error('compute_manifold_correlation_stats:InvalidPairSet', ...
        'pair_set must be N_pair x 4: [az1 el1 az2 el2].');
end
if size(W, 1) ~= numel(x(:))
    error('compute_manifold_correlation_stats:ShapeMismatch', 'size(W,1) must equal numel(x).');
end

corr_values = zeros(size(pair_set, 1), 1);
cond_GHG_values = zeros(size(pair_set, 1), 1);
for iPair = 1:size(pair_set, 1)
    a1 = build_cyl_steering_vec(x, y, z, pair_set(iPair, 1), pair_set(iPair, 2), lambda, ...
        'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    a2 = build_cyl_steering_vec(x, y, z, pair_set(iPair, 3), pair_set(iPair, 4), lambda, ...
        'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    G = W' * [a1, a2];
    g1 = G(:, 1);
    g2 = G(:, 2);
    corr_values(iPair) = abs(g1' * g2) / max(norm(g1) * norm(g2), eps);
    cond_GHG_values(iPair) = cond(G' * G + opts.reg * eye(2));
end

stats = struct();
stats.mean_corr = mean(corr_values);
stats.median_corr = median(corr_values);
stats.p90_corr = percentile_local(corr_values, 90);
stats.max_corr = max(corr_values);
stats.min_corr = min(corr_values);
stats.num_pairs = numel(corr_values);
stats.mean_cond_GHG = mean(cond_GHG_values);
stats.max_cond_GHG = max(cond_GHG_values);
stats.corr_values = corr_values;
stats.cond_GHG_values = cond_GHG_values;
end

function opts = parse_options_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.reg = 1e-10;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('compute_manifold_correlation_stats:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'reg'
            opts.reg = value;
        otherwise
            error('compute_manifold_correlation_stats:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function v = percentile_local(x, p)
x = sort(x(:));
if isempty(x)
    v = NaN;
    return;
end
idx = 1 + (numel(x) - 1) * p / 100;
lo = floor(idx);
hi = ceil(idx);
if lo == hi
    v = x(lo);
else
    v = x(lo) + (idx - lo) * (x(hi) - x(lo));
end
end

