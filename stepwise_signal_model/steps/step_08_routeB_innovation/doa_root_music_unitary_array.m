function [doa_value, debug_info] = doa_root_music_unitary_array(y, K, lambda, d, Lc)
% Unitary array-domain Root-MUSIC after FBSS.

    doa_value = nan(1, Lc);

    T_snap = size(y, 2);
    if T_snap < 1
        debug_info = fill_debug_failed_arr(eye(K), eye(K), nan(K, 1), Lc, NaN);
        return;
    end

    Rxx = (y * y') / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    Q = unitary_matrix(K);
    Rss_real_complex = Q' * Rss * Q;
    max_imag_part_rel = norm(imag(Rss_real_complex), 'fro') / max(norm(Rss_real_complex, 'fro'), eps);

    Rss_real = real(Rss_real_complex);
    Rss_real = 0.5 * (Rss_real + Rss_real');

    [V_real, D_real] = eig(Rss_real);
    eigvals = real(diag(D_real));
    [eigvals, idx] = sort(eigvals, 'descend');
    V_real = V_real(:, idx);

    if numel(eigvals) <= Lc
        debug_info = fill_debug_failed_arr(Rss, Rss_real, eigvals, Lc, max_imag_part_rel);
        return;
    end

    En_real = V_real(:, Lc+1:end);
    En = Q * En_real;
    C = En * En';
    C = 0.5 * (C + C');

    M = K;
    poly_coeffs = zeros(1, 2 * M - 1);
    lag_list = -(M-1):(M-1);
    for ii = 1:numel(lag_list)
        poly_coeffs(ii) = sum(diag(C, lag_list(ii)));
    end

    rts = roots(fliplr(poly_coeffs));
    inside_roots = rts(abs(rts) < 1);
    num_inside_roots = numel(inside_roots);
    if num_inside_roots < Lc
        debug_info = fill_debug_failed_arr(Rss, Rss_real, eigvals, Lc, max_imag_part_rel);
        debug_info.num_inside_roots = num_inside_roots;
        return;
    end

    [~, ord] = sort(abs(abs(inside_roots) - 1), 'ascend');
    chosen = inside_roots(ord(1:Lc));

    omega = angle(chosen);
    sin_theta = -(lambda / (2 * pi * d)) * omega;
    if sum(abs(sin_theta) <= 1 + 1e-9) < Lc
        debug_info = fill_debug_failed_arr(Rss, Rss_real, eigvals, Lc, max_imag_part_rel);
        debug_info.num_inside_roots = num_inside_roots;
        return;
    end

    sin_theta = min(max(real(sin_theta), -1), 1);
    doa_value = sort(asind(sin_theta)).';
    doa_value = doa_value(:).';

    if numel(doa_value) ~= Lc || any(~isfinite(doa_value))
        doa_value = nan(1, Lc);
        debug_info = fill_debug_failed_arr(Rss, Rss_real, eigvals, Lc, max_imag_part_rel);
        debug_info.num_inside_roots = num_inside_roots;
        return;
    end

    debug_info = fill_debug_info_arr(Rss, Rss_real, eigvals, Lc, chosen, max_imag_part_rel, num_inside_roots);
end

function debug_info = fill_debug_info_arr(Rss, Rss_real, eigvals, Lc, chosen, max_imag_part_rel, num_inside_roots)
    debug_info = struct();
    debug_info.eigvals = eigvals;
    debug_info.lambda2_over_noise = compute_lambda2_over_noise(eigvals, Lc);
    debug_info.num_inside_roots = num_inside_roots;
    debug_info.root_distance_unit = abs(abs(chosen) - 1);
    debug_info.cond_number_complex = cond(Rss);
    debug_info.cond_number_real = cond(Rss_real);
    debug_info.max_imag_part_rel = max_imag_part_rel;
end

function debug_info = fill_debug_failed_arr(Rss, Rss_real, eigvals, Lc, max_imag_part_rel)
    debug_info = fill_debug_info_arr(Rss, Rss_real, eigvals, Lc, nan(Lc, 1), max_imag_part_rel, 0);
    debug_info.root_distance_unit = nan(Lc, 1);
end

function r = compute_lambda2_over_noise(eigvals, Lc)
    if numel(eigvals) < Lc + 1 || numel(eigvals) < 2
        r = NaN;
        return;
    end
    noise_start = Lc + 1;
    noise_end = min(numel(eigvals), Lc + 6);
    noise_floor = mean(eigvals(noise_start:noise_end));
    r = eigvals(2) / max(noise_floor, eps);
end
