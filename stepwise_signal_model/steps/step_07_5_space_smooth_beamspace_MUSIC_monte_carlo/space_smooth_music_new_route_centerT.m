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
theta_sep = bw_64 / 1;   % 绗竴杞厛鐢ㄨ緝绋抽棿闅?
% theta_sep = bw_64 / 2; % 绗簩杞啀娴嬭瘯涓ゅ€嶈秴鍒嗚鲸
tol_deg = 0.1;

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;

if K_fbss >= array_num
    error('K_fbss must be smaller than array_num.');
end
if K_fbss <= 2
    error('K_fbss must be larger than the source count.');
end
if (array_num - K_fbss + 1) < 2
    error('The number of overlapped subarrays is too small.');
end
if center_beam_count <= 2
    error('center_beam_count must be larger than the source count.');
end
if center_beam_count > (M_full + 1)
    error('center_beam_count must not exceed M_full + 1.');
end

j = sqrt(-1);
t = linspace(0, 1, T_snap);
theta_a = theta_c - theta_sep / 2;
theta_b = theta_c + theta_sep / 2;
target_theta = [theta_a, theta_b];
RecvbeamC = mean(target_theta);
theta_search_B = search_scale_B * theta_sep;
routeB_beam_span = 1.5 * theta_search_B;
beam_grid_full_deg = linspace(RecvbeamC - routeB_beam_span / 2, ...
                              RecvbeamC + routeB_beam_span / 2, ...
                              M_full + 1);

nsnr = numel(snr_list);
raw_success_count = zeros(1, nsnr);
tol_success_count = zeros(1, nsnr);
rmse_sum_sqerr = zeros(1, nsnr);
rmse_valid_count = zeros(1, nsnr);
sum_num_peaks = zeros(1, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 07.5 Route B SNR sweep');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, tol_deg=%.3f', mat2str(snr_list), Metkl, tol_deg);
log_lines = append_log(log_lines, 'T_snap=%d, theta_sep=%.4f, theta_a=%.4f, theta_b=%.4f', ...
    T_snap, theta_sep, theta_a, theta_b);
log_lines = append_log(log_lines, 'Route B internal settings:');
log_lines = append_log(log_lines, 'K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, '');

for iSNR = 1:nsnr
    snr = snr_list(iSNR);
    log_lines = append_log(log_lines, '=== SNR = %.1f dB ===', snr);

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

        [doa_B, debug_B] = DOA_three_music_new_route_centerT( ...
            y, ...
            K_fbss, ...
            beam_grid_full_deg, ...
            center_beam_count, ...
            RecvbeamC, ...
            theta_search_B, ...
            'Lc', 2, ...
            'GridStepDeg', 0.01, ...
            'UseQR', true);

        sum_num_peaks(iSNR) = sum_num_peaks(iSNR) + debug_B.num_peaks;

        raw_ok = all(isfinite(doa_B));
        tol_ok = is_valid_doa_success(doa_B, target_theta, tol_deg);

        if raw_ok
            raw_success_count(iSNR) = raw_success_count(iSNR) + 1;
            sqerr = sum((sort(doa_B(:).') - sort(target_theta(:).')).^2);
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

    mean_num_peaks_now = sum_num_peaks(iSNR) / Metkl;
    log_lines = append_log(log_lines, ...
        'SNR=%.1f | raw=%d tol=%d RMSE=%.4f mean_num_peaks=%.2f', ...
        snr, raw_success_count(iSNR), tol_success_count(iSNR), current_rmse, mean_num_peaks_now);
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(1, nsnr);
valid_mask = rmse_valid_count > 0;
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ (2 * rmse_valid_count(valid_mask)));
mean_num_peaks = sum_num_peaks / Metkl;

figure('Name', 'Route B tol success vs SNR', 'NumberTitle', 'off');
plot(snr_list, tol_success_rate, '-o', 'LineWidth', 1.2);
grid on;
xlabel('SNR (dB)');
ylabel('tol success rate');
title(sprintf('Route B tol success, T_{snap}=%d, \\theta_{sep}=%.4f', T_snap, theta_sep));

figure('Name', 'Route B RMSE vs SNR', 'NumberTitle', 'off');
plot(snr_list, rmse, '-o', 'LineWidth', 1.2);
grid on;
xlabel('SNR (dB)');
ylabel('RMSE (deg)');
title(sprintf('Route B RMSE, T_{snap}=%d, \\theta_{sep}=%.4f', T_snap, theta_sep));

figure('Name', 'Route B raw success and peak count vs SNR', 'NumberTitle', 'off');
plot(snr_list, raw_success_rate, '-o', 'LineWidth', 1.2);
hold on;
plot(snr_list, mean_num_peaks, '-s', 'LineWidth', 1.2);
hold off;
grid on;
xlabel('SNR (dB)');
ylabel('value');
title(sprintf('Route B raw success / mean peak count, T_{snap}=%d, \\theta_{sep}=%.4f', T_snap, theta_sep));
legend({'raw success', 'mean num peaks'}, 'Location', 'best');

function log_lines = append_log(log_lines, fmt, varargin)
line = sprintf(fmt, varargin{:});
fprintf('%s\n', line);
log_lines{end+1, 1} = line;
end
