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
modify_doc_path = fullfile(script_dir, '第8.6步修改方向.md');
first_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_subarray_manifold.m');
second_script_path = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_spectrum_diagnostics.m');
second_result_dir = fullfile(script_dir, 'results_step8_6_level2_spectrum_diagnostics');
second_summary_csv = fullfile(second_result_dir, 'step8_6_level2_spectrum_diagnostics_summary.csv');
second_single_diag_csv = fullfile(second_result_dir, 'step8_6_level2_single_subarray_spectrum_diag.csv');
second_record_path = fullfile(script_dir, '第8.6步_层次二第二部分_谱函数消融诊断记录.md');

assert(exist(first_script_path, 'file') == 2, 'First-part script not found.');
assert(exist(second_script_path, 'file') == 2, 'Second-part script not found.');
assert(exist(second_summary_csv, 'file') == 2, 'Second-part summary CSV not found.');
assert(exist(second_single_diag_csv, 'file') == 2, 'Second-part single-subarray diag CSV not found.');
assert(exist(second_record_path, 'file') == 2, 'Second-part record not found.');

result_dir = fullfile(script_dir, 'results_step8_6_level2_subarray_selection');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

record_doc_path = fullfile(script_dir, '第8.6步_层次二第三部分_子阵选择与加权谱验证记录.md');
log_path = fullfile(result_dir, 'step8_6_level2_subarray_selection.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

log_msg(fid_log, 'Step 08.6 level 2 part 3: subarray selection and weighted spectrum validation');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'First-part commit: %s', first_part_commit);
log_msg(fid_log, 'Second-part commit: %s', second_part_commit);
log_msg(fid_log, 'Modify direction doc: %s', modify_doc_path);
log_msg(fid_log, 'First-part script: %s', first_script_path);
log_msg(fid_log, 'Second-part script: %s', second_script_path);
log_msg(fid_log, 'Second-part summary: %s', second_summary_csv);
log_msg(fid_log, 'Second-part single-subarray diag: %s', second_single_diag_csv);
log_msg(fid_log, 'Second-part record: %s', second_record_path);
log_msg(fid_log, 'Scope guard: level 2 subarray selection only. No fullscan, no level 3, no 2D az/el MUSIC, no covariance fitting.');

azCtr_deg = 0;
el_a = 0;
el_b = 0;
el_assumed_deg = 0;
el_scan_deg = 0;
T_snap = 260;
Lc = 2;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
K_phi_list = [20, 24, 28, 32];
sep_factor_list = [7, 10];
snr_list = [24, 28, 30];
Metkl = 100;
angle_step = 0.005;
base_seed = 20260626;
sigma_phi = 6;

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
work_span_deg = max(arrInfo.phiActRel(col_select)) - min(arrInfo.phiActRel(col_select));

log_msg(fid_log, '');
log_msg(fid_log, 'Geometry health check');
log_msg(fid_log, 'cfg.arr.Naz=%d, cfg.arr.Nel=%d, R=%.9f m, lambda=%.9f m', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.R, cfg.arr.lambda);
log_msg(fid_log, 'dPhi=%.9f deg, dz/lambda=%.9f, sectorHalf=%.9f deg, Q=%d', ...
    cfg.arr.dPhi, cfg.arr.dz / cfg.arr.lambda, cfg.beam.sectorHalf, Q);
log_msg(fid_log, 'working phi first/last/span=%.9f / %.9f / %.9f deg', ...
    arrInfo.phiActRel(1), arrInfo.phiActRel(Q), work_span_deg);
log_msg(fid_log, 'bw_eq_65=%.9f deg, angle_step=%.6f deg, ngrid=%d', ...
    bw_eq_65, angle_step, numel(angle_grid));
if Q ~= 65
    log_msg(fid_log, 'WARNING: Q=%d, expected 65.', Q);
end

route_names = { ...
    'center_real', ...
    'min_den_forward', ...
    'min_den_fb', ...
    'center_window_3_avg_spectrum', ...
    'center_window_5_avg_spectrum', ...
    'center_window_7_avg_spectrum', ...
    'center_window_9_avg_spectrum', ...
    'center_window_5_min_den', ...
    'center_window_7_min_den', ...
    'gaussian_weight_avg_spectrum', ...
    'gaussian_weight_den_then_inverse', ...
    'oracle_best_subarray_upper_bound'};
nroutes = numel(route_names);

center_window_size_by_route = [1, 0, 0, 3, 5, 7, 9, 5, 7, 0, 0, 0];
sigma_phi_by_route = nan(1, nroutes);
sigma_phi_by_route(10:11) = sigma_phi;

log_msg(fid_log, '');
log_msg(fid_log, 'Routes');
for iroute = 1:nroutes
    log_msg(fid_log, '  %2d: %s', iroute, route_names{iroute});
end

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
center_window_two_peak_sum = zeros(nroutes, nK, nsep, nsnr);
oracle_best_subarray_tol_count = zeros(nK, nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
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

    route_subsets = build_route_subsets_local(route_names, cache, sigma_phi);

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
                En = fbss_noise_subspace_level2_local(y_combined, K_phi, Lc);
                [D_forward, D_backward] = compute_subarray_denominators_local(cache, En);
                single_diag = analyze_single_subarrays_local(D_forward, angle_grid, target_theta, tol_deg);
                oracle = oracle_best_subarray_local(single_diag, tol_deg);

                [P_route, route_debug] = build_route_spectra_local(D_forward, D_backward, route_subsets);

                doa_all = cell(nroutes, 1);
                num_peaks_all = zeros(nroutes, 1);
                for iroute = 1:(nroutes - 1)
                    [doa_now, num_peaks_now] = estimate_from_spectrum_local(P_route(iroute, :), angle_grid, Lc);
                    doa_all{iroute} = doa_now;
                    num_peaks_all(iroute) = num_peaks_now;
                end
                doa_all{nroutes} = oracle.doa_est;
                num_peaks_all(nroutes) = oracle.num_peaks;

                if oracle.is_tol_abs
                    oracle_best_subarray_tol_count(iK, iSep, iSNR) = oracle_best_subarray_tol_count(iK, iSep, iSNR) + 1;
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
                    num_peaks_sum(iroute, iK, iSep, iSNR) = num_peaks_sum(iroute, iK, iSep, iSNR) + num_peaks_all(iroute);
                    center_window_two_peak_sum(iroute, iK, iSep, iSNR) = center_window_two_peak_sum(iroute, iK, iSep, iSNR) + ...
                        route_two_peak_rate_local(single_diag, route_subsets(iroute).idx);
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
                    spectrum_examples.single_diag = single_diag;
                    spectrum_examples.subarray_center_phi_deg = cache.subarray_center_phi_deg;
                    spectrum_examples.route_debug = route_debug;
                    spectrum_examples.oracle = oracle;
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
center_window_two_peak_rate = center_window_two_peak_sum / Metkl;
oracle_best_subarray_tol_rate = oracle_best_subarray_tol_count / Metkl;

[best_route_minus_center_real, best_route_minus_min_den, best_selection_route_idx, best_selection_tol] = ...
    calc_best_minus_metrics_local(tol_success_rate_abs01, route_names);

summary_rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    theta_sep_deg, Q, center_window_size_by_route, sigma_phi_by_route, ...
    raw_success_rate, tol_success_rate_abs01, tol_success_rate_rel025, rmse_deg, ...
    mean_num_peaks, degraded_rate, oracle_best_subarray_tol_rate, center_window_two_peak_rate, ...
    best_route_minus_center_real, best_route_minus_min_den);

summary_path = fullfile(result_dir, 'step8_6_level2_subarray_selection_summary.csv');
keypoints_path = fullfile(result_dir, 'step8_6_level2_subarray_selection_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_6_level2_subarray_selection_result.mat');
write_summary_csv_local(summary_path, summary_rows);
write_summary_csv_local(keypoints_path, summary_rows);

diagnosis = choose_diagnosis_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    tol_success_rate_abs01, oracle_best_subarray_tol_rate, best_route_minus_center_real, ...
    best_route_minus_min_den, best_selection_route_idx, best_selection_tol);

params = struct();
params.first_part_commit = first_part_commit;
params.second_part_commit = second_part_commit;
params.modify_doc_path = modify_doc_path;
params.first_script_path = first_script_path;
params.second_script_path = second_script_path;
params.second_summary_csv = second_summary_csv;
params.second_single_diag_csv = second_single_diag_csv;
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
params.sigma_phi = sigma_phi;
params.d_eq = d_eq;
params.bw_eq_65 = bw_eq_65;

save(mat_path, ...
    'params', 'route_names', 'K_phi_list', 'sep_factor_list', 'snr_list', 'angle_grid', ...
    'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', 'raw_success_rate', ...
    'tol_success_rate_abs01', 'tol_success_rate_rel025', 'rmse_deg', ...
    'mean_num_peaks', 'degraded_rate', 'oracle_best_subarray_tol_rate', ...
    'center_window_two_peak_rate', 'best_route_minus_center_real', ...
    'best_route_minus_min_den', 'best_selection_route_idx', 'best_selection_tol', ...
    'spectrum_examples', 'diagnosis');

plot_tol_sep10_snr30_local(fullfile(result_dir, 'level2_subarray_selection_tol_sep10_snr30.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, tol_success_rate_abs01);
plot_kphi_vs_tol_local(fullfile(result_dir, 'level2_subarray_selection_kphi_vs_tol.png'), ...
    route_names, K_phi_list, sep_factor_list, snr_list, tol_success_rate_abs01);
plot_center_window_size_vs_tol_local(fullfile(result_dir, 'level2_center_window_size_vs_tol.png'), ...
    route_names, center_window_size_by_route, K_phi_list, sep_factor_list, snr_list, tol_success_rate_abs01);
plot_oracle_gap_vs_route_local(fullfile(result_dir, 'level2_oracle_gap_vs_route.png'), ...
    K_phi_list, sep_factor_list, snr_list, tol_success_rate_abs01, oracle_best_subarray_tol_rate);

write_record_doc_local(record_doc_path, params, route_names, summary_rows, diagnosis, ...
    summary_path, keypoints_path, mat_path);

log_msg(fid_log, '');
log_msg(fid_log, 'Diagnostic conclusion: %s', diagnosis.conclusion);
log_msg(fid_log, 'Next step: %s', diagnosis.next_step);
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', keypoints_path);
log_msg(fid_log, '  %s', mat_path);
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_subarray_selection_tol_sep10_snr30.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_subarray_selection_kphi_vs_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_center_window_size_vs_tol.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'level2_oracle_gap_vs_route.png'));
log_msg(fid_log, '  %s', record_doc_path);
safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 subarray selection finished.');
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

function En = fbss_noise_subspace_level2_local(y_combined, K_phi, Lc)
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

function subsets = build_route_subsets_local(route_names, cache, sigma_phi)
    P_phi = cache.P_phi;
    p_mid = round((P_phi + 1) / 2);
    all_idx = 1:P_phi;
    subsets = repmat(struct('idx', [], 'weights', []), numel(route_names), 1);

    subsets(1).idx = p_mid;
    subsets(2).idx = all_idx;
    subsets(3).idx = all_idx;
    subsets(4).idx = center_window_idx_local(P_phi, 3);
    subsets(5).idx = center_window_idx_local(P_phi, 5);
    subsets(6).idx = center_window_idx_local(P_phi, 7);
    subsets(7).idx = center_window_idx_local(P_phi, 9);
    subsets(8).idx = center_window_idx_local(P_phi, 5);
    subsets(9).idx = center_window_idx_local(P_phi, 7);
    subsets(10).idx = all_idx;
    subsets(11).idx = all_idx;
    subsets(12).idx = all_idx;

    w = exp(-0.5 * (cache.subarray_center_phi_deg(:).' / sigma_phi).^2);
    w = w / sum(w);
    subsets(10).weights = w;
    subsets(11).weights = w;
end

function idx = center_window_idx_local(P_phi, win)
    p_mid = round((P_phi + 1) / 2);
    half = floor(win / 2);
    idx = max(1, p_mid-half):min(P_phi, p_mid+half);
end

function [P_route, route_debug] = build_route_spectra_local(D_forward, D_backward, subsets)
    D_fb = 0.5 * (D_forward + D_backward);
    ngrid = size(D_forward, 2);
    P_route = zeros(12, ngrid);

    P_route(1, :) = inv_den_local(D_forward(subsets(1).idx, :));
    P_route(2, :) = inv_den_local(min(D_forward(subsets(2).idx, :), [], 1));
    P_route(3, :) = inv_den_local(min(D_fb(subsets(3).idx, :), [], 1));
    P_route(4, :) = mean(inv_den_local(D_forward(subsets(4).idx, :)), 1);
    P_route(5, :) = mean(inv_den_local(D_forward(subsets(5).idx, :)), 1);
    P_route(6, :) = mean(inv_den_local(D_forward(subsets(6).idx, :)), 1);
    P_route(7, :) = mean(inv_den_local(D_forward(subsets(7).idx, :)), 1);
    P_route(8, :) = inv_den_local(min(D_forward(subsets(8).idx, :), [], 1));
    P_route(9, :) = inv_den_local(min(D_forward(subsets(9).idx, :), [], 1));
    P_route(10, :) = subsets(10).weights * inv_den_local(D_forward);
    P_route(11, :) = inv_den_local(subsets(11).weights * D_forward);
    P_route(12, :) = max(inv_den_local(D_forward), [], 1);

    route_debug = struct();
    route_debug.subsets = subsets;
end

function y = inv_den_local(x)
    y = 1 ./ max(real(x), eps);
end

function diag_list = analyze_single_subarrays_local(D_forward, angle_grid, target_theta, tol_deg)
    P_phi = size(D_forward, 1);
    diag_list = repmat(struct( ...
        'subarray_index', NaN, ...
        'num_peaks', NaN, ...
        'doa_est', nan(1, 2), ...
        'peak_error_max_deg', NaN, ...
        'is_two_peak_valid', false), P_phi, 1);

    for p = 1:P_phi
        Pmu = inv_den_local(D_forward(p, :));
        [doa_est, num_peaks] = estimate_from_spectrum_local(Pmu, angle_grid, 2);
        peak_error_max = NaN;
        is_valid = false;
        if num_peaks >= 2
            peak_error_max = max(abs(sort(doa_est(:).') - sort(target_theta(:).')));
            is_valid = is_valid_doa_success(doa_est, target_theta, tol_deg);
        end
        diag_list(p).subarray_index = p;
        diag_list(p).num_peaks = num_peaks;
        diag_list(p).doa_est = doa_est;
        diag_list(p).peak_error_max_deg = peak_error_max;
        diag_list(p).is_two_peak_valid = is_valid;
    end
end

function oracle = oracle_best_subarray_local(diag_list, tol_deg)
    num_peaks = [diag_list.num_peaks];
    errors = [diag_list.peak_error_max_deg];
    valid_two = num_peaks >= 2 & isfinite(errors);
    oracle = struct();
    oracle.doa_est = nan(1, 2);
    oracle.num_peaks = max(num_peaks);
    oracle.best_subarray_index = NaN;
    oracle.best_error = NaN;
    oracle.is_tol_abs = false;

    if any(valid_two)
        [best_error, rel_idx] = min(errors(valid_two));
        idx_all = find(valid_two);
        best_idx = idx_all(rel_idx);
        oracle.doa_est = diag_list(best_idx).doa_est;
        oracle.best_subarray_index = best_idx;
        oracle.best_error = best_error;
        oracle.is_tol_abs = best_error <= tol_deg;
    end
end

function rate = route_two_peak_rate_local(diag_list, idx)
    if isempty(idx)
        rate = NaN;
        return
    end
    rate = mean([diag_list(idx).num_peaks] >= 2);
end

function [doa_est, num_peaks] = estimate_from_spectrum_local(Pmu, angle_grid, Lc)
    [~, peak_inds] = FindLocalPeak_NoEdge_Fun(Pmu);
    num_peaks = numel(peak_inds);
    if num_peaks < Lc
        doa_est = nan(1, Lc);
    else
        doa_est = sort(angle_grid(peak_inds(1:Lc)));
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

function [best_minus_center, best_minus_min_den, best_idx, best_tol] = calc_best_minus_metrics_local(tol_abs, route_names)
    idx_center = find(strcmp(route_names, 'center_real'), 1);
    idx_min_fwd = find(strcmp(route_names, 'min_den_forward'), 1);
    idx_min_fb = find(strcmp(route_names, 'min_den_fb'), 1);
    selection_idx = 4:11;

    [~, nK, nsep, nsnr] = size(tol_abs);
    best_minus_center = zeros(nK, nsep, nsnr);
    best_minus_min_den = zeros(nK, nsep, nsnr);
    best_idx = zeros(nK, nsep, nsnr);
    best_tol = zeros(nK, nsep, nsnr);

    for iK = 1:nK
        for iSep = 1:nsep
            for iSNR = 1:nsnr
                vals = tol_abs(selection_idx, iK, iSep, iSNR);
                [best_val, rel_idx] = max(vals);
                best_idx(iK, iSep, iSNR) = selection_idx(rel_idx);
                best_tol(iK, iSep, iSNR) = best_val;
                center_val = tol_abs(idx_center, iK, iSep, iSNR);
                min_val = max([tol_abs(idx_min_fwd, iK, iSep, iSNR), tol_abs(idx_min_fb, iK, iSep, iSNR)]);
                best_minus_center(iK, iSep, iSNR) = best_val - center_val;
                best_minus_min_den(iK, iSep, iSNR) = best_val - min_val;
            end
        end
    end
end

function rows = build_summary_rows_local(route_names, K_phi_list, sep_factor_list, snr_list, theta_sep_deg, Q, ...
    center_window_size_by_route, sigma_phi_by_route, raw_rate, tol_abs, tol_rel, rmse_deg, mean_num_peaks, ...
    degraded_rate, oracle_tol_rate, center_window_two_peak_rate, best_minus_center, best_minus_min_den)

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
                        route_names{iroute}, K_phi, P_phi, center_window_size_by_route(iroute), ...
                        sigma_phi_by_route(iroute), sep_factor_list(iSep), theta_sep_deg(iSep), snr_list(iSNR), ...
                        raw_rate(iroute, iK, iSep, iSNR), tol_abs(iroute, iK, iSep, iSNR), ...
                        tol_rel(iroute, iK, iSep, iSNR), rmse_deg(iroute, iK, iSep, iSNR), ...
                        mean_num_peaks(iroute, iK, iSep, iSNR), degraded_rate(iroute, iK, iSep, iSNR), ...
                        oracle_tol_rate(iK, iSep, iSNR), center_window_two_peak_rate(iroute, iK, iSep, iSNR), ...
                        best_minus_center(iK, iSep, iSNR), best_minus_min_den(iK, iSep, iSNR)};
                end
            end
        end
    end
end

function write_summary_csv_local(path_out, rows)
    header = ['route_name,K_phi,P_phi,center_window_size,sigma_phi,sep_factor,theta_sep_deg,snr_db,' ...
        'raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,mean_num_peaks,' ...
        'degraded_rate,oracle_best_subarray_tol_rate,center_window_two_peak_rate,' ...
        'best_route_minus_center_real,best_route_minus_min_den'];
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', header);
    for ii = 1:size(rows, 1)
        fprintf(fid, '%s,%d,%d,%d,%.9f,%d,%.9f,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f\n', ...
            rows{ii, 1}, rows{ii, 2}, rows{ii, 3}, rows{ii, 4}, rows{ii, 5}, rows{ii, 6}, ...
            rows{ii, 7}, rows{ii, 8}, rows{ii, 9}, rows{ii, 10}, rows{ii, 11}, rows{ii, 12}, ...
            rows{ii, 13}, rows{ii, 14}, rows{ii, 15}, rows{ii, 16}, rows{ii, 17}, rows{ii, 18});
    end
end

function diagnosis = choose_diagnosis_local(route_names, K_phi_list, sep_factor_list, snr_list, ...
    tol_abs, oracle_tol, best_minus_center, best_minus_min_den, best_selection_route_idx, best_selection_tol)

    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    idx_center = find(strcmp(route_names, 'center_real'), 1);
    idx_min_fwd = find(strcmp(route_names, 'min_den_forward'), 1);
    idx_min_fb = find(strcmp(route_names, 'min_den_fb'), 1);

    best_actual_tol_by_K = squeeze(max(tol_abs(1:11, :, idxSep, idxSNR), [], 1));
    [best_actual_tol, best_K_idx] = max(best_actual_tol_by_K);
    best_K = K_phi_list(best_K_idx);
    best_actual_route_idx = find(tol_abs(1:11, best_K_idx, idxSep, idxSNR) == best_actual_tol, 1, 'first');
    best_actual_route = route_names{best_actual_route_idx};
    center_at_best = tol_abs(idx_center, best_K_idx, idxSep, idxSNR);
    min_den_at_best = max([tol_abs(idx_min_fwd, best_K_idx, idxSep, idxSNR), tol_abs(idx_min_fb, best_K_idx, idxSep, idxSNR)]);
    oracle_at_best = oracle_tol(best_K_idx, idxSep, idxSNR);
    oracle_gap = oracle_at_best - best_actual_tol;

    best_selection_tol_key = best_selection_tol(best_K_idx, idxSep, idxSNR);
    best_selection_route = route_names{best_selection_route_idx(best_K_idx, idxSep, idxSNR)};
    minus_center = best_minus_center(best_K_idx, idxSep, idxSNR);
    minus_min_den = best_minus_min_den(best_K_idx, idxSep, idxSNR);

    if minus_center >= 0.05 && minus_min_den >= 0.05
        conclusion = '层次二继续有效，下一步围绕该 route 做更大规模 K_phi/SNR 扫描。';
        next_step = '继续当前最佳子阵选择/加权 route 的小规模扩大扫描。';
        case_id = 'A';
    elseif oracle_gap >= 0.10
        conclusion = '层次二的关键不是谱函数形式，而是如何从多个子阵中识别有效子阵。';
        next_step = '继续做子阵选择判据，例如 peak-to-valley、峰间距、谱峰对称性和子阵中心角权重。';
        case_id = 'C';
    elseif oracle_at_best < 0.40
        conclusion = '在当前完全同相、同俯仰、sep=10 边界下，层次二一维 MUSIC 谱函数族的理论上限也有限。';
        next_step = '进入层次二的一维圆柱阵平滑协方差拟合，仍不进入层次三。';
        case_id = 'D';
    else
        conclusion = '中心子阵真实流形已经基本达到当前层次二 MUSIC 谱函数族上限，进一步聚合收益有限。';
        if oracle_at_best - center_at_best >= 0.10
            next_step = '继续做子阵选择判据，因为 oracle 上限仍明显高于 center_real。';
        else
            next_step = '进入层次二协方差拟合。';
        end
        case_id = 'B';
    end

    diagnosis = struct();
    diagnosis.case_id = case_id;
    diagnosis.key_sep_factor = sep_factor_list(idxSep);
    diagnosis.key_snr_db = snr_list(idxSNR);
    diagnosis.best_K_phi = best_K;
    diagnosis.best_actual_route = best_actual_route;
    diagnosis.best_actual_tol = best_actual_tol;
    diagnosis.center_real_tol_at_best_K = center_at_best;
    diagnosis.min_den_tol_at_best_K = min_den_at_best;
    diagnosis.oracle_tol_at_best_K = oracle_at_best;
    diagnosis.oracle_gap = oracle_gap;
    diagnosis.best_selection_route = best_selection_route;
    diagnosis.best_selection_tol = best_selection_tol_key;
    diagnosis.best_route_minus_center_real = minus_center;
    diagnosis.best_route_minus_min_den = minus_min_den;
    diagnosis.conclusion = conclusion;
    diagnosis.next_step = next_step;
end

function plot_tol_sep10_snr30_local(path_out, route_names, K_phi_list, sep_factor_list, snr_list, tol_abs)
    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    vals = squeeze(tol_abs(:, :, idxSep, idxSNR));
    fig = figure('Visible', 'off', 'Position', [80, 80, 1180, 650]);
    bar(vals.');
    grid on
    xlabel('K_\phi');
    ylabel('tol success abs01');
    title(sprintf('Subarray selection tol, sep=%d, SNR=%d dB', sep_factor_list(idxSep), snr_list(idxSNR)));
    set(gca, 'XTickLabel', string(K_phi_list));
    legend(route_names, 'Interpreter', 'none', 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_kphi_vs_tol_local(path_out, route_names, K_phi_list, sep_factor_list, snr_list, tol_abs)
    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    show_routes = {'center_real', 'min_den_forward', 'min_den_fb', ...
        'center_window_3_avg_spectrum', 'center_window_5_min_den', ...
        'gaussian_weight_avg_spectrum', 'oracle_best_subarray_upper_bound'};
    fig = figure('Visible', 'off', 'Position', [100, 100, 980, 620]);
    for ii = 1:numel(show_routes)
        idx = find(strcmp(route_names, show_routes{ii}), 1);
        plot(K_phi_list, squeeze(tol_abs(idx, :, idxSep, idxSNR)), '-o', 'LineWidth', 1.2);
        hold on
    end
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('K_\phi');
    ylabel('tol success abs01');
    title(sprintf('K_phi versus tol, sep=%d, SNR=%d dB', sep_factor_list(idxSep), snr_list(idxSNR)));
    legend(show_routes, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_center_window_size_vs_tol_local(path_out, route_names, center_window_size, K_phi_list, sep_factor_list, snr_list, tol_abs)
    idxK = find(K_phi_list == 24, 1);
    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    avg_idx = find(contains(route_names, 'center_window_') & contains(route_names, 'avg_spectrum'));
    min_idx = find(contains(route_names, 'center_window_') & contains(route_names, 'min_den'));
    fig = figure('Visible', 'off', 'Position', [100, 100, 880, 560]);
    plot(center_window_size(avg_idx), squeeze(tol_abs(avg_idx, idxK, idxSep, idxSNR)), '-o', 'LineWidth', 1.3);
    hold on
    plot(center_window_size(min_idx), squeeze(tol_abs(min_idx, idxK, idxSep, idxSNR)), '-s', 'LineWidth', 1.3);
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('center window size');
    ylabel('tol success abs01');
    title(sprintf('Center window size, K=%d, sep=%d, SNR=%d dB', K_phi_list(idxK), sep_factor_list(idxSep), snr_list(idxSNR)));
    legend({'avg spectrum', 'min den'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_oracle_gap_vs_route_local(path_out, K_phi_list, sep_factor_list, snr_list, tol_abs, oracle_tol)
    idxSep = find(sep_factor_list == 10, 1);
    idxSNR = find(snr_list == 30, 1);
    best_actual = squeeze(max(tol_abs(1:11, :, idxSep, idxSNR), [], 1));
    oracle = squeeze(oracle_tol(:, idxSep, idxSNR));
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 560]);
    plot(K_phi_list, oracle, '-o', 'LineWidth', 1.4);
    hold on
    plot(K_phi_list, best_actual, '-s', 'LineWidth', 1.4);
    plot(K_phi_list, oracle - best_actual, '-^', 'LineWidth', 1.4);
    hold off
    grid on
    ylim([0 1.05]);
    xlabel('K_\phi');
    ylabel('rate / gap');
    title(sprintf('Oracle gap, sep=%d, SNR=%d dB', sep_factor_list(idxSep), snr_list(idxSNR)));
    legend({'oracle', 'best actual route', 'oracle gap'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function write_record_doc_local(path_out, params, route_names, summary_rows, diagnosis, summary_path, keypoints_path, mat_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# 第8.6步 层次二第三部分：子阵选择与加权谱验证记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 第一部分提交：`%s`\n', params.first_part_commit);
    fprintf(fid, '- 第二部分提交：`%s`\n', params.second_part_commit);
    fprintf(fid, '- 修改方向文档：`%s`\n', params.modify_doc_path);
    fprintf(fid, '- 本轮只做层次二第三部分：中心子阵与子阵选择/加权聚合优化。不做 fullscan、层次三、2D az/el MUSIC、协方差拟合、PME、SBL、SPICE、DML。\n\n');

    fprintf(fid, '## 参数\n\n');
    fprintf(fid, '- `Q=%d`, `K_phi_list=%s`, `sep_factor_list=%s`, `snr_list=%s`, `Metkl=%d`, `angle_step=%.4f deg`, `sigma_phi=%.2f deg`。\n', ...
        params.Q, mat2str(params.K_phi_list), mat2str(params.sep_factor_list), mat2str(params.snr_list), ...
        params.Metkl, params.angle_step, params.sigma_phi);
    fprintf(fid, '- 65列基线 `bw_eq_65=%.9f deg`。\n\n', params.bw_eq_65);

    fprintf(fid, '## Route\n\n');
    for ii = 1:numel(route_names)
        fprintf(fid, '- `%s`\n', route_names{ii});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 关键对比：sep=10, SNR=30, best K=%d\n\n', diagnosis.best_K_phi);
    fprintf(fid, '- 最佳实际 route：`%s`，tol_abs01=%.3f。\n', diagnosis.best_actual_route, diagnosis.best_actual_tol);
    fprintf(fid, '- center_real：tol_abs01=%.3f。\n', diagnosis.center_real_tol_at_best_K);
    fprintf(fid, '- min_den 最好值：tol_abs01=%.3f。\n', diagnosis.min_den_tol_at_best_K);
    fprintf(fid, '- oracle：tol_abs01=%.3f，oracle gap=%.3f。\n', diagnosis.oracle_tol_at_best_K, diagnosis.oracle_gap);
    fprintf(fid, '- 最佳加权/选择 route：`%s`，tol_abs01=%.3f，minus center=%.3f，minus min_den=%.3f。\n\n', ...
        diagnosis.best_selection_route, diagnosis.best_selection_tol, diagnosis.best_route_minus_center_real, diagnosis.best_route_minus_min_den);

    fprintf(fid, '| route | K_phi | tol_abs01 | tol_rel025 | RMSE | mean_peaks | oracle_rate | center_window_two_peak_rate |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
    for ii = 1:size(summary_rows, 1)
        if summary_rows{ii, 2} == diagnosis.best_K_phi && summary_rows{ii, 6} == 10 && summary_rows{ii, 8} == 30
            fprintf(fid, '| `%s` | %d | %.3f | %.3f | %.5f | %.3f | %.3f | %.3f |\n', ...
                summary_rows{ii, 1}, summary_rows{ii, 2}, summary_rows{ii, 10}, summary_rows{ii, 11}, ...
                summary_rows{ii, 12}, summary_rows{ii, 13}, summary_rows{ii, 15}, summary_rows{ii, 16});
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 判断\n\n');
    fprintf(fid, '- 是否存在稳定超过 center_real 的方案：%s。\n', yesno_local(diagnosis.best_route_minus_center_real >= 0.05));
    fprintf(fid, '- 是否存在稳定超过 min_den 的方案：%s。\n', yesno_local(diagnosis.best_route_minus_min_den >= 0.05));
    fprintf(fid, '- 是否存在明显 oracle gap：%s。\n\n', yesno_local(diagnosis.oracle_gap >= 0.10));
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
