function features = compute_likelihood_landscape_features(top_candidates, coarse_debug, grid_cfg_coarse, search_opts, varargin)
%COMPUTE_LIKELIHOOD_LANDSCAPE_FEATURES Extract coarse-grid uncertainty features.
%
% features = compute_likelihood_landscape_features(top_candidates,
% coarse_debug, grid_cfg_coarse, search_opts) computes deterministic
% likelihood-landscape features from Step11.3 coarse top candidates. The
% function intentionally does not accept or use target truth values.

if nargin < 4
    error('compute_likelihood_landscape_features:NotEnoughInputs', ...
        'top_candidates, coarse_debug, grid_cfg_coarse, and search_opts are required.');
end
opts = parse_opts_local(varargin{:});

top_scores = extract_scores_local(top_candidates);
top_scores = top_scores(isfinite(top_scores));
topK_available = numel(top_scores);
if topK_available < 1
    error('compute_likelihood_landscape_features:EmptyTopCandidates', ...
        'At least one finite coarse top candidate score is required.');
end

Kmax = opts.topK_max;
if isfield(search_opts, 'topK_max') && isfinite(search_opts.topK_max)
    Kmax = search_opts.topK_max;
end
Kmax = max(1, floor(Kmax));
tau = opts.tau;
if isfield(search_opts, 'likelihood_tau') && isfinite(search_opts.likelihood_tau) && search_opts.likelihood_tau > 0
    tau = search_opts.likelihood_tau;
end

best_score = top_scores(1);
score_scale = max(abs(best_score), eps);
s = (top_scores - best_score) ./ score_scale;
softmax_arg = s ./ max(tau, eps);
softmax_arg = softmax_arg - max(softmax_arg);
softmax_exp = exp(softmax_arg);
softmax_weights = softmax_exp ./ max(sum(softmax_exp), eps);

H_J = -sum(softmax_weights .* log(softmax_weights + eps));
H_norm = H_J / max(log(max(Kmax, 2)), eps);
H_norm = min(max(real(H_norm), 0), 1);

score_3 = top_scores(min(3, topK_available));
score_7 = top_scores(min(7, topK_available));
gap_13 = (best_score - score_3) / score_scale;
gap_17 = (best_score - score_7) / score_scale;
gap_13 = max(real(gap_13), 0);
gap_17 = max(real(gap_17), 0);

best = top_candidates(1);
az_bounds = get_bounds_local(grid_cfg_coarse, opts.az_bounds, 'az_bounds');
el_bounds = get_bounds_local(grid_cfg_coarse, opts.el_center_bounds, 'el_bounds');
coarse_az_step = get_scalar_field_local(grid_cfg_coarse, 'az_step', opts.coarse_az_step);
coarse_el_step = get_scalar_field_local(grid_cfg_coarse, 'el_step', opts.coarse_el_step);

az_sorted = sort(best.az_hat(:).');
d_az = min([az_sorted(1) - az_bounds(1), az_bounds(2) - az_sorted(1), ...
    az_sorted(2) - az_bounds(1), az_bounds(2) - az_sorted(2)]);
d_el = min([best.el_center_hat - el_bounds(1), el_bounds(2) - best.el_center_hat]);
boundary_margin = min(d_az / max(coarse_az_step, eps), d_el / max(coarse_el_step, eps));
if ~isfinite(boundary_margin)
    boundary_margin = Inf;
end
boundary_risk = double(boundary_margin < 1.5);

cond_best_GHG = get_scalar_field_local(coarse_debug, 'cond_best_GHG', NaN);
if ~(isfinite(cond_best_GHG) && cond_best_GHG > 0)
    cond_risk = 1;
else
    cond_risk = min(max(log10(cond_best_GHG) / 8, 0), 1);
end

gap_risk = 1 - min(gap_13 / 0.02, 1);
U = 0.45 * H_norm + 0.25 * gap_risk + 0.15 * boundary_risk + 0.15 * cond_risk;
U = min(max(real(U), 0), 1);

features = struct();
features.H_norm = H_norm;
features.gap_13 = gap_13;
features.gap_17 = gap_17;
features.boundary_margin = boundary_margin;
features.boundary_risk = boundary_risk;
features.cond_best_GHG = cond_best_GHG;
features.cond_risk = cond_risk;
features.U = U;
features.top_scores = top_scores(:).';
features.softmax_weights = softmax_weights(:).';
features.best_score = best_score;
features.topK_available = topK_available;
features.topK_max = Kmax;
features.tau = tau;
features.az_bounds = az_bounds;
features.el_center_bounds = el_bounds;
features.coarse_az_step = coarse_az_step;
features.coarse_el_step = coarse_el_step;
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.topK_max = 7;
opts.tau = 0.02;
opts.az_bounds = [];
opts.el_center_bounds = [];
opts.coarse_az_step = NaN;
opts.coarse_el_step = NaN;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('compute_likelihood_landscape_features:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'topkmax'
            opts.topK_max = value;
        case 'tau'
            opts.tau = value;
        case 'azbounds'
            opts.az_bounds = value;
        case {'elcenterbounds','el_bounds','elbounds'}
            opts.el_center_bounds = value;
        case 'coarseazstep'
            opts.coarse_az_step = value;
        case 'coarseelstep'
            opts.coarse_el_step = value;
        otherwise
            error('compute_likelihood_landscape_features:UnknownOption', ...
                'Unknown option: %s.', name);
    end
end
end

function scores = extract_scores_local(top_candidates)
scores = nan(numel(top_candidates), 1);
for idx = 1:numel(top_candidates)
    if isfield(top_candidates(idx), 'score')
        scores(idx) = top_candidates(idx).score;
    elseif isfield(top_candidates(idx), 'max_score')
        scores(idx) = top_candidates(idx).max_score;
    end
end
end

function bounds = get_bounds_local(s, fallback, field_name)
if ~isempty(fallback)
    bounds = sort(fallback(:).');
elseif isstruct(s) && isfield(s, field_name)
    bounds = sort(s.(field_name)(:).');
else
    bounds = [-Inf, Inf];
end
if numel(bounds) ~= 2
    error('compute_likelihood_landscape_features:InvalidBounds', ...
        '%s must contain two values.', field_name);
end
end

function value = get_scalar_field_local(s, field_name, fallback)
value = fallback;
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
end
if ~(isscalar(value) && isfinite(value))
    value = fallback;
end
end
