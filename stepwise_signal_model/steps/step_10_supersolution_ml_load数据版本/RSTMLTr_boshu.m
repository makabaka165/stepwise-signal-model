function [Pw] = RSTMLTr_boshu(ml_input, thetas1, thetas2, array_num, d, lamda, A1)
% 构造双目标假设下的阵元级导向矢量。
j = sqrt(-1);
steering_vector_s = exp(-j * 2 * pi * d / lamda * (0 : array_num - 1).' * sind([thetas1, thetas2]));

% 将阵元级流形矩阵映射到波束域。
A = A1.' * steering_vector_s;
steering_vector_new = A;
PA = steering_vector_new * inv(steering_vector_new' * steering_vector_new) * steering_vector_new';

% 波束域中的未归一化集中似然评分函数。
Pw = trace(PA * (ml_input * ml_input'));
end
