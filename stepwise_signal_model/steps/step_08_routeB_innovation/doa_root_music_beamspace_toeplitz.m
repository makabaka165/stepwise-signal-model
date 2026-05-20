function [doa_value, debug_info] = doa_root_music_beamspace_toeplitz(y, K, Tk, lambda, d, Lc)
% Beamspace Root-MUSIC after FBSS + Toeplitz projection + centerT projection.

    doa_value = nan(1, Lc);

    T_snap = size(y, 2);
    if T_snap < 1
        debug_info = fill_debug_failed_bs(eye(K), eye(K), nan(size(Tk, 2), 1), Lc, 0);
        return;
    end

    Rxx = (y * y') / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rss_pre = mssp_array_fb(Rxx, K);
    Rss_pre = 0.5 * (Rss_pre + Rss_pre');
    Rss = toeplitz_project(Rss_pre);

    Rb = Tk.' * Rss * conj(Tk);
    Rb = 0.5 * (Rb + Rb');

    [Vb, Db] = eig(Rb);
    eigvals_rb = real(diag(Db));
    [eigvals_rb, idx] = sort(eigvals_rb, 'descend');
    Vb = Vb(:, idx);

    if size(Vb, 2) <= Lc
        debug_info = fill_debug_failed_bs(Rss_pre, Rss, eigvals_rb, Lc, 0);
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
    inside_roots = rts(abs(rts) < 1);
    num_inside_roots = numel(inside_roots);
    if num_inside_roots < Lc
        debug_info = fill_debug_failed_bs(Rss_pre, Rss, eigvals_rb, Lc, num_inside_roots);
        return;
    end

    [~, ord] = sort(abs(abs(inside_roots) - 1), 'ascend');
    chosen = inside_roots(ord(1:Lc));

    omega = angle(chosen);
    sin_theta = -(lambda / (2 * pi * d)) * omega;
    if sum(abs(sin_theta) <= 1 + 1e-9) < Lc
        debug_info = fill_debug_failed_bs(Rss_pre, Rss, eigvals_rb, Lc, num_inside_roots);
        return;
    end

    sin_theta = min(max(real(sin_theta), -1), 1);
    doa_value = sort(asind(sin_theta)).';
    doa_value = doa_value(:).';

    if numel(doa_value) ~= Lc || any(~isfinite(doa_value))
        doa_value = nan(1, Lc);
        debug_info = fill_debug_failed_bs(Rss_pre, Rss, eigvals_rb, Lc, num_inside_roots);
        return;
    end

    debug_info = fill_debug_info_bs(Rss_pre, Rss, eigvals_rb, Lc, chosen, num_inside_roots);
end

function debug_info = fill_debug_info_bs(Rss_pre, Rss_post, eigvals_rb, Lc, chosen, num_inside_roots)
    [~, D_pre] = eig(0.5 * (Rss_pre + Rss_pre'));
    eigvals_rss_pre = sort(real(diag(D_pre)), 'descend');
    [~, D_post] = eig(0.5 * (Rss_post + Rss_post'));
    eigvals_rss_post = sort(real(diag(D_post)), 'descend');

    debug_info = struct();
    debug_info.eigvals_rb = eigvals_rb;
    debug_info.eigvals_rss_pre_tp = eigvals_rss_pre;
    debug_info.eigvals_rss_after_tp = eigvals_rss_post;
    debug_info.lambda2_over_noise = compute_lambda2_over_noise(eigvals_rb, Lc);
    debug_info.lambda2_over_noise_before_tp = compute_lambda2_over_noise(eigvals_rss_pre, Lc);
    debug_info.lambda2_over_noise_after_tp = compute_lambda2_over_noise(eigvals_rss_post, Lc);
    debug_info.num_inside_roots = num_inside_roots;
    debug_info.root_distance_unit = abs(abs(chosen) - 1);
    debug_info.toeplitz_residual_norm = norm(Rss_pre - Rss_post, 'fro') / max(norm(Rss_pre, 'fro'), eps);
end

function debug_info = fill_debug_failed_bs(Rss_pre, Rss_post, eigvals_rb, Lc, num_inside_roots)
    debug_info = fill_debug_info_bs(Rss_pre, Rss_post, eigvals_rb, Lc, ones(Lc, 1) * nan, num_inside_roots);
    debug_info.root_distance_unit = nan(Lc, 1);
end

function r = compute_lambda2_over_noise(eigvals, Lc)
    if numel(eigvals) < Lc + 1
        r = NaN;
        return;
    end
    noise_start = Lc + 1;
    noise_end = min(numel(eigvals), Lc + 6);
    noise_floor = mean(eigvals(noise_start:noise_end));
    r = eigvals(2) / max(noise_floor, eps);
end
