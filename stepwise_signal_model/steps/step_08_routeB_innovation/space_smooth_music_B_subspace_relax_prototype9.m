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
base_seed = 20260526;

search_scale_B = 4;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;

max_outer_iter = 6;
angle_tol_stop_deg = 1e-3;
min_sep_guard = 0.05;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
posK = d * (0:K_fbss-1).';

route_names = { ...
    'baseline_routeB_centerT_grid_music', ...
    'proto6_array_root_music', ...
    'proto6_beamspace_root_music', ...
    'proto9_subspace_relax_root_music'};
nroutes = numel(route_names);

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count_rel = zeros(nroutes, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nsep, nsnr);
sum_num_peaks = zeros(nroutes, nsep, nsnr);

lambda2_over_noise_array_sum = zeros(nsep, nsnr);
lambda2_over_noise_beam_sum = zeros(nsep, nsnr);
root_dist_array_sum = zeros(nsep, nsnr);
root_dist_beam_sum = zeros(nsep, nsnr);
proto6_diag_count = zeros(nsep, nsnr);

outer_iter_sum = zeros(nsep, nsnr);
init_failed_count = zeros(nsep, nsnr);
guard_applied_count = zeros(nsep, nsnr);
final_residual_pow_sum = zeros(nsep, nsnr);
final_residual_pow_count = zeros(nsep, nsnr);
proto9_diag_count = zeros(nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

result_dir = fullfile(script_dir, 'results_step8_routeB_subspace_relax_proto9');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log(log_lines, 'Step 08 Prototype 9: Subspace-RELAX Root-MUSIC fair compare');
log_lines = append_log(log_lines, 'Routes: baseline Route B, proto6 array/beamspace Root-MUSIC, proto9 subspace-RELAX.');
log_lines = append_log(log_lines, 'Fairness rule: same (sep_factor, snr_db, metkl_num) uses the same independent seed for all routes.');
log_lines = append_log(log_lines, 'base_seed=%d', base_seed);
log_lines = append_log(log_lines, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f, tol_rel_ratio=%.2f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg, tol_rel_ratio);
log_lines = append_log(log_lines, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_lines = append_log(log_lines, 'Route B settings: K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f', ...
    K_fbss, M_full, center_beam_count, search_scale_B);
log_lines = append_log(log_lines, 'Prototype 9 settings: max_outer_iter=%d, angle_tol_stop_deg=%.3e, min_sep_guard=%.3f', ...
    max_outer_iter, angle_tol_stop_deg, min_sep_guard);
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

            [doa_baseline, num_peaks_baseline] = DOA_three_music_new_route_centerT( ...
                y, K_fbss, Tk_true, RecvbeamC_true, theta_search_B_fixed);
            [doa_proto6_array, debug_proto6_array] = doa_root_music_array(y, K_fbss, lambda, d, 2);
            [doa_proto6_beam, debug_proto6_beam] = doa_root_music_beamspace(y, K_fbss, Tk_true, lambda, d, 2);
            [doa_proto9, debug_proto9] = doa_subspace_relax_root_music( ...
                y, K_fbss, lambda, d, 2, doa_proto6_array, max_outer_iter, angle_tol_stop_deg, min_sep_guard);

            num_peaks_array = sum(isfinite(doa_proto6_array));
            num_peaks_beam = sum(isfinite(doa_proto6_beam));
            num_peaks_proto9 = sum(isfinite(doa_proto9));

            doa_all = {doa_baseline, doa_proto6_array, doa_proto6_beam, doa_proto9};
            num_peaks_all = [num_peaks_baseline, num_peaks_array, num_peaks_beam, num_peaks_proto9];

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

            outer_iter_sum(iSep, iSNR) = outer_iter_sum(iSep, iSNR) + debug_proto9.outer_iter_used;
            init_failed_count(iSep, iSNR) = init_failed_count(iSep, iSNR) + double(debug_proto9.init_failed);
            guard_applied_count(iSep, iSNR) = guard_applied_count(iSep, iSNR) + double(debug_proto9.guard_applied);
            if isfinite(debug_proto9.final_residual_power)
                final_residual_pow_sum(iSep, iSNR) = final_residual_pow_sum(iSep, iSNR) + debug_proto9.final_residual_power;
                final_residual_pow_count(iSep, iSNR) = final_residual_pow_count(iSep, iSNR) + 1;
            end
            proto9_diag_count(iSep, iSNR) = proto9_diag_count(iSep, iSNR) + 1;

            if metkl_num == 1
                sample = struct();
                sample.seed_now = seed_now;
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr;
                sample.tol_deg_rel = tol_deg_rel;
                sample.target_theta = target_theta;
                sample.beam_grid_full_true = beam_grid_full_true;
                sample.beam_grid_center_true = beam_grid_center_true;
                sample.doa_baseline = doa_baseline;
                sample.doa_proto6_array = doa_proto6_array;
                sample.doa_proto6_beam = doa_proto6_beam;
                sample.doa_proto9 = doa_proto9;
                sample.debug_proto6_array = debug_proto6_array;
                sample.debug_proto6_beam = debug_proto6_beam;
                sample.debug_proto9 = debug_proto9;
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

lambda2_over_noise_array_mean = lambda2_over_noise_array_sum ./ max(proto6_diag_count, 1);
lambda2_over_noise_beam_mean = lambda2_over_noise_beam_sum ./ max(proto6_diag_count, 1);
root_dist_array_mean = root_dist_array_sum ./ max(proto6_diag_count, 1);
root_dist_beam_mean = root_dist_beam_sum ./ max(proto6_diag_count, 1);

mean_outer_iter = outer_iter_sum ./ max(proto9_diag_count, 1);
init_failed_rate = init_failed_count ./ Metkl;
guard_applied_rate = guard_applied_count ./ Metkl;
mean_final_residual_power = final_residual_pow_sum ./ max(final_residual_pow_count, 1);
mean_final_residual_power(final_residual_pow_count == 0) = NaN;

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
        'sep_factor=%d | SNR90 abs01 -> baseline=%s, proto6-array=%s, proto6-beam=%s, proto9=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90(1, iSep)), fmt_snr90(snr90(2, iSep)), ...
        fmt_snr90(snr90(3, iSep)), fmt_snr90(snr90(4, iSep)));
    log_lines = append_log(log_lines, ...
        'sep_factor=%d | SNR90 rel025 -> baseline=%s, proto6-array=%s, proto6-beam=%s, proto9=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90_rel(1, iSep)), fmt_snr90(snr90_rel(2, iSep)), ...
        fmt_snr90(snr90_rel(3, iSep)), fmt_snr90(snr90_rel(4, iSep)));
end

log_lines = append_log(log_lines, 'max init_failed_rate=%.3f', max(init_failed_rate(:)));
log_lines = append_log(log_lines, 'max guard_applied_rate=%.3f', max(guard_applied_rate(:)));
log_lines = append_log(log_lines, 'min/max mean_outer_iter=%.3f / %.3f', min(mean_outer_iter(:)), max(mean_outer_iter(:)));

log_path = fullfile(result_dir, 'step8_routeB_subspace_relax_proto9.log');
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
params.max_outer_iter = max_outer_iter;
params.angle_tol_stop_deg = angle_tol_stop_deg;
params.min_sep_guard = min_sep_guard;

summary_path = fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_summary.csv');
fid = fopen(summary_path, 'w');
fprintf(fid, ['route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
    'raw_success_count,tol_success_count,tol_success_count_rel,' ...
    'raw_success_rate,tol_success_rate,tol_success_rate_rel,' ...
    'rmse_deg,rmse_valid_count,mean_num_peaks,' ...
    'snr90_db,snr90_rel_db,' ...
    'lambda2_over_noise_array,lambda2_over_noise_beam,root_dist_array,root_dist_beam,' ...
    'mean_outer_iter,init_failed_rate,guard_applied_rate,mean_final_residual_power\n']);
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            fprintf(fid, ['%s,%d,%.6f,%.6f,%.6f,%d,' ...
                '%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,' ...
                '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6e\n'], ...
                route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
                snr_list(iSNR), raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                tol_success_count_rel(iroute, iSep, iSNR), raw_success_rate(iroute, iSep, iSNR), ...
                tol_success_rate(iroute, iSep, iSNR), tol_success_rate_rel(iroute, iSep, iSNR), ...
                rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), mean_num_peaks(iroute, iSep, iSNR), ...
                snr90(iroute, iSep), snr90_rel(iroute, iSep), ...
                lambda2_over_noise_array_mean(iSep, iSNR), lambda2_over_noise_beam_mean(iSep, iSNR), ...
                root_dist_array_mean(iSep, iSNR), root_dist_beam_mean(iSep, iSNR), ...
                mean_outer_iter(iSep, iSNR), init_failed_rate(iSep, iSNR), guard_applied_rate(iSep, iSNR), ...
                mean_final_residual_power(iSep, iSNR));
        end
    end
end
fclose(fid);

keypoints_path = fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_keypoints.csv');
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

mat_path = fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_result.mat');
save(mat_path, ...
    'params', 'route_names', 'sep_factor_list', 'snr_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_count', 'tol_success_count', 'tol_success_count_rel', ...
    'raw_success_rate', 'tol_success_rate', 'tol_success_rate_rel', ...
    'rmse_sum_sqerr', 'rmse_valid_count', 'rmse', 'sum_num_peaks', 'mean_num_peaks', ...
    'snr90', 'snr90_rel', ...
    'lambda2_over_noise_array_mean', 'lambda2_over_noise_beam_mean', ...
    'root_dist_array_mean', 'root_dist_beam_mean', ...
    'mean_outer_iter', 'init_failed_rate', 'guard_applied_rate', 'mean_final_residual_power', ...
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
    title(sprintf('Prototype9 tol success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig1, fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_tol_success.png'));
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
    title(sprintf('Prototype9 RMSE, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig2, fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_rmse.png'));
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
    title(sprintf('Prototype9 raw success, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig3, fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_raw_success.png'));
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
    title(sprintf('Prototype9 mean num peaks, bw/%d', sep_factor_list(iSep)));
    legend(route_names, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig4, fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_mean_num_peaks.png'));
close(fig4)

fig5 = figure('Visible', 'off');
for iSep = 1:nsep
    subplot(nsep, 1, iSep);
    plot(snr_list, mean_outer_iter(iSep, :), '-o', 'LineWidth', 1.1);
    hold on
    plot(snr_list, guard_applied_rate(iSep, :), '-s', 'LineWidth', 1.1);
    plot(snr_list, init_failed_rate(iSep, :), '-^', 'LineWidth', 1.1);
    hold off
    grid on
    ylabel('iter / rate');
    title(sprintf('Prototype9 iteration diagnostics, bw/%d', sep_factor_list(iSep)));
    legend({'mean outer iter', 'guard rate', 'init fail rate'}, 'Location', 'best');
end
xlabel('SNR (dB)');
saveas(fig5, fullfile(result_dir, 'step8_routeB_subspace_relax_proto9_iter_diag.png'));
close(fig5)

disp('Step 08 Prototype 9 finished.');
disp('route_names =');
disp(route_names);
disp('snr90_abs01 =');
disp(snr90);
disp('snr90_rel025 =');
disp(snr90_rel);
disp('max init_failed_rate =');
disp(max(init_failed_rate(:)));
disp('max guard_applied_rate =');
disp(max(guard_applied_rate(:)));
disp('min/max mean_outer_iter =');
disp([min(mean_outer_iter(:)), max(mean_outer_iter(:))]);
disp('result_dir =');
disp(result_dir);

function [beam_grid_full_deg, beam_grid_center_deg, Tk] = build_centerT_from_center( ...
    center_deg, routeB_beam_span, M_full, center_beam_count, posK, lambda)
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

    Wcenter = exp(1j * 2*pi/lambda * posK * sind(beam_grid_center_deg));
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
