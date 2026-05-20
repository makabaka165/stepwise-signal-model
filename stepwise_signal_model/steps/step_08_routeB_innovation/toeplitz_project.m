function R_t = toeplitz_project(R)
% Hermitian Toeplitz projection.

    K = size(R, 1);
    if size(R, 2) ~= K
        error('toeplitz_project: R must be square.');
    end

    R = 0.5 * (R + R');

    r = zeros(K, 1);
    for k = 0:K-1
        r(k+1) = mean(diag(R, k));
    end

    r(1) = real(r(1));
    R_t = toeplitz(r);
    R_t = 0.5 * (R_t + R_t');
end
