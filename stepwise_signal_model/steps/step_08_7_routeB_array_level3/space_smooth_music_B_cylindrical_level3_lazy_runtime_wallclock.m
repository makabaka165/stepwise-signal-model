% Step 8.7 Part 7B final runtime validation script.
% This script implements true lazy cascade execution and wall-clock timing.
% It keeps only routes needed for the final engineering runtime chain:
% level2 MUSIC, common-el refocus, level2 rank1 fallback,
% 2D MUSIC, and pair-local refinement.
% Earlier exploratory routes are preserved in their own stage scripts.

clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
step75_dir = fullfile(steps_dir, 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');

addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
addpath(step75_dir);

cfg = sim_cfg();

part7_result_dir = fullfile(script_dir, 'results_step8_7_7_cascade_dispatch_runtime');
part7_keypoints_csv_path = fullfile(part7_result_dir, 'step8_7_7_cascade_dispatch_runtime_keypoints.csv');
part7_summary_csv_path = fullfile(part7_result_dir, 'step8_7_7_cascade_dispatch_runtime_summary.csv');
part6b_result_dir = fullfile(script_dir, 'results_step8_7_6b_observable_dispatch_calibrated');
part6b_keypoints_csv_path = fullfile(part6b_result_dir, 'step8_7_6b_observable_dispatch_calibrated_keypoints.csv');
if ~exist(part7_keypoints_csv_path, 'file')
    error('Missing required part-7 keypoints: %s', part7_keypoints_csv_path);
end
if ~exist(part7_summary_csv_path, 'file')
    error('Missing required part-7 summary: %s', part7_summary_csv_path);
end
if ~exist(part6b_keypoints_csv_path, 'file')
    error('Missing required part-6B keypoints: %s', part6b_keypoints_csv_path);
end
part7_keypoints_tbl = readtable(part7_keypoints_csv_path, 'TextType', 'string');
part7_summary_tbl = readtable(part7_summary_csv_path, 'TextType', 'string');
part6b_keypoints_tbl = readtable(part6b_keypoints_csv_path, 'TextType', 'string');

result_tag = getenv('STEP87_RESULT_TAG');
if isempty(result_tag)
    result_tag = '';
end
result_dir = fullfile(script_dir, ['results_step8_7_7b_lazy_runtime_wallclock' char(result_tag)]);
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_7_7b_lazy_runtime_wallclock.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

summary_csv_path = fullfile(result_dir, 'step8_7_7b_lazy_runtime_wallclock_summary.csv');
keypoints_csv_path = fullfile(result_dir, 'step8_7_7b_lazy_runtime_wallclock_keypoints.csv');
trial_csv_path = fullfile(result_dir, 'step8_7_7b_lazy_runtime_wallclock_trial_runtime.csv');
mat_path = fullfile(result_dir, 'step8_7_7b_lazy_runtime_wallclock_result.mat');
if isempty(result_tag)
    record_doc_path = fullfile(script_dir, '第8.7步_7B_真实lazy级联运行时间验证记录.md');
else
    record_doc_path = fullfile(script_dir, ['第8.7步_7B_真实lazy级联运行时间验证记录' char(result_tag) '.md']);
end

log_msg(fid_log, 'Step 08.7 part 7B: true lazy cascade wall-clock runtime validation');
log_msg(fid_log, 'Result tag: "%s". Result directory: %s.', char(result_tag), result_dir);
log_msg(fid_log, 'Scope: run a real full-route wall-clock baseline and a real lazy cascade. Lazy mode does not call untriggered downstream route functions.');
log_msg(fid_log, 'Constraints: no new DOA algorithm, no V2, no complex-gain q, no weak-target SIC, no anti-phase derivative, no 4D search, no new fullscan, no edits to step 8.6 or part-7 outputs.');
log_msg(fid_log, 'Part-7 cascade gate is preserved. Because part 7 uses common-el refocus as a safety gate for low-cost early-stop, lazy mode computes refocus before allowing level2/refocus/rank1 low-cost stops.');

azCtr_deg = 0;
sep_factor = 10;
snr_list = [0, 8, 16];
Metkl = 30;
quick_mode = false;
if strcmpi(getenv('STEP87_QUICK_MODE'), '1')
    Metkl = 3;
    quick_mode = true;
end
T_snap = 260;
Lc = 2;
K_phi_level2 = 20;
K_phi_music = 20;
K_z_music = 8;
K_phi_covfit = 6;
K_z_covfit = 3;
az_grid = azCtr_deg - 0.6:0.02:azCtr_deg + 0.6;
el_grid = -2:0.5:12;
el_refocus_grid = -2:0.5:12;
el_bank = -5:1:15;
az_tol_deg = 0.1;
el_tol_deg = 0.5;
min_pair_sep_deg = 0.05;
max_pair_sep_deg = 0.80;
base_seed = 20260917;

arrInfo = arr_cyl(cfg, azCtr_deg);
Q = cfg.beam.subNaz;
Nel = cfg.arr.Nel;
X3d = arrInfo.XAct(1:Q, :);
Y3d = arrInfo.YAct(1:Q, :);
Z3d = arrInfo.ZAct(1:Q, :);
A_ref_2d = exp(-1j * 2*pi / cfg.arr.lambda * ...
    (X3d * cosd(azCtr_deg) + Y3d * sind(azCtr_deg)));

d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
bw_eq_65 = 50.8 * 1.45 * cfg.arr.lambda / ((Q - 1) * d_eq);
theta_sep = bw_eq_65 / sep_factor;
theta_true = sort([azCtr_deg - theta_sep/2, azCtr_deg + theta_sep/2]);

log_msg(fid_log, 'Geometry: Q=%d, Nel=%d, theta_sep=%.9f deg.', Q, Nel, theta_sep);
log_msg(fid_log, 'Run control: Metkl=%d, quick_mode=%d, SNR=%s, T_snap=%d, sep_factor=%d.', ...
    Metkl, quick_mode, mat2str(snr_list), T_snap, sep_factor);
log_msg(fid_log, 'Timing excludes plotting and file I/O. Per-route timing uses tic/toc around each route function.');

level2_pair_candidates = make_pair_candidates_local(az_grid, min_pair_sep_deg, max_pair_sep_deg);
level2_cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_bank, K_phi_level2, level2_pair_candidates);
level2_refocus_cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_refocus_grid, K_phi_level2, level2_pair_candidates);
music_cache = make_level3_grid_cache_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_grid, K_phi_music, K_z_music);
[p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi_covfit, K_z_covfit);

scenarios = build_dispatch_scenarios_local(snr_list);
log_msg(fid_log, 'Scenario count=%d. Reused from part 6B/7 reduced set.', numel(scenarios));

s1_base = exp(1j * 2*pi * (0:T_snap-1) / 17);
v_base = exp(1j * 2*pi * (0:T_snap-1) / 23 + 1j*pi/7);

log_msg(fid_log, 'Running one warm-up trial. Warm-up is not included in runtime statistics.');
rng(base_seed - 1);
sc_warm = scenarios(1);
s1 = s1_base .* exp(1j * 2*pi * rand);
v = v_base .* exp(1j * 2*pi * rand);
y_clean_warm = make_clean_cylindrical_observations_general_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, theta_true(1), theta_true(2), ...
    sc_warm.el_true(1), sc_warm.el_true(2), sc_warm.beta, sc_warm.phi_deg, sc_warm.rho, s1, v);
y_noisy_warm = add_noise_local(y_clean_warm, sc_warm.snr_db);
run_full_route_wallclock_local(y_noisy_warm, sc_warm, X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
    az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, ...
    Lc, level2_cache_map, level2_refocus_cache_map, music_cache, p_sel, r_sel, theta_true, ...
    min_pair_sep_deg, max_pair_sep_deg);
run_lazy_cascade_wallclock_local(y_noisy_warm, sc_warm, X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
    az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, ...
    Lc, level2_cache_map, level2_refocus_cache_map, music_cache, p_sel, r_sel, theta_true, ...
    min_pair_sep_deg, max_pair_sep_deg);
log_msg(fid_log, 'Warm-up finished.');

trial_rows = cell(numel(scenarios) * Metkl, 1);
row_idx = 0;
tic_all = tic;
for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    log_msg(fid_log, 'Scenario %02d/%02d group=%s case=%s SNR=%g beta=%.3g phase=%.1f rho=%.3g el=[%.1f %.1f].', ...
        isc, numel(scenarios), sc.group, sc.case_name, sc.snr_db, sc.beta, sc.phi_deg, sc.rho, sc.el_true(1), sc.el_true(2));
    for imc = 1:Metkl
        rng(base_seed + isc * 1000 + imc);
        s1 = s1_base .* exp(1j * 2*pi * rand);
        v = v_base .* exp(1j * 2*pi * rand);
        y_clean_2d = make_clean_cylindrical_observations_general_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, theta_true(1), theta_true(2), ...
            sc.el_true(1), sc.el_true(2), sc.beta, sc.phi_deg, sc.rho, s1, v);
        y_noisy_2d = add_noise_local(y_clean_2d, sc.snr_db);

        [full_result, full_time] = run_full_route_wallclock_local(y_noisy_2d, sc, X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
            az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, ...
            Lc, level2_cache_map, level2_refocus_cache_map, music_cache, p_sel, r_sel, theta_true, ...
            min_pair_sep_deg, max_pair_sep_deg);
        [lazy_result, lazy_time] = run_lazy_cascade_wallclock_local(y_noisy_2d, sc, X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
            az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, ...
            Lc, level2_cache_map, level2_refocus_cache_map, music_cache, p_sel, r_sel, theta_true, ...
            min_pair_sep_deg, max_pair_sep_deg);

        full_success = joint_success_from_result_local(full_result, theta_true, sc.el_true, az_tol_deg, el_tol_deg);
        lazy_success = joint_success_from_result_local(lazy_result, theta_true, sc.el_true, az_tol_deg, el_tol_deg);
        oracle_boundary = sc.weak_target_flag || sc.anti_phase_flag;
        lazy_route = string(getfield_default_local(lazy_result, 'recommended_route', ""));
        lazy_conf = string(getfield_default_local(lazy_result, 'confidence_flag', ""));
        lazy_false_high = strcmp(lazy_conf, "high") && ~lazy_success;
        lazy_false_medium_high = any(strcmp(lazy_conf, ["high", "medium"])) && ~lazy_success;
        lazy_boundary_missed = oracle_boundary && strcmp(lazy_conf, "high") && ...
            ~any(strcmp(lazy_route, ["low_confidence", "boundary_unreliable"])) && ~lazy_success;
        runtime_speedup = full_time.t_total / max(lazy_time.t_total, eps);
        runtime_reduction = 1 - lazy_time.t_total / max(full_time.t_total, eps);

        row_idx = row_idx + 1;
        trial_rows{row_idx} = make_lazy_trial_row_local(sc, imc, full_result, lazy_result, ...
            full_success, lazy_success, lazy_false_high, lazy_false_medium_high, lazy_boundary_missed, ...
            full_time, lazy_time, runtime_speedup, runtime_reduction);
    end
end
elapsed_sec = toc(tic_all);
log_msg(fid_log, 'Runtime loops finished in %.2f sec.', elapsed_sec);

trial_rows = trial_rows(1:row_idx);
trial_tbl = cell2table(vertcat(trial_rows{:}), 'VariableNames', lazy_trial_var_names_local());
summary_tbl = build_lazy_summary_table_local(trial_tbl);
keypoints_tbl = build_lazy_keypoints_local(summary_tbl, trial_tbl, part7_keypoints_tbl, part6b_keypoints_tbl);

log_msg(fid_log, 'Writing trial, summary, keypoints and MAT outputs.');
writetable(trial_tbl, trial_csv_path);
writetable(summary_tbl, summary_csv_path);
writetable(keypoints_tbl, keypoints_csv_path);
log_msg(fid_log, 'Rendering plots.');
plot_lazy_vs_full_runtime_boxplot_local(trial_tbl, fullfile(result_dir, 'lazy_vs_full_runtime_boxplot.png'));
plot_runtime_speedup_by_group_local(summary_tbl, fullfile(result_dir, 'runtime_speedup_by_group.png'));
plot_lazy_success_vs_full_success_local(summary_tbl, fullfile(result_dir, 'lazy_success_vs_full_success.png'));
plot_execution_rate_by_stage_local(summary_tbl, fullfile(result_dir, 'execution_rate_by_stage.png'));
plot_early_stop_stage_distribution_local(trial_tbl, fullfile(result_dir, 'early_stop_stage_distribution.png'));
plot_runtime_vs_route_used_local(trial_tbl, fullfile(result_dir, 'runtime_vs_route_used.png'));
save(mat_path, 'trial_tbl', 'summary_tbl', 'keypoints_tbl', 'part7_keypoints_tbl', 'part7_summary_tbl', ...
    'part6b_keypoints_tbl', 'az_grid', 'el_grid', 'el_refocus_grid', 'el_bank', 'theta_true', 'theta_sep', ...
    'K_phi_level2', 'K_phi_music', 'K_z_music', 'K_phi_covfit', 'K_z_covfit', ...
    'p_sel', 'r_sel', 'cfg', 'quick_mode', 'Metkl', '-v7');
write_lazy_record_doc_local(record_doc_path, keypoints_tbl, result_dir, elapsed_sec, Metkl, quick_mode);
log_msg(fid_log, 'Outputs written to %s', result_dir);
function scenarios = build_dispatch_scenarios_local(snr_list)
    scenarios = repmat(make_dispatch_scenario_local('', '', NaN, [NaN, NaN], NaN, NaN, NaN, NaN), 0, 1);
    idx = 0;
    rho_list = [1, 0.7, 0.5];
    for iv = 1:numel(rho_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_dispatch_scenario_local('rho_scan', sprintf('rho_%g', rho_list(iv)), ...
                snr_list(is), [0, 0], 1, 0, rho_list(iv), 0);
        end
    end
    beta_list = [1, 0.5, 0.3, 0.1];
    for iv = 1:numel(beta_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_dispatch_scenario_local('beta_scan', sprintf('beta_%g', beta_list(iv)), ...
                snr_list(is), [0, 0], beta_list(iv), 0, 1, 0);
        end
    end
    phase_list = [0, 120, 150, 180];
    for iv = 1:numel(phase_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_dispatch_scenario_local('phase_scan', sprintf('phase_%g', phase_list(iv)), ...
                snr_list(is), [0, 0], 1, phase_list(iv), 1, 0);
        end
    end
    large_cases = { ...
        'A_el2_beta1_phase0_rho1',  [0, 2],  1,   0,   1; ...
        'B_el5_beta1_phase0_rho1',  [0, 5],  1,   0,   1; ...
        'C_el5_beta05_phase0_rho1', [0, 5],  0.5, 0,   1; ...
        'D_el5_beta1_phase180_rho1',[0, 5],  1,   180, 1; ...
        'E_el5_beta1_phase0_rho07', [0, 5],  1,   0,   0.7; ...
        'F_el10_beta05_phase180_rho07',[0, 10], 0.5, 180, 0.7};
    for iv = 1:size(large_cases, 1)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_dispatch_scenario_local('large_el', large_cases{iv, 1}, ...
                snr_list(is), large_cases{iv, 2}, large_cases{iv, 3}, large_cases{iv, 4}, large_cases{iv, 5}, 0);
        end
    end
end

function sc = make_dispatch_scenario_local(group, case_name, snr_db, el_true, beta, phi_deg, rho, el_assumed)
    sc = struct();
    sc.group = group;
    sc.stage = group;
    sc.case_name = case_name;
    sc.snr_db = snr_db;
    sc.el_true = el_true;
    sc.el_assumed = el_assumed;
    sc.el_b = el_true(2);
    sc.el_mismatch = abs(el_assumed - mean(el_true));
    sc.el_diff = abs(diff(el_true));
    sc.beta = beta;
    sc.phi_deg = phi_deg;
    sc.rho = rho;
    sc.large_el_flag = sc.el_diff >= 2;
    sc.common_el_flag = sc.el_diff < 0.5;
    sc.weak_target_flag = beta <= 0.3;
    sc.anti_phase_flag = min(abs(phi_deg - 180), abs(phi_deg + 180)) <= 30 || phi_deg >= 150;
end

function y_clean_2d = make_clean_cylindrical_observations_general_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, theta_b, el_a, el_b, beta, phi_deg, rho, s1, v)
    rho = min(max(rho, 0), 1);
    s2 = beta * exp(1j * deg2rad(phi_deg)) * (rho * s1 + sqrt(max(1 - rho^2, 0)) * v);
    A_a = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, el_a);
    A_b = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_b, el_b);
    y_clean_2d = reshape(A_a(:) * s1 + A_b(:) * s2, size(X3d, 1), size(X3d, 2), numel(s1));
end

function A = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_deg)
    k = 2*pi / lambda;
    phase = X3d * (cosd(el_deg) * cosd(az_deg)) + ...
        Y3d * (cosd(el_deg) * sind(az_deg)) + ...
        Z3d * sind(el_deg);
    A = conj(A_ref_2d) .* exp(-1j * k * phase);
end

function y_noisy = add_noise_local(y_clean, snr_db)
    sig_power = mean(abs(y_clean(:)).^2);
    sigma2 = sig_power / 10^(snr_db/10);
    noise = sqrt(sigma2/2) * (randn(size(y_clean)) + 1j * randn(size(y_clean)));
    y_noisy = y_clean + noise;
end

function result = run_level2_music_route_local( ...
    y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, el_assumed, az_grid, K_phi, Lc)
    y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_assumed);
    Rfb = level2_fbss_cov_local(y_combined, K_phi);
    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_assumed, el_assumed);
    sub_cache = make_subarray_steer_cache_local(B_grid, K_phi);
    p0 = ceil(sub_cache.P_phi / 2);
    A = sub_cache.A_forward(:, :, p0);
    [V, D] = eig(0.5 * (Rfb + Rfb'));
    [~, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    evals = real(diag(D));
    evals = evals(ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(A) .* (Cn * A), 1));
    spectrum = 1 ./ max(den, eps);
    peaks = find_1d_peaks_local(spectrum, az_grid, Lc);
    result = make_result_local(peaks.az_est, [el_assumed, el_assumed], peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum_1d = spectrum;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.spectrum_width = peaks.spectrum_width;
    result.pair_sep_est = peaks.peak_separation_az;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, result.lambda2_over_noise, ...
        result.lambda2_over_lambda1, result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_bank, K_phi, candidate_pairs)
    cache_map = struct([]);
    for ie = 1:numel(el_bank)
        B = build_level2_combined_az_steer_grid_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_bank(ie), el_bank(ie));
        sub_cache = make_subarray_steer_cache_local(B, K_phi);
        precomp = precompute_rank1_pair_bases_local(sub_cache, candidate_pairs);
        cache_map(ie).el = el_bank(ie);
        cache_map(ie).sub_cache = sub_cache;
        cache_map(ie).precomp = precomp;
    end
end

function result = run_level2_rank1_route_local( ...
    y_noisy_2d, Z3d, lambda, el_assumed, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    [~, idx] = min(abs([cache_map.el] - el_assumed));
    y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, cache_map(idx).el);
    Rfb = level2_fbss_cov_local(y_combined, K_phi);
    result = score_level2_cache_local(Rfb, cache_map(idx), az_grid, theta_true);
    result.el_est = [cache_map(idx).el, cache_map(idx).el];
    result.peak_count = 2;
    result.failure_reason = failure_reason_pair_local(result.az_est, result.el_est, min_sep, max_sep);
end

function result = score_level2_cache_local(Rfb, cache, az_grid, theta_true)
    score = score_rank1_all_local(Rfb, cache.precomp);
    [best_score, best_idx] = min(score);
    score2 = second_score_local(score, best_idx);
    pair_idx = cache.precomp.candidate_pairs(best_idx, :);
    true_precomp = precompute_rank1_pair_bases_local(cache.sub_cache, nearest_pair_indices_local(az_grid, theta_true));
    true_score = score_rank1_all_local(Rfb, true_precomp);
    result = make_result_local(sort(az_grid(pair_idx)), [NaN, NaN], 2, best_score, true_score(1), 'ok');
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est));
end

function result = run_common_el_refocus_power_route_local( ...
    y_noisy_2d, Z3d, lambda, el_grid, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    n = numel(el_grid);
    power_curve = zeros(1, n);
    lambda1_curve = zeros(1, n);
    for ie = 1:n
        y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_grid(ie));
        power_curve(ie) = mean(abs(y_combined(:)).^2);
        Rfb = level2_fbss_cov_local(y_combined, K_phi);
        lambda1_curve(ie) = max(real(eig(0.5 * (Rfb + Rfb'))));
    end
    [~, idx] = max(power_curve);
    el_hat = el_grid(idx);
    result = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, el_hat, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep);
    result.el_hat = el_hat;
    result.el_est = [el_hat, el_hat];
    result.el_common_est = el_hat;
    result.el_selection_method = "focused_power";
    result.focused_power_peak_sharpness = peak_sharpness_local(power_curve);
    result.lambda1_peak_sharpness = peak_sharpness_local(lambda1_curve);
    result.rank1_objective_valley_width_el = NaN;
    result.rank1_objective_selected_el_rank = NaN;
    result.power_curve = power_curve;
    result.lambda1_curve = lambda1_curve;
    result.el_grid = el_grid;
end

function sharpness = peak_sharpness_local(curve)
    curve = real(curve(:));
    [mx, idx] = max(curve);
    tmp = curve;
    tmp(idx) = -inf;
    second = max(tmp);
    sharpness = (mx - second) / max(abs(mx), eps);
end

function y_combined = combine_layers_level2_local(y_2d, Z3d, lambda, el_assumed_deg)
    Nel = size(y_2d, 2);
    z_col = Z3d(1, :).';
    steer_el = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    W = steer_el' / sqrt(Nel);
    tmp = W * reshape(permute(y_2d, [2, 1, 3]), Nel, []);
    y_combined = reshape(tmp, size(y_2d, 1), size(y_2d, 3));
end

function Rfb = level2_fbss_cov_local(y_combined, K_phi)
    Rxx = y_combined * y_combined' / size(y_combined, 2);
    Rxx = 0.5 * (Rxx + Rxx');
    Rfb = mssp_array_fb(Rxx, K_phi);
    Rfb = 0.5 * (Rfb + Rfb');
end

function b = build_level2_combined_az_steer_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg, el_assumed_deg)
    Nel = size(X3d, 2);
    a_norm = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg);
    z_col = Z3d(1, :).';
    a_z = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    w_z = a_z / sqrt(Nel);
    b = (w_z' * a_norm.').';
    b = b / max(norm(b), eps);
end

function B_grid = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid, el_scan_deg, el_assumed_deg)
    B_grid = zeros(size(X3d, 1), numel(angle_grid));
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
    for p = 1:P_phi
        A_forward(:, :, p) = normalize_columns_local(B_grid(p:p+K_phi-1, :));
    end
    cache = struct('K_phi', K_phi, 'P_phi', P_phi, 'J', J, 'A_forward', A_forward);
end

function result = run_level3_2d_music_route_local(Rfb, grid_cache, Lc)
    [V, D] = eig(0.5 * (Rfb + Rfb'));
    [~, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    evals = real(diag(D));
    evals = evals(ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(grid_cache.A_center) .* (Cn * grid_cache.A_center), 1));
    P = reshape(1 ./ max(den, eps), numel(grid_cache.az_grid), numel(grid_cache.el_grid));
    peaks = find_2d_peaks_local(P, grid_cache.az_grid, grid_cache.el_grid, Lc);
    result = make_result_local(peaks.az_est, peaks.el_est, peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum = P;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_separation_el = peaks.peak_separation_el;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.global_peak_el = peaks.global_peak_el;
    result.two_peak_flag = peaks.two_peak_flag;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, result.lambda2_over_noise, ...
        result.lambda2_over_lambda1, result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function Rfb = level3_fbss_cov_from_observation_local(y_2d, K_phi, K_z)
    [Q, Nel, T_snap] = size(y_2d);
    P_phi = Q - K_phi + 1;
    P_z = Nel - K_z + 1;
    K = K_phi * K_z;
    Rf = complex(zeros(K, K));
    for p = 1:P_phi
        for r = 1:P_z
            Y = reshape(y_2d(p:p+K_phi-1, r:r+K_z-1, :), K, T_snap);
            Rf = Rf + (Y * Y') / T_snap;
        end
    end
    Rf = Rf / (P_phi * P_z);
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Rfb = 0.5 * (Rf + J * conj(Rf) * J);
    Rfb = 0.5 * (Rfb + Rfb');
end

function Rfb = level3_fbss_cov_selected_from_observation_local(y_2d, K_phi, K_z, p_sel, r_sel)
    T_snap = size(y_2d, 3);
    K = K_phi * K_z;
    Rf = complex(zeros(K, K));
    count = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            p = p_sel(ip);
            r = r_sel(ir);
            Y = reshape(y_2d(p:p+K_phi-1, r:r+K_z-1, :), K, T_snap);
            Rf = Rf + (Y * Y') / T_snap;
            count = count + 1;
        end
    end
    Rf = Rf / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Rfb = 0.5 * (Rf + J * conj(Rf) * J);
    Rfb = 0.5 * (Rfb + Rfb');
end

function result = run_level3_pair_el_local_rank1_covfit_local( ...
    Rfb, music_result, X3d, Y3d, Z3d, A_ref_2d, lambda, K_phi, K_z, p_sel, r_sel, theta_true, el_true, min_sep, max_sep)
    if any(~isfinite(music_result.az_est)) || music_result.peak_count < 2
        result = make_result_local([NaN, NaN], [NaN, NaN], music_result.peak_count, NaN, NaN, 'no_2d_peaks');
        return
    end
    candidates = make_pair_el_local_candidates_local(music_result.az_est, music_result.el_est, min_sep, max_sep);
    scores = zeros(size(candidates, 1), 1);
    for ic = 1:size(candidates, 1)
        G = build_level3_rank1_model_fbss_selected_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, candidates(ic, 1:2), candidates(ic, 3:4), ...
            1, 0, K_phi, K_z, p_sel, r_sel);
        scores(ic) = solve_covfit_score_local(Rfb, G);
    end
    [best_score, best_idx] = min(scores);
    score2 = second_score_local(scores, best_idx);
    true_idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true);
    true_score = scores(true_idx);
    best = candidates(best_idx, :);
    result = make_result_local(sort(best(1:2)), best(3:4), 2, best_score, true_score, 'ok');
    [result.az_est, order] = sort(best(1:2));
    result.el_est = best(2 + order);
    result.objective_true_rank = 1 + sum(scores < true_score);
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est)) && all(isfinite(result.el_est));
    result.pair_local_confidence_proxy = result.score_gap_ratio / max(1 + result.residual_norm, eps);
end

function Gfb = build_level3_rank1_model_fbss_selected_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair, el_pair, beta, phi_deg, K_phi, K_z, p_sel, r_sel)
    A1 = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(1), el_pair(1));
    A2 = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(2), el_pair(2));
    q = beta * exp(1j * deg2rad(phi_deg));
    K = K_phi * K_z;
    G = complex(zeros(K, K));
    count = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            p = p_sel(ip);
            r = r_sel(ir);
            a1 = A1(p:p+K_phi-1, r:r+K_z-1);
            a2 = A2(p:p+K_phi-1, r:r+K_z-1);
            c = a1(:) / max(norm(a1(:)), eps) + q * a2(:) / max(norm(a2(:)), eps);
            G = G + c * c';
            count = count + 1;
        end
    end
    G = G / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Gfb = 0.5 * (G + J * conj(G) * J);
    Gfb = 0.5 * (Gfb + Gfb');
end

function grid_cache = make_level3_grid_cache_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_grid, K_phi, K_z)
    p0 = floor((size(X3d, 1) - K_phi) / 2) + 1;
    r0 = floor((size(X3d, 2) - K_z) / 2) + 1;
    K = K_phi * K_z;
    A = complex(zeros(K, numel(az_grid) * numel(el_grid)));
    idx = 0;
    for ie = 1:numel(el_grid)
        for ia = 1:numel(az_grid)
            idx = idx + 1;
            Afull = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid(ia), el_grid(ie));
            sub = Afull(p0:p0+K_phi-1, r0:r0+K_z-1);
            A(:, idx) = sub(:) / max(norm(sub(:)), eps);
        end
    end
    grid_cache = struct('az_grid', az_grid, 'el_grid', el_grid, 'K_phi', K_phi, 'K_z', K_z, 'A_center', A);
end

function [p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi, K_z)
    p_all = 1:(Q - K_phi + 1);
    r_all = 1:(Nel - K_z + 1);
    p_sel = unique(round(linspace(1, numel(p_all), 7)));
    r_sel = unique(round(linspace(1, numel(r_all), 5)));
    p_sel = p_all(p_sel);
    r_sel = r_all(r_sel);
end

function candidates = make_pair_el_local_candidates_local(az_est, el_est, min_sep, max_sep)
    az1 = az_est(1) + [-0.04, 0, 0.04];
    az2 = az_est(2) + [-0.04, 0, 0.04];
    el1 = el_est(1) + [-0.5, 0, 0.5];
    el2 = el_est(2) + [-0.5, 0, 0.5];
    candidates = zeros(numel(az1)*numel(az2)*numel(el1)*numel(el2), 4);
    count = 0;
    for i1 = 1:numel(az1)
        for i2 = 1:numel(az2)
            th = sort([az1(i1), az2(i2)]);
            sep = diff(th);
            if sep < min_sep || sep > max_sep
                continue
            end
            for e1 = 1:numel(el1)
                for e2 = 1:numel(el2)
                    count = count + 1;
                    candidates(count, :) = [th, el1(e1), el2(e2)];
                end
            end
        end
    end
    candidates = candidates(1:count, :);
end

function idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true)
    truth = [theta_true(:).', el_true(:).'];
    d = sum((candidates - truth).^2, 2);
    [~, idx] = min(d);
end

function peaks = find_2d_peaks_local(P, az_axis, el_axis, Lc)
    Pwork = real(P);
    mask = false(size(Pwork));
    for ia = 2:size(Pwork, 1)-1
        for ie = 2:size(Pwork, 2)-1
            win = Pwork(ia-1:ia+1, ie-1:ie+1);
            mask(ia, ie) = Pwork(ia, ie) == max(win(:)) && Pwork(ia, ie) > median(win(:));
        end
    end
    idx = find(mask);
    vals = Pwork(idx);
    [~, ord] = sort(vals, 'descend');
    idx = idx(ord);
    peak_count = numel(idx);
    az_est = nan(1, Lc);
    el_est = nan(1, Lc);
    if peak_count >= Lc
        [ia, ie] = ind2sub(size(Pwork), idx(1:Lc));
        az_est = az_axis(ia);
        el_est = el_axis(ie);
        [az_est, order] = sort(az_est);
        el_est = el_est(order);
        reason = 'ok';
    else
        reason = 'peak_count_lt_2';
    end
    peak_vals = vals(:).';
    if numel(peak_vals) >= 2
        peak_prominence_ratio = peak_vals(2) / max(peak_vals(1), eps);
    else
        peak_prominence_ratio = 0;
    end
    if numel(az_est) >= 2 && all(isfinite(az_est))
        peak_separation_az = diff(sort(az_est));
        peak_separation_el = abs(diff(el_est));
        two_peak_flag = true;
    else
        peak_separation_az = NaN;
        peak_separation_el = NaN;
        two_peak_flag = false;
    end
    if isempty(idx)
        global_peak_el = NaN;
    else
        [~, ie0] = ind2sub(size(Pwork), idx(1));
        global_peak_el = el_axis(ie0);
    end
    peaks = struct('az_est', az_est, 'el_est', el_est, 'peak_count', peak_count, ...
        'failure_reason', reason, 'peak_separation_az', peak_separation_az, ...
        'peak_separation_el', peak_separation_el, 'peak_prominence_ratio', peak_prominence_ratio, ...
        'global_peak_el', global_peak_el, 'two_peak_flag', two_peak_flag);
end

function peaks = find_1d_peaks_local(P, az_axis, Lc)
    Pwork = real(P(:)).';
    idx = [];
    for ii = 2:numel(Pwork)-1
        if Pwork(ii) >= Pwork(ii-1) && Pwork(ii) >= Pwork(ii+1) && Pwork(ii) > median(Pwork)
            idx(end+1) = ii; %#ok<AGROW>
        end
    end
    if isempty(idx)
        [~, imax] = max(Pwork);
        idx = imax;
    end
    [~, ord] = sort(Pwork(idx), 'descend');
    idx = idx(ord);
    peak_count = numel(idx);
    az_est = nan(1, Lc);
    if peak_count >= Lc
        az_est = sort(az_axis(idx(1:Lc)));
        reason = 'ok';
    else
        reason = 'peak_count_lt_2';
    end
    peak_vals = Pwork(idx);
    if numel(peak_vals) >= 2
        peak_prominence_ratio = peak_vals(2) / max(peak_vals(1), eps);
    else
        peak_prominence_ratio = 0;
    end
    if numel(az_est) >= 2 && all(isfinite(az_est))
        peak_separation_az = diff(sort(az_est));
    else
        peak_separation_az = NaN;
    end
    mask = Pwork >= 0.5 * max(Pwork);
    if any(mask)
        spectrum_width = az_axis(find(mask, 1, 'last')) - az_axis(find(mask, 1, 'first'));
    else
        spectrum_width = NaN;
    end
    peaks = struct('az_est', az_est, 'peak_count', peak_count, 'failure_reason', reason, ...
        'peak_separation_az', peak_separation_az, 'peak_prominence_ratio', peak_prominence_ratio, ...
        'spectrum_width', spectrum_width);
end

function score2 = second_score_local(score, best_idx)
    if isempty(score)
        score2 = NaN;
        return
    end
    mask = true(size(score));
    mask(best_idx) = false;
    if any(mask)
        score2 = min(score(mask));
    else
        score2 = score(best_idx);
    end
end

function [lambda1, lambda2, lambda_noise_mean, lambda2_over_noise, lambda2_over_lambda1, effective_rank_proxy] = eigen_proxy_from_vals_local(evals)
    evals = real(evals(:));
    evals = max(evals, 0);
    if isempty(evals)
        lambda1 = NaN;
        lambda2 = NaN;
        lambda_noise_mean = NaN;
        lambda2_over_noise = NaN;
        lambda2_over_lambda1 = NaN;
        effective_rank_proxy = NaN;
        return
    end
    lambda1 = evals(min(1, numel(evals)));
    lambda2 = evals(min(2, numel(evals)));
    if numel(evals) >= 3
        lambda_noise_mean = mean(evals(3:end));
    else
        lambda_noise_mean = mean(evals);
    end
    lambda2_over_noise = lambda2 / max(lambda_noise_mean, eps);
    lambda2_over_lambda1 = lambda2 / max(lambda1, eps);
    effective_rank_proxy = (sum(evals)^2) / max(sum(evals.^2), eps);
end

function result = apply_observable_dispatch_rule_local(route_map, min_sep, max_sep)
    music = route_map.music;
    rank1 = route_map.rank1_fallback;
    refocus = route_map.common_el_refocus_rank1;
    music2d = route_map.level3_2d_music;
    pair2d = route_map.pair_el_local_covfit;

    music2d_ok = is_music2d_reliable_local(music2d, min_sep, max_sep);
    pair_ok = is_pair_route_reliable_local(pair2d, min_sep, max_sep);
    music_ok = is_level2_music_reliable_local(music, min_sep, max_sep);
    refocus_ok = is_refocus_route_reliable_local(refocus, min_sep, max_sep);
    rank1_ok = is_rank1_route_reliable_local(rank1, min_sep, max_sep);
    route_conflict = has_route_conflict_local(route_map);
    boundary_proxy = is_boundary_unreliable_local(route_map, min_sep, max_sep);

    if music2d_ok && pair_ok
        result = pair2d;
        result.recommended_route = "pair_el_local_covfit";
        if is_pair_route_high_confidence_local(pair2d, music2d, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "ok";
    elseif music2d_ok
        result = music2d;
        result.recommended_route = "level3_2d_music";
        result.confidence_flag = "medium";
        result.failure_reason = "ok";
    elseif music_ok
        result = music;
        result.recommended_route = "level2_music_or_center_real";
        if is_level2_music_high_confidence_local(music, route_map, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        if route_conflict
            result.failure_reason = "route_conflict";
        else
            result.failure_reason = "ok";
        end
    elseif boundary_proxy
        result = make_boundary_result_local(route_map, 'boundary_unreliable', 'low', 'boundary_unreliable', false, false);
    elseif refocus_ok
        result = refocus;
        result.recommended_route = "common_el_refocus_power_rank1";
        if is_refocus_route_high_confidence_local(refocus, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        if route_conflict
            result.failure_reason = "route_conflict";
        else
            result.failure_reason = "ok";
        end
    elseif rank1_ok
        result = rank1;
        result.recommended_route = "level2_rank1_fallback";
        if is_rank1_route_high_confidence_local(rank1, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "music_single_rank1_fallback";
    else
        result = make_boundary_result_local(route_map, 'low_confidence', 'low', 'boundary_unreliable', false, false);
    end
    result.weak_target_boundary_flag = false;
    result.anti_phase_boundary_flag = false;
    result.low_confidence_flag = strcmp(result.confidence_flag, "low") || ...
        any(strcmp(result.recommended_route, ["low_confidence", "boundary_unreliable"]));
end

function ok = is_level2_music_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'peak_separation_az', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    width = getfield_default_local(result, 'spectrum_width', NaN);
    l2n = getfield_default_local(result, 'lambda2_over_noise', NaN);
    ok = result.peak_count >= 2 && all(isfinite(result.az_est)) && isfinite(sep) && ...
        sep >= min_sep && sep <= max_sep && isfinite(prom) && prom >= 0.55 && ...
        (~isfinite(width) || width <= 0.45) && (~isfinite(l2n) || l2n >= 1.10);
end

function ok = is_music2d_reliable_local(result, min_sep, max_sep)
    sep_az = getfield_default_local(result, 'peak_separation_az', NaN);
    sep_el = getfield_default_local(result, 'peak_separation_el', NaN);
    max_el = max(abs(getfield_default_local(result, 'el_est', [NaN, NaN])));
    ok = result.peak_count >= 2 && all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep_az) && isfinite(sep_el) && sep_az >= min_sep && sep_az <= max_sep && ...
        sep_el >= 1.0 && isfinite(max_el) && max_el >= 1.0;
end

function ok = is_rank1_route_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    gap = getfield_default_local(result, 'score_gap_ratio', NaN);
    ok = all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep) && sep >= min_sep && sep <= max_sep && ...
        isfinite(residual) && residual < 2e-3 && isfinite(gap) && gap >= 2e-3;
end

function ok = is_refocus_route_reliable_local(result, min_sep, max_sep)
    sharp = getfield_default_local(result, 'focused_power_peak_sharpness', NaN);
    lambda_sharp = getfield_default_local(result, 'lambda1_peak_sharpness', NaN);
    ok = is_rank1_route_reliable_local(result, min_sep, max_sep) && ...
        isfinite(sharp) && sharp >= 0.03 && isfinite(lambda_sharp) && lambda_sharp >= 0.03;
end

function ok = is_pair_route_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    max_el = max(abs(getfield_default_local(result, 'el_est', [NaN, NaN])));
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    ok = all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep) && sep >= min_sep && sep <= max_sep && ...
        isfinite(residual) && residual < 0.05 && isfinite(max_el) && max_el >= 1.0 && ...
        (~isfinite(prom) || prom >= 0.45);
end

function ok = is_level2_music_high_confidence_local(result, route_map, min_sep, max_sep)
    width = getfield_default_local(result, 'spectrum_width', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    l2n = getfield_default_local(result, 'lambda2_over_noise', NaN);
    l21 = getfield_default_local(result, 'lambda2_over_lambda1', NaN);
    refocus = route_map.common_el_refocus_rank1;
    refocus_gap = getfield_default_local(refocus, 'score_gap_ratio', NaN);
    ok = is_level2_music_reliable_local(result, min_sep, max_sep) && ...
        isfinite(prom) && prom >= 0.82 && (~isfinite(width) || width <= 0.24) && ...
        (~isfinite(l2n) || l2n >= 1.35) && (~isfinite(l21) || l21 >= 0.18) && ...
        (~isfinite(refocus_gap) || refocus_gap >= 2e-3);
end

function ok = is_rank1_route_high_confidence_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    gap = getfield_default_local(result, 'score_gap_ratio', NaN);
    ok = is_rank1_route_reliable_local(result, min_sep, max_sep) && ...
        isfinite(residual) && residual < 7e-4 && isfinite(gap) && gap >= 1e-2 && ...
        ~is_sep_edge_local(sep, min_sep, max_sep, 0.015);
end

function ok = is_refocus_route_high_confidence_local(result, min_sep, max_sep)
    sharp = getfield_default_local(result, 'focused_power_peak_sharpness', NaN);
    lambda_sharp = getfield_default_local(result, 'lambda1_peak_sharpness', NaN);
    ok = is_rank1_route_high_confidence_local(result, min_sep, max_sep) && ...
        isfinite(sharp) && sharp >= 0.09 && isfinite(lambda_sharp) && lambda_sharp >= 0.09;
end

function ok = is_pair_route_high_confidence_local(result, music2d_result, min_sep, max_sep)
    proxy = getfield_default_local(result, 'pair_local_confidence_proxy', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    sep_el = getfield_default_local(music2d_result, 'peak_separation_el', NaN);
    prom = getfield_default_local(music2d_result, 'peak_prominence_ratio', NaN);
    ok = is_pair_route_reliable_local(result, min_sep, max_sep) && ...
        isfinite(proxy) && proxy >= 0.12 && isfinite(residual) && residual < 0.02 && ...
        isfinite(sep_el) && sep_el >= 1.5 && isfinite(prom) && prom >= 0.55;
end

function tf = is_boundary_unreliable_local(route_map, min_sep, max_sep)
    music = route_map.music;
    rank1 = route_map.rank1_fallback;
    refocus = route_map.common_el_refocus_rank1;
    music2d = route_map.level3_2d_music;
    pair2d = route_map.pair_el_local_covfit;

    no_reliable_2d = ~is_music2d_reliable_local(music2d, min_sep, max_sep) && ...
        ~is_pair_route_reliable_local(pair2d, min_sep, max_sep);
    music_single = music.peak_count < 2 || any(~isfinite(music.az_est));
    rank1_finite = all(isfinite(rank1.az_est)) && all(isfinite(rank1.el_est));
    rank1_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    rank1_sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    refocus_sharp = min( ...
        getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    route_conflict = has_route_conflict_local(route_map);
    strong_single_peak = music.peak_count < 2 && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;

    weak_rank1 = (~isfinite(rank1_gap) || rank1_gap < 5e-3) && ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3);
    sep_edge = is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;

    tf = (no_reliable_2d && music_single && rank1_finite && weak_rank1) || ...
        (no_reliable_2d && music_single && rank1_finite && sep_edge) || ...
        (no_reliable_2d && strong_single_peak && refocus_unsharp) || ...
        (no_reliable_2d && route_conflict && ~is_level2_music_reliable_local(music, min_sep, max_sep));
end

function tf = has_route_conflict_local(route_map)
    az_list = {};
    route_fields = {'music', 'rank1_fallback', 'common_el_refocus_rank1', 'level3_2d_music', 'pair_el_local_covfit'};
    for i = 1:numel(route_fields)
        now = route_map.(route_fields{i});
        az_est = getfield_default_local(now, 'az_est', [NaN, NaN]);
        if numel(az_est) >= 2 && all(isfinite(az_est))
            az_list{end+1} = sort(az_est(:)).'; %#ok<AGROW>
        end
    end
    tf = false;
    if numel(az_list) < 2
        return
    end
    for i = 1:numel(az_list)-1
        for j = (i+1):numel(az_list)
            if max(abs(az_list{i} - az_list{j})) > 0.14
                tf = true;
                return
            end
        end
    end
end

function tf = is_sep_edge_local(sep, min_sep, max_sep, edge_margin)
    tf = ~isfinite(sep) || sep <= (min_sep + edge_margin) || sep >= (max_sep - edge_margin);
end

function result = make_boundary_result_local(route_map, route_name, confidence, reason, weak_flag, anti_flag)
    fallback = route_map.music;
    result = make_result_local(fallback.az_est, fallback.el_est, fallback.peak_count, NaN, NaN, reason);
    result.recommended_route = string(route_name);
    result.confidence_flag = string(confidence);
    result.failure_reason = string(reason);
    result.weak_target_boundary_flag = weak_flag;
    result.anti_phase_boundary_flag = anti_flag;
    result.low_confidence_flag = true;
end

function candidate_pairs = make_pair_candidates_local(angle_grid, min_sep, max_sep)
    n = numel(angle_grid);
    candidate_pairs = zeros(n*n, 2);
    count = 0;
    for ii = 1:(n-1)
        sep_vec = angle_grid((ii+1):end) - angle_grid(ii);
        jj_rel = find(sep_vec >= min_sep & sep_vec <= max_sep);
        jj = jj_rel + ii;
        nadd = numel(jj);
        candidate_pairs(count+1:count+nadd, :) = [repmat(ii, nadd, 1), jj(:)];
        count = count + nadd;
    end
    candidate_pairs = candidate_pairs(1:count, :);
end

function pair_idx = nearest_pair_indices_local(grid, theta_pair)
    [~, i1] = min(abs(grid - theta_pair(1)));
    [~, i2] = min(abs(grid - theta_pair(2)));
    pair_idx = sort([i1, i2]);
    if pair_idx(1) == pair_idx(2)
        pair_idx(2) = min(pair_idx(1) + 1, numel(grid));
    end
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
        G = 0.5 * (F + J * conj(F) * J);
        v = matrix_to_realvec_local(G);
        g_basis(:, ic) = single(v);
        gg(ic) = real(v' * v);
        gi(ic) = real(v' * ivec);
    end
    precomp = struct('K_phi', K, 'P_phi', P_phi, 'candidate_pairs', candidate_pairs, ...
        'g_basis', g_basis, 'gg', gg, 'gi', gi, 'ivec', single(ivec), 'ii', ii);
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

function score = solve_covfit_score_local(Robs, G)
    y = matrix_to_realvec_local(Robs);
    g = matrix_to_realvec_local(G);
    ivec = matrix_to_realvec_local(eye(size(Robs)));
    yy = real(y' * y);
    gg = real(g' * g);
    gi = real(g' * ivec);
    ii = real(ivec' * ivec);
    gy = real(g' * y);
    iy = real(ivec' * y);
    detv = gg * ii - gi^2;
    vals = zeros(4, 1);
    if abs(detv) > 1e-12
        alpha = (gy * ii - gi * iy) / detv;
        sigma2 = (gg * iy - gi * gy) / detv;
        if alpha >= 0 && sigma2 >= 0
            vals(1) = -2*(alpha*gy + sigma2*iy) + alpha^2*gg + 2*alpha*sigma2*gi + sigma2^2*ii;
        else
            vals(1) = inf;
        end
    else
        vals(1) = inf;
    end
    alpha_only = max(gy / max(gg, eps), 0);
    vals(2) = -2*alpha_only*gy + alpha_only^2*gg;
    sigma_only = max(iy / max(ii, eps), 0);
    vals(3) = -2*sigma_only*iy + sigma_only^2*ii;
    vals(4) = 0;
    score = max(yy + min(vals), 0) / max(yy, eps);
end

function v = matrix_to_realvec_local(M)
    m = M(:);
    v = [real(m); imag(m)];
end

function A = normalize_columns_local(A)
    nrm = sqrt(sum(abs(A).^2, 1));
    nrm(nrm == 0) = 1;
    A = A ./ nrm;
end

function result = make_result_local(az_est, el_est, peak_count, objective_best, objective_true, reason)
    result = struct();
    result.az_est = az_est;
    result.el_est = el_est;
    result.peak_count = peak_count;
    result.objective_best = objective_best;
    result.objective_true_pair = objective_true;
    result.objective_margin = objective_true - objective_best;
    result.objective_true_rank = NaN;
    result.el_common_est = NaN;
    result.el_hat = NaN;
    result.el_selection_method = "";
    result.focused_power_peak_sharpness = NaN;
    result.lambda1_peak_sharpness = NaN;
    result.rank1_objective_valley_width_el = NaN;
    result.rank1_objective_selected_el_rank = NaN;
    result.failure_reason = reason;
    result.spectrum = [];
    result.spectrum_1d = [];
    result.peak_separation_az = NaN;
    result.peak_separation_el = NaN;
    result.peak_prominence_ratio = NaN;
    result.spectrum_width = NaN;
    result.score_gap_abs = NaN;
    result.score_gap_ratio = NaN;
    result.residual_norm = objective_best;
    result.pair_sep_est = NaN;
    result.finite_output_flag = all(isfinite(az_est)) && all(isfinite(el_est));
    result.two_peak_flag = false;
    result.global_peak_el = NaN;
    result.pair_local_confidence_proxy = NaN;
    result.lambda1 = NaN;
    result.lambda2 = NaN;
    result.lambda_noise_mean = NaN;
    result.lambda2_over_noise = NaN;
    result.lambda2_over_lambda1 = NaN;
    result.effective_rank_proxy = NaN;
    result.recommended_route = "";
    result.confidence_flag = "";
    result.weak_target_boundary_flag = false;
    result.anti_phase_boundary_flag = false;
    result.low_confidence_flag = false;
end

function store = init_route_trial_store_local(route_names, Metkl)
    template = struct('route_name', '', 'raw_success', zeros(Metkl, 1), ...
        'az_success', zeros(Metkl, 1), 'el_success', zeros(Metkl, 1), ...
        'joint_success', zeros(Metkl, 1), 'az_rmse', nan(Metkl, 1), ...
        'el_rmse', nan(Metkl, 1), 'pair_2d_rmse', nan(Metkl, 1), ...
        'peak_count', nan(Metkl, 1), 'degraded', zeros(Metkl, 1), ...
        'objective_true_pair', nan(Metkl, 1), 'objective_best', nan(Metkl, 1), ...
        'objective_margin', nan(Metkl, 1), 'objective_true_rank', nan(Metkl, 1), ...
        'el_common_est', nan(Metkl, 1), 'el_hat', nan(Metkl, 1), ...
        'focused_power_peak_sharpness', nan(Metkl, 1), 'lambda1_peak_sharpness', nan(Metkl, 1), ...
        'rank1_objective_valley_width_el', nan(Metkl, 1), ...
        'rank1_objective_selected_el_rank', nan(Metkl, 1), ...
        'el_selection_method', strings(Metkl, 1), 'failure_reason', strings(Metkl, 1), ...
        'recommended_route', strings(Metkl, 1), 'confidence_flag', strings(Metkl, 1), ...
        'weak_target_boundary_flag', false(Metkl, 1), ...
        'anti_phase_boundary_flag', false(Metkl, 1), ...
        'low_confidence_flag', false(Metkl, 1));
    store = repmat(template, numel(route_names), 1);
    for ir = 1:numel(route_names)
        store(ir).route_name = route_names{ir};
    end
end

function store = store_route_trial_local(store, ir, imc, result, theta_true, el_true, az_tol, el_tol)
    [az_err, el_err, pair_rmse] = pair_errors_local(result.az_est, result.el_est, theta_true, el_true);
    store(ir).az_rmse(imc) = sqrt(mean(az_err.^2, 'omitnan'));
    store(ir).el_rmse(imc) = sqrt(mean(el_err.^2, 'omitnan'));
    store(ir).pair_2d_rmse(imc) = pair_rmse;
    store(ir).az_success(imc) = all(abs(az_err) <= az_tol);
    store(ir).el_success(imc) = all(abs(el_err) <= el_tol);
    store(ir).joint_success(imc) = store(ir).az_success(imc) && store(ir).el_success(imc);
    store(ir).raw_success(imc) = all(isfinite(result.az_est)) && numel(result.az_est) == 2;
    store(ir).peak_count(imc) = result.peak_count;
    store(ir).degraded(imc) = ~store(ir).joint_success(imc);
    store(ir).objective_true_pair(imc) = result.objective_true_pair;
    store(ir).objective_best(imc) = result.objective_best;
    store(ir).objective_margin(imc) = result.objective_margin;
    store(ir).objective_true_rank(imc) = result.objective_true_rank;
    store(ir).el_common_est(imc) = result.el_common_est;
    store(ir).el_hat(imc) = getfield_default_local(result, 'el_hat', NaN);
    store(ir).focused_power_peak_sharpness(imc) = getfield_default_local(result, 'focused_power_peak_sharpness', NaN);
    store(ir).lambda1_peak_sharpness(imc) = getfield_default_local(result, 'lambda1_peak_sharpness', NaN);
    store(ir).rank1_objective_valley_width_el(imc) = getfield_default_local(result, 'rank1_objective_valley_width_el', NaN);
    store(ir).rank1_objective_selected_el_rank(imc) = getfield_default_local(result, 'rank1_objective_selected_el_rank', NaN);
    store(ir).el_selection_method(imc) = string(getfield_default_local(result, 'el_selection_method', ""));
    store(ir).failure_reason(imc) = string(result.failure_reason);
    store(ir).recommended_route(imc) = string(getfield_default_local(result, 'recommended_route', ""));
    store(ir).confidence_flag(imc) = string(getfield_default_local(result, 'confidence_flag', ""));
    store(ir).weak_target_boundary_flag(imc) = logical(getfield_default_local(result, 'weak_target_boundary_flag', false));
    store(ir).anti_phase_boundary_flag(imc) = logical(getfield_default_local(result, 'anti_phase_boundary_flag', false));
    store(ir).low_confidence_flag(imc) = logical(getfield_default_local(result, 'low_confidence_flag', false));
end

function store = init_dispatch_compare_store_local(Metkl)
    store = struct( ...
        'oracle_route', strings(Metkl, 1), ...
        'observable_route', strings(Metkl, 1), ...
        'observable_confidence', strings(Metkl, 1), ...
        'observable_failure_reason', strings(Metkl, 1), ...
        'oracle_success', zeros(Metkl, 1), ...
        'observable_success', zeros(Metkl, 1), ...
        'route_agreement', zeros(Metkl, 1), ...
        'low_confidence', zeros(Metkl, 1), ...
        'boundary_unreliable', zeros(Metkl, 1), ...
        'false_high_confidence', zeros(Metkl, 1), ...
        'false_medium_high_confidence', zeros(Metkl, 1), ...
        'boundary_missed', zeros(Metkl, 1));
end

function store = store_dispatch_compare_trial_local(store, imc, oracle_result, observable_result, theta_true, el_true, az_tol, el_tol)
    oracle_success = joint_success_from_result_local(oracle_result, theta_true, el_true, az_tol, el_tol);
    observable_success = joint_success_from_result_local(observable_result, theta_true, el_true, az_tol, el_tol);
    oracle_route = string(getfield_default_local(oracle_result, 'recommended_route', ""));
    observable_route = string(getfield_default_local(observable_result, 'recommended_route', ""));
    conf = string(getfield_default_local(observable_result, 'confidence_flag', ""));
    fail_reason = string(getfield_default_local(observable_result, 'failure_reason', ""));
    oracle_boundary = any(strcmp(oracle_route, ["weak_target_boundary", "anti_phase_boundary", "low_confidence"]));
    observable_normal_high = strcmp(conf, "high") && ...
        ~any(strcmp(observable_route, ["low_confidence", "boundary_unreliable"]));

    store.oracle_route(imc) = oracle_route;
    store.observable_route(imc) = observable_route;
    store.observable_confidence(imc) = conf;
    store.observable_failure_reason(imc) = fail_reason;
    store.oracle_success(imc) = oracle_success;
    store.observable_success(imc) = observable_success;
    store.route_agreement(imc) = strcmp(oracle_route, observable_route);
    store.low_confidence(imc) = strcmp(conf, "low") || ...
        any(strcmp(observable_route, ["low_confidence", "boundary_unreliable"]));
    store.boundary_unreliable(imc) = strcmp(observable_route, "boundary_unreliable");
    store.false_high_confidence(imc) = strcmp(conf, "high") && ~observable_success;
    store.false_medium_high_confidence(imc) = any(strcmp(conf, ["high", "medium"])) && ~observable_success;
    store.boundary_missed(imc) = oracle_boundary && observable_normal_high && ~observable_success;
end

function metrics = summarize_dispatch_compare_local(store)
    metrics = struct();
    metrics.oracle_dispatch_route = mode_string_local_nonempty(store.oracle_route);
    metrics.observable_dispatch_route = mode_string_local_nonempty(store.observable_route);
    metrics.route_agreement_rate = mean(store.route_agreement);
    metrics.oracle_dispatch_success_rate = mean(store.oracle_success);
    metrics.observable_dispatch_success_rate = mean(store.observable_success);
    metrics.observable_vs_oracle_success_gap = metrics.observable_dispatch_success_rate - metrics.oracle_dispatch_success_rate;
    metrics.low_confidence_rate = mean(store.low_confidence);
    metrics.boundary_unreliable_rate = mean(store.boundary_unreliable);
    metrics.false_high_confidence_rate = mean(store.false_high_confidence);
    metrics.false_medium_high_confidence_rate = mean(store.false_medium_high_confidence);
    metrics.boundary_missed_rate = mean(store.boundary_missed);
    metrics.route_used_distribution = distribution_string_local(store.observable_route);
    metrics.confidence_flag_distribution = distribution_string_local(store.observable_confidence);
    metrics.main_failure_reason = mode_string_local_nonempty(store.observable_failure_reason(store.observable_success == 0));
end

function [az_err, el_err, pair_rmse] = pair_errors_local(az_est, el_est, az_true, el_true)
    az_est = az_est(:).';
    el_est = el_est(:).';
    if numel(az_est) < 2 || any(~isfinite(az_est)) || any(~isfinite(el_est))
        az_err = [NaN, NaN];
        el_err = [NaN, NaN];
        pair_rmse = NaN;
        return
    end
    est = [az_est(:), el_est(:)];
    truth = [az_true(:), el_true(:)];
    d11 = norm(est(1, :) - truth(1, :)) + norm(est(2, :) - truth(2, :));
    d12 = norm(est(1, :) - truth(2, :)) + norm(est(2, :) - truth(1, :));
    if d12 < d11
        truth = flipud(truth);
    end
    az_err = est(:, 1).' - truth(:, 1).';
    el_err = est(:, 2).' - truth(:, 2).';
    pair_rmse = sqrt(mean(sum((est - truth).^2, 2)));
end

function metrics = summarize_route_trials_local(store)
    metrics = struct();
    metrics.raw_success_rate = mean(store.raw_success);
    metrics.az_tol_success_rate_abs01 = mean(store.az_success);
    metrics.el_tol_success_rate_abs05 = mean(store.el_success);
    metrics.joint_tol_success_rate = mean(store.joint_success);
    metrics.az_rmse_deg = mean(store.az_rmse, 'omitnan');
    metrics.el_rmse_deg = mean(store.el_rmse, 'omitnan');
    metrics.pair_2d_rmse = mean(store.pair_2d_rmse, 'omitnan');
    metrics.peak_count_mean = mean(store.peak_count, 'omitnan');
    metrics.degraded_rate = mean(store.degraded);
    metrics.objective_true_pair = mean(store.objective_true_pair, 'omitnan');
    metrics.objective_best = mean(store.objective_best, 'omitnan');
    metrics.objective_margin = mean(store.objective_margin, 'omitnan');
    metrics.objective_true_rank_median = median(store.objective_true_rank, 'omitnan');
    metrics.el_common_est_mean = mean(store.el_common_est, 'omitnan');
    metrics.el_hat_mean = mean(store.el_hat, 'omitnan');
    metrics.el_hat_error_mean = mean(store.el_hat, 'omitnan');
    metrics.el_hat_error_abs_mean = mean(abs(store.el_hat), 'omitnan');
    metrics.el_common_est_error = metrics.el_hat_error_mean;
    metrics.focused_power_peak_sharpness = mean(store.focused_power_peak_sharpness, 'omitnan');
    metrics.lambda1_peak_sharpness = mean(store.lambda1_peak_sharpness, 'omitnan');
    metrics.rank1_objective_valley_width_el = mean(store.rank1_objective_valley_width_el, 'omitnan');
    metrics.rank1_objective_selected_el_rank = median(store.rank1_objective_selected_el_rank, 'omitnan');
    method_vals = store.el_selection_method(store.el_selection_method ~= "");
    if isempty(method_vals)
        metrics.el_selection_method = "";
    else
        metrics.el_selection_method = method_vals(1);
    end
    if metrics.joint_tol_success_rate >= 0.8
        metrics.route_failure_reason = 'ok';
    elseif metrics.raw_success_rate < 0.8
        metrics.route_failure_reason = 'insufficient_peak_or_pair';
    elseif metrics.az_tol_success_rate_abs01 < 0.8
        metrics.route_failure_reason = 'az_error';
    elseif metrics.el_tol_success_rate_abs05 < 0.8
        metrics.route_failure_reason = 'el_error';
    else
        metrics.route_failure_reason = 'joint_boundary';
    end
    rec_vals = store.recommended_route(store.recommended_route ~= "");
    if isempty(rec_vals)
        metrics.recommended_route = "";
    else
        metrics.recommended_route = mode_string_local(rec_vals);
    end
    conf_vals = store.confidence_flag(store.confidence_flag ~= "");
    if isempty(conf_vals)
        metrics.confidence_flag = "";
    else
        metrics.confidence_flag = mode_string_local(conf_vals);
    end
    metrics.recommended_route_success_rate = mean(store.joint_success);
    metrics.weak_target_boundary_rate = mean(store.weak_target_boundary_flag);
    metrics.anti_phase_boundary_rate = mean(store.anti_phase_boundary_flag);
    metrics.low_confidence_rate = mean(store.low_confidence_flag);
end

function row = make_summary_row_local(sc, route_name, metrics, compare_metrics)
    row = {sc.stage, sc.group, sc.case_name, sc.el_b, sc.el_diff, sc.el_mismatch, ...
        sc.beta, sc.phi_deg, sc.rho, sc.weak_target_flag, sc.anti_phase_flag, ...
        sc.large_el_flag, sc.common_el_flag, sc.snr_db, route_name, ...
        metrics.raw_success_rate, metrics.az_tol_success_rate_abs01, metrics.el_tol_success_rate_abs05, ...
        metrics.joint_tol_success_rate, metrics.az_rmse_deg, metrics.el_rmse_deg, metrics.pair_2d_rmse, ...
        metrics.peak_count_mean, metrics.degraded_rate, string(metrics.route_failure_reason), ...
        metrics.objective_true_pair, metrics.objective_best, metrics.objective_margin, ...
        metrics.objective_true_rank_median, metrics.el_hat_mean, metrics.el_hat_error_mean, ...
        metrics.el_hat_error_abs_mean, metrics.focused_power_peak_sharpness, ...
        metrics.lambda1_peak_sharpness, metrics.rank1_objective_valley_width_el, ...
        metrics.rank1_objective_selected_el_rank, string(metrics.el_selection_method), ...
        metrics.el_common_est_mean, metrics.el_common_est_error, ...
        string(metrics.recommended_route), string(metrics.confidence_flag), ...
        metrics.recommended_route_success_rate, metrics.weak_target_boundary_rate, ...
        metrics.anti_phase_boundary_rate, metrics.low_confidence_rate, ...
        string(compare_metrics.oracle_dispatch_route), string(compare_metrics.observable_dispatch_route), ...
        compare_metrics.route_agreement_rate, compare_metrics.oracle_dispatch_success_rate, ...
        compare_metrics.observable_dispatch_success_rate, compare_metrics.observable_vs_oracle_success_gap, ...
        compare_metrics.low_confidence_rate, compare_metrics.boundary_unreliable_rate, ...
        compare_metrics.false_high_confidence_rate, ...
        compare_metrics.false_medium_high_confidence_rate, compare_metrics.boundary_missed_rate, ...
        string(compare_metrics.route_used_distribution), string(compare_metrics.confidence_flag_distribution), ...
        string(compare_metrics.main_failure_reason)};
end

function names = summary_var_names_local()
    names = {'stage', 'group', 'case_name', 'el_b_deg', 'el_diff_deg', 'el_mismatch_deg', ...
        'beta', 'phi_deg', 'rho', 'weak_target_truth_flag', 'anti_phase_truth_flag', ...
        'large_el_truth_flag', 'common_el_truth_flag', 'snr_db', 'route_name', ...
        'raw_success_rate', 'az_tol_success_rate_abs01', 'el_tol_success_rate_abs05', ...
        'joint_tol_success_rate', 'az_rmse_deg', 'el_rmse_deg', 'pair_2d_rmse', ...
        'peak_count_mean', 'degraded_rate', 'route_failure_reason', ...
        'mean_objective_true_pair', 'mean_objective_best', 'objective_margin', ...
        'objective_true_rank_median', 'el_hat_mean', 'el_hat_error_mean', ...
        'el_hat_error_abs_mean', 'focused_power_peak_sharpness', ...
        'lambda1_peak_sharpness', 'rank1_objective_valley_width_el', ...
        'rank1_objective_selected_el_rank', 'el_selection_method', ...
        'el_common_est_mean', 'el_common_est_error', ...
        'recommended_route', 'confidence_flag', 'recommended_route_success_rate', ...
        'weak_target_boundary_rate', 'anti_phase_boundary_rate', 'low_confidence_rate', ...
        'oracle_dispatch_route', 'observable_dispatch_route', 'route_agreement_rate', ...
        'oracle_dispatch_success_rate', 'observable_dispatch_success_rate', ...
        'observable_vs_oracle_success_gap', 'dispatch_low_confidence_rate', 'boundary_unreliable_rate', ...
        'false_high_confidence_rate', 'false_medium_high_confidence_rate', ...
        'boundary_missed_rate', 'route_used_distribution', 'confidence_flag_distribution', ...
        'main_failure_reason'};
end

function s = mode_string_local(vals)
    u = unique(vals);
    counts = zeros(numel(u), 1);
    for i = 1:numel(u)
        counts(i) = sum(vals == u(i));
    end
    [~, idx] = max(counts);
    s = u(idx);
end

function s = mode_string_local_nonempty(vals)
    vals = vals(vals ~= "");
    if isempty(vals)
        s = "";
    else
        s = mode_string_local(vals);
    end
end

function txt = distribution_string_local(vals)
    vals = vals(vals ~= "");
    if isempty(vals)
        txt = "";
        return
    end
    u = unique(vals, 'stable');
    parts = strings(numel(u), 1);
    n = numel(vals);
    for i = 1:numel(u)
        parts(i) = sprintf('%s:%.3f', u(i), sum(vals == u(i)) / n);
    end
    txt = strjoin(cellstr(parts), ';');
end

function ok = joint_success_from_result_local(result, theta_true, el_true, az_tol, el_tol)
    [az_err, el_err] = pair_errors_local(result.az_est, result.el_est, theta_true, el_true);
    ok = all(abs(az_err) <= az_tol) && all(abs(el_err) <= el_tol);
    ok = ok && all(isfinite(az_err)) && all(isfinite(el_err));
end

function val = getfield_default_local(s, name, default_val)
    if isfield(s, name)
        val = s.(name);
    else
        val = default_val;
    end
end

function keypoints = build_keypoints_local(summary_tbl, orig_keypoints_tbl)
    kp = {};
    Obs = summary_tbl(strcmp(summary_tbl.route_name, 'observable_dispatch'), :);
    Ora = summary_tbl(strcmp(summary_tbl.route_name, 'oracle_label_dispatch'), :);
    refocus_rows = summary_tbl(strcmp(summary_tbl.route_name, 'common_el_refocus_power_rank1'), :);
    kp(end+1, :) = {'oracle_dispatch_success_all', mean(Ora.joint_tol_success_rate, 'omitnan'), 'oracle-label dispatch mean joint success'}; %#ok<AGROW>
    kp(end+1, :) = {'observable_dispatch_success_all', mean(Obs.joint_tol_success_rate, 'omitnan'), 'observable dispatch mean joint success'}; %#ok<AGROW>
    kp(end+1, :) = {'observable_vs_oracle_gap_all', mean(Obs.observable_vs_oracle_success_gap, 'omitnan'), 'observable minus oracle success gap'}; %#ok<AGROW>
    kp(end+1, :) = {'route_agreement_rate_all', mean(Obs.route_agreement_rate, 'omitnan'), 'observable and oracle route agreement'}; %#ok<AGROW>
    kp(end+1, :) = {'low_confidence_rate_all', mean(Obs.dispatch_low_confidence_rate, 'omitnan'), 'observable low-confidence rate'}; %#ok<AGROW>
    kp(end+1, :) = {'boundary_unreliable_rate_all', mean(Obs.boundary_unreliable_rate, 'omitnan'), 'observable boundary-unreliable rate'}; %#ok<AGROW>
    kp(end+1, :) = {'false_high_confidence_rate_all', mean(Obs.false_high_confidence_rate, 'omitnan'), 'observable false high-confidence rate'}; %#ok<AGROW>
    kp(end+1, :) = {'false_medium_high_confidence_rate_all', mean(Obs.false_medium_high_confidence_rate, 'omitnan'), 'observable false medium/high-confidence rate'}; %#ok<AGROW>
    kp(end+1, :) = {'boundary_missed_rate_all', mean(Obs.boundary_missed_rate, 'omitnan'), 'observable missed-boundary rate'}; %#ok<AGROW>
    kp(end+1, :) = {'rho_scan_observable_success', group_route_mean_local(Obs, 'rho_scan', 'joint_tol_success_rate'), 'observable success on rho scan'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_scan_observable_success', group_route_mean_local(Obs, 'beta_scan', 'joint_tol_success_rate'), 'observable success on beta scan'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_scan_observable_success', group_route_mean_local(Obs, 'phase_scan', 'joint_tol_success_rate'), 'observable success on phase scan'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_observable_success', group_route_mean_local(Obs, 'large_el', 'joint_tol_success_rate'), 'observable success on large-el cases'}; %#ok<AGROW>
    kp(end+1, :) = {'rho_scan_false_high', group_route_mean_local(Obs, 'rho_scan', 'false_high_confidence_rate'), 'false-high rate on rho scan'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_scan_false_high', group_route_mean_local(Obs, 'beta_scan', 'false_high_confidence_rate'), 'false-high rate on beta scan'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_scan_false_high', group_route_mean_local(Obs, 'phase_scan', 'false_high_confidence_rate'), 'false-high rate on phase scan'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_false_high', group_route_mean_local(Obs, 'large_el', 'false_high_confidence_rate'), 'false-high rate on large-el cases'}; %#ok<AGROW>
    kp(end+1, :) = {'rho_scan_boundary_missed', group_route_mean_local(Obs, 'rho_scan', 'boundary_missed_rate'), 'boundary-missed rate on rho scan'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_scan_boundary_missed', group_route_mean_local(Obs, 'beta_scan', 'boundary_missed_rate'), 'boundary-missed rate on beta scan'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_scan_boundary_missed', group_route_mean_local(Obs, 'phase_scan', 'boundary_missed_rate'), 'boundary-missed rate on phase scan'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_boundary_missed', group_route_mean_local(Obs, 'large_el', 'boundary_missed_rate'), 'boundary-missed rate on large-el cases'}; %#ok<AGROW>
    kp(end+1, :) = {'beta03_low_confidence_rate', case_mean_local(Obs, 'beta_0.3', 'dispatch_low_confidence_rate'), 'low-confidence rate at beta=0.3'}; %#ok<AGROW>
    kp(end+1, :) = {'phase150_low_confidence_rate', case_mean_local(Obs, 'phase_150', 'dispatch_low_confidence_rate'), 'low-confidence rate at phase=150'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_caseB_observable_success', case_mean_local(Obs, 'B_el5_beta1_phase0_rho1', 'joint_tol_success_rate'), 'observable success on clean large-el case'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_caseF_observable_success', case_mean_local(Obs, 'F_el10_beta05_phase180_rho07', 'joint_tol_success_rate'), 'observable success on hardest representative case'}; %#ok<AGROW>
    kp(end+1, :) = {'refocus_computed_all_scenarios_flag', double(height(refocus_rows) == height(Obs)), 'common-el refocus route computed for every scenario-SNR case'}; %#ok<AGROW>
    kp(end+1, :) = {'num_cases_refocus_available', height(refocus_rows), 'scenario-SNR cases with computed common-el refocus output'}; %#ok<AGROW>
    kp(end+1, :) = {'num_cases_refocus_selected', sum(strcmp(Obs.observable_dispatch_route, 'common_el_refocus_power_rank1')), 'scenario-SNR cases whose observable dispatch selected common-el refocus'}; %#ok<AGROW>

    if ~isempty(orig_keypoints_tbl)
        orig_obs = keypoint_value_local(orig_keypoints_tbl, 'observable_dispatch_success_all');
        orig_gap = keypoint_value_local(orig_keypoints_tbl, 'observable_vs_oracle_gap_all');
        orig_route_agree = keypoint_value_local(orig_keypoints_tbl, 'route_agreement_rate_all');
        orig_low = keypoint_value_local(orig_keypoints_tbl, 'low_confidence_rate_all');
        orig_false_high = keypoint_value_local(orig_keypoints_tbl, 'false_high_confidence_rate_all');
        orig_boundary_missed = keypoint_value_local(orig_keypoints_tbl, 'boundary_missed_rate_all');

        new_obs = mean(Obs.joint_tol_success_rate, 'omitnan');
        new_gap = mean(Obs.observable_vs_oracle_success_gap, 'omitnan');
        new_low = mean(Obs.dispatch_low_confidence_rate, 'omitnan');
        new_false_high = mean(Obs.false_high_confidence_rate, 'omitnan');
        new_boundary_missed = mean(Obs.boundary_missed_rate, 'omitnan');

        kp(end+1, :) = {'orig_observable_dispatch_success_all', orig_obs, 'part-6 observable dispatch success'}; %#ok<AGROW>
        kp(end+1, :) = {'orig_observable_vs_oracle_gap_all', orig_gap, 'part-6 observable-oracle gap'}; %#ok<AGROW>
        kp(end+1, :) = {'orig_route_agreement_rate_all', orig_route_agree, 'part-6 route agreement'}; %#ok<AGROW>
        kp(end+1, :) = {'orig_low_confidence_rate_all', orig_low, 'part-6 low-confidence rate'}; %#ok<AGROW>
        kp(end+1, :) = {'orig_false_high_confidence_rate_all', orig_false_high, 'part-6 false-high rate'}; %#ok<AGROW>
        kp(end+1, :) = {'orig_boundary_missed_rate_all', orig_boundary_missed, 'part-6 boundary-missed rate'}; %#ok<AGROW>
        kp(end+1, :) = {'delta_observable_dispatch_success_all', new_obs - orig_obs, '6B minus part-6 observable success'}; %#ok<AGROW>
        kp(end+1, :) = {'delta_observable_vs_oracle_gap_all', new_gap - orig_gap, '6B minus part-6 observable-oracle gap'}; %#ok<AGROW>
        kp(end+1, :) = {'delta_low_confidence_rate_all', new_low - orig_low, '6B minus part-6 low-confidence rate'}; %#ok<AGROW>
        kp(end+1, :) = {'delta_false_high_confidence_rate_all', new_false_high - orig_false_high, '6B minus part-6 false-high rate'}; %#ok<AGROW>
        kp(end+1, :) = {'delta_boundary_missed_rate_all', new_boundary_missed - orig_boundary_missed, '6B minus part-6 boundary-missed rate'}; %#ok<AGROW>
    end
    keypoints = cell2table(kp, 'VariableNames', {'keypoint', 'value', 'note'});
end

function tbl = read_optional_keypoints_local(path_in)
    if exist(path_in, 'file')
        tbl = readtable(path_in, 'TextType', 'string');
    else
        tbl = table();
    end
end

function val = case_mean_local(T, case_name, colname)
    mask = strcmp(T.case_name, case_name);
    if any(mask)
        val = mean(T.(colname)(mask), 'omitnan');
    else
        val = NaN;
    end
end

function val = group_route_mean_local(T, group_name, colname)
    mask = strcmp(T.group, group_name);
    if any(mask)
        val = mean(T.(colname)(mask), 'omitnan');
    else
        val = NaN;
    end
end

function reason = failure_reason_pair_local(az_est, el_est, min_sep, max_sep)
    if any(~isfinite(az_est)) || any(~isfinite(el_est))
        reason = 'nan_estimate';
    elseif diff(sort(az_est)) < min_sep
        reason = 'pair_too_close';
    elseif diff(sort(az_est)) > max_sep
        reason = 'pair_too_wide';
    else
        reason = 'ok';
    end
end

function plot_observable_vs_oracle_success_local(tbl, path_out)
    O = tbl(strcmp(tbl.route_name, 'observable_dispatch'), :);
    [groups, ~, gidx] = unique(O.group, 'stable');
    vals = zeros(numel(groups), 2);
    for ig = 1:numel(groups)
        vals(ig, 1) = mean(O.oracle_dispatch_success_rate(gidx == ig), 'omitnan');
        vals(ig, 2) = mean(O.observable_dispatch_success_rate(gidx == ig), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', groups, 'XTickLabelRotation', 20);
    ylabel('joint success rate');
    title('Oracle vs observable dispatch success');
    legend({'oracle', 'observable'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_observable_route_agreement_local(tbl, path_out)
    O = tbl(strcmp(tbl.route_name, 'observable_dispatch'), :);
    fig = figure('Visible', 'off');
    x = unique(O.snr_db).';
    groups = unique(O.group, 'stable');
    hold on
    for ig = 1:numel(groups)
        y = nan(size(x));
        for ix = 1:numel(x)
            mask = strcmp(O.group, groups{ig}) & O.snr_db == x(ix);
            y(ix) = mean(O.route_agreement_rate(mask), 'omitnan');
        end
        plot(x, y, '-o', 'LineWidth', 1.2);
    end
    grid on
    ylim([-0.05, 1.05]);
    xlabel('SNR (dB)');
    ylabel('route agreement rate');
    title('Observable route agreement');
    legend(groups, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_observable_low_confidence_local(tbl, path_out)
    O = tbl(strcmp(tbl.route_name, 'observable_dispatch'), :);
    [groups, ~, gidx] = unique(O.group, 'stable');
    vals = zeros(numel(groups), 1);
    for ig = 1:numel(groups)
        vals(ig) = mean(O.dispatch_low_confidence_rate(gidx == ig), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', groups, 'XTickLabelRotation', 20);
    ylabel('low-confidence rate');
    title('Observable low-confidence rate');
    saveas(fig, path_out);
    close(fig);
end

function plot_observable_false_high_confidence_local(tbl, path_out)
    O = tbl(strcmp(tbl.route_name, 'observable_dispatch'), :);
    [groups, ~, gidx] = unique(O.group, 'stable');
    vals = zeros(numel(groups), 2);
    for ig = 1:numel(groups)
        vals(ig, 1) = mean(O.false_high_confidence_rate(gidx == ig), 'omitnan');
        vals(ig, 2) = mean(O.false_medium_high_confidence_rate(gidx == ig), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', groups, 'XTickLabelRotation', 20);
    ylabel('rate');
    title('Observable false confidence');
    legend({'false_high', 'false_medium_high'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_observable_dispatch_by_group_local(tbl, path_out)
    O = tbl(strcmp(tbl.route_name, 'observable_dispatch'), :);
    [groups, ~, gidx] = unique(O.group, 'stable');
    snrs = unique(O.snr_db).';
    vals = zeros(numel(groups), numel(snrs));
    for ig = 1:numel(groups)
        for is = 1:numel(snrs)
            mask = gidx == ig & O.snr_db == snrs(is);
            vals(ig, is) = mean(O.joint_tol_success_rate(mask), 'omitnan');
        end
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', groups, 'XTickLabelRotation', 20);
    ylabel('joint success rate');
    title('Observable dispatch by scenario group');
    legend(compose('SNR=%g', snrs), 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function val = keypoint_value_local(keypoints_tbl, name)
    if isempty(keypoints_tbl) || ~ismember('keypoint', keypoints_tbl.Properties.VariableNames)
        val = NaN;
        return
    end
    idx = strcmp(string(keypoints_tbl.keypoint), string(name));
    if any(idx)
        val = keypoints_tbl.value(find(idx, 1));
    else
        val = NaN;
    end
end

function val = min_or_nan_local(x)
    if isempty(x)
        val = NaN;
    else
        val = min(x);
    end
end

function val = max_or_nan_local(x)
    if isempty(x)
        val = NaN;
    else
        val = max(x);
    end
end

function write_record_doc_v2_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, Metkl)
    fid = fopen(record_doc_path, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 绗?.7姝6锛氳娴嬮噺椹卞姩宸ョ▼鍒嗘祦楠岃瘉璁板綍\n\n');
    fprintf(fid, '## Scope\n\n');
    fprintf(fid, '- Script: `space_smooth_music_B_cylindrical_level3_observable_dispatch_demo.m`\n');
    fprintf(fid, '- Result dir: `results_step8_7_6_observable_dispatch_demo/`\n');
    fprintf(fid, '- General source model: `s2 = beta * exp(j*phi) * (rho*s1 + sqrt(1-rho^2)*v)`\n');
    fprintf(fid, '- Observable dispatch only uses route outputs and spectrum/covariance diagnostics.\n');
    fprintf(fid, '- Monte Carlo: Metkl=%d, SNR=[0,8,16], T_snap=260.\n', Metkl);
    fprintf(fid, '- Metkl is reduced from 50 to 30 for runtime control.\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.3f | %s |\n', keypoints_tbl.keypoint{i}, keypoints_tbl.value(i), keypoints_tbl.note{i});
    end

    oracle_success = keypoint_value_local(keypoints_tbl, 'oracle_dispatch_success_all');
    observable_success = keypoint_value_local(keypoints_tbl, 'observable_dispatch_success_all');
    gap = keypoint_value_local(keypoints_tbl, 'observable_vs_oracle_gap_all');
    route_agree = keypoint_value_local(keypoints_tbl, 'route_agreement_rate_all');
    low_conf = keypoint_value_local(keypoints_tbl, 'low_confidence_rate_all');
    false_high = keypoint_value_local(keypoints_tbl, 'false_high_confidence_rate_all');
    boundary_missed = keypoint_value_local(keypoints_tbl, 'boundary_missed_rate_all');

    fprintf(fid, '\n## Judgment\n\n');
    fprintf(fid, '- Oracle dispatch success: %.3f\n', oracle_success);
    fprintf(fid, '- Observable dispatch success: %.3f\n', observable_success);
    fprintf(fid, '- Observable minus oracle gap: %.3f\n', gap);
    fprintf(fid, '- Route agreement rate: %.3f\n', route_agree);
    fprintf(fid, '- Low-confidence rate: %.3f\n', low_conf);
    fprintf(fid, '- False-high-confidence rate: %.3f\n', false_high);
    fprintf(fid, '- Boundary-missed rate: %.3f\n\n', boundary_missed);

    if observable_success >= oracle_success - 0.10 && false_high <= 0.05
        fprintf(fid, 'Observable dispatch is close enough to oracle dispatch and can be treated as an engineering prototype.\n\n');
    elseif false_high <= 0.05
        fprintf(fid, 'Observable dispatch is conservative. Coverage is below oracle, but confidence control is acceptable.\n\n');
    elseif false_high > 0.10
        fprintf(fid, 'Observable dispatch is not reliable enough for an engineering interface. Confidence design still needs revision.\n\n');
    else
        fprintf(fid, 'Observable dispatch is partially usable, but the thresholds still need tuning.\n\n');
    end

    fprintf(fid, '## Output\n\n');
    fprintf(fid, '- Result dir: `%s`\n', result_dir);
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
end

function write_record_doc_v3_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, Metkl)
    fid = fopen(record_doc_path, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# Step 8.7 Part 6B: observable dispatch de-oracle gating and confidence calibration\n\n');
    fprintf(fid, '## Scope\n\n');
    fprintf(fid, '- Script: `space_smooth_music_B_cylindrical_level3_observable_dispatch_calibrated.m`\n');
    fprintf(fid, '- Result dir: `results_step8_7_6b_observable_dispatch_calibrated/`\n');
    fprintf(fid, '- General source model: `s2 = beta * exp(j*phi) * (rho*s1 + sqrt(1-rho^2)*v)`\n');
    fprintf(fid, '- Same reduced scenario set as part 6: rho scan, beta scan, phase scan, and representative large-el cases.\n');
    fprintf(fid, '- Observable dispatch uses only route outputs and diagnostic observables, not `beta/phase/rho/el_true/el_diff`.\n');
    fprintf(fid, '- Part 6B changes only route gating, confidence calibration, and reporting.\n');
    fprintf(fid, '- Monte Carlo: Metkl=%d, SNR=[0,8,16], T_snap=260.\n\n', Metkl);

    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.3f | %s |\n', keypoints_tbl.keypoint{i}, keypoints_tbl.value(i), keypoints_tbl.note{i});
    end

    oracle_success = keypoint_value_local(keypoints_tbl, 'oracle_dispatch_success_all');
    observable_success = keypoint_value_local(keypoints_tbl, 'observable_dispatch_success_all');
    gap = keypoint_value_local(keypoints_tbl, 'observable_vs_oracle_gap_all');
    route_agree = keypoint_value_local(keypoints_tbl, 'route_agreement_rate_all');
    low_conf = keypoint_value_local(keypoints_tbl, 'low_confidence_rate_all');
    boundary_unreliable = keypoint_value_local(keypoints_tbl, 'boundary_unreliable_rate_all');
    false_high = keypoint_value_local(keypoints_tbl, 'false_high_confidence_rate_all');
    false_med_high = keypoint_value_local(keypoints_tbl, 'false_medium_high_confidence_rate_all');
    boundary_missed = keypoint_value_local(keypoints_tbl, 'boundary_missed_rate_all');
    refocus_all = keypoint_value_local(keypoints_tbl, 'refocus_computed_all_scenarios_flag');
    refocus_selected = keypoint_value_local(keypoints_tbl, 'num_cases_refocus_selected');
    d_success = keypoint_value_local(keypoints_tbl, 'delta_observable_dispatch_success_all');
    d_low = keypoint_value_local(keypoints_tbl, 'delta_low_confidence_rate_all');
    d_false_high = keypoint_value_local(keypoints_tbl, 'delta_false_high_confidence_rate_all');
    d_boundary = keypoint_value_local(keypoints_tbl, 'delta_boundary_missed_rate_all');

    fprintf(fid, '\n## Calibration Summary\n\n');
    fprintf(fid, '- Oracle dispatch success: %.3f\n', oracle_success);
    fprintf(fid, '- Calibrated observable dispatch success: %.3f\n', observable_success);
    fprintf(fid, '- Observable-oracle gap: %.3f\n', gap);
    fprintf(fid, '- Route agreement rate: %.3f\n', route_agree);
    fprintf(fid, '- Low-confidence rate: %.3f\n', low_conf);
    fprintf(fid, '- Boundary-unreliable rate: %.3f\n', boundary_unreliable);
    fprintf(fid, '- False-high-confidence rate: %.3f\n', false_high);
    fprintf(fid, '- False-medium/high-confidence rate: %.3f\n', false_med_high);
    fprintf(fid, '- Boundary-missed rate: %.3f\n', boundary_missed);
    fprintf(fid, '- Refocus computed on all scenario-SNR cases: %.0f\n', refocus_all);
    fprintf(fid, '- Scenario-SNR cases selecting refocus: %.0f\n\n', refocus_selected);

    fprintf(fid, '## Delta vs Part 6\n\n');
    fprintf(fid, '- Observable success delta: %.3f\n', d_success);
    fprintf(fid, '- Low-confidence delta: %.3f\n', d_low);
    fprintf(fid, '- False-high delta: %.3f\n', d_false_high);
    fprintf(fid, '- Boundary-missed delta: %.3f\n\n', d_boundary);

    fprintf(fid, '## Judgment\n\n');
    if observable_success >= oracle_success - 0.10 && false_high <= 0.05
        fprintf(fid, 'Observable dispatch now meets the target safety bar while staying close to oracle dispatch. It is usable as the current engineering prototype for step 8.7.\n\n');
    elseif false_high <= 0.05
        fprintf(fid, 'Calibration makes the dispatch safer, but coverage drops noticeably. This is still acceptable as a conservative engineering prototype.\n\n');
    elseif false_high > 0.05
        fprintf(fid, 'False-high-confidence remains above target. The dispatch is improved but still not clean enough to call the engineering loop closed.\n\n');
    else
        fprintf(fid, 'The calibration is mixed and still needs another threshold pass.\n\n');
    end

    fprintf(fid, '## Output\n\n');
    fprintf(fid, '- Result dir: `%s`\n', result_dir);
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
end

function write_record_doc_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, Metkl)
    fid = fopen(record_doc_path, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 绗?.7姝5锛氫竴鑸簮妯″瀷鍒嗘祦杈圭晫楠岃瘉璁板綍\n\n');
    fprintf(fid, '## 瀹炵幇鑼冨洿\n\n');
    fprintf(fid, '- 鏂拌剼鏈細`space_smooth_music_B_cylindrical_level3_general_model_dispatch_boundary.m`銆俓n');
    fprintf(fid, '- 鏂扮粨鏋滅洰褰曪細`results_step8_7_5_general_model_dispatch_boundary/`銆俓n');
    fprintf(fid, '- 浣跨敤涓€鑸簮妯″瀷 `s2=beta*exp(j*phi)*(rho*s1+sqrt(1-rho^2)*v)`銆俓n');
    fprintf(fid, '- 瀹炵幇 route锛歚level2_music_or_center_real`銆乣level2_rank1_fallback`銆乣common_el_refocus_power_rank1`銆乣level3_2d_music`銆乣pair_el_local_covfit`銆乣dispatch_recommended_route`銆俓n');
    fprintf(fid, '- 鏈疆鍙獙璇佸垎娴佽竟鐣岋紝涓嶅仛 fullscan/V2 constrained covariance fitting/complex-gain q/瀹屾暣 4D 鎼滅储銆俓n');
    fprintf(fid, '- Monte Carlo: Metkl=%d, SNR=[0,8,16], T_snap=260銆俓n\n', Metkl);
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.3f | %s |\n', keypoints_tbl.keypoint{i}, keypoints_tbl.value(i), keypoints_tbl.note{i});
    end
    fprintf(fid, '\n## 鍒嗙粍鍒ゆ柇\n\n');
    rho1 = keypoint_value_local(keypoints_tbl, 'rho_music_joint_rho1');
    rho07 = keypoint_value_local(keypoints_tbl, 'rho_music_joint_rho0p7');
    if rho07 > rho1
        fprintf(fid, '- rho 鎵弿锛歳ho 闄嶄綆鍚?MUSIC 鏈夋仮澶嶈秼鍔匡紝闈炲畬鍏ㄧ浉骞插満鏅笉闇€瑕佷紭鍏堝惎鐢?rank1 fallback銆俓n');
    else
        fprintf(fid, '- rho 鎵弿锛歳ho 闄嶄綆鍚?MUSIC 鏈槑鏄炬仮澶嶏紝闂鍙兘浠嶅彈灏忛棿闅斿拰闃靛垪妯″瀷闄愬埗銆俓n');
    end
    b03 = keypoint_value_local(keypoints_tbl, 'beta_rank1_joint_beta0p3');
    wb03 = keypoint_value_local(keypoints_tbl, 'beta_weak_boundary_rate_beta0p3');
    if wb03 >= 0.9 || b03 < 0.8
        fprintf(fid, '- beta 鎵弿锛歜eta<=0.3 灞炰簬寮辩洰鏍囪竟鐣岋紝闇€瑕?SIC 鎴栧急鐩爣妫€娴嬬瓥鐣ワ紝涓嶅缓璁己琛?rank1 pair covfit銆俓n');
    else
        fprintf(fid, '- beta 鎵弿锛氬綋鍓?beta 杈圭晫鏈畬鍏ㄥ嚮绌?rank1锛屼絾浠嶅簲淇濈暀 weak_target_boundary 鏍囪銆俓n');
    end
    p150 = keypoint_value_local(keypoints_tbl, 'phase_rank1_joint_phase150');
    ap150 = keypoint_value_local(keypoints_tbl, 'phase_anti_boundary_rate_phase150');
    if ap150 >= 0.9 || p150 < 0.8
        fprintf(fid, '- phase 鎵弿锛歱hase=150/180 灞炰簬杩戝弽鐩哥梾鎬佽竟鐣岋紝搴旀爣璁?anti_phase_boundary銆俓n');
    else
        fprintf(fid, '- phase 鎵弿锛氳繎鍙嶇浉鏈畬鍏ㄥけ璐ワ紝浣嗕粛涓嶅簲鍖呰涓烘甯?rank1 fallback 鍦烘櫙銆俓n');
    end
    le5 = keypoint_value_local(keypoints_tbl, 'large_el_2dmusic_joint_el5_clean');
    hard = keypoint_value_local(keypoints_tbl, 'large_el_2dmusic_joint_el10_hard');
    if le5 >= 0.8
        fprintf(fid, '- 澶т刊浠板樊涓€鑸簮锛歟l_b>=5 鐨勫共鍑€寮虹浉骞插満鏅彲鐢?2D MUSIC 鍑犱綍鍒嗙澶勭悊銆俓n');
    end
    if hard < 0.8
        fprintf(fid, '- 澶т刊浠板樊鍙犲姞寮辩洰鏍?鍙嶇浉/浣庣浉骞叉椂浠嶅彲鑳藉け璐ワ紝浜岀淮鍑犱綍涓嶈兘瀹屽叏瑙ｅ喅鍔ㄦ€佽寖鍥村拰鐥呮€佺浉浣嶉棶棰樸€俓n');
    end
    fprintf(fid, '- 鏈疆浠嶄笉闇€瑕佸疄鐜?V2/general covariance fitting锛沄2 缁х画浣滀负鏈潵涓€鑸崗鏂瑰樊妯″瀷鎵╁睍淇濈暀銆俓n\n');
    fprintf(fid, '## 杈撳嚭\n\n');
    fprintf(fid, '- 缁撴灉鐩綍锛歚%s`\n', result_dir);
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
end

function safe_fclose_local(fid)
    if ~isempty(fid) && fid > 0
        fclose(fid);
    end
end

function log_msg(fid, fmt, varargin)
    msg = sprintf(fmt, varargin{:});
    fprintf('%s\n', msg);
    if fid > 0
        fprintf(fid, '%s\n', msg);
    end
end

function [result, trace] = apply_cascade_dispatch_rule_local(route_map, min_sep, max_sep, cost_model)
    music = route_map.music;
    rank1 = route_map.rank1_fallback;
    refocus = route_map.common_el_refocus_rank1;
    music2d = route_map.level3_2d_music;
    pair2d = route_map.pair_el_local_covfit;

    pair_available = music2d.peak_count >= 2 && all(isfinite(music2d.az_est));
    common_el_proxy = is_strong_common_el_proxy_local(music, refocus);
    trace = struct();
    trace.routes_evaluated_count = 0;
    trace.full_routes_available_count = 4 + double(pair_available);
    trace.estimated_cost_unit = 0;
    trace.full_dispatch_cost_unit = cost_model.level2_music + cost_model.refocus + ...
        cost_model.level2_rank1 + cost_model.music2d + cost_model.pair_local * double(pair_available);
    trace.heavy_route_triggered_flag = false;
    trace.music2d_triggered_flag = false;
    trace.pair_local_triggered_flag = false;
    trace.early_stop_flag = false;
    trace.stop_stage = "";

    low_cost_boundary = is_low_cost_boundary_proxy_from_partial_local(music, rank1, refocus, min_sep, max_sep);

    trace.routes_evaluated_count = trace.routes_evaluated_count + 1;
    trace.estimated_cost_unit = trace.estimated_cost_unit + cost_model.level2_music;
    if is_level2_music_reliable_local(music, min_sep, max_sep) && common_el_proxy
        result = music;
        result.recommended_route = "level2_music_or_center_real";
        if is_level2_music_high_confidence_local(music, route_map, min_sep, max_sep)
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "ok";
        trace.stop_stage = "level2_music";
        trace.early_stop_flag = trace.routes_evaluated_count < trace.full_routes_available_count;
        return
    end

    trace.routes_evaluated_count = trace.routes_evaluated_count + 1;
    trace.estimated_cost_unit = trace.estimated_cost_unit + cost_model.refocus;
    if is_refocus_route_reliable_local(refocus, min_sep, max_sep) && ~low_cost_boundary && common_el_proxy
        result = refocus;
        result.recommended_route = "common_el_refocus_power_rank1";
        result.confidence_flag = "medium";
        result.failure_reason = "ok";
        trace.stop_stage = "refocus";
        trace.early_stop_flag = trace.routes_evaluated_count < trace.full_routes_available_count;
        return
    end

    trace.routes_evaluated_count = trace.routes_evaluated_count + 1;
    trace.estimated_cost_unit = trace.estimated_cost_unit + cost_model.level2_rank1;
    if is_rank1_route_reliable_local(rank1, min_sep, max_sep) && ~low_cost_boundary && common_el_proxy
        result = rank1;
        result.recommended_route = "level2_rank1_fallback";
        result.confidence_flag = "medium";
        result.failure_reason = "music_single_rank1_fallback";
        trace.stop_stage = "rank1_fallback";
        trace.early_stop_flag = trace.routes_evaluated_count < trace.full_routes_available_count;
        return
    end

    trace.routes_evaluated_count = trace.routes_evaluated_count + 1;
    trace.estimated_cost_unit = trace.estimated_cost_unit + cost_model.music2d;
    trace.heavy_route_triggered_flag = true;
    trace.music2d_triggered_flag = true;
    if is_music2d_reliable_local(music2d, min_sep, max_sep)
        if pair_available && is_cascade_pair_refinement_needed_local(music2d, min_sep, max_sep)
            trace.routes_evaluated_count = trace.routes_evaluated_count + 1;
            trace.estimated_cost_unit = trace.estimated_cost_unit + cost_model.pair_local;
            trace.pair_local_triggered_flag = true;
            if is_pair_route_reliable_local(pair2d, min_sep, max_sep)
                result = pair2d;
                result.recommended_route = "pair_el_local_covfit";
                result.confidence_flag = "medium";
                result.failure_reason = "ok";
                trace.stop_stage = "pair_local_covfit";
                trace.early_stop_flag = trace.routes_evaluated_count < trace.full_routes_available_count;
                return
            end
        end
        result = music2d;
        result.recommended_route = "level3_2d_music";
        result.confidence_flag = "medium";
        if trace.pair_local_triggered_flag
            result.failure_reason = "pair_local_not_reliable";
        else
            result.failure_reason = "ok";
        end
        trace.stop_stage = "level3_2d_music";
        trace.early_stop_flag = trace.routes_evaluated_count < trace.full_routes_available_count;
        return
    end

    if is_boundary_unreliable_local(route_map, min_sep, max_sep) || low_cost_boundary
        result = make_boundary_result_local(route_map, 'boundary_unreliable', 'low', 'boundary_unreliable', false, false);
    else
        result = make_boundary_result_local(route_map, 'low_confidence', 'low', 'no_reliable_observable_route', false, false);
    end
    trace.stop_stage = "low_confidence";
    trace.early_stop_flag = trace.routes_evaluated_count < trace.full_routes_available_count;
end

function tf = is_low_cost_boundary_proxy_from_partial_local(music, rank1, refocus, min_sep, max_sep)
    music_single = music.peak_count < 2 || any(~isfinite(music.az_est));
    strong_single_peak = music_single && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;
    rank1_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    rank1_sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    weak_rank1 = (~isfinite(rank1_gap) || rank1_gap < 5e-3) || ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3);
    sep_edge = is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_sharp = min( ...
        getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;
    refocus_rank1_conflict = false;
    if all(isfinite(getfield_default_local(refocus, 'az_est', [NaN, NaN]))) && ...
            all(isfinite(getfield_default_local(rank1, 'az_est', [NaN, NaN])))
        refocus_rank1_conflict = max(abs(sort(refocus.az_est) - sort(rank1.az_est))) > 0.14;
    end
    tf = (music_single && refocus_unsharp && weak_rank1) || ...
        (strong_single_peak && refocus_unsharp) || ...
        (music_single && sep_edge && weak_rank1) || ...
        (refocus_rank1_conflict && ~is_refocus_route_reliable_local(refocus, min_sep, max_sep));
end

function tf = is_strong_common_el_proxy_local(music, refocus)
    el_music = getfield_default_local(music, 'el_est', [NaN, NaN]);
    el_assumed = mean(el_music(isfinite(el_music)), 'omitnan');
    if ~isfinite(el_assumed)
        el_assumed = 0;
    end
    el_hat = getfield_default_local(refocus, 'el_hat', NaN);
    refocus_sharp = min( ...
        getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    tf = isfinite(el_hat) && isfinite(refocus_sharp) && ...
        abs(el_hat - el_assumed) <= 0.75 && refocus_sharp >= 0.075;
end

function ok = is_music2d_high_confidence_local(result, min_sep, max_sep)
    sep_az = getfield_default_local(result, 'peak_separation_az', NaN);
    sep_el = getfield_default_local(result, 'peak_separation_el', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    ok = is_music2d_reliable_local(result, min_sep, max_sep) && ...
        isfinite(prom) && prom >= 0.75 && isfinite(sep_el) && sep_el >= 2.5 && ...
        ~is_sep_edge_local(sep_az, min_sep, max_sep, 0.02);
end

function tf = is_cascade_pair_refinement_needed_local(music2d_result, min_sep, max_sep)
    tf = is_music2d_reliable_local(music2d_result, min_sep, max_sep) && ...
        ~is_music2d_high_confidence_local(music2d_result, min_sep, max_sep);
end

function store = init_cascade_runtime_store_local(Metkl)
    store = struct( ...
        'oracle_route', strings(Metkl, 1), ...
        'full_route', strings(Metkl, 1), ...
        'cascade_route', strings(Metkl, 1), ...
        'cascade_confidence', strings(Metkl, 1), ...
        'cascade_failure_reason', strings(Metkl, 1), ...
        'oracle_success', zeros(Metkl, 1), ...
        'full_success', zeros(Metkl, 1), ...
        'cascade_success', zeros(Metkl, 1), ...
        'route_agreement_with_6b', zeros(Metkl, 1), ...
        'low_confidence', zeros(Metkl, 1), ...
        'boundary_unreliable', zeros(Metkl, 1), ...
        'false_high_confidence', zeros(Metkl, 1), ...
        'false_medium_high_confidence', zeros(Metkl, 1), ...
        'boundary_missed', zeros(Metkl, 1), ...
        'routes_evaluated_count', zeros(Metkl, 1), ...
        'full_routes_available_count', zeros(Metkl, 1), ...
        'estimated_cost_unit', zeros(Metkl, 1), ...
        'full_dispatch_cost_unit', zeros(Metkl, 1), ...
        'heavy_route_triggered_flag', zeros(Metkl, 1), ...
        'music2d_triggered_flag', zeros(Metkl, 1), ...
        'pair_local_triggered_flag', zeros(Metkl, 1), ...
        'early_stop_flag', zeros(Metkl, 1));
end

function store = store_cascade_runtime_trial_local( ...
    store, imc, oracle_result, full_result, cascade_result, trace, theta_true, el_true, az_tol, el_tol)
    oracle_success = joint_success_from_result_local(oracle_result, theta_true, el_true, az_tol, el_tol);
    full_success = joint_success_from_result_local(full_result, theta_true, el_true, az_tol, el_tol);
    cascade_success = joint_success_from_result_local(cascade_result, theta_true, el_true, az_tol, el_tol);
    oracle_route = string(getfield_default_local(oracle_result, 'recommended_route', ""));
    full_route = string(getfield_default_local(full_result, 'recommended_route', ""));
    cascade_route = string(getfield_default_local(cascade_result, 'recommended_route', ""));
    conf = string(getfield_default_local(cascade_result, 'confidence_flag', ""));
    fail_reason = string(getfield_default_local(cascade_result, 'failure_reason', ""));
    oracle_boundary = any(strcmp(oracle_route, ["weak_target_boundary", "anti_phase_boundary", "low_confidence"]));
    cascade_normal_high = strcmp(conf, "high") && ...
        ~any(strcmp(cascade_route, ["low_confidence", "boundary_unreliable"]));

    store.oracle_route(imc) = oracle_route;
    store.full_route(imc) = full_route;
    store.cascade_route(imc) = cascade_route;
    store.cascade_confidence(imc) = conf;
    store.cascade_failure_reason(imc) = fail_reason;
    store.oracle_success(imc) = oracle_success;
    store.full_success(imc) = full_success;
    store.cascade_success(imc) = cascade_success;
    store.route_agreement_with_6b(imc) = strcmp(full_route, cascade_route);
    store.low_confidence(imc) = strcmp(conf, "low") || ...
        any(strcmp(cascade_route, ["low_confidence", "boundary_unreliable"]));
    store.boundary_unreliable(imc) = strcmp(cascade_route, "boundary_unreliable");
    store.false_high_confidence(imc) = strcmp(conf, "high") && ~cascade_success;
    store.false_medium_high_confidence(imc) = any(strcmp(conf, ["high", "medium"])) && ~cascade_success;
    store.boundary_missed(imc) = oracle_boundary && cascade_normal_high && ~cascade_success;
    store.routes_evaluated_count(imc) = trace.routes_evaluated_count;
    store.full_routes_available_count(imc) = trace.full_routes_available_count;
    store.estimated_cost_unit(imc) = trace.estimated_cost_unit;
    store.full_dispatch_cost_unit(imc) = trace.full_dispatch_cost_unit;
    store.heavy_route_triggered_flag(imc) = trace.heavy_route_triggered_flag;
    store.music2d_triggered_flag(imc) = trace.music2d_triggered_flag;
    store.pair_local_triggered_flag(imc) = trace.pair_local_triggered_flag;
    store.early_stop_flag(imc) = trace.early_stop_flag;
end

function metrics = summarize_cascade_runtime_local(store)
    metrics = struct();
    metrics.oracle_dispatch_route = mode_string_local_nonempty(store.oracle_route);
    metrics.full_observable_dispatch_route = mode_string_local_nonempty(store.full_route);
    metrics.cascade_dispatch_route = mode_string_local_nonempty(store.cascade_route);
    metrics.route_agreement_with_6b = mean(store.route_agreement_with_6b);
    metrics.oracle_dispatch_success_rate = mean(store.oracle_success);
    metrics.full_dispatch_success_rate = mean(store.full_success);
    metrics.cascade_success_rate = mean(store.cascade_success);
    metrics.cascade_vs_full_success_gap = metrics.cascade_success_rate - metrics.full_dispatch_success_rate;
    metrics.low_confidence_rate = mean(store.low_confidence);
    metrics.boundary_unreliable_rate = mean(store.boundary_unreliable);
    metrics.false_high_confidence_rate = mean(store.false_high_confidence);
    metrics.false_medium_high_confidence_rate = mean(store.false_medium_high_confidence);
    metrics.boundary_missed_rate = mean(store.boundary_missed);
    metrics.mean_routes_evaluated = mean(store.routes_evaluated_count);
    metrics.mean_full_routes_available = mean(store.full_routes_available_count);
    metrics.mean_estimated_cost = mean(store.estimated_cost_unit);
    metrics.mean_full_dispatch_cost = mean(store.full_dispatch_cost_unit);
    metrics.cost_reduction_vs_full_dispatch = 1 - metrics.mean_estimated_cost / max(metrics.mean_full_dispatch_cost, eps);
    metrics.heavy_route_trigger_rate = mean(store.heavy_route_triggered_flag);
    metrics.music2d_trigger_rate = mean(store.music2d_triggered_flag);
    metrics.pair_local_trigger_rate = mean(store.pair_local_triggered_flag);
    metrics.early_stop_rate = mean(store.early_stop_flag);
    metrics.cascade_route_distribution = distribution_string_local(store.cascade_route);
    metrics.cascade_confidence_distribution = distribution_string_local(store.cascade_confidence);
    metrics.main_failure_reason = mode_string_local_nonempty(store.cascade_failure_reason(store.cascade_success == 0));
end

function row = make_cascade_summary_row_local(sc, metrics)
    row = { ...
        string(sc.group), string(sc.case_name), sc.snr_db, sc.beta, sc.phi_deg, sc.rho, ...
        sc.el_true(1), sc.el_true(2), sc.el_diff, sc.el_assumed, ...
        string(metrics.oracle_dispatch_route), string(metrics.full_observable_dispatch_route), ...
        string(metrics.cascade_dispatch_route), metrics.route_agreement_with_6b, ...
        metrics.oracle_dispatch_success_rate, metrics.full_dispatch_success_rate, ...
        metrics.cascade_success_rate, metrics.cascade_vs_full_success_gap, ...
        metrics.false_high_confidence_rate, metrics.false_medium_high_confidence_rate, ...
        metrics.boundary_missed_rate, metrics.low_confidence_rate, metrics.boundary_unreliable_rate, ...
        metrics.mean_routes_evaluated, metrics.mean_full_routes_available, ...
        metrics.mean_estimated_cost, metrics.mean_full_dispatch_cost, ...
        metrics.cost_reduction_vs_full_dispatch, metrics.heavy_route_trigger_rate, ...
        metrics.music2d_trigger_rate, metrics.pair_local_trigger_rate, metrics.early_stop_rate, ...
        string(metrics.cascade_route_distribution), string(metrics.cascade_confidence_distribution), ...
        string(metrics.main_failure_reason)};
end

function names = cascade_summary_var_names_local()
    names = { ...
        'group', 'case_name', 'snr_db', 'beta', 'phi_deg', 'rho', ...
        'el_a_deg', 'el_b_deg', 'el_diff_deg', 'el_assumed_deg', ...
        'oracle_dispatch_route', 'full_observable_dispatch_route', 'cascade_dispatch_route', ...
        'route_agreement_with_6b', 'oracle_dispatch_success_rate', 'full_6b_success_rate', ...
        'cascade_success_rate', 'cascade_vs_full_success_gap', ...
        'false_high_confidence_rate', 'false_medium_high_confidence_rate', ...
        'boundary_missed_rate', 'low_confidence_rate', 'boundary_unreliable_rate', ...
        'mean_routes_evaluated', 'mean_full_routes_available', ...
        'mean_estimated_cost', 'mean_full_dispatch_cost', 'cost_reduction_vs_full_dispatch', ...
        'heavy_route_trigger_rate', 'music2d_trigger_rate', 'pair_local_trigger_rate', ...
        'early_stop_rate', 'cascade_route_distribution', 'cascade_confidence_distribution', ...
        'main_failure_reason'};
end

function keypoints = build_cascade_keypoints_local(summary_tbl, baseline_keypoints_tbl)
    kp = {};
    saved_full = keypoint_value_local(baseline_keypoints_tbl, 'observable_dispatch_success_all');
    kp(end+1, :) = {'saved_full6b_success_all', saved_full, 'saved part-6B observable dispatch success'}; %#ok<AGROW>
    kp(end+1, :) = {'recomputed_full6b_success_all', mean(summary_tbl.full_6b_success_rate, 'omitnan'), 'recomputed full dispatch success under part-7 runtime script'}; %#ok<AGROW>
    kp(end+1, :) = {'cascade_dispatch_success_all', mean(summary_tbl.cascade_success_rate, 'omitnan'), 'cascade dispatch mean joint success'}; %#ok<AGROW>
    kp(end+1, :) = {'cascade_vs_saved_full_gap_all', mean(summary_tbl.cascade_success_rate, 'omitnan') - saved_full, 'cascade success minus saved 6B full dispatch success'}; %#ok<AGROW>
    kp(end+1, :) = {'cascade_vs_recomputed_full_gap_all', mean(summary_tbl.cascade_vs_full_success_gap, 'omitnan'), 'cascade success minus recomputed full dispatch success'}; %#ok<AGROW>
    kp(end+1, :) = {'route_agreement_with_6b_all', mean(summary_tbl.route_agreement_with_6b, 'omitnan'), 'cascade route agreement with full 6B observable dispatch'}; %#ok<AGROW>
    kp(end+1, :) = {'low_confidence_rate_all', mean(summary_tbl.low_confidence_rate, 'omitnan'), 'cascade low-confidence rate'}; %#ok<AGROW>
    kp(end+1, :) = {'boundary_unreliable_rate_all', mean(summary_tbl.boundary_unreliable_rate, 'omitnan'), 'cascade boundary-unreliable rate'}; %#ok<AGROW>
    kp(end+1, :) = {'false_high_confidence_rate_all', mean(summary_tbl.false_high_confidence_rate, 'omitnan'), 'cascade false high-confidence rate'}; %#ok<AGROW>
    kp(end+1, :) = {'false_medium_high_confidence_rate_all', mean(summary_tbl.false_medium_high_confidence_rate, 'omitnan'), 'cascade false medium/high-confidence rate'}; %#ok<AGROW>
    kp(end+1, :) = {'boundary_missed_rate_all', mean(summary_tbl.boundary_missed_rate, 'omitnan'), 'cascade boundary-missed rate'}; %#ok<AGROW>
    kp(end+1, :) = {'mean_routes_evaluated_all', mean(summary_tbl.mean_routes_evaluated, 'omitnan'), 'mean routes evaluated by cascade'}; %#ok<AGROW>
    kp(end+1, :) = {'mean_estimated_cost_all', mean(summary_tbl.mean_estimated_cost, 'omitnan'), 'mean estimated cascade cost unit'}; %#ok<AGROW>
    kp(end+1, :) = {'mean_full_dispatch_cost_all', mean(summary_tbl.mean_full_dispatch_cost, 'omitnan'), 'mean estimated full dispatch cost unit'}; %#ok<AGROW>
    kp(end+1, :) = {'cost_reduction_vs_full_dispatch_all', mean(summary_tbl.cost_reduction_vs_full_dispatch, 'omitnan'), 'estimated cost reduction versus full dispatch'}; %#ok<AGROW>
    kp(end+1, :) = {'heavy_route_trigger_rate_all', mean(summary_tbl.heavy_route_trigger_rate, 'omitnan'), 'cascade heavy-route trigger rate'}; %#ok<AGROW>
    kp(end+1, :) = {'music2d_trigger_rate_all', mean(summary_tbl.music2d_trigger_rate, 'omitnan'), 'cascade 2D MUSIC trigger rate'}; %#ok<AGROW>
    kp(end+1, :) = {'pair_local_trigger_rate_all', mean(summary_tbl.pair_local_trigger_rate, 'omitnan'), 'cascade pair-local trigger rate'}; %#ok<AGROW>
    kp(end+1, :) = {'early_stop_rate_all', mean(summary_tbl.early_stop_rate, 'omitnan'), 'cascade early-stop rate'}; %#ok<AGROW>
    kp(end+1, :) = {'rho_scan_cascade_success', group_metric_mean_local(summary_tbl, 'rho_scan', 'cascade_success_rate'), 'cascade success on rho scan'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_scan_cascade_success', group_metric_mean_local(summary_tbl, 'beta_scan', 'cascade_success_rate'), 'cascade success on beta scan'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_scan_cascade_success', group_metric_mean_local(summary_tbl, 'phase_scan', 'cascade_success_rate'), 'cascade success on phase scan'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_cascade_success', group_metric_mean_local(summary_tbl, 'large_el', 'cascade_success_rate'), 'cascade success on large-el cases'}; %#ok<AGROW>
    kp(end+1, :) = {'rho_scan_false_high', group_metric_mean_local(summary_tbl, 'rho_scan', 'false_high_confidence_rate'), 'rho-scan false-high rate'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_scan_false_high', group_metric_mean_local(summary_tbl, 'beta_scan', 'false_high_confidence_rate'), 'beta-scan false-high rate'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_scan_false_high', group_metric_mean_local(summary_tbl, 'phase_scan', 'false_high_confidence_rate'), 'phase-scan false-high rate'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_false_high', group_metric_mean_local(summary_tbl, 'large_el', 'false_high_confidence_rate'), 'large-el false-high rate'}; %#ok<AGROW>
    keypoints = cell2table(kp, 'VariableNames', {'keypoint', 'value', 'note'});
end

function val = group_metric_mean_local(T, group_name, colname)
    mask = strcmp(string(T.group), string(group_name));
    if any(mask)
        val = mean(T.(colname)(mask), 'omitnan');
    else
        val = NaN;
    end
end

function plot_cascade_success_vs_full_dispatch_local(tbl, path_out)
    groups = unique(string(tbl.group), 'stable');
    vals = zeros(numel(groups), 2);
    for ig = 1:numel(groups)
        mask = string(tbl.group) == groups(ig);
        vals(ig, 1) = mean(tbl.full_6b_success_rate(mask), 'omitnan');
        vals(ig, 2) = mean(tbl.cascade_success_rate(mask), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('joint success rate');
    title('Cascade success vs full dispatch');
    legend({'full 6B observable', 'cascade'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_cascade_estimated_cost_reduction_local(tbl, path_out)
    groups = unique(string(tbl.group), 'stable');
    vals = zeros(numel(groups), 1);
    for ig = 1:numel(groups)
        mask = string(tbl.group) == groups(ig);
        vals(ig) = mean(tbl.cost_reduction_vs_full_dispatch(mask), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([0, 1]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('cost reduction ratio');
    title('Cascade estimated cost reduction');
    saveas(fig, path_out);
    close(fig);
end

function plot_cascade_routes_evaluated_distribution_local(runtime_stores, path_out)
    vals = [];
    for i = 1:numel(runtime_stores)
        vals = [vals; runtime_stores{i}.routes_evaluated_count(:)]; %#ok<AGROW>
    end
    bins = 1:max(max(vals), 5);
    counts = zeros(size(bins));
    for ib = 1:numel(bins)
        counts(ib) = mean(vals == bins(ib));
    end
    fig = figure('Visible', 'off');
    bar(bins, counts);
    grid on
    ylim([0, 1]);
    xlabel('routes evaluated');
    ylabel('share of trials');
    title('Cascade routes evaluated distribution');
    saveas(fig, path_out);
    close(fig);
end

function plot_cascade_heavy_route_trigger_rate_local(tbl, path_out)
    groups = unique(string(tbl.group), 'stable');
    vals = zeros(numel(groups), 3);
    for ig = 1:numel(groups)
        mask = string(tbl.group) == groups(ig);
        vals(ig, 1) = mean(tbl.heavy_route_trigger_rate(mask), 'omitnan');
        vals(ig, 2) = mean(tbl.music2d_trigger_rate(mask), 'omitnan');
        vals(ig, 3) = mean(tbl.pair_local_trigger_rate(mask), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('trigger rate');
    title('Cascade heavy-route trigger rate');
    legend({'heavy route', '2D MUSIC', 'pair-local'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_cascade_false_high_and_low_confidence_local(tbl, path_out)
    groups = unique(string(tbl.group), 'stable');
    vals = zeros(numel(groups), 3);
    for ig = 1:numel(groups)
        mask = string(tbl.group) == groups(ig);
        vals(ig, 1) = mean(tbl.false_high_confidence_rate(mask), 'omitnan');
        vals(ig, 2) = mean(tbl.low_confidence_rate(mask), 'omitnan');
        vals(ig, 3) = mean(tbl.boundary_missed_rate(mask), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('rate');
    title('Cascade false-high and low-confidence');
    legend({'false high', 'low confidence', 'boundary missed'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function write_cascade_record_doc_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, Metkl)
    fid = fopen(record_doc_path, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# Step 8.7 Part 7: budget-aware cascade early-stop runtime dispatch\n\n');
    fprintf(fid, '## Scope\n\n');
    fprintf(fid, '- Script: `space_smooth_music_B_cylindrical_level3_cascade_dispatch_runtime.m`\n');
    fprintf(fid, '- Result dir: `results_step8_7_7_cascade_dispatch_runtime/`\n');
    fprintf(fid, '- Scenario set: reused from part 6B without adding new combinations.\n');
    fprintf(fid, '- Monte Carlo: Metkl=%d, SNR=[0,8,16], T_snap=260.\n', Metkl);
    fprintf(fid, '- Goal: compare full 6B observable dispatch against a cascade runtime with early-stop and estimated route cost.\n\n');

    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.3f | %s |\n', keypoints_tbl.keypoint{i}, keypoints_tbl.value(i), keypoints_tbl.note{i});
    end

    cascade_success = keypoint_value_local(keypoints_tbl, 'cascade_dispatch_success_all');
    saved_full = keypoint_value_local(keypoints_tbl, 'saved_full6b_success_all');
    gap = keypoint_value_local(keypoints_tbl, 'cascade_vs_saved_full_gap_all');
    false_high = keypoint_value_local(keypoints_tbl, 'false_high_confidence_rate_all');
    boundary_missed = keypoint_value_local(keypoints_tbl, 'boundary_missed_rate_all');
    low_conf = keypoint_value_local(keypoints_tbl, 'low_confidence_rate_all');
    mean_routes = keypoint_value_local(keypoints_tbl, 'mean_routes_evaluated_all');
    cost_reduction = keypoint_value_local(keypoints_tbl, 'cost_reduction_vs_full_dispatch_all');
    music2d_rate = keypoint_value_local(keypoints_tbl, 'music2d_trigger_rate_all');
    pair_rate = keypoint_value_local(keypoints_tbl, 'pair_local_trigger_rate_all');

    fprintf(fid, '\n## Judgment\n\n');
    fprintf(fid, '- Saved full 6B success: %.3f\n', saved_full);
    fprintf(fid, '- Cascade success: %.3f\n', cascade_success);
    fprintf(fid, '- Cascade minus saved full gap: %.3f\n', gap);
    fprintf(fid, '- False-high-confidence rate: %.3f\n', false_high);
    fprintf(fid, '- Boundary-missed rate: %.3f\n', boundary_missed);
    fprintf(fid, '- Low-confidence rate: %.3f\n', low_conf);
    fprintf(fid, '- Mean routes evaluated: %.3f\n', mean_routes);
    fprintf(fid, '- Estimated cost reduction: %.3f\n', cost_reduction);
    fprintf(fid, '- 2D MUSIC trigger rate: %.3f\n', music2d_rate);
    fprintf(fid, '- Pair-local trigger rate: %.3f\n\n', pair_rate);

    if cascade_success >= saved_full - 0.05 && false_high <= 0.05 && boundary_missed <= 0.05 && cost_reduction >= 0.30
        fprintf(fid, 'Cascade dispatch is close to the 6B full observable baseline while achieving meaningful estimated cost reduction. It can be treated as the current runtime prototype.\n\n');
    elseif false_high <= 0.05 && cost_reduction >= 0.20
        fprintf(fid, 'Cascade dispatch is conservative and runtime-friendly. Coverage is lower than the full 6B rule set, but the safety profile is acceptable.\n\n');
    elseif false_high > 0.05
        fprintf(fid, 'False-high-confidence remains too large for a runtime interface. The early-stop gates still need tightening.\n\n');
    else
        fprintf(fid, 'Cascade dispatch does not yet show enough runtime value relative to the full rule set.\n\n');
    end

    fprintf(fid, '## Output\n\n');
    fprintf(fid, '- Result dir: `%s`\n', result_dir);
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
end

function [result, timing] = run_full_route_wallclock_local( ...
    y_noisy_2d, sc, X3d, Y3d, Z3d, A_ref_2d, lambda, ...
    az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, ...
    Lc, level2_cache_map, level2_refocus_cache_map, music_cache, p_sel, r_sel, theta_true, ...
    min_pair_sep_deg, max_pair_sep_deg)
    timing = init_wallclock_timing_local();
    t_all = tic;

    t0 = tic;
    music = run_level2_music_route_local( ...
        y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, sc.el_assumed, az_grid, K_phi_level2, Lc);
    timing.t_level2_music = toc(t0);
    timing.executed_level2_music = true;

    t0 = tic;
    rank1 = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, sc.el_assumed, level2_cache_map, az_grid, K_phi_level2, ...
        theta_true, min_pair_sep_deg, max_pair_sep_deg);
    timing.t_level2_rank1 = toc(t0);
    timing.executed_level2_rank1 = true;

    t0 = tic;
    refocus = run_common_el_refocus_power_route_local( ...
        y_noisy_2d, Z3d, lambda, el_refocus_grid, level2_refocus_cache_map, az_grid, K_phi_level2, ...
        theta_true, min_pair_sep_deg, max_pair_sep_deg);
    timing.t_refocus = toc(t0);
    timing.executed_refocus = true;

    t0 = tic;
    Rfb_2d = level3_fbss_cov_from_observation_local(y_noisy_2d, K_phi_music, K_z_music);
    music2d = run_level3_2d_music_route_local(Rfb_2d, music_cache, Lc);
    timing.t_2dmusic = toc(t0);
    timing.executed_2dmusic = true;

    pair_available = music2d.peak_count >= 2 && all(isfinite(music2d.az_est)) && all(isfinite(music2d.el_est));
    if pair_available
        t0 = tic;
        Rfb_pair = level3_fbss_cov_selected_from_observation_local(y_noisy_2d, K_phi_covfit, K_z_covfit, p_sel, r_sel);
        pair2d = run_level3_pair_el_local_rank1_covfit_local( ...
            Rfb_pair, music2d, X3d, Y3d, Z3d, A_ref_2d, lambda, K_phi_covfit, K_z_covfit, ...
            p_sel, r_sel, theta_true, sc.el_true, min_pair_sep_deg, max_pair_sep_deg);
        timing.t_pair_local = toc(t0);
        timing.executed_pair_local = true;
    else
        pair2d = make_empty_route_result_local("pair_local_not_available");
        pair2d.peak_count = music2d.peak_count;
    end

    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    t0 = tic;
    result = apply_observable_dispatch_rule_local(route_map, min_pair_sep_deg, max_pair_sep_deg);
    timing.t_dispatch = toc(t0);
    timing.t_total = toc(t_all);
    timing.executed_stage_count = double(timing.executed_level2_music) + double(timing.executed_refocus) + ...
        double(timing.executed_level2_rank1) + double(timing.executed_2dmusic) + double(timing.executed_pair_local);
    timing.early_stop_stage = 0;
    timing.early_stop_flag = false;
    timing.route_map = route_map;
end

function [result, timing] = run_lazy_cascade_wallclock_local( ...
    y_noisy_2d, sc, X3d, Y3d, Z3d, A_ref_2d, lambda, ...
    az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, ...
    Lc, level2_cache_map, level2_refocus_cache_map, music_cache, p_sel, r_sel, theta_true, ...
    min_pair_sep_deg, max_pair_sep_deg)
    timing = init_wallclock_timing_local();
    t_all = tic;

    empty_result = make_empty_route_result_local("not_executed");
    music = empty_result;
    rank1 = empty_result;
    refocus = empty_result;
    music2d = empty_result;
    pair2d = empty_result;

    t0 = tic;
    music = run_level2_music_route_local( ...
        y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, sc.el_assumed, az_grid, K_phi_level2, Lc);
    timing.t_level2_music = toc(t0);
    timing.executed_level2_music = true;

    t0 = tic;
    refocus = run_common_el_refocus_power_route_local( ...
        y_noisy_2d, Z3d, lambda, el_refocus_grid, level2_refocus_cache_map, az_grid, K_phi_level2, ...
        theta_true, min_pair_sep_deg, max_pair_sep_deg);
    timing.t_refocus = toc(t0);
    timing.executed_refocus = true;

    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    common_el_proxy = is_strong_common_el_proxy_local(music, refocus);
    low_cost_boundary_partial = is_low_cost_boundary_proxy_from_partial_local( ...
        music, rank1, refocus, min_pair_sep_deg, max_pair_sep_deg);

    if is_level2_music_reliable_local(music, min_pair_sep_deg, max_pair_sep_deg) && common_el_proxy
        result = music;
        result.recommended_route = "level2_music_or_center_real";
        if is_level2_music_high_confidence_local(music, route_map, min_pair_sep_deg, max_pair_sep_deg)
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "ok";
        timing = finish_lazy_timing_local(timing, t_all, 1, true, route_map);
        return
    end

    if is_refocus_route_reliable_local(refocus, min_pair_sep_deg, max_pair_sep_deg) && ...
            ~low_cost_boundary_partial && common_el_proxy
        result = refocus;
        result.recommended_route = "common_el_refocus_power_rank1";
        result.confidence_flag = "medium";
        result.failure_reason = "ok";
        timing = finish_lazy_timing_local(timing, t_all, 2, true, route_map);
        return
    end

    t0 = tic;
    rank1 = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, sc.el_assumed, level2_cache_map, az_grid, K_phi_level2, ...
        theta_true, min_pair_sep_deg, max_pair_sep_deg);
    timing.t_level2_rank1 = toc(t0);
    timing.executed_level2_rank1 = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    low_cost_boundary = is_low_cost_boundary_proxy_from_partial_local( ...
        music, rank1, refocus, min_pair_sep_deg, max_pair_sep_deg);

    if is_rank1_route_reliable_local(rank1, min_pair_sep_deg, max_pair_sep_deg) && ...
            ~low_cost_boundary && common_el_proxy
        result = rank1;
        result.recommended_route = "level2_rank1_fallback";
        result.confidence_flag = "medium";
        result.failure_reason = "music_single_rank1_fallback";
        timing = finish_lazy_timing_local(timing, t_all, 3, true, route_map);
        return
    end

    t0 = tic;
    Rfb_2d = level3_fbss_cov_from_observation_local(y_noisy_2d, K_phi_music, K_z_music);
    music2d = run_level3_2d_music_route_local(Rfb_2d, music_cache, Lc);
    timing.t_2dmusic = toc(t0);
    timing.executed_2dmusic = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);

    if is_music2d_reliable_local(music2d, min_pair_sep_deg, max_pair_sep_deg)
        pair_available = music2d.peak_count >= 2 && all(isfinite(music2d.az_est)) && all(isfinite(music2d.el_est));
        if pair_available && is_cascade_pair_refinement_needed_local(music2d, min_pair_sep_deg, max_pair_sep_deg)
            t0 = tic;
            Rfb_pair = level3_fbss_cov_selected_from_observation_local(y_noisy_2d, K_phi_covfit, K_z_covfit, p_sel, r_sel);
            pair2d = run_level3_pair_el_local_rank1_covfit_local( ...
                Rfb_pair, music2d, X3d, Y3d, Z3d, A_ref_2d, lambda, K_phi_covfit, K_z_covfit, ...
                p_sel, r_sel, theta_true, sc.el_true, min_pair_sep_deg, max_pair_sep_deg);
            timing.t_pair_local = toc(t0);
            timing.executed_pair_local = true;
            route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
            if is_pair_route_reliable_local(pair2d, min_pair_sep_deg, max_pair_sep_deg)
                result = pair2d;
                result.recommended_route = "pair_el_local_covfit";
                result.confidence_flag = "medium";
                result.failure_reason = "ok";
                timing = finish_lazy_timing_local(timing, t_all, 5, true, route_map);
                return
            end
        end
        result = music2d;
        result.recommended_route = "level3_2d_music";
        result.confidence_flag = "medium";
        if timing.executed_pair_local
            result.failure_reason = "pair_local_not_reliable";
        else
            result.failure_reason = "ok";
        end
        timing = finish_lazy_timing_local(timing, t_all, 4, true, route_map);
        return
    end

    if is_boundary_unreliable_local(route_map, min_pair_sep_deg, max_pair_sep_deg) || low_cost_boundary
        result = make_boundary_result_local(route_map, 'boundary_unreliable', 'low', 'boundary_unreliable', false, false);
    else
        result = make_boundary_result_local(route_map, 'low_confidence', 'low', 'no_reliable_observable_route', false, false);
    end
    timing = finish_lazy_timing_local(timing, t_all, 6, false, route_map);
end

function timing = init_wallclock_timing_local()
    timing = struct();
    timing.t_level2_music = 0;
    timing.t_level2_rank1 = 0;
    timing.t_refocus = 0;
    timing.t_2dmusic = 0;
    timing.t_pair_local = 0;
    timing.t_dispatch = 0;
    timing.t_total = 0;
    timing.executed_level2_music = false;
    timing.executed_refocus = false;
    timing.executed_level2_rank1 = false;
    timing.executed_2dmusic = false;
    timing.executed_pair_local = false;
    timing.executed_stage_count = 0;
    timing.early_stop_stage = NaN;
    timing.early_stop_flag = false;
    timing.route_map = struct();
end

function timing = finish_lazy_timing_local(timing, t_all, early_stop_stage, early_stop_flag, route_map)
    timing.t_total = toc(t_all);
    timing.executed_stage_count = double(timing.executed_level2_music) + double(timing.executed_refocus) + ...
        double(timing.executed_level2_rank1) + double(timing.executed_2dmusic) + double(timing.executed_pair_local);
    timing.early_stop_stage = early_stop_stage;
    timing.early_stop_flag = early_stop_flag;
    timing.route_map = route_map;
end

function route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d)
    route_map = struct();
    route_map.music = music;
    route_map.rank1_fallback = rank1;
    route_map.common_el_refocus_rank1 = refocus;
    route_map.level3_2d_music = music2d;
    route_map.pair_el_local_covfit = pair2d;
end

function result = make_empty_route_result_local(reason)
    result = make_result_local([NaN, NaN], [NaN, NaN], 0, NaN, NaN, reason);
    result.recommended_route = "";
    result.confidence_flag = "";
    result.failure_reason = reason;
end

function row = make_lazy_trial_row_local(sc, imc, full_result, lazy_result, ...
    full_success, lazy_success, lazy_false_high, lazy_false_medium_high, lazy_boundary_missed, ...
    full_time, lazy_time, runtime_speedup, runtime_reduction)
    full_route = string(getfield_default_local(full_result, 'recommended_route', ""));
    lazy_route = string(getfield_default_local(lazy_result, 'recommended_route', ""));
    lazy_conf = string(getfield_default_local(lazy_result, 'confidence_flag', ""));
    lazy_reason = string(getfield_default_local(lazy_result, 'failure_reason', ""));
    row = { ...
        string(sc.group), string(sc.case_name), sc.snr_db, imc, ...
        full_route, lazy_route, full_success, lazy_success, strcmp(full_route, lazy_route), ...
        lazy_false_high, lazy_false_medium_high, lazy_boundary_missed, ...
        strcmp(lazy_conf, "low") || any(strcmp(lazy_route, ["low_confidence", "boundary_unreliable"])), ...
        strcmp(lazy_route, "boundary_unreliable"), ...
        full_time.t_total, lazy_time.t_total, runtime_speedup, runtime_reduction, ...
        full_time.t_level2_music, full_time.t_level2_rank1, full_time.t_refocus, full_time.t_2dmusic, full_time.t_pair_local, full_time.t_dispatch, ...
        lazy_time.t_level2_music, lazy_time.t_refocus, lazy_time.t_level2_rank1, lazy_time.t_2dmusic, lazy_time.t_pair_local, ...
        double(lazy_time.executed_level2_music), double(lazy_time.executed_refocus), ...
        double(lazy_time.executed_level2_rank1), double(lazy_time.executed_2dmusic), double(lazy_time.executed_pair_local), ...
        lazy_time.executed_stage_count, lazy_time.early_stop_stage, double(lazy_time.early_stop_flag), ...
        lazy_conf, lazy_reason};
end

function names = lazy_trial_var_names_local()
    names = { ...
        'group', 'case_name', 'SNR', 'mc', ...
        'full_route', 'lazy_route', 'full_success', 'lazy_success', 'route_agreement_full_vs_lazy', ...
        'lazy_false_high_confidence', 'lazy_false_medium_high_confidence', 'lazy_boundary_missed', ...
        'lazy_low_confidence', 'lazy_boundary_unreliable', ...
        'full_runtime_sec', 'lazy_runtime_sec', 'runtime_speedup', 'runtime_reduction', ...
        'full_t_level2_music', 'full_t_level2_rank1', 'full_t_refocus', 'full_t_2dmusic', 'full_t_pair_local', 'full_t_dispatch', ...
        'lazy_t_level2_music', 'lazy_t_refocus', 'lazy_t_level2_rank1', 'lazy_t_2dmusic', 'lazy_t_pair_local', ...
        'executed_level2_music', 'executed_refocus', 'executed_level2_rank1', 'executed_2dmusic', 'executed_pair_local', ...
        'executed_stage_count', 'early_stop_stage', 'early_stop_flag', ...
        'confidence_flag', 'failure_reason'};
end

function summary_tbl = build_lazy_summary_table_local(trial_tbl)
    rows = {};
    rows{end+1, 1} = make_lazy_summary_row_local(trial_tbl, true(height(trial_tbl), 1), "overall", "all", "all", NaN);

    groups = unique(string(trial_tbl.group), 'stable');
    for ig = 1:numel(groups)
        mask = string(trial_tbl.group) == groups(ig);
        rows{end+1, 1} = make_lazy_summary_row_local(trial_tbl, mask, "group", groups(ig), "all", NaN); %#ok<AGROW>
    end

    for ig = 1:numel(groups)
        g = groups(ig);
        group_mask = string(trial_tbl.group) == g;
        cases = unique(string(trial_tbl.case_name(group_mask)), 'stable');
        for ic = 1:numel(cases)
            c = cases(ic);
            case_mask = group_mask & string(trial_tbl.case_name) == c;
            snrs = unique(trial_tbl.SNR(case_mask));
            for is = 1:numel(snrs)
                mask = case_mask & trial_tbl.SNR == snrs(is);
                rows{end+1, 1} = make_lazy_summary_row_local(trial_tbl, mask, "scenario_snr", g, c, snrs(is)); %#ok<AGROW>
            end
        end
    end

    summary_tbl = cell2table(vertcat(rows{:}), 'VariableNames', lazy_summary_var_names_local());
end

function row = make_lazy_summary_row_local(tbl, mask, level, group_name, case_name, snr_val)
    full_runtime = tbl.full_runtime_sec(mask);
    lazy_runtime = tbl.lazy_runtime_sec(mask);
    speedup = tbl.runtime_speedup(mask);
    reduction = tbl.runtime_reduction(mask);
    early_stage = tbl.early_stop_stage(mask);
    lazy_route = string(tbl.lazy_route(mask));
    failure_reason = string(tbl.failure_reason(mask));
    row = { ...
        string(level), string(group_name), string(case_name), snr_val, sum(mask), ...
        mean(tbl.full_success(mask), 'omitnan'), mean(tbl.lazy_success(mask), 'omitnan'), ...
        mean(tbl.lazy_success(mask), 'omitnan') - mean(tbl.full_success(mask), 'omitnan'), ...
        mean(tbl.route_agreement_full_vs_lazy(mask), 'omitnan'), ...
        mean(tbl.lazy_false_high_confidence(mask), 'omitnan'), ...
        mean(tbl.lazy_false_medium_high_confidence(mask), 'omitnan'), ...
        mean(tbl.lazy_boundary_missed(mask), 'omitnan'), ...
        mean(tbl.lazy_low_confidence(mask), 'omitnan'), ...
        mean(tbl.lazy_boundary_unreliable(mask), 'omitnan'), ...
        mean(full_runtime, 'omitnan'), median(full_runtime, 'omitnan'), percentile_no_toolbox_local(full_runtime, 90), percentile_no_toolbox_local(full_runtime, 95), ...
        mean(lazy_runtime, 'omitnan'), median(lazy_runtime, 'omitnan'), percentile_no_toolbox_local(lazy_runtime, 90), percentile_no_toolbox_local(lazy_runtime, 95), ...
        mean(speedup, 'omitnan'), median(speedup, 'omitnan'), percentile_no_toolbox_local(speedup, 90), ...
        mean(reduction, 'omitnan'), ...
        mean(tbl.executed_stage_count(mask), 'omitnan'), ...
        mean(tbl.executed_level2_music(mask), 'omitnan'), ...
        mean(tbl.executed_refocus(mask), 'omitnan'), ...
        mean(tbl.executed_level2_rank1(mask), 'omitnan'), ...
        mean(tbl.executed_2dmusic(mask), 'omitnan'), ...
        mean(tbl.executed_pair_local(mask), 'omitnan'), ...
        mean(tbl.early_stop_flag(mask), 'omitnan'), ...
        mean(tbl.executed_2dmusic(mask), 'omitnan'), ...
        mean(tbl.executed_pair_local(mask), 'omitnan'), ...
        mean(early_stage == 1, 'omitnan'), mean(early_stage == 2, 'omitnan'), mean(early_stage == 3, 'omitnan'), ...
        mean(early_stage == 4, 'omitnan'), mean(early_stage == 5, 'omitnan'), mean(early_stage == 6, 'omitnan'), ...
        mode_string_local_nonempty(lazy_route), mode_string_local_nonempty(failure_reason)};
end

function names = lazy_summary_var_names_local()
    names = { ...
        'summary_level', 'group', 'case_name', 'SNR', 'num_trials', ...
        'full_success_rate', 'lazy_success_rate', 'lazy_vs_full_success_gap', ...
        'route_agreement_full_vs_lazy', ...
        'lazy_false_high_confidence_rate', 'lazy_false_medium_high_confidence_rate', ...
        'lazy_boundary_missed_rate', 'lazy_low_confidence_rate', 'lazy_boundary_unreliable_rate', ...
        'mean_full_runtime_sec', 'median_full_runtime_sec', 'p90_full_runtime_sec', 'p95_full_runtime_sec', ...
        'mean_lazy_runtime_sec', 'median_lazy_runtime_sec', 'p90_lazy_runtime_sec', 'p95_lazy_runtime_sec', ...
        'mean_runtime_speedup', 'median_runtime_speedup', 'p90_runtime_speedup', ...
        'mean_runtime_reduction', 'mean_executed_stage_count', ...
        'execution_rate_level2_music', 'execution_rate_refocus', 'execution_rate_level2_rank1', ...
        'execution_rate_2dmusic', 'execution_rate_pair_local', ...
        'early_stop_rate', 'heavy_route_trigger_rate', 'pair_local_trigger_rate', ...
        'early_stop_stage1_rate', 'early_stop_stage2_rate', 'early_stop_stage3_rate', ...
        'early_stop_stage4_rate', 'early_stop_stage5_rate', 'early_stop_stage6_rate', ...
        'main_lazy_route', 'main_failure_reason'};
end

function keypoints = build_lazy_keypoints_local(summary_tbl, trial_tbl, part7_keypoints_tbl, part6b_keypoints_tbl)
    rows = {};
    rows = add_keypoint_row_local(rows, 'part7_cascade_success_all', keypoint_value_local(part7_keypoints_tbl, 'cascade_dispatch_success_all'), 'part-7 estimated cascade success');
    rows = add_keypoint_row_local(rows, 'part7_estimated_cost_reduction_all', keypoint_value_local(part7_keypoints_tbl, 'cost_reduction_vs_full_dispatch_all'), 'part-7 estimated cost reduction');
    rows = add_keypoint_row_local(rows, 'part7_music2d_trigger_rate_all', keypoint_value_local(part7_keypoints_tbl, 'music2d_trigger_rate_all'), 'part-7 estimated 2D MUSIC trigger rate');
    rows = add_keypoint_row_local(rows, 'part7_pair_local_trigger_rate_all', keypoint_value_local(part7_keypoints_tbl, 'pair_local_trigger_rate_all'), 'part-7 estimated pair-local trigger rate');
    rows = add_keypoint_row_local(rows, 'part6b_observable_success_all', keypoint_value_local(part6b_keypoints_tbl, 'observable_dispatch_success_all'), 'saved part-6B observable success');

    ov = summary_tbl(string(summary_tbl.summary_level) == "overall", :);
    metric_names = { ...
        'full_success_rate', 'lazy_success_rate', 'lazy_vs_full_success_gap', ...
        'route_agreement_full_vs_lazy', 'lazy_false_high_confidence_rate', ...
        'lazy_false_medium_high_confidence_rate', 'lazy_boundary_missed_rate', ...
        'lazy_low_confidence_rate', 'lazy_boundary_unreliable_rate', ...
        'mean_full_runtime_sec', 'median_full_runtime_sec', 'p90_full_runtime_sec', 'p95_full_runtime_sec', ...
        'mean_lazy_runtime_sec', 'median_lazy_runtime_sec', 'p90_lazy_runtime_sec', 'p95_lazy_runtime_sec', ...
        'mean_runtime_speedup', 'median_runtime_speedup', 'p90_runtime_speedup', ...
        'mean_runtime_reduction', 'mean_executed_stage_count', ...
        'execution_rate_level2_music', 'execution_rate_refocus', 'execution_rate_level2_rank1', ...
        'execution_rate_2dmusic', 'execution_rate_pair_local', 'early_stop_rate', ...
        'heavy_route_trigger_rate', 'pair_local_trigger_rate', ...
        'early_stop_stage1_rate', 'early_stop_stage2_rate', 'early_stop_stage3_rate', ...
        'early_stop_stage4_rate', 'early_stop_stage5_rate', 'early_stop_stage6_rate'};
    for i = 1:numel(metric_names)
        rows = add_keypoint_row_local(rows, metric_names{i} + "_all", ov.(metric_names{i})(1), "overall " + metric_names{i});
    end

    groups = unique(string(trial_tbl.group), 'stable');
    for ig = 1:numel(groups)
        g = groups(ig);
        row = summary_tbl(string(summary_tbl.summary_level) == "group" & string(summary_tbl.group) == g, :);
        if isempty(row)
            continue
        end
        prefix = matlab.lang.makeValidName(char(g));
        rows = add_keypoint_row_local(rows, prefix + "_lazy_success_rate", row.lazy_success_rate(1), "group lazy success");
        rows = add_keypoint_row_local(rows, prefix + "_mean_lazy_runtime_sec", row.mean_lazy_runtime_sec(1), "group mean lazy runtime");
        rows = add_keypoint_row_local(rows, prefix + "_mean_runtime_speedup", row.mean_runtime_speedup(1), "group mean runtime speedup");
        rows = add_keypoint_row_local(rows, prefix + "_execution_rate_2dmusic", row.execution_rate_2dmusic(1), "group 2D MUSIC execution rate");
        rows = add_keypoint_row_local(rows, prefix + "_execution_rate_pair_local", row.execution_rate_pair_local(1), "group pair-local execution rate");
        rows = add_keypoint_row_local(rows, prefix + "_false_high_rate", row.lazy_false_high_confidence_rate(1), "group false-high rate");
        rows = add_keypoint_row_local(rows, prefix + "_low_confidence_rate", row.lazy_low_confidence_rate(1), "group low-confidence rate");
    end
    keypoints = cell2table(vertcat(rows{:}), 'VariableNames', {'keypoint', 'value', 'note'});
end

function rows = add_keypoint_row_local(rows, key, val, note)
    rows{end+1, 1} = {string(key), val, string(note)};
end

function p = percentile_no_toolbox_local(x, pct)
    x = sort(x(isfinite(x)));
    if isempty(x)
        p = NaN;
        return
    end
    if numel(x) == 1
        p = x(1);
        return
    end
    pos = 1 + (numel(x) - 1) * pct / 100;
    lo = floor(pos);
    hi = ceil(pos);
    if lo == hi
        p = x(lo);
    else
        p = x(lo) + (x(hi) - x(lo)) * (pos - lo);
    end
end

function plot_lazy_vs_full_runtime_boxplot_local(trial_tbl, path_out)
    fig = figure('Visible', 'off');
    data = [trial_tbl.full_runtime_sec; trial_tbl.lazy_runtime_sec];
    grp = [repmat("full", height(trial_tbl), 1); repmat("lazy", height(trial_tbl), 1)];
    boxplot(data, grp);
    grid on
    ylabel('runtime (sec)');
    title('Lazy vs full route wall-clock runtime');
    saveas(fig, path_out);
    close(fig);
end

function plot_runtime_speedup_by_group_local(summary_tbl, path_out)
    tbl = summary_tbl(string(summary_tbl.summary_level) == "group", :);
    fig = figure('Visible', 'off');
    bar(tbl.mean_runtime_speedup);
    grid on
    set(gca, 'XTick', 1:height(tbl), 'XTickLabel', cellstr(string(tbl.group)), 'XTickLabelRotation', 20);
    ylabel('full / lazy runtime');
    title('Mean runtime speedup by group');
    saveas(fig, path_out);
    close(fig);
end

function plot_lazy_success_vs_full_success_local(summary_tbl, path_out)
    tbl = summary_tbl(string(summary_tbl.summary_level) == "group", :);
    vals = [tbl.full_success_rate, tbl.lazy_success_rate];
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(tbl), 'XTickLabel', cellstr(string(tbl.group)), 'XTickLabelRotation', 20);
    ylabel('success rate');
    title('Lazy success vs full observable dispatch');
    legend({'full route', 'lazy cascade'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_execution_rate_by_stage_local(summary_tbl, path_out)
    ov = summary_tbl(string(summary_tbl.summary_level) == "overall", :);
    vals = [ov.execution_rate_level2_music, ov.execution_rate_refocus, ov.execution_rate_level2_rank1, ...
        ov.execution_rate_2dmusic, ov.execution_rate_pair_local];
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:5, 'XTickLabel', {'L2 MUSIC', 'refocus', 'L2 rank1', '2D MUSIC', 'pair local'}, 'XTickLabelRotation', 20);
    ylabel('execution rate');
    title('Lazy execution rate by stage');
    saveas(fig, path_out);
    close(fig);
end

function plot_early_stop_stage_distribution_local(trial_tbl, path_out)
    stages = 1:6;
    vals = zeros(size(stages));
    for i = 1:numel(stages)
        vals(i) = mean(trial_tbl.early_stop_stage == stages(i), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:6, 'XTickLabel', {'1 L2', '2 refocus', '3 rank1', '4 2D', '5 pair', '6 low'});
    ylabel('rate');
    title('Early-stop stage distribution');
    saveas(fig, path_out);
    close(fig);
end

function plot_runtime_vs_route_used_local(trial_tbl, path_out)
    routes = unique(string(trial_tbl.lazy_route), 'stable');
    vals = nan(numel(routes), 1);
    for i = 1:numel(routes)
        vals(i) = mean(trial_tbl.lazy_runtime_sec(string(trial_tbl.lazy_route) == routes(i)), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    set(gca, 'XTick', 1:numel(routes), 'XTickLabel', cellstr(routes), 'XTickLabelRotation', 25);
    ylabel('mean lazy runtime (sec)');
    title('Runtime by lazy route');
    saveas(fig, path_out);
    close(fig);
end

function write_lazy_record_doc_local(record_doc_path, keypoints_tbl, result_dir, elapsed_sec, Metkl, quick_mode)
    fid = fopen(record_doc_path, 'w', 'n', 'UTF-8');
    if fid < 0
        fid = fopen(record_doc_path, 'w');
    end
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.7步 7B 真实lazy级联运行时间验证记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 脚本：`space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m`\n');
    fprintf(fid, '- 短名 runner：`space_smooth_music_B_cylindrical_level3_lazy_runtime.m`\n');
    [~, result_dir_name] = fileparts(result_dir);
    fprintf(fid, '- 结果目录：`%s/`\n', result_dir_name);
    fprintf(fid, '- 场景：复用第 6B/第 7 部分 reduced scenario set。\n');
    fprintf(fid, '- Monte Carlo：Metkl=%d，quick_mode=%d，SNR=[0,8,16]，T_snap=260。\n', Metkl, quick_mode);
    fprintf(fid, '- warm-up：正式统计前执行 1 个 warm-up trial，不计入 runtime 统计。\n');
    fprintf(fid, '- per-trial runtime 只统计算法 route 和 dispatch，不包含绘图、CSV/MAT 写盘。\n\n');
    fprintf(fid, '## 执行结构说明\n\n');
    fprintf(fid, '本轮实现了真实 lazy execution：若前序 gate 已经选定 route，后续未触发 route 的函数不调用，并在 trial CSV 中记录 executed_level2_music、executed_refocus、executed_level2_rank1、executed_2dmusic、executed_pair_local。\n\n');
    fprintf(fid, '为保持与第 7 部分一致，本脚本保留 common-el refocus 作为 level2/rank1 低成本早停的安全门控。因此 level2 MUSIC route 本身先计算，但其早停确认会在 refocus 诊断后进行；这避免大俯仰差场景被过早误分流到层次二。\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.6g | %s |\n', string(keypoints_tbl.keypoint(i)), keypoints_tbl.value(i), string(keypoints_tbl.note(i)));
    end

    full_success = keypoint_value_local(keypoints_tbl, 'full_success_rate_all');
    lazy_success = keypoint_value_local(keypoints_tbl, 'lazy_success_rate_all');
    gap = keypoint_value_local(keypoints_tbl, 'lazy_vs_full_success_gap_all');
    false_high = keypoint_value_local(keypoints_tbl, 'lazy_false_high_confidence_rate_all');
    boundary_missed = keypoint_value_local(keypoints_tbl, 'lazy_boundary_missed_rate_all');
    low_conf = keypoint_value_local(keypoints_tbl, 'lazy_low_confidence_rate_all');
    mean_reduction = keypoint_value_local(keypoints_tbl, 'mean_runtime_reduction_all');
    median_speedup = keypoint_value_local(keypoints_tbl, 'median_runtime_speedup_all');

    fprintf(fid, '\n## 判断\n\n');
    fprintf(fid, '- full-route success = %.3f\n', full_success);
    fprintf(fid, '- lazy cascade success = %.3f\n', lazy_success);
    fprintf(fid, '- lazy-full gap = %.3f\n', gap);
    fprintf(fid, '- false-high-confidence = %.3f\n', false_high);
    fprintf(fid, '- boundary-missed = %.3f\n', boundary_missed);
    fprintf(fid, '- low-confidence = %.3f\n', low_conf);
    fprintf(fid, '- mean runtime reduction = %.3f\n', mean_reduction);
    fprintf(fid, '- median runtime speedup = %.3f\n\n', median_speedup);

    if lazy_success >= full_success - 0.05 && false_high <= 0.05 && boundary_missed <= 0.05 && mean_reduction >= 0.30
        fprintf(fid, '结论：真实 lazy cascade 在保持成功率和安全指标的同时实现了明显 wall-clock runtime reduction，可作为工程 runtime 架构雏形。\n\n');
    elseif false_high <= 0.05 && boundary_missed <= 0.05 && mean_reduction < 0.20
        fprintf(fid, '结论：当前级联逻辑安全，但真实运行时间节省不明显，瓶颈可能在前置 route 或共享开销。\n\n');
    elseif mean_reduction >= 0.30 && lazy_success < full_success - 0.05
        fprintf(fid, '结论：lazy runtime 明显更快但成功率下降，早停过于激进，需要增加验证器或放宽后续 route 触发条件。\n\n');
    elseif false_high > 0.05
        fprintf(fid, '结论：lazy early-stop 仍存在不安全高置信误报，不应作为工程 runtime 接口。\n\n');
    else
        fprintf(fid, '结论：lazy cascade 需要结合成功率、安全性和实际 runtime reduction 继续调阈值。\n\n');
    end

    route_agree = keypoint_value_local(keypoints_tbl, 'route_agreement_full_vs_lazy_all');
    fprintf(fid, '## 补充观察\n\n');
    fprintf(fid, '- 与 full-route observable dispatch 的逐 trial route agreement = %.3f。主要差异来自 common-el 场景中 full dispatch 倾向选择 `common_el_refocus_power_rank1`，而 lazy gate 在部分样本中早停到 `level2_rank1_fallback`。二者成功率几乎一致，但 route 名称不完全一致。\n', route_agree);
    fprintf(fid, '- 最耗时场景集中在 large-el 组，特别是需要同时执行 2D MUSIC 与 pair-local 的代表 case；这些场景的 lazy runtime 接近 full-route baseline。\n');
    fprintf(fid, '- rho/beta/phase 的 common-el 组有明显 runtime reduction，原因是多数样本在 refocus/rank1/low-confidence 前已停止，不再触发 2D MUSIC 与 pair-local。\n\n');

    fprintf(fid, '## 输出\n\n');
    fprintf(fid, '- 结果目录：`%s`\n', result_dir);
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
end
