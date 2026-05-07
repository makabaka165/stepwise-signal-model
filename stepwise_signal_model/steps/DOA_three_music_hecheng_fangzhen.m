function doa_value = DOA_three_music_hecheng_fangzhen(estm_data_in, subarray_num, A, angle_recv, theta_bw)
    % 上下文修复：输入参数的 angel_recv 已修正为 angle_recv
    j = sqrt(-1);
    freq = 10;
    lamda = 0.3 / freq;
    derad = pi / 180; % deg -> rad
    d = 0.015;
    N2P = subarray_num;
    position = [d * (0:N2P-1)]';
    Xc = estm_data_in;
    n = size(estm_data_in, 2);
    Q = 0;   % 子阵数量为Q+1
    celln = size(Xc, 1) - Q;
    
    % 算法
    Xc = Xc(:, ceil(size(Xc, 2)/2));
    Rxxmc = Xc * Xc' / n;
    RxxC_mssp = mssp(Rxxmc, celln);
    Rx = RxxC_mssp;
    
    alori_num = 1;
    Lc = 1; % 目标数量
    
    % 上下文修复：统一变量名为 theta_bw
    angle_search = [angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2];
    
    if subarray_num == 256
        QQ = Lc + 1;
    else
        QQ = Lc + 1;
    end
    
    [EVc, Dc] = eig(Rx);
    EVAc = diag(Dc)';
    [~, Ic] = sort(EVAc);
    EVc = fliplr(EVc(:, Ic));
    
    for iang = 1 : length(angle_search)
        phim = derad * angle_search(iang);
        ac = A(:, 1:celln).' * (exp(-j*2*pi*position/lamda*sin(phim)));
        Enc = EVc(:, QQ:celln);  % En=EV(:, L+1:kelm);
        SPc(iang) = (ac' * ac) / (ac' * Enc * Enc' * ac); % SP(iang) = (a'*a)/(a'*En*En'*a)
    end
    
    p_SPc = abs(SPc);
    SPcmax = max(p_SPc);
    p_SPc1 = 10 * log10(p_SPc / SPcmax);
    
    [peak_val, peak_ind] = FindLocalPeak_Fun(p_SPc); % 峰值排序
    doa_value = angle_search(peak_ind(1));
    
    figure();
    plot(angle_search, abs(p_SPc));
    hold on;
end