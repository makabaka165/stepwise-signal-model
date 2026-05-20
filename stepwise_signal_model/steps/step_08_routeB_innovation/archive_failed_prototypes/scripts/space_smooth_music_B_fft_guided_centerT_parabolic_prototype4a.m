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
sep_factor_list = [6, 7, 8, 9, 10];

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
Nfft_spatial = 4096;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
posK = d * (0:K_fbss-1).';

route_names = {'baseline_true_centerT', 'fft_guided_centerT', 'fft_guided_centerT_parabolic'};
nroutes = numel(route_names);

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count = zeros(nroutes, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nsep, nsnr);
sum_num_peaks = zeros(nroutes, nsep, nsnr);

fft_center_error_coarse_sum = zeros(nsep, nsnr);
fft_center_error_coarse_sumsq = zeros(nsep, nsnr);
fft_center_error_refined_sum = zeros(nsep, nsnr);
fft_center_error_refined_sumsq = zeros(nsep, nsnr);
fft_center_error_count = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Route B FFT-guided centerT parabolic prototype 4a');
log_lines = append_log(log_lines, 'Prototype scope: keep Route B unchanged, compare true center, coarse FFT center, and parabolic-refined FFT center.');
log_lines = append_log(log_lines, 'Route comparison: baseline_true_centerT vs fft_guided_centerT vs fft_guided_centerT_parabolic.');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B internal settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, 'FFT settings: Nfft_spatial=%d, FFT input = mean(y,2), center pick = max spatial FFT bin + optional 3-point parabolic refinement.', ...
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
        RecvbeamC_true, routeB_beam_span, M_full, center_beam_count, posK, lambda);

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
            [RecvbeamC_fft_coarse, theta_grid_valid, Pfft_valid, peak_idx] = ...
                calc_spatial_fft_center_coarse(y, lambda, d, Nfft_spatial);
            [RecvbeamC_fft_parabolic, delta_bin, used_parabolic] = ...
                refine_fft_center_parabolic(theta_grid_valid, Pfft_valid, peak_idx);

            fft_center_error_coarse_deg = RecvbeamC_fft_coarse - RecvbeamC_true;
            fft_center_error_refined_deg = RecvbeamC_fft_parabolic - RecvbeamC_true;

            fft_center_error_coarse_sum(iSep, iSNR) = fft_center_error_coarse_sum(iSep, iSNR) + fft_center_error_coarse_deg;
            fft_center_error_coarse_sumsq(iSep, iSNR) = fft_center_error_coarse_sumsq(iSep, iSNR) + fft_center_error_coarse_deg^2;
            fft_center_error_refined_sum(iSep, iSNR) = fft_center_error_refined_sum(iSep, iSNR) + fft_center_error_refined_deg;
            fft_center_error_refined_sumsq(iSep, iSNR) = fft_center_error_refined_sumsq(iSep, iSNR) + fft_center_error_refined_deg^2;
            fft_center_error_count(iSep, iSNR) = fft_center_error_count(iSep, iSNR) + 1;

            [~, beam_grid_center_fft, Tk_fft] = build_centerT_from_center( ...
                RecvbeamC_fft_coarse, routeB_beam_span, M_full, center_beam_count, posK, lambda);
            [~, beam_grid_center_para, Tk_para] = build_centerT_from_center( ...
                RecvbeamC_fft_parabolic, routeB_beam_span, M_full, center_beam_count, posK, lambda);

            [doa_true, num_peaks_true] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_true, RecvbeamC_true, theta_search_B);
            [doa_fft, num_peaks_fft] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft, RecvbeamC_fft_coarse, theta_search_B);
            [doa_para, num_peaks_para] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_para, RecvbeamC_fft_parabolic, theta_search_B);

            doa_all = {doa_true, doa_fft, doa_para};
            num_peaks_all = [num_peaks_true, num_peaks_fft, num_peaks_para];

            for iroute = 1:nroutes
                doa_now = doa_all{iroute};
                raw_ok = all(isfinite(doa_now));
                tol_ok = is_valid_doa_success(doa_now, target_theta, tol_deg);

                if raw_ok
                    raw_success_count(iroute, iSep, iSNR) = raw_success_count(iroute, iSep, iSNR) + 1;
                    sqerr = sum((sort(doa_now(:).') - sort(target_theta(:).')).^2);
                    rmse_sum_sqerr(iroute, iSep, iSNR) = rmse_sum_sqerr(iroute, iSep, iSNR) + sqerr;
                    rmse_valid_count(iroute, iSep, iSNR) = rmse_valid_count(iroute, iSep, iSNR) + 1;
                end

                if tol_ok
                    tol_success_count(iroute, iSep, iSNR) = tol_success_count(iroute, iSep, iSNR) + 1;
                end

                sum_num_peaks(iroute, iSep, iSNR) = sum_num_peaks(iroute, iSep, iSNR) + num_peaks_all(iroute);
            end

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
                sample.RecvbeamC_fft_coarse = RecvbeamC_fft_coarse;
                sample.RecvbeamC_fft_parabolic = RecvbeamC_fft_parabolic;
                sample.fft_center_error_coarse_deg = fft_center_error_coarse_deg;
                sample.fft_center_error_refined_deg = fft_center_error_refined_deg;
                sample.theta_grid_valid = theta_grid_valid;
                sample.Pfft_valid = Pfft_valid;
                sample.peak_idx = peak_idx;
                sample.delta_bin = delta_bin;
                sample.used_parabolic = used_parabolic;
                sample.beam_grid_full_true = beam_grid_full_true;
                sample.beam_grid_center_true = beam_grid_center_true;
                sample.beam_grid_center_fft = beam_grid_center_fft;
                sample.beam_grid_center_para = beam_grid_center_para;
                sample.doa_true = doa_true;
                sample.doa_fft = doa_fft;
                sample.doa_para = doa_para;
                sample.num_peaks_true = num_peaks_true;
                sample.num_peaks_fft = num_peaks_fft;
                sample.num_peaks_para = num_peaks_para;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        current_rmse_true = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 1, iSep, iSNR);
        current_rmse_fft = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 2, iSep, iSNR);
        current_rmse_para = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 3, iSep, iSNR);

        raw_rate_true = raw_success_count(1, iSep, iSNR) / Metkl;
        raw_rate_fft = raw_success_count(2, iSep, iSNR) / Metkl;
        raw_rate_para = raw_success_count(3, iSep, iSNR) / Metkl;
        tol_rate_true = tol_success_count(1, iSep, iSNR) / Metkl;
        tol_rate_fft = tol_success_count(2, iSep, iSNR) / Metkl;
        tol_rate_para = tol_success_count(3, iSep, iSNR) / Metkl;
        mean_num_peaks_true = sum_num_peaks(1, iSep, iSNR) / Metkl;
        mean_num_peaks_fft = sum_num_peaks(2, iSep, iSNR) / Metkl;
        mean_num_peaks_para = sum_num_peaks(3, iSep, iSNR) / Metkl;

        mean_fft_center_error_coarse = fft_center_error_coarse_sum(iSep, iSNR) / fft_center_error_count(iSep, iSNR);
        mean_fft_center_error_refined = fft_center_error_refined_sum(iSep, iSNR) / fft_center_error_count(iSep, iSNR);
        var_fft_center_error_coarse = fft_center_error_coarse_sumsq(iSep, iSNR) / fft_center_error_count(iSep, iSNR) - ...
            mean_fft_center_error_coarse^2;
        var_fft_center_error_refined = fft_center_error_refined_sumsq(iSep, iSNR) / fft_center_error_count(iSep, iSNR) - ...
            mean_fft_center_error_refined^2;
        std_fft_center_error_coarse = sqrt(max(var_fft_center_error_coarse, 0));
        std_fft_center_error_refined = sqrt(max(var_fft_center_error_refined, 0));

        sample = debug_samples{iSep, iSNR};
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | baseline raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(1, iSep, iSNR), tol_success_count(1, iSep, iSNR), ...
            raw_rate_true, tol_rate_true, current_rmse_true, mean_num_peaks_true);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | fft-guided raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f mean_fft_err=%.4f std_fft_err=%.4f', ...
            snr, raw_success_count(2, iSep, iSNR), tol_success_count(2, iSep, iSNR), ...
            raw_rate_fft, tol_rate_fft, current_rmse_fft, mean_num_peaks_fft, ...
            mean_fft_center_error_coarse, std_fft_center_error_coarse);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | parabolic raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f mean_para_err=%.4f std_para_err=%.4f', ...
            snr, raw_success_count(3, iSep, iSNR), tol_success_count(3, iSep, iSNR), ...
            raw_rate_para, tol_rate_para, current_rmse_para, mean_num_peaks_para, ...
            mean_fft_center_error_refined, std_fft_center_error_refined);
        log_lines = append_log(log_lines, ...
            'sample metkl=1 | center_true=%.4f center_fft=%.4f center_para=%.4f err_fft=%.4f err_para=%.4f delta_bin=%.4f used_parabolic=%d doa_true=%s doa_fft=%s doa_para=%s', ...
            sample.RecvbeamC_true, sample.RecvbeamC_fft_coarse, sample.RecvbeamC_fft_parabolic, ...
            sample.fft_center_error_coarse_deg, sample.fft_center_error_refined_deg, ...
            sample.delta_bin, sample.used_parabolic, ...
            mat2str(sample.doa_true, 4), mat2str(sample.doa_fft, 4), mat2str(sample.doa_para, 4));
    end

    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;

mean_fft_center_error_coarse_deg = fft_center_error_coarse_sum ./ max(fft_center_error_count, 1);
var_fft_center_error_coarse_deg = fft_center_error_coarse_sumsq ./ max(fft_center_error_count, 1) - ...
    mean_fft_center_error_coarse_deg.^2;
std_fft_center_error_coarse_deg = sqrt(max(var_fft_center_error_coarse_deg, 0));

mean_fft_center_error_refined_deg = fft_center_error_refined_sum ./ max(fft_center_error_count, 1);
var_fft_center_error_refined_deg = fft_center_error_refined_sumsq ./ max(fft_center_error_count, 1) - ...
    mean_fft_center_error_refined_deg.^2;
std_fft_center_error_refined_deg = sqrt(max(var_fft_center_error_refined_deg, 0));

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
        'SNR90 summary | bw/%d baseline=%s fft-guided=%s parabolic=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90(1, iSep)), fmt_snr90(snr90(2, iSep)), fmt_snr90(snr90(3, iSep)));
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
params.prototype_note = 'Prototype 4a: FFT-guided Route B with 3-point parabolic center refinement.';

result_dir = fullfile(script_dir, 'results_step8_routeB_fft_guided_centerT_parabolic_proto4a');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_fft_guided_centerT_parabolic_proto4a.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_fft_guided_centerT_parabolic_proto4a_summary.csv');
fid = fopen(csv_path, 'w');
if fid < 0
    error('Failed to open csv file.');
end
fprintf(fid, 'route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,raw_success_count,tol_success_count,raw_success_rate,tol_success_rate,rmse_deg,rmse_valid_count,mean_num_peaks,snr90_db,mean_fft_center_error_coarse_deg,std_fft_center_error_coarse_deg,mean_fft_center_error_refined_deg,std_fft_center_error_refined_deg\n');
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, '%s,%d,%.6f,%.6f,%.6f,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), ...
                theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), ...
                raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                raw_success_rate(iroute, iSep, iSNR), tol_success_rate(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), ...
                mean_num_peaks(iroute, iSep, iSNR), snr90(iroute, iSep), ...
                mean_fft_center_error_coarse_deg(iSep, iSNR), std_fft_center_error_coarse_deg(iSep, iSNR), ...
                mean_fft_center_error_refined_deg(iSep, iSNR), std_fft_center_error_refined_deg(iSep, iSNR));
        end
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step8_routeB_fft_guided_centerT_parabolic_proto4a_result.mat');
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
    'fft_center_error_coarse_sum', ...
    'fft_center_error_coarse_sumsq', ...
    'fft_center_error_refined_sum', ...
    'fft_center_error_refined_sumsq', ...
    'fft_center_error_count', ...
    'mean_fft_center_error_coarse_deg', ...
    'std_fft_center_error_coarse_deg', ...
    'mean_fft_center_error_refined_deg', ...
    'std_fft_center_error_refined_deg', ...
    'debug_samples');

fig1 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(tol_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(tol_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.2);
    plot(snr_list, squeeze(tol_success_rate(3, iSep, :)), '-^', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('tol success');
    title(sprintf('Prototype 4a tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_parabolic_proto4a_tol_success.png'));
close(fig1)

fig2 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(rmse(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(rmse(2, iSep, :)), '-s', 'LineWidth', 1.2);
    plot(snr_list, squeeze(rmse(3, iSep, :)), '-^', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('RMSE (deg)');
    title(sprintf('Prototype 4a RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_parabolic_proto4a_rmse.png'));
close(fig2)

fig3 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(raw_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(raw_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.2);
    plot(snr_list, squeeze(raw_success_rate(3, iSep, :)), '-^', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('raw success');
    title(sprintf('Prototype 4a raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_parabolic_proto4a_raw_success.png'));
close(fig3)

fig4 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(mean_num_peaks(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(mean_num_peaks(2, iSep, :)), '-s', 'LineWidth', 1.2);
    plot(snr_list, squeeze(mean_num_peaks(3, iSep, :)), '-^', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('mean peaks');
    title(sprintf('Prototype 4a mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_fft_guided_centerT_parabolic_proto4a_mean_num_peaks.png'));
close(fig4)

disp('Prototype 4a finished.');
disp('route_names =');
disp(route_names);
disp('snr90 =');
disp(snr90);
disp('result_dir =');
disp(result_dir);

function [RecvbeamC_fft_coarse, theta_grid_valid, Pfft_valid, peak_idx] = calc_spatial_fft_center_coarse(y, lambda, d, Nfft_spatial)
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
    RecvbeamC_fft_coarse = theta_grid_valid(peak_idx);
end

function [RecvbeamC_fft_parabolic, delta_bin, used_parabolic] = refine_fft_center_parabolic(theta_grid_valid, Pfft_valid, peak_idx)
    RecvbeamC_fft_parabolic = theta_grid_valid(peak_idx);
    delta_bin = 0;
    used_parabolic = false;

    if peak_idx <= 1 || peak_idx >= numel(Pfft_valid)
        return;
    end

    pL = Pfft_valid(peak_idx - 1);
    pC = Pfft_valid(peak_idx);
    pR = Pfft_valid(peak_idx + 1);
    denom = pL - 2 * pC + pR;

    if abs(denom) <= eps * max([abs(pL), abs(pC), abs(pR), 1])
        return;
    end

    delta_bin = 0.5 * (pL - pR) / denom;
    delta_bin = max(min(delta_bin, 1), -1);

    if numel(theta_grid_valid) >= 2
        dtheta = theta_grid_valid(peak_idx + 1) - theta_grid_valid(peak_idx);
        RecvbeamC_fft_parabolic = theta_grid_valid(peak_idx) + delta_bin * dtheta;
        used_parabolic = true;
    end
end

function [beam_grid_full_deg, beam_grid_center_deg, Tk] = build_centerT_from_center( ...
    center_deg, routeB_beam_span, M_full, center_beam_count, posK, lambda)
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
