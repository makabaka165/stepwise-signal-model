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
snr_list = -4:2:30;
Metkl = 200;
T_snap = 260;
tol_deg = 0.1;
sep_factor_list = 1:10;

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;

j = sqrt(-1);
t = linspace(0, 1, T_snap);

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nsep, nsnr);
tol_success_count = zeros(nsep, nsnr);
rmse_sum_sqerr = zeros(nsep, nsnr);
rmse_valid_count = zeros(nsep, nsnr);
sum_num_peaks = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);

log_lines = {};
log_lines = append_log(log_lines, 'Step 7.5 Route B full SNR resolution-limit scan');
log_lines = append_log(log_lines, 'Route B only: element-domain covariance -> element-domain FBSS -> centerT beamspace -> 1D MUSIC.');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B internal settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, '');

for iSep = 1:nsep
    sep_factor = sep_factor_list(iSep);
    theta_sep = bw_64 / sep_factor;
    theta_a = theta_c - theta_sep / 2;
    theta_b = theta_c + theta_sep / 2;
    target_theta = [theta_a, theta_b];
    RecvbeamC = mean(target_theta);

    theta_search_B = search_scale_B * theta_sep;
    routeB_beam_span = 1.5 * theta_search_B;
    beam_grid_full_deg = linspace( ...
        RecvbeamC - routeB_beam_span / 2, ...
        RecvbeamC + routeB_beam_span / 2, ...
        M_full + 1);

    % 中心截取 + QR 构造 centerT 投影矩阵（与 theta_sep 相关，故按 sep_factor 重算）
    full_beam_count = numel(beam_grid_full_deg);
    center_idx = floor((full_beam_count + 1) / 2);
    half_left = floor((center_beam_count - 1) / 2);
    half_right = center_beam_count - half_left - 1;
    center_indices = (center_idx - half_left):(center_idx + half_right);
    beam_grid_center_deg = beam_grid_full_deg(center_indices);

    posK = d * (0:K_fbss-1).';
    Wcenter = exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg));
    [Tk, ~] = qr(Wcenter, 0);

    theta_sep_deg(iSep) = theta_sep;
    theta_a_deg(iSep) = theta_a;
    theta_b_deg(iSep) = theta_b;

    log_lines = append_log(log_lines, '=== sep_factor = %d, theta_sep = %.4f deg ===', sep_factor, theta_sep);

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

            [doa_B, num_peaks_B] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk, RecvbeamC, theta_search_B);

            raw_ok = all(isfinite(doa_B));
            tol_ok = is_valid_doa_success(doa_B, target_theta, tol_deg);

            if raw_ok
                raw_success_count(iSep, iSNR) = raw_success_count(iSep, iSNR) + 1;
                sqerr = sum((sort(doa_B(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(iSep, iSNR) = rmse_sum_sqerr(iSep, iSNR) + sqerr;
                rmse_valid_count(iSep, iSNR) = rmse_valid_count(iSep, iSNR) + 1;
            end

            if tol_ok
                tol_success_count(iSep, iSNR) = tol_success_count(iSep, iSNR) + 1;
            end

            sum_num_peaks(iSep, iSNR) = sum_num_peaks(iSep, iSNR) + num_peaks_B;
        end

        current_rmse = NaN;
        if rmse_valid_count(iSep, iSNR) > 0
            current_rmse = sqrt(rmse_sum_sqerr(iSep, iSNR) / (2 * rmse_valid_count(iSep, iSNR)));
        end

        raw_rate = raw_success_count(iSep, iSNR) / Metkl;
        tol_rate = tol_success_count(iSep, iSNR) / Metkl;
        mean_num_peaks_now = sum_num_peaks(iSep, iSNR) / Metkl;

        log_lines = append_log(log_lines, ...
            'SNR=%d dB | raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(iSep, iSNR), tol_success_count(iSep, iSNR), ...
            raw_rate, tol_rate, current_rmse, mean_num_peaks_now);
    end

    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;

rmse = nan(nsep, nsnr);
valid_mask = rmse_valid_count > 0;
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ ...
    (2 * rmse_valid_count(valid_mask)));

snr90 = nan(nsep, 1);
for iSep = 1:nsep
    idx = find(tol_success_rate(iSep, :) >= 0.9, 1, 'first');
    if ~isempty(idx)
        snr90(iSep) = snr_list(idx);
    else
        log_lines = append_log(log_lines, ...
            'sep_factor = %d did not reach 90%% tol success within tested SNR range.', ...
            sep_factor_list(iSep));
    end
end

params = struct();
params.rng_seed = 20260515;
params.array_num = array_num;
params.fc = fc;
params.lambda = lambda;
params.d = d;
params.bw_64 = bw_64;
params.theta_c = theta_c;
params.snr_list = snr_list;
params.Metkl = Metkl;
params.T_snap = T_snap;
params.tol_deg = tol_deg;
params.sep_factor_list = sep_factor_list;
params.search_scale_B = search_scale_B;
params.K_fbss = K_fbss;
params.M_full = M_full;
params.center_beam_count = center_beam_count;
params.fullscan_note = 'Step 7.5 full bw/1~bw/10 SNR resolution-limit scan for Route B.';

result_dir = fullfile(fileparts(mfilename('fullpath')), 'results_step7_5_routeB_fullscan_bw1_to_bw10');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step7_5_routeB_fullscan.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step7_5_routeB_fullscan_summary.csv');
fid = fopen(csv_path, 'w');
if fid < 0
    error('Failed to open csv file.');
end
fprintf(fid, 'sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,raw_success_count,tol_success_count,raw_success_rate,tol_success_rate,rmse_deg,rmse_valid_count,mean_num_peaks,snr90_db\n');
for iSep = 1:nsep
    for iSNR = 1:nsnr
        fprintf(fid, '%d,%.6f,%.6f,%.6f,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f\n', ...
            sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
            snr_list(iSNR), raw_success_count(iSep, iSNR), tol_success_count(iSep, iSNR), ...
            raw_success_rate(iSep, iSNR), tol_success_rate(iSep, iSNR), rmse(iSep, iSNR), ...
            rmse_valid_count(iSep, iSNR), mean_num_peaks(iSep, iSNR), snr90(iSep));
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step7_5_routeB_fullscan_result.mat');
save(mat_path, ...
    'params', ...
    'sep_factor_list', ...
    'snr_list', ...
    'theta_sep_deg', ...
    'theta_a_deg', ...
    'theta_b_deg', ...
    'raw_success_count', ...
    'tol_success_count', ...
    'raw_success_rate', ...
    'tol_success_rate', ...
    'rmse_sum_sqerr', ...
    'rmse_valid_count', ...
    'rmse', ...
    'sum_num_peaks', ...
    'mean_num_peaks', ...
    'snr90');

legend_labels = arrayfun(@(k) sprintf('bw/%d', k), sep_factor_list, 'UniformOutput', false);

fig1 = figure('Visible', 'off');
hold on
for iSep = 1:nsep
    plot(snr_list, tol_success_rate(iSep, :), '-o', 'LineWidth', 1.2);
end
hold off
grid on
xlabel('SNR (dB)');
ylabel('tol success rate');
title('Step 7.5 Route B fullscan: tol success rate vs SNR');
legend(legend_labels, 'Location', 'eastoutside');
saveas(fig1, fullfile(result_dir, 'step7_5_routeB_fullscan_tol_success.png'));
close(fig1)

fig2 = figure('Visible', 'off');
hold on
for iSep = 1:nsep
    plot(snr_list, rmse(iSep, :), '-o', 'LineWidth', 1.2);
end
hold off
grid on
xlabel('SNR (dB)');
ylabel('RMSE (deg)');
title('Step 7.5 Route B fullscan: RMSE vs SNR');
legend(legend_labels, 'Location', 'eastoutside');
saveas(fig2, fullfile(result_dir, 'step7_5_routeB_fullscan_rmse.png'));
close(fig2)

fig3 = figure('Visible', 'off');
plot(1:nsep, snr90, '-o', 'LineWidth', 1.2);
grid on
xticks(1:nsep)
xticklabels(legend_labels)
xlabel('target separation')
ylabel('SNR required for 90% tol success');
title('Step 7.5 Route B fullscan: SNR threshold for 90% tol success');
saveas(fig3, fullfile(result_dir, 'step7_5_routeB_fullscan_snr90.png'));
close(fig3)

fig4 = figure('Visible', 'off');
hold on
for iSep = 1:nsep
    plot(snr_list, raw_success_rate(iSep, :), '-o', 'LineWidth', 1.2);
end
hold off
grid on
xlabel('SNR (dB)');
ylabel('raw success rate');
title('Step 7.5 Route B fullscan: raw success rate vs SNR');
legend(legend_labels, 'Location', 'eastoutside');
saveas(fig4, fullfile(result_dir, 'step7_5_routeB_fullscan_raw_success.png'));
close(fig4)

fig5 = figure('Visible', 'off');
hold on
for iSep = 1:nsep
    plot(snr_list, mean_num_peaks(iSep, :), '-o', 'LineWidth', 1.2);
end
hold off
grid on
xlabel('SNR (dB)');
ylabel('mean num peaks');
title('Step 7.5 Route B fullscan: mean number of peaks vs SNR');
legend(legend_labels, 'Location', 'eastoutside');
saveas(fig5, fullfile(result_dir, 'step7_5_routeB_fullscan_mean_num_peaks.png'));
close(fig5)

disp('Summary arrays:');
disp('sep_factor_list =');
disp(sep_factor_list);
disp('snr_list =');
disp(snr_list);
disp('snr90 =');
disp(snr90);
disp('result_dir =');
disp(result_dir);

function log_lines = append_log(log_lines, fmt, varargin)
line = sprintf(fmt, varargin{:});
fprintf('%s\n', line);
log_lines{end+1, 1} = line;
end
