function doa_value = DOA_three_music_new_route_centerT(y, subarray_num, T, angle_recv, theta_bw)
    % 新路线：阵元域先做空间平滑，再投影到中心截取T波束域进行 MUSIC 双目标测角。
    % 输入：
    %   y             阵元域输入数据，维度为“阵元数 x 快拍数”
    %   subarray_num  当前使用的阵元子阵长度
    %   T             阵元域到中心截取T波束域的投影矩阵
    %   angle_recv    当前局部搜索中心角
    %   theta_bw      当前局部搜索宽度
    % 输出：
    %   doa_value     检测得到的两个角度峰值；若峰数不足则返回 NaN
    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lamda = c / fc;
    derad = pi / 180; % 角度转弧度
    d = 0.047;
    position = [d * (0:subarray_num-1)]';
    n = size(y, 2);
    Lc = 2; % 当前验证脚本固定假设有两个相干目标
    QQ = Lc + 1;

    % 第一步：先在阵元域构造协方差矩阵，再进行空间平滑，最后投影到波束域。
    Rxx = y * y' / n;
    Rx = mssp(Rxx, subarray_num);
    Rb = T' * Rx * T;

    % 第二步：围绕局部中心角做细搜索，步长固定为 0.01 度。
    angle_search = angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2;

    % 第三步：对波束域协方差矩阵做特征分解，构造噪声子空间。
    [EVb, Db] = eig(Rb);
    EVAb = diag(Db)';
    [~, Ib] = sort(EVAb);
    EVb = fliplr(EVb(:, Ib));
    Enb = EVb(:, QQ:size(Rb, 1));

    % 第四步：在局部角域内逐点计算 MUSIC 空间谱。
    SPb = zeros(1, length(angle_search));
    for iang = 1 : length(angle_search)
        phim = derad * angle_search(iang);
        a_sub = exp(-j*2*pi*position/lamda*sin(phim));
        b_sub = T' * a_sub;
        SPb(iang) = (b_sub' * b_sub) / (b_sub' * Enb * Enb' * b_sub);
    end

    p_SPb = abs(SPb);
    [~, peak_ind] = FindLocalPeak_Fun(p_SPb);
    if length(peak_ind) < Lc
        doa_value = nan(1, Lc);
        return
    end

    % 第五步：取最强的两个局部峰，并按从左到右排序。
    doa_value = sort(angle_search(peak_ind(1:2)));
end
