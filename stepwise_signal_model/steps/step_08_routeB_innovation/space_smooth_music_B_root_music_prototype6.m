clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step75_dir = fullfile(fileparts(script_dir), 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');
addpath(step75_dir);
addpath(script_dir);

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
tol_rel_ratio = 0.25;
sep_factor_list = [7, 8, 9, 10];
base_seed = 20260522;

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
Nfft_spatial = 4096;

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
    'baseline_routeB_centerT_grid_music', ...
    'proto4e_fft_piecewise_grid_music', ...
    'proto6_array_root_music', ...
    'proto6_beamspace_root_music'};
nroutes = numel(route_names);

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count_rel = zeros(nroutes, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nsep, nsnr);
sum_num_peaks = zeros(nroutes, nsep, nsnr);

fft_center_error_sum = zeros(nsep, nsnr);
fft_center_error_sumsq = zeros(nsep, nsnr);
fwhm_fft_sum = zeros(nsep, nsnr);
fwhm_fft_sumsq = zeros(nsep, nsnr);
raw_search_ratio_4e_sum = zeros(nsep, nsnr);
piecewise_search_ratio_4e_sum = zeros(nsep, nsnr);
piecewise_span_ratio_4e_sum = zeros(nsep, nsnr);
theta_search_4e_sum = zeros(nsep, nsnr);
routeB_beam_span_4e_sum = zeros(nsep, nsnr);

lambda2_over_noise_array_sum = zeros(nsep, nsnr);
lambda2_over_noise_beam_sum = zeros(nsep, nsnr);
root_dist_array_sum = zeros(nsep, nsnr);
root_dist_beam_sum = zeros(nsep, nsnr);
proto6_diag_count = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

result_dir = fullfile(script_dir, 'results_step8_routeB_root_music_proto6');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Prototype 6: FBSS + Root-MUSIC fair compare');
log_lines = append_log(log_lines, 'Routes: baseline Route B, proto4e, proto6 array Root-MUSIC, proto6 beamspace Root-MUSIC.');
log_lines = append_log(log_lines, 'Fairness rule: same (sep_factor, snr_db, metkl_num) uses the same independent seed for all routes.');
log_lines = append_log(log_lines, 'base_seed=%d', base_seed);
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f, tol_rel_ratio=%.2f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg, tol_rel_ratio);
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
    tol_deg_rel = tol_rel_ratio * theta_sep;

    theta_search_B_fixed = search_scale_B * theta_sep;
    routeB_beam_span_fixed = 1.5 * theta_search_B_fixed;
    [beam_grid_full_true, beam_grid_center_true, Tk_true] = build_centerT_from_center( ...
        RecvbeamC_true, routeB_beam_span_fixed, M_full, center_beam_count, posK, lambda);

    theta_sep_deg(iSep) = theta_sep;
    theta_a_deg(iSep) = theta_a;
    theta_b_deg(iSep) = theta_b;

    log_lines = append_log(log_lines, '=== sep_factor = %d, theta_sep = %.4f deg, tol_rel = %.4f deg ===', ...
        sep_factor, theta_sep, tol_deg_rel);

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
            noise = sqrt(noise_power / 2) * (randn(size(y_clean)) + j * randn(size(y_clean)));
            y = y_clean + noise;
            y_mean = mean(y, 2);

            [RecvbeamC_fft, theta_grid_valid, Pfft_valid, peak_idx] = ...
                calc_spatial_fft_center(y, lambda, d, Nfft_spatial);
            fft_center_error_deg = RecvbeamC_fft - RecvbeamC_true;

            [fwhm_fft_deg, left_idx_half, right_idx_half, used_fallback_fwhm] = ...
                estimate_fft_fwhm(theta_grid_valid, Pfft_valid, peak_idx, theta_search_B_fixed);

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
            raw_search_ratio_4e_sum(iSep, iSNR) = raw_search_ratio_4e_sum(iSep, iSNR) + r_raw_4e;
            piecewise_search_ratio_4e_sum(iSep, iSNR) = piecewise_search_ratio_4e_sum(iSep, iSNR) + r_search_4e;
            piecewise_span_ratio_4e_sum(iSep, iSNR) = piecewise_span_ratio_4e_sum(iSep, iSNR) + r_span_4e;
            theta_search_4e_sum(iSep, iSNR) = theta_search_4e_sum(iSep, iSNR) + theta_search_B_4e;
            routeB_beam_span_4e_sum(iSep, iSNR) = routeB_beam_span_4e_sum(iSep, iSNR) + routeB_beam_span_4e;

            [~, beam_grid_center_fft_4e, Tk_fft_4e] = build_centerT_from_center( ...
                RecvbeamC_fft, routeB_beam_span_4e, M_full, center_beam_count, posK, lambda);

            [doa_baseline, num_peaks_baseline] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_true, RecvbeamC_true, theta_search_B_fixed);
            [doa_4e, num_peaks_4e] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft_4e, RecvbeamC_fft, theta_search_B_4e);
            [doa_proto6_array, debug_proto6_array] = doa_root_music_array(y, K_fbss, lambda, d, 2);
            [doa_proto6_beam, debug_proto6_beam] = doa_root_music_beamspace(y, K_fbss, Tk_true, lambda, d, 2);

            num_peaks_array = double(all(isfinite(doa_proto6_array))) * numel(doa_proto6_array);
            num_peaks_beam = double(all(isfinite(doa_proto6_beam))) * numel(doa_proto6_beam);

            doa_all = {doa_baseline, doa_4e, doa_proto6_array, doa_proto6_beam};
            num_peaks_all = [num_peaks_baseline, num_peaks_4e, num_peaks_array, num_peaks_beam];

            for iroute = 1:nroutes
                doa_now = doa_all{iroute};
                raw_ok = all(isfinite(doa_now));
                tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_deg_rel);

                if raw_ok
                    raw_success_count(iroute, iSep, iSNR) = raw_success_count(iroute, iSep, iSNR) + 1;
                    sqerr = sum((sort(doa_now(:).') - sort(target_theta(:).')).^2);
                    rmse_sum_sqerr(iroute, iSep, iSNR) = rmse_sum_sqerr(iroute, iSep, iSNR) + sqerr;
                    rmse_valid_count(iroute, iSep, iSNR) = rmse_valid_count(iroute, iSep, iSNR) + 1;
                end

                if tol_ok_abs
                    tol_success_count(iroute, iSep, iSNR) = tol_success_count(iroute, iSep, iSNR) + 1;
                end

                if tol_ok_rel
                    tol_success_count_rel(iroute, iSep, iSNR) = tol_success_count_rel(iroute, iSep, iSNR) + 1;
                end

                sum_num_peaks(iroute, iSep, iSNR) = sum_num_peaks(iroute, iSep, iSNR) + num_peaks_all(iroute);
            end

            if isfinite(debug_proto6_array.lambda2_over_noise)
                lambda2_over_noise_array_sum(iSep, iSNR) = lambda2_over_noise_array_sum(iSep, iSNR) + ...
                    debug_proto6_array.lambda2_over_noise;
            end
            if isfinite(debug_proto6_beam.lambda2_over_noise)
                lambda2_over_noise_beam_sum(iSep, iSNR) = lambda2_over_noise_beam_sum(iSep, iSNR) + ...
                    debug_proto6_beam.lambda2_over_noise;
            end
            if all(isfinite(debug_proto6_array.root_distance_unit))
                root_dist_array_sum(iSep, iSNR) = root_dist_array_sum(iSep, iSNR) + ...
                    mean(debug_proto6_array.root_distance_unit);
            end
            if all(isfinite(debug_proto6_beam.root_distance_unit))
                root_dist_beam_sum(iSep, iSNR) = root_dist_beam_sum(iSep, iSNR) + ...
                    mean(debug_proto6_beam.root_distance_unit);
            end
            proto6_diag_count(iSep, iSNR) = proto6_diag_count(iSep, iSNR) + 1;

            if metkl_num == 1
                sample = struct();
                sample.seed_now = seed_now;
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr;
                sample.tol_deg_rel = tol_deg_rel;
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
                sample.theta_search_B_4e = theta_search_B_4e;
                sample.routeB_beam_span_4e = routeB_beam_span_4e;
                sample.r_raw_4e = r_raw_4e;
                sample.r_search_4e = r_search_4e;
                sample.r_span_4e = r_span_4e;
                sample.piecewise_region_4e = piecewise_region_4e;
                sample.beam_grid_full_true = beam_grid_full_true;
                sample.beam_grid_center_true = beam_grid_center_true;
                sample.beam_grid_center_fft_4e = beam_grid_center_fft_4e;
                sample.doa_baseline = doa_baseline;
                sample.doa_4e = doa_4e;
                sample.doa_proto6_array = doa_proto6_array;
                sample.doa_proto6_beam = doa_proto6_beam;
                sample.debug_proto6_array = debug_proto6_array;
                sample.debug_proto6_beam = debug_proto6_beam;
                debug_samples{iSep, iSNR} = sample;
            end
        end
    end
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
tol_success_rate_rel = tol_success_count_rel / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;
rmse = sqrt(rmse_sum_sqerr ./ max(rmse_valid_count, 1) / 2);

mean_fft_center_error_deg = fft_center_error_sum ./ max(proto6_diag_count, 1);
std_fft_center_error_deg = sqrt(max(fft_center_error_sumsq ./ max(proto6_diag_count, 1) - mean_fft_center_error_deg.^2, 0));
mean_fwhm_fft_deg = fwhm_fft_sum ./ max(proto6_diag_count, 1);
std_fwhm_fft_deg = sqrt(max(fwhm_fft_sumsq ./ max(proto6_diag_count, 1) - mean_fwhm_fft_deg.^2, 0));
mean_raw_search_ratio_4e = raw_search_ratio_4e_sum ./ max(proto6_diag_count, 1);
mean_piecewise_search_ratio_4e = piecewise_search_ratio_4e_sum ./ max(proto6_diag_count, 1);
mean_piecewise_span_ratio_4e = piecewise_span_ratio_4e_sum ./ max(proto6_diag_count, 1);
mean_theta_search_4e_deg = theta_search_4e_sum ./ max(proto6_diag_count, 1);
mean_routeB_beam_span_4e_deg = routeB_beam_span_4e_sum ./ max(proto6_diag_count, 1);
lambda2_over_noise_array = lambda2_over_noise_array_sum ./ max(proto6_diag_count, 1);
lambda2_over_noise_beam = lambda2_over_noise_beam_sum ./ max(proto6_diag_count, 1);
root_dist_array_mean = root_dist_array_sum ./ max(proto6_diag_count, 1);
root_dist_beam_mean = root_dist_beam_sum ./ max(proto6_diag_count, 1);

snr90 = nan(nroutes, nsep);
snr90_rel = nan(nroutes, nsep);
for iroute = 1:nroutes
    for iSep = 1:nsep
        idx_abs = find(squeeze(tol_success_rate(iroute, iSep, :)) >= 0.9, 1, 'first');
        if ~isempty(idx_abs)
            snr90(iroute, iSep) = snr_list(idx_abs);
        end
        idx_rel = find(squeeze(tol_success_rate_rel(iroute, iSep, :)) >= 0.9, 1, 'first');
        if ~isempty(idx_rel)
            snr90_rel(iroute, iSep) = snr_list(idx_rel);
        end
    end
end

for iSep = 1:nsep
    log_lines = append_log(log_lines, ...
        'sep_factor=%d | SNR90 abs01 -> baseline=%s, proto4e=%s, proto6-array=%s, proto6-beam=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90(1, iSep)), fmt_snr90(snr90(2, iSep)), ...
        fmt_snr90(snr90(3, iSep)), fmt_snr90(snr90(4, iSep)));
    log_lines = append_log(log_lines, ...
        'sep_factor=%d | SNR90 rel025 -> baseline=%s, proto4e=%s, proto6-array=%s, proto6-beam=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90_rel(1, iSep)), fmt_snr90(snr90_rel(2, iSep)), ...
        fmt_snr90(snr90_rel(3, iSep)), fmt_snr90(snr90_rel(4, iSep)));
end

log_path = fullfile(result_dir, 'step8_routeB_root_music_proto6.log');
fid = fopen(log_path, 'w');
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

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
params.tol_rel_ratio = tol_rel_ratio;
params.sep_factor_list = sep_factor_list;
params.search_scale_B = search_scale_B;
params.K_fbss = K_fbss;
params.M_full = M_full;
params.center_beam_count = center_beam_count;
params.Nfft_spatial = Nfft_spatial;
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

summary_path = fullfile(result_dir, 'step8_routeB_root_music_proto6_summary.csv');
fid = fopen(summary_path, 'w');
fprintf(fid, ['route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
    'raw_success_count,tol_success_count,tol_success_count_rel,' ...
    'raw_success_rate,tol_success_rate,tol_success_rate_rel,' ...
    'rmse_deg,rmse_valid_count,mean_num_peaks,' ...
    'snr90_db,snr90_rel_db,' ...
    'mean_fft_center_error_deg,std_fft_center_error_deg,mean_fwhm_fft_deg,std_fwhm_fft_deg,' ...
    'mean_raw_search_ratio_4e,mean_piecewise_search_ratio_4e,mean_piecewise_span_ratio_4e,' ...
    'mean_theta_search_4e_deg,mean_routeB_beam_span_4e_deg,' ...
    'lambda2_over_noise_array,lambda2_over_noise_beam,root_dist_array_mean,root_dist_beam_mean\n']);
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, ['%s,%d,%.6f,%.6f,%.6f,%d,' ...
                '%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,' ...
                '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n'], ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
                snr_list(iSNR), raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                tol_success_count_rel(iroute, iSep, iSNR), raw_success_rate(iroute, iSep, iSNR), ...
                tol_success_rate(iroute, iSep, iSNR), tol_success_rate_rel(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), mean_num_peaks(iroute, iSep, iSNR), ...
                snr90(iroute, iSep), snr90_rel(iroute, iSep), ...
                mean_fft_center_error_deg(iSep, iSNR), std_fft_center_error_deg(iSep, iSNR), ...
                mean_fwhm_fft_deg(iSep, iSNR), std_fwhm_fft_deg(iSep, iSNR), ...
                mean_raw_search_ratio_4e(iSep, iSNR), mean_piecewise_search_ratio_4e(iSep, iSNR), ...
                mean_piecewise_span_ratio_4e(iSep, iSNR), mean_theta_search_4e_deg(iSep, iSNR), ...
                mean_routeB_beam_span_4e_deg(iSep, iSNR), lambda2_over_noise_array(iSep, iSNR), ...
                lambda2_over_noise_beam(iSep, iSNR), root_dist_array_mean(iSep, iSNR), root_dist_beam_mean(iSep, iSNR));
        end
    end
end
fclose(fid);

keypoints_path = fullfile(result_dir, 'step8_routeB_root_music_proto6_keypoints.csv');
fid = fopen(keypoints_path, 'w');
fprintf(fid, 'route_name,sep_factor,snr_db,raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,mean_num_peaks\n');
for iSep = 1:nsep
    sep_factor = sep_factor_list(iSep);
    switch sep_factor
        case 7
            key_snr_list = [12, 14, 16];
        case 8
            key_snr_list = [14, 16, 18];
        case 9
            key_snr_list = [18, 20, 22];
        case 10
            key_snr_list = [20, 22, 24];
        otherwise
            key_snr_list = [];
    end
    for is = 1:numel(key_snr_list)
        snr_key = key_snr_list(is);
        idx = find(snr_list == snr_key, 1, 'first');
        if isempty(idx)
            continue;
        end
        for iroute = 1:nroutes
            fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                route_names{iroute}, sep_factor, snr_key, raw_success_rate(iroute, iSep, idx), ...
                tol_success_rate(iroute, iSep, idx), tol_success_rate_rel(iroute, iSep, idx), ...
                rmse(iroute, iSep, idx), mean_num_peaks(iroute, iSep, idx));
        end
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step8_routeB_root_music_proto6_result.mat');
save(mat_path, ...
    'params', 'route_names', 'sep_factor_list', 'snr_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_count', 'tol_success_count', 'tol_success_count_rel', ...
    'raw_success_rate', 'tol_success_rate', 'tol_success_rate_rel', ...
    'rmse_sum_sqerr', 'rmse_valid_count', 'rmse', 'sum_num_peaks', 'mean_num_peaks', ...
    'snr90', 'snr90_rel', ...
    'mean_fft_center_error_deg', 'std_fft_center_error_deg', 'mean_fwhm_fft_deg', 'std_fwhm_fft_deg', ...
    'mean_raw_search_ratio_4e', 'mean_piecewise_search_ratio_4e', 'mean_piecewise_span_ratio_4e', ...
    'mean_theta_search_4e_deg', 'mean_routeB_beam_span_4e_deg', ...
    'lambda2_over_noise_array', 'lambda2_over_noise_beam', 'root_dist_array_mean', 'root_dist_beam_mean', ...
    'debug_samples');

fig1 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    for iroute = 1:nroutes
        plot(snr_list, squeeze(tol_success_rate(iroute, iSep, :)), 'LineWidth', 1.1);
        hold on
    end
    hold off
    grid on
    ylabel('tol success');
    title(sprintf('Prototype6 tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_root_music_proto6_tol_success.png'));
close(fig1)

fig2 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    for iroute = 1:nroutes
        plot(snr_list, squeeze(rmse(iroute, iSep, :)), 'LineWidth', 1.1);
        hold on
    end
    hold off
    grid on
    ylabel('RMSE (deg)');
    title(sprintf('Prototype6 RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_root_music_proto6_rmse.png'));
close(fig2)

fig3 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    for iroute = 1:nroutes
        plot(snr_list, squeeze(raw_success_rate(iroute, iSep, :)), 'LineWidth', 1.1);
        hold on
    end
    hold off
    grid on
    ylabel('raw success');
    title(sprintf('Prototype6 raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_root_music_proto6_raw_success.png'));
close(fig3)

fig4 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    for iroute = 1:nroutes
        plot(snr_list, squeeze(mean_num_peaks(iroute, iSep, :)), 'LineWidth', 1.1);
        hold on
    end
    hold off
    grid on
    ylabel('mean peaks');
    title(sprintf('Prototype6 mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_root_music_proto6_mean_num_peaks.png'));
close(fig4)

fig5 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, lambda2_over_noise_array(iSep, :), '-o', 'LineWidth', 1.1);
    hold on
    plot(snr_list, lambda2_over_noise_beam(iSep, :), '-s', 'LineWidth', 1.1);
    hold off
    grid on
    ylabel('\lambda_2 / noise');
    title(sprintf('Prototype6 lambda2 diag, bw/%d', sep_factor_list(iSep)));
    legend({'proto6-array', 'proto6-beam'}, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig5, fullfile(result_dir, 'step8_routeB_root_music_proto6_lambda2_diag.png'));
close(fig5)

disp('Step 08 Prototype 6 finished.');
disp('route_names =');
disp(route_names);
disp('snr90_abs01 =');
disp(snr90);
disp('snr90_rel025 =');
disp(snr90_rel);
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

function ok = is_valid_doa_success(doa_est, target_theta, tol_deg_now)
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
    ok = all(abs(doa_est - target_theta) <= tol_deg_now);
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
