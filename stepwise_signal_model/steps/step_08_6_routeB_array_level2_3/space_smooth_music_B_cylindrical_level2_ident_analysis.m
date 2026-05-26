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

modify_doc_path = fullfile(script_dir, '第8.6步修改方向.md');
formula_doc_path = fullfile(script_dir, '第8.6步层次二和三公式推导.md');
part8_record_path = fullfile(script_dir, '第8.6步_层次二第八部分_complex_gain协方差拟合验证记录.md');
part9_record_path = fullfile(script_dir, '第8.6步_层次二第九部分_complex_gain_q估计诊断记录.md');
part7_record_path = fullfile(script_dir, '第8.6步_层次二第七部分_rank1协方差拟合工程压力测试记录.md');
part6_record_path = fullfile(script_dir, '第8.6步_层次二第六部分_rank1协方差拟合最终验证记录.md');
part9_result_dir = fullfile(script_dir, 'results_step8_6_level2_complex_gain_qdiagnostic');
part9_summary_csv = fullfile(part9_result_dir, 'step8_6_level2_complex_gain_qdiagnostic_summary.csv');
part9_keypoints_csv = fullfile(part9_result_dir, 'step8_6_level2_complex_gain_qdiagnostic_keypoints.csv');

assert(exist(modify_doc_path, 'file') == 2, 'Modify direction doc not found.');
assert(exist(formula_doc_path, 'file') == 2, 'Formula doc not found.');
assert(exist(part8_record_path, 'file') == 2, 'Part-8 record not found.');
assert(exist(part9_record_path, 'file') == 2, 'Part-9 record not found.');
assert(exist(part7_record_path, 'file') == 2, 'Part-7 record not found.');
assert(exist(part6_record_path, 'file') == 2, 'Part-6 record not found.');
assert(exist(part9_summary_csv, 'file') == 2, 'Part-9 summary CSV not found.');
assert(exist(part9_keypoints_csv, 'file') == 2, 'Part-9 keypoints CSV not found.');

result_dir = fullfile(script_dir, 'results_step8_6_level2_identifiability_analysis');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

record_doc_path = fullfile(script_dir, '第8.6步_层次二第十部分_complex_gain可辨识性与任务分流记录.md');
theory_doc_path = fullfile(script_dir, '第8.6步_层次二_模型可辨识性与任务分流说明.md');
log_path = fullfile(result_dir, 'step8_6_level2_identifiability_analysis.log');
summary_path = fullfile(result_dir, 'step8_6_level2_identifiability_summary.csv');
mat_path = fullfile(result_dir, 'step8_6_level2_identifiability_result.mat');

fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

log_msg(fid_log, 'Step 08.6 level 2 part 10: complex-gain identifiability analysis');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Modify direction doc: %s', modify_doc_path);
log_msg(fid_log, 'Formula doc: %s', formula_doc_path);
log_msg(fid_log, 'Read record: %s', part8_record_path);
log_msg(fid_log, 'Read record: %s', part9_record_path);
log_msg(fid_log, 'Read record: %s', part7_record_path);
log_msg(fid_log, 'Read record: %s', part6_record_path);
log_msg(fid_log, 'Read result: %s', part9_summary_csv);
log_msg(fid_log, 'Read result: %s', part9_keypoints_csv);
log_msg(fid_log, 'Scope guard: no V2, no level-3, no Q change, no q-grid expansion, no fullscan.');

part9_summary_tbl = readtable(part9_summary_csv, 'TextType', 'string');
part9_keypoints_tbl = readtable(part9_keypoints_csv, 'TextType', 'string');
log_msg(fid_log, 'Part-9 summary rows=%d, keypoints rows=%d', height(part9_summary_tbl), height(part9_keypoints_tbl));

azCtr_deg = 0;
el_a_deg = 0;
el_b_deg = 0;
el_assumed_deg = 0;
T_snap = 260;
Metkl = 20;
K_phi = 28;
Lc = 2;
sep_factor = 10;
snr_db = 8;
base_seed = 20260713;

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

log_msg(fid_log, '');
log_msg(fid_log, 'Geometry health check');
log_msg(fid_log, 'cfg.arr.Naz=%d, cfg.arr.Nel=%d, R=%.9f m, lambda=%.9f m', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.R, cfg.arr.lambda);
log_msg(fid_log, 'dPhi=%.9f deg, dz/lambda=%.9f, sectorHalf=%.9f deg, Q=%d', ...
    cfg.arr.dPhi, cfg.arr.dz / cfg.arr.lambda, cfg.beam.sectorHalf, Q);
log_msg(fid_log, 'theta_sep(sep=10)=%.9f deg, target_theta=[%.9f %.9f] deg', ...
    theta_sep, target_theta(1), target_theta(2));
if Q ~= 65
    log_msg(fid_log, 'WARNING: Q=%d, expected 65.', Q);
end

scenarios = build_ident_scenarios_local();
qdiag_refs = extract_qdiag_references_local(part9_summary_tbl, scenarios);

center_grid = azCtr_deg + (-0.15:0.005:0.15);
sep_grid = theta_sep + (-0.20:0.005:0.335);
sep_grid = sep_grid(sep_grid >= 0.05 & sep_grid <= 0.60);
[pair_map_pairs_theta, pair_map_idx] = build_center_sep_pairs_local(center_grid, sep_grid);
[angle_grid_pair, candidate_pairs_pair] = theta_pairs_to_grid_indices_local(pair_map_pairs_theta);
B_grid_pair = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_pair, 0, 0);
cache_pair = make_subarray_steer_cache_local(B_grid_pair, K_phi);

beta_grid_fine = logspace(log10(0.05), log10(3), 41);
phi_grid_fine = 0:5:180;
q_grid_fine = build_q_grid_info_local(beta_grid_fine, phi_grid_fine);
true_pair_complex = precompute_true_pair_complex_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, target_theta, 0, 0, K_phi);

[joint_pairs_theta, joint_theta1_grid, joint_theta2_grid, joint_idx_map, true_joint_pair_idx] = ...
    build_joint_theta_pairs_local(target_theta, 0.06, 0.01, 0.05, 0.40);
[angle_grid_joint, candidate_pairs_joint] = theta_pairs_to_grid_indices_local(joint_pairs_theta);
B_grid_joint = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, cfg.arr.lambda, angle_grid_joint, 0, 0);
cache_joint = make_subarray_steer_cache_local(B_grid_joint, K_phi);
precomp_joint = precompute_complex_pair_bases_local(cache_joint, candidate_pairs_joint);

ident_cfg = struct();
ident_cfg.X3d = X3d;
ident_cfg.Y3d = Y3d;
ident_cfg.Z3d = Z3d;
ident_cfg.A_ref_2d = A_ref_2d;
ident_cfg.lambda = cfg.arr.lambda;
ident_cfg.s_base = s_base;
ident_cfg.T_snap = T_snap;
ident_cfg.Metkl = Metkl;
ident_cfg.base_seed = base_seed;
ident_cfg.snr_db = snr_db;
ident_cfg.K_phi = K_phi;
ident_cfg.Lc = Lc;
ident_cfg.theta_sep = theta_sep;
ident_cfg.target_theta = target_theta;
ident_cfg.center_grid = center_grid;
ident_cfg.sep_grid = sep_grid;
ident_cfg.pair_map_idx = pair_map_idx;
ident_cfg.cache_pair = cache_pair;
ident_cfg.candidate_pairs_pair = candidate_pairs_pair;
ident_cfg.q_grid_fine = q_grid_fine;
ident_cfg.true_pair_complex = true_pair_complex;
ident_cfg.joint_pairs_theta = joint_pairs_theta;
ident_cfg.joint_idx_map = joint_idx_map;
ident_cfg.true_joint_pair_idx = true_joint_pair_idx;
ident_cfg.precomp_joint = precomp_joint;

scenario_results = cell(1, numel(scenarios));

log_msg(fid_log, '');
log_msg(fid_log, 'Scenario analysis');
for iScenario = 1:numel(scenarios)
    sc = scenarios(iScenario);
    log_msg(fid_log, '  %d/%d %s: beta=%.3f, phase=%.1f deg', ...
        iScenario, numel(scenarios), sc.scenario_name, sc.beta_true, sc.phase_true_deg);
    scenario_results{iScenario} = run_identifiability_scenario_local(sc, qdiag_refs(iScenario), ident_cfg, fid_log);
    log_msg(fid_log, '    route=%s, model=%s, q_est=%s, weak=%s, anti_phase=%s', ...
        scenario_results{iScenario}.recommended_route, ...
        yesno_local(scenario_results{iScenario}.model_feasible_flag), ...
        yesno_local(scenario_results{iScenario}.q_estimation_feasible_flag), ...
        yesno_local(scenario_results{iScenario}.weak_target_flag), ...
        yesno_local(scenario_results{iScenario}.anti_phase_degenerate_flag));
end

scenario_results = [scenario_results{:}];

summary_tbl = build_identifiability_summary_table_local(scenario_results);
writetable(summary_tbl, summary_path);

save(mat_path, 'ident_cfg', 'scenarios', 'qdiag_refs', 'scenario_results', 'summary_tbl');

plot_pair_map_local(fullfile(result_dir, 'ident_pair_map_beta1_phase0.png'), scenario_results, 'beta1_phase0');
plot_pair_map_local(fullfile(result_dir, 'ident_pair_map_beta0p3_phase0.png'), scenario_results, 'beta0p3_phase0');
plot_pair_map_local(fullfile(result_dir, 'ident_pair_map_beta0p1_phase0.png'), scenario_results, 'beta0p1_phase0');
plot_pair_map_local(fullfile(result_dir, 'ident_pair_map_phase150.png'), scenario_results, 'beta1_phase150');
plot_q_map_local(fullfile(result_dir, 'ident_q_map_beta0p3_phase0.png'), scenario_results, 'beta0p3_phase0');
plot_q_map_local(fullfile(result_dir, 'ident_q_map_phase150.png'), scenario_results, 'beta1_phase150');
plot_route_decision_matrix_local(fullfile(result_dir, 'ident_route_decision_matrix.png'), scenario_results);

write_theory_doc_local(theory_doc_path, scenarios, qdiag_refs, scenario_results, modify_doc_path, formula_doc_path, ...
    part8_record_path, part9_record_path, part7_record_path, part6_record_path, mfilename('fullpath'));
write_record_doc_local(record_doc_path, scenarios, qdiag_refs, scenario_results, summary_path, mat_path, ...
    modify_doc_path, formula_doc_path, part8_record_path, part9_record_path, part7_record_path, part6_record_path, ...
    fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_identifiability_analysis.m'), mfilename('fullpath'));

log_msg(fid_log, '');
log_msg(fid_log, 'Generated files:');
log_msg(fid_log, '  %s', summary_path);
log_msg(fid_log, '  %s', mat_path);
log_msg(fid_log, '  %s', fullfile(result_dir, 'ident_pair_map_beta1_phase0.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'ident_pair_map_beta0p3_phase0.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'ident_pair_map_beta0p1_phase0.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'ident_pair_map_phase150.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'ident_q_map_beta0p3_phase0.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'ident_q_map_phase150.png'));
log_msg(fid_log, '  %s', fullfile(result_dir, 'ident_route_decision_matrix.png'));
log_msg(fid_log, '  %s', record_doc_path);
log_msg(fid_log, '  %s', theory_doc_path);

safe_fclose_local(fid_log);
clear cleanup_log

disp('Step 08.6 level 2 identifiability analysis finished.');
disp(result_dir);

function scenarios = build_ident_scenarios_local()
    scenarios = struct('scenario_name', {}, 'case_name', {}, 'beta_true', {}, 'phase_true_deg', {});
    scenarios(end+1) = struct('scenario_name', 'beta1_phase0', 'case_name', 'beta_1', 'beta_true', 1.0, 'phase_true_deg', 0); %#ok<AGROW>
    scenarios(end+1) = struct('scenario_name', 'beta0p3_phase0', 'case_name', 'beta_0p3', 'beta_true', 0.3, 'phase_true_deg', 0); %#ok<AGROW>
    scenarios(end+1) = struct('scenario_name', 'beta0p1_phase0', 'case_name', 'beta_0p1', 'beta_true', 0.1, 'phase_true_deg', 0); %#ok<AGROW>
    scenarios(end+1) = struct('scenario_name', 'beta1_phase150', 'case_name', 'phase_150', 'beta_true', 1.0, 'phase_true_deg', 150); %#ok<AGROW>
    scenarios(end+1) = struct('scenario_name', 'beta1_phase180', 'case_name', 'phase_180', 'beta_true', 1.0, 'phase_true_deg', 180); %#ok<AGROW>
    scenarios(end+1) = struct('scenario_name', 'beta0p3_phase60', 'case_name', 'case_1_beta0p3_phase60', 'beta_true', 0.3, 'phase_true_deg', 60); %#ok<AGROW>
    scenarios(end+1) = struct('scenario_name', 'beta0p3_phase150', 'case_name', 'case_2_beta0p3_phase150', 'beta_true', 0.3, 'phase_true_deg', 150); %#ok<AGROW>
end

function refs = extract_qdiag_references_local(summary_tbl, scenarios)
    stage_col = string(summary_tbl.experiment_stage);
    route_col = string(summary_tbl.route_name);
    case_col = string(summary_tbl.case_name);
    refs = repmat(struct(), 1, numel(scenarios));
    for iScenario = 1:numel(scenarios)
        case_name = string(scenarios(iScenario).case_name);
        mask_base = stage_col == "snr8_sanity" & case_col == case_name;
        refs(iScenario).case_name = scenarios(iScenario).case_name;
        refs(iScenario).equal_tol = lookup_qdiag_value_local(summary_tbl, mask_base & route_col == "covfit_rank1_equal_phase", 'tol_success_rate_abs01');
        refs(iScenario).old_tol = lookup_qdiag_value_local(summary_tbl, mask_base & route_col == "complex_gain_grid_old", 'tol_success_rate_abs01');
        refs(iScenario).qfixed_tol = lookup_qdiag_value_local(summary_tbl, mask_base & route_col == "complex_gain_q_fixed_true", 'tol_success_rate_abs01');
        refs(iScenario).staged_tol = lookup_qdiag_value_local(summary_tbl, mask_base & route_col == "complex_gain_staged_search", 'tol_success_rate_abs01');
        refs(iScenario).true_q_rank = lookup_qdiag_value_local(summary_tbl, mask_base & route_col == "complex_gain_q_fixed_true", 'true_q_objective_rank_median');
    end
end

function value = lookup_qdiag_value_local(tbl, mask, var_name)
    if any(mask)
        value = tbl.(var_name)(find(mask, 1));
    else
        value = NaN;
    end
end

function result = run_identifiability_scenario_local(sc, qdiag_ref, ident_cfg, fid_log)
    q_true_info = build_q_grid_info_local(sc.beta_true, sc.phase_true_deg);
    q_true_complex = q_true_info.q_grid(1);
    precomp_pair_qfixed = precompute_qfixed_pair_bases_local(ident_cfg.cache_pair, ident_cfg.candidate_pairs_pair, q_true_complex);
    q_local = build_local_q_grid_local(sc.beta_true, sc.phase_true_deg);
    true_q_local_idx = find_q_grid_index_local(q_local, sc.beta_true, sc.phase_true_deg);

    nCenter = numel(ident_cfg.center_grid);
    nSep = numel(ident_cfg.sep_grid);
    nBeta = numel(ident_cfg.q_grid_fine.beta_grid);
    nPhi = numel(ident_cfg.q_grid_fine.phi_grid_deg);

    pair_map_sum = zeros(nCenter, nSep);
    q_map_sum = zeros(nBeta, nPhi);
    joint_pair_best_sum = zeros(size(ident_cfg.joint_idx_map));

    pair_rank_vals = zeros(ident_cfg.Metkl, 1);
    pair_sep_width_vals = zeros(ident_cfg.Metkl, 1);
    pair_center_width_vals = zeros(ident_cfg.Metkl, 1);
    pair_curv_center_vals = zeros(ident_cfg.Metkl, 1);
    pair_curv_sep_vals = zeros(ident_cfg.Metkl, 1);
    q_rank_vals = zeros(ident_cfg.Metkl, 1);
    q_beta_width_vals = zeros(ident_cfg.Metkl, 1);
    q_phi_width_vals = zeros(ident_cfg.Metkl, 1);
    q_boundary_flag_vals = false(ident_cfg.Metkl, 1);
    q_recip_flag_vals = false(ident_cfg.Metkl, 1);
    gap_vals = zeros(ident_cfg.Metkl, 1);
    competing_vals = zeros(ident_cfg.Metkl, 1);
    true_better_vals = false(ident_cfg.Metkl, 1);

    debug_samples = struct([]);
    s2_clean = make_engineering_s2_local(ident_cfg.s_base, sc.beta_true, sc.phase_true_deg, 1, ident_cfg.base_seed);
    y_clean_2d = make_clean_cylindrical_observations_level2_local( ...
        ident_cfg.X3d, ident_cfg.Y3d, ident_cfg.Z3d, ident_cfg.A_ref_2d, ident_cfg.lambda, ...
        ident_cfg.target_theta(1), ident_cfg.target_theta(2), 0, 0, ident_cfg.s_base, s2_clean);
    noise_power = mean(abs(y_clean_2d(:)).^2) / 10^(ident_cfg.snr_db / 10);

    for metkl_num = 1:ident_cfg.Metkl
        seed_now = ident_cfg.base_seed + 100000 * find(strcmp({build_ident_scenarios_local().scenario_name}, sc.scenario_name), 1) + metkl_num;
        rng(seed_now, 'twister');
        noise = sqrt(noise_power/2) * (randn(size(y_clean_2d)) + 1j * randn(size(y_clean_2d)));
        y_2d = y_clean_2d + noise;
        y_combined = combine_layers_level2_local(y_2d, ident_cfg.Z3d, ident_cfg.lambda, 0);
        [Rfb, ~] = fbss_covariance_and_noise_subspace_local(y_combined, ident_cfg.K_phi, ident_cfg.Lc);

        pair_scores = score_basis_search_local(Rfb, precomp_pair_qfixed);
        pair_map = vector_to_map_local(pair_scores, ident_cfg.pair_map_idx);
        pair_metrics = analyze_pair_map_local(pair_map, ident_cfg.center_grid, ident_cfg.sep_grid, 0, ident_cfg.theta_sep);

        q_scores = score_complex_all_local(Rfb, ident_cfg.true_pair_complex, ident_cfg.q_grid_fine);
        q_map = reshape(q_scores, nBeta, nPhi);
        q_metrics = analyze_q_map_local(q_map, ident_cfg.q_grid_fine.beta_grid, ident_cfg.q_grid_fine.phi_grid_deg, sc.beta_true, sc.phase_true_deg);

        joint_scores = score_complex_all_local(Rfb, ident_cfg.precomp_joint, q_local);
        joint_metrics = analyze_joint_map_local(joint_scores, ident_cfg.joint_pairs_theta, q_local, ident_cfg.true_joint_pair_idx, true_q_local_idx);
        joint_pair_best_map = vector_to_map_local(min(joint_scores, [], 2), ident_cfg.joint_idx_map);

        pair_map_sum = pair_map_sum + pair_map;
        q_map_sum = q_map_sum + q_map;
        joint_pair_best_sum = joint_pair_best_sum + fillmissing(joint_pair_best_map, 'constant', 0);

        pair_rank_vals(metkl_num) = pair_metrics.true_pair_rank;
        pair_sep_width_vals(metkl_num) = pair_metrics.valley_sep_width;
        pair_center_width_vals(metkl_num) = pair_metrics.valley_center_width;
        pair_curv_center_vals(metkl_num) = pair_metrics.curvature_center;
        pair_curv_sep_vals(metkl_num) = pair_metrics.curvature_sep;
        q_rank_vals(metkl_num) = q_metrics.true_q_rank;
        q_beta_width_vals(metkl_num) = q_metrics.valley_beta_width;
        q_phi_width_vals(metkl_num) = q_metrics.valley_phi_width;
        q_boundary_flag_vals(metkl_num) = q_metrics.boundary_low_valley_flag;
        q_recip_flag_vals(metkl_num) = q_metrics.reciprocal_low_valley_flag;
        gap_vals(metkl_num) = joint_metrics.objective_gap_true_vs_best_wrong;
        competing_vals(metkl_num) = joint_metrics.num_competing_minima;
        true_better_vals(metkl_num) = joint_metrics.objective_gap_true_vs_best_wrong > 0;

        if metkl_num == 1
            debug_samples(1).seed_now = seed_now; %#ok<AGROW>
            debug_samples(1).pair_map = pair_map;
            debug_samples(1).q_map = q_map;
            debug_samples(1).joint_pair_best_map = joint_pair_best_map;
            debug_samples(1).pair_metrics = pair_metrics;
            debug_samples(1).q_metrics = q_metrics;
            debug_samples(1).joint_metrics = joint_metrics;
        end
    end

    pair_map_mean = pair_map_sum / ident_cfg.Metkl;
    q_map_mean = q_map_sum / ident_cfg.Metkl;
    joint_pair_best_mean = joint_pair_best_sum / ident_cfg.Metkl;

    pair_rank_med = median(pair_rank_vals, 'omitnan');
    q_rank_med = median(q_rank_vals, 'omitnan');
    pair_sep_width_med = median(pair_sep_width_vals, 'omitnan');
    pair_center_width_med = median(pair_center_width_vals, 'omitnan');
    q_beta_width_med = median(q_beta_width_vals, 'omitnan');
    q_phi_width_med = median(q_phi_width_vals, 'omitnan');
    gap_med = median(gap_vals, 'omitnan');
    competing_med = round(median(competing_vals, 'omitnan'));
    pair_curv_center_med = median(pair_curv_center_vals, 'omitnan');
    pair_curv_sep_med = median(pair_curv_sep_vals, 'omitnan');
    boundary_low_flag = mean(q_boundary_flag_vals) >= 0.5;
    reciprocal_low_flag = mean(q_recip_flag_vals) >= 0.5;

    weak_target_flag = sc.beta_true <= 0.15 && qdiag_ref.qfixed_tol < 0.6;
    anti_phase_flag = sc.phase_true_deg >= 150 && qdiag_ref.qfixed_tol < 0.1 && ...
        (pair_rank_med > 5 || gap_med <= 0);
    % model_feasible_flag means the level-2 complex-gain model can recover the
    % angle pair when q is given; it does not require the theta/q landscape to
    % be sharp enough for direct engineering deployment.
    model_feasible_flag = ~weak_target_flag && ~anti_phase_flag && qdiag_ref.qfixed_tol >= 0.75;
    q_estimation_feasible_flag = model_feasible_flag && pair_rank_med <= 5 && gap_med > 0 && ...
        q_rank_med <= 5 && ...
        q_beta_width_med <= max(0.15, 0.75 * sc.beta_true) && ...
        q_phi_width_med <= 30 && ~boundary_low_flag && ~reciprocal_low_flag;

    if abs(sc.beta_true - 1) < 1e-12 && abs(sc.phase_true_deg) < 1e-12
        recommended_route = "V0_equal_phase_mainline";
    elseif anti_phase_flag
        recommended_route = "anti_phase_boundary";
    elseif weak_target_flag
        recommended_route = "weak_target_boundary";
    elseif model_feasible_flag && q_estimation_feasible_flag
        recommended_route = "V1_possible";
    elseif model_feasible_flag || qdiag_ref.qfixed_tol >= qdiag_ref.old_tol + 0.15
        recommended_route = "V1_needs_prior_or_regularization";
    else
        recommended_route = "task_split_required";
    end

    result = struct();
    result.scenario_name = sc.scenario_name;
    result.case_name = sc.case_name;
    result.beta_true = sc.beta_true;
    result.phase_true_deg = sc.phase_true_deg;
    result.qdiag_ref = qdiag_ref;
    result.model_feasible_flag = model_feasible_flag;
    result.q_estimation_feasible_flag = q_estimation_feasible_flag;
    result.weak_target_flag = weak_target_flag;
    result.anti_phase_degenerate_flag = anti_phase_flag;
    result.boundary_low_valley_flag = boundary_low_flag;
    result.reciprocal_low_valley_flag = reciprocal_low_flag;
    result.true_pair_rank_qfixed = pair_rank_med;
    result.true_q_rank_thetaf = q_rank_med;
    result.valley_sep_width_qfixed = pair_sep_width_med;
    result.valley_center_width_qfixed = pair_center_width_med;
    result.valley_beta_width_thetaf = q_beta_width_med;
    result.valley_phi_width_thetaf = q_phi_width_med;
    result.objective_gap_true_vs_best_wrong = gap_med;
    result.num_competing_minima = competing_med;
    result.recommended_route = recommended_route;
    result.pair_curvature_center = pair_curv_center_med;
    result.pair_curvature_sep = pair_curv_sep_med;
    result.true_better_rate = mean(true_better_vals);
    result.pair_map_mean = pair_map_mean;
    result.q_map_mean = q_map_mean;
    result.joint_pair_best_mean = joint_pair_best_mean;
    result.center_grid = ident_cfg.center_grid;
    result.sep_grid = ident_cfg.sep_grid;
    result.theta_sep = ident_cfg.theta_sep;
    result.beta_grid_fine = ident_cfg.q_grid_fine.beta_grid;
    result.phi_grid_fine = ident_cfg.q_grid_fine.phi_grid_deg;
    result.joint_theta1_grid = joint_theta1_grid_from_pairs_local(ident_cfg.joint_pairs_theta);
    result.joint_theta2_grid = joint_theta2_grid_from_pairs_local(ident_cfg.joint_pairs_theta);
    result.trial_metrics = struct( ...
        'pair_rank', pair_rank_vals, ...
        'pair_valley_sep_width', pair_sep_width_vals, ...
        'pair_valley_center_width', pair_center_width_vals, ...
        'pair_curvature_center', pair_curv_center_vals, ...
        'pair_curvature_sep', pair_curv_sep_vals, ...
        'q_rank', q_rank_vals, ...
        'q_valley_beta_width', q_beta_width_vals, ...
        'q_valley_phi_width', q_phi_width_vals, ...
        'q_boundary_low_valley_flag', q_boundary_flag_vals, ...
        'q_reciprocal_low_valley_flag', q_recip_flag_vals, ...
        'objective_gap_true_vs_best_wrong', gap_vals, ...
        'num_competing_minima', competing_vals);
    result.debug_samples = debug_samples;

    log_msg(fid_log, '    qdiag old/qfixed/equal/staged = %.3f / %.3f / %.3f / %.3f', ...
        qdiag_ref.old_tol, qdiag_ref.qfixed_tol, qdiag_ref.equal_tol, qdiag_ref.staged_tol);
    log_msg(fid_log, '    pair_rank=%.1f, q_rank=%.1f, pair_valley_sep=%.4f, q_valley_beta=%.4f, q_valley_phi=%.1f, gap=%.6g, competing=%d', ...
        pair_rank_med, q_rank_med, pair_sep_width_med, q_beta_width_med, q_phi_width_med, gap_med, competing_med);
end

function summary_tbl = build_identifiability_summary_table_local(results)
    n = numel(results);
    summary_tbl = table('Size', [n, 20], ...
        'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double', ...
        'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', ...
        'double', 'double', 'double', 'string'}, ...
        'VariableNames', {'scenario_name', 'beta_true', 'phase_true_deg', 'model_feasible_flag', ...
        'q_estimation_feasible_flag', 'weak_target_flag', 'anti_phase_degenerate_flag', 'true_pair_rank_qfixed', ...
        'true_q_rank_thetaf', 'valley_sep_width_qfixed', 'valley_center_width_qfixed', ...
        'valley_beta_width_thetaf', 'valley_phi_width_thetaf', 'objective_gap_true_vs_best_wrong', ...
        'num_competing_minima', 'qdiag_tol_old', 'qdiag_tol_qfixed', 'boundary_low_valley_flag', ...
        'reciprocal_low_valley_flag', 'recommended_route'});
    for i = 1:n
        r = results(i);
        summary_tbl.scenario_name(i) = string(r.scenario_name);
        summary_tbl.beta_true(i) = r.beta_true;
        summary_tbl.phase_true_deg(i) = r.phase_true_deg;
        summary_tbl.model_feasible_flag(i) = double(r.model_feasible_flag);
        summary_tbl.q_estimation_feasible_flag(i) = double(r.q_estimation_feasible_flag);
        summary_tbl.weak_target_flag(i) = double(r.weak_target_flag);
        summary_tbl.anti_phase_degenerate_flag(i) = double(r.anti_phase_degenerate_flag);
        summary_tbl.true_pair_rank_qfixed(i) = r.true_pair_rank_qfixed;
        summary_tbl.true_q_rank_thetaf(i) = r.true_q_rank_thetaf;
        summary_tbl.valley_sep_width_qfixed(i) = r.valley_sep_width_qfixed;
        summary_tbl.valley_center_width_qfixed(i) = r.valley_center_width_qfixed;
        summary_tbl.valley_beta_width_thetaf(i) = r.valley_beta_width_thetaf;
        summary_tbl.valley_phi_width_thetaf(i) = r.valley_phi_width_thetaf;
        summary_tbl.objective_gap_true_vs_best_wrong(i) = r.objective_gap_true_vs_best_wrong;
        summary_tbl.num_competing_minima(i) = r.num_competing_minima;
        summary_tbl.qdiag_tol_old(i) = r.qdiag_ref.old_tol;
        summary_tbl.qdiag_tol_qfixed(i) = r.qdiag_ref.qfixed_tol;
        summary_tbl.boundary_low_valley_flag(i) = double(r.boundary_low_valley_flag);
        summary_tbl.reciprocal_low_valley_flag(i) = double(r.reciprocal_low_valley_flag);
        summary_tbl.recommended_route(i) = string(r.recommended_route);
    end
end

function [pairs_theta, idx_map] = build_center_sep_pairs_local(center_grid, sep_grid)
    idx_map = zeros(numel(center_grid), numel(sep_grid));
    pairs_theta = zeros(numel(center_grid) * numel(sep_grid), 2);
    count = 0;
    for ic = 1:numel(center_grid)
        for is = 1:numel(sep_grid)
            count = count + 1;
            idx_map(ic, is) = count;
            pairs_theta(count, :) = [center_grid(ic) - sep_grid(is) / 2, center_grid(ic) + sep_grid(is) / 2];
        end
    end
    pairs_theta = pairs_theta(1:count, :);
end

function [pairs_theta, theta1_grid, theta2_grid, idx_map, true_pair_idx] = build_joint_theta_pairs_local(target_theta, half_width, step, min_sep, max_sep)
    theta1_grid = target_theta(1) + (-half_width:step:half_width);
    theta2_grid = target_theta(2) + (-half_width:step:half_width);
    idx_map = zeros(numel(theta1_grid), numel(theta2_grid));
    pairs_theta = zeros(numel(theta1_grid) * numel(theta2_grid), 2);
    count = 0;
    true_pair_idx = NaN;
    for i1 = 1:numel(theta1_grid)
        for i2 = 1:numel(theta2_grid)
            sep_now = theta2_grid(i2) - theta1_grid(i1);
            if sep_now < min_sep || sep_now > max_sep
                continue
            end
            count = count + 1;
            idx_map(i1, i2) = count;
            pairs_theta(count, :) = [theta1_grid(i1), theta2_grid(i2)];
            if abs(theta1_grid(i1) - target_theta(1)) < 1e-12 && abs(theta2_grid(i2) - target_theta(2)) < 1e-12
                true_pair_idx = count;
            end
        end
    end
    pairs_theta = pairs_theta(1:count, :);
    if ~isfinite(true_pair_idx)
        error('True pair was not included in the local joint theta grid.');
    end
end

function q_local = build_local_q_grid_local(beta_true, phi_true_deg)
    beta_mult = exp(linspace(log(0.5), log(1.8), 9));
    beta_grid = round(beta_true * beta_mult, 6);
    beta_grid = min(max(beta_grid, 0.05), 3);
    beta_grid = unique(sort([beta_grid, beta_true]));
    phi_grid = min(max(phi_true_deg + (-30:10:30), 0), 180);
    phi_grid = unique(sort([phi_grid, phi_true_deg]));
    q_local = build_q_grid_info_local(beta_grid, phi_grid);
end

function precomp = precompute_qfixed_pair_bases_local(cache, candidate_pairs, q_complex)
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
        C = A1 + q_complex * A2;
        F = (C * C') / P_phi;
        G = fb_project_local(F, J);
        v = matrix_to_realvec_local(G);
        g_basis(:, ic) = single(v);
        gg(ic) = real(v' * v);
        gi(ic) = real(v' * ivec);
    end
    precomp = struct();
    precomp.g_basis = g_basis;
    precomp.gg = gg;
    precomp.gi = gi;
    precomp.ivec = single(ivec);
    precomp.ii = ii;
end

function score = score_basis_search_local(Robs, precomp)
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
    val_both(ok_both) = -2 * (alpha(ok_both) .* gy(ok_both) + sigma2(ok_both) * iy) + ...
        alpha(ok_both).^2 .* gg(ok_both) + 2 * alpha(ok_both) .* sigma2(ok_both) .* gi(ok_both) + sigma2(ok_both).^2 * ii;
    alpha_only = max(gy ./ max(gg, eps), 0);
    val_alpha = -2 * alpha_only .* gy + alpha_only.^2 .* gg;
    sigma_only = max(iy / max(ii, eps), 0);
    val_sigma = -2 * sigma_only * iy + sigma_only.^2 * ii;
    val_zero = zeros(size(gg));
    best_delta = min([val_both, val_alpha, repmat(val_sigma, size(gg)), val_zero], [], 2);
    score = (yy + best_delta) / max(yy, eps);
end

function metrics = analyze_pair_map_local(pair_map, center_grid, sep_grid, true_center, true_sep)
    [~, ic] = min(abs(center_grid - true_center));
    [~, is] = min(abs(sep_grid - true_sep));
    flat = pair_map(:);
    true_score = pair_map(ic, is);
    best_score = min(flat);
    score_range = max(flat) - min(flat);
    delta = max(1e-6, 0.05 * score_range);
    mask_true = pair_map <= true_score + delta;
    comp_true = connected_component_from_seed_local(mask_true, [ic, is]);
    [rows, cols] = find(comp_true);
    metrics = struct();
    metrics.true_pair_rank = 1 + sum(flat < true_score);
    metrics.valley_sep_width = sep_grid(max(cols)) - sep_grid(min(cols));
    metrics.valley_center_width = center_grid(max(rows)) - center_grid(min(rows));
    metrics.curvature_center = second_diff_nonuniform_local(center_grid, pair_map(:, is), ic);
    metrics.curvature_sep = second_diff_nonuniform_local(sep_grid, pair_map(ic, :).', is);
    metrics.true_score = true_score;
    metrics.best_score = best_score;
    metrics.num_global_low_components = count_components_local(pair_map <= best_score + delta);
end

function metrics = analyze_q_map_local(q_map, beta_grid, phi_grid, beta_true, phi_true_deg)
    [~, ib] = min(abs(beta_grid - beta_true));
    [~, ip] = min(abs(phi_grid - phi_true_deg));
    flat = q_map(:);
    true_score = q_map(ib, ip);
    best_score = min(flat);
    score_range = max(flat) - min(flat);
    delta = max(1e-6, 0.05 * score_range);
    mask_true = q_map <= true_score + delta;
    comp_true = connected_component_from_seed_local(mask_true, [ib, ip]);
    [rows, cols] = find(comp_true);
    global_mask = q_map <= best_score + delta;
    reciprocal_beta = min(max(1 / beta_true, beta_grid(1)), beta_grid(end));
    reciprocal_phi = mod(-phi_true_deg, 360);
    if reciprocal_phi > 180
        reciprocal_phi = 360 - reciprocal_phi;
    end
    [~, ibr] = min(abs(beta_grid - reciprocal_beta));
    [~, ipr] = min(abs(phi_grid - reciprocal_phi));

    metrics = struct();
    metrics.true_q_rank = 1 + sum(flat < true_score);
    metrics.valley_beta_width = beta_grid(max(rows)) - beta_grid(min(rows));
    metrics.valley_phi_width = phi_grid(max(cols)) - phi_grid(min(cols));
    metrics.true_score = true_score;
    metrics.best_score = best_score;
    metrics.boundary_low_valley_flag = any(global_mask(1, :), 'all') || any(global_mask(end, :), 'all') || ...
        any(global_mask(:, 1), 'all') || any(global_mask(:, end), 'all');
    metrics.reciprocal_low_valley_flag = q_map(ibr, ipr) <= best_score + delta;
end

function metrics = analyze_joint_map_local(score_all, pairs_theta, q_local, true_pair_idx, true_q_idx)
    true_score = score_all(true_pair_idx, true_q_idx);
    mask_wrong = true(size(score_all));
    mask_wrong(true_pair_idx, true_q_idx) = false;
    best_wrong = min(score_all(mask_wrong));
    score_range = max(score_all(:)) - min(score_all(:));
    delta = max(1e-6, 0.05 * score_range);
    pair_best = min(score_all, [], 2);
    pair_best_global = min(pair_best);
    pair_centers = mean(pairs_theta, 2);
    pair_seps = pairs_theta(:, 2) - pairs_theta(:, 1);
    true_center = mean(pairs_theta(true_pair_idx, :));
    true_sep = diff(pairs_theta(true_pair_idx, :));
    is_far = abs(pair_centers - true_center) > 0.015 | abs(pair_seps - true_sep) > 0.015;

    metrics = struct();
    metrics.objective_gap_true_vs_best_wrong = best_wrong - true_score;
    metrics.num_competing_minima = sum(is_far & pair_best <= pair_best_global + delta);
    metrics.true_joint_rank = 1 + sum(score_all(:) < true_score);
end

function map = vector_to_map_local(vec, idx_map)
    map = nan(size(idx_map));
    mask = idx_map > 0;
    map(mask) = vec(idx_map(mask));
end

function plot_pair_map_local(path_out, results, scenario_name)
    idx = find(strcmp({results.scenario_name}, scenario_name), 1);
    r = results(idx);
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 620]);
    imagesc(r.sep_grid, r.center_grid, r.pair_map_mean);
    set(gca, 'YDir', 'normal');
    hold on
    plot(r.beta_true * 0 + (r.sep_grid(1) + 0), r.beta_true * 0 + (r.center_grid(1) + 0), 'w.'); %#ok<NASGU>
    plot([r.sep_grid(1), r.sep_grid(end)], [0, 0], '--w', 'LineWidth', 0.8);
    plot([r.theta_sep, r.theta_sep], [r.center_grid(1), r.center_grid(end)], '--w', 'LineWidth', 0.8);
    plot(r.theta_sep, 0, 'wo', 'MarkerFaceColor', 'w', 'MarkerSize', 7);
    hold off
    xlabel('theta sep (deg)');
    ylabel('theta center (deg)');
    title(sprintf('Pair objective map: %s', strrep(scenario_name, '_', '\_')));
    colorbar
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function plot_q_map_local(path_out, results, scenario_name)
    idx = find(strcmp({results.scenario_name}, scenario_name), 1);
    r = results(idx);
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 620]);
    imagesc(r.phi_grid_fine, log10(r.beta_grid_fine), r.q_map_mean);
    set(gca, 'YDir', 'normal');
    hold on
    plot(r.phase_true_deg, log10(r.beta_true), 'wo', 'MarkerFaceColor', 'w', 'MarkerSize', 7);
    hold off
    xlabel('phi (deg)');
    ylabel('log10(beta)');
    yticks(log10([0.05, 0.1, 0.3, 1, 3]));
    yticklabels({'0.05', '0.1', '0.3', '1', '3'});
    title(sprintf('Q objective map: %s', strrep(scenario_name, '_', '\_')));
    colorbar
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function plot_route_decision_matrix_local(path_out, results)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1180, 520]);
    ax = axes(fig);
    axis(ax, [0 7.2 0 numel(results) + 1]);
    axis(ax, 'off');
    hold(ax, 'on');

    headers = {'Scenario', 'Model', 'Q-Est', 'Weak', 'Anti', 'Route'};
    x_pos = [0.5, 2.2, 3.1, 4.0, 4.9, 6.15];
    for ih = 1:numel(headers)
        text(ax, x_pos(ih), numel(results) + 0.4, headers{ih}, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    end

    for i = 1:numel(results)
        y = numel(results) - i + 1;
        r = results(i);
        text(ax, x_pos(1), y, r.scenario_name, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
        draw_flag_cell_local(ax, x_pos(2), y, r.model_feasible_flag);
        draw_flag_cell_local(ax, x_pos(3), y, r.q_estimation_feasible_flag);
        draw_flag_cell_local(ax, x_pos(4), y, r.weak_target_flag);
        draw_flag_cell_local(ax, x_pos(5), y, r.anti_phase_degenerate_flag);
        text(ax, x_pos(6), y, char(r.recommended_route), 'HorizontalAlignment', 'center', 'Interpreter', 'none');
    end
    hold(ax, 'off');
    exportgraphics(fig, path_out, 'Resolution', 150);
    close(fig);
end

function draw_flag_cell_local(ax, x, y, flag)
    if flag
        fc = [0.67, 0.86, 0.67];
        txt = '1';
    else
        fc = [0.92, 0.92, 0.92];
        txt = '0';
    end
    rectangle(ax, 'Position', [x - 0.28, y - 0.28, 0.56, 0.56], 'FaceColor', fc, 'EdgeColor', [0.5, 0.5, 0.5]);
    text(ax, x, y, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontWeight', 'bold');
end

function write_theory_doc_local(path_out, scenarios, qdiag_refs, results, modify_doc_path, formula_doc_path, ...
    part8_record_path, part9_record_path, part7_record_path, part6_record_path, actual_script_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));

    idx_beta03 = find(strcmp({results.scenario_name}, 'beta0p3_phase0'), 1);
    idx_beta01 = find(strcmp({results.scenario_name}, 'beta0p1_phase0'), 1);
    idx_phase150 = find(strcmp({results.scenario_name}, 'beta1_phase150'), 1);
    idx_phase180 = find(strcmp({results.scenario_name}, 'beta1_phase180'), 1);

    fprintf(fid, '# 第8.6步 层次二模型可辨识性与任务分流说明\n\n');
    fprintf(fid, '## 读取依据\n\n');
    fprintf(fid, '- 修改方向文档：`%s`\n', modify_doc_path);
    fprintf(fid, '- 公式文档：`%s`\n', formula_doc_path);
    fprintf(fid, '- 第六部分记录：`%s`\n', part6_record_path);
    fprintf(fid, '- 第七部分记录：`%s`\n', part7_record_path);
    fprintf(fid, '- 第八部分记录：`%s`\n', part8_record_path);
    fprintf(fid, '- 第九部分记录：`%s`\n', part9_record_path);
    fprintf(fid, '- 本轮实际执行脚本：`%s`\n\n', actual_script_path);

    fprintf(fid, '## 为什么不继续增加模型自由度\n\n');
    fprintf(fid, '第九部分已经把 `q=1` 特例链路修正到与 `equal_phase` 一致，说明当前 V1 的主要矛盾不再是特例实现错误，而是 `q` 本身的可辨识性与搜索稳定性。此时继续推进 V2 constrained covariance fitting 会进一步增加自由度，并放大错误极小值、边界吸附和任务混叠风险，因此本轮停止在层次二内做可辨识性分析与任务分流，不推进 V2。\n\n');

    fprintf(fid, '## V1 的三类失败\n\n');
    fprintf(fid, '### 类型 A：q 估计失败，但模型本身可行\n\n');
    fprintf(fid, '- 代表场景：`beta=0.3, phase=0`。\n');
    fprintf(fid, '- 第九部分 `old q-grid` tol@8dB=%.3f，`q_fixed_true` tol@8dB=%.3f。\n', qdiag_refs(idx_beta03).old_tol, qdiag_refs(idx_beta03).qfixed_tol);
    fprintf(fid, '- 第十部分判定：`model_feasible_flag=%d`，`q_estimation_feasible_flag=%d`，推荐 `%s`。\n', ...
        results(idx_beta03).model_feasible_flag, results(idx_beta03).q_estimation_feasible_flag, results(idx_beta03).recommended_route);
    fprintf(fid, '- 含义细化：`model_feasible_flag=1` 只表示 true `q` 下角度恢复链路可行；`q_estimation_feasible_flag=0` 表示 `q` landscape 仍然宽平，并伴随边界/倒数等价低谷，当前不具备直接工程化条件。\n');
    fprintf(fid, '- 含义：如果 `q` 已知，角度 pair 有机会恢复；问题集中在 `q` landscape 是否足够尖锐、是否需要先验/正则，而不是直接继续加参数。\n\n');

    fprintf(fid, '### 类型 B：弱目标可辨性不足\n\n');
    fprintf(fid, '- 代表场景：`beta=0.1, phase=0`。\n');
    fprintf(fid, '- 第九部分 `q_fixed_true` tol@8dB=%.3f。\n', qdiag_refs(idx_beta01).qfixed_tol);
    fprintf(fid, '- 第十部分判定：`weak_target_flag=%d`，推荐 `%s`。\n', ...
        results(idx_beta01).weak_target_flag, results(idx_beta01).recommended_route);
    fprintf(fid, '- 含义：弱目标对一维协方差的扰动太小，即使 `q` 已知也只能部分恢复，不应把这类场景继续解释成单纯 `q` 搜索器实现问题。\n\n');

    fprintf(fid, '### 类型 C：近反相一维层次二病态边界\n\n');
    fprintf(fid, '- 代表场景：`phase=150/180 deg`。\n');
    fprintf(fid, '- 第九部分 `q_fixed_true` tol@8dB：`phase150=%.3f`，`phase180=%.3f`。\n', qdiag_refs(idx_phase150).qfixed_tol, qdiag_refs(idx_phase180).qfixed_tol);
    fprintf(fid, '- 第十部分判定：`phase150 route=%s`，`phase180 route=%s`。\n', ...
        results(idx_phase150).recommended_route, results(idx_phase180).recommended_route);
    fprintf(fid, '- 含义：两个近角度 steering 的近反相组合会把公共模式压低，使得一维层次二协方差拟合对双角度不再敏感。这属于层次二病态边界，不应继续用 V1 修复。\n\n');

    fprintf(fid, '## 任务分流原则\n\n');
    fprintf(fid, '- 近等幅、非反相、俯仰接近：优先走 `V0 equal-phase`。\n');
    fprintf(fid, '- 幅度比中等但 `q` 不明：`V1 complex-gain` 只保留为候选分析工具，当前不工程化；需要更稳的 `q` 优化器、先验或正则后再讨论。\n');
    fprintf(fid, '- 极弱目标：归类为 `weak_target_boundary`，需要强弱目标检测策略、SNR 提升或额外任务分流，不应继续强推当前 pair covfit。\n');
    fprintf(fid, '- 近反相：归类为 `anti_phase_boundary`，认定为一维层次二病态边界。\n');
    fprintf(fid, '- 大俯仰差或俯仰先验不准：按第七部分结果直接分流到层次三。本轮不做层次三实现。\n\n');

    fprintf(fid, '## 本轮建议\n\n');
    fprintf(fid, 'V1 还值得保留，但只值得作为“模型可行性诊断”和“需要何种先验/正则”的候选路线；不值得继续在当前自由度上直接工程化外推。当前主线应转向任务分流规则和层次三边界，而不是继续在层次二里盲目增加自由度。\n');
end

function write_record_doc_local(path_out, scenarios, qdiag_refs, results, summary_path, mat_path, ...
    modify_doc_path, formula_doc_path, part8_record_path, part9_record_path, part7_record_path, part6_record_path, ...
    wrapper_script_path, actual_script_path)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# 第8.6步 层次二第十部分：complex-gain 可辨识性与任务分流记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 修改方向文档：`%s`\n', modify_doc_path);
    fprintf(fid, '- 公式文档：`%s`\n', formula_doc_path);
    fprintf(fid, '- 第六部分记录：`%s`\n', part6_record_path);
    fprintf(fid, '- 第七部分记录：`%s`\n', part7_record_path);
    fprintf(fid, '- 第八部分记录：`%s`\n', part8_record_path);
    fprintf(fid, '- 第九部分记录：`%s`\n', part9_record_path);
    fprintf(fid, '- 文档要求脚本入口：`%s`\n', wrapper_script_path);
    fprintf(fid, '- 实际执行脚本：`%s`\n', actual_script_path);
    fprintf(fid, '- 本轮不做 V2，不进层次三，不改 `Q=65`，不扩 q-grid，不做 fullscan。\n\n');

    fprintf(fid, '## 参数与场景\n\n');
    fprintf(fid, '- `Q=65`, `K_phi=28`, `sep_factor=10`, `SNR=8 dB`, `T_snap=260`, `Metkl=20`。\n');
    fprintf(fid, '- `beta_grid_fine=logspace(log10(0.05), log10(3), 41)`，`phi_grid_fine=0:5:180`。\n');
    fprintf(fid, '- 场景：\n');
    for i = 1:numel(scenarios)
        fprintf(fid, '  - `%s`: beta=%.3f, phase=%.1f deg\n', scenarios(i).scenario_name, scenarios(i).beta_true, scenarios(i).phase_true_deg);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Landscape 定义\n\n');
    fprintf(fid, '1. `q fixed true` 的 pair map：固定 `q=q_true`，扫描 `(theta_center, theta_sep)`。\n');
    fprintf(fid, '2. `theta fixed true` 的 q map：固定 `theta=true pair`，扫描 `(beta, phi)`。\n');
    fprintf(fid, '3. joint local map：在 true theta 邻域和 local q 邻域内同时扫描，用于检查错误 `(theta, q)` 组合是否击败 true `(theta, q)`。\n\n');

    fprintf(fid, '## 结果总表\n\n');
    fprintf(fid, '| scenario | old q-grid tol | q_fixed_true tol | model | q_est | weak | anti | pair rank | q rank | gap(true vs best wrong) | route |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n');
    for i = 1:numel(results)
        r = results(i);
        fprintf(fid, '| `%s` | %.3f | %.3f | %d | %d | %d | %d | %.1f | %.1f | %.6g | `%s` |\n', ...
            r.scenario_name, qdiag_refs(i).old_tol, qdiag_refs(i).qfixed_tol, ...
            r.model_feasible_flag, r.q_estimation_feasible_flag, r.weak_target_flag, ...
            r.anti_phase_degenerate_flag, r.true_pair_rank_qfixed, r.true_q_rank_thetaf, ...
            r.objective_gap_true_vs_best_wrong, r.recommended_route);
    end
    fprintf(fid, '\n');
    fprintf(fid, '- `model=1` 仅表示在 true `q` 已知时，层次二 complex-gain 模型对该场景仍有恢复能力。\n');
    fprintf(fid, '- `q_est=1` 还要求 `q` objective 有足够尖锐的低谷，且 joint theta/q 不被错误组合击败；本轮没有场景满足这个更强条件。\n\n');

    idx_beta03 = find(strcmp({results.scenario_name}, 'beta0p3_phase0'), 1);
    idx_beta01 = find(strcmp({results.scenario_name}, 'beta0p1_phase0'), 1);
    idx_phase150 = find(strcmp({results.scenario_name}, 'beta1_phase150'), 1);
    idx_phase180 = find(strcmp({results.scenario_name}, 'beta1_phase180'), 1);

    fprintf(fid, '## 关键判断\n\n');
    fprintf(fid, '- `beta=0.3, phase=0`：`q_fixed_true` 从 %.3f 提升到 %.3f，对应 `%s`。这说明该场景属于“模型在 true q 下可行，但 q 本身不可稳健辨识”。\n', ...
        qdiag_refs(idx_beta03).old_tol, qdiag_refs(idx_beta03).qfixed_tol, results(idx_beta03).recommended_route);
    fprintf(fid, '- `beta=0.1, phase=0`：`q_fixed_true=%.3f`，同时 `weak_target_flag=%d`。该场景归入弱目标边界。\n', ...
        qdiag_refs(idx_beta01).qfixed_tol, results(idx_beta01).weak_target_flag);
    fprintf(fid, '- `phase=150/180 deg`：`q_fixed_true=%.3f / %.3f`，`route=%s / %s`。该类场景归入近反相病态边界。\n', ...
        qdiag_refs(idx_phase150).qfixed_tol, qdiag_refs(idx_phase180).qfixed_tol, ...
        results(idx_phase150).recommended_route, results(idx_phase180).recommended_route);
    fprintf(fid, '- `V1` 当前仍有价值，但价值已经收敛到“可辨识性分析与先验需求定位”，不再适合作为当前工程主算法直接外推。\n\n');

    fprintf(fid, '## 任务分流结论\n\n');
    fprintf(fid, '- `V0 equal-phase`：保留为近等幅、非反相主线。\n');
    fprintf(fid, '- `V1 complex-gain`：保留为候选诊断路线，当前不工程化。\n');
    fprintf(fid, '- 弱目标：分流到 `weak_target_boundary`。\n');
    fprintf(fid, '- 近反相：分流到 `anti_phase_boundary`。\n');
    fprintf(fid, '- 大俯仰差/俯仰先验误差：按第七部分继续分流到层次三。\n\n');

    fprintf(fid, '## 输出文件\n\n');
    fprintf(fid, '- summary：`%s`\n', summary_path);
    fprintf(fid, '- MAT：`%s`\n', mat_path);
    fprintf(fid, '- figures：`ident_pair_map_beta1_phase0.png`, `ident_pair_map_beta0p3_phase0.png`, `ident_pair_map_beta0p1_phase0.png`, `ident_pair_map_phase150.png`, `ident_q_map_beta0p3_phase0.png`, `ident_q_map_phase150.png`, `ident_route_decision_matrix.png`\n');
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
    precomp.g11 = g11;
    precomp.g22 = g22;
    precomp.gre = gre;
    precomp.gim = gim;
    precomp.gg_coef = [c11, c22, crr, cii, c12, c1r, c1i, c2r, c2i, cri];
    precomp.gi_coef = [gi11, gi22, gire, giim];
    precomp.ivec = single(ivec);
    precomp.ii = ii;
end

function precomp = precompute_true_pair_complex_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg, K_phi)
    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, target_theta, el_scan_deg, el_assumed_deg);
    cache = make_subarray_steer_cache_local(B_grid, K_phi);
    precomp = precompute_complex_pair_bases_local(cache, [1, 2]);
end

function score = score_complex_all_local(Robs, precomp, q_grid_info)
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
    score = solve_covfit_score_only_local(gy, gi, gg, yy, iy, precomp.ii);
end

function score = solve_covfit_score_only_local(gy, gi, gg, yy, iy, ii)
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
    best_delta = min(all_vals, [], 3);
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
end

function idx = find_q_grid_index_local(q_grid_info, beta_true, phi_true_deg)
    idx = find(abs(q_grid_info.beta_list - beta_true) < 1e-12 & ...
        abs(q_grid_info.phi_list_deg - phi_true_deg) < 1e-12, 1);
    if isempty(idx)
        error('True q is not on the configured q-grid.');
    end
end

function [angle_grid, candidate_pairs] = theta_pairs_to_grid_indices_local(pairs_theta)
    angle_grid = unique(pairs_theta(:)).';
    candidate_pairs = zeros(size(pairs_theta));
    for ii = 1:size(pairs_theta, 1)
        [~, candidate_pairs(ii, 1)] = min(abs(angle_grid - pairs_theta(ii, 1)));
        [~, candidate_pairs(ii, 2)] = min(abs(angle_grid - pairs_theta(ii, 2)));
    end
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

function G = fb_project_local(F, J)
    G = 0.5 * (F + J * conj(F) * J);
end

function v = matrix_to_realvec_local(M)
    m = M(:);
    v = [real(m); imag(m)];
end

function comp = connected_component_from_seed_local(mask, seed_rc)
    comp = false(size(mask));
    if ~mask(seed_rc(1), seed_rc(2))
        comp(seed_rc(1), seed_rc(2)) = true;
        return
    end
    queue = zeros(numel(mask), 2);
    qh = 1;
    qt = 1;
    queue(qt, :) = seed_rc;
    comp(seed_rc(1), seed_rc(2)) = true;
    while qh <= qt
        r = queue(qh, 1);
        c = queue(qh, 2);
        qh = qh + 1;
        neigh = [r-1, c; r+1, c; r, c-1; r, c+1];
        for k = 1:4
            rr = neigh(k, 1);
            cc = neigh(k, 2);
            if rr < 1 || rr > size(mask, 1) || cc < 1 || cc > size(mask, 2)
                continue
            end
            if ~mask(rr, cc) || comp(rr, cc)
                continue
            end
            qt = qt + 1;
            queue(qt, :) = [rr, cc];
            comp(rr, cc) = true;
        end
    end
end

function ncomp = count_components_local(mask)
    visited = false(size(mask));
    ncomp = 0;
    for r = 1:size(mask, 1)
        for c = 1:size(mask, 2)
            if ~mask(r, c) || visited(r, c)
                continue
            end
            ncomp = ncomp + 1;
            comp = connected_component_from_seed_local(mask, [r, c]);
            visited = visited | comp;
        end
    end
end

function d2 = second_diff_nonuniform_local(x, y, idx)
    if idx <= 1 || idx >= numel(x)
        d2 = NaN;
        return
    end
    x1 = x(idx-1);
    x2 = x(idx);
    x3 = x(idx+1);
    y1 = y(idx-1);
    y2 = y(idx);
    y3 = y(idx+1);
    d2 = 2 * ( ...
        y1 / ((x1 - x2) * (x1 - x3)) + ...
        y2 / ((x2 - x1) * (x2 - x3)) + ...
        y3 / ((x3 - x1) * (x3 - x2)));
end

function out = joint_theta1_grid_from_pairs_local(pairs_theta)
    out = unique(pairs_theta(:, 1)).';
end

function out = joint_theta2_grid_from_pairs_local(pairs_theta)
    out = unique(pairs_theta(:, 2)).';
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
