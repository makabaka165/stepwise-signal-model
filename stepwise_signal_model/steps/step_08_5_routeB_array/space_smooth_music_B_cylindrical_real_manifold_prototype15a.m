clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
step08_dir = fullfile(steps_dir, 'step_08_routeB_innovation');
step75_dir = fullfile(steps_dir, 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');

addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
addpath(step75_dir);
addpath(step08_dir);

cfg = sim_cfg();

result_dir = fullfile(script_dir, 'results_step8_5_cylindrical_real_manifold_proto15a');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() fclose(fid_log));

log_msg(fid_log, 'Step 08.5 Prototype 15.A: cylindrical real-manifold grid-MUSIC');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Frozen paths: %s ; %s', step08_dir, step75_dir);

proto14_mat = fullfile(script_dir, 'results_step8_5_cylindrical_multilayer_proto14', ...
    'step8_5_cylindrical_multilayer_proto14_result.mat');
assert(exist(proto14_mat, 'file') == 2, 'proto14 result.mat not found.');
proto14_data = load(proto14_mat);

sep_factor_list = [1, 2, 3, 5, 7, 10];
snr_list = -4:2:30;
Metkl = 200;
T_snap = 260;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
base_seed = 20260601;
azCtr_deg = 0;
N_arc = 32;
K_fbss = 28;
Lc = 2;
el_a = 0;
el_b = 0;
el_assumed = 0;
theta_c = azCtr_deg;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s1 = exp(j * 2*pi * cfg.arr.fc * t);
s2 = exp(j * 2*pi * cfg.arr.fc * t);

route_names = { ...
    'multilayer_coherent_proto14_N32_baseline', ...
    'multilayer_coherent_proto15_grid_music_real_manifold_main', ...
    'multilayer_coherent_proto15_grid_music_ula_assumption_ablation'};
manifold_types = {'root_music_ula_from_proto14', 'real_xy_grid_music', 'ula_grid_music_ablation'};
nroutes = numel(route_names);
route_name_64 = 'pure_ula_root_music_64ch_proto6_replay';

arrInfo = arr_cyl(cfg, azCtr_deg);
col_mid = round((cfg.beam.subNaz + 1) / 2);
col_select = (col_mid - N_arc/2 + 1):(col_mid + N_arc/2);
iel_select = round(cfg.arr.Nel / 2);
iel_select_all = 1:cfg.arr.Nel;
X3d = arrInfo.XAct(col_select, iel_select_all);
Y3d = arrInfo.YAct(col_select, iel_select_all);
Z3d = arrInfo.ZAct(col_select, iel_select_all);
A_ref_2d = exp(-j * 2*pi / cfg.arr.lambda * (X3d * cosd(azCtr_deg) + Y3d * sind(azCtr_deg)));

d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
arc_dist = d_eq;
arc_over_lambda = arc_dist / cfg.arr.lambda;
subArc_span_deg = (cfg.beam.subNaz - 1) * cfg.arr.dPhi;
N_arc_span_deg = (N_arc - 1) * cfg.arr.dPhi;
edge_offset_deg = N_arc_span_deg / 2;
dz_over_lambda = cfg.arr.dz / cfg.arr.lambda;
elev_aperture = (cfg.arr.Nel - 1) * cfg.arr.dz;
expected_snr_gain_db = 10 * log10(cfg.arr.Nel);
bw_eq = 50.8 * 1.45 * cfg.arr.lambda / (N_arc - 1) / d_eq;
bw_eq = round(bw_eq * 100) / 100;
search_range = bw_eq;
search_step = 0.005;
angle_grid = (azCtr_deg - search_range):search_step:(azCtr_deg + search_range);

P_sub = N_arc - K_fbss + 1;
p_mid = round((P_sub + 1) / 2);
col_center = col_select(p_mid:p_mid + K_fbss - 1);
assert(numel(col_center) == K_fbss, 'FBSS center subarray length mismatch.');
assert(col_center(end) - col_center(1) == K_fbss - 1, 'FBSS center subarray indices are not contiguous.');
X_K = arrInfo.XAct(col_center, iel_select);
Y_K = arrInfo.YAct(col_center, iel_select);
A_ref_K = exp(-j * 2*pi / cfg.arr.lambda * (X_K * cosd(azCtr_deg) + Y_K * sind(azCtr_deg)));

A_real_grid = exp(-j * 2*pi / cfg.arr.lambda * (X_K * cosd(angle_grid) + Y_K * sind(angle_grid)));
A_real_grid = A_real_grid .* conj(A_ref_K);
A_real_grid = A_real_grid ./ vecnorm(A_real_grid, 2, 1);
A_ula_grid = exp(-j * 2*pi * d_eq * (0:K_fbss-1).' * sind(angle_grid) / cfg.arr.lambda);
A_ula_grid = A_ula_grid ./ vecnorm(A_ula_grid, 2, 1);

N_64 = 64;
d_64 = 0.047;
fc_64 = 2.7e9;
lambda_64 = 3e8 / fc_64;
bw_64 = 50.8 * 1.45 * lambda_64 / (N_64 - 1) / d_64;
bw_64 = round(bw_64 * 10) / 10;
theta_c_64 = 13;
K_fbss_64 = 56;
sep_factor_list_64 = [7, 8, 9, 10];
snr_list_64 = 14:2:28;
pos_N64 = d_64 * (0:N_64-1).';
t_64 = linspace(0, 1, T_snap);
s1_64 = exp(j * 2*pi * fc_64 * t_64);
s2_64 = exp(j * 2*pi * fc_64 * t_64);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 1 geometry health check');
log_msg(fid_log, 'arc_dist=%.8f m, arc/lambda=%.8f, subArc_span_deg=%.6f', arc_dist, arc_over_lambda, subArc_span_deg);
log_msg(fid_log, 'N_arc=%d, K_fbss=%d, N_arc_span_deg=%.6f, edge_offset_deg=%.6f, bw_eq=%.6f deg', ...
    N_arc, K_fbss, N_arc_span_deg, edge_offset_deg, bw_eq);
log_msg(fid_log, 'dz/lambda=%.8f, elev_aperture=%.8f m, expected_snr_gain=%.6f dB', ...
    dz_over_lambda, elev_aperture, expected_snr_gain_db);
log_msg(fid_log, 'P_sub=%d, p_mid=%d, col_center(local)=%s', P_sub, p_mid, mat2str(col_center));
log_msg(fid_log, 'col_center global cols=%s', mat2str(arrInfo.colsAct(col_center)));
log_msg(fid_log, 'X_K range=[%.8f %.8f] m, Y_K range=[%.8f %.8f] m', min(X_K), max(X_K), min(Y_K), max(Y_K));
log_msg(fid_log, 'max |X_K-X_K(1)|=%.8f m, max |Y_K-Y_K(1)|=%.8f m', ...
    max(abs(X_K - X_K(1))), max(abs(Y_K - Y_K(1))));
log_msg(fid_log, 'grid search: range=+/-%.3f deg, step=%.3f deg, ngrid=%d', search_range, search_step, numel(angle_grid));

assert(abs(dz_over_lambda - 17e-3/0.030) / (17e-3/0.030) < 0.01, 'dz/lambda check failed.');
assert(abs(elev_aperture - 0.527) / 0.527 < 0.01, 'elev aperture check failed.');
assert(abs(expected_snr_gain_db - 15.0515) / 15.0515 < 0.01, 'expected gain check failed.');
assert(K_fbss == 28 && P_sub == 5 && p_mid == 3, 'FBSS geometry check failed.');
log_msg(fid_log, 'Layer 1 passed.');

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 2 fully in-phase sanity check');
sep_factor_sanity = 5;
snr_sanity = 28;
theta_sep_sanity = bw_eq / sep_factor_sanity;
theta_a_sanity = theta_c - theta_sep_sanity/2;
theta_b_sanity = theta_c + theta_sep_sanity/2;
target_sanity = [theta_a_sanity, theta_b_sanity];
y_clean_2d_sanity = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
    theta_a_sanity, theta_b_sanity, el_a, el_b, s1, s2);
noise_power_sanity = mean(abs(y_clean_2d_sanity(:)).^2) / 10^(snr_sanity / 10);
rng(base_seed, 'twister');
noise_2d_sanity = sqrt(noise_power_sanity / 2) * (randn(size(y_clean_2d_sanity)) + j * randn(size(y_clean_2d_sanity)));
y_2d_sanity = y_clean_2d_sanity + noise_2d_sanity;
y_combined_sanity = combine_layers_local(y_2d_sanity, Z3d, cfg.arr.lambda, el_assumed);
[En_sanity, eigvals_sanity, lambda2_sanity] = fbss_noise_subspace(y_combined_sanity, K_fbss, Lc);
[doa_real_sanity, peaks_real_sanity, Pmu_real_sanity] = grid_music_estimate(En_sanity, A_real_grid, angle_grid, Lc);
[doa_ula_sanity, peaks_ula_sanity, Pmu_ula_sanity] = grid_music_estimate(En_sanity, A_ula_grid, angle_grid, Lc);
err_real_sanity = max(abs(sort(doa_real_sanity) - sort(target_sanity)));
err_ula_sanity = max(abs(sort(doa_ula_sanity) - sort(target_sanity)));
sanity_real_ok = all(isfinite(doa_real_sanity)) && err_real_sanity < 0.05;
sanity_ula_ok = all(isfinite(doa_ula_sanity)) && err_ula_sanity < 0.30;
log_msg(fid_log, 'Real manifold grid sanity: pass=%d, doa=[%.4f %.4f], true=[%.4f %.4f], max_err=%.4f deg, peaks=%d, lambda2_over_noise=%.4g', ...
    sanity_real_ok, doa_real_sanity(1), doa_real_sanity(2), target_sanity(1), target_sanity(2), err_real_sanity, peaks_real_sanity, lambda2_sanity);
log_msg(fid_log, 'ULA grid ablation sanity: pass=%d, doa=[%.4f %.4f], true=[%.4f %.4f], max_err=%.4f deg, peaks=%d', ...
    sanity_ula_ok, doa_ula_sanity(1), doa_ula_sanity(2), target_sanity(1), target_sanity(2), err_ula_sanity, peaks_ula_sanity);

theta_sep_64_sanity = bw_64 / sep_factor_sanity;
theta_a_64_sanity = theta_c_64 - theta_sep_64_sanity/2;
theta_b_64_sanity = theta_c_64 + theta_sep_64_sanity/2;
A_a_64_sanity = exp(-j * 2*pi * pos_N64 * sind(theta_a_64_sanity) / lambda_64);
A_b_64_sanity = exp(-j * 2*pi * pos_N64 * sind(theta_b_64_sanity) / lambda_64);
y_clean_64_sanity = A_a_64_sanity * s1_64 + A_b_64_sanity * s2_64;
rng(base_seed, 'twister');
noise_power_64_sanity = mean(abs(y_clean_64_sanity(:)).^2) / 10^(snr_sanity / 10);
noise_64_sanity = sqrt(noise_power_64_sanity / 2) * (randn(size(y_clean_64_sanity)) + j * randn(size(y_clean_64_sanity)));
y_64_sanity = y_clean_64_sanity + noise_64_sanity;
[doa_64_sanity, dbg_64_sanity] = doa_root_music_array(y_64_sanity, K_fbss_64, lambda_64, d_64, Lc);
sanity_64_err = max(abs(sort(doa_64_sanity) - sort([theta_a_64_sanity, theta_b_64_sanity])));
sanity_64_ok = all(isfinite(doa_64_sanity)) && sanity_64_err < 0.05;
log_msg(fid_log, 'Proto6 replay sanity: pass=%d, doa=[%.4f %.4f], true=[%.4f %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g', ...
    sanity_64_ok, doa_64_sanity(1), doa_64_sanity(2), theta_a_64_sanity, theta_b_64_sanity, sanity_64_err, dbg_64_sanity.lambda2_over_noise);
if ~(sanity_real_ok && sanity_ula_ok && sanity_64_ok)
    error('Prototype 15.A sanity check failed.');
end
log_msg(fid_log, 'Layer 2 passed.');

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);
raw_success_count = zeros(2, nsep, nsnr);
tol_success_count = zeros(2, nsep, nsnr);
tol_success_count_rel = zeros(2, nsep, nsnr);
rmse_sum_sqerr = zeros(2, nsep, nsnr);
rmse_valid_count = zeros(2, nsep, nsnr);
est_sum = zeros(2, nsep, nsnr, Lc);
lambda2_sum = zeros(2, nsep, nsnr);
lambda2_count = zeros(2, nsep, nsnr);
degraded_sample_count = zeros(2, nsep, nsnr);
num_peaks_sum = zeros(2, nsep, nsnr);
theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
spectrum_example = struct();

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 real-manifold and ULA-grid ablation regression starts');
tic;
for iSep = 1:nsep
    sep_factor = sep_factor_list(iSep);
    theta_sep = bw_eq / sep_factor;
    theta_a = theta_c - theta_sep / 2;
    theta_b = theta_c + theta_sep / 2;
    target_theta = [theta_a, theta_b];
    tol_deg_rel = tol_rel_ratio * theta_sep;
    theta_sep_deg(iSep) = theta_sep;
    theta_a_deg(iSep) = theta_a;
    theta_b_deg(iSep) = theta_b;

    y_clean_2d = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
        theta_a, theta_b, el_a, el_b, s1, s2);
    log_msg(fid_log, 'sep_factor=%d, theta_sep=%.6f deg, theta_a=%.6f, theta_b=%.6f', ...
        sep_factor, theta_sep, theta_a, theta_b);

    for iSNR = 1:nsnr
        snr_db = snr_list(iSNR);
        noise_power_2d = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);

        for metkl_num = 1:Metkl
            seed_now = base_seed + 100000*iSep + 1000*iSNR + metkl_num;
            rng(seed_now, 'twister');
            noise_2d = sqrt(noise_power_2d / 2) * (randn(size(y_clean_2d)) + j * randn(size(y_clean_2d)));
            y_2d = y_clean_2d + noise_2d;
            y_combined = combine_layers_local(y_2d, Z3d, cfg.arr.lambda, el_assumed);
            [En, ~, lambda2_over_noise] = fbss_noise_subspace(y_combined, K_fbss, Lc);
            [doa_real, npeak_real, Pmu_real] = grid_music_estimate(En, A_real_grid, angle_grid, Lc);
            [doa_ula, npeak_ula, Pmu_ula] = grid_music_estimate(En, A_ula_grid, angle_grid, Lc);

            doa_all = {doa_real, doa_ula};
            npeak_all = [npeak_real, npeak_ula];
            for iroute = 1:2
                doa_now = doa_all{iroute};
                raw_ok = all(isfinite(doa_now));
                tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_deg_rel);
                doa_degraded = true;
                if raw_ok
                    raw_success_count(iroute, iSep, iSNR) = raw_success_count(iroute, iSep, iSNR) + 1;
                    doa_sorted = sort(doa_now(:).');
                    err = doa_sorted - sort(target_theta(:).');
                    doa_degraded = max(abs(err)) > 1.0;
                    rmse_sum_sqerr(iroute, iSep, iSNR) = rmse_sum_sqerr(iroute, iSep, iSNR) + sum(err.^2);
                    rmse_valid_count(iroute, iSep, iSNR) = rmse_valid_count(iroute, iSep, iSNR) + 1;
                    est_sum(iroute, iSep, iSNR, :) = squeeze(est_sum(iroute, iSep, iSNR, :)).' + doa_sorted;
                end
                if doa_degraded
                    degraded_sample_count(iroute, iSep, iSNR) = degraded_sample_count(iroute, iSep, iSNR) + 1;
                end
                if tol_ok_abs
                    tol_success_count(iroute, iSep, iSNR) = tol_success_count(iroute, iSep, iSNR) + 1;
                end
                if tol_ok_rel
                    tol_success_count_rel(iroute, iSep, iSNR) = tol_success_count_rel(iroute, iSep, iSNR) + 1;
                end
                lambda2_sum(iroute, iSep, iSNR) = lambda2_sum(iroute, iSep, iSNR) + lambda2_over_noise;
                lambda2_count(iroute, iSep, iSNR) = lambda2_count(iroute, iSep, iSNR) + 1;
                num_peaks_sum(iroute, iSep, iSNR) = num_peaks_sum(iroute, iSep, iSNR) + npeak_all(iroute);
            end

            if sep_factor == 10 && snr_db == 30 && metkl_num == 1
                spectrum_example.angle_grid = angle_grid;
                spectrum_example.Pmu_real = Pmu_real / max(Pmu_real);
                spectrum_example.Pmu_ula = Pmu_ula / max(Pmu_ula);
                spectrum_example.target_theta = target_theta;
                spectrum_example.doa_real = doa_real;
                spectrum_example.doa_ula = doa_ula;
            end
        end
    end
    log_msg(fid_log, 'sep_factor=%d finished, elapsed=%.1f s', sep_factor, toc);
end

raw_success_rate_new = raw_success_count / Metkl;
tol_success_rate_new = tol_success_count / Metkl;
tol_success_rate_rel_new = tol_success_count_rel / Metkl;
rmse_new = sqrt(rmse_sum_sqerr ./ max(rmse_valid_count, 1) / Lc);
rmse_new(rmse_valid_count == 0) = NaN;
lambda2_over_noise_new = lambda2_sum ./ max(lambda2_count, 1);
num_peaks_mean_new = num_peaks_sum / Metkl;
[mean_bias_new, max_bias_new] = summarize_bias_local(est_sum, rmse_valid_count, theta_a_deg, theta_b_deg);
snr90_new = calc_snr90(tol_success_rate_new, snr_list);
snr90_rel_new = calc_snr90(tol_success_rate_rel_new, snr_list);

proto14_route_idx = find(strcmp(proto14_data.route_names, 'cylindrical_multilayer_coherent_proto14_main'), 1);
assert(~isempty(proto14_route_idx), 'Cannot find proto14 route.');
raw_success_rate_all = nan(nroutes, nsep, nsnr);
tol_success_rate_all = nan(nroutes, nsep, nsnr);
tol_success_rate_rel_all = nan(nroutes, nsep, nsnr);
rmse_all = nan(nroutes, nsep, nsnr);
mean_bias_all = nan(nroutes, nsep, nsnr);
max_bias_all = nan(nroutes, nsep, nsnr);
degraded_count_all = nan(nroutes, nsep, nsnr);
num_peaks_mean_all = nan(nroutes, nsep, nsnr);
lambda2_over_noise_all = nan(nroutes, nsep, nsnr);
snr90_all = nan(nroutes, nsep);
snr90_rel_all = nan(nroutes, nsep);

raw_success_rate_all(1, :, :) = proto14_data.raw_success_rate(proto14_route_idx, :, :);
tol_success_rate_all(1, :, :) = proto14_data.tol_success_rate(proto14_route_idx, :, :);
tol_success_rate_rel_all(1, :, :) = proto14_data.tol_success_rate_rel(proto14_route_idx, :, :);
rmse_all(1, :, :) = proto14_data.rmse(proto14_route_idx, :, :);
mean_bias_all(1, :, :) = proto14_data.mean_bias_deg(proto14_route_idx, :, :);
max_bias_all(1, :, :) = proto14_data.max_bias_deg(proto14_route_idx, :, :);
degraded_count_all(1, :, :) = proto14_data.degraded_sample_count(proto14_route_idx, :, :);
num_peaks_mean_all(1, :, :) = proto14_data.mean_num_peaks(proto14_route_idx, :, :);
lambda2_over_noise_all(1, :, :) = proto14_data.lambda2_over_noise(proto14_route_idx, :, :);
snr90_all(1, :) = proto14_data.snr90(proto14_route_idx, :);
snr90_rel_all(1, :) = proto14_data.snr90_rel(proto14_route_idx, :);

for iroute = 2:3
    idx_new = iroute - 1;
    raw_success_rate_all(iroute, :, :) = raw_success_rate_new(idx_new, :, :);
    tol_success_rate_all(iroute, :, :) = tol_success_rate_new(idx_new, :, :);
    tol_success_rate_rel_all(iroute, :, :) = tol_success_rate_rel_new(idx_new, :, :);
    rmse_all(iroute, :, :) = rmse_new(idx_new, :, :);
    mean_bias_all(iroute, :, :) = mean_bias_new(idx_new, :, :);
    max_bias_all(iroute, :, :) = max_bias_new(idx_new, :, :);
    degraded_count_all(iroute, :, :) = degraded_sample_count(idx_new, :, :);
    num_peaks_mean_all(iroute, :, :) = num_peaks_mean_new(idx_new, :, :);
    lambda2_over_noise_all(iroute, :, :) = lambda2_over_noise_new(idx_new, :, :);
    snr90_all(iroute, :) = snr90_new(idx_new, :);
    snr90_rel_all(iroute, :) = snr90_rel_new(idx_new, :);
end

% Route 4 proto6 replay.
[snr90_64, snr90_rel_64, tol_success_rate_64, degraded_count_64] = run_proto6_replay( ...
    sep_factor_list_64, snr_list_64, bw_64, theta_c_64, pos_N64, s1_64, s2_64, ...
    K_fbss_64, lambda_64, d_64, Lc, tol_deg, tol_rel_ratio, Metkl, base_seed);

hist_snr90 = [14, 16, 20, 22];
layer3a_ok = all(isfinite(snr90_64) & abs(snr90_64 - hist_snr90) <= 2);
idx_sep10 = find(sep_factor_list == 10, 1);
idx_snr24 = find(snr_list == 24, 1);
idx_snr30 = find(snr_list == 30, 1);
layer3b_rate = tol_success_rate_all(2, idx_sep10, idx_snr24);
layer3b_ok = layer3b_rate >= 0.85;
snr90_ref_eff = snr90_all(1, :);
snr90_ref_eff(~isfinite(snr90_ref_eff)) = max(snr_list) + 2;
snr90_advance_real = snr90_ref_eff - snr90_all(2, :);
layer3c_ok = all(isfinite(snr90_advance_real) & snr90_advance_real >= 4);
rmse_ratio_3d = rmse_all(2, idx_sep10, idx_snr30) / rmse_all(3, idx_sep10, idx_snr30);
layer3d_ok = rmse_ratio_3d <= 0.5;
degradation_rate = squeeze(sum(degraded_count_all, [2 3])) / (nsep * nsnr * Metkl);
layer3e_ok = degradation_rate(2) < 0.15;
mean_bias_sep10_30 = mean_bias_all(2, idx_sep10, idx_snr30);
layer3f_ok = abs(mean_bias_sep10_30) < 0.005;

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 acceptance checks');
for iSep = 1:nsep
    log_msg(fid_log, 'sep_factor=%d | SNR90 baseline=%s, real=%s, ula_grid=%s | RMSE@30 baseline=%.4f, real=%.4f, ula_grid=%.4f', ...
        sep_factor_list(iSep), fmt_num(snr90_all(1, iSep)), fmt_num(snr90_all(2, iSep)), fmt_num(snr90_all(3, iSep)), ...
        rmse_all(1, iSep, idx_snr30), rmse_all(2, iSep, idx_snr30), rmse_all(3, iSep, idx_snr30));
end
log_msg(fid_log, '3a proto6 replay pass=%d, SNR90=%s dB, history=%s dB', layer3a_ok, mat2str(snr90_64, 4), mat2str(hist_snr90));
log_msg(fid_log, '3b real manifold sep=10 SNR=24 tol_rate=%.6f, pass=%d', layer3b_rate, layer3b_ok);
log_msg(fid_log, '3c real manifold SNR90 advance vs proto14=%s dB, pass=%d', mat2str(snr90_advance_real, 4), layer3c_ok);
log_msg(fid_log, '3d sep=10 SNR=30 RMSE ratio real/ULAgrid=%.6f, pass=%d', rmse_ratio_3d, layer3d_ok);
log_msg(fid_log, '3e degradation rates baseline=%.6f, real=%.6f, ula_grid=%.6f, pass=%d', degradation_rate(1), degradation_rate(2), degradation_rate(3), layer3e_ok);
log_msg(fid_log, '3f sep=10 SNR=30 real mean_bias=%.8f deg, pass=%d', mean_bias_sep10_30, layer3f_ok);

summary_path = fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_keypoints.csv');
write_summary_csv(summary_path, route_names, manifold_types, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_rate_all, tol_success_rate_all, tol_success_rate_rel_all, rmse_all, snr90_all, snr90_rel_all, ...
    mean_bias_all, max_bias_all, degraded_count_all, num_peaks_mean_all, lambda2_over_noise_all, ...
    route_name_64, sep_factor_list_64, snr_list_64, snr90_64, snr90_rel_64, tol_success_rate_64, degraded_count_64);
write_keypoints_csv(keypoints_path, route_names, manifold_types, sep_factor_list, snr_list, tol_success_rate_all, rmse_all, ...
    snr90_all, mean_bias_all, max_bias_all, degraded_count_all, num_peaks_mean_all, route_name_64, sep_factor_list_64, snr90_64);

result_mat_path = fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_result.mat');
save(result_mat_path, ...
    'route_names', 'manifold_types', 'route_name_64', 'sep_factor_list', 'snr_list', 'Metkl', 'T_snap', ...
    'tol_deg', 'tol_rel_ratio', 'base_seed', 'N_arc', 'K_fbss', 'Lc', 'bw_eq', 'search_range', 'search_step', ...
    'angle_grid', 'col_center', 'X_K', 'Y_K', 'raw_success_rate_all', 'tol_success_rate_all', ...
    'tol_success_rate_rel_all', 'rmse_all', 'snr90_all', 'snr90_rel_all', 'mean_bias_all', 'max_bias_all', ...
    'degraded_count_all', 'num_peaks_mean_all', 'lambda2_over_noise_all', 'snr90_64', 'snr90_rel_64', ...
    'tol_success_rate_64', 'degraded_count_64', 'spectrum_example', 'layer3a_ok', 'layer3b_ok', 'layer3c_ok', ...
    'layer3d_ok', 'layer3e_ok', 'layer3f_ok', 'rmse_ratio_3d', 'mean_bias_sep10_30', 'degradation_rate');

plot_manifold_compare(fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_manifold_compare.png'), ...
    angle_grid, A_real_grid, A_ula_grid, bw_eq);
plot_rmse_compare(fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_rmse_compare.png'), ...
    route_names, sep_factor_list, snr_list, rmse_all);
plot_snr90(fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_snr90.png'), ...
    route_names, sep_factor_list, snr90_all);
plot_spectrum_example(fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_spectrum_example.png'), spectrum_example);
plot_proto6_replay(fullfile(result_dir, 'step8_5_cylindrical_real_manifold_proto15a_proto6_replay.png'), ...
    sep_factor_list_64, snr90_64, hist_snr90, tol_success_rate_64, snr_list_64);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 4 diagnostics generated.');
log_msg(fid_log, 'Generated figures: manifold_compare, rmse_compare, snr90, spectrum_example, proto6_replay.');
log_msg(fid_log, 'Result directory: %s', result_dir);
log_msg(fid_log, '');
log_msg(fid_log, '4-layer acceptance summary');
log_msg(fid_log, 'Layer 1 geometry: PASS');
log_msg(fid_log, 'Layer 2 sanity: real=%d (err=%.4f), ula_grid=%d (err=%.4f), proto6=%d (err=%.4f)', ...
    sanity_real_ok, err_real_sanity, sanity_ula_ok, err_ula_sanity, sanity_64_ok, sanity_64_err);
log_msg(fid_log, 'Layer 3 regression: 3a=%d, 3b=%d, 3c=%d, 3d=%d, 3e=%d, 3f=%d', ...
    layer3a_ok, layer3b_ok, layer3c_ok, layer3d_ok, layer3e_ok, layer3f_ok);
log_msg(fid_log, 'Layer 4 figures: PASS');

function y_clean_2d = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, theta_b, el_a, el_b, s1, s2)
    j = sqrt(-1);
    unit_a = [cosd(el_a) * cosd(theta_a), cosd(el_a) * sind(theta_a), sind(el_a)];
    unit_b = [cosd(el_b) * cosd(theta_b), cosd(el_b) * sind(theta_b), sind(el_b)];
    phase_a = X3d * unit_a(1) + Y3d * unit_a(2) + Z3d * unit_a(3);
    phase_b = X3d * unit_b(1) + Y3d * unit_b(2) + Z3d * unit_b(3);
    A_a_2d = conj(A_ref_2d) .* exp(-j * 2*pi / lambda * phase_a);
    A_b_2d = conj(A_ref_2d) .* exp(-j * 2*pi / lambda * phase_b);
    y_clean_2d = reshape(A_a_2d(:) * s1 + A_b_2d(:) * s2, size(X3d, 1), size(X3d, 2), numel(s1));
end

function y_combined = combine_layers_local(y_2d, Z3d, lambda, el_assumed)
    j = sqrt(-1);
    Nel = size(y_2d, 2);
    z_col = Z3d(1, :).';
    steer_el = exp(-j * 2*pi / lambda * z_col * sind(el_assumed));
    W = steer_el' / sqrt(Nel);
    tmp = W * reshape(permute(y_2d, [2, 1, 3]), Nel, []);
    y_combined = reshape(tmp, size(y_2d, 1), size(y_2d, 3));
end

function [En, eigvals, lambda2_over_noise] = fbss_noise_subspace(y, K, Lc)
    T_snap = size(y, 2);
    Rxx = (y * y') / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');
    Rfb = mssp_array_fb(Rxx, K);
    Rfb = 0.5 * (Rfb + Rfb');
    [V, D] = eig(Rfb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
    V = V(:, idx);
    En = V(:, Lc+1:end);
    noise_floor = mean(eigvals(Lc+1:min(numel(eigvals), Lc+6)));
    lambda2_over_noise = eigvals(2) / max(noise_floor, eps);
end

function [doa_est, num_peaks, Pmu] = grid_music_estimate(En, A_grid, angle_grid, Lc)
    C = En * En';
    CA = C * A_grid;
    den = real(sum(conj(A_grid) .* CA, 1));
    Pmu = 1 ./ max(den, eps);
    [~, peak_inds] = FindLocalPeak_NoEdge_Fun(Pmu);
    num_peaks = numel(peak_inds);
    if num_peaks < Lc
        doa_est = nan(1, Lc);
    else
        doa_est = sort(angle_grid(peak_inds(1:Lc)));
    end
end

function snr90 = calc_snr90(rate_cube, snr_list)
    [nroutes, nsep, ~] = size(rate_cube);
    snr90 = nan(nroutes, nsep);
    for iroute = 1:nroutes
        for iSep = 1:nsep
            idx = find(squeeze(rate_cube(iroute, iSep, :)) >= 0.9, 1, 'first');
            if ~isempty(idx)
                snr90(iroute, iSep) = snr_list(idx);
            end
        end
    end
end

function snr90 = calc_snr90_2d(rate_mat, snr_list)
    nsep = size(rate_mat, 1);
    snr90 = nan(1, nsep);
    for iSep = 1:nsep
        idx = find(rate_mat(iSep, :) >= 0.9, 1, 'first');
        if ~isempty(idx)
            snr90(iSep) = snr_list(idx);
        end
    end
end

function [mean_bias_deg, max_bias_deg] = summarize_bias_local(est_sum, valid_count, theta_a_deg, theta_b_deg)
    [nroutes, nsep, nsnr, ~] = size(est_sum);
    mean_bias_deg = nan(nroutes, nsep, nsnr);
    max_bias_deg = nan(nroutes, nsep, nsnr);
    for iroute = 1:nroutes
        for iSep = 1:nsep
            for iSNR = 1:nsnr
                count_now = valid_count(iroute, iSep, iSNR);
                if count_now > 0
                    mean_pair = squeeze(est_sum(iroute, iSep, iSNR, :)).' / count_now;
                    bias_pair = mean_pair - [theta_a_deg(iSep), theta_b_deg(iSep)];
                    mean_bias_deg(iroute, iSep, iSNR) = mean(bias_pair);
                    max_bias_deg(iroute, iSep, iSNR) = max(abs(bias_pair));
                end
            end
        end
    end
end

function [snr90_64, snr90_rel_64, tol_success_rate_64, degraded_count_64] = run_proto6_replay( ...
    sep_factor_list_64, snr_list_64, bw_64, theta_c_64, pos_N64, s1_64, s2_64, K_fbss_64, lambda_64, d_64, Lc, tol_deg, tol_rel_ratio, Metkl, base_seed)
    j = sqrt(-1);
    nsep64 = numel(sep_factor_list_64);
    nsnr64 = numel(snr_list_64);
    tol_count_64 = zeros(nsep64, nsnr64);
    tol_count_rel_64 = zeros(nsep64, nsnr64);
    degraded_count_64 = zeros(nsep64, nsnr64);
    for iSep64 = 1:nsep64
        theta_sep_64 = bw_64 / sep_factor_list_64(iSep64);
        theta_a_64 = theta_c_64 - theta_sep_64/2;
        theta_b_64 = theta_c_64 + theta_sep_64/2;
        target_theta_64 = [theta_a_64, theta_b_64];
        tol_deg_rel_64 = tol_rel_ratio * theta_sep_64;
        A_a_64 = exp(-j * 2*pi * pos_N64 * sind(theta_a_64) / lambda_64);
        A_b_64 = exp(-j * 2*pi * pos_N64 * sind(theta_b_64) / lambda_64);
        y_clean_64 = A_a_64 * s1_64 + A_b_64 * s2_64;
        for iSNR64 = 1:nsnr64
            noise_power_64 = mean(abs(y_clean_64(:)).^2) / 10^(snr_list_64(iSNR64) / 10);
            for metkl_num = 1:Metkl
                seed_64 = base_seed + 100000 * (iSep64 + 100) + 1000 * iSNR64 + metkl_num;
                rng(seed_64, 'twister');
                noise_64 = sqrt(noise_power_64 / 2) * (randn(size(y_clean_64)) + j * randn(size(y_clean_64)));
                y_64 = y_clean_64 + noise_64;
                doa_64 = doa_root_music_array(y_64, K_fbss_64, lambda_64, d_64, Lc);
                if is_valid_doa_success(doa_64, target_theta_64, tol_deg)
                    tol_count_64(iSep64, iSNR64) = tol_count_64(iSep64, iSNR64) + 1;
                end
                if is_valid_doa_success(doa_64, target_theta_64, tol_deg_rel_64)
                    tol_count_rel_64(iSep64, iSNR64) = tol_count_rel_64(iSep64, iSNR64) + 1;
                end
                if ~all(isfinite(doa_64)) || max(abs(sort(doa_64) - sort(target_theta_64))) > 1.0
                    degraded_count_64(iSep64, iSNR64) = degraded_count_64(iSep64, iSNR64) + 1;
                end
            end
        end
    end
    tol_success_rate_64 = tol_count_64 / Metkl;
    tol_success_rate_rel_64 = tol_count_rel_64 / Metkl;
    snr90_64 = calc_snr90_2d(tol_success_rate_64, snr_list_64);
    snr90_rel_64 = calc_snr90_2d(tol_success_rate_rel_64, snr_list_64);
end

function write_summary_csv(path_out, route_names, manifold_types, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_rate, tol_success_rate, tol_success_rate_rel, rmse, snr90, snr90_rel, mean_bias_deg, max_bias_deg, ...
    degraded_count, num_peaks_mean, lambda2_over_noise, route_name_64, sep_factor_list_64, snr_list_64, snr90_64, snr90_rel_64, ...
    tol_success_rate_64, degraded_count_64)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['route_name,manifold_type,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
        'raw_success_rate,tol_success_rate,tol_success_rate_rel,rmse_deg,snr90_db,snr90_rel_db,' ...
        'mean_bias_deg,max_bias_deg,degraded_sample_count,num_peaks_found,lambda2_over_noise\n']);
    for iroute = 1:numel(route_names)
        for iSep = 1:numel(sep_factor_list)
            for iSNR = 1:numel(snr_list)
                fprintf(fid, '%s,%s,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f,%.6f\n', ...
                    route_names{iroute}, manifold_types{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), ...
                    theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), raw_success_rate(iroute, iSep, iSNR), ...
                    tol_success_rate(iroute, iSep, iSNR), tol_success_rate_rel(iroute, iSep, iSNR), rmse(iroute, iSep, iSNR), ...
                    snr90(iroute, iSep), snr90_rel(iroute, iSep), mean_bias_deg(iroute, iSep, iSNR), ...
                    max_bias_deg(iroute, iSep, iSNR), degraded_count(iroute, iSep, iSNR), ...
                    num_peaks_mean(iroute, iSep, iSNR), lambda2_over_noise(iroute, iSep, iSNR));
            end
        end
    end
    for iSep64 = 1:numel(sep_factor_list_64)
        for iSNR64 = 1:numel(snr_list_64)
            fprintf(fid, '%s,proto6_replay,%d,NaN,NaN,NaN,%d,NaN,%.6f,NaN,NaN,%.6f,%.6f,NaN,NaN,%d,NaN,NaN\n', ...
                route_name_64, sep_factor_list_64(iSep64), snr_list_64(iSNR64), tol_success_rate_64(iSep64, iSNR64), ...
                snr90_64(iSep64), snr90_rel_64(iSep64), degraded_count_64(iSep64, iSNR64));
        end
    end
end

function write_keypoints_csv(path_out, route_names, manifold_types, sep_factor_list, snr_list, tol_success_rate, rmse, ...
    snr90, mean_bias_deg, max_bias_deg, degraded_count, num_peaks_mean, route_name_64, sep_factor_list_64, snr90_64)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'route_name,manifold_type,sep_factor,snr_db,tol_success_rate_abs01,rmse_deg,snr90_db,mean_bias_deg,max_bias_deg,degraded_sample_count,num_peaks_found\n');
    for iSep = 1:numel(sep_factor_list)
        key_snr_list = unique([min(snr_list), 24, 30, snr90(:, iSep).']);
        key_snr_list = key_snr_list(isfinite(key_snr_list));
        key_snr_list = sort(key_snr_list(key_snr_list >= min(snr_list) & key_snr_list <= max(snr_list)));
        for snr_key = key_snr_list
            idx = find(snr_list == snr_key, 1);
            for iroute = 1:numel(route_names)
                fprintf(fid, '%s,%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
                    route_names{iroute}, manifold_types{iroute}, sep_factor_list(iSep), snr_key, ...
                    tol_success_rate(iroute, iSep, idx), rmse(iroute, iSep, idx), snr90(iroute, iSep), ...
                    mean_bias_deg(iroute, iSep, idx), max_bias_deg(iroute, iSep, idx), ...
                    degraded_count(iroute, iSep, idx), num_peaks_mean(iroute, iSep, idx));
            end
        end
    end
    for iSep64 = 1:numel(sep_factor_list_64)
        fprintf(fid, '%s,proto6_replay,%d,24,NaN,NaN,%.6f,NaN,NaN,NaN,NaN\n', ...
            route_name_64, sep_factor_list_64(iSep64), snr90_64(iSep64));
    end
end

function plot_manifold_compare(path_out, angle_grid, A_real_grid, A_ula_grid, bw_eq)
    corr_val = abs(sum(conj(A_real_grid) .* A_ula_grid, 1));
    [~, idx_edge] = min(abs(angle_grid - bw_eq));
    phase_real = unwrap(angle(A_real_grid(:, idx_edge)));
    phase_ula = unwrap(angle(A_ula_grid(:, idx_edge)));
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 680]);
    subplot(2, 1, 1);
    plot(angle_grid, corr_val, 'LineWidth', 1.4);
    grid on
    xlabel('azimuth (deg)');
    ylabel('|a real^H a ULA|');
    title('Real manifold versus ULA manifold correlation');
    subplot(2, 1, 2);
    plot(1:numel(phase_real), phase_real - phase_real(1), '-o', 'LineWidth', 1.0);
    hold on
    plot(1:numel(phase_ula), phase_ula - phase_ula(1), '-s', 'LineWidth', 1.0);
    hold off
    grid on
    xlabel('FBSS center subarray element');
    ylabel('relative phase at +bw_eq (rad)');
    legend({'real XY', 'ULA'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_rmse_compare(path_out, route_names, sep_factor_list, snr_list, rmse)
    fig = figure('Visible', 'off', 'Position', [80, 80, 1150, 900]);
    for iSep = 1:numel(sep_factor_list)
        subplot(3, 2, iSep);
        for iroute = 1:numel(route_names)
            plot(snr_list, squeeze(rmse(iroute, iSep, :)), 'LineWidth', 1.1);
            hold on
        end
        yline(0.1, '--');
        hold off
        grid on
        title(sprintf('sep=%d', sep_factor_list(iSep)));
        xlabel('SNR (dB)');
        ylabel('RMSE (deg)');
        if iSep == 1
            legend(route_names, 'Interpreter', 'none', 'Location', 'best');
        end
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_snr90(path_out, route_names, sep_factor_list, snr90)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 540]);
    for iroute = 1:numel(route_names)
        plot(sep_factor_list, snr90(iroute, :), '-o', 'LineWidth', 1.4);
        hold on
    end
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 abs01 (dB)');
    title('Prototype15.A SNR90');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_spectrum_example(path_out, spectrum_example)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 520]);
    plot(spectrum_example.angle_grid, 10*log10(spectrum_example.Pmu_real), 'LineWidth', 1.3);
    hold on
    plot(spectrum_example.angle_grid, 10*log10(spectrum_example.Pmu_ula), 'LineWidth', 1.3);
    xline(spectrum_example.target_theta(1), '--');
    xline(spectrum_example.target_theta(2), '--');
    hold off
    grid on
    xlabel('azimuth (deg)');
    ylabel('normalized MUSIC spectrum (dB)');
    title(sprintf('sep=10, SNR=30 dB, real doa=[%.3f %.3f], ULA doa=[%.3f %.3f]', ...
        spectrum_example.doa_real(1), spectrum_example.doa_real(2), spectrum_example.doa_ula(1), spectrum_example.doa_ula(2)));
    legend({'real manifold', 'ULA manifold', 'true az'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_proto6_replay(path_out, sep_factor_list_64, snr90_64, hist_snr90, tol_success_rate_64, snr_list_64)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 620]);
    subplot(2, 1, 1);
    plot(sep_factor_list_64, snr90_64, '-o', 'LineWidth', 1.4);
    hold on
    plot(sep_factor_list_64, hist_snr90, '--s', 'LineWidth', 1.2);
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 abs01 (dB)');
    legend({'proto15.A replay', 'proto6 history'}, 'Location', 'best');
    subplot(2, 1, 2);
    imagesc(snr_list_64, sep_factor_list_64, tol_success_rate_64);
    colorbar
    caxis([0 1]);
    xlabel('SNR (dB)');
    ylabel('sep factor');
    title('Proto6 replay tol success');
    saveas(fig, path_out);
    close(fig);
end

function out = fmt_num(x)
    if ~isfinite(x)
        out = 'NaN';
    else
        out = sprintf('%.0f', x);
    end
end

function log_msg(fid, varargin)
    msg = sprintf(varargin{:});
    fprintf('%s\n', msg);
    fprintf(fid, '%s\n', msg);
end
