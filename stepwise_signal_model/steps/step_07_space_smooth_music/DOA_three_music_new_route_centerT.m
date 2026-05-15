function doa_value = DOA_three_music_new_route_centerT(y, subarray_num, T_center, angle_recv, theta_bw)
    % Route B: element-domain preprocessing -> centerT beamspace -> 1D MUSIC.
    % Keep the existing 1D peak-picking logic and only fix the centerT
    % projection direction so it is consistent with the old route A.' * y.

    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lamda = c / fc;
    derad = pi / 180;
    d = 0.047;
    position = (d * (0:subarray_num-1)).';
    n = size(y, 2);
    Lc = 2;
    QQ = Lc + 1;

    Rxx = y * y' / n;
    Rx = mssp(Rxx, subarray_num);
    Rb = T_center.' * Rx * conj(T_center);
    Rb = 0.5 * (Rb + Rb');

    angle_search = angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2;

    [EVb, Db] = eig(Rb);
    EVAb = diag(Db).';
    [~, Ib] = sort(EVAb);
    EVb = fliplr(EVb(:, Ib));
    Enb = EVb(:, QQ:size(Rb, 1));

    SPb = zeros(1, length(angle_search));
    for iang = 1:length(angle_search)
        phim = derad * angle_search(iang);
        a_sub = exp(-j * 2 * pi * position / lamda * sin(phim));
        b_sub = T_center.' * a_sub;
        SPb(iang) = (b_sub' * b_sub) / (b_sub' * Enb * Enb' * b_sub);
    end

    p_SPb = abs(SPb);
    [~, peak_ind] = FindLocalPeak_Fun(p_SPb);
    if length(peak_ind) < Lc
        doa_value = nan(1, Lc);
        return;
    end

    doa_value = sort(angle_search(peak_ind(1:2)));
end
