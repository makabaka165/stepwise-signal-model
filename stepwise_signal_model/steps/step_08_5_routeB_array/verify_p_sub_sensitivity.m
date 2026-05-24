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

result_dir = fullfile(script_dir, 'results_step8_5_verify_p_sub_sensitivity');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'verify_p_sub_sensitivity.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() fclose(fid_log));

log_msg(fid_log, 'Verify A: FBSS P_sub sensitivity scan');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Frozen algorithm path: %s', step08_dir);

proto14_mat = fullfile(script_dir, 'results_step8_5_cylindrical_multilayer_proto14', ...
    'step8_5_cylindrical_multilayer_proto14_result.mat');
assert(exist(proto14_mat, 'file') == 2, 'proto14 result.mat not found.');
proto14_data = load(proto14_mat);
proto14_route_idx = find(strcmp(proto14_data.route_names, 'cylindrical_multilayer_coherent_proto14_main'), 1);
assert(~isempty(proto14_route_idx), 'proto14 route 2 not found.');

N_arc = 32;
K_fbss_list = [28, 24, 20, 16];
P_sub_list = N_arc - K_fbss_list + 1;
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

assert(numel(K_fbss_list) == 4, 'K list length mismatch.');
assert(isequal(K_fbss_list, [28, 24, 20, 16]), 'K_fbss_list must be [28,24,20,16].');
assert(isequal(P_sub_list, N_arc - K_fbss_list + 1), 'P_sub formula mismatch.');

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s1 = exp(j * 2*pi * cfg.arr.fc * t);
s2 = exp(j * 2*pi * cfg.arr.fc * t);

route_names = { ...
    'verify_psub_K28_P05_proto14_baseline', ...
    'verify_psub_K24_P09_match_proto6_psub', ...
    'verify_psub_K20_P13_aggressive', ...
    'verify_psub_K16_P17_extreme'};

arrInfo = arr_cyl(cfg, azCtr_deg);
col_mid = round((cfg.beam.subNaz + 1) / 2);
col_select = (col_mid - N_arc/2 + 1):(col_mid + N_arc/2);
iel_select_all = 1:cfg.arr.Nel;
X3d = arrInfo.XAct(col_select, iel_select_all);
Y3d = arrInfo.YAct(col_select, iel_select_all);
Z3d = arrInfo.ZAct(col_select, iel_select_all);

unit_ref = [cosd(0) * cosd(azCtr_deg), cosd(0) * sind(azCtr_deg), 0];
A_ref_2d = exp(-j * 2*pi / cfg.arr.lambda * (X3d * unit_ref(1) + Y3d * unit_ref(2)));

d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
arc_dist = d_eq;
arc_over_lambda = arc_dist / cfg.arr.lambda;
subArc_span_deg = (cfg.beam.subNaz - 1) * cfg.arr.dPhi;
N_arc_span_deg = (N_arc - 1) * cfg.arr.dPhi;
dz_over_lambda = cfg.arr.dz / cfg.arr.lambda;
elev_aperture = (cfg.arr.Nel - 1) * cfg.arr.dz;
expected_snr_gain_db = 10 * log10(cfg.arr.Nel);
bw_eq = 50.8 * 1.45 * cfg.arr.lambda / (N_arc - 1) / d_eq;
bw_eq = round(bw_eq * 100) / 100;

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 1 geometry health check');
for iK = 1:numel(K_fbss_list)
    log_msg(fid_log, 'K index %d: K_fbss=%d, P_sub=%d, K/N=%.3f', ...
        iK, K_fbss_list(iK), P_sub_list(iK), K_fbss_list(iK) / N_arc);
end
log_msg(fid_log, 'arc_dist=%.8f m, arc/lambda=%.8f, subArc_span_deg=%.6f deg', ...
    arc_dist, arc_over_lambda, subArc_span_deg);
log_msg(fid_log, 'N_arc_span_deg=%.6f deg, bw_eq=%.6f deg, dz/lambda=%.8f', ...
    N_arc_span_deg, bw_eq, dz_over_lambda);
log_msg(fid_log, 'expected_snr_gain=%.6f dB, selected global cols=%s', ...
    expected_snr_gain_db, mat2str(arrInfo.colsAct(col_select)));
assert(arc_over_lambda >= 0.4 && arc_over_lambda <= 0.5, 'arc/lambda geometry check failed.');
assert(abs(N_arc_span_deg - 58.125) / 58.125 < 0.01, 'N_arc span check failed.');
assert(abs(expected_snr_gain_db - 15.0515) / 15.0515 < 0.01, 'expected gain check failed.');
log_msg(fid_log, 'Layer 1 passed.');

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 2 fully in-phase sanity check');
sep_factor_sanity = 5;
snr_sanity = 28;
theta_sep_sanity = bw_eq / sep_factor_sanity;
theta_a_sanity = theta_c - theta_sep_sanity / 2;
theta_b_sanity = theta_c + theta_sep_sanity / 2;
target_sanity = [theta_a_sanity, theta_b_sanity];
y_clean_2d_sanity = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, ...
    cfg.arr.lambda, theta_a_sanity, theta_b_sanity, el_a, el_b, s1, s2);
noise_power_sanity = mean(abs(y_clean_2d_sanity(:)).^2) / 10^(snr_sanity / 10);
rng(base_seed, 'twister');
noise_2d_sanity = sqrt(noise_power_sanity / 2) * (randn(size(y_clean_2d_sanity)) + j * randn(size(y_clean_2d_sanity)));
y_2d_sanity = y_clean_2d_sanity + noise_2d_sanity;
y_main_sanity = combine_layers_local(y_2d_sanity, Z3d, cfg.arr.lambda, el_assumed);

sanity_max_err_deg = nan(numel(K_fbss_list), 1);
sanity_pass = false(numel(K_fbss_list), 1);
sanity_failed = false(numel(K_fbss_list), 1);
sanity_lambda2_over_noise = nan(numel(K_fbss_list), 1);
sanity_threshold = [0.05, 0.05, 0.10, 0.30];
sanity_doa = nan(numel(K_fbss_list), Lc);
sanity_eigvals_first5 = nan(numel(K_fbss_list), 5);

for iK = 1:numel(K_fbss_list)
    K_fbss = K_fbss_list(iK);
    [doa_sanity, dbg_sanity] = doa_root_music_array(y_main_sanity, K_fbss, cfg.arr.lambda, d_eq, Lc);
    sanity_doa(iK, :) = doa_sanity;
    sanity_max_err_deg(iK) = max(abs(sort(doa_sanity) - sort(target_sanity)));
    sanity_pass(iK) = all(isfinite(doa_sanity)) && sanity_max_err_deg(iK) < sanity_threshold(iK);
    sanity_failed(iK) = ~sanity_pass(iK);
    sanity_lambda2_over_noise(iK) = dbg_sanity.lambda2_over_noise;
    n_eig = min(5, numel(dbg_sanity.eigvals));
    sanity_eigvals_first5(iK, 1:n_eig) = dbg_sanity.eigvals(1:n_eig);
    log_msg(fid_log, 'K=%d P_sub=%d sanity pass=%d doa=[%.4f %.4f], true=[%.4f %.4f], max_err=%.4f deg, threshold=%.4f, lambda2_over_noise=%.4g', ...
        K_fbss, P_sub_list(iK), sanity_pass(iK), doa_sanity(1), doa_sanity(2), ...
        target_sanity(1), target_sanity(2), sanity_max_err_deg(iK), sanity_threshold(iK), dbg_sanity.lambda2_over_noise);
    if iK == 4 && ~sanity_pass(iK)
        log_msg(fid_log, 'K=16 sanity failed but run continues. eigvals first5=%s', mat2str(sanity_eigvals_first5(iK, :), 5));
    elseif iK < 4 && ~sanity_pass(iK)
        error('Mandatory sanity failed for K=%d.', K_fbss);
    end
end
log_msg(fid_log, 'Layer 2 completed. K=16 sanity_failed=%d.', sanity_failed(4));

nK = numel(K_fbss_list);
nsep = numel(sep_factor_list);
nsnr = numel(snr_list);
raw_success_count = zeros(nK, nsep, nsnr);
tol_success_count = zeros(nK, nsep, nsnr);
tol_success_count_rel = zeros(nK, nsep, nsnr);
rmse_sum_sqerr = zeros(nK, nsep, nsnr);
rmse_valid_count = zeros(nK, nsep, nsnr);
sum_num_peaks = zeros(nK, nsep, nsnr);
est_sum = zeros(nK, nsep, nsnr, Lc);
lambda2_over_noise_sum = zeros(nK, nsep, nsnr);
lambda2_count = zeros(nK, nsep, nsnr);
degraded_sample_count = zeros(nK, nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 P_sub sensitivity full scan starts');
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

    y_clean_2d = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, ...
        cfg.arr.lambda, theta_a, theta_b, el_a, el_b, s1, s2);
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
            y_main = combine_layers_local(y_2d, Z3d, cfg.arr.lambda, el_assumed);

            for iK = 1:nK
                K_fbss = K_fbss_list(iK);
                [doa_now, dbg_now] = doa_root_music_array(y_main, K_fbss, cfg.arr.lambda, d_eq, Lc);
                raw_ok = all(isfinite(doa_now));
                tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_deg_rel);
                doa_degraded = true;

                if raw_ok
                    raw_success_count(iK, iSep, iSNR) = raw_success_count(iK, iSep, iSNR) + 1;
                    doa_sorted = sort(doa_now(:).');
                    target_sorted = sort(target_theta(:).');
                    err = doa_sorted - target_sorted;
                    doa_degraded = max(abs(err)) > 1.0;
                    rmse_sum_sqerr(iK, iSep, iSNR) = rmse_sum_sqerr(iK, iSep, iSNR) + sum(err.^2);
                    rmse_valid_count(iK, iSep, iSNR) = rmse_valid_count(iK, iSep, iSNR) + 1;
                    est_sum(iK, iSep, iSNR, :) = squeeze(est_sum(iK, iSep, iSNR, :)).' + doa_sorted;
                end

                if doa_degraded
                    degraded_sample_count(iK, iSep, iSNR) = degraded_sample_count(iK, iSep, iSNR) + 1;
                end
                if tol_ok_abs
                    tol_success_count(iK, iSep, iSNR) = tol_success_count(iK, iSep, iSNR) + 1;
                end
                if tol_ok_rel
                    tol_success_count_rel(iK, iSep, iSNR) = tol_success_count_rel(iK, iSep, iSNR) + 1;
                end
                sum_num_peaks(iK, iSep, iSNR) = sum_num_peaks(iK, iSep, iSNR) + double(raw_ok) * Lc;
                if isfield(dbg_now, 'lambda2_over_noise') && isfinite(dbg_now.lambda2_over_noise)
                    lambda2_over_noise_sum(iK, iSep, iSNR) = lambda2_over_noise_sum(iK, iSep, iSNR) + dbg_now.lambda2_over_noise;
                    lambda2_count(iK, iSep, iSNR) = lambda2_count(iK, iSep, iSNR) + 1;
                end
            end
        end
    end
    log_msg(fid_log, 'sep_factor=%d finished, elapsed=%.1f s', sep_factor, toc);
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
tol_success_rate_rel = tol_success_count_rel / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;
rmse_deg = sqrt(rmse_sum_sqerr ./ max(rmse_valid_count, 1) / Lc);
rmse_deg(rmse_valid_count == 0) = NaN;
lambda2_over_noise = lambda2_over_noise_sum ./ max(lambda2_count, 1);
lambda2_over_noise(lambda2_count == 0) = NaN;
[mean_az_a_est, mean_az_b_est, mean_bias_deg, max_bias_deg] = ...
    summarize_bias_local(est_sum, rmse_valid_count, theta_a_deg, theta_b_deg);

snr90_abs01 = calc_snr90(tol_success_rate, snr_list);
snr90_rel = calc_snr90(tol_success_rate_rel, snr_list);
degraded_count_total = squeeze(sum(sum(degraded_sample_count, 3), 2));
degraded_per_sep = sum(degraded_sample_count, 3);
degraded_rate_total = degraded_count_total / (nsep * nsnr * Metkl);
degraded_rate_by_sep = degraded_per_sep / (nsnr * Metkl);

proto14_rmse = squeeze(proto14_data.rmse(proto14_route_idx, :, :));
proto14_tol_count = squeeze(proto14_data.tol_success_count(proto14_route_idx, :, :));
rmse_k28 = squeeze(rmse_deg(1, :, :));
tol_count_k28 = squeeze(tol_success_count(1, :, :));
rmse_diff = rmse_k28 - proto14_rmse;
both_nan = isnan(rmse_k28) & isnan(proto14_rmse);
nan_mismatch = xor(isnan(rmse_k28), isnan(proto14_rmse));
rmse_diff(both_nan) = 0;
rmse_diff(nan_mismatch) = Inf;
tol_count_diff = tol_count_k28 - proto14_tol_count;
proto14_baseline_compare = struct();
proto14_baseline_compare.rmse_diff_max = max(abs(rmse_diff(:)));
proto14_baseline_compare.tol_count_diff_max = max(abs(tol_count_diff(:)));
proto14_baseline_compare.pass = proto14_baseline_compare.rmse_diff_max < 1e-10 && ...
    proto14_baseline_compare.tol_count_diff_max == 0;

idx_sep10 = find(sep_factor_list == 10, 1);
idx_snr24 = find(snr_list == 24, 1);
idx_snr30 = find(snr_list == 30, 1);
layer3a_ok = proto14_baseline_compare.pass;
layer3b_rate = tol_success_rate(2, idx_sep10, idx_snr24);
layer3b_ok = layer3b_rate >= 0.85;
layer3c_snr90 = snr90_abs01(2, idx_sep10);
layer3c_ok = isfinite(layer3c_snr90) && layer3c_snr90 <= 24;
layer3d_k24_snr90 = snr90_abs01(2, idx_sep10);
layer3d_k20_snr90 = snr90_abs01(3, idx_sep10);
layer3d_ok = isfinite(layer3d_k24_snr90) && isfinite(layer3d_k20_snr90) && layer3d_k20_snr90 <= layer3d_k24_snr90;
layer3e_k20_degraded = degraded_rate_total(3);
layer3e_k16_degraded = degraded_rate_total(4);
layer3f_bias_diff = abs(mean_bias_deg(2, idx_sep10, idx_snr30) - mean_bias_deg(1, idx_sep10, idx_snr30));
layer3f_ok = isfinite(layer3f_bias_diff) && layer3f_bias_diff < 0.005;

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 acceptance checks');
log_msg(fid_log, '3a K=28 proto14 replay pass=%d, rmse_diff_max=%.4g, tol_count_diff_max=%.4g', ...
    layer3a_ok, proto14_baseline_compare.rmse_diff_max, proto14_baseline_compare.tol_count_diff_max);
log_msg(fid_log, '3b K=24 sep=10 SNR=24 tol_rate=%.6f, pass=%d', layer3b_rate, layer3b_ok);
log_msg(fid_log, '3c K=24 sep=10 SNR90=%s dB, pass=%d', fmt_num(layer3c_snr90), layer3c_ok);
log_msg(fid_log, '3d K=20 sep=10 SNR90=%s dB vs K=24 %s dB, pass=%d', ...
    fmt_num(layer3d_k20_snr90), fmt_num(layer3d_k24_snr90), layer3d_ok);
log_msg(fid_log, '3e degraded total K=20 %.6f, K=16 %.6f, sanity_failed_K16=%d', ...
    layer3e_k20_degraded, layer3e_k16_degraded, sanity_failed(4));
log_msg(fid_log, '3f K=24 vs K=28 sep=10 SNR=30 mean_bias diff=%.8f deg, pass=%d', ...
    layer3f_bias_diff, layer3f_ok);
for iK = 1:nK
    log_msg(fid_log, 'K=%d P_sub=%d SNR90=%s, degraded_total=%.6f', ...
        K_fbss_list(iK), P_sub_list(iK), mat2str(snr90_abs01(iK, :), 4), degraded_rate_total(iK));
end

summary_path = fullfile(result_dir, 'verify_p_sub_sensitivity_summary.csv');
keypoints_path = fullfile(result_dir, 'verify_p_sub_sensitivity_keypoints.csv');
write_summary_csv(summary_path, route_names, K_fbss_list, P_sub_list, sep_factor_list, snr_list, ...
    theta_sep_deg, theta_a_deg, theta_b_deg, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse_deg, snr90_abs01, snr90_rel, mean_bias_deg, max_bias_deg, lambda2_over_noise, ...
    degraded_sample_count, mean_num_peaks, sanity_failed);
write_keypoints_csv(keypoints_path, K_fbss_list, P_sub_list, sep_factor_list, snr90_abs01, snr90_rel, ...
    degraded_rate_by_sep, sanity_max_err_deg);

result_mat_path = fullfile(result_dir, 'verify_p_sub_sensitivity_result.mat');
save(result_mat_path, 'cfg', 'K_fbss_list', 'P_sub_list', 'sep_factor_list', 'snr_list', ...
    'route_names', 'N_arc', 'Metkl', 'T_snap', 'base_seed', 'azCtr_deg', 'el_a', 'el_b', 'el_assumed', ...
    'tol_deg', 'tol_rel_ratio', 'Lc', 'bw_eq', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_count', 'tol_success_count', 'tol_success_count_rel', 'raw_success_rate', ...
    'tol_success_rate', 'tol_success_rate_rel', 'rmse_deg', 'rmse_valid_count', 'mean_num_peaks', ...
    'snr90_abs01', 'snr90_rel', 'mean_bias_deg', 'max_bias_deg', 'mean_az_a_est', 'mean_az_b_est', ...
    'lambda2_over_noise', 'degraded_sample_count', 'degraded_count_total', 'degraded_per_sep', ...
    'degraded_rate_total', 'degraded_rate_by_sep', 'sanity_max_err_deg', 'sanity_pass', ...
    'sanity_failed', 'sanity_lambda2_over_noise', 'sanity_doa', 'sanity_eigvals_first5', ...
    'proto14_baseline_compare', 'rmse_diff', 'tol_count_diff', ...
    'layer3a_ok', 'layer3b_ok', 'layer3c_ok', 'layer3d_ok', 'layer3f_ok', 'layer3b_rate', ...
    'layer3c_snr90', 'layer3d_k24_snr90', 'layer3d_k20_snr90', 'layer3f_bias_diff');

plot_psub_vs_snr90(fullfile(result_dir, 'verify_p_sub_psub_vs_snr90.png'), ...
    K_fbss_list, P_sub_list, sep_factor_list, theta_sep_deg, snr_list, tol_success_rate);
plot_psub_vs_degradation(fullfile(result_dir, 'verify_p_sub_psub_vs_degradation.png'), ...
    K_fbss_list, P_sub_list, sep_factor_list, degraded_rate_by_sep);
plot_sep10_tol(fullfile(result_dir, 'verify_p_sub_sep10_tol_vs_snr.png'), ...
    K_fbss_list, P_sub_list, snr_list, squeeze(tol_success_rate(:, idx_sep10, :)));
plot_proto14_diff(fullfile(result_dir, 'verify_p_sub_proto14_diff.png'), ...
    sep_factor_list, snr_list, rmse_diff, tol_count_diff);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 4 diagnostic figures generated.');
log_msg(fid_log, 'Result directory: %s', result_dir);
log_msg(fid_log, '');
log_msg(fid_log, '4-layer acceptance summary');
log_msg(fid_log, 'Layer 1 geometry: PASS');
log_msg(fid_log, 'Layer 2 sanity max_err=[%s], sanity_failed=[%s]', ...
    num2str(sanity_max_err_deg.', ' %.4f'), num2str(sanity_failed.'));
log_msg(fid_log, 'Layer 3 regression: 3a=%d, 3b=%d, 3c=%d, 3d=%d, 3e=report, 3f=%d', ...
    layer3a_ok, layer3b_ok, layer3c_ok, layer3d_ok, layer3f_ok);
log_msg(fid_log, 'Layer 4 figures: PASS');

function y_clean_2d = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, theta_b, el_a, el_b, s1, s2)
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

function write_summary_csv(path_out, route_names, K_fbss_list, P_sub_list, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_rate, tol_success_rate, tol_success_rate_rel, rmse_deg, snr90_abs01, snr90_rel, mean_bias_deg, max_bias_deg, ...
    lambda2_over_noise, degraded_sample_count, mean_num_peaks, sanity_failed)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['route_name,K_fbss,P_sub,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
        'raw_success_rate,tol_success_rate,tol_success_rate_rel,rmse_deg,snr90_db,snr90_rel_db,' ...
        'mean_bias_deg,max_bias_deg,lambda2_over_noise,degraded_sample_count,num_peaks_found,sanity_failed\n']);
    for iK = 1:numel(K_fbss_list)
        for iSep = 1:numel(sep_factor_list)
            for iSNR = 1:numel(snr_list)
                fprintf(fid, '%s,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f,%d\n', ...
                    route_names{iK}, K_fbss_list(iK), P_sub_list(iK), sep_factor_list(iSep), theta_sep_deg(iSep), ...
                    theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), raw_success_rate(iK, iSep, iSNR), ...
                    tol_success_rate(iK, iSep, iSNR), tol_success_rate_rel(iK, iSep, iSNR), rmse_deg(iK, iSep, iSNR), ...
                    snr90_abs01(iK, iSep), snr90_rel(iK, iSep), mean_bias_deg(iK, iSep, iSNR), ...
                    max_bias_deg(iK, iSep, iSNR), lambda2_over_noise(iK, iSep, iSNR), ...
                    degraded_sample_count(iK, iSep, iSNR), mean_num_peaks(iK, iSep, iSNR), sanity_failed(iK));
            end
        end
    end
end

function write_keypoints_csv(path_out, K_fbss_list, P_sub_list, sep_factor_list, snr90_abs01, snr90_rel, degraded_rate_by_sep, sanity_max_err_deg)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'K_fbss,P_sub,sep_factor,snr90_db,snr90_rel_db,degraded_rate,sanity_max_err_deg\n');
    for iK = 1:numel(K_fbss_list)
        for iSep = 1:numel(sep_factor_list)
            fprintf(fid, '%d,%d,%d,%.6f,%.6f,%.6f,%.6f\n', ...
                K_fbss_list(iK), P_sub_list(iK), sep_factor_list(iSep), ...
                snr90_abs01(iK, iSep), snr90_rel(iK, iSep), degraded_rate_by_sep(iK, iSep), sanity_max_err_deg(iK));
        end
    end
end

function plot_psub_vs_snr90(path_out, K_fbss_list, P_sub_list, sep_factor_list, theta_sep_deg, snr_list, tol_success_rate)
    fig = figure('Visible', 'off', 'Position', [80, 80, 1100, 900]);
    labels = make_k_labels(K_fbss_list, P_sub_list);
    for iSep = 1:numel(sep_factor_list)
        subplot(3, 2, iSep);
        for iK = 1:numel(K_fbss_list)
            plot(snr_list, squeeze(tol_success_rate(iK, iSep, :)), '-o', 'LineWidth', 1.2);
            hold on
        end
        yline(0.85, '--', '0.85');
        hold off
        grid on
        ylim([0 1.05]);
        xlabel('SNR (dB)');
        ylabel('tol rate');
        title(sprintf('sep=%d, theta sep=%.3f deg', sep_factor_list(iSep), theta_sep_deg(iSep)));
        if iSep == 1
            legend(labels, 'Location', 'best');
        end
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_psub_vs_degradation(path_out, K_fbss_list, P_sub_list, sep_factor_list, degraded_rate_by_sep)
    fig = figure('Visible', 'off', 'Position', [100, 100, 940, 560]);
    labels = make_k_labels(K_fbss_list, P_sub_list);
    vals = degraded_rate_by_sep.' * 100;
    bar(vals);
    grid on
    xlabel('sep factor');
    ylabel('degraded samples (%)');
    set(gca, 'XTick', 1:numel(sep_factor_list), 'XTickLabel', string(sep_factor_list));
    legend(labels, 'Location', 'best');
    title('P_sub sensitivity degradation rate by sep');
    saveas(fig, path_out);
    close(fig);
end

function plot_sep10_tol(path_out, K_fbss_list, P_sub_list, snr_list, sep10_tol_rate)
    fig = figure('Visible', 'off', 'Position', [100, 100, 860, 520]);
    labels = make_k_labels(K_fbss_list, P_sub_list);
    for iK = 1:numel(K_fbss_list)
        plot(snr_list, sep10_tol_rate(iK, :), '-o', 'LineWidth', 1.4);
        hold on
    end
    yline(0.85, '--', '0.85');
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('SNR (dB)');
    ylabel('tol rate');
    title('sep=10 tol success versus SNR');
    legend(labels, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_proto14_diff(path_out, sep_factor_list, snr_list, rmse_diff, tol_count_diff)
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 620]);
    subplot(1, 2, 1);
    imagesc(snr_list, sep_factor_list, rmse_diff);
    colorbar
    xlabel('SNR (dB)');
    ylabel('sep factor');
    title('K=28 RMSE diff versus proto14');
    subplot(1, 2, 2);
    imagesc(snr_list, sep_factor_list, tol_count_diff);
    colorbar
    xlabel('SNR (dB)');
    ylabel('sep factor');
    title('K=28 tol-count diff versus proto14');
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

function labels = make_k_labels(K_fbss_list, P_sub_list)
    labels = cell(1, numel(K_fbss_list));
    for ii = 1:numel(K_fbss_list)
        labels{ii} = sprintf('K=%d P=%d', K_fbss_list(ii), P_sub_list(ii));
    end
end

function log_msg(fid, varargin)
    msg = sprintf(varargin{:});
    fprintf('%s\n', msg);
    fprintf(fid, '%s\n', msg);
end
