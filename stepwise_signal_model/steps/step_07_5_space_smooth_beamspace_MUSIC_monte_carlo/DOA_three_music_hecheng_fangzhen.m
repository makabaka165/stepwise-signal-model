function doa_value = DOA_three_music_hecheng_fangzhen(estm_data_in, subarray_num, A, angle_recv, theta_bw)
    % 旧路线：先在波束域构造数据，再在波束域近似做空间平滑并进行 MUSIC 测角。
    % 输入：
    %   estm_data_in  波束形成后的输入数据，维度为“波束数 x 快拍数”
    %   subarray_num  阵元数，用于构造导向矢量
    %   A             局部波束形成矩阵
    %   angle_recv    当前局部搜索中心角
    %   theta_bw      当前双目标角间隔，同时也用来设置局部搜索范围
    % 输出：
    %   doa_value     检测得到的两个角度峰值；若峰数不足则返回 NaN
    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lamda = c / fc;
    derad = pi / 180; % 角度转弧度
    d = 0.047;
    N2P = subarray_num;
    position = [d * (0:N2P-1)]';
    Xc = estm_data_in;
    n = size(estm_data_in, 2);
    Q = 10;  % 对波束域数据划分 11 个重叠子阵
    celln = size(Xc, 1) - Q;
    
    % 第一步：在波束域构造协方差矩阵，再对重叠波束子阵做平均。
    Rxxmc = Xc * Xc' / n;
    RxxC_mssp = mssp(Rxxmc, celln);
    Rx = RxxC_mssp;
    % 第二步：为了和平滑后的维数一致，只取中间连续的 celln 个波束。
    % 这里对应的是此前讨论过的“中间截取”思路。
    beam_start = floor((size(A, 2) - celln) / 2) + 1;
    beam_ind = beam_start : beam_start + celln - 1;
    
    Lc = 2; % 当前验证脚本固定假设有两个相干目标
    % 第三步：围绕局部中心角做细搜索，步长固定为 0.01 度。
    angle_search = angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2;
    QQ = Lc + 1;
    
    % 对平滑后的协方差矩阵做特征分解，构造噪声子空间。
    [EVc, Dc] = eig(Rx);
    EVAc = diag(Dc)';
    [~, Ic] = sort(EVAc);
    EVc = fliplr(EVc(:, Ic));
    
    % 前 Lc 个特征向量对应信号子空间，剩余向量构成噪声子空间。
    Enc = EVc(:, QQ:celln);
    % 第四步：在局部角域内逐点计算 MUSIC 空间谱。
    SPc = zeros(1, length(angle_search));
    for iang = 1 : length(angle_search)
        phim = derad * angle_search(iang);
        ac = A(:, beam_ind).' * exp(-j*2*pi*position/lamda*sin(phim));
        SPc(iang) = (ac' * ac) / (ac' * Enc * Enc' * ac);
    end
    
    p_SPc = abs(SPc);
    [~, peak_ind] = FindLocalPeak_Fun(p_SPc);
    if length(peak_ind) < Lc
        doa_value = nan(1, Lc);
        return
    end
    
    % 第五步：取最强的两个局部峰，并按从左到右排序，
    % 便于和真实角度 [theta_a, theta_b] 一一对应。
    % doa_value = [较小角度峰值, 较大角度峰值]
    doa_value = sort(angle_search(peak_ind(1:2)));
end
