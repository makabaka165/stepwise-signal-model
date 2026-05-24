function [doa_value, debug_info] = doa_root_music_unitary_beamspace(y, K, Tk, lambda, d, Lc)
% Unitary beamspace Root-MUSIC after FBSS + centerT projection + beamspace FB.

    doa_value = nan(1, Lc);

    T_snap = size(y, 2);
    if T_snap < 1
        debug_info = fill_debug_failed_bs(eye(size(Tk, 2)), eye(size(Tk, 2)), nan(size(Tk, 2), 1), Lc, NaN);
        return;
    end

    Rxx = (y * y') / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    Rb = Tk.' * Rss * conj(Tk);
    Rb = 0.5 * (Rb + Rb');

    M_b = size(Rb, 1);
    J_b = fliplr(eye(M_b));
    Rb_fb = 0.5 * (Rb + J_b * conj(Rb) * J_b);
    Rb_fb = 0.5 * (Rb_fb + Rb_fb');

    Q_b = unitary_matrix(M_b);
    Rb_real_complex = Q_b' * Rb_fb * Q_b;
    max_imag_part_rel = norm(imag(Rb_real_complex), 'fro') / max(norm(Rb_real_complex, 'fro'), eps);

    Rb_real = real(Rb_real_complex);
    Rb_real = 0.5 * (Rb_real + Rb_real');

    [Vb_real, Db] = eig(Rb_real);
    eigvals_rb = real(diag(Db));
    [eigvals_rb, idx] = sort(eigvals_rb, 'descend');
    Vb_real = Vb_real(:, idx);

    if numel(eigvals_rb) <= Lc
        debug_info = fill_debug_failed_bs(Rb_fb, Rb_real, eigvals_rb, Lc, max_imag_part_rel);
        return;
    end

    En_b_real = Vb_real(:, Lc+1:end);
    En_b = Q_b * En_b_real;
    Q = conj(Tk) * (En_b * En_b') * Tk.';
    Q = 0.5 * (Q + Q');

    M = K;
    poly_coeffs = zeros(1, 2 * M - 1);
    lag_list = -(M-1):(M-1);
    for ii = 1:numel(lag_list)
        poly_coeffs(ii) = sum(diag(Q, lag_list(ii)));
    end

    rts = roots(fliplr(poly_coeffs));
    inside_roots = rts(abs(rts) < 1);
    num_inside_roots = numel(inside_roots);
    if num_inside_roots < Lc
        debug_info = fill_debug_failed_bs(Rb_fb, Rb_real, eigvals_rb, Lc, max_imag_part_rel);
        debug_info.num_inside_roots = num_inside_roots;
        return;
    end

    [~, ord] = sort(abs(abs(inside_roots) - 1), 'ascend');
    chosen = inside_roots(ord(1:Lc));

    omega = angle(chosen);
    sin_theta = -(lambda / (2 * pi * d)) * omega;
    if sum(abs(sin_theta) <= 1 + 1e-9) < Lc
        debug_info = fill_debug_failed_bs(Rb_fb, Rb_real, eigvals_rb, Lc, max_imag_part_rel);
        debug_info.num_inside_roots = num_inside_roots;
        return;
    end

    sin_theta = min(max(real(sin_theta), -1), 1);
    doa_value = sort(asind(sin_theta)).';
    doa_value = doa_value(:).';

    if numel(doa_value) ~= Lc || any(~isfinite(doa_value))
        doa_value = nan(1, Lc);
        debug_info = fill_debug_failed_bs(Rb_fb, Rb_real, eigvals_rb, Lc, max_imag_part_rel);
        debug_info.num_inside_roots = num_inside_roots;
        return;
    end

    debug_info = fill_debug_info_bs(Rb_fb, Rb_real, eigvals_rb, Lc, chosen, max_imag_part_rel, num_inside_roots);
end

function debug_info = fill_debug_info_bs(Rb, Rb_real, eigvals_rb, Lc, chosen, max_imag_part_rel, num_inside_roots)
    debug_info = struct();
    debug_info.eigvals_rb = eigvals_rb;
    debug_info.lambda2_over_noise = compute_lambda2_over_noise(eigvals_rb, Lc);
    debug_info.num_inside_roots = num_inside_roots;
    debug_info.root_distance_unit = abs(abs(chosen) - 1);
    debug_info.cond_number_rb_complex = cond(Rb);
    debug_info.cond_number_rb_real = cond(Rb_real);
    debug_info.max_imag_part_rel = max_imag_part_rel;
end

function debug_info = fill_debug_failed_bs(Rb, Rb_real, eigvals_rb, Lc, max_imag_part_rel)
    debug_info = fill_debug_info_bs(Rb, Rb_real, eigvals_rb, Lc, nan(Lc, 1), max_imag_part_rel, 0);
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
