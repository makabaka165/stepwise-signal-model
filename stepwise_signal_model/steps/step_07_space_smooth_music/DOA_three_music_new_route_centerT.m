function [doa_value, num_peaks] = DOA_three_music_new_route_centerT( ...
    y, K, Tk, angle_recv, search_width_deg)
    % Route B：阵元域 FBSS -> centerT 投影 -> 1D MUSIC。
    % 输入：阵元域数据、FBSS 子阵长度、外部构造的 centerT、搜索中心、搜索宽度。
    % 输出：两个 DOA 估计值、找到的局部峰个数。

    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lamda = c / fc;
    d = 0.047;
    Lc = 2;
    [~, T_snap] = size(y);
    posK = d * (0:K-1).';

    % 第一步：阵元域协方差。
    Rxx = y * y' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    % 第二步：严格阵元域前后向空间平滑（FBSS）。
    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    % 第三步：投影到外部传入的 centerT 波束域。
    Rb = Tk.' * Rss * conj(Tk);  % Tk 用正指数、aK 用负指数，故厄米共轭由 Tk.' 与 conj(Tk) 配对
    Rb = 0.5 * (Rb + Rb');

    % 第四步：特征分解构造噪声子空间。
    [E, D] = eig(Rb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
    E = E(:, idx);
    En = E(:, Lc+1:end);

    % 第五步：在局部角域内做一维 MUSIC 搜索。
    angle_search = angle_recv - search_width_deg/2 : 0.01 : angle_recv + search_width_deg/2;
    Pmu = zeros(1, numel(angle_search));
    for ii = 1:numel(angle_search)
        theta = angle_search(ii);
        aK = exp(-j * 2*pi/lamda * posK * sind(theta));
        bK = Tk.' * aK;
        den = real(bK' * En * En' * bK);
        num = real(bK' * bK);
        Pmu(ii) = num / max(den, eps);
    end

    % 第六步：禁止端点峰，取最强的两个局部峰。
    [~, peak_ind] = FindLocalPeak_NoEdge_Fun(abs(Pmu));
    num_peaks = numel(peak_ind);
    if num_peaks < Lc
        doa_value = nan(1, Lc);
        return;
    end

    doa_value = sort(angle_search(peak_ind(1:Lc)));
end
