clc
clear
close all

rng(20260515, 'twister');

script_dir = fileparts(mfilename('fullpath'));
step75_dir = fullfile(fileparts(script_dir), 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');
addpath(step75_dir);

c = 3e8;
array_num = 64;
fc = 2.7e9;
lambda = c / fc;
d = 0.047;

bw_64 = 50.8 * 1.45 * lambda / (array_num - 1) / d;
bw_64 = roundn(bw_64, -1);

theta_c = 13;
snr_list = 14:2:28;
Metkl = 200;
T_snap = 260;
tol_deg = 0.1;
sep_factor_list = [8, 9, 10];

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
Nfft_spatial = 4096;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
posK = d * (0:K_fbss-1).';

route_names = {'baseline_true_centerT', 'fft_guided_centerT'};
nroutes = numel(route_names);

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count = zeros(nroutes, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nsep, nsnr);
sum_num_peaks = zeros(nroutes, nsep, nsnr);

fft_center_error_sum = zeros(nsep, nsnr);
fft_center_error_sumsq = zeros(nsep, nsnr);
fft_center_error_count = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Route B FFT-guided centerT prototype 4');
log_lines = append_log(log_lines, 'Prototype scope: replace true center with FFT coarse center while keeping Route B FBSS + centerT + 1D MUSIC unchanged.');
log_lines = append_log(log_lines, 'Route comparison: baseline_true_centerT vs fft_guided_centerT.');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B internal settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, 'FFT settings: Nfft_spatial=%d, FFT input = mean(y,2), center pick = max spatial FFT bin.', ...
    Nfft_spatial);
log_lines = append_log(log_lines, '');

for iSep = 1:nsep
    sep_factor = sep_factor_list(iSep);
    theta_sep = bw_64 / sep_factor;
    theta_a = theta_c - theta_sep / 2;
    theta_b = theta_c + theta_sep / 2;
    target_theta = [theta_a, theta_b];
    RecvbeamC_true = mean(target_theta);

    theta_search_B = search_scale_B * theta_sep;
    routeB_beam_span = 1.5 * theta_search_B;

    [beam_grid_full_true, beam_grid_center_true, Tk_true] = build_centerT_from_center( ...
        RecvbeamC_true, theta_search_B, routeB_beam_span, M_full, center_beam_count, posK, lambda);

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

            y_mean = mean(y, 2);
            [RecvbeamC_fft, theta_grid_valid, Pfft_valid, peak_idx] = ...
                calc_spatial_fft_center(y, lambda, d, Nfft_spatial);
            fft_center_error_deg = RecvbeamC_fft - RecvbeamC_true;

            fft_center_error_sum(iSep, iSNR) = fft_center_error_sum(iSep, iSNR) + fft_center_error_deg;
            fft_center_error_sumsq(iSep, iSNR) = fft_center_error_sumsq(iSep, iSNR) + fft_center_error_deg^2;
            fft_center_error_count(iSep, iSNR) = fft_center_error_count(iSep, iSNR) + 1;

            [~, beam_grid_center_fft, Tk_fft] = build_centerT_from_center( ...
                RecvbeamC_fft, theta_search_B, routeB_beam_span, M_full, center_beam_count, posK, lambda);

            [doa_true, num_peaks_true] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_true, RecvbeamC_true, theta_search_B);
            [doa_fft, num_peaks_fft] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft, RecvbeamC_fft, theta_search_B);

            raw_ok_true = all(isfinite(doa_true));
            tol_ok_true = is_valid_doa_success(doa_true, target_theta, tol_deg);
            if raw_ok_true
                raw_success_count(1, iSep, iSNR) = raw_success_count(1, iSep, iSNR) + 1;
                sqerr_true = sum((sort(doa_true(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(1, iSep, iSNR) = rmse_sum_sqerr(1, iSep, iSNR) + sqerr_true;
                rmse_valid_count(1, iSep, iSNR) = rmse_valid_count(1, iSep, iSNR) + 1;
            end
            if tol_ok_true
                tol_success_count(1, iSep, iSNR) = tol_success_count(1, iSep, iSNR) + 1;
            end
            sum_num_peaks(1, iSep, iSNR) = sum_num_peaks(1, iSep, iSNR) + num_peaks_true;

            raw_ok_fft = all(isfinite(doa_fft));
            tol_ok_fft = is_valid_doa_success(doa_fft, target_theta, tol_deg);
            if raw_ok_fft
                raw_success_count(2, iSep, iSNR) = raw_success_count(2, iSep, iSNR) + 1;
                sqerr_fft = sum((sort(doa_fft(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(2, iSep, iSNR) = rmse_sum_sqerr(2, iSep, iSNR) + sqerr_fft;
                rmse_valid_count(2, iSep, iSNR) = rmse_valid_count(2, iSep, iSNR) + 1;
            end
            if tol_ok_fft
                tol_success_count(2, iSep, iSNR) = tol_success_count(2, iSep, iSNR) + 1;
            end
            sum_num_peaks(2, iSep, iSNR) = sum_num_peaks(2, iSep, iSNR) + num_peaks_fft;

            if metkl_num == 1
                sample = struct();
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr;
                sample.target_theta = target_theta;
                sample.theta_search_B = theta_search_B;
                sample.routeB_beam_span = routeB_beam_span;
                sample.y_mean = y_mean;
                sample.RecvbeamC_true = RecvbeamC_true;
                sample.RecvbeamC_fft = RecvbeamC_fft;
                sample.fft_center_error_deg = fft_center_error_deg;
                sample.theta_grid_valid = theta_grid_valid;
                sample.Pfft_valid = Pfft_valid;
                sample.peak_idx = peak_idx;
                sample.beam_grid_full_true = beam_grid_full_true;
                sample.beam_grid_center_true = beam_grid_center_true;
                sample.beam_grid_center_fft = beam_grid_center_fft;
                sample.doa_true = doa_true;
                sample.doa_fft = doa_fft;
                sample.num_peaks_true = num_peaks_true;
                sample.num_peaks_fft = num_peaks_fft;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        current_rmse_true = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 1, iSep, iSNR);
        current_rmse_fft = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 2, iSep, iSNR);

        raw_rate_true = raw_success_count(1, iSep, iSNR) / Metkl;
        raw_rate_fft = raw_success_count(2, iSep, iSNR) / Metkl;
        tol_rate_true = tol_success_count(1, iSep, iSNR) / Metkl;
        tol_rate_fft = tol_success_count(2, iSep, iSNR) / Metkl;
        mean_num_peaks_true = sum_num_peaks(1, iSep, iSNR) / Metkl;
        mean_num_peaks_fft = sum_num_peaks(2, iSep, iSNR) / Metkl;
        mean_fft_center_error = fft_center_error_sum(iSep, iSNR) / fft_center_error_count(iSep, iSNR);
        var_fft_center_error = fft_center_error_sumsq(iSep, iSNR) / fft_center_error_count(iSep, iSNR) - ...
            mean_fft_center_error^2;
        std_fft_center_error = sqrt(max(var_fft_center_error, 0));

        sample = debug_samples{iSep, iSNR};
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | baseline raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(1, iSep, iSNR), tol_success_count(1, iSep, iSNR), ...
            raw_rate_true, tol_rate_true, current_rmse_true, mean_num_peaks_true);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | fft-guided raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f mean_fft_center_err=%.4f std_fft_center_err=%.4f', ...
            snr, raw_success_count(2, iSep, iSNR), tol_success_count(2, iSep, iSNR), ...
            raw_rate_fft, tol_rate_fft, current_rmse_fft, mean_num_peaks_fft, ...
            mean_fft_center_error, std_fft_center_error);
        log_lines = append_log(log_lines, ...
            'sample metkl=1 | center_true=%.4f center_fft=%.4f center_err=%.4f doa_true=%s doa_fft=%s peaks_true=%d peaks_fft=%d', ...
            sample.RecvbeamC_true, sample.RecvbeamC_fft, sample.fft_center_error_deg, ...
            mat2str(sample.doa_true, 4), mat2str(sample.doa_fft, 4), ...
            sample.num_peaks_true, sample.num_peaks_fft);
    end

    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;

mean_fft_center_error_deg = fft_center_error_sum ./ max(fft_center_error_count, 1);
var_fft_center_error_deg = fft_center_error_sumsq ./ max(fft_center_error_count, 1) - ...
    mean_fft_center_error_deg.^2;
std_fft_center_error_deg = sqrt(max(var_fft_center_error_deg, 0));

rmse = nan(nroutes, nsep, nsnr);
valid_mask = rmse_valid_count > 0;
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ ...
    (2 * rmse_valid_count(valid_mask)));

snr90 = nan(nroutes, nsep);
for iroute = 1:nroutes
    for iSep = 1:nsep
        idx = find(squeeze(tol_success_rate(iroute, iSep, :)) >= 0.9, 1, 'first');
        if ~isempty(idx)
            snr90(iroute, iSep) = snr_list(idx);
        end
    end
end

for iSep = 1:nsep
    log_lines = append_log(log_lines, ...
        'SNR90 summary | bw/%d baseline=%s fft-guided=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90(1, iSep)), fmt_snr90(snr90(2, iSep)));
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
params.Nfft_spatial = Nfft_spatial;
params.prototype_note = 'Prototype 4: Route B baseline with FFT-guided data-driven center replacement.';

result_dir = fullfile(script_dir, 'results_step8_routeB_fft_guided_centerT_proto4');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_fft_guided_centerT_proto4.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_fft_guided_centerT_proto4_summary.csv');
fid = fopen(csv_path, 'w');
if fid < 0
    error('Failed to open csv file.');
end
fprintf(fid, 'route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,raw_success_count,tol_success_count,raw_success_rate,tol_success_rate,rmse_deg,rmse_valid_count,mean_num_peaks,snr90_db,mean_fft_center_error_deg,std_fft_center_error_deg\n');
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, '%s,%d,%.6f,%.6f,%.6f,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f\n', ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), ...
                theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), ...
                raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                raw_success_rate(iroute, iSep, iSNR), tol_success_rate(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), ...
                mean_num_peaks(iroute, iSep, iSNR), snr90(iroute, iSep), ...
                mean_fft_center_error_deg(iSep, iSNR), std_fft_center_error_deg(iSep, iSNR));
        end
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step8_routeB_fft_guided_centerT_proto4_result.mat');
save(mat_path, ...
    'params', ...
    'route_names', ...
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
    'snr90', ...
    'fft_center_error_sum', ...
    'fft_center_error_sumsq', ...
    'fft_center_error_count', ...
    'mean_fft_center_error_deg', ...
    'std_fft_center_error_deg', ...
    'debug_samples');

fig1 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(tol_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(tol_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('tol success');
    title(sprintf('Prototype 4 tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_proto4_tol_success.png'));
close(fig1)

fig2 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(rmse(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(rmse(2, iSep, :)), '-s', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('RMSE (deg)');
    title(sprintf('Prototype 4 RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_proto4_rmse.png'));
close(fig2)

fig3 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(raw_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(raw_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('raw success');
    title(sprintf('Prototype 4 raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_proto4_raw_success.png'));
close(fig3)

fig4 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(mean_num_peaks(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(mean_num_peaks(2, iSep, :)), '-s', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('mean peaks');
    title(sprintf('Prototype 4 mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_proto4_mean_num_peaks.png'));
close(fig4)

disp('Prototype 4 finished.');
disp('route_names =');
disp(route_names);
disp('snr90 =');
disp(snr90);
disp('result_dir =');
disp(result_dir);

function [RecvbeamC_fft, theta_grid_valid, Pfft_valid, peak_idx] = calc_spatial_fft_center(y, lambda, d, Nfft_spatial)
    y_mean = mean(y, 2);
    Yfft = fftshift(fft(y_mean, Nfft_spatial));
    Pfft = abs(Yfft).^2;

    k = (-Nfft_spatial/2):(Nfft_spatial/2 - 1);
    mu = k / Nfft_spatial;
    sin_theta = -mu * lambda / d;
    valid_mask = abs(sin_theta) <= 1;

    theta_grid_valid = asind(sin_theta(valid_mask));
    Pfft_valid = Pfft(valid_mask);

    [~, peak_idx] = max(Pfft_valid);
    RecvbeamC_fft = theta_grid_valid(peak_idx);
end

function [beam_grid_full_deg, beam_grid_center_deg, Tk] = build_centerT_from_center( ...
    center_deg, theta_search_B, routeB_beam_span, M_full, center_beam_count, posK, lambda)
    j = sqrt(-1);

    beam_grid_full_deg = linspace( ...
        center_deg - routeB_beam_span / 2, ...
        center_deg + routeB_beam_span / 2, ...
        M_full + 1);

    full_beam_count = numel(beam_grid_full_deg);
    center_idx = floor((full_beam_count + 1) / 2);
    half_left = floor((center_beam_count - 1) / 2);
    half_right = center_beam_count - half_left - 1;
    center_indices = (center_idx - half_left):(center_idx + half_right);
    beam_grid_center_deg = beam_grid_full_deg(center_indices);

    Wcenter = exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg));
    [Tk, ~] = qr(Wcenter, 0);
end

function current_rmse = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, iroute, iSep, iSNR)
    current_rmse = NaN;
    if rmse_valid_count(iroute, iSep, iSNR) > 0
        current_rmse = sqrt( ...
            rmse_sum_sqerr(iroute, iSep, iSNR) / ...
            (2 * rmse_valid_count(iroute, iSep, iSNR)));
    end
end

function out = fmt_snr90(x)
    if isfinite(x)
        out = sprintf('%.0f dB', x);
    else
        out = 'NaN';
    end
end

function ok = is_valid_doa_success(doa_est, target_theta, tol_deg)
    if any(~isfinite(doa_est))
        ok = false;
        return;
    end

    doa_est = sort(doa_est(:).');
    target_theta = sort(target_theta(:).');

    if numel(doa_est) ~= numel(target_theta)
        ok = false;
        return;
    end

    err = abs(doa_est - target_theta);
    ok = all(err <= tol_deg);
end

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
