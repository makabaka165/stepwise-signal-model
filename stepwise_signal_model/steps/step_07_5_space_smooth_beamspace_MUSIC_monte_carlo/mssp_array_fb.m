function Rfbss = mssp_array_fb(Rxx, K)
    % True array-domain forward-backward spatial smoothing.
    %
    % Rxx : N x N array covariance
    % K   : subarray length, must satisfy K < N

    N = size(Rxx, 1);

    if size(Rxx, 2) ~= N
        error('Rxx must be square.');
    end

    if K >= N
        error('K must be smaller than N for true spatial smoothing.');
    end

    if K < 2
        error('K must be at least 2.');
    end

    P = N - K + 1;

    Rf = zeros(K, K);
    for p = 1:P
        idx = p:p+K-1;
        Rf = Rf + Rxx(idx, idx);
    end
    Rf = Rf / P;

    J = fliplr(eye(K));
    Rfbss = 0.5 * (Rf + J * conj(Rf) * J);
    Rfbss = 0.5 * (Rfbss + Rfbss');
end
