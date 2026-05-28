clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
step75_dir = fullfile(steps_dir, 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');
step08_dir = fullfile(steps_dir, 'step_08_routeB_innovation');

addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
addpath(step75_dir);
addpath(step08_dir);

cfg = sim_cfg();

fourth_part_commit = '0a36280';
modify_doc_path = fullfile(script_dir, '第8.6步修改方向.md');
fourth_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_covfit.m');
fourth_result_dir = fullfile(script_dir, 'results_step8_6_level2_covfit');
fourth_summary_csv = fullfile(fourth_result_dir, 'step8_6_level2_covfit_summary.csv');
fourth_keypoints_csv = fullfile(fourth_result_dir, 'step8_6_level2_covfit_keypoints.csv');
fourth_mat_path = fullfile(fourth_result_dir, 'step8_6_level2_covfit_result.mat');
fourth_record_path = fullfile(script_dir, '第8.6步_层次二第四部分_一维圆柱协方差拟合验证记录.md');

assert(exist(fourth_script_path, 'file') == 2, 'Fourth-part script not found.');
assert(exist(fourth_summary_csv, 'file') == 2, 'Fourth-part summary CSV not found.');
assert(exist(fourth_keypoints_csv, 'file') == 2, 'Fourth-part keypoints CSV not found.');
assert(exist(fourth_mat_path, 'file') == 2, 'Fourth-part MAT result not found.');
assert(exist(fourth_record_path, 'file') == 2, 'Fourth-part record not found.');

result_dir = fullfile(script_dir, 'results_step8_6_level2_rank1_covfit_scan');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

record_doc_path = fullfile(script_dir, '第8.6步_层次二第五部分_rank1协方差拟合稳定性扫描记录.md');
log_path = fullfile(result_dir, 'step8_6_level2_rank1_covfit_scan.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

log_msg(fid_log, 'Step 08.6 level 2 part 5: rank1 equal-phase covfit stability and bias scan');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Fourth-part commit: %s', fourth_part_commit);
log_msg(fid_log, 'Modify direction doc: %s', modify_doc_path);
log_msg(fid_log, 'Fourth-part script: %s', fourth_script_path);
log_msg(fid_log, 'Fourth-part summary: %s', fourth_summary_csv);
log_msg(fid_log, 'Fourth-part keypoints: %s', fourth_keypoints_csv);
log_msg(fid_log, 'Fourth-part MAT: %s', fourth_mat_path);
log_msg(fid_log, 'Fourth-part record: %s', fourth_record_path);
log_msg(fid_log, 'Scope guard: level 2 rank1 covfit scan only. No fullscan, no level 3, no 2D az/el MUSIC, no Hermitian LS optimization, no phase-scan covfit.');

fourth_summary_tbl = readtable(fourth_summary_csv);
fourth_keypoints_tbl = readtable(fourth_keypoints_csv);
fourth_mat_info = whos('-file', fourth_mat_path);
fourth_record_text = fileread(fourth_record_path);
fourth_benchmark = summarize_fourth_part_benchmark_local(fourth_summary_tbl);
log_msg(fid_log, 'Fourth-part loaded benchmark at K=20, sep=10, SNR=30: rank1 tol_abs01=%.3f, center/min_den tol_abs01=%.3f', ...
    fourth_benchmark.rank1_tol_abs01, fourth_benchmark.baseline_tol_abs01);
log_msg(fid_log, 'Fourth-part keypoints rows=%d, MAT vars=%d, record chars=%d', ...
    height(fourth_keypoints_tbl), numel(fourth_mat_info), strlength(fourth_record_text));

azCtr_deg = 0;
el_a = 0;
el_b = 0;
el_assumed_deg = 0;
el_scan_deg = 0;
T_snap = 260;
Lc = 2;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
K_phi_list = [16, 20, 24, 28];
sep_factor_list = [7, 10];
snr_list = [18, 20, 22, 24, 26, 28, 30];
Metkl_requested = 100;
Metkl = 50;
Metkl_reason = 'Reduced from 100 to 50 because fourth-part 600-trial covfit took about 445 s; this scan is much larger.';
angle_step_music = 0.005;
angle_step_coarse = 0.02;
angle_step_refine = 0.005;
min_pair_sep_deg = 0.05;
max_pair_sep_deg = 0.80;
top_N = 5;
refine_half_width = 0.06;
phase_offset_list = [0, 5, 15, 30, 60];
phase_Metkl = 50;
base_seed = 20260628;

log_msg(fid_log, 'Metkl requested=%d, used=%d. Reason: %s', Metkl_requested, Metkl, Metkl_reason);

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s_base = exp(j * 2*pi * cfg.arr.fc * t);

arrInfo = arr_cyl(cfg, azCtr_deg);
Q = cfg.beam.subNaz;
col_select = 1:Q;
X3d = arrInfo.XAct(col_select, :);
Y3d = arrInfo.YAct(col_select, :);
Z3d = arrInfo.ZAct(col_select, :);
A_ref_2d = exp(-j * 2*pi / cfg.arr.lambda * ...
    (X3d * cosd(azCtr_deg) + Y3d * sind(azCtr_deg)));

d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
bw_eq_65 = 50.8 * 1.45 * cfg.arr.lambda / ((Q - 1) * d_eq);
angle_grid_music = (azCtr_deg - bw_eq_65):angle_step_music:(azCtr_deg + bw_eq_65);
angle_grid_coarse = (azCtr_deg - bw_eq_65):angle_step_coarse:(azCtr_deg + bw_eq_65);
work_span_deg = max(arrInfo.phiActRel(col_select)) - min(arrInfo.phiActRel(col_select));

log_msg(fid_log, '');
log_msg(fid_log, 'Geometry health check');
log_msg(fid_log, 'cfg.arr.Naz=%d, cfg.arr.Nel=%d, R=%.9f m, lambda=%.9f m', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.R, cfg.arr.lambda);
log_msg(fid_log, 'dPhi=%.9f deg, dz/lambda=%.9f, sectorHalf=%.9f deg, Q=%d', ...
    cfg.arr.dPhi, cfg.arr.dz / cfg.arr.lambda, cfg.beam.sectorHalf, Q);
log_msg(fid_log, 'working phi first/last/span=%.9f / %.9f / %.9f deg', ...
    arrInfo.phiActRel(1), arrInfo.phiActRel(Q), work_span_deg);
log_msg(fid_log, 'bw_eq_65=%.9f deg, music_step=%.6f deg, coarse_step=%.6f deg, refine_step=%.6f deg', ...
    bw_eq_65, angle_step_music, angle_step_coarse, angle_step_refine);
if Q ~= 65
    log_msg(fid_log, 'WARNING: Q=%d, expected 65.', Q);
end

route_names = {'center_real', 'min_den_fb', 'covfit_rank1_equal_phase'};
nroutes = numel(route_names);
idx_rank1 = 3;

log_msg(fid_log, '');
log_msg(fid_log, 'Routes');
for iroute = 1:nroutes
    log_msg(fid_log, '  %d: %s', iroute, route_names{iroute});
end

B_grid_music = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_music, el_scan_deg, el_assumed_deg);
B_grid_coarse = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_coarse, el_scan_deg, el_assumed_deg);

stage1 = init_stats_local(nroutes, numel(K_phi_list), numel(sep_factor_list), numel(snr_list));
theta_sep_deg = nan(numel(sep_factor_list), 1);
theta_a_deg = nan(numel(sep_factor_list), 1);
theta_b_deg = nan(numel(sep_factor_list), 1);
debug_samples = struct();
objective_valley_samples = struct([]);

log_msg(fid_log, '');
log_msg(fid_log, 'Stage 1: K/SNR small scan');
tic;
for iK = 1:numel(K_phi_list)
    K_phi = K_phi_list(iK);
    P_phi = Q - K_phi + 1;
    cache_music = make_subarray_steer_cache_local(B_grid_music, K_phi);
    candidate_pairs_coarse = make_pair_candidates_local(angle_grid_coarse, min_pair_sep_deg, max_pair_sep_deg);
    cache_coarse = make_subarray_steer_cache_local(B_grid_coarse, K_phi);
    precomp_coarse = precompute_rank1_pair_bases_local(cache_coarse, candidate_pairs_coarse);
    log_msg(fid_log, 'K_phi=%d, P_phi=%d, coarse_candidates=%d, subarray_span=%.6f deg', ...
        K_phi, P_phi, size(candidate_pairs_coarse, 1), (K_phi - 1) * cfg.arr.dPhi);

    for iSep = 1:numel(sep_factor_list)
        sep_factor = sep_factor_list(iSep);
        theta_sep = bw_eq_65 / sep_factor;
        target_theta = [azCtr_deg - theta_sep/2, azCtr_deg + theta_sep/2];
        theta_sep_deg(iSep) = theta_sep;
        theta_a_deg(iSep) = target_theta(1);
        theta_b_deg(iSep) = target_theta(2);
        tol_rel_now = tol_rel_ratio * theta_sep;
        true_pair_precomp = precompute_true_pair_rank1_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi);
        y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta(1), target_theta(2), el_a, el_b, s_base, s_base);

        for iSNR = 1:numel(snr_list)
            snr_db = snr_list(iSNR);
            noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);
            for metkl_num = 1:Metkl
                seed_now = base_seed + 100000*iK + 10000*iSep + 1000*iSNR + metkl_num;
                rng(seed_now, 'twister');
                noise = sqrt(noise_power/2) * (randn(size(y_clean_2d)) + 1j*randn(size(y_clean_2d)));
                y_2d = y_clean_2d + noise;
                y_combined = combine_layers_level2_local(y_2d, Z3d, cfg.arr.lambda, el_assumed_deg);
                [Rfb, En] = fbss_covariance_and_noise_subspace_local(y_combined, K_phi, Lc);
                doa_all = estimate_music_routes_local(cache_music, En, angle_grid_music, Lc);
                rank1_result = run_rank1_covfit_pair_search_local( ...
                    Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
                    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, el_scan_deg, el_assumed_deg, K_phi, ...
                    min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, true_pair_precomp);
                doa_all{idx_rank1} = rank1_result.doa_est;

                stage1 = update_route_metrics_local(stage1, doa_all, rank1_result, idx_rank1, target_theta, ...
                    theta_sep, azCtr_deg, tol_deg, tol_rel_now, iK, iSep, iSNR);

                if K_phi == 20 && sep_factor == 10 && snr_db == 30 && metkl_num <= 3
                    objective_valley_samples(end+1).stage = 'ksnr_scan'; %#ok<SAGROW>
                    objective_valley_samples(end).K_phi = K_phi;
                    objective_valley_samples(end).sep_factor = sep_factor;
                    objective_valley_samples(end).snr_db = snr_db;
                    objective_valley_samples(end).seed_now = seed_now;
                    objective_valley_samples(end).rank1_result = rank1_result;
                end
                if K_phi == 20 && sep_factor == 10 && snr_db == 30 && metkl_num == 1
                    debug_samples.stage1_key = rank1_result;
                    debug_samples.stage1_key.target_theta = target_theta;
                    debug_samples.stage1_key.seed_now = seed_now;
                    debug_samples.stage1_key.music_doa = doa_all(1:2);
                end
            end
        end
        log_msg(fid_log, '  sep=%d finished for K=%d, elapsed=%.1f s', sep_factor, K_phi, toc);
    end
end

stage1_metrics = finalize_stats_local(stage1, Metkl, route_names, K_phi_list, sep_factor_list, snr_list, theta_sep_deg, azCtr_deg);
stage1_metrics.snr90_abs01 = compute_snr90_local(stage1_metrics.tol_success_rate_abs01, snr_list);
stage1_metrics.snr90_rel025 = compute_snr90_local(stage1_metrics.tol_success_rate_rel025, snr_list);
best_K_info = choose_best_rank1_k_local(stage1_metrics, K_phi_list, sep_factor_list, snr_list, idx_rank1);
best_K_phi = best_K_info.best_K_phi;
log_msg(fid_log, 'Best K_phi for phase mismatch diagnosis: %d (%s)', best_K_phi, best_K_info.reason);

log_msg(fid_log, '');
log_msg(fid_log, 'Stage 2: phase/model mismatch diagnosis, K=%d, sep=10, SNR=30, Metkl=%d', best_K_phi, phase_Metkl);
phase_metrics = run_phase_mismatch_stage_local( ...
    fid_log, cfg, X3d, Y3d, Z3d, A_ref_2d, B_grid_music, B_grid_coarse, ...
    angle_grid_music, angle_grid_coarse, route_names, idx_rank1, best_K_phi, ...
    bw_eq_65, azCtr_deg, el_a, el_b, el_assumed_deg, el_scan_deg, ...
    s_base, phase_offset_list, phase_Metkl, 10, 30, min_pair_sep_deg, max_pair_sep_deg, ...
    top_N, refine_half_width, angle_step_refine, tol_deg, tol_rel_ratio, base_seed + 700000);

summary_rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, theta_sep_deg, ...
    Q, stage1_metrics, phase_metrics, best_K_phi);
summary_path = fullfile(result_dir, 'step8_6_level2_rank1_covfit_scan_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_6_level2_rank1_covfit_scan_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_6_level2_rank1_covfit_scan_result.mat');
write_summary_csv_local(summary_path, summary_rows);
keypoint_rows = filter_keypoint_rows_local(summary_rows);
write_summary_csv_local(keypoints_path, keypoint_rows);

diagnosis = choose_diagnosis_local(stage1_metrics, phase_metrics, route_names, K_phi_list, sep_factor_list, snr_list, idx_rank1, best_K_phi);

params = struct();
params.fourth_part_commit = fourth_part_commit;
params.modify_doc_path = modify_doc_path;
params.fourth_script_path = fourth_script_path;
params.fourth_summary_csv = fourth_summary_csv;
params.fourth_keypoints_csv = fourth_keypoints_csv;
params.fourth_mat_path = fourth_mat_path;
params.fourth_record_path = fourth_record_path;
params.fourth_benchmark = fourth_benchmark;
params.azCtr_deg = azCtr_deg;
params.el_a = el_a;
params.el_b = el_b;
params.el_assumed_deg = el_assumed_deg;
params.el_scan_deg = el_scan_deg;
params.T_snap = T_snap;
params.Lc = Lc;
params.tol_deg = tol_deg;
params.tol_rel_ratio = tol_rel_ratio;
params.Q = Q;
params.K_phi_list = K_phi_list;
params.sep_factor_list = sep_factor_list;
params.snr_list = snr_list;
params.Metkl_requested = Metkl_requested;
params.Metkl = Metkl;
params.Metkl_reason = Metkl_reason;
params.phase_Metkl = phase_Metkl;
params.phase_offset_list = phase_offset_list;
params.angle_step_music = angle_step_music;
params.angle_step_coarse = angle_step_coarse;
params.angle_step_refine = angle_step_refine;
params.min_pair_sep_deg = min_pair_sep_deg;
params.max_pair_sep_deg = max_pair_sep_deg;
params.top_N = top_N;
params.refine_half_width = refine_half_width;
params.base_seed = base_seed;
params.d_eq = d_eq;
params.bw_eq_65 = bw_eq_65;
params.best_K_phi_phase_stage = best_K_phi;

save(mat_path, 'params', 'route_names', 'K_phi_list', 'sep_factor_list', 'snr_list', ...
    'phase_offset_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'stage1', 'stage1_metrics', 'phase_metrics', 'best_K_info', ...
    'debug_samples', 'objective_valley_samples', 'diagnosis');

plot_snr90_vs_kphi_local(fullfile(result_dir, 'rank1_covfit_snr90_vs_kphi.png'), ...
    route_names, K_phi_list, sep_factor_list, stage1_metrics.snr90_abs01, stage1_metrics.snr90_rel025);
plot_tol_vs_snr_sep10_local(fullfile(result_dir, 'rank1_covfit_tol_vs_snr_sep10.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, stage1_metrics.tol_success_rate_abs01);
plot_sep_bias_vs_snr_local(fullfile(result_dir, 'rank1_covfit_sep_bias_vs_snr.png'), ...
    K_phi_list, sep_factor_list, snr_list, stage1_metrics.mean_pair_sep_bias, stage1_metrics.mean_abs_pair_sep_error, idx_rank1);
plot_objective_valley_width_local(fullfile(result_dir, 'rank1_covfit_objective_valley_width.png'), ...
    K_phi_list, sep_factor_list, snr_list, stage1_metrics.objective_valley_sep_width_mean, ...
    stage1_metrics.objective_valley_center_width_mean, idx_rank1);
plot_phase_offset_sensitivity_local(fullfile(result_dir, 'rank1_covfit_phase_offset_sensitivity.png'), ...
    route_names, phase_offset_list, phase_metrics.tol_success_rate_abs01, phase_metrics.rmse_deg, best_K_phi);

write_record_doc_local(record_doc_path, params, route_names, stage1_metrics, phase_metrics, diagnosis, ...
    best_K_info, summary_path, keypoints_path, mat_path);

log_msg(fid_log, '');
log_msg(fid_log, 'Diagnostic conclusion: %s', diagnosis.conclusion);
log_msg(fid_log, 'Next step: %s', diagnosis.next_step);
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', keypoints_path);
log_msg(fid_log, '  %s', mat_path);
log_msg(fid_log, '  %s', fullfile(result_dir, 'rank1_covfit_snr90_vs_kphi.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'rank1_covfit_tol_vs_snr_sep10.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'rank1_covfit_sep_bias_vs_snr.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'rank1_covfit_objective_valley_width.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'rank1_covfit_phase_offset_sensitivity.png'));
log_msg(fid_log, '  %s', record_doc_path);
safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 rank1 covfit scan finished.');
disp('result_dir =');
disp(result_dir);
disp('diagnosis =');
disp(diagnosis.conclusion);

function fourth_benchmark = summarize_fourth_part_benchmark_local(fourth_summary_tbl)
    mask_key = fourth_summary_tbl.K_phi == 20 & fourth_summary_tbl.sep_factor == 10 & fourth_summary_tbl.snr_db == 30;
    route_col = string(fourth_summary_tbl.route_name);
    fourth_benchmark = struct();
    fourth_benchmark.K_phi = 20;
    fourth_benchmark.sep_factor = 10;
    fourth_benchmark.snr_db = 30;
    fourth_benchmark.rank1_tol_abs01 = NaN;
    fourth_benchmark.baseline_tol_abs01 = NaN;
    idx_rank1 = mask_key & route_col == "covfit_rank1_equal_phase";
    idx_center = mask_key & route_col == "center_real";
    idx_min = mask_key & route_col == "min_den_fb";
    if any(idx_rank1)
        fourth_benchmark.rank1_tol_abs01 = fourth_summary_tbl.tol_success_rate_abs01(idx_rank1);
    end
    if any(idx_center) && any(idx_min)
        fourth_benchmark.baseline_tol_abs01 = max( ...
            fourth_summary_tbl.tol_success_rate_abs01(idx_center), ...
            fourth_summary_tbl.tol_success_rate_abs01(idx_min));
    end
end

function stats = init_stats_local(nroutes, nK, nsep, nsnr)
    dims = [nroutes, nK, nsep, nsnr];
    stats.raw_success_count = zeros(dims);
    stats.tol_success_count_abs01 = zeros(dims);
    stats.tol_success_count_rel025 = zeros(dims);
    stats.rmse_sum_sqerr = zeros(dims);
    stats.rmse_valid_count = zeros(dims);
    stats.degraded_count = zeros(dims);
    stats.pair_count = zeros(dims);
    stats.pair_sep_sum = zeros(dims);
    stats.pair_sep_sq_sum = zeros(dims);
    stats.pair_sep_bias_sum = zeros(dims);
    stats.pair_sep_abs_error_sum = zeros(dims);
    stats.pair_center_sum = zeros(dims);
    stats.pair_center_sq_sum = zeros(dims);
    stats.pair_center_bias_sum = zeros(dims);
    stats.pair_center_abs_error_sum = zeros(dims);
    stats.objective_true_rank_values = cell(dims);
    stats.objective_margin_sum = nan(dims);
    stats.valley_sep_width_sum = nan(dims);
    stats.valley_center_width_sum = nan(dims);
    stats.objective_margin_sum(3, :, :, :) = 0;
    stats.valley_sep_width_sum(3, :, :, :) = 0;
    stats.valley_center_width_sum(3, :, :, :) = 0;
end

function stats = update_route_metrics_local(stats, doa_all, rank1_result, idx_rank1, target_theta, theta_sep, true_center, tol_deg, tol_rel_now, iK, iSep, iSNR)
    nroutes = numel(doa_all);
    for iroute = 1:nroutes
        doa_now = doa_all{iroute};
        raw_ok = all(isfinite(doa_now)) && numel(doa_now) == 2;
        tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
        tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_rel_now);
        degraded = true;
        if raw_ok
            stats.raw_success_count(iroute, iK, iSep, iSNR) = stats.raw_success_count(iroute, iK, iSep, iSNR) + 1;
            doa_sorted = sort(doa_now(:).');
            err = doa_sorted - sort(target_theta(:).');
            stats.rmse_sum_sqerr(iroute, iK, iSep, iSNR) = stats.rmse_sum_sqerr(iroute, iK, iSep, iSNR) + sum(err.^2);
            stats.rmse_valid_count(iroute, iK, iSep, iSNR) = stats.rmse_valid_count(iroute, iK, iSep, iSNR) + 1;
            degraded = max(abs(err)) > 1.0;
            pair_sep = doa_sorted(2) - doa_sorted(1);
            pair_center = mean(doa_sorted);
            sep_bias = pair_sep - theta_sep;
            center_bias = pair_center - true_center;
            stats.pair_count(iroute, iK, iSep, iSNR) = stats.pair_count(iroute, iK, iSep, iSNR) + 1;
            stats.pair_sep_sum(iroute, iK, iSep, iSNR) = stats.pair_sep_sum(iroute, iK, iSep, iSNR) + pair_sep;
            stats.pair_sep_sq_sum(iroute, iK, iSep, iSNR) = stats.pair_sep_sq_sum(iroute, iK, iSep, iSNR) + pair_sep.^2;
            stats.pair_sep_bias_sum(iroute, iK, iSep, iSNR) = stats.pair_sep_bias_sum(iroute, iK, iSep, iSNR) + sep_bias;
            stats.pair_sep_abs_error_sum(iroute, iK, iSep, iSNR) = stats.pair_sep_abs_error_sum(iroute, iK, iSep, iSNR) + abs(sep_bias);
            stats.pair_center_sum(iroute, iK, iSep, iSNR) = stats.pair_center_sum(iroute, iK, iSep, iSNR) + pair_center;
            stats.pair_center_sq_sum(iroute, iK, iSep, iSNR) = stats.pair_center_sq_sum(iroute, iK, iSep, iSNR) + pair_center.^2;
            stats.pair_center_bias_sum(iroute, iK, iSep, iSNR) = stats.pair_center_bias_sum(iroute, iK, iSep, iSNR) + center_bias;
            stats.pair_center_abs_error_sum(iroute, iK, iSep, iSNR) = stats.pair_center_abs_error_sum(iroute, iK, iSep, iSNR) + abs(center_bias);
        end
        if tol_ok_abs
            stats.tol_success_count_abs01(iroute, iK, iSep, iSNR) = stats.tol_success_count_abs01(iroute, iK, iSep, iSNR) + 1;
        end
        if tol_ok_rel
            stats.tol_success_count_rel025(iroute, iK, iSep, iSNR) = stats.tol_success_count_rel025(iroute, iK, iSep, iSNR) + 1;
        end
        if degraded
            stats.degraded_count(iroute, iK, iSep, iSNR) = stats.degraded_count(iroute, iK, iSep, iSNR) + 1;
        end
    end
    stats.objective_true_rank_values{idx_rank1, iK, iSep, iSNR}(end+1) = rank1_result.true_rank;
    stats.objective_margin_sum(idx_rank1, iK, iSep, iSNR) = stats.objective_margin_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.objective_margin_true_vs_best;
    stats.valley_sep_width_sum(idx_rank1, iK, iSep, iSNR) = stats.valley_sep_width_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.valley_sep_width;
    stats.valley_center_width_sum(idx_rank1, iK, iSep, iSNR) = stats.valley_center_width_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.valley_center_width;
end

function metrics = finalize_stats_local(stats, Metkl, route_names, K_phi_list, sep_factor_list, snr_list, theta_sep_deg, true_center)
    metrics = struct();
    metrics.route_names = route_names;
    metrics.K_phi_list = K_phi_list;
    metrics.sep_factor_list = sep_factor_list;
    metrics.snr_list = snr_list;
    metrics.theta_sep_deg = theta_sep_deg;
    metrics.raw_success_rate = stats.raw_success_count / Metkl;
    metrics.tol_success_rate_abs01 = stats.tol_success_count_abs01 / Metkl;
    metrics.tol_success_rate_rel025 = stats.tol_success_count_rel025 / Metkl;
    metrics.rmse_deg = sqrt(stats.rmse_sum_sqerr ./ max(stats.rmse_valid_count, 1) / 2);
    metrics.rmse_deg(stats.rmse_valid_count == 0) = NaN;
    metrics.degraded_rate = stats.degraded_count / Metkl;
    cnt = max(stats.pair_count, 1);
    metrics.mean_pair_sep_est = stats.pair_sep_sum ./ cnt;
    metrics.std_pair_sep_est = sqrt(max(stats.pair_sep_sq_sum ./ cnt - metrics.mean_pair_sep_est.^2, 0));
    metrics.mean_pair_sep_bias = stats.pair_sep_bias_sum ./ cnt;
    metrics.mean_abs_pair_sep_error = stats.pair_sep_abs_error_sum ./ cnt;
    metrics.mean_pair_center_est = stats.pair_center_sum ./ cnt;
    metrics.std_pair_center_est = sqrt(max(stats.pair_center_sq_sum ./ cnt - metrics.mean_pair_center_est.^2, 0));
    metrics.mean_pair_center_bias = stats.pair_center_bias_sum ./ cnt;
    metrics.mean_abs_pair_center_error = stats.pair_center_abs_error_sum ./ cnt;
    metrics.mean_pair_sep_est(stats.pair_count == 0) = NaN;
    metrics.std_pair_sep_est(stats.pair_count == 0) = NaN;
    metrics.mean_pair_sep_bias(stats.pair_count == 0) = NaN;
    metrics.mean_abs_pair_sep_error(stats.pair_count == 0) = NaN;
    metrics.mean_pair_center_est(stats.pair_count == 0) = NaN;
    metrics.std_pair_center_est(stats.pair_count == 0) = NaN;
    metrics.mean_pair_center_bias(stats.pair_count == 0) = NaN;
    metrics.mean_abs_pair_center_error(stats.pair_count == 0) = NaN;
    metrics.objective_margin_true_vs_best = stats.objective_margin_sum / Metkl;
    metrics.objective_valley_sep_width_mean = stats.valley_sep_width_sum / Metkl;
    metrics.objective_valley_center_width_mean = stats.valley_center_width_sum / Metkl;
    metrics.objective_true_rank_median = nan(size(stats.raw_success_count));
    metrics.objective_true_rank_p90 = nan(size(stats.raw_success_count));
    for iroute = 1:numel(route_names)
        for iK = 1:numel(K_phi_list)
            for iSep = 1:numel(sep_factor_list)
                for iSNR = 1:numel(snr_list)
                    vals = stats.objective_true_rank_values{iroute, iK, iSep, iSNR};
                    if ~isempty(vals)
                        metrics.objective_true_rank_median(iroute, iK, iSep, iSNR) = median(vals, 'omitnan');
                        metrics.objective_true_rank_p90(iroute, iK, iSep, iSNR) = prctile(vals, 90);
                    end
                end
            end
        end
    end
    metrics.true_center = true_center;
end

function snr90 = compute_snr90_local(tol_rate, snr_list)
    [nroutes, nK, nsep, ~] = size(tol_rate);
    snr90 = nan(nroutes, nK, nsep);
    for iroute = 1:nroutes
        for iK = 1:nK
            for iSep = 1:nsep
                vals = squeeze(tol_rate(iroute, iK, iSep, :));
                idx = find(vals >= 0.9, 1, 'first');
                if ~isempty(idx)
                    snr90(iroute, iK, iSep) = snr_list(idx);
                end
            end
        end
    end
end

function best_K_info = choose_best_rank1_k_local(metrics, K_phi_list, sep_factor_list, snr_list, idx_rank1)
    idxSep10 = find(sep_factor_list == 10, 1);
    idxSNR30 = find(snr_list == 30, 1);
    snr90 = squeeze(metrics.snr90_abs01(idx_rank1, :, idxSep10));
    mean_tol = squeeze(mean(metrics.tol_success_rate_abs01(idx_rank1, :, idxSep10, :), 4));
    sep_err_30 = squeeze(metrics.mean_abs_pair_sep_error(idx_rank1, :, idxSep10, idxSNR30));
    finite_idx = find(isfinite(snr90));
    if ~isempty(finite_idx)
        best_snr90 = min(snr90(finite_idx));
        candidate = finite_idx(snr90(finite_idx) == best_snr90);
        [~, rel] = max(mean_tol(candidate));
        best_idx = candidate(rel);
        tie = candidate(mean_tol(candidate) == mean_tol(best_idx));
        if numel(tie) > 1
            [~, rel2] = min(sep_err_30(tie));
            best_idx = tie(rel2);
        end
        reason = sprintf('lowest finite sep=10 rank1 SNR90_abs01=%.1f dB, tie-broken by mean tol and sep error', snr90(best_idx));
    else
        [~, best_idx] = max(mean_tol);
        reason = 'no finite sep=10 rank1 SNR90_abs01; chose highest mean tol over SNR';
    end
    best_K_info = struct();
    best_K_info.best_K_phi = K_phi_list(best_idx);
    best_K_info.best_K_index = best_idx;
    best_K_info.reason = reason;
    best_K_info.sep10_snr90_abs01 = snr90;
    best_K_info.sep10_mean_tol = mean_tol;
    best_K_info.sep10_abs_sep_error_snr30 = sep_err_30;
end

function phase_metrics = run_phase_mismatch_stage_local( ...
    fid_log, cfg, X3d, Y3d, Z3d, A_ref_2d, B_grid_music, B_grid_coarse, ...
    angle_grid_music, angle_grid_coarse, route_names, idx_rank1, K_phi, ...
    bw_eq_65, azCtr_deg, el_a, el_b, el_assumed_deg, el_scan_deg, ...
    s_base, phase_offset_list, Metkl, sep_factor, snr_db, min_pair_sep_deg, max_pair_sep_deg, ...
    top_N, refine_half_width, angle_step_refine, tol_deg, tol_rel_ratio, base_seed)

    nroutes = numel(route_names);
    stats = init_stats_local(nroutes, 1, 1, numel(phase_offset_list));
    cache_music = make_subarray_steer_cache_local(B_grid_music, K_phi);
    candidate_pairs_coarse = make_pair_candidates_local(angle_grid_coarse, min_pair_sep_deg, max_pair_sep_deg);
    cache_coarse = make_subarray_steer_cache_local(B_grid_coarse, K_phi);
    precomp_coarse = precompute_rank1_pair_bases_local(cache_coarse, candidate_pairs_coarse);
    theta_sep = bw_eq_65 / sep_factor;
    target_theta = [azCtr_deg - theta_sep/2, azCtr_deg + theta_sep/2];
    tol_rel_now = tol_rel_ratio * theta_sep;
    true_pair_precomp = precompute_true_pair_rank1_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi);

    for iPhase = 1:numel(phase_offset_list)
        phase_offset = phase_offset_list(iPhase);
        s2 = s_base * exp(1j * deg2rad(phase_offset));
        y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta(1), target_theta(2), el_a, el_b, s_base, s2);
        noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);
        for metkl_num = 1:Metkl
            seed_now = base_seed + 10000*iPhase + metkl_num;
            rng(seed_now, 'twister');
            noise = sqrt(noise_power/2) * (randn(size(y_clean_2d)) + 1j*randn(size(y_clean_2d)));
            y_2d = y_clean_2d + noise;
            y_combined = combine_layers_level2_local(y_2d, Z3d, cfg.arr.lambda, el_assumed_deg);
            [Rfb, En] = fbss_covariance_and_noise_subspace_local(y_combined, K_phi, 2);
            doa_all = estimate_music_routes_local(cache_music, En, angle_grid_music, 2);
            rank1_result = run_rank1_covfit_pair_search_local( ...
                Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
                X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, el_scan_deg, el_assumed_deg, K_phi, ...
                min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, true_pair_precomp);
            doa_all{idx_rank1} = rank1_result.doa_est;
            stats = update_route_metrics_local(stats, doa_all, rank1_result, idx_rank1, target_theta, ...
                theta_sep, azCtr_deg, tol_deg, tol_rel_now, 1, 1, iPhase);
        end
        log_msg(fid_log, '  phase offset %.1f deg finished', phase_offset);
    end
    phase_metrics = finalize_stats_local(stats, Metkl, route_names, K_phi, sep_factor, phase_offset_list, theta_sep, azCtr_deg);
    phase_metrics.stage_snr_db = snr_db;
    phase_metrics.phase_offset_list = phase_offset_list;
    phase_metrics.K_phi = K_phi;
    phase_metrics.sep_factor = sep_factor;
    phase_metrics.theta_sep_deg = theta_sep;
end

function y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, theta_b, el_a, el_b, s1, s2)
    unit_a = [cosd(el_a) * cosd(theta_a), cosd(el_a) * sind(theta_a), sind(el_a)];
    unit_b = [cosd(el_b) * cosd(theta_b), cosd(el_b) * sind(theta_b), sind(el_b)];
    phase_a = X3d * unit_a(1) + Y3d * unit_a(2) + Z3d * unit_a(3);
    phase_b = X3d * unit_b(1) + Y3d * unit_b(2) + Z3d * unit_b(3);
    A_a_norm = conj(A_ref_2d) .* exp(-1j * 2*pi / lambda * phase_a);
    A_b_norm = conj(A_ref_2d) .* exp(-1j * 2*pi / lambda * phase_b);
    y_clean_2d = reshape(A_a_norm(:) * s1 + A_b_norm(:) * s2, ...
        size(X3d, 1), size(X3d, 2), numel(s1));
end

function y_combined = combine_layers_level2_local(y_2d, Z3d, lambda, el_assumed_deg)
    Nel = size(y_2d, 2);
    z_col = Z3d(1, :).';
    steer_el = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    W = steer_el' / sqrt(Nel);
    tmp = W * reshape(permute(y_2d, [2, 1, 3]), Nel, []);
    y_combined = reshape(tmp, size(y_2d, 1), size(y_2d, 3));
end

function b = build_level2_combined_az_steer_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg, el_assumed_deg)
    Nel = size(X3d, 2);
    k = 2*pi / lambda;
    phase = X3d * (cosd(el_scan_deg) * cosd(az_deg)) + ...
        Y3d * (cosd(el_scan_deg) * sind(az_deg)) + ...
        Z3d * sind(el_scan_deg);
    a_norm = conj(A_ref_2d) .* exp(-1j * k * phase);
    z_col = Z3d(1, :).';
    a_z = exp(-1j * k * z_col * sind(el_assumed_deg));
    w_z = a_z / sqrt(Nel);
    b = (w_z' * a_norm.').';
    nb = norm(b);
    if nb > 0
        b = b / nb;
    end
end

function B_grid = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid, el_scan_deg, el_assumed_deg)
    Q = size(X3d, 1);
    B_grid = zeros(Q, numel(angle_grid));
    for ia = 1:numel(angle_grid)
        B_grid(:, ia) = build_level2_combined_az_steer_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid(ia), el_scan_deg, el_assumed_deg);
    end
end

function cache = make_subarray_steer_cache_local(B_grid, K_phi)
    Q = size(B_grid, 1);
    ngrid = size(B_grid, 2);
    P_phi = Q - K_phi + 1;
    J = fliplr(eye(K_phi));
    A_forward = complex(zeros(K_phi, ngrid, P_phi));
    A_backward = complex(zeros(K_phi, ngrid, P_phi));
    for p = 1:P_phi
        A = normalize_columns_local(B_grid(p:p+K_phi-1, :));
        A_forward(:, :, p) = A;
        A_backward(:, :, p) = J * conj(A);
    end
    cache = struct();
    cache.K_phi = K_phi;
    cache.P_phi = P_phi;
    cache.J = J;
    cache.A_forward = A_forward;
    cache.A_backward = A_backward;
end

function A = normalize_columns_local(A)
    nrm = sqrt(sum(abs(A).^2, 1));
    nrm(nrm == 0) = 1;
    A = A ./ nrm;
end

function [Rfb, En] = fbss_covariance_and_noise_subspace_local(y_combined, K_phi, Lc)
    T_snap = size(y_combined, 2);
    Rxx = y_combined * y_combined' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');
    Rfb = mssp_array_fb(Rxx, K_phi);
    Rfb = 0.5 * (Rfb + Rfb');
    [V, D] = eig(Rfb);
    eigvals = real(diag(D));
    [~, idx] = sort(eigvals, 'descend');
    V = V(:, idx);
    En = V(:, Lc+1:end);
end

function doa_all = estimate_music_routes_local(cache, En, angle_grid, Lc)
    [D_forward, D_backward] = compute_subarray_denominators_local(cache, En);
    P_phi = cache.P_phi;
    p_mid = round((P_phi + 1) / 2);
    P_center = inv_den_local(D_forward(p_mid, :));
    D_fb = 0.5 * (D_forward + D_backward);
    P_min_fb = inv_den_local(min(D_fb, [], 1));
    doa_all = cell(3, 1);
    doa_all{1} = estimate_from_spectrum_local(P_center, angle_grid, Lc);
    doa_all{2} = estimate_from_spectrum_local(P_min_fb, angle_grid, Lc);
    doa_all{3} = nan(1, Lc);
end

function [D_forward, D_backward] = compute_subarray_denominators_local(cache, En)
    Cn = En * En';
    P_phi = cache.P_phi;
    ngrid = size(cache.A_forward, 2);
    D_forward = zeros(P_phi, ngrid);
    D_backward = zeros(P_phi, ngrid);
    for p = 1:P_phi
        A = cache.A_forward(:, :, p);
        D_forward(p, :) = real(sum(conj(A) .* (Cn * A), 1));
        Ab = cache.A_backward(:, :, p);
        D_backward(p, :) = real(sum(conj(Ab) .* (Cn * Ab), 1));
    end
end

function y = inv_den_local(x)
    y = 1 ./ max(real(x), eps);
end

function doa_est = estimate_from_spectrum_local(Pmu, angle_grid, Lc)
    [~, peak_inds] = FindLocalPeak_NoEdge_Fun(Pmu);
    if numel(peak_inds) < Lc
        doa_est = nan(1, Lc);
    else
        doa_est = sort(angle_grid(peak_inds(1:Lc)));
    end
end

function candidate_pairs = make_pair_candidates_local(angle_grid, min_sep, max_sep)
    n = numel(angle_grid);
    candidate_pairs = zeros(n*n, 2);
    count = 0;
    for ii = 1:(n-1)
        sep_vec = angle_grid((ii+1):end) - angle_grid(ii);
        jj_rel = find(sep_vec >= min_sep & sep_vec <= max_sep);
        if isempty(jj_rel)
            continue
        end
        jj = jj_rel + ii;
        nadd = numel(jj);
        candidate_pairs(count+1:count+nadd, :) = [repmat(ii, nadd, 1), jj(:)];
        count = count + nadd;
    end
    candidate_pairs = candidate_pairs(1:count, :);
end

function precomp = precompute_rank1_pair_bases_local(cache, candidate_pairs)
    K = cache.K_phi;
    P_phi = cache.P_phi;
    J = cache.J;
    Nc = size(candidate_pairs, 1);
    L = 2 * K * K;
    g_basis = zeros(L, Nc, 'single');
    gg = zeros(Nc, 1);
    gi = zeros(Nc, 1);
    ivec = matrix_to_realvec_local(eye(K));
    ii = real(ivec' * ivec);
    for ic = 1:Nc
        i1 = candidate_pairs(ic, 1);
        i2 = candidate_pairs(ic, 2);
        A1 = reshape(cache.A_forward(:, i1, :), K, P_phi);
        A2 = reshape(cache.A_forward(:, i2, :), K, P_phi);
        C = A1 + A2;
        F = (C * C') / P_phi;
        G = fb_project_local(F, J);
        v = matrix_to_realvec_local(G);
        g_basis(:, ic) = single(v);
        gg(ic) = real(v' * v);
        gi(ic) = real(v' * ivec);
    end
    precomp = struct();
    precomp.K_phi = K;
    precomp.P_phi = P_phi;
    precomp.candidate_pairs = candidate_pairs;
    precomp.g_basis = g_basis;
    precomp.gg = gg;
    precomp.gi = gi;
    precomp.ivec = single(ivec);
    precomp.ii = ii;
end

function G = fb_project_local(F, J)
    G = 0.5 * (F + J * conj(F) * J);
end

function v = matrix_to_realvec_local(M)
    m = M(:);
    v = [real(m); imag(m)];
end

function true_precomp = precompute_true_pair_rank1_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi)
    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg);
    cache = make_subarray_steer_cache_local(B_grid, K_phi);
    true_precomp = precompute_rank1_pair_bases_local(cache, [1, 2]);
end

function rank1_result = run_rank1_covfit_pair_search_local( ...
    Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, el_scan_deg, el_assumed_deg, K_phi, ...
    min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, true_pair_precomp)

    coarse_scores = score_rank1_all_local(Rfb, precomp_coarse);
    top_idx = top_indices_local(coarse_scores, top_N);
    top_pairs_theta = [angle_grid_coarse(candidate_pairs_coarse(top_idx, 1)).', ...
        angle_grid_coarse(candidate_pairs_coarse(top_idx, 2)).'];
    refine_pairs_theta = make_refine_pairs_local(top_pairs_theta, refine_half_width, angle_step_refine, ...
        min_pair_sep_deg, max_pair_sep_deg);
    if isempty(refine_pairs_theta)
        refine_pairs_theta = top_pairs_theta;
    end
    [angle_grid_refine, candidate_pairs_refine] = theta_pairs_to_grid_indices_local(refine_pairs_theta);
    B_grid_refine = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid_refine, el_scan_deg, el_assumed_deg);
    cache_refine = make_subarray_steer_cache_local(B_grid_refine, K_phi);
    precomp_refine = precompute_rank1_pair_bases_local(cache_refine, candidate_pairs_refine);
    refine_scores = score_rank1_all_local(Rfb, precomp_refine);
    true_score = score_rank1_all_local(Rfb, true_pair_precomp);
    [best_score, best_idx] = min(refine_scores);
    [best_coarse_score, best_coarse_idx] = min(coarse_scores);
    doa_est = sort(angle_grid_refine(candidate_pairs_refine(best_idx, :)));
    coarse_pair = sort(angle_grid_coarse(candidate_pairs_coarse(best_coarse_idx, :)));
    true_rank = 1 + sum(coarse_scores < true_score(1));
    centers = mean(angle_grid_refine(candidate_pairs_refine), 2);
    seps = diff(angle_grid_refine(candidate_pairs_refine), 1, 2);
    valley_mask = refine_scores <= best_score * 1.05;
    if any(valley_mask)
        valley_sep_width = max(seps(valley_mask)) - min(seps(valley_mask));
        valley_center_width = max(centers(valley_mask)) - min(centers(valley_mask));
    else
        valley_sep_width = NaN;
        valley_center_width = NaN;
    end
    rank1_result = struct();
    rank1_result.doa_est = doa_est;
    rank1_result.objective_best = best_score;
    rank1_result.objective_true = true_score(1);
    rank1_result.objective_margin_true_vs_best = true_score(1) - best_score;
    rank1_result.true_rank = true_rank;
    rank1_result.coarse_pair = coarse_pair;
    rank1_result.coarse_objective_best = best_coarse_score;
    rank1_result.valley_sep_width = valley_sep_width;
    rank1_result.valley_center_width = valley_center_width;
    rank1_result.refine_pair_count = size(candidate_pairs_refine, 1);
    rank1_result.valley_pair_count = sum(valley_mask);
end

function score = score_rank1_all_local(Robs, precomp)
    y = matrix_to_realvec_local(Robs);
    yy = real(y' * y);
    gy = double(precomp.g_basis' * single(y));
    iy = double(precomp.ivec' * single(y));
    gg = precomp.gg;
    gi = precomp.gi;
    ii = precomp.ii;
    detv = gg * ii - gi.^2;
    valid = abs(detv) > 1e-12;
    alpha = zeros(size(gg));
    sigma2 = zeros(size(gg));
    alpha(valid) = (gy(valid) * ii - gi(valid) * iy) ./ detv(valid);
    sigma2(valid) = (gg(valid) * iy - gi(valid) .* gy(valid)) ./ detv(valid);
    val_both = inf(size(gg));
    ok_both = valid & alpha >= 0 & sigma2 >= 0;
    val_both(ok_both) = -2*(alpha(ok_both).*gy(ok_both) + sigma2(ok_both)*iy) + ...
        alpha(ok_both).^2 .* gg(ok_both) + 2*alpha(ok_both).*sigma2(ok_both).*gi(ok_both) + sigma2(ok_both).^2 * ii;
    alpha_only = max(gy ./ max(gg, eps), 0);
    val_alpha = -2*alpha_only.*gy + alpha_only.^2 .* gg;
    sigma_only = max(iy / max(ii, eps), 0);
    val_sigma = -2*sigma_only*iy + sigma_only.^2 * ii;
    val_zero = zeros(size(gg));
    best_delta = min([val_both, val_alpha, repmat(val_sigma, size(gg)), val_zero], [], 2);
    score = max(yy + best_delta, 0) / max(yy, eps);
end

function idx = top_indices_local(score, top_N)
    [~, ord] = sort(score, 'ascend');
    idx = ord(1:min(top_N, numel(ord)));
end

function pairs = make_refine_pairs_local(top_pairs_theta, half_width, step, min_sep, max_sep)
    pairs = zeros(0, 2);
    for ii = 1:size(top_pairs_theta, 1)
        g1 = (top_pairs_theta(ii, 1)-half_width):step:(top_pairs_theta(ii, 1)+half_width);
        g2 = (top_pairs_theta(ii, 2)-half_width):step:(top_pairs_theta(ii, 2)+half_width);
        [T1, T2] = ndgrid(g1, g2);
        sep = T2 - T1;
        mask = sep >= min_sep & sep <= max_sep;
        pairs = [pairs; T1(mask), T2(mask)]; %#ok<AGROW>
    end
    if isempty(pairs)
        return
    end
    pairs = round(pairs / step) * step;
    pairs = unique(pairs, 'rows');
end

function [angle_grid, candidate_pairs] = theta_pairs_to_grid_indices_local(pairs_theta)
    angle_grid = unique(pairs_theta(:)).';
    candidate_pairs = zeros(size(pairs_theta));
    for ii = 1:size(pairs_theta, 1)
        [~, candidate_pairs(ii, 1)] = min(abs(angle_grid - pairs_theta(ii, 1)));
        [~, candidate_pairs(ii, 2)] = min(abs(angle_grid - pairs_theta(ii, 2)));
    end
end

function summary_rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, theta_sep_deg, Q, stage1_metrics, phase_metrics, best_K_phi)
    summary_rows = {};
    for iroute = 1:numel(route_names)
        for iK = 1:numel(K_phi_list)
            K_phi = K_phi_list(iK);
            P_phi = Q - K_phi + 1;
            for iSep = 1:numel(sep_factor_list)
                for iSNR = 1:numel(snr_list)
                    summary_rows(end+1, :) = make_row_local('ksnr_scan', route_names{iroute}, K_phi, P_phi, ...
                        sep_factor_list(iSep), theta_sep_deg(iSep), snr_list(iSNR), 0, ...
                        stage1_metrics, iroute, iK, iSep, iSNR, ...
                        stage1_metrics.snr90_abs01(iroute, iK, iSep), stage1_metrics.snr90_rel025(iroute, iK, iSep)); %#ok<AGROW>
                end
            end
        end
    end
    P_phi = Q - best_K_phi + 1;
    for iroute = 1:numel(route_names)
        for iPhase = 1:numel(phase_metrics.phase_offset_list)
            summary_rows(end+1, :) = make_row_local('phase_mismatch', route_names{iroute}, best_K_phi, P_phi, ...
                phase_metrics.sep_factor, phase_metrics.theta_sep_deg, phase_metrics.stage_snr_db, ...
                phase_metrics.phase_offset_list(iPhase), phase_metrics, iroute, 1, 1, iPhase, NaN, NaN); %#ok<AGROW>
        end
    end
end

function row = make_row_local(stage, route_name, K_phi, P_phi, sep_factor, theta_sep_deg, snr_db, phase_offset_deg, metrics, iroute, iK, iSep, iSNR, snr90_abs01, snr90_rel025)
    row = {stage, route_name, K_phi, P_phi, sep_factor, theta_sep_deg, snr_db, phase_offset_deg, ...
        metrics.raw_success_rate(iroute, iK, iSep, iSNR), ...
        metrics.tol_success_rate_abs01(iroute, iK, iSep, iSNR), ...
        metrics.tol_success_rate_rel025(iroute, iK, iSep, iSNR), ...
        metrics.rmse_deg(iroute, iK, iSep, iSNR), ...
        metrics.degraded_rate(iroute, iK, iSep, iSNR), ...
        snr90_abs01, snr90_rel025, ...
        metrics.mean_pair_sep_est(iroute, iK, iSep, iSNR), ...
        metrics.std_pair_sep_est(iroute, iK, iSep, iSNR), ...
        metrics.mean_pair_sep_bias(iroute, iK, iSep, iSNR), ...
        metrics.mean_abs_pair_sep_error(iroute, iK, iSep, iSNR), ...
        metrics.mean_pair_center_est(iroute, iK, iSep, iSNR), ...
        metrics.std_pair_center_est(iroute, iK, iSep, iSNR), ...
        metrics.mean_pair_center_bias(iroute, iK, iSep, iSNR), ...
        metrics.mean_abs_pair_center_error(iroute, iK, iSep, iSNR), ...
        metrics.objective_true_rank_median(iroute, iK, iSep, iSNR), ...
        metrics.objective_true_rank_p90(iroute, iK, iSep, iSNR), ...
        metrics.objective_margin_true_vs_best(iroute, iK, iSep, iSNR), ...
        metrics.objective_valley_sep_width_mean(iroute, iK, iSep, iSNR), ...
        metrics.objective_valley_center_width_mean(iroute, iK, iSep, iSNR)};
end

function keypoint_rows = filter_keypoint_rows_local(summary_rows)
    keypoint_rows = {};
    for ii = 1:size(summary_rows, 1)
        stage = summary_rows{ii, 1};
        sep_factor = summary_rows{ii, 5};
        snr_db = summary_rows{ii, 7};
        if strcmp(stage, 'phase_mismatch') || ...
                (strcmp(stage, 'ksnr_scan') && sep_factor == 10 && any(snr_db == [24, 28, 30]))
            keypoint_rows(end+1, :) = summary_rows(ii, :); %#ok<AGROW>
        end
    end
end

function write_summary_csv_local(path_out, rows)
    header = ['stage,route_name,K_phi,P_phi,sep_factor,theta_sep_deg,snr_db,phase_offset_deg,' ...
        'raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,degraded_rate,' ...
        'snr90_abs01,snr90_rel025,mean_pair_sep_est,std_pair_sep_est,mean_pair_sep_bias,' ...
        'mean_abs_pair_sep_error,mean_pair_center_est,std_pair_center_est,mean_pair_center_bias,' ...
        'mean_abs_pair_center_error,objective_true_rank_median,objective_true_rank_p90,' ...
        'objective_margin_true_vs_best,objective_valley_sep_width_mean,objective_valley_center_width_mean'];
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', header);
    for ii = 1:size(rows, 1)
        fprintf(fid, '%s,%s,%d,%d,%d,%.9f,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9g,%.9f,%.9f\n', ...
            rows{ii, 1}, rows{ii, 2}, rows{ii, 3}, rows{ii, 4}, rows{ii, 5}, rows{ii, 6}, ...
            rows{ii, 7}, rows{ii, 8}, rows{ii, 9}, rows{ii, 10}, rows{ii, 11}, rows{ii, 12}, ...
            rows{ii, 13}, rows{ii, 14}, rows{ii, 15}, rows{ii, 16}, rows{ii, 17}, rows{ii, 18}, ...
            rows{ii, 19}, rows{ii, 20}, rows{ii, 21}, rows{ii, 22}, rows{ii, 23}, rows{ii, 24}, ...
            rows{ii, 25}, rows{ii, 26}, rows{ii, 27}, rows{ii, 28});
    end
end

function diagnosis = choose_diagnosis_local(stage1_metrics, phase_metrics, route_names, K_phi_list, sep_factor_list, snr_list, idx_rank1, best_K_phi)
    idxSep10 = find(sep_factor_list == 10, 1);
    idxBestK = find(K_phi_list == best_K_phi, 1);
    idxSNR30 = find(snr_list == 30, 1);
    idxCenter = find(strcmp(route_names, 'center_real'), 1);
    idxMin = find(strcmp(route_names, 'min_den_fb'), 1);
    rank1_snr90_sep10 = squeeze(stage1_metrics.snr90_abs01(idx_rank1, :, idxSep10));
    best_rank1_snr90 = stage1_metrics.snr90_abs01(idx_rank1, idxBestK, idxSep10);
    best_rank1_tol30 = stage1_metrics.tol_success_rate_abs01(idx_rank1, idxBestK, idxSep10, idxSNR30);
    best_rank1_abs_sep_err30 = stage1_metrics.mean_abs_pair_sep_error(idx_rank1, idxBestK, idxSep10, idxSNR30);
    best_rank1_sep_bias30 = stage1_metrics.mean_pair_sep_bias(idx_rank1, idxBestK, idxSep10, idxSNR30);
    best_rank1_valley_sep30 = stage1_metrics.objective_valley_sep_width_mean(idx_rank1, idxBestK, idxSep10, idxSNR30);
    center_tol30 = stage1_metrics.tol_success_rate_abs01(idxCenter, idxBestK, idxSep10, idxSNR30);
    min_tol30 = stage1_metrics.tol_success_rate_abs01(idxMin, idxBestK, idxSep10, idxSNR30);
    phase_rank1 = squeeze(phase_metrics.tol_success_rate_abs01(idx_rank1, 1, 1, :));
    phase_center = squeeze(phase_metrics.tol_success_rate_abs01(idxCenter, 1, 1, :));
    phase_min = squeeze(phase_metrics.tol_success_rate_abs01(idxMin, 1, 1, :));
    phase_drop = phase_rank1(1) - min(phase_rank1(2:end));
    music_nonzero_best = max([phase_center(2:end); phase_min(2:end)]);
    rank1_nonzero_min = min(phase_rank1(2:end));

    if best_rank1_snr90 <= 24 && best_rank1_abs_sep_err30 < 0.08 && phase_drop < 0.20
        case_id = 'A';
        conclusion = 'rank1 equal-phase covfit 是层次二当前主算法候选。';
        next_step = '围绕 rank1 equal-phase covfit 做更大范围 fullscan 或论文整理。';
    elseif phase_drop >= 0.20 && music_nonzero_best >= rank1_nonzero_min
        case_id = 'C';
        conclusion = 'rank1 equal-phase 是极端完全同相模型的专用解法。后续需要实现 rank1 phase-scan covfit。';
        next_step = '实现 covfit_rank1_phase_grid，仍保持层次二一维模型。';
    elseif best_rank1_tol30 >= 0.9 && (best_rank1_abs_sep_err30 >= 0.08 || best_rank1_valley_sep30 >= 0.10)
        case_id = 'B';
        conclusion = 'rank1 covfit 能稳定定位两个目标在绝对容差内，但 separation 方向低谷较宽，需要加入间隔正则或更细的 pair constraint。';
        next_step = '在层次二内做 separation 正则化或更细 pair constraint，不进入层次三。';
    else
        case_id = 'D';
        conclusion = '当前 rank1 covfit 还只是 proof-of-concept，需要优化 pair search、objective normalization 或约束。';
        next_step = '优先优化 rank1 pair search 和 objective normalization。';
    end
    diagnosis = struct();
    diagnosis.case_id = case_id;
    diagnosis.best_K_phi = best_K_phi;
    diagnosis.rank1_snr90_sep10_by_K = rank1_snr90_sep10;
    diagnosis.best_rank1_snr90_sep10 = best_rank1_snr90;
    diagnosis.best_rank1_tol30_sep10 = best_rank1_tol30;
    diagnosis.center_tol30_sep10 = center_tol30;
    diagnosis.min_den_tol30_sep10 = min_tol30;
    diagnosis.best_rank1_abs_sep_err30 = best_rank1_abs_sep_err30;
    diagnosis.best_rank1_sep_bias30 = best_rank1_sep_bias30;
    diagnosis.best_rank1_valley_sep_width30 = best_rank1_valley_sep30;
    diagnosis.phase_rank1_tol = phase_rank1;
    diagnosis.phase_center_tol = phase_center;
    diagnosis.phase_min_den_tol = phase_min;
    diagnosis.phase_drop = phase_drop;
    diagnosis.conclusion = conclusion;
    diagnosis.next_step = next_step;
end

function plot_snr90_vs_kphi_local(path_out, route_names, K_phi_list, sep_factor_list, snr90_abs01, snr90_rel025)
    idxSep10 = find(sep_factor_list == 10, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    for iroute = 1:numel(route_names)
        plot(K_phi_list, squeeze(snr90_abs01(iroute, :, idxSep10)), '-o', 'LineWidth', 1.3);
        hold on
    end
    for iroute = 1:numel(route_names)
        plot(K_phi_list, squeeze(snr90_rel025(iroute, :, idxSep10)), '--s', 'LineWidth', 1.0);
    end
    hold off
    grid on
    xlabel('K_\phi');
    ylabel('SNR90 dB');
    title('SNR90 vs K_phi, sep=10');
    legend([strcat(route_names, ' abs01'), strcat(route_names, ' rel025')], 'Interpreter', 'none', 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_tol_vs_snr_sep10_local(path_out, route_names, K_phi_list, sep_factor_list, snr_list, tol_abs)
    idxSep10 = find(sep_factor_list == 10, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1000, 620]);
    tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    for iK = 1:numel(K_phi_list)
        nexttile
        for iroute = 1:numel(route_names)
            plot(snr_list, squeeze(tol_abs(iroute, iK, idxSep10, :)), '-o', 'LineWidth', 1.2);
            hold on
        end
        hold off
        grid on
        ylim([0 1.05]);
        title(sprintf('K=%d', K_phi_list(iK)));
        xlabel('SNR dB');
        ylabel('tol abs01');
    end
    legend(route_names, 'Interpreter', 'none', 'Location', 'southoutside', 'Orientation', 'horizontal');
    saveas(fig, path_out);
    close(fig);
end

function plot_sep_bias_vs_snr_local(path_out, K_phi_list, sep_factor_list, snr_list, sep_bias, abs_sep_error, idx_rank1)
    idxSep10 = find(sep_factor_list == 10, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 580]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iK = 1:numel(K_phi_list)
        plot(snr_list, squeeze(sep_bias(idx_rank1, iK, idxSep10, :)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('mean pair sep bias deg');
    title('rank1 sep bias, sep=10');
    legend(compose('K=%d', K_phi_list), 'Location', 'best');
    nexttile
    for iK = 1:numel(K_phi_list)
        plot(snr_list, squeeze(abs_sep_error(idx_rank1, iK, idxSep10, :)), '-s', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('mean abs sep error deg');
    title('rank1 abs sep error, sep=10');
    saveas(fig, path_out);
    close(fig);
end

function plot_objective_valley_width_local(path_out, K_phi_list, sep_factor_list, snr_list, valley_sep, valley_center, idx_rank1)
    idxSep10 = find(sep_factor_list == 10, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 580]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iK = 1:numel(K_phi_list)
        plot(snr_list, squeeze(valley_sep(idx_rank1, iK, idxSep10, :)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('sep valley width deg');
    title('rank1 objective valley sep width');
    legend(compose('K=%d', K_phi_list), 'Location', 'best');
    nexttile
    for iK = 1:numel(K_phi_list)
        plot(snr_list, squeeze(valley_center(idx_rank1, iK, idxSep10, :)), '-s', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('center valley width deg');
    title('rank1 objective valley center width');
    saveas(fig, path_out);
    close(fig);
end

function plot_phase_offset_sensitivity_local(path_out, route_names, phase_offset_list, tol_abs, rmse_deg, best_K_phi)
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 580]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iroute = 1:numel(route_names)
        plot(phase_offset_list, squeeze(tol_abs(iroute, 1, 1, :)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('phase offset deg');
    ylabel('tol abs01');
    title(sprintf('Phase offset sensitivity, K=%d', best_K_phi));
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    nexttile
    for iroute = 1:numel(route_names)
        plot(phase_offset_list, squeeze(rmse_deg(iroute, 1, 1, :)), '-s', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xlabel('phase offset deg');
    ylabel('RMSE deg');
    title('RMSE versus phase offset');
    saveas(fig, path_out);
    close(fig);
end

function write_record_doc_local(path_out, params, route_names, stage1_metrics, phase_metrics, diagnosis, best_K_info, summary_path, keypoints_path, mat_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    idxSep10 = find(params.sep_factor_list == 10, 1);
    idxBestK = find(params.K_phi_list == diagnosis.best_K_phi, 1);
    idxSNR30 = find(params.snr_list == 30, 1);
    fprintf(fid, '# 第8.6步 层次二第五部分：rank1协方差拟合稳定性扫描记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 第四部分提交：`%s`\n', params.fourth_part_commit);
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 已读取第四部分脚本、summary/keypoints、MAT 和记录文档。\n');
    fprintf(fid, '- 本轮只做层次二 rank1 equal-phase covfit 稳定性与偏差分析。不做 fullscan、层次三、2D az/el MUSIC、Hermitian LS 优化或 phase-scan covfit。\n\n');

    fprintf(fid, '## 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi_list=%s`, `sep_factor_list=%s`, `snr_list=%s`, `T_snap=%d`。\n', ...
        params.Q, mat2str(params.K_phi_list), mat2str(params.sep_factor_list), mat2str(params.snr_list), params.T_snap);
    fprintf(fid, '- `Metkl_requested=%d`，实际使用 `Metkl=%d`。原因：%s\n', params.Metkl_requested, params.Metkl, params.Metkl_reason);
    fprintf(fid, '- phase mismatch：`K_phi=%d`, `sep=10`, `SNR=30`, `phase_offset_list=%s`, `Metkl=%d`。\n\n', ...
        params.best_K_phi_phase_stage, mat2str(params.phase_offset_list), params.phase_Metkl);

    fprintf(fid, '## Route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## K/SNR 小扫描结果\n\n');
    fprintf(fid, '- rank1 sep=10 SNR90_abs01 by K：%s。\n', mat2str(diagnosis.rank1_snr90_sep10_by_K(:).'));
    fprintf(fid, '- 最佳 K_phi：`%d`。选择依据：%s\n', best_K_info.best_K_phi, best_K_info.reason);
    fprintf(fid, '- 最佳 K 在 sep=10, SNR=30：rank1 tol_abs01=%.3f，center_real=%.3f，min_den_fb=%.3f。\n', ...
        diagnosis.best_rank1_tol30_sep10, diagnosis.center_tol30_sep10, diagnosis.min_den_tol30_sep10);
    fprintf(fid, '- mean_abs_pair_sep_error=%.5f deg，mean_pair_sep_bias=%.5f deg，objective_valley_sep_width_mean=%.5f deg。\n\n', ...
        diagnosis.best_rank1_abs_sep_err30, diagnosis.best_rank1_sep_bias30, diagnosis.best_rank1_valley_sep_width30);

    fprintf(fid, '| route | K | sep | SNR | tol_abs01 | RMSE | sep_bias | abs_sep_err | center_bias | true_rank_med | valley_sep_width |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for iroute = 1:numel(route_names)
        fprintf(fid, '| `%s` | %d | 10 | 30 | %.3f | %.5f | %.5f | %.5f | %.5f | %.1f | %.5f |\n', ...
            route_names{iroute}, diagnosis.best_K_phi, ...
            stage1_metrics.tol_success_rate_abs01(iroute, idxBestK, idxSep10, idxSNR30), ...
            stage1_metrics.rmse_deg(iroute, idxBestK, idxSep10, idxSNR30), ...
            stage1_metrics.mean_pair_sep_bias(iroute, idxBestK, idxSep10, idxSNR30), ...
            stage1_metrics.mean_abs_pair_sep_error(iroute, idxBestK, idxSep10, idxSNR30), ...
            stage1_metrics.mean_pair_center_bias(iroute, idxBestK, idxSep10, idxSNR30), ...
            stage1_metrics.objective_true_rank_median(iroute, idxBestK, idxSep10, idxSNR30), ...
            stage1_metrics.objective_valley_sep_width_mean(iroute, idxBestK, idxSep10, idxSNR30));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Phase Offset Sensitivity\n\n');
    fprintf(fid, '| phase_offset_deg | center_real | min_den_fb | rank1_equal_phase |\n');
    fprintf(fid, '|---:|---:|---:|---:|\n');
    for ip = 1:numel(params.phase_offset_list)
        fprintf(fid, '| %.1f | %.3f | %.3f | %.3f |\n', params.phase_offset_list(ip), ...
            phase_metrics.tol_success_rate_abs01(1, 1, 1, ip), ...
            phase_metrics.tol_success_rate_abs01(2, 1, 1, ip), ...
            phase_metrics.tol_success_rate_abs01(3, 1, 1, ip));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 判断\n\n');
    fprintf(fid, '- pair separation bias 是否明显：%s。\n', yesno_local(abs(diagnosis.best_rank1_sep_bias30) >= 0.08));
    fprintf(fid, '- objective valley 是否过宽：%s。\n', yesno_local(diagnosis.best_rank1_valley_sep_width30 >= 0.10));
    fprintf(fid, '- phase offset sensitivity 是否明显：%s。\n', yesno_local(diagnosis.phase_drop >= 0.20));
    fprintf(fid, '%s\n\n', diagnosis.conclusion);
    fprintf(fid, '下一步：%s\n\n', diagnosis.next_step);

    fprintf(fid, '## 输出文件\n\n');
    fprintf(fid, '- summary：`%s`\n', summary_path);
    fprintf(fid, '- keypoints：`%s`\n', keypoints_path);
    fprintf(fid, '- MAT：`%s`\n', mat_path);
end

function out = yesno_local(x)
    if x
        out = '是';
    else
        out = '否';
    end
end

function log_msg(fid, varargin)
    msg = sprintf(varargin{:});
    fprintf('%s\n', msg);
    fprintf(fid, '%s\n', msg);
end

function safe_fclose_local(fid)
    if isnumeric(fid) && isscalar(fid) && fid > 2
        try
            fclose(fid);
        catch
        end
    end
end
