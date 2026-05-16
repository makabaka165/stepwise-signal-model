function [peak_val, peak_ind] = FindLocalPeak_Fun(x)
    % 找出输入序列中的全部局部峰值。
    % 输入：
    %   x        待搜索的一维序列
    % 输出：
    %   peak_val 按从大到小排序后的峰值
    %   peak_ind 与 peak_val 对应的峰值下标

    % 统一按行向量处理，并先取幅值，避免复数输入影响比较过程。
    x1 = abs(x);
    x1 = reshape(x1, 1, length(x1));
    a_x = x1;
    L = length(x1);

    a_x_min = min(a_x);
    a_x_leftshift = [a_x(2:L), a_x_min];
    a_x_rightshift = [a_x_min, a_x(1:(L-1))];
    r1 = a_x > a_x_leftshift;
    r2 = a_x > a_x_rightshift;
    r3 = r1 .* r2;

    % 对两端点做单独判断，避免移位比较时漏检边界峰。
    if x1(1) > x1(2)
        r3(1) = 1;
    else
        r3(1) = 0;
    end

    if x1(L) > x1(L-1)
        r3(L) = 1;
    else
        r3(L) = 0;
    end

    % 汇总全部峰值位置，并按峰值大小从大到小重新排序。
    peak_ind = find(r3);
    peak_val = x(peak_ind);
    peak_num = length(peak_val);
    [peak_val, ind] = sort(peak_val);

    peak_ind = peak_ind(ind);

    % 翻转排序结果，使峰值按从大到小输出。
    peak_val = peak_val(peak_num:-1:1);
    peak_ind = peak_ind(peak_num:-1:1);
end
