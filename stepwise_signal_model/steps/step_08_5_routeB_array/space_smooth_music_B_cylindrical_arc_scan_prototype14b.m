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

result_dir = fullfile(script_dir, 'results_step8_5_cylindrical_arc_scan_proto14b');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() fclose(fid_log));

log_msg(fid_log, 'Step 08.5 Prototype 14b: cylindrical arc N_arc=48/64 aperture scan');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Frozen algorithm paths: %s ; %s', step08_dir, step75_dir);

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
el_a = 0;
el_b = 0;
el_assumed = 0;
theta_c = azCtr_deg;
Lc = 2;
N_arc_scan = [48, 64];
K_scan = N_arc_scan - 4;
N_arc_all = [32, N_arc_scan];
K_all_routes = [28, K_scan];
route_names = { ...
    'multilayer_coherent_proto14_N32_baseline', ...
    'multilayer_coherent_proto14b_N48_main', ...
    'multilayer_coherent_proto14b_N64_main'};
route_name_64 = 'pure_ula_root_music_64ch_proto6_replay';

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s1 = exp(j * 2*pi * cfg.arr.fc * t);
s2 = exp(j * 2*pi * cfg.arr.fc * t);

arrInfo = arr_cyl(cfg, azCtr_deg);
col_mid = round((cfg.beam.subNaz + 1) / 2);
iel_select_all = 1:cfg.arr.Nel;
d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
arc_dist = d_eq;
arc_over_lambda = arc_dist / cfg.arr.lambda;
subArc_span_deg = (cfg.beam.subNaz - 1) * cfg.arr.dPhi;
dz_over_lambda = cfg.arr.dz / cfg.arr.lambda;
expected_snr_gain_db = 10 * log10(cfg.arr.Nel);

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

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);
nscan = numel(N_arc_scan);

% Route 1: load N_arc=32 multilayer main from proto14.
proto14_route_idx = find(strcmp(proto14_data.route_names, 'cylindrical_multilayer_coherent_proto14_main'), 1);
assert(~isempty(proto14_route_idx), 'Cannot find proto14 N32 main route.');
raw_success_rate_all = nan(3, nsep, nsnr);
tol_success_rate_all = nan(3, nsep, nsnr);
tol_success_rate_rel_all = nan(3, nsep, nsnr);
rmse_all = nan(3, nsep, nsnr);
mean_bias_deg_all = nan(3, nsep, nsnr);
max_bias_deg_all = nan(3, nsep, nsnr);
lambda2_over_noise_all = nan(3, nsep, nsnr);
degraded_sample_count_all = nan(3, nsep, nsnr);
measured_snr_gain_db_all = nan(3, nsep, nsnr);
snr90_all = nan(3, nsep);
snr90_rel_all = nan(3, nsep);
theta_sep_deg_all = nan(3, nsep);
theta_a_deg_all = nan(3, nsep);
theta_b_deg_all = nan(3, nsep);
bw_eq_all = nan(1, 3);
N_arc_span_deg_all = nan(1, 3);
edge_offset_deg_all = nan(1, 3);
sin_phi_over_phi_all = nan(1, 3);
steering_mismatch_pct_all = nan(1, 3);

raw_success_rate_all(1, :, :) = proto14_data.raw_success_rate(proto14_route_idx, :, :);
tol_success_rate_all(1, :, :) = proto14_data.tol_success_rate(proto14_route_idx, :, :);
tol_success_rate_rel_all(1, :, :) = proto14_data.tol_success_rate_rel(proto14_route_idx, :, :);
rmse_all(1, :, :) = proto14_data.rmse(proto14_route_idx, :, :);
mean_bias_deg_all(1, :, :) = proto14_data.mean_bias_deg(proto14_route_idx, :, :);
max_bias_deg_all(1, :, :) = proto14_data.max_bias_deg(proto14_route_idx, :, :);
lambda2_over_noise_all(1, :, :) = proto14_data.lambda2_over_noise(proto14_route_idx, :, :);
degraded_sample_count_all(1, :, :) = proto14_data.degraded_sample_count(proto14_route_idx, :, :);
measured_snr_gain_db_all(1, :, :) = proto14_data.measured_snr_gain_db(proto14_route_idx, :, :);
snr90_all(1, :) = proto14_data.snr90(proto14_route_idx, :);
snr90_rel_all(1, :) = proto14_data.snr90_rel(proto14_route_idx, :);
theta_sep_deg_all(1, :) = proto14_data.theta_sep_deg;
theta_a_deg_all(1, :) = proto14_data.theta_a_deg;
theta_b_deg_all(1, :) = proto14_data.theta_b_deg;

raw_success_count_scan = zeros(nscan, nsep, nsnr);
tol_success_count_scan = zeros(nscan, nsep, nsnr);
tol_success_count_rel_scan = zeros(nscan, nsep, nsnr);
rmse_sum_sqerr_scan = zeros(nscan, nsep, nsnr);
rmse_valid_count_scan = zeros(nscan, nsep, nsnr);
est_sum_scan = zeros(nscan, nsep, nsnr, Lc);
lambda2_over_noise_sum_scan = zeros(nscan, nsep, nsnr);
lambda2_count_scan = zeros(nscan, nsep, nsnr);
degraded_sample_count_scan = zeros(nscan, nsep, nsnr);
measured_snr_gain_db_scan = nan(nscan, nsep, nsnr);
theta_sep_deg_scan = nan(nscan, nsep);
theta_a_deg_scan = nan(nscan, nsep);
theta_b_deg_scan = nan(nscan, nsep);
bw_eq_scan = nan(1, nscan);
N_arc_span_deg_scan = nan(1, nscan);
edge_offset_deg_scan = nan(1, nscan);
sin_phi_over_phi_scan = nan(1, nscan);
steering_mismatch_pct_scan = nan(1, nscan);
sanity_ok_scan = false(1, nscan);
sanity_err_scan = nan(1, nscan);
sanity_doa_scan = nan(nscan, Lc);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 1 geometry health check');
log_msg(fid_log, 'cfg.beam.sectorHalf=%.6f deg, cfg.beam.subNaz=%d, subArc_span_deg=%.6f deg', ...
    cfg.beam.sectorHalf, cfg.beam.subNaz, subArc_span_deg);
log_msg(fid_log, 'arc_dist=%.8f m, arc/lambda=%.8f, dz/lambda=%.8f, expected layer gain=%.4f dB', ...
    arc_dist, arc_over_lambda, dz_over_lambda, expected_snr_gain_db);

for iRoute = 1:3
    N_arc = N_arc_all(iRoute);
    N_arc_span_deg_all(iRoute) = (N_arc - 1) * cfg.arr.dPhi;
    edge_offset_deg_all(iRoute) = N_arc_span_deg_all(iRoute) / 2;
    phi_rad = deg2rad(edge_offset_deg_all(iRoute));
    sin_phi_over_phi_all(iRoute) = sin(phi_rad) / phi_rad;
    steering_mismatch_pct_all(iRoute) = (1 - sin_phi_over_phi_all(iRoute)) * 100;
    bw_eq_all(iRoute) = 50.8 * 1.45 * cfg.arr.lambda / (N_arc - 1) / d_eq;
    bw_eq_all(iRoute) = round(bw_eq_all(iRoute) * 100) / 100;
end
bw_eq_scan = bw_eq_all(2:3);
N_arc_span_deg_scan = N_arc_span_deg_all(2:3);
edge_offset_deg_scan = edge_offset_deg_all(2:3);
sin_phi_over_phi_scan = sin_phi_over_phi_all(2:3);
steering_mismatch_pct_scan = steering_mismatch_pct_all(2:3);

for iScan = 1:nscan
    log_msg(fid_log, 'N_arc=%d, K_fbss=%d, N_arc_span_deg=%.6f, edge_offset_deg=%.6f, sin(phi)/phi=%.6f, mismatch=%.3f%%, bw_eq=%.6f deg', ...
        N_arc_scan(iScan), K_scan(iScan), N_arc_span_deg_scan(iScan), edge_offset_deg_scan(iScan), ...
        sin_phi_over_phi_scan(iScan), steering_mismatch_pct_scan(iScan), bw_eq_scan(iScan));
end
assert(abs(N_arc_span_deg_scan(1) - 88.125) / 88.125 < 0.01, 'N_arc=48 span check failed.');
assert(abs(edge_offset_deg_scan(1) - 44.0625) / 44.0625 < 0.01, 'N_arc=48 edge check failed.');
assert(abs(sin_phi_over_phi_scan(1) - 0.911) / 0.911 < 0.01, 'N_arc=48 sin/phi check failed.');
assert(abs(bw_eq_scan(1) - 3.59) / 3.59 < 0.01, 'N_arc=48 bw check failed.');
assert(abs(N_arc_span_deg_scan(2) - 118.125) / 118.125 < 0.01, 'N_arc=64 span check failed.');
assert(abs(edge_offset_deg_scan(2) - 59.0625) / 59.0625 < 0.01, 'N_arc=64 edge check failed.');
assert(abs(sin_phi_over_phi_scan(2) - 0.832) / 0.832 < 0.01, 'N_arc=64 sin/phi check failed.');
assert(abs(bw_eq_scan(2) - 2.68) / 2.68 < 0.01, 'N_arc=64 bw check failed.');
log_msg(fid_log, 'Layer 1 passed.');

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 2 fully in-phase sanity check');
sep_factor_sanity = 5;
snr_sanity = 28;
for iScan = 1:nscan
    N_arc = N_arc_scan(iScan);
    K_fbss = K_scan(iScan);
    [X3d, Y3d, Z3d, A_ref_2d] = get_geometry_for_narc(arrInfo, col_mid, N_arc, cfg);
    theta_sep = bw_eq_scan(iScan) / sep_factor_sanity;
    theta_a = theta_c - theta_sep/2;
    theta_b = theta_c + theta_sep/2;
    target_theta = [theta_a, theta_b];
    y_clean_2d = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
        theta_a, theta_b, el_a, el_b, s1, s2);
    noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(snr_sanity / 10);
    rng(base_seed + iScan * 1e7, 'twister');
    noise_2d = sqrt(noise_power / 2) * (randn(size(y_clean_2d)) + j * randn(size(y_clean_2d)));
    y_2d = y_clean_2d + noise_2d;
    y_combined = combine_layers_local(y_2d, Z3d, cfg.arr.lambda, el_assumed);
    [doa_sanity, dbg_sanity] = doa_root_music_array(y_combined, K_fbss, cfg.arr.lambda, d_eq, Lc);
    sanity_err = max(abs(sort(doa_sanity) - sort(target_theta)));
    threshold = 0.10;
    if N_arc == 64
        threshold = 0.15;
    end
    sanity_ok_scan(iScan) = all(isfinite(doa_sanity)) && sanity_err < threshold;
    sanity_err_scan(iScan) = sanity_err;
    sanity_doa_scan(iScan, :) = doa_sanity;
    log_msg(fid_log, 'N_arc=%d sanity: pass=%d, doa=[%.4f %.4f], true=[%.4f %.4f], max_err=%.4f deg, threshold=%.2f, lambda2_over_noise=%.4g', ...
        N_arc, sanity_ok_scan(iScan), doa_sanity(1), doa_sanity(2), theta_a, theta_b, sanity_err, threshold, dbg_sanity.lambda2_over_noise);
end

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
layer2_ok = all(sanity_ok_scan) && sanity_64_ok;
if layer2_ok
    log_msg(fid_log, 'Layer 2 passed.');
else
    log_msg(fid_log, 'Layer 2 failed, but full regression continues to quantify aperture/mismatch boundary.');
end

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 N_arc=48/64 full regression starts');
tic;
for iScan = 1:nscan
    N_arc = N_arc_scan(iScan);
    K_fbss = K_scan(iScan);
    seed_offset = iScan * 1e7;
    [X3d, Y3d, Z3d, A_ref_2d] = get_geometry_for_narc(arrInfo, col_mid, N_arc, cfg);
    log_msg(fid_log, 'Start N_arc=%d, K_fbss=%d, seed_offset=%.0f', N_arc, K_fbss, seed_offset);

    for iSep = 1:nsep
        sep_factor = sep_factor_list(iSep);
        theta_sep = bw_eq_scan(iScan) / sep_factor;
        theta_a = theta_c - theta_sep / 2;
        theta_b = theta_c + theta_sep / 2;
        target_theta = [theta_a, theta_b];
        tol_deg_rel = tol_rel_ratio * theta_sep;
        theta_sep_deg_scan(iScan, iSep) = theta_sep;
        theta_a_deg_scan(iScan, iSep) = theta_a;
        theta_b_deg_scan(iScan, iSep) = theta_b;

        y_clean_2d = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
            theta_a, theta_b, el_a, el_b, s1, s2);
        y_clean_combined = combine_layers_local(y_clean_2d, Z3d, cfg.arr.lambda, el_assumed);
        clean_gain = 10 * log10(mean(abs(y_clean_combined(:)).^2) / mean(abs(squeeze(y_clean_2d(:, round(cfg.arr.Nel/2), :)).^2), 'all'));
        log_msg(fid_log, 'N_arc=%d, sep_factor=%d, theta_sep=%.6f deg, theta_a=%.6f, theta_b=%.6f, clean_gain=%.4f dB', ...
            N_arc, sep_factor, theta_sep, theta_a, theta_b, clean_gain);

        for iSNR = 1:nsnr
            snr_db = snr_list(iSNR);
            noise_power_2d = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);
            measured_snr_gain_db_scan(iScan, iSep, iSNR) = clean_gain;

            for metkl_num = 1:Metkl
                seed_now = base_seed + 100000*iSep + 1000*iSNR + metkl_num + seed_offset;
                rng(seed_now, 'twister');
                noise_2d = sqrt(noise_power_2d / 2) * (randn(size(y_clean_2d)) + j * randn(size(y_clean_2d)));
                y_2d = y_clean_2d + noise_2d;
                y_combined = combine_layers_local(y_2d, Z3d, cfg.arr.lambda, el_assumed);
                [doa_now, dbg_now] = doa_root_music_array(y_combined, K_fbss, cfg.arr.lambda, d_eq, Lc);

                raw_ok = all(isfinite(doa_now));
                tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_deg_rel);
                doa_degraded = true;
                if raw_ok
                    raw_success_count_scan(iScan, iSep, iSNR) = raw_success_count_scan(iScan, iSep, iSNR) + 1;
                    doa_sorted = sort(doa_now(:).');
                    target_sorted = sort(target_theta(:).');
                    err = doa_sorted - target_sorted;
                    doa_degraded = max(abs(err)) > 1.0;
                    rmse_sum_sqerr_scan(iScan, iSep, iSNR) = rmse_sum_sqerr_scan(iScan, iSep, iSNR) + sum(err.^2);
                    rmse_valid_count_scan(iScan, iSep, iSNR) = rmse_valid_count_scan(iScan, iSep, iSNR) + 1;
                    est_sum_scan(iScan, iSep, iSNR, :) = squeeze(est_sum_scan(iScan, iSep, iSNR, :)).' + doa_sorted;
                end
                if doa_degraded
                    degraded_sample_count_scan(iScan, iSep, iSNR) = degraded_sample_count_scan(iScan, iSep, iSNR) + 1;
                end
                if tol_ok_abs
                    tol_success_count_scan(iScan, iSep, iSNR) = tol_success_count_scan(iScan, iSep, iSNR) + 1;
                end
                if tol_ok_rel
                    tol_success_count_rel_scan(iScan, iSep, iSNR) = tol_success_count_rel_scan(iScan, iSep, iSNR) + 1;
                end
                if isfield(dbg_now, 'lambda2_over_noise') && isfinite(dbg_now.lambda2_over_noise)
                    lambda2_over_noise_sum_scan(iScan, iSep, iSNR) = lambda2_over_noise_sum_scan(iScan, iSep, iSNR) + dbg_now.lambda2_over_noise;
                    lambda2_count_scan(iScan, iSep, iSNR) = lambda2_count_scan(iScan, iSep, iSNR) + 1;
                end
            end
        end
    end
    log_msg(fid_log, 'N_arc=%d finished, elapsed=%.1f s', N_arc, toc);
end

raw_success_rate_scan = raw_success_count_scan / Metkl;
tol_success_rate_scan = tol_success_count_scan / Metkl;
tol_success_rate_rel_scan = tol_success_count_rel_scan / Metkl;
rmse_scan = sqrt(rmse_sum_sqerr_scan ./ max(rmse_valid_count_scan, 1) / Lc);
rmse_scan(rmse_valid_count_scan == 0) = NaN;
lambda2_over_noise_scan = lambda2_over_noise_sum_scan ./ max(lambda2_count_scan, 1);
lambda2_over_noise_scan(lambda2_count_scan == 0) = NaN;
[mean_bias_scan, max_bias_scan] = summarize_bias_local(est_sum_scan, rmse_valid_count_scan, theta_a_deg_scan, theta_b_deg_scan);
snr90_scan = calc_snr90(tol_success_rate_scan, snr_list);
snr90_rel_scan = calc_snr90(tol_success_rate_rel_scan, snr_list);

for iScan = 1:nscan
    idxRoute = iScan + 1;
    raw_success_rate_all(idxRoute, :, :) = raw_success_rate_scan(iScan, :, :);
    tol_success_rate_all(idxRoute, :, :) = tol_success_rate_scan(iScan, :, :);
    tol_success_rate_rel_all(idxRoute, :, :) = tol_success_rate_rel_scan(iScan, :, :);
    rmse_all(idxRoute, :, :) = rmse_scan(iScan, :, :);
    mean_bias_deg_all(idxRoute, :, :) = mean_bias_scan(iScan, :, :);
    max_bias_deg_all(idxRoute, :, :) = max_bias_scan(iScan, :, :);
    lambda2_over_noise_all(idxRoute, :, :) = lambda2_over_noise_scan(iScan, :, :);
    degraded_sample_count_all(idxRoute, :, :) = degraded_sample_count_scan(iScan, :, :);
    measured_snr_gain_db_all(idxRoute, :, :) = measured_snr_gain_db_scan(iScan, :, :);
    snr90_all(idxRoute, :) = snr90_scan(iScan, :);
    snr90_rel_all(idxRoute, :) = snr90_rel_scan(iScan, :);
    theta_sep_deg_all(idxRoute, :) = theta_sep_deg_scan(iScan, :);
    theta_a_deg_all(idxRoute, :) = theta_a_deg_scan(iScan, :);
    theta_b_deg_all(idxRoute, :) = theta_b_deg_scan(iScan, :);
end

% Route 4 proto6 replay.
nsep64 = numel(sep_factor_list_64);
nsnr64 = numel(snr_list_64);
tol_success_count_64 = zeros(nsep64, nsnr64);
tol_success_count_rel_64 = zeros(nsep64, nsnr64);
raw_success_count_64 = zeros(nsep64, nsnr64);
degraded_sample_count_64 = zeros(nsep64, nsnr64);
rmse_sum_sqerr_64 = zeros(nsep64, nsnr64);
rmse_valid_count_64 = zeros(nsep64, nsnr64);
est_sum_64 = zeros(nsep64, nsnr64, Lc);
lambda2_over_noise_sum_64 = zeros(nsep64, nsnr64);
lambda2_count_64 = zeros(nsep64, nsnr64);
theta_sep_deg_64 = nan(nsep64, 1);
theta_a_deg_64 = nan(nsep64, 1);
theta_b_deg_64 = nan(nsep64, 1);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 proto6 replay starts: %s', route_name_64);
for iSep64 = 1:nsep64
    sep_factor_64 = sep_factor_list_64(iSep64);
    theta_sep_64 = bw_64 / sep_factor_64;
    theta_a_64 = theta_c_64 - theta_sep_64 / 2;
    theta_b_64 = theta_c_64 + theta_sep_64 / 2;
    target_theta_64 = [theta_a_64, theta_b_64];
    tol_deg_rel_64 = tol_rel_ratio * theta_sep_64;
    theta_sep_deg_64(iSep64) = theta_sep_64;
    theta_a_deg_64(iSep64) = theta_a_64;
    theta_b_deg_64(iSep64) = theta_b_64;
    A_a_64 = exp(-j * 2*pi * pos_N64 * sind(theta_a_64) / lambda_64);
    A_b_64 = exp(-j * 2*pi * pos_N64 * sind(theta_b_64) / lambda_64);
    y_clean_64 = A_a_64 * s1_64 + A_b_64 * s2_64;
    for iSNR64 = 1:nsnr64
        snr_db_64 = snr_list_64(iSNR64);
        noise_power_64 = mean(abs(y_clean_64(:)).^2) / 10^(snr_db_64 / 10);
        for metkl_num = 1:Metkl
            seed_64 = base_seed + 100000 * (iSep64 + 100) + 1000 * iSNR64 + metkl_num;
            rng(seed_64, 'twister');
            noise_64 = sqrt(noise_power_64 / 2) * (randn(size(y_clean_64)) + j * randn(size(y_clean_64)));
            y_64 = y_clean_64 + noise_64;
            [doa_64, dbg_64] = doa_root_music_array(y_64, K_fbss_64, lambda_64, d_64, Lc);
            raw_ok_64 = all(isfinite(doa_64));
            tol_ok_abs_64 = is_valid_doa_success(doa_64, target_theta_64, tol_deg);
            tol_ok_rel_64 = is_valid_doa_success(doa_64, target_theta_64, tol_deg_rel_64);
            doa_degraded_64 = true;
            if raw_ok_64
                raw_success_count_64(iSep64, iSNR64) = raw_success_count_64(iSep64, iSNR64) + 1;
                doa_sorted_64 = sort(doa_64(:).');
                target_sorted_64 = sort(target_theta_64(:).');
                err_64 = doa_sorted_64 - target_sorted_64;
                doa_degraded_64 = max(abs(err_64)) > 1.0;
                rmse_sum_sqerr_64(iSep64, iSNR64) = rmse_sum_sqerr_64(iSep64, iSNR64) + sum(err_64.^2);
                rmse_valid_count_64(iSep64, iSNR64) = rmse_valid_count_64(iSep64, iSNR64) + 1;
                est_sum_64(iSep64, iSNR64, :) = squeeze(est_sum_64(iSep64, iSNR64, :)).' + doa_sorted_64;
            end
            if doa_degraded_64
                degraded_sample_count_64(iSep64, iSNR64) = degraded_sample_count_64(iSep64, iSNR64) + 1;
            end
            if tol_ok_abs_64
                tol_success_count_64(iSep64, iSNR64) = tol_success_count_64(iSep64, iSNR64) + 1;
            end
            if tol_ok_rel_64
                tol_success_count_rel_64(iSep64, iSNR64) = tol_success_count_rel_64(iSep64, iSNR64) + 1;
            end
            if isfield(dbg_64, 'lambda2_over_noise') && isfinite(dbg_64.lambda2_over_noise)
                lambda2_over_noise_sum_64(iSep64, iSNR64) = lambda2_over_noise_sum_64(iSep64, iSNR64) + dbg_64.lambda2_over_noise;
                lambda2_count_64(iSep64, iSNR64) = lambda2_count_64(iSep64, iSNR64) + 1;
            end
        end
    end
end

raw_success_rate_64 = raw_success_count_64 / Metkl;
tol_success_rate_64 = tol_success_count_64 / Metkl;
tol_success_rate_rel_64 = tol_success_count_rel_64 / Metkl;
rmse_64 = sqrt(rmse_sum_sqerr_64 ./ max(rmse_valid_count_64, 1) / Lc);
rmse_64(rmse_valid_count_64 == 0) = NaN;
lambda2_over_noise_64 = lambda2_over_noise_sum_64 ./ max(lambda2_count_64, 1);
lambda2_over_noise_64(lambda2_count_64 == 0) = NaN;
[mean_bias_64, max_bias_64] = summarize_bias64_local(est_sum_64, rmse_valid_count_64, theta_a_deg_64, theta_b_deg_64);
snr90_64 = calc_snr90_2d(tol_success_rate_64, snr_list_64);
snr90_rel_64 = calc_snr90_2d(tol_success_rate_rel_64, snr_list_64);

hist_snr90 = [14, 16, 20, 22];
layer3a_ok = all(isfinite(snr90_64) & abs(snr90_64 - hist_snr90) <= 2);
idx_sep10 = find(sep_factor_list == 10, 1);
idx_snr18 = find(snr_list == 18, 1);
idx_snr14 = find(snr_list == 14, 1);
layer3b_rate = tol_success_rate_all(2, idx_sep10, idx_snr18);
layer3c_rate = tol_success_rate_all(3, idx_sep10, idx_snr14);
layer3b_ok = layer3b_rate >= 0.85;
layer3c_ok = layer3c_rate >= 0.85;
degradation_rate_by_sep = squeeze(sum(degraded_sample_count_all, 3)) / (nsnr * Metkl);
degradation_rate_overall = squeeze(sum(degraded_sample_count_all, [2 3])) / (nsep * nsnr * Metkl);
layer3d_ok = degradation_rate_overall(2) < 0.10 && degradation_rate_overall(3) < 0.10;

snr90_ref = snr90_all(1, :);
snr90_ref_eff = snr90_ref;
snr90_ref_eff(~isfinite(snr90_ref_eff)) = max(snr_list) + 2;
snr90_advance_48 = snr90_ref_eff - snr90_all(2, :);
layer3e_ok = all(isfinite(snr90_advance_48) & snr90_advance_48 >= 4);

idx_snr30 = find(snr_list == 30, 1);
mean_bias_increment_64_vs_48 = abs(squeeze(mean_bias_deg_all(3, :, idx_snr30)) - squeeze(mean_bias_deg_all(2, :, idx_snr30)));
layer3f_ok = all(mean_bias_increment_64_vs_48(isfinite(mean_bias_increment_64_vs_48)) < 0.05);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 acceptance checks');
for iSep = 1:nsep
    log_msg(fid_log, 'sep_factor=%d | SNR90 N32=%s, N48=%s, N64=%s | degradation N32=%.4f, N48=%.4f, N64=%.4f | sep10 tol rates logged separately', ...
        sep_factor_list(iSep), fmt_num(snr90_all(1, iSep)), fmt_num(snr90_all(2, iSep)), fmt_num(snr90_all(3, iSep)), ...
        degradation_rate_by_sep(1, iSep), degradation_rate_by_sep(2, iSep), degradation_rate_by_sep(3, iSep));
end
for iSep64 = 1:nsep64
    log_msg(fid_log, 'proto6 replay sep_factor=%d | SNR90 abs01=%s dB, rel025=%s dB', ...
        sep_factor_list_64(iSep64), fmt_num(snr90_64(iSep64)), fmt_num(snr90_rel_64(iSep64)));
end
log_msg(fid_log, '3a proto6 replay pass=%d, SNR90=%s dB, history=%s dB', layer3a_ok, mat2str(snr90_64, 4), mat2str(hist_snr90));
log_msg(fid_log, '3b N48 sep=10 SNR=18 tol_rate=%.6f, pass=%d', layer3b_rate, layer3b_ok);
log_msg(fid_log, '3c N64 sep=10 SNR=14 tol_rate=%.6f, pass=%d', layer3c_rate, layer3c_ok);
log_msg(fid_log, '3d degradation overall N48=%.6f, N64=%.6f, pass=%d', degradation_rate_overall(2), degradation_rate_overall(3), layer3d_ok);
log_msg(fid_log, '3e N48 SNR90 advance vs N32=%s dB, pass=%d', mat2str(snr90_advance_48, 4), layer3e_ok);
log_msg(fid_log, '3f abs mean_bias increment N64 vs N48 at 30dB=%s deg, pass=%d', mat2str(mean_bias_increment_64_vs_48, 4), layer3f_ok);

summary_path = fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b_keypoints.csv');
write_summary_csv(summary_path, route_names, sep_factor_list, snr_list, N_arc_all, K_all_routes, bw_eq_all, ...
    edge_offset_deg_all, steering_mismatch_pct_all, theta_sep_deg_all, theta_a_deg_all, theta_b_deg_all, ...
    raw_success_rate_all, tol_success_rate_all, tol_success_rate_rel_all, rmse_all, snr90_all, snr90_rel_all, ...
    mean_bias_deg_all, max_bias_deg_all, lambda2_over_noise_all, degraded_sample_count_all, measured_snr_gain_db_all, ...
    route_name_64, sep_factor_list_64, snr_list_64, snr90_64, snr90_rel_64, mean_bias_64, max_bias_64, ...
    lambda2_over_noise_64, degraded_sample_count_64, tol_success_rate_64, tol_success_rate_rel_64, theta_sep_deg_64, theta_a_deg_64, theta_b_deg_64);
write_keypoints_csv(keypoints_path, route_names, sep_factor_list, snr_list, N_arc_all, K_all_routes, bw_eq_all, ...
    edge_offset_deg_all, steering_mismatch_pct_all, tol_success_rate_all, rmse_all, snr90_all, ...
    mean_bias_deg_all, max_bias_deg_all, degraded_sample_count_all, measured_snr_gain_db_all, ...
    route_name_64, sep_factor_list_64, snr_list_64, snr90_64, tol_success_rate_64, degraded_sample_count_64);

result_mat_path = fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b_result.mat');
save(result_mat_path, ...
    'route_names', 'route_name_64', 'sep_factor_list', 'snr_list', 'Metkl', 'T_snap', 'tol_deg', 'tol_rel_ratio', ...
    'base_seed', 'N_arc_all', 'K_all_routes', 'bw_eq_all', 'N_arc_span_deg_all', 'edge_offset_deg_all', ...
    'sin_phi_over_phi_all', 'steering_mismatch_pct_all', 'theta_sep_deg_all', 'theta_a_deg_all', 'theta_b_deg_all', ...
    'raw_success_rate_all', 'tol_success_rate_all', 'tol_success_rate_rel_all', 'rmse_all', 'snr90_all', 'snr90_rel_all', ...
    'mean_bias_deg_all', 'max_bias_deg_all', 'lambda2_over_noise_all', 'degraded_sample_count_all', ...
    'measured_snr_gain_db_all', 'degradation_rate_by_sep', 'degradation_rate_overall', ...
    'sep_factor_list_64', 'snr_list_64', 'snr90_64', 'snr90_rel_64', 'tol_success_rate_64', ...
    'degraded_sample_count_64', 'mean_bias_64', 'max_bias_64', 'layer3a_ok', 'layer3b_ok', 'layer3c_ok', ...
    'layer3d_ok', 'layer3e_ok', 'layer3f_ok', 'layer3b_rate', 'layer3c_rate', 'snr90_advance_48', ...
    'mean_bias_increment_64_vs_48', 'sanity_ok_scan', 'sanity_err_scan', 'sanity_doa_scan');

plot_narc_vs_degradation(fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b_narc_vs_degradation.png'), ...
    sep_factor_list, N_arc_all, degradation_rate_by_sep, degradation_rate_overall);
plot_narc_vs_snr90(fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b_narc_vs_snr90.png'), ...
    sep_factor_list, N_arc_all, snr90_all);
plot_steering_mismatch(fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b_steering_mismatch.png'), ...
    cfg, N_arc_all, edge_offset_deg_all, sin_phi_over_phi_all, steering_mismatch_pct_all);
plot_proto6_replay(fullfile(result_dir, 'step8_5_cylindrical_arc_scan_proto14b_proto6_replay.png'), ...
    sep_factor_list_64, snr90_64, hist_snr90, tol_success_rate_64, snr_list_64);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 4 diagnostics generated.');
log_msg(fid_log, 'Generated figures: narc_vs_degradation, narc_vs_snr90, steering_mismatch, proto6_replay.');
log_msg(fid_log, 'Result directory: %s', result_dir);
log_msg(fid_log, '');
log_msg(fid_log, '4-layer acceptance summary');
log_msg(fid_log, 'Layer 1 geometry: PASS');
log_msg(fid_log, 'Layer 2 sanity: N48=%d (err=%.4f), N64=%d (err=%.4f), proto6=%d (err=%.4f)', ...
    sanity_ok_scan(1), sanity_err_scan(1), sanity_ok_scan(2), sanity_err_scan(2), sanity_64_ok, sanity_64_err);
log_msg(fid_log, 'Layer 3 regression: 3a=%d, 3b=%d, 3c=%d, 3d=%d, 3e=%d, 3f=%d', ...
    layer3a_ok, layer3b_ok, layer3c_ok, layer3d_ok, layer3e_ok, layer3f_ok);
log_msg(fid_log, 'Layer 4 figures: PASS');

function [X3d, Y3d, Z3d, A_ref_2d] = get_geometry_for_narc(arrInfo, col_mid, N_arc, cfg)
    j = sqrt(-1);
    col_select = (col_mid - N_arc/2 + 1):(col_mid + N_arc/2);
    iel_all = 1:cfg.arr.Nel;
    X3d = arrInfo.XAct(col_select, iel_all);
    Y3d = arrInfo.YAct(col_select, iel_all);
    Z3d = arrInfo.ZAct(col_select, iel_all);
    unit_ref = [cosd(0) * cosd(0), cosd(0) * sind(0), 0];
    A_ref_2d = exp(-j * 2*pi / cfg.arr.lambda * (X3d * unit_ref(1) + Y3d * unit_ref(2)));
end

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
    [nscan, nsep, nsnr, ~] = size(est_sum);
    mean_bias_deg = nan(nscan, nsep, nsnr);
    max_bias_deg = nan(nscan, nsep, nsnr);
    for iScan = 1:nscan
        for iSep = 1:nsep
            for iSNR = 1:nsnr
                count_now = valid_count(iScan, iSep, iSNR);
                if count_now > 0
                    mean_pair = squeeze(est_sum(iScan, iSep, iSNR, :)).' / count_now;
                    bias_pair = mean_pair - [theta_a_deg(iScan, iSep), theta_b_deg(iScan, iSep)];
                    mean_bias_deg(iScan, iSep, iSNR) = mean(bias_pair);
                    max_bias_deg(iScan, iSep, iSNR) = max(abs(bias_pair));
                end
            end
        end
    end
end

function [mean_bias_deg, max_bias_deg] = summarize_bias64_local(est_sum, valid_count, theta_a_deg, theta_b_deg)
    [nsep, nsnr, ~] = size(est_sum);
    mean_bias_deg = nan(nsep, nsnr);
    max_bias_deg = nan(nsep, nsnr);
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            count_now = valid_count(iSep, iSNR);
            if count_now > 0
                mean_pair = squeeze(est_sum(iSep, iSNR, :)).' / count_now;
                bias_pair = mean_pair - [theta_a_deg(iSep), theta_b_deg(iSep)];
                mean_bias_deg(iSep, iSNR) = mean(bias_pair);
                max_bias_deg(iSep, iSNR) = max(abs(bias_pair));
            end
        end
    end
end

function write_summary_csv(path_out, route_names, sep_factor_list, snr_list, N_arc_all, K_all_routes, bw_eq_all, ...
    edge_offset_deg_all, steering_mismatch_pct_all, theta_sep_deg_all, theta_a_deg_all, theta_b_deg_all, ...
    raw_success_rate_all, tol_success_rate_all, tol_success_rate_rel_all, rmse_all, snr90_all, snr90_rel_all, ...
    mean_bias_deg_all, max_bias_deg_all, lambda2_over_noise_all, degraded_sample_count_all, measured_snr_gain_db_all, ...
    route_name_64, sep_factor_list_64, snr_list_64, snr90_64, snr90_rel_64, mean_bias_64, max_bias_64, ...
    lambda2_over_noise_64, degraded_sample_count_64, tol_success_rate_64, tol_success_rate_rel_64, theta_sep_deg_64, theta_a_deg_64, theta_b_deg_64)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['route_name,N_arc,K_fbss,bw_eq_deg,edge_offset_deg,steering_mismatch_pct,' ...
        'sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,raw_success_rate,tol_success_rate,tol_success_rate_rel,' ...
        'rmse_deg,snr90_db,snr90_rel_db,mean_bias_deg,max_bias_deg,lambda2_over_noise,degraded_sample_count,measured_snr_gain_db\n']);
    for iroute = 1:numel(route_names)
        for iSep = 1:numel(sep_factor_list)
            for iSNR = 1:numel(snr_list)
                fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
                    route_names{iroute}, N_arc_all(iroute), K_all_routes(iroute), bw_eq_all(iroute), ...
                    edge_offset_deg_all(iroute), steering_mismatch_pct_all(iroute), sep_factor_list(iSep), ...
                    theta_sep_deg_all(iroute, iSep), theta_a_deg_all(iroute, iSep), theta_b_deg_all(iroute, iSep), ...
                    snr_list(iSNR), raw_success_rate_all(iroute, iSep, iSNR), tol_success_rate_all(iroute, iSep, iSNR), ...
                    tol_success_rate_rel_all(iroute, iSep, iSNR), rmse_all(iroute, iSep, iSNR), snr90_all(iroute, iSep), ...
                    snr90_rel_all(iroute, iSep), mean_bias_deg_all(iroute, iSep, iSNR), max_bias_deg_all(iroute, iSep, iSNR), ...
                    lambda2_over_noise_all(iroute, iSep, iSNR), degraded_sample_count_all(iroute, iSep, iSNR), ...
                    measured_snr_gain_db_all(iroute, iSep, iSNR));
            end
        end
    end
    for iSep64 = 1:numel(sep_factor_list_64)
        for iSNR64 = 1:numel(snr_list_64)
            fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
                route_name_64, 64, 56, NaN, NaN, NaN, sep_factor_list_64(iSep64), ...
                theta_sep_deg_64(iSep64), theta_a_deg_64(iSep64), theta_b_deg_64(iSep64), snr_list_64(iSNR64), ...
                NaN, tol_success_rate_64(iSep64, iSNR64), tol_success_rate_rel_64(iSep64, iSNR64), NaN, ...
                snr90_64(iSep64), snr90_rel_64(iSep64), mean_bias_64(iSep64, iSNR64), max_bias_64(iSep64, iSNR64), ...
                lambda2_over_noise_64(iSep64, iSNR64), degraded_sample_count_64(iSep64, iSNR64), NaN);
        end
    end
end

function write_keypoints_csv(path_out, route_names, sep_factor_list, snr_list, N_arc_all, K_all_routes, bw_eq_all, ...
    edge_offset_deg_all, steering_mismatch_pct_all, tol_success_rate_all, rmse_all, snr90_all, ...
    mean_bias_deg_all, max_bias_deg_all, degraded_sample_count_all, measured_snr_gain_db_all, ...
    route_name_64, sep_factor_list_64, snr_list_64, snr90_64, tol_success_rate_64, degraded_sample_count_64)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'route_name,N_arc,K_fbss,bw_eq_deg,edge_offset_deg,steering_mismatch_pct,sep_factor,snr_db,tol_success_rate_abs01,rmse_deg,snr90_db,mean_bias_deg,max_bias_deg,degraded_sample_count,measured_snr_gain_db\n');
    for iSep = 1:numel(sep_factor_list)
        key_snr_list = unique([min(snr_list), 14, 18, 24, 30, snr90_all(:, iSep).']);
        key_snr_list = key_snr_list(isfinite(key_snr_list));
        key_snr_list = sort(key_snr_list(key_snr_list >= min(snr_list) & key_snr_list <= max(snr_list)));
        for snr_key = key_snr_list
            idx = find(snr_list == snr_key, 1);
            for iroute = 1:numel(route_names)
                fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
                    route_names{iroute}, N_arc_all(iroute), K_all_routes(iroute), bw_eq_all(iroute), ...
                    edge_offset_deg_all(iroute), steering_mismatch_pct_all(iroute), sep_factor_list(iSep), snr_key, ...
                    tol_success_rate_all(iroute, iSep, idx), rmse_all(iroute, iSep, idx), snr90_all(iroute, iSep), ...
                    mean_bias_deg_all(iroute, iSep, idx), max_bias_deg_all(iroute, iSep, idx), ...
                    degraded_sample_count_all(iroute, iSep, idx), measured_snr_gain_db_all(iroute, iSep, idx));
            end
        end
    end
    for iSep64 = 1:numel(sep_factor_list_64)
        idx = find(snr_list_64 == 24, 1);
        if isempty(idx)
            idx = numel(snr_list_64);
        end
        fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
            route_name_64, 64, 56, NaN, NaN, NaN, sep_factor_list_64(iSep64), snr_list_64(idx), ...
            tol_success_rate_64(iSep64, idx), NaN, snr90_64(iSep64), NaN, NaN, degraded_sample_count_64(iSep64, idx), NaN);
    end
end

function plot_narc_vs_degradation(path_out, sep_factor_list, N_arc_all, degradation_rate_by_sep, degradation_rate_overall)
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 620]);
    subplot(2, 1, 1);
    bar(sep_factor_list, degradation_rate_by_sep.' * 100);
    grid on
    xlabel('sep factor');
    ylabel('degraded samples (%)');
    title('N\_arc versus degradation by sep factor');
    legend(arrayfun(@(x) sprintf('N=%d', x), N_arc_all, 'UniformOutput', false), 'Location', 'best');
    subplot(2, 1, 2);
    bar(categorical(arrayfun(@(x) sprintf('N=%d', x), N_arc_all, 'UniformOutput', false)), degradation_rate_overall * 100);
    grid on
    ylabel('overall degraded samples (%)');
    title('Overall degradation');
    saveas(fig, path_out);
    close(fig);
end

function plot_narc_vs_snr90(path_out, sep_factor_list, N_arc_all, snr90_all)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 540]);
    for iroute = 1:numel(N_arc_all)
        plot(sep_factor_list, snr90_all(iroute, :), '-o', 'LineWidth', 1.4);
        hold on
    end
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 abs01 (dB)');
    title('N\_arc versus SNR90');
    legend(arrayfun(@(x) sprintf('N=%d', x), N_arc_all, 'UniformOutput', false), 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_steering_mismatch(path_out, cfg, N_arc_all, edge_offset_deg_all, sin_phi_over_phi_all, steering_mismatch_pct_all)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 540]);
    phi_deg = 0:0.2:60;
    phi_rad = deg2rad(phi_deg);
    ratio = ones(size(phi_rad));
    idx = phi_rad > 0;
    ratio(idx) = sin(phi_rad(idx)) ./ phi_rad(idx);
    plot(phi_deg, ratio, 'LineWidth', 1.5);
    hold on
    for ii = 1:numel(N_arc_all)
        plot(edge_offset_deg_all(ii), sin_phi_over_phi_all(ii), 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
        text(edge_offset_deg_all(ii), sin_phi_over_phi_all(ii), sprintf(' N=%d, %.1f%%', N_arc_all(ii), steering_mismatch_pct_all(ii)));
    end
    hold off
    grid on
    xlabel('edge offset phi (deg)');
    ylabel('sin(phi) / phi');
    title(sprintf('Arc-to-ULA tangent mismatch, dPhi=%.3f deg', cfg.arr.dPhi));
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
    legend({'proto14b replay', 'proto6 history'}, 'Location', 'best');
    title('Proto6 replay check');
    subplot(2, 1, 2);
    imagesc(snr_list_64, sep_factor_list_64, tol_success_rate_64);
    colorbar
    caxis([0 1]);
    xlabel('SNR (dB)');
    ylabel('sep factor');
    title('Replay tol success rate');
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
