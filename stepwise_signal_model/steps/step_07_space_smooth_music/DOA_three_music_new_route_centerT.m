function [doa_value, debug] = DOA_three_music_new_route_centerT( ...
    y, K, beam_grid_full_deg, center_beam_count, angle_recv, search_width_deg, varargin)
    % Route B：
    % 严格阵元域 FBSS -> centerT 波束域投影 -> 一维 MUSIC。
    %
    % y                  : N x T_snap 阵元域快拍
    % K                  : FBSS 子阵长度，要求 K < N
    % beam_grid_full_deg : 完整候选波束角网格（度）
    % center_beam_count  : 中心截取的波束数量
    % angle_recv         : 局部搜索中心角（度）
    % search_width_deg   : MUSIC 搜索宽度（度）

    p = inputParser;
    addParameter(p, 'Lc', 2);
    addParameter(p, 'GridStepDeg', 0.01);
    addParameter(p, 'UseQR', true);
    parse(p, varargin{:});

    Lc = p.Results.Lc;
    grid_step_deg = p.Results.GridStepDeg;
    use_qr = p.Results.UseQR;

    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lambda = c / fc;
    d = 0.047;

    [N, T_snap] = size(y);

    if K >= N
        error('严格 FBSS 要求 K 小于 N。');
    end

    if K <= Lc
        error('K 必须大于目标数 Lc。');
    end

    Psub = N - K + 1;
    if Psub < Lc
        error('重叠子阵数 N-K+1 不能小于 Lc。');
    end

    beam_grid_full_deg = reshape(beam_grid_full_deg, 1, []);
    full_beam_count = numel(beam_grid_full_deg);

    if center_beam_count <= Lc
        error('中心波束数量必须大于目标数 Lc。');
    end

    if center_beam_count > full_beam_count
        error('中心波束数量不能超过完整波束网格数量。');
    end

    if search_width_deg <= 0
        error('搜索宽度必须为正数。');
    end

    % 1. 阵元域协方差
    Rxx = y * y' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    % 2. 严格阵元域 FBSS
    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    % 3. 从完整波束网格中截取中心波束
    center_idx = floor((full_beam_count + 1) / 2);
    half_left = floor((center_beam_count - 1) / 2);
    half_right = center_beam_count - half_left - 1;

    start_idx = center_idx - half_left;
    end_idx = center_idx + half_right;

    if start_idx < 1 || end_idx > full_beam_count
        error('中心波束截取超出波束网格边界。');
    end

    center_indices = start_idx:end_idx;
    beam_grid_center_deg = beam_grid_full_deg(center_indices);

    % 4. 构造 K 维 centerT 投影矩阵
    posK = d * (0:K-1).';

    % 使用正指数约定，与 Route A 的 A.' * y 保持一致。
    Wcenter = exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg));

    if use_qr
        [Tk, ~] = qr(Wcenter, 0);
    else
        Tk = Wcenter;
    end

    if size(Tk, 2) <= Lc
        error('波束域维数必须大于目标数 Lc。');
    end

    % 5. 波束域协方差
    % Tk 使用正指数，阵元导向矢量使用负指数，因此投影保持：
    %   B = Tk.' * Y
    %   Rb = Tk.' * Rss * conj(Tk)
    Rb = Tk.' * Rss * conj(Tk);
    Rb = 0.5 * (Rb + Rb');

    % 6. 特征分解
    [E, D] = eig(Rb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
    E = E(:, idx);

    if size(E, 2) <= Lc
        doa_value = nan(1, Lc);
        debug = struct();
        debug.reason = '噪声子空间为空';
        debug.eigvals = eigvals;
        return;
    end

    En = E(:, Lc+1:end);

    % 7. 一维 MUSIC 搜索
    angle_search = angle_recv - search_width_deg/2 : ...
                   grid_step_deg : ...
                   angle_recv + search_width_deg/2;

    Pmu = zeros(1, numel(angle_search));

    for ii = 1:numel(angle_search)
        theta = angle_search(ii);

        aK = exp(-j * 2*pi/lambda * posK * sind(theta));
        bK = Tk.' * aK;

        den = real(bK' * En * En' * bK);
        num = real(bK' * bK);

        Pmu(ii) = num / max(den, eps);
    end

    [~, peak_ind] = FindLocalPeak_NoEdge_Fun(abs(Pmu));

    debug.num_peaks = numel(peak_ind);
    if isempty(peak_ind)
        debug.peak_angles = [];
        debug.peak_values = [];
    else
        keep_count = min(numel(peak_ind), 5);
        debug.peak_angles = angle_search(peak_ind(1:keep_count));
        debug.peak_values = Pmu(peak_ind(1:keep_count));
    end

    if numel(peak_ind) < Lc
        doa_value = nan(1, Lc);
    else
        doa_value = sort(angle_search(peak_ind(1:Lc)));
    end

    debug.angle_search = angle_search;
    debug.spectrum = Pmu;
    debug.eigvals = eigvals;
    debug.K = K;
    debug.N = N;
    debug.Psub = Psub;
    debug.center_indices = center_indices;
    debug.beam_grid_center_deg = beam_grid_center_deg;
    debug.center_beam_count = center_beam_count;
    debug.use_qr = use_qr;
    debug.search_width_deg = search_width_deg;
    debug.grid_step_deg = grid_step_deg;
end
