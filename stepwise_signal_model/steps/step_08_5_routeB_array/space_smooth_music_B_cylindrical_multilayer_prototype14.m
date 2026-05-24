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

result_dir = fullfile(script_dir, 'results_step8_5_cylindrical_multilayer_proto14');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() fclose(fid_log));

log_msg(fid_log, 'Step 08.5 Prototype 14: cylindrical multilayer coherent elevation combining + azimuth Root-MUSIC');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Frozen algorithm paths: %s ; %s', step08_dir, step75_dir);

sep_factor_list = [1, 2, 3, 5, 7, 10];
snr_list = -4:2:30;
Metkl = 200;
T_snap = 260;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
base_seed = 20260601;
azCtr_deg = 0;
N_arc = 32;
iel_select = round(cfg.arr.Nel / 2);
iel_select_all = 1:cfg.arr.Nel;
K_fbss = 28;
Lc = 2;
el_a = 0;
el_b = 0;
theta_c = azCtr_deg;
el_assumed_main = el_a;
el_assumed_mismatch = el_a + 2;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s1 = exp(j * 2*pi * cfg.arr.fc * t);
s2 = exp(j * 2*pi * cfg.arr.fc * t);

route_names = { ...
    'cylindrical_singlelayer_proto10_baseline', ...
    'cylindrical_multilayer_coherent_proto14_main', ...
    'cylindrical_multilayer_el_mismatch_2deg_proto14b'};
nroutes = numel(route_names);
route_name_64 = 'pure_ula_root_music_64ch_proto6_replay';

arrInfo = arr_cyl(cfg, azCtr_deg);
col_mid = round((cfg.beam.subNaz + 1) / 2);
col_select = (col_mid - N_arc/2 + 1):(col_mid + N_arc/2);

X3d = arrInfo.XAct(col_select, iel_select_all);
Y3d = arrInfo.YAct(col_select, iel_select_all);
Z3d = arrInfo.ZAct(col_select, iel_select_all);
pos_mid_xyz = [arrInfo.XAct(col_select, iel_select), ...
               arrInfo.YAct(col_select, iel_select), ...
               arrInfo.ZAct(col_select, iel_select)];

unit_ref = [cosd(0) * cosd(azCtr_deg), cosd(0) * sind(azCtr_deg), 0];
A_ref_2d = exp(-j * 2*pi / cfg.arr.lambda * (X3d * unit_ref(1) + Y3d * unit_ref(2)));

d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
arc_dist = d_eq;
arc_over_lambda = arc_dist / cfg.arr.lambda;
subArc_span_deg = (cfg.beam.subNaz - 1) * cfg.arr.dPhi;
N_arc_span_deg = (N_arc - 1) * cfg.arr.dPhi;
edge_offset_deg = N_arc_span_deg / 2;
dz_over_lambda = cfg.arr.dz / cfg.arr.lambda;
elev_aperture = (cfg.arr.Nel - 1) * cfg.arr.dz;
elev_aperture_over_lambda = elev_aperture / cfg.arr.lambda;
elev_aperture_deg_3dB = 50.8 * 1.45 / elev_aperture_over_lambda;
expected_snr_gain_db = 10 * log10(cfg.arr.Nel);
bw_eq = 50.8 * 1.45 * cfg.arr.lambda / (N_arc - 1) / d_eq;
bw_eq = round(bw_eq * 100) / 100;

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
log_msg(fid_log, 'cfg.arr.Naz=%d, cfg.arr.Nel=%d, cfg.arr.R=%.6f m, cfg.arr.dPhi=%.6f deg', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.R, cfg.arr.dPhi);
log_msg(fid_log, 'cfg.beam.sectorHalf=%.6f deg, cfg.beam.subNaz=%d', cfg.beam.sectorHalf, cfg.beam.subNaz);
log_msg(fid_log, 'arc_dist=%.8f m', arc_dist);
log_msg(fid_log, 'arc/lambda=%.8f', arc_over_lambda);
log_msg(fid_log, 'subArc_span_deg=%.6f deg', subArc_span_deg);
log_msg(fid_log, 'N_arc_span_deg=%.6f deg', N_arc_span_deg);
log_msg(fid_log, 'edge_offset_deg=%.6f deg', edge_offset_deg);
log_msg(fid_log, 'dz/lambda=%.8f', dz_over_lambda);
log_msg(fid_log, 'elev_aperture=%.8f m, elev_aperture/lambda=%.8f', elev_aperture, elev_aperture_over_lambda);
log_msg(fid_log, 'elev_aperture_deg_3dB=%.6f deg', elev_aperture_deg_3dB);
log_msg(fid_log, 'N_arc*Nel=%d elements before combining', N_arc * cfg.arr.Nel);
log_msg(fid_log, 'expected_snr_gain=%.6f dB', expected_snr_gain_db);
log_msg(fid_log, 'd_eq=%.8f m, d_eq/lambda=%.8f, bw_eq=%.6f deg', d_eq, d_eq / cfg.arr.lambda, bw_eq);
log_msg(fid_log, 'col_select=%s within the 65-column working sector', mat2str(col_select));
log_msg(fid_log, 'selected global cols=%s', mat2str(arrInfo.colsAct(col_select)));
log_msg(fid_log, 'selected relative phi first/last = %.6f / %.6f deg', ...
    arrInfo.phiActRel(col_select(1)), arrInfo.phiActRel(col_select(end)));
log_msg(fid_log, 'z first/mid/last = %.8f / %.8f / %.8f m', Z3d(1, 1), Z3d(1, iel_select), Z3d(1, end));

assert(abs(arc_dist - 2*pi*0.4/192) / (2*pi*0.4/192) < 0.01, 'arc_dist geometry check failed.');
assert(arc_over_lambda >= 0.4 && arc_over_lambda <= 0.5, 'arc/lambda geometry check failed.');
assert(abs(subArc_span_deg - 120) / 120 < 0.01, 'subArc_span_deg geometry check failed.');
assert(abs(N_arc_span_deg - 58.125) / 58.125 < 0.01, 'N_arc_span_deg geometry check failed.');
assert(abs(dz_over_lambda - 17e-3/0.030) / (17e-3/0.030) < 0.01, 'dz/lambda geometry check failed.');
assert(abs(elev_aperture - 0.527) / 0.527 < 0.01, 'elevation aperture check failed.');
assert(abs(expected_snr_gain_db - 15.0515) / 15.0515 < 0.01, 'expected SNR gain check failed.');
log_msg(fid_log, 'Layer 1 passed.');

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 2 fully in-phase single-sample sanity check');
sep_factor_sanity = 5;
snr_sanity = 28;
theta_sep_sanity = bw_eq / sep_factor_sanity;
theta_a_sanity = theta_c - theta_sep_sanity/2;
theta_b_sanity = theta_c + theta_sep_sanity/2;
target_sanity = [theta_a_sanity, theta_b_sanity];
[y_clean_2d_sanity, y_clean_single_sanity, y_clean_main_sanity, y_clean_mismatch_sanity] = ...
    make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
    theta_a_sanity, theta_b_sanity, el_a, el_b, s1, s2, iel_select, el_assumed_main, el_assumed_mismatch);
noise_power_sanity = mean(abs(y_clean_2d_sanity(:)).^2) / 10^(snr_sanity / 10);
rng(base_seed, 'twister');
noise_2d_sanity = sqrt(noise_power_sanity / 2) * (randn(size(y_clean_2d_sanity)) + j * randn(size(y_clean_2d_sanity)));
y_2d_sanity = y_clean_2d_sanity + noise_2d_sanity;
y_single_sanity = squeeze(y_2d_sanity(:, iel_select, :));
y_main_sanity = combine_layers_local(y_2d_sanity, Z3d, cfg.arr.lambda, el_assumed_main);
y_mismatch_sanity = combine_layers_local(y_2d_sanity, Z3d, cfg.arr.lambda, el_assumed_mismatch);

[doa_single_sanity, dbg_single_sanity] = doa_root_music_array(y_single_sanity, K_fbss, cfg.arr.lambda, d_eq, Lc);
[doa_main_sanity, dbg_main_sanity] = doa_root_music_array(y_main_sanity, K_fbss, cfg.arr.lambda, d_eq, Lc);
[doa_mismatch_sanity, dbg_mismatch_sanity] = doa_root_music_array(y_mismatch_sanity, K_fbss, cfg.arr.lambda, d_eq, Lc);

single_sanity_err = max(abs(sort(doa_single_sanity) - sort(target_sanity)));
main_sanity_err = max(abs(sort(doa_main_sanity) - sort(target_sanity)));
mismatch_sanity_err = max(abs(sort(doa_mismatch_sanity) - sort(target_sanity)));
single_sanity_ok = all(isfinite(doa_single_sanity)) && single_sanity_err < 0.30;
main_sanity_ok = all(isfinite(doa_main_sanity)) && main_sanity_err < 0.10;
mismatch_sanity_ok = all(isfinite(doa_mismatch_sanity)) && mismatch_sanity_err < 0.50;

sanity_gain_main_db = power_gain_db(y_clean_main_sanity, y_clean_single_sanity);
sanity_gain_mismatch_db = power_gain_db(y_clean_mismatch_sanity, y_clean_single_sanity);
log_msg(fid_log, 'Single-layer sanity: pass=%d, doa=[%.4f, %.4f], true=[%.4f, %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g', ...
    single_sanity_ok, doa_single_sanity(1), doa_single_sanity(2), target_sanity(1), target_sanity(2), single_sanity_err, dbg_single_sanity.lambda2_over_noise);
log_msg(fid_log, 'Multilayer coherent sanity: pass=%d, doa=[%.4f, %.4f], true=[%.4f, %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g, measured_gain=%.4f dB', ...
    main_sanity_ok, doa_main_sanity(1), doa_main_sanity(2), target_sanity(1), target_sanity(2), main_sanity_err, dbg_main_sanity.lambda2_over_noise, sanity_gain_main_db);
log_msg(fid_log, 'Multilayer el mismatch 2deg sanity: pass=%d, doa=[%.4f, %.4f], true=[%.4f, %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g, measured_gain=%.4f dB', ...
    mismatch_sanity_ok, doa_mismatch_sanity(1), doa_mismatch_sanity(2), target_sanity(1), target_sanity(2), mismatch_sanity_err, dbg_mismatch_sanity.lambda2_over_noise, sanity_gain_mismatch_db);

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
log_msg(fid_log, 'Pure ULA N=64 proto6 replay sanity: pass=%d, doa=[%.4f, %.4f], true=[%.4f, %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g', ...
    sanity_64_ok, doa_64_sanity(1), doa_64_sanity(2), theta_a_64_sanity, theta_b_64_sanity, sanity_64_err, dbg_64_sanity.lambda2_over_noise);

if ~main_sanity_ok
    log_msg(fid_log, 'Layer 2 failed because route 2 max_err=%.4f deg > 0.10 deg. Stop before full regression.', main_sanity_err);
    error('Prototype 14 route 2 sanity check failed.');
end
log_msg(fid_log, 'Layer 2 route 2 passed; full regression continues.');

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);
raw_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count_rel = zeros(nroutes, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nsep, nsnr);
sum_num_peaks = zeros(nroutes, nsep, nsnr);
est_sum = zeros(nroutes, nsep, nsnr, Lc);
lambda2_over_noise_sum = zeros(nroutes, nsep, nsnr);
lambda2_count = zeros(nroutes, nsep, nsnr);
degraded_sample_count = zeros(nroutes, nsep, nsnr);
measured_snr_gain_db = nan(nroutes, nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
clean_gain_by_sep = nan(nroutes, nsep);
debug_samples = cell(nsep, nsnr);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 full fair comparison starts');
log_msg(fid_log, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_msg(fid_log, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f, tol_rel_ratio=%.2f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg, tol_rel_ratio);
log_msg(fid_log, 'N_arc=%d, Nel=%d, K_fbss=%d, base_seed=%d, no source phase bias', ...
    N_arc, cfg.arr.Nel, K_fbss, base_seed);

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

    [y_clean_2d, y_clean_single, y_clean_main, y_clean_mismatch] = ...
        make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
        theta_a, theta_b, el_a, el_b, s1, s2, iel_select, el_assumed_main, el_assumed_mismatch);

    clean_gain_by_sep(1, iSep) = 0;
    clean_gain_by_sep(2, iSep) = power_gain_db(y_clean_main, y_clean_single);
    clean_gain_by_sep(3, iSep) = power_gain_db(y_clean_mismatch, y_clean_single);
    log_msg(fid_log, 'sep_factor=%d, theta_sep=%.6f deg, theta_a=%.6f deg, theta_b=%.6f deg, tol_rel=%.6f deg, clean_gain_main=%.4f dB, clean_gain_mismatch=%.4f dB', ...
        sep_factor, theta_sep, theta_a, theta_b, tol_deg_rel, clean_gain_by_sep(2, iSep), clean_gain_by_sep(3, iSep));

    for iSNR = 1:nsnr
        snr_db = snr_list(iSNR);
        noise_power_2d = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);
        measured_snr_gain_db(:, iSep, iSNR) = clean_gain_by_sep(:, iSep);

        for metkl_num = 1:Metkl
            seed_now = base_seed + 100000*iSep + 1000*iSNR + metkl_num;
            rng(seed_now, 'twister');
            noise_2d = sqrt(noise_power_2d / 2) * (randn(size(y_clean_2d)) + j * randn(size(y_clean_2d)));
            y_2d = y_clean_2d + noise_2d;

            y_single = squeeze(y_2d(:, iel_select, :));
            y_main = combine_layers_local(y_2d, Z3d, cfg.arr.lambda, el_assumed_main);
            y_mismatch = combine_layers_local(y_2d, Z3d, cfg.arr.lambda, el_assumed_mismatch);

            [doa_single, debug_single] = doa_root_music_array(y_single, K_fbss, cfg.arr.lambda, d_eq, Lc);
            [doa_main, debug_main] = doa_root_music_array(y_main, K_fbss, cfg.arr.lambda, d_eq, Lc);
            [doa_mismatch, debug_mismatch] = doa_root_music_array(y_mismatch, K_fbss, cfg.arr.lambda, d_eq, Lc);

            doa_all = {doa_single, doa_main, doa_mismatch};
            debug_all = {debug_single, debug_main, debug_mismatch};

            for iroute = 1:nroutes
                doa_now = doa_all{iroute};
                debug_now = debug_all{iroute};
                raw_ok = all(isfinite(doa_now));
                tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_deg_rel);
                doa_degraded = true;

                if raw_ok
                    raw_success_count(iroute, iSep, iSNR) = raw_success_count(iroute, iSep, iSNR) + 1;
                    doa_sorted = sort(doa_now(:).');
                    target_sorted = sort(target_theta(:).');
                    err = doa_sorted - target_sorted;
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

                sum_num_peaks(iroute, iSep, iSNR) = sum_num_peaks(iroute, iSep, iSNR) + double(raw_ok) * Lc;
                if isfield(debug_now, 'lambda2_over_noise') && isfinite(debug_now.lambda2_over_noise)
                    lambda2_over_noise_sum(iroute, iSep, iSNR) = lambda2_over_noise_sum(iroute, iSep, iSNR) + debug_now.lambda2_over_noise;
                    lambda2_count(iroute, iSep, iSNR) = lambda2_count(iroute, iSep, iSNR) + 1;
                end
            end

            if metkl_num == 1
                sample = struct();
                sample.seed_now = seed_now;
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr_db;
                sample.target_theta = target_theta;
                sample.doa_single = doa_single;
                sample.doa_main = doa_main;
                sample.doa_mismatch = doa_mismatch;
                sample.debug_single = debug_single;
                sample.debug_main = debug_main;
                sample.debug_mismatch = debug_mismatch;
                debug_samples{iSep, iSNR} = sample;
            end
        end
    end

    partial_path = fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_result_partial.mat');
    save(partial_path, ...
        'route_names', 'sep_factor_list', 'snr_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
        'raw_success_count', 'tol_success_count', 'tol_success_count_rel', ...
        'rmse_sum_sqerr', 'rmse_valid_count', 'sum_num_peaks', 'est_sum', ...
        'lambda2_over_noise_sum', 'lambda2_count', 'degraded_sample_count', ...
        'measured_snr_gain_db', 'clean_gain_by_sep', 'debug_samples');

    log_msg(fid_log, 'sep_factor=%d finished, elapsed=%.1f s', sep_factor, toc);
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
tol_success_rate_rel = tol_success_count_rel / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;
rmse = sqrt(rmse_sum_sqerr ./ max(rmse_valid_count, 1) / Lc);
rmse(rmse_valid_count == 0) = NaN;
lambda2_over_noise = lambda2_over_noise_sum ./ max(lambda2_count, 1);
lambda2_over_noise(lambda2_count == 0) = NaN;

[mean_az_a_est, mean_az_b_est, mean_bias_deg, max_bias_deg] = ...
    summarize_bias_local(est_sum, rmse_valid_count, theta_a_deg, theta_b_deg);

snr90 = calc_snr90(tol_success_rate, snr_list);
snr90_rel = calc_snr90(tol_success_rate_rel, snr_list);

nsep64 = numel(sep_factor_list_64);
nsnr64 = numel(snr_list_64);
raw_success_count_64 = zeros(nsep64, nsnr64);
tol_success_count_64 = zeros(nsep64, nsnr64);
tol_success_count_rel_64 = zeros(nsep64, nsnr64);
rmse_sum_sqerr_64 = zeros(nsep64, nsnr64);
rmse_valid_count_64 = zeros(nsep64, nsnr64);
sum_num_peaks_64 = zeros(nsep64, nsnr64);
est_sum_64 = zeros(nsep64, nsnr64, Lc);
lambda2_over_noise_sum_64 = zeros(nsep64, nsnr64);
lambda2_count_64 = zeros(nsep64, nsnr64);
degraded_sample_count_64 = zeros(nsep64, nsnr64);
theta_sep_deg_64 = nan(nsep64, 1);
theta_a_deg_64 = nan(nsep64, 1);
theta_b_deg_64 = nan(nsep64, 1);
measured_snr_gain_db_64 = nan(nsep64, nsnr64);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 proto6 replay starts: %s', route_name_64);
log_msg(fid_log, 'sep_factor_list_64=%s, snr_list_64=%s, N_64=%d, K_fbss_64=%d, d_64=%.6f, lambda_64=%.8f, bw_64=%.3f, theta_c_64=%.3f', ...
    mat2str(sep_factor_list_64), mat2str(snr_list_64), N_64, K_fbss_64, d_64, lambda_64, bw_64, theta_c_64);

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

    log_msg(fid_log, 'proto6 replay sep_factor=%d, theta_sep=%.6f deg, theta_a=%.6f deg, theta_b=%.6f deg, tol_rel=%.6f deg', ...
        sep_factor_64, theta_sep_64, theta_a_64, theta_b_64, tol_deg_rel_64);

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

            sum_num_peaks_64(iSep64, iSNR64) = sum_num_peaks_64(iSep64, iSNR64) + double(raw_ok_64) * Lc;
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
mean_num_peaks_64 = sum_num_peaks_64 / Metkl;
rmse_64 = sqrt(rmse_sum_sqerr_64 ./ max(rmse_valid_count_64, 1) / Lc);
rmse_64(rmse_valid_count_64 == 0) = NaN;
lambda2_over_noise_64 = lambda2_over_noise_sum_64 ./ max(lambda2_count_64, 1);
lambda2_over_noise_64(lambda2_count_64 == 0) = NaN;

[mean_az_a_est_64, mean_az_b_est_64, mean_bias_deg_64, max_bias_deg_64] = ...
    summarize_bias64_local(est_sum_64, rmse_valid_count_64, theta_a_deg_64, theta_b_deg_64);
snr90_64 = calc_snr90_2d(tol_success_rate_64, snr_list_64);
snr90_rel_64 = calc_snr90_2d(tol_success_rate_rel_64, snr_list_64);

degradation_rate = squeeze(sum(degraded_sample_count, [2 3])) / (nsep * nsnr * Metkl);
degradation_rate_by_sep = squeeze(sum(degraded_sample_count, 3)) / (nsnr * Metkl);
degradation_rate_64 = sum(degraded_sample_count_64(:)) / (nsep64 * nsnr64 * Metkl);

hist_sep = [7, 8, 9, 10];
hist_snr90 = [14, 16, 20, 22];
layer3_proto6_replay_ok = true;
for kk = 1:numel(hist_sep)
    idx64 = find(sep_factor_list_64 == hist_sep(kk), 1);
    layer3_proto6_replay_ok = layer3_proto6_replay_ok && isfinite(snr90_64(idx64)) && abs(snr90_64(idx64) - hist_snr90(kk)) <= 2;
end

idx_sep10 = find(sep_factor_list == 10, 1);
idx_snr10 = find(snr_list == 10, 1);
layer3_sep10_snr10_rate = tol_success_rate(2, idx_sep10, idx_snr10);
layer3_sep10_snr10_ok = layer3_sep10_snr10_rate >= 0.85;

snr90_baseline_effective = snr90(1, :);
snr90_baseline_effective(~isfinite(snr90_baseline_effective)) = max(snr_list) + 2;
snr90_advance_main = snr90_baseline_effective - snr90(2, :);
layer3_snr90_advance_ok = all(isfinite(snr90_advance_main) & snr90_advance_main >= 12);

layer3_degradation_ok = all(degradation_rate_by_sep(2, :) < 0.05);
snr90_loss_mismatch = snr90(3, :) - snr90(2, :);
layer3_mismatch_ok = all(~isfinite(snr90_loss_mismatch) | snr90_loss_mismatch < 6);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 acceptance checks');
for iSep = 1:nsep
    log_msg(fid_log, 'sep_factor=%d | SNR90 abs01 -> single=%s dB, multilayer=%s dB, mismatch2deg=%s dB | main advance lower-bound=%s dB | sep degradation main=%.4f', ...
        sep_factor_list(iSep), fmt_num(snr90(1, iSep)), fmt_num(snr90(2, iSep)), fmt_num(snr90(3, iSep)), ...
        fmt_num(snr90_advance_main(iSep)), degradation_rate_by_sep(2, iSep));
end
for iSep64 = 1:nsep64
    log_msg(fid_log, 'proto6 replay sep_factor=%d | SNR90 abs01=%s dB, rel025=%s dB, degraded_rate_at_snr90=%.4f', ...
        sep_factor_list_64(iSep64), fmt_num(snr90_64(iSep64)), fmt_num(snr90_rel_64(iSep64)), ...
        degradation_at_snr90(snr90_64(iSep64), snr_list_64, degraded_sample_count_64(iSep64, :), Metkl));
end
log_msg(fid_log, '3a proto6 replay SNR90 vs historical [14,16,20,22] dB with +/-2 dB tolerance, pass=%d', layer3_proto6_replay_ok);
log_msg(fid_log, '3b route2 sep_factor=10, SNR=10 dB tol_rate_abs01=%.6f, pass=%d', layer3_sep10_snr10_rate, layer3_sep10_snr10_ok);
log_msg(fid_log, '3c route2 SNR90 advance vs route1 lower-bound=%s dB, pass=%d', mat2str(snr90_advance_main, 4), layer3_snr90_advance_ok);
log_msg(fid_log, '3d route2 degradation by sep=%s, overall=%.6f, pass=%d', mat2str(degradation_rate_by_sep(2, :), 4), degradation_rate(2), layer3_degradation_ok);
log_msg(fid_log, '3e route3 el mismatch 2deg SNR90 loss vs route2=%s dB, pass/report=%d', mat2str(snr90_loss_mismatch, 4), layer3_mismatch_ok);

summary_path = fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_keypoints.csv');
write_summary_csv(summary_path, route_names, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_count, tol_success_count, tol_success_count_rel, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse, rmse_valid_count, mean_num_peaks, snr90, snr90_rel, mean_bias_deg, max_bias_deg, ...
    mean_az_a_est, mean_az_b_est, lambda2_over_noise, degraded_sample_count, measured_snr_gain_db, ...
    route_name_64, sep_factor_list_64, snr_list_64, theta_sep_deg_64, theta_a_deg_64, theta_b_deg_64, ...
    raw_success_count_64, tol_success_count_64, tol_success_count_rel_64, raw_success_rate_64, tol_success_rate_64, ...
    tol_success_rate_rel_64, rmse_64, rmse_valid_count_64, mean_num_peaks_64, snr90_64, snr90_rel_64, ...
    mean_bias_deg_64, max_bias_deg_64, mean_az_a_est_64, mean_az_b_est_64, lambda2_over_noise_64, ...
    degraded_sample_count_64, measured_snr_gain_db_64);
write_keypoints_csv(keypoints_path, route_names, sep_factor_list, snr_list, raw_success_rate, tol_success_rate, ...
    tol_success_rate_rel, rmse, mean_num_peaks, mean_bias_deg, max_bias_deg, mean_az_a_est, mean_az_b_est, ...
    snr90, degraded_sample_count, measured_snr_gain_db, route_name_64, sep_factor_list_64, snr_list_64, ...
    raw_success_rate_64, tol_success_rate_64, tol_success_rate_rel_64, rmse_64, mean_num_peaks_64, ...
    mean_bias_deg_64, max_bias_deg_64, mean_az_a_est_64, mean_az_b_est_64, snr90_64, ...
    degraded_sample_count_64, measured_snr_gain_db_64);

result_mat_path = fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_result.mat');
save(result_mat_path, ...
    'cfg', 'route_names', 'route_name_64', 'sep_factor_list', 'snr_list', 'Metkl', 'T_snap', ...
    'tol_deg', 'tol_rel_ratio', 'base_seed', 'azCtr_deg', 'N_arc', 'K_fbss', 'Lc', ...
    'el_a', 'el_b', 'el_assumed_main', 'el_assumed_mismatch', 'arc_dist', 'arc_over_lambda', ...
    'subArc_span_deg', 'N_arc_span_deg', 'dz_over_lambda', 'elev_aperture', 'elev_aperture_over_lambda', ...
    'elev_aperture_deg_3dB', 'expected_snr_gain_db', 'bw_eq', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_count', 'tol_success_count', 'tol_success_count_rel', 'raw_success_rate', ...
    'tol_success_rate', 'tol_success_rate_rel', 'rmse', 'rmse_valid_count', 'mean_num_peaks', ...
    'snr90', 'snr90_rel', 'mean_bias_deg', 'max_bias_deg', 'mean_az_a_est', 'mean_az_b_est', ...
    'lambda2_over_noise', 'degraded_sample_count', 'measured_snr_gain_db', 'clean_gain_by_sep', ...
    'sep_factor_list_64', 'snr_list_64', 'theta_sep_deg_64', 'theta_a_deg_64', 'theta_b_deg_64', ...
    'snr90_64', 'snr90_rel_64', 'tol_success_rate_64', 'degraded_sample_count_64', ...
    'measured_snr_gain_db_64', 'degradation_rate', 'degradation_rate_by_sep', 'degradation_rate_64', ...
    'snr90_advance_main', 'snr90_loss_mismatch', 'layer3_proto6_replay_ok', 'layer3_sep10_snr10_ok', ...
    'layer3_snr90_advance_ok', 'layer3_degradation_ok', 'layer3_mismatch_ok', 'debug_samples');

plot_layer_gain(fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_layer_gain.png'), ...
    sep_factor_list, clean_gain_by_sep, expected_snr_gain_db);
plot_degradation_rate(fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_degradation_rate.png'), ...
    route_names, route_name_64, degradation_rate, degradation_rate_64, degradation_rate_by_sep, sep_factor_list);
plot_snr90(fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_snr90.png'), ...
    route_names, sep_factor_list, snr90, route_name_64, sep_factor_list_64, snr90_64);
plot_el_mismatch(fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_el_mismatch.png'), ...
    sep_factor_list, clean_gain_by_sep, snr90_loss_mismatch, expected_snr_gain_db);
plot_geometry_diag(fullfile(result_dir, 'step8_5_cylindrical_multilayer_proto14_geometry_diag.png'), ...
    cfg, arrInfo, col_select, X3d, Y3d, Z3d, iel_select, expected_snr_gain_db);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 4 diagnostics generated.');
log_msg(fid_log, 'Generated figures: layer_gain, degradation_rate, snr90, el_mismatch, geometry_diag.');
log_msg(fid_log, 'Result directory: %s', result_dir);

log_msg(fid_log, '');
log_msg(fid_log, '4-layer acceptance summary');
log_msg(fid_log, 'Layer 1 geometry: PASS');
log_msg(fid_log, 'Layer 2 sanity: route1=%d (err=%.4f), route2=%d (err=%.4f), route3=%d (err=%.4f), route4=%d (err=%.4f)', ...
    single_sanity_ok, single_sanity_err, main_sanity_ok, main_sanity_err, mismatch_sanity_ok, mismatch_sanity_err, sanity_64_ok, sanity_64_err);
log_msg(fid_log, 'Layer 3 regression: 3a=%d, 3b=%d, 3c=%d, 3d=%d, 3e=%d', ...
    layer3_proto6_replay_ok, layer3_sep10_snr10_ok, layer3_snr90_advance_ok, layer3_degradation_ok, layer3_mismatch_ok);
log_msg(fid_log, 'Layer 4 figures: PASS');
log_msg(fid_log, 'Route2 measured coherent gain by sep=%s dB, theoretical=%.4f dB', mat2str(clean_gain_by_sep(2, :), 4), expected_snr_gain_db);
log_msg(fid_log, 'Route2 degradation overall=%.6f (proto10 v2 reference 0.5639). Route1 degradation overall=%.6f.', degradation_rate(2), degradation_rate(1));
log_msg(fid_log, 'Route3 el mismatch 2deg SNR90 loss vs route2=%s dB; clean coherent loss=%.4f dB.', ...
    mat2str(snr90_loss_mismatch, 4), clean_gain_by_sep(2, 1) - clean_gain_by_sep(3, 1));

function [y_clean_2d, y_clean_single, y_clean_main, y_clean_mismatch] = make_clean_cylindrical_observations( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, theta_b, el_a, el_b, s1, s2, iel_select, el_main, el_mismatch)

    j = sqrt(-1);
    unit_a = [cosd(el_a) * cosd(theta_a), cosd(el_a) * sind(theta_a), sind(el_a)];
    unit_b = [cosd(el_b) * cosd(theta_b), cosd(el_b) * sind(theta_b), sind(el_b)];
    phase_a = X3d * unit_a(1) + Y3d * unit_a(2) + Z3d * unit_a(3);
    phase_b = X3d * unit_b(1) + Y3d * unit_b(2) + Z3d * unit_b(3);
    A_a_2d = exp(-j * 2*pi / lambda * phase_a);
    A_b_2d = exp(-j * 2*pi / lambda * phase_b);
    A_a_ref = conj(A_ref_2d) .* A_a_2d;
    A_b_ref = conj(A_ref_2d) .* A_b_2d;
    y_clean_2d = reshape(A_a_ref(:) * s1 + A_b_ref(:) * s2, size(X3d, 1), size(X3d, 2), numel(s1));
    y_clean_single = squeeze(y_clean_2d(:, iel_select, :));
    y_clean_main = combine_layers_local(y_clean_2d, Z3d, lambda, el_main);
    y_clean_mismatch = combine_layers_local(y_clean_2d, Z3d, lambda, el_mismatch);
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

function gain_db = power_gain_db(y_combined, y_single)
    gain_db = 10 * log10(mean(abs(y_combined(:)).^2) / mean(abs(y_single(:)).^2));
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

function [mean_az_a_est, mean_az_b_est, mean_bias_deg, max_bias_deg] = summarize_bias_local(est_sum, valid_count, theta_a_deg, theta_b_deg)
    [nroutes, nsep, nsnr, ~] = size(est_sum);
    mean_az_a_est = nan(nroutes, nsep, nsnr);
    mean_az_b_est = nan(nroutes, nsep, nsnr);
    mean_bias_deg = nan(nroutes, nsep, nsnr);
    max_bias_deg = nan(nroutes, nsep, nsnr);
    for iroute = 1:nroutes
        for iSep = 1:nsep
            for iSNR = 1:nsnr
                count_now = valid_count(iroute, iSep, iSNR);
                if count_now > 0
                    mean_pair = squeeze(est_sum(iroute, iSep, iSNR, :)).' / count_now;
                    mean_az_a_est(iroute, iSep, iSNR) = mean_pair(1);
                    mean_az_b_est(iroute, iSep, iSNR) = mean_pair(2);
                    bias_pair = mean_pair - [theta_a_deg(iSep), theta_b_deg(iSep)];
                    mean_bias_deg(iroute, iSep, iSNR) = mean(bias_pair);
                    max_bias_deg(iroute, iSep, iSNR) = max(abs(bias_pair));
                end
            end
        end
    end
end

function [mean_az_a_est, mean_az_b_est, mean_bias_deg, max_bias_deg] = summarize_bias64_local(est_sum, valid_count, theta_a_deg, theta_b_deg)
    [nsep, nsnr, ~] = size(est_sum);
    mean_az_a_est = nan(nsep, nsnr);
    mean_az_b_est = nan(nsep, nsnr);
    mean_bias_deg = nan(nsep, nsnr);
    max_bias_deg = nan(nsep, nsnr);
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            count_now = valid_count(iSep, iSNR);
            if count_now > 0
                mean_pair = squeeze(est_sum(iSep, iSNR, :)).' / count_now;
                mean_az_a_est(iSep, iSNR) = mean_pair(1);
                mean_az_b_est(iSep, iSNR) = mean_pair(2);
                bias_pair = mean_pair - [theta_a_deg(iSep), theta_b_deg(iSep)];
                mean_bias_deg(iSep, iSNR) = mean(bias_pair);
                max_bias_deg(iSep, iSNR) = max(abs(bias_pair));
            end
        end
    end
end

function write_summary_csv(path_out, route_names, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_count, tol_success_count, tol_success_count_rel, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse, rmse_valid_count, mean_num_peaks, snr90, snr90_rel, mean_bias_deg, max_bias_deg, ...
    mean_az_a_est, mean_az_b_est, lambda2_over_noise, degraded_sample_count, measured_snr_gain_db, ...
    route_name_64, sep_factor_list_64, snr_list_64, theta_sep_deg_64, theta_a_deg_64, theta_b_deg_64, ...
    raw_success_count_64, tol_success_count_64, tol_success_count_rel_64, raw_success_rate_64, tol_success_rate_64, ...
    tol_success_rate_rel_64, rmse_64, rmse_valid_count_64, mean_num_peaks_64, snr90_64, snr90_rel_64, ...
    mean_bias_deg_64, max_bias_deg_64, mean_az_a_est_64, mean_az_b_est_64, lambda2_over_noise_64, ...
    degraded_sample_count_64, measured_snr_gain_db_64)

    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
        'raw_success_count,tol_success_count,tol_success_count_rel,' ...
        'raw_success_rate,tol_success_rate,tol_success_rate_rel,' ...
        'rmse_deg,rmse_valid_count,mean_num_peaks,' ...
        'snr90_db,snr90_rel_db,mean_bias_deg,max_bias_deg,mean_az_a_est,mean_az_b_est,' ...
        'lambda2_over_noise,degraded_sample_count,measured_snr_gain_db\n']);

    for iroute = 1:numel(route_names)
        for iSep = 1:numel(sep_factor_list)
            for iSNR = 1:numel(snr_list)
                fprintf(fid, ['%s,%d,%.6f,%.6f,%.6f,%d,' ...
                    '%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.6f,' ...
                    '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n'], ...
                    route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
                    snr_list(iSNR), raw_success_count(iroute, iSep, iSNR), tol_success_count(iroute, iSep, iSNR), ...
                    tol_success_count_rel(iroute, iSep, iSNR), raw_success_rate(iroute, iSep, iSNR), ...
                    tol_success_rate(iroute, iSep, iSNR), tol_success_rate_rel(iroute, iSep, iSNR), ...
                    rmse(iroute, iSep, iSNR), rmse_valid_count(iroute, iSep, iSNR), mean_num_peaks(iroute, iSep, iSNR), ...
                    snr90(iroute, iSep), snr90_rel(iroute, iSep), mean_bias_deg(iroute, iSep, iSNR), ...
                    max_bias_deg(iroute, iSep, iSNR), mean_az_a_est(iroute, iSep, iSNR), ...
                    mean_az_b_est(iroute, iSep, iSNR), lambda2_over_noise(iroute, iSep, iSNR), ...
                    degraded_sample_count(iroute, iSep, iSNR), measured_snr_gain_db(iroute, iSep, iSNR));
            end
        end
    end

    for iSep64 = 1:numel(sep_factor_list_64)
        for iSNR64 = 1:numel(snr_list_64)
            fprintf(fid, ['%s,%d,%.6f,%.6f,%.6f,%d,' ...
                '%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.6f,' ...
                '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n'], ...
                route_name_64, sep_factor_list_64(iSep64), theta_sep_deg_64(iSep64), theta_a_deg_64(iSep64), ...
                theta_b_deg_64(iSep64), snr_list_64(iSNR64), raw_success_count_64(iSep64, iSNR64), ...
                tol_success_count_64(iSep64, iSNR64), tol_success_count_rel_64(iSep64, iSNR64), ...
                raw_success_rate_64(iSep64, iSNR64), tol_success_rate_64(iSep64, iSNR64), ...
                tol_success_rate_rel_64(iSep64, iSNR64), rmse_64(iSep64, iSNR64), ...
                rmse_valid_count_64(iSep64, iSNR64), mean_num_peaks_64(iSep64, iSNR64), ...
                snr90_64(iSep64), snr90_rel_64(iSep64), mean_bias_deg_64(iSep64, iSNR64), ...
                max_bias_deg_64(iSep64, iSNR64), mean_az_a_est_64(iSep64, iSNR64), ...
                mean_az_b_est_64(iSep64, iSNR64), lambda2_over_noise_64(iSep64, iSNR64), ...
                degraded_sample_count_64(iSep64, iSNR64), measured_snr_gain_db_64(iSep64, iSNR64));
        end
    end
end

function write_keypoints_csv(path_out, route_names, sep_factor_list, snr_list, raw_success_rate, tol_success_rate, ...
    tol_success_rate_rel, rmse, mean_num_peaks, mean_bias_deg, max_bias_deg, mean_az_a_est, mean_az_b_est, snr90, ...
    degraded_sample_count, measured_snr_gain_db, route_name_64, sep_factor_list_64, snr_list_64, raw_success_rate_64, ...
    tol_success_rate_64, tol_success_rate_rel_64, rmse_64, mean_num_peaks_64, mean_bias_deg_64, max_bias_deg_64, ...
    mean_az_a_est_64, mean_az_b_est_64, snr90_64, degraded_sample_count_64, measured_snr_gain_db_64)

    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'route_name,sep_factor,snr_db,raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,mean_num_peaks,mean_bias_deg,max_bias_deg,mean_az_a_est,mean_az_b_est,degraded_sample_count,measured_snr_gain_db\n');

    for iSep = 1:numel(sep_factor_list)
        key_snr_list = unique([min(snr_list), 10, 24, 30, snr90(:, iSep).']);
        key_snr_list = key_snr_list(isfinite(key_snr_list));
        key_snr_list = key_snr_list(key_snr_list >= min(snr_list) & key_snr_list <= max(snr_list));
        key_snr_list = sort(key_snr_list);
        for is = 1:numel(key_snr_list)
            snr_key = key_snr_list(is);
            idx = find(snr_list == snr_key, 1, 'first');
            if isempty(idx)
                continue;
            end
            for iroute = 1:numel(route_names)
                fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
                    route_names{iroute}, sep_factor_list(iSep), snr_key, raw_success_rate(iroute, iSep, idx), ...
                    tol_success_rate(iroute, iSep, idx), tol_success_rate_rel(iroute, iSep, idx), ...
                    rmse(iroute, iSep, idx), mean_num_peaks(iroute, iSep, idx), ...
                    mean_bias_deg(iroute, iSep, idx), max_bias_deg(iroute, iSep, idx), ...
                    mean_az_a_est(iroute, iSep, idx), mean_az_b_est(iroute, iSep, idx), ...
                    degraded_sample_count(iroute, iSep, idx), measured_snr_gain_db(iroute, iSep, idx));
            end
        end
    end

    for iSep64 = 1:numel(sep_factor_list_64)
        key_snr_list_64 = unique([min(snr_list_64), 24, 28, snr90_64(iSep64)]);
        key_snr_list_64 = key_snr_list_64(isfinite(key_snr_list_64));
        key_snr_list_64 = key_snr_list_64(key_snr_list_64 >= min(snr_list_64) & key_snr_list_64 <= max(snr_list_64));
        key_snr_list_64 = sort(key_snr_list_64);
        for is = 1:numel(key_snr_list_64)
            snr_key = key_snr_list_64(is);
            idx = find(snr_list_64 == snr_key, 1, 'first');
            if isempty(idx)
                continue;
            end
            fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
                route_name_64, sep_factor_list_64(iSep64), snr_key, raw_success_rate_64(iSep64, idx), ...
                tol_success_rate_64(iSep64, idx), tol_success_rate_rel_64(iSep64, idx), ...
                rmse_64(iSep64, idx), mean_num_peaks_64(iSep64, idx), ...
                mean_bias_deg_64(iSep64, idx), max_bias_deg_64(iSep64, idx), ...
                mean_az_a_est_64(iSep64, idx), mean_az_b_est_64(iSep64, idx), ...
                degraded_sample_count_64(iSep64, idx), measured_snr_gain_db_64(iSep64, idx));
        end
    end
end

function plot_layer_gain(path_out, sep_factor_list, clean_gain_by_sep, expected_snr_gain_db)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 520]);
    plot(sep_factor_list, clean_gain_by_sep(2, :), '-o', 'LineWidth', 1.5);
    hold on
    plot(sep_factor_list, clean_gain_by_sep(3, :), '-s', 'LineWidth', 1.5);
    yline(expected_snr_gain_db, '--', sprintf('theory %.2f dB', expected_snr_gain_db), 'LineWidth', 1.2);
    hold off
    grid on
    xlabel('sep factor');
    ylabel('measured coherent gain (dB)');
    title('Prototype14 32-layer coherent gain');
    legend({'route2 coherent', 'route3 mismatch 2deg', 'theory'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_degradation_rate(path_out, route_names, route_name_64, degradation_rate, degradation_rate_64, degradation_rate_by_sep, sep_factor_list)
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 620]);
    subplot(2, 1, 1);
    vals = [degradation_rate(:); degradation_rate_64] * 100;
    bar(vals);
    grid on
    ylabel('overall degraded samples (%)');
    labels = [route_names(:); {route_name_64}];
    set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'XTickLabelRotation', 20);
    title('Overall degradation rate');
    subplot(2, 1, 2);
    plot(sep_factor_list, degradation_rate_by_sep(1, :) * 100, '-o', 'LineWidth', 1.2);
    hold on
    plot(sep_factor_list, degradation_rate_by_sep(2, :) * 100, '-s', 'LineWidth', 1.2);
    plot(sep_factor_list, degradation_rate_by_sep(3, :) * 100, '-^', 'LineWidth', 1.2);
    yline(5, '--', '5% target');
    hold off
    grid on
    xlabel('sep factor');
    ylabel('degraded samples by sep (%)');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    title('Degradation rate by sep factor');
    saveas(fig, path_out);
    close(fig);
end

function plot_snr90(path_out, route_names, sep_factor_list, snr90, route_name_64, sep_factor_list_64, snr90_64)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 540]);
    for iroute = 1:numel(route_names)
        plot(sep_factor_list, snr90(iroute, :), '-o', 'LineWidth', 1.4);
        hold on
    end
    plot(sep_factor_list_64, snr90_64, '--s', 'LineWidth', 1.4);
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 abs01 (dB)');
    title('Prototype14 SNR90 comparison');
    legend([route_names(:); {route_name_64}], 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_el_mismatch(path_out, sep_factor_list, clean_gain_by_sep, snr90_loss_mismatch, expected_snr_gain_db)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 620]);
    subplot(2, 1, 1);
    loss_clean = clean_gain_by_sep(2, :) - clean_gain_by_sep(3, :);
    plot(sep_factor_list, loss_clean, '-o', 'LineWidth', 1.4);
    yline(6, '--', '6 dB report threshold');
    grid on
    ylabel('clean coherent loss (dB)');
    title(sprintf('2deg elevation mismatch loss, theory gain %.2f dB', expected_snr_gain_db));
    subplot(2, 1, 2);
    plot(sep_factor_list, snr90_loss_mismatch, '-s', 'LineWidth', 1.4);
    yline(6, '--', '6 dB report threshold');
    grid on
    xlabel('sep factor');
    ylabel('SNR90 loss route3-route2 (dB)');
    title('SNR90 loss from el mismatch');
    saveas(fig, path_out);
    close(fig);
end

function plot_geometry_diag(path_out, cfg, arrInfo, col_select, X3d, Y3d, Z3d, iel_select, expected_snr_gain_db)
    fig = figure('Visible', 'off', 'Position', [80, 80, 1100, 780]);

    subplot(2, 2, 1);
    plot(arrInfo.X(:, 1), arrInfo.Y(:, 1), '.', 'Color', [0.75 0.75 0.75]);
    hold on
    plot(arrInfo.XAct(:, 1), arrInfo.YAct(:, 1), 'r.', 'MarkerSize', 10);
    plot(X3d(:, 1), Y3d(:, 1), 'bo', 'MarkerSize', 4, 'LineWidth', 1.1);
    axis equal
    grid on
    title('Top view: full array, sector, selected 32 columns');
    xlabel('x (m)');
    ylabel('y (m)');
    legend({'192 columns', '65-column sector', '32-column DOA arc'}, 'Location', 'best');

    subplot(2, 2, 2);
    z = arrInfo.zRow;
    plot(zeros(size(z)), z, 'k.', 'MarkerSize', 12);
    hold on
    plot(0, z(iel_select), 'bo', 'MarkerSize', 8, 'LineWidth', 1.4);
    for ii = 1:numel(z)
        line([-0.05 0.05], [z(ii) z(ii)], 'Color', [0.85 0.85 0.85]);
    end
    hold off
    grid on
    ylim([min(z)-0.02, max(z)+0.02]);
    xlim([-0.12, 0.12]);
    title('Side view: all 32 elevation layers');
    xlabel('schematic x');
    ylabel('z (m)');

    subplot(2, 2, 3);
    plot(X3d(:, 1), Y3d(:, 1), 'bo-', 'LineWidth', 1.2);
    hold on
    plot([X3d(1, 1), X3d(end, 1)], [Y3d(1, 1), Y3d(end, 1)], 'k--', 'LineWidth', 1.1);
    hold off
    axis equal
    grid on
    title('Selected arc versus chord');
    xlabel('x (m)');
    ylabel('y (m)');

    subplot(2, 2, 4);
    z_col = Z3d(1, :).';
    el_axis = -5:0.05:5;
    gain = nan(size(el_axis));
    for ii = 1:numel(el_axis)
        steer = exp(-1j * 2*pi / cfg.arr.lambda * z_col * sind(el_axis(ii)));
        gain(ii) = 10 * log10(abs(sum(conj(steer)))^2 / cfg.arr.Nel);
    end
    plot(el_axis, gain, 'LineWidth', 1.2);
    hold on
    yline(expected_snr_gain_db, '--', '0deg coherent gain');
    xline(2, ':', '2deg mismatch');
    hold off
    grid on
    xlabel('assumed el when true el=0 (deg)');
    ylabel('coherent gain (dB)');
    title('Elevation combining gain versus mismatch');

    saveas(fig, path_out);
    close(fig);
end

function rate = degradation_at_snr90(snr90_value, snr_list, degraded_counts, Metkl)
    if ~isfinite(snr90_value)
        rate = NaN;
        return
    end
    idx = find(snr_list == snr90_value, 1);
    if isempty(idx)
        rate = NaN;
    else
        rate = degraded_counts(idx) / Metkl;
    end
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
