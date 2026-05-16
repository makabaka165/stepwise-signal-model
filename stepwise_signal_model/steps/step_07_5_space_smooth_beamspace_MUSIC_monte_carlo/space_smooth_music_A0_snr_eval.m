clc
clear
close all

rng(20260515, 'twister');

c = 3e8;
array_num = 64;
fc = 2.7e9;
lambda = c / fc;
d = 0.047;

bw_64 = 50.8 * 1.45 * lambda / (array_num - 1) / d;
bw_64 = roundn(bw_64, -1);

theta_c = 13;
snr_list = -10:2:30;
Metkl = 200;
T_snap = 260;
theta_sep = bw_64 / 1;
tol_deg = 0.1;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
position_full = d * (0:array_num-1).';
win_old = taylorwin(array_num, 25, -40)';
win_old = win_old / sqrt(win_old * win_old');

routeA0_beam_span = bw_64;
M_old_A0 = 50;
angle_recv_A0 = linspace(theta_c - routeA0_beam_span / 2, ...
                         theta_c + routeA0_beam_span / 2, ...
                         M_old_A0 + 1);
A0_beam_matrix = diag(win_old) * exp( ...
    j * 2 * pi * position_full / lambda * sin(angle_recv_A0 * pi / 180));

theta_a = theta_c - theta_sep / 2;
theta_b = theta_c + theta_sep / 2;
target_theta = [theta_a, theta_b];
RecvbeamC = mean(target_theta);
theta_search_A0 = theta_sep;
A0_left = RecvbeamC - theta_search_A0 / 2;
A0_right = RecvbeamC + theta_search_A0 / 2;

nsnr = numel(snr_list);
raw_success_count = zeros(1, nsnr);
tol_success_count = zeros(1, nsnr);
rmse_sum_sqerr = zeros(1, nsnr);
rmse_valid_count = zeros(1, nsnr);
boundary_like_hit_count = zeros(1, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Route A0 SNR sweep, constrained boundary-prior route');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, tol_deg=%.3f', mat2str(snr_list), Metkl, tol_deg);
log_lines = append_log(log_lines, 'T_snap=%d, theta_sep=%.4f, theta_a=%.4f, theta_b=%.4f', ...
    T_snap, theta_sep, theta_a, theta_b);
log_lines = append_log(log_lines, 'Route A0 internal settings:');
log_lines = append_log(log_lines, 'routeA0_beam_span=%.4f, M_old_A0=%d, theta_search_A0=%.4f', ...
    routeA0_beam_span, M_old_A0, theta_search_A0);
log_lines = append_log(log_lines, '');

for iSNR = 1:nsnr
    snr = snr_list(iSNR);

    for metkl_num = 1:Metkl
        s1 = exp(j * 2 * pi * fc * t);
        s2 = exp(j * 2 * pi * fc * t);

        A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
        A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);

        s11 = A_a.' * s1;
        s21 = A_b.' * s2;
        y_clean = s11 + s21;

        noise_power = mean(abs(y_clean(:)).^2) / 10^(snr / 10);
        noise = sqrt(noise_power / 2) * ...
            (randn(size(y_clean)) + j * randn(size(y_clean)));

        y = y_clean + noise;

        sr_DBF_A0 = A0_beam_matrix.' * y;
        doa_A0 = DOA_three_music_hecheng_fangzhen( ...
            sr_DBF_A0, array_num, A0_beam_matrix, RecvbeamC, theta_search_A0);

        edge_tol = 1e-9;
        boundary_like_hit = all(isfinite(doa_A0)) && ...
            (any(abs(doa_A0 - A0_left) < edge_tol) || ...
             any(abs(doa_A0 - A0_right) < edge_tol));
        if boundary_like_hit
            boundary_like_hit_count(iSNR) = boundary_like_hit_count(iSNR) + 1;
        end

        raw_ok = all(isfinite(doa_A0));
        tol_ok = is_valid_doa_success(doa_A0, target_theta, tol_deg);

        if raw_ok
            raw_success_count(iSNR) = raw_success_count(iSNR) + 1;
            sqerr = sum((sort(doa_A0(:).') - sort(target_theta(:).')).^2);
            rmse_sum_sqerr(iSNR) = rmse_sum_sqerr(iSNR) + sqerr;
            rmse_valid_count(iSNR) = rmse_valid_count(iSNR) + 1;
        end

        if tol_ok
            tol_success_count(iSNR) = tol_success_count(iSNR) + 1;
        end
    end

    current_rmse = NaN;
    if rmse_valid_count(iSNR) > 0
        current_rmse = sqrt(rmse_sum_sqerr(iSNR) / (2 * rmse_valid_count(iSNR)));
    end

    boundary_like_rate = boundary_like_hit_count(iSNR) / Metkl;
    log_lines = append_log(log_lines, ...
        'SNR=%d dB | raw=%d tol=%d RMSE=%.4f boundary_like=%.2f', ...
        snr, raw_success_count(iSNR), tol_success_count(iSNR), current_rmse, boundary_like_rate);
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(1, nsnr);
valid_mask = rmse_valid_count > 0;
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ (2 * rmse_valid_count(valid_mask)));
boundary_like_hit_rate = boundary_like_hit_count / Metkl;

fig1 = figure('Name', 'Route A0 tol success vs SNR', 'NumberTitle', 'off');
plot(snr_list, tol_success_rate, '-o', 'LineWidth', 1.2);
grid on;
xlabel('SNR (dB)');
ylabel('tol success rate');
title(sprintf('Route A0 SNR sweep, constrained boundary-prior route: tol success, T_{snap}=%d, \\theta_{sep}=%.4f', ...
    T_snap, theta_sep));

fig2 = figure('Name', 'Route A0 RMSE vs SNR', 'NumberTitle', 'off');
plot(snr_list, rmse, '-o', 'LineWidth', 1.2);
grid on;
xlabel('SNR (dB)');
ylabel('RMSE (deg)');
title(sprintf('Route A0 SNR sweep, constrained boundary-prior route: RMSE, T_{snap}=%d, \\theta_{sep}=%.4f', ...
    T_snap, theta_sep));

fig3 = figure('Name', 'Route A0 raw success and boundary hit vs SNR', 'NumberTitle', 'off');
plot(snr_list, raw_success_rate, '-o', 'LineWidth', 1.2);
hold on;
plot(snr_list, boundary_like_hit_rate, '-s', 'LineWidth', 1.2);
hold off;
grid on;
xlabel('SNR (dB)');
ylabel('rate');
title(sprintf('Route A0 SNR sweep, constrained boundary-prior route: raw success / boundary hit, T_{snap}=%d, \\theta_{sep}=%.4f', ...
    T_snap, theta_sep));
legend({'raw success', 'boundary-like hit'}, 'Location', 'best');

function log_lines = append_log(log_lines, fmt, varargin)
line = sprintf(fmt, varargin{:});
fprintf('%s\n', line);
log_lines{end+1, 1} = line;
end
