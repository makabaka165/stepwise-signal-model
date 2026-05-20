clc
clear
close all

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
sep_factor_list = [7, 8, 9, 10];
base_seed = 20260520;

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
Nfft_spatial = 4096;

gamma_search_4b = 1.20;
gamma_span_4b = 1.50;
search_lower_ratio_4b = 0.60;
search_upper_ratio_4b = 1.60;
span_lower_ratio_4b = 0.80;
span_upper_ratio_4b = 1.60;

gamma_search_4e = 1.20;
beta_span_4e = 1.45;
search_lower_ratio_4e = 0.60;
search_upper_ratio_4e = 1.45;
span_lower_ratio_4e = 0.80;
span_upper_ratio_4e = 1.45;
piecewise_break1 = 1.05;
piecewise_break2 = 1.35;
piecewise_mid_slope = 0.50;
piecewise_high_slope = 0.20;
piecewise_mid_anchor = piecewise_break1;
piecewise_high_anchor = 1.20;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
posK = d * (0:K_fbss-1).';

route_names = { ...
    'baseline_true_centerT', ...
    'fft_guided_centerT_proto4', ...
    'fft_guided_centerT_adaptive_window_proto4b', ...
    'fft_guided_centerT_piecewise_proto4e'};
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
fwhm_fft_sum = zeros(nsep, nsnr);
fwhm_fft_sumsq = zeros(nsep, nsnr);
theta_search_4b_sum = zeros(nsep, nsnr);
routeB_beam_span_4b_sum = zeros(nsep, nsnr);
theta_search_4e_sum = zeros(nsep, nsnr);
routeB_beam_span_4e_sum = zeros(nsep, nsnr);
raw_search_ratio_4e_sum = zeros(nsep, nsnr);
piecewise_search_ratio_4e_sum = zeros(nsep, nsnr);
piecewise_span_ratio_4e_sum = zeros(nsep, nsnr);
diag_count = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Route B FFT-guided prototype4 line fair compare');
log_lines = append_log(log_lines, 'Fair compare scope: baseline_true_centerT vs proto4 vs proto4b vs proto4e.');
log_lines = append_log(log_lines, 'Fairness rule: each (sep_factor, snr_db, metkl_num) uses an independent fixed RNG seed.');
log_lines = append_log(log_lines, 'base_seed=%d', base_seed);
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f, Nfft_spatial=%d', ...
    K_fbss, M_full, center_beam_count, search_scale_B, Nfft_spatial);
log_lines = append_log(log_lines, '');

for iSep = 1:nsep
    sep_factor = sep_factor_list(iSep);
    theta_sep = bw_64 / sep_factor;
    theta_a = theta_c - theta_sep / 2;
    theta_b = theta_c + theta_sep / 2;
    target_theta = [theta_a, theta_b];
    RecvbeamC_true = mean(target_theta);

    theta_search_B_fixed = search_scale_B * theta_sep;
    routeB_beam_span_fixed = 1.5 * theta_search_B_fixed;

    [beam_grid_full_true, beam_grid_center_true, Tk_true] = build_centerT_from_center( ...
        RecvbeamC_true, routeB_beam_span_fixed, M_full, center_beam_count, posK, lambda);

    theta_sep_deg(iSep) = theta_sep;
    theta_a_deg(iSep) = theta_a;
    theta_b_deg(iSep) = theta_b;

    log_lines = append_log(log_lines, '=== sep_factor = %d, theta_sep = %.4f deg ===', sep_factor, theta_sep);

    for iSNR = 1:nsnr
        snr = snr_list(iSNR);

        for metkl_num = 1:Metkl
            seed_now = base_seed + 100000 * iSep + 1000 * iSNR + metkl_num;
            rng(seed_now, 'twister');

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

            [fwhm_fft_deg, left_idx_half, right_idx_half, used_fallback_fwhm] = ...
                estimate_fft_fwhm(theta_grid_valid, Pfft_valid, peak_idx, theta_search_B_fixed);

            [theta_search_B_4b, routeB_beam_span_4b] = map_fwhm_to_adaptive_window_4b( ...
                fwhm_fft_deg, theta_search_B_fixed, routeB_beam_span_fixed, ...
                gamma_search_4b, gamma_span_4b, search_lower_ratio_4b, search_upper_ratio_4b, ...
                span_lower_ratio_4b, span_upper_ratio_4b);

            [theta_search_B_4e, routeB_beam_span_4e, r_raw_4e, r_search_4e, r_span_4e, piecewise_region_4e] = ...
                map_fwhm_to_adaptive_window_piecewise_4e( ...
                fwhm_fft_deg, theta_search_B_fixed, routeB_beam_span_fixed, ...
                gamma_search_4e, beta_span_4e, search_lower_ratio_4e, search_upper_ratio_4e, ...
                span_lower_ratio_4e, span_upper_ratio_4e, piecewise_break1, piecewise_break2, ...
                piecewise_mid_slope, piecewise_high_slope, piecewise_mid_anchor, piecewise_high_anchor);

            fft_center_error_sum(iSep, iSNR) = fft_center_error_sum(iSep, iSNR) + fft_center_error_deg;
            fft_center_error_sumsq(iSep, iSNR) = fft_center_error_sumsq(iSep, iSNR) + fft_center_error_deg^2;
            fwhm_fft_sum(iSep, iSNR) = fwhm_fft_sum(iSep, iSNR) + fwhm_fft_deg;
            fwhm_fft_sumsq(iSep, iSNR) = fwhm_fft_sumsq(iSep, iSNR) + fwhm_fft_deg^2;
            theta_search_4b_sum(iSep, iSNR) = theta_search_4b_sum(iSep, iSNR) + theta_search_B_4b;
            routeB_beam_span_4b_sum(iSep, iSNR) = routeB_beam_span_4b_sum(iSep, iSNR) + routeB_beam_span_4b;
            theta_search_4e_sum(iSep, iSNR) = theta_search_4e_sum(iSep, iSNR) + theta_search_B_4e;
            routeB_beam_span_4e_sum(iSep, iSNR) = routeB_beam_span_4e_sum(iSep, iSNR) + routeB_beam_span_4e;
            raw_search_ratio_4e_sum(iSep, iSNR) = raw_search_ratio_4e_sum(iSep, iSNR) + r_raw_4e;
            piecewise_search_ratio_4e_sum(iSep, iSNR) = piecewise_search_ratio_4e_sum(iSep, iSNR) + r_search_4e;
            piecewise_span_ratio_4e_sum(iSep, iSNR) = piecewise_span_ratio_4e_sum(iSep, iSNR) + r_span_4e;
            diag_count(iSep, iSNR) = diag_count(iSep, iSNR) + 1;

            [~, beam_grid_center_fft_proto4, Tk_fft_proto4] = build_centerT_from_center( ...
                RecvbeamC_fft, routeB_beam_span_fixed, M_full, center_beam_count, posK, lambda);
            [~, beam_grid_center_fft_4b, Tk_fft_4b] = build_centerT_from_center( ...
                RecvbeamC_fft, routeB_beam_span_4b, M_full, center_beam_count, posK, lambda);
            [~, beam_grid_center_fft_4e, Tk_fft_4e] = build_centerT_from_center( ...
                RecvbeamC_fft, routeB_beam_span_4e, M_full, center_beam_count, posK, lambda);

            [doa_true, num_peaks_true] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_true, RecvbeamC_true, theta_search_B_fixed);
            [doa_proto4, num_peaks_proto4] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft_proto4, RecvbeamC_fft, theta_search_B_fixed);
            [doa_4b, num_peaks_4b] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft_4b, RecvbeamC_fft, theta_search_B_4b);
            [doa_4e, num_peaks_4e] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft_4e, RecvbeamC_fft, theta_search_B_4e);

            doa_all = {doa_true, doa_proto4, doa_4b, doa_4e};
            num_peaks_all = [num_peaks_true, num_peaks_proto4, num_peaks_4b, num_peaks_4e];

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
                sample.seed_now = seed_now;
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr;
                sample.target_theta = target_theta;
                sample.y_mean = y_mean;
                sample.RecvbeamC_true = RecvbeamC_true;
                sample.RecvbeamC_fft = RecvbeamC_fft;
                sample.fft_center_error_deg = fft_center_error_deg;
                sample.theta_grid_valid = theta_grid_valid;
                sample.Pfft_valid = Pfft_valid;
                sample.peak_idx = peak_idx;
                sample.fwhm_fft_deg = fwhm_fft_deg;
                sample.left_idx_half = left_idx_half;
                sample.right_idx_half = right_idx_half;
                sample.used_fallback_fwhm = used_fallback_fwhm;
                sample.theta_search_B_fixed = theta_search_B_fixed;
                sample.routeB_beam_span_fixed = routeB_beam_span_fixed;
                sample.theta_search_B_4b = theta_search_B_4b;
                sample.routeB_beam_span_4b = routeB_beam_span_4b;
                sample.theta_search_B_4e = theta_search_B_4e;
                sample.routeB_beam_span_4e = routeB_beam_span_4e;
                sample.r_raw_4e = r_raw_4e;
                sample.r_search_4e = r_search_4e;
                sample.r_span_4e = r_span_4e;
                sample.piecewise_region_4e = piecewise_region_4e;
                sample.beam_grid_full_true = beam_grid_full_true;
                sample.beam_grid_center_true = beam_grid_center_true;
                sample.beam_grid_center_fft_proto4 = beam_grid_center_fft_proto4;
                sample.beam_grid_center_fft_4b = beam_grid_center_fft_4b;
                sample.beam_grid_center_fft_4e = beam_grid_center_fft_4e;
                sample.doa_true = doa_true;
                sample.doa_proto4 = doa_proto4;
                sample.doa_4b = doa_4b;
                sample.doa_4e = doa_4e;
                sample.num_peaks_true = num_peaks_true;
                sample.num_peaks_proto4 = num_peaks_proto4;
                sample.num_peaks_4b = num_peaks_4b;
                sample.num_peaks_4e = num_peaks_4e;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        mean_fft_center_error = fft_center_error_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        var_fft_center_error = fft_center_error_sumsq(iSep, iSNR) / diag_count(iSep, iSNR) - mean_fft_center_error^2;
        std_fft_center_error = sqrt(max(var_fft_center_error, 0));

        mean_fwhm_fft = fwhm_fft_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        var_fwhm_fft = fwhm_fft_sumsq(iSep, iSNR) / diag_count(iSep, iSNR) - mean_fwhm_fft^2;
        std_fwhm_fft = sqrt(max(var_fwhm_fft, 0));

        log_lines = append_log(log_lines, ...
            'SNR=%d dB | baseline tol_rate=%.3f proto4 tol_rate=%.3f proto4b tol_rate=%.3f proto4e tol_rate=%.3f | fft_err_mean=%.4f std=%.4f | fwhm_mean=%.4f std=%.4f', ...
            snr, ...
            tol_success_count(1, iSep, iSNR) / Metkl, ...
            tol_success_count(2, iSep, iSNR) / Metkl, ...
            tol_success_count(3, iSep, iSNR) / Metkl, ...
            tol_success_count(4, iSep, iSNR) / Metkl, ...
            mean_fft_center_error, std_fft_center_error, mean_fwhm_fft, std_fwhm_fft);
    end

    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;

mean_fft_center_error_deg = fft_center_error_sum ./ max(diag_count, 1);
var_fft_center_error_deg = fft_center_error_sumsq ./ max(diag_count, 1) - mean_fft_center_error_deg.^2;
std_fft_center_error_deg = sqrt(max(var_fft_center_error_deg, 0));

mean_fwhm_fft_deg = fwhm_fft_sum ./ max(diag_count, 1);
var_fwhm_fft_deg = fwhm_fft_sumsq ./ max(diag_count, 1) - mean_fwhm_fft_deg.^2;
std_fwhm_fft_deg = sqrt(max(var_fwhm_fft_deg, 0));

mean_theta_search_4b_deg = theta_search_4b_sum ./ max(diag_count, 1);
mean_routeB_beam_span_4b_deg = routeB_beam_span_4b_sum ./ max(diag_count, 1);
mean_theta_search_4e_deg = theta_search_4e_sum ./ max(diag_count, 1);
mean_routeB_beam_span_4e_deg = routeB_beam_span_4e_sum ./ max(diag_count, 1);
mean_raw_search_ratio_4e = raw_search_ratio_4e_sum ./ max(diag_count, 1);
mean_piecewise_search_ratio_4e = piecewise_search_ratio_4e_sum ./ max(diag_count, 1);
mean_piecewise_span_ratio_4e = piecewise_span_ratio_4e_sum ./ max(diag_count, 1);

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
        'SNR90 summary | bw/%d baseline=%s proto4=%s proto4b=%s proto4e=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90(1, iSep)), fmt_snr90(snr90(2, iSep)), ...
        fmt_snr90(snr90(3, iSep)), fmt_snr90(snr90(4, iSep)));
end

params = struct();
params.base_seed = base_seed;
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
params.gamma_search_4b = gamma_search_4b;
params.gamma_span_4b = gamma_span_4b;
params.search_lower_ratio_4b = search_lower_ratio_4b;
params.search_upper_ratio_4b = search_upper_ratio_4b;
params.span_lower_ratio_4b = span_lower_ratio_4b;
params.span_upper_ratio_4b = span_upper_ratio_4b;
params.gamma_search_4e = gamma_search_4e;
params.beta_span_4e = beta_span_4e;
params.search_lower_ratio_4e = search_lower_ratio_4e;
params.search_upper_ratio_4e = search_upper_ratio_4e;
params.span_lower_ratio_4e = span_lower_ratio_4e;
params.span_upper_ratio_4e = span_upper_ratio_4e;
params.piecewise_break1 = piecewise_break1;
params.piecewise_break2 = piecewise_break2;
params.piecewise_mid_slope = piecewise_mid_slope;
params.piecewise_high_slope = piecewise_high_slope;
params.piecewise_mid_anchor = piecewise_mid_anchor;
params.piecewise_high_anchor = piecewise_high_anchor;

result_dir = fullfile(script_dir, 'results_step8_routeB_fft_guided_fair_compare_proto4_line');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_fft_guided_fair_compare_proto4_line.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_fft_guided_fair_compare_proto4_line_summary.csv');
fid = fopen(csv_path, 'w');
if fid < 0
    error('Failed to open csv file.');
end
fprintf(fid, 'route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,raw_success_count,tol_success_count,raw_success_rate,tol_success_rate,rmse_deg,rmse_valid_count,mean_num_peaks,snr90_db,mean_fft_center_error_deg,std_fft_center_error_deg,mean_fwhm_fft_deg,std_fwhm_fft_deg,mean_theta_search_4b_deg,mean_routeB_beam_span_4b_deg,mean_theta_search_4e_deg,mean_routeB_beam_span_4e_deg,mean_raw_search_ratio_4e,mean_piecewise_search_ratio_4e,mean_piecewise_span_ratio_4e\n');
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, '%s,%d,%.6f,%.6f,%.6f,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
                snr_list(iSNR), raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                raw_success_rate(iroute, iSep, iSNR), tol_success_rate(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), mean_num_peaks(iroute, iSep, iSNR), ...
                snr90(iroute, iSep), mean_fft_center_error_deg(iSep, iSNR), std_fft_center_error_deg(iSep, iSNR), ...
                mean_fwhm_fft_deg(iSep, iSNR), std_fwhm_fft_deg(iSep, iSNR), ...
                mean_theta_search_4b_deg(iSep, iSNR), mean_routeB_beam_span_4b_deg(iSep, iSNR), ...
                mean_theta_search_4e_deg(iSep, iSNR), mean_routeB_beam_span_4e_deg(iSep, iSNR), ...
                mean_raw_search_ratio_4e(iSep, iSNR), mean_piecewise_search_ratio_4e(iSep, iSNR), ...
                mean_piecewise_span_ratio_4e(iSep, iSNR));
        end
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step8_routeB_fft_guided_fair_compare_proto4_line_result.mat');
save(mat_path, ...
    'params', 'route_names', 'sep_factor_list', 'snr_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_count', 'tol_success_count', 'raw_success_rate', 'tol_success_rate', ...
    'rmse_sum_sqerr', 'rmse_valid_count', 'rmse', 'sum_num_peaks', 'mean_num_peaks', 'snr90', ...
    'mean_fft_center_error_deg', 'std_fft_center_error_deg', 'mean_fwhm_fft_deg', 'std_fwhm_fft_deg', ...
    'mean_theta_search_4b_deg', 'mean_routeB_beam_span_4b_deg', 'mean_theta_search_4e_deg', ...
    'mean_routeB_beam_span_4e_deg', 'mean_raw_search_ratio_4e', 'mean_piecewise_search_ratio_4e', ...
    'mean_piecewise_span_ratio_4e', 'debug_samples');

fig1 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(tol_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.1);
    hold on
    plot(snr_list, squeeze(tol_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.1);
    plot(snr_list, squeeze(tol_success_rate(3, iSep, :)), '-^', 'LineWidth', 1.1);
    plot(snr_list, squeeze(tol_success_rate(4, iSep, :)), '-d', 'LineWidth', 1.1);
    hold off
    grid on
    ylabel('tol success');
    title(sprintf('Fair compare tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_fft_guided_fair_compare_proto4_line_tol_success.png'));
close(fig1)

fig2 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(rmse(1, iSep, :)), '-o', 'LineWidth', 1.1);
    hold on
    plot(snr_list, squeeze(rmse(2, iSep, :)), '-s', 'LineWidth', 1.1);
    plot(snr_list, squeeze(rmse(3, iSep, :)), '-^', 'LineWidth', 1.1);
    plot(snr_list, squeeze(rmse(4, iSep, :)), '-d', 'LineWidth', 1.1);
    hold off
    grid on
    ylabel('RMSE (deg)');
    title(sprintf('Fair compare RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_fft_guided_fair_compare_proto4_line_rmse.png'));
close(fig2)

fig3 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(raw_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.1);
    hold on
    plot(snr_list, squeeze(raw_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.1);
    plot(snr_list, squeeze(raw_success_rate(3, iSep, :)), '-^', 'LineWidth', 1.1);
    plot(snr_list, squeeze(raw_success_rate(4, iSep, :)), '-d', 'LineWidth', 1.1);
    hold off
    grid on
    ylabel('raw success');
    title(sprintf('Fair compare raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_fft_guided_fair_compare_proto4_line_raw_success.png'));
close(fig3)

fig4 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(mean_num_peaks(1, iSep, :)), '-o', 'LineWidth', 1.1);
    hold on
    plot(snr_list, squeeze(mean_num_peaks(2, iSep, :)), '-s', 'LineWidth', 1.1);
    plot(snr_list, squeeze(mean_num_peaks(3, iSep, :)), '-^', 'LineWidth', 1.1);
    plot(snr_list, squeeze(mean_num_peaks(4, iSep, :)), '-d', 'LineWidth', 1.1);
    hold off
    grid on
    ylabel('mean peaks');
    title(sprintf('Fair compare mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_fft_guided_fair_compare_proto4_line_mean_num_peaks.png'));
close(fig4)

disp('Step 08 prototype4 line fair compare finished.');
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

function [fwhm_fft_deg, left_idx_half, right_idx_half, used_fallback_fwhm] = estimate_fft_fwhm(theta_grid_valid, Pfft_valid, peak_idx, fallback_width_deg)
    used_fallback_fwhm = false;
    left_idx_half = NaN;
    right_idx_half = NaN;

    Pmax = Pfft_valid(peak_idx);
    Phalf = 0.5 * Pmax;

    left_rel = find(Pfft_valid(1:peak_idx) < Phalf, 1, 'last');
    right_rel = find(Pfft_valid(peak_idx:end) < Phalf, 1, 'first');

    if isempty(left_rel) || isempty(right_rel)
        fwhm_fft_deg = fallback_width_deg;
        used_fallback_fwhm = true;
        return;
    end

    left_idx_half = left_rel;
    right_idx_half = peak_idx + right_rel - 1;

    if left_idx_half >= peak_idx || right_idx_half <= peak_idx
        fwhm_fft_deg = fallback_width_deg;
        used_fallback_fwhm = true;
        return;
    end

    left_theta_cross = interp_half_power_theta( ...
        theta_grid_valid(left_idx_half), theta_grid_valid(left_idx_half + 1), ...
        Pfft_valid(left_idx_half), Pfft_valid(left_idx_half + 1), Phalf);
    right_theta_cross = interp_half_power_theta( ...
        theta_grid_valid(right_idx_half - 1), theta_grid_valid(right_idx_half), ...
        Pfft_valid(right_idx_half - 1), Pfft_valid(right_idx_half), Phalf);

    fwhm_fft_deg = abs(right_theta_cross - left_theta_cross);
    if ~(isfinite(fwhm_fft_deg) && fwhm_fft_deg > 0)
        fwhm_fft_deg = fallback_width_deg;
        used_fallback_fwhm = true;
    end
end

function theta_cross = interp_half_power_theta(theta1, theta2, power1, power2, target_power)
    if ~(isfinite(theta1) && isfinite(theta2) && isfinite(power1) && isfinite(power2))
        theta_cross = NaN;
        return;
    end

    dp = power2 - power1;
    if abs(dp) < eps
        theta_cross = 0.5 * (theta1 + theta2);
        return;
    end

    alpha = (target_power - power1) / dp;
    alpha = min(max(alpha, 0), 1);
    theta_cross = theta1 + alpha * (theta2 - theta1);
end

function [theta_search_B_adapt, routeB_beam_span_adapt] = map_fwhm_to_adaptive_window_4b( ...
    fwhm_fft_deg, theta_search_fixed, routeB_beam_span_fixed, ...
    gamma_search, gamma_span, search_lower_ratio, search_upper_ratio, span_lower_ratio, span_upper_ratio)
    theta_search_raw = gamma_search * fwhm_fft_deg;
    routeB_beam_span_raw = gamma_span * theta_search_raw;

    theta_search_B_adapt = min(max(theta_search_raw, search_lower_ratio * theta_search_fixed), ...
        search_upper_ratio * theta_search_fixed);
    routeB_beam_span_adapt = min(max(routeB_beam_span_raw, span_lower_ratio * routeB_beam_span_fixed), ...
        span_upper_ratio * routeB_beam_span_fixed);
end

function [theta_search_B_adapt, routeB_beam_span_adapt, r_raw, r_search_piecewise, r_span_piecewise, piecewise_region] = ...
    map_fwhm_to_adaptive_window_piecewise_4e( ...
    fwhm_fft_deg, theta_search_B_fixed, routeB_beam_span_fixed, ...
    gamma_search, beta_span, search_lower_ratio, search_upper_ratio, span_lower_ratio, span_upper_ratio, ...
    piecewise_break1, piecewise_break2, piecewise_mid_slope, piecewise_high_slope, ...
    piecewise_mid_anchor, piecewise_high_anchor)
    theta_search_raw = gamma_search * fwhm_fft_deg;
    r_raw = theta_search_raw / theta_search_B_fixed;

    if r_raw <= piecewise_break1
        r_search_piecewise = r_raw;
        piecewise_region = 'low';
    elseif r_raw <= piecewise_break2
        r_search_piecewise = piecewise_mid_anchor + piecewise_mid_slope * (r_raw - piecewise_break1);
        piecewise_region = 'mid';
    else
        r_search_piecewise = piecewise_high_anchor + piecewise_high_slope * (r_raw - piecewise_break2);
        piecewise_region = 'high';
    end

    r_search_piecewise = min(max(r_search_piecewise, search_lower_ratio), search_upper_ratio);
    theta_search_B_adapt = r_search_piecewise * theta_search_B_fixed;

    theta_span_raw = beta_span * theta_search_B_adapt;
    r_span_piecewise = theta_span_raw / routeB_beam_span_fixed;
    r_span_piecewise = min(max(r_span_piecewise, span_lower_ratio), span_upper_ratio);
    routeB_beam_span_adapt = r_span_piecewise * routeB_beam_span_fixed;
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
    ok = all(abs(doa_est - target_theta) <= tol_deg);
end

function out = fmt_snr90(x)
    if isfinite(x)
        out = sprintf('%.0f dB', x);
    else
        out = 'NaN';
    end
end

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
