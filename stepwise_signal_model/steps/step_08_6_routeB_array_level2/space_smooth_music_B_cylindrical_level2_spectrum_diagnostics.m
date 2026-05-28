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
formula_doc_path = fullfile(script_dir, '第8.6步层次二和三公式推导.md');
modify_doc_path = fullfile(script_dir, '第8.6步修改方向.md');
first_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_subarray_manifold.m');
first_record_path = fullfile(script_dir, '第8.6步_层次二_65列真实圆柱子阵流形验证记录.md');
first_result_dir = fullfile(script_dir, 'results_step8_6_level2_subarray_manifold');
first_result_mat = fullfile(first_result_dir, 'step8_6_level2_subarray_manifold_result.mat');
first_summary_csv = fullfile(first_result_dir, 'step8_6_level2_subarray_manifold_summary.csv');
first_keypoints_csv = fullfile(first_result_dir, 'step8_6_level2_subarray_manifold_keypoints.csv');

result_dir = fullfile(script_dir, 'results_step8_6_level2_spectrum_diagnostics');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

record_doc_path = fullfile(script_dir, '第8.6步_层次二第二部分_谱函数消融诊断记录.md');
log_path = fullfile(result_dir, 'step8_6_level2_spectrum_diagnostics.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

assert(exist(first_script_path, 'file') == 2, 'First-part script not found.');
assert(exist(first_result_mat, 'file') == 2, 'First-part result mat not found.');
assert(exist(first_summary_csv, 'file') == 2, 'First-part summary CSV not found.');
assert(exist(first_keypoints_csv, 'file') == 2, 'First-part keypoints CSV not found.');
first_part_data = load(first_result_mat, 'params', 'kphi_decision');

log_msg(fid_log, 'Step 08.6 level 2 part 2: spectrum aggregation diagnostics');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'First-part commit: %s', first_part_commit);
log_msg(fid_log, 'Modify direction doc: %s', modify_doc_path);
log_msg(fid_log, 'Formula doc: %s', formula_doc_path);
log_msg(fid_log, 'First-part script: %s', first_script_path);
log_msg(fid_log, 'First-part result MAT: %s', first_result_mat);
log_msg(fid_log, 'First-part summary CSV: %s', first_summary_csv);
log_msg(fid_log, 'First-part keypoints CSV: %s', first_keypoints_csv);
log_msg(fid_log, 'First-part record: %s', first_record_path);
log_msg(fid_log, 'Old helper paths:');
log_msg(fid_log, '  %s', fullfile(project_dir, 'core', 'config', 'sim_cfg.m'));
log_msg(fid_log, '  %s', fullfile(project_dir, 'core', 'array', 'arr_cyl.m'));
log_msg(fid_log, '  %s', fullfile(step75_dir, 'mssp_array_fb.m'));
log_msg(fid_log, '  %s', fullfile(step75_dir, 'FindLocalPeak_NoEdge_Fun.m'));
log_msg(fid_log, '  %s', fullfile(step75_dir, 'is_valid_doa_success.m'));
log_msg(fid_log, '  %s', fullfile(step08_dir, 'doa_root_music_array.m'));
log_msg(fid_log, 'Scope guard: level 2 spectrum diagnostics only. No fullscan, no level 3, no 2D az/el MUSIC, no PME, no sparse recovery.');

azCtr_deg = 0;
el_a = 0;
el_b = 0;
el_assumed_deg = 0;
el_scan_deg = 0;
T_snap = 260;
Lc = 2;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
K_phi_list = [24, 28, 32];
sep_factor_list = [7, 10];
snr_list = [24, 28, 30];
Metkl = 50;
angle_step = 0.005;
base_seed = 20260625;

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
angle_grid = (azCtr_deg - bw_eq_65):angle_step:(azCtr_deg + bw_eq_65);
expected_gain_db = 10 * log10(cfg.arr.Nel);
work_span_deg = max(arrInfo.phiActRel(col_select)) - min(arrInfo.phiActRel(col_select));

log_msg(fid_log, '');
log_msg(fid_log, 'Geometry health check');
log_msg(fid_log, 'cfg.arr.Naz=%d, cfg.arr.Nel=%d, cfg.arr.R=%.9f m, lambda=%.9f m', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.R, cfg.arr.lambda);
log_msg(fid_log, 'cfg.arr.dz=%.9f m, dz/lambda=%.9f, dPhi=%.9f deg', ...
    cfg.arr.dz, cfg.arr.dz / cfg.arr.lambda, cfg.arr.dPhi);
log_msg(fid_log, 'cfg.beam.sectorHalf=%.9f deg, cfg.beam.subNaz=%d, Q=%d', ...
    cfg.beam.sectorHalf, cfg.beam.subNaz, Q);
log_msg(fid_log, 'working phi first/last/span = %.9f / %.9f / %.9f deg', ...
    arrInfo.phiActRel(1), arrInfo.phiActRel(Q), work_span_deg);
log_msg(fid_log, 'bw_eq_65=%.9f deg, angle_step=%.6f deg, ngrid=%d', ...
    bw_eq_65, angle_step, numel(angle_grid));
log_msg(fid_log, '32-layer theoretical coherent gain=%.6f dB', expected_gain_db);
if Q ~= 65
    log_msg(fid_log, 'WARNING: Q=%d, expected 65 for this diagnostic.', Q);
end

route_names = { ...
    'center_real', ...
    'avg_den_forward', ...
    'avg_spectrum_forward', ...
    'min_den_forward', ...
    'median_den_forward', ...
    'trimmed_avg_den_forward', ...
    'avg_den_fb', ...
    'avg_spectrum_fb', ...
    'min_den_fb'};
nroutes = numel(route_names);

log_msg(fid_log, '');
log_msg(fid_log, 'Spectrum aggregation routes');
log_msg(fid_log, 'A center_real: P=1/d_mid.');
log_msg(fid_log, 'B avg_den_forward: P=1/mean_p d_p. This is first-part route 3.');
log_msg(fid_log, 'C avg_spectrum_forward: P=mean_p 1/d_p.');
log_msg(fid_log, 'D min_den_forward: P=1/min_p d_p.');
log_msg(fid_log, 'E median_den_forward: P=1/median_p d_p.');
log_msg(fid_log, 'F trimmed_avg_den_forward: remove lowest/highest 20%% of d_p then P=1/mean.');
log_msg(fid_log, 'G avg_den_fb: P=1/mean_p 0.5*(d_p+d_b,p). This is first-part route 4.');
log_msg(fid_log, 'H avg_spectrum_fb: P=mean_p 0.5*(1/d_p+1/d_b,p).');
log_msg(fid_log, 'I min_den_fb: P=1/min_p 0.5*(d_p+d_b,p).');

nK = numel(K_phi_list);
nsep = numel(sep_factor_list);
nsnr = numel(snr_list);

raw_success_count = zeros(nroutes, nK, nsep, nsnr);
tol_success_count_abs01 = zeros(nroutes, nK, nsep, nsnr);
tol_success_count_rel025 = zeros(nroutes, nK, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nK, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nK, nsep, nsnr);
num_peaks_sum = zeros(nroutes, nK, nsep, nsnr);
degraded_count = zeros(nroutes, nK, nsep, nsnr);
aggregation_peak_loss_count = zeros(nroutes, nK, nsep, nsnr);

single_two_peak_count = zeros(nK, nsep, nsnr);
single_total_count = zeros(nK, nsep, nsnr);
single_best_tol_count = zeros(nK, nsep, nsnr);
single_any_two_peak_count = zeros(nK, nsep, nsnr);
theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);

single_diag_rows = {};
spectrum_examples = struct();

B_grid = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid, el_scan_deg, el_assumed_deg);

tic;
for iK = 1:nK
    K_phi = K_phi_list(iK);
    cache = make_subarray_steer_cache_local(B_grid, arrInfo.phiActRel(col_select), K_phi);
    P_phi = cache.P_phi;
    log_msg(fid_log, '');
    log_msg(fid_log, 'K_phi=%d, P_phi=%d, subarray_span=%.6f deg', ...
        K_phi, P_phi, (K_phi - 1) * cfg.arr.dPhi);

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

        for iSNR = 1:nsnr
            snr_db = snr_list(iSNR);
            noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(snr_db / 10);

            for metkl_num = 1:Metkl
                seed_now = base_seed + 100000*iK + 10000*iSep + 1000*iSNR + metkl_num;
                rng(seed_now, 'twister');
                noise = sqrt(noise_power / 2) * (randn(size(y_clean_2d)) + 1j*randn(size(y_clean_2d)));
                y_2d = y_clean_2d + noise;
                y_combined = combine_layers_level2_local(y_2d, Z3d, cfg.arr.lambda, el_assumed_deg);
                [En, eigvals] = fbss_noise_subspace_level2_local(y_combined, K_phi, Lc);
                [D_forward, D_backward] = compute_subarray_denominators_local(cache, En);
                [P_route, route_debug] = build_aggregation_spectra_local(D_forward, D_backward, cache);

                single_diag = analyze_single_subarrays_local(D_forward, angle_grid, target_theta, ...
                    tol_deg, cache, metkl_num == 1);
                single_two_peak_count(iK, iSep, iSNR) = single_two_peak_count(iK, iSep, iSNR) + ...
                    sum([single_diag.num_peaks] >= Lc);
                single_total_count(iK, iSep, iSNR) = single_total_count(iK, iSep, iSNR) + P_phi;
                any_single_two_peak = any([single_diag.num_peaks] >= Lc);
                any_single_best_tol = any([single_diag.is_two_peak_valid]);
                if any_single_two_peak
                    single_any_two_peak_count(iK, iSep, iSNR) = single_any_two_peak_count(iK, iSep, iSNR) + 1;
                end
                if any_single_best_tol
                    single_best_tol_count(iK, iSep, iSNR) = single_best_tol_count(iK, iSep, iSNR) + 1;
                end

                if metkl_num == 1
                    single_diag_rows = append_single_diag_rows_local(single_diag_rows, single_diag, ...
                        K_phi, P_phi, sep_factor, snr_db, metkl_num, target_theta);
                end

                doa_all = cell(nroutes, 1);
                num_peaks_all = zeros(nroutes, 1);
                Pmu_all = cell(nroutes, 1);
                for iroute = 1:nroutes
                    Pmu = P_route(iroute, :);
                    [doa_now, num_peaks_now] = estimate_from_spectrum_local(Pmu, angle_grid, Lc);
                    doa_all{iroute} = doa_now;
                    num_peaks_all(iroute) = num_peaks_now;
                    Pmu_all{iroute} = Pmu;
                end

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
                    if any_single_two_peak && num_peaks_all(iroute) < Lc
                        aggregation_peak_loss_count(iroute, iK, iSep, iSNR) = aggregation_peak_loss_count(iroute, iK, iSep, iSNR) + 1;
                    end
                    num_peaks_sum(iroute, iK, iSep, iSNR) = num_peaks_sum(iroute, iK, iSep, iSNR) + num_peaks_all(iroute);
                end

                if K_phi == 24 && sep_factor == 10 && snr_db == 30 && metkl_num == 1
                    spectrum_examples = struct();
                    spectrum_examples.K_phi = K_phi;
                    spectrum_examples.P_phi = P_phi;
                    spectrum_examples.sep_factor = sep_factor;
                    spectrum_examples.snr_db = snr_db;
                    spectrum_examples.seed_now = seed_now;
                    spectrum_examples.angle_grid = angle_grid;
                    spectrum_examples.target_theta = target_theta;
                    spectrum_examples.route_names = route_names;
                    spectrum_examples.P_route = normalize_rows_local(P_route);
                    spectrum_examples.D_forward = D_forward;
                    spectrum_examples.D_backward = D_backward;
                    spectrum_examples.single_diag = single_diag;
                    spectrum_examples.subarray_center_phi_deg = cache.subarray_center_phi_deg;
                    spectrum_examples.eigvals = eigvals;
                    spectrum_examples.route_debug = route_debug;
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
mean_num_peaks = num_peaks_sum / Metkl;
degraded_rate = degraded_count / Metkl;
single_subarray_two_peak_rate = single_two_peak_count ./ max(single_total_count, 1);
single_subarray_best_tol_rate = single_best_tol_count / Metkl;
aggregation_peak_loss_rate = aggregation_peak_loss_count / Metkl;

summary_rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    theta_sep_deg, Q, cfg.arr.dPhi, raw_success_rate, tol_success_rate_abs01, ...
    tol_success_rate_rel025, rmse_deg, rmse_valid_count, mean_num_peaks, degraded_rate, ...
    single_subarray_two_peak_rate, single_subarray_best_tol_rate, aggregation_peak_loss_rate);

summary_path = fullfile(result_dir, 'step8_6_level2_spectrum_diagnostics_summary.csv');
single_diag_path = fullfile(result_dir, 'step8_6_level2_single_subarray_spectrum_diag.csv');
mat_path = fullfile(result_dir, 'step8_6_level2_spectrum_diagnostics_result.mat');
write_summary_csv_local(summary_path, summary_rows);
write_single_diag_csv_local(single_diag_path, single_diag_rows);

params = struct();
params.first_part_commit = first_part_commit;
params.formula_doc_path = formula_doc_path;
params.modify_doc_path = modify_doc_path;
params.first_script_path = first_script_path;
params.first_result_mat = first_result_mat;
params.first_summary_csv = first_summary_csv;
params.first_keypoints_csv = first_keypoints_csv;
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
params.angle_step = angle_step;
params.base_seed = base_seed;
params.d_eq = d_eq;
params.bw_eq_65 = bw_eq_65;

diagnosis = choose_diagnosis_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    tol_success_rate_abs01, mean_num_peaks, single_subarray_two_peak_rate, ...
    single_subarray_best_tol_rate, aggregation_peak_loss_rate);

save(mat_path, ...
    'params', 'route_names', 'K_phi_list', 'sep_factor_list', 'snr_list', 'angle_grid', ...
    'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', 'raw_success_count', ...
    'tol_success_count_abs01', 'tol_success_count_rel025', 'raw_success_rate', ...
    'tol_success_rate_abs01', 'tol_success_rate_rel025', 'rmse_deg', ...
    'rmse_valid_count', 'mean_num_peaks', 'degraded_rate', ...
    'single_subarray_two_peak_rate', 'single_subarray_best_tol_rate', ...
    'aggregation_peak_loss_rate', 'single_diag_rows', 'spectrum_examples', ...
    'diagnosis', 'first_part_data');

plot_aggregation_compare_local(fullfile(result_dir, 'level2_spectrum_aggregation_compare_sep10_snr30_K24.png'), ...
    spectrum_examples);
plot_single_peak_map_local(fullfile(result_dir, 'level2_single_subarray_peak_map_sep10_snr30_K24.png'), ...
    spectrum_examples);
plot_single_num_peaks_local(fullfile(result_dir, 'level2_single_subarray_num_peaks_vs_index_sep10_snr30_K24.png'), ...
    spectrum_examples);
plot_aggregation_peak_loss_rate_local(fullfile(result_dir, 'level2_aggregation_peak_loss_rate.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, aggregation_peak_loss_rate);
plot_route_tol_compare_local(fullfile(result_dir, 'level2_route_tol_compare_spectrum_diagnostics.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, tol_success_rate_abs01);

write_record_doc_local(record_doc_path, params, route_names, summary_rows, single_diag_rows, diagnosis, ...
    spectrum_examples, summary_path, single_diag_path, mat_path);

log_msg(fid_log, '');
log_msg(fid_log, 'Diagnostic conclusion: %s', diagnosis.conclusion);
log_msg(fid_log, 'Next step: %s', diagnosis.next_step);
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', single_diag_path);
log_msg(fid_log, '  %s', mat_path);
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_spectrum_aggregation_compare_sep10_snr30_K24.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_single_subarray_peak_map_sep10_snr30_K24.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_single_subarray_num_peaks_vs_index_sep10_snr30_K24.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_aggregation_peak_loss_rate.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_route_tol_compare_spectrum_diagnostics.png'));
log_msg(fid_log, '  %s', record_doc_path);
safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 spectrum diagnostics finished.');
disp('result_dir =');
disp(result_dir);
disp('diagnosis =');
disp(diagnosis.conclusion);

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

function cache = make_subarray_steer_cache_local(B_grid, phiActRel, K_phi)
    Q = size(B_grid, 1);
    ngrid = size(B_grid, 2);
    P_phi = Q - K_phi + 1;
    J = fliplr(eye(K_phi));
    A_forward = complex(zeros(K_phi, ngrid, P_phi));
    A_backward = complex(zeros(K_phi, ngrid, P_phi));
    subarray_center_phi_deg = zeros(P_phi, 1);

    for p = 1:P_phi
        A = normalize_columns_local(B_grid(p:p+K_phi-1, :));
        A_forward(:, :, p) = A;
        A_backward(:, :, p) = J * conj(A);
        subarray_center_phi_deg(p) = mean(phiActRel(p:p+K_phi-1));
    end

    cache = struct();
    cache.K_phi = K_phi;
    cache.P_phi = P_phi;
    cache.A_forward = A_forward;
    cache.A_backward = A_backward;
    cache.subarray_center_phi_deg = subarray_center_phi_deg;
end

function A = normalize_columns_local(A)
    nrm = sqrt(sum(abs(A).^2, 1));
    nrm(nrm == 0) = 1;
    A = A ./ nrm;
end

function [En, eigvals] = fbss_noise_subspace_level2_local(y_combined, K_phi, Lc)
    T_snap = size(y_combined, 2);
    Rxx = y_combined * y_combined' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');
    Rfb = mssp_array_fb(Rxx, K_phi);
    Rfb = 0.5 * (Rfb + Rfb');
    [V, D] = eig(Rfb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
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
        CA = Cn * A;
        D_forward(p, :) = real(sum(conj(A) .* CA, 1));
        Ab = cache.A_backward(:, :, p);
        CAb = Cn * Ab;
        D_backward(p, :) = real(sum(conj(Ab) .* CAb, 1));
    end
end

function [P_route, route_debug] = build_aggregation_spectra_local(D_forward, D_backward, cache)
    P_phi = cache.P_phi;
    p_mid = round((P_phi + 1) / 2);
    D_fb = 0.5 * (D_forward + D_backward);
    trim_n = floor(0.2 * P_phi);
    sorted_D = sort(D_forward, 1, 'ascend');
    if 2 * trim_n >= P_phi
        D_trim = mean(D_forward, 1);
    else
        D_trim = mean(sorted_D(trim_n+1:end-trim_n, :), 1);
    end

    P_route = zeros(9, size(D_forward, 2));
    P_route(1, :) = inv_den_local(D_forward(p_mid, :));
    P_route(2, :) = inv_den_local(mean(D_forward, 1));
    P_route(3, :) = mean(inv_den_local(D_forward), 1);
    P_route(4, :) = inv_den_local(min(D_forward, [], 1));
    P_route(5, :) = inv_den_local(median(D_forward, 1));
    P_route(6, :) = inv_den_local(D_trim);
    P_route(7, :) = inv_den_local(mean(D_fb, 1));
    P_route(8, :) = mean(0.5 * inv_den_local(D_forward) + 0.5 * inv_den_local(D_backward), 1);
    P_route(9, :) = inv_den_local(min(D_fb, [], 1));

    route_debug = struct();
    route_debug.trim_n = trim_n;
    route_debug.p_mid = p_mid;
end

function y = inv_den_local(x)
    y = 1 ./ max(real(x), eps);
end

function diag_list = analyze_single_subarrays_local(D_forward, angle_grid, target_theta, tol_deg, cache, keep_spectrum)
    P_phi = cache.P_phi;
    diag_list = repmat(struct( ...
        'subarray_index', NaN, ...
        'subarray_center_phi_deg', NaN, ...
        'num_peaks', NaN, ...
        'peak1_deg', NaN, ...
        'peak2_deg', NaN, ...
        'peak_error_max_deg', NaN, ...
        'peak_separation_deg', NaN, ...
        'peak_to_valley_ratio', NaN, ...
        'is_two_peak_valid', false, ...
        'Pmu', []), P_phi, 1);

    for p = 1:P_phi
        Pmu = inv_den_local(D_forward(p, :));
        [doa_est, num_peaks, peak_inds] = estimate_from_spectrum_local(Pmu, angle_grid, 2);
        peak1 = NaN;
        peak2 = NaN;
        peak_error_max = NaN;
        peak_sep = NaN;
        peak_to_valley = NaN;
        is_valid = false;

        if num_peaks >= 2
            peak_pair = sort(doa_est(:).');
            peak1 = peak_pair(1);
            peak2 = peak_pair(2);
            peak_error_max = max(abs(peak_pair - sort(target_theta(:).')));
            peak_sep = abs(peak2 - peak1);
            is_valid = is_valid_doa_success(peak_pair, target_theta, tol_deg);

            idx_pair = sort(peak_inds(1:2));
            valley = min(Pmu(idx_pair(1):idx_pair(2)));
            peak_to_valley = min(Pmu(idx_pair)) / max(valley, eps);
        end

        diag_list(p).subarray_index = p;
        diag_list(p).subarray_center_phi_deg = cache.subarray_center_phi_deg(p);
        diag_list(p).num_peaks = num_peaks;
        diag_list(p).peak1_deg = peak1;
        diag_list(p).peak2_deg = peak2;
        diag_list(p).peak_error_max_deg = peak_error_max;
        diag_list(p).peak_separation_deg = peak_sep;
        diag_list(p).peak_to_valley_ratio = peak_to_valley;
        diag_list(p).is_two_peak_valid = is_valid;
        if keep_spectrum
            diag_list(p).Pmu = Pmu / max(Pmu);
        end
    end
end

function [doa_est, num_peaks, peak_inds] = estimate_from_spectrum_local(Pmu, angle_grid, Lc)
    [~, peak_inds] = FindLocalPeak_NoEdge_Fun(Pmu);
    num_peaks = numel(peak_inds);
    if num_peaks < Lc
        doa_est = nan(1, Lc);
    else
        doa_est = sort(angle_grid(peak_inds(1:Lc)));
    end
end

function rows = append_single_diag_rows_local(rows, diag_list, K_phi, P_phi, sep_factor, snr_db, metkl_num, target_theta)
    for p = 1:numel(diag_list)
        rows(end+1, :) = { ...
            K_phi, P_phi, sep_factor, snr_db, metkl_num, ...
            diag_list(p).subarray_index, diag_list(p).subarray_center_phi_deg, ...
            diag_list(p).num_peaks, diag_list(p).peak1_deg, diag_list(p).peak2_deg, ...
            target_theta(1), target_theta(2), diag_list(p).peak_error_max_deg, ...
            diag_list(p).peak_separation_deg, diag_list(p).peak_to_valley_ratio, ...
            double(diag_list(p).is_two_peak_valid)};
    end
end

function P_norm = normalize_rows_local(P)
    P_norm = P;
    for ii = 1:size(P, 1)
        mx = max(P(ii, :));
        if mx > 0
            P_norm(ii, :) = P(ii, :) / mx;
        end
    end
end

function rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    theta_sep_deg, Q, dPhi, raw_success_rate, tol_abs, tol_rel, rmse_deg, rmse_valid_count, ...
    mean_num_peaks, degraded_rate, single_two_peak_rate, single_best_tol_rate, aggregation_peak_loss_rate)

    rows = {};
    for iroute = 1:numel(route_names)
        for iK = 1:numel(K_phi_list)
            K_phi = K_phi_list(iK);
            P_phi = Q - K_phi + 1;
            subarray_span_deg = (K_phi - 1) * dPhi;
            for iSep = 1:numel(sep_factor_list)
                for iSNR = 1:numel(snr_list)
                    rows(end+1, :) = { ...
                        route_names{iroute}, K_phi, P_phi, subarray_span_deg, ...
                        sep_factor_list(iSep), theta_sep_deg(iSep), snr_list(iSNR), ...
                        raw_success_rate(iroute, iK, iSep, iSNR), ...
                        tol_abs(iroute, iK, iSep, iSNR), ...
                        tol_rel(iroute, iK, iSep, iSNR), ...
                        rmse_deg(iroute, iK, iSep, iSNR), ...
                        rmse_valid_count(iroute, iK, iSep, iSNR), ...
                        mean_num_peaks(iroute, iK, iSep, iSNR), ...
                        degraded_rate(iroute, iK, iSep, iSNR), ...
                        single_two_peak_rate(iK, iSep, iSNR), ...
                        single_best_tol_rate(iK, iSep, iSNR), ...
                        aggregation_peak_loss_rate(iroute, iK, iSep, iSNR)};
                end
            end
        end
    end
end

function write_summary_csv_local(path_out, rows)
    header = ['route_name,K_phi,P_phi,subarray_span_deg,sep_factor,theta_sep_deg,snr_db,' ...
        'raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,rmse_valid_count,' ...
        'mean_num_peaks,degraded_rate,single_subarray_two_peak_rate,single_subarray_best_tol_rate,' ...
        'aggregation_peak_loss_rate'];
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', header);
    for ii = 1:size(rows, 1)
        fprintf(fid, '%s,%d,%d,%.9f,%d,%.9f,%d,%.9f,%.9f,%.9f,%.9f,%d,%.9f,%.9f,%.9f,%.9f,%.9f\n', ...
            rows{ii, 1}, rows{ii, 2}, rows{ii, 3}, rows{ii, 4}, rows{ii, 5}, rows{ii, 6}, rows{ii, 7}, ...
            rows{ii, 8}, rows{ii, 9}, rows{ii, 10}, rows{ii, 11}, rows{ii, 12}, rows{ii, 13}, ...
            rows{ii, 14}, rows{ii, 15}, rows{ii, 16}, rows{ii, 17});
    end
end

function write_single_diag_csv_local(path_out, rows)
    header = ['K_phi,P_phi,sep_factor,snr_db,metkl_num,subarray_index,subarray_center_phi_deg,' ...
        'num_peaks,peak1_deg,peak2_deg,target1_deg,target2_deg,peak_error_max_deg,' ...
        'peak_separation_deg,peak_to_valley_ratio,is_two_peak_valid'];
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', header);
    for ii = 1:size(rows, 1)
        fprintf(fid, '%d,%d,%d,%d,%d,%d,%.9f,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%d\n', ...
            rows{ii, 1}, rows{ii, 2}, rows{ii, 3}, rows{ii, 4}, rows{ii, 5}, rows{ii, 6}, ...
            rows{ii, 7}, rows{ii, 8}, rows{ii, 9}, rows{ii, 10}, rows{ii, 11}, rows{ii, 12}, ...
            rows{ii, 13}, rows{ii, 14}, rows{ii, 15}, rows{ii, 16});
    end
end

function diagnosis = choose_diagnosis_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    tol_abs, ~, single_two_peak_rate, single_best_tol_rate, aggregation_loss_rate)

    idxK = find(K_phi_list == 24, 1);
    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    idx_avg_den_fb = find(strcmp(route_names, 'avg_den_fb'), 1);
    idx_avg_spec_fb = find(strcmp(route_names, 'avg_spectrum_fb'), 1);
    idx_min_den_fb = find(strcmp(route_names, 'min_den_fb'), 1);

    key_single_two = single_two_peak_rate(idxK, idxSep, idxSNR);
    key_single_best_tol = single_best_tol_rate(idxK, idxSep, idxSNR);
    key_loss_avg_den_fb = aggregation_loss_rate(idx_avg_den_fb, idxK, idxSep, idxSNR);
    key_tol_avg_den_fb = tol_abs(idx_avg_den_fb, idxK, idxSep, idxSNR);
    key_tol_avg_spec_fb = tol_abs(idx_avg_spec_fb, idxK, idxSep, idxSNR);
    key_tol_min_den_fb = tol_abs(idx_min_den_fb, idxK, idxSep, idxSNR);

    best_tol = max(tol_abs(:, idxK, idxSep, idxSNR));
    [~, best_route_idx] = max(tol_abs(:, idxK, idxSep, idxSNR));
    best_route = route_names{best_route_idx};
    improved_over_avg_den_fb = best_tol - key_tol_avg_den_fb;

    if key_single_two > 0.05 && key_loss_avg_den_fb > 0.50
        conclusion = ['层次二第一部分 route 4 失败主要来自谱函数聚合方式。后续应优化聚合策略，' ...
            '例如 avg_spectrum、min_den、trimmed_avg 或子阵加权，而不是直接判定层次二失败。'];
        next_step = '继续层次二谱函数优化。';
        case_id = 1;
    elseif improved_over_avg_den_fb >= 0.20 || key_tol_avg_spec_fb - key_tol_avg_den_fb >= 0.20 || key_tol_min_den_fb - key_tol_avg_den_fb >= 0.20
        conclusion = '层次二仍有价值。当前改进方向应是谱函数聚合方式，而不是直接进入协方差拟合或层次三。';
        next_step = '对最佳聚合方式做小规模 K_phi/SNR 扫描。';
        case_id = 3;
    else
        conclusion = ['在完全同相、同俯仰、小间隔条件下，当前一维层次二 MUSIC 谱函数族无法形成稳定双峰；' ...
            '问题不是简单平均方式导致，而是平滑后信号子空间和真实圆柱子阵流形的匹配不足。下一步应进入层次二的一维圆柱阵平滑协方差拟合。'];
        next_step = '进入层次二的一维圆柱阵平滑协方差拟合。';
        case_id = 2;
    end

    diagnosis = struct();
    diagnosis.case_id = case_id;
    diagnosis.key_K_phi = K_phi_list(idxK);
    diagnosis.key_sep_factor = sep_factor_list(idxSep);
    diagnosis.key_snr_db = snr_list(idxSNR);
    diagnosis.single_subarray_two_peak_rate = key_single_two;
    diagnosis.single_subarray_best_tol_rate = key_single_best_tol;
    diagnosis.aggregation_peak_loss_rate_avg_den_fb = key_loss_avg_den_fb;
    diagnosis.tol_avg_den_fb = key_tol_avg_den_fb;
    diagnosis.tol_avg_spectrum_fb = key_tol_avg_spec_fb;
    diagnosis.tol_min_den_fb = key_tol_min_den_fb;
    diagnosis.best_route = best_route;
    diagnosis.best_tol = best_tol;
    diagnosis.improved_over_avg_den_fb = improved_over_avg_den_fb;
    diagnosis.conclusion = conclusion;
    diagnosis.next_step = next_step;
end

function plot_aggregation_compare_local(path_out, example)
    fig = figure('Visible', 'off', 'Position', [80, 80, 1180, 720]);
    for iroute = 1:numel(example.route_names)
        plot(example.angle_grid, 10*log10(example.P_route(iroute, :)), 'LineWidth', 1.0);
        hold on
    end
    xline(example.target_theta(1), '--k');
    xline(example.target_theta(2), '--k');
    hold off
    grid on
    xlabel('azimuth (deg)');
    ylabel('normalized spectrum (dB)');
    title(sprintf('Aggregation spectra, K=%d, sep=%d, SNR=%d dB', example.K_phi, example.sep_factor, example.snr_db));
    legend([example.route_names(:); {'true az'}], 'Interpreter', 'none', 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_single_peak_map_local(path_out, example)
    fig = figure('Visible', 'off', 'Position', [100, 100, 950, 620]);
    p = [example.single_diag.subarray_index];
    peak1 = [example.single_diag.peak1_deg];
    peak2 = [example.single_diag.peak2_deg];
    plot(p, peak1, 'bo', 'LineWidth', 1.1);
    hold on
    plot(p, peak2, 'rs', 'LineWidth', 1.1);
    yline(example.target_theta(1), '--k');
    yline(example.target_theta(2), '--k');
    hold off
    grid on
    xlabel('subarray index');
    ylabel('peak azimuth (deg)');
    title(sprintf('Single-subarray peak map, K=%d, sep=%d, SNR=%d dB', example.K_phi, example.sep_factor, example.snr_db));
    legend({'peak1', 'peak2', 'true az'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_single_num_peaks_local(path_out, example)
    fig = figure('Visible', 'off', 'Position', [100, 100, 950, 620]);
    p = [example.single_diag.subarray_index];
    npeak = [example.single_diag.num_peaks];
    err = [example.single_diag.peak_error_max_deg];
    yyaxis left
    bar(p, npeak);
    ylabel('num peaks');
    yyaxis right
    plot(p, err, '-o', 'LineWidth', 1.1);
    ylabel('max peak error (deg)');
    grid on
    xlabel('subarray index');
    title(sprintf('Single-subarray num peaks and error, K=%d, sep=%d, SNR=%d dB', ...
        example.K_phi, example.sep_factor, example.snr_db));
    saveas(fig, path_out);
    close(fig);
end

function plot_aggregation_peak_loss_rate_local(path_out, route_names, K_phi_list, sep_factor_list, snr_list, loss_rate)
    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    vals = squeeze(loss_rate(:, :, idxSep, idxSNR));
    fig = figure('Visible', 'off', 'Position', [100, 100, 1050, 600]);
    bar(vals.');
    grid on
    xlabel('K_\phi index');
    ylabel('aggregation peak loss rate');
    title(sprintf('Aggregation peak loss, sep=%d, SNR=%d dB', sep_factor_list(idxSep), snr_list(idxSNR)));
    set(gca, 'XTickLabel', string(K_phi_list));
    legend(route_names, 'Interpreter', 'none', 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_route_tol_compare_local(path_out, route_names, K_phi_list, sep_factor_list, snr_list, tol_abs)
    idxK = find(K_phi_list == 24, 1);
    idxSep = find(sep_factor_list == 10, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1080, 620]);
    for iroute = 1:numel(route_names)
        plot(snr_list, squeeze(tol_abs(iroute, idxK, idxSep, :)), '-o', 'LineWidth', 1.1);
        hold on
    end
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('SNR (dB)');
    ylabel('tol success abs01');
    title(sprintf('Route tolerance compare, K=%d, sep=%d', K_phi_list(idxK), sep_factor_list(idxSep)));
    legend(route_names, 'Interpreter', 'none', 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function write_record_doc_local(path_out, params, route_names, summary_rows, single_diag_rows, diagnosis, example, ...
    summary_path, single_diag_path, mat_path)

    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# 第8.6步 层次二第二部分：谱函数消融诊断记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 第一部分提交：`%s`\n', params.first_part_commit);
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 本轮只做层次二谱函数消融诊断，不做 fullscan，不做层次三，不做 2D az/el MUSIC，不做 PME 或稀疏恢复。\n\n');

    fprintf(fid, '## 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi_list=%s`, `sep_factor_list=%s`, `snr_list=%s`, `Metkl=%d`, `angle_step=%.4f deg`。\n', ...
        params.Q, mat2str(params.K_phi_list), mat2str(params.sep_factor_list), mat2str(params.snr_list), params.Metkl, params.angle_step);
    fprintf(fid, '- 角间隔基于 65 列工程基线：`bw_eq_65=%.9f deg`。\n\n', params.bw_eq_65);

    fprintf(fid, '## 谱函数 route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 关键结果：K=24, sep=10, SNR=30\n\n');
    fprintf(fid, '| route | tol_abs01 | tol_rel025 | RMSE | mean_peaks | degraded | agg_peak_loss |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
    for ii = 1:size(summary_rows, 1)
        if summary_rows{ii, 2} == 24 && summary_rows{ii, 5} == 10 && summary_rows{ii, 7} == 30
            fprintf(fid, '| `%s` | %.3f | %.3f | %.5f | %.3f | %.3f | %.3f |\n', ...
                summary_rows{ii, 1}, summary_rows{ii, 9}, summary_rows{ii, 10}, summary_rows{ii, 11}, ...
                summary_rows{ii, 13}, summary_rows{ii, 14}, summary_rows{ii, 17});
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 单子阵谱诊断\n\n');
    fprintf(fid, '- `single_subarray_two_peak_rate=%.6f`\n', diagnosis.single_subarray_two_peak_rate);
    fprintf(fid, '- `single_subarray_best_tol_rate=%.6f`\n', diagnosis.single_subarray_best_tol_rate);
    fprintf(fid, '- `avg_den_fb aggregation_peak_loss_rate=%.6f`\n', diagnosis.aggregation_peak_loss_rate_avg_den_fb);
    fprintf(fid, '- 最佳聚合 route：`%s`，关键点 tol_abs01=%.6f。\n', diagnosis.best_route, diagnosis.best_tol);
    fprintf(fid, '- 单子阵诊断 CSV：`%s`\n\n', single_diag_path);

    [center_is_better, edge_note] = summarize_center_edge_local(single_diag_rows);
    fprintf(fid, '中心/边缘子阵观察：%s；center_is_better=%d。\n\n', edge_note, center_is_better);

    fprintf(fid, '## 是否存在单子阵双峰但聚合单峰\n\n');
    if diagnosis.single_subarray_two_peak_rate > 0 && diagnosis.aggregation_peak_loss_rate_avg_den_fb > 0
        fprintf(fid, '存在。关键点上至少部分单子阵出现两个局部峰，而 `avg_den_fb` 聚合仍出现峰损失。\n\n');
    else
        fprintf(fid, '未观察到显著现象。关键点上单子阵双峰率或聚合峰损失率不足以支持“平均方式单独抹平双峰”。\n\n');
    end

    fprintf(fid, '## 是否所有子阵都单峰\n\n');
    if diagnosis.single_subarray_two_peak_rate == 0
        fprintf(fid, '是。关键点上单子阵双峰率为 0，说明所有子阵自身也难以形成双峰。\n\n');
    elseif diagnosis.single_subarray_two_peak_rate < 0.05
        fprintf(fid, '不是全部。关键点上存在少量双峰子阵，但单子阵双峰率仅 %.6f，说明绝大多数子阵自身仍是单峰。\n\n', ...
            diagnosis.single_subarray_two_peak_rate);
    else
        fprintf(fid, '不是。关键点上存在一定比例的单子阵双峰，需要进一步看这些双峰是否命中真实目标。\n\n');
    end

    fprintf(fid, '## 结论\n\n');
    fprintf(fid, '%s\n\n', diagnosis.conclusion);
    fprintf(fid, '下一步：%s\n\n', diagnosis.next_step);

    fprintf(fid, '## 输出文件\n\n');
    fprintf(fid, '- summary：`%s`\n', summary_path);
    fprintf(fid, '- single subarray diag：`%s`\n', single_diag_path);
    fprintf(fid, '- MAT：`%s`\n', mat_path);
    fprintf(fid, '- 关键谱图示例：K=%d, sep=%d, SNR=%d dB。\n', example.K_phi, example.sep_factor, example.snr_db);
end

function [center_is_better, note] = summarize_center_edge_local(single_diag_rows)
    if isempty(single_diag_rows)
        center_is_better = false;
        note = '无单子阵行';
        return
    end
    rows = single_diag_rows;
    err = cell2mat(rows(:, 13));
    idx = cell2mat(rows(:, 6));
    K = cell2mat(rows(:, 1));
    P = cell2mat(rows(:, 2));
    key_mask = K == 24 & cell2mat(rows(:, 3)) == 10 & cell2mat(rows(:, 4)) == 30;
    err = err(key_mask);
    idx = idx(key_mask);
    P = P(key_mask);
    finite_mask = isfinite(err);
    if isempty(err) || ~any(finite_mask)
        center_is_better = false;
        note = '关键点无有限双峰误差子阵';
        return
    end
    err_all = err;
    err = err(finite_mask);
    idx = idx(finite_mask);
    P = P(finite_mask);
    center_dist = abs(idx - (P + 1) / 2);
    center_mask = center_dist <= median(center_dist, 'omitnan');
    center_err = mean(err(center_mask), 'omitnan');
    edge_err = mean(err(~center_mask), 'omitnan');
    center_is_better = isfinite(edge_err) && center_err < edge_err;
    finite_count = sum(finite_mask);
    total_count = numel(err_all);
    idx_min = min(idx);
    idx_max = max(idx);
    if isfinite(edge_err)
        note = sprintf('K24/sep10/SNR30 首个样本有限双峰子阵 %d/%d，索引范围 %d-%d；中心半区平均误差 %.6f deg，边缘半区平均误差 %.6f deg', ...
            finite_count, total_count, idx_min, idx_max, center_err, edge_err);
    else
        note = sprintf('K24/sep10/SNR30 首个样本有限双峰子阵 %d/%d，索引范围 %d-%d；有限双峰只出现在中心附近，边缘半区无有限双峰误差', ...
            finite_count, total_count, idx_min, idx_max);
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
