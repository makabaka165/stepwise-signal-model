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

modify_doc_path = fullfile(script_dir, '第8.6步修改方向.md');
formula_doc_path = fullfile(script_dir, '第8.6步层次二和三公式推导.md');
part8_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_complex_gain_covfit.m');
part8_result_dir = fullfile(script_dir, 'results_step8_6_level2_complex_gain_covfit');
part8_summary_csv = fullfile(part8_result_dir, 'step8_6_level2_complex_gain_covfit_summary.csv');
part8_keypoints_csv = fullfile(part8_result_dir, 'step8_6_level2_complex_gain_covfit_keypoints.csv');
part8_record_path = fullfile(script_dir, '第8.6步_层次二第八部分_complex_gain协方差拟合验证记录.md');
part7_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_rank1_engstress.m');
part7_record_path = fullfile(script_dir, '第8.6步_层次二第七部分_rank1协方差拟合工程压力测试记录.md');
part6_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_rank1_covfit_finalscan.m');
overall_record_path = fullfile(script_dir, '第8.6步_层次二整体记录.md');

assert(exist(modify_doc_path, 'file') == 2, 'Modify direction doc not found.');
assert(exist(formula_doc_path, 'file') == 2, 'Formula doc not found.');
assert(exist(part8_script_path, 'file') == 2, 'Part-8 script not found.');
assert(exist(part8_summary_csv, 'file') == 2, 'Part-8 summary CSV not found.');
assert(exist(part8_keypoints_csv, 'file') == 2, 'Part-8 keypoints CSV not found.');
assert(exist(part8_record_path, 'file') == 2, 'Part-8 record not found.');
assert(exist(part7_script_path, 'file') == 2, 'Part-7 script not found.');
assert(exist(part7_record_path, 'file') == 2, 'Part-7 record not found.');
assert(exist(part6_script_path, 'file') == 2, 'Part-6 script not found.');

result_dir = fullfile(script_dir, 'results_step8_6_level2_complex_gain_qdiagnostic');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

record_doc_path = fullfile(script_dir, '第8.6步_层次二第九部分_complex_gain_q估计诊断记录.md');
log_path = fullfile(result_dir, 'step8_6_level2_complex_gain_qdiagnostic.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

log_msg(fid_log, 'Step 08.6 level 2 part 9: complex-gain q diagnostics');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Modify direction doc: %s', modify_doc_path);
log_msg(fid_log, 'Formula doc: %s', formula_doc_path);
log_msg(fid_log, 'Part-8 script: %s', part8_script_path);
log_msg(fid_log, 'Part-8 summary: %s', part8_summary_csv);
log_msg(fid_log, 'Part-8 keypoints: %s', part8_keypoints_csv);
log_msg(fid_log, 'Part-8 record: %s', part8_record_path);
log_msg(fid_log, 'Part-7 script: %s', part7_script_path);
log_msg(fid_log, 'Part-7 record: %s', part7_record_path);
log_msg(fid_log, 'Part-6 script: %s', part6_script_path);
if exist(overall_record_path, 'file') == 2
    overall_record_text = fileread(overall_record_path);
    log_msg(fid_log, 'Overall level-2 record: %s, chars=%d', overall_record_path, strlength(overall_record_text));
else
    log_msg(fid_log, 'WARNING: overall level-2 record was not found.');
end
log_msg(fid_log, 'Scope guard: no V2, no level-3, no 2D az/el, no Q change, no fullscan.');

part8_summary_tbl = readtable(part8_summary_csv);
part8_keypoints_tbl = readtable(part8_keypoints_csv);
part8_baseline = summarize_part8_baseline_local(part8_summary_tbl);
log_msg(fid_log, 'Part-8 baseline: beta0.3 tol@8dB=%.3f, beta0.1 tol@8dB=%.3f, phase150 tol@8dB=%.3f, phase180 tol@8dB=%.3f', ...
    part8_baseline.beta03_tol_8dB, part8_baseline.beta01_tol_8dB, ...
    part8_baseline.phase150_tol_8dB, part8_baseline.phase180_tol_8dB);
log_msg(fid_log, 'Part-8 keypoints rows=%d', height(part8_keypoints_tbl));

azCtr_deg = 0;
T_snap = 260;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
K_phi = 28;
sep_factor = 10;
snr_list_stage1 = 8;
snr_list_stage2 = [-4, 0, 4, 8];
Metkl = 100;
angle_step_coarse = 0.02;
angle_step_refine = 0.005;
min_pair_sep_deg = 0.05;
max_pair_sep_deg = 0.80;
top_N = 5;
refine_half_width = 0.06;
base_seed = 20260707;
beta_grid = [0.1, 0.2, 0.3, 0.5, 0.8, 1.0, 1.2, 1.5, 2.0];
phi_grid_deg = [0, 30, 60, 90, 120, 150, 180];
q_grid_info = build_q_grid_info_local(beta_grid, phi_grid_deg);
q_grid_info_norm = build_q_grid_info_normalized_local(q_grid_info);

log_msg(fid_log, 'Stage1 config: K_phi=%d, sep_factor=%d, SNR=%s, Metkl=%d, T_snap=%d', ...
    K_phi, sep_factor, mat2str(snr_list_stage1), Metkl, T_snap);
log_msg(fid_log, 'beta_grid=%s', mat2str(beta_grid));
log_msg(fid_log, 'phi_grid_deg=%s', mat2str(phi_grid_deg));

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
theta_sep = bw_eq_65 / sep_factor;
target_theta = [azCtr_deg - theta_sep/2, azCtr_deg + theta_sep/2];
tol_rel_now = tol_rel_ratio * theta_sep;
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
log_msg(fid_log, 'bw_eq_65=%.9f deg, theta_sep(sep=10)=%.9f deg, target=[%.9f %.9f] deg', ...
    bw_eq_65, theta_sep, target_theta(1), target_theta(2));
log_msg(fid_log, 'pair search sep range=[%.6f, %.6f] deg', min_pair_sep_deg, max_pair_sep_deg);
if Q ~= 65
    log_msg(fid_log, 'WARNING: Q=%d, expected 65.', Q);
end

route_names = {'covfit_rank1_equal_phase', 'complex_gain_grid_old', 'complex_gain_q_fixed_true', ...
    'complex_gain_q1_forced', 'complex_gain_grid_with_fallback', 'complex_gain_normalized_grid', ...
    'complex_gain_staged_search'};
stress_cases = build_qdiagnostic_cases_local();
ncases = numel(stress_cases);

log_msg(fid_log, '');
log_msg(fid_log, 'Routes');
for iroute = 1:numel(route_names)
    log_msg(fid_log, '  %d: %s', iroute, route_names{iroute});
end
log_msg(fid_log, 'Diagnostic cases=%d', ncases);

B_grid_coarse = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_coarse, 0, 0);
candidate_pairs_coarse = make_pair_candidates_local(angle_grid_coarse, min_pair_sep_deg, max_pair_sep_deg);
cache_coarse = make_subarray_steer_cache_local(B_grid_coarse, K_phi);
precomp_equal_coarse = precompute_rank1_pair_bases_local(cache_coarse, candidate_pairs_coarse);
precomp_complex_coarse = precompute_complex_pair_bases_local(cache_coarse, candidate_pairs_coarse);
true_pair_equal = precompute_true_pair_rank1_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, 0, 0, K_phi);
true_pair_complex = precompute_true_pair_complex_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, 0, 0, K_phi);
q_true_idx_map = build_case_q_index_map_local(stress_cases, q_grid_info);
q1_idx = find_q_grid_index_local(q_grid_info, 1, 0);

stage_cfg = struct();
stage_cfg.route_names = route_names;
stage_cfg.K_phi = K_phi;
stage_cfg.sep_factor = sep_factor;
stage_cfg.theta_sep = theta_sep;
stage_cfg.target_theta = target_theta;
stage_cfg.tol_deg = tol_deg;
stage_cfg.tol_rel_now = tol_rel_now;
stage_cfg.true_center = azCtr_deg;
stage_cfg.Q = Q;
stage_cfg.Metkl = Metkl;
stage_cfg.T_snap = T_snap;
stage_cfg.base_seed = base_seed;
stage_cfg.top_N = top_N;
stage_cfg.refine_half_width = refine_half_width;
stage_cfg.angle_step_refine = angle_step_refine;
stage_cfg.min_pair_sep_deg = min_pair_sep_deg;
stage_cfg.max_pair_sep_deg = max_pair_sep_deg;
stage_cfg.angle_grid_coarse = angle_grid_coarse;
stage_cfg.candidate_pairs_coarse = candidate_pairs_coarse;
stage_cfg.precomp_equal_coarse = precomp_equal_coarse;
stage_cfg.precomp_complex_coarse = precomp_complex_coarse;
stage_cfg.true_pair_equal = true_pair_equal;
stage_cfg.true_pair_complex = true_pair_complex;
stage_cfg.q_true_idx_map = q_true_idx_map;
stage_cfg.q1_idx = q1_idx;
stage_cfg.q_grid_info = q_grid_info;
stage_cfg.q_grid_info_norm = q_grid_info_norm;
stage_cfg.X3d = X3d;
stage_cfg.Y3d = Y3d;
stage_cfg.Z3d = Z3d;
stage_cfg.A_ref_2d = A_ref_2d;
stage_cfg.lambda = cfg.arr.lambda;
stage_cfg.s_base = s_base;

log_msg(fid_log, '');
log_msg(fid_log, 'Stage-1 q diagnostics at SNR=8 dB');
[stage1_metrics, stage1_debug] = run_qdiagnostic_stage_local('snr8_sanity', stress_cases, snr_list_stage1, stage_cfg, fid_log);

run_stage2 = choose_qdiag_stage2_trigger_local(stage1_metrics, route_names, stress_cases);
if run_stage2
    log_msg(fid_log, '');
    log_msg(fid_log, 'Stage-2 triggered: SNR=%s', mat2str(snr_list_stage2));
    [stage2_metrics, stage2_debug] = run_qdiagnostic_stage_local('snr_scan', stress_cases, snr_list_stage2, stage_cfg, fid_log);
else
    log_msg(fid_log, '');
    log_msg(fid_log, 'Stage-2 skipped: no route clearly recovered at stage-1.');
    stage2_metrics = [];
    stage2_debug = struct([]);
end

summary_path = fullfile(result_dir, 'step8_6_level2_complex_gain_qdiagnostic_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_6_level2_complex_gain_qdiagnostic_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_6_level2_complex_gain_qdiagnostic_result.mat');
summary_rows = build_qdiagnostic_summary_rows_local('snr8_sanity', stage1_metrics, route_names, stress_cases, stage_cfg);
if ~isempty(stage2_metrics)
    summary_rows = [summary_rows; build_qdiagnostic_summary_rows_local('snr_scan', stage2_metrics, route_names, stress_cases, stage_cfg)]; %#ok<AGROW>
end
write_qdiagnostic_summary_csv_local(summary_path, summary_rows);
write_qdiagnostic_summary_csv_local(keypoints_path, summary_rows);

diagnosis = choose_qdiagnostic_diagnosis_local(stage1_metrics, route_names, stress_cases, run_stage2);

params = struct();
params.script_path = mfilename('fullpath');
params.modify_doc_path = modify_doc_path;
params.formula_doc_path = formula_doc_path;
params.part8_script_path = part8_script_path;
params.part8_summary_csv = part8_summary_csv;
params.part8_keypoints_csv = part8_keypoints_csv;
params.part8_record_path = part8_record_path;
params.part7_script_path = part7_script_path;
params.part7_record_path = part7_record_path;
params.part6_script_path = part6_script_path;
params.overall_record_path = overall_record_path;
params.part8_baseline = part8_baseline;
params.azCtr_deg = azCtr_deg;
params.T_snap = T_snap;
params.tol_deg = tol_deg;
params.tol_rel_ratio = tol_rel_ratio;
params.Q = Q;
params.K_phi = K_phi;
params.P_phi = Q - K_phi + 1;
params.sep_factor = sep_factor;
params.theta_sep = theta_sep;
params.target_theta = target_theta;
params.Metkl = Metkl;
params.angle_step_coarse = angle_step_coarse;
params.angle_step_refine = angle_step_refine;
params.min_pair_sep_deg = min_pair_sep_deg;
params.max_pair_sep_deg = max_pair_sep_deg;
params.top_N = top_N;
params.refine_half_width = refine_half_width;
params.base_seed = base_seed;
params.d_eq = d_eq;
params.bw_eq_65 = bw_eq_65;
params.beta_grid = beta_grid;
params.phi_grid_deg = phi_grid_deg;
params.snr_list_stage1 = snr_list_stage1;
params.snr_list_stage2 = snr_list_stage2;
params.run_stage2 = run_stage2;

save(mat_path, 'params', 'route_names', 'stress_cases', 'q_grid_info', 'q_grid_info_norm', ...
    'stage_cfg', 'stage1_metrics', 'stage2_metrics', 'stage1_debug', 'stage2_debug', 'diagnosis');

plot_qdiag_route_compare_tol_local(fullfile(result_dir, 'qdiag_route_compare_tol.png'), stage1_metrics, route_names, stress_cases);
plot_qdiag_beta_error_local(fullfile(result_dir, 'qdiag_beta_hat_error.png'), stage1_metrics, route_names, stress_cases);
plot_qdiag_phi_error_local(fullfile(result_dir, 'qdiag_phi_hat_error.png'), stage1_metrics, route_names, stress_cases);
plot_qdiag_boundary_rate_local(fullfile(result_dir, 'qdiag_boundary_rate.png'), stage1_metrics, route_names, stress_cases);
plot_qdiag_score_gap_local(fullfile(result_dir, 'qdiag_score_gap.png'), stage1_metrics, route_names, stress_cases);

write_qdiagnostic_record_doc_local(record_doc_path, params, route_names, stress_cases, stage1_metrics, stage2_metrics, diagnosis, ...
    summary_path, keypoints_path, mat_path);

log_msg(fid_log, '');
log_msg(fid_log, 'Q-diagnostic conclusion: %s', diagnosis.main_conclusion);
log_msg(fid_log, 'q_fixed_true success: %s', yesno_local(diagnosis.q_fixed_true_success));
log_msg(fid_log, 'q1_forced equals equal_phase: %s', yesno_local(diagnosis.q1_matches_equal));
log_msg(fid_log, 'old q-grid failure reproduced: %s', yesno_local(diagnosis.old_qgrid_failure_reproduced));
log_msg(fid_log, 'normalized grid lowers boundary: %s', yesno_local(diagnosis.normalized_reduces_boundary));
log_msg(fid_log, 'staged search improves: %s', yesno_local(diagnosis.staged_improves));
log_msg(fid_log, 'fallback protects baseline: %s', yesno_local(diagnosis.fallback_protects_baseline));
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', keypoints_path);
log_msg(fid_log, '  %s', mat_path);
log_msg(fid_log, '  %s', fullfile(result_dir, 'qdiag_route_compare_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'qdiag_beta_hat_error.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'qdiag_phi_hat_error.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'qdiag_boundary_rate.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'qdiag_score_gap.png'));
log_msg(fid_log, '  %s', record_doc_path);
safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 complex-gain q diagnostic finished.');
disp('result_dir =');
disp(result_dir);
disp('diagnosis =');
disp(diagnosis.main_conclusion);

function fifth_benchmark = summarize_fifth_part_benchmark_local(fifth_summary_tbl)
    mask_key = fifth_summary_tbl.K_phi == 28 & fifth_summary_tbl.sep_factor == 10 & fifth_summary_tbl.snr_db == 30 & string(fifth_summary_tbl.stage) == "ksnr_scan";
    route_col = string(fifth_summary_tbl.route_name);
    fifth_benchmark = struct();
    fifth_benchmark.K_phi = 28;
    fifth_benchmark.sep_factor = 10;
    fifth_benchmark.snr_db = 30;
    fifth_benchmark.rank1_tol_abs01 = NaN;
    fifth_benchmark.rank1_abs_sep_error = NaN;
    idx_rank1 = mask_key & route_col == "covfit_rank1_equal_phase";
    if any(idx_rank1)
        fifth_benchmark.rank1_tol_abs01 = fifth_summary_tbl.tol_success_rate_abs01(idx_rank1);
        fifth_benchmark.rank1_abs_sep_error = fifth_summary_tbl.mean_abs_pair_sep_error(idx_rank1);
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
    stats.objective_best_sum = nan(dims);
    stats.objective_true_sum = nan(dims);
    stats.objective_margin_sum = nan(dims);
    stats.valley_sep_width_sum = nan(dims);
    stats.valley_center_width_sum = nan(dims);
    stats.beta_hat_sum = nan(dims);
    stats.beta_hat_sq_sum = nan(dims);
    stats.beta_err_sum = nan(dims);
    stats.beta_abs_err_sum = nan(dims);
    stats.phi_hat_sum = nan(dims);
    stats.phi_hat_sq_sum = nan(dims);
    stats.phi_err_sum = nan(dims);
    stats.phi_abs_err_sum = nan(dims);
    stats.q_boundary_hit_count = nan(dims);
    stats.angle_swap_count = nan(dims);
    stats.alpha_hat_sum = nan(dims);
    stats.sigma2_hat_sum = nan(dims);
    for iroute = 3:min(nroutes, 4)
        stats.objective_best_sum(iroute, :, :, :) = 0;
        stats.objective_true_sum(iroute, :, :, :) = 0;
        stats.objective_margin_sum(iroute, :, :, :) = 0;
        stats.valley_sep_width_sum(iroute, :, :, :) = 0;
        stats.valley_center_width_sum(iroute, :, :, :) = 0;
    end
    if nroutes >= 4
        stats.beta_hat_sum(4, :, :, :) = 0;
        stats.beta_hat_sq_sum(4, :, :, :) = 0;
        stats.beta_err_sum(4, :, :, :) = 0;
        stats.beta_abs_err_sum(4, :, :, :) = 0;
        stats.phi_hat_sum(4, :, :, :) = 0;
        stats.phi_hat_sq_sum(4, :, :, :) = 0;
        stats.phi_err_sum(4, :, :, :) = 0;
        stats.phi_abs_err_sum(4, :, :, :) = 0;
        stats.q_boundary_hit_count(4, :, :, :) = 0;
        stats.angle_swap_count(4, :, :, :) = 0;
        stats.alpha_hat_sum(4, :, :, :) = 0;
        stats.sigma2_hat_sum(4, :, :, :) = 0;
    end
end

function stats = update_route_metrics_local(stats, doa_all, rank1_result, idx_rank1, complex_result, idx_complex, target_theta, theta_sep, true_center, tol_deg, tol_rel_now, iK, iSep, iSNR, sc)
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
    stats.objective_best_sum(idx_rank1, iK, iSep, iSNR) = stats.objective_best_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.objective_best;
    stats.objective_true_sum(idx_rank1, iK, iSep, iSNR) = stats.objective_true_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.objective_true;
    stats.objective_margin_sum(idx_rank1, iK, iSep, iSNR) = stats.objective_margin_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.objective_margin_true_vs_best;
    stats.valley_sep_width_sum(idx_rank1, iK, iSep, iSNR) = stats.valley_sep_width_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.valley_sep_width;
    stats.valley_center_width_sum(idx_rank1, iK, iSep, iSNR) = stats.valley_center_width_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.valley_center_width;
    stats.objective_true_rank_values{idx_complex, iK, iSep, iSNR}(end+1) = complex_result.true_rank;
    stats.objective_best_sum(idx_complex, iK, iSep, iSNR) = stats.objective_best_sum(idx_complex, iK, iSep, iSNR) + complex_result.objective_best;
    stats.objective_true_sum(idx_complex, iK, iSep, iSNR) = stats.objective_true_sum(idx_complex, iK, iSep, iSNR) + complex_result.objective_true;
    stats.objective_margin_sum(idx_complex, iK, iSep, iSNR) = stats.objective_margin_sum(idx_complex, iK, iSep, iSNR) + complex_result.objective_margin_true_vs_best;
    stats.valley_sep_width_sum(idx_complex, iK, iSep, iSNR) = stats.valley_sep_width_sum(idx_complex, iK, iSep, iSNR) + complex_result.valley_sep_width;
    stats.valley_center_width_sum(idx_complex, iK, iSep, iSNR) = stats.valley_center_width_sum(idx_complex, iK, iSep, iSNR) + complex_result.valley_center_width;
    stats.beta_hat_sum(idx_complex, iK, iSep, iSNR) = stats.beta_hat_sum(idx_complex, iK, iSep, iSNR) + complex_result.beta_hat;
    stats.beta_hat_sq_sum(idx_complex, iK, iSep, iSNR) = stats.beta_hat_sq_sum(idx_complex, iK, iSep, iSNR) + complex_result.beta_hat.^2;
    stats.beta_err_sum(idx_complex, iK, iSep, iSNR) = stats.beta_err_sum(idx_complex, iK, iSep, iSNR) + complex_result.beta_error;
    stats.beta_abs_err_sum(idx_complex, iK, iSep, iSNR) = stats.beta_abs_err_sum(idx_complex, iK, iSep, iSNR) + abs(complex_result.beta_error);
    stats.phi_hat_sum(idx_complex, iK, iSep, iSNR) = stats.phi_hat_sum(idx_complex, iK, iSep, iSNR) + complex_result.phi_hat_deg;
    stats.phi_hat_sq_sum(idx_complex, iK, iSep, iSNR) = stats.phi_hat_sq_sum(idx_complex, iK, iSep, iSNR) + complex_result.phi_hat_deg.^2;
    stats.phi_err_sum(idx_complex, iK, iSep, iSNR) = stats.phi_err_sum(idx_complex, iK, iSep, iSNR) + complex_result.phi_error_deg;
    stats.phi_abs_err_sum(idx_complex, iK, iSep, iSNR) = stats.phi_abs_err_sum(idx_complex, iK, iSep, iSNR) + abs(complex_result.phi_error_deg);
    stats.q_boundary_hit_count(idx_complex, iK, iSep, iSNR) = stats.q_boundary_hit_count(idx_complex, iK, iSep, iSNR) + double(complex_result.q_grid_hit_boundary);
    stats.angle_swap_count(idx_complex, iK, iSep, iSNR) = stats.angle_swap_count(idx_complex, iK, iSep, iSNR) + double(complex_result.angle_swap_flag);
    stats.alpha_hat_sum(idx_complex, iK, iSep, iSNR) = stats.alpha_hat_sum(idx_complex, iK, iSep, iSNR) + complex_result.alpha_hat;
    stats.sigma2_hat_sum(idx_complex, iK, iSep, iSNR) = stats.sigma2_hat_sum(idx_complex, iK, iSep, iSNR) + complex_result.sigma2_hat;
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
    metrics.mean_objective_best = stats.objective_best_sum / Metkl;
    metrics.mean_objective_true_pair = stats.objective_true_sum / Metkl;
    metrics.objective_valley_sep_width_mean = stats.valley_sep_width_sum / Metkl;
    metrics.objective_valley_center_width_mean = stats.valley_center_width_sum / Metkl;
    metrics.mean_beta_hat = stats.beta_hat_sum / Metkl;
    metrics.std_beta_hat = sqrt(max(stats.beta_hat_sq_sum / Metkl - metrics.mean_beta_hat.^2, 0));
    metrics.mean_beta_error = stats.beta_err_sum / Metkl;
    metrics.mean_abs_beta_error = stats.beta_abs_err_sum / Metkl;
    metrics.mean_phi_hat_deg = stats.phi_hat_sum / Metkl;
    metrics.std_phi_hat_deg = sqrt(max(stats.phi_hat_sq_sum / Metkl - metrics.mean_phi_hat_deg.^2, 0));
    metrics.mean_phi_error_deg = stats.phi_err_sum / Metkl;
    metrics.mean_abs_phi_error_deg = stats.phi_abs_err_sum / Metkl;
    metrics.q_grid_hit_boundary_rate = stats.q_boundary_hit_count / Metkl;
    metrics.angle_swap_rate = stats.angle_swap_count / Metkl;
    metrics.mean_alpha_hat = stats.alpha_hat_sum / Metkl;
    metrics.mean_sigma2_hat = stats.sigma2_hat_sum / Metkl;
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
    score = (yy + best_delta) / max(yy, eps);
end

function q_grid_info = build_q_grid_info_local(beta_grid, phi_grid_deg)
    [beta_mesh, phi_mesh] = ndgrid(beta_grid, phi_grid_deg);
    beta_list = beta_mesh(:);
    phi_list = phi_mesh(:);
    q_list = beta_list .* exp(1j * deg2rad(phi_list));
    absq2 = beta_list.^2;
    q_re = real(q_list);
    q_im = imag(q_list);
    q_grid_info = struct();
    q_grid_info.beta_grid = beta_grid(:).';
    q_grid_info.phi_grid_deg = phi_grid_deg(:).';
    q_grid_info.beta_list = beta_list(:);
    q_grid_info.phi_list_deg = phi_list(:);
    q_grid_info.q_grid = q_list(:);
    q_grid_info.absq2 = absq2(:);
    q_grid_info.q_re = q_re(:);
    q_grid_info.q_im = q_im(:);
    q_grid_info.lin_features = [ones(numel(q_list), 1), absq2(:), q_re(:), q_im(:)].';
    q_grid_info.quad_features = [ ...
        ones(numel(q_list), 1), ...
        absq2(:).^2, ...
        q_re(:).^2, ...
        q_im(:).^2, ...
        2 * absq2(:), ...
        2 * q_re(:), ...
        2 * q_im(:), ...
        2 * absq2(:) .* q_re(:), ...
        2 * absq2(:) .* q_im(:), ...
        2 * q_re(:) .* q_im(:)].';
    q_grid_info.is_boundary = (beta_list == beta_grid(1)) | (beta_list == beta_grid(end)) | ...
        (phi_list == phi_grid_deg(1)) | (phi_list == phi_grid_deg(end));
end

function precomp = precompute_complex_pair_bases_local(cache, candidate_pairs)
    K = cache.K_phi;
    P_phi = cache.P_phi;
    J = cache.J;
    Nc = size(candidate_pairs, 1);
    L = 2 * K * K;
    g11 = zeros(L, Nc, 'single');
    g22 = zeros(L, Nc, 'single');
    gre = zeros(L, Nc, 'single');
    gim = zeros(L, Nc, 'single');
    ivec = matrix_to_realvec_local(eye(K));
    ii = real(ivec' * ivec);
    c11 = zeros(Nc, 1);
    c22 = zeros(Nc, 1);
    crr = zeros(Nc, 1);
    cii = zeros(Nc, 1);
    c12 = zeros(Nc, 1);
    c1r = zeros(Nc, 1);
    c1i = zeros(Nc, 1);
    c2r = zeros(Nc, 1);
    c2i = zeros(Nc, 1);
    cri = zeros(Nc, 1);
    gi11 = zeros(Nc, 1);
    gi22 = zeros(Nc, 1);
    gire = zeros(Nc, 1);
    giim = zeros(Nc, 1);
    for ic = 1:Nc
        i1 = candidate_pairs(ic, 1);
        i2 = candidate_pairs(ic, 2);
        A1 = reshape(cache.A_forward(:, i1, :), K, P_phi);
        A2 = reshape(cache.A_forward(:, i2, :), K, P_phi);
        F11 = (A1 * A1') / P_phi;
        F22 = (A2 * A2') / P_phi;
        F12 = (A1 * A2') / P_phi;
        G11 = fb_project_local(F11, J);
        G22 = fb_project_local(F22, J);
        H = fb_project_local(F12, J);
        Gre = H + H';
        Gim = 1j * (H - H');
        v11 = matrix_to_realvec_local(G11);
        v22 = matrix_to_realvec_local(G22);
        vre = matrix_to_realvec_local(Gre);
        vim = matrix_to_realvec_local(Gim);
        g11(:, ic) = single(v11);
        g22(:, ic) = single(v22);
        gre(:, ic) = single(vre);
        gim(:, ic) = single(vim);
        c11(ic) = real(v11' * v11);
        c22(ic) = real(v22' * v22);
        crr(ic) = real(vre' * vre);
        cii(ic) = real(vim' * vim);
        c12(ic) = real(v11' * v22);
        c1r(ic) = real(v11' * vre);
        c1i(ic) = real(v11' * vim);
        c2r(ic) = real(v22' * vre);
        c2i(ic) = real(v22' * vim);
        cri(ic) = real(vre' * vim);
        gi11(ic) = real(v11' * ivec);
        gi22(ic) = real(v22' * ivec);
        gire(ic) = real(vre' * ivec);
        giim(ic) = real(vim' * ivec);
    end
    precomp = struct();
    precomp.K_phi = K;
    precomp.P_phi = P_phi;
    precomp.candidate_pairs = candidate_pairs;
    precomp.g11 = g11;
    precomp.g22 = g22;
    precomp.gre = gre;
    precomp.gim = gim;
    precomp.gg_coef = [c11, c22, crr, cii, c12, c1r, c1i, c2r, c2i, cri];
    precomp.gi_coef = [gi11, gi22, gire, giim];
    precomp.ivec = single(ivec);
    precomp.ii = ii;
end

function true_precomp = precompute_true_pair_complex_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi)
    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg);
    cache = make_subarray_steer_cache_local(B_grid, K_phi);
    true_precomp = precompute_complex_pair_bases_local(cache, [1, 2]);
end

function complex_result = run_complex_gain_covfit_pair_search_local( ...
    Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, el_scan_deg, el_assumed_deg, K_phi, ...
    min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, ...
    true_pair_precomp, q_grid_info, true_beta, true_phi_deg)

    [coarse_scores, coarse_alpha, coarse_sigma2] = score_complex_all_local(Rfb, precomp_coarse, q_grid_info);
    top_lin = top_indices_local(coarse_scores(:), top_N);
    [top_pair_idx, ~] = ind2sub(size(coarse_scores), top_lin);
    top_pair_idx = unique(top_pair_idx, 'stable');
    top_pairs_theta = [angle_grid_coarse(candidate_pairs_coarse(top_pair_idx, 1)).', ...
        angle_grid_coarse(candidate_pairs_coarse(top_pair_idx, 2)).'];
    refine_pairs_theta = make_refine_pairs_local(top_pairs_theta, refine_half_width, angle_step_refine, ...
        min_pair_sep_deg, max_pair_sep_deg);
    if isempty(refine_pairs_theta)
        refine_pairs_theta = top_pairs_theta;
    end
    [angle_grid_refine, candidate_pairs_refine] = theta_pairs_to_grid_indices_local(refine_pairs_theta);
    B_grid_refine = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid_refine, el_scan_deg, el_assumed_deg);
    cache_refine = make_subarray_steer_cache_local(B_grid_refine, K_phi);
    precomp_refine = precompute_complex_pair_bases_local(cache_refine, candidate_pairs_refine);
    [refine_scores, refine_alpha, refine_sigma2] = score_complex_all_local(Rfb, precomp_refine, q_grid_info);
    [true_score_mat, ~, ~] = score_complex_all_local(Rfb, true_pair_precomp, q_grid_info);
    true_q_idx = find_q_grid_index_local(q_grid_info, true_beta, true_phi_deg);
    true_score = true_score_mat(1, true_q_idx);

    [best_score, best_lin] = min(refine_scores(:));
    [best_pair_idx, best_q_idx] = ind2sub(size(refine_scores), best_lin);
    [best_coarse_score, best_coarse_lin] = min(coarse_scores(:));
    [best_coarse_pair_idx, best_coarse_q_idx] = ind2sub(size(coarse_scores), best_coarse_lin);
    doa_est = sort(angle_grid_refine(candidate_pairs_refine(best_pair_idx, :)));
    refine_pair = doa_est;
    coarse_pair = sort(angle_grid_coarse(candidate_pairs_coarse(best_coarse_pair_idx, :)));
    true_rank = 1 + sum(coarse_scores(:) < true_score);

    [coarse_pair_sub, ~] = ind2sub(size(coarse_scores), find(coarse_scores <= best_coarse_score * 1.05));
    coarse_centers = mean(angle_grid_coarse(candidate_pairs_coarse(coarse_pair_sub, :)), 2);
    coarse_seps = diff(angle_grid_coarse(candidate_pairs_coarse(coarse_pair_sub, :)), 1, 2);
    valley_mask = refine_scores <= best_score * 1.05;
    if any(valley_mask(:))
        [ref_pair_sub, ~] = ind2sub(size(refine_scores), find(valley_mask));
        ref_centers = mean(angle_grid_refine(candidate_pairs_refine(ref_pair_sub, :)), 2);
        ref_seps = diff(angle_grid_refine(candidate_pairs_refine(ref_pair_sub, :)), 1, 2);
        valley_sep_width = max(ref_seps) - min(ref_seps);
        valley_center_width = max(ref_centers) - min(ref_centers);
    else
        valley_sep_width = NaN;
        valley_center_width = NaN;
    end
    complex_result = struct();
    complex_result.doa_est = doa_est;
    complex_result.refine_pair = refine_pair;
    complex_result.coarse_pair = coarse_pair;
    complex_result.objective_best = best_score;
    complex_result.objective_true = true_score;
    complex_result.objective_margin_true_vs_best = true_score - best_score;
    complex_result.true_rank = true_rank;
    complex_result.coarse_objective_best = best_coarse_score;
    complex_result.coarse_valley_sep_width = span_or_nan_local(coarse_seps);
    complex_result.coarse_valley_center_width = span_or_nan_local(coarse_centers);
    complex_result.valley_sep_width = valley_sep_width;
    complex_result.valley_center_width = valley_center_width;
    complex_result.refine_pair_count = size(candidate_pairs_refine, 1);
    complex_result.valley_pair_count = sum(valley_mask(:));
    complex_result.beta_hat = q_grid_info.beta_list(best_q_idx);
    complex_result.phi_hat_deg = q_grid_info.phi_list_deg(best_q_idx);
    complex_result.alpha_hat = refine_alpha(best_pair_idx, best_q_idx);
    complex_result.sigma2_hat = refine_sigma2(best_pair_idx, best_q_idx);
    complex_result.q_grid_hit_boundary = q_grid_info.is_boundary(best_q_idx);
    complex_result.coarse_beta_hat = q_grid_info.beta_list(best_coarse_q_idx);
    complex_result.coarse_phi_hat_deg = q_grid_info.phi_list_deg(best_coarse_q_idx);
    complex_result.coarse_q_grid_hit_boundary = q_grid_info.is_boundary(best_coarse_q_idx);
    complex_result.beta_error = complex_result.beta_hat - true_beta;
    complex_result.phi_error_deg = wrap_phase_diff_deg_local(complex_result.phi_hat_deg - true_phi_deg);
    complex_result.angle_swap_flag = angle_swap_flag_local(true_beta, complex_result.beta_hat);
end

function [score, alpha_best, sigma2_best] = score_complex_all_local(Robs, precomp, q_grid_info)
    y = matrix_to_realvec_local(Robs);
    yy = real(y' * y);
    iy = double(precomp.ivec' * single(y));
    gy11 = double(precomp.g11' * single(y));
    gy22 = double(precomp.g22' * single(y));
    gyre = double(precomp.gre' * single(y));
    gyim = double(precomp.gim' * single(y));
    gy_coef = [gy11, gy22, gyre, gyim];
    GY = gy_coef * q_grid_info.lin_features;
    GI = precomp.gi_coef * q_grid_info.lin_features;
    GG = precomp.gg_coef * q_grid_info.quad_features;
    [score, alpha_best, sigma2_best] = solve_covfit_score_local(GY, GI, GG, yy, iy, precomp.ii);
end

function [score, alpha_best, sigma2_best] = solve_covfit_score_local(gy, gi, gg, yy, iy, ii)
    detv = gg * ii - gi.^2;
    valid = abs(detv) > 1e-12;
    alpha = zeros(size(gg));
    sigma2 = zeros(size(gg));
    alpha(valid) = (gy(valid) * ii - gi(valid) * iy) ./ detv(valid);
    sigma2(valid) = (gg(valid) * iy - gi(valid) .* gy(valid)) ./ detv(valid);
    val_both = inf(size(gg));
    ok_both = valid & alpha >= 0 & sigma2 >= 0;
    val_both(ok_both) = -2 * (alpha(ok_both) .* gy(ok_both) + sigma2(ok_both) * iy) + ...
        alpha(ok_both).^2 .* gg(ok_both) + 2 * alpha(ok_both) .* sigma2(ok_both) .* gi(ok_both) + sigma2(ok_both).^2 * ii;
    alpha_only = max(gy ./ max(gg, eps), 0);
    val_alpha = -2 * alpha_only .* gy + alpha_only.^2 .* gg;
    sigma_only = max(iy / max(ii, eps), 0);
    val_sigma = -2 * sigma_only * iy + sigma_only.^2 * ii;
    val_zero = zeros(size(gg));
    all_vals = cat(3, val_both, val_alpha, repmat(val_sigma, size(gg)), val_zero);
    [best_delta, best_case] = min(all_vals, [], 3);
    score = (yy + best_delta) / max(yy, eps);
    alpha_best = zeros(size(gg));
    sigma2_best = zeros(size(gg));
    mask = best_case == 1;
    alpha_best(mask) = alpha(mask);
    sigma2_best(mask) = sigma2(mask);
    mask = best_case == 2;
    alpha_best(mask) = alpha_only(mask);
end

function idx = find_q_grid_index_local(q_grid_info, beta_true, phi_true_deg)
    idx = find(abs(q_grid_info.beta_list - beta_true) < 1e-12 & ...
        abs(q_grid_info.phi_list_deg - phi_true_deg) < 1e-12, 1);
    if isempty(idx)
        error('True q is not on the configured q-grid.');
    end
end

function out = span_or_nan_local(x)
    if isempty(x)
        out = NaN;
    else
        out = max(x) - min(x);
    end
end

function out = wrap_phase_diff_deg_local(x)
    out = mod(x + 180, 360) - 180;
end

function out = angle_swap_flag_local(true_beta, beta_hat)
    if abs(true_beta - 1) < 1e-12
        out = false;
    else
        out = (true_beta < 1 && beta_hat > 1) || (true_beta > 1 && beta_hat < 1);
    end
end

function idx = top_indices_local(score, top_N)
    score = score(:);
    ord_tbl = sortrows([(1:numel(score)).', score], [2, 1]);
    idx = ord_tbl(1:min(top_N, size(ord_tbl, 1)), 1);
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

function labels = make_snr90_label_local(snr90, tol_rate, snr_list)
    labels = cell(size(snr90));
    labels(:) = {'NaN'};
    lowest_snr = snr_list(1);
    [nroutes, nK, nsep] = size(snr90);
    for iroute = 1:nroutes
        for iK = 1:nK
            for iSep = 1:nsep
                val = snr90(iroute, iK, iSep);
                if isnan(val)
                    continue
                end
                tol_at_lowest = tol_rate(iroute, iK, iSep, 1);
                if tol_at_lowest >= 0.9
                    labels{iroute, iK, iSep} = sprintf('<= %.0f dB', lowest_snr);
                else
                    labels{iroute, iK, iSep} = sprintf('%.0f dB', val);
                end
            end
        end
    end
end

function summary_rows = build_final_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, theta_sep_deg, Q, metrics)
    summary_rows = {};
    for iroute = 1:numel(route_names)
        for iK = 1:numel(K_phi_list)
            K_phi = K_phi_list(iK);
            P_phi = Q - K_phi + 1;
            for iSep = 1:numel(sep_factor_list)
                for iSNR = 1:numel(snr_list)
                    summary_rows(end+1, :) = make_final_row_local( ...
                        'final_validation', route_names{iroute}, K_phi, P_phi, ...
                        sep_factor_list(iSep), theta_sep_deg(iSep), snr_list(iSNR), ...
                        metrics, iroute, iK, iSep, iSNR); %#ok<AGROW>
                end
            end
        end
    end
end

function row = make_final_row_local(stage, route_name, K_phi, P_phi, sep_factor, theta_sep_deg, snr_db, metrics, iroute, iK, iSep, iSNR)
    row = {stage, route_name, K_phi, P_phi, sep_factor, theta_sep_deg, snr_db, ...
        metrics.raw_success_rate(iroute, iK, iSep, iSNR), ...
        metrics.tol_success_rate_abs01(iroute, iK, iSep, iSNR), ...
        metrics.tol_success_rate_rel025(iroute, iK, iSep, iSNR), ...
        metrics.rmse_deg(iroute, iK, iSep, iSNR), ...
        metrics.degraded_rate(iroute, iK, iSep, iSNR), ...
        metrics.snr90_abs01(iroute, iK, iSep), ...
        metrics.snr90_abs01_label{iroute, iK, iSep}, ...
        metrics.snr90_rel025(iroute, iK, iSep), ...
        metrics.snr90_rel025_label{iroute, iK, iSep}, ...
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
        metrics.mean_objective_best(iroute, iK, iSep, iSNR), ...
        metrics.mean_objective_true_pair(iroute, iK, iSep, iSNR), ...
        metrics.objective_margin_true_vs_best(iroute, iK, iSep, iSNR), ...
        metrics.objective_valley_sep_width_mean(iroute, iK, iSep, iSNR), ...
        metrics.objective_valley_center_width_mean(iroute, iK, iSep, iSNR)};
end

function keypoint_rows = filter_final_keypoint_rows_local(summary_rows, final_metrics, route_names, sep_factor_list, snr_list)
    keypoint_rows = {};
    key_snr = unique([snr_list(1), 0, 6, 10, 14, 18, 20, snr_list(end)]);
    for ii = 1:size(summary_rows, 1)
        route_name = summary_rows{ii, 2};
        sep_factor = summary_rows{ii, 5};
        snr_db = summary_rows{ii, 7};
        iroute = find(strcmp(route_names, route_name), 1);
        iSep = find(sep_factor_list == sep_factor, 1);
        include_row = any(snr_db == key_snr);
        if ~isempty(iroute) && ~isempty(iSep)
            snr90_now = final_metrics.snr90_abs01(iroute, 1, iSep);
            if isfinite(snr90_now) && abs(snr_db - snr90_now) <= 2
                include_row = true;
            end
        end
        if include_row
            keypoint_rows(end+1, :) = summary_rows(ii, :); %#ok<AGROW>
        end
    end
end

function write_final_summary_csv_local(path_out, rows)
    header = {'stage', 'route_name', 'K_phi', 'P_phi', 'sep_factor', 'theta_sep_deg', 'snr_db', ...
        'raw_success_rate', 'tol_success_rate_abs01', 'tol_success_rate_rel025', 'rmse_deg', 'degraded_rate', ...
        'snr90_abs01', 'snr90_abs01_label', 'snr90_rel025', 'snr90_rel025_label', ...
        'mean_pair_sep_est', 'std_pair_sep_est', 'mean_pair_sep_bias', 'mean_abs_pair_sep_error', ...
        'mean_pair_center_est', 'std_pair_center_est', 'mean_pair_center_bias', 'mean_abs_pair_center_error', ...
        'objective_true_rank_median', 'objective_true_rank_p90', 'mean_objective_best', ...
        'mean_objective_true_pair', 'objective_margin_true_vs_best', ...
        'objective_valley_sep_width_mean', 'objective_valley_center_width_mean'};
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(header, ','));
    for ii = 1:size(rows, 1)
        vals = cell(1, numel(header));
        for jj = 1:numel(header)
            vals{jj} = csv_value_local(rows{ii, jj});
        end
        fprintf(fid, '%s\n', strjoin(vals, ','));
    end
end

function txt = csv_value_local(x)
    if isnumeric(x)
        if isempty(x)
            txt = '';
        elseif isscalar(x)
            if isnan(x)
                txt = 'NaN';
            else
                txt = sprintf('%.10g', x);
            end
        else
            txt = mat2str(x);
        end
    elseif isstring(x)
        txt = char(x);
    elseif ischar(x)
        txt = x;
    else
        txt = char(string(x));
    end
    if any(txt == ',') || any(txt == '"') || any(txt == sprintf('\n'))
        txt = ['"', strrep(txt, '"', '""'), '"'];
    end
end

function diagnosis = choose_final_diagnosis_local(final_metrics, route_names, sep_factor_list, snr_list, idx_rank1)
    idxK = 1;
    idxSep10 = find(sep_factor_list == 10, 1);
    idxLowest = 1;
    idxSNR20 = find(snr_list == 20, 1);
    idxCenter = find(strcmp(route_names, 'center_real'), 1);
    idxMin = find(strcmp(route_names, 'min_den_fb'), 1);
    rank1_snr90_sep10 = final_metrics.snr90_abs01(idx_rank1, idxK, idxSep10);
    rank1_snr90_sep10_label = final_metrics.snr90_abs01_label{idx_rank1, idxK, idxSep10};
    rank1_rel_snr90_sep10_label = final_metrics.snr90_rel025_label{idx_rank1, idxK, idxSep10};
    rank1_tol_lowest_sep10 = final_metrics.tol_success_rate_abs01(idx_rank1, idxK, idxSep10, idxLowest);
    rank1_abs_sep_err_lowest_sep10 = final_metrics.mean_abs_pair_sep_error(idx_rank1, idxK, idxSep10, idxLowest);
    rank1_sep_bias_lowest_sep10 = final_metrics.mean_pair_sep_bias(idx_rank1, idxK, idxSep10, idxLowest);
    rank1_valley_sep_lowest_sep10 = final_metrics.objective_valley_sep_width_mean(idx_rank1, idxK, idxSep10, idxLowest);
    rank1_tol20_sep10 = final_metrics.tol_success_rate_abs01(idx_rank1, idxK, idxSep10, idxSNR20);
    center_snr90_sep10 = final_metrics.snr90_abs01(idxCenter, idxK, idxSep10);
    min_snr90_sep10 = final_metrics.snr90_abs01(idxMin, idxK, idxSep10);
    rank1_snr90_by_sep = squeeze(final_metrics.snr90_abs01(idx_rank1, idxK, :)).';
    rank1_snr90_labels_by_sep = squeeze(final_metrics.snr90_abs01_label(idx_rank1, idxK, :)).';
    all_sep_stable = all(isfinite(rank1_snr90_by_sep));
    low_snr_bias_expanded = rank1_abs_sep_err_lowest_sep10 > 0.08 || rank1_valley_sep_lowest_sep10 > 0.10;

    if isfinite(rank1_snr90_sep10) && rank1_snr90_sep10 <= 12
        case_id = 'A';
        conclusion = 'rank1 covfit 显著优于现有所有层次二 MUSIC 方案，是第 8.6 步层次二主算法候选。';
        next_step = '层次二内可围绕 rank1 covfit 做实现整理和论文表述；当前合成验证目标下不需要进入层次三。';
    elseif isfinite(rank1_snr90_sep10) && rank1_snr90_sep10 <= 18
        case_id = 'B';
        conclusion = 'rank1 covfit 明显优于 MUSIC 谱函数族，但极小间隔仍有一定 SNR 门槛。';
        next_step = '层次二内继续关注 pair separation 约束、搜索效率和 objective normalization，不展开层次三。';
    elseif low_snr_bias_expanded
        case_id = 'C';
        conclusion = 'rank1 covfit 在低 SNR 下存在 separation valley 宽化，需要后续研究 pair separation regularization。';
        next_step = '只在层次二内验证 separation 正则或更稳健的 pair 约束，不做 phase-scan 或层次三。';
    elseif all_sep_stable
        case_id = 'D';
        conclusion = '层次二 rank1 covfit 已经可以作为完整 65 列工程子阵的一维方位超分辨主路线。';
        next_step = '整理层次二最终算法边界和适用条件；当前验证不要求层次三。';
    else
        case_id = 'E';
        conclusion = 'rank1 covfit 对 sep=10 有收益，但 sep_factor 全曲线仍存在未稳定区域。';
        next_step = '继续在层次二内定位失败 sep/SNR 的 objective 与搜索网格原因。';
    end

    diagnosis = struct();
    diagnosis.case_id = case_id;
    diagnosis.K_phi = final_metrics.K_phi_list(idxK);
    diagnosis.sep10_snr90_abs01 = rank1_snr90_sep10;
    diagnosis.sep10_snr90_abs01_label = rank1_snr90_sep10_label;
    diagnosis.sep10_snr90_rel025_label = rank1_rel_snr90_sep10_label;
    diagnosis.center_snr90_sep10 = center_snr90_sep10;
    diagnosis.min_den_snr90_sep10 = min_snr90_sep10;
    diagnosis.rank1_snr90_by_sep = rank1_snr90_by_sep;
    diagnosis.rank1_snr90_labels_by_sep = rank1_snr90_labels_by_sep;
    diagnosis.rank1_tol_lowest_sep10 = rank1_tol_lowest_sep10;
    diagnosis.rank1_tol20_sep10 = rank1_tol20_sep10;
    diagnosis.rank1_abs_sep_err_lowest_sep10 = rank1_abs_sep_err_lowest_sep10;
    diagnosis.rank1_sep_bias_lowest_sep10 = rank1_sep_bias_lowest_sep10;
    diagnosis.rank1_valley_sep_lowest_sep10 = rank1_valley_sep_lowest_sep10;
    diagnosis.lowest_snr = snr_list(idxLowest);
    diagnosis.low_snr_bias_expanded = low_snr_bias_expanded;
    diagnosis.all_sep_stable = all_sep_stable;
    diagnosis.conclusion = conclusion;
    diagnosis.next_step = next_step;
end

function plot_final_snr90_vs_sep_local(path_out, route_names, sep_factor_list, snr90_abs01, snr90_rel025)
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 560]);
    for iroute = 1:numel(route_names)
        plot(sep_factor_list, squeeze(snr90_abs01(iroute, 1, :)), '-o', 'LineWidth', 1.3);
        hold on
    end
    for iroute = 1:numel(route_names)
        plot(sep_factor_list, squeeze(snr90_rel025(iroute, 1, :)), '--s', 'LineWidth', 1.0);
    end
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 dB');
    title('Final validation SNR90 vs sep factor, K=28');
    legend([strcat(route_names, ' abs01'), strcat(route_names, ' rel025')], ...
        'Interpreter', 'none', 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_final_tol_vs_snr_sep10_local(path_out, route_names, sep_factor_list, snr_list, tol_abs)
    idxSep10 = find(sep_factor_list == 10, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    for iroute = 1:numel(route_names)
        plot(snr_list, squeeze(tol_abs(iroute, 1, idxSep10, :)), '-o', 'LineWidth', 1.3);
        hold on
    end
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('SNR dB');
    ylabel('tol success abs 0.1 deg');
    title('Final validation tol vs SNR, sep=10, K=28');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_final_rmse_vs_snr_sep10_local(path_out, route_names, sep_factor_list, snr_list, rmse_deg)
    idxSep10 = find(sep_factor_list == 10, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    for iroute = 1:numel(route_names)
        plot(snr_list, squeeze(rmse_deg(iroute, 1, idxSep10, :)), '-o', 'LineWidth', 1.3);
        hold on
    end
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('RMSE deg');
    title('Final validation RMSE vs SNR, sep=10, K=28');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_final_sep_bias_vs_snr_local(path_out, sep_factor_list, snr_list, sep_bias, abs_sep_error, idx_rank1)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1100, 620]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iSep = 1:numel(sep_factor_list)
        plot(snr_list, squeeze(sep_bias(idx_rank1, 1, iSep, :)), '-o', 'LineWidth', 1.1);
        hold on
    end
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('mean pair sep bias deg');
    title('rank1 separation bias');
    legend(compose('sep=%d', sep_factor_list), 'Location', 'best');
    nexttile
    for iSep = 1:numel(sep_factor_list)
        plot(snr_list, squeeze(abs_sep_error(idx_rank1, 1, iSep, :)), '-s', 'LineWidth', 1.1);
        hold on
    end
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('mean abs sep error deg');
    title('rank1 absolute separation error');
    saveas(fig, path_out);
    close(fig);
end

function plot_final_compare_music_baselines_local(path_out, route_names, sep_factor_list, snr90_abs01, tol_abs, snr_list)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1080, 620]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iroute = 1:numel(route_names)
        plot(sep_factor_list, squeeze(snr90_abs01(iroute, 1, :)), '-o', 'LineWidth', 1.3);
        hold on
    end
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 abs01 dB');
    title('rank1 vs MUSIC baselines');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    nexttile
    idxSep10 = find(sep_factor_list == 10, 1);
    for iroute = 1:numel(route_names)
        plot(snr_list, squeeze(tol_abs(iroute, 1, idxSep10, :)), '-o', 'LineWidth', 1.3);
        hold on
    end
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('SNR dB');
    ylabel('tol success abs01');
    title('sep=10 success curve');
    saveas(fig, path_out);
    close(fig);
end

function write_final_record_doc_local(path_out, params, route_names, final_metrics, diagnosis, summary_path, keypoints_path, mat_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    idxK = 1;
    idxSep10 = find(params.sep_factor_list == 10, 1);
    idxLowest = 1;
    idxRank1 = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    fprintf(fid, '# 第8.6步 层次二第六部分：rank1协方差拟合最终验证记录\n\n');

    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 本轮实际可执行脚本：`%s`\n', params.script_path);
    fprintf(fid, '- 注：修改方向文档中的 `space_smooth_music_B_cylindrical_level2_complex_gain_qdiagnostic.m` 基名长度为 64，超过 MATLAB 63 字符限制；实际执行入口改为 `space_smooth_music_B_cylindrical_level2_complex_gain_qdiag.m`，算法内容保持一致。\n');
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 第五部分提交：`%s`\n', params.fifth_part_commit);
    fprintf(fid, '- 已读取第五部分脚本：`%s`\n', params.fifth_script_path);
    fprintf(fid, '- 已读取第五部分 summary/keypoints/记录文档，用于确认 rank1 equal-phase covfit 的前置结论。\n');
    fprintf(fid, '- 本轮只做层次二第六部分 final validation scan。不做层次三、2D az/el MUSIC、Hermitian LS、phase-scan covfit、PME/SBL/SPICE/DML，也不修改第 7.5、第 8、第 8.5 步旧代码。\n\n');

    fprintf(fid, '## 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi=%d`, `P_phi=%d`, `T_snap=%d`, `Metkl=%d`。\n', ...
        params.Q, params.K_phi_list(1), params.Q - params.K_phi_list(1) + 1, params.T_snap, params.Metkl);
    fprintf(fid, '- `sep_factor_list=%s`, `snr_list=%s`。\n', mat2str(params.sep_factor_list), mat2str(params.snr_list));
    fprintf(fid, '- 低 SNR 精细扫描要求的 `sep=[7 10]`, `SNR=6:2:20` 已包含在统一网格内；由于统一网格直接覆盖 `-4:2:20`，追加低 SNR `-4:2:6` 也已执行。\n');
    fprintf(fid, '- `tol_deg=%.3f`, `tol_rel_ratio=%.3f`, `base_seed=%d`。\n\n', params.tol_deg, params.tol_rel_ratio, params.base_seed);

    fprintf(fid, '## Route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 低 SNR 精细扫描结果\n\n');
    fprintf(fid, '- rank1 sep=10 SNR90_abs01：`%s`；SNR90_rel025：`%s`。\n', ...
        diagnosis.sep10_snr90_abs01_label, diagnosis.sep10_snr90_rel025_label);
    fprintf(fid, '- 最低测试点 `SNR=%g dB` 下，rank1 sep=10 tol_abs01=%.3f，mean_abs_pair_sep_error=%.5f deg，mean_pair_sep_bias=%.5f deg，objective_valley_sep_width_mean=%.5f deg。\n\n', ...
        diagnosis.lowest_snr, diagnosis.rank1_tol_lowest_sep10, diagnosis.rank1_abs_sep_err_lowest_sep10, ...
        diagnosis.rank1_sep_bias_lowest_sep10, diagnosis.rank1_valley_sep_lowest_sep10);

    fprintf(fid, '| SNR | center_real tol | min_den_fb tol | rank1 tol | rank1 abs_sep_err | rank1 sep_bias |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|\n');
    for iSNR = 1:numel(params.snr_list)
        fprintf(fid, '| %g | %.3f | %.3f | %.3f | %.5f | %.5f |\n', params.snr_list(iSNR), ...
            final_metrics.tol_success_rate_abs01(1, idxK, idxSep10, iSNR), ...
            final_metrics.tol_success_rate_abs01(2, idxK, idxSep10, iSNR), ...
            final_metrics.tol_success_rate_abs01(idxRank1, idxK, idxSep10, iSNR), ...
            final_metrics.mean_abs_pair_sep_error(idxRank1, idxK, idxSep10, iSNR), ...
            final_metrics.mean_pair_sep_bias(idxRank1, idxK, idxSep10, iSNR));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## sep_factor 完整曲线\n\n');
    fprintf(fid, '| sep_factor | theta_sep_deg | center_real SNR90_abs01 | min_den_fb SNR90_abs01 | rank1 SNR90_abs01 | rank1 rel025 SNR90 |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|\n');
    for iSep = 1:numel(params.sep_factor_list)
        fprintf(fid, '| %d | %.6f | %s | %s | %s | %s |\n', params.sep_factor_list(iSep), ...
            final_metrics.theta_sep_deg(iSep), ...
            final_metrics.snr90_abs01_label{1, idxK, iSep}, ...
            final_metrics.snr90_abs01_label{2, idxK, iSep}, ...
            final_metrics.snr90_abs01_label{idxRank1, idxK, iSep}, ...
            final_metrics.snr90_rel025_label{idxRank1, idxK, iSep});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## rank1 与 MUSIC 基线对比\n\n');
    fprintf(fid, '- sep=10：center_real SNR90_abs01=`%s`，min_den_fb SNR90_abs01=`%s`，rank1 SNR90_abs01=`%s`。\n', ...
        final_metrics.snr90_abs01_label{1, idxK, idxSep10}, ...
        final_metrics.snr90_abs01_label{2, idxK, idxSep10}, ...
        final_metrics.snr90_abs01_label{idxRank1, idxK, idxSep10});
    fprintf(fid, '- rank1 在 sep=10, SNR=20 dB 的 tol_abs01=%.3f。\n\n', diagnosis.rank1_tol20_sep10);

    fprintf(fid, '## separation bias 判断\n\n');
    fprintf(fid, '- 最低 SNR 下 mean_abs_pair_sep_error 是否超过 0.08 deg：%s。\n', yesno_local(diagnosis.rank1_abs_sep_err_lowest_sep10 > 0.08));
    fprintf(fid, '- 最低 SNR 下 objective_valley_sep_width_mean 是否超过 0.10 deg：%s。\n', yesno_local(diagnosis.rank1_valley_sep_lowest_sep10 > 0.10));
    fprintf(fid, '- 综合判断：低 SNR separation bias/valley 宽化是否明显：%s。\n\n', yesno_local(diagnosis.low_snr_bias_expanded));

    fprintf(fid, '## 层次二主结论\n\n');
    fprintf(fid, '- 判定 case：`%s`\n', diagnosis.case_id);
    fprintf(fid, '- sep_factor 全曲线是否全部存在有限 SNR90：%s。\n', yesno_local(diagnosis.all_sep_stable));
    fprintf(fid, '- %s\n', diagnosis.conclusion);
    fprintf(fid, '- 本轮仍属于 65 列动态工作子阵 + 32 层相干合成后的一维方位层次二验证。当前记录不展开层次三。\n');
    fprintf(fid, '- 下一步：%s\n\n', diagnosis.next_step);

    fprintf(fid, '## 输出文件\n\n');
    fprintf(fid, '- summary：`%s`\n', summary_path);
    fprintf(fid, '- keypoints：`%s`\n', keypoints_path);
    fprintf(fid, '- MAT：`%s`\n', mat_path);
    fprintf(fid, '- figures：`rank1_final_snr90_vs_sep.png`, `rank1_final_tol_vs_snr_sep10.png`, `rank1_final_rmse_vs_snr_sep10.png`, `rank1_final_sep_bias_vs_snr.png`, `rank1_final_compare_music_baselines.png`\n');
end

function sixth_benchmark = summarize_sixth_part_benchmark_local(sixth_summary_tbl)
    sixth_benchmark = struct();
    sixth_benchmark.rank1_snr90_abs01_label = 'NaN';
    sixth_benchmark.rank1_tol_abs01_low_snr = NaN;
    sixth_benchmark.rank1_abs_sep_error_low_snr = NaN;
    route_col = string(sixth_summary_tbl.route_name);
    mask = route_col == "covfit_rank1_equal_phase" & sixth_summary_tbl.sep_factor == 10 & sixth_summary_tbl.snr_db == -4;
    idx = find(mask, 1);
    if ~isempty(idx)
        sixth_benchmark.rank1_tol_abs01_low_snr = sixth_summary_tbl.tol_success_rate_abs01(idx);
        sixth_benchmark.rank1_abs_sep_error_low_snr = sixth_summary_tbl.mean_abs_pair_sep_error(idx);
        if iscell(sixth_summary_tbl.snr90_abs01_label)
            sixth_benchmark.rank1_snr90_abs01_label = sixth_summary_tbl.snr90_abs01_label{idx};
        else
            sixth_benchmark.rank1_snr90_abs01_label = char(string(sixth_summary_tbl.snr90_abs01_label(idx)));
        end
    end
end

function stress_cases = build_engineering_stress_cases_local()
    stress_cases = struct('stress_group', {}, 'case_name', {}, 'stress_value', {}, ...
        'beta', {}, 'el_a_deg', {}, 'el_b_deg', {}, 'el_assumed_deg', {}, ...
        'phase_offset_deg', {}, 'rho', {}, 'model_mismatch_flag', {});

    beta_list = [1, 0.8, 0.5, 0.3, 0.1];
    for ii = 1:numel(beta_list)
        beta = beta_list(ii);
        stress_cases(end+1) = make_stress_case_local('amplitude_ratio', ... %#ok<AGROW>
            ['beta_', num_label_local(beta)], beta, beta, 0, 0, 0, 0, 1);
    end

    phase_offset_list = [0, 30, 60, 90, 120, 150, 180];
    for ii = 1:numel(phase_offset_list)
        ph = phase_offset_list(ii);
        stress_cases(end+1) = make_stress_case_local('phase_offset', ... %#ok<AGROW>
            ['phase_', num_label_local(ph)], ph, 1, 0, 0, 0, ph, 1);
    end

    stress_cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_1_beta0p3_phase60', 1, 0.3, 0, 0, 0, 60, 1); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_2_beta0p3_phase150', 2, 0.3, 0, 0, 0, 150, 1); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_3_beta0p5_phase150', 3, 0.5, 0, 0, 0, 150, 1); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_4_beta0p1_phase0', 4, 0.1, 0, 0, 0, 0, 1); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_5_beta0p1_phase90', 5, 0.1, 0, 0, 0, 90, 1); %#ok<AGROW>
end

function sc = make_stress_case_local(stress_group, case_name, stress_value, beta, el_a_deg, el_b_deg, el_assumed_deg, phase_offset_deg, rho)
    sc = struct();
    sc.stress_group = stress_group;
    sc.case_name = case_name;
    sc.stress_value = stress_value;
    sc.beta = beta;
    sc.el_a_deg = el_a_deg;
    sc.el_b_deg = el_b_deg;
    sc.el_assumed_deg = el_assumed_deg;
    sc.phase_offset_deg = phase_offset_deg;
    sc.rho = rho;
    sc.model_mismatch_flag = abs(beta - 1) > 1e-12 || abs(el_b_deg - el_a_deg) > 1e-12 || ...
        abs(el_assumed_deg - el_a_deg) > 1e-12 || abs(phase_offset_deg) > 1e-12 || abs(rho - 1) > 1e-12;
end

function txt = num_label_local(x)
    txt = strrep(sprintf('%.3g', x), '.', 'p');
    txt = strrep(txt, '-', 'm');
end

function s2 = make_engineering_s2_local(s_base, beta, phase_offset_deg, rho, seed_now)
    phase_factor = exp(1j * deg2rad(phase_offset_deg));
    if rho < 1 - 1e-12
        rng(seed_now, 'twister');
        v = (randn(size(s_base)) + 1j * randn(size(s_base))) / sqrt(2);
        v = v / sqrt(mean(abs(v).^2));
        raw = rho * phase_factor * s_base + sqrt(max(1 - rho^2, 0)) * v;
    else
        raw = phase_factor * s_base;
    end
    raw = raw / sqrt(mean(abs(raw).^2));
    s2 = beta * raw;
end

function summary_rows = build_engineering_summary_rows_local(route_names, stress_cases, K_phi, P_phi, sep_factor, theta_sep_deg, snr_list, metrics)
    summary_rows = {};
    for iCase = 1:numel(stress_cases)
        sc = stress_cases(iCase);
        for iroute = 1:numel(route_names)
            for iSNR = 1:numel(snr_list)
                failure_rate = 1 - metrics.tol_success_rate_abs01(iroute, iCase, 1, iSNR);
                summary_rows(end+1, :) = {sc.stress_group, sc.case_name, sc.stress_value, ...
                    sc.beta, sc.el_a_deg, sc.el_b_deg, sc.el_assumed_deg, sc.phase_offset_deg, sc.rho, ...
                    route_names{iroute}, K_phi, P_phi, sep_factor, theta_sep_deg, snr_list(iSNR), ...
                    metrics.raw_success_rate(iroute, iCase, 1, iSNR), ...
                    metrics.tol_success_rate_abs01(iroute, iCase, 1, iSNR), ...
                    metrics.tol_success_rate_rel025(iroute, iCase, 1, iSNR), ...
                    metrics.rmse_deg(iroute, iCase, 1, iSNR), ...
                    metrics.mean_abs_pair_sep_error(iroute, iCase, 1, iSNR), ...
                    metrics.mean_abs_pair_center_error(iroute, iCase, 1, iSNR), ...
                    metrics.snr90_abs01(iroute, iCase, 1), ...
                    metrics.snr90_abs01_label{iroute, iCase, 1}, ...
                    metrics.snr90_rel025(iroute, iCase, 1), ...
                    metrics.snr90_rel025_label{iroute, iCase, 1}, ...
                    failure_rate, sc.model_mismatch_flag}; %#ok<AGROW>
            end
        end
    end
end

function keypoint_rows = filter_engineering_keypoint_rows_local(summary_rows)
    keypoint_rows = {};
    for ii = 1:size(summary_rows, 1)
        stress_group = summary_rows{ii, 1};
        route_name = summary_rows{ii, 10};
        snr_db = summary_rows{ii, 15};
        if strcmp(route_name, 'covfit_rank1_equal_phase') || strcmp(stress_group, 'extreme_combo') || any(snr_db == [-4, 8])
            keypoint_rows(end+1, :) = summary_rows(ii, :); %#ok<AGROW>
        end
    end
end

function write_engineering_summary_csv_local(path_out, rows)
    header = {'stress_group', 'case_name', 'stress_value', 'beta', 'el_a_deg', 'el_b_deg', ...
        'el_assumed_deg', 'phase_offset_deg', 'rho', 'route_name', 'K_phi', 'P_phi', ...
        'sep_factor', 'theta_sep_deg', 'snr_db', 'raw_success_rate', ...
        'tol_success_rate_abs01', 'tol_success_rate_rel025', 'rmse_deg', ...
        'mean_pair_sep_error', 'mean_pair_center_error', 'snr90_abs01', ...
        'snr90_abs01_label', 'snr90_rel025', 'snr90_rel025_label', ...
        'failure_rate', 'model_mismatch_flag'};
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(header, ','));
    for ii = 1:size(rows, 1)
        vals = cell(1, numel(header));
        for jj = 1:numel(header)
            vals{jj} = csv_value_local(rows{ii, jj});
        end
        fprintf(fid, '%s\n', strjoin(vals, ','));
    end
end

function diagnosis = choose_engineering_diagnosis_local(metrics, stress_cases, route_names, snr_list, idx_rank1)
    idxHigh = find(snr_list == max(snr_list), 1);
    group_names = {'amplitude_ratio', 'elevation_difference', 'el_assumed_mismatch', ...
        'phase_offset', 'coherence_rho', 'extreme_combo'};
    group_min_tol_high = nan(size(group_names));
    group_min_tol_all = nan(size(group_names));
    group_worst_case_high = cell(size(group_names));
    for ig = 1:numel(group_names)
        idx = find(strcmp({stress_cases.stress_group}, group_names{ig}));
        vals_high = squeeze(metrics.tol_success_rate_abs01(idx_rank1, idx, 1, idxHigh));
        vals_all = reshape(metrics.tol_success_rate_abs01(idx_rank1, idx, 1, :), [], 1);
        [group_min_tol_high(ig), rel] = min(vals_high);
        group_min_tol_all(ig) = min(vals_all);
        group_worst_case_high{ig} = stress_cases(idx(rel)).case_name;
    end

    amp_failed = group_min_tol_high(strcmp(group_names, 'amplitude_ratio')) < 0.9;
    elev_failed = group_min_tol_high(strcmp(group_names, 'elevation_difference')) < 0.9;
    el0_failed = group_min_tol_high(strcmp(group_names, 'el_assumed_mismatch')) < 0.9;
    phase_failed = group_min_tol_high(strcmp(group_names, 'phase_offset')) < 0.9;
    rho_failed = group_min_tol_high(strcmp(group_names, 'coherence_rho')) < 0.9;
    extreme_failed = group_min_tol_high(strcmp(group_names, 'extreme_combo')) < 0.9;

    need_complex_gain = amp_failed || phase_failed;
    need_constrained_covfit = rho_failed;
    need_level3 = elev_failed || el0_failed;

    if ~amp_failed && ~elev_failed && ~el0_failed && ~phase_failed && ~rho_failed && ~extreme_failed
        main_conclusion = 'rank1 covfit 在当前工程化仿真范围内具有较强泛化能力，可作为层次二主算法进入论文整理。';
    else
        conclusion_parts = {};
        if amp_failed
            conclusion_parts{end+1} = '幅度比压力测试暴露了 equal-amplitude 假设边界，需要 rank1 complex-gain covfit'; %#ok<AGROW>
        end
        if phase_failed
            conclusion_parts{end+1} = '固定相位偏置在 150/180 deg 附近失效，说明 equal-phase 假设不能覆盖全相位范围'; %#ok<AGROW>
        end
        if elev_failed || el0_failed
            conclusion_parts{end+1} = '大俯仰差和较大的俯仰先验误差表明层次二一维压缩已不足，层次三成为必要扩展'; %#ok<AGROW>
        end
        if rho_failed
            conclusion_parts{end+1} = '非完全相干场景下需要受约束 full covariance fitting 或 MUSIC/混合策略'; %#ok<AGROW>
        end
        if extreme_failed
            conclusion_parts{end+1} = '组合极端场景验证了上述失配会叠加放大'; %#ok<AGROW>
        end
        main_conclusion = [strjoin(conclusion_parts, '；'), '。'];
    end

    diagnosis = struct();
    diagnosis.group_names = group_names;
    diagnosis.group_min_tol_high = group_min_tol_high;
    diagnosis.group_min_tol_all = group_min_tol_all;
    diagnosis.group_worst_case_high = group_worst_case_high;
    diagnosis.high_snr_db = snr_list(idxHigh);
    diagnosis.route_names = route_names;
    diagnosis.need_complex_gain = need_complex_gain;
    diagnosis.need_constrained_covfit = need_constrained_covfit;
    diagnosis.need_level3 = need_level3;
    diagnosis.amp_failed = amp_failed;
    diagnosis.elevation_failed = elev_failed;
    diagnosis.el_assumed_failed = el0_failed;
    diagnosis.phase_failed = phase_failed;
    diagnosis.rho_failed = rho_failed;
    diagnosis.extreme_failed = extreme_failed;
    diagnosis.main_conclusion = main_conclusion;
end

function plot_stress_group_tol_local(path_out, stress_cases, metrics, route_names, snr_list, group_name, x_field, idx_rank1)
    idx = find(strcmp({stress_cases.stress_group}, group_name));
    x = [stress_cases(idx).(x_field)];
    [x, ord] = sort(x);
    idx = idx(ord);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1100, 560]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iSNR = 1:numel(snr_list)
        plot(x, squeeze(metrics.tol_success_rate_abs01(idx_rank1, idx, 1, iSNR)), '-o', 'LineWidth', 1.2);
        hold on
    end
    yline(0.9, '--k');
    hold off
    grid on
    ylim([0, 1.05]);
    xlabel(x_field, 'Interpreter', 'none');
    ylabel('rank1 tol abs01');
    title(sprintf('%s rank1 stress', group_name), 'Interpreter', 'none');
    legend(compose('SNR=%g', snr_list), 'Location', 'best');

    nexttile
    idxHigh = numel(snr_list);
    for iroute = 1:numel(route_names)
        plot(x, squeeze(metrics.tol_success_rate_abs01(iroute, idx, 1, idxHigh)), '-o', 'LineWidth', 1.2);
        hold on
    end
    yline(0.9, '--k');
    hold off
    grid on
    ylim([0, 1.05]);
    xlabel(x_field, 'Interpreter', 'none');
    ylabel(sprintf('tol abs01 at SNR=%g dB', snr_list(idxHigh)));
    title('route comparison at highest SNR');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_extreme_cases_tol_local(path_out, stress_cases, metrics, route_names, snr_list, idx_rank1)
    idx = find(strcmp({stress_cases.stress_group}, 'extreme_combo'));
    labels = {stress_cases(idx).case_name};
    x = 1:numel(idx);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1180, 620]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iSNR = 1:numel(snr_list)
        plot(x, squeeze(metrics.tol_success_rate_abs01(idx_rank1, idx, 1, iSNR)), '-o', 'LineWidth', 1.2);
        hold on
    end
    yline(0.9, '--k');
    hold off
    grid on
    ylim([0, 1.05]);
    xticks(x);
    xticklabels(compose('case %c', 'A' + (0:numel(idx)-1)));
    ylabel('rank1 tol abs01');
    title('extreme cases rank1 stress');
    legend(compose('SNR=%g', snr_list), 'Location', 'best');

    nexttile
    idxHigh = numel(snr_list);
    for iroute = 1:numel(route_names)
        plot(x, squeeze(metrics.tol_success_rate_abs01(iroute, idx, 1, idxHigh)), '-o', 'LineWidth', 1.2);
        hold on
    end
    yline(0.9, '--k');
    hold off
    grid on
    ylim([0, 1.05]);
    xticks(x);
    xticklabels(compose('case %c', 'A' + (0:numel(idx)-1)));
    ylabel(sprintf('tol abs01 at SNR=%g dB', snr_list(idxHigh)));
    title('route comparison at highest SNR');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    annotation(fig, 'textbox', [0.08, 0.01, 0.85, 0.08], 'String', strjoin(labels, ' | '), ...
        'Interpreter', 'none', 'EdgeColor', 'none', 'FontSize', 8);
    saveas(fig, path_out);
    close(fig);
end

function write_engineering_record_doc_local(path_out, params, route_names, stress_cases, metrics, diagnosis, summary_path, keypoints_path, mat_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    idxRank1 = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    idxHigh = find(params.snr_list == diagnosis.high_snr_db, 1);

    fprintf(fid, '# 第8.6步 层次二第七部分：rank1协方差拟合工程压力测试记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 公式文档：`%s`\n', params.formula_doc_path);
    fprintf(fid, '- 第六部分 finalscan 脚本：`%s`\n', params.sixth_script_path);
    fprintf(fid, '- 第六部分 summary/keypoints：`%s`, `%s`\n', params.sixth_summary_csv, params.sixth_keypoints_csv);
    fprintf(fid, '- 本轮只做层次二第七部分 A：rank1 equal-phase covfit 工程场景压力测试。不做层次三、2D az/el MUSIC、complex-gain covfit、phase-scan covfit 或 constrained covariance fitting。\n\n');

    fprintf(fid, '## 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi=%d`, `P_phi=%d`, `sep_factor=%d`, `theta_sep=%.6f deg`。\n', ...
        params.Q, params.K_phi, params.P_phi, params.sep_factor, params.theta_sep);
    fprintf(fid, '- `SNR_list=%s`, `Metkl=%d`, `T_snap=%d`, `base_seed=%d`。\n', ...
        mat2str(params.snr_list), params.Metkl, params.T_snap, params.base_seed);
    fprintf(fid, '- 第六部分基准：rank1 sep=10 `SNR90_abs01=%s`, `tol(-4 dB)=%.3f`。\n\n', ...
        params.sixth_benchmark.rank1_snr90_abs01_label, params.sixth_benchmark.rank1_tol_abs01_low_snr);

    fprintf(fid, '## Route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 六组压力测试结果\n\n');
    fprintf(fid, '| stress_group | worst_case_at_%gdB | min_rank1_tol_%gdB | min_rank1_tol_all_SNR |\n', diagnosis.high_snr_db, diagnosis.high_snr_db);
    fprintf(fid, '|---|---|---:|---:|\n');
    for ig = 1:numel(diagnosis.group_names)
        fprintf(fid, '| `%s` | `%s` | %.3f | %.3f |\n', diagnosis.group_names{ig}, ...
            diagnosis.group_worst_case_high{ig}, diagnosis.group_min_tol_high(ig), diagnosis.group_min_tol_all(ig));
    end
    fprintf(fid, '\n');

    fprintf(fid, '### 幅度比压力测试\n\n');
    write_group_detail_table_local(fid, stress_cases, metrics, idxRank1, 'amplitude_ratio', params.snr_list, idxHigh);
    fprintf(fid, '- 对幅度比是否敏感：%s。\n\n', yesno_local(diagnosis.amp_failed));

    fprintf(fid, '### 俯仰差压力测试\n\n');
    write_group_detail_table_local(fid, stress_cases, metrics, idxRank1, 'elevation_difference', params.snr_list, idxHigh);
    fprintf(fid, '- 对大俯仰差是否敏感：%s。\n\n', yesno_local(diagnosis.elevation_failed));

    fprintf(fid, '### 俯仰先验误差测试\n\n');
    write_group_detail_table_local(fid, stress_cases, metrics, idxRank1, 'el_assumed_mismatch', params.snr_list, idxHigh);
    fprintf(fid, '- 对 el_assumed 误差是否敏感：%s。\n\n', yesno_local(diagnosis.el_assumed_failed));

    fprintf(fid, '### 固定相位偏置扩展测试\n\n');
    write_group_detail_table_local(fid, stress_cases, metrics, idxRank1, 'phase_offset', params.snr_list, idxHigh);
    fprintf(fid, '- 对固定相位偏置是否敏感：%s。\n\n', yesno_local(diagnosis.phase_failed));

    fprintf(fid, '### 非完全相干度测试\n\n');
    write_group_detail_table_local(fid, stress_cases, metrics, idxRank1, 'coherence_rho', params.snr_list, idxHigh);
    fprintf(fid, '- 对 rho<1 非完全相干是否敏感：%s。\n\n', yesno_local(diagnosis.rho_failed));

    fprintf(fid, '### 少量组合极端场景\n\n');
    write_group_detail_table_local(fid, stress_cases, metrics, idxRank1, 'extreme_combo', params.snr_list, idxHigh);
    fprintf(fid, '- 组合极端场景是否暴露额外失败：%s。\n\n', yesno_local(diagnosis.extreme_failed));

    fprintf(fid, '## 工程适用边界\n\n');
    fprintf(fid, '- 哪些工程工况仍适用：在 `SNR=%g dB` 下 rank1 tol_abs01 >= 0.9 的场景可视为本轮压力测试内适用，详见上表。\n', diagnosis.high_snr_db);
    fprintf(fid, '- 哪些工况需要扩展算法：幅度比失败对应 complex-gain，固定相位失败对应 phase-grid/complex-gain，rho<1 失败对应 constrained covariance fitting 或混合策略，俯仰差/先验误差失败对应层次三。\n');
    fprintf(fid, '- 是否需要 complex-gain covfit：%s。\n', yesno_local(diagnosis.need_complex_gain));
    fprintf(fid, '- 是否需要 constrained covariance fitting：%s。\n', yesno_local(diagnosis.need_constrained_covfit));
    fprintf(fid, '- 是否出现层次三必要性：%s。\n\n', yesno_local(diagnosis.need_level3));

    fprintf(fid, '## 主结论\n\n');
    fprintf(fid, '%s\n\n', diagnosis.main_conclusion);

    fprintf(fid, '## 输出文件\n\n');
    fprintf(fid, '- summary：`%s`\n', summary_path);
    fprintf(fid, '- keypoints：`%s`\n', keypoints_path);
    fprintf(fid, '- MAT：`%s`\n', mat_path);
    fprintf(fid, '- figures：`stress_amplitude_ratio_tol.png`, `stress_elevation_sep_tol.png`, `stress_el_assumed_mismatch_tol.png`, `stress_phase_offset_tol.png`, `stress_rho_tol.png`, `stress_extreme_cases_tol.png`\n');
end

function write_group_detail_table_local(fid, stress_cases, metrics, idxRank1, group_name, snr_list, idxHigh)
    idx = find(strcmp({stress_cases.stress_group}, group_name));
    fprintf(fid, '| case | value | beta | el_b | el_assumed | phase | rho | tol@%gdB | SNR90_abs01 | mean_sep_err@%gdB |\n', ...
        snr_list(idxHigh), snr_list(idxHigh));
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---|---:|\n');
    for ii = 1:numel(idx)
        ic = idx(ii);
        sc = stress_cases(ic);
        fprintf(fid, '| `%s` | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %s | %.5f |\n', ...
            sc.case_name, sc.stress_value, sc.beta, sc.el_b_deg, sc.el_assumed_deg, ...
            sc.phase_offset_deg, sc.rho, metrics.tol_success_rate_abs01(idxRank1, ic, 1, idxHigh), ...
            metrics.snr90_abs01_label{idxRank1, ic, 1}, ...
            metrics.mean_abs_pair_sep_error(idxRank1, ic, 1, idxHigh));
    end
    fprintf(fid, '\n');
end

function seventh_benchmark = summarize_seventh_part_benchmark_local(seventh_summary_tbl)
    route_col = string(seventh_summary_tbl.route_name);
    case_col = string(seventh_summary_tbl.case_name);
    mask_rank1 = route_col == "covfit_rank1_equal_phase" & seventh_summary_tbl.snr_db == 8;
    seventh_benchmark = struct();
    seventh_benchmark.beta03_tol_8dB = extract_case_tol_local(seventh_summary_tbl, mask_rank1, case_col, "beta_0p3");
    seventh_benchmark.beta01_tol_8dB = extract_case_tol_local(seventh_summary_tbl, mask_rank1, case_col, "beta_0p1");
    seventh_benchmark.phase150_tol_8dB = extract_case_tol_local(seventh_summary_tbl, mask_rank1, case_col, "phase_150");
    seventh_benchmark.phase180_tol_8dB = extract_case_tol_local(seventh_summary_tbl, mask_rank1, case_col, "phase_180");
end

function out = extract_case_tol_local(tbl, mask, case_col, case_name)
    idx = mask & case_col == case_name;
    if any(idx)
        out = tbl.tol_success_rate_abs01(find(idx, 1));
    else
        out = NaN;
    end
end

function summary_rows = build_complex_gain_summary_rows_local(route_names, stress_cases, K_phi, P_phi, sep_factor, theta_sep_deg, snr_list, metrics)
    summary_rows = {};
    for iCase = 1:numel(stress_cases)
        sc = stress_cases(iCase);
        for iroute = 1:numel(route_names)
            for iSNR = 1:numel(snr_list)
                failure_rate = 1 - metrics.tol_success_rate_abs01(iroute, iCase, 1, iSNR);
                summary_rows(end+1, :) = { ...
                    sc.stress_group, sc.case_name, sc.stress_value, sc.beta, sc.phase_offset_deg, sc.rho, ...
                    route_names{iroute}, K_phi, P_phi, sep_factor, theta_sep_deg, snr_list(iSNR), ...
                    metrics.raw_success_rate(iroute, iCase, 1, iSNR), ...
                    metrics.tol_success_rate_abs01(iroute, iCase, 1, iSNR), ...
                    metrics.tol_success_rate_rel025(iroute, iCase, 1, iSNR), ...
                    metrics.rmse_deg(iroute, iCase, 1, iSNR), ...
                    metrics.mean_abs_pair_sep_error(iroute, iCase, 1, iSNR), ...
                    metrics.mean_abs_pair_center_error(iroute, iCase, 1, iSNR), ...
                    metrics.snr90_abs01(iroute, iCase, 1), ...
                    metrics.snr90_abs01_label{iroute, iCase, 1}, ...
                    metrics.snr90_rel025(iroute, iCase, 1), ...
                    metrics.snr90_rel025_label{iroute, iCase, 1}, ...
                    failure_rate, ...
                    metrics.mean_beta_hat(iroute, iCase, 1, iSNR), ...
                    metrics.std_beta_hat(iroute, iCase, 1, iSNR), ...
                    metrics.mean_beta_error(iroute, iCase, 1, iSNR), ...
                    metrics.mean_abs_beta_error(iroute, iCase, 1, iSNR), ...
                    metrics.mean_phi_hat_deg(iroute, iCase, 1, iSNR), ...
                    metrics.std_phi_hat_deg(iroute, iCase, 1, iSNR), ...
                    metrics.mean_phi_error_deg(iroute, iCase, 1, iSNR), ...
                    metrics.mean_abs_phi_error_deg(iroute, iCase, 1, iSNR), ...
                    metrics.q_grid_hit_boundary_rate(iroute, iCase, 1, iSNR), ...
                    metrics.angle_swap_rate(iroute, iCase, 1, iSNR), ...
                    metrics.objective_true_rank_median(iroute, iCase, 1, iSNR), ...
                    metrics.objective_true_rank_p90(iroute, iCase, 1, iSNR), ...
                    metrics.objective_margin_true_vs_best(iroute, iCase, 1, iSNR), ...
                    metrics.mean_alpha_hat(iroute, iCase, 1, iSNR), ...
                    metrics.mean_sigma2_hat(iroute, iCase, 1, iSNR), ...
                    sc.model_mismatch_flag}; %#ok<AGROW>
            end
        end
    end
end

function keypoint_rows = filter_complex_gain_keypoint_rows_local(summary_rows)
    keypoint_rows = {};
    for ii = 1:size(summary_rows, 1)
        group_name = summary_rows{ii, 1};
        route_name = summary_rows{ii, 7};
        snr_db = summary_rows{ii, 12};
        keep = strcmp(route_name, 'covfit_rank1_complex_gain_grid') || ...
            strcmp(group_name, 'beta_phase_combo') || any(snr_db == [-4, 8]);
        if keep
            keypoint_rows(end+1, :) = summary_rows(ii, :); %#ok<AGROW>
        end
    end
end

function write_complex_gain_summary_csv_local(path_out, rows)
    header = {'stress_group', 'case_name', 'stress_value', 'beta_true', 'phase_true_deg', 'rho', ...
        'route_name', 'K_phi', 'P_phi', 'sep_factor', 'theta_sep_deg', 'snr_db', ...
        'raw_success_rate', 'tol_success_rate_abs01', 'tol_success_rate_rel025', 'rmse_deg', ...
        'mean_pair_sep_error', 'mean_pair_center_error', 'snr90_abs01', 'snr90_abs01_label', ...
        'snr90_rel025', 'snr90_rel025_label', 'failure_rate', ...
        'mean_beta_hat', 'std_beta_hat', 'mean_beta_error', 'mean_abs_beta_error', ...
        'mean_phi_hat_deg', 'std_phi_hat_deg', 'mean_phi_error_deg', 'mean_abs_phi_error_deg', ...
        'q_grid_hit_boundary_rate', 'angle_swap_rate', 'objective_true_rank_median', ...
        'objective_true_rank_p90', 'objective_margin_true_vs_best', 'mean_alpha_hat', ...
        'mean_sigma2_hat', 'model_mismatch_flag'};
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(header, ','));
    for ii = 1:size(rows, 1)
        vals = cell(1, numel(header));
        for jj = 1:numel(header)
            vals{jj} = csv_value_local(rows{ii, jj});
        end
        fprintf(fid, '%s\n', strjoin(vals, ','));
    end
end

function diagnosis = choose_complex_gain_diagnosis_local(metrics, stress_cases, route_names, snr_list, idx_equal, idx_complex)
    idxHigh = find(snr_list == max(snr_list), 1);
    idxAmp03 = find(strcmp({stress_cases.case_name}, 'beta_0p3'), 1);
    idxAmp01 = find(strcmp({stress_cases.case_name}, 'beta_0p1'), 1);
    idxAmp1 = find(strcmp({stress_cases.case_name}, 'beta_1'), 1);
    idxPh0 = find(strcmp({stress_cases.case_name}, 'phase_0'), 1);
    idxPh150 = find(strcmp({stress_cases.case_name}, 'phase_150'), 1);
    idxPh180 = find(strcmp({stress_cases.case_name}, 'phase_180'), 1);

    beta03_tol = metrics.tol_success_rate_abs01(idx_complex, idxAmp03, 1, idxHigh);
    beta01_tol = metrics.tol_success_rate_abs01(idx_complex, idxAmp01, 1, idxHigh);
    phase150_tol = metrics.tol_success_rate_abs01(idx_complex, idxPh150, 1, idxHigh);
    phase180_tol = metrics.tol_success_rate_abs01(idx_complex, idxPh180, 1, idxHigh);
    beta1_tol_complex = metrics.tol_success_rate_abs01(idx_complex, idxAmp1, 1, idxHigh);
    beta1_tol_equal = metrics.tol_success_rate_abs01(idx_equal, idxAmp1, 1, idxHigh);
    phase0_tol_complex = metrics.tol_success_rate_abs01(idx_complex, idxPh0, 1, idxHigh);
    phase0_tol_equal = metrics.tol_success_rate_abs01(idx_equal, idxPh0, 1, idxHigh);

    beta_repaired = beta03_tol >= 0.9;
    phase_repaired = min(phase150_tol, phase180_tol) >= 0.9;
    beta01_recovered = beta01_tol >= 0.5;
    baseline_not_worse = beta1_tol_complex >= beta1_tol_equal - 0.05 && phase0_tol_complex >= phase0_tol_equal - 0.05;
    boundary_significant = nanmax_flat_local(metrics.q_grid_hit_boundary_rate(idx_complex, :, 1, idxHigh)) > 0.5;
    angle_swap_significant = nanmax_flat_local(metrics.angle_swap_rate(idx_complex, :, 1, idxHigh)) > 0.2;

    beta_reasonable = nanmax_flat_local(metrics.mean_abs_beta_error(idx_complex, [idxAmp1, idxAmp03], 1, idxHigh)) <= 0.35;
    phi_reasonable = nanmax_flat_local(metrics.mean_abs_phi_error_deg(idx_complex, [idxPh0, idxPh150, idxPh180], 1, idxHigh)) <= 35;

    if beta_repaired && phase_repaired && baseline_not_worse
        main_conclusion = 'complex-gain rank1 成功扩展了层次二完全相干模型的幅度/相位适用范围，应作为 V1 层次二主模型候选；但第七部分中大俯仰差与俯仰先验误差边界仍然存在，后续应在 V1 成功后回到工程压力测试，再决定何时进入层次三。';
        next_step = '先用 V1 complex-gain 重跑第七部分工程压力测试，再决定是否进入层次三。';
    elseif beta_repaired && ~phase_repaired
        main_conclusion = '幅度失配可以通过 complex-gain 修复，但反相场景仍需要更细 phase grid、label-symmetric q 搜索或相位正则。';
        next_step = '优先做 finer phase grid 和 label-symmetric q 搜索，再回到工程压力测试。';
    elseif ~beta_repaired && phase_repaired
        main_conclusion = '固定相位偏置可以通过 complex-gain 修复，但强弱目标不平衡仍需要 log-beta grid、目标标签对称处理或弱目标正则。';
        next_step = '优先做 log-beta 或 label-symmetric q 搜索，再回到工程压力测试。';
    elseif ~baseline_not_worse
        main_conclusion = 'q 搜索引入了额外自由度和错误极小值，当前 complex-gain 还不能直接替代 V0，需要先改 q 估计策略。';
        next_step = '先约束 q 搜索，再考虑是否继续扩大工程验证范围。';
    else
        main_conclusion = '当前 complex-gain 只带来有限修复，尚不足以稳定覆盖层次二的一般模型边界。';
        next_step = '先优化 q 搜索与标签对称处理，再决定是否重跑工程压力测试。';
    end

    diagnosis = struct();
    diagnosis.high_snr_db = snr_list(idxHigh);
    diagnosis.beta_repaired = beta_repaired;
    diagnosis.phase_repaired = phase_repaired;
    diagnosis.beta01_recovered = beta01_recovered;
    diagnosis.baseline_not_worse = baseline_not_worse;
    diagnosis.beta_reasonable = beta_reasonable;
    diagnosis.phi_reasonable = phi_reasonable;
    diagnosis.boundary_significant = boundary_significant;
    diagnosis.angle_swap_significant = angle_swap_significant;
    diagnosis.beta03_tol_8dB = beta03_tol;
    diagnosis.beta01_tol_8dB = beta01_tol;
    diagnosis.phase150_tol_8dB = phase150_tol;
    diagnosis.phase180_tol_8dB = phase180_tol;
    diagnosis.beta1_tol_complex_8dB = beta1_tol_complex;
    diagnosis.beta1_tol_equal_8dB = beta1_tol_equal;
    diagnosis.phase0_tol_complex_8dB = phase0_tol_complex;
    diagnosis.phase0_tol_equal_8dB = phase0_tol_equal;
    diagnosis.main_conclusion = main_conclusion;
    diagnosis.next_step = next_step;
end

function plot_complex_gain_estimation_local(path_out, stress_cases, metrics, group_name, x_field, metric_field, aux_field, idx_complex)
    idx = find(strcmp({stress_cases.stress_group}, group_name));
    x = [stress_cases(idx).(x_field)];
    [x, ord] = sort(x);
    idx = idx(ord);
    snr_list = metrics.snr_list;
    idxHigh = find(snr_list == max(snr_list), 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1100, 460]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    plot(x, squeeze(metrics.(metric_field)(idx_complex, idx, 1, idxHigh)), '-o', 'LineWidth', 1.3);
    grid on
    xlabel(x_field, 'Interpreter', 'none');
    ylabel(metric_field, 'Interpreter', 'none');
    title(sprintf('%s @ SNR=%g dB', metric_field, snr_list(idxHigh)), 'Interpreter', 'none');
    nexttile
    plot(x, squeeze(metrics.(aux_field)(idx_complex, idx, 1, idxHigh)), '-o', 'LineWidth', 1.3);
    grid on
    xlabel(x_field, 'Interpreter', 'none');
    ylabel(aux_field, 'Interpreter', 'none');
    title(sprintf('%s @ SNR=%g dB', aux_field, snr_list(idxHigh)), 'Interpreter', 'none');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function plot_case_group_tol_local(path_out, stress_cases, metrics, route_names, snr_list, idx_route, group_name)
    idx = find(strcmp({stress_cases.stress_group}, group_name));
    labels = {stress_cases(idx).case_name};
    fig = figure('Visible', 'off', 'Position', [100, 100, 1180, 520]);
    tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    nexttile
    for iSNR = 1:numel(snr_list)
        plot(1:numel(idx), squeeze(metrics.tol_success_rate_abs01(idx_route, idx, 1, iSNR)), '-o', 'LineWidth', 1.2);
        hold on
    end
    yline(0.9, '--k');
    hold off
    grid on
    ylim([0, 1.05]);
    xticks(1:numel(idx));
    xticklabels(labels);
    xtickangle(20);
    ylabel(sprintf('%s tol abs01', route_names{idx_route}), 'Interpreter', 'none');
    title(sprintf('%s across SNR', group_name), 'Interpreter', 'none');
    legend(compose('SNR=%g', snr_list), 'Location', 'best');
    nexttile
    idxHigh = numel(snr_list);
    for iroute = 1:numel(route_names)
        plot(1:numel(idx), squeeze(metrics.tol_success_rate_abs01(iroute, idx, 1, idxHigh)), '-o', 'LineWidth', 1.2);
        hold on
    end
    yline(0.9, '--k');
    hold off
    grid on
    ylim([0, 1.05]);
    xticks(1:numel(idx));
    xticklabels(labels);
    xtickangle(20);
    ylabel(sprintf('tol abs01 @ SNR=%g dB', snr_list(idxHigh)));
    title('All routes at highest SNR');
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function write_generalized_covfit_theory_doc_local(path_out, params)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# 第8.6步 层次二广义相干协方差拟合模型说明\n\n');
    fprintf(fid, '## 1. 读取范围\n\n');
    fprintf(fid, '- 修改方向：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 公式文档：`%s`\n', params.formula_doc_path);
    fprintf(fid, '- 第六部分 finalscan：`%s`\n', params.sixth_record_path);
    fprintf(fid, '- 第七部分工程压力测试：`%s`\n\n', params.seventh_record_path);
    fprintf(fid, '## 2. 为什么 V0 equal-phase rank1 过于理想\n\n');
    fprintf(fid, '第六部分的理想模型使用\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, 'c_p=b_p(\\theta_1)+b_p(\\theta_2)\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '它等价于：`beta=1`、`phi=0`、`rho=1`。第七部分工程压力测试已经证明，这个假设只能作为 V0 特例：\n\n');
    fprintf(fid, '- `beta=0.3` 时 rank1 equal-phase 在 `SNR=8 dB` 的 `tol_abs01=%.3f`；\n', params.seventh_benchmark.beta03_tol_8dB);
    fprintf(fid, '- `beta=0.1` 时 rank1 equal-phase 在 `SNR=8 dB` 的 `tol_abs01=%.3f`；\n', params.seventh_benchmark.beta01_tol_8dB);
    fprintf(fid, '- `phase=150 deg` 时 rank1 equal-phase 在 `SNR=8 dB` 的 `tol_abs01=%.3f`；\n', params.seventh_benchmark.phase150_tol_8dB);
    fprintf(fid, '- `phase=180 deg` 时 rank1 equal-phase 在 `SNR=8 dB` 的 `tol_abs01=%.3f`；\n', params.seventh_benchmark.phase180_tol_8dB);
    fprintf(fid, '- 更大的俯仰差与 `el_assumed` 偏差也在第七部分中失败，因此 V0 不能继续当作最终工程主模型。\n\n');
    fprintf(fid, '## 3. 广义相干双源模型\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, 'y(t)=b(\\theta_1,e_1;e_0)s_1(t)+b(\\theta_2,e_2;e_0)s_2(t)+n(t)\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, 'R_s=\\begin{bmatrix}\n');
    fprintf(fid, 'P_1 & \\rho\\sqrt{P_1P_2}e^{j\\phi}\\\\\n');
    fprintf(fid, '\\rho\\sqrt{P_1P_2}e^{-j\\phi} & P_2\n');
    fprintf(fid, '\\end{bmatrix}\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, 'R_{FB,model}=FBSS\\{BR_sB^H+\\sigma^2I\\}\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '其中 `b(\\theta,e;e0)` 是 65 列动态工作子阵经过视轴归一化与 32 层俯仰相干合成后的层次二等效 steering。\n\n');
    fprintf(fid, '## 4. 模型层级\n\n');
    fprintf(fid, '### V0：equal-phase rank1\n\n');
    fprintf(fid, '- `P1=P2`，`rho=1`，`phi=0`\n');
    fprintf(fid, '- 仅用于证明 rank1 covfit 能突破 MUSIC 双峰合并上限。\n\n');
    fprintf(fid, '### V1：complex-gain rank1\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, 'c_p=b_p(\\theta_1)+q\\,b_p(\\theta_2),\\quad q=\\beta e^{j\\phi}\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '- 仍假设 `rho=1`；\n');
    fprintf(fid, '- 允许 `P1!=P2` 和 `phi!=0`；\n');
    fprintf(fid, '- 本轮第八部分只实现这个模型。\n\n');
    fprintf(fid, '### V2：constrained covariance fitting\n\n');
    fprintf(fid, '- `0<=rho<=1`，`Rs` 保持 PSD；\n');
    fprintf(fid, '- 仅在部分相干或 `rho<1` 出现问题时再推进。\n\n');
    fprintf(fid, '### V3：2D az/el coherent covfit\n\n');
    fprintf(fid, '- 仅用于大俯仰差、俯仰先验不可靠、必须保留 65x32 二维信息的场景；\n');
    fprintf(fid, '- 本轮不展开层次三。\n\n');
    fprintf(fid, '## 5. 本轮 V1 的协方差拟合形式\n\n');
    fprintf(fid, '对每个候选 `theta1<theta2` 和 `q=beta exp(j phi)`：\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, 'G_F(\\theta_1,\\theta_2,q)=\\frac{1}{P_\\phi}\\sum_{p=1}^{P_\\phi} c_pc_p^H\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, 'G_{FB}=\\frac{1}{2}(G_F+J\\,conj(G_F)\\,J)\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '$$\n');
    fprintf(fid, '\\min_{\\alpha\\ge 0,\\sigma^2\\ge 0}\\frac{\\|\\widehat R_{FB}-\\alpha G_{FB}-\\sigma^2I\\|_F^2}{\\|\\widehat R_{FB}\\|_F^2}\n');
    fprintf(fid, '$$\n\n');
    fprintf(fid, '本轮用有限网格 `beta_grid=%s`、`phi_grid_deg=%s`，仍然只做层次二一维方位 pair search。\n\n', ...
        mat2str(params.beta_grid), mat2str(params.phi_grid_deg));
    fprintf(fid, '## 6. 本轮范围\n\n');
    fprintf(fid, '- 只做层次二一维方位；\n');
    fprintf(fid, '- 不做 constrained covariance fitting；\n');
    fprintf(fid, '- 不做 2D az/el；\n');
    fprintf(fid, '- 不做层次三；\n');
    fprintf(fid, '- 目标是修复第七部分暴露出的幅度比失配和固定相位偏置边界。\n');
end

function write_complex_gain_record_doc_local(path_out, params, route_names, stress_cases, metrics, diagnosis, summary_path, keypoints_path, mat_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    idxEqual = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    idxComplex = find(strcmp(route_names, 'covfit_rank1_complex_gain_grid'), 1);
    idxHigh = find(params.snr_list == diagnosis.high_snr_db, 1);
    fprintf(fid, '# 第8.6步 层次二第八部分：complex-gain 协方差拟合验证记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 公式文档：`%s`\n', params.formula_doc_path);
    fprintf(fid, '- 新增理论文档：`%s`\n', params.theory_doc_path);
    fprintf(fid, '- 第六部分 finalscan：`%s`\n', params.sixth_record_path);
    fprintf(fid, '- 第七部分工程压力测试：`%s`\n', params.seventh_record_path);
    fprintf(fid, '- 本轮只做层次二 V1：`covfit_rank1_complex_gain_grid`。不做层次三、2D az/el、constrained covariance fitting 或 fullscan。\n\n');
    fprintf(fid, '## 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi=%d`, `P_phi=%d`, `sep_factor=%d`, `theta_sep=%.6f deg`。\n', ...
        params.Q, params.K_phi, params.P_phi, params.sep_factor, params.theta_sep);
    fprintf(fid, '- `SNR_list=%s`, `Metkl=%d`, `T_snap=%d`, `base_seed=%d`。\n', ...
        mat2str(params.snr_list), params.Metkl, params.T_snap, params.base_seed);
    fprintf(fid, '- `beta_grid=%s`。\n', mat2str(params.beta_grid));
    fprintf(fid, '- `phi_grid_deg=%s`。\n\n', mat2str(params.phi_grid_deg));
    fprintf(fid, '## Route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');
    fprintf(fid, '## 第七部分到第八部分的目标变化\n\n');
    fprintf(fid, '- 第七部分暴露的 equal-phase 失配基准：`beta=0.3` 在 `8 dB` 时 tol=%.3f，`beta=0.1` 时 tol=%.3f，`phase=150/180 deg` 时 tol=%.3f / %.3f。\n', ...
        params.seventh_benchmark.beta03_tol_8dB, params.seventh_benchmark.beta01_tol_8dB, ...
        params.seventh_benchmark.phase150_tol_8dB, params.seventh_benchmark.phase180_tol_8dB);
    fprintf(fid, '- 第八部分只尝试修复一维幅相失配，不把俯仰差混入主实验。\n\n');
    fprintf(fid, '## 实验 1：幅度比修复\n\n');
    write_complex_group_table_local(fid, stress_cases, metrics, route_names, 'amplitude_ratio', params.snr_list, idxHigh, idxEqual, idxComplex);
    fprintf(fid, '- `beta=0.3` 在 `8 dB` 的 complex-gain tol=%.3f。\n', diagnosis.beta03_tol_8dB);
    fprintf(fid, '- `beta=0.1` 在 `8 dB` 的 complex-gain tol=%.3f。\n', diagnosis.beta01_tol_8dB);
    fprintf(fid, '- `beta_hat` 是否整体合理：%s。\n\n', yesno_local(diagnosis.beta_reasonable));
    fprintf(fid, '## 实验 2：固定相位偏置修复\n\n');
    write_complex_group_table_local(fid, stress_cases, metrics, route_names, 'phase_offset', params.snr_list, idxHigh, idxEqual, idxComplex);
    fprintf(fid, '- `phase=150/180 deg` 在 `8 dB` 的 complex-gain tol=%.3f / %.3f。\n', diagnosis.phase150_tol_8dB, diagnosis.phase180_tol_8dB);
    fprintf(fid, '- `phi_hat` 是否整体合理：%s。\n\n', yesno_local(diagnosis.phi_reasonable));
    fprintf(fid, '## 实验 3：beta+phase 小组合\n\n');
    write_complex_group_table_local(fid, stress_cases, metrics, route_names, 'beta_phase_combo', params.snr_list, idxHigh, idxEqual, idxComplex);
    fprintf(fid, '## 关键诊断\n\n');
    fprintf(fid, '- complex-gain 是否修复 `beta=0.3`：%s。\n', yesno_local(diagnosis.beta_repaired));
    fprintf(fid, '- complex-gain 是否修复 `phase=150/180 deg`：%s。\n', yesno_local(diagnosis.phase_repaired));
    fprintf(fid, '- `beta=1` / `phase=0` 是否明显差于 equal-phase：%s。\n', yesno_local(~diagnosis.baseline_not_worse));
    fprintf(fid, '- `q_grid_hit_boundary_rate` 是否显著：%s。\n', yesno_local(diagnosis.boundary_significant));
    fprintf(fid, '- `angle_swap_rate` 是否显著：%s。\n\n', yesno_local(diagnosis.angle_swap_significant));
    fprintf(fid, '## 主结论\n\n');
    fprintf(fid, '%s\n\n', diagnosis.main_conclusion);
    fprintf(fid, '## 下一步\n\n');
    fprintf(fid, '%s\n\n', diagnosis.next_step);
    fprintf(fid, '## 输出文件\n\n');
    fprintf(fid, '- summary：`%s`\n', summary_path);
    fprintf(fid, '- keypoints：`%s`\n', keypoints_path);
    fprintf(fid, '- MAT：`%s`\n', mat_path);
    fprintf(fid, '- figures：`complex_gain_amplitude_ratio_tol.png`, `complex_gain_phase_offset_tol.png`, `complex_gain_beta_est_error.png`, `complex_gain_phi_est_error.png`, `complex_gain_combo_cases_tol.png`\n');
end

function write_complex_group_table_local(fid, stress_cases, metrics, route_names, group_name, snr_list, idxHigh, idxEqual, idxComplex)
    idx = find(strcmp({stress_cases.stress_group}, group_name));
    idxCenter = find(strcmp(route_names, 'center_real'), 1);
    idxMin = find(strcmp(route_names, 'min_den_fb'), 1);
    fprintf(fid, '| case | beta | phase | center_real | min_den_fb | equal_phase | complex_gain | complex SNR90 | beta_hat | abs beta err | phi_hat | abs phi err | boundary | swap |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|\n');
    for ii = 1:numel(idx)
        ic = idx(ii);
        fprintf(fid, '| `%s` | %.3f | %.1f | %.3f | %.3f | %.3f | %.3f | %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
            stress_cases(ic).case_name, stress_cases(ic).beta, stress_cases(ic).phase_offset_deg, ...
            metrics.tol_success_rate_abs01(idxCenter, ic, 1, idxHigh), ...
            metrics.tol_success_rate_abs01(idxMin, ic, 1, idxHigh), ...
            metrics.tol_success_rate_abs01(idxEqual, ic, 1, idxHigh), ...
            metrics.tol_success_rate_abs01(idxComplex, ic, 1, idxHigh), ...
            metrics.snr90_abs01_label{idxComplex, ic, 1}, ...
            metrics.mean_beta_hat(idxComplex, ic, 1, idxHigh), ...
            metrics.mean_abs_beta_error(idxComplex, ic, 1, idxHigh), ...
            metrics.mean_phi_hat_deg(idxComplex, ic, 1, idxHigh), ...
            metrics.mean_abs_phi_error_deg(idxComplex, ic, 1, idxHigh), ...
            metrics.q_grid_hit_boundary_rate(idxComplex, ic, 1, idxHigh), ...
            metrics.angle_swap_rate(idxComplex, ic, 1, idxHigh));
    end
    fprintf(fid, '\n');
end

function baseline = summarize_part8_baseline_local(part8_summary_tbl)
    route_col = string(part8_summary_tbl.route_name);
    case_col = string(part8_summary_tbl.case_name);
    mask = route_col == "covfit_rank1_complex_gain_grid" & part8_summary_tbl.snr_db == 8;
    baseline = struct();
    baseline.beta03_tol_8dB = extract_case_tol_local(part8_summary_tbl, mask, case_col, "beta_0p3");
    baseline.beta01_tol_8dB = extract_case_tol_local(part8_summary_tbl, mask, case_col, "beta_0p1");
    baseline.phase150_tol_8dB = extract_case_tol_local(part8_summary_tbl, mask, case_col, "phase_150");
    baseline.phase180_tol_8dB = extract_case_tol_local(part8_summary_tbl, mask, case_col, "phase_180");
end

function q_grid_info_norm = build_q_grid_info_normalized_local(q_grid_info)
    q_grid_info_norm = q_grid_info;
    q_grid_info_norm.model_scale = 1 + q_grid_info.absq2(:);
end

function cases = build_qdiagnostic_cases_local()
    cases = struct('stress_group', {}, 'case_name', {}, 'stress_value', {}, ...
        'beta', {}, 'el_a_deg', {}, 'el_b_deg', {}, 'el_assumed_deg', {}, ...
        'phase_offset_deg', {}, 'rho', {}, 'model_mismatch_flag', {});
    cases(end+1) = make_stress_case_local('amplitude_ratio', 'beta_1', 1, 1.0, 0, 0, 0, 0, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('amplitude_ratio', 'beta_0p8', 0.8, 0.8, 0, 0, 0, 0, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('amplitude_ratio', 'beta_0p5', 0.5, 0.5, 0, 0, 0, 0, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('amplitude_ratio', 'beta_0p3', 0.3, 0.3, 0, 0, 0, 0, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('amplitude_ratio', 'beta_0p1', 0.1, 0.1, 0, 0, 0, 0, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('phase_offset', 'phase_150', 150, 1.0, 0, 0, 0, 150, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('phase_offset', 'phase_180', 180, 1.0, 0, 0, 0, 180, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_1_beta0p3_phase60', 1, 0.3, 0, 0, 0, 60, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_2_beta0p3_phase150', 2, 0.3, 0, 0, 0, 150, 1); %#ok<AGROW>
    cases(end+1) = make_stress_case_local('beta_phase_combo', 'case_5_beta0p1_phase90', 5, 0.1, 0, 0, 0, 90, 1); %#ok<AGROW>
end

function q_idx_map = build_case_q_index_map_local(cases, q_grid_info)
    q_idx_map = zeros(1, numel(cases));
    for iCase = 1:numel(cases)
        q_idx_map(iCase) = find_q_grid_index_local(q_grid_info, cases(iCase).beta, cases(iCase).phase_offset_deg);
    end
end

function [metrics, debug_samples] = run_qdiagnostic_stage_local(stage_name, cases, snr_list, stage_cfg, fid_log)
    nroutes = numel(stage_cfg.route_names);
    ncases = numel(cases);
    stats = init_qdiag_stats_local(nroutes, ncases, numel(snr_list));
    debug_samples = struct([]);
    t_stage = tic;
    for iCase = 1:ncases
        sc = cases(iCase);
        s2_clean = make_engineering_s2_local(stage_cfg.s_base, sc.beta, sc.phase_offset_deg, sc.rho, stage_cfg.base_seed + iCase);
        y_clean_fixed = make_clean_cylindrical_observations_level2_local( ...
            stage_cfg.X3d, stage_cfg.Y3d, stage_cfg.Z3d, stage_cfg.A_ref_2d, stage_cfg.lambda, ...
            stage_cfg.target_theta(1), stage_cfg.target_theta(2), 0, 0, stage_cfg.s_base, s2_clean);
        for iSNR = 1:numel(snr_list)
            snr_db = snr_list(iSNR);
            noise_power = mean(abs(y_clean_fixed(:)).^2) / 10^(snr_db / 10);
            for metkl_num = 1:stage_cfg.Metkl
                seed_now = stage_cfg.base_seed + 100000*iCase + 1000*iSNR + metkl_num;
                rng(seed_now, 'twister');
                noise = sqrt(noise_power/2) * (randn(size(y_clean_fixed)) + 1j * randn(size(y_clean_fixed)));
                y_2d = y_clean_fixed + noise;
                y_combined = combine_layers_level2_local(y_2d, stage_cfg.Z3d, stage_cfg.lambda, 0);
                [Rfb, ~] = fbss_covariance_and_noise_subspace_local(y_combined, stage_cfg.K_phi, 2);

                q_true_idx = stage_cfg.q_true_idx_map(iCase);
                equal_result = run_rank1_covfit_pair_search_debug_local( ...
                    Rfb, stage_cfg.precomp_equal_coarse, stage_cfg.candidate_pairs_coarse, stage_cfg.angle_grid_coarse, ...
                    stage_cfg.X3d, stage_cfg.Y3d, stage_cfg.Z3d, stage_cfg.A_ref_2d, stage_cfg.lambda, ...
                    0, 0, stage_cfg.K_phi, stage_cfg.min_pair_sep_deg, stage_cfg.max_pair_sep_deg, ...
                    stage_cfg.top_N, stage_cfg.refine_half_width, stage_cfg.angle_step_refine, stage_cfg.true_pair_equal);
                route_equal = convert_equal_result_to_common_local(equal_result);

                route_old = run_complex_gain_pair_search_mode_local( ...
                    Rfb, stage_cfg.precomp_complex_coarse, stage_cfg.candidate_pairs_coarse, stage_cfg.angle_grid_coarse, ...
                    stage_cfg.X3d, stage_cfg.Y3d, stage_cfg.Z3d, stage_cfg.A_ref_2d, stage_cfg.lambda, ...
                    0, 0, stage_cfg.K_phi, stage_cfg.min_pair_sep_deg, stage_cfg.max_pair_sep_deg, ...
                    stage_cfg.top_N, stage_cfg.refine_half_width, stage_cfg.angle_step_refine, ...
                    stage_cfg.true_pair_complex, stage_cfg.q_grid_info, q_true_idx, sc.beta, sc.phase_offset_deg, [], []);

                route_qtrue = run_complex_gain_pair_search_mode_local( ...
                    Rfb, stage_cfg.precomp_complex_coarse, stage_cfg.candidate_pairs_coarse, stage_cfg.angle_grid_coarse, ...
                    stage_cfg.X3d, stage_cfg.Y3d, stage_cfg.Z3d, stage_cfg.A_ref_2d, stage_cfg.lambda, ...
                    0, 0, stage_cfg.K_phi, stage_cfg.min_pair_sep_deg, stage_cfg.max_pair_sep_deg, ...
                    stage_cfg.top_N, stage_cfg.refine_half_width, stage_cfg.angle_step_refine, ...
                    stage_cfg.true_pair_complex, stage_cfg.q_grid_info, q_true_idx, sc.beta, sc.phase_offset_deg, q_true_idx, []);

                route_q1 = run_complex_gain_pair_search_mode_local( ...
                    Rfb, stage_cfg.precomp_complex_coarse, stage_cfg.candidate_pairs_coarse, stage_cfg.angle_grid_coarse, ...
                    stage_cfg.X3d, stage_cfg.Y3d, stage_cfg.Z3d, stage_cfg.A_ref_2d, stage_cfg.lambda, ...
                    0, 0, stage_cfg.K_phi, stage_cfg.min_pair_sep_deg, stage_cfg.max_pair_sep_deg, ...
                    stage_cfg.top_N, stage_cfg.refine_half_width, stage_cfg.angle_step_refine, ...
                    stage_cfg.true_pair_complex, stage_cfg.q_grid_info, q_true_idx, sc.beta, sc.phase_offset_deg, stage_cfg.q1_idx, ...
                    equal_result.top_pairs_theta);
                route_q1 = align_q1_with_equal_local(route_q1, route_equal);

                route_fallback = apply_qfallback_local(route_old, route_q1);

                route_norm = run_complex_gain_pair_search_mode_local( ...
                    Rfb, stage_cfg.precomp_complex_coarse, stage_cfg.candidate_pairs_coarse, stage_cfg.angle_grid_coarse, ...
                    stage_cfg.X3d, stage_cfg.Y3d, stage_cfg.Z3d, stage_cfg.A_ref_2d, stage_cfg.lambda, ...
                    0, 0, stage_cfg.K_phi, stage_cfg.min_pair_sep_deg, stage_cfg.max_pair_sep_deg, ...
                    stage_cfg.top_N, stage_cfg.refine_half_width, stage_cfg.angle_step_refine, ...
                    stage_cfg.true_pair_complex, stage_cfg.q_grid_info_norm, q_true_idx, sc.beta, sc.phase_offset_deg, [], []);

                route_staged = run_complex_gain_pair_search_mode_local( ...
                    Rfb, stage_cfg.precomp_complex_coarse, stage_cfg.candidate_pairs_coarse, stage_cfg.angle_grid_coarse, ...
                    stage_cfg.X3d, stage_cfg.Y3d, stage_cfg.Z3d, stage_cfg.A_ref_2d, stage_cfg.lambda, ...
                    0, 0, stage_cfg.K_phi, stage_cfg.min_pair_sep_deg, stage_cfg.max_pair_sep_deg, ...
                    stage_cfg.top_N, stage_cfg.refine_half_width, stage_cfg.angle_step_refine, ...
                    stage_cfg.true_pair_complex, stage_cfg.q_grid_info, q_true_idx, sc.beta, sc.phase_offset_deg, [], equal_result.top_pairs_theta);

                route_results = {route_equal, route_old, route_qtrue, route_q1, route_fallback, route_norm, route_staged};
                ref_scores = struct();
                ref_scores.qgrid = route_old.objective_best;
                ref_scores.qtrue = route_qtrue.objective_best;
                ref_scores.q1 = route_q1.objective_best;
                stats = update_qdiag_stats_local(stats, route_results, ref_scores, ...
                    stage_cfg.target_theta, stage_cfg.theta_sep, stage_cfg.true_center, ...
                    stage_cfg.tol_deg, stage_cfg.tol_rel_now, iCase, iSNR);

                if metkl_num == 1
                    debug_samples(end+1).stage = stage_name; %#ok<AGROW>
                    debug_samples(end).case_name = sc.case_name;
                    debug_samples(end).snr_db = snr_db;
                    debug_samples(end).seed_now = seed_now;
                    debug_samples(end).equal_result = route_equal;
                    debug_samples(end).old_result = route_old;
                    debug_samples(end).qtrue_result = route_qtrue;
                    debug_samples(end).q1_result = route_q1;
                    debug_samples(end).fallback_result = route_fallback;
                    debug_samples(end).norm_result = route_norm;
                    debug_samples(end).staged_result = route_staged;
                end
            end
        end
        log_msg(fid_log, '  [%s] case %02d/%02d %-24s finished, elapsed=%.1f s', ...
            stage_name, iCase, ncases, sc.case_name, toc(t_stage));
    end
    metrics = finalize_qdiag_metrics_local(stats, stage_cfg.Metkl, stage_cfg.route_names, cases, snr_list);
    metrics.stage_name = stage_name;
end

function stats = init_qdiag_stats_local(nroutes, ncases, nsnr)
    dims = [nroutes, ncases, nsnr];
    stats.raw_success_count = zeros(dims);
    stats.tol_success_count_abs01 = zeros(dims);
    stats.tol_success_count_rel025 = zeros(dims);
    stats.rmse_sum_sqerr = zeros(dims);
    stats.rmse_valid_count = zeros(dims);
    stats.pair_count = zeros(dims);
    stats.pair_sep_abs_error_sum = zeros(dims);
    stats.pair_center_abs_error_sum = zeros(dims);
    stats.q_metric_count = zeros(dims);
    stats.beta_hat_sum = zeros(dims);
    stats.beta_abs_err_sum = zeros(dims);
    stats.phi_hat_sum = zeros(dims);
    stats.phi_abs_err_sum = zeros(dims);
    stats.boundary_count = zeros(dims);
    stats.angle_swap_count = zeros(dims);
    stats.fallback_count = zeros(dims);
    stats.q1_selected_count = zeros(dims);
    stats.reciprocal_better_count = zeros(dims);
    stats.score_best_sum = zeros(dims);
    stats.true_rank_values = cell(dims);
    stats.ref_count = zeros(ncases, nsnr);
    stats.score_qgrid_sum = zeros(ncases, nsnr);
    stats.score_qtrue_sum = zeros(ncases, nsnr);
    stats.score_q1_sum = zeros(ncases, nsnr);
end

function result = run_rank1_covfit_pair_search_debug_local( ...
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
    doa_est = sort(angle_grid_refine(candidate_pairs_refine(best_idx, :)));
    true_rank = 1 + sum(coarse_scores < true_score(1));
    result = struct();
    result.doa_est = doa_est;
    result.objective_best = best_score;
    result.objective_true = true_score(1);
    result.true_rank = true_rank;
    result.top_pairs_theta = top_pairs_theta;
    result.has_q = false;
    result.beta_hat = NaN;
    result.phi_hat_deg = NaN;
    result.beta_error = NaN;
    result.phi_error_deg = NaN;
    result.q_grid_hit_boundary = false;
    result.angle_swap_flag = false;
    result.reciprocal_q_better_flag = false;
    result.fallback_used = false;
    result.q1_selected = false;
end

function result = convert_equal_result_to_common_local(equal_result)
    result = equal_result;
end

function result = run_complex_gain_pair_search_mode_local( ...
    Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, el_scan_deg, el_assumed_deg, K_phi, ...
    min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, ...
    true_pair_precomp, q_grid_info_score, true_q_idx, true_beta, true_phi_deg, fixed_q_idx, input_top_pairs_theta)

    [coarse_scores_all, coarse_alpha_all, coarse_sigma2_all] = score_complex_all_scaled_local(Rfb, precomp_coarse, q_grid_info_score);
    if isempty(fixed_q_idx)
        if isempty(input_top_pairs_theta)
            top_lin = top_indices_local(coarse_scores_all(:), top_N);
            [top_pair_idx, ~] = ind2sub(size(coarse_scores_all), top_lin);
            top_pair_idx = unique(top_pair_idx, 'stable');
            top_pairs_theta = [angle_grid_coarse(candidate_pairs_coarse(top_pair_idx, 1)).', ...
                angle_grid_coarse(candidate_pairs_coarse(top_pair_idx, 2)).'];
        else
            top_pairs_theta = input_top_pairs_theta;
        end
    else
        coarse_scores_vec = coarse_scores_all(:, fixed_q_idx);
        top_idx = top_indices_local(coarse_scores_vec, top_N);
        top_pairs_theta = [angle_grid_coarse(candidate_pairs_coarse(top_idx, 1)).', ...
            angle_grid_coarse(candidate_pairs_coarse(top_idx, 2)).'];
    end

    refine_pairs_theta = make_refine_pairs_local(top_pairs_theta, refine_half_width, angle_step_refine, ...
        min_pair_sep_deg, max_pair_sep_deg);
    if isempty(refine_pairs_theta)
        refine_pairs_theta = top_pairs_theta;
    end
    [angle_grid_refine, candidate_pairs_refine] = theta_pairs_to_grid_indices_local(refine_pairs_theta);
    B_grid_refine = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid_refine, el_scan_deg, el_assumed_deg);
    cache_refine = make_subarray_steer_cache_local(B_grid_refine, K_phi);
    precomp_refine = precompute_complex_pair_bases_local(cache_refine, candidate_pairs_refine);
    [refine_scores_all, refine_alpha_all, refine_sigma2_all] = score_complex_all_scaled_local(Rfb, precomp_refine, q_grid_info_score);
    [true_scores, ~, ~] = score_complex_all_scaled_local(Rfb, true_pair_precomp, q_grid_info_score);
    true_score = true_scores(1, true_q_idx);

    if isempty(fixed_q_idx)
        [best_score, best_lin] = min(refine_scores_all(:));
        [best_pair_idx, best_q_idx] = ind2sub(size(refine_scores_all), best_lin);
        [best_coarse_score, best_coarse_lin] = min(coarse_scores_all(:));
        [best_coarse_pair_idx, ~] = ind2sub(size(coarse_scores_all), best_coarse_lin);
        true_rank = 1 + sum(coarse_scores_all(:) < true_score);
        alpha_hat = refine_alpha_all(best_pair_idx, best_q_idx);
        sigma2_hat = refine_sigma2_all(best_pair_idx, best_q_idx);
    else
        refine_scores_vec = refine_scores_all(:, fixed_q_idx);
        [best_score, best_pair_idx] = min(refine_scores_vec);
        coarse_scores_vec = coarse_scores_all(:, fixed_q_idx);
        [best_coarse_score, best_coarse_pair_idx] = min(coarse_scores_vec);
        best_q_idx = fixed_q_idx;
        if fixed_q_idx == true_q_idx
            true_rank = 1 + sum(coarse_scores_vec < true_score);
        else
            true_rank = NaN;
        end
        alpha_hat = refine_alpha_all(best_pair_idx, best_q_idx);
        sigma2_hat = refine_sigma2_all(best_pair_idx, best_q_idx);
    end

    doa_est = sort(angle_grid_refine(candidate_pairs_refine(best_pair_idx, :)));
    coarse_pair = sort(angle_grid_coarse(candidate_pairs_coarse(best_coarse_pair_idx, :)));
    beta_hat = q_grid_info_score.beta_list(best_q_idx);
    phi_hat_deg = q_grid_info_score.phi_list_deg(best_q_idx);

    result = struct();
    result.doa_est = doa_est;
    result.objective_best = best_score;
    result.objective_true = true_score;
    result.true_rank = true_rank;
    result.top_pairs_theta = top_pairs_theta;
    result.coarse_pair = coarse_pair;
    result.coarse_objective_best = best_coarse_score;
    result.beta_hat = beta_hat;
    result.phi_hat_deg = phi_hat_deg;
    result.alpha_hat = alpha_hat;
    result.sigma2_hat = sigma2_hat;
    result.beta_error = beta_hat - true_beta;
    result.phi_error_deg = wrap_phase_diff_deg_local(phi_hat_deg - true_phi_deg);
    result.q_grid_hit_boundary = q_grid_info_score.is_boundary(best_q_idx);
    result.angle_swap_flag = angle_swap_flag_local(true_beta, beta_hat);
    result.reciprocal_q_better_flag = reciprocal_q_better_local(beta_hat, phi_hat_deg, true_beta, true_phi_deg);
    result.fallback_used = false;
    result.q1_selected = false;
    result.has_q = true;
end

function [score, alpha_best, sigma2_best] = score_complex_all_scaled_local(Robs, precomp, q_grid_info)
    y = matrix_to_realvec_local(Robs);
    yy = real(y' * y);
    iy = double(precomp.ivec' * single(y));
    gy11 = double(precomp.g11' * single(y));
    gy22 = double(precomp.g22' * single(y));
    gyre = double(precomp.gre' * single(y));
    gyim = double(precomp.gim' * single(y));
    gy_coef = [gy11, gy22, gyre, gyim];
    gy = gy_coef * q_grid_info.lin_features;
    gi = precomp.gi_coef * q_grid_info.lin_features;
    gg = precomp.gg_coef * q_grid_info.quad_features;
    if isfield(q_grid_info, 'model_scale')
        scale = q_grid_info.model_scale(:).';
        gy = gy ./ scale;
        gi = gi ./ scale;
        gg = gg ./ (scale.^2);
    end
    [score, alpha_best, sigma2_best] = solve_covfit_score_local(gy, gi, gg, yy, iy, precomp.ii);
end

function result = apply_qfallback_local(route_old, route_q1)
    score_tol = max(1e-6, 0.05 * max(abs(route_q1.objective_best), abs(route_old.objective_best)));
    use_q1 = route_old.q_grid_hit_boundary && ...
        route_q1.objective_best <= (route_old.objective_best + score_tol);
    if use_q1
        result = route_q1;
    else
        result = route_old;
    end
    result.fallback_used = use_q1;
    result.q1_selected = use_q1;
end

function result = align_q1_with_equal_local(result, equal_result)
    objective_gap = abs(result.objective_best - equal_result.objective_best);
    coarse_gap = 0;
    if isfield(result, 'coarse_objective_best') && isfield(equal_result, 'coarse_objective_best')
        coarse_gap = abs(result.coarse_objective_best - equal_result.coarse_objective_best);
    end
    if objective_gap <= 1e-5 && coarse_gap <= 1e-5
        result.doa_est = equal_result.doa_est;
        result.top_pairs_theta = equal_result.top_pairs_theta;
        if isfield(equal_result, 'coarse_pair')
            result.coarse_pair = equal_result.coarse_pair;
        end
        result.objective_best = equal_result.objective_best;
        result.objective_true = equal_result.objective_true;
        result.true_rank = equal_result.true_rank;
        if isfield(equal_result, 'coarse_objective_best')
            result.coarse_objective_best = equal_result.coarse_objective_best;
        end
    end
end

function tf = reciprocal_q_better_local(beta_hat, phi_hat_deg, beta_true, phi_true_deg)
    if ~isfinite(beta_hat) || beta_hat == 0
        tf = false;
        return
    end
    direct_cost = abs(beta_hat - beta_true) + abs(wrap_phase_diff_deg_local(phi_hat_deg - phi_true_deg)) / 180;
    recip_cost = abs(1 / beta_hat - beta_true) + abs(wrap_phase_diff_deg_local(-phi_hat_deg - phi_true_deg)) / 180;
    tf = recip_cost + 1e-12 < direct_cost;
end

function run_stage2 = choose_qdiag_stage2_trigger_local(metrics, route_names, cases)
    idxEqual = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    candidate_routes = find(ismember(route_names, {'complex_gain_grid_with_fallback', 'complex_gain_normalized_grid', 'complex_gain_staged_search'}));
    idxBeta1 = find(strcmp({cases.case_name}, 'beta_1'), 1);
    idxBeta03 = find(strcmp({cases.case_name}, 'beta_0p3'), 1);
    idxPhase150 = find(strcmp({cases.case_name}, 'phase_150'), 1);
    idxPhase180 = find(strcmp({cases.case_name}, 'phase_180'), 1);
    run_stage2 = false;
    for ir = candidate_routes
        protect = metrics.tol_success_rate_abs01(ir, idxBeta1, 1) >= metrics.tol_success_rate_abs01(idxEqual, idxBeta1, 1) - 0.05;
        recover = metrics.tol_success_rate_abs01(ir, idxBeta03, 1) >= 0.9 || ...
            metrics.tol_success_rate_abs01(ir, idxPhase150, 1) >= 0.9 || ...
            metrics.tol_success_rate_abs01(ir, idxPhase180, 1) >= 0.9;
        run_stage2 = run_stage2 || (protect && recover);
    end
end

function stats = update_qdiag_stats_local(stats, route_results, ref_scores, target_theta, theta_sep, true_center, tol_deg, tol_rel_now, iCase, iSNR)
    nroutes = numel(route_results);
    for iroute = 1:nroutes
        res = route_results{iroute};
        doa_now = res.doa_est;
        raw_ok = all(isfinite(doa_now)) && numel(doa_now) == 2;
        tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
        tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_rel_now);
        if raw_ok
            stats.raw_success_count(iroute, iCase, iSNR) = stats.raw_success_count(iroute, iCase, iSNR) + 1;
            doa_sorted = sort(doa_now(:).');
            err = doa_sorted - sort(target_theta(:).');
            stats.rmse_sum_sqerr(iroute, iCase, iSNR) = stats.rmse_sum_sqerr(iroute, iCase, iSNR) + sum(err.^2);
            stats.rmse_valid_count(iroute, iCase, iSNR) = stats.rmse_valid_count(iroute, iCase, iSNR) + 1;
            pair_sep = doa_sorted(2) - doa_sorted(1);
            pair_center = mean(doa_sorted);
            stats.pair_count(iroute, iCase, iSNR) = stats.pair_count(iroute, iCase, iSNR) + 1;
            stats.pair_sep_abs_error_sum(iroute, iCase, iSNR) = stats.pair_sep_abs_error_sum(iroute, iCase, iSNR) + abs(pair_sep - theta_sep);
            stats.pair_center_abs_error_sum(iroute, iCase, iSNR) = stats.pair_center_abs_error_sum(iroute, iCase, iSNR) + abs(pair_center - true_center);
        end
        if tol_ok_abs
            stats.tol_success_count_abs01(iroute, iCase, iSNR) = stats.tol_success_count_abs01(iroute, iCase, iSNR) + 1;
        end
        if tol_ok_rel
            stats.tol_success_count_rel025(iroute, iCase, iSNR) = stats.tol_success_count_rel025(iroute, iCase, iSNR) + 1;
        end
        if isfield(res, 'objective_best') && isfinite(res.objective_best)
            stats.score_best_sum(iroute, iCase, iSNR) = stats.score_best_sum(iroute, iCase, iSNR) + res.objective_best;
        end
        if isfield(res, 'true_rank') && isfinite(res.true_rank)
            stats.true_rank_values{iroute, iCase, iSNR}(end+1) = res.true_rank;
        end
        if isfield(res, 'has_q') && res.has_q
            stats.q_metric_count(iroute, iCase, iSNR) = stats.q_metric_count(iroute, iCase, iSNR) + 1;
            stats.beta_hat_sum(iroute, iCase, iSNR) = stats.beta_hat_sum(iroute, iCase, iSNR) + res.beta_hat;
            stats.beta_abs_err_sum(iroute, iCase, iSNR) = stats.beta_abs_err_sum(iroute, iCase, iSNR) + abs(res.beta_error);
            stats.phi_hat_sum(iroute, iCase, iSNR) = stats.phi_hat_sum(iroute, iCase, iSNR) + res.phi_hat_deg;
            stats.phi_abs_err_sum(iroute, iCase, iSNR) = stats.phi_abs_err_sum(iroute, iCase, iSNR) + abs(res.phi_error_deg);
            stats.boundary_count(iroute, iCase, iSNR) = stats.boundary_count(iroute, iCase, iSNR) + double(res.q_grid_hit_boundary);
            stats.angle_swap_count(iroute, iCase, iSNR) = stats.angle_swap_count(iroute, iCase, iSNR) + double(res.angle_swap_flag);
            stats.fallback_count(iroute, iCase, iSNR) = stats.fallback_count(iroute, iCase, iSNR) + double(res.fallback_used);
            stats.q1_selected_count(iroute, iCase, iSNR) = stats.q1_selected_count(iroute, iCase, iSNR) + double(res.q1_selected);
            stats.reciprocal_better_count(iroute, iCase, iSNR) = stats.reciprocal_better_count(iroute, iCase, iSNR) + double(res.reciprocal_q_better_flag);
        end
    end
    stats.ref_count(iCase, iSNR) = stats.ref_count(iCase, iSNR) + 1;
    stats.score_qgrid_sum(iCase, iSNR) = stats.score_qgrid_sum(iCase, iSNR) + ref_scores.qgrid;
    stats.score_qtrue_sum(iCase, iSNR) = stats.score_qtrue_sum(iCase, iSNR) + ref_scores.qtrue;
    stats.score_q1_sum(iCase, iSNR) = stats.score_q1_sum(iCase, iSNR) + ref_scores.q1;
end

function metrics = finalize_qdiag_metrics_local(stats, Metkl, route_names, cases, snr_list)
    metrics = struct();
    metrics.route_names = route_names;
    metrics.case_names = {cases.case_name};
    metrics.snr_list = snr_list;
    metrics.raw_success_rate = stats.raw_success_count / Metkl;
    metrics.tol_success_rate_abs01 = stats.tol_success_count_abs01 / Metkl;
    metrics.tol_success_rate_rel025 = stats.tol_success_count_rel025 / Metkl;
    metrics.rmse_deg = sqrt(stats.rmse_sum_sqerr ./ max(stats.rmse_valid_count, 1) / 2);
    metrics.rmse_deg(stats.rmse_valid_count == 0) = NaN;
    metrics.mean_pair_sep_error = stats.pair_sep_abs_error_sum ./ max(stats.pair_count, 1);
    metrics.mean_pair_center_error = stats.pair_center_abs_error_sum ./ max(stats.pair_count, 1);
    metrics.mean_pair_sep_error(stats.pair_count == 0) = NaN;
    metrics.mean_pair_center_error(stats.pair_count == 0) = NaN;
    metrics.mean_beta_hat = stats.beta_hat_sum ./ max(stats.q_metric_count, 1);
    metrics.mean_abs_beta_error = stats.beta_abs_err_sum ./ max(stats.q_metric_count, 1);
    metrics.mean_phi_hat_deg = stats.phi_hat_sum ./ max(stats.q_metric_count, 1);
    metrics.mean_abs_phi_error_deg = stats.phi_abs_err_sum ./ max(stats.q_metric_count, 1);
    metrics.q_grid_hit_boundary_rate = stats.boundary_count ./ max(stats.q_metric_count, 1);
    metrics.angle_swap_rate = stats.angle_swap_count ./ max(stats.q_metric_count, 1);
    metrics.fallback_rate = stats.fallback_count / Metkl;
    metrics.q1_selected_rate = stats.q1_selected_count / Metkl;
    metrics.reciprocal_q_better_rate = stats.reciprocal_better_count ./ max(stats.q_metric_count, 1);
    metrics.score_best_mean = stats.score_best_sum / Metkl;
    metrics.true_q_objective_rank_median = nan(size(stats.score_best_sum));
    for iroute = 1:numel(route_names)
        for iCase = 1:numel(cases)
            for iSNR = 1:numel(snr_list)
                vals = stats.true_rank_values{iroute, iCase, iSNR};
                if ~isempty(vals)
                    metrics.true_q_objective_rank_median(iroute, iCase, iSNR) = median(vals, 'omitnan');
                end
            end
        end
    end
    metrics.score_qgrid_mean = stats.score_qgrid_sum ./ max(stats.ref_count, 1);
    metrics.score_qtrue_mean = stats.score_qtrue_sum ./ max(stats.ref_count, 1);
    metrics.score_q1_mean = stats.score_q1_sum ./ max(stats.ref_count, 1);
    metrics.score_gap_qgrid_vs_qtrue = metrics.score_qgrid_mean - metrics.score_qtrue_mean;
    metrics.score_gap_qgrid_vs_q1 = metrics.score_qgrid_mean - metrics.score_q1_mean;
end

function rows = build_qdiagnostic_summary_rows_local(stage_name, metrics, route_names, cases, stage_cfg)
    rows = {};
    for iroute = 1:numel(route_names)
        for iCase = 1:numel(cases)
            sc = cases(iCase);
            for iSNR = 1:numel(metrics.snr_list)
                rows(end+1, :) = {stage_name, route_names{iroute}, sc.case_name, sc.stress_group, sc.beta, sc.phase_offset_deg, ... %#ok<AGROW>
                    metrics.snr_list(iSNR), metrics.raw_success_rate(iroute, iCase, iSNR), ...
                    metrics.tol_success_rate_abs01(iroute, iCase, iSNR), metrics.tol_success_rate_rel025(iroute, iCase, iSNR), ...
                    metrics.rmse_deg(iroute, iCase, iSNR), metrics.mean_pair_sep_error(iroute, iCase, iSNR), ...
                    metrics.mean_pair_center_error(iroute, iCase, iSNR), metrics.mean_beta_hat(iroute, iCase, iSNR), ...
                    metrics.mean_abs_beta_error(iroute, iCase, iSNR), metrics.mean_phi_hat_deg(iroute, iCase, iSNR), ...
                    metrics.mean_abs_phi_error_deg(iroute, iCase, iSNR), metrics.q_grid_hit_boundary_rate(iroute, iCase, iSNR), ...
                    metrics.angle_swap_rate(iroute, iCase, iSNR), metrics.reciprocal_q_better_rate(iroute, iCase, iSNR), ...
                    metrics.fallback_rate(iroute, iCase, iSNR), metrics.q1_selected_rate(iroute, iCase, iSNR), ...
                    metrics.true_q_objective_rank_median(iroute, iCase, iSNR), metrics.score_best_mean(iroute, iCase, iSNR), ...
                    metrics.score_qgrid_mean(iCase, iSNR), metrics.score_qtrue_mean(iCase, iSNR), metrics.score_q1_mean(iCase, iSNR), ...
                    metrics.score_gap_qgrid_vs_qtrue(iCase, iSNR), metrics.score_gap_qgrid_vs_q1(iCase, iSNR), ...
                    stage_cfg.K_phi, stage_cfg.Q - stage_cfg.K_phi + 1, stage_cfg.sep_factor, stage_cfg.theta_sep};
            end
        end
    end
end

function write_qdiagnostic_summary_csv_local(path_out, rows)
    header = {'experiment_stage', 'route_name', 'case_name', 'stress_group', 'beta_true', 'phase_true_deg', 'snr_db', ...
        'raw_success_rate', 'tol_success_rate_abs01', 'tol_success_rate_rel025', 'rmse_deg', ...
        'mean_pair_sep_error', 'mean_pair_center_error', 'mean_beta_hat', 'mean_abs_beta_error', ...
        'mean_phi_hat_deg', 'mean_abs_phi_error_deg', 'q_grid_hit_boundary_rate', 'angle_swap_rate', ...
        'reciprocal_q_better_rate', 'fallback_rate', 'q1_selected_rate', 'true_q_objective_rank_median', ...
        'score_best_mean', 'score_qgrid_mean', 'score_qtrue_mean', 'score_q1_mean', ...
        'score_gap_qgrid_vs_qtrue', 'score_gap_qgrid_vs_q1', 'K_phi', 'P_phi', 'sep_factor', 'theta_sep_deg'};
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(header, ','));
    for ii = 1:size(rows, 1)
        vals = cell(1, numel(header));
        for jj = 1:numel(header)
            vals{jj} = csv_value_local(rows{ii, jj});
        end
        fprintf(fid, '%s\n', strjoin(vals, ','));
    end
end

function diagnosis = choose_qdiagnostic_diagnosis_local(metrics, route_names, cases, run_stage2)
    idxEq = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    idxOld = find(strcmp(route_names, 'complex_gain_grid_old'), 1);
    idxQtrue = find(strcmp(route_names, 'complex_gain_q_fixed_true'), 1);
    idxQ1 = find(strcmp(route_names, 'complex_gain_q1_forced'), 1);
    idxFallback = find(strcmp(route_names, 'complex_gain_grid_with_fallback'), 1);
    idxNorm = find(strcmp(route_names, 'complex_gain_normalized_grid'), 1);
    idxStage = find(strcmp(route_names, 'complex_gain_staged_search'), 1);
    idxBeta1 = find(strcmp({cases.case_name}, 'beta_1'), 1);
    idxBeta03 = find(strcmp({cases.case_name}, 'beta_0p3'), 1);
    idxBeta01 = find(strcmp({cases.case_name}, 'beta_0p1'), 1);
    idxPhase150 = find(strcmp({cases.case_name}, 'phase_150'), 1);
    idxPhase180 = find(strcmp({cases.case_name}, 'phase_180'), 1);

    q_fixed_true_success = min([ ...
        metrics.tol_success_rate_abs01(idxQtrue, idxBeta03, 1), ...
        metrics.tol_success_rate_abs01(idxQtrue, idxBeta01, 1), ...
        metrics.tol_success_rate_abs01(idxQtrue, idxPhase150, 1), ...
        metrics.tol_success_rate_abs01(idxQtrue, idxPhase180, 1)]) >= 0.9;

    q1_matches_equal = nanmax_flat_local(abs(squeeze(metrics.tol_success_rate_abs01(idxQ1, :, 1) - metrics.tol_success_rate_abs01(idxEq, :, 1)))) < 1e-9 && ...
        nanmax_flat_local(abs(squeeze(metrics.score_best_mean(idxQ1, :, 1) - metrics.score_best_mean(idxEq, :, 1)))) < 1e-9;

    old_qgrid_failure_reproduced = metrics.tol_success_rate_abs01(idxOld, idxBeta1, 1) < metrics.tol_success_rate_abs01(idxEq, idxBeta1, 1) - 0.5 && ...
        metrics.tol_success_rate_abs01(idxOld, idxPhase150, 1) < 0.9 && metrics.tol_success_rate_abs01(idxOld, idxPhase180, 1) < 0.9;

    normalized_reduces_boundary = mean(squeeze(metrics.q_grid_hit_boundary_rate(idxNorm, :, 1)), 'omitnan') + 1e-12 < ...
        mean(squeeze(metrics.q_grid_hit_boundary_rate(idxOld, :, 1)), 'omitnan');

    staged_improves = metrics.tol_success_rate_abs01(idxStage, idxBeta1, 1) >= metrics.tol_success_rate_abs01(idxEq, idxBeta1, 1) - 0.05 && ...
        (metrics.tol_success_rate_abs01(idxStage, idxBeta03, 1) > metrics.tol_success_rate_abs01(idxOld, idxBeta03, 1) || ...
         metrics.tol_success_rate_abs01(idxStage, idxPhase150, 1) > metrics.tol_success_rate_abs01(idxOld, idxPhase150, 1));

    fallback_protects_baseline = metrics.tol_success_rate_abs01(idxFallback, idxBeta1, 1) >= metrics.tol_success_rate_abs01(idxEq, idxBeta1, 1) - 0.05 && ...
        metrics.tol_success_rate_abs01(idxFallback, idxPhase150, 1) >= metrics.tol_success_rate_abs01(idxEq, idxPhase150, 1) - 0.05 && ...
        metrics.tol_success_rate_abs01(idxFallback, idxPhase180, 1) >= metrics.tol_success_rate_abs01(idxEq, idxPhase180, 1) - 0.05;

    q_fixed_true_mean = mean([metrics.tol_success_rate_abs01(idxQtrue, idxBeta03, 1), metrics.tol_success_rate_abs01(idxQtrue, idxPhase150, 1), metrics.tol_success_rate_abs01(idxQtrue, idxPhase180, 1)]);
    old_qgrid_mean = mean([metrics.tol_success_rate_abs01(idxOld, idxBeta03, 1), metrics.tol_success_rate_abs01(idxOld, idxPhase150, 1), metrics.tol_success_rate_abs01(idxOld, idxPhase180, 1)]);

    if ~q1_matches_equal
        main_conclusion = 'q1_forced 与 equal-phase 不一致，说明当前 complex-gain 实现路径还存在公式或搜索逻辑 bug，不能继续外推 V1。';
        model_verdict = '当前首先是实现一致性问题。';
    elseif q_fixed_true_success
        main_conclusion = 'q_fixed_true 能恢复关键场景，complex-gain 模型本身成立，失败主要来自 q 估计；下一步继续收敛 V1，不推进 V2。';
        model_verdict = '模型可行，问题主要在 q 估计。';
    elseif q_fixed_true_mean > old_qgrid_mean + 0.15
        main_conclusion = 'q_fixed_true 明显优于旧 q-grid，但仍未全面恢复，说明模型有一定解释力，当前主要瓶颈仍是 q 估计稳定性。';
        model_verdict = '模型部分可行，q 估计仍是主瓶颈。';
    else
        main_conclusion = 'q_fixed_true 也没有明显恢复，说明层次二一维 complex-gain 模型本身就不足以解释这些更一般场景，不应继续直接外推 V1。';
        model_verdict = '当前既有模型边界，也有 q 估计问题。';
    end

    diagnosis = struct();
    diagnosis.q_fixed_true_success = q_fixed_true_success;
    diagnosis.q1_matches_equal = q1_matches_equal;
    diagnosis.old_qgrid_failure_reproduced = old_qgrid_failure_reproduced;
    diagnosis.normalized_reduces_boundary = normalized_reduces_boundary;
    diagnosis.staged_improves = staged_improves;
    diagnosis.fallback_protects_baseline = fallback_protects_baseline;
    diagnosis.model_verdict = model_verdict;
    diagnosis.run_stage2 = run_stage2;
    diagnosis.main_conclusion = main_conclusion;
end

function plot_qdiag_route_compare_tol_local(path_out, metrics, route_names, cases)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1300, 560]);
    x = 1:numel(cases);
    for iroute = 1:numel(route_names)
        plot(x, squeeze(metrics.tol_success_rate_abs01(iroute, :, 1)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    ylim([0, 1.05]);
    xlim([1, numel(cases)]);
    xticks(x);
    xticklabels({cases.case_name});
    xtickangle(25);
    yline(0.9, '--k');
    ylabel('tol abs01 @ 8 dB');
    title('Route compare on key cases');
    legend(route_names, 'Interpreter', 'none', 'Location', 'bestoutside');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function plot_qdiag_beta_error_local(path_out, metrics, route_names, cases)
    route_pick = {'complex_gain_grid_old', 'complex_gain_q_fixed_true', 'complex_gain_grid_with_fallback', 'complex_gain_normalized_grid', 'complex_gain_staged_search'};
    idx_route = find(ismember(route_names, route_pick));
    idx_case = find(ismember({cases.stress_group}, {'amplitude_ratio', 'beta_phase_combo'}));
    fig = figure('Visible', 'off', 'Position', [100, 100, 1250, 520]);
    for ii = 1:numel(idx_route)
        plot(1:numel(idx_case), squeeze(metrics.mean_abs_beta_error(idx_route(ii), idx_case, 1)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xticks(1:numel(idx_case));
    xticklabels({cases(idx_case).case_name});
    xtickangle(25);
    ylabel('mean abs beta error');
    title('Beta estimation error');
    legend(route_names(idx_route), 'Interpreter', 'none', 'Location', 'bestoutside');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function plot_qdiag_phi_error_local(path_out, metrics, route_names, cases)
    route_pick = {'complex_gain_grid_old', 'complex_gain_q_fixed_true', 'complex_gain_grid_with_fallback', 'complex_gain_normalized_grid', 'complex_gain_staged_search'};
    idx_route = find(ismember(route_names, route_pick));
    idx_case = find(ismember({cases.stress_group}, {'phase_offset', 'beta_phase_combo'}));
    fig = figure('Visible', 'off', 'Position', [100, 100, 1250, 520]);
    for ii = 1:numel(idx_route)
        plot(1:numel(idx_case), squeeze(metrics.mean_abs_phi_error_deg(idx_route(ii), idx_case, 1)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    xticks(1:numel(idx_case));
    xticklabels({cases(idx_case).case_name});
    xtickangle(25);
    ylabel('mean abs phi error (deg)');
    title('Phase estimation error');
    legend(route_names(idx_route), 'Interpreter', 'none', 'Location', 'bestoutside');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function plot_qdiag_boundary_rate_local(path_out, metrics, route_names, cases)
    route_pick = {'complex_gain_grid_old', 'complex_gain_grid_with_fallback', 'complex_gain_normalized_grid', 'complex_gain_staged_search'};
    idx_route = find(ismember(route_names, route_pick));
    fig = figure('Visible', 'off', 'Position', [100, 100, 1250, 520]);
    for ii = 1:numel(idx_route)
        plot(1:numel(cases), squeeze(metrics.q_grid_hit_boundary_rate(idx_route(ii), :, 1)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    ylim([0, 1.05]);
    xticks(1:numel(cases));
    xticklabels({cases.case_name});
    xtickangle(25);
    ylabel('boundary rate');
    title('Boundary absorption diagnostics');
    legend(route_names(idx_route), 'Interpreter', 'none', 'Location', 'bestoutside');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function plot_qdiag_score_gap_local(path_out, metrics, route_names, cases)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1250, 520]);
    plot(1:numel(cases), metrics.score_gap_qgrid_vs_qtrue(:, 1), '-o', 'LineWidth', 1.2);
    hold on
    plot(1:numel(cases), metrics.score_gap_qgrid_vs_q1(:, 1), '-o', 'LineWidth', 1.2);
    hold off
    grid on
    xticks(1:numel(cases));
    xticklabels({cases.case_name});
    xtickangle(25);
    ylabel('score gap');
    title('Old q-grid score gap vs oracle and q=1');
    legend({'qgrid - qtrue', 'qgrid - q1'}, 'Location', 'best');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function write_qdiagnostic_record_doc_local(path_out, params, route_names, cases, stage1_metrics, stage2_metrics, diagnosis, summary_path, keypoints_path, mat_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    idxEq = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    idxOld = find(strcmp(route_names, 'complex_gain_grid_old'), 1);
    idxQtrue = find(strcmp(route_names, 'complex_gain_q_fixed_true'), 1);
    idxQ1 = find(strcmp(route_names, 'complex_gain_q1_forced'), 1);
    idxFallback = find(strcmp(route_names, 'complex_gain_grid_with_fallback'), 1);
    idxNorm = find(strcmp(route_names, 'complex_gain_normalized_grid'), 1);
    idxStage = find(strcmp(route_names, 'complex_gain_staged_search'), 1);

    fprintf(fid, '# 第8.6步 层次二第九部分：complex-gain q 估计诊断记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 公式文档：`%s`\n', params.formula_doc_path);
    fprintf(fid, '- 第八部分脚本/记录/结果：`%s`, `%s`\n', params.part8_script_path, params.part8_record_path);
    fprintf(fid, '- 第七部分记录：`%s`\n', params.part7_record_path);
    fprintf(fid, '- 本轮只做 V1 q 估计诊断与约束修正，不推进 V2，不进层次三。\n\n');

    fprintf(fid, '## Route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Stage-1 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi=%d`, `P_phi=%d`, `sep_factor=%d`, `theta_sep=%.6f deg`\n', ...
        params.Q, params.K_phi, params.P_phi, params.sep_factor, params.theta_sep);
    fprintf(fid, '- `SNR=8 dB`, `Metkl=%d`, `T_snap=%d`\n', params.Metkl, params.T_snap);
    fprintf(fid, '- `beta_grid=%s`\n', mat2str(params.beta_grid));
    fprintf(fid, '- `phi_grid_deg=%s`\n\n', mat2str(params.phi_grid_deg));

    fprintf(fid, '## 第八部分旧 q-grid 失败复现\n\n');
    fprintf(fid, '- 旧 q-grid 在第八部分：`beta=0.3` tol=%.3f，`beta=0.1` tol=%.3f，`phase=150/180` tol=%.3f / %.3f。\n', ...
        params.part8_baseline.beta03_tol_8dB, params.part8_baseline.beta01_tol_8dB, ...
        params.part8_baseline.phase150_tol_8dB, params.part8_baseline.phase180_tol_8dB);
    fprintf(fid, '- 本轮是否复现旧失败：%s。\n\n', yesno_local(diagnosis.old_qgrid_failure_reproduced));

    fprintf(fid, '## 关键场景表（SNR=8 dB）\n\n');
    fprintf(fid, '| case | eq | old | qtrue | q1 | fallback | normalized | staged |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
    key_names = {'beta_1', 'beta_0p3', 'beta_0p1', 'phase_150', 'phase_180', 'case_1_beta0p3_phase60', 'case_2_beta0p3_phase150', 'case_5_beta0p1_phase90'};
    for ii = 1:numel(key_names)
        ic = find(strcmp({cases.case_name}, key_names{ii}), 1);
        fprintf(fid, '| `%s` | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
            key_names{ii}, ...
            stage1_metrics.tol_success_rate_abs01(idxEq, ic, 1), ...
            stage1_metrics.tol_success_rate_abs01(idxOld, ic, 1), ...
            stage1_metrics.tol_success_rate_abs01(idxQtrue, ic, 1), ...
            stage1_metrics.tol_success_rate_abs01(idxQ1, ic, 1), ...
            stage1_metrics.tol_success_rate_abs01(idxFallback, ic, 1), ...
            stage1_metrics.tol_success_rate_abs01(idxNorm, ic, 1), ...
            stage1_metrics.tol_success_rate_abs01(idxStage, ic, 1));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## q 诊断\n\n');
    fprintf(fid, '- `q_fixed_true` 是否成功：%s。\n', yesno_local(diagnosis.q_fixed_true_success));
    fprintf(fid, '- `q1_forced` 是否与 `equal_phase` 一致：%s。\n', yesno_local(diagnosis.q1_matches_equal));
    fprintf(fid, '- `normalized_grid` 是否降低 boundary rate：%s。\n', yesno_local(diagnosis.normalized_reduces_boundary));
    fprintf(fid, '- `staged_search` 是否改善：%s。\n', yesno_local(diagnosis.staged_improves));
    fprintf(fid, '- `fallback` 是否保护 baseline：%s。\n', yesno_local(diagnosis.fallback_protects_baseline));
    fprintf(fid, '- 模型/估计判断：%s\n\n', diagnosis.model_verdict);

    fprintf(fid, '## Stage-2\n\n');
    if params.run_stage2
        fprintf(fid, '- 已触发补充 SNR 扫描：`%s`\n\n', mat2str(params.snr_list_stage2));
    else
        fprintf(fid, '- 未触发补充 SNR 扫描，因为 stage-1 没有 route 在保护 baseline 的同时明显恢复关键失败场景。\n\n');
    end

    fprintf(fid, '## 主结论\n\n');
    fprintf(fid, '%s\n\n', diagnosis.main_conclusion);

    fprintf(fid, '## 输出文件\n\n');
    fprintf(fid, '- summary：`%s`\n', summary_path);
    fprintf(fid, '- keypoints：`%s`\n', keypoints_path);
    fprintf(fid, '- MAT：`%s`\n', mat_path);
    fprintf(fid, '- figures：`qdiag_route_compare_tol.png`, `qdiag_beta_hat_error.png`, `qdiag_phi_hat_error.png`, `qdiag_boundary_rate.png`, `qdiag_score_gap.png`\n');
end

function out = nanmax_flat_local(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        out = NaN;
    else
        out = max(x);
    end
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
