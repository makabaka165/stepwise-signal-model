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

result_dir = fullfile(script_dir, 'results_step8_5_verify_coherence_sensitivity');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'verify_coherence_sensitivity.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() fclose(fid_log));

log_msg(fid_log, 'Verify B: source coherence phase sensitivity scan');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Frozen algorithm path: %s', step08_dir);

proto14_mat = fullfile(script_dir, 'results_step8_5_cylindrical_multilayer_proto14', ...
    'step8_5_cylindrical_multilayer_proto14_result.mat');
assert(exist(proto14_mat, 'file') == 2, 'proto14 result.mat not found.');
proto14_data = load(proto14_mat);
proto14_route_idx = find(strcmp(proto14_data.route_names, 'cylindrical_multilayer_coherent_proto14_main'), 1);
assert(~isempty(proto14_route_idx), 'proto14 route 2 not found.');

N_arc = 32;
K_fbss = 28;
phase_offset_deg_list = [0, 5, 15, 30, 60, 90, 180];
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

assert(isequal(phase_offset_deg_list, [0, 5, 15, 30, 60, 90, 180]), ...
    'phase_offset_deg_list must be [0,5,15,30,60,90,180].');

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s1 = exp(j * 2*pi * cfg.arr.fc * t);

route_names = { ...
    'verify_coh_phase00_completely_inphase_baseline', ...
    'verify_coh_phase05_near_inphase', ...
    'verify_coh_phase15_mild_decoherence', ...
    'verify_coh_phase30_typical_multipath', ...
    'verify_coh_phase60_strong_multipath', ...
    'verify_coh_phase90_quadrature', ...
    'verify_coh_phase180_antiphase'};

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
log_msg(fid_log, 'phase_offset_deg_list=%s', mat2str(phase_offset_deg_list));
log_msg(fid_log, 'K_fbss=%d, arc_dist=%.8f m, arc/lambda=%.8f, subArc_span_deg=%.6f deg', ...
    K_fbss, arc_dist, arc_over_lambda, subArc_span_deg);
log_msg(fid_log, 'N_arc_span_deg=%.6f deg, bw_eq=%.6f deg, dz/lambda=%.8f', ...
    N_arc_span_deg, bw_eq, dz_over_lambda);
log_msg(fid_log, 'expected_snr_gain=%.6f dB, selected global cols=%s', ...
    expected_snr_gain_db, mat2str(arrInfo.colsAct(col_select)));
assert(arc_over_lambda >= 0.4 && arc_over_lambda <= 0.5, 'arc/lambda geometry check failed.');
assert(abs(N_arc_span_deg - 58.125) / 58.125 < 0.01, 'N_arc span check failed.');
assert(abs(expected_snr_gain_db - 15.0515) / 15.0515 < 0.01, 'expected gain check failed.');
log_msg(fid_log, 'Layer 1 passed.');

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 2 phase-offset sanity check');
sep_factor_sanity = 5;
snr_sanity = 28;
theta_sep_sanity = bw_eq / sep_factor_sanity;
theta_a_sanity = theta_c - theta_sep_sanity / 2;
theta_b_sanity = theta_c + theta_sep_sanity / 2;
target_sanity = [theta_a_sanity, theta_b_sanity];
sanity_threshold = [0.05, 0.05, 0.05, 0.05, 0.10, 0.10, 0.30];
sanity_max_err_deg = nan(numel(phase_offset_deg_list), 1);
sanity_pass = false(numel(phase_offset_deg_list), 1);
sanity_lambda2_over_noise = nan(numel(phase_offset_deg_list), 1);
sanity_doa = nan(numel(phase_offset_deg_list), Lc);

for iPhase = 1:numel(phase_offset_deg_list)
    phase_deg = phase_offset_deg_list(iPhase);
    s2 = build_s2_with_phase(s1, cfg.arr.fc, t, phase_deg);
    y_clean_2d_sanity = make_clean_cylindrical_observations(X3d, Y3d, Z3d, A_ref_2d, ...
        cfg.arr.lambda, theta_a_sanity, theta_b_sanity, el_a, el_b, s1, s2);
    noise_power_sanity = mean(abs(y_clean_2d_sanity(:)).^2) / 10^(snr_sanity / 10);
    rng(base_seed, 'twister');
    noise_2d_sanity = sqrt(noise_power_sanity / 2) * (randn(size(y_clean_2d_sanity)) + j * randn(size(y_clean_2d_sanity)));
    y_2d_sanity = y_clean_2d_sanity + noise_2d_sanity;
    y_main_sanity = combine_layers_local(y_2d_sanity, Z3d, cfg.arr.lambda, el_assumed);
    [doa_sanity, dbg_sanity] = doa_root_music_array(y_main_sanity, K_fbss, cfg.arr.lambda, d_eq, Lc);
    sanity_doa(iPhase, :) = doa_sanity;
    sanity_max_err_deg(iPhase) = max(abs(sort(doa_sanity) - sort(target_sanity)));
    sanity_pass(iPhase) = all(isfinite(doa_sanity)) && sanity_max_err_deg(iPhase) < sanity_threshold(iPhase);
    sanity_lambda2_over_noise(iPhase) = dbg_sanity.lambda2_over_noise;
    log_msg(fid_log, 'phase=%d deg sanity pass=%d doa=[%.4f %.4f], true=[%.4f %.4f], max_err=%.4f deg, threshold=%.4f, lambda2_over_noise=%.4g', ...
        phase_deg, sanity_pass(iPhase), doa_sanity(1), doa_sanity(2), ...
        target_sanity(1), target_sanity(2), sanity_max_err_deg(iPhase), sanity_threshold(iPhase), dbg_sanity.lambda2_over_noise);
end
layer2_all_pass = all(sanity_pass);
sanity_trend_ok = all(sanity_max_err_deg(2:6) <= max(sanity_max_err_deg(1), 0.05));
log_msg(fid_log, 'Layer 2 completed. all_pass=%d, trend_check_0_to_90=%d', layer2_all_pass, sanity_trend_ok);

nPhase = numel(phase_offset_deg_list);
nsep = numel(sep_factor_list);
nsnr = numel(snr_list);
raw_success_count = zeros(nPhase, nsep, nsnr);
tol_success_count = zeros(nPhase, nsep, nsnr);
tol_success_count_rel = zeros(nPhase, nsep, nsnr);
rmse_sum_sqerr = zeros(nPhase, nsep, nsnr);
rmse_valid_count = zeros(nPhase, nsep, nsnr);
sum_num_peaks = zeros(nPhase, nsep, nsnr);
est_sum = zeros(nPhase, nsep, nsnr, Lc);
lambda2_over_noise_sum = zeros(nPhase, nsep, nsnr);
lambda2_count = zeros(nPhase, nsep, nsnr);
degraded_sample_count = zeros(nPhase, nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 coherence sensitivity full scan starts');
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

    for iPhase = 1:nPhase
        phase_deg = phase_offset_deg_list(iPhase);
        s2 = build_s2_with_phase(s1, cfg.arr.fc, t, phase_deg);
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
                    raw_success_count(iPhase, iSep, iSNR) = raw_success_count(iPhase, iSep, iSNR) + 1;
                    doa_sorted = sort(doa_now(:).');
                    target_sorted = sort(target_theta(:).');
                    err = doa_sorted - target_sorted;
                    doa_degraded = max(abs(err)) > 1.0;
                    rmse_sum_sqerr(iPhase, iSep, iSNR) = rmse_sum_sqerr(iPhase, iSep, iSNR) + sum(err.^2);
                    rmse_valid_count(iPhase, iSep, iSNR) = rmse_valid_count(iPhase, iSep, iSNR) + 1;
                    est_sum(iPhase, iSep, iSNR, :) = squeeze(est_sum(iPhase, iSep, iSNR, :)).' + doa_sorted;
                end

                if doa_degraded
                    degraded_sample_count(iPhase, iSep, iSNR) = degraded_sample_count(iPhase, iSep, iSNR) + 1;
                end
                if tol_ok_abs
                    tol_success_count(iPhase, iSep, iSNR) = tol_success_count(iPhase, iSep, iSNR) + 1;
                end
                if tol_ok_rel
                    tol_success_count_rel(iPhase, iSep, iSNR) = tol_success_count_rel(iPhase, iSep, iSNR) + 1;
                end
                sum_num_peaks(iPhase, iSep, iSNR) = sum_num_peaks(iPhase, iSep, iSNR) + double(raw_ok) * Lc;
                if isfield(dbg_now, 'lambda2_over_noise') && isfinite(dbg_now.lambda2_over_noise)
                    lambda2_over_noise_sum(iPhase, iSep, iSNR) = lambda2_over_noise_sum(iPhase, iSep, iSNR) + dbg_now.lambda2_over_noise;
                    lambda2_count(iPhase, iSep, iSNR) = lambda2_count(iPhase, iSep, iSNR) + 1;
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
proto14_degraded = squeeze(proto14_data.degraded_sample_count(proto14_route_idx, :, :));
proto14_mean_bias = squeeze(proto14_data.mean_bias_deg(proto14_route_idx, :, :));
rmse_phase0 = squeeze(rmse_deg(1, :, :));
tol_count_phase0 = squeeze(tol_success_count(1, :, :));
degraded_phase0 = squeeze(degraded_sample_count(1, :, :));
mean_bias_phase0 = squeeze(mean_bias_deg(1, :, :));
rmse_diff = rmse_phase0 - proto14_rmse;
both_nan = isnan(rmse_phase0) & isnan(proto14_rmse);
nan_mismatch = xor(isnan(rmse_phase0), isnan(proto14_rmse));
rmse_diff(both_nan) = 0;
rmse_diff(nan_mismatch) = Inf;
tol_count_diff = tol_count_phase0 - proto14_tol_count;
degraded_diff = degraded_phase0 - proto14_degraded;
mean_bias_diff = mean_bias_phase0 - proto14_mean_bias;
mean_bias_diff(isnan(mean_bias_phase0) & isnan(proto14_mean_bias)) = 0;

proto14_baseline_compare = struct();
proto14_baseline_compare.rmse_diff_max = max(abs(rmse_diff(:)));
proto14_baseline_compare.tol_count_diff_max = max(abs(tol_count_diff(:)));
proto14_baseline_compare.degraded_count_diff_max = max(abs(degraded_diff(:)));
proto14_baseline_compare.mean_bias_diff_max = max(abs(mean_bias_diff(:)));
proto14_baseline_compare.pass = proto14_baseline_compare.rmse_diff_max < 1e-10 && ...
    proto14_baseline_compare.tol_count_diff_max == 0 && proto14_baseline_compare.degraded_count_diff_max == 0;

idx_sep10 = find(sep_factor_list == 10, 1);
idx_snr20 = find(snr_list == 20, 1);
idx_snr24 = find(snr_list == 24, 1);
idx_snr30 = find(snr_list == 30, 1);
idx_phase30 = find(phase_offset_deg_list == 30, 1);
idx_phase60 = find(phase_offset_deg_list == 60, 1);
idx_phase90 = find(phase_offset_deg_list == 90, 1);
idx_phase180 = find(phase_offset_deg_list == 180, 1);

layer3a_ok = proto14_baseline_compare.pass;
layer3b_rate = tol_success_rate(idx_phase30, idx_sep10, idx_snr24);
layer3b_ok = layer3b_rate >= 0.85;
layer3c_rate60 = tol_success_rate(idx_phase60, idx_sep10, idx_snr20);
layer3c_rate90 = tol_success_rate(idx_phase90, idx_sep10, idx_snr20);
layer3c_ok = layer3c_rate60 >= 0.85 && layer3c_rate90 >= 0.85;
layer3d_diffs = diff(degraded_rate_total(1:idx_phase90));
layer3d_ok = all(layer3d_diffs <= 1e-12) && degraded_rate_total(idx_phase90) < degraded_rate_total(1);
layer3e_ratio_180_0 = degraded_rate_total(idx_phase180) / max(degraded_rate_total(1), eps);
layer3f_bias_diff = abs(mean_bias_diff(idx_sep10, idx_snr30));
layer3f_ok = layer3f_bias_diff < 1e-10;

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 acceptance checks');
log_msg(fid_log, '3a phase=0 proto14 replay pass=%d, rmse_diff_max=%.4g, tol_count_diff_max=%.4g, degraded_diff_max=%.4g', ...
    layer3a_ok, proto14_baseline_compare.rmse_diff_max, proto14_baseline_compare.tol_count_diff_max, proto14_baseline_compare.degraded_count_diff_max);
log_msg(fid_log, '3b phase=30 sep=10 SNR=24 tol_rate=%.6f, pass=%d', layer3b_rate, layer3b_ok);
log_msg(fid_log, '3c phase=60/90 sep=10 SNR=20 tol_rate=[%.6f %.6f], pass=%d', layer3c_rate60, layer3c_rate90, layer3c_ok);
log_msg(fid_log, '3d degraded rates 0->90=%s, monotonic_down=%d', mat2str(degraded_rate_total(1:idx_phase90).', 4), layer3d_ok);
log_msg(fid_log, '3e phase=180 degraded=%.6f vs phase=0 degraded=%.6f, ratio=%.6f', ...
    degraded_rate_total(idx_phase180), degraded_rate_total(1), layer3e_ratio_180_0);
log_msg(fid_log, '3f phase=0 sep=10 SNR=30 mean_bias diff=%.4g deg, pass=%d', layer3f_bias_diff, layer3f_ok);
for iPhase = 1:nPhase
    log_msg(fid_log, 'phase=%d deg SNR90=%s, degraded_total=%.6f', ...
        phase_offset_deg_list(iPhase), mat2str(snr90_abs01(iPhase, :), 4), degraded_rate_total(iPhase));
end

summary_path = fullfile(result_dir, 'verify_coherence_sensitivity_summary.csv');
keypoints_path = fullfile(result_dir, 'verify_coherence_sensitivity_keypoints.csv');
write_summary_csv(summary_path, route_names, phase_offset_deg_list, sep_factor_list, snr_list, ...
    theta_sep_deg, theta_a_deg, theta_b_deg, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse_deg, snr90_abs01, snr90_rel, mean_bias_deg, max_bias_deg, lambda2_over_noise, ...
    degraded_sample_count, mean_num_peaks);
write_keypoints_csv(keypoints_path, phase_offset_deg_list, sep_factor_list, snr90_abs01, snr90_rel, ...
    degraded_rate_by_sep, sanity_max_err_deg);

result_mat_path = fullfile(result_dir, 'verify_coherence_sensitivity_result.mat');
save(result_mat_path, 'cfg', 'phase_offset_deg_list', 'sep_factor_list', 'snr_list', ...
    'route_names', 'N_arc', 'K_fbss', 'Metkl', 'T_snap', 'base_seed', 'azCtr_deg', ...
    'el_a', 'el_b', 'el_assumed', 'tol_deg', 'tol_rel_ratio', 'Lc', 'bw_eq', ...
    'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', 'raw_success_count', ...
    'tol_success_count', 'tol_success_count_rel', 'raw_success_rate', 'tol_success_rate', ...
    'tol_success_rate_rel', 'rmse_deg', 'rmse_valid_count', 'mean_num_peaks', ...
    'snr90_abs01', 'snr90_rel', 'mean_bias_deg', 'max_bias_deg', 'mean_az_a_est', ...
    'mean_az_b_est', 'lambda2_over_noise', 'degraded_sample_count', ...
    'degraded_count_total', 'degraded_per_sep', 'degraded_rate_total', 'degraded_rate_by_sep', ...
    'sanity_max_err_deg', 'sanity_pass', 'layer2_all_pass', 'sanity_lambda2_over_noise', 'sanity_doa', ...
    'proto14_baseline_compare', 'rmse_diff', 'tol_count_diff', 'degraded_diff', 'mean_bias_diff', ...
    'layer3a_ok', 'layer3b_ok', 'layer3c_ok', 'layer3d_ok', 'layer3f_ok', ...
    'layer3b_rate', 'layer3c_rate60', 'layer3c_rate90', 'layer3e_ratio_180_0', 'layer3f_bias_diff');

plot_phase_snr90_heatmap(fullfile(result_dir, 'verify_coh_phase_vs_snr90_heatmap.png'), ...
    phase_offset_deg_list, sep_factor_list, snr90_abs01);
plot_phase_degradation(fullfile(result_dir, 'verify_coh_phase_vs_degradation_curves.png'), ...
    phase_offset_deg_list, sep_factor_list, degraded_rate_by_sep);
plot_sep10_phase_curve(fullfile(result_dir, 'verify_coh_sep10_phase_curve.png'), ...
    phase_offset_deg_list, squeeze(snr90_abs01(:, idx_sep10)));
plot_sep10_snr_grid(fullfile(result_dir, 'verify_coh_sep10_snr_grid.png'), ...
    phase_offset_deg_list, snr_list, squeeze(tol_success_rate(:, idx_sep10, :)));
plot_proto14_diff(fullfile(result_dir, 'verify_coh_proto14_diff.png'), ...
    sep_factor_list, snr_list, rmse_diff, tol_count_diff);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 4 diagnostic figures generated.');
log_msg(fid_log, 'Result directory: %s', result_dir);
log_msg(fid_log, '');
log_msg(fid_log, '4-layer acceptance summary');
log_msg(fid_log, 'Layer 1 geometry: PASS');
log_msg(fid_log, 'Layer 2 sanity all_pass=%d, max_err=[%s], trend_0_to_90=%d', ...
    layer2_all_pass, num2str(sanity_max_err_deg.', ' %.4f'), sanity_trend_ok);
log_msg(fid_log, 'Layer 3 regression: 3a=%d, 3b=%d, 3c=%d, 3d=%d, 3e=report, 3f=%d', ...
    layer3a_ok, layer3b_ok, layer3c_ok, layer3d_ok, layer3f_ok);
log_msg(fid_log, 'Layer 4 figures: PASS');

function s2 = build_s2_with_phase(s1, ~, ~, phase_deg)
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

function write_summary_csv(path_out, route_names, phase_offset_deg_list, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_rate, tol_success_rate, tol_success_rate_rel, rmse_deg, snr90_abs01, snr90_rel, mean_bias_deg, max_bias_deg, ...
    lambda2_over_noise, degraded_sample_count, mean_num_peaks)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['route_name,phase_offset_deg,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
        'raw_success_rate,tol_success_rate,tol_success_rate_rel,rmse_deg,snr90_db,snr90_rel_db,' ...
        'mean_bias_deg,max_bias_deg,lambda2_over_noise,degraded_sample_count,num_peaks_found\n']);
    for iPhase = 1:numel(phase_offset_deg_list)
        for iSep = 1:numel(sep_factor_list)
            for iSNR = 1:numel(snr_list)
                fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f\n', ...
                    route_names{iPhase}, phase_offset_deg_list(iPhase), sep_factor_list(iSep), theta_sep_deg(iSep), ...
                    theta_a_deg(iSep), theta_b_deg(iSep), snr_list(iSNR), raw_success_rate(iPhase, iSep, iSNR), ...
                    tol_success_rate(iPhase, iSep, iSNR), tol_success_rate_rel(iPhase, iSep, iSNR), rmse_deg(iPhase, iSep, iSNR), ...
                    snr90_abs01(iPhase, iSep), snr90_rel(iPhase, iSep), mean_bias_deg(iPhase, iSep, iSNR), ...
                    max_bias_deg(iPhase, iSep, iSNR), lambda2_over_noise(iPhase, iSep, iSNR), ...
                    degraded_sample_count(iPhase, iSep, iSNR), mean_num_peaks(iPhase, iSep, iSNR));
            end
        end
    end
end

function write_keypoints_csv(path_out, phase_offset_deg_list, sep_factor_list, snr90_abs01, snr90_rel, degraded_rate_by_sep, sanity_max_err_deg)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'phase_offset_deg,sep_factor,snr90_db,snr90_rel_db,degraded_rate,sanity_max_err_deg\n');
    for iPhase = 1:numel(phase_offset_deg_list)
        for iSep = 1:numel(sep_factor_list)
            fprintf(fid, '%d,%d,%.6f,%.6f,%.6f,%.6f\n', ...
                phase_offset_deg_list(iPhase), sep_factor_list(iSep), ...
                snr90_abs01(iPhase, iSep), snr90_rel(iPhase, iSep), ...
                degraded_rate_by_sep(iPhase, iSep), sanity_max_err_deg(iPhase));
        end
    end
end

function plot_phase_snr90_heatmap(path_out, phase_offset_deg_list, sep_factor_list, snr90_abs01)
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    imagesc(sep_factor_list, phase_offset_deg_list, snr90_abs01);
    colorbar
    xlabel('sep factor');
    ylabel('phase offset (deg)');
    title('SNR90 (abs01) vs sep factor and phase offset');
    set(gca, 'YDir', 'normal');
    for iPhase = 1:numel(phase_offset_deg_list)
        for iSep = 1:numel(sep_factor_list)
            val = snr90_abs01(iPhase, iSep);
            if isfinite(val)
                txt = sprintf('%.0f', val);
            else
                txt = 'NaN';
            end
            text(sep_factor_list(iSep), phase_offset_deg_list(iPhase), txt, ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_phase_degradation(path_out, phase_offset_deg_list, sep_factor_list, degraded_rate_by_sep)
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    for iPhase = 1:numel(phase_offset_deg_list)
        plot(sep_factor_list, degraded_rate_by_sep(iPhase, :) * 100, '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xlabel('sep factor');
    ylabel('degraded samples (%)');
    title('Degradation rate versus phase offset');
    legend(make_phase_labels(phase_offset_deg_list), 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_sep10_phase_curve(path_out, phase_offset_deg_list, sep10_snr90)
    fig = figure('Visible', 'off', 'Position', [100, 100, 820, 520]);
    plot(phase_offset_deg_list, sep10_snr90, '-o', 'LineWidth', 1.5);
    hold on
    yline(24, '--', '24 dB');
    yline(30, '--', '30 dB');
    hold off
    grid on
    xlabel('phase offset (deg)');
    ylabel('sep=10 SNR90 (dB)');
    title('sep=10 SNR90 versus source phase offset');
    saveas(fig, path_out);
    close(fig);
end

function plot_sep10_snr_grid(path_out, phase_offset_deg_list, snr_list, sep10_tol_rate)
    fig = figure('Visible', 'off', 'Position', [100, 100, 880, 520]);
    imagesc(snr_list, phase_offset_deg_list, sep10_tol_rate);
    set(gca, 'YDir', 'normal');
    colorbar
    caxis([0 1]);
    xlabel('SNR (dB)');
    ylabel('phase offset (deg)');
    title('sep=10 tol success rate');
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
    title('phase=0 RMSE diff versus proto14');
    subplot(1, 2, 2);
    imagesc(snr_list, sep_factor_list, tol_count_diff);
    colorbar
    xlabel('SNR (dB)');
    ylabel('sep factor');
    title('phase=0 tol-count diff versus proto14');
    saveas(fig, path_out);
    close(fig);
end

function labels = make_phase_labels(phase_offset_deg_list)
    labels = cell(1, numel(phase_offset_deg_list));
    for ii = 1:numel(phase_offset_deg_list)
        labels{ii} = sprintf('phase=%d deg', phase_offset_deg_list(ii));
    end
end

function log_msg(fid, varargin)
    msg = sprintf(varargin{:});
    fprintf('%s\n', msg);
    fprintf(fid, '%s\n', msg);
end
