function [Pw] = RSTMLTr(ml_input, thetas1, thetas2, array_num, d, lamda)
% 构造双目标假设下的阵元级导向矩阵。
j = sqrt(-1);
steering_vector_s = exp(-j * 2 * pi * d / lamda * (0 : array_num - 1).' * sind([thetas1, thetas2]));

% 直接 ML 情形下，等效流形矩阵就是阵元级流形矩阵本身。
steering_vector_new = steering_vector_s;
PA = steering_vector_new * inv(steering_vector_new' * steering_vector_new) * steering_vector_new';

% 未归一化的集中似然评分函数：tr(P_A * Y * Y^H)。
Pw = trace(PA * (ml_input * ml_input'));
end
