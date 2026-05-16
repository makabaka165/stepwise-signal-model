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
snr_list = 30;
Metkl = 20;
T_snap = 260;
theta_sep = bw_64 / 1;
tol_deg = 0.1;

search_scale_A1 = 4;
qSmoothRatio_list = [0.02, 0.05, 0.10, 0.20];
spectrum_mode_list = {'center', 'manifold'};

j = sqrt(-1);
t = linspace(0, 1, T_snap);
position_full = d * (0:array_num-1).';
win_old = taylorwin(array_num, 25, -40)';
win_old = win_old / sqrt(win_old * win_old');

theta_a = theta_c - theta_sep / 2;
theta_b = theta_c + theta_sep / 2;
target_theta = [theta_a, theta_b];
RecvbeamC = mean(target_theta);
theta_search_A1 = search_scale_A1 * theta_sep;

routeA1_beam_span = search_scale_A1 * bw_64;
M_old_A1 = round(search_scale_A1 * 50);
angle_recv_A1 = linspace(theta_c - routeA1_beam_span / 2, ...
                         theta_c + routeA1_beam_span / 2, ...
                         M_old_A1 + 1);
A1_beam_matrix = diag(win_old) * exp( ...
    j * 2 * pi * position_full / lambda * sin(angle_recv_A1 * pi / 180));

nsnr = numel(snr_list);
nq = numel(qSmoothRatio_list);
nmode = numel(spectrum_mode_list);

raw_success_count = zeros(nmode, nq, nsnr);
tol_success_count = zeros(nmode, nq, nsnr);
rmse_sum_sqerr = zeros(nmode, nq, nsnr);
rmse_valid_count = zeros(nmode, nq, nsnr);
edge_hit_count = zeros(nmode, nq, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 07.5 Route A1 parameter sweep');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, tol_deg=%.3f', mat2str(snr_list), Metkl, tol_deg);
log_lines = append_log(log_lines, 'T_snap=%d, theta_sep=%.4f, theta_a=%.4f, theta_b=%.4f', ...
    T_snap, theta_sep, theta_a, theta_b);
log_lines = append_log(log_lines, 'Route A1 internal settings:');
log_lines = append_log(log_lines, 'search_scale_A1=%.2f, M_old_A1=%d', search_scale_A1, M_old_A1);
log_lines = append_log(log_lines, 'qSmoothRatio_list=%s', mat2str(qSmoothRatio_list));
log_lines = append_log(log_lines, 'spectrum_mode_list=%s', strjoin(spectrum_mode_list, ', '));
log_lines = append_log(log_lines, '');

for iMode = 1:nmode
    spectrum_mode = spectrum_mode_list{iMode};
    log_lines = append_log(log_lines, '=== SpectrumMode = %s ===', spectrum_mode);

    for iQ = 1:nq
        qSmoothRatio_A1 = qSmoothRatio_list(iQ);
        log_lines = append_log(log_lines, '-- qSmoothRatio_A1 = %.2f --', qSmoothRatio_A1);

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

                sr_DBF_A1 = A1_beam_matrix.' * y;
                [doa_A1, debug_A1] = DOA_three_music_hecheng_fangzhen_eval( ...
                    sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, ...
                    'Lc', 2, ...
                    'QSmoothRatio', qSmoothRatio_A1, ...
                    'TargetTheta', target_theta, ...
                    'SpectrumMode', spectrum_mode);

                if debug_A1.edge_hit
                    edge_hit_count(iMode, iQ, iSNR) = edge_hit_count(iMode, iQ, iSNR) + 1;
                end

                raw_ok = all(isfinite(doa_A1));
                tol_ok = is_valid_doa_success(doa_A1, target_theta, tol_deg);

                if raw_ok
                    raw_success_count(iMode, iQ, iSNR) = raw_success_count(iMode, iQ, iSNR) + 1;
                    sqerr = sum((sort(doa_A1(:).') - sort(target_theta(:).')).^2);
                    rmse_sum_sqerr(iMode, iQ, iSNR) = rmse_sum_sqerr(iMode, iQ, iSNR) + sqerr;
                    rmse_valid_count(iMode, iQ, iSNR) = rmse_valid_count(iMode, iQ, iSNR) + 1;
                end

                if tol_ok
                    tol_success_count(iMode, iQ, iSNR) = tol_success_count(iMode, iQ, iSNR) + 1;
                end
            end

            current_rmse = NaN;
            if rmse_valid_count(iMode, iQ, iSNR) > 0
                current_rmse = sqrt(rmse_sum_sqerr(iMode, iQ, iSNR) / ...
                    (2 * rmse_valid_count(iMode, iQ, iSNR)));
            end

            edge_hit_rate = edge_hit_count(iMode, iQ, iSNR) / Metkl;
            log_lines = append_log(log_lines, ...
                'SNR=%.1f | raw=%d tol=%d RMSE=%.4f edge_hit=%.2f', ...
                snr, raw_success_count(iMode, iQ, iSNR), ...
                tol_success_count(iMode, iQ, iSNR), current_rmse, edge_hit_rate);
        end

        log_lines = append_log(log_lines, '');
    end
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(nmode, nq, nsnr);
valid_mask = rmse_valid_count > 0;
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ (2 * rmse_valid_count(valid_mask)));
edge_hit_rate = edge_hit_count / Metkl;

output_dir = fileparts(mfilename('fullpath'));
fid = fopen(fullfile(output_dir, [mfilename, '.log']), 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

figure('Name', 'Route A1 tol success parameter sweep', 'NumberTitle', 'off');
for iMode = 1:nmode
    subplot(nmode, 1, iMode);
    bar(qSmoothRatio_list, squeeze(tol_success_rate(iMode, :, 1)));
    grid on;
    xlabel('qSmoothRatio');
    ylabel('tol success rate');
    title(sprintf('Route A1 tol success, SpectrumMode=%s, SNR=%.1f dB', ...
        spectrum_mode_list{iMode}, snr_list(1)));
end

figure('Name', 'Route A1 RMSE parameter sweep', 'NumberTitle', 'off');
for iMode = 1:nmode
    subplot(nmode, 1, iMode);
    bar(qSmoothRatio_list, squeeze(rmse(iMode, :, 1)));
    grid on;
    xlabel('qSmoothRatio');
    ylabel('RMSE (deg)');
    title(sprintf('Route A1 RMSE, SpectrumMode=%s, SNR=%.1f dB', ...
        spectrum_mode_list{iMode}, snr_list(1)));
end

figure('Name', 'Route A1 raw success and edge hit parameter sweep', 'NumberTitle', 'off');
for iMode = 1:nmode
    subplot(nmode, 1, iMode);
    plot(qSmoothRatio_list, squeeze(raw_success_rate(iMode, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(qSmoothRatio_list, squeeze(edge_hit_rate(iMode, :, 1)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xlabel('qSmoothRatio');
    ylabel('rate');
    title(sprintf('Route A1 raw success / edge hit, SpectrumMode=%s, SNR=%.1f dB', ...
        spectrum_mode_list{iMode}, snr_list(1)));
    legend({'raw success', 'edge hit'}, 'Location', 'best');
end

function log_lines = append_log(log_lines, fmt, varargin)
line = sprintf(fmt, varargin{:});
fprintf('%s\n', line);
log_lines{end+1, 1} = line;
end
