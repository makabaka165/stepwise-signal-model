function [doa_value, debug] = DOA_three_music_hecheng_fangzhen_eval( ...
    estm_data_in, subarray_num, A, angle_recv, search_width_deg, varargin)

    p = inputParser;
    addParameter(p, 'Lc', 2);
    addParameter(p, 'QSmoothRatio', 0.2);
    parse(p, varargin{:});

    Lc = p.Results.Lc;
    qSmoothRatio = p.Results.QSmoothRatio;

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
    Q = round(qSmoothRatio * B);
    Q = max(Q, 1);
    Q = min(Q, B - Lc - 1);
    celln = B - Q;
    QQ = Lc + 1;

    if celln <= Lc
        doa_value = nan(1, Lc);
        debug = struct();
        debug.reason = 'celln_too_small';
        debug.B = B;
        debug.Q = Q;
        debug.celln = celln;
        return;
    end

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
        ac = A(:, beam_ind).' * exp(-j * 2 * pi * position / lamda * sin(phim));
        SPc(iang) = (ac' * ac) / (ac' * Enc * Enc' * ac);
    end

    p_SPc = abs(SPc);
    [~, peak_ind] = FindLocalPeak_NoEdge_Fun(p_SPc);

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
end
