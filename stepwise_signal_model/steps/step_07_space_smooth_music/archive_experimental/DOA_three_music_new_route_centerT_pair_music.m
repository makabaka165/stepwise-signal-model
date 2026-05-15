function [doa_value, debug] = DOA_three_music_new_route_centerT_pair_music( ...
    y, subarray_num, T_center, angle_recv, theta_bw, varargin)

    % Route C: keep the same frontend as Route B and replace only the
    % backend with a 2D pair-MUSIC search.

    p = inputParser;
    addParameter(p, 'Lc', 2);
    addParameter(p, 'GridStepDeg', 0.005);
    addParameter(p, 'SearchMarginDeg', []);
    addParameter(p, 'PairCenterTolDeg', []);
    addParameter(p, 'MinSepDeg', 0.03);
    addParameter(p, 'DiagonalLoading', 1e-12);
    parse(p, varargin{:});

    Lc = p.Results.Lc;
    grid_step_deg = p.Results.GridStepDeg;
    search_margin_deg = p.Results.SearchMarginDeg;
    pair_center_tol_deg = p.Results.PairCenterTolDeg;
    min_sep_deg = p.Results.MinSepDeg;
    diagonal_loading = p.Results.DiagonalLoading;

    if Lc ~= 2
        error('DOA_three_music_new_route_centerT_pair_music only supports Lc = 2.');
    end

    if isempty(search_margin_deg)
        search_margin_deg = 0;
    end

    if isempty(pair_center_tol_deg)
        pair_center_tol_deg = max(0.08, 0.05 * theta_bw);
    end

    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lambda = c / fc;
    d = 0.047;

    [Nuse, Lsnap] = size(y);
    if Nuse ~= subarray_num
        error('The row count of y must equal subarray_num.');
    end

    if size(T_center, 1) ~= subarray_num
        error('T_center row count must equal subarray_num.');
    end

    if size(T_center, 2) <= Lc
        error('T_center must have more columns than Lc.');
    end

    Rxx = y * y' / Lsnap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rx = mssp(Rxx, subarray_num);
    Rx = 0.5 * (Rx + Rx');

    Rb = T_center.' * Rx * conj(T_center);
    Rb = 0.5 * (Rb + Rb');

    [E, D] = eig(Rb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
    E = E(:, idx);

    if size(E, 2) <= Lc
        doa_value = nan(1, Lc);
        debug = struct();
        debug.reason = 'empty_noise_subspace';
        debug.eigvals = eigvals;
        return;
    end

    En = E(:, Lc+1:end);
    Qn = En * En';

    angle_grid = angle_recv - theta_bw/2 - search_margin_deg : ...
                 grid_step_deg : ...
                 angle_recv + theta_bw/2 + search_margin_deg;

    pos = d * (0:subarray_num-1).';
    G = zeros(size(T_center, 2), numel(angle_grid));
    for ii = 1:numel(angle_grid)
        theta = angle_grid(ii);
        a_sub = exp(-j * 2 * pi / lambda * pos * sind(theta));
        b_sub = T_center.' * a_sub;
        G(:, ii) = b_sub / max(norm(b_sub), eps);
    end

    best_score = inf;
    best_score_det = inf;
    best_pair = [nan nan];

    for ii = 1:numel(angle_grid)-1
        for jj = ii+1:numel(angle_grid)
            if angle_grid(jj) - angle_grid(ii) < min_sep_deg
                continue;
            end

            pair_center = 0.5 * (angle_grid(ii) + angle_grid(jj));
            if abs(pair_center - angle_recv) > pair_center_tol_deg
                continue;
            end

            Bpair = [G(:, ii), G(:, jj)];
            [Qpair, Rpair] = qr(Bpair, 0);
            if rcond(Rpair) < 1e-8
                continue;
            end

            Mpair = Qpair' * Qn * Qpair;
            score = real(trace(Mpair));
            score_det = real(det(Mpair + diagonal_loading * eye(2)));

            if score < best_score
                best_score = score;
                best_score_det = score_det;
                best_pair = [angle_grid(ii), angle_grid(jj)];
            end
        end
    end

    if ~all(isfinite(best_pair))
        doa_value = [NaN NaN];
        debug.reason = 'no_valid_pair';
        debug.angle_grid = angle_grid;
        debug.best_score = best_score;
        debug.best_score_det = best_score_det;
        debug.best_pair = best_pair;
        debug.eigvals = eigvals;
        debug.subarray_num = subarray_num;
        debug.center_beam_count = size(T_center, 2);
        debug.search_margin_deg = search_margin_deg;
        debug.pair_center_tol_deg = pair_center_tol_deg;
        debug.grid_step_deg = grid_step_deg;
        debug.min_sep_deg = min_sep_deg;
        debug.diagonal_loading = diagonal_loading;
        debug.score_mode = 'trace_Qpair_Qn_Qpair';
        return;
    end

    doa_value = sort(best_pair);

    debug.angle_grid = angle_grid;
    debug.best_score = best_score;
    debug.best_score_det = best_score_det;
    debug.best_pair = best_pair;
    debug.eigvals = eigvals;
    debug.subarray_num = subarray_num;
    debug.center_beam_count = size(T_center, 2);
    debug.search_margin_deg = search_margin_deg;
    debug.pair_center_tol_deg = pair_center_tol_deg;
    debug.grid_step_deg = grid_step_deg;
    debug.min_sep_deg = min_sep_deg;
    debug.diagonal_loading = diagonal_loading;
    debug.score_mode = 'trace_Qpair_Qn_Qpair';
end
