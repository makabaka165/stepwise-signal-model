function [doa_value, debug_info] = doa_root_music_beamspace(y, K, Tk, lambda, d, Lc)
% Beamspace Root-MUSIC after FBSS + centerT projection.

    M_b = size(Tk, 2);
    debug_info = struct( ...
        'eigvals_rb', nan(M_b, 1), ...
        'lambda2_over_noise', NaN, ...
        'num_inside_roots', 0, ...
        'root_distance_unit', nan(Lc, 1));
    doa_value = nan(1, Lc);

    if nargin < 6
        error('doa_root_music_beamspace requires y, K, Tk, lambda, d, and Lc.');
    end

    T_snap = size(y, 2);
    if T_snap < 1
        return;
    end

    Rxx = (y * y') / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    Rb = Tk.' * Rss * conj(Tk);
    Rb = 0.5 * (Rb + Rb');

    [Vb, Db] = eig(Rb);
    eigvals_rb = real(diag(Db));
    [eigvals_rb, idx] = sort(eigvals_rb, 'descend');
    Vb = Vb(:, idx);
    debug_info.eigvals_rb = eigvals_rb;

    if numel(eigvals_rb) < max(Lc + 1, 2)
        return;
    end

    noise_start = Lc + 1;
    noise_end = min(numel(eigvals_rb), Lc + 6);
    if noise_start <= noise_end
        noise_floor = mean(eigvals_rb(noise_start:noise_end));
        debug_info.lambda2_over_noise = eigvals_rb(min(2, numel(eigvals_rb))) / max(noise_floor, eps);
    end

    if size(Vb, 2) <= Lc
        return;
    end

    En_b = Vb(:, Lc+1:end);
    Q = conj(Tk) * (En_b * En_b') * Tk.';
    Q = 0.5 * (Q + Q');

    M = K;
    poly_coeffs = zeros(1, 2 * M - 1);
    lag_list = -(M-1):(M-1);
    for ii = 1:numel(lag_list)
        poly_coeffs(ii) = sum(diag(Q, lag_list(ii)));
    end

    rts = roots(fliplr(poly_coeffs));
    if isempty(rts)
        return;
    end

    inside_roots = rts(abs(rts) < 1);
    debug_info.num_inside_roots = numel(inside_roots);
    if numel(inside_roots) < Lc
        return;
    end

    [~, ord] = sort(abs(abs(inside_roots) - 1), 'ascend');
    chosen = inside_roots(ord(1:Lc));
    debug_info.root_distance_unit = abs(abs(chosen) - 1);

    omega = angle(chosen);
    sin_theta = -(lambda / (2 * pi * d)) * omega;
    if sum(abs(sin_theta) <= 1 + 1e-9) < Lc
        return;
    end

    sin_theta = min(max(real(sin_theta), -1), 1);
    doa_value = sort(asind(sin_theta)).';
    doa_value = doa_value(:).';

    if numel(doa_value) ~= Lc || any(~isfinite(doa_value))
        doa_value = nan(1, Lc);
    end
end
