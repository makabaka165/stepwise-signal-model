function pair2d_info = local_2d_pair_refinement(Y_work, selected, array_geom, cfg)
%LOCAL_2D_PAIR_REFINEMENT Local 2-D MUSIC refinement for elevation mismatch.

if nargin < 4
    cfg = struct();
end
cfg = defaults_local(cfg);

pair2d_info = struct('route_name', 'local_2d_pair_refinement', ...
    'valid', false, 'confidence_ok', false, 'az_est', [], 'el_est', [], ...
    'peak_ratio', NaN, 'reason', '');

if cfg.boundary_unreliable_flag
    pair2d_info.reason = 'boundary_unreliable_flag blocks 2-D output';
    return
end

Xsnap = reshape(Y_work, [], size(Y_work, 3));
% Compact SVD avoids repeated full covariance EVD in formal MC runs while
% preserving the signal subspace used by the local 2-D MUSIC spectrum.
[U, ~, ~] = svd(Xsnap, 'econ');
nSrc = min([cfg.num_sources, size(U, 2)]);
if nSrc < 1
    nSrc = 1;
end
Us = U(:, 1:nSrc);

az_axis = (selected.centerAz - cfg.az_grid_half_span_deg):cfg.az_grid_step_deg:(selected.centerAz + cfg.az_grid_half_span_deg);
el_axis = (cfg.coarseEl - cfg.el_grid_half_span_deg):cfg.el_grid_step_deg:(cfg.coarseEl + cfg.el_grid_half_span_deg);
P = zeros(numel(el_axis), numel(az_axis));
for ie = 1:numel(el_axis)
    for ia = 1:numel(az_axis)
        a = steering_vector_local(selected, array_geom, az_axis(ia), el_axis(ie));
        den = real(1 - sum(abs(Us' * a).^2));
        P(ie, ia) = 1 / max(den, eps);
    end
end
P = P ./ max(P(:));

peaks = find_2d_peaks_local(P, az_axis, el_axis, cfg);
if size(peaks, 1) < 2
    pair2d_info.reason = 'less than two local 2-D peaks';
    pair2d_info.spectrum = P;
    pair2d_info.az_axis = az_axis;
    pair2d_info.el_axis = el_axis;
    return
end

az_pair = peaks(1:2, 1).';
el_pair = peaks(1:2, 2).';
peak_ratio = peaks(2, 3) / max(peaks(1, 3), eps);
sep = abs(diff(sort(az_pair)));

pair2d_info.az_est = az_pair;
pair2d_info.el_est = el_pair;
pair2d_info.peak_ratio = peak_ratio;
pair2d_info.spectrum = P;
pair2d_info.az_axis = az_axis;
pair2d_info.el_axis = el_axis;
pair2d_info.valid = sep >= cfg.min_pair_sep_deg && peak_ratio >= cfg.music_2d_peak2_ratio_min;
pair2d_info.confidence_ok = pair2d_info.valid;
if pair2d_info.valid
    pair2d_info.reason = 'two local 2-D MUSIC peaks accepted';
else
    pair2d_info.reason = '2-D peaks fail separation or confidence threshold';
end
end

function cfg = defaults_local(cfg)
    cfg = set_default_local(cfg, 'num_sources', 2);
    cfg = set_default_local(cfg, 'coarseEl', 0);
    cfg = set_default_local(cfg, 'az_grid_half_span_deg', 1.5);
    cfg = set_default_local(cfg, 'az_grid_step_deg', 0.04);
    cfg = set_default_local(cfg, 'el_grid_half_span_deg', 8);
    cfg = set_default_local(cfg, 'el_grid_step_deg', 0.25);
    cfg = set_default_local(cfg, 'min_pair_sep_deg', 0.15);
    cfg = set_default_local(cfg, 'music_2d_peak2_ratio_min', 0.25);
    cfg = set_default_local(cfg, 'boundary_unreliable_flag', false);
end

function cfg = set_default_local(cfg, name, value)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = value;
    end
end

function peaks = find_2d_peaks_local(P, az_axis, el_axis, cfg)
    rows = [];
    for ie = 2:size(P, 1) - 1
        for ia = 2:size(P, 2) - 1
            win = P(ie - 1:ie + 1, ia - 1:ia + 1);
            if P(ie, ia) >= max(win(:)) && P(ie, ia) > 0
                rows(end + 1, :) = [az_axis(ia), el_axis(ie), P(ie, ia)]; %#ok<AGROW>
            end
        end
    end
    if isempty(rows)
        [~, idx] = max(P(:));
        [ie, ia] = ind2sub(size(P), idx);
        rows = [az_axis(ia), el_axis(ie), P(ie, ia)];
    end
    [~, order] = sort(rows(:, 3), 'descend');
    rows = rows(order, :);
    keep = true(size(rows, 1), 1);
    for i = 2:size(rows, 1)
        for j = 1:i - 1
            if keep(j) && hypot(rows(i, 1) - rows(j, 1), rows(i, 2) - rows(j, 2)) < cfg.min_pair_sep_deg
                keep(i) = false;
            end
        end
    end
    peaks = rows(keep, :);
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
