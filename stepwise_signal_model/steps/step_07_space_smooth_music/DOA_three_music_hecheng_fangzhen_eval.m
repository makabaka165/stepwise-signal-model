function [doa_value, edge_hit] = DOA_three_music_hecheng_fangzhen_eval( ...
    estm_data_in, subarray_num, A, angle_recv, search_width_deg, qSmoothRatio)
    % A1 评估版：搜索宽度与目标间隔解耦；使用 FindLocalPeak_NoEdge_Fun 禁止端点峰；额外返回 edge_hit 标志。
    % 输入：波束域数据、阵元数、波束矩阵、搜索中心、搜索宽度、平滑比例。
    % 输出：两个 DOA 估计值、是否命中搜索区间端点。

    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lamda = c / fc;
    derad = pi / 180;
    d = 0.047;
    Lc = 2;
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

    % 第一步：在波束域构造协方差矩阵，再对重叠子阵做平均。
    Rxxmc = Xc * Xc' / n;
    RxxC_mssp = mssp(Rxxmc, celln);
    Rx = 0.5 * (RxxC_mssp + RxxC_mssp');

    % 第二步：与 A0 相同，取中心连续 celln 个 beam 维持平滑后维数对齐。
    beam_start = floor((size(A, 2) - celln) / 2) + 1;
    beam_ind = beam_start:beam_start + celln - 1;

    % 第三步：在更宽的局部角域内做细搜索，步长 0.01 度。
    angle_search = angle_recv - search_width_deg/2 : 0.01 : angle_recv + search_width_deg/2;

    % 第四步：特征分解构造噪声子空间。
    [EVc, Dc] = eig(Rx);
    EVAc = diag(Dc).';
    [~, Ic] = sort(EVAc);
    EVc = fliplr(EVc(:, Ic));
    Enc = EVc(:, QQ:celln);

    SPc = zeros(1, length(angle_search));
    % 第五步：在搜索网格上逐点计算 MUSIC 空间谱（center 谱）。
    for iang = 1:length(angle_search)
        phim = derad * angle_search(iang);
        atheta = exp(-j * 2 * pi * position / lamda * sin(phim));
        ac = A(:, beam_ind).' * atheta;
        SPc(iang) = (ac' * ac) / max(ac' * Enc * Enc' * ac, eps);
    end

    p_SPc = abs(SPc);
    % 第六步：禁止端点峰，取最强的两个局部峰；并标记是否仍命中区间端点。
    [~, peak_ind] = FindLocalPeak_NoEdge_Fun(p_SPc);

    if length(peak_ind) < Lc
        doa_value = nan(1, Lc);
        edge_hit = false;
        return;
    end

    doa_value = sort(angle_search(peak_ind(1:Lc)));
    edge_hit = false;
    if all(isfinite(doa_value))
        edge_tol = 1e-12;
        edge_hit = any(abs(doa_value - angle_search(1)) < edge_tol) || ...
                   any(abs(doa_value - angle_search(end)) < edge_tol);
    end
end
