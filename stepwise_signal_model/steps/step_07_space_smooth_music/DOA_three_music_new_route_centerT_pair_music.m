function [doa_value, debug] = DOA_three_music_new_route_centerT_pair_music( ...
    y, subarray_num, T_center, angle_recv, theta_bw, varargin)

    % 新路线 centerT 的 2D pair-MUSIC 版本：
    % 阵元域处理 -> centerT beamspace -> 角度对 MUSIC 搜索。
    %
    % 该函数只改变 MUSIC 后端，不改变当前 Route B 的前端处理逻辑。
    % 即：仍使用 Rx = mssp(Rxx, subarray_num)，保持与
    % DOA_three_music_new_route_centerT.m 的前半段一致。

    p = inputParser;
    addParameter(p, 'Lc', 2);
    addParameter(p, 'GridStepDeg', 0.005);
    addParameter(p, 'SearchMarginDeg', []);
    addParameter(p, 'MinSepDeg', 0.03);
    addParameter(p, 'DiagonalLoading', 1e-12);
    parse(p, varargin{:});

    Lc = p.Results.Lc;
    grid_step_deg = p.Results.GridStepDeg;
    search_margin_deg = p.Results.SearchMarginDeg;
    min_sep_deg = p.Results.MinSepDeg;
    diagonal_loading = p.Results.DiagonalLoading;

    if Lc ~= 2
        error('DOA_three_music_new_route_centerT_pair_music only supports Lc = 2.');
    end

    if isempty(search_margin_deg)
        search_margin_deg = max(0.2, 0.2 * theta_bw);
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

    % 1. 阵元域协方差
    Rxx = y * y' / Lsnap;
    Rxx = 0.5 * (Rxx + Rxx');

    % 2. 保持与当前 Route B 一致的前端处理
    Rx = mssp(Rxx, subarray_num);
    Rx = 0.5 * (Rx + Rx');

    % 3. centerT beamspace 投影
    Rb = T_center' * Rx * T_center;
    Rb = 0.5 * (Rb + Rb');

    % 4. EVD
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

    % 5. 搜索角网格
    angle_grid = angle_recv - theta_bw/2 - search_margin_deg : ...
                 grid_step_deg : ...
                 angle_recv + theta_bw/2 + search_margin_deg;

    pos = d * (0:subarray_num-1).';
    G = zeros(size(T_center, 2), numel(angle_grid));

    for ii = 1:numel(angle_grid)
        theta = angle_grid(ii);
        a_sub = exp(-j * 2*pi/lambda * pos * sind(theta));
        b_sub = T_center' * a_sub;
        G(:, ii) = b_sub / max(norm(b_sub), eps);
    end

    % 6. 2D pair-MUSIC 搜索
    best_score = inf;
    best_pair = [nan nan];

    for ii = 1:numel(angle_grid)-1
        for jj = ii+1:numel(angle_grid)

            if angle_grid(jj) - angle_grid(ii) < min_sep_deg
                continue;
            end

            Bpair = [G(:, ii), G(:, jj)];
            Gram = Bpair' * Bpair;

            if rcond(Gram) < 1e-8
                continue;
            end

            Mpair = Bpair' * Qn * Bpair;
            score = real(det(Mpair + diagonal_loading * eye(2)));

            if score < best_score
                best_score = score;
                best_pair = [angle_grid(ii), angle_grid(jj)];
            end
        end
    end

    if ~all(isfinite(best_pair))
        doa_value = [NaN NaN];
        debug.reason = 'no_valid_pair';
        debug.angle_grid = angle_grid;
        debug.best_score = best_score;
        debug.best_pair = best_pair;
        debug.eigvals = eigvals;
        debug.subarray_num = subarray_num;
        debug.center_beam_count = size(T_center, 2);
        debug.search_margin_deg = search_margin_deg;
        debug.grid_step_deg = grid_step_deg;
        debug.min_sep_deg = min_sep_deg;
        debug.diagonal_loading = diagonal_loading;
        return;
    end

    doa_value = sort(best_pair);

    debug.angle_grid = angle_grid;
    debug.best_score = best_score;
    debug.best_pair = best_pair;
    debug.eigvals = eigvals;
    debug.subarray_num = subarray_num;
    debug.center_beam_count = size(T_center, 2);
    debug.search_margin_deg = search_margin_deg;
    debug.grid_step_deg = grid_step_deg;
    debug.min_sep_deg = min_sep_deg;
    debug.diagonal_loading = diagonal_loading;
end
