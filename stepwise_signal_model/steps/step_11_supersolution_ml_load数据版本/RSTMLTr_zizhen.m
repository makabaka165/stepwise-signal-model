function [Pw] = RSTMLTr_zizhen(ml_input, thetas1, thetas2, array_num, d, lamda, A1)
% 构造双目标假设下的阵元级导向矢量。
j = sqrt(-1);
steering_vector_s = exp(-j * 2 * pi * d / lamda * (0 : array_num - 1).' * sind([thetas1, thetas2]));

% 将每个 4 阵元子阵的局部流形映射为 1 个子阵输出通道。
A = zeros(array_num / 4, 2);
for i = 1 : array_num / 4
    A(i, :) = A1.' * steering_vector_s((i - 1) * 4 + 1 : i * 4, :);
end

steering_vector_new = A;
PA = steering_vector_new * inv(steering_vector_new' * steering_vector_new) * steering_vector_new';

% 子阵域中的未归一化集中似然评分函数。
Pw = trace(PA * (ml_input * ml_input'));
end
