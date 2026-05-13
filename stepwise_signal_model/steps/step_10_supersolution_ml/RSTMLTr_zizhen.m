function [Pw] = RSTMLTr_zizhen(ml_input, thetas1, thetas2, array_num, d, lamda, A1)
% Element-space steering matrix under the 2-target hypothesis.
j = sqrt(-1);
steering_vector_s = exp(-j * 2 * pi * d / lamda * (0 : array_num - 1).' * sind([thetas1, thetas2]));

% Map each 4-element subarray manifold to one synthesized subarray channel.
A = zeros(array_num / 4, 2);
for i = 1 : array_num / 4
    A(i, :) = A1.' * steering_vector_s((i - 1) * 4 + 1 : i * 4, :);
end

steering_vector_new = A;
PA = steering_vector_new * inv(steering_vector_new' * steering_vector_new) * steering_vector_new';

% Unnormalized concentrated-ML score in subarray space.
Pw = trace(PA * (ml_input * ml_input'));
end
