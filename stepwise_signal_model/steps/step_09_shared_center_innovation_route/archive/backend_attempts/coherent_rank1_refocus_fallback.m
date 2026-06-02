function coherent_info = coherent_rank1_refocus_fallback(Y_work, selected, array_geom, music_info, cfg)
%COHERENT_RANK1_REFOCUS_FALLBACK Conservative common-el rank-1 fallback.

if nargin < 5
    cfg = struct();
end
cfg = defaults_local(cfg);

coherent_info = struct('route_name', 'common_el_rank1_refocus', ...
    'valid', false, 'confidence_ok', false, 'az_est', [], 'el_est', [], ...
    'score', NaN, 'score_margin', NaN, 'reason', '');

if cfg.boundary_unreliable_flag
    coherent_info.reason = 'boundary_unreliable_flag blocks coherent pair output';
    return
end
if cfg.need_2d_refinement
    coherent_info.reason = '2-D refinement is required before common-el pair output';
    return
end
if ~cfg.frontend_unresolved_cluster
    coherent_info.reason = 'frontend did not mark the cell as an unresolved local cluster';
    return
end
if ~isfield(music_info, 'rank1_like') || ~music_info.rank1_like
    coherent_info.reason = 'covariance is not rank-1-like enough for coherent fallback';
    return
end
if ~isfield(music_info, 'peak_count') || music_info.peak_count < 2
    if ~isfield(music_info, 'peak2_ratio') || music_info.peak2_ratio < cfg.coherent_music_peak2_ratio_min
        coherent_info.reason = 'music evidence is too weak for coherent pair fallback';
        return
    end
end

Xsnap = reshape(Y_work, [], size(Y_work, 3));
if norm(Xsnap, 'fro') <= eps
    coherent_info.reason = 'empty Y_work';
    return
end
[U, ~, ~] = svd(Xsnap, 'econ');
signal_vec = U(:, 1);

if isfield(music_info, 'peak_az') && ~isempty(music_info.peak_az)
    center0 = music_info.peak_az(1);
else
    center0 = selected.centerAz;
end

center_grid = (center0 - cfg.fallback_center_span_deg):cfg.fallback_center_step_deg:(center0 + cfg.fallback_center_span_deg);
sep_grid = cfg.min_pair_sep_deg:cfg.fallback_sep_step_deg:cfg.max_pair_sep_deg;

scores = [];
pairs = [];
for ic = 1:numel(center_grid)
    for isep = 1:numel(sep_grid)
        az_pair = [center_grid(ic) - sep_grid(isep) / 2, center_grid(ic) + sep_grid(isep) / 2];
        A = [steering_vector_local(selected, array_geom, az_pair(1), cfg.coarseEl), ...
            steering_vector_local(selected, array_geom, az_pair(2), cfg.coarseEl)];
        coef = (A' * A + 1e-6 * eye(2)) \ (A' * signal_vec);
        proj = A * coef;
        scores(end + 1, 1) = real((proj' * proj) / max(signal_vec' * signal_vec, eps)); %#ok<AGROW>
        pairs(end + 1, :) = az_pair; %#ok<AGROW>
    end
end

[score_sorted, order] = sort(scores, 'descend');
best_pair = sort(pairs(order(1), :));
best_score = score_sorted(1);
if numel(score_sorted) >= 2
    margin = score_sorted(1) - score_sorted(2);
else
    margin = score_sorted(1);
end

coherent_info.az_est = best_pair;
coherent_info.el_est = cfg.coarseEl * ones(1, 2);
coherent_info.score = best_score;
coherent_info.score_margin = margin;
coherent_info.valid = best_score >= cfg.coherent_min_projection_score && ...
    margin >= cfg.coherent_min_score_margin;
coherent_info.confidence_ok = coherent_info.valid;
if coherent_info.valid
    coherent_info.reason = 'rank-1 common-elevation pair score is accepted';
else
    coherent_info.reason = 'rank-1 pair score is not separated enough';
end
end

function cfg = defaults_local(cfg)
    cfg = set_default_local(cfg, 'coarseEl', 0);
    cfg = set_default_local(cfg, 'min_pair_sep_deg', 0.15);
    cfg = set_default_local(cfg, 'max_pair_sep_deg', 1.2);
    cfg = set_default_local(cfg, 'fallback_center_span_deg', 0.20);
    cfg = set_default_local(cfg, 'fallback_center_step_deg', 0.05);
    cfg = set_default_local(cfg, 'fallback_sep_step_deg', 0.05);
    cfg = set_default_local(cfg, 'coherent_min_projection_score', 0.70);
    cfg = set_default_local(cfg, 'coherent_min_score_margin', 1e-4);
    cfg = set_default_local(cfg, 'coherent_music_peak2_ratio_min', 0.15);
    cfg = set_default_local(cfg, 'frontend_unresolved_cluster', true);
    cfg = set_default_local(cfg, 'need_2d_refinement', false);
    cfg = set_default_local(cfg, 'boundary_unreliable_flag', false);
end

function cfg = set_default_local(cfg, name, value)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = value;
    end
end

function a = steering_vector_local(selected, array_geom, az_deg, el_deg)
    lambda = getfield_default_local(array_geom, 'lambda', 1);
    X = selected.XWork;
    Y = selected.YWork;
    Z = selected.ZWork;
    kx = cosd(el_deg) * cosd(az_deg);
    ky = cosd(el_deg) * sind(az_deg);
    kz = sind(el_deg);
    phase = 2 * pi / lambda * (X * kx + Y * ky + Z * kz);
    a = exp(1j * phase);
    a = a(:);
    a = a / max(norm(a), eps);
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end
