function ers = mssp(cr, k)
    % 改进型空间平滑：
    % 先做前后向平均，再对全部重叠子阵的协方差矩阵求均值。
    % 输入：
    %   cr  原始协方差矩阵
    %   k   平滑后子阵维数
    % 输出：
    %   ers 空间平滑后的协方差矩阵
    [M, ~] = size(cr);
    N = M - k + 1;
    J = fliplr(eye(M));
    crfb = (cr + J * cr.' * J) / 2;
    crs = zeros(k, k);
    
    % 对所有长度为 k 的重叠子阵做平均。
    for in = 1:N
        crs = crs + crfb(in:in+k-1, in:in+k-1);
    end
    
    ers = crs / N;
end
