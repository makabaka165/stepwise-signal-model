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

result_dir = fullfile(script_dir, 'results_step8_5_verify_joint_psub_coherence');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'verify_joint_psub_coherence.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() fclose(fid_log));

log_msg(fid_log, 'Verify C: K_fbss x source phase joint scan');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Frozen algorithm path: %s', step08_dir);

proto14_mat = fullfile(script_dir, 'results_step8_5_cylindrical_multilayer_proto14', ...
    'step8_5_cylindrical_multilayer_proto14_result.mat');
verifyB_mat = fullfile(script_dir, 'results_step8_5_verify_coherence_sensitivity', ...
    'verify_coherence_sensitivity_result.mat');
verifyA_mat = fullfile(script_dir, 'results_step8_5_verify_p_sub_sensitivity', ...
    'verify_p_sub_sensitivity_result.mat');
assert(exist(proto14_mat, 'file') == 2, 'proto14 result.mat not found.');
assert(exist(verifyB_mat, 'file') == 2, 'verify B result.mat not found.');
assert(exist(verifyA_mat, 'file') == 2, 'verify A result.mat not found.');
proto14_data = load(proto14_mat);
verifyB_data = load(verifyB_mat);
verifyA_data = load(verifyA_mat);
proto14_route_idx = find(strcmp(proto14_data.route_names, 'cylindrical_multilayer_coherent_proto14_main'), 1);
assert(~isempty(proto14_route_idx), 'proto14 route 2 not found.');

N_arc = 32;
K_fbss_list = [28, 24];
phase_offset_deg_list = [0, 5, 15, 30];
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

assert(isequal(K_fbss_list, [28, 24]), 'K_fbss_list must be [28,24].');
assert(isequal(phase_offset_deg_list, [0, 5, 15, 30]), 'phase_offset_deg_list must be [0,5,15,30].');

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s1 = exp(j * 2*pi * cfg.arr.fc * t);

route_names = cell(numel(K_fbss_list), numel(phase_offset_deg_list));
for iK = 1:numel(K_fbss_list)
    for iPhase = 1:numel(phase_offset_deg_list)
        route_names{iK, iPhase} = sprintf('verify_joint_K%d_phase%02d', ...
            K_fbss_list(iK), phase_offset_deg_list(iPhase));
    end
end

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
expected_snr_gain_db = 10 * log10(cfg.arr.Nel);
bw_eq = 50.8 * 1.45 * cfg.arr.lambda / (N_arc - 1) / d_eq;
bw_eq = round(bw_eq * 100) / 100;

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 1 geometry health check');
log_msg(fid_log, 'K_fbss_list=%s, phase_offset_deg_list=%s', mat2str(K_fbss_list), mat2str(phase_offset_deg_list));
log_msg(fid_log, 'arc_dist=%.8f m, arc/lambda=%.8f, subArc_span_deg=%.6f deg', arc_dist, arc_over_lambda, subArc_span_deg);
log_msg(fid_log, 'N_arc_span_deg=%.6f deg, bw_eq=%.6f deg, dz/lambda=%.8f, expected_snr_gain=%.6f dB', ...
    N_arc_span_deg, bw_eq, dz_over_lambda, expected_snr_gain_db);
assert(arc_over_lambda >= 0.4 && arc_over_lambda <= 0.5, 'arc/lambda geometry check failed.');
assert(abs(N_arc_span_deg - 58.125) / 58.125 < 0.01, 'N_arc span check failed.');
assert(abs(expected_snr_gain_db - 15.0515) / 15.0515 < 0.01, 'expected gain check failed.');
log_msg(fid_log, 'Layer 1 passed.');

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 2 joint sanity check');
sep_factor_sanity = 5;
snr_sanity = 28;
theta_sep_sanity = bw_eq / sep_factor_sanity;
theta_a_sanity = theta_c - theta_sep_sanity / 2;
theta_b_sanity = theta_c + theta_sep_sanity / 2;
target_sanity = [theta_a_sanity, theta_b_sanity];
sanity_max_err_deg = nan(numel(K_fbss_list), numel(phase_offset_deg_list));
sanity_pass = false(numel(K_fbss_list), numel(phase_offset_deg_list));
sanity_doa = nan(numel(K_fbss_list), numel(phase_offset_deg_list), Lc);
sanity_lambda2_over_noise = nan(numel(K_fbss_list), numel(phase_offset_deg_list));

for iK = 1:numel(K_fbss_list)
    K_fbss = K_fbss_list(iK);
    for iPhase = 1:numel(phase_offset_deg_list)
        phase_deg = phase_offset_deg_list(iPhase);
        s2 = build_s2_with_phase(s1, phase_deg);
        y_clean_2d_sanity = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, ...
            cfg.arr.lambda, theta_a_sanity, theta_b_sanity, el_a, el_b, s1, s2);
        noise_power_sanity = mean(abs(y_clean_2d_sanity(:)).^2) / 10^(snr_sanity / 10);
        rng(base_seed, 'twister');
        noise_2d_sanity = sqrt(noise_power_sanity / 2) * (randn(size(y_clean_2d_sanity)) + j * randn(size(y_clean_2d_sanity)));
        y_2d_sanity = y_clean_2d_sanity + noise_2d_sanity;
        y_main_sanity = combine_layers_local(y_2d_sanity, Z3d, cfg.arr.lambda, el_assumed);
        [doa_sanity, dbg_sanity] = doa_root_music_array(y_main_sanity, K_fbss, cfg.arr.lambda, d_eq, Lc);
        sanity_doa(iK, iPhase, :) = doa_sanity;
        sanity_max_err_deg(iK, iPhase) = max(abs(sort(doa_sanity) - sort(target_sanity)));
        sanity_pass(iK, iPhase) = all(isfinite(doa_sanity)) && sanity_max_err_deg(iK, iPhase) < 0.10;
        sanity_lambda2_over_noise(iK, iPhase) = dbg_sanity.lambda2_over_noise;
        log_msg(fid_log, 'K=%d phase=%d sanity pass=%d doa=[%.4f %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g', ...
            K_fbss, phase_deg, sanity_pass(iK, iPhase), doa_sanity(1), doa_sanity(2), ...
            sanity_max_err_deg(iK, iPhase), dbg_sanity.lambda2_over_noise);
    end
end
layer2_ok = all(sanity_pass(:));
if ~layer2_ok
    error('Layer 2 sanity failed.');
end
log_msg(fid_log, 'Layer 2 passed.');

nK = numel(K_fbss_list);
nPhase = numel(phase_offset_deg_list);
nsep = numel(sep_factor_list);
nsnr = numel(snr_list);
raw_success_count = zeros(nK, nPhase, nsep, nsnr);
tol_success_count = zeros(nK, nPhase, nsep, nsnr);
tol_success_count_rel = zeros(nK, nPhase, nsep, nsnr);
rmse_sum_sqerr = zeros(nK, nPhase, nsep, nsnr);
rmse_valid_count = zeros(nK, nPhase, nsep, nsnr);
sum_num_peaks = zeros(nK, nPhase, nsep, nsnr);
est_sum = zeros(nK, nPhase, nsep, nsnr, Lc);
lambda2_over_noise_sum = zeros(nK, nPhase, nsep, nsnr);
lambda2_count = zeros(nK, nPhase, nsep, nsnr);
degraded_sample_count = zeros(nK, nPhase, nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 joint scan starts');
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
    log_msg(fid_log, 'sep_factor=%d, theta_sep=%.6f deg, theta_a=%.6f, theta_b=%.6f', ...
        sep_factor, theta_sep, theta_a, theta_b);

    for iK = 1:nK
        K_fbss = K_fbss_list(iK);
        for iPhase = 1:nPhase
            phase_deg = phase_offset_deg_list(iPhase);
            s2 = build_s2_with_phase(s1, phase_deg);
            y_clean_2d = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, ...
                cfg.arr.lambda, theta_a, theta_b, el_a, el_b, s1, s2);

            for iSNR = 1:nsnr
                snr_db = snr_list(iSNR);
                noise_power_2d = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);

                for metkl_num = 1:Metkl
                    seed_now = base_seed + 100000*iSep + 1000*iSNR + metkl_num;
                    rng(seed_now, 'twister');
                    noise_2d = sqrt(noise_power_2d / 2) * (randn(size(y_clean_2d)) + j * randn(size(y_clean_2d)));
                    y_2d = y_clean_2d + noise_2d;
                    y_main = combine_layers_local(y_2d, Z3d, cfg.arr.lambda, el_assumed);

                    [doa_now, dbg_now] = doa_root_music_array(y_main, K_fbss, cfg.arr.lambda, d_eq, Lc);
                    raw_ok = all(isfinite(doa_now));
                    tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                    tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_deg_rel);
                    doa_degraded = true;

                    if raw_ok
                        raw_success_count(iK, iPhase, iSep, iSNR) = raw_success_count(iK, iPhase, iSep, iSNR) + 1;
                        doa_sorted = sort(doa_now(:).');
                        target_sorted = sort(target_theta(:).');
                        err = doa_sorted - target_sorted;
                        doa_degraded = max(abs(err)) > 1.0;
                        rmse_sum_sqerr(iK, iPhase, iSep, iSNR) = rmse_sum_sqerr(iK, iPhase, iSep, iSNR) + sum(err.^2);
                        rmse_valid_count(iK, iPhase, iSep, iSNR) = rmse_valid_count(iK, iPhase, iSep, iSNR) + 1;
                        est_sum(iK, iPhase, iSep, iSNR, :) = squeeze(est_sum(iK, iPhase, iSep, iSNR, :)).' + doa_sorted;
                    end

                    if doa_degraded
                        degraded_sample_count(iK, iPhase, iSep, iSNR) = degraded_sample_count(iK, iPhase, iSep, iSNR) + 1;
                    end
                    if tol_ok_abs
                        tol_success_count(iK, iPhase, iSep, iSNR) = tol_success_count(iK, iPhase, iSep, iSNR) + 1;
                    end
                    if tol_ok_rel
                        tol_success_count_rel(iK, iPhase, iSep, iSNR) = tol_success_count_rel(iK, iPhase, iSep, iSNR) + 1;
                    end
                    sum_num_peaks(iK, iPhase, iSep, iSNR) = sum_num_peaks(iK, iPhase, iSep, iSNR) + double(raw_ok) * Lc;
                    if isfield(dbg_now, 'lambda2_over_noise') && isfinite(dbg_now.lambda2_over_noise)
                        lambda2_over_noise_sum(iK, iPhase, iSep, iSNR) = lambda2_over_noise_sum(iK, iPhase, iSep, iSNR) + dbg_now.lambda2_over_noise;
                        lambda2_count(iK, iPhase, iSep, iSNR) = lambda2_count(iK, iPhase, iSep, iSNR) + 1;
                    end
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

snr90_abs01 = calc_snr90_4d(tol_success_rate, snr_list);
snr90_rel = calc_snr90_4d(tol_success_rate_rel, snr_list);
degraded_per_sep = squeeze(sum(degraded_sample_count, 4));
degraded_count_total = squeeze(sum(sum(degraded_sample_count, 4), 3));
degraded_rate_by_sep = degraded_per_sep / (nsnr * Metkl);
degraded_rate_total = degraded_count_total / (nsep * nsnr * Metkl);

self_check = struct();
proto14_rmse = squeeze(proto14_data.rmse(proto14_route_idx, :, :));
proto14_tol = squeeze(proto14_data.tol_success_count(proto14_route_idx, :, :));
self_check.K28_phase00_vs_proto14 = make_self_check(squeeze(rmse_deg(1, 1, :, :)), proto14_rmse, ...
    squeeze(tol_success_count(1, 1, :, :)), proto14_tol);

idx_B_phase15 = find(verifyB_data.phase_offset_deg_list == 15, 1);
self_check.K28_phase15_vs_verifyB = make_self_check(squeeze(rmse_deg(1, 3, :, :)), ...
    squeeze(verifyB_data.rmse_deg(idx_B_phase15, :, :)), squeeze(tol_success_count(1, 3, :, :)), ...
    squeeze(verifyB_data.tol_success_count(idx_B_phase15, :, :)));

idx_A_K24 = find(verifyA_data.K_fbss_list == 24, 1);
self_check.K24_phase00_vs_verifyA = make_self_check(squeeze(rmse_deg(2, 1, :, :)), ...
    squeeze(verifyA_data.rmse_deg(idx_A_K24, :, :)), squeeze(tol_success_count(2, 1, :, :)), ...
    squeeze(verifyA_data.tol_success_count(idx_A_K24, :, :)));

all_self_check_ok = self_check.K28_phase00_vs_proto14.pass && ...
    self_check.K28_phase15_vs_verifyB.pass && self_check.K24_phase00_vs_verifyA.pass;

idx_sep10 = find(sep_factor_list == 10, 1);
idx_phase0 = find(phase_offset_deg_list == 0, 1);
idx_phase5 = find(phase_offset_deg_list == 5, 1);
idx_phase15 = find(phase_offset_deg_list == 15, 1);
idx_phase30 = find(phase_offset_deg_list == 30, 1);
snr90_sep10 = squeeze(snr90_abs01(:, :, idx_sep10));
degraded_total_matrix = squeeze(degraded_rate_total);

delta_j1 = snr90_sep10(2, idx_phase15) - snr90_sep10(1, idx_phase15);
layer3b_ok = isfinite(delta_j1) && abs(delta_j1) <= 2;
delta_phase5 = snr90_sep10(2, idx_phase5) - snr90_sep10(1, idx_phase5);
delta_phase0 = snr90_diff_signed(snr90_sep10(2, idx_phase0), snr90_sep10(1, idx_phase0));
layer3d_ok = (isfinite(snr90_sep10(2, idx_phase0)) && ~isfinite(snr90_sep10(1, idx_phase0))) || ...
    (isfinite(delta_phase0) && delta_phase0 <= -5);
layer3e_k24_le_k28 = all(degraded_total_matrix(2, :) <= degraded_total_matrix(1, :) + 1e-12);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 acceptance checks');
log_msg(fid_log, '3a-1 self-check K28 phase0 vs proto14: pass=%d, rmse_diff_max=%.4g, tol_count_diff_max=%.4g', ...
    self_check.K28_phase00_vs_proto14.pass, self_check.K28_phase00_vs_proto14.rmse_diff_max, self_check.K28_phase00_vs_proto14.tol_count_diff_max);
log_msg(fid_log, '3a-2 self-check K28 phase15 vs verifyB: pass=%d, rmse_diff_max=%.4g, tol_count_diff_max=%.4g', ...
    self_check.K28_phase15_vs_verifyB.pass, self_check.K28_phase15_vs_verifyB.rmse_diff_max, self_check.K28_phase15_vs_verifyB.tol_count_diff_max);
log_msg(fid_log, '3a-3 self-check K24 phase0 vs verifyA: pass=%d, rmse_diff_max=%.4g, tol_count_diff_max=%.4g', ...
    self_check.K24_phase00_vs_verifyA.pass, self_check.K24_phase00_vs_verifyA.rmse_diff_max, self_check.K24_phase00_vs_verifyA.tol_count_diff_max);
log_msg(fid_log, '3b J1 delta SNR90(K24-K28) at phase15 sep10 = %.4g dB, pass=%d', delta_j1, layer3b_ok);
log_msg(fid_log, '3c delta SNR90(K24-K28) at phase5 sep10 = %.4g dB', delta_phase5);
log_msg(fid_log, '3d delta SNR90(K24-K28) at phase0 sep10 = %.4g dB, pass=%d', delta_phase0, layer3d_ok);
log_msg(fid_log, '3e degraded K24<=K28 by phase = %d, degraded matrix=%s', layer3e_k24_le_k28, mat2str(degraded_total_matrix, 4));
log_msg(fid_log, 'sep=10 SNR90 matrix rows K=[28;24], cols phase=[0 5 15 30]: %s', mat2str(snr90_sep10, 4));

summary_path = fullfile(result_dir, 'verify_joint_psub_coherence_summary.csv');
keypoints_path = fullfile(result_dir, 'verify_joint_psub_coherence_keypoints.csv');
write_summary_csv(summary_path, route_names, K_fbss_list, phase_offset_deg_list, sep_factor_list, snr_list, ...
    theta_sep_deg, theta_a_deg, theta_b_deg, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse_deg, snr90_abs01, snr90_rel, mean_bias_deg, max_bias_deg, lambda2_over_noise, degraded_sample_count);
write_keypoints_csv(keypoints_path, K_fbss_list, phase_offset_deg_list, sep_factor_list, snr90_abs01, ...
    snr90_rel, degraded_rate_by_sep);

result_mat_path = fullfile(result_dir, 'verify_joint_psub_coherence_result.mat');
save(result_mat_path, 'cfg', 'K_fbss_list', 'phase_offset_deg_list', 'sep_factor_list', 'snr_list', ...
    'route_names', 'N_arc', 'Metkl', 'T_snap', 'base_seed', 'azCtr_deg', 'el_a', 'el_b', ...
    'el_assumed', 'tol_deg', 'tol_rel_ratio', 'Lc', 'bw_eq', 'theta_sep_deg', 'theta_a_deg', ...
    'theta_b_deg', 'raw_success_count', 'tol_success_count', 'tol_success_count_rel', ...
    'raw_success_rate', 'tol_success_rate', 'tol_success_rate_rel', 'rmse_deg', 'rmse_valid_count', ...
    'mean_num_peaks', 'snr90_abs01', 'snr90_rel', 'mean_bias_deg', 'max_bias_deg', ...
    'mean_az_a_est', 'mean_az_b_est', 'lambda2_over_noise', 'degraded_sample_count', ...
    'degraded_count_total', 'degraded_per_sep', 'degraded_rate_total', 'degraded_rate_by_sep', ...
    'sanity_max_err_deg', 'sanity_pass', 'sanity_doa', 'sanity_lambda2_over_noise', ...
    'self_check', 'all_self_check_ok', 'delta_j1', 'delta_phase5', 'delta_phase0', ...
    'layer3b_ok', 'layer3d_ok', 'layer3e_k24_le_k28', 'snr90_sep10', 'degraded_total_matrix');

plot_sep10_snr90_heatmap(fullfile(result_dir, 'verify_joint_sep10_snr90_heatmap.png'), ...
    K_fbss_list, phase_offset_deg_list, snr90_sep10);
plot_sep10_tol_curves(fullfile(result_dir, 'verify_joint_sep10_tol_rate_curves.png'), ...
    K_fbss_list, phase_offset_deg_list, snr_list, squeeze(tol_success_rate(:, :, idx_sep10, :)));
plot_degradation_heatmap(fullfile(result_dir, 'verify_joint_degradation_heatmap.png'), ...
    K_fbss_list, phase_offset_deg_list, degraded_total_matrix);
plot_redundancy_test(fullfile(result_dir, 'verify_joint_redundancy_test.png'), ...
    phase_offset_deg_list, snr90_sep10, degraded_total_matrix);
plot_self_check_diff(fullfile(result_dir, 'verify_joint_self_check_diff.png'), snr_list, sep_factor_list, self_check);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 4 diagnostic figures generated.');
log_msg(fid_log, 'Result directory: %s', result_dir);
log_msg(fid_log, '');
log_msg(fid_log, '4-layer acceptance summary');
log_msg(fid_log, 'Layer 1 geometry: PASS');
log_msg(fid_log, 'Layer 2 sanity max_err matrix=%s', mat2str(sanity_max_err_deg, 4));
log_msg(fid_log, 'Layer 3 regression: self_checks=%d, J1=%d, phase0_K24_gain=%d, K24_degraded_le_K28=%d', ...
    all_self_check_ok, layer3b_ok, layer3d_ok, layer3e_k24_le_k28);
log_msg(fid_log, 'Layer 4 figures: PASS');

function s2 = build_s2_with_phase(s1, phase_deg)
    j = sqrt(-1);
    if phase_deg == 0
        s2 = s1;
    else
        s2 = s1 .* exp(j * deg2rad(phase_deg));
    end
end

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

function snr90 = calc_snr90_4d(rate_cube, snr_list)
    [nK, nPhase, nsep, ~] = size(rate_cube);
    snr90 = nan(nK, nPhase, nsep);
    for iK = 1:nK
        for iPhase = 1:nPhase
            for iSep = 1:nsep
                idx = find(squeeze(rate_cube(iK, iPhase, iSep, :)) >= 0.9, 1, 'first');
                if ~isempty(idx)
                    snr90(iK, iPhase, iSep) = snr_list(idx);
                end
            end
        end
    end
end

function [mean_az_a_est, mean_az_b_est, mean_bias_deg, max_bias_deg] = summarize_bias_local(est_sum, valid_count, theta_a_deg, theta_b_deg)
    [nK, nPhase, nsep, nsnr, ~] = size(est_sum);
    mean_az_a_est = nan(nK, nPhase, nsep, nsnr);
    mean_az_b_est = nan(nK, nPhase, nsep, nsnr);
    mean_bias_deg = nan(nK, nPhase, nsep, nsnr);
    max_bias_deg = nan(nK, nPhase, nsep, nsnr);
    for iK = 1:nK
        for iPhase = 1:nPhase
            for iSep = 1:nsep
                for iSNR = 1:nsnr
                    count_now = valid_count(iK, iPhase, iSep, iSNR);
                    if count_now > 0
                        mean_pair = squeeze(est_sum(iK, iPhase, iSep, iSNR, :)).' / count_now;
                        mean_az_a_est(iK, iPhase, iSep, iSNR) = mean_pair(1);
                        mean_az_b_est(iK, iPhase, iSep, iSNR) = mean_pair(2);
                        bias_pair = mean_pair - [theta_a_deg(iSep), theta_b_deg(iSep)];
                        mean_bias_deg(iK, iPhase, iSep, iSNR) = mean(bias_pair);
                        max_bias_deg(iK, iPhase, iSep, iSNR) = max(abs(bias_pair));
                    end
                end
            end
        end
    end
end

function out = make_self_check(test_rmse, ref_rmse, test_tol, ref_tol)
    rmse_diff = test_rmse - ref_rmse;
    both_nan = isnan(test_rmse) & isnan(ref_rmse);
    nan_mismatch = xor(isnan(test_rmse), isnan(ref_rmse));
    rmse_diff(both_nan) = 0;
    rmse_diff(nan_mismatch) = Inf;
    tol_diff = test_tol - ref_tol;
    out = struct();
    out.rmse_diff = rmse_diff;
    out.tol_count_diff = tol_diff;
    out.rmse_diff_max = max(abs(rmse_diff(:)));
    out.tol_count_diff_max = max(abs(tol_diff(:)));
    out.pass = out.rmse_diff_max < 1e-10 && out.tol_count_diff_max == 0;
end

function d = snr90_diff_signed(new_value, ref_value)
    if isfinite(new_value) && isfinite(ref_value)
        d = new_value - ref_value;
    elseif isfinite(new_value) && ~isfinite(ref_value)
        d = -Inf;
    elseif ~isfinite(new_value) && isfinite(ref_value)
        d = Inf;
    else
        d = NaN;
    end
end

function write_summary_csv(path_out, route_names, K_fbss_list, phase_offset_deg_list, sep_factor_list, snr_list, ...
    theta_sep_deg, theta_a_deg, theta_b_deg, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse_deg, snr90_abs01, snr90_rel, mean_bias_deg, max_bias_deg, lambda2_over_noise, degraded_sample_count)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['route_name,K_fbss,phase_offset_deg,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
        'raw_success_rate,tol_success_rate,tol_success_rate_rel,rmse_deg,snr90_db,snr90_rel_db,' ...
        'mean_bias_deg,max_bias_deg,lambda2_over_noise,degraded_sample_count\n']);
    for iK = 1:numel(K_fbss_list)
        for iPhase = 1:numel(phase_offset_deg_list)
            for iSep = 1:numel(sep_factor_list)
                for iSNR = 1:numel(snr_list)
                    fprintf(fid, '%s,%d,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d\n', ...
                        route_names{iK, iPhase}, K_fbss_list(iK), phase_offset_deg_list(iPhase), sep_factor_list(iSep), ...
                        theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), ...
                        raw_success_rate(iK, iPhase, iSep, iSNR), tol_success_rate(iK, iPhase, iSep, iSNR), ...
                        tol_success_rate_rel(iK, iPhase, iSep, iSNR), rmse_deg(iK, iPhase, iSep, iSNR), ...
                        snr90_abs01(iK, iPhase, iSep), snr90_rel(iK, iPhase, iSep), ...
                        mean_bias_deg(iK, iPhase, iSep, iSNR), max_bias_deg(iK, iPhase, iSep, iSNR), ...
                        lambda2_over_noise(iK, iPhase, iSep, iSNR), degraded_sample_count(iK, iPhase, iSep, iSNR));
                end
            end
        end
    end
end

function write_keypoints_csv(path_out, K_fbss_list, phase_offset_deg_list, sep_factor_list, snr90_abs01, snr90_rel, degraded_rate_by_sep)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'K_fbss,phase_offset_deg,sep_factor,snr90_db,snr90_rel_db,degraded_rate\n');
    for iK = 1:numel(K_fbss_list)
        for iPhase = 1:numel(phase_offset_deg_list)
            for iSep = 1:numel(sep_factor_list)
                fprintf(fid, '%d,%d,%d,%.6f,%.6f,%.6f\n', ...
                    K_fbss_list(iK), phase_offset_deg_list(iPhase), sep_factor_list(iSep), ...
                    snr90_abs01(iK, iPhase, iSep), snr90_rel(iK, iPhase, iSep), degraded_rate_by_sep(iK, iPhase, iSep));
            end
        end
    end
end

function plot_sep10_snr90_heatmap(path_out, K_fbss_list, phase_offset_deg_list, snr90_sep10)
    fig = figure('Visible', 'off', 'Position', [100, 100, 760, 420]);
    imagesc(phase_offset_deg_list, 1:numel(K_fbss_list), snr90_sep10);
    set(gca, 'YTick', 1:numel(K_fbss_list), 'YTickLabel', compose('K=%d', K_fbss_list));
    colorbar
    xlabel('phase offset (deg)');
    ylabel('K fbss');
    title('sep=10 SNR90 joint matrix');
    for iK = 1:numel(K_fbss_list)
        for iPhase = 1:numel(phase_offset_deg_list)
            val = snr90_sep10(iK, iPhase);
            if isfinite(val)
                txt = sprintf('%.0f', val);
            else
                txt = 'NaN';
            end
            text(phase_offset_deg_list(iPhase), iK, txt, 'HorizontalAlignment', 'center', ...
                'Color', 'w', 'FontWeight', 'bold');
        end
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_sep10_tol_curves(path_out, K_fbss_list, phase_offset_deg_list, snr_list, sep10_tol)
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    for iK = 1:numel(K_fbss_list)
        for iPhase = 1:numel(phase_offset_deg_list)
            if K_fbss_list(iK) == 28
                style = '-';
            else
                style = '--';
            end
            plot(snr_list, squeeze(sep10_tol(iK, iPhase, :)), [style 'o'], 'LineWidth', 1.1);
            hold on
        end
    end
    yline(0.85, ':', '0.85');
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('SNR (dB)');
    ylabel('tol rate');
    title('sep=10 tol rate curves');
    legend(make_joint_labels(K_fbss_list, phase_offset_deg_list), 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_degradation_heatmap(path_out, K_fbss_list, phase_offset_deg_list, degraded_total_matrix)
    fig = figure('Visible', 'off', 'Position', [100, 100, 760, 420]);
    vals = degraded_total_matrix * 100;
    imagesc(phase_offset_deg_list, 1:numel(K_fbss_list), vals);
    set(gca, 'YTick', 1:numel(K_fbss_list), 'YTickLabel', compose('K=%d', K_fbss_list));
    colorbar
    xlabel('phase offset (deg)');
    ylabel('K fbss');
    title('overall degradation rate (%)');
    for iK = 1:numel(K_fbss_list)
        for iPhase = 1:numel(phase_offset_deg_list)
            text(phase_offset_deg_list(iPhase), iK, sprintf('%.2f%%', vals(iK, iPhase)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_redundancy_test(path_out, phase_offset_deg_list, snr90_sep10, degraded_total_matrix)
    diff_snr90 = snr90_sep10(1, :) - snr90_sep10(2, :);
    diff_degraded = (degraded_total_matrix(1, :) - degraded_total_matrix(2, :)) * 100;
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 620]);
    subplot(2, 1, 1);
    plot(phase_offset_deg_list, diff_snr90, '-o', 'LineWidth', 1.4);
    yline(0, '--');
    yline(2, ':');
    yline(-2, ':');
    grid on
    xlabel('phase offset (deg)');
    ylabel('SNR90 K28 - K24 (dB)');
    title('J1 redundancy test: SNR90 difference');
    subplot(2, 1, 2);
    plot(phase_offset_deg_list, diff_degraded, '-o', 'LineWidth', 1.4);
    yline(0, '--');
    grid on
    xlabel('phase offset (deg)');
    ylabel('degradation K28 - K24 (%)');
    title('J1 redundancy test: degradation difference');
    saveas(fig, path_out);
    close(fig);
end

function plot_self_check_diff(path_out, snr_list, sep_factor_list, self_check)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 420]);
    names = {'K28 phase0 vs proto14', 'K28 phase15 vs verifyB', 'K24 phase0 vs verifyA'};
    diffs = {self_check.K28_phase00_vs_proto14.rmse_diff, ...
             self_check.K28_phase15_vs_verifyB.rmse_diff, ...
             self_check.K24_phase00_vs_verifyA.rmse_diff};
    for ii = 1:3
        subplot(1, 3, ii);
        imagesc(snr_list, sep_factor_list, diffs{ii});
        colorbar
        xlabel('SNR (dB)');
        ylabel('sep factor');
        title(names{ii});
    end
    saveas(fig, path_out);
    close(fig);
end

function labels = make_joint_labels(K_fbss_list, phase_offset_deg_list)
    labels = cell(1, numel(K_fbss_list) * numel(phase_offset_deg_list));
    idx = 0;
    for iK = 1:numel(K_fbss_list)
        for iPhase = 1:numel(phase_offset_deg_list)
            idx = idx + 1;
            labels{idx} = sprintf('K=%d phase=%d', K_fbss_list(iK), phase_offset_deg_list(iPhase));
        end
    end
end

function log_msg(fid, varargin)
    msg = sprintf(varargin{:});
    fprintf('%s\n', msg);
    fprintf(fid, '%s\n', msg);
end
