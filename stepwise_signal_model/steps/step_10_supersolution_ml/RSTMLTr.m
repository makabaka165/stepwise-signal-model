function [Pw] = RSTMLTr(ml_input, thetas1, thetas2, array_num, d, lamda)
% Build the element-space steering matrix for a 2-target hypothesis.
j = sqrt(-1);
steering_vector_s = exp(-j * 2 * pi * d / lamda * (0 : array_num - 1).' * sind([thetas1, thetas2]));

% For the direct ML case, the equivalent manifold is the element-space manifold itself.
steering_vector_new = steering_vector_s;
PA = steering_vector_new * inv(steering_vector_new' * steering_vector_new) * steering_vector_new';

% Unnormalized concentrated-ML score: tr(P_A * Y * Y^H).
Pw = trace(PA * (ml_input * ml_input'));
end
