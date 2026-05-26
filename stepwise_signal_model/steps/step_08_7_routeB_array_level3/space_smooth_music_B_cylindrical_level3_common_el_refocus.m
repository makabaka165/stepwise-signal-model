clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
step75_dir = fullfile(steps_dir, 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');

addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
addpath(step75_dir);

cfg = sim_cfg();

result_dir = fullfile(script_dir, 'results_step8_7_4_common_el_refocus');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_7_4_common_el_refocus.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

record_doc_path = fullfile(script_dir, '第8.7步_4_common-el重聚焦与层次二fallback验证记录.md');
summary_csv_path = fullfile(result_dir, 'step8_7_4_common_el_refocus_summary.csv');
keypoints_csv_path = fullfile(result_dir, 'step8_7_4_common_el_refocus_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_7_4_common_el_refocus_result.mat');

log_msg(fid_log, 'Step 08.7 part 4: common-el refocus + layer2 rank1 fallback validation');
log_msg(fid_log, 'Scope: estimate common elevation from raw 65x32 data, refocus layers, then reuse level2 rank1 fallback. No fullscan, no V2, no complex-gain q, no edits to step 8.6.');

azCtr_deg = 0;
sep_factor = 10;
snr_list = [0, 8, 16];
Metkl = 50;
T_snap = 260;
beta = 1;
phi_deg = 0;
rho = 1;
Lc = 2;
K_phi_level2 = 20;
K_phi_music = 20;
K_z_music = 8;
K_phi_covfit = 6;
K_z_covfit = 3;
az_grid = azCtr_deg - 0.6:0.02:azCtr_deg + 0.6;
az_covfit_grid = azCtr_deg - 0.6:0.04:azCtr_deg + 0.6;
el_grid = -2:0.5:12;
el_refocus_grid = -2:0.25:12;
el_common_grid = -2:1:12;
el_assumed_list = [0, 2, 5, 10];
el_bank = -5:1:15;
az_tol_deg = 0.1;
el_tol_deg = 0.5;
min_pair_sep_deg = 0.05;
max_pair_sep_deg = 0.80;
base_seed = 20260907;

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
log_msg(fid_log, 'Run control: scenario B only, Metkl=%d, SNR=%s, el_assumed=%s, T_snap=%d.', ...
    Metkl, mat2str(snr_list), mat2str(el_assumed_list), T_snap);
log_msg(fid_log, '2D MUSIC K=[%d,%d], covfit K=[%d,%d], refocus_el_grid=%d.', ...
    K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, numel(el_refocus_grid));

route_names = { ...
    'level2_rank1_wrong_el_assumed', ...
    'level2_el_bank_old', ...
    'level3_2d_music', ...
    'common_el_covfit_old', ...
    'common_el_refocus_power', ...
    'common_el_refocus_2dmusic_peak', ...
    'common_el_refocus_rank1_objective', ...
    'oracle_el_rank1_covfit'};

level2_pair_candidates = make_pair_candidates_local(az_grid, min_pair_sep_deg, max_pair_sep_deg);
level2_cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_bank, K_phi_level2, level2_pair_candidates);
music_cache = make_level3_grid_cache_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_grid, K_phi_music, K_z_music);
[p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi_covfit, K_z_covfit);
common_candidates = make_common_el_candidates_local(az_covfit_grid, el_common_grid, min_pair_sep_deg, max_pair_sep_deg);

log_msg(fid_log, 'Precomputing common-el old candidates: %d', size(common_candidates, 1));
common_old_precomp = precompute_level3_rank1_candidate_bases_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, common_candidates, K_phi_covfit, K_z_covfit, p_sel, r_sel);
level2_refocus_cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, az_grid, el_refocus_grid, K_phi_level2, level2_pair_candidates);

summary_rows = {};
trial_results = struct([]);
trial_count = 0;
curve_example = struct('valid', false);
stores = cell(numel(snr_list), numel(el_assumed_list));
for is = 1:numel(snr_list)
    for ie = 1:numel(el_assumed_list)
        stores{is, ie} = init_route_trial_store_local(route_names, Metkl);
    end
end

tic
for is = 1:numel(snr_list)
    snr_db = snr_list(is);
    sc_raw = make_scenario_b_local(snr_db, 0);
    log_msg(fid_log, 'Scenario B fairness block SNR=%g dB: el_true=[0 0], shared raw observations across el_assumed.', snr_db);
    s1_base = exp(1j * 2*pi * (0:T_snap-1) / 17);
    v_base = exp(1j * 2*pi * (0:T_snap-1) / 23 + 1j*pi/7);

    for imc = 1:Metkl
        rng(base_seed + is * 1000 + imc);
        s1 = s1_base .* exp(1j * 2*pi * rand);
        v = v_base .* exp(1j * 2*pi * rand);
        y_clean_2d = make_clean_cylindrical_observations_general_local( ...
            X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, theta_true(1), theta_true(2), ...
            0, 0, beta, phi_deg, rho, s1, v);
        y_noisy_2d = add_noise_local(y_clean_2d, snr_db);

        R2d_music = level3_fbss_cov_from_observation_local(y_noisy_2d, K_phi_music, K_z_music);
        r3_music = run_level3_2d_music_route_local(R2d_music, music_cache, Lc);
        R2d_covfit = level3_fbss_cov_selected_from_observation_local(y_noisy_2d, K_phi_covfit, K_z_covfit, p_sel, r_sel);
        r4_old = run_level3_common_el_rank1_covfit_precomp_local( ...
            R2d_covfit, common_candidates, common_old_precomp, theta_true, [0, 0]);
        r5_power = run_common_el_refocus_power_route_local( ...
            y_noisy_2d, Z3d, cfg.arr.lambda, el_refocus_grid, level2_refocus_cache_map, az_grid, ...
            K_phi_level2, theta_true, min_pair_sep_deg, max_pair_sep_deg);
        r6_music_peak = run_common_el_refocus_music_peak_route_local( ...
            y_noisy_2d, Z3d, cfg.arr.lambda, r3_music, music_cache, level2_refocus_cache_map, az_grid, ...
            K_phi_level2, theta_true, min_pair_sep_deg, max_pair_sep_deg);
        r7_rank1_obj = run_common_el_refocus_rank1_objective_route_local( ...
            y_noisy_2d, Z3d, cfg.arr.lambda, el_refocus_grid, level2_refocus_cache_map, az_grid, ...
            K_phi_level2, theta_true, min_pair_sep_deg, max_pair_sep_deg);
        r8_oracle = run_level3_oracle_rank1_route_local( ...
            R2d_covfit, X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, theta_true, [0, 0], ...
            beta, phi_deg, K_phi_covfit, K_z_covfit, p_sel, r_sel, min_pair_sep_deg, max_pair_sep_deg);

        if ~curve_example.valid && snr_db == 8
            curve_example = make_refocus_curve_example_local(r5_power, r7_rank1_obj);
        end

        for ie = 1:numel(el_assumed_list)
            sc_now = make_scenario_b_local(snr_db, el_assumed_list(ie));
            r1 = run_level2_rank1_route_local( ...
                y_noisy_2d, Z3d, cfg.arr.lambda, sc_now.el_assumed, level2_cache_map, az_grid, ...
                K_phi_level2, theta_true, min_pair_sep_deg, max_pair_sep_deg);
            r2 = run_level2_el_bank_route_local( ...
                y_noisy_2d, Z3d, cfg.arr.lambda, el_bank, level2_cache_map, az_grid, ...
                K_phi_level2, theta_true, min_pair_sep_deg, max_pair_sep_deg);
            route_results = {r1, r2, r3_music, r4_old, r5_power, r6_music_peak, r7_rank1_obj, r8_oracle};
            for ir = 1:numel(route_names)
                stores{is, ie} = store_route_trial_local(stores{is, ie}, ir, imc, ...
                    route_results{ir}, theta_true, sc_now.el_true, az_tol_deg, el_tol_deg);
            end
        end

        trial_count = trial_count + 1;
        trial_results(trial_count).scenario = sc_raw; %#ok<SAGROW>
        trial_results(trial_count).mc = imc;
        trial_results(trial_count).refocus_results = {r3_music, r4_old, r5_power, r6_music_peak, r7_rank1_obj, r8_oracle};
    end
end

for is = 1:numel(snr_list)
    for ie = 1:numel(el_assumed_list)
        sc = make_scenario_b_local(snr_list(is), el_assumed_list(ie));
        for ir = 1:numel(route_names)
            metrics = summarize_route_trials_local(stores{is, ie}(ir));
            summary_rows(end+1, :) = make_summary_row_local(sc, route_names{ir}, metrics); %#ok<AGROW>
            log_msg(fid_log, 'SNR=%g el_assumed=%g %-45s joint=%.3f az=%.3f el=%.3f rmse=[%.4f %.4f] reason=%s', ...
                snr_list(is), el_assumed_list(ie), route_names{ir}, metrics.joint_tol_success_rate, ...
                metrics.az_tol_success_rate_abs01, metrics.el_tol_success_rate_abs05, ...
                metrics.az_rmse_deg, metrics.el_rmse_deg, metrics.route_failure_reason);
        end
    end
end
elapsed_sec = toc;
log_msg(fid_log, 'Finished in %.2f sec.', elapsed_sec);

summary_tbl = cell2table(summary_rows, 'VariableNames', summary_var_names_local());
summary_tbl = add_refocus_gap_diagnostics_local(summary_tbl);
writetable(summary_tbl, summary_csv_path);
keypoints_tbl = build_keypoints_local(summary_tbl);
writetable(keypoints_tbl, keypoints_csv_path);

plot_refocus_el_hat_vs_true_local(summary_tbl, fullfile(result_dir, 'refocus_el_hat_vs_true.png'));
plot_refocus_route_tol_compare_local(summary_tbl, fullfile(result_dir, 'refocus_route_tol_compare.png'));
plot_refocus_power_curve_example_local(curve_example, fullfile(result_dir, 'refocus_power_curve_example.png'));
plot_refocus_rank1_objective_vs_el_local(curve_example, fullfile(result_dir, 'refocus_rank1_objective_vs_el.png'));
plot_oracle_gap_local(summary_tbl, fullfile(result_dir, 'refocus_nonoracle_vs_oracle_gap.png'));

save(mat_path, 'summary_tbl', 'keypoints_tbl', 'trial_results', 'route_names', ...
    'az_grid', 'az_covfit_grid', 'el_grid', 'el_refocus_grid', 'el_common_grid', ...
    'el_assumed_list', 'theta_true', 'theta_sep', ...
    'K_phi_covfit', 'K_z_covfit', 'p_sel', 'r_sel', 'curve_example', 'cfg', '-v7.3');

write_record_doc_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, K_phi_level2);
log_msg(fid_log, 'Outputs written to %s', result_dir);

function scenarios = build_scenarios_local(snr_list)
    scenarios = struct([]);
    idx = 0;
    el_b_list = [0, 1, 2, 5, 10];
    for ib = 1:numel(el_b_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx).stage = 'A';
            scenarios(idx).case_name = sprintf('elB_%g', el_b_list(ib));
            scenarios(idx).el_true = [0, el_b_list(ib)];
            scenarios(idx).el_assumed = 0;
            scenarios(idx).snr_db = snr_list(is);
            scenarios(idx).el_b = el_b_list(ib);
            scenarios(idx).el_mismatch = 0;
        end
    end
    el_assumed_list = [0, 2, 5, 10];
    for ie = 1:numel(el_assumed_list)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx).stage = 'B';
            scenarios(idx).case_name = sprintf('el0_%g', el_assumed_list(ie));
            scenarios(idx).el_true = [0, 0];
            scenarios(idx).el_assumed = el_assumed_list(ie);
            scenarios(idx).snr_db = snr_list(is);
            scenarios(idx).el_b = 0;
            scenarios(idx).el_mismatch = el_assumed_list(ie);
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
    az1 = az_est(1) + (-0.08:0.02:0.08);
    az2 = az_est(2) + (-0.08:0.02:0.08);
    el1 = el_est(1) + (-1:0.5:1);
    el2 = el_est(2) + (-1:0.5:1);
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
        'el_selection_method', strings(Metkl, 1), 'failure_reason', strings(Metkl, 1));
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
end

function row = make_summary_row_local(sc, route_name, metrics)
    row = {sc.stage, sc.case_name, sc.el_b, sc.el_mismatch, sc.snr_db, route_name, ...
        metrics.raw_success_rate, metrics.az_tol_success_rate_abs01, metrics.el_tol_success_rate_abs05, ...
        metrics.joint_tol_success_rate, metrics.az_rmse_deg, metrics.el_rmse_deg, metrics.pair_2d_rmse, ...
        metrics.peak_count_mean, metrics.degraded_rate, string(metrics.route_failure_reason), ...
        metrics.objective_true_pair, metrics.objective_best, metrics.objective_margin, ...
        metrics.objective_true_rank_median, metrics.el_hat_mean, metrics.el_hat_error_mean, ...
        metrics.el_hat_error_abs_mean, metrics.focused_power_peak_sharpness, ...
        metrics.lambda1_peak_sharpness, metrics.rank1_objective_valley_width_el, ...
        metrics.rank1_objective_selected_el_rank, string(metrics.el_selection_method), ...
        metrics.el_common_est_mean, metrics.el_common_est_error};
end

function names = summary_var_names_local()
    names = {'stage', 'case_name', 'el_b_deg', 'el_mismatch_deg', 'snr_db', 'route_name', ...
        'raw_success_rate', 'az_tol_success_rate_abs01', 'el_tol_success_rate_abs05', ...
        'joint_tol_success_rate', 'az_rmse_deg', 'el_rmse_deg', 'pair_2d_rmse', ...
        'peak_count_mean', 'degraded_rate', 'route_failure_reason', ...
        'mean_objective_true_pair', 'mean_objective_best', 'objective_margin', ...
        'objective_true_rank_median', 'el_hat_mean', 'el_hat_error_mean', ...
        'el_hat_error_abs_mean', 'focused_power_peak_sharpness', ...
        'lambda1_peak_sharpness', 'rank1_objective_valley_width_el', ...
        'rank1_objective_selected_el_rank', 'el_selection_method', ...
        'el_common_est_mean', 'el_common_est_error'};
end

function val = getfield_default_local(s, name, default_val)
    if isfield(s, name)
        val = s.(name);
    else
        val = default_val;
    end
end

function keypoints = build_keypoints_local(summary_tbl)
    r_l2 = "level2_rank1_wrong_el_assumed";
    r_elbank = "level2_el_bank_old";
    r_music = "level3_2d_music";
    r_old = "common_el_covfit_old";
    r_power = "common_el_refocus_power";
    r_music_peak = "common_el_refocus_2dmusic_peak";
    r_rank1 = "common_el_refocus_rank1_objective";
    r_oracle = "oracle_el_rank1_covfit";
    B = summary_tbl(strcmp(summary_tbl.stage, 'B'), :);
    ge5 = B.el_mismatch_deg >= 5;
    kp = {};
    kp(end+1, :) = {'B_l2_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_l2) & ge5)), 'level2 with wrong el_assumed'}; %#ok<AGROW>
    kp(end+1, :) = {'B_elbank_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_elbank) & ge5)), 'old el-bank baseline'}; %#ok<AGROW>
    kp(end+1, :) = {'B_music2d_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_music) & ge5)), '2D MUSIC baseline'}; %#ok<AGROW>
    kp(end+1, :) = {'B_common_old_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_old) & ge5)), 'old common-el covfit'}; %#ok<AGROW>
    kp(end+1, :) = {'B_refocus_power_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_power) & ge5)), 'power refocus + layer2 rank1'}; %#ok<AGROW>
    kp(end+1, :) = {'B_refocus_2dmusic_peak_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_music_peak) & ge5)), '2D MUSIC peak refocus + layer2 rank1'}; %#ok<AGROW>
    kp(end+1, :) = {'B_refocus_rank1_objective_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_rank1) & ge5)), 'rank1 objective refocus + layer2 rank1'}; %#ok<AGROW>
    kp(end+1, :) = {'B_oracle_joint_ge5', mean(B.joint_tol_success_rate(strcmp(B.route_name, r_oracle) & ge5)), 'oracle el rank1 upper bound'}; %#ok<AGROW>
    kp(end+1, :) = {'B_power_oracle_gap_ge5', gap_mean_local(B, r_power, r_oracle, ge5), 'oracle minus power refocus'}; %#ok<AGROW>
    kp(end+1, :) = {'B_music_peak_oracle_gap_ge5', gap_mean_local(B, r_music_peak, r_oracle, ge5), 'oracle minus music-peak refocus'}; %#ok<AGROW>
    kp(end+1, :) = {'B_rank1_objective_oracle_gap_ge5', gap_mean_local(B, r_rank1, r_oracle, ge5), 'oracle minus rank1-objective refocus'}; %#ok<AGROW>
    kp(end+1, :) = {'B_refocus_power_el_hat_abs_error_ge5', mean(B.el_hat_error_abs_mean(strcmp(B.route_name, r_power) & ge5), 'omitnan'), 'power el_hat abs error'}; %#ok<AGROW>
    kp(end+1, :) = {'B_refocus_2dmusic_peak_el_hat_abs_error_ge5', mean(B.el_hat_error_abs_mean(strcmp(B.route_name, r_music_peak) & ge5), 'omitnan'), '2D MUSIC peak el_hat abs error'}; %#ok<AGROW>
    kp(end+1, :) = {'B_refocus_rank1_objective_el_hat_abs_error_ge5', mean(B.el_hat_error_abs_mean(strcmp(B.route_name, r_rank1) & ge5), 'omitnan'), 'rank1 objective el_hat abs error'}; %#ok<AGROW>
    kp(end+1, :) = {'B_rank1_objective_valley_width_el_ge5', mean(B.rank1_objective_valley_width_el(strcmp(B.route_name, r_rank1) & ge5), 'omitnan'), 'rank1 objective el valley width'}; %#ok<AGROW>
    keypoints = cell2table(kp, 'VariableNames', {'keypoint', 'value', 'note'});
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

function plot_oracle_gap_local(tbl, path_out)
    B = tbl(strcmp(tbl.stage, 'B') & tbl.snr_db == 8, :);
    routes = {'common_el_covfit_old', 'common_el_refocus_power', ...
        'common_el_refocus_2dmusic_peak', 'common_el_refocus_rank1_objective', ...
        'oracle_el_rank1_covfit'};
    vals = zeros(numel(routes), numel(unique(B.el_mismatch_deg)));
    x = unique(B.el_mismatch_deg).';
    for ir = 1:numel(routes)
        for ix = 1:numel(x)
            mask = strcmp(B.route_name, routes{ir}) & B.el_mismatch_deg == x(ix);
            vals(ir, ix) = B.joint_tol_success_rate(mask);
        end
    end
    fig = figure('Visible', 'off');
    plot(x, vals', '-o', 'LineWidth', 1.2);
    grid on
    xlabel('el assumed mismatch (deg)');
    ylabel('joint tol success rate');
    ylim([-0.05, 1.05]);
    legend(routes, 'Interpreter', 'none', 'Location', 'best');
    title('Non-oracle vs oracle gap, stage B, SNR=8 dB');
    saveas(fig, path_out);
    close(fig);
end

function sc = make_scenario_b_local(snr_db, el_assumed)
    sc = struct();
    sc.stage = 'B';
    sc.case_name = sprintf('el0_%g', el_assumed);
    sc.el_true = [0, 0];
    sc.el_assumed = el_assumed;
    sc.snr_db = snr_db;
    sc.el_b = 0;
    sc.el_mismatch = el_assumed;
end

function summary_tbl = add_refocus_gap_diagnostics_local(summary_tbl)
    summary_tbl.same_raw_observation_flag = true(height(summary_tbl), 1);
    summary_tbl.nonoracle_oracle_gap = nan(height(summary_tbl), 1);
    snrs = unique(summary_tbl.snr_db).';
    els = unique(summary_tbl.el_mismatch_deg).';
    for isnr = 1:numel(snrs)
        for ie = 1:numel(els)
            mask_case = summary_tbl.snr_db == snrs(isnr) & summary_tbl.el_mismatch_deg == els(ie);
            oracle_mask = mask_case & strcmp(summary_tbl.route_name, 'oracle_el_rank1_covfit');
            if ~any(oracle_mask)
                continue
            end
            oracle_joint = summary_tbl.joint_tol_success_rate(find(oracle_mask, 1));
            summary_tbl.nonoracle_oracle_gap(mask_case) = oracle_joint - summary_tbl.joint_tol_success_rate(mask_case);
        end
    end
end

function plot_refocus_el_hat_vs_true_local(tbl, path_out)
    B = tbl(strcmp(tbl.stage, 'B') & tbl.snr_db == 8, :);
    routes = {'common_el_refocus_power', 'common_el_refocus_2dmusic_peak', 'common_el_refocus_rank1_objective'};
    vals = zeros(numel(routes), 1);
    for ir = 1:numel(routes)
        vals(ir) = mean(B.el_hat_mean(strcmp(B.route_name, routes{ir})), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    hold on
    yline(0, '--k', 'true el');
    grid on
    set(gca, 'XTick', 1:numel(routes), 'XTickLabel', routes, 'XTickLabelRotation', 25);
    ylabel('mean el hat (deg)');
    title('Refocus el hat vs true, SNR=8 dB');
    saveas(fig, path_out);
    close(fig);
end

function plot_refocus_route_tol_compare_local(tbl, path_out)
    B = tbl(strcmp(tbl.stage, 'B') & tbl.snr_db == 8, :);
    routes = unique(B.route_name, 'stable');
    x = unique(B.el_mismatch_deg).';
    fig = figure('Visible', 'off');
    hold on
    for ir = 1:numel(routes)
        y = zeros(size(x));
        for ix = 1:numel(x)
            mask = strcmp(B.route_name, routes{ir}) & B.el_mismatch_deg == x(ix);
            y(ix) = B.joint_tol_success_rate(mask);
        end
        plot(x, y, '-o', 'LineWidth', 1.2);
    end
    grid on
    xlabel('level2 el assumed (deg)');
    ylabel('joint tol success rate');
    ylim([-0.05, 1.05]);
    title('Refocus route tolerance compare, SNR=8 dB');
    legend(routes, 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_refocus_power_curve_example_local(example, path_out)
    fig = figure('Visible', 'off');
    if isfield(example, 'valid') && example.valid
        yyaxis left
        plot(example.el_grid, example.power_curve, '-o', 'LineWidth', 1.1);
        ylabel('focused power');
        yyaxis right
        plot(example.el_grid, example.lambda1_curve, '-s', 'LineWidth', 1.1);
        ylabel('lambda1');
        xlabel('el0 (deg)');
        grid on
        title('Refocus power/lambda1 example');
    else
        text(0.1, 0.5, 'No curve example captured');
        axis off
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_refocus_rank1_objective_vs_el_local(example, path_out)
    fig = figure('Visible', 'off');
    if isfield(example, 'valid') && example.valid
        plot(example.el_grid, example.objective_curve, '-o', 'LineWidth', 1.1);
        xlabel('el0 (deg)');
        ylabel('rank1 objective');
        grid on
        title('Rank1 objective vs refocus el example');
    else
        text(0.1, 0.5, 'No objective example captured');
        axis off
    end
    saveas(fig, path_out);
    close(fig);
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

function write_record_doc_local(record_doc_path, summary_tbl, keypoints_tbl, result_dir, elapsed_sec, K_phi_level2)
    fid = fopen(record_doc_path, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.7步_4：common-el重聚焦与层次二fallback验证记录\n\n');
    fprintf(fid, '## 实现范围\n\n');
    fprintf(fid, '- 新脚本：`space_smooth_music_B_cylindrical_level3_common_el_refocus.m`。\n');
    fprintf(fid, '- 新增 route：`common_el_refocus_power`、`common_el_refocus_2dmusic_peak`、`common_el_refocus_rank1_objective`。\n');
    fprintf(fid, '- 同一份 raw 65 x 32 noisy observation 复用于 el_assumed=[0,2,5,10]；refocus route 不使用错误 el_assumed。\n');
    fprintf(fid, '- refocus 后回到 K_phi=%d 的层次二 rank1 fallback；本轮不做 fullscan/V2/complex-gain/4D 搜索。\n\n', K_phi_level2);
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.3f | %s |\n', keypoints_tbl.keypoint{i}, keypoints_tbl.value(i), keypoints_tbl.note{i});
    end
    fprintf(fid, '\n## 判断\n\n');
    val_power = keypoint_value_local(keypoints_tbl, 'B_refocus_power_joint_ge5');
    val_music_peak = keypoint_value_local(keypoints_tbl, 'B_refocus_2dmusic_peak_joint_ge5');
    val_rank1 = keypoint_value_local(keypoints_tbl, 'B_refocus_rank1_objective_joint_ge5');
    val_oracle = keypoint_value_local(keypoints_tbl, 'B_oracle_joint_ge5');
    best_refocus = max([val_power, val_music_peak, val_rank1]);
    if best_refocus >= 0.9 && val_oracle >= 0.9
        fprintf(fid, '- common-el refocus + layer2 rank1 fallback 成功解决同俯仰强相干小间隔且俯仰先验错误的层次二边界。\n');
        fprintf(fid, '- 这说明层次三不一定要直接做完整 3D/4D covfit，可先估公共俯仰再回到成熟层次二 fallback。\n');
    elseif best_refocus > keypoint_value_local(keypoints_tbl, 'B_common_old_joint_ge5')
        fprintf(fid, '- refocus route 明显优于 old common-el，但尚未达到 0.9；先估公共俯仰再回到层次二是更稳方向，el_hat 仍需优化。\n');
    elseif val_oracle >= 0.9
        fprintf(fid, '- refocus route 仍失败但 oracle 成功，说明二维信息有效，公共俯仰非 oracle 估计仍是瓶颈。\n');
    else
        fprintf(fid, '- oracle 也未稳定成功，应先检查模型和评价流程。\n');
    end
    fprintf(fid, '- 本轮仍不需要回到 V2/general Rs；下一步应围绕公共俯仰估计和工程分流收束。\n\n');
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
