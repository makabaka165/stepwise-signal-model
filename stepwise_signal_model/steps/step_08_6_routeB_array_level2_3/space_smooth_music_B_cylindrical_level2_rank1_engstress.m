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
sixth_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_rank1_covfit_finalscan.m');
sixth_result_dir = fullfile(script_dir, 'results_step8_6_level2_rank1_covfit_finalscan');
sixth_summary_csv = fullfile(sixth_result_dir, 'step8_6_level2_rank1_covfit_finalscan_summary.csv');
sixth_keypoints_csv = fullfile(sixth_result_dir, 'step8_6_level2_rank1_covfit_finalscan_keypoints.csv');
sixth_record_path = fullfile(script_dir, '第8.6步_层次二第六部分_rank1协方差拟合最终验证记录.md');
overall_record_path = fullfile(script_dir, '第8.6步_层次二整体记录.md');

assert(exist(modify_doc_path, 'file') == 2, 'Modify direction doc not found.');
assert(exist(formula_doc_path, 'file') == 2, 'Formula doc not found.');
assert(exist(sixth_script_path, 'file') == 2, 'Sixth-part finalscan script not found.');
assert(exist(sixth_summary_csv, 'file') == 2, 'Sixth-part summary CSV not found.');
assert(exist(sixth_keypoints_csv, 'file') == 2, 'Sixth-part keypoints CSV not found.');

result_dir = fullfile(script_dir, 'results_step8_6_level2_rank1_covfit_engineering_stress');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

record_doc_path = fullfile(script_dir, '第8.6步_层次二第七部分_rank1协方差拟合工程压力测试记录.md');
log_path = fullfile(result_dir, 'step8_6_level2_rank1_engineering_stress.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

log_msg(fid_log, 'Step 08.6 level 2 part 7A: rank1 equal-phase covfit engineering stress test');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Modify direction doc: %s', modify_doc_path);
log_msg(fid_log, 'Formula doc: %s', formula_doc_path);
log_msg(fid_log, 'Sixth-part script: %s', sixth_script_path);
log_msg(fid_log, 'Sixth-part summary: %s', sixth_summary_csv);
log_msg(fid_log, 'Sixth-part keypoints: %s', sixth_keypoints_csv);
if exist(sixth_record_path, 'file') == 2
    sixth_record_text = fileread(sixth_record_path);
    log_msg(fid_log, 'Sixth-part record: %s, chars=%d', sixth_record_path, strlength(sixth_record_text));
elseif exist(overall_record_path, 'file') == 2
    sixth_record_text = fileread(overall_record_path);
    log_msg(fid_log, 'Sixth-part record file is absent in working tree; using overall level-2 record: %s, chars=%d', ...
        overall_record_path, strlength(sixth_record_text));
else
    sixth_record_text = '';
    log_msg(fid_log, 'WARNING: neither sixth-part record nor overall level-2 record was found.');
end
log_msg(fid_log, 'Scope guard: level 2 engineering stress test only. No level 3, no 2D az/el MUSIC, no complex-gain covfit, no phase-scan covfit, no constrained covariance fitting.');

sixth_summary_tbl = readtable(sixth_summary_csv);
sixth_keypoints_tbl = readtable(sixth_keypoints_csv);
sixth_benchmark = summarize_sixth_part_benchmark_local(sixth_summary_tbl);
log_msg(fid_log, 'Sixth-part benchmark: rank1 sep=10 SNR90_abs01 label=%s, tol(-4 dB)=%.3f, abs sep error(-4 dB)=%.5f deg', ...
    sixth_benchmark.rank1_snr90_abs01_label, sixth_benchmark.rank1_tol_abs01_low_snr, sixth_benchmark.rank1_abs_sep_error_low_snr);
log_msg(fid_log, 'Sixth-part keypoints rows=%d', height(sixth_keypoints_tbl));

azCtr_deg = 0;
T_snap = 260;
Lc = 2;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
K_phi = 28;
sep_factor = 10;
snr_list = [-4, 0, 4, 8];
Metkl = 100;
angle_step_music = 0.005;
angle_step_coarse = 0.02;
angle_step_refine = 0.005;
min_pair_sep_deg = 0.05;
max_pair_sep_deg = 0.80;
top_N = 5;
refine_half_width = 0.06;
base_seed = 20260701;

log_msg(fid_log, 'Stress grid: K_phi=%d, sep_factor=%d, SNR=%s, Metkl=%d, T_snap=%d.', ...
    K_phi, sep_factor, mat2str(snr_list), Metkl, T_snap);
log_msg(fid_log, 'Routes use the same noisy observation within each scenario/SNR/trial.');

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
log_msg(fid_log, 'bw_eq_65=%.9f deg, theta_sep(sep=10)=%.9f deg, target=[%.9f %.9f] deg', ...
    bw_eq_65, theta_sep, target_theta(1), target_theta(2));
log_msg(fid_log, 'rank1 pair search sep range=[%.6f, %.6f] deg', min_pair_sep_deg, max_pair_sep_deg);
if Q ~= 65
    log_msg(fid_log, 'WARNING: Q=%d, expected 65.', Q);
end

route_names = {'center_real', 'min_den_fb', 'covfit_rank1_equal_phase'};
nroutes = numel(route_names);
idx_rank1 = 3;
stress_cases = build_engineering_stress_cases_local();
ncases = numel(stress_cases);
unique_el_assumed = unique([stress_cases.el_assumed_deg]);

log_msg(fid_log, '');
log_msg(fid_log, 'Routes');
for iroute = 1:nroutes
    log_msg(fid_log, '  %d: %s', iroute, route_names{iroute});
end
log_msg(fid_log, 'Stress cases=%d, unique el_assumed=%s', ncases, mat2str(unique_el_assumed));

steer_cache = repmat(struct(), numel(unique_el_assumed), 1);
for iu = 1:numel(unique_el_assumed)
    el0 = unique_el_assumed(iu);
    B_grid_music = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_music, el0, el0);
    B_grid_coarse = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_coarse, el0, el0);
    steer_cache(iu).el_assumed_deg = el0;
    steer_cache(iu).cache_music = make_subarray_steer_cache_local(B_grid_music, K_phi);
    steer_cache(iu).candidate_pairs_coarse = make_pair_candidates_local(angle_grid_coarse, min_pair_sep_deg, max_pair_sep_deg);
    steer_cache(iu).cache_coarse = make_subarray_steer_cache_local(B_grid_coarse, K_phi);
    steer_cache(iu).precomp_coarse = precompute_rank1_pair_bases_local( ...
        steer_cache(iu).cache_coarse, steer_cache(iu).candidate_pairs_coarse);
    steer_cache(iu).true_pair_precomp = precompute_true_pair_rank1_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, el0, el0, K_phi);
    log_msg(fid_log, '  el_assumed=%.3f deg, coarse_candidates=%d', ...
        el0, size(steer_cache(iu).candidate_pairs_coarse, 1));
end

stats = init_stats_local(nroutes, ncases, 1, numel(snr_list));
debug_samples = struct([]);

log_msg(fid_log, '');
log_msg(fid_log, 'Engineering stress scan');
tic;
for iCase = 1:ncases
    sc = stress_cases(iCase);
    iu = find(abs(unique_el_assumed - sc.el_assumed_deg) < 1e-12, 1);
    cache_now = steer_cache(iu);
    is_random_signal = sc.rho < 1;
    if ~is_random_signal
        s2_clean = make_engineering_s2_local(s_base, sc.beta, sc.phase_offset_deg, sc.rho, base_seed + iCase);
        y_clean_fixed = make_clean_cylindrical_observations_level2_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta(1), target_theta(2), ...
            sc.el_a_deg, sc.el_b_deg, s_base, s2_clean);
    else
        y_clean_fixed = [];
    end

    for iSNR = 1:numel(snr_list)
        snr_db = snr_list(iSNR);
        if ~is_random_signal
            noise_power_fixed = mean(abs(y_clean_fixed(:)).^2) / 10^(snr_db / 10);
        end
        for metkl_num = 1:Metkl
            seed_now = base_seed + 100000*iCase + 1000*iSNR + metkl_num;
            rng(seed_now, 'twister');
            if is_random_signal
                s2_now = make_engineering_s2_local(s_base, sc.beta, sc.phase_offset_deg, sc.rho, seed_now);
                y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
                    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta(1), target_theta(2), ...
                    sc.el_a_deg, sc.el_b_deg, s_base, s2_now);
                noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);
            else
                y_clean_2d = y_clean_fixed;
                noise_power = noise_power_fixed;
            end
            noise = sqrt(noise_power/2) * (randn(size(y_clean_2d)) + 1j*randn(size(y_clean_2d)));
            y_2d = y_clean_2d + noise;
            y_combined = combine_layers_level2_local(y_2d, Z3d, cfg.arr.lambda, sc.el_assumed_deg);
            [Rfb, En] = fbss_covariance_and_noise_subspace_local(y_combined, K_phi, Lc);
            doa_all = estimate_music_routes_local(cache_now.cache_music, En, angle_grid_music, Lc);
            rank1_result = run_rank1_covfit_pair_search_local( ...
                Rfb, cache_now.precomp_coarse, cache_now.candidate_pairs_coarse, angle_grid_coarse, ...
                X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, sc.el_assumed_deg, sc.el_assumed_deg, K_phi, ...
                min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, cache_now.true_pair_precomp);
            doa_all{idx_rank1} = rank1_result.doa_est;
            stats = update_route_metrics_local(stats, doa_all, rank1_result, idx_rank1, target_theta, ...
                theta_sep, azCtr_deg, tol_deg, tol_rel_now, iCase, 1, iSNR);

            if (iCase == 1 || strcmp(sc.stress_group, 'extreme_combo')) && iSNR == numel(snr_list) && metkl_num == 1
                debug_samples(end+1).case_name = sc.case_name; %#ok<SAGROW>
                debug_samples(end).stress_group = sc.stress_group;
                debug_samples(end).snr_db = snr_db;
                debug_samples(end).seed_now = seed_now;
                debug_samples(end).rank1_result = rank1_result;
                debug_samples(end).music_doa = doa_all(1:2);
            end
        end
    end
    log_msg(fid_log, '  case %02d/%02d %-22s %-18s finished, elapsed=%.1f s', ...
        iCase, ncases, sc.stress_group, sc.case_name, toc);
end

metrics = finalize_stats_local(stats, Metkl, route_names, 1:ncases, 1, snr_list, theta_sep, azCtr_deg);
metrics.snr90_abs01 = compute_snr90_local(metrics.tol_success_rate_abs01, snr_list);
metrics.snr90_rel025 = compute_snr90_local(metrics.tol_success_rate_rel025, snr_list);
metrics.snr90_abs01_label = make_snr90_label_local(metrics.snr90_abs01, metrics.tol_success_rate_abs01, snr_list);
metrics.snr90_rel025_label = make_snr90_label_local(metrics.snr90_rel025, metrics.tol_success_rate_rel025, snr_list);

summary_path = fullfile(result_dir, 'step8_6_level2_rank1_engineering_stress_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_6_level2_rank1_engineering_stress_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_6_level2_rank1_engineering_stress_result.mat');
summary_rows = build_engineering_summary_rows_local(route_names, stress_cases, K_phi, Q - K_phi + 1, ...
    sep_factor, theta_sep, snr_list, metrics);
write_engineering_summary_csv_local(summary_path, summary_rows);
keypoint_rows = filter_engineering_keypoint_rows_local(summary_rows);
write_engineering_summary_csv_local(keypoints_path, keypoint_rows);

diagnosis = choose_engineering_diagnosis_local(metrics, stress_cases, route_names, snr_list, idx_rank1);

params = struct();
params.modify_doc_path = modify_doc_path;
params.formula_doc_path = formula_doc_path;
params.sixth_script_path = sixth_script_path;
params.sixth_summary_csv = sixth_summary_csv;
params.sixth_keypoints_csv = sixth_keypoints_csv;
params.sixth_record_path = sixth_record_path;
params.overall_record_path = overall_record_path;
params.sixth_benchmark = sixth_benchmark;
params.azCtr_deg = azCtr_deg;
params.T_snap = T_snap;
params.Lc = Lc;
params.tol_deg = tol_deg;
params.tol_rel_ratio = tol_rel_ratio;
params.Q = Q;
params.K_phi = K_phi;
params.P_phi = Q - K_phi + 1;
params.sep_factor = sep_factor;
params.theta_sep = theta_sep;
params.target_theta = target_theta;
params.snr_list = snr_list;
params.Metkl = Metkl;
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

save(mat_path, 'params', 'route_names', 'stress_cases', 'snr_list', ...
    'stats', 'metrics', 'debug_samples', 'diagnosis');

plot_stress_group_tol_local(fullfile(result_dir, 'stress_amplitude_ratio_tol.png'), ...
    stress_cases, metrics, route_names, snr_list, 'amplitude_ratio', 'beta', idx_rank1);
plot_stress_group_tol_local(fullfile(result_dir, 'stress_elevation_sep_tol.png'), ...
    stress_cases, metrics, route_names, snr_list, 'elevation_difference', 'el_b_deg', idx_rank1);
plot_stress_group_tol_local(fullfile(result_dir, 'stress_el_assumed_mismatch_tol.png'), ...
    stress_cases, metrics, route_names, snr_list, 'el_assumed_mismatch', 'el_assumed_deg', idx_rank1);
plot_stress_group_tol_local(fullfile(result_dir, 'stress_phase_offset_tol.png'), ...
    stress_cases, metrics, route_names, snr_list, 'phase_offset', 'phase_offset_deg', idx_rank1);
plot_stress_group_tol_local(fullfile(result_dir, 'stress_rho_tol.png'), ...
    stress_cases, metrics, route_names, snr_list, 'coherence_rho', 'rho', idx_rank1);
plot_extreme_cases_tol_local(fullfile(result_dir, 'stress_extreme_cases_tol.png'), ...
    stress_cases, metrics, route_names, snr_list, idx_rank1);

write_engineering_record_doc_local(record_doc_path, params, route_names, stress_cases, metrics, diagnosis, ...
    summary_path, keypoints_path, mat_path);

log_msg(fid_log, '');
log_msg(fid_log, 'Engineering stress conclusion: %s', diagnosis.main_conclusion);
log_msg(fid_log, 'Need complex-gain covfit: %s', yesno_local(diagnosis.need_complex_gain));
log_msg(fid_log, 'Need constrained covariance fitting: %s', yesno_local(diagnosis.need_constrained_covfit));
log_msg(fid_log, 'Need level 3: %s', yesno_local(diagnosis.need_level3));
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', keypoints_path);
log_msg(fid_log, '  %s', mat_path);
log_msg(fid_log, '  %s', fullfile(result_dir, 'stress_amplitude_ratio_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'stress_elevation_sep_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'stress_el_assumed_mismatch_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'stress_phase_offset_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'stress_rho_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'stress_extreme_cases_tol.png'));
log_msg(fid_log, '  %s', record_doc_path);
safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 rank1 covfit engineering stress test finished.');
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
    stats.objective_best_sum(3, :, :, :) = 0;
    stats.objective_true_sum(3, :, :, :) = 0;
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
    stats.objective_best_sum(idx_rank1, iK, iSep, iSNR) = stats.objective_best_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.objective_best;
    stats.objective_true_sum(idx_rank1, iK, iSep, iSNR) = stats.objective_true_sum(idx_rank1, iK, iSep, iSNR) + rank1_result.objective_true;
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
    metrics.mean_objective_best = stats.objective_best_sum / Metkl;
    metrics.mean_objective_true_pair = stats.objective_true_sum / Metkl;
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

    el_b_list = [0, 0.5, 1, 2, 5, 10, 15, 20];
    for ii = 1:numel(el_b_list)
        el_b = el_b_list(ii);
        stress_cases(end+1) = make_stress_case_local('elevation_difference', ... %#ok<AGROW>
            ['elB_', num_label_local(el_b)], el_b, 1, 0, el_b, 0, 0, 1);
    end

    el_assumed_list = [0, 0.5, 1, 2, 5, 10];
    for ii = 1:numel(el_assumed_list)
        el0 = el_assumed_list(ii);
        stress_cases(end+1) = make_stress_case_local('el_assumed_mismatch', ... %#ok<AGROW>
            ['el0_', num_label_local(el0)], el0, 1, 0, 0, el0, 0, 1);
    end

    phase_offset_list = [0, 5, 15, 30, 60, 90, 120, 150, 180];
    for ii = 1:numel(phase_offset_list)
        ph = phase_offset_list(ii);
        stress_cases(end+1) = make_stress_case_local('phase_offset', ... %#ok<AGROW>
            ['phase_', num_label_local(ph)], ph, 1, 0, 0, 0, ph, 1);
    end

    rho_list = [1, 0.99, 0.95, 0.9, 0.7, 0.5];
    for ii = 1:numel(rho_list)
        rho = rho_list(ii);
        stress_cases(end+1) = make_stress_case_local('coherence_rho', ... %#ok<AGROW>
            ['rho_', num_label_local(rho)], rho, 1, 0, 0, 0, 0, rho);
    end

    stress_cases(end+1) = make_stress_case_local('extreme_combo', 'case_A_beta0p5_el5_rho1_ph0', 1, 0.5, 0, 5, 0, 0, 1); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('extreme_combo', 'case_B_beta0p5_el10_rho1_ph30', 2, 0.5, 0, 10, 0, 30, 1); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('extreme_combo', 'case_C_beta0p8_el5_rho0p9_ph30', 3, 0.8, 0, 5, 0, 30, 0.9); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('extreme_combo', 'case_D_beta0p3_el10_rho0p9_ph60', 4, 0.3, 0, 10, 0, 60, 0.9); %#ok<AGROW>
    stress_cases(end+1) = make_stress_case_local('extreme_combo', 'case_E_beta1_el15_rho0p7_ph90', 5, 1.0, 0, 15, 0, 90, 0.7); %#ok<AGROW>
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
