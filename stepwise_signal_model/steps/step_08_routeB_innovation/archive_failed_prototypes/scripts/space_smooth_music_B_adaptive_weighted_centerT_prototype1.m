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

route_names = {'baseline_centerT', 'adaptive_weighted_centerT'};
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
log_lines = append_log(log_lines, 'Step 08 Route B adaptive weighted centerT prototype 1');
log_lines = append_log(log_lines, 'Prototype scope: keep Route B baseline framing, only replace centerT with adaptive weighted centerT.');
log_lines = append_log(log_lines, 'Route comparison: baseline_centerT vs adaptive_weighted_centerT.');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B internal settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, 'Weighted centerT rule: smoothed coarse MUSIC direct weights with [1 2 1]/4 smoothing and 5%% floor.');
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
            [p_center, p_smooth, weight_vector, p_floor] = build_adaptive_weights( ...
                angle_search, P_coarse, beam_grid_center_deg);

            Wcenter_weighted = A_center * diag(weight_vector);
            [Tk_weighted, ~] = qr(Wcenter_weighted, 0);
            cond_Wcenter_weighted = cond(Wcenter_weighted);

            [doa_weighted, num_peaks_weighted] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_weighted, RecvbeamC, theta_search_B);

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

            raw_ok_weighted = all(isfinite(doa_weighted));
            tol_ok_weighted = is_valid_doa_success(doa_weighted, target_theta, tol_deg);
            if raw_ok_weighted
                raw_success_count(2, iSep, iSNR) = raw_success_count(2, iSep, iSNR) + 1;
                sqerr_weighted = sum((sort(doa_weighted(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(2, iSep, iSNR) = rmse_sum_sqerr(2, iSep, iSNR) + sqerr_weighted;
                rmse_valid_count(2, iSep, iSNR) = rmse_valid_count(2, iSep, iSNR) + 1;
            end
            if tol_ok_weighted
                tol_success_count(2, iSep, iSNR) = tol_success_count(2, iSep, iSNR) + 1;
            end
            sum_num_peaks(2, iSep, iSNR) = sum_num_peaks(2, iSep, iSNR) + num_peaks_weighted;

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
                sample.p_center = p_center;
                sample.p_smooth = p_smooth;
                sample.p_floor = p_floor;
                sample.weight_vector = weight_vector;
                sample.cond_Wcenter_base = cond_Wcenter_base;
                sample.cond_Wcenter_weighted = cond_Wcenter_weighted;
                sample.doa_baseline = doa_baseline;
                sample.doa_weighted = doa_weighted;
                sample.num_peaks_baseline = num_peaks_baseline;
                sample.num_peaks_weighted = num_peaks_weighted;
                debug_samples{iSep, iSNR} = sample;
            end
        end

        current_rmse_baseline = NaN;
        if rmse_valid_count(1, iSep, iSNR) > 0
            current_rmse_baseline = sqrt( ...
                rmse_sum_sqerr(1, iSep, iSNR) / ...
                (2 * rmse_valid_count(1, iSep, iSNR)));
        end

        current_rmse_weighted = NaN;
        if rmse_valid_count(2, iSep, iSNR) > 0
            current_rmse_weighted = sqrt( ...
                rmse_sum_sqerr(2, iSep, iSNR) / ...
                (2 * rmse_valid_count(2, iSep, iSNR)));
        end

        raw_rate_baseline = raw_success_count(1, iSep, iSNR) / Metkl;
        raw_rate_weighted = raw_success_count(2, iSep, iSNR) / Metkl;
        tol_rate_baseline = tol_success_count(1, iSep, iSNR) / Metkl;
        tol_rate_weighted = tol_success_count(2, iSep, iSNR) / Metkl;
        mean_num_peaks_baseline = sum_num_peaks(1, iSep, iSNR) / Metkl;
        mean_num_peaks_weighted = sum_num_peaks(2, iSep, iSNR) / Metkl;

        sample = debug_samples{iSep, iSNR};
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | baseline raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(1, iSep, iSNR), tol_success_count(1, iSep, iSNR), ...
            raw_rate_baseline, tol_rate_baseline, current_rmse_baseline, mean_num_peaks_baseline);
        log_lines = append_log(log_lines, ...
            'SNR=%d dB | weighted raw=%d tol=%d raw_rate=%.3f tol_rate=%.3f RMSE=%.4f mean_num_peaks=%.2f', ...
            snr, raw_success_count(2, iSep, iSNR), tol_success_count(2, iSep, iSNR), ...
            raw_rate_weighted, tol_rate_weighted, current_rmse_weighted, mean_num_peaks_weighted);
        log_lines = append_log(log_lines, ...
            'sample metkl=1 | doa_base=%s doa_weighted=%s cond_base=%.3e cond_weighted=%.3e weight_minmax=[%.3f %.3f]', ...
            mat2str(sample.doa_baseline, 4), mat2str(sample.doa_weighted, 4), ...
            sample.cond_Wcenter_base, sample.cond_Wcenter_weighted, ...
            min(sample.weight_vector), max(sample.weight_vector));
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
        'SNR90 summary | bw/%d baseline=%s weighted=%s', ...
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
params.prototype_note = 'Prototype 1: adaptive weighted centerT from smoothed coarse local MUSIC spectrum.';

result_dir = fullfile(script_dir, 'results_step8_routeB_adaptive_weighted_centerT_proto1');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_routeB_adaptive_weighted_centerT_proto1.log');
fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

csv_path = fullfile(result_dir, 'step8_routeB_adaptive_weighted_centerT_proto1_summary.csv');
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

mat_path = fullfile(result_dir, 'step8_routeB_adaptive_weighted_centerT_proto1_result.mat');
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

xvals = 1:nsep;
xlabels = arrayfun(@(k) sprintf('bw/%d', k), sep_factor_list, 'UniformOutput', false);

fig1 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, squeeze(tol_success_rate(1, iSep, :)), '-o', 'LineWidth', 1.2);
    hold on
    plot(snr_list, squeeze(tol_success_rate(2, iSep, :)), '-s', 'LineWidth', 1.2);
    hold off
    grid on
    ylabel('tol success');
    title(sprintf('Prototype 1 tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_adaptive_weighted_centerT_proto1_tol_success.png'));
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
    title(sprintf('Prototype 1 RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_adaptive_weighted_centerT_proto1_rmse.png'));
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
    title(sprintf('Prototype 1 raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_adaptive_weighted_centerT_proto1_raw_success.png'));
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
    title(sprintf('Prototype 1 mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_adaptive_weighted_centerT_proto1_mean_num_peaks.png'));
close(fig4)

disp('Prototype 1 finished.');
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

function [p_center, p_smooth, weight_vector, p_floor] = build_adaptive_weights( ...
    angle_search, P_coarse, beam_grid_center_deg)
    p_center = interp1(angle_search, P_coarse, beam_grid_center_deg, 'linear', 'extrap');
    p_center(~isfinite(p_center)) = 0;
    p_center = max(real(p_center), 0);

    h = [1 2 1] / 4;
    p_smooth = conv(p_center, h, 'same');
    p_smooth = max(real(p_smooth), 0);

    peak_val = max(p_smooth);
    if ~(isfinite(peak_val) && peak_val > 0)
        p_floor = 1;
        weight_vector = ones(size(p_smooth));
        return;
    end

    p_floor = 0.05 * peak_val;
    weight_vector = max(p_smooth, p_floor);
    weight_vector = weight_vector / max(weight_vector);
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
