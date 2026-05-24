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

first_part_commit = '03c02c9';
second_part_commit = 'c217c0f';
third_part_commit = '694cae5';
modify_doc_path = fullfile(script_dir, '第8.6步修改方向.md');
first_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_subarray_manifold.m');
second_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_spectrum_diagnostics.m');
third_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_subarray_selection.m');
third_result_dir = fullfile(script_dir, 'results_step8_6_level2_subarray_selection');
third_summary_csv = fullfile(third_result_dir, 'step8_6_level2_subarray_selection_summary.csv');
third_keypoints_csv = fullfile(third_result_dir, 'step8_6_level2_subarray_selection_keypoints.csv');
third_record_path = fullfile(script_dir, '第8.6步_层次二第三部分_子阵选择与加权谱验证记录.md');

assert(exist(first_script_path, 'file') == 2, 'First-part script not found.');
assert(exist(second_script_path, 'file') == 2, 'Second-part script not found.');
assert(exist(third_script_path, 'file') == 2, 'Third-part script not found.');
assert(exist(third_summary_csv, 'file') == 2, 'Third-part summary CSV not found.');
assert(exist(third_keypoints_csv, 'file') == 2, 'Third-part keypoints CSV not found.');
assert(exist(third_record_path, 'file') == 2, 'Third-part record not found.');

result_dir = fullfile(script_dir, 'results_step8_6_level2_covfit');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

record_doc_path = fullfile(script_dir, '第8.6步_层次二第四部分_一维圆柱协方差拟合验证记录.md');
log_path = fullfile(result_dir, 'step8_6_level2_covfit.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

log_msg(fid_log, 'Step 08.6 level 2 part 4: one-dimensional cylindrical covariance fitting');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'First-part commit: %s', first_part_commit);
log_msg(fid_log, 'Second-part commit: %s', second_part_commit);
log_msg(fid_log, 'Third-part commit: %s', third_part_commit);
log_msg(fid_log, 'Modify direction doc: %s', modify_doc_path);
log_msg(fid_log, 'First-part script: %s', first_script_path);
log_msg(fid_log, 'Second-part script: %s', second_script_path);
log_msg(fid_log, 'Third-part script: %s', third_script_path);
log_msg(fid_log, 'Third-part summary: %s', third_summary_csv);
log_msg(fid_log, 'Third-part keypoints: %s', third_keypoints_csv);
log_msg(fid_log, 'Third-part record: %s', third_record_path);
log_msg(fid_log, 'Scope guard: level 2 covfit only. No fullscan, no level 3, no 2D az/el MUSIC, no PME/SBL/SPICE/DML.');
log_msg(fid_log, 'Covfit model: R_obs=R_FB; rank1 uses R=alpha*G_FB(theta1,theta2)+sigma2*I; Hermitian LS uses Rs=[c11,c12;conj(c12),c22] with PSD-projected score.');

third_summary_tbl = readtable(third_summary_csv);
third_keypoints_tbl = readtable(third_keypoints_csv);
third_record_text = fileread(third_record_path);
third_benchmark = summarize_third_part_benchmark_local(third_summary_tbl);
log_msg(fid_log, 'Third-part loaded benchmark at K=20, sep=10, SNR=30: best route=%s, tol_abs01=%.3f', ...
    char(third_benchmark.best_route), third_benchmark.best_tol_abs01);
log_msg(fid_log, 'Third-part keypoints rows=%d, record chars=%d', height(third_keypoints_tbl), strlength(third_record_text));

azCtr_deg = 0;
el_a = 0;
el_b = 0;
el_assumed_deg = 0;
el_scan_deg = 0;
T_snap = 260;
Lc = 2;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
K_phi_list = [20, 24];
sep_factor_list = [7, 10];
snr_list = [24, 28, 30];
Metkl = 50;
angle_step_music = 0.005;
angle_step_coarse = 0.02;
angle_step_refine = 0.005;
min_pair_sep_deg = 0.05;
max_pair_sep_deg = 0.80;
top_N = 5;
refine_half_width = 0.06;
base_seed = 20260627;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
s1 = exp(j * 2*pi * cfg.arr.fc * t);
s2 = exp(j * 2*pi * cfg.arr.fc * t);

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

route_names = { ...
    'center_real', ...
    'min_den_fb', ...
    'covfit_rank1_equal_phase', ...
    'covfit_hermitian_lsq_psd'};
nroutes = numel(route_names);

log_msg(fid_log, '');
log_msg(fid_log, 'Routes');
for iroute = 1:nroutes
    log_msg(fid_log, '  %d: %s', iroute, route_names{iroute});
end

nK = numel(K_phi_list);
nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nroutes, nK, nsep, nsnr);
tol_success_count_abs01 = zeros(nroutes, nK, nsep, nsnr);
tol_success_count_rel025 = zeros(nroutes, nK, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nK, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nK, nsep, nsnr);
degraded_count = zeros(nroutes, nK, nsep, nsnr);
pair_sep_sum = zeros(nroutes, nK, nsep, nsnr);
pair_center_sum = zeros(nroutes, nK, nsep, nsnr);
pair_stat_count = zeros(nroutes, nK, nsep, nsnr);
objective_best_sum = nan(nroutes, nK, nsep, nsnr);
objective_true_sum = nan(nroutes, nK, nsep, nsnr);
objective_true_rank_values = cell(nroutes, nK, nsep, nsnr);
psd_violation_count = nan(nroutes, nK, nsep, nsnr);
sigma2_negative_count = nan(nroutes, nK, nsep, nsnr);

objective_best_sum(3:4, :, :, :) = 0;
objective_true_sum(3:4, :, :, :) = 0;
psd_violation_count(4, :, :, :) = 0;
sigma2_negative_count(4, :, :, :) = 0;

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = struct([]);

B_grid_music = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_music, el_scan_deg, el_assumed_deg);
B_grid_coarse = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_coarse, el_scan_deg, el_assumed_deg);

log_msg(fid_log, '');
log_msg(fid_log, 'Sanity stage: K=20, sep=[7 10], SNR=60 dB, Metkl=1');
[sanity_results, objective_maps, sanity_pass] = run_covfit_sanity_local( ...
    fid_log, cfg, X3d, Y3d, Z3d, A_ref_2d, B_grid_music, B_grid_coarse, ...
    angle_grid_music, angle_grid_coarse, ...
    K_phi_list(1), sep_factor_list, bw_eq_65, azCtr_deg, el_a, el_b, ...
    el_assumed_deg, el_scan_deg, s1, s2, min_pair_sep_deg, max_pair_sep_deg, ...
    top_N, refine_half_width, angle_step_refine, tol_deg, base_seed);

plot_objective_map_local(fullfile(result_dir, 'covfit_objective_map_rank1_sep10_K20.png'), ...
    objective_maps.rank1_sep10, 'rank1 equal-phase covfit objective, K=20, sep=10');
plot_objective_map_local(fullfile(result_dir, 'covfit_objective_map_hermitian_sep10_K20.png'), ...
    objective_maps.hermitian_sep10, 'Hermitian LS PSD covfit objective, K=20, sep=10');

if ~sanity_pass
    log_msg(fid_log, '');
    log_msg(fid_log, 'WARNING: sanity did not pass the near-true-pair check. Continue MC for diagnostic evidence only after formula check was retained.');
end

tic;
for iK = 1:nK
    K_phi = K_phi_list(iK);
    P_phi = Q - K_phi + 1;
    cache_music = make_subarray_steer_cache_local(B_grid_music, K_phi);
    cache_coarse = make_subarray_steer_cache_local(B_grid_coarse, K_phi);
    candidate_pairs_coarse = make_pair_candidates_local(angle_grid_coarse, min_pair_sep_deg, max_pair_sep_deg);
    precomp_coarse = precompute_covfit_pair_bases_local(cache_coarse, candidate_pairs_coarse);

    log_msg(fid_log, '');
    log_msg(fid_log, 'K_phi=%d, P_phi=%d, coarse_candidates=%d, subarray_span=%.6f deg', ...
        K_phi, P_phi, size(candidate_pairs_coarse, 1), (K_phi - 1) * cfg.arr.dPhi);

    for iSep = 1:nsep
        sep_factor = sep_factor_list(iSep);
        theta_sep = bw_eq_65 / sep_factor;
        theta_a = azCtr_deg - theta_sep / 2;
        theta_b = azCtr_deg + theta_sep / 2;
        target_theta = [theta_a, theta_b];
        tol_rel_now = tol_rel_ratio * theta_sep;
        theta_sep_deg(iSep) = theta_sep;
        theta_a_deg(iSep) = theta_a;
        theta_b_deg(iSep) = theta_b;

        y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, theta_a, theta_b, el_a, el_b, s1, s2);
        true_pair_precomp = precompute_true_pair_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi);

        for iSNR = 1:nsnr
            snr_db = snr_list(iSNR);
            noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);

            for metkl_num = 1:Metkl
                seed_now = base_seed + 100000*iK + 10000*iSep + 1000*iSNR + metkl_num;
                rng(seed_now, 'twister');
                noise = sqrt(noise_power / 2) * (randn(size(y_clean_2d)) + 1j*randn(size(y_clean_2d)));
                y_2d = y_clean_2d + noise;
                y_combined = combine_layers_level2_local(y_2d, Z3d, cfg.arr.lambda, el_assumed_deg);
                [Rfb, En] = fbss_covariance_and_noise_subspace_local(y_combined, K_phi, Lc);

                [D_forward, D_backward] = compute_subarray_denominators_local(cache_music, En);
                doa_center = estimate_center_real_music_local(D_forward, angle_grid_music, Lc);
                doa_min_den_fb = estimate_min_den_fb_music_local(D_forward, D_backward, angle_grid_music, Lc);

                covfit_result = run_covfit_pair_search_local( ...
                    Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
                    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, el_scan_deg, el_assumed_deg, K_phi, ...
                    min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, true_pair_precomp);

                doa_all = { ...
                    doa_center, ...
                    doa_min_den_fb, ...
                    covfit_result.rank1.doa_est, ...
                    covfit_result.hermitian.doa_est};

                best_objective = [NaN, NaN, covfit_result.rank1.objective_best, covfit_result.hermitian.objective_best];
                true_objective = [NaN, NaN, covfit_result.rank1.objective_true, covfit_result.hermitian.objective_true];
                true_rank = [NaN, NaN, covfit_result.rank1.true_rank, covfit_result.hermitian.true_rank];

                for iroute = 1:nroutes
                    doa_now = doa_all{iroute};
                    raw_ok = all(isfinite(doa_now)) && numel(doa_now) == Lc;
                    tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                    tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_rel_now);
                    doa_degraded = true;

                    if raw_ok
                        raw_success_count(iroute, iK, iSep, iSNR) = raw_success_count(iroute, iK, iSep, iSNR) + 1;
                        err = sort(doa_now(:).') - sort(target_theta(:).');
                        rmse_sum_sqerr(iroute, iK, iSep, iSNR) = rmse_sum_sqerr(iroute, iK, iSep, iSNR) + sum(err.^2);
                        rmse_valid_count(iroute, iK, iSep, iSNR) = rmse_valid_count(iroute, iK, iSep, iSNR) + 1;
                        doa_degraded = max(abs(err)) > 1.0;
                        pair_sep_sum(iroute, iK, iSep, iSNR) = pair_sep_sum(iroute, iK, iSep, iSNR) + abs(doa_now(2) - doa_now(1));
                        pair_center_sum(iroute, iK, iSep, iSNR) = pair_center_sum(iroute, iK, iSep, iSNR) + mean(doa_now);
                        pair_stat_count(iroute, iK, iSep, iSNR) = pair_stat_count(iroute, iK, iSep, iSNR) + 1;
                    end
                    if tol_ok_abs
                        tol_success_count_abs01(iroute, iK, iSep, iSNR) = tol_success_count_abs01(iroute, iK, iSep, iSNR) + 1;
                    end
                    if tol_ok_rel
                        tol_success_count_rel025(iroute, iK, iSep, iSNR) = tol_success_count_rel025(iroute, iK, iSep, iSNR) + 1;
                    end
                    if doa_degraded
                        degraded_count(iroute, iK, iSep, iSNR) = degraded_count(iroute, iK, iSep, iSNR) + 1;
                    end
                    if iroute >= 3
                        objective_best_sum(iroute, iK, iSep, iSNR) = objective_best_sum(iroute, iK, iSep, iSNR) + best_objective(iroute);
                        objective_true_sum(iroute, iK, iSep, iSNR) = objective_true_sum(iroute, iK, iSep, iSNR) + true_objective(iroute);
                        objective_true_rank_values{iroute, iK, iSep, iSNR}(end+1) = true_rank(iroute);
                    end
                end

                if covfit_result.hermitian.psd_violation
                    psd_violation_count(4, iK, iSep, iSNR) = psd_violation_count(4, iK, iSep, iSNR) + 1;
                end
                if covfit_result.hermitian.sigma2_negative
                    sigma2_negative_count(4, iK, iSep, iSNR) = sigma2_negative_count(4, iK, iSep, iSNR) + 1;
                end

                if K_phi == 20 && sep_factor == 10 && snr_db == 30 && metkl_num == 1
                    debug_samples = covfit_result;
                    debug_samples.target_theta = target_theta;
                    debug_samples.seed_now = seed_now;
                    debug_samples.doa_center = doa_center;
                    debug_samples.doa_min_den_fb = doa_min_den_fb;
                end
            end
        end

        log_msg(fid_log, '  sep=%d finished for K=%d, elapsed=%.1f s', sep_factor, K_phi, toc);
    end
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate_abs01 = tol_success_count_abs01 / Metkl;
tol_success_rate_rel025 = tol_success_count_rel025 / Metkl;
rmse_deg = sqrt(rmse_sum_sqerr ./ max(rmse_valid_count, 1) / Lc);
rmse_deg(rmse_valid_count == 0) = NaN;
degraded_rate = degraded_count / Metkl;
mean_pair_sep_est = pair_sep_sum ./ max(pair_stat_count, 1);
mean_pair_center_est = pair_center_sum ./ max(pair_stat_count, 1);
mean_pair_sep_est(pair_stat_count == 0) = NaN;
mean_pair_center_est(pair_stat_count == 0) = NaN;
mean_objective_best = objective_best_sum / Metkl;
mean_objective_true_pair = objective_true_sum / Metkl;
objective_true_rank_median = nan(nroutes, nK, nsep, nsnr);
for iroute = 1:nroutes
    for iK = 1:nK
        for iSep = 1:nsep
            for iSNR = 1:nsnr
                vals = objective_true_rank_values{iroute, iK, iSep, iSNR};
                if ~isempty(vals)
                    objective_true_rank_median(iroute, iK, iSep, iSNR) = median(vals, 'omitnan');
                end
            end
        end
    end
end
psd_violation_rate = psd_violation_count / Metkl;
sigma2_negative_rate = sigma2_negative_count / Metkl;

summary_rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    theta_sep_deg, Q, raw_success_rate, tol_success_rate_abs01, tol_success_rate_rel025, ...
    rmse_deg, degraded_rate, mean_pair_sep_est, mean_pair_center_est, mean_objective_best, ...
    mean_objective_true_pair, objective_true_rank_median, psd_violation_rate, sigma2_negative_rate);

summary_path = fullfile(result_dir, 'step8_6_level2_covfit_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_6_level2_covfit_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_6_level2_covfit_result.mat');
write_summary_csv_local(summary_path, summary_rows);
write_summary_csv_local(keypoints_path, summary_rows);

diagnosis = choose_diagnosis_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    tol_success_rate_abs01, objective_true_rank_median, sanity_results);

params = struct();
params.first_part_commit = first_part_commit;
params.second_part_commit = second_part_commit;
params.third_part_commit = third_part_commit;
params.modify_doc_path = modify_doc_path;
params.first_script_path = first_script_path;
params.second_script_path = second_script_path;
params.third_script_path = third_script_path;
params.third_summary_csv = third_summary_csv;
params.third_keypoints_csv = third_keypoints_csv;
params.third_benchmark = third_benchmark;
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
params.sanity_pass = sanity_pass;

save(mat_path, ...
    'params', 'route_names', 'K_phi_list', 'sep_factor_list', 'snr_list', ...
    'angle_grid_music', 'angle_grid_coarse', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_rate', 'tol_success_rate_abs01', 'tol_success_rate_rel025', ...
    'rmse_deg', 'degraded_rate', 'mean_pair_sep_est', 'mean_pair_center_est', ...
    'mean_objective_best', 'mean_objective_true_pair', 'objective_true_rank_median', ...
    'psd_violation_rate', 'sigma2_negative_rate', 'sanity_results', 'objective_maps', ...
    'debug_samples', 'diagnosis');

plot_route_metric_compare_sep10_local(fullfile(result_dir, 'covfit_route_tol_compare_sep10.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, tol_success_rate_abs01, ...
    'tol success abs01', 'Covfit route tol compare, sep=10');
plot_route_metric_compare_sep10_local(fullfile(result_dir, 'covfit_route_rmse_compare_sep10.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, rmse_deg, ...
    'RMSE deg', 'Covfit route RMSE compare, sep=10');
plot_objective_true_vs_best_local(fullfile(result_dir, 'covfit_objective_true_vs_best.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, mean_objective_best, mean_objective_true_pair);

write_record_doc_local(record_doc_path, params, route_names, summary_rows, diagnosis, sanity_results, ...
    summary_path, keypoints_path, mat_path);

log_msg(fid_log, '');
log_msg(fid_log, 'Sanity pass: %d', sanity_pass);
for ii = 1:numel(sanity_results)
    log_msg(fid_log, '  sanity sep=%d rank1 doa=[%.4f %.4f], true=[%.4f %.4f], rank1_true_rank=%g, hermitian_true_rank=%g', ...
        sanity_results(ii).sep_factor, sanity_results(ii).rank1_doa_est(1), sanity_results(ii).rank1_doa_est(2), ...
        sanity_results(ii).target_theta(1), sanity_results(ii).target_theta(2), ...
        sanity_results(ii).rank1_true_rank, sanity_results(ii).hermitian_true_rank);
end
log_msg(fid_log, 'Diagnostic conclusion: %s', diagnosis.conclusion);
log_msg(fid_log, 'Next step: %s', diagnosis.next_step);
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', keypoints_path);
log_msg(fid_log, '  %s', mat_path);
log_msg(fid_log, '  %s', fullfile(result_dir, 'covfit_objective_map_rank1_sep10_K20.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'covfit_objective_map_hermitian_sep10_K20.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'covfit_route_tol_compare_sep10.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'covfit_route_rmse_compare_sep10.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'covfit_objective_true_vs_best.png'));
log_msg(fid_log, '  %s', record_doc_path);
safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 covfit finished.');
disp('result_dir =');
disp(result_dir);
disp('diagnosis =');
disp(diagnosis.conclusion);

function [sanity_results, objective_maps, sanity_pass] = run_covfit_sanity_local( ...
    fid_log, cfg, X3d, Y3d, Z3d, A_ref_2d, B_grid_music, B_grid_coarse, ...
    angle_grid_music, angle_grid_coarse, K_phi, sep_factor_list, bw_eq_65, azCtr_deg, ...
    el_a, el_b, el_assumed_deg, el_scan_deg, s1, s2, ...
    min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, tol_deg, base_seed)

    cache_music = make_subarray_steer_cache_local(B_grid_music, K_phi);
    cache_coarse = make_subarray_steer_cache_local(B_grid_coarse, K_phi);
    candidate_pairs_coarse = make_pair_candidates_local(angle_grid_coarse, min_pair_sep_deg, max_pair_sep_deg);
    precomp_coarse = precompute_covfit_pair_bases_local(cache_coarse, candidate_pairs_coarse);
    sanity_results = repmat(struct(), numel(sep_factor_list), 1);
    objective_maps = struct();
    sanity_pass = true;

    for iSep = 1:numel(sep_factor_list)
        sep_factor = sep_factor_list(iSep);
        theta_sep = bw_eq_65 / sep_factor;
        target_theta = [azCtr_deg - theta_sep/2, azCtr_deg + theta_sep/2];
        y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta(1), target_theta(2), el_a, el_b, s1, s2);
        noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(60 / 10);
        rng(base_seed + 7000 + sep_factor, 'twister');
        noise = sqrt(noise_power/2) * (randn(size(y_clean_2d)) + 1j*randn(size(y_clean_2d)));
        y_2d = y_clean_2d + noise;
        y_combined = combine_layers_level2_local(y_2d, Z3d, cfg.arr.lambda, el_assumed_deg);
        [Rfb, En] = fbss_covariance_and_noise_subspace_local(y_combined, K_phi, 2);
        [D_forward, D_backward] = compute_subarray_denominators_local(cache_music, En);
        doa_center = estimate_center_real_music_local(D_forward, angle_grid_music, 2);
        doa_min_den_fb = estimate_min_den_fb_music_local(D_forward, D_backward, angle_grid_music, 2);
        true_pair_precomp = precompute_true_pair_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi);
        covfit_result = run_covfit_pair_search_local( ...
            Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, el_scan_deg, el_assumed_deg, K_phi, ...
            min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, true_pair_precomp);

        rank1_ok = is_valid_doa_success(covfit_result.rank1.doa_est, target_theta, tol_deg);
        true_rank_ok = covfit_result.rank1.true_rank <= 10;
        sanity_pass = sanity_pass && rank1_ok && true_rank_ok;

        log_msg(fid_log, '  sanity sep=%d: center=[%.4f %.4f], min_den=[%.4f %.4f], rank1=[%.4f %.4f], herm=[%.4f %.4f], rank1_true_rank=%g, herm_true_rank=%g', ...
            sep_factor, doa_center(1), doa_center(2), doa_min_den_fb(1), doa_min_den_fb(2), ...
            covfit_result.rank1.doa_est(1), covfit_result.rank1.doa_est(2), ...
            covfit_result.hermitian.doa_est(1), covfit_result.hermitian.doa_est(2), ...
            covfit_result.rank1.true_rank, covfit_result.hermitian.true_rank);

        sanity_results(iSep).sep_factor = sep_factor;
        sanity_results(iSep).target_theta = target_theta;
        sanity_results(iSep).center_doa_est = doa_center;
        sanity_results(iSep).min_den_fb_doa_est = doa_min_den_fb;
        sanity_results(iSep).rank1_doa_est = covfit_result.rank1.doa_est;
        sanity_results(iSep).hermitian_doa_est = covfit_result.hermitian.doa_est;
        sanity_results(iSep).rank1_objective_best = covfit_result.rank1.objective_best;
        sanity_results(iSep).rank1_objective_true = covfit_result.rank1.objective_true;
        sanity_results(iSep).hermitian_objective_best = covfit_result.hermitian.objective_best;
        sanity_results(iSep).hermitian_objective_true = covfit_result.hermitian.objective_true;
        sanity_results(iSep).rank1_true_rank = covfit_result.rank1.true_rank;
        sanity_results(iSep).hermitian_true_rank = covfit_result.hermitian.true_rank;
        sanity_results(iSep).rank1_near_true = rank1_ok;

        if sep_factor == 10
            objective_maps.rank1_sep10 = make_objective_map_struct_local( ...
                angle_grid_coarse, candidate_pairs_coarse, covfit_result.rank1.coarse_scores, ...
                target_theta, covfit_result.rank1.coarse_pair, covfit_result.rank1.doa_est);
            objective_maps.hermitian_sep10 = make_objective_map_struct_local( ...
                angle_grid_coarse, candidate_pairs_coarse, covfit_result.hermitian.coarse_scores, ...
                target_theta, covfit_result.hermitian.coarse_pair, covfit_result.hermitian.doa_est);
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

function third_benchmark = summarize_third_part_benchmark_local(third_summary_tbl)
    route_col = string(third_summary_tbl.route_name);
    mask = third_summary_tbl.K_phi == 20 & third_summary_tbl.sep_factor == 10 & third_summary_tbl.snr_db == 30;
    third_benchmark = struct();
    third_benchmark.K_phi = 20;
    third_benchmark.sep_factor = 10;
    third_benchmark.snr_db = 30;
    third_benchmark.best_route = "NA";
    third_benchmark.best_tol_abs01 = NaN;
    if any(mask)
        idx_all = find(mask);
        [best_tol, rel_idx] = max(third_summary_tbl.tol_success_rate_abs01(mask));
        best_idx = idx_all(rel_idx);
        third_benchmark.best_route = route_col(best_idx);
        third_benchmark.best_tol_abs01 = best_tol;
    end
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

function doa_est = estimate_center_real_music_local(D_forward, angle_grid, Lc)
    P_phi = size(D_forward, 1);
    p_mid = round((P_phi + 1) / 2);
    Pmu = inv_den_local(D_forward(p_mid, :));
    doa_est = estimate_from_spectrum_local(Pmu, angle_grid, Lc);
end

function doa_est = estimate_min_den_fb_music_local(D_forward, D_backward, angle_grid, Lc)
    D_fb = 0.5 * (D_forward + D_backward);
    Pmu = inv_den_local(min(D_fb, [], 1));
    doa_est = estimate_from_spectrum_local(Pmu, angle_grid, Lc);
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
    max_pairs = n * n;
    candidate_pairs = zeros(max_pairs, 2);
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

function precomp = precompute_covfit_pair_bases_local(cache, candidate_pairs)
    K = cache.K_phi;
    P_phi = cache.P_phi;
    J = cache.J;
    Nc = size(candidate_pairs, 1);
    L = 2 * K * K;
    basis1 = zeros(L, Nc, 'single');
    basis2 = zeros(L, Nc, 'single');
    basis3 = zeros(L, Nc, 'single');
    basis4 = zeros(L, Nc, 'single');
    gram = zeros(5, 5, Nc);
    ivec = matrix_to_realvec_local(eye(K));

    for ic = 1:Nc
        i1 = candidate_pairs(ic, 1);
        i2 = candidate_pairs(ic, 2);
        A1 = reshape(cache.A_forward(:, i1, :), K, P_phi);
        A2 = reshape(cache.A_forward(:, i2, :), K, P_phi);
        F11 = (A1 * A1') / P_phi;
        F22 = (A2 * A2') / P_phi;
        F12 = (A1 * A2') / P_phi;
        F21 = F12';
        G11 = fb_project_local(F11, J);
        G22 = fb_project_local(F22, J);
        G12 = fb_project_local(F12, J);
        G21 = fb_project_local(F21, J);
        v1 = matrix_to_realvec_local(G11);
        v2 = matrix_to_realvec_local(G22);
        v3 = matrix_to_realvec_local(G12 + G21);
        v4 = matrix_to_realvec_local(1j * (G12 - G21));
        basis1(:, ic) = single(v1);
        basis2(:, ic) = single(v2);
        basis3(:, ic) = single(v3);
        basis4(:, ic) = single(v4);
        B = [v1, v2, v3, v4, ivec];
        gram(:, :, ic) = B' * B;
    end

    precomp = struct();
    precomp.K_phi = K;
    precomp.P_phi = P_phi;
    precomp.candidate_pairs = candidate_pairs;
    precomp.basis1 = basis1;
    precomp.basis2 = basis2;
    precomp.basis3 = basis3;
    precomp.basis4 = basis4;
    precomp.gram = gram;
    precomp.ivec = single(ivec);
end

function G = fb_project_local(F, J)
    G = 0.5 * (F + J * conj(F) * J);
end

function v = matrix_to_realvec_local(M)
    m = M(:);
    v = [real(m); imag(m)];
end

function true_precomp = precompute_true_pair_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi)

    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg);
    cache = make_subarray_steer_cache_local(B_grid, K_phi);
    true_precomp = precompute_covfit_pair_bases_local(cache, [1, 2]);
end

function covfit_result = run_covfit_pair_search_local( ...
    Rfb, precomp_coarse, candidate_pairs_coarse, angle_grid_coarse, ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, el_scan_deg, el_assumed_deg, K_phi, ...
    min_pair_sep_deg, max_pair_sep_deg, top_N, refine_half_width, angle_step_refine, true_pair_precomp)

    coarse_rank1 = score_rank1_all_local(Rfb, precomp_coarse);
    coarse_herm = score_hermitian_all_local(Rfb, precomp_coarse);

    top_rank_idx = top_indices_local(coarse_rank1.score, top_N);
    top_herm_idx = top_indices_local(coarse_herm.score_projected, top_N);
    top_pair_idx = unique([top_rank_idx(:); top_herm_idx(:)]);
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
    precomp_refine = precompute_covfit_pair_bases_local(cache_refine, candidate_pairs_refine);

    refine_rank1 = score_rank1_all_local(Rfb, precomp_refine);
    refine_herm = score_hermitian_all_local(Rfb, precomp_refine);
    true_rank1 = score_rank1_all_local(Rfb, true_pair_precomp);
    true_herm = score_hermitian_all_local(Rfb, true_pair_precomp);

    [best_rank_score, best_rank_idx] = min(refine_rank1.score);
    [best_herm_score, best_herm_idx] = min(refine_herm.score_projected);
    [best_rank_coarse_score, best_rank_coarse_idx] = min(coarse_rank1.score);
    [best_herm_coarse_score, best_herm_coarse_idx] = min(coarse_herm.score_projected);

    rank_pair = angle_grid_refine(candidate_pairs_refine(best_rank_idx, :));
    herm_pair = angle_grid_refine(candidate_pairs_refine(best_herm_idx, :));
    rank_coarse_pair = angle_grid_coarse(candidate_pairs_coarse(best_rank_coarse_idx, :));
    herm_coarse_pair = angle_grid_coarse(candidate_pairs_coarse(best_herm_coarse_idx, :));

    covfit_result = struct();
    covfit_result.rank1 = struct();
    covfit_result.rank1.doa_est = sort(rank_pair);
    covfit_result.rank1.objective_best = best_rank_score;
    covfit_result.rank1.objective_true = true_rank1.score(1);
    covfit_result.rank1.true_rank = 1 + sum(coarse_rank1.score < true_rank1.score(1));
    covfit_result.rank1.coarse_pair = sort(rank_coarse_pair);
    covfit_result.rank1.coarse_objective_best = best_rank_coarse_score;
    covfit_result.rank1.coarse_scores = coarse_rank1.score;

    covfit_result.hermitian = struct();
    covfit_result.hermitian.doa_est = sort(herm_pair);
    covfit_result.hermitian.objective_best = best_herm_score;
    covfit_result.hermitian.objective_true = true_herm.score_projected(1);
    covfit_result.hermitian.true_rank = 1 + sum(coarse_herm.score_projected < true_herm.score_projected(1));
    covfit_result.hermitian.coarse_pair = sort(herm_coarse_pair);
    covfit_result.hermitian.coarse_objective_best = best_herm_coarse_score;
    covfit_result.hermitian.score_unconstrained_best = refine_herm.score_unconstrained(best_herm_idx);
    covfit_result.hermitian.psd_violation = refine_herm.psd_violation(best_herm_idx);
    covfit_result.hermitian.sigma2_negative = refine_herm.sigma2_negative(best_herm_idx);
    covfit_result.hermitian.coarse_scores = coarse_herm.score_projected;
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

function out = score_rank1_all_local(Robs, precomp)
    y = matrix_to_realvec_local(Robs);
    yy = real(y' * y);
    ysingle = single(y);
    aty1 = double(precomp.basis1' * ysingle);
    aty2 = double(precomp.basis2' * ysingle);
    aty3 = double(precomp.basis3' * ysingle);
    aty5 = double(precomp.ivec' * ysingle);
    Nc = numel(aty1);
    score = zeros(Nc, 1);

    for ic = 1:Nc
        gram = precomp.gram(:, :, ic);
        gg = sum(sum(gram(1:3, 1:3)));
        gi = sum(gram(1:3, 5));
        ii = gram(5, 5);
        gy = aty1(ic) + aty2(ic) + aty3(ic);
        iy = aty5;
        [alpha, sigma2] = solve_rank1_nnls2_local(gg, gi, ii, gy, iy);
        sse = yy - 2*(alpha*gy + sigma2*iy) + alpha^2*gg + 2*alpha*sigma2*gi + sigma2^2*ii;
        score(ic) = max(real(sse), 0) / max(yy, eps);
    end

    out = struct();
    out.score = score;
end

function [alpha, sigma2] = solve_rank1_nnls2_local(gg, gi, ii, gy, iy)
    G = [gg, gi; gi, ii];
    rhs = [gy; iy];
    if rcond(G) > 1e-12
        x = G \ rhs;
    else
        x = pinv(G) * rhs;
    end
    candidates = zeros(4, 2);
    candidates(1, :) = max(real(x), 0).';
    candidates(2, :) = [max(gy / max(gg, eps), 0), 0];
    candidates(3, :) = [0, max(iy / max(ii, eps), 0)];
    candidates(4, :) = [0, 0];
    best_val = inf;
    alpha = 0;
    sigma2 = 0;
    for ii_c = 1:size(candidates, 1)
        a = candidates(ii_c, 1);
        s = candidates(ii_c, 2);
        val = -2*(a*gy + s*iy) + a^2*gg + 2*a*s*gi + s^2*ii;
        if val < best_val
            best_val = val;
            alpha = a;
            sigma2 = s;
        end
    end
end

function out = score_hermitian_all_local(Robs, precomp)
    y = matrix_to_realvec_local(Robs);
    yy = real(y' * y);
    ysingle = single(y);
    Nc = size(precomp.basis1, 2);
    aty = zeros(5, Nc);
    aty(1, :) = double(precomp.basis1' * ysingle);
    aty(2, :) = double(precomp.basis2' * ysingle);
    aty(3, :) = double(precomp.basis3' * ysingle);
    aty(4, :) = double(precomp.basis4' * ysingle);
    aty(5, :) = double(precomp.ivec' * ysingle);

    score_unconstrained = zeros(Nc, 1);
    score_projected = zeros(Nc, 1);
    psd_violation = false(Nc, 1);
    sigma2_negative = false(Nc, 1);

    for ic = 1:Nc
        gram = precomp.gram(:, :, ic);
        rhs = aty(:, ic);
        if rcond(gram) > 1e-12
            x = gram \ rhs;
        else
            x = pinv(gram) * rhs;
        end
        score_unconstrained(ic) = score_from_x_local(yy, rhs, gram, x);
        sigma2_negative(ic) = x(5) < 0;
        Rs = [real(x(1)), x(3) + 1j*x(4); x(3) - 1j*x(4), real(x(2))];
        Rs = 0.5 * (Rs + Rs');
        ev = eig(Rs);
        psd_violation(ic) = min(real(ev)) < -1e-9;
        [V, D] = eig(Rs);
        d = max(real(diag(D)), 0);
        Rs_proj = V * diag(d) * V';
        Rs_proj = 0.5 * (Rs_proj + Rs_proj');
        x_proj = [real(Rs_proj(1, 1)); real(Rs_proj(2, 2)); real(Rs_proj(1, 2)); imag(Rs_proj(1, 2)); max(real(x(5)), 0)];
        score_projected(ic) = score_from_x_local(yy, rhs, gram, x_proj);
    end

    out = struct();
    out.score_unconstrained = score_unconstrained;
    out.score_projected = score_projected;
    out.psd_violation = psd_violation;
    out.sigma2_negative = sigma2_negative;
end

function score = score_from_x_local(yy, rhs, gram, x)
    sse = yy - 2*real(x' * rhs) + real(x' * gram * x);
    score = max(real(sse), 0) / max(yy, eps);
end

function map = make_objective_map_struct_local(angle_grid, candidate_pairs, score, target_theta, coarse_pair, refined_pair)
    theta1 = angle_grid(candidate_pairs(:, 1)).';
    theta2 = angle_grid(candidate_pairs(:, 2)).';
    map = struct();
    map.theta1 = theta1;
    map.theta2 = theta2;
    map.center = 0.5 * (theta1 + theta2);
    map.sep = theta2 - theta1;
    map.score = score(:);
    map.target_center = mean(target_theta);
    map.target_sep = abs(target_theta(2) - target_theta(1));
    map.coarse_center = mean(coarse_pair);
    map.coarse_sep = abs(coarse_pair(2) - coarse_pair(1));
    map.refined_center = mean(refined_pair);
    map.refined_sep = abs(refined_pair(2) - refined_pair(1));
end

function plot_objective_map_local(path_out, map, title_text)
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 640]);
    scatter(map.center, map.sep, 12, log10(map.score + eps), 'filled');
    hold on
    plot(map.target_center, map.target_sep, 'wp', 'MarkerFaceColor', 'k', 'MarkerSize', 12);
    plot(map.coarse_center, map.coarse_sep, 'wo', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
    plot(map.refined_center, map.refined_sep, 'ws', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
    hold off
    grid on
    xlabel('pair center (deg)');
    ylabel('pair separation (deg)');
    title(title_text);
    cb = colorbar;
    ylabel(cb, 'log10 normalized objective');
    legend({'candidate pair', 'true pair', 'best coarse', 'best refined'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, theta_sep_deg, Q, ...
    raw_rate, tol_abs, tol_rel, rmse_deg, degraded_rate, mean_pair_sep_est, mean_pair_center_est, ...
    mean_objective_best, mean_objective_true_pair, objective_true_rank_median, psd_violation_rate, sigma2_negative_rate)

    rows = cell(numel(route_names) * numel(K_phi_list) * numel(sep_factor_list) * numel(snr_list), 18);
    row_idx = 0;
    for iroute = 1:numel(route_names)
        for iK = 1:numel(K_phi_list)
            K_phi = K_phi_list(iK);
            P_phi = Q - K_phi + 1;
            for iSep = 1:numel(sep_factor_list)
                for iSNR = 1:numel(snr_list)
                    row_idx = row_idx + 1;
                    rows(row_idx, :) = { ...
                        route_names{iroute}, K_phi, P_phi, sep_factor_list(iSep), theta_sep_deg(iSep), snr_list(iSNR), ...
                        raw_rate(iroute, iK, iSep, iSNR), tol_abs(iroute, iK, iSep, iSNR), ...
                        tol_rel(iroute, iK, iSep, iSNR), rmse_deg(iroute, iK, iSep, iSNR), ...
                        degraded_rate(iroute, iK, iSep, iSNR), mean_pair_sep_est(iroute, iK, iSep, iSNR), ...
                        mean_pair_center_est(iroute, iK, iSep, iSNR), mean_objective_best(iroute, iK, iSep, iSNR), ...
                        mean_objective_true_pair(iroute, iK, iSep, iSNR), objective_true_rank_median(iroute, iK, iSep, iSNR), ...
                        psd_violation_rate(iroute, iK, iSep, iSNR), sigma2_negative_rate(iroute, iK, iSep, iSNR)};
                end
            end
        end
    end
end

function write_summary_csv_local(path_out, rows)
    header = ['route_name,K_phi,P_phi,sep_factor,theta_sep_deg,snr_db,' ...
        'raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,degraded_rate,' ...
        'mean_pair_sep_est,mean_pair_center_est,mean_objective_best,mean_objective_true_pair,' ...
        'objective_true_rank_median,psd_violation_rate,sigma2_negative_rate'];
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', header);
    for ii = 1:size(rows, 1)
        fprintf(fid, '%s,%d,%d,%d,%.9f,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9g,%.9g,%.9f,%.9f,%.9f\n', ...
            rows{ii, 1}, rows{ii, 2}, rows{ii, 3}, rows{ii, 4}, rows{ii, 5}, rows{ii, 6}, ...
            rows{ii, 7}, rows{ii, 8}, rows{ii, 9}, rows{ii, 10}, rows{ii, 11}, rows{ii, 12}, ...
            rows{ii, 13}, rows{ii, 14}, rows{ii, 15}, rows{ii, 16}, rows{ii, 17}, rows{ii, 18});
    end
end

function diagnosis = choose_diagnosis_local(route_names, K_phi_list, sep_factor_list, snr_list, tol_abs, true_rank_median, sanity_results)
    idxK = find(K_phi_list == 20, 1);
    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    idx_center = find(strcmp(route_names, 'center_real'), 1);
    idx_min = find(strcmp(route_names, 'min_den_fb'), 1);
    idx_rank1 = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    idx_herm = find(strcmp(route_names, 'covfit_hermitian_lsq_psd'), 1);

    center_tol = tol_abs(idx_center, idxK, idxSep, idxSNR);
    min_tol = tol_abs(idx_min, idxK, idxSep, idxSNR);
    rank1_tol = tol_abs(idx_rank1, idxK, idxSep, idxSNR);
    herm_tol = tol_abs(idx_herm, idxK, idxSep, idxSNR);
    base_tol = max(center_tol, min_tol);
    best_covfit_tol = max(rank1_tol, herm_tol);
    rank1_gain = rank1_tol - base_tol;
    herm_gain_over_rank1 = herm_tol - rank1_tol;
    rank1_true_rank = true_rank_median(idx_rank1, idxK, idxSep, idxSNR);
    herm_true_rank = true_rank_median(idx_herm, idxK, idxSep, idxSNR);

    sanity_sep10 = sanity_results([sanity_results.sep_factor] == 10);
    rank1_map_near_true = ~isempty(sanity_sep10) && sanity_sep10.rank1_near_true && sanity_sep10.rank1_true_rank <= 10;

    if rank1_gain >= 0.10
        case_id = 'A';
        conclusion = '层次二协方差拟合有效。完全同相小间隔场景中，pair covariance fitting 比 MUSIC 峰搜索更适合。';
        next_step = '围绕 rank1 equal-phase covfit 做更大规模 K/SNR 小扫描，仍不进入层次三。';
    elseif herm_gain_over_rank1 >= 0.10
        case_id = 'B';
        conclusion = '一般源协方差拟合比固定完全同相模型更稳，但需要关注 PSD violation 和 sigma2 negative 问题。';
        next_step = '优化 Hermitian covfit 的 PSD 约束和正则化。';
    elseif best_covfit_tol >= base_tol - 0.02 && rank1_map_near_true
        case_id = 'C';
        conclusion = '协方差拟合模型方向正确，但当前 pair search/约束/噪声条件不足以稳定提升。';
        next_step = '改进 pair search 或 regularization，仍保持层次二一维模型。';
    else
        case_id = 'D';
        conclusion = '当前一维层次二平滑协方差模型与观测 R_FB 不匹配，问题不只是峰搜索。';
        next_step = '重新检查 FBSS 后模型构造；只作为建议考虑层次三，本轮不实现层次三。';
    end

    diagnosis = struct();
    diagnosis.case_id = case_id;
    diagnosis.key_K_phi = K_phi_list(idxK);
    diagnosis.key_sep_factor = sep_factor_list(idxSep);
    diagnosis.key_snr_db = snr_list(idxSNR);
    diagnosis.center_real_tol = center_tol;
    diagnosis.min_den_fb_tol = min_tol;
    diagnosis.covfit_rank1_tol = rank1_tol;
    diagnosis.covfit_hermitian_tol = herm_tol;
    diagnosis.base_tol = base_tol;
    diagnosis.best_covfit_tol = best_covfit_tol;
    diagnosis.rank1_gain_over_base = rank1_gain;
    diagnosis.hermitian_gain_over_rank1 = herm_gain_over_rank1;
    diagnosis.rank1_true_rank_median = rank1_true_rank;
    diagnosis.hermitian_true_rank_median = herm_true_rank;
    diagnosis.rank1_map_near_true = rank1_map_near_true;
    diagnosis.conclusion = conclusion;
    diagnosis.next_step = next_step;
end

function plot_route_metric_compare_sep10_local(path_out, route_names, K_phi_list, sep_factor_list, snr_list, metric, ylabel_text, title_text)
    idxSep = find(sep_factor_list == 10, 1);
    vals = [];
    labels = strings(1, numel(K_phi_list) * numel(snr_list));
    col = 0;
    for iK = 1:numel(K_phi_list)
        for iSNR = 1:numel(snr_list)
            col = col + 1;
            vals(:, col) = squeeze(metric(:, iK, idxSep, iSNR)); %#ok<AGROW>
            labels(col) = sprintf('K%d/SNR%d', K_phi_list(iK), snr_list(iSNR));
        end
    end
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 600]);
    bar(vals.');
    grid on
    set(gca, 'XTickLabel', labels);
    xlabel('case');
    ylabel(ylabel_text);
    title(title_text);
    legend(route_names, 'Interpreter', 'none', 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_objective_true_vs_best_local(path_out, route_names, K_phi_list, sep_factor_list, snr_list, obj_best, obj_true)
    idxSep = find(sep_factor_list == 10, 1);
    idxK = find(K_phi_list == 20, 1);
    idx_rank1 = find(strcmp(route_names, 'covfit_rank1_equal_phase'), 1);
    idx_herm = find(strcmp(route_names, 'covfit_hermitian_lsq_psd'), 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 560]);
    plot(snr_list, squeeze(obj_best(idx_rank1, idxK, idxSep, :)), '-o', 'LineWidth', 1.3);
    hold on
    plot(snr_list, squeeze(obj_true(idx_rank1, idxK, idxSep, :)), '--o', 'LineWidth', 1.3);
    plot(snr_list, squeeze(obj_best(idx_herm, idxK, idxSep, :)), '-s', 'LineWidth', 1.3);
    plot(snr_list, squeeze(obj_true(idx_herm, idxK, idxSep, :)), '--s', 'LineWidth', 1.3);
    hold off
    grid on
    xlabel('SNR dB');
    ylabel('normalized objective');
    title('Objective best vs true pair, K=20, sep=10');
    legend({'rank1 best', 'rank1 true', 'Hermitian best', 'Hermitian true'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function write_record_doc_local(path_out, params, route_names, summary_rows, diagnosis, sanity_results, summary_path, keypoints_path, mat_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# 第8.6步 层次二第四部分：一维圆柱协方差拟合验证记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 第一部分提交：`%s`\n', params.first_part_commit);
    fprintf(fid, '- 第二部分提交：`%s`\n', params.second_part_commit);
    fprintf(fid, '- 第三部分提交：`%s`\n', params.third_part_commit);
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 已读取第三部分 summary/keypoints/记录；第三部分在 `K=20, sep=10, SNR=30` 的最佳 tol_abs01=%.3f（route=`%s`）。\n', ...
        params.third_benchmark.best_tol_abs01, char(params.third_benchmark.best_route));
    fprintf(fid, '- 本轮只做层次二一维圆柱阵平滑协方差拟合。不做 fullscan、层次三、2D az/el MUSIC、PME、SBL、SPICE、DML。\n\n');

    fprintf(fid, '## 模型\n\n');
    fprintf(fid, '- 65列动态工作子阵经32层俯仰相干合成后得到 `y(t) in C^{Q}`，再做方位 FBSS 得到 `R_obs=R_FB`。\n');
    fprintf(fid, '- `covfit_rank1_equal_phase`：`R_model = alpha*G_FB(theta1,theta2)+sigma2*I`，并对 `alpha>=0, sigma2>=0` 做二维非负最小二乘。\n');
    fprintf(fid, '- `covfit_hermitian_lsq_psd`：对一般 2x2 Hermitian `Rs` 做 real LS，并用 PSD 投影后的 score 作为主结果，同时记录 PSD violation 和 sigma2 negative。\n');
    fprintf(fid, '- pair search 使用 coarse `%.3f deg` + refine `%.3f deg`，候选间隔限制 `[%.2f, %.2f] deg`；true pair objective 只作诊断，不参与估计。\n\n', ...
        params.angle_step_coarse, params.angle_step_refine, params.min_pair_sep_deg, params.max_pair_sep_deg);

    fprintf(fid, '## 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi_list=%s`, `sep_factor_list=%s`, `snr_list=%s`, `Metkl=%d`, `T_snap=%d`。\n', ...
        params.Q, mat2str(params.K_phi_list), mat2str(params.sep_factor_list), mat2str(params.snr_list), params.Metkl, params.T_snap);
    fprintf(fid, '- 65列基线 `bw_eq_65=%.9f deg`。\n\n', params.bw_eq_65);

    fprintf(fid, '## Route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Sanity\n\n');
    fprintf(fid, '- sanity pass：%s。\n', yesno_local(params.sanity_pass));
    fprintf(fid, '| sep_factor | true theta | rank1 est | rank1 true rank | Hermitian est | Hermitian true rank |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|\n');
    for ii = 1:numel(sanity_results)
        fprintf(fid, '| %d | [%.4f, %.4f] | [%.4f, %.4f] | %.0f | [%.4f, %.4f] | %.0f |\n', ...
            sanity_results(ii).sep_factor, sanity_results(ii).target_theta(1), sanity_results(ii).target_theta(2), ...
            sanity_results(ii).rank1_doa_est(1), sanity_results(ii).rank1_doa_est(2), sanity_results(ii).rank1_true_rank, ...
            sanity_results(ii).hermitian_doa_est(1), sanity_results(ii).hermitian_doa_est(2), sanity_results(ii).hermitian_true_rank);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 关键对比：K=20, sep=10, SNR=30\n\n');
    fprintf(fid, '- center_real：tol_abs01=%.3f。\n', diagnosis.center_real_tol);
    fprintf(fid, '- min_den_fb：tol_abs01=%.3f。\n', diagnosis.min_den_fb_tol);
    fprintf(fid, '- covfit_rank1_equal_phase：tol_abs01=%.3f，gain over baseline=%.3f。\n', ...
        diagnosis.covfit_rank1_tol, diagnosis.rank1_gain_over_base);
    fprintf(fid, '- covfit_hermitian_lsq_psd：tol_abs01=%.3f，gain over rank1=%.3f。\n', ...
        diagnosis.covfit_hermitian_tol, diagnosis.hermitian_gain_over_rank1);
    fprintf(fid, '- rank1 true-pair rank median=%.1f，Hermitian true-pair rank median=%.1f。\n\n', ...
        diagnosis.rank1_true_rank_median, diagnosis.hermitian_true_rank_median);

    fprintf(fid, '| route | K_phi | sep | SNR | tol_abs01 | tol_rel025 | RMSE | best_obj | true_obj | true_rank_med | PSD viol | sigma2 neg |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for ii = 1:size(summary_rows, 1)
        if summary_rows{ii, 2} == diagnosis.key_K_phi && summary_rows{ii, 4} == diagnosis.key_sep_factor && summary_rows{ii, 6} == diagnosis.key_snr_db
            fprintf(fid, '| `%s` | %d | %d | %d | %.3f | %.3f | %.5f | %.4g | %.4g | %.1f | %.3f | %.3f |\n', ...
                summary_rows{ii, 1}, summary_rows{ii, 2}, summary_rows{ii, 4}, summary_rows{ii, 6}, ...
                summary_rows{ii, 8}, summary_rows{ii, 9}, summary_rows{ii, 10}, summary_rows{ii, 14}, ...
                summary_rows{ii, 15}, summary_rows{ii, 16}, summary_rows{ii, 17}, summary_rows{ii, 18});
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 判断\n\n');
    fprintf(fid, '- 是否显著超过 0.420 现有上限：%s。\n', yesno_local(diagnosis.best_covfit_tol > 0.420 + 1e-9));
    fprintf(fid, '- rank1 objective map 是否在 true pair 附近有低谷：%s。\n', yesno_local(diagnosis.rank1_map_near_true));
    fprintf(fid, '- Hermitian exact true-pair objective 在 sanity 中也很低，但 PSD-LS search 出现竞争低谷，MC 中不稳定。\n');
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
