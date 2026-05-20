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
tol_rel_ratio = 0.25;
sep_factor_list = [7, 8, 9, 10];
base_seed = 20260521;

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

D_known = 2;
max_iter_refine = 60;
max_outer_iter = 6;
angle_tol_stop_deg = 1e-3;
residual_change_tol = 1e-3;
local_refine_step = 0.005;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
posK = d * (0:K_fbss-1).';

route_names = { ...
    'baseline_true_centerT', ...
    'fft_guided_centerT_proto4', ...
    'fft_guided_centerT_adaptive_window_proto4b', ...
    'fft_guided_centerT_piecewise_proto4e', ...
    'root_music_reference', ...
    'fftii_known2_proto5a_refined2'};
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
diag_count = zeros(nsep, nsnr);

outer_iter_sum = zeros(nsep, nsnr);
refine_iter_target1_sum = zeros(nsep, nsnr);
refine_iter_target2_sum = zeros(nsep, nsnr);
residual_power_final_sum = zeros(nsep, nsnr);
fftii_diag_valid_count = zeros(nsep, nsnr);
fftii_init_two_stage_cancel_count = zeros(nsep, nsnr);
fftii_init_single_peak_fallback_count = zeros(nsep, nsnr);
fftii_fail_init_count = zeros(nsep, nsnr);
fftii_second_peak_ratio_sum = zeros(nsep, nsnr);
fftii_second_peak_ratio_count = zeros(nsep, nsnr);
fftii_init_candidate_rank_sum = zeros(nsep, nsnr);
fftii_init_candidate_rank_count = zeros(nsep, nsnr);
fftii_guard_applied_count = zeros(nsep, nsnr);
fftii_interp_degenerate_count = zeros(nsep, nsnr);
fftii_abs_delta_target1_sum = zeros(nsep, nsnr);
fftii_abs_delta_target2_sum = zeros(nsep, nsnr);
fftii_abs_delta_target_count = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Prototype 5a refined2: FFT-domain cancellation and mu-domain interpolation');
log_lines = append_log(log_lines, 'Routes: baseline / proto4 / proto4b / proto4e / Root-MUSIC / FFT-II refined');
log_lines = append_log(log_lines, 'Fairness rule: each (sep_factor, snr_db, metkl_num) uses an independent fixed RNG seed.');
log_lines = append_log(log_lines, 'base_seed=%d', base_seed);
log_lines = append_log(log_lines, ...
    'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg_abs=%.3f, tol_rel_ratio=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg, tol_rel_ratio);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, ...
    'Route B settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f, Nfft_spatial=%d', ...
    K_fbss, M_full, center_beam_count, search_scale_B, Nfft_spatial);
log_lines = append_log(log_lines, ...
    ['FFT-II settings: D=%d, max_outer_iter=%d, max_iter_refine=%d, ' ...
     'angle_tol_stop_deg=%.4g, residual_change_tol=%.4g, local_refine_step=%.4f'], ...
    D_known, max_outer_iter, max_iter_refine, angle_tol_stop_deg, residual_change_tol, local_refine_step);
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
            [theta_grid_valid, mu_grid_valid, Xfft_valid, Pfft_valid, peak_idx, RecvbeamC_fft] = ...
                calc_spatial_fft_spectrum(y_mean, lambda, d, Nfft_spatial);
            fft_center_error_deg = RecvbeamC_fft - RecvbeamC_true;

            [fwhm_fft_deg, left_idx_half, right_idx_half, used_fallback_fwhm] = ...
                estimate_fft_fwhm(theta_grid_valid, Pfft_valid, peak_idx, theta_search_B_fixed);

            [theta_search_B_4b, routeB_beam_span_4b] = map_fwhm_to_adaptive_window_4b( ...
                fwhm_fft_deg, theta_search_B_fixed, routeB_beam_span_fixed, ...
                gamma_search_4b, gamma_span_4b, search_lower_ratio_4b, search_upper_ratio_4b, ...
                span_lower_ratio_4b, span_upper_ratio_4b);

            [theta_search_B_4e, routeB_beam_span_4e, r_raw_4e, r_search_4e, r_span_4e] = ...
                map_fwhm_to_adaptive_window_piecewise_4e( ...
                fwhm_fft_deg, theta_search_B_fixed, routeB_beam_span_fixed, ...
                gamma_search_4e, beta_span_4e, search_lower_ratio_4e, search_upper_ratio_4e, ...
                span_lower_ratio_4e, span_upper_ratio_4e, piecewise_break1, piecewise_break2, ...
                piecewise_mid_slope, piecewise_high_slope, piecewise_mid_anchor, piecewise_high_anchor);

            fft_center_error_sum(iSep, iSNR) = fft_center_error_sum(iSep, iSNR) + fft_center_error_deg;
            fft_center_error_sumsq(iSep, iSNR) = fft_center_error_sumsq(iSep, iSNR) + fft_center_error_deg^2;
            fwhm_fft_sum(iSep, iSNR) = fwhm_fft_sum(iSep, iSNR) + fwhm_fft_deg;
            fwhm_fft_sumsq(iSep, iSNR) = fwhm_fft_sumsq(iSep, iSNR) + fwhm_fft_deg^2;
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

            Rxx = y * y' / T_snap;
            Rxx = 0.5 * (Rxx + Rxx');
            Rss = mssp_array_fb(Rxx, K_fbss);
            Rss = 0.5 * (Rss + Rss');
            theta_root_music = estimate_root_music_from_fbss_cov(Rss, D_known, lambda, d);
            num_peaks_root = sum(isfinite(theta_root_music));

            theta_min = min(theta_grid_valid);
            theta_max = max(theta_grid_valid);
            [theta_init_fftii, mu_init_fftii, init_mode_fftii, init_peak_idx_fftii, theta_init_stage1, theta_init_stage2, init_alpha_stage1, ...
                theta_init_candidates, candidate_power_list, selected_candidate_rank, second_peak_ratio, num_residual_peak_candidates, Xres1_valid] = ...
                find_top2_fft_initializers_fft_domain( ...
                y_mean, theta_grid_valid, mu_grid_valid, Xfft_valid, Pfft_valid, theta_sep, theta_min, theta_max, lambda, d, Nfft_spatial);

            fftii_info = run_fftii_known2_fft_domain( ...
                y_mean, theta_init_fftii, mu_init_fftii, init_mode_fftii, theta_grid_valid, mu_grid_valid, Xfft_valid, Pfft_valid, ...
                lambda, d, Nfft_spatial, theta_min, theta_max, theta_sep, ...
                max_iter_refine, max_outer_iter, angle_tol_stop_deg, residual_change_tol, local_refine_step);
            theta_fftii = fftii_info.theta_final;
            num_peaks_fftii = sum(isfinite(theta_fftii));

            if strcmp(init_mode_fftii, 'two_stage_cancel_init')
                fftii_init_two_stage_cancel_count(iSep, iSNR) = fftii_init_two_stage_cancel_count(iSep, iSNR) + 1;
            elseif strcmp(init_mode_fftii, 'single_peak_fallback')
                fftii_init_single_peak_fallback_count(iSep, iSNR) = fftii_init_single_peak_fallback_count(iSep, iSNR) + 1;
            else
                fftii_fail_init_count(iSep, iSNR) = fftii_fail_init_count(iSep, iSNR) + 1;
            end

            if isfinite(second_peak_ratio)
                fftii_second_peak_ratio_sum(iSep, iSNR) = fftii_second_peak_ratio_sum(iSep, iSNR) + second_peak_ratio;
                fftii_second_peak_ratio_count(iSep, iSNR) = fftii_second_peak_ratio_count(iSep, iSNR) + 1;
            end
            if isfinite(selected_candidate_rank)
                fftii_init_candidate_rank_sum(iSep, iSNR) = fftii_init_candidate_rank_sum(iSep, iSNR) + selected_candidate_rank;
                fftii_init_candidate_rank_count(iSep, iSNR) = fftii_init_candidate_rank_count(iSep, iSNR) + 1;
            end

            if fftii_info.valid_run
                outer_iter_sum(iSep, iSNR) = outer_iter_sum(iSep, iSNR) + fftii_info.outer_iter_used;
                refine_iter_target1_sum(iSep, iSNR) = refine_iter_target1_sum(iSep, iSNR) + fftii_info.refine_iter_used_target1;
                refine_iter_target2_sum(iSep, iSNR) = refine_iter_target2_sum(iSep, iSNR) + fftii_info.refine_iter_used_target2;
                residual_power_final_sum(iSep, iSNR) = residual_power_final_sum(iSep, iSNR) + fftii_info.residual_power_final;
                fftii_diag_valid_count(iSep, iSNR) = fftii_diag_valid_count(iSep, iSNR) + 1;
                fftii_guard_applied_count(iSep, iSNR) = fftii_guard_applied_count(iSep, iSNR) + sum(fftii_info.guard_applied_trace);
                fftii_interp_degenerate_count(iSep, iSNR) = fftii_interp_degenerate_count(iSep, iSNR) + sum(fftii_info.interp_degenerate_trace(:));
                fftii_abs_delta_target1_sum(iSep, iSNR) = fftii_abs_delta_target1_sum(iSep, iSNR) + sum_nonan(abs(fftii_info.delta_trace_bin(:, 1)));
                fftii_abs_delta_target2_sum(iSep, iSNR) = fftii_abs_delta_target2_sum(iSep, iSNR) + sum_nonan(abs(fftii_info.delta_trace_bin(:, 2)));
                fftii_abs_delta_target_count(iSep, iSNR) = fftii_abs_delta_target_count(iSep, iSNR) + ...
                    sum(isfinite(fftii_info.delta_trace_bin(:, 1))) + sum(isfinite(fftii_info.delta_trace_bin(:, 2)));
            end

            doa_all = {doa_true, doa_proto4, doa_4b, doa_4e, theta_root_music, theta_fftii};
            num_peaks_all = [num_peaks_true, num_peaks_proto4, num_peaks_4b, num_peaks_4e, num_peaks_root, num_peaks_fftii];

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

            if metkl_num == 1
                sample = struct();
                sample.seed_now = seed_now;
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr;
                sample.target_theta = target_theta;
                sample.tol_deg_abs = tol_deg;
                sample.tol_deg_rel = tol_deg_rel;
                sample.y_mean = y_mean;
                sample.RecvbeamC_true = RecvbeamC_true;
                sample.RecvbeamC_fft = RecvbeamC_fft;
                sample.fft_center_error_deg = fft_center_error_deg;
                sample.theta_grid_valid = theta_grid_valid;
                sample.mu_grid_valid = mu_grid_valid;
                sample.Xfft_valid = Xfft_valid;
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
                sample.beam_grid_full_true = beam_grid_full_true;
                sample.beam_grid_center_true = beam_grid_center_true;
                sample.beam_grid_center_fft_proto4 = beam_grid_center_fft_proto4;
                sample.beam_grid_center_fft_4b = beam_grid_center_fft_4b;
                sample.beam_grid_center_fft_4e = beam_grid_center_fft_4e;
                sample.doa_true = doa_true;
                sample.doa_proto4 = doa_proto4;
                sample.doa_4b = doa_4b;
                sample.doa_4e = doa_4e;
                sample.theta_root_music = theta_root_music;
                sample.theta_init_fftii = theta_init_fftii;
                sample.mu_init_fftii = mu_init_fftii;
                sample.theta_init_stage1 = theta_init_stage1;
                sample.theta_init_stage2 = theta_init_stage2;
                sample.init_alpha_stage1 = init_alpha_stage1;
                sample.init_mode_fftii = init_mode_fftii;
                sample.init_peak_idx_fftii = init_peak_idx_fftii;
                sample.theta_init_candidates = theta_init_candidates;
                sample.candidate_power_list = candidate_power_list;
                sample.selected_candidate_rank = selected_candidate_rank;
                sample.second_peak_ratio = second_peak_ratio;
                sample.num_residual_peak_candidates = num_residual_peak_candidates;
                sample.Xres1_valid = Xres1_valid;
                sample.theta_final_fftii = theta_fftii;
                sample.fftii_info = fftii_info;
                sample.num_peaks_true = num_peaks_true;
                sample.num_peaks_proto4 = num_peaks_proto4;
                sample.num_peaks_4b = num_peaks_4b;
                sample.num_peaks_4e = num_peaks_4e;
                sample.num_peaks_root = num_peaks_root;
                sample.num_peaks_fftii = num_peaks_fftii;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        mean_fft_center_error = fft_center_error_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        var_fft_center_error = fft_center_error_sumsq(iSep, iSNR) / diag_count(iSep, iSNR) - mean_fft_center_error^2;
        std_fft_center_error = sqrt(max(var_fft_center_error, 0));

        mean_fwhm_fft = fwhm_fft_sum(iSep, iSNR) / diag_count(iSep, iSNR);
        var_fwhm_fft = fwhm_fft_sumsq(iSep, iSNR) / diag_count(iSep, iSNR) - mean_fwhm_fft^2;
        std_fwhm_fft = sqrt(max(var_fwhm_fft, 0));

        fftii_valid_count_now = max(fftii_diag_valid_count(iSep, iSNR), 1);
        mean_outer_iter_now = outer_iter_sum(iSep, iSNR) / fftii_valid_count_now;
        mean_residual_power_now = residual_power_final_sum(iSep, iSNR) / fftii_valid_count_now;

        log_lines = append_log(log_lines, ...
            ['SNR=%d dB | baseline(abs=%.3f rel=%.3f) proto4(abs=%.3f rel=%.3f) ' ...
             'proto4b(abs=%.3f rel=%.3f) proto4e(abs=%.3f rel=%.3f) ' ...
             'root(abs=%.3f rel=%.3f) fftii(abs=%.3f rel=%.3f) ' ...
             '| fft_err_mean=%.4f std=%.4f | fwhm_mean=%.4f std=%.4f | fftii_outer_mean=%.2f pres_final=%.4e'], ...
            snr, ...
            tol_success_count(1, iSep, iSNR) / Metkl, tol_success_count_rel(1, iSep, iSNR) / Metkl, ...
            tol_success_count(2, iSep, iSNR) / Metkl, tol_success_count_rel(2, iSep, iSNR) / Metkl, ...
            tol_success_count(3, iSep, iSNR) / Metkl, tol_success_count_rel(3, iSep, iSNR) / Metkl, ...
            tol_success_count(4, iSep, iSNR) / Metkl, tol_success_count_rel(4, iSep, iSNR) / Metkl, ...
            tol_success_count(5, iSep, iSNR) / Metkl, tol_success_count_rel(5, iSep, iSNR) / Metkl, ...
            tol_success_count(6, iSep, iSNR) / Metkl, tol_success_count_rel(6, iSep, iSNR) / Metkl, ...
            mean_fft_center_error, std_fft_center_error, mean_fwhm_fft, std_fwhm_fft, ...
            mean_outer_iter_now, mean_residual_power_now);

        if ~isempty(debug_samples{iSep, iSNR})
            sample = debug_samples{iSep, iSNR};
            log_lines = append_log(log_lines, ...
                ['sample metkl=1 | center_true=%.4f center_fft=%.4f err_fft=%.4f fwhm=%.4f ' ...
                 '| init_mode=%s theta_init=[%.4f %.4f] alpha1=[%.4e%+.4ej] ' ...
                 'root=[%.4f %.4f] fftii=[%.4f %.4f] pres_final=%.4e'], ...
                sample.RecvbeamC_true, sample.RecvbeamC_fft, sample.fft_center_error_deg, sample.fwhm_fft_deg, ...
                sample.init_mode_fftii, sample.theta_init_fftii(1), sample.theta_init_fftii(2), ...
                real(sample.init_alpha_stage1), imag(sample.init_alpha_stage1), ...
                safe_get_pair(sample.theta_root_music, 1), safe_get_pair(sample.theta_root_music, 2), ...
                safe_get_pair(sample.theta_final_fftii, 1), safe_get_pair(sample.theta_final_fftii, 2), ...
                sample.fftii_info.residual_power_final);
        end
    end

    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
tol_success_rate_rel = tol_success_count_rel / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;

mean_fft_center_error_deg = fft_center_error_sum ./ max(diag_count, 1);
var_fft_center_error_deg = fft_center_error_sumsq ./ max(diag_count, 1) - mean_fft_center_error_deg.^2;
std_fft_center_error_deg = sqrt(max(var_fft_center_error_deg, 0));

mean_fwhm_fft_deg = fwhm_fft_sum ./ max(diag_count, 1);
var_fwhm_fft_deg = fwhm_fft_sumsq ./ max(diag_count, 1) - mean_fwhm_fft_deg.^2;
std_fwhm_fft_deg = sqrt(max(var_fwhm_fft_deg, 0));

mean_outer_iter_used = outer_iter_sum ./ max(fftii_diag_valid_count, 1);
mean_refine_iter_target1 = refine_iter_target1_sum ./ max(fftii_diag_valid_count, 1);
mean_refine_iter_target2 = refine_iter_target2_sum ./ max(fftii_diag_valid_count, 1);
mean_residual_power_final = residual_power_final_sum ./ max(fftii_diag_valid_count, 1);
fftii_init_two_stage_cancel_rate = fftii_init_two_stage_cancel_count / Metkl;
fftii_init_single_peak_fallback_rate = fftii_init_single_peak_fallback_count / Metkl;
fftii_fail_init_rate = fftii_fail_init_count / Metkl;
fftii_mean_second_peak_ratio = fftii_second_peak_ratio_sum ./ max(fftii_second_peak_ratio_count, 1);
fftii_mean_init_candidate_rank = fftii_init_candidate_rank_sum ./ max(fftii_init_candidate_rank_count, 1);
fftii_two_stage_candidate_found_rate = fftii_init_two_stage_cancel_rate;
fftii_guard_applied_rate = fftii_guard_applied_count ./ max(fftii_diag_valid_count, 1);
fftii_interp_degenerate_rate = fftii_interp_degenerate_count ./ max(2 * fftii_diag_valid_count .* max_outer_iter, 1);
fftii_mean_abs_delta_target1_bin = fftii_abs_delta_target1_sum ./ max(fftii_diag_valid_count .* max_outer_iter, 1);
fftii_mean_abs_delta_target2_bin = fftii_abs_delta_target2_sum ./ max(fftii_diag_valid_count .* max_outer_iter, 1);

rmse = nan(nroutes, nsep, nsnr);
valid_mask = rmse_valid_count > 0;
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ ...
    (2 * rmse_valid_count(valid_mask)));

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
        'SNR90 summary abs01 | bw/%d baseline=%s proto4=%s proto4b=%s proto4e=%s root=%s fftii=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90(1, iSep)), fmt_snr90(snr90(2, iSep)), ...
        fmt_snr90(snr90(3, iSep)), fmt_snr90(snr90(4, iSep)), ...
        fmt_snr90(snr90(5, iSep)), fmt_snr90(snr90(6, iSep)));
    log_lines = append_log(log_lines, ...
        'SNR90 summary rel025 | bw/%d baseline=%s proto4=%s proto4b=%s proto4e=%s root=%s fftii=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90_rel(1, iSep)), fmt_snr90(snr90_rel(2, iSep)), ...
        fmt_snr90(snr90_rel(3, iSep)), fmt_snr90(snr90_rel(4, iSep)), ...
        fmt_snr90(snr90_rel(5, iSep)), fmt_snr90(snr90_rel(6, iSep)));
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
params.tol_deg_abs = tol_deg;
params.tol_rel_ratio = tol_rel_ratio;
params.sep_factor_list = sep_factor_list;
params.search_scale_B = search_scale_B;
params.K_fbss = K_fbss;
params.M_full = M_full;
params.center_beam_count = center_beam_count;
params.Nfft_spatial = Nfft_spatial;
params.D_known = D_known;
params.max_iter_refine = max_iter_refine;
params.max_outer_iter = max_outer_iter;
params.angle_tol_stop_deg = angle_tol_stop_deg;
params.residual_change_tol = residual_change_tol;
params.local_refine_step = local_refine_step;
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

result_dir = fullfile(script_dir, 'results_step8_routeB_fftii_known2_proto5a_refined');
result_dir = fullfile(script_dir, 'results_step8_routeB_fftii_known2_proto5a_refined2');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2_summary.csv');
fid = fopen(csv_path, 'w');
if fid < 0
    error('Failed to open csv file.');
end
fprintf(fid, ['route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
    'raw_success_count,tol_success_count,tol_success_count_rel,raw_success_rate,tol_success_rate,tol_success_rate_rel,' ...
    'rmse_deg,rmse_valid_count,mean_num_peaks,snr90_db,snr90_rel_db,' ...
    'mean_fft_center_error_deg,std_fft_center_error_deg,mean_fwhm_fft_deg,std_fwhm_fft_deg,' ...
    'mean_outer_iter_used,mean_refine_iter_target1,mean_refine_iter_target2,mean_residual_power_final,' ...
    'fftii_init_two_stage_cancel_rate,fftii_init_single_peak_fallback_rate,fftii_fail_init_rate,' ...
    'fftii_mean_second_peak_ratio,fftii_mean_init_candidate_rank,fftii_two_stage_candidate_found_rate,' ...
    'fftii_guard_applied_rate,fftii_interp_degenerate_rate,fftii_mean_abs_delta_target1_bin,fftii_mean_abs_delta_target2_bin\n']);
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, ['%s,%d,%.6f,%.6f,%.6f,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,' ...
                '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6e,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n'], ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
                snr_list(iSNR), raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                tol_success_count_rel(iroute, iSep, iSNR), raw_success_rate(iroute, iSep, iSNR), ...
                tol_success_rate(iroute, iSep, iSNR), tol_success_rate_rel(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), mean_num_peaks(iroute, iSep, iSNR), ...
                snr90(iroute, iSep), snr90_rel(iroute, iSep), ...
                mean_fft_center_error_deg(iSep, iSNR), std_fft_center_error_deg(iSep, iSNR), ...
                mean_fwhm_fft_deg(iSep, iSNR), std_fwhm_fft_deg(iSep, iSNR), ...
                mean_outer_iter_used(iSep, iSNR), mean_refine_iter_target1(iSep, iSNR), ...
                mean_refine_iter_target2(iSep, iSNR), mean_residual_power_final(iSep, iSNR), ...
                fftii_init_two_stage_cancel_rate(iSep, iSNR), fftii_init_single_peak_fallback_rate(iSep, iSNR), ...
                fftii_fail_init_rate(iSep, iSNR), ...
                fftii_mean_second_peak_ratio(iSep, iSNR), fftii_mean_init_candidate_rank(iSep, iSNR), ...
                fftii_two_stage_candidate_found_rate(iSep, iSNR), fftii_guard_applied_rate(iSep, iSNR), ...
                fftii_interp_degenerate_rate(iSep, iSNR), fftii_mean_abs_delta_target1_bin(iSep, iSNR), ...
                fftii_mean_abs_delta_target2_bin(iSep, iSNR));
        end
    end
end
fclose(fid);

keypoint_path = fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2_keypoints.csv');
fid = fopen(keypoint_path, 'w');
if fid < 0
    error('Failed to open keypoint csv file.');
end
fprintf(fid, 'route_name,sep_factor,snr_db,raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,mean_num_peaks\n');
for iSep = 1:nsep
    switch sep_factor_list(iSep)
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
    for kk = 1:numel(key_snr_list)
        snr_now = key_snr_list(kk);
        idx_snr = find(snr_list == snr_now, 1, 'first');
        if isempty(idx_snr)
            continue;
        end
        for iroute = 1:nroutes
            fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                route_names{iroute}, sep_factor_list(iSep), snr_now, ...
                raw_success_rate(iroute, iSep, idx_snr), tol_success_rate(iroute, iSep, idx_snr), ...
                tol_success_rate_rel(iroute, iSep, idx_snr), rmse(iroute, iSep, idx_snr), ...
                mean_num_peaks(iroute, iSep, idx_snr));
        end
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2_result.mat');
save(mat_path, ...
    'params', 'route_names', 'sep_factor_list', 'snr_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_count', 'tol_success_count', 'tol_success_count_rel', 'raw_success_rate', 'tol_success_rate', 'tol_success_rate_rel', ...
    'rmse_sum_sqerr', 'rmse_valid_count', 'rmse', 'sum_num_peaks', 'mean_num_peaks', 'snr90', 'snr90_rel', ...
    'mean_fft_center_error_deg', 'std_fft_center_error_deg', 'mean_fwhm_fft_deg', 'std_fwhm_fft_deg', ...
    'mean_outer_iter_used', 'mean_refine_iter_target1', 'mean_refine_iter_target2', 'mean_residual_power_final', ...
    'fftii_init_two_stage_cancel_rate', 'fftii_init_single_peak_fallback_rate', 'fftii_fail_init_rate', ...
    'fftii_mean_second_peak_ratio', 'fftii_mean_init_candidate_rank', 'fftii_two_stage_candidate_found_rate', ...
    'fftii_guard_applied_rate', 'fftii_interp_degenerate_rate', 'fftii_mean_abs_delta_target1_bin', 'fftii_mean_abs_delta_target2_bin', ...
    'debug_samples');

fig1 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(tol_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.0);
    hold on
    plot(snr_list, squeeze(tol_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.0);
    plot(snr_list, squeeze(tol_success_rate(3, iSep, :)), '-^', 'LineWidth', 1.0);
    plot(snr_list, squeeze(tol_success_rate(4, iSep, :)), '-d', 'LineWidth', 1.0);
    plot(snr_list, squeeze(tol_success_rate(5, iSep, :)), '-x', 'LineWidth', 1.0);
    plot(snr_list, squeeze(tol_success_rate(6, iSep, :)), '-p', 'LineWidth', 1.0);
    hold off
    grid on
    ylabel('tol success');
    title(sprintf('Prototype 5a refined tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
save_figure_png_safe(fig1, fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2_tol_success.png'));
close(fig1)

fig2 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(rmse(1, iSep, :)), '-o', 'LineWidth', 1.0);
    hold on
    plot(snr_list, squeeze(rmse(2, iSep, :)), '-s', 'LineWidth', 1.0);
    plot(snr_list, squeeze(rmse(3, iSep, :)), '-^', 'LineWidth', 1.0);
    plot(snr_list, squeeze(rmse(4, iSep, :)), '-d', 'LineWidth', 1.0);
    plot(snr_list, squeeze(rmse(5, iSep, :)), '-x', 'LineWidth', 1.0);
    plot(snr_list, squeeze(rmse(6, iSep, :)), '-p', 'LineWidth', 1.0);
    hold off
    grid on
    ylabel('RMSE (deg)');
    title(sprintf('Prototype 5a refined RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
save_figure_png_safe(fig2, fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2_rmse.png'));
close(fig2)

fig3 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(raw_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.0);
    hold on
    plot(snr_list, squeeze(raw_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.0);
    plot(snr_list, squeeze(raw_success_rate(3, iSep, :)), '-^', 'LineWidth', 1.0);
    plot(snr_list, squeeze(raw_success_rate(4, iSep, :)), '-d', 'LineWidth', 1.0);
    plot(snr_list, squeeze(raw_success_rate(5, iSep, :)), '-x', 'LineWidth', 1.0);
    plot(snr_list, squeeze(raw_success_rate(6, iSep, :)), '-p', 'LineWidth', 1.0);
    hold off
    grid on
    ylabel('raw success');
    title(sprintf('Prototype 5a refined raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
save_figure_png_safe(fig3, fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2_raw_success.png'));
close(fig3)

fig4 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(mean_num_peaks(1, iSep, :)), '-o', 'LineWidth', 1.0);
    hold on
    plot(snr_list, squeeze(mean_num_peaks(2, iSep, :)), '-s', 'LineWidth', 1.0);
    plot(snr_list, squeeze(mean_num_peaks(3, iSep, :)), '-^', 'LineWidth', 1.0);
    plot(snr_list, squeeze(mean_num_peaks(4, iSep, :)), '-d', 'LineWidth', 1.0);
    plot(snr_list, squeeze(mean_num_peaks(5, iSep, :)), '-x', 'LineWidth', 1.0);
    plot(snr_list, squeeze(mean_num_peaks(6, iSep, :)), '-p', 'LineWidth', 1.0);
    hold off
    grid on
    ylabel('mean peaks');
    title(sprintf('Prototype 5a refined mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
save_figure_png_safe(fig4, fullfile(result_dir, 'step8_routeB_fftii_known2_proto5a_refined2_mean_num_peaks.png'));
close(fig4)

disp('Step 08 Prototype 5a refined2 finished.');
disp('route_names =');
disp(route_names);
disp('snr90_abs =');
disp(snr90);
disp('snr90_rel =');
disp(snr90_rel);
disp('result_dir =');
disp(result_dir);

function [theta_grid_valid, mu_grid_valid, Xfft_valid, Pfft_valid, peak_idx, center_deg] = calc_spatial_fft_spectrum(y_mean, lambda, d, Nfft_spatial)
    Yfft = fftshift(fft(y_mean, Nfft_spatial));
    Pfft = abs(Yfft).^2;

    k = (-Nfft_spatial/2):(Nfft_spatial/2 - 1);
    mu = k / Nfft_spatial;
    sin_theta = -mu * lambda / d;
    valid_mask = abs(sin_theta) <= 1;

    theta_grid_valid = asind(sin_theta(valid_mask));
    mu_grid_valid = mu(valid_mask);
    Xfft_valid = Yfft(valid_mask);
    Pfft_valid = Pfft(valid_mask);
    [~, peak_idx] = max(Pfft_valid);
    center_deg = theta_grid_valid(peak_idx);
end

function mu = theta_to_mu(theta_deg, lambda, d)
    mu = -d * sind(theta_deg) / lambda;
end

function theta_deg = mu_to_theta(mu, lambda, d)
    sin_theta = -mu * lambda / d;
    sin_theta = min(max(real(sin_theta), -1), 1);
    theta_deg = asind(sin_theta);
end

function Xmu = eval_dft_at_mu(y_mean, mu_query)
    n = (0:numel(y_mean)-1).';
    mu_query = mu_query(:).';
    Xmu = zeros(1, numel(mu_query));
    for ii = 1:numel(mu_query)
        Xmu(ii) = sum(y_mean(:) .* exp(-1j * 2 * pi * n * mu_query(ii)));
    end
end

function kernel_val = dirichlet_kernel(mu_src, mu_query, M)
    mu_query = mu_query(:).';
    delta_mu = mu_src - mu_query;
    kernel_val = zeros(size(mu_query));
    tol = 1e-12;
    hit_same = abs(delta_mu) < tol;
    kernel_val(hit_same) = 1;
    idx = ~hit_same;
    if any(idx)
        nume = 1 - exp(1j * 2 * pi * M * delta_mu(idx));
        deno = 1 - exp(1j * 2 * pi * delta_mu(idx));
        kernel_val(idx) = nume ./ deno;
    end
end

function Xres_valid = build_fft_residual_valid(Xfft_valid, mu_grid_valid, mu_est, alpha_est, M)
    Xres_valid = Xfft_valid(:).';
    for ii = 1:numel(mu_est)
        if ~isfinite(mu_est(ii)) || ~isfinite(alpha_est(ii))
            continue;
        end
        Xres_valid = Xres_valid - alpha_est(ii) .* dirichlet_kernel(mu_est(ii), mu_grid_valid, M);
    end
    Xres_valid = Xres_valid(:);
end

function [theta_init, mu_init, init_mode, init_peak_idx, theta_init_1, theta_init_2, alpha_stage1, ...
    theta_init_candidates, candidate_power_list, selected_candidate_rank, second_peak_ratio, num_residual_peak_candidates, Xres1_valid] = ...
    find_top2_fft_initializers_fft_domain(y_mean, theta_grid_valid, mu_grid_valid, Xfft_valid, Pfft_valid, theta_sep, theta_min, theta_max, lambda, d, Nfft_spatial)
    theta_init = [NaN, NaN];
    mu_init = [NaN, NaN];
    init_mode = 'fail_init';
    init_peak_idx = [NaN, NaN];
    theta_init_1 = NaN;
    theta_init_2 = NaN;
    alpha_stage1 = NaN;
    theta_init_candidates = [];
    candidate_power_list = [];
    selected_candidate_rank = NaN;
    second_peak_ratio = NaN;
    num_residual_peak_candidates = 0;
    Xres1_valid = nan(size(Xfft_valid));
    max_init_candidate_count = 12;
    M = numel(y_mean);

    [~, main_idx] = max(Pfft_valid);
    theta_init_1 = theta_grid_valid(main_idx);
    mu1_init = mu_grid_valid(main_idx);
    alpha_stage1 = eval_dft_at_mu(y_mean, mu1_init) / M;

    Xres1_valid = Xfft_valid(:).' - alpha_stage1 .* dirichlet_kernel(mu1_init, mu_grid_valid, M);
    Pres1_valid = abs(Xres1_valid).^2;
    [peak_val_res, peak_ind_res] = FindLocalPeak_NoEdge_Fun(Pres1_valid);

    power_main = max(Pfft_valid(main_idx), eps);
    min_sep_deg = max(0.12 * theta_sep, 0.03);
    max_sep_deg = max(5 * theta_sep, 1.0);
    same_peak_exclusion_deg = max(0.08 * theta_sep, 0.02);
    num_residual_peak_candidates = min(numel(peak_ind_res), max_init_candidate_count);

    if num_residual_peak_candidates > 0
        peak_ind_res = peak_ind_res(1:num_residual_peak_candidates);
        peak_val_res = peak_val_res(1:num_residual_peak_candidates);
        theta_init_candidates = theta_grid_valid(peak_ind_res);
        candidate_power_list = peak_val_res;
        second_peak_ratio = peak_val_res(1) / power_main;

        for icand = 1:numel(peak_ind_res)
            second_idx = peak_ind_res(icand);
            theta_candidate = theta_grid_valid(second_idx);
            power_second = peak_val_res(icand);
            sep_now = abs(theta_candidate - theta_init_1);
            if ~isfinite(theta_candidate)
                continue;
            end
            if sep_now < min_sep_deg || sep_now > max_sep_deg
                continue;
            end
            if sep_now <= same_peak_exclusion_deg
                continue;
            end
            if power_second < 0.05 * power_main
                continue;
            end

            theta_init_2 = theta_candidate;
            theta_init = sort([theta_init_1, theta_init_2]);
            mu_init = sort(theta_to_mu(theta_init, lambda, d));
            init_mode = 'two_stage_cancel_init';
            init_peak_idx = [main_idx, second_idx];
            selected_candidate_rank = icand;
            return;
        end
    end

    theta_init = sort([theta_init_1 - 0.5 * theta_sep, theta_init_1 + 0.5 * theta_sep]);
    theta_init(1) = max(theta_init(1), theta_min);
    theta_init(2) = min(theta_init(2), theta_max);
    theta_init_2 = theta_init(2);
    mu_init = sort(theta_to_mu(theta_init, lambda, d));
    init_peak_idx = [main_idx, main_idx];

    if all(isfinite(theta_init)) && theta_init(2) > theta_init(1)
        init_mode = 'single_peak_fallback';
    else
        theta_init = [NaN, NaN];
        mu_init = [NaN, NaN];
        theta_init_2 = NaN;
        init_mode = 'fail_init';
    end
end

function theta_est = estimate_root_music_from_fbss_cov(Rss, D, lambda, d)
    theta_est = nan(1, D);

    if any(~isfinite(Rss(:)))
        return;
    end

    Rss = 0.5 * (Rss + Rss');
    [V, Dm] = eig(Rss);
    eigvals = real(diag(Dm));
    [~, idx] = sort(eigvals, 'descend');
    V = V(:, idx);
    if size(V, 2) <= D
        return;
    end

    En = V(:, D+1:end);
    C = En * En';
    M = size(Rss, 1);
    poly_coeffs = zeros(1, 2 * M - 1);

    lag_list = -(M-1):(M-1);
    for ii = 1:numel(lag_list)
        poly_coeffs(ii) = sum(diag(C, lag_list(ii)));
    end

    rts = roots(fliplr(poly_coeffs));
    if isempty(rts)
        return;
    end

    inside_roots = rts(abs(rts) < 1);
    if numel(inside_roots) < D
        return;
    end

    [~, ord] = sort(abs(abs(inside_roots) - 1), 'ascend');
    chosen = inside_roots(ord(1:D));
    omega = angle(chosen);
    sin_theta = -(lambda / (2 * pi * d)) * omega;
    if sum(abs(sin_theta) <= 1 + 1e-9) < D
        return;
    end

    sin_theta = min(max(real(sin_theta), -1), 1);
    theta_est = sort(asind(sin_theta)).';
    if numel(theta_est) ~= D || any(~isfinite(theta_est))
        theta_est = nan(1, D);
    end
end

function alpha_hat = estimate_complex_amplitude_ls(y_mean, theta_deg, lambda, d)
    alpha_hat = estimate_joint_amplitudes_ls(y_mean, theta_deg, lambda, d);
    if numel(alpha_hat) ~= 1
        alpha_hat = NaN;
    end
end

function alpha_hat = estimate_joint_amplitudes_ls(y_mean, theta_deg_list, lambda, d)
    theta_deg_list = theta_deg_list(:).';
    n = (0:numel(y_mean)-1).';
    A = zeros(numel(y_mean), numel(theta_deg_list));
    for ii = 1:numel(theta_deg_list)
        if ~isfinite(theta_deg_list(ii))
            alpha_hat = nan(numel(theta_deg_list), 1);
            return;
        end
        A(:, ii) = exp(-1j * 2 * pi * d * n * sind(theta_deg_list(ii)) / lambda);
    end

    if rank(A) < min(size(A))
        alpha_hat = nan(numel(theta_deg_list), 1);
        return;
    end

    alpha_hat = pinv(A) * y_mean;
end

function y_cancel = cancel_other_components_from_mean_snapshot(y_mean, theta_all, target_idx, lambda, d)
    y_cancel = y_mean;
    alpha_all = estimate_joint_amplitudes_ls(y_mean, theta_all, lambda, d);
    if any(~isfinite(alpha_all))
        return;
    end

    n = (0:numel(y_mean)-1).';
    for ii = 1:numel(theta_all)
        if ii == target_idx || ~isfinite(theta_all(ii))
            continue;
        end
        a_theta = exp(-1j * 2 * pi * d * n * sind(theta_all(ii)) / lambda);
        y_cancel = y_cancel - alpha_all(ii) * a_theta;
    end
end

function refine_info = refine_single_target_fftii(y_residual, theta_init, lambda, d, theta_min, theta_max, theta_sep, max_iter_refine, local_refine_step)
    refine_info = struct();
    refine_info.theta_refined = theta_init;
    refine_info.iter_used = 0;
    refine_info.local_peak_idx = NaN;
    refine_info.delta_bin = NaN;
    refine_info.local_theta_grid = [];
    refine_info.local_metric = [];

    if ~isfinite(theta_init)
        refine_info.theta_refined = NaN;
        return;
    end

    theta_old = theta_init;
    n = (0:numel(y_residual)-1).';

    for iter = 1:max_iter_refine
        local_half_width = max(0.8 * theta_sep, 0.20);
        theta_left = max(theta_min, theta_old - local_half_width);
        theta_right = min(theta_max, theta_old + local_half_width);
        theta_local = theta_left:local_refine_step:theta_right;
        if numel(theta_local) < 3
            theta_local = linspace(theta_left, theta_right, 3);
        end

        local_metric = zeros(size(theta_local));
        for kk = 1:numel(theta_local)
            a_theta = exp(-1j * 2 * pi * d * n * sind(theta_local(kk)) / lambda);
            local_metric(kk) = abs(a_theta' * y_residual)^2 / max(real(a_theta' * a_theta), eps);
        end

        [~, peak_idx] = max(local_metric);
        if peak_idx == 1 || peak_idx == numel(local_metric)
            delta = 0;
            theta_new = theta_local(peak_idx);
        else
            pL = local_metric(peak_idx - 1);
            pC = local_metric(peak_idx);
            pR = local_metric(peak_idx + 1);
            denom = pL - 2 * pC + pR;
            if abs(denom) < eps
                delta = 0;
            else
                delta = 0.5 * (pL - pR) / denom;
                delta = min(max(delta, -1), 1);
            end
            theta_new = theta_local(peak_idx) + delta * local_refine_step;
        end

        theta_new = min(max(theta_new, theta_min), theta_max);
        refine_info.iter_used = iter;
        refine_info.local_peak_idx = peak_idx;
        refine_info.delta_bin = delta;
        refine_info.local_theta_grid = theta_local;
        refine_info.local_metric = local_metric;

        if abs(theta_new - theta_old) < 1e-3
            theta_old = theta_new;
            break;
        end

        theta_old = theta_new;
    end

    refine_info.theta_refined = theta_old;
end

function [delta_bin, alpha_new, interp_degenerate, p_eff] = update_single_target_fft_interp( ...
    y_mean, mu_est, alpha_est, target_idx, mu_grid_valid, M)
    interp_degenerate = false;
    delta_bin = NaN;
    alpha_new = alpha_est(target_idx);
    p_interp = 0.5;

    mu_now = mu_est(target_idx);
    if ~isfinite(mu_now)
        interp_degenerate = true;
        p_eff = NaN;
        return;
    end

    [~, nearest_idx] = min(abs(mu_grid_valid - mu_now));
    if nearest_idx <= 1 || nearest_idx >= numel(mu_grid_valid)
        interp_degenerate = true;
        p_eff = NaN;
        return;
    end

    mu_step = median(diff(mu_grid_valid));
    dist_edge_bins = min(nearest_idx - 1, numel(mu_grid_valid) - nearest_idx);
    p_eff = min(p_interp, dist_edge_bins - 0.05);
    if ~(isfinite(p_eff) && p_eff >= 0.2)
        interp_degenerate = true;
        return;
    end

    mu_center = mu_grid_valid(nearest_idx);
    mu_plus = mu_center + p_eff * mu_step;
    mu_minus = mu_center - p_eff * mu_step;

    X_plus = eval_dft_at_mu(y_mean, mu_plus);
    X_minus = eval_dft_at_mu(y_mean, mu_minus);

    leakage_plus = 0;
    leakage_minus = 0;
    leakage_center = 0;
    for ii = 1:numel(mu_est)
        if ii == target_idx || ~isfinite(mu_est(ii)) || ~isfinite(alpha_est(ii))
            continue;
        end
        leakage_plus = leakage_plus + alpha_est(ii) .* dirichlet_kernel(mu_est(ii), mu_plus, M);
        leakage_minus = leakage_minus + alpha_est(ii) .* dirichlet_kernel(mu_est(ii), mu_minus, M);
        leakage_center = leakage_center + alpha_est(ii) .* dirichlet_kernel(mu_est(ii), mu_now, M);
    end

    Xr_plus = X_plus - leakage_plus;
    Xr_minus = X_minus - leakage_minus;
    denom = Xr_plus - Xr_minus;
    if abs(denom) < 1e-12
        interp_degenerate = true;
        return;
    end

    delta_bin = 0.5 * real((Xr_plus + Xr_minus) / denom);
    if ~isfinite(delta_bin)
        interp_degenerate = true;
        return;
    end
    delta_bin = min(max(delta_bin, -p_eff), p_eff);

    matched_sum = eval_dft_at_mu(y_mean, mu_now);
    alpha_new = (matched_sum - leakage_center) / M;
end

function refine_info = refine_single_target_fftii_theta_fallback(y_residual, theta_init, lambda, d, theta_min, theta_max, theta_sep, local_refine_step)
    refine_info = refine_single_target_fftii(y_residual, theta_init, lambda, d, theta_min, theta_max, theta_sep, 1, local_refine_step);
end

function theta_est = apply_sep_guard(theta_est, y_mean, lambda, d, min_sep_guard)
    theta_est = sort(theta_est(:).');
    if numel(theta_est) ~= 2 || any(~isfinite(theta_est))
        return;
    end

    sep_now = abs(theta_est(2) - theta_est(1));
    if sep_now >= min_sep_guard
        return;
    end

    alpha_hat = estimate_joint_amplitudes_ls(y_mean, theta_est, lambda, d);
    if any(~isfinite(alpha_hat))
        theta_mid = mean(theta_est);
        theta_est = [theta_mid - min_sep_guard / 2, theta_mid + min_sep_guard / 2];
        return;
    end

    [~, weak_idx] = min(abs(alpha_hat));
    if weak_idx == 1
        theta_est(1) = theta_est(2) - min_sep_guard;
    else
        theta_est(2) = theta_est(1) + min_sep_guard;
    end
    theta_est = sort(theta_est);
end

function fftii_info = run_fftii_known2_fft_domain(y_mean, theta_init, mu_init, init_mode, theta_grid_valid, mu_grid_valid, Xfft_valid, Pfft_valid, ...
    lambda, d, Nfft_spatial, theta_min, theta_max, theta_sep, max_iter_refine, max_outer_iter, angle_tol_stop_deg, residual_change_tol, local_refine_step)
    fftii_info = struct();
    fftii_info.theta_final = [NaN, NaN];
    fftii_info.mu_final = [NaN, NaN];
    fftii_info.valid_run = false;
    fftii_info.outer_iter_used = 0;
    fftii_info.refine_iter_used_target1 = 0;
    fftii_info.refine_iter_used_target2 = 0;
    fftii_info.residual_power_final = NaN;
    fftii_info.residual_power_trace = nan(max_outer_iter, 1);
    fftii_info.angle_update_trace = nan(max_outer_iter, 1);
    fftii_info.theta_trace = nan(max_outer_iter, 2);
    fftii_info.mu_trace = nan(max_outer_iter, 2);
    fftii_info.alpha_trace = nan(max_outer_iter, 2);
    fftii_info.delta_trace_bin = nan(max_outer_iter, 2);
    fftii_info.guard_applied_trace = false(max_outer_iter, 1);
    fftii_info.interp_degenerate_trace = false(max_outer_iter, 2);
    fftii_info.theta_init = theta_init;
    fftii_info.mu_init = mu_init;
    fftii_info.init_mode = init_mode;
    fftii_info.primary_peak_idx = NaN;
    fftii_info.alpha_hat_final = [NaN; NaN];
    fftii_info.X_res_valid_final = nan(size(Xfft_valid));

    if any(~isfinite(theta_init)) || any(~isfinite(mu_init)) || strcmp(init_mode, 'fail_init')
        return;
    end

    theta_est = sort(theta_init(:).');
    mu_est = sort(mu_init(:).');
    alpha_est = estimate_joint_amplitudes_ls(y_mean, theta_est, lambda, d).';
    residual_prev = Inf;
    min_sep_guard = max(0.10 * theta_sep, 0.03);
    M = numel(y_mean);

    for outer = 1:max_outer_iter
        theta_prev = theta_est;
        if any(~isfinite(alpha_est))
            alpha_est = estimate_joint_amplitudes_ls(y_mean, theta_est, lambda, d).';
        end

        for target_idx = 1:2
            [delta_bin, alpha_new, interp_degenerate, ~] = update_single_target_fft_interp( ...
                y_mean, mu_est, alpha_est, target_idx, mu_grid_valid, M);
            fftii_info.delta_trace_bin(outer, target_idx) = delta_bin;
            fftii_info.interp_degenerate_trace(outer, target_idx) = interp_degenerate;

            if interp_degenerate
                other_idx = 3 - target_idx;
                y_residual = y_mean;
                if isfinite(alpha_est(other_idx))
                    a_other = exp(-1j * 2 * pi * (0:numel(y_mean)-1).' * mu_est(other_idx));
                    y_residual = y_residual - alpha_est(other_idx) * a_other;
                end
                refine_fallback = refine_single_target_fftii_theta_fallback( ...
                    y_residual, theta_est(target_idx), lambda, d, theta_min, theta_max, theta_sep, local_refine_step);
                theta_est(target_idx) = refine_fallback.theta_refined;
                mu_est(target_idx) = theta_to_mu(theta_est(target_idx), lambda, d);
            else
                mu_step = median(diff(mu_grid_valid));
                mu_est(target_idx) = mu_est(target_idx) + delta_bin * mu_step;
                theta_est(target_idx) = mu_to_theta(mu_est(target_idx), lambda, d);
                alpha_est(target_idx) = alpha_new;
            end
        end

        theta_est = sort(theta_est);
        mu_est = sort(theta_to_mu(theta_est, lambda, d));
        theta_est = apply_sep_guard(theta_est, y_mean, lambda, d, min_sep_guard);
        theta_after_guard = theta_est;
        theta_est = sort(theta_est);
        mu_est = sort(theta_to_mu(theta_est, lambda, d));
        fftii_info.guard_applied_trace(outer) = any(abs(theta_after_guard - sort(theta_prev)) > 0);

        alpha_hat = estimate_joint_amplitudes_ls(y_mean, theta_est, lambda, d).';
        alpha_est = alpha_hat;
        X_res_valid = build_fft_residual_valid(Xfft_valid, mu_grid_valid, mu_est, alpha_est, M);
        residual_power = mean(abs(X_res_valid).^2);
        angle_update = max(abs(theta_est - theta_prev));

        fftii_info.outer_iter_used = outer;
        fftii_info.residual_power_trace(outer) = residual_power;
        fftii_info.angle_update_trace(outer) = angle_update;
        fftii_info.theta_trace(outer, :) = theta_est;
        fftii_info.mu_trace(outer, :) = mu_est;
        fftii_info.alpha_trace(outer, :) = alpha_est;
        fftii_info.alpha_hat_final = alpha_hat(:);
        fftii_info.X_res_valid_final = X_res_valid;

        residual_change = abs(residual_prev - residual_power) / max(residual_prev, eps);
        residual_prev = residual_power;

        if angle_update < angle_tol_stop_deg || residual_change < residual_change_tol
            break;
        end
    end

    fftii_info.theta_final = theta_est;
    fftii_info.mu_final = mu_est;
    fftii_info.valid_run = all(isfinite(theta_est));
    fftii_info.residual_power_final = residual_prev;
    [~, primary_peak_idx] = max(Pfft_valid);
    fftii_info.primary_peak_idx = primary_peak_idx;
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

function [theta_search_B_adapt, routeB_beam_span_adapt, r_raw, r_search_piecewise, r_span_piecewise] = ...
    map_fwhm_to_adaptive_window_piecewise_4e( ...
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

function v = safe_get_pair(x, idx)
    if numel(x) >= idx && isfinite(x(idx))
        v = x(idx);
    else
        v = NaN;
    end
end

function s = sum_nonan(x)
    x = x(isfinite(x));
    if isempty(x)
        s = 0;
    else
        s = sum(x);
    end
end

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end

function save_figure_png_safe(fig_handle, out_path)
    set(fig_handle, 'PaperPositionMode', 'auto');
    try
        print(fig_handle, out_path, '-dpng', '-r150');
    catch
        try
            exportgraphics(fig_handle, out_path, 'Resolution', 150);
        catch export_err
            error('Failed to save figure to %s: %s', out_path, export_err.message);
        end
    end
end
