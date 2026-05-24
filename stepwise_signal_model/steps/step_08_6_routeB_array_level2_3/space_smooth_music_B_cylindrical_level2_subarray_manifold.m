clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
step75_dir = fullfile(steps_dir, 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');
step08_dir = fullfile(steps_dir, 'step_08_routeB_innovation');
step85_dir = fullfile(steps_dir, 'step_08_5_routeB_array');

addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
addpath(step75_dir);
addpath(step08_dir);

cfg = sim_cfg();

formula_doc_path = fullfile(script_dir, '第8.6步层次二和三公式推导.md');
record_doc_path = fullfile(script_dir, '第8.6步_层次二_65列真实圆柱子阵流形验证记录.md');
result_dir = fullfile(script_dir, 'results_step8_6_level2_subarray_manifold');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_6_level2_subarray_manifold.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

log_msg(fid_log, 'Step 08.6 level 2: 65-column dynamic subarray + 32-layer coherent combining + 1D real cylindrical subarray-manifold MUSIC');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Formula doc: %s', formula_doc_path);
log_msg(fid_log, 'Reference code paths:');
log_msg(fid_log, '  %s', fullfile(project_dir, 'core', 'config', 'sim_cfg.m'));
log_msg(fid_log, '  %s', fullfile(project_dir, 'core', 'array', 'arr_cyl.m'));
log_msg(fid_log, '  %s', fullfile(step75_dir, 'mssp_array_fb.m'));
log_msg(fid_log, '  %s', fullfile(step75_dir, 'FindLocalPeak_NoEdge_Fun.m'));
log_msg(fid_log, '  %s', fullfile(step75_dir, 'is_valid_doa_success.m'));
log_msg(fid_log, '  %s', fullfile(step08_dir, 'doa_root_music_array.m'));
log_msg(fid_log, '  %s', fullfile(step08_dir, 'space_smooth_music_B_root_music_prototype6.m'));
log_msg(fid_log, '  %s', fullfile(step85_dir, 'space_smooth_music_B_cylindrical_multilayer_prototype14.m'));
log_msg(fid_log, '  %s', fullfile(step85_dir, 'space_smooth_music_B_cylindrical_real_manifold_prototype15a.m'));
log_msg(fid_log, '  %s', fullfile(step85_dir, 'results_step8_5_cylindrical_multilayer_proto14', 'step8_5_cylindrical_multilayer_proto14_keypoints.csv'));
log_msg(fid_log, '  %s', fullfile(step85_dir, 'results_step8_5_cylindrical_multilayer_proto14', 'step8_5_cylindrical_multilayer_proto14_summary.csv'));
log_msg(fid_log, '  %s', fullfile(step85_dir, 'results_step8_5_cylindrical_real_manifold_proto15a', 'step8_5_cylindrical_real_manifold_proto15a_keypoints.csv'));
log_msg(fid_log, '  %s', fullfile(step85_dir, 'results_step8_5_cylindrical_real_manifold_proto15a', 'step8_5_cylindrical_real_manifold_proto15a_summary.csv'));
log_msg(fid_log, '  %s', fullfile(step85_dir, '第8.5步_routeB_array_实验记录.md'));
log_msg(fid_log, '  %s', fullfile(step85_dir, '第8.5步_算法与路线技术规范.md'));
log_msg(fid_log, '');
log_msg(fid_log, 'Scope guard: only level 2 is implemented. No level 3, no 2D az/el MUSIC, no PME, no sparse/DML/SBL/SPICE.');

azCtr_deg = 0;
el_a = 0;
el_b = 0;
el_assumed_deg = 0;
el_scan_deg = 0;
T_snap = 260;
Lc = 2;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
base_seed = 20260624;
K_phi_sanity = 28;
K_phi_scan_list = [24, 28, 32, 40, 48, 56];
sep_factor_sanity = [5, 7, 10];
snr_sanity = [20, 24, 28, 30];
Metkl_sanity = 20;
sep_factor_kphi = [7, 10];
snr_kphi = [24, 28, 30];
Metkl_kphi = 100;
sep_factor_full = [1, 2, 3, 5, 7, 10];
snr_full = -4:2:30;
Metkl_full = 200;
angle_step_sanity = 0.005;
angle_step_kphi = 0.005;
angle_step_full = 0.01;

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
bw_eq_32 = 50.8 * 1.45 * cfg.arr.lambda / ((32 - 1) * d_eq);
work_span_deg = max(arrInfo.phiActRel(col_select)) - min(arrInfo.phiActRel(col_select));
expected_gain_db = 10 * log10(cfg.arr.Nel);
dz_over_lambda = cfg.arr.dz / cfg.arr.lambda;
iel_select = round(cfg.arr.Nel / 2);

log_msg(fid_log, '');
log_msg(fid_log, 'Geometry health check');
log_msg(fid_log, 'cfg.arr.Naz=%d', cfg.arr.Naz);
log_msg(fid_log, 'cfg.arr.Nel=%d', cfg.arr.Nel);
log_msg(fid_log, 'cfg.arr.R=%.9f m', cfg.arr.R);
log_msg(fid_log, 'cfg.arr.lambda=%.9f m', cfg.arr.lambda);
log_msg(fid_log, 'cfg.arr.dz=%.9f m', cfg.arr.dz);
log_msg(fid_log, 'cfg.arr.dPhi=%.9f deg', cfg.arr.dPhi);
log_msg(fid_log, 'cfg.beam.sectorHalf=%.9f deg', cfg.beam.sectorHalf);
log_msg(fid_log, 'cfg.beam.subNaz=%d', cfg.beam.subNaz);
log_msg(fid_log, 'Q=%d', Q);
log_msg(fid_log, 'arrInfo.phiActRel(first)=%.9f deg', arrInfo.phiActRel(col_select(1)));
log_msg(fid_log, 'arrInfo.phiActRel(last)=%.9f deg', arrInfo.phiActRel(col_select(end)));
log_msg(fid_log, 'working subarray azimuth span=%.9f deg, approximately 120 deg=%d', ...
    work_span_deg, abs(work_span_deg - 120) < 1e-9);
log_msg(fid_log, 'z layer count=%d, is 32=%d', size(Z3d, 2), size(Z3d, 2) == 32);
log_msg(fid_log, 'dz/lambda=%.9f', dz_over_lambda);
log_msg(fid_log, '32-layer theoretical coherent gain=%.6f dB', expected_gain_db);
log_msg(fid_log, 'd_eq=%.9f m, d_eq/lambda=%.9f', d_eq, d_eq / cfg.arr.lambda);
log_msg(fid_log, 'bw_eq_65=%.9f deg (main baseline)', bw_eq_65);
log_msg(fid_log, 'bw_eq_32=%.9f deg (history-only proto14 comparison)', bw_eq_32);
if Q ~= 65
    log_msg(fid_log, 'WARNING: cfg.beam.subNaz is %d, expected engineering baseline Q=65.', Q);
else
    log_msg(fid_log, 'Q=65 check passed.');
end
if size(Z3d, 2) ~= 32
    log_msg(fid_log, 'WARNING: elevation layer count is %d, expected 32.', size(Z3d, 2));
end

log_msg(fid_log, '');
log_msg(fid_log, 'Theory positioning');
log_msg(fid_log, 'proto14 N_arc=32 is an old exploratory local-ULA aperture, not the current complete working array.');
log_msg(fid_log, 'The engineering working array is the 65-column sector selected dynamically by arr_cyl(cfg, azCtr_deg).');
log_msg(fid_log, 'Level 2 tests whether the full 65-column sector can be used through a real cylindrical subarray-manifold MUSIC model.');
log_msg(fid_log, 'Level 2 remains a 1D azimuth algorithm: 32 elevation layers are coherently combined and then compressed away.');

route_names = { ...
    'level2_ula_root_music_65col_baseline', ...
    'level2_center_real_grid_music', ...
    'level2_subarray_avg_real_grid_music_forward', ...
    'level2_subarray_avg_real_grid_music_fb'};

log_msg(fid_log, '');
log_msg(fid_log, 'Route definitions');
log_msg(fid_log, 'route 1: %s | 65x32 -> 32-layer combining -> doa_root_music_array with d_eq', route_names{1});
log_msg(fid_log, 'route 2: %s | FBSS En -> center-subarray real cylindrical grid-MUSIC', route_names{2});
log_msg(fid_log, 'route 3: %s | FBSS En -> all forward FBSS subarrays real cylindrical grid-MUSIC', route_names{3});
log_msg(fid_log, 'route 4: %s | FBSS En -> all forward/backward FBSS subarrays real cylindrical grid-MUSIC (main level-2 route)', route_names{4});

y_clean_gain_ref = make_clean_cylindrical_observations_level2_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, -0.5, 0.5, el_a, el_b, s1, s2);
y_clean_combined_ref = combine_layers_level2_local(y_clean_gain_ref, Z3d, cfg.arr.lambda, el_assumed_deg);
y_clean_single_ref = squeeze(y_clean_gain_ref(:, iel_select, :));
clean_gain_ref_db = power_gain_db_local(y_clean_combined_ref, y_clean_single_ref);
log_msg(fid_log, '');
log_msg(fid_log, '32-layer coherent-combining sanity: el_assumed_deg=%.6f, clean_gain_db=%.6f dB, theory=%.6f dB', ...
    el_assumed_deg, clean_gain_ref_db, expected_gain_db);

stage_common = struct();
stage_common.cfg = cfg;
stage_common.route_names = route_names;
stage_common.X3d = X3d;
stage_common.Y3d = Y3d;
stage_common.Z3d = Z3d;
stage_common.A_ref_2d = A_ref_2d;
stage_common.lambda = cfg.arr.lambda;
stage_common.d_eq = d_eq;
stage_common.bw_eq_65 = bw_eq_65;
stage_common.azCtr_deg = azCtr_deg;
stage_common.el_a = el_a;
stage_common.el_b = el_b;
stage_common.el_assumed_deg = el_assumed_deg;
stage_common.el_scan_deg = el_scan_deg;
stage_common.s1 = s1;
stage_common.s2 = s2;
stage_common.Lc = Lc;
stage_common.tol_deg = tol_deg;
stage_common.tol_rel_ratio = tol_rel_ratio;
stage_common.base_seed = base_seed;
stage_common.iel_select = iel_select;
stage_common.full_Q = Q;
stage_common.figure_K_phi = K_phi_sanity;

angle_grid_sanity = (azCtr_deg - bw_eq_65):angle_step_sanity:(azCtr_deg + bw_eq_65);
log_msg(fid_log, '');
log_msg(fid_log, 'Sanity stage starts: sep=%s, snr=%s, Metkl=%d, K_phi=%d, angle step=%.4f deg, ngrid=%d', ...
    mat2str(sep_factor_sanity), mat2str(snr_sanity), Metkl_sanity, K_phi_sanity, angle_step_sanity, numel(angle_grid_sanity));
sanity_result = run_level2_stage_local('sanity', K_phi_sanity, sep_factor_sanity, snr_sanity, Metkl_sanity, ...
    angle_grid_sanity, stage_common, fid_log, 0, true);
log_stage_brief_local(fid_log, sanity_result, route_names, 'sanity');

angle_grid_kphi = (azCtr_deg - bw_eq_65):angle_step_kphi:(azCtr_deg + bw_eq_65);
log_msg(fid_log, '');
log_msg(fid_log, 'K_phi scan starts: sep=%s, snr=%s, Metkl=%d, K_phi_list=%s, angle step=%.4f deg, ngrid=%d', ...
    mat2str(sep_factor_kphi), mat2str(snr_kphi), Metkl_kphi, mat2str(K_phi_scan_list), angle_step_kphi, numel(angle_grid_kphi));
kphi_result = run_level2_stage_local('kphi_scan', K_phi_scan_list, sep_factor_kphi, snr_kphi, Metkl_kphi, ...
    angle_grid_kphi, stage_common, fid_log, 10000000, false);
log_stage_brief_local(fid_log, kphi_result, route_names, 'kphi_scan');

[K_phi_best, K_phi_best_idx, kphi_decision] = decide_fullscan_local(kphi_result, route_names);
log_msg(fid_log, '');
log_msg(fid_log, 'K_phi decision: best K_phi=%d, score_main=%.6f, sep10_snr30_route4=%.6f, sep10_snr30_route1=%.6f, improvement=%.6f', ...
    K_phi_best, kphi_decision.best_score, kphi_decision.route4_sep10_snr30, ...
    kphi_decision.route1_sep10_snr30_at_best, kphi_decision.improvement_vs_route1);
log_msg(fid_log, 'K_phi decision notes: %s', kphi_decision.note);

fullscan_executed = false;
fullscan_skip_reason = '';
fullscan_result = struct();
estimated_full_trials = numel(sep_factor_full) * numel(snr_full) * Metkl_full * numel(unique([K_phi_best, K_phi_sanity]));
fullscan_trial_budget = 12000;
if kphi_decision.is_promising && estimated_full_trials <= fullscan_trial_budget
    fullscan_executed = true;
    K_phi_full = unique([K_phi_best, K_phi_sanity]);
    angle_grid_full = (azCtr_deg - bw_eq_65):angle_step_full:(azCtr_deg + bw_eq_65);
    log_msg(fid_log, '');
    log_msg(fid_log, 'Fullscan starts: K_phi=%s, sep=%s, snr=%s, Metkl=%d, angle step=%.4f deg, ngrid=%d', ...
        mat2str(K_phi_full), mat2str(sep_factor_full), mat2str(snr_full), Metkl_full, angle_step_full, numel(angle_grid_full));
    fullscan_result = run_level2_stage_local('fullscan', K_phi_full, sep_factor_full, snr_full, Metkl_full, ...
        angle_grid_full, stage_common, fid_log, 20000000, false);
    log_stage_brief_local(fid_log, fullscan_result, route_names, 'fullscan');
elseif kphi_decision.is_promising
    fullscan_skip_reason = sprintf(['K_phi 扫描有希望，但按指定 fullscan 参数至少需要 %d 个 Monte Carlo 样本点，' ...
        '且每个样本还要执行多 route 谱搜索；本轮优先完成 sanity + K_phi 扫描，暂缓 fullscan。'], estimated_full_trials);
    log_msg(fid_log, 'Fullscan skipped: %s', fullscan_skip_reason);
else
    fullscan_skip_reason = 'K_phi 扫描没有显示 route 4 相对 65 列 ULA Root-MUSIC 基线有明确改善。';
    log_msg(fid_log, 'Fullscan skipped: %s', fullscan_skip_reason);
end

all_rows = [sanity_result.summary_rows; kphi_result.summary_rows];
if fullscan_executed
    all_rows = [all_rows; fullscan_result.summary_rows];
end
summary_path = fullfile(result_dir, 'step8_6_level2_subarray_manifold_summary.csv');
write_rows_csv_local(summary_path, all_rows);

key_rows = filter_keypoint_rows_local(all_rows, fullscan_executed);
keypoints_path = fullfile(result_dir, 'step8_6_level2_subarray_manifold_keypoints.csv');
write_rows_csv_local(keypoints_path, key_rows);

spectrum_examples = struct();
spectrum_examples.sanity = sanity_result.spectrum_example;
spectrum_examples.kphi = kphi_result.spectrum_example;
if fullscan_executed
    spectrum_examples.fullscan = fullscan_result.spectrum_example;
else
    spectrum_examples.fullscan = struct();
end

params = struct();
params.formula_doc_path = formula_doc_path;
params.reference_paths = { ...
    fullfile(project_dir, 'core', 'config', 'sim_cfg.m'), ...
    fullfile(project_dir, 'core', 'array', 'arr_cyl.m'), ...
    fullfile(step75_dir, 'mssp_array_fb.m'), ...
    fullfile(step75_dir, 'FindLocalPeak_NoEdge_Fun.m'), ...
    fullfile(step75_dir, 'is_valid_doa_success.m'), ...
    fullfile(step08_dir, 'doa_root_music_array.m'), ...
    fullfile(step08_dir, 'space_smooth_music_B_root_music_prototype6.m'), ...
    fullfile(step85_dir, 'space_smooth_music_B_cylindrical_multilayer_prototype14.m'), ...
    fullfile(step85_dir, 'space_smooth_music_B_cylindrical_real_manifold_prototype15a.m')};
params.azCtr_deg = azCtr_deg;
params.el_a = el_a;
params.el_b = el_b;
params.el_assumed_deg = el_assumed_deg;
params.el_scan_deg = el_scan_deg;
params.T_snap = T_snap;
params.Lc = Lc;
params.tol_deg = tol_deg;
params.tol_rel_ratio = tol_rel_ratio;
params.base_seed = base_seed;
params.Q = Q;
params.dPhi = cfg.arr.dPhi;
params.d_eq = d_eq;
params.bw_eq_65 = bw_eq_65;
params.bw_eq_32_history = bw_eq_32;
params.expected_gain_db = expected_gain_db;
params.clean_gain_ref_db = clean_gain_ref_db;
params.sanity = struct('sep_factor_list', sep_factor_sanity, 'snr_list', snr_sanity, ...
    'Metkl', Metkl_sanity, 'K_phi_list', K_phi_sanity, 'angle_step', angle_step_sanity);
params.kphi_scan = struct('sep_factor_list', sep_factor_kphi, 'snr_list', snr_kphi, ...
    'Metkl', Metkl_kphi, 'K_phi_list', K_phi_scan_list, 'angle_step', angle_step_kphi);
params.fullscan = struct('sep_factor_list', sep_factor_full, 'snr_list', snr_full, ...
    'Metkl', Metkl_full, 'executed', fullscan_executed, 'skip_reason', fullscan_skip_reason, ...
    'trial_budget', fullscan_trial_budget, 'estimated_full_trials', estimated_full_trials, ...
    'angle_step', angle_step_full);

mat_path = fullfile(result_dir, 'step8_6_level2_subarray_manifold_result.mat');
save(mat_path, ...
    'params', 'route_names', 'K_phi_scan_list', 'sep_factor_sanity', 'snr_sanity', ...
    'sep_factor_kphi', 'snr_kphi', 'sep_factor_full', 'snr_full', ...
    'angle_grid_sanity', 'angle_grid_kphi', 'sanity_result', 'kphi_result', ...
    'fullscan_result', 'fullscan_executed', 'fullscan_skip_reason', ...
    'K_phi_best', 'K_phi_best_idx', 'kphi_decision', 'spectrum_examples');

if fullscan_executed
    plot_route_compare_snr90_local(fullfile(result_dir, 'level2_route_compare_snr90.png'), fullscan_result, route_names);
else
    plot_route_compare_tol_sanity_local(fullfile(result_dir, 'level2_route_compare_tol_sanity.png'), sanity_result, route_names);
end
plot_kphi_vs_tol_local(fullfile(result_dir, 'level2_kphi_vs_tol_sep10.png'), kphi_result, route_names, 10);
plot_kphi_vs_rmse_local(fullfile(result_dir, 'level2_kphi_vs_rmse_sep10.png'), kphi_result, route_names, 10);
plot_spectrum_example_local(fullfile(result_dir, 'level2_spectrum_example_sep10_snr30.png'), sanity_result.spectrum_example, route_names);

write_record_doc_local(record_doc_path, params, route_names, sanity_result, kphi_result, fullscan_result, ...
    fullscan_executed, fullscan_skip_reason, K_phi_best, kphi_decision);

log_msg(fid_log, '');
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', log_path);
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', keypoints_path);
log_msg(fid_log, '  %s', mat_path);
if fullscan_executed
    log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_route_compare_snr90.png'));
else
    log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_route_compare_tol_sanity.png'));
end
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_kphi_vs_tol_sep10.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_kphi_vs_rmse_sep10.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_spectrum_example_sep10_snr30.png'));
log_msg(fid_log, '  %s', record_doc_path);
safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 finished.');
disp('result_dir =');
disp(result_dir);
disp('fullscan_executed =');
disp(fullscan_executed);
disp('fullscan_skip_reason =');
disp(fullscan_skip_reason);

function stage = run_level2_stage_local(stage_name, K_phi_list, sep_factor_list, snr_list, Metkl, angle_grid, common, fid_log, seed_offset, capture_spectrum)
    if isscalar(K_phi_list)
        K_phi_list = K_phi_list(:).';
    end

    route_names = common.route_names;
    nroutes = numel(route_names);
    nK = numel(K_phi_list);
    nsep = numel(sep_factor_list);
    nsnr = numel(snr_list);
    Lc = common.Lc;
    Q = common.full_Q;

    raw_success_count = zeros(nroutes, nK, nsep, nsnr);
    tol_success_count_abs01 = zeros(nroutes, nK, nsep, nsnr);
    tol_success_count_rel025 = zeros(nroutes, nK, nsep, nsnr);
    rmse_sum_sqerr = zeros(nroutes, nK, nsep, nsnr);
    rmse_valid_count = zeros(nroutes, nK, nsep, nsnr);
    num_peaks_sum = zeros(nroutes, nK, nsep, nsnr);
    lambda2_sum = zeros(nroutes, nK, nsep, nsnr);
    lambda2_count = zeros(nroutes, nK, nsep, nsnr);
    degraded_count = zeros(nroutes, nK, nsep, nsnr);

    theta_sep_deg = nan(nsep, 1);
    theta_a_deg = nan(nsep, 1);
    theta_b_deg = nan(nsep, 1);
    clean_gain_db_by_sep = nan(nsep, 1);
    debug_samples = cell(nK, nsep, nsnr);
    spectrum_example = struct();

    B_grid = build_level2_combined_az_steer_grid_local(common.X3d, common.Y3d, common.Z3d, ...
        common.A_ref_2d, common.lambda, angle_grid, common.el_scan_deg, common.el_assumed_deg);

    for iK = 1:nK
        K_phi = K_phi_list(iK);
        P_phi = Q - K_phi + 1;
        subarray_span_deg = (K_phi - 1) * common.cfg.arr.dPhi;
        log_msg(fid_log, '%s K_phi=%d, P_phi=%d, subarray_span=%.6f deg', ...
            stage_name, K_phi, P_phi, subarray_span_deg);

        if K_phi <= Lc || P_phi <= 0
            log_msg(fid_log, 'WARNING: skip K_phi=%d because K_phi<=Lc or P_phi<=0.', K_phi);
            continue
        end

        cache_center = make_spectrum_operator_cache_local(B_grid, K_phi, 'center_real');
        cache_forward = make_spectrum_operator_cache_local(B_grid, K_phi, 'subarray_avg_forward');
        cache_fb = make_spectrum_operator_cache_local(B_grid, K_phi, 'subarray_avg_fb');

        for iSep = 1:nsep
            sep_factor = sep_factor_list(iSep);
            theta_sep = common.bw_eq_65 / sep_factor;
            theta_a = common.azCtr_deg - theta_sep / 2;
            theta_b = common.azCtr_deg + theta_sep / 2;
            target_theta = [theta_a, theta_b];
            tol_rel_now = common.tol_rel_ratio * theta_sep;
            theta_sep_deg(iSep) = theta_sep;
            theta_a_deg(iSep) = theta_a;
            theta_b_deg(iSep) = theta_b;

            y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
                common.X3d, common.Y3d, common.Z3d, common.A_ref_2d, common.lambda, ...
                theta_a, theta_b, common.el_a, common.el_b, common.s1, common.s2);
            y_clean_combined = combine_layers_level2_local(y_clean_2d, common.Z3d, common.lambda, common.el_assumed_deg);
            y_clean_single = squeeze(y_clean_2d(:, common.iel_select, :));
            clean_gain_db_by_sep(iSep) = power_gain_db_local(y_clean_combined, y_clean_single);

            for iSNR = 1:nsnr
                snr_db = snr_list(iSNR);
                noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);

                for metkl_num = 1:Metkl
                    seed_now = common.base_seed + seed_offset + 100000*iSep + 1000*iSNR + metkl_num;
                    rng(seed_now, 'twister');
                    noise = sqrt(noise_power / 2) * (randn(size(y_clean_2d)) + 1j*randn(size(y_clean_2d)));
                    y_2d = y_clean_2d + noise;
                    y_combined = combine_layers_level2_local(y_2d, common.Z3d, common.lambda, common.el_assumed_deg);

                    [doa_root, debug_root] = doa_root_music_array(y_combined, K_phi, common.lambda, common.d_eq, Lc);
                    [En, eigvals, lambda2_grid, Rfb] = fbss_noise_subspace_level2_local(y_combined, K_phi, Lc);
                    [doa_center, npeak_center, Pmu_center, dbg_center] = grid_music_level2_subarray_avg_cached_local( ...
                        En, cache_center, angle_grid, Lc);
                    [doa_forward, npeak_forward, Pmu_forward, dbg_forward] = grid_music_level2_subarray_avg_cached_local( ...
                        En, cache_forward, angle_grid, Lc);
                    [doa_fb, npeak_fb, Pmu_fb, dbg_fb] = grid_music_level2_subarray_avg_cached_local( ...
                        En, cache_fb, angle_grid, Lc);

                    doa_all = {doa_root, doa_center, doa_forward, doa_fb};
                    npeak_all = [double(all(isfinite(doa_root))) * Lc, npeak_center, npeak_forward, npeak_fb];
                    lambda2_all = [debug_root.lambda2_over_noise, lambda2_grid, lambda2_grid, lambda2_grid];

                    for iroute = 1:nroutes
                        doa_now = doa_all{iroute};
                        raw_ok = all(isfinite(doa_now)) && numel(doa_now) == Lc;
                        tol_ok_abs = is_valid_doa_success(doa_now, target_theta, common.tol_deg);
                        tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_rel_now);
                        doa_degraded = true;

                        if raw_ok
                            raw_success_count(iroute, iK, iSep, iSNR) = raw_success_count(iroute, iK, iSep, iSNR) + 1;
                            err = sort(doa_now(:).') - sort(target_theta(:).');
                            rmse_sum_sqerr(iroute, iK, iSep, iSNR) = rmse_sum_sqerr(iroute, iK, iSep, iSNR) + sum(err.^2);
                            rmse_valid_count(iroute, iK, iSep, iSNR) = rmse_valid_count(iroute, iK, iSep, iSNR) + 1;
                            doa_degraded = max(abs(err)) > 1.0;
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

                        num_peaks_sum(iroute, iK, iSep, iSNR) = num_peaks_sum(iroute, iK, iSep, iSNR) + npeak_all(iroute);
                        if isfinite(lambda2_all(iroute))
                            lambda2_sum(iroute, iK, iSep, iSNR) = lambda2_sum(iroute, iK, iSep, iSNR) + lambda2_all(iroute);
                            lambda2_count(iroute, iK, iSep, iSNR) = lambda2_count(iroute, iK, iSep, iSNR) + 1;
                        end
                    end

                    if metkl_num == 1
                        sample = struct();
                        sample.seed_now = seed_now;
                        sample.K_phi = K_phi;
                        sample.P_phi = P_phi;
                        sample.sep_factor = sep_factor;
                        sample.theta_sep_deg = theta_sep;
                        sample.snr_db = snr_db;
                        sample.target_theta = target_theta;
                        sample.doa_root = doa_root;
                        sample.doa_center = doa_center;
                        sample.doa_forward = doa_forward;
                        sample.doa_fb = doa_fb;
                        sample.eigvals = eigvals;
                        sample.lambda2_grid = lambda2_grid;
                        sample.debug_root = debug_root;
                        sample.debug_center = dbg_center;
                        sample.debug_forward = dbg_forward;
                        sample.debug_fb = dbg_fb;
                        sample.Rfb = Rfb;
                        debug_samples{iK, iSep, iSNR} = sample;
                    end

                    if capture_spectrum && isempty(fieldnames(spectrum_example)) && ...
                            K_phi == common.figure_K_phi && sep_factor == 10 && snr_db == 30 && metkl_num == 1
                        spectrum_example = struct();
                        spectrum_example.stage_name = stage_name;
                        spectrum_example.K_phi = K_phi;
                        spectrum_example.P_phi = P_phi;
                        spectrum_example.sep_factor = sep_factor;
                        spectrum_example.snr_db = snr_db;
                        spectrum_example.angle_grid = angle_grid;
                        spectrum_example.target_theta = target_theta;
                        spectrum_example.Pmu_center = Pmu_center / max(Pmu_center);
                        spectrum_example.Pmu_forward = Pmu_forward / max(Pmu_forward);
                        spectrum_example.Pmu_fb = Pmu_fb / max(Pmu_fb);
                        spectrum_example.doa_center = doa_center;
                        spectrum_example.doa_forward = doa_forward;
                        spectrum_example.doa_fb = doa_fb;
                        spectrum_example.doa_root = doa_root;
                    end
                end
            end
        end
    end

    raw_success_rate = raw_success_count / Metkl;
    tol_success_rate_abs01 = tol_success_count_abs01 / Metkl;
    tol_success_rate_rel025 = tol_success_count_rel025 / Metkl;
    rmse_deg = sqrt(rmse_sum_sqerr ./ max(rmse_valid_count, 1) / Lc);
    rmse_deg(rmse_valid_count == 0) = NaN;
    mean_num_peaks = num_peaks_sum / Metkl;
    lambda2_over_noise_mean = lambda2_sum ./ max(lambda2_count, 1);
    lambda2_over_noise_mean(lambda2_count == 0) = NaN;
    degraded_rate = degraded_count / Metkl;
    snr90_abs01 = calc_snr90_4d_local(tol_success_rate_abs01, snr_list);
    snr90_rel025 = calc_snr90_4d_local(tol_success_rate_rel025, snr_list);

    summary_rows = build_summary_rows_local(stage_name, route_names, K_phi_list, sep_factor_list, snr_list, ...
        theta_sep_deg, theta_a_deg, theta_b_deg, common.cfg.arr.dPhi, raw_success_count, ...
        tol_success_count_abs01, tol_success_count_rel025, raw_success_rate, tol_success_rate_abs01, ...
        tol_success_rate_rel025, rmse_deg, rmse_valid_count, mean_num_peaks, lambda2_over_noise_mean, ...
        degraded_count, degraded_rate, snr90_abs01, snr90_rel025);

    stage = struct();
    stage.stage_name = stage_name;
    stage.K_phi_list = K_phi_list;
    stage.sep_factor_list = sep_factor_list;
    stage.snr_list = snr_list;
    stage.Metkl = Metkl;
    stage.angle_grid = angle_grid;
    stage.theta_sep_deg = theta_sep_deg;
    stage.theta_a_deg = theta_a_deg;
    stage.theta_b_deg = theta_b_deg;
    stage.clean_gain_db_by_sep = clean_gain_db_by_sep;
    stage.raw_success_count = raw_success_count;
    stage.tol_success_count_abs01 = tol_success_count_abs01;
    stage.tol_success_count_rel025 = tol_success_count_rel025;
    stage.raw_success_rate = raw_success_rate;
    stage.tol_success_rate_abs01 = tol_success_rate_abs01;
    stage.tol_success_rate_rel025 = tol_success_rate_rel025;
    stage.rmse_deg = rmse_deg;
    stage.rmse_valid_count = rmse_valid_count;
    stage.mean_num_peaks = mean_num_peaks;
    stage.lambda2_over_noise_mean = lambda2_over_noise_mean;
    stage.degraded_count = degraded_count;
    stage.degraded_rate = degraded_rate;
    stage.snr90_abs01 = snr90_abs01;
    stage.snr90_rel025 = snr90_rel025;
    stage.summary_rows = summary_rows;
    stage.debug_samples = debug_samples;
    stage.spectrum_example = spectrum_example;
end

function y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, theta_b, el_a, el_b, s1, s2)

    unit_a = [cosd(el_a) * cosd(theta_a), cosd(el_a) * sind(theta_a), sind(el_a)];
    unit_b = [cosd(el_b) * cosd(theta_b), cosd(el_b) * sind(theta_b), sind(el_b)];

    phase_a = X3d * unit_a(1) + Y3d * unit_a(2) + Z3d * unit_a(3);
    phase_b = X3d * unit_b(1) + Y3d * unit_b(2) + Z3d * unit_b(3);

    A_a_2d = exp(-1j * 2*pi / lambda * phase_a);
    A_b_2d = exp(-1j * 2*pi / lambda * phase_b);

    A_a_norm = conj(A_ref_2d) .* A_a_2d;
    A_b_norm = conj(A_ref_2d) .* A_b_2d;

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
    a_2d = exp(-1j * k * phase);
    a_norm = conj(A_ref_2d) .* a_2d;

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

function cache = make_spectrum_operator_cache_local(B_grid, K_phi, mode)
    Q = size(B_grid, 1);
    ngrid = size(B_grid, 2);
    P_phi = Q - K_phi + 1;
    if P_phi <= 0
        error('Invalid K_phi=%d for Q=%d.', K_phi, Q);
    end

    J = fliplr(eye(K_phi));
    G_flat = zeros(ngrid, K_phi * K_phi);

    switch mode
        case 'center_real'
            p_mid = round((P_phi + 1) / 2);
            A = normalize_columns_local(B_grid(p_mid:p_mid+K_phi-1, :));
            for ia = 1:ngrid
                a = A(:, ia);
                G_flat(ia, :) = reshape(a * a', 1, []);
            end
        case 'subarray_avg_forward'
            for p = 1:P_phi
                A = normalize_columns_local(B_grid(p:p+K_phi-1, :));
                for ia = 1:ngrid
                    a = A(:, ia);
                    G_flat(ia, :) = G_flat(ia, :) + reshape(a * a', 1, []);
                end
            end
            G_flat = G_flat / P_phi;
        case 'subarray_avg_fb'
            for p = 1:P_phi
                A = normalize_columns_local(B_grid(p:p+K_phi-1, :));
                for ia = 1:ngrid
                    a = A(:, ia);
                    ab = J * conj(a);
                    nb = norm(ab);
                    if nb > 0
                        ab = ab / nb;
                    end
                    G_flat(ia, :) = G_flat(ia, :) + reshape(a * a', 1, []) + reshape(ab * ab', 1, []);
                end
            end
            G_flat = G_flat / (2 * P_phi);
        otherwise
            error('Unknown mode: %s', mode);
    end

    cache = struct();
    cache.mode = mode;
    cache.K_phi = K_phi;
    cache.P_phi = P_phi;
    cache.G_flat = G_flat;
end

function A = normalize_columns_local(A)
    nrm = sqrt(sum(abs(A).^2, 1));
    nrm(nrm == 0) = 1;
    A = A ./ nrm;
end

function [doa_est, num_peaks, Pmu, debug_info] = grid_music_level2_subarray_avg_cached_local(En, cache, angle_grid, Lc)
    Cn = En * En';
    cvec = reshape(Cn.', [], 1);
    den = real(cache.G_flat * cvec).';
    Pmu = 1 ./ max(den, eps);

    [~, peak_inds] = FindLocalPeak_NoEdge_Fun(Pmu);
    num_peaks = numel(peak_inds);
    if num_peaks < Lc
        doa_est = nan(1, Lc);
    else
        doa_est = sort(angle_grid(peak_inds(1:Lc)));
    end

    debug_info = struct();
    debug_info.mode = cache.mode;
    debug_info.K_phi = cache.K_phi;
    debug_info.P_phi = cache.P_phi;
    debug_info.den_min = min(den);
    debug_info.den_max = max(den);
    debug_info.num_peaks = num_peaks;
end

function [doa_est, num_peaks, Pmu, angle_grid, debug_info] = grid_music_level2_subarray_avg_local( ...
    En, X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid, K_phi, Lc, el_scan_deg, el_assumed_deg, mode)

    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid, el_scan_deg, el_assumed_deg);
    cache = make_spectrum_operator_cache_local(B_grid, K_phi, mode);
    [doa_est, num_peaks, Pmu, debug_info] = grid_music_level2_subarray_avg_cached_local( ...
        En, cache, angle_grid, Lc);
end

function [En, eigvals, lambda2_over_noise, Rfb] = fbss_noise_subspace_level2_local(y_combined, K_phi, Lc)
    T_snap = size(y_combined, 2);
    Rxx = y_combined * y_combined' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    Rfb = mssp_array_fb(Rxx, K_phi);
    Rfb = 0.5 * (Rfb + Rfb');

    [V, D] = eig(Rfb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
    V = V(:, idx);

    if size(V, 2) <= Lc
        En = zeros(size(V, 1), 0);
    else
        En = V(:, Lc+1:end);
    end

    noise_start = Lc + 1;
    noise_end = min(numel(eigvals), Lc + 6);
    if numel(eigvals) >= 2 && noise_start <= noise_end
        lambda2_over_noise = eigvals(2) / max(mean(eigvals(noise_start:noise_end)), eps);
    else
        lambda2_over_noise = NaN;
    end
end

function snr90 = calc_snr90_4d_local(rate4d, snr_list)
    [nroutes, nK, nsep, ~] = size(rate4d);
    snr90 = nan(nroutes, nK, nsep);
    for iroute = 1:nroutes
        for iK = 1:nK
            for iSep = 1:nsep
                idx = find(squeeze(rate4d(iroute, iK, iSep, :)) >= 0.9, 1, 'first');
                if ~isempty(idx)
                    snr90(iroute, iK, iSep) = snr_list(idx);
                end
            end
        end
    end
end

function rows = build_summary_rows_local(stage_name, route_names, K_phi_list, sep_factor_list, snr_list, ...
    theta_sep_deg, theta_a_deg, theta_b_deg, dPhi, raw_success_count, tol_success_count_abs01, ...
    tol_success_count_rel025, raw_success_rate, tol_success_rate_abs01, tol_success_rate_rel025, ...
    rmse_deg, rmse_valid_count, mean_num_peaks, lambda2_over_noise_mean, degraded_count, ...
    degraded_rate, snr90_abs01, snr90_rel025)

    rows = {};
    nroutes = numel(route_names);
    for iroute = 1:nroutes
        for iK = 1:numel(K_phi_list)
            K_phi = K_phi_list(iK);
            P_phi = 65 - K_phi + 1;
            subarray_span_deg = (K_phi - 1) * dPhi;
            for iSep = 1:numel(sep_factor_list)
                for iSNR = 1:numel(snr_list)
                    rows(end+1, :) = { ...
                        stage_name, route_names{iroute}, K_phi, P_phi, subarray_span_deg, ...
                        sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
                        snr_list(iSNR), raw_success_count(iroute, iK, iSep, iSNR), ...
                        tol_success_count_abs01(iroute, iK, iSep, iSNR), ...
                        tol_success_count_rel025(iroute, iK, iSep, iSNR), ...
                        raw_success_rate(iroute, iK, iSep, iSNR), ...
                        tol_success_rate_abs01(iroute, iK, iSep, iSNR), ...
                        tol_success_rate_rel025(iroute, iK, iSep, iSNR), ...
                        rmse_deg(iroute, iK, iSep, iSNR), ...
                        rmse_valid_count(iroute, iK, iSep, iSNR), ...
                        mean_num_peaks(iroute, iK, iSep, iSNR), ...
                        lambda2_over_noise_mean(iroute, iK, iSep, iSNR), ...
                        degraded_count(iroute, iK, iSep, iSNR), ...
                        degraded_rate(iroute, iK, iSep, iSNR), ...
                        snr90_abs01(iroute, iK, iSep), ...
                        snr90_rel025(iroute, iK, iSep)};
                end
            end
        end
    end
end

function write_rows_csv_local(path_out, rows)
    header = {'experiment_stage','route_name','K_phi','P_phi','subarray_span_deg','sep_factor', ...
        'theta_sep_deg','theta_a_deg','theta_b_deg','snr_db','raw_success_count', ...
        'tol_success_count_abs01','tol_success_count_rel025','raw_success_rate', ...
        'tol_success_rate_abs01','tol_success_rate_rel025','rmse_deg','rmse_valid_count', ...
        'mean_num_peaks','lambda2_over_noise_mean','degraded_count','degraded_rate', ...
        'snr90_abs01','snr90_rel025'};

    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(header, ','));
    for ii = 1:size(rows, 1)
        fprintf(fid, '%s,%s,%d,%d,%.9f,%d,%.9f,%.9f,%.9f,%d,%d,%d,%d,%.9f,%.9f,%.9f,%.9f,%d,%.9f,%.9f,%d,%.9f,%.9f,%.9f\n', ...
            rows{ii, 1}, rows{ii, 2}, rows{ii, 3}, rows{ii, 4}, rows{ii, 5}, rows{ii, 6}, ...
            rows{ii, 7}, rows{ii, 8}, rows{ii, 9}, rows{ii, 10}, rows{ii, 11}, rows{ii, 12}, ...
            rows{ii, 13}, rows{ii, 14}, rows{ii, 15}, rows{ii, 16}, rows{ii, 17}, rows{ii, 18}, ...
            rows{ii, 19}, rows{ii, 20}, rows{ii, 21}, rows{ii, 22}, rows{ii, 23}, rows{ii, 24});
    end
end

function key_rows = filter_keypoint_rows_local(rows, fullscan_executed)
    key_rows = {};
    for ii = 1:size(rows, 1)
        stage = rows{ii, 1};
        sep_factor = rows{ii, 6};
        snr_db = rows{ii, 10};
        keep = strcmp(stage, 'sanity') || strcmp(stage, 'kphi_scan');
        if fullscan_executed && strcmp(stage, 'fullscan')
            keep = ismember(sep_factor, [5, 7, 10]) && ismember(snr_db, [20, 24, 28, 30]);
        end
        if keep
            key_rows(end+1, :) = rows(ii, :);
        end
    end
end

function [K_phi_best, K_phi_best_idx, decision] = decide_fullscan_local(kphi_result, route_names)
    route4_idx = find(strcmp(route_names, 'level2_subarray_avg_real_grid_music_fb'), 1);
    route1_idx = find(strcmp(route_names, 'level2_ula_root_music_65col_baseline'), 1);
    idx_sep10 = find(kphi_result.sep_factor_list == 10, 1);
    idx_snr30 = find(kphi_result.snr_list == 30, 1);

    nK = numel(kphi_result.K_phi_list);
    score = nan(1, nK);
    rmse_tiebreak = nan(1, nK);
    for iK = 1:nK
        vals = squeeze(kphi_result.tol_success_rate_abs01(route4_idx, iK, :, :));
        score(iK) = mean(vals(:), 'omitnan');
        if ~isempty(idx_sep10) && ~isempty(idx_snr30)
            rmse_tiebreak(iK) = kphi_result.rmse_deg(route4_idx, iK, idx_sep10, idx_snr30);
        end
    end

    [best_score, K_phi_best_idx] = max(score);
    tied = find(abs(score - best_score) < 1e-12);
    if numel(tied) > 1
        [~, idx_min] = min(rmse_tiebreak(tied));
        K_phi_best_idx = tied(idx_min);
    end
    K_phi_best = kphi_result.K_phi_list(K_phi_best_idx);

    route4_sep10_snr30 = NaN;
    route1_sep10_snr30_at_best = NaN;
    improvement = NaN;
    if ~isempty(idx_sep10) && ~isempty(idx_snr30)
        route4_sep10_snr30 = kphi_result.tol_success_rate_abs01(route4_idx, K_phi_best_idx, idx_sep10, idx_snr30);
        route1_sep10_snr30_at_best = kphi_result.tol_success_rate_abs01(route1_idx, K_phi_best_idx, idx_sep10, idx_snr30);
        improvement = route4_sep10_snr30 - route1_sep10_snr30_at_best;
    end

    is_promising = isfinite(route4_sep10_snr30) && route4_sep10_snr30 >= 0.50 && improvement >= 0.05;
    if is_promising
        note = 'route 4 在 sep10/snr30 上相对 route 1 有明确改善。';
    elseif isfinite(route4_sep10_snr30) && route4_sep10_snr30 >= 0.50
        note = 'route 4 的绝对表现不差，但没有明确超过 route 1。';
    else
        note = 'route 4 在 sep10/snr30 上仍然较弱，因此不执行 fullscan。';
    end

    decision = struct();
    decision.best_score = best_score;
    decision.route4_sep10_snr30 = route4_sep10_snr30;
    decision.route1_sep10_snr30_at_best = route1_sep10_snr30_at_best;
    decision.improvement_vs_route1 = improvement;
    decision.is_promising = is_promising;
    decision.note = note;
end

function log_stage_brief_local(fid_log, result, route_names, label)
    idx_sep10 = find(result.sep_factor_list == 10, 1);
    idx_snr30 = find(result.snr_list == 30, 1);
    if isempty(idx_sep10)
        idx_sep10 = numel(result.sep_factor_list);
    end
    if isempty(idx_snr30)
        idx_snr30 = numel(result.snr_list);
    end

    log_msg(fid_log, '');
    log_msg(fid_log, '%s brief summary at sep=%d, snr=%d', label, ...
        result.sep_factor_list(idx_sep10), result.snr_list(idx_snr30));
    for iK = 1:numel(result.K_phi_list)
        for iroute = 1:numel(route_names)
            log_msg(fid_log, '  K=%d | %-52s | tol_abs=%.3f, tol_rel=%.3f, rmse=%.5f, peaks=%.3f, lambda2=%.4g, degraded=%.3f', ...
                result.K_phi_list(iK), route_names{iroute}, ...
                result.tol_success_rate_abs01(iroute, iK, idx_sep10, idx_snr30), ...
                result.tol_success_rate_rel025(iroute, iK, idx_sep10, idx_snr30), ...
                result.rmse_deg(iroute, iK, idx_sep10, idx_snr30), ...
                result.mean_num_peaks(iroute, iK, idx_sep10, idx_snr30), ...
                result.lambda2_over_noise_mean(iroute, iK, idx_sep10, idx_snr30), ...
                result.degraded_rate(iroute, iK, idx_sep10, idx_snr30));
        end
    end
end

function plot_route_compare_tol_sanity_local(path_out, result, route_names)
    idxK = find(result.K_phi_list == 28, 1);
    if isempty(idxK)
        idxK = 1;
    end
    fig = figure('Visible', 'off', 'Position', [100, 100, 960, 620]);
    for iSep = 1:numel(result.sep_factor_list)
        subplot(numel(result.sep_factor_list), 1, iSep);
        for iroute = 1:numel(route_names)
            plot(result.snr_list, squeeze(result.tol_success_rate_abs01(iroute, idxK, iSep, :)), '-o', 'LineWidth', 1.1);
            hold on
        end
        hold off
        grid on
        ylim([0 1.05]);
        ylabel('tol abs01');
        title(sprintf('Sanity route compare, sep=%d, K=%d', result.sep_factor_list(iSep), result.K_phi_list(idxK)));
        if iSep == 1
            legend(route_names, 'Interpreter', 'none', 'Location', 'best');
        end
    end
    xlabel('SNR (dB)');
    saveas(fig, path_out);
    close(fig);
end

function plot_route_compare_snr90_local(path_out, result, route_names)
    fig = figure('Visible', 'off', 'Position', [100, 100, 940, 560]);
    idxK = 1;
    for iroute = 1:numel(route_names)
        plot(result.sep_factor_list, squeeze(result.snr90_abs01(iroute, idxK, :)), '-o', 'LineWidth', 1.4);
        hold on
    end
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 abs01 (dB)');
    title(sprintf('Level 2 fullscan SNR90, K=%d', result.K_phi_list(idxK)));
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_kphi_vs_tol_local(path_out, result, route_names, sep_factor_target)
    idxSep = find(result.sep_factor_list == sep_factor_target, 1);
    if isempty(idxSep)
        idxSep = numel(result.sep_factor_list);
    end
    idxSNR = find(result.snr_list == max(result.snr_list), 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    for iroute = 1:numel(route_names)
        vals = squeeze(result.tol_success_rate_abs01(iroute, :, idxSep, idxSNR));
        plot(result.K_phi_list, vals, '-o', 'LineWidth', 1.3);
        hold on
    end
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('K_\phi');
    ylabel('tol success abs01');
    title(sprintf('K_phi scan tol, sep=%d, SNR=%d dB', result.sep_factor_list(idxSep), result.snr_list(idxSNR)));
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_kphi_vs_rmse_local(path_out, result, route_names, sep_factor_target)
    idxSep = find(result.sep_factor_list == sep_factor_target, 1);
    if isempty(idxSep)
        idxSep = numel(result.sep_factor_list);
    end
    idxSNR = find(result.snr_list == max(result.snr_list), 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 920, 560]);
    for iroute = 1:numel(route_names)
        vals = squeeze(result.rmse_deg(iroute, :, idxSep, idxSNR));
        plot(result.K_phi_list, vals, '-o', 'LineWidth', 1.3);
        hold on
    end
    hold off
    grid on
    xlabel('K_\phi');
    ylabel('RMSE (deg)');
    title(sprintf('K_phi scan RMSE, sep=%d, SNR=%d dB', result.sep_factor_list(idxSep), result.snr_list(idxSNR)));
    legend(route_names, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_spectrum_example_local(path_out, spectrum_example, route_names)
    fig = figure('Visible', 'off', 'Position', [100, 100, 960, 560]);
    if isempty(fieldnames(spectrum_example))
        text(0.1, 0.5, 'No spectrum example captured');
        axis off
        saveas(fig, path_out);
        close(fig);
        return
    end
    plot(spectrum_example.angle_grid, 10*log10(spectrum_example.Pmu_center), 'LineWidth', 1.2);
    hold on
    plot(spectrum_example.angle_grid, 10*log10(spectrum_example.Pmu_forward), 'LineWidth', 1.2);
    plot(spectrum_example.angle_grid, 10*log10(spectrum_example.Pmu_fb), 'LineWidth', 1.2);
    xline(spectrum_example.target_theta(1), '--k');
    xline(spectrum_example.target_theta(2), '--k');
    hold off
    grid on
    xlabel('azimuth (deg)');
    ylabel('normalized MUSIC spectrum (dB)');
    title(sprintf('Level 2 spectrum example: sep=%d, SNR=%d dB, K=%d', ...
        spectrum_example.sep_factor, spectrum_example.snr_db, spectrum_example.K_phi));
    legend({route_names{2}, route_names{3}, route_names{4}, 'true az'}, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function write_record_doc_local(path_out, params, route_names, sanity_result, kphi_result, fullscan_result, ...
    fullscan_executed, fullscan_skip_reason, K_phi_best, kphi_decision)

    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# 第8.6步 层次二：65列真实圆柱子阵流形验证记录\n\n');
    fprintf(fid, '## 公式文档与范围\n\n');
    fprintf(fid, '- 公式文档：`%s`\n', params.formula_doc_path);
    fprintf(fid, '- 本轮只实现层次二：65列动态工作子阵、32层俯仰相干合成、一维方位真实圆柱子阵流形MUSIC。\n');
    fprintf(fid, '- 本轮不做层次三，不做2D az/el联合MUSIC，不引入PME、圆柱模态变换、稀疏恢复、DML、SBL、SPICE。\n\n');

    fprintf(fid, '## 65列工程基线\n\n');
    fprintf(fid, '- `cfg.beam.sectorHalf = 60 deg`，`cfg.arr.Naz = 192`，`cfg.arr.dPhi = 360/192 = %.6f deg`。\n', params.dPhi);
    fprintf(fid, '- `cfg.beam.subNaz = 2*floor(60/1.875)+1 = %d`，所以本轮工程基线是 `Q=%d`。\n', params.Q, params.Q);
    fprintf(fid, '- 第8.5步 proto14 的 `N_arc=32` 重新定位为旧探索版本：它是在65列工作子阵中截取中心32列做局部ULA近似，不是当前工程完整工作阵元。\n');
    fprintf(fid, '- 32列不是当前工程建模中的完整工作阵元；完整工作阵元应由 `arr_cyl(cfg, azCtr_deg)` 动态选出的65列给出。\n\n');

    fprintf(fid, '## 层次二定位\n\n');
    fprintf(fid, '- 层次一：把方位维近似为局部ULA，再用FBSS + Root-MUSIC。\n');
    fprintf(fid, '- 层次二：先把65x32数据按俯仰先验相干合成为65xT，再用真实圆柱方位子阵流形做一维grid-MUSIC。\n');
    fprintf(fid, '- 层次二仍是一维方位算法，俯仰维被压缩掉；32层的作用是提供相干增益，理论功率增益 `10log10(32)=%.4f dB`，本轮测得 clean gain `%.4f dB`。\n\n', ...
        params.expected_gain_db, params.clean_gain_ref_db);

    fprintf(fid, '## 层次二公式\n\n');
    fprintf(fid, '圆柱阵真实 steering：\n\n');
    fprintf(fid, '$$a_{q,m}(az,el)=\\exp[-j k (X_{q,m}\\cos(el)\\cos(az)+Y_{q,m}\\cos(el)\\sin(az)+Z_{q,m}\\sin(el))]$$\n\n');
    fprintf(fid, '视轴归一化：\n\n');
    fprintf(fid, '$$a_{norm}(q,m;az,el)=\\operatorname{conj}(a_{ref}(q,m))a(q,m;az,el)$$\n\n');
    fprintf(fid, '32层相干合成：\n\n');
    fprintf(fid, '$$b_q(az,el;el_0)=w_z^H(el_0)a_{norm}(q,:;az,el)$$\n\n');
    fprintf(fid, '方位子阵 steering：\n\n');
    fprintf(fid, '$$b_p(az)=S_p b(az)$$\n\n');
    fprintf(fid, '前向真实子阵平均MUSIC：\n\n');
    fprintf(fid, '$$P_{forward}(az)=\\frac{1}{(1/P_\\phi)\\sum_p b_p^H(az)E_nE_n^Hb_p(az)}$$\n\n');
    fprintf(fid, '前后向真实子阵平均MUSIC：\n\n');
    fprintf(fid, '$$P_{FB}(az)=\\frac{1}{(1/(2P_\\phi))\\sum_p\\{b_p^HE_nE_n^Hb_p+(J\\operatorname{conj}(b_p))^HE_nE_n^H(J\\operatorname{conj}(b_p))\\}}$$\n\n');
    fprintf(fid, '真实圆柱流形不是严格Vandermonde结构，所以 route 3/4 不能使用Root-MUSIC，只能使用grid-MUSIC谱搜索。\n\n');

    fprintf(fid, '## 四条 route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- route %d：`%s`\n', ii, route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Sanity 结果摘要\n\n');
    write_stage_markdown_summary_local(fid, sanity_result, route_names, 10, 30);

    fprintf(fid, '## K_phi 扫描结果摘要\n\n');
    fprintf(fid, '- 扫描K_phi：`%s`；最优候选 `K_phi=%d`。\n', mat2str(kphi_result.K_phi_list), K_phi_best);
    fprintf(fid, '- 判定：%s\n', kphi_decision.note);
    write_stage_markdown_summary_local(fid, kphi_result, route_names, 10, 30);

    fprintf(fid, '## Fullscan 执行情况\n\n');
    if fullscan_executed
        fprintf(fid, '已执行fullscan。\n\n');
        write_snr90_markdown_local(fid, fullscan_result, route_names);
    else
        fprintf(fid, '未执行fullscan。原因：%s\n\n', fullscan_skip_reason);
    end

    fprintf(fid, '## 层次二主结论\n\n');
    conclusion = choose_conclusion_local(kphi_decision);
    fprintf(fid, '%s\n\n', conclusion);

    fprintf(fid, '## 后续建议（只限层次二）\n\n');
    fprintf(fid, '- 继续围绕 `K_phi`、网格步长、谱函数平均方式和FBSS协方差拟合误差做层次二内的消融。\n');
    fprintf(fid, '- 若要进一步严格化，优先考虑层次二的一维圆柱阵平滑协方差拟合；本轮不展开层次三。\n');
end

function write_stage_markdown_summary_local(fid, result, route_names, sep_factor_target, snr_target)
    idxSep = find(result.sep_factor_list == sep_factor_target, 1);
    if isempty(idxSep)
        idxSep = numel(result.sep_factor_list);
    end
    idxSNR = find(result.snr_list == snr_target, 1);
    if isempty(idxSNR)
        idxSNR = numel(result.snr_list);
    end
    fprintf(fid, '| K_phi | route | tol_abs01 | tol_rel025 | RMSE(deg) | mean_peaks | lambda2/noise | degraded_rate |\n');
    fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|---:|\n');
    for iK = 1:numel(result.K_phi_list)
        for iroute = 1:numel(route_names)
            fprintf(fid, '| %d | `%s` | %.3f | %.3f | %.5f | %.3f | %.4g | %.3f |\n', ...
                result.K_phi_list(iK), route_names{iroute}, ...
                result.tol_success_rate_abs01(iroute, iK, idxSep, idxSNR), ...
                result.tol_success_rate_rel025(iroute, iK, idxSep, idxSNR), ...
                result.rmse_deg(iroute, iK, idxSep, idxSNR), ...
                result.mean_num_peaks(iroute, iK, idxSep, idxSNR), ...
                result.lambda2_over_noise_mean(iroute, iK, idxSep, idxSNR), ...
                result.degraded_rate(iroute, iK, idxSep, idxSNR));
        end
    end
    fprintf(fid, '\n');
end

function write_snr90_markdown_local(fid, result, route_names)
    fprintf(fid, '| K_phi | sep_factor | route | SNR90 abs01 | SNR90 rel025 |\n');
    fprintf(fid, '|---:|---:|---|---:|---:|\n');
    for iK = 1:numel(result.K_phi_list)
        for iSep = 1:numel(result.sep_factor_list)
            for iroute = 1:numel(route_names)
                fprintf(fid, '| %d | %d | `%s` | %.3f | %.3f |\n', ...
                    result.K_phi_list(iK), result.sep_factor_list(iSep), route_names{iroute}, ...
                    result.snr90_abs01(iroute, iK, iSep), result.snr90_rel025(iroute, iK, iSep));
            end
        end
    end
    fprintf(fid, '\n');
end

function conclusion = choose_conclusion_local(kphi_decision)
    if kphi_decision.is_promising && kphi_decision.improvement_vs_route1 >= 0.20
        conclusion = ['65列工程工作子阵不能直接ULA化；真实圆柱子阵流形建模对层次二有效，' ...
            '后续可继续围绕K_phi、angle_grid、协方差拟合细化。'];
    elseif isfinite(kphi_decision.improvement_vs_route1) && kphi_decision.improvement_vs_route1 > 0
        conclusion = ['真实圆柱子阵流形修正有一定收益，但完全同相小间隔仍主要受秩恢复和双峰合并限制。'];
    else
        conclusion = ['当前瓶颈不只是ULA近似误差。对于完全同相、同俯仰、极小方位间隔，' ...
            '层次二真实圆柱流形MUSIC仍不足以根治问题。后续层次二内可考虑更严格的平滑协方差拟合，但本轮不展开层次三。'];
    end
end

function gain_db = power_gain_db_local(y_combined, y_single)
    gain_db = 10 * log10(mean(abs(y_combined(:)).^2) / mean(abs(y_single(:)).^2));
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
