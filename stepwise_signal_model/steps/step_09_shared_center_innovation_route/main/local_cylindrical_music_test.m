function music_info = local_cylindrical_music_test(Y_work, selected, array_geom, cfg)
%LOCAL_CYLINDRICAL_MUSIC_TEST Common-elevation local MUSIC decision.

if nargin < 4
    cfg = struct();
end
cfg = defaults_local(cfg);

Xsnap = reshape(Y_work, [], size(Y_work, 3));
Nsnap = max(1, size(Xsnap, 2));
% Compact SVD gives the same signal subspace needed by MUSIC without
% forming a 2080 x 2080 covariance eigendecomposition for every MC trial.
[U, S, ~] = svd(Xsnap, 'econ');
evals = real(diag(S)).^2 / Nsnap;
nSrc = min([cfg.num_sources, size(U, 2)]);
if nSrc < 1
    nSrc = 1;
end
Us = U(:, 1:nSrc);

az_center = selected.centerAz;
az_axis = (az_center - cfg.az_grid_half_span_deg):cfg.az_grid_step_deg:(az_center + cfg.az_grid_half_span_deg);
el0 = cfg.coarseEl;
P = zeros(size(az_axis));
for i = 1:numel(az_axis)
    a = steering_vector_local(selected, array_geom, az_axis(i), el0);
    den = real(1 - sum(abs(Us' * a).^2));
    P(i) = 1 / max(den, eps);
end
P = P ./ max(P);

[peak_idx, peak_val] = find_1d_peaks_local(P);
if isempty(peak_idx)
    [peak_val, peak_idx] = max(P);
end
[peak_val, sidx] = sort(peak_val, 'descend');
peak_idx = peak_idx(sidx);
peak_az = az_axis(peak_idx);

if numel(peak_idx) >= 2
    az_pair = sort(peak_az(1:2));
    peak2_ratio = peak_val(2) / max(peak_val(1), eps);
    sep = abs(diff(az_pair));
else
    az_pair = peak_az(1);
    peak2_ratio = 0;
    sep = 0;
end

lambda1 = get_index_or_nan_local(evals, 1);
lambda2 = get_index_or_nan_local(evals, 2);
lambda_noise = mean(evals(min(numel(evals), nSrc + 1):end));
if isempty(lambda_noise) || isnan(lambda_noise)
    lambda_noise = 0;
end
lambda2_over_1 = lambda2 / max(lambda1, eps);
lambda2_over_noise = lambda2 / max(lambda_noise, eps);
rank1_like = lambda2_over_1 < cfg.rank1_lambda2_over_lambda1_max;

two_peak_ok = numel(peak_idx) >= 2 && ...
    sep >= cfg.min_pair_sep_deg && sep <= cfg.max_pair_sep_deg && ...
    peak2_ratio >= cfg.music_peak2_ratio_min;

music_info = struct();
music_info.route_name = 'local_cylindrical_music';
music_info.valid = true;
music_info.az_axis = az_axis;
music_info.spectrum = P;
music_info.el0 = el0;
music_info.peak_count = numel(peak_idx);
music_info.peak_az = peak_az(:).';
music_info.peak_value = peak_val(:).';
music_info.peak2_ratio = peak2_ratio;
music_info.peak_sep_deg = sep;
music_info.az_est = az_pair(:).';
music_info.el_est = el0 * ones(1, numel(az_pair));
music_info.is_two_peak_resolvable = two_peak_ok;
music_info.confidence_ok = two_peak_ok;
music_info.rank1_like = rank1_like;
music_info.lambda1 = lambda1;
music_info.lambda2 = lambda2;
music_info.lambda2_over_lambda1 = lambda2_over_1;
music_info.lambda2_over_noise = lambda2_over_noise;
music_info.need_2d_refinement = logical(cfg.need_2d_refinement);
music_info.boundary_unreliable = logical(cfg.boundary_unreliable_flag);
music_info.reason = reason_local(two_peak_ok, rank1_like, music_info.need_2d_refinement);
end

function cfg = defaults_local(cfg)
    cfg = set_default_local(cfg, 'num_sources', 2);
    cfg = set_default_local(cfg, 'coarseEl', 0);
    cfg = set_default_local(cfg, 'az_grid_half_span_deg', 1.5);
    cfg = set_default_local(cfg, 'az_grid_step_deg', 0.02);
    cfg = set_default_local(cfg, 'min_pair_sep_deg', 0.15);
    cfg = set_default_local(cfg, 'max_pair_sep_deg', 1.2);
    cfg = set_default_local(cfg, 'music_peak2_ratio_min', 0.38);
    cfg = set_default_local(cfg, 'rank1_lambda2_over_lambda1_max', 0.25);
    cfg = set_default_local(cfg, 'need_2d_refinement', false);
    cfg = set_default_local(cfg, 'boundary_unreliable_flag', false);
end

function cfg = set_default_local(cfg, name, value)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = value;
    end
end

function reason = reason_local(two_peak_ok, rank1_like, need_2d)
    if two_peak_ok
        reason = 'two local MUSIC peaks are resolvable';
    elseif need_2d
        reason = 'common-elevation local MUSIC needs 2-D refinement';
    elseif rank1_like
        reason = 'single/merged MUSIC peak with rank-1-like covariance';
    else
        reason = 'local MUSIC evidence is not sufficient';
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

function [idx, vals] = find_1d_peaks_local(P)
    idx = [];
    vals = [];
    if numel(P) < 3
        return
    end
    for i = 2:numel(P) - 1
        if P(i) >= P(i - 1) && P(i) > P(i + 1)
            idx(end + 1) = i; %#ok<AGROW>
            vals(end + 1) = P(i); %#ok<AGROW>
        end
    end
end

function value = get_index_or_nan_local(x, idx)
    if numel(x) >= idx
        value = x(idx);
    else
        value = NaN;
    end
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end
