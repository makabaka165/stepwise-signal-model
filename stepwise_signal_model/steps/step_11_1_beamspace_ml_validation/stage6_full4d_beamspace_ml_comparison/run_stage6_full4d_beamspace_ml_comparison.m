clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_1_full4d_beamspace_ml_comparison');

addpath(common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.1 Stage6 starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

cfg = sim_cfg();
arrInfo = arr_cyl(cfg, cfg.beam.azSectorCenter);
x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
N_elem = numel(x);
expected_N_elem = cfg.beam.subNaz * cfg.arr.Nel;
if N_elem ~= expected_N_elem
    error('run_stage6:NelemMismatch', 'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;

base_seed = 20260616;
L = 64;
Metkl = 2;
az_center_true = cfg.beam.azSectorCenter;
el_center_nominal = cfg.beam.elSectorCenter;
el_center_offset = 0.31;
beam_layouts = struct( ...
    'name', {'az5_el5', 'az5_el3'}, ...
    'az_count', {5, 5}, ...
    'el_count', {5, 3});
model_mode_list = {'common_el_restricted', 'controlled_pair2d', 'full4d'};
whitening_mode_list = {'white'};
scenarios = build_scenarios_local();

az_search_half_width = 1.5;
el_search_half_width = 1.2;
az_beam_span = 2.2;
el_beam_span = 1.6;
az_grid_step_deg = 0.10;
el_grid_step_deg = 0.15;
el_sep_index_list = [0, 1, 2];
search_orientations = [1, -1];
az_tol_deg = 0.15;
el_tol_deg = 0.22;
reg = 1e-10;

log_lines = append_log_local(log_lines, 'cfg.arr: Naz=%d, Nel=%d, fc=%.6g, lambda=%.12g, R=%.6g, dz=%.6g', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.fc, cfg.arr.lambda, cfg.arr.R, cfg.arr.dz);
log_lines = append_log_local(log_lines, 'cfg.beam.subNaz=%d, arrInfo.nAct=%d, expected_N_elem=%d', ...
    cfg.beam.subNaz, arrInfo.nAct, expected_N_elem);
log_lines = append_log_local(log_lines, 'phase_factor=%.6g, phase_sign=%+.0f', phase_factor, phase_sign);
log_lines = append_log_local(log_lines, 'base_seed=%d, L=%d, Metkl=%d', base_seed, L, Metkl);
log_lines = append_log_local(log_lines, 'beam_layouts=%s', strjoin({beam_layouts.name}, ','));
log_lines = append_log_local(log_lines, 'model_mode_list=%s, whitening_mode_list=%s', ...
    strjoin(model_mode_list, ','), strjoin(whitening_mode_list, ','));
log_lines = append_log_local(log_lines, ...
    'az_search_half_width=%.3f, el_search_half_width=%.3f, az_beam_span=%.3f, el_beam_span=%.3f', ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span);
log_lines = append_log_local(log_lines, ...
    'az_grid_step_deg=%.3f, el_grid_step_deg=%.3f, el_sep_index_list=%s, search_orientations=%s', ...
    az_grid_step_deg, el_grid_step_deg, mat2str(el_sep_index_list), mat2str(search_orientations));
for iScenario = 1:numel(scenarios)
    s = scenarios(iScenario);
    log_lines = append_log_local(log_lines, ...
        'scenario %02d %s: rho=%.2f, phase=%.1f, beta=%.2f, az_sep=%.2f, el_sep=%.2f, snr=%.1f, bias=[%.1f %.1f]', ...
        iScenario, s.name, s.rho, s.phase_deg, s.beta, s.az_sep, s.el_sep, s.snr_db, s.az_center_bias, s.el_center_bias);
end

total_rows = numel(scenarios) * numel(beam_layouts) * numel(model_mode_list) * numel(whitening_mode_list) * Metkl;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

tic;
for iScenario = 1:numel(scenarios)
    scenario = scenarios(iScenario);
    source_mode = source_mode_for_rho_local(scenario.rho);
    az_true = [az_center_true - scenario.az_sep/2, az_center_true + scenario.az_sep/2];
    el_center_true = el_center_nominal + el_center_offset;
    el_true_base = [el_center_true - scenario.el_sep/2, el_center_true + scenario.el_sep/2];

    az_beam_c = az_center_true + scenario.az_center_bias;
    el_beam_c = el_center_nominal + scenario.el_center_bias;
    az_bounds = [az_beam_c - az_search_half_width, az_beam_c + az_search_half_width];
    el_bounds = [el_beam_c - el_search_half_width, el_beam_c + el_search_half_width];
    az_grid = az_bounds(1):az_grid_step_deg:az_bounds(2);
    el_grid = el_bounds(1):el_grid_step_deg:el_bounds(2);

    for iLayout = 1:numel(beam_layouts)
        layout = beam_layouts(iLayout);
        beam_az = linspace(az_beam_c - az_beam_span, az_beam_c + az_beam_span, layout.az_count);
        beam_el = linspace(el_beam_c - el_beam_span, el_beam_c + el_beam_span, layout.el_count);
        [W, beam_info] = build_cyl_azel_beam_transform(x, y, z, beam_az, beam_el, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
        grid = precompute_beamspace_azel_grid(W, x, y, z, az_grid, el_grid, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);

        for trial_id = 1:Metkl
            if scenario.el_sep > 0 && mod(trial_id, 2) == 0
                el_true = fliplr(el_true_base);
            else
                el_true = el_true_base;
            end
            seed_now = base_seed + 10000*iScenario + 1000*iLayout + trial_id;
            [Y, truth] = make_cyl_pair2d_correlated_snapshots(x, y, z, az_true, el_true, lambda, L, scenario.snr_db, ...
                'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Rho', scenario.rho, ...
                'PhaseDeg', scenario.phase_deg, 'AmplitudeRatio', scenario.beta, 'Seed', seed_now, ...
                'NormalizeSourcePower', true);
            if ~isequal(size(Y), [N_elem, L])
                error('run_stage6:YShapeMismatch', 'Y must be N_elem x L.');
            end
            Z = W' * Y;

            for iWhite = 1:numel(whitening_mode_list)
                whitening_mode = whitening_mode_list{iWhite};
                for iModel = 1:numel(model_mode_list)
                    model_mode = model_mode_list{iModel};
                    search_cfg = struct();
                    search_cfg.whitening_mode = whitening_mode;
                    search_cfg.reg = reg;
                    search_cfg.el_sep_index_list = el_sep_index_list;
                    search_cfg.search_orientations = search_orientations;
                    search_cfg.keep_score_cube = false;
                    search_cfg.keep_score_tensor = false;
                    search_cfg.max_candidates = Inf;
                    search_cfg.topK = 5;

                    switch model_mode
                        case 'common_el_restricted'
                            [est_common, ~, debug] = search_pair_grid_common_el_precomputed(Z, W, grid, search_cfg);
                            est = struct();
                            est.az_hat = est_common.az_hat;
                            est.el_hat = [est_common.el_hat, est_common.el_hat];
                        case 'controlled_pair2d'
                            [est, ~, debug] = search_pair_grid_el_separation_precomputed(Z, W, grid, search_cfg);
                        case 'full4d'
                            [est, ~, debug] = search_pair_grid_full4d_precomputed(Z, W, grid, search_cfg);
                        otherwise
                            error('run_stage6:UnknownModelMode', 'Unknown model mode: %s', model_mode);
                    end

                    metrics = eval_full4d_pair_metrics(est, az_true, el_true, az_bounds, el_bounds, az_tol_deg, el_tol_deg);
                    row_idx = row_idx + 1;
                    trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, scenario, source_mode, model_mode, ...
                        whitening_mode, layout, truth.source_corr_empirical, est, az_true, el_true, metrics, debug, ...
                        N_elem, L, phase_factor, phase_sign);
                end
            end
        end
    end
    log_lines = append_log_local(log_lines, 'Completed scenario %02d/%02d %s, rows=%d/%d, elapsed %.2f s', ...
        iScenario, numel(scenarios), scenario.name, row_idx, total_rows, toc);
end

if row_idx ~= total_rows
    error('run_stage6:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table);
[keypoint_rows, keypoints] = summarize_stage6_full4d_keypoints(summary_table);
keypoint_table = struct2table(keypoint_rows);

trial_csv = fullfile(result_dir, 'step11_1_full4d_comparison_trial.csv');
summary_csv = fullfile(result_dir, 'step11_1_full4d_comparison_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_1_full4d_comparison_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_1_full4d_comparison_result.mat');
log_path = fullfile(result_dir, 'step11_1_full4d_comparison.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
plot_paths = plot_stage6_full4d_comparison(summary_table, result_dir);

params = struct();
params.base_seed = base_seed;
params.L = L;
params.Metkl = Metkl;
params.az_center_true = az_center_true;
params.el_center_nominal = el_center_nominal;
params.el_center_offset = el_center_offset;
params.beam_layouts = beam_layouts;
params.model_mode_list = model_mode_list;
params.whitening_mode_list = whitening_mode_list;
params.scenarios = scenarios;
params.az_search_half_width = az_search_half_width;
params.el_search_half_width = el_search_half_width;
params.az_beam_span = az_beam_span;
params.el_beam_span = el_beam_span;
params.az_grid_step_deg = az_grid_step_deg;
params.el_grid_step_deg = el_grid_step_deg;
params.el_sep_index_list = el_sep_index_list;
params.search_orientations = search_orientations;
params.az_tol_deg = az_tol_deg;
params.el_tol_deg = el_tol_deg;
params.N_elem = N_elem;
params.phase_factor = phase_factor;
params.phase_sign = phase_sign;
params.lambda = lambda;

save(mat_path, 'params', 'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_log_local(log_lines, 'Keypoints:');
metric_names = fieldnames(keypoints);
for iMetric = 1:numel(metric_names)
    name = metric_names{iMetric};
    value = keypoints.(name);
    if isnumeric(value) || islogical(value)
        log_lines = append_log_local(log_lines, '  %s = %.12g', name, double(value));
    else
        log_lines = append_log_local(log_lines, '  %s = %s', name, char(value));
    end
end
log_lines = append_log_local(log_lines, 'full4d_pass_flag=%d', keypoints.full4d_pass_flag);
log_lines = append_log_local(log_lines, 'full4d_recommended_role=%s', keypoints.full4d_recommended_role);
log_lines = append_log_local(log_lines, 'recommended_next_step=%s', keypoints.recommended_next_step);
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function scenarios = build_scenarios_local()
template = struct('name', '', 'rho', NaN, 'phase_deg', NaN, 'beta', NaN, 'az_sep', NaN, ...
    'el_sep', NaN, 'snr_db', NaN, 'az_center_bias', NaN, 'el_center_bias', NaN);
scenarios = repmat(template, 10, 1);
scenarios(1) = make_scenario_local('easy_noncoherent', 0, 0, 1, 1.27, 0.67, 30, 0, 0);
scenarios(2) = make_scenario_local('moderate_coherent', 0.9, 5, 0.7, 1.27, 0.37, 30, 0, 0);
scenarios(3) = make_scenario_local('strong_coherent', 0.99, 5, 1, 1.27, 0.37, 30, 0, 0);
scenarios(4) = make_scenario_local('full_coherent', 1.0, 0, 1, 1.27, 0.37, 30, 0, 0);
scenarios(5) = make_scenario_local('hard_phase', 0.99, 150, 1, 0.83, 0.37, 30, 0, 0);
scenarios(6) = make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30, 0, 0);
scenarios(7) = make_scenario_local('near_common_el', 0.99, 30, 0.7, 0.83, 0.0, 30, 0, 0);
scenarios(8) = make_scenario_local('biased_frontend', 0.99, 30, 0.7, 0.83, 0.37, 30, 0.2, 0);
scenarios(9) = make_scenario_local('low_snr_hard', 1.0, 150, 0.3, 0.83, 0.37, 20, 0, 0);
scenarios(10) = make_scenario_local('larger_el_sep', 0.9, 30, 0.7, 1.27, 0.67, 30, 0, 0);
end

function s = make_scenario_local(name, rho, phase_deg, beta, az_sep, el_sep, snr_db, az_bias, el_bias)
s = struct('name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, 'az_sep', az_sep, ...
    'el_sep', el_sep, 'snr_db', snr_db, 'az_center_bias', az_bias, 'el_center_bias', el_bias);
end

function source_mode = source_mode_for_rho_local(rho)
if abs(rho) < 1e-12
    source_mode = 'noncoherent';
else
    source_mode = 'correlated_main';
end
end

function row = make_trial_row_template_local()
row = struct();
fields = {'trial_global_id','trial_id','scenario_name','source_mode','model_mode','whitening_mode', ...
    'beam_layout_name','beam_count','beam_az_count','beam_el_count','rho','phase_deg','beta','source_corr_empirical', ...
    'az_sep_deg','el_sep_deg','snr_db','az_center_bias_deg','el_center_bias_deg','az_hat_1','az_hat_2', ...
    'el_hat_1','el_hat_2','az_true_1','az_true_2','el_true_1','el_true_2','raw_success', ...
    'az_tol_success','el_tol_success','joint_tol_success','az_rmse_deg','el_rmse_deg', ...
    'az_center_error_deg','az_sep_error_deg','abs_az_sep_error_deg','el_center_error_deg', ...
    'el_sep_error_deg','abs_el_sep_error_deg','boundary_hit','max_score','num_pairs','cond_WHW', ...
    'cond_best_GHG','N_elem','L','phase_factor','phase_sign'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.scenario_name = '';
row.source_mode = '';
row.model_mode = '';
row.whitening_mode = '';
row.beam_layout_name = '';
bool_fields = {'raw_success','az_tol_success','el_tol_success','joint_tol_success','boundary_hit'};
for idx = 1:numel(bool_fields)
    row.(bool_fields{idx}) = false;
end
end

function row = make_trial_row_local(trial_global_id, trial_id, scenario, source_mode, model_mode, whitening_mode, ...
    layout, source_corr_empirical, est, az_true, el_true, metrics, debug, N_elem, L, phase_factor, phase_sign)
row = make_trial_row_template_local();
row.trial_global_id = trial_global_id;
row.trial_id = trial_id;
row.scenario_name = scenario.name;
row.source_mode = source_mode;
row.model_mode = model_mode;
row.whitening_mode = whitening_mode;
row.beam_layout_name = layout.name;
row.beam_count = layout.az_count * layout.el_count;
row.beam_az_count = layout.az_count;
row.beam_el_count = layout.el_count;
row.rho = scenario.rho;
row.phase_deg = scenario.phase_deg;
row.beta = scenario.beta;
row.source_corr_empirical = source_corr_empirical;
row.az_sep_deg = scenario.az_sep;
row.el_sep_deg = scenario.el_sep;
row.snr_db = scenario.snr_db;
row.az_center_bias_deg = scenario.az_center_bias;
row.el_center_bias_deg = scenario.el_center_bias;
row.az_hat_1 = est.az_hat(1);
row.az_hat_2 = est.az_hat(2);
row.el_hat_1 = est.el_hat(1);
row.el_hat_2 = est.el_hat(2);
row.az_true_1 = az_true(1);
row.az_true_2 = az_true(2);
row.el_true_1 = el_true(1);
row.el_true_2 = el_true(2);
row.raw_success = metrics.raw_success;
row.az_tol_success = metrics.az_tol_success;
row.el_tol_success = metrics.el_tol_success;
row.joint_tol_success = metrics.joint_tol_success;
row.az_rmse_deg = metrics.az_rmse_deg;
row.el_rmse_deg = metrics.el_rmse_deg;
row.az_center_error_deg = metrics.az_center_error_deg;
row.az_sep_error_deg = metrics.az_sep_error_deg;
row.abs_az_sep_error_deg = metrics.abs_az_sep_error_deg;
row.el_center_error_deg = metrics.el_center_error_deg;
row.el_sep_error_deg = metrics.el_sep_error_deg;
row.abs_el_sep_error_deg = metrics.abs_el_sep_error_deg;
row.boundary_hit = metrics.boundary_hit;
row.max_score = debug.max_score;
row.num_pairs = debug.num_pairs;
row.cond_WHW = debug.cond_WHW;
row.cond_best_GHG = debug.cond_best_GHG;
row.N_elem = N_elem;
row.L = L;
row.phase_factor = phase_factor;
row.phase_sign = phase_sign;
end

function summary_table = build_summary_table_local(trial_table)
group_fields = {'scenario_name','source_mode','model_mode','whitening_mode','beam_layout_name','beam_count', ...
    'beam_az_count','beam_el_count','snr_db','rho','phase_deg','beta','az_sep_deg','el_sep_deg', ...
    'az_center_bias_deg','el_center_bias_deg'};
groups = unique(trial_table(:, group_fields), 'rows');
rows = repmat(make_summary_row_template_local(), height(groups), 1);
for iGroup = 1:height(groups)
    mask = true(height(trial_table), 1);
    for iField = 1:numel(group_fields)
        field = group_fields{iField};
        mask = mask & match_value_local(trial_table.(field), groups.(field)(iGroup));
    end
    sub = trial_table(mask, :);
    rows(iGroup).scenario_name = char_value_local(groups.scenario_name(iGroup));
    rows(iGroup).source_mode = char_value_local(groups.source_mode(iGroup));
    rows(iGroup).model_mode = char_value_local(groups.model_mode(iGroup));
    rows(iGroup).whitening_mode = char_value_local(groups.whitening_mode(iGroup));
    rows(iGroup).beam_layout_name = char_value_local(groups.beam_layout_name(iGroup));
    rows(iGroup).beam_count = groups.beam_count(iGroup);
    rows(iGroup).beam_az_count = groups.beam_az_count(iGroup);
    rows(iGroup).beam_el_count = groups.beam_el_count(iGroup);
    rows(iGroup).snr_db = groups.snr_db(iGroup);
    rows(iGroup).rho = groups.rho(iGroup);
    rows(iGroup).phase_deg = groups.phase_deg(iGroup);
    rows(iGroup).beta = groups.beta(iGroup);
    rows(iGroup).az_sep_deg = groups.az_sep_deg(iGroup);
    rows(iGroup).el_sep_deg = groups.el_sep_deg(iGroup);
    rows(iGroup).az_center_bias_deg = groups.az_center_bias_deg(iGroup);
    rows(iGroup).el_center_bias_deg = groups.el_center_bias_deg(iGroup);
    rows(iGroup).raw_success_rate = mean(double(sub.raw_success));
    rows(iGroup).az_tol_success_rate = mean(double(sub.az_tol_success));
    rows(iGroup).el_tol_success_rate = mean(double(sub.el_tol_success));
    rows(iGroup).joint_tol_success_rate = mean(double(sub.joint_tol_success));
    rows(iGroup).mean_az_rmse_deg = mean_omitnan_local(sub.az_rmse_deg);
    rows(iGroup).mean_el_rmse_deg = mean_omitnan_local(sub.el_rmse_deg);
    rows(iGroup).mean_abs_az_sep_error_deg = mean_omitnan_local(sub.abs_az_sep_error_deg);
    rows(iGroup).mean_abs_el_sep_error_deg = mean_omitnan_local(sub.abs_el_sep_error_deg);
    rows(iGroup).boundary_hit_rate = mean(double(sub.boundary_hit));
    rows(iGroup).mean_num_pairs = mean_omitnan_local(sub.num_pairs);
    rows(iGroup).mean_cond_WHW = mean_omitnan_local(sub.cond_WHW);
    rows(iGroup).mean_cond_best_GHG = mean_omitnan_local(sub.cond_best_GHG);
    rows(iGroup).mean_max_score = mean_omitnan_local(sub.max_score);
end
summary_table = struct2table(rows);
summary_table = add_model_comparison_local(summary_table);
end

function row = make_summary_row_template_local()
row = struct();
fields = {'scenario_name','source_mode','model_mode','whitening_mode','beam_layout_name','beam_count', ...
    'beam_az_count','beam_el_count','snr_db','rho','phase_deg','beta','az_sep_deg','el_sep_deg', ...
    'az_center_bias_deg','el_center_bias_deg','raw_success_rate','az_tol_success_rate','el_tol_success_rate', ...
    'joint_tol_success_rate','mean_az_rmse_deg','mean_el_rmse_deg','mean_abs_az_sep_error_deg', ...
    'mean_abs_el_sep_error_deg','boundary_hit_rate','mean_num_pairs','mean_cond_WHW','mean_cond_best_GHG', ...
    'mean_max_score','full4d_minus_pair2d_joint_success_gap','full4d_minus_common_joint_success_gap', ...
    'pair2d_minus_common_joint_success_gap','complexity_ratio_full4d_over_pair2d', ...
    'complexity_ratio_pair2d_over_common','score_margin_full4d_minus_pair2d','score_margin_pair2d_minus_common'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.scenario_name = '';
row.source_mode = '';
row.model_mode = '';
row.whitening_mode = '';
row.beam_layout_name = '';
end

function summary_table = add_model_comparison_local(summary_table)
summary_table.full4d_minus_pair2d_joint_success_gap(:) = NaN;
summary_table.full4d_minus_common_joint_success_gap(:) = NaN;
summary_table.pair2d_minus_common_joint_success_gap(:) = NaN;
summary_table.complexity_ratio_full4d_over_pair2d(:) = NaN;
summary_table.complexity_ratio_pair2d_over_common(:) = NaN;
summary_table.score_margin_full4d_minus_pair2d(:) = NaN;
summary_table.score_margin_pair2d_minus_common(:) = NaN;
for idx = 1:height(summary_table)
    base_mask = same_scenario_layout_mask_local(summary_table, idx);
    full_mask = base_mask & string_match_local(summary_table.model_mode, 'full4d');
    pair_mask = base_mask & string_match_local(summary_table.model_mode, 'controlled_pair2d');
    common_mask = base_mask & string_match_local(summary_table.model_mode, 'common_el_restricted');
    if any(full_mask) && any(pair_mask) && any(common_mask)
        full_success = mean_omitnan_local(summary_table.joint_tol_success_rate(full_mask));
        pair_success = mean_omitnan_local(summary_table.joint_tol_success_rate(pair_mask));
        common_success = mean_omitnan_local(summary_table.joint_tol_success_rate(common_mask));
        full_pairs = mean_omitnan_local(summary_table.mean_num_pairs(full_mask));
        pair_pairs = mean_omitnan_local(summary_table.mean_num_pairs(pair_mask));
        common_pairs = mean_omitnan_local(summary_table.mean_num_pairs(common_mask));
        full_score = mean_omitnan_local(summary_table.mean_max_score(full_mask));
        pair_score = mean_omitnan_local(summary_table.mean_max_score(pair_mask));
        common_score = mean_omitnan_local(summary_table.mean_max_score(common_mask));
        summary_table.full4d_minus_pair2d_joint_success_gap(idx) = full_success - pair_success;
        summary_table.full4d_minus_common_joint_success_gap(idx) = full_success - common_success;
        summary_table.pair2d_minus_common_joint_success_gap(idx) = pair_success - common_success;
        summary_table.complexity_ratio_full4d_over_pair2d(idx) = full_pairs / max(pair_pairs, eps);
        summary_table.complexity_ratio_pair2d_over_common(idx) = pair_pairs / max(common_pairs, eps);
        summary_table.score_margin_full4d_minus_pair2d(idx) = full_score - pair_score;
        summary_table.score_margin_pair2d_minus_common(idx) = pair_score - common_score;
    end
end
end

function mask = same_scenario_layout_mask_local(summary_table, idx)
mask = string_match_local(summary_table.scenario_name, char_value_local(summary_table.scenario_name(idx))) & ...
    string_match_local(summary_table.whitening_mode, char_value_local(summary_table.whitening_mode(idx))) & ...
    string_match_local(summary_table.beam_layout_name, char_value_local(summary_table.beam_layout_name(idx))) & ...
    abs(summary_table.snr_db - summary_table.snr_db(idx)) < 1e-12 & ...
    abs(summary_table.rho - summary_table.rho(idx)) < 1e-12 & ...
    abs(summary_table.phase_deg - summary_table.phase_deg(idx)) < 1e-12 & ...
    abs(summary_table.beta - summary_table.beta(idx)) < 1e-12 & ...
    abs(summary_table.az_sep_deg - summary_table.az_sep_deg(idx)) < 1e-12 & ...
    abs(summary_table.el_sep_deg - summary_table.el_sep_deg(idx)) < 1e-12 & ...
    abs(summary_table.az_center_bias_deg - summary_table.az_center_bias_deg(idx)) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg - summary_table.el_center_bias_deg(idx)) < 1e-12;
end

function mask = match_value_local(values, target)
if iscell(values) || ischar(target) || isstring(target)
    mask = string_match_local(values, char_value_local(target));
else
    mask = abs(values - target) < 1e-12;
end
end

function mask = string_match_local(values, target)
if iscell(values)
    mask = strcmp(values, target);
elseif isstring(values)
    mask = strcmp(values, string(target));
else
    mask = strcmp(cellstr(values), target);
end
end

function value = char_value_local(value_in)
if iscell(value_in)
    value = value_in{1};
elseif isstring(value_in)
    value = char(value_in);
else
    value = char(value_in);
end
end

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage6:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
