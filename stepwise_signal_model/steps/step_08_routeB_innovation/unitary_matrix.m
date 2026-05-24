function Q = unitary_matrix(K)
% Constructs K x K unitary matrix Q (Lee 1981).

    if K < 1 || mod(K, 1) ~= 0
        error('unitary_matrix: K must be a positive integer.');
    end

    if mod(K, 2) == 0
        m = K / 2;
        Im = eye(m);
        Jm = fliplr(eye(m));
        Q = (1 / sqrt(2)) * [Im, 1j * Im; ...
                             Jm, -1j * Jm];
    else
        m = (K - 1) / 2;
        Im = eye(m);
        Jm = fliplr(eye(m));
        zero_col = zeros(m, 1);
        zero_row = zeros(1, m);
        Q = (1 / sqrt(2)) * [Im, zero_col, 1j * Im; ...
                             zero_row, sqrt(2), zero_row; ...
                             Jm, zero_col, -1j * Jm];
    end
end
