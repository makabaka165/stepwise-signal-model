function [peak_val, peak_ind] = FindLocalPeak_Fun(x)
    % 找出所有的局部峰值
    % 输入：矢量 x
    % 输出：peak_val 峰值序列 从大到小，peak_ind对应下标
    
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
    
    % 边缘两点特殊处理
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
    
    peak_ind = find(r3);
    peak_val = x(peak_ind);
    peak_num = length(peak_val);
    [peak_val, ind] = sort(peak_val);
    
    peak_ind = peak_ind(ind);
    
    % 数组翻转，实现从大到小排序
    peak_val = peak_val(peak_num:-1:1);
    peak_ind = peak_ind(peak_num:-1:1);
end