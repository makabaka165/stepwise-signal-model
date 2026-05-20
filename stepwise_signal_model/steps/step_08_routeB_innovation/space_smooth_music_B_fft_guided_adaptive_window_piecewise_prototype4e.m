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
sep_factor_list = [7, 8, 9, 10];

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
Nfft_spatial = 4096;

gamma_search = 1.20;
beta_span = 1.45;
search_lower_ratio = 0.60;
search_upper_ratio = 1.45;
span_lower_ratio = 0.80;
span_upper_ratio = 1.45;

piecewise_break1 = 1.05;
piecewise_break2 = 1.35;
piecewise_mid_slope = 0.50;
piecewise_high_slope = 0.20;
piecewise_mid_anchor = piecewise_break1;
piecewise_high_anchor = 1.20;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
posK = d * (0:K_fbss-1).';

route_names = {'baseline_true_centerT', 'fft_guided_centerT', 'fft_guided_centerT_adaptive_window_piecewise'};
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
theta_search_adapt_sum = zeros(nsep, nsnr);
routeB_beam_span_adapt_sum = zeros(nsep, nsnr);
raw_search_ratio_sum = zeros(nsep, nsnr);
piecewise_search_ratio_sum = zeros(nsep, nsnr);
piecewise_span_ratio_sum = zeros(nsep, nsnr);
region_low_count = zeros(nsep, nsnr);
region_mid_count = zeros(nsep, nsnr);
region_high_count = zeros(nsep, nsnr);
search_upper_clip_count = zeros(nsep, nsnr);
span_upper_clip_count = zeros(nsep, nsnr);
diag_count = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Route B FFT-guided adaptive window piecewise prototype 4e');
log_lines = append_log(log_lines, 'Prototype scope: keep FFT coarse center fixed and replace the 4b linear FWHM mapping with a piecewise-saturated adaptive window.');
log_lines = append_log(log_lines, 'Route comparison: baseline_true_centerT vs fft_guided_centerT vs fft_guided_centerT_adaptive_window_piecewise.');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B internal settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, 'FFT settings: Nfft_spatial=%d, piecewise FWHM mapping with gamma_search=%.2f, beta_span=%.2f.', ...
    Nfft_spatial, gamma_search, beta_span);
log_lines = append_log(log_lines, 'Adaptive bounds: search in [%.2f, %.2f] x fixed, span in [%.2f, %.2f] x fixed.', ...
    search_lower_ratio, search_upper_ratio, span_lower_ratio, span_upper_ratio);
log_lines = append_log(log_lines, 'Piecewise search ratio breaks: low<=%.2f, mid<=%.2f, mid_slope=%.2f, high_slope=%.2f.', ...
    piecewise_break1, piecewise_break2, piecewise_mid_slope, piecewise_high_slope);
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

            fft_center_error_deg = RecvbeamC_fft_coarse - RecvbeamC_true;
            [fwhm_fft_deg, left_idx_half, right_idx_half, used_fallback_fwhm] = ...
                estimate_fft_fwhm(theta_grid_valid, Pfft_valid, peak_idx, theta_search_B_fixed);
            [theta_search_B_adapt, routeB_beam_span_adapt, r_raw, r_search_piecewise, r_span_piecewise, ...
                piecewise_region, search_hit_upper, span_hit_upper] = ...
                map_fwhm_to_adaptive_window_piecewise(fwhm_fft_deg, theta_search_B_fixed, routeB_beam_span_fixed, ...
                gamma_search, beta_span, search_lower_ratio, search_upper_ratio, span_lower_ratio, span_upper_ratio, ...
                piecewise_break1, piecewise_break2, piecewise_mid_slope, piecewise_high_slope, ...
                piecewise_mid_anchor, piecewise_high_anchor);

            fft_center_error_sum(iSep, iSNR) = fft_center_error_sum(iSep, iSNR) + fft_center_error_deg;
            fft_center_error_sumsq(iSep, iSNR) = fft_center_error_sumsq(iSep, iSNR) + fft_center_error_deg^2;
            fwhm_fft_sum(iSep, iSNR) = fwhm_fft_sum(iSep, iSNR) + fwhm_fft_deg;
            fwhm_fft_sumsq(iSep, iSNR) = fwhm_fft_sumsq(iSep, iSNR) + fwhm_fft_deg^2;
            theta_search_adapt_sum(iSep, iSNR) = theta_search_adapt_sum(iSep, iSNR) + theta_search_B_adapt;
            routeB_beam_span_adapt_sum(iSep, iSNR) = routeB_beam_span_adapt_sum(iSep, iSNR) + routeB_beam_span_adapt;
            raw_search_ratio_sum(iSep, iSNR) = raw_search_ratio_sum(iSep, iSNR) + r_raw;
            piecewise_search_ratio_sum(iSep, iSNR) = piecewise_search_ratio_sum(iSep, iSNR) + r_search_piecewise;
            piecewise_span_ratio_sum(iSep, iSNR) = piecewise_span_ratio_sum(iSep, iSNR) + r_span_piecewise;
            if strcmp(piecewise_region, 'low')
                region_low_count(iSep, iSNR) = region_low_count(iSep, iSNR) + 1;
            elseif strcmp(piecewise_region, 'mid')
                region_mid_count(iSep, iSNR) = region_mid_count(iSep, iSNR) + 1;
            else
                region_high_count(iSep, iSNR) = region_high_count(iSep, iSNR) + 1;
            end
            if search_hit_upper
                search_upper_clip_count(iSep, iSNR) = search_upper_clip_count(iSep, iSNR) + 1;
            end
            if span_hit_upper
                span_upper_clip_count(iSep, iSNR) = span_upper_clip_count(iSep, iSNR) + 1;
            end
            diag_count(iSep, iSNR) = diag_count(iSep, iSNR) + 1;

            [~, beam_grid_center_fft_fixed, Tk_fft_fixed] = build_centerT_from_center( ...
                RecvbeamC_fft_coarse, routeB_beam_span_fixed, M_full, center_beam_count, posK, lambda);
            [~, beam_grid_center_fft_adapt, Tk_fft_adapt] = build_centerT_from_center( ...
                RecvbeamC_fft_coarse, routeB_beam_span_adapt, M_full, center_beam_count, posK, lambda);

            [doa_true, num_peaks_true] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_true, RecvbeamC_true, theta_search_B_fixed);
            [doa_fft, num_peaks_fft] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft_fixed, RecvbeamC_fft_coarse, theta_search_B_fixed);
            [doa_adapt, num_peaks_adapt] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_fft_adapt, RecvbeamC_fft_coarse, theta_search_B_adapt);

            doa_all = {doa_true, doa_fft, doa_adapt};
            num_peaks_all = [num_peaks_true, num_peaks_fft, num_peaks_adapt];

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
                sample.y_mean = y_mean;
                sample.RecvbeamC_true = RecvbeamC_true;
                sample.RecvbeamC_fft_coarse = RecvbeamC_fft_coarse;
                sample.fft_center_error_deg = fft_center_error_deg;
                sample.theta_grid_valid = theta_grid_valid;
                sample.Pfft_valid = Pfft_valid;
                sample.peak_idx = peak_idx;
                sample.fwhm_fft_deg = fwhm_fft_deg;
                sample.left_idx_half = left_idx_half;
                sample.right_idx_half = right_idx_half;
                sample.used_fallback_fwhm = used_fallback_fwhm;
                sample.theta_search_B_fixed = theta_search_B_fixed;
                sample.theta_search_B_adapt = theta_search_B_adapt;
                sample.routeB_beam_span_fixed = routeB_beam_span_fixed;
                sample.routeB_beam_span_adapt = routeB_beam_span_adapt;
                sample.r_raw = r_raw;
                sample.piecewise_region = piecewise_region;
                sample.r_search_piecewise = r_search_piecewise;
                sample.r_span_piecewise = r_span_piecewise;
                sample.search_hit_upper = search_hit_upper;
                sample.span_hit_upper = span_hit_upper;
                sample.beam_grid_full_true = beam_grid_full_true;
                sample.beam_grid_center_true = beam_grid_center_true;
                sample.beam_grid_center_fft_fixed = beam_grid_center_fft_fixed;
                sample.beam_grid_center_fft_adapt = beam_grid_center_fft_adapt;
                sample.doa_true = doa_true;
                sample.doa_fft = doa_fft;
                sample.doa_adapt = doa_adapt;
                sample.num_peaks_true = num_peaks_true;
                sample.num_peaks_fft = num_peaks_fft;
                sample.num_peaks_adapt = num_peaks_adapt;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        current_rmse_true = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 1, iSep, iSNR);
        current_rmse_fft = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 2, iSep, iSNR);
        current_rmse_adapt = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 3, iSep, iSNR);

        raw_rate_true = raw_success_count(1, iSep, iSNR) / Metkl;
        raw_rate_fft = raw_success_count(2, iSep, iSNR) / Metkl;
        raw_rate_adapt = raw_success_count(3, iSep, iSNR) / Metkl;
        tol_rate_true = tol_success_count(1, iSep, iSNR) / Metkl;
        tol_rate_fft = tol_success_count(2, iSep, iSNR) / Metkl;
        tol_rate_adapt = tol_success_count(3, iSep, iSNR) / Metkl;
        mean_num_peaks_true = sum_num_peaks(1, iSep, iSNR) / Metkl;
        mean_num_peaks_fft = sum_num_peaks(2, iSep, iSNR) / Metkl;
        mean_num_peaks_adapt = sum_num_peaks(3, iSep, iSNR) / Metkl;

        mean_fft_center_error = fft_center_error_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        var_fft_center_error = fft_center_error_sumsq(iSep, iSNR) / diag_count(iSep, iSNR) - ...
            mean_fft_center_error^2;
        std_fft_center_error = sqrt(max(var_fft_center_error, 0));

        mean_fwhm_fft = fwhm_fft_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        var_fwhm_fft = fwhm_fft_sumsq(iSep, iSNR) / diag_count(iSep, iSNR) - mean_fwhm_fft^2;
        std_fwhm_fft = sqrt(max(var_fwhm_fft, 0));

        mean_theta_search_adapt = theta_search_adapt_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        mean_routeB_beam_span_adapt = routeB_beam_span_adapt_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        mean_raw_search_ratio = raw_search_ratio_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        mean_piecewise_search_ratio = piecewise_search_ratio_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        mean_piecewise_span_ratio = piecewise_span_ratio_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        region_low_rate_now = region_low_count(iSep, iSNR) / diag_count(iSep, iSNR);
        region_mid_rate_now = region_mid_count(iSep, iSNR) / diag_count(iSep, iSNR);
        region_high_rate_now = region_high_count(iSep, iSNR) / diag_count(iSep, iSNR);
        search_upper_clip_rate_now = search_upper_clip_count(iSep, iSNR) / diag_count(iSep, iSNR);
        span_upper_clip_rate_now = span_upper_clip_count(iSep, iSNR) / diag_count(iSep, iSNR);

        sample = debug_samples{iSep, iSNR};
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | baseline raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(1, iSep, iSNR), tol_success_count(1, iSep, iSNR), ...
            raw_rate_true, tol_rate_true, current_rmse_true, mean_num_peaks_true);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | fft-guided raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f mean_fft_err=%.4f std_fft_err=%.4f', ...
            snr, raw_success_count(2, iSep, iSNR), tol_success_count(2, iSep, iSNR), ...
            raw_rate_fft, tol_rate_fft, current_rmse_fft, mean_num_peaks_fft, ...
            mean_fft_center_error, std_fft_center_error);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | piecewise-window raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f mean_fwhm=%.4f mean_r_raw=%.4f mean_r_search=%.4f mean_r_span=%.4f mean_search_adapt=%.4f mean_span_adapt=%.4f region=[%.2f %.2f %.2f] clip=[%.2f %.2f]', ...
            snr, raw_success_count(3, iSep, iSNR), tol_success_count(3, iSep, iSNR), ...
            raw_rate_adapt, tol_rate_adapt, current_rmse_adapt, mean_num_peaks_adapt, ...
            mean_fwhm_fft, mean_raw_search_ratio, mean_piecewise_search_ratio, mean_piecewise_span_ratio, ...
            mean_theta_search_adapt, mean_routeB_beam_span_adapt, ...
            region_low_rate_now, region_mid_rate_now, region_high_rate_now, ...
            search_upper_clip_rate_now, span_upper_clip_rate_now);
        log_lines = append_log(log_lines, ...
            'sample metkl=1 | center_true=%.4f center_fft=%.4f err_fft=%.4f fwhm=%.4f r_raw=%.4f region=%s r_search=%.4f r_span=%.4f search_fixed=%.4f search_adapt=%.4f span_fixed=%.4f span_adapt=%.4f upper_clip=[%d %d] fallback_fwhm=%d doa_true=%s doa_fft=%s doa_adapt=%s', ...
            sample.RecvbeamC_true, sample.RecvbeamC_fft_coarse, sample.fft_center_error_deg, ...
            sample.fwhm_fft_deg, sample.r_raw, sample.piecewise_region, sample.r_search_piecewise, sample.r_span_piecewise, ...
            sample.theta_search_B_fixed, sample.theta_search_B_adapt, ...
            sample.routeB_beam_span_fixed, sample.routeB_beam_span_adapt, sample.search_hit_upper, sample.span_hit_upper, sample.used_fallback_fwhm, ...
            mat2str(sample.doa_true, 4), mat2str(sample.doa_fft, 4), mat2str(sample.doa_adapt, 4));
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

mean_theta_search_adapt_deg = theta_search_adapt_sum ./ max(diag_count, 1);
mean_routeB_beam_span_adapt_deg = routeB_beam_span_adapt_sum ./ max(diag_count, 1);
mean_raw_search_ratio_4b = raw_search_ratio_sum ./ max(diag_count, 1);
mean_piecewise_search_ratio = piecewise_search_ratio_sum ./ max(diag_count, 1);
mean_piecewise_span_ratio = piecewise_span_ratio_sum ./ max(diag_count, 1);
region_low_rate = region_low_count ./ max(diag_count, 1);
region_mid_rate = region_mid_count ./ max(diag_count, 1);
region_high_rate = region_high_count ./ max(diag_count, 1);
search_upper_clip_rate = search_upper_clip_count ./ max(diag_count, 1);
span_upper_clip_rate = span_upper_clip_count ./ max(diag_count, 1);

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
        'SNR90 summary | bw/%d baseline=%s fft-guided=%s piecewise-window=%s', ...
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
params.gamma_search = gamma_search;
params.beta_span = beta_span;
params.search_lower_ratio = search_lower_ratio;
params.search_upper_ratio = search_upper_ratio;
params.span_lower_ratio = span_lower_ratio;
params.span_upper_ratio = span_upper_ratio;
params.piecewise_break1 = piecewise_break1;
params.piecewise_break2 = piecewise_break2;
params.piecewise_mid_slope = piecewise_mid_slope;
params.piecewise_high_slope = piecewise_high_slope;
params.piecewise_mid_anchor = piecewise_mid_anchor;
params.piecewise_high_anchor = piecewise_high_anchor;
params.prototype_note = 'Prototype 4e: FFT-guided Route B with piecewise-saturated FWHM adaptive local search window.';

result_dir = fullfile(script_dir, 'results_step8_routeB_fft_guided_adaptive_window_piecewise_proto4e');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_fft_guided_adaptive_window_piecewise_proto4e.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_fft_guided_adaptive_window_piecewise_proto4e_summary.csv');
fid = fopen(csv_path, 'w');
if fid < 0
    error('Failed to open csv file.');
end
fprintf(fid, 'route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,raw_success_count,tol_success_count,raw_success_rate,tol_success_rate,rmse_deg,rmse_valid_count,mean_num_peaks,snr90_db,mean_fft_center_error_deg,std_fft_center_error_deg,mean_fwhm_fft_deg,std_fwhm_fft_deg,mean_raw_search_ratio_4b,mean_piecewise_search_ratio,mean_piecewise_span_ratio,region_low_rate,region_mid_rate,region_high_rate,search_upper_clip_rate,span_upper_clip_rate,mean_theta_search_adapt_deg,mean_routeB_beam_span_adapt_deg\n');
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, '%s,%d,%.6f,%.6f,%.6f,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), ...
                theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), ...
                raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                raw_success_rate(iroute, iSep, iSNR), tol_success_rate(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), ...
                mean_num_peaks(iroute, iSep, iSNR), snr90(iroute, iSep), ...
                mean_fft_center_error_deg(iSep, iSNR), std_fft_center_error_deg(iSep, iSNR), ...
                mean_fwhm_fft_deg(iSep, iSNR), std_fwhm_fft_deg(iSep, iSNR), ...
                mean_raw_search_ratio_4b(iSep, iSNR), mean_piecewise_search_ratio(iSep, iSNR), ...
                mean_piecewise_span_ratio(iSep, iSNR), region_low_rate(iSep, iSNR), ...
                region_mid_rate(iSep, iSNR), region_high_rate(iSep, iSNR), ...
                search_upper_clip_rate(iSep, iSNR), span_upper_clip_rate(iSep, iSNR), ...
                mean_theta_search_adapt_deg(iSep, iSNR), mean_routeB_beam_span_adapt_deg(iSep, iSNR));
        end
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step8_routeB_fft_guided_adaptive_window_piecewise_proto4e_result.mat');
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
    'fwhm_fft_sum', ...
    'fwhm_fft_sumsq', ...
    'theta_search_adapt_sum', ...
    'routeB_beam_span_adapt_sum', ...
    'raw_search_ratio_sum', ...
    'piecewise_search_ratio_sum', ...
    'piecewise_span_ratio_sum', ...
    'region_low_count', ...
    'region_mid_count', ...
    'region_high_count', ...
    'search_upper_clip_count', ...
    'span_upper_clip_count', ...
    'diag_count', ...
    'mean_fft_center_error_deg', ...
    'std_fft_center_error_deg', ...
    'mean_fwhm_fft_deg', ...
    'std_fwhm_fft_deg', ...
    'mean_raw_search_ratio_4b', ...
    'mean_piecewise_search_ratio', ...
    'mean_piecewise_span_ratio', ...
    'region_low_rate', ...
    'region_mid_rate', ...
    'region_high_rate', ...
    'search_upper_clip_rate', ...
    'span_upper_clip_rate', ...
    'mean_theta_search_adapt_deg', ...
    'mean_routeB_beam_span_adapt_deg', ...
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
    title(sprintf('Prototype 4e tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_fft_guided_adaptive_window_piecewise_proto4e_tol_success.png'));
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
    title(sprintf('Prototype 4e RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_fft_guided_adaptive_window_piecewise_proto4e_rmse.png'));
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
    title(sprintf('Prototype 4e raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_fft_guided_adaptive_window_piecewise_proto4e_raw_success.png'));
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
    title(sprintf('Prototype 4e mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_fft_guided_adaptive_window_piecewise_proto4e_mean_num_peaks.png'));
close(fig4)

disp('Prototype 4e finished.');
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

function [theta_search_B_adapt, routeB_beam_span_adapt, r_raw, r_search_piecewise, r_span_piecewise, ...
    piecewise_region, search_hit_upper, span_hit_upper] = map_fwhm_to_adaptive_window_piecewise( ...
    fwhm_fft_deg, theta_search_B_fixed, routeB_beam_span_fixed, ...
    gamma_search, beta_span, search_lower_ratio, search_upper_ratio, span_lower_ratio, span_upper_ratio, ...
    piecewise_break1, piecewise_break2, piecewise_mid_slope, piecewise_high_slope, ...
    piecewise_mid_anchor, piecewise_high_anchor)
    theta_search_raw = gamma_search * fwhm_fft_deg;
    r_raw = theta_search_raw / theta_search_B_fixed;

    if r_raw <= piecewise_break1
        r_search_piecewise = r_raw;
    elseif r_raw <= piecewise_break2
        r_search_piecewise = piecewise_mid_anchor + piecewise_mid_slope * (r_raw - piecewise_break1);
    else
        r_search_piecewise = piecewise_high_anchor + piecewise_high_slope * (r_raw - piecewise_break2);
    end

    piecewise_region = classify_piecewise_region(r_raw, piecewise_break1, piecewise_break2);
    r_search_piecewise = min(max(r_search_piecewise, search_lower_ratio), search_upper_ratio);
    search_hit_upper = abs(r_search_piecewise - search_upper_ratio) < 1e-12;
    theta_search_B_adapt = r_search_piecewise * theta_search_B_fixed;

    theta_span_raw = beta_span * theta_search_B_adapt;
    r_span_piecewise = theta_span_raw / routeB_beam_span_fixed;
    r_span_piecewise = min(max(r_span_piecewise, span_lower_ratio), span_upper_ratio);
    span_hit_upper = abs(r_span_piecewise - span_upper_ratio) < 1e-12;
    routeB_beam_span_adapt = r_span_piecewise * routeB_beam_span_fixed;
end

function piecewise_region = classify_piecewise_region(r_raw, piecewise_break1, piecewise_break2)
    if r_raw <= piecewise_break1
        piecewise_region = 'low';
    elseif r_raw <= piecewise_break2
        piecewise_region = 'mid';
    else
        piecewise_region = 'high';
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
