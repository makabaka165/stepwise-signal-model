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

route_names = {'baseline_centerT', 'cov_residual_refine_centerT'};
nroutes = numel(route_names);
j = sqrt(-1);
t = linspace(0, 1, T_snap);

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count = zeros(nroutes, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nsep, nsnr);
sum_num_peaks = zeros(nroutes, nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Route B covariance residual refine prototype 3');
log_lines = append_log(log_lines, 'Prototype scope: keep Route B baseline framing, add beamspace covariance residual cancellation and single-target second-pass refinement.');
log_lines = append_log(log_lines, 'Route comparison: baseline_centerT vs cov_residual_refine_centerT.');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B internal settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, 'Residual refine rule: dominant peak chosen by baseline peak height, beamspace rank-1 covariance cancellation, PSD projection, and guard-band protected second-pass refinement.');
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

    full_beam_count = numel(beam_grid_full_deg);
    center_idx = floor((full_beam_count + 1) / 2);
    half_left = floor((center_beam_count - 1) / 2);
    half_right = center_beam_count - half_left - 1;
    center_indices = (center_idx - half_left):(center_idx + half_right);
    beam_grid_center_deg = beam_grid_full_deg(center_indices);

    posK = d * (0:K_fbss-1).';
    Wcenter_base = exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg));
    [Tk_base, ~] = qr(Wcenter_base, 0);
    cond_Wcenter_base = cond(Wcenter_base);

    theta_sep_deg(iSep) = theta_sep;
    theta_a_deg(iSep) = theta_a;
    theta_b_deg(iSep) = theta_b;

    log_lines = append_log(log_lines, '=== sep_factor = %d, theta_sep = %.4f deg ===', sep_factor, theta_sep);

    for iSNR = 1:nsnr
        snr = snr_list(iSNR);
        guard_band_deg = max(0.05, 0.15 * theta_sep);
        insufficient_first_pass_count = 0;
        no_refined_peak_count = 0;

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

            [doa_baseline, num_peaks_baseline] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_base, RecvbeamC, theta_search_B);

            [angle_search, P_coarse, peak_angles, peak_values, Rb_base, eigvals_base] = ...
                calc_routeB_music_spectrum(y, K_fbss, Tk_base, RecvbeamC, theta_search_B, 2);

            proto3 = struct();
            proto3.reason = 'ok';
            proto3.theta_dom = NaN;
            proto3.theta_other_init = NaN;
            proto3.theta_refined = NaN;
            proto3.dominant_peak_value = NaN;
            proto3.secondary_peak_value = NaN;
            proto3.alpha_dom = NaN;
            proto3.guard_band_deg = guard_band_deg;
            proto3.min_eig_before_psd = NaN;
            proto3.num_negative_eigs = NaN;
            proto3.min_eig_after_psd = NaN;
            proto3.num_peaks_proto3 = 0;
            proto3.peak_angles = peak_angles;
            proto3.peak_values = peak_values;
            proto3.angle_search_res = angle_search;
            proto3.P_residual = nan(size(P_coarse));

            if numel(peak_angles) < 2
                doa_proto3 = [NaN NaN];
                insufficient_first_pass_count = insufficient_first_pass_count + 1;
                proto3.reason = 'insufficient_first_pass_peaks';
            else
                theta_dom = peak_angles(1);
                theta_other_init = peak_angles(2);
                dominant_peak_value = peak_values(1);
                secondary_peak_value = peak_values(2);

                [alpha_dom, b_dom] = estimate_dominant_component_ls(Rb_base, Tk_base, posK, lambda, theta_dom);
                R_dom = alpha_dom * (b_dom * b_dom');
                R_res = Rb_base - R_dom;
                R_res = 0.5 * (R_res + R_res');

                eigvals_before = real(eig(R_res));
                min_eig_before_psd = min(eigvals_before);
                num_negative_eigs = sum(eigvals_before < -1e-10);

                [R_res_psd, eigvals_after] = project_psd_hermitian(R_res);
                min_eig_after_psd = min(real(eigvals_after));

                [theta_refined, P_residual, num_peaks_residual] = ...
                    find_refined_secondary_from_residual( ...
                    R_res_psd, Tk_base, posK, lambda, RecvbeamC, theta_search_B, theta_dom, guard_band_deg);

                doa_proto3 = sort([theta_dom, theta_refined]);
                proto3.theta_dom = theta_dom;
                proto3.theta_other_init = theta_other_init;
                proto3.theta_refined = theta_refined;
                proto3.dominant_peak_value = dominant_peak_value;
                proto3.secondary_peak_value = secondary_peak_value;
                proto3.alpha_dom = alpha_dom;
                proto3.min_eig_before_psd = min_eig_before_psd;
                proto3.num_negative_eigs = num_negative_eigs;
                proto3.min_eig_after_psd = min_eig_after_psd;
                proto3.num_peaks_proto3 = num_peaks_residual;
                proto3.P_residual = P_residual;

                if ~isfinite(theta_refined)
                    no_refined_peak_count = no_refined_peak_count + 1;
                    proto3.reason = 'no_refined_secondary_peak';
                end
            end

            raw_ok_baseline = all(isfinite(doa_baseline));
            tol_ok_baseline = is_valid_doa_success(doa_baseline, target_theta, tol_deg);
            if raw_ok_baseline
                raw_success_count(1, iSep, iSNR) = raw_success_count(1, iSep, iSNR) + 1;
                sqerr_baseline = sum((sort(doa_baseline(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(1, iSep, iSNR) = rmse_sum_sqerr(1, iSep, iSNR) + sqerr_baseline;
                rmse_valid_count(1, iSep, iSNR) = rmse_valid_count(1, iSep, iSNR) + 1;
            end
            if tol_ok_baseline
                tol_success_count(1, iSep, iSNR) = tol_success_count(1, iSep, iSNR) + 1;
            end
            sum_num_peaks(1, iSep, iSNR) = sum_num_peaks(1, iSep, iSNR) + num_peaks_baseline;

            raw_ok_proto3 = all(isfinite(doa_proto3));
            tol_ok_proto3 = is_valid_doa_success(doa_proto3, target_theta, tol_deg);
            if raw_ok_proto3
                raw_success_count(2, iSep, iSNR) = raw_success_count(2, iSep, iSNR) + 1;
                sqerr_proto3 = sum((sort(doa_proto3(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(2, iSep, iSNR) = rmse_sum_sqerr(2, iSep, iSNR) + sqerr_proto3;
                rmse_valid_count(2, iSep, iSNR) = rmse_valid_count(2, iSep, iSNR) + 1;
            end
            if tol_ok_proto3
                tol_success_count(2, iSep, iSNR) = tol_success_count(2, iSep, iSNR) + 1;
            end
            sum_num_peaks(2, iSep, iSNR) = sum_num_peaks(2, iSep, iSNR) + proto3.num_peaks_proto3;

            if metkl_num == 1
                sample = struct();
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr;
                sample.target_theta = target_theta;
                sample.RecvbeamC = RecvbeamC;
                sample.theta_search_B = theta_search_B;
                sample.beam_grid_center_deg = beam_grid_center_deg;
                sample.cond_Wcenter_base = cond_Wcenter_base;
                sample.angle_search = angle_search;
                sample.P_coarse = P_coarse;
                sample.peak_angles = peak_angles;
                sample.peak_values = peak_values;
                sample.Rb_base = Rb_base;
                sample.eigvals_base = eigvals_base;
                sample.doa_baseline = doa_baseline;
                sample.num_peaks_baseline = num_peaks_baseline;
                sample.doa_proto3 = doa_proto3;
                sample.proto3 = proto3;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        current_rmse_baseline = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 1, iSep, iSNR);
        current_rmse_proto3 = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 2, iSep, iSNR);

        raw_rate_baseline = raw_success_count(1, iSep, iSNR) / Metkl;
        raw_rate_proto3 = raw_success_count(2, iSep, iSNR) / Metkl;
        tol_rate_baseline = tol_success_count(1, iSep, iSNR) / Metkl;
        tol_rate_proto3 = tol_success_count(2, iSep, iSNR) / Metkl;
        mean_num_peaks_baseline = sum_num_peaks(1, iSep, iSNR) / Metkl;
        mean_num_peaks_proto3 = sum_num_peaks(2, iSep, iSNR) / Metkl;

        sample = debug_samples{iSep, iSNR};
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | baseline raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(1, iSep, iSNR), tol_success_count(1, iSep, iSNR), ...
            raw_rate_baseline, tol_rate_baseline, current_rmse_baseline, mean_num_peaks_baseline);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | proto3 raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f insufficient_first_pass=%d no_refined_peak=%d', ...
            snr, raw_success_count(2, iSep, iSNR), tol_success_count(2, iSep, iSNR), ...
            raw_rate_proto3, tol_rate_proto3, current_rmse_proto3, mean_num_peaks_proto3, ...
            insufficient_first_pass_count, no_refined_peak_count);
        log_lines = append_log(log_lines, ...
            'sample metkl=1 | doa_base=%s doa_proto3=%s dom=%.4f other_init=%.4f refined=%.4f alpha=%.3e guard=%.4f eig_before=%.3e neg=%d eig_after=%.3e reason=%s', ...
            mat2str(sample.doa_baseline, 4), mat2str(sample.doa_proto3, 4), ...
            sample.proto3.theta_dom, sample.proto3.theta_other_init, sample.proto3.theta_refined, ...
            sample.proto3.alpha_dom, sample.proto3.guard_band_deg, ...
            sample.proto3.min_eig_before_psd, sample.proto3.num_negative_eigs, ...
            sample.proto3.min_eig_after_psd, sample.proto3.reason);
    end

    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;

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
        'SNR90 summary | bw/%d baseline=%s proto3=%s', ...
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
params.prototype_note = 'Prototype 3: beamspace covariance residual cancellation with PSD-projected second-pass refinement.';

result_dir = fullfile(script_dir, 'results_step8_routeB_cov_residual_refine_proto3');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_cov_residual_refine_proto3.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_cov_residual_refine_proto3_summary.csv');
fid = fopen(csv_path, 'w');
if fid < 0
    error('Failed to open csv file.');
end
fprintf(fid, 'route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,raw_success_count,tol_success_count,raw_success_rate,tol_success_rate,rmse_deg,rmse_valid_count,mean_num_peaks,snr90_db\n');
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, '%s,%d,%.6f,%.6f,%.6f,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f\n', ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), ...
                theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), ...
                raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                raw_success_rate(iroute, iSep, iSNR), tol_success_rate(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), ...
                mean_num_peaks(iroute, iSep, iSNR), snr90(iroute, iSep));
        end
    end
end
fclose(fid);

mat_path = fullfile(result_dir, 'step8_routeB_cov_residual_refine_proto3_result.mat');
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
    title(sprintf('Prototype 3 tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_cov_residual_refine_proto3_tol_success.png'));
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
    title(sprintf('Prototype 3 RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_cov_residual_refine_proto3_rmse.png'));
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
    title(sprintf('Prototype 3 raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_cov_residual_refine_proto3_raw_success.png'));
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
    title(sprintf('Prototype 3 mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_cov_residual_refine_proto3_mean_num_peaks.png'));
close(fig4)

disp('Prototype 3 finished.');
disp('route_names =');
disp(route_names);
disp('snr90 =');
disp(snr90);
disp('result_dir =');
disp(result_dir);

function [angle_search, Pmu, peak_angles, peak_values, Rb, eigvals] = calc_routeB_music_spectrum( ...
    y, K, Tk, angle_recv, search_width_deg, Lc)
    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lambda = c / fc;
    d = 0.047;
    [~, T_snap] = size(y);
    posK = d * (0:K-1).';

    Rxx = y * y' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    Rb = Tk.' * Rss * conj(Tk);
    Rb = 0.5 * (Rb + Rb');

    [E, D] = eig(Rb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
    E = E(:, idx);
    En = E(:, Lc+1:end);

    angle_search = angle_recv - search_width_deg / 2 : 0.01 : angle_recv + search_width_deg / 2;
    Pmu = zeros(1, numel(angle_search));

    for ii = 1:numel(angle_search)
        theta = angle_search(ii);
        aK = exp(-j * 2*pi/lambda * posK * sind(theta));
        bK = Tk.' * aK;
        den = real(bK' * En * En' * bK);
        num = real(bK' * bK);
        Pmu(ii) = num / max(den, eps);
    end

    [peak_values, peak_ind] = FindLocalPeak_NoEdge_Fun(abs(Pmu));
    peak_angles = angle_search(peak_ind);
end

function [alpha_dom, b_dom] = estimate_dominant_component_ls(Rb, Tk, posK, lambda, theta_dom)
    j = sqrt(-1);
    aK = exp(-j * 2*pi/lambda * posK * sind(theta_dom));
    b_dom = Tk.' * aK;
    denom = norm(b_dom)^4;
    if denom <= eps
        alpha_dom = 0;
        return;
    end
    alpha_dom = real(b_dom' * Rb * b_dom) / denom;
    alpha_dom = max(alpha_dom, 0);
end

function [R_psd, eigvals_after] = project_psd_hermitian(R)
    R = 0.5 * (R + R');
    [V, D] = eig(R);
    eigvals = real(diag(D));
    eigvals(eigvals < 0) = 0;
    R_psd = V * diag(eigvals) * V';
    R_psd = 0.5 * (R_psd + R_psd');
    eigvals_after = eigvals;
end

function [theta_refined, P_residual, num_peaks_residual] = find_refined_secondary_from_residual( ...
    R_res_psd, Tk, posK, lambda, angle_recv, search_width_deg, theta_dom, guard_band_deg)
    j = sqrt(-1);
    Lc_res = 1;

    [E, D] = eig(R_res_psd);
    eigvals = real(diag(D));
    [~, idx] = sort(eigvals, 'descend');
    E = E(:, idx);
    En = E(:, Lc_res+1:end);

    angle_search = angle_recv - search_width_deg / 2 : 0.01 : angle_recv + search_width_deg / 2;
    P_residual = nan(1, numel(angle_search));

    for ii = 1:numel(angle_search)
        theta = angle_search(ii);
        if abs(theta - theta_dom) <= guard_band_deg
            continue;
        end
        aK = exp(-j * 2*pi/lambda * posK * sind(theta));
        bK = Tk.' * aK;
        den = real(bK' * En * En' * bK);
        num = real(bK' * bK);
        P_residual(ii) = num / max(den, eps);
    end

    finite_mask = isfinite(P_residual);
    if ~any(finite_mask)
        theta_refined = NaN;
        num_peaks_residual = 0;
        return;
    end

    Pres = P_residual;
    Pres(~finite_mask) = 0;
    [peak_values, peak_ind] = FindLocalPeak_NoEdge_Fun(abs(Pres));
    num_peaks_residual = numel(peak_ind);

    if isempty(peak_ind)
        theta_refined = NaN;
        return;
    end

    theta_candidates = angle_search(peak_ind);
    valid = abs(theta_candidates - theta_dom) > guard_band_deg;
    theta_candidates = theta_candidates(valid);
    peak_values = peak_values(valid);

    if isempty(theta_candidates)
        theta_refined = NaN;
        return;
    end

    [~, idx_best] = max(peak_values);
    theta_refined = theta_candidates(idx_best);
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
