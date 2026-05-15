function [doa_value, debug] = DOA_three_music_hecheng_fangzhen_eval( ...
    estm_data_in, subarray_num, A, angle_recv, search_width_deg, varargin)
    % A1 评估版 Route A：
    % 在原始 beam-index smoothing MUSIC 基础上，增加更一般搜索条件下的诊断信息。

    p = inputParser;
    addParameter(p, 'Lc', 2);
    addParameter(p, 'QSmoothRatio', 0.2);
    addParameter(p, 'TargetTheta', []);
    addParameter(p, 'CellnMode', 'ratio');
    addParameter(p, 'FixedCelln', 41);
    addParameter(p, 'FixedPhysicalSpanDeg', []);
    addParameter(p, 'SpectrumMode', 'center');
    parse(p, varargin{:});

    Lc = p.Results.Lc;
    qSmoothRatio = p.Results.QSmoothRatio;
    target_theta = p.Results.TargetTheta;
    celln_mode = p.Results.CellnMode;
    fixed_celln = p.Results.FixedCelln;
    fixed_physical_span_deg = p.Results.FixedPhysicalSpanDeg;
    spectrum_mode = p.Results.SpectrumMode;

    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lamda = c / fc;
    derad = pi / 180;
    d = 0.047;
    N2P = subarray_num;
    position = (d * (0:N2P-1)).';
    Xc = estm_data_in;
    n = size(estm_data_in, 2);

    B = size(Xc, 1);
    beam_grid_count = size(A, 2);
    if beam_grid_count < 2
        doa_value = nan(1, Lc);
        debug = struct();
        debug.reason = 'beam_grid_too_small';
        return;
    end

    beam_grid_angles_rad = unwrap(angle(A(2, :) ./ max(A(1, :), eps)));
    beam_grid_angles_deg = asind(beam_grid_angles_rad * lamda / (2 * pi * d));
    beam_grid_span_deg = beam_grid_angles_deg(end) - beam_grid_angles_deg(1);
    beam_grid_step_deg = median(diff(beam_grid_angles_deg));

    switch lower(celln_mode)
        case 'ratio'
            Q = round(qSmoothRatio * B);
            Q = max(Q, 1);
            Q = min(Q, B - Lc - 1);
            celln = B - Q;
        case 'fixed_celln'
            celln = min(fixed_celln, B - 1);
            Q = B - celln;
        case 'fixed_physical'
            if isempty(fixed_physical_span_deg)
                doa_value = nan(1, Lc);
                debug = struct();
                debug.reason = '未提供固定物理跨度';
                debug.B = B;
                debug.beam_grid_step_deg = beam_grid_step_deg;
                return;
            end
            celln = round(fixed_physical_span_deg / beam_grid_step_deg) + 1;
            celln = min(celln, B - 1);
            Q = B - celln;
        otherwise
            error('不支持的 CellnMode：%s', celln_mode);
    end

    if celln <= Lc || Q < 1
        doa_value = nan(1, Lc);
        debug = struct();
        debug.reason = 'celln 或 Q 不合法';
        debug.B = B;
        debug.Q = Q;
        debug.celln = celln;
        debug.CellnMode = celln_mode;
        debug.FixedCelln = fixed_celln;
        debug.FixedPhysicalSpanDeg = fixed_physical_span_deg;
        debug.beam_grid_step_deg = beam_grid_step_deg;
        return;
    end

    QQ = Lc + 1;
    Rxxmc = Xc * Xc' / n;
    RxxC_mssp = mssp(Rxxmc, celln);
    Rx = 0.5 * (RxxC_mssp + RxxC_mssp');

    beam_start = floor((size(A, 2) - celln) / 2) + 1;
    beam_ind = beam_start:beam_start + celln - 1;

    angle_search = angle_recv - search_width_deg/2 : 0.01 : angle_recv + search_width_deg/2;

    [EVc, Dc] = eig(Rx);
    EVAc = diag(Dc).';
    [~, Ic] = sort(EVAc);
    EVc = fliplr(EVc(:, Ic));
    Enc = EVc(:, QQ:celln);

    SPc = zeros(1, length(angle_search));
    for iang = 1:length(angle_search)
        phim = derad * angle_search(iang);
        atheta = exp(-j * 2 * pi * position / lamda * sin(phim));

        switch lower(spectrum_mode)
            case 'center'
                ac = A(:, beam_ind).' * atheta;
                SPc(iang) = (ac' * ac) / max(ac' * Enc * Enc' * ac, eps);
            case 'manifold'
                gtheta = A.' * atheta;
                Pwin = B - celln + 1;
                Htheta = zeros(celln, Pwin);
                for pp = 1:Pwin
                    Htheta(:, pp) = gtheta(pp:pp+celln-1);
                end
                numerator = norm(Htheta, 'fro')^2;
                denominator = norm(Enc' * Htheta, 'fro')^2;
                SPc(iang) = numerator / max(denominator, eps);
            otherwise
                error('不支持的 SpectrumMode：%s', spectrum_mode);
        end
    end

    p_SPc = abs(SPc);
    [peak_val, peak_ind] = FindLocalPeak_NoEdge_Fun(p_SPc);

    if length(peak_ind) < Lc
        doa_value = nan(1, Lc);
    else
        doa_value = sort(angle_search(peak_ind(1:Lc)));
    end

    edge_hit = false;
    if all(isfinite(doa_value))
        edge_tol = 1e-12;
        edge_hit = any(abs(doa_value - angle_search(1)) < edge_tol) || ...
                   any(abs(doa_value - angle_search(end)) < edge_tol);
    end

    debug = struct();
    debug.edge_hit = edge_hit;
    debug.angle_search = angle_search;
    debug.spectrum = p_SPc;
    debug.peak_ind = peak_ind;
    debug.beam_ind = beam_ind;
    debug.B = B;
    debug.Q = Q;
    debug.QSmoothRatio = qSmoothRatio;
    debug.celln = celln;
    debug.CellnMode = celln_mode;
    debug.FixedCelln = fixed_celln;
    debug.FixedPhysicalSpanDeg = fixed_physical_span_deg;
    debug.SpectrumMode = spectrum_mode;
    debug.selected_doa = doa_value;
    debug.search_width_deg = search_width_deg;
    debug.beam_grid_count = beam_grid_count;
    debug.beam_grid_span_deg = beam_grid_span_deg;
    debug.beam_grid_step_deg = beam_grid_step_deg;
    debug.num_peaks = numel(peak_ind);

    if isempty(peak_ind)
        debug.peak_angles = [];
        debug.peak_values = [];
    else
        keep_count = min(numel(peak_ind), 5);
        debug.peak_angles = angle_search(peak_ind(1:keep_count));
        debug.peak_values = peak_val(1:keep_count);
    end

    if ~isempty(target_theta)
        debug.target_theta = target_theta;
        target_spectrum_values = nan(size(target_theta));
        nearest_peak_to_target = nan(size(target_theta));
        nearest_peak_error_to_target = nan(size(target_theta));

        for kk = 1:numel(target_theta)
            [~, idx_target] = min(abs(angle_search - target_theta(kk)));
            target_spectrum_values(kk) = p_SPc(idx_target);

            if ~isempty(debug.peak_angles)
                [min_err, idx_peak] = min(abs(debug.peak_angles - target_theta(kk)));
                nearest_peak_to_target(kk) = debug.peak_angles(idx_peak);
                nearest_peak_error_to_target(kk) = min_err;
            end
        end

        debug.target_spectrum_values = target_spectrum_values;
        debug.nearest_peak_to_target = nearest_peak_to_target;
        debug.nearest_peak_error_to_target = nearest_peak_error_to_target;
    end
end
