function features = compute_likelihood_landscape_features_v2(top_candidates, coarse_debug, grid_cfg_coarse, search_opts, policy_cfg)
%COMPUTE_LIKELIHOOD_LANDSCAPE_FEATURES_V2 Stage2 decoupled uncertainty features.
%
% Stage2 keeps the stable softmax entropy from Stage1, but separates search
% budget uncertainty (U_search) from confidence uncertainty (U_confidence).
% The function never uses target truth.

if nargin < 5 || isempty(policy_cfg)
    policy_cfg = struct();
end
policy_cfg = fill_policy_defaults_local(policy_cfg);
if nargin < 4
    error('compute_likelihood_landscape_features_v2:NotEnoughInputs', ...
        'top_candidates, coarse_debug, grid_cfg_coarse, search_opts, and policy_cfg are required.');
end

top_scores = extract_scores_local(top_candidates);
top_scores = top_scores(isfinite(top_scores));
topK_available = numel(top_scores);
if topK_available < 1
    error('compute_likelihood_landscape_features_v2:EmptyTopCandidates', ...
        'At least one finite coarse candidate score is required.');
end

topK_max = policy_cfg.topK_max;
if isfield(search_opts, 'topK_max') && isfinite(search_opts.topK_max)
    topK_max = search_opts.topK_max;
end
topK_max = max(1, floor(topK_max));
tau = policy_cfg.tau;
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
H_norm = H_J / max(log(max(topK_max, 2)), eps);
H_norm = min(max(real(H_norm), 0), 1);

score_3 = top_scores(min(3, topK_available));
score_7 = top_scores(min(7, topK_available));
gap_13 = max(real((best_score - score_3) / score_scale), 0);
gap_17 = max(real((best_score - score_7) / score_scale), 0);

best = top_candidates(1);
az_bounds = get_bounds_local(grid_cfg_coarse, 'az_bounds', [-Inf, Inf]);
el_bounds = get_bounds_local(grid_cfg_coarse, 'el_bounds', [-Inf, Inf]);
coarse_az_step = get_scalar_field_local(grid_cfg_coarse, 'az_step', NaN);
coarse_el_step = get_scalar_field_local(grid_cfg_coarse, 'el_step', NaN);

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

gap_risk = 1 - min(gap_13 / max(policy_cfg.gap_scale, eps), 1);
gap_risk = min(max(gap_risk, 0), 1);
U_search = 0.65 * gap_risk + 0.30 * boundary_risk + 0.05 * min(H_norm, 0.5);
U_search = min(max(real(U_search), 0), 1);
U_confidence = 0.35 * H_norm + 0.25 * gap_risk + 0.25 * cond_risk + 0.15 * boundary_risk;
U_confidence = min(max(real(U_confidence), 0), 1);

features = struct();
features.H_norm = H_norm;
features.gap_13 = gap_13;
features.gap_17 = gap_17;
features.boundary_margin = boundary_margin;
features.boundary_risk = boundary_risk;
features.cond_best_GHG = cond_best_GHG;
features.cond_risk = cond_risk;
features.U_search = U_search;
features.U_confidence = U_confidence;
features.gap_risk = gap_risk;
features.top_scores = top_scores(:).';
features.softmax_weights = softmax_weights(:).';
features.best_score = best_score;
features.topK_available = topK_available;
features.topK_max = topK_max;
features.tau = tau;
features.gap_scale = policy_cfg.gap_scale;
end

function policy_cfg = fill_policy_defaults_local(policy_cfg)
if ~isfield(policy_cfg, 'topK_max')
    policy_cfg.topK_max = 7;
end
if ~isfield(policy_cfg, 'tau')
    policy_cfg.tau = 0.02;
end
if ~isfield(policy_cfg, 'gap_scale')
    policy_cfg.gap_scale = 0.003;
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

function value = get_scalar_field_local(s, field_name, fallback)
value = fallback;
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
end
if ~(isscalar(value) && isfinite(value))
    value = fallback;
end
end

function bounds = get_bounds_local(s, field_name, fallback)
if isstruct(s) && isfield(s, field_name)
    bounds = sort(s.(field_name)(:).');
else
    bounds = fallback;
end
if numel(bounds) ~= 2
    error('compute_likelihood_landscape_features_v2:InvalidBounds', ...
        '%s must contain two values.', field_name);
end
end
