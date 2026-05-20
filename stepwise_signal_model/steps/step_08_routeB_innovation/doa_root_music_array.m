function [doa_value, debug_info] = doa_root_music_array(y, K, lambda, d, Lc)
% Array-domain Root-MUSIC after FBSS.

    debug_info = struct( ...
        'eigvals', nan(K, 1), ...
        'lambda2_over_noise', NaN, ...
        'num_inside_roots', 0, ...
        'root_distance_unit', nan(Lc, 1));
    doa_value = nan(1, Lc);

    if nargin < 5
        error('doa_root_music_array requires y, K, lambda, d, and Lc.');
    end

    T_snap = size(y, 2);
    if T_snap < 1
        return;
    end

    Rxx = (y * y') / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    [V, Dm] = eig(Rss);
    eigvals = real(diag(Dm));
    [eigvals, idx] = sort(eigvals, 'descend');
    V = V(:, idx);
    debug_info.eigvals = eigvals;

    if numel(eigvals) < max(Lc + 1, 2)
        return;
    end

    noise_start = Lc + 1;
    noise_end = min(numel(eigvals), Lc + 6);
    if noise_start <= noise_end
        noise_floor = mean(eigvals(noise_start:noise_end));
        debug_info.lambda2_over_noise = eigvals(min(2, numel(eigvals))) / max(noise_floor, eps);
    end

    if size(V, 2) <= Lc
        return;
    end

    En = V(:, Lc+1:end);
    C = En * En';

    M = K;
    poly_coeffs = zeros(1, 2 * M - 1);
    lag_list = -(M-1):(M-1);
    for ii = 1:numel(lag_list)
        poly_coeffs(ii) = sum(diag(C, lag_list(ii)));
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
