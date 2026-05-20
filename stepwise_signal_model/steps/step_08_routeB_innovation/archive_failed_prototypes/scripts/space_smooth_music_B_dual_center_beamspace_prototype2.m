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

trigger_peak_width_deg = 0.20;
trigger_asym_ratio = 0.15;
gamma_sigma = 0.60;

route_names = {'baseline_centerT', 'dual_center_beamspace'};
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
log_lines = append_log(log_lines, 'Step 08 Route B dual-center beamspace prototype 2');
log_lines = append_log(log_lines, 'Prototype scope: keep Route B baseline framing, replace centerT with dual-center candidate beamspace when coarse peak is wide or asymmetric.');
log_lines = append_log(log_lines, 'Route comparison: baseline_centerT vs dual_center_beamspace.');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B internal settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, 'Dual-center trigger: peak_width_deg > %.3f or asym_ratio > %.3f, gamma_sigma = %.2f', ...
    trigger_peak_width_deg, trigger_asym_ratio, gamma_sigma);
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
    A_center = exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg));
    Wcenter_base = A_center;
    [Tk_base, ~] = qr(Wcenter_base, 0);
    cond_Wcenter_base = cond(Wcenter_base);

    theta_sep_deg(iSep) = theta_sep;
    theta_a_deg(iSep) = theta_a;
    theta_b_deg(iSep) = theta_b;

    log_lines = append_log(log_lines, '=== sep_factor = %d, theta_sep = %.4f deg ===', sep_factor, theta_sep);

    for iSNR = 1:nsnr
        snr = snr_list(iSNR);

        trigger_count = 0;
        candidate1_win_count = 0;
        candidate2_win_count = 0;

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

            [angle_search, P_coarse, coarse_eigvals] = calc_routeB_music_spectrum( ...
                y, K_fbss, Tk_base, RecvbeamC, theta_search_B);
            [mu_hat, sigma_hat, peak_width_deg, asym_ratio] = characterize_coarse_peak( ...
                angle_search, P_coarse, RecvbeamC);

            use_dual_center = (peak_width_deg > trigger_peak_width_deg) || ...
                              (asym_ratio > trigger_asym_ratio);

            if use_dual_center
                trigger_count = trigger_count + 1;
                delta_deg = gamma_sigma * sigma_hat;
            else
                delta_deg = 0;
            end

            mu1 = mu_hat - delta_deg;
            mu2 = mu_hat + delta_deg;

            beam_grid_center_deg_1 = beam_grid_center_deg + (mu1 - RecvbeamC);
            beam_grid_center_deg_2 = beam_grid_center_deg + (mu2 - RecvbeamC);

            Tk1 = build_centerT_from_grid(posK, lambda, beam_grid_center_deg_1);
            Tk2 = build_centerT_from_grid(posK, lambda, beam_grid_center_deg_2);
            cond_Wcenter_1 = cond(exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg_1)));
            cond_Wcenter_2 = cond(exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg_2)));

            [doa_dual_1, num_peaks_dual_1, score_dual_1] = estimate_routeB_with_score( ...
                y, K_fbss, Tk1, RecvbeamC, theta_search_B);
            [doa_dual_2, num_peaks_dual_2, score_dual_2] = estimate_routeB_with_score( ...
                y, K_fbss, Tk2, RecvbeamC, theta_search_B);

            if score_dual_1 <= score_dual_2
                doa_dual = doa_dual_1;
                num_peaks_dual = num_peaks_dual_1;
                chosen_candidate = 1;
                chosen_score = score_dual_1;
                other_score = score_dual_2;
                candidate1_win_count = candidate1_win_count + 1;
            else
                doa_dual = doa_dual_2;
                num_peaks_dual = num_peaks_dual_2;
                chosen_candidate = 2;
                chosen_score = score_dual_2;
                other_score = score_dual_1;
                candidate2_win_count = candidate2_win_count + 1;
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

            raw_ok_dual = all(isfinite(doa_dual));
            tol_ok_dual = is_valid_doa_success(doa_dual, target_theta, tol_deg);
            if raw_ok_dual
                raw_success_count(2, iSep, iSNR) = raw_success_count(2, iSep, iSNR) + 1;
                sqerr_dual = sum((sort(doa_dual(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(2, iSep, iSNR) = rmse_sum_sqerr(2, iSep, iSNR) + sqerr_dual;
                rmse_valid_count(2, iSep, iSNR) = rmse_valid_count(2, iSep, iSNR) + 1;
            end
            if tol_ok_dual
                tol_success_count(2, iSep, iSNR) = tol_success_count(2, iSep, iSNR) + 1;
            end
            sum_num_peaks(2, iSep, iSNR) = sum_num_peaks(2, iSep, iSNR) + num_peaks_dual;

            if metkl_num == 1
                sample = struct();
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr;
                sample.target_theta = target_theta;
                sample.RecvbeamC = RecvbeamC;
                sample.theta_search_B = theta_search_B;
                sample.beam_grid_center_deg = beam_grid_center_deg;
                sample.angle_search = angle_search;
                sample.P_coarse = P_coarse;
                sample.coarse_eigvals = coarse_eigvals;
                sample.mu_hat = mu_hat;
                sample.sigma_hat = sigma_hat;
                sample.peak_width_deg = peak_width_deg;
                sample.asym_ratio = asym_ratio;
                sample.use_dual_center = use_dual_center;
                sample.mu1 = mu1;
                sample.mu2 = mu2;
                sample.beam_grid_center_deg_1 = beam_grid_center_deg_1;
                sample.beam_grid_center_deg_2 = beam_grid_center_deg_2;
                sample.cond_Wcenter_base = cond_Wcenter_base;
                sample.cond_Wcenter_1 = cond_Wcenter_1;
                sample.cond_Wcenter_2 = cond_Wcenter_2;
                sample.doa_baseline = doa_baseline;
                sample.doa_dual_1 = doa_dual_1;
                sample.doa_dual_2 = doa_dual_2;
                sample.doa_dual = doa_dual;
                sample.num_peaks_baseline = num_peaks_baseline;
                sample.num_peaks_dual_1 = num_peaks_dual_1;
                sample.num_peaks_dual_2 = num_peaks_dual_2;
                sample.num_peaks_dual = num_peaks_dual;
                sample.score_dual_1 = score_dual_1;
                sample.score_dual_2 = score_dual_2;
                sample.chosen_candidate = chosen_candidate;
                sample.chosen_score = chosen_score;
                sample.other_score = other_score;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        current_rmse_baseline = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 1, iSep, iSNR);
        current_rmse_dual = calc_current_rmse(rmse_sum_sqerr, rmse_valid_count, 2, iSep, iSNR);

        raw_rate_baseline = raw_success_count(1, iSep, iSNR) / Metkl;
        raw_rate_dual = raw_success_count(2, iSep, iSNR) / Metkl;
        tol_rate_baseline = tol_success_count(1, iSep, iSNR) / Metkl;
        tol_rate_dual = tol_success_count(2, iSep, iSNR) / Metkl;
        mean_num_peaks_baseline = sum_num_peaks(1, iSep, iSNR) / Metkl;
        mean_num_peaks_dual = sum_num_peaks(2, iSep, iSNR) / Metkl;
        trigger_rate = trigger_count / Metkl;

        sample = debug_samples{iSep, iSNR};
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | baseline raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(1, iSep, iSNR), tol_success_count(1, iSep, iSNR), ...
            raw_rate_baseline, tol_rate_baseline, current_rmse_baseline, mean_num_peaks_baseline);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | dual raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f trigger_rate=%.3f win12=[%d %d]', ...
            snr, raw_success_count(2, iSep, iSNR), tol_success_count(2, iSep, iSNR), ...
            raw_rate_dual, tol_rate_dual, current_rmse_dual, mean_num_peaks_dual, ...
            trigger_rate, candidate1_win_count, candidate2_win_count);
        log_lines = append_log(log_lines, ...
            'sample metkl=1 | use_dual=%d mu_hat=%.4f sigma_hat=%.4f width=%.4f asym=%.4f doa_base=%s doa_dual=%s score12=[%.3e %.3e] chosen=%d', ...
            sample.use_dual_center, sample.mu_hat, sample.sigma_hat, sample.peak_width_deg, ...
            sample.asym_ratio, mat2str(sample.doa_baseline, 4), mat2str(sample.doa_dual, 4), ...
            sample.score_dual_1, sample.score_dual_2, sample.chosen_candidate);
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
        'SNR90 summary | bw/%d baseline=%s dual=%s', ...
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
params.trigger_peak_width_deg = trigger_peak_width_deg;
params.trigger_asym_ratio = trigger_asym_ratio;
params.gamma_sigma = gamma_sigma;
params.prototype_note = 'Prototype 2: dual-center candidate beamspace selected by beamspace MUSIC score.';

result_dir = fullfile(script_dir, 'results_step8_routeB_dual_center_beamspace_proto2');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_dual_center_beamspace_proto2.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_dual_center_beamspace_proto2_summary.csv');
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

mat_path = fullfile(result_dir, 'step8_routeB_dual_center_beamspace_proto2_result.mat');
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
    title(sprintf('Prototype 2 tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_dual_center_beamspace_proto2_tol_success.png'));
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
    title(sprintf('Prototype 2 RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_dual_center_beamspace_proto2_rmse.png'));
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
    title(sprintf('Prototype 2 raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_dual_center_beamspace_proto2_raw_success.png'));
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
    title(sprintf('Prototype 2 mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_dual_center_beamspace_proto2_mean_num_peaks.png'));
close(fig4)

disp('Prototype 2 finished.');
disp('route_names =');
disp(route_names);
disp('snr90 =');
disp(snr90);
disp('result_dir =');
disp(result_dir);

function [angle_search, Pmu, eigvals] = calc_routeB_music_spectrum( ...
    y, K, Tk, angle_recv, search_width_deg)
    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lambda = c / fc;
    d = 0.047;
    Lc = 2;
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
end

function [doa_value, num_peaks, score] = estimate_routeB_with_score( ...
    y, K, Tk, angle_recv, search_width_deg)
    [doa_value, num_peaks] = DOA_three_music_new_route_centerT(y, K, Tk, angle_recv, search_width_deg);

    if all(isfinite(doa_value))
        score = calc_noise_subspace_score(y, K, Tk, doa_value);
    else
        score = inf;
    end
end

function score = calc_noise_subspace_score(y, K, Tk, doa_value)
    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lambda = c / fc;
    d = 0.047;
    Lc = 2;
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
    [~, idx] = sort(eigvals, 'descend');
    E = E(:, idx);
    En = E(:, Lc+1:end);

    score = 0;
    for ii = 1:numel(doa_value)
        aK = exp(-j * 2*pi/lambda * posK * sind(doa_value(ii)));
        bK = Tk.' * aK;
        score = score + real(bK' * En * En' * bK) / max(real(bK' * bK), eps);
    end
end

function [mu_hat, sigma_hat, peak_width_deg, asym_ratio] = characterize_coarse_peak( ...
    angle_search, P_coarse, default_mu)
    Pmag = abs(P_coarse(:).');
    [peak_val, peak_idx] = max(Pmag);

    if ~(isfinite(peak_val) && peak_val > 0)
        mu_hat = default_mu;
        sigma_hat = 0.05;
        peak_width_deg = 0;
        asym_ratio = 0;
        return;
    end

    mu_hat = angle_search(peak_idx);
    half_level = 0.5 * peak_val;

    left_idx = find(Pmag(1:peak_idx) < half_level, 1, 'last');
    if isempty(left_idx)
        left_cross = angle_search(1);
    else
        left_cross = angle_search(left_idx);
    end

    right_rel = find(Pmag(peak_idx:end) < half_level, 1, 'first');
    if isempty(right_rel)
        right_cross = angle_search(end);
    else
        right_cross = angle_search(peak_idx + right_rel - 1);
    end

    peak_width_deg = max(right_cross - left_cross, 0.01);
    sigma_hat = max(peak_width_deg / 2.355, 0.02);

    left_width = max(mu_hat - left_cross, 0.001);
    right_width = max(right_cross - mu_hat, 0.001);
    asym_ratio = abs(right_width - left_width) / max(peak_width_deg, 0.001);
end

function Tk = build_centerT_from_grid(posK, lambda, beam_grid_center_deg)
    j = sqrt(-1);
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

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
