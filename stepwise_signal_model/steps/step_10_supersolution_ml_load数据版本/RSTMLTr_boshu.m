function [Pw] = RSTMLTr_boshu(ml_input, thetas1, thetas2, array_num, d, lamda, A1)
% Element-space steering matrix under the 2-target hypothesis.
j = sqrt(-1);
steering_vector_s = exp(-j * 2 * pi * d / lamda * (0 : array_num - 1).' * sind([thetas1, thetas2]));

% Map the element-space manifold into beamspace.
A = A1.' * steering_vector_s;
steering_vector_new = A;
PA = steering_vector_new * inv(steering_vector_new' * steering_vector_new) * steering_vector_new';

% Unnormalized concentrated-ML score in beamspace.
Pw = trace(PA * (ml_input * ml_input'));
end
