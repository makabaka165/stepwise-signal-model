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

result_dir = fullfile(script_dir, 'results_step8_7_5_general_model_dispatch_boundary');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_7_5_general_model_dispatch_boundary.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

record_doc_path = fullfile(script_dir, '第8.7步_5_一般源模型分流边界验证记录.md');
summary_csv_path = fullfile(result_dir, 'step8_7_5_general_model_dispatch_boundary_summary.csv');
keypoints_csv_path = fullfile(result_dir, 'step8_7_5_general_model_dispatch_boundary_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_7_5_general_model_dispatch_boundary_result.mat');

log_msg(fid_log, 'Step 08.7 part 5: general source model dispatch-boundary validation');
log_msg(fid_log, 'Scope: validate route dispatch rules under beta/phase/rho/elevation boundaries. No fullscan, no V2, no complex-gain q, no 4D search, no edits to step 8.6 or prior step 8.7 outputs.');

azCtr_deg = 0;
sep_factor = 10;
snr_list = [0, 8, 16];
Metkl = 50;
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
log_msg(fid_log, 'Run control: Metkl=%d, SNR=%s, T_snap=%d, sep_factor=%d.', ...
    Metkl, mat2str(snr_list), T_snap, sep_factor);
log_msg(fid_log, '2D MUSIC K=[%d,%d], pair-local covfit K=[%d,%d], refocus_el_grid=%d.', ...
    K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, numel(el_refocus_grid));

route_names = { ...
    'level2_music_or_center_real', ...
    'level2_rank1_fallback', ...
    'common_el_refocus_power_rank1', ...
    'level3_2d_music', ...
    'pair_el_local_covfit', ...
    'dispatch_recommended_route'};

level2_pair_candidates = make_pair_candidates_local(az_grid, min_pair_sep_deg, max_pair_sep_deg);
level2_cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_bank, K_phi_level2, level2_pair_candidates);
level2_refocus_cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_refocus_grid, K_phi_level2, level2_pair_candidates);
music_cache = make_level3_grid_cache_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_grid, K_phi_music, K_z_music);
[p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi_covfit, K_z_covfit);

scenarios = build_dispatch_scenarios_local(snr_list);
log_msg(fid_log, 'Scenario count=%d. Groups: rho scan, beta scan, phase scan, large elevation general cases.', numel(scenarios));

summary_rows = {};
trial_results = struct([]);
trial_count = 0;
stores = cell(numel(scenarios), 1);
for isc = 1:numel(scenarios)
    stores{isc} = init_route_trial_store_local(route_names, Metkl);
end

tic
for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    log_msg(fid_log, 'Scenario %02d/%02d group=%s case=%s SNR=%g beta=%.3g phase=%.1f rho=%.3g el=[%.1f %.1f].', ...
        isc, numel(scenarios), sc.group, sc.case_name, sc.snr_db, sc.beta, sc.phi_deg, sc.rho, sc.el_true(1), sc.el_true(2));
    s1_base = exp(1j * 2*pi * (0:T_snap-1) / 17);
    v_base = exp(1j * 2*pi * (0:T_snap-1) / 23 + 1j*pi/7);

    for imc = 1:Metkl
        rng(base_seed + isc * 1000 + imc);
        s1 = s1_base .* exp(1j * 2*pi * rand);
        v = v_base .* exp(1j * 2*pi * rand);
        y_clean_2d = make_clean_cylindrical_observations_general_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, theta_true(1), theta_true(2), ...
            sc.el_true(1), sc.el_true(2), sc.beta, sc.phi_deg, sc.rho, s1, v);
        y_noisy_2d = add_noise_local(y_clean_2d, sc.snr_db);

        r1_music_l2 = run_level2_music_route_local( ...
            y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, sc.el_assumed, ...
            az_grid, K_phi_level2, Lc);
        r2_rank1 = run_level2_rank1_route_local( ...
            y_noisy_2d, Z3d, cfg.arr.lambda, sc.el_assumed, level2_cache_map, az_grid, ...
            K_phi_level2, theta_true, min_pair_sep_deg, max_pair_sep_deg);
        if sc.common_el_flag
            r3_refocus = run_common_el_refocus_power_route_local( ...
                y_noisy_2d, Z3d, cfg.arr.lambda, el_refocus_grid, level2_refocus_cache_map, az_grid, ...
                K_phi_level2, theta_true, min_pair_sep_deg, max_pair_sep_deg);
        else
            r3_refocus = make_result_local([NaN, NaN], [NaN, NaN], NaN, NaN, NaN, 'not_common_el_case');
        end
        if sc.large_el_flag
            R2d_music = level3_fbss_cov_from_observation_local(y_noisy_2d, K_phi_music, K_z_music);
            r4_2dmusic = run_level3_2d_music_route_local(R2d_music, music_cache, Lc);
            R2d_covfit = level3_fbss_cov_selected_from_observation_local(y_noisy_2d, K_phi_covfit, K_z_covfit, p_sel, r_sel);
            r5_pair = run_level3_pair_el_local_rank1_covfit_local( ...
                R2d_covfit, r4_2dmusic, X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, ...
                K_phi_covfit, K_z_covfit, p_sel, r_sel, theta_true, sc.el_true, min_pair_sep_deg, max_pair_sep_deg);
        else
            r4_2dmusic = make_result_local([NaN, NaN], [NaN, NaN], NaN, NaN, NaN, 'not_large_el_case');
            r5_pair = make_result_local([NaN, NaN], [NaN, NaN], r4_2dmusic.peak_count, NaN, NaN, 'not_large_el_case');
        end
        route_map = struct( ...
            'music', r1_music_l2, ...
            'rank1_fallback', r2_rank1, ...
            'common_el_refocus_rank1', r3_refocus, ...
            'level3_2d_music', r4_2dmusic, ...
            'pair_el_local_covfit', r5_pair);
        r6_dispatch = apply_dispatch_rule_local(sc, route_map);
        route_results = {r1_music_l2, r2_rank1, r3_refocus, r4_2dmusic, r5_pair, r6_dispatch};
        for ir = 1:numel(route_names)
            stores{isc} = store_route_trial_local(stores{isc}, ir, imc, ...
                route_results{ir}, theta_true, sc.el_true, az_tol_deg, el_tol_deg);
        end

        trial_count = trial_count + 1;
        trial_results(trial_count).scenario = sc; %#ok<SAGROW>
        trial_results(trial_count).mc = imc;
        trial_results(trial_count).route_results = route_results;
    end
end

for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    for ir = 1:numel(route_names)
        metrics = summarize_route_trials_local(stores{isc}(ir));
        summary_rows(end+1, :) = make_summary_row_local(sc, route_names{ir}, metrics); %#ok<AGROW>
        log_msg(fid_log, 'group=%-8s case=%-18s SNR=%g route=%-32s joint=%.3f rec_success=%.3f weak=%.3f anti=%.3f low=%.3f peak=%.2f reason=%s', ...
            sc.group, sc.case_name, sc.snr_db, route_names{ir}, metrics.joint_tol_success_rate, ...
            metrics.recommended_route_success_rate, metrics.weak_target_boundary_rate, ...
            metrics.anti_phase_boundary_rate, metrics.low_confidence_rate, ...
            metrics.peak_count_mean, metrics.route_failure_reason);
    end
end
elapsed_sec = toc;
log_msg(fid_log, 'Finished in %.2f sec.', elapsed_sec);

summary_tbl = cell2table(summary_rows, 'VariableNames', summary_var_names_local());
writetable(summary_tbl, summary_csv_path);
keypoints_tbl = build_keypoints_local(summary_tbl);
writetable(keypoints_tbl, keypoints_csv_path);

plot_dispatch_rho_scan_routes_local(summary_tbl, fullfile(result_dir, 'dispatch_rho_scan_routes.png'));
plot_dispatch_beta_scan_boundaries_local(summary_tbl, fullfile(result_dir, 'dispatch_beta_scan_boundaries.png'));
plot_dispatch_phase_scan_boundaries_local(summary_tbl, fullfile(result_dir, 'dispatch_phase_scan_boundaries.png'));
plot_dispatch_large_el_cases_local(summary_tbl, fullfile(result_dir, 'dispatch_large_el_general_cases.png'));
plot_dispatch_recommended_success_local(summary_tbl, fullfile(result_dir, 'dispatch_recommended_route_success.png'));

save(mat_path, 'summary_tbl', 'keypoints_tbl', 'route_names', ...
    'az_grid', 'el_grid', 'el_refocus_grid', 'el_bank', 'theta_true', 'theta_sep', ...
    'K_phi_level2', 'K_phi_music', 'K_z_music', 'K_phi_covfit', 'K_z_covfit', ...
    'p_sel', 'r_sel', 'cfg', '-v7.3');

write_record_doc_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, Metkl);
log_msg(fid_log, 'Outputs written to %s', result_dir);

function scenarios = build_dispatch_scenarios_local(snr_list)
    scenarios = repmat(make_dispatch_scenario_local('', '', NaN, [NaN, NaN], NaN, NaN, NaN, NaN), 0, 1);
    idx = 0;
    rho_list = [1, 0.99, 0.9, 0.7, 0.5];
    for iv = 1:numel(rho_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_dispatch_scenario_local('rho_scan', sprintf('rho_%g', rho_list(iv)), ...
                snr_list(is), [0, 0], 1, 0, rho_list(iv), 0);
        end
    end
    beta_list = [1, 0.8, 0.5, 0.3, 0.1];
    for iv = 1:numel(beta_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_dispatch_scenario_local('beta_scan', sprintf('beta_%g', beta_list(iv)), ...
                snr_list(is), [0, 0], beta_list(iv), 0, 1, 0);
        end
    end
    phase_list = [0, 60, 90, 120, 150, 180];
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

function scenarios = build_scenarios_local(snr_list)
    scenarios = struct([]);
    idx = 0;
    el_b_list = [0, 1, 2, 5, 10];
    for ib = 1:numel(el_b_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx).stage = 'A';
            scenarios(idx).group = 'legacy_A';
            scenarios(idx).case_name = sprintf('elB_%g', el_b_list(ib));
            scenarios(idx).el_true = [0, el_b_list(ib)];
            scenarios(idx).el_assumed = 0;
            scenarios(idx).snr_db = snr_list(is);
            scenarios(idx).el_b = el_b_list(ib);
            scenarios(idx).el_mismatch = 0;
            scenarios(idx).el_diff = el_b_list(ib);
            scenarios(idx).beta = 1;
            scenarios(idx).phi_deg = 0;
            scenarios(idx).rho = 1;
            scenarios(idx).large_el_flag = scenarios(idx).el_diff >= 2;
            scenarios(idx).common_el_flag = scenarios(idx).el_diff < 0.5;
            scenarios(idx).weak_target_flag = false;
            scenarios(idx).anti_phase_flag = false;
        end
    end
    el_assumed_list = [0, 2, 5, 10];
    for ie = 1:numel(el_assumed_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx).stage = 'B';
            scenarios(idx).group = 'legacy_B';
            scenarios(idx).case_name = sprintf('el0_%g', el_assumed_list(ie));
            scenarios(idx).el_true = [0, 0];
            scenarios(idx).el_assumed = el_assumed_list(ie);
            scenarios(idx).snr_db = snr_list(is);
            scenarios(idx).el_b = 0;
            scenarios(idx).el_mismatch = el_assumed_list(ie);
            scenarios(idx).el_diff = 0;
            scenarios(idx).beta = 1;
            scenarios(idx).phi_deg = 0;
            scenarios(idx).rho = 1;
            scenarios(idx).large_el_flag = false;
            scenarios(idx).common_el_flag = true;
            scenarios(idx).weak_target_flag = false;
            scenarios(idx).anti_phase_flag = false;
        end
    end
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
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(A) .* (Cn * A), 1));
    spectrum = 1 ./ max(den, eps);
    peaks = find_1d_peaks_local(spectrum, az_grid, Lc);
    result = make_result_local(peaks.az_est, [el_assumed, el_assumed], peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum_1d = spectrum;
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

function result = run_level2_el_bank_route_local( ...
    y_noisy_2d, Z3d, lambda, el_bank, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    best = [];
    for ie = 1:numel(el_bank)
        y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, cache_map(ie).el);
        Rfb = level2_fbss_cov_local(y_combined, K_phi);
        now = score_level2_cache_local(Rfb, cache_map(ie), az_grid, theta_true);
        now.el_est = [cache_map(ie).el, cache_map(ie).el];
        if isempty(best) || now.objective_best < best.objective_best
            best = now;
        end
    end
    result = best;
    result.peak_count = 2;
    result.failure_reason = failure_reason_pair_local(result.az_est, result.el_est, min_sep, max_sep);
end

function result = score_level2_cache_local(Rfb, cache, az_grid, theta_true)
    score = score_rank1_all_local(Rfb, cache.precomp);
    [best_score, best_idx] = min(score);
    pair_idx = cache.precomp.candidate_pairs(best_idx, :);
    true_precomp = precompute_rank1_pair_bases_local(cache.sub_cache, nearest_pair_indices_local(az_grid, theta_true));
    true_score = score_rank1_all_local(Rfb, true_precomp);
    result = make_result_local(sort(az_grid(pair_idx)), [NaN, NaN], 2, best_score, true_score(1), 'ok');
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

function result = run_common_el_refocus_music_peak_route_local( ...
    y_noisy_2d, Z3d, lambda, music_result, music_cache, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    [~, idx] = max(music_result.spectrum(:));
    [~, ie] = ind2sub(size(music_result.spectrum), idx);
    el_hat = music_cache.el_grid(ie);
    result = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, el_hat, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep);
    result.el_hat = el_hat;
    result.el_est = [el_hat, el_hat];
    result.el_common_est = el_hat;
    result.el_selection_method = "2dmusic_peak";
    result.focused_power_peak_sharpness = NaN;
    result.lambda1_peak_sharpness = NaN;
    result.rank1_objective_valley_width_el = NaN;
    result.rank1_objective_selected_el_rank = NaN;
end

function result = run_common_el_refocus_rank1_objective_route_local( ...
    y_noisy_2d, Z3d, lambda, el_grid, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    n = numel(el_grid);
    objective_curve = zeros(1, n);
    margin_curve = zeros(1, n);
    route_results = cell(1, n);
    for ie = 1:n
        y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_grid(ie));
        Rfb = level2_fbss_cov_local(y_combined, K_phi);
        now = score_level2_cache_local(Rfb, cache_map(ie), az_grid, theta_true);
        now.el_est = [el_grid(ie), el_grid(ie)];
        now.peak_count = 2;
        now.failure_reason = failure_reason_pair_local(now.az_est, now.el_est, min_sep, max_sep);
        objective_curve(ie) = now.objective_best;
        margin_curve(ie) = now.objective_margin;
        route_results{ie} = now;
    end
    [~, idx] = min(objective_curve);
    el_hat = el_grid(idx);
    result = route_results{idx};
    result.el_hat = el_hat;
    result.el_est = [el_hat, el_hat];
    result.el_common_est = el_hat;
    result.el_selection_method = "rank1_objective";
    result.focused_power_peak_sharpness = NaN;
    result.lambda1_peak_sharpness = NaN;
    result.rank1_objective_valley_width_el = objective_valley_width_local(el_grid, objective_curve);
    result.rank1_objective_selected_el_rank = 1 + sum(objective_curve < objective_curve(idx));
    result.objective_curve = objective_curve;
    result.margin_curve = margin_curve;
    result.el_grid = el_grid;
end

function example = make_refocus_curve_example_local(power_result, objective_result)
    example = struct();
    example.valid = true;
    example.el_grid = power_result.el_grid;
    example.power_curve = power_result.power_curve;
    example.lambda1_curve = power_result.lambda1_curve;
    example.objective_curve = objective_result.objective_curve;
    example.margin_curve = objective_result.margin_curve;
end

function sharpness = peak_sharpness_local(curve)
    curve = real(curve(:));
    [mx, idx] = max(curve);
    tmp = curve;
    tmp(idx) = -inf;
    second = max(tmp);
    sharpness = (mx - second) / max(abs(mx), eps);
end

function width = objective_valley_width_local(el_grid, objective_curve)
    best = min(objective_curve);
    thresh = best + max(1e-6, 0.02 * max(best, eps));
    vals = el_grid(objective_curve <= thresh);
    if isempty(vals)
        width = NaN;
    else
        width = max(vals) - min(vals);
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
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(grid_cache.A_center) .* (Cn * grid_cache.A_center), 1));
    P = reshape(1 ./ max(den, eps), numel(grid_cache.az_grid), numel(grid_cache.el_grid));
    peaks = find_2d_peaks_local(P, grid_cache.az_grid, grid_cache.el_grid, Lc);
    result = make_result_local(peaks.az_est, peaks.el_est, peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum = P;
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

function result = run_level3_common_el_rank1_covfit_local( ...
    Rfb, X3d, Y3d, Z3d, A_ref_2d, lambda, candidates, K_phi, K_z, p_sel, r_sel, theta_true, el_true)
    scores = zeros(size(candidates, 1), 1);
    for ic = 1:size(candidates, 1)
        th = candidates(ic, 1:2);
        elc = candidates(ic, 3);
        G = build_level3_rank1_model_fbss_selected_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, th, [elc, elc], 1, 0, K_phi, K_z, p_sel, r_sel);
        scores(ic) = solve_covfit_score_local(Rfb, G);
    end
    [best_score, best_idx] = min(scores);
    true_like_idx = nearest_common_candidate_local(candidates, theta_true, mean(el_true));
    true_score = scores(true_like_idx);
    best = candidates(best_idx, :);
    result = make_result_local(sort(best(1:2)), [best(3), best(3)], 2, best_score, true_score, 'ok');
    result.el_common_est = best(3);
    result.objective_true_rank = 1 + sum(scores < true_score);
    result.objective_example = struct('el_grid', unique(candidates(:, 3)).', ...
        'score_by_el', best_score_by_el_local(candidates, scores), 'valid', false);
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
    true_idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true);
    true_score = scores(true_idx);
    best = candidates(best_idx, :);
    result = make_result_local(sort(best(1:2)), best(3:4), 2, best_score, true_score, 'ok');
    [result.az_est, order] = sort(best(1:2));
    result.el_est = best(2 + order);
    result.objective_true_rank = 1 + sum(scores < true_score);
end

function result = run_level3_oracle_rank1_route_local( ...
    Rfb, X3d, Y3d, Z3d, A_ref_2d, lambda, theta_true, el_true, beta, phi_deg, K_phi, K_z, p_sel, r_sel, min_sep, max_sep)
    candidates = make_oracle_local_pairs_local(theta_true, el_true, min_sep, max_sep);
    scores = zeros(size(candidates, 1), 1);
    for ic = 1:size(candidates, 1)
        G = build_level3_rank1_model_fbss_selected_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, candidates(ic, 1:2), candidates(ic, 3:4), ...
            beta, phi_deg, K_phi, K_z, p_sel, r_sel);
        scores(ic) = solve_covfit_score_local(Rfb, G);
    end
    [best_score, best_idx] = min(scores);
    true_idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true);
    true_score = scores(true_idx);
    best = candidates(best_idx, :);
    result = make_result_local(sort(best(1:2)), best(3:4), 2, best_score, true_score, 'ok');
    [result.az_est, order] = sort(best(1:2));
    result.el_est = best(2 + order);
    result.objective_true_rank = 1 + sum(scores < true_score);
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

function candidates = make_common_el_candidates_local(az_grid, el_grid, min_sep, max_sep)
    pairs = make_pair_candidates_local(az_grid, min_sep, max_sep);
    candidates = zeros(size(pairs, 1) * numel(el_grid), 3);
    count = 0;
    for ie = 1:numel(el_grid)
        n = size(pairs, 1);
        candidates(count+1:count+n, :) = [az_grid(pairs), repmat(el_grid(ie), n, 1)];
        count = count + n;
    end
end

function candidates = make_centersep_candidates_local(az_center_grid, az_sep_grid, el_grid, min_sep, max_sep)
    candidates = zeros(numel(az_center_grid) * numel(az_sep_grid) * numel(el_grid), 5);
    count = 0;
    for ia = 1:numel(az_center_grid)
        for isep = 1:numel(az_sep_grid)
            az_sep = az_sep_grid(isep);
            if az_sep < min_sep || az_sep > max_sep
                continue
            end
            th = [az_center_grid(ia) - az_sep/2, az_center_grid(ia) + az_sep/2];
            for ie = 1:numel(el_grid)
                count = count + 1;
                candidates(count, :) = [th, el_grid(ie), az_center_grid(ia), az_sep];
            end
        end
    end
    candidates = candidates(1:count, :);
end

function precomp = precompute_level3_rank1_candidate_bases_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, candidates, K_phi, K_z, p_sel, r_sel)
    K = K_phi * K_z;
    Nc = size(candidates, 1);
    L = 2 * K * K;
    g_basis = zeros(L, Nc, 'single');
    gg = zeros(Nc, 1);
    gi = zeros(Nc, 1);
    ivec = matrix_to_realvec_local(eye(K));
    ii = real(ivec' * ivec);
    for ic = 1:Nc
        G = build_level3_rank1_model_fbss_selected_direct_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, candidates(ic, 1:2), ...
            [candidates(ic, 3), candidates(ic, 3)], 1, 0, K_phi, K_z, p_sel, r_sel);
        v = matrix_to_realvec_local(G);
        g_basis(:, ic) = single(v);
        gg(ic) = real(v' * v);
        gi(ic) = real(v' * ivec);
    end
    precomp = struct('g_basis', g_basis, 'gg', gg, 'gi', gi, 'ivec', single(ivec), 'ii', ii);
end

function result = run_level3_common_el_rank1_covfit_precomp_local(Rfb, candidates, precomp, theta_true, el_true)
    scores = score_rank1_all_local(Rfb, precomp);
    [best_score, best_idx] = min(scores);
    true_like_idx = nearest_common_candidate_local(candidates, theta_true, mean(el_true));
    true_score = scores(true_like_idx);
    best = candidates(best_idx, :);
    result = make_result_local(sort(best(1:2)), [best(3), best(3)], 2, best_score, true_score, 'ok');
    result.el_common_est = best(3);
    result.objective_true_rank = 1 + sum(scores < true_score);
end

function result = run_level3_common_el_centersep_covfit_local( ...
    Rfb, coarse_candidates, coarse_precomp, X3d, Y3d, Z3d, A_ref_2d, lambda, ...
    K_phi, K_z, p_sel, r_sel, theta_true, el_true, topN, min_sep, max_sep)
    coarse_scores = score_rank1_all_local(Rfb, coarse_precomp);
    [coarse_best_score, coarse_best_idx] = min(coarse_scores);
    [~, ord] = sort(coarse_scores, 'ascend');
    ord = ord(1:min(topN, numel(ord)));

    refine_candidates = zeros(0, 5);
    for ii = 1:numel(ord)
        c0 = coarse_candidates(ord(ii), 4);
        s0 = coarse_candidates(ord(ii), 5);
        e0 = coarse_candidates(ord(ii), 3);
        azc_grid = c0-0.04:0.01:c0+0.04;
        sep_grid = s0-0.04:0.005:s0+0.04;
        el_grid = e0-1:0.25:e0+1;
        now = make_centersep_candidates_local(azc_grid, sep_grid, el_grid, min_sep, max_sep);
        refine_candidates = [refine_candidates; now]; %#ok<AGROW>
    end
    refine_candidates = unique(round(refine_candidates * 1e6) / 1e6, 'rows');

    refine_scores = inf(size(refine_candidates, 1), 1);
    for ic = 1:size(refine_candidates, 1)
        G = build_level3_rank1_model_fbss_selected_direct_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, refine_candidates(ic, 1:2), ...
            [refine_candidates(ic, 3), refine_candidates(ic, 3)], 1, 0, K_phi, K_z, p_sel, r_sel);
        refine_scores(ic) = solve_covfit_score_local(Rfb, G);
    end
    [refine_best_score, refine_best_idx] = min(refine_scores);
    if refine_best_score < coarse_best_score
        best_score = refine_best_score;
        best = refine_candidates(refine_best_idx, :);
        all_scores_for_rank = [coarse_scores; refine_scores];
    else
        best_score = coarse_best_score;
        best = coarse_candidates(coarse_best_idx, :);
        all_scores_for_rank = coarse_scores;
    end

    G_true = build_level3_rank1_model_fbss_selected_direct_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, theta_true, [mean(el_true), mean(el_true)], ...
        1, 0, K_phi, K_z, p_sel, r_sel);
    true_score = solve_covfit_score_local(Rfb, G_true);
    result = make_result_local(sort(best(1:2)), [best(3), best(3)], 2, best_score, true_score, 'ok');
    result.el_common_est = best(3);
    result.objective_true_rank = 1 + sum(all_scores_for_rank < true_score);
end

function Gfb = build_level3_rank1_model_fbss_selected_direct_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair, el_pair, beta, phi_deg, K_phi, K_z, p_sel, r_sel)
    q = beta * exp(1j * deg2rad(phi_deg));
    K = K_phi * K_z;
    G = complex(zeros(K, K));
    count = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            p = p_sel(ip);
            r = r_sel(ir);
            a1 = steering_2d_subarray_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(1), el_pair(1), p, r, K_phi, K_z);
            a2 = steering_2d_subarray_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(2), el_pair(2), p, r, K_phi, K_z);
            c = a1 / max(norm(a1), eps) + q * a2 / max(norm(a2), eps);
            G = G + c * c';
            count = count + 1;
        end
    end
    G = G / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Gfb = 0.5 * (G + J * conj(G) * J);
    Gfb = 0.5 * (Gfb + Gfb');
end

function a = steering_2d_subarray_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_deg, p, r, K_phi, K_z)
    xs = X3d(p:p+K_phi-1, r:r+K_z-1);
    ys = Y3d(p:p+K_phi-1, r:r+K_z-1);
    zs = Z3d(p:p+K_phi-1, r:r+K_z-1);
    ref = A_ref_2d(p:p+K_phi-1, r:r+K_z-1);
    phase = xs * (cosd(el_deg) * cosd(az_deg)) + ...
        ys * (cosd(el_deg) * sind(az_deg)) + zs * sind(el_deg);
    a = conj(ref(:)) .* exp(-1j * 2*pi / lambda * phase(:));
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

function candidates = make_oracle_local_pairs_local(theta_true, el_true, min_sep, max_sep)
    az_offsets = [-0.04, -0.02, 0, 0.02, 0.04];
    el_offsets = [-0.5, 0, 0.5];
    candidates = zeros(numel(az_offsets)^2 * numel(el_offsets)^2, 4);
    count = 0;
    for a1 = 1:numel(az_offsets)
        for a2 = 1:numel(az_offsets)
            th = sort([theta_true(1) + az_offsets(a1), theta_true(2) + az_offsets(a2)]);
            sep = diff(th);
            if sep < min_sep || sep > max_sep
                continue
            end
            for e1 = 1:numel(el_offsets)
                for e2 = 1:numel(el_offsets)
                    count = count + 1;
                    candidates(count, :) = [th, el_true(1)+el_offsets(e1), el_true(2)+el_offsets(e2)];
                end
            end
        end
    end
    candidates = candidates(1:count, :);
end

function idx = nearest_common_candidate_local(candidates, theta_true, el_true)
    d = sum((candidates(:, 1:2) - theta_true).^2, 2) + (candidates(:, 3) - el_true).^2;
    [~, idx] = min(d);
end

function idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true)
    truth = [theta_true(:).', el_true(:).'];
    d = sum((candidates - truth).^2, 2);
    [~, idx] = min(d);
end

function score_by_el = best_score_by_el_local(candidates, scores)
    elv = unique(candidates(:, 3)).';
    score_by_el = zeros(size(elv));
    for i = 1:numel(elv)
        score_by_el(i) = min(scores(candidates(:, 3) == elv(i)));
    end
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
    peaks = struct('az_est', az_est, 'el_est', el_est, 'peak_count', peak_count, 'failure_reason', reason);
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
    peaks = struct('az_est', az_est, 'peak_count', peak_count, 'failure_reason', reason);
end

function result = apply_dispatch_rule_local(sc, route_map)
    music_ok = route_map.music.peak_count >= 2 && all(isfinite(route_map.music.az_est));
    music_single = route_map.music.peak_count < 2 || ~all(isfinite(route_map.music.az_est));
    music2d_ok = route_map.level3_2d_music.peak_count >= 2 && all(isfinite(route_map.level3_2d_music.az_est));
    pair_ok = all(isfinite(route_map.pair_el_local_covfit.az_est));

    if sc.large_el_flag && pair_ok
        selected = route_map.pair_el_local_covfit;
        selected.recommended_route = "pair_el_local_covfit";
        selected.confidence_flag = confidence_with_boundary_local(sc);
        selected.failure_reason = "ok";
    elseif sc.large_el_flag && music2d_ok
        selected = route_map.level3_2d_music;
        selected.recommended_route = "level3_2d_music";
        selected.confidence_flag = confidence_with_boundary_local(sc);
        selected.failure_reason = "ok";
    elseif sc.weak_target_flag
        selected = make_boundary_result_local(route_map, 'weak_target_boundary', 'low', 'weak_target_boundary', true, false);
    elseif sc.anti_phase_flag
        selected = make_boundary_result_local(route_map, 'anti_phase_boundary', 'low', 'anti_phase_boundary', false, true);
    elseif sc.rho < 1 && music_ok
        selected = route_map.music;
        selected.recommended_route = "music";
        selected.confidence_flag = "high";
        selected.failure_reason = "ok";
    elseif sc.common_el_flag && sc.rho >= 0.99 && music_single
        selected = route_map.common_el_refocus_rank1;
        selected.recommended_route = "common_el_refocus_rank1";
        selected.confidence_flag = "high";
        selected.failure_reason = "ok";
    elseif music_ok
        selected = route_map.music;
        selected.recommended_route = "music";
        selected.confidence_flag = "medium";
        selected.failure_reason = "ok";
    elseif all(isfinite(route_map.rank1_fallback.az_est))
        selected = route_map.rank1_fallback;
        selected.recommended_route = "rank1_fallback";
        selected.confidence_flag = "medium";
        selected.failure_reason = "music_single_rank1_fallback";
    else
        selected = make_boundary_result_local(route_map, 'low_confidence', 'low', 'no_reliable_route', false, false);
    end
    if selected.recommended_route == ""
        selected.recommended_route = "low_confidence";
    end
    selected.weak_target_boundary_flag = sc.weak_target_flag || strcmp(selected.recommended_route, "weak_target_boundary");
    selected.anti_phase_boundary_flag = sc.anti_phase_flag || strcmp(selected.recommended_route, "anti_phase_boundary");
    selected.low_confidence_flag = strcmp(selected.confidence_flag, "low") || strcmp(selected.recommended_route, "low_confidence");
    result = selected;
end

function confidence = confidence_with_boundary_local(sc)
    if sc.weak_target_flag || sc.anti_phase_flag
        confidence = "medium";
    else
        confidence = "high";
    end
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

function row = make_summary_row_local(sc, route_name, metrics)
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
        metrics.anti_phase_boundary_rate, metrics.low_confidence_rate};
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
        'weak_target_boundary_rate', 'anti_phase_boundary_rate', 'low_confidence_rate'};
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

function val = getfield_default_local(s, name, default_val)
    if isfield(s, name)
        val = s.(name);
    else
        val = default_val;
    end
end

function keypoints = build_keypoints_local(summary_tbl)
    kp = {};
    R = summary_tbl(strcmp(summary_tbl.group, 'rho_scan'), :);
    B = summary_tbl(strcmp(summary_tbl.group, 'beta_scan'), :);
    P = summary_tbl(strcmp(summary_tbl.group, 'phase_scan'), :);
    L = summary_tbl(strcmp(summary_tbl.group, 'large_el'), :);
    D = summary_tbl(strcmp(summary_tbl.route_name, 'dispatch_recommended_route'), :);

    kp(end+1, :) = {'rho_music_joint_rho1', route_case_mean_local(R, 'level2_music_or_center_real', 'rho_1'), 'MUSIC joint at fully coherent rho=1'}; %#ok<AGROW>
    kp(end+1, :) = {'rho_music_joint_rho0p7', route_case_mean_local(R, 'level2_music_or_center_real', 'rho_0.7'), 'MUSIC joint at rho=0.7'}; %#ok<AGROW>
    kp(end+1, :) = {'rho_music_peak_rho0p7', route_case_mean_col_local(R, 'level2_music_or_center_real', 'rho_0.7', 'peak_count_mean'), 'MUSIC peak count at rho=0.7'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_rank1_joint_beta1', route_case_mean_local(B, 'level2_rank1_fallback', 'beta_1'), 'rank1 joint at beta=1'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_rank1_joint_beta0p3', route_case_mean_local(B, 'level2_rank1_fallback', 'beta_0.3'), 'rank1 joint at weak target beta=0.3'}; %#ok<AGROW>
    kp(end+1, :) = {'beta_weak_boundary_rate_beta0p3', dispatch_case_col_local(D, 'beta_0.3', 'weak_target_boundary_rate'), 'dispatch weak-target boundary rate at beta=0.3'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_rank1_joint_phase0', route_case_mean_local(P, 'level2_rank1_fallback', 'phase_0'), 'rank1 joint at phase=0'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_rank1_joint_phase150', route_case_mean_local(P, 'level2_rank1_fallback', 'phase_150'), 'rank1 joint at phase=150'}; %#ok<AGROW>
    kp(end+1, :) = {'phase_anti_boundary_rate_phase150', dispatch_case_col_local(D, 'phase_150', 'anti_phase_boundary_rate'), 'dispatch anti-phase boundary rate at phase=150'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_2dmusic_joint_el5_clean', route_case_mean_local(L, 'level3_2d_music', 'B_el5_beta1_phase0_rho1'), '2D MUSIC joint at el_b=5 beta=1 phase=0 rho=1'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_pair_covfit_joint_el5_clean', route_case_mean_local(L, 'pair_el_local_covfit', 'B_el5_beta1_phase0_rho1'), 'pair-local covfit joint at el_b=5 clean coherent case'}; %#ok<AGROW>
    kp(end+1, :) = {'large_el_2dmusic_joint_el10_hard', route_case_mean_local(L, 'level3_2d_music', 'F_el10_beta05_phase180_rho07'), '2D MUSIC joint at hardest large-el case'}; %#ok<AGROW>
    kp(end+1, :) = {'dispatch_success_all', mean(D.joint_tol_success_rate, 'omitnan'), 'recommended route mean joint success across scenarios'}; %#ok<AGROW>
    kp(end+1, :) = {'dispatch_low_confidence_all', mean(D.low_confidence_rate, 'omitnan'), 'recommended route low-confidence rate'}; %#ok<AGROW>
    keypoints = cell2table(kp, 'VariableNames', {'keypoint', 'value', 'note'});
end

function val = route_case_mean_local(T, route_name, case_name)
    val = route_case_mean_col_local(T, route_name, case_name, 'joint_tol_success_rate');
end

function val = route_case_mean_col_local(T, route_name, case_name, colname)
    mask = strcmp(T.route_name, route_name) & strcmp(T.case_name, case_name);
    if any(mask)
        val = mean(T.(colname)(mask), 'omitnan');
    else
        val = NaN;
    end
end

function val = dispatch_case_col_local(T, case_name, colname)
    mask = strcmp(T.case_name, case_name);
    if any(mask)
        val = mean(T.(colname)(mask), 'omitnan');
    else
        val = NaN;
    end
end

function gap = gap_mean_local(T, route_name, oracle_name, mask_base)
    v_route = mean(T.joint_tol_success_rate(strcmp(T.route_name, route_name) & mask_base), 'omitnan');
    v_oracle = mean(T.joint_tol_success_rate(strcmp(T.route_name, oracle_name) & mask_base), 'omitnan');
    gap = v_oracle - v_route;
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

function plot_dispatch_rho_scan_routes_local(tbl, path_out)
    T = tbl(strcmp(tbl.group, 'rho_scan') & tbl.snr_db == 8, :);
    routes = {'level2_music_or_center_real', 'level2_rank1_fallback', ...
        'common_el_refocus_power_rank1', 'dispatch_recommended_route'};
    x = unique(T.rho).';
    fig = figure('Visible', 'off');
    hold on
    for ir = 1:numel(routes)
        y = metric_by_x_local(T, routes{ir}, 'rho', x, 'joint_tol_success_rate');
        plot(x, y, '-o', 'LineWidth', 1.2);
    end
    set(gca, 'XDir', 'reverse');
    grid on
    xlabel('rho');
    ylabel('joint tol success rate');
    ylim([-0.05, 1.05]);
    title('Rho scan routes, SNR=8 dB');
    legend(routes, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_dispatch_beta_scan_boundaries_local(tbl, path_out)
    T = tbl(strcmp(tbl.group, 'beta_scan') & tbl.snr_db == 8, :);
    routes = {'level2_music_or_center_real', 'level2_rank1_fallback', ...
        'common_el_refocus_power_rank1', 'dispatch_recommended_route'};
    x = unique(T.beta).';
    fig = figure('Visible', 'off');
    yyaxis left
    hold on
    for ir = 1:numel(routes)
        y = metric_by_x_local(T, routes{ir}, 'beta', x, 'joint_tol_success_rate');
        plot(x, y, '-o', 'LineWidth', 1.2);
    end
    ylabel('joint tol success rate');
    ylim([-0.05, 1.05]);
    yyaxis right
    yb = metric_by_x_local(T, 'dispatch_recommended_route', 'beta', x, 'weak_target_boundary_rate');
    plot(x, yb, '--k', 'LineWidth', 1.5);
    ylabel('weak target boundary rate');
    ylim([-0.05, 1.05]);
    set(gca, 'XDir', 'reverse');
    grid on
    xlabel('beta');
    title('Beta scan boundaries, SNR=8 dB');
    legend([routes, {'weak_boundary'}], 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_dispatch_phase_scan_boundaries_local(tbl, path_out)
    T = tbl(strcmp(tbl.group, 'phase_scan') & tbl.snr_db == 8, :);
    routes = {'level2_music_or_center_real', 'level2_rank1_fallback', ...
        'common_el_refocus_power_rank1', 'dispatch_recommended_route'};
    x = unique(T.phi_deg).';
    fig = figure('Visible', 'off');
    yyaxis left
    hold on
    for ir = 1:numel(routes)
        y = metric_by_x_local(T, routes{ir}, 'phi_deg', x, 'joint_tol_success_rate');
        plot(x, y, '-o', 'LineWidth', 1.2);
    end
    ylabel('joint tol success rate');
    ylim([-0.05, 1.05]);
    yyaxis right
    yb = metric_by_x_local(T, 'dispatch_recommended_route', 'phi_deg', x, 'anti_phase_boundary_rate');
    plot(x, yb, '--k', 'LineWidth', 1.5);
    ylabel('anti-phase boundary rate');
    ylim([-0.05, 1.05]);
    grid on
    xlabel('phase (deg)');
    title('Phase scan boundaries, SNR=8 dB');
    legend([routes, {'anti_phase_boundary'}], 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_dispatch_large_el_cases_local(tbl, path_out)
    T = tbl(strcmp(tbl.group, 'large_el') & tbl.snr_db == 8, :);
    routes = {'level3_2d_music', 'pair_el_local_covfit', 'dispatch_recommended_route'};
    cases = unique(T.case_name, 'stable');
    vals = zeros(numel(cases), numel(routes));
    for ic = 1:numel(cases)
        for ir = 1:numel(routes)
            mask = strcmp(T.case_name, cases{ic}) & strcmp(T.route_name, routes{ir});
            vals(ic, ir) = mean(T.joint_tol_success_rate(mask), 'omitnan');
        end
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(cases), 'XTickLabel', cases, 'XTickLabelRotation', 25);
    ylabel('joint tol success rate');
    title('Large elevation general cases, SNR=8 dB');
    legend(routes, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_dispatch_recommended_success_local(tbl, path_out)
    T = tbl(strcmp(tbl.route_name, 'dispatch_recommended_route'), :);
    [groups, ~, gidx] = unique(T.group, 'stable');
    vals = zeros(numel(groups), 3);
    snrs = [0, 8, 16];
    for ig = 1:numel(groups)
        for is = 1:numel(snrs)
            mask = gidx == ig & T.snr_db == snrs(is);
            vals(ig, is) = mean(T.joint_tol_success_rate(mask), 'omitnan');
        end
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', groups, 'XTickLabelRotation', 20);
    ylabel('recommended route joint success');
    title('Dispatch recommended route success');
    legend(compose('SNR=%g', snrs), 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function y = metric_by_x_local(T, route_name, xcol, xvals, metric_name)
    y = nan(size(xvals));
    for ix = 1:numel(xvals)
        mask = strcmp(T.route_name, route_name) & abs(T.(xcol) - xvals(ix)) < 1e-9;
        y(ix) = mean(T.(metric_name)(mask), 'omitnan');
    end
end

function val = keypoint_value_local(keypoints_tbl, name)
    idx = strcmp(keypoints_tbl.keypoint, name);
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

function write_record_doc_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, Metkl)
    fid = fopen(record_doc_path, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.7步_5：一般源模型分流边界验证记录\n\n');
    fprintf(fid, '## 实现范围\n\n');
    fprintf(fid, '- 新脚本：`space_smooth_music_B_cylindrical_level3_general_model_dispatch_boundary.m`。\n');
    fprintf(fid, '- 新结果目录：`results_step8_7_5_general_model_dispatch_boundary/`。\n');
    fprintf(fid, '- 使用一般源模型 `s2=beta*exp(j*phi)*(rho*s1+sqrt(1-rho^2)*v)`。\n');
    fprintf(fid, '- 实现 route：`level2_music_or_center_real`、`level2_rank1_fallback`、`common_el_refocus_power_rank1`、`level3_2d_music`、`pair_el_local_covfit`、`dispatch_recommended_route`。\n');
    fprintf(fid, '- 本轮只验证分流边界，不做 fullscan/V2 constrained covariance fitting/complex-gain q/完整 4D 搜索。\n');
    fprintf(fid, '- Monte Carlo: Metkl=%d, SNR=[0,8,16], T_snap=260。\n\n', Metkl);
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.3f | %s |\n', keypoints_tbl.keypoint{i}, keypoints_tbl.value(i), keypoints_tbl.note{i});
    end
    fprintf(fid, '\n## 分组判断\n\n');
    rho1 = keypoint_value_local(keypoints_tbl, 'rho_music_joint_rho1');
    rho07 = keypoint_value_local(keypoints_tbl, 'rho_music_joint_rho0p7');
    if rho07 > rho1
        fprintf(fid, '- rho 扫描：rho 降低后 MUSIC 有恢复趋势，非完全相干场景不需要优先启用 rank1 fallback。\n');
    else
        fprintf(fid, '- rho 扫描：rho 降低后 MUSIC 未明显恢复，问题可能仍受小间隔和阵列模型限制。\n');
    end
    b03 = keypoint_value_local(keypoints_tbl, 'beta_rank1_joint_beta0p3');
    wb03 = keypoint_value_local(keypoints_tbl, 'beta_weak_boundary_rate_beta0p3');
    if wb03 >= 0.9 || b03 < 0.8
        fprintf(fid, '- beta 扫描：beta<=0.3 属于弱目标边界，需要 SIC 或弱目标检测策略，不建议强行 rank1 pair covfit。\n');
    else
        fprintf(fid, '- beta 扫描：当前 beta 边界未完全击穿 rank1，但仍应保留 weak_target_boundary 标记。\n');
    end
    p150 = keypoint_value_local(keypoints_tbl, 'phase_rank1_joint_phase150');
    ap150 = keypoint_value_local(keypoints_tbl, 'phase_anti_boundary_rate_phase150');
    if ap150 >= 0.9 || p150 < 0.8
        fprintf(fid, '- phase 扫描：phase=150/180 属于近反相病态边界，应标记 anti_phase_boundary。\n');
    else
        fprintf(fid, '- phase 扫描：近反相未完全失败，但仍不应包装为正常 rank1 fallback 场景。\n');
    end
    le5 = keypoint_value_local(keypoints_tbl, 'large_el_2dmusic_joint_el5_clean');
    hard = keypoint_value_local(keypoints_tbl, 'large_el_2dmusic_joint_el10_hard');
    if le5 >= 0.8
        fprintf(fid, '- 大俯仰差一般源：el_b>=5 的干净强相干场景可由 2D MUSIC 几何分离处理。\n');
    end
    if hard < 0.8
        fprintf(fid, '- 大俯仰差叠加弱目标/反相/低相干时仍可能失败，二维几何不能完全解决动态范围和病态相位问题。\n');
    end
    fprintf(fid, '- 本轮仍不需要实现 V2/general covariance fitting；V2 继续作为未来一般协方差模型扩展保留。\n\n');
    fprintf(fid, '## 输出\n\n');
    fprintf(fid, '- 结果目录：`%s`\n', result_dir);
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
