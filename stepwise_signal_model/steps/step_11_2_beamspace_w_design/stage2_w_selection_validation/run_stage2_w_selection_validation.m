clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
step11_1_common_dir = fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common');
stage1_result_dir = fullfile(step_dir, 'results_step11_2_w_pool_diagnostics');
result_dir = fullfile(step_dir, 'results_step11_2_w_selection_validation');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.2 Stage2 W selection validation starts');
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
    error('run_stage2_w_selection_validation:NelemMismatch', 'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;
B_list = [9, 15, 25];
Metkl = 5;
L = 64;
reg = 1e-10;

stage1_mat = fullfile(stage1_result_dir, 'step11_2_w_pool_diagnostics_result.mat');
if exist(stage1_mat, 'file') ~= 2
    error('run_stage2_w_selection_validation:MissingStage1Mat', ...
        'Run Stage1 first. Missing: %s', stage1_mat);
end
stage1_data = load(stage1_mat, 'W_case_bank', 'params');
W_cases = select_stage2_w_cases_local(stage1_data.W_case_bank, B_list);
scenario_table = build_scenario_table_local();

cfg_eval = struct();
cfg_eval.x = x;
cfg_eval.y = y;
cfg_eval.z = z;
cfg_eval.lambda = lambda;
cfg_eval.phase_factor = phase_factor;
cfg_eval.phase_sign = phase_sign;
cfg_eval.az_center_true = cfg.beam.azSectorCenter;
cfg_eval.el_center_nominal = cfg.beam.elSectorCenter;
cfg_eval.L = L;
cfg_eval.Metkl = Metkl;
cfg_eval.az_search_half_width = 1.5;
cfg_eval.el_search_half_width = 1.2;
cfg_eval.az_grid_step_deg = 0.08;
cfg_eval.el_grid_step_deg = 0.12;
cfg_eval.el_sep_index_list = [0, 1, 2];
cfg_eval.search_orientations = [1, -1];
cfg_eval.az_tol_deg = 0.15;
cfg_eval.el_tol_deg = 0.20;
cfg_eval.el_sep_tol_deg = 0.25;
cfg_eval.reg = reg;
cfg_eval.base_seed = 20260626;

log_lines = append_log_local(log_lines, 'Loaded Stage1 MAT: %s', stage1_mat);
log_lines = append_log_local(log_lines, 'Selected W cases=%d, scenarios=%d, Metkl=%d, L=%d', ...
    numel(W_cases), height(scenario_table), Metkl, L);
log_lines = append_log_local(log_lines, 'Search grid: az half %.3f step %.3f, el half %.3f step %.3f', ...
    cfg_eval.az_search_half_width, cfg_eval.az_grid_step_deg, cfg_eval.el_search_half_width, cfg_eval.el_grid_step_deg);

tic;
[trial_table, summary_table] = evaluate_w_pair2d_backend(W_cases, scenario_table, cfg_eval);
log_lines = append_log_local(log_lines, 'Backend validation finished, rows=%d, elapsed %.2f s', height(trial_table), toc);

keypoints = build_keypoints_local(summary_table);
keypoint_table = keypoints_to_table_local(keypoints);
plot_paths = make_plots_local(summary_table, result_dir);

trial_csv = fullfile(result_dir, 'step11_2_w_selection_validation_trial.csv');
summary_csv = fullfile(result_dir, 'step11_2_w_selection_validation_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_2_w_selection_validation_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_2_w_selection_validation_result.mat');
log_path = fullfile(result_dir, 'step11_2_w_selection_validation.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
params = cfg_eval;
params.B_list = B_list;
params.Metkl = Metkl;
params.L = L;
save(mat_path, 'params', 'W_cases', 'scenario_table', 'trial_table', 'summary_table', ...
    'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_log_local(log_lines, 'Keypoints:');
names = fieldnames(keypoints);
for iName = 1:numel(names)
    value = keypoints.(names{iName});
    if isnumeric(value) || islogical(value)
        log_lines = append_log_local(log_lines, '  %s = %.12g', names{iName}, double(value));
    else
        log_lines = append_log_local(log_lines, '  %s = %s', names{iName}, char(value));
    end
end
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function W_cases = select_stage2_w_cases_local(W_case_bank, B_list)
method_map = { ...
    'regular_3dB_grid', 'regular_3dB_grid'; ...
    'greedy_projection', 'greedy_projection'; ...
    'greedy_lowcorr', 'greedy_lowcorr'; ...
    'svd_upper_bound', 'svd_upper_bound'; ...
    'random_pool_baseline', 'random_pool_baseline'};
W_cases = struct([]);
for iB = 1:numel(B_list)
    B = B_list(iB);
    for iMethod = 1:size(method_map, 1)
        method_name = method_map{iMethod, 1};
        idx = find(strcmp({W_case_bank.name}, method_name) & [W_case_bank.B] == B, 1);
        if isempty(idx)
            error('run_stage2_w_selection_validation:MissingWCase', 'Missing W case %s B=%d.', method_name, B);
        end
        entry = W_case_bank(idx);
        entry.name = method_map{iMethod, 2};
        W_cases = [W_cases; entry]; %#ok<AGROW>
    end
end
end

function scenario_table = build_scenario_table_local()
rows = [ ...
    make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30); ...
    make_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30); ...
    make_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30); ...
    make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30); ...
    make_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20)];
scenario_table = struct2table(rows);
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
row = struct();
row.scenario_name = name;
row.rho = rho;
row.phase_deg = phase_deg;
row.beta = beta;
row.az_sep_deg = az_sep_deg;
row.el_sep_deg = el_sep_deg;
row.snr_db = snr_db;
end

function keypoints = build_keypoints_local(summary_table)
aggregate = unique(summary_table(:, {'method_name','B','overall_joint_success_rate','overall_az_rmse_deg', ...
    'overall_el_rmse_deg','worst_case_success','projection_loss','max_corr','cond_WHW','mean_num_pairs'}), 'rows');
aggregate.combined_rmse_deg = hypot(aggregate.overall_az_rmse_deg, aggregate.overall_el_rmse_deg);
nonrandom_mask = ~strcmp(cellstr(aggregate.method_name), 'random_pool_baseline');
nonrandom = aggregate(nonrandom_mask, :);
[~, best_idx] = max(nonrandom.overall_joint_success_rate + 0.25 * nonrandom.worst_case_success - ...
    0.05 * nonrandom.combined_rmse_deg);
best = nonrandom(best_idx, :);

B15 = nonrandom(abs(nonrandom.B - 15) < 1e-12, :);
[~, best_B15_idx] = max(B15.overall_joint_success_rate + 0.25 * B15.worst_case_success - ...
    0.05 * B15.combined_rmse_deg);
best_B15 = B15(best_B15_idx, :);

regular_B25 = select_aggregate_row_local(aggregate, 'regular_3dB_grid', 25);
gproj_B25 = select_aggregate_row_local(aggregate, 'greedy_projection', 25);
glow_B25 = select_aggregate_row_local(aggregate, 'greedy_lowcorr', 25);
svd_B25 = select_aggregate_row_local(aggregate, 'svd_upper_bound', 25);

gproj_score = gproj_B25.overall_joint_success_rate + 0.25 * gproj_B25.worst_case_success - ...
    0.05 * gproj_B25.combined_rmse_deg;
glow_score = glow_B25.overall_joint_success_rate + 0.25 * glow_B25.worst_case_success - ...
    0.05 * glow_B25.combined_rmse_deg;
if gproj_score >= glow_score
    greedy_B25 = gproj_B25;
    greedy_method = 'greedy_projection';
else
    greedy_B25 = glow_B25;
    greedy_method = 'greedy_lowcorr';
end

keypoints = struct();
keypoints.best_method_overall = sprintf('%s_B%d', char_value_local(best.method_name(1)), best.B(1));
keypoints.best_method_B15 = char_value_local(best_B15.method_name(1));
keypoints.best_method_overall_excludes_random = 1;
keypoints.regular_success_B25 = regular_B25.overall_joint_success_rate;
keypoints.greedy_success_B25 = greedy_B25.overall_joint_success_rate;
keypoints.best_greedy_method_B25 = greedy_method;
keypoints.svd_success_B25 = svd_B25.overall_joint_success_rate;
keypoints.greedy_minus_regular_success_gain_B25 = greedy_B25.overall_joint_success_rate - regular_B25.overall_joint_success_rate;
keypoints.svd_minus_regular_success_gain_B25 = svd_B25.overall_joint_success_rate - regular_B25.overall_joint_success_rate;
keypoints.greedy_to_svd_success_gap_B25 = svd_B25.overall_joint_success_rate - greedy_B25.overall_joint_success_rate;
keypoints.worst_case_regular_success = regular_B25.worst_case_success;
keypoints.worst_case_greedy_success = greedy_B25.worst_case_success;
keypoints.worst_case_svd_success = svd_B25.worst_case_success;
keypoints.regular_combined_rmse_B25 = regular_B25.combined_rmse_deg;
keypoints.greedy_combined_rmse_B25 = greedy_B25.combined_rmse_deg;
keypoints.svd_combined_rmse_B25 = svd_B25.combined_rmse_deg;
keypoints.greedy_minus_regular_combined_rmse_gain_B25 = regular_B25.combined_rmse_deg - greedy_B25.combined_rmse_deg;
keypoints.regular_projection_loss_B25 = regular_B25.projection_loss;
keypoints.greedy_projection_loss_B25 = greedy_B25.projection_loss;
keypoints.svd_projection_loss_B25 = svd_B25.projection_loss;
keypoints.regular_max_corr_B25 = regular_B25.max_corr;
keypoints.greedy_max_corr_B25 = greedy_B25.max_corr;
keypoints.svd_max_corr_B25 = svd_B25.max_corr;
keypoints.w_selection_validation_pass_flag = ...
    (keypoints.worst_case_greedy_success > keypoints.worst_case_regular_success) || ...
    (keypoints.greedy_minus_regular_combined_rmse_gain_B25 > 0);
keypoints.recommended_W = sprintf('%s_B25', greedy_method);

if keypoints.w_selection_validation_pass_flag
    if keypoints.worst_case_greedy_success > keypoints.worst_case_regular_success
        keypoints.recommended_next_step = 'use_best_greedy_existing_pool_W_for_pair2d_ml_and_document_worst_case_gain';
    else
        keypoints.recommended_next_step = 'use_greedy_lowcorr_as_backend_W_candidate_but_document_worst_case_not_solved';
    end
elseif keypoints.svd_minus_regular_success_gain_B25 > 0.1
    keypoints.recommended_next_step = 'document_svd_gap_and_consider_new_engineering_beam_layout_study';
else
    keypoints.recommended_next_step = 'keep_existing_3dB_beam_layout_for_pair2d_ml_and_prepare_writing';
end
end

function row = select_aggregate_row_local(T, method_name, B)
mask = strcmp(cellstr(T.method_name), method_name) & abs(T.B - B) < 1e-12;
if ~any(mask)
    error('run_stage2_w_selection_validation:MissingAggregateRow', 'Missing %s B=%d.', method_name, B);
end
row = T(find(mask, 1), :);
end

function keypoint_table = keypoints_to_table_local(keypoints)
names = fieldnames(keypoints);
rows = repmat(struct('keypoint', '', 'value', ''), numel(names), 1);
for idx = 1:numel(names)
    rows(idx).keypoint = names{idx};
    value = keypoints.(names{idx});
    if isnumeric(value) || islogical(value)
        rows(idx).value = sprintf('%.12g', double(value));
    else
        rows(idx).value = char(value);
    end
end
keypoint_table = struct2table(rows);
end

function plot_paths = make_plots_local(summary_table, result_dir)
plot_paths = {};
plot_paths{end + 1} = plot_success_compare_local(summary_table, result_dir);
plot_paths{end + 1} = plot_rmse_compare_local(summary_table, result_dir);
plot_paths{end + 1} = plot_worst_case_compare_local(summary_table, result_dir);
plot_paths{end + 1} = plot_metric_vs_success_local(summary_table, result_dir, 'projection_loss', ...
    'projection loss', 'w_method_projection_vs_success.png');
plot_paths{end + 1} = plot_metric_vs_success_local(summary_table, result_dir, 'max_corr', ...
    'max corr', 'w_method_corr_vs_success.png');
plot_paths{end + 1} = plot_complexity_compare_local(summary_table, result_dir);
end

function aggregate = aggregate_for_plot_local(summary_table)
aggregate = unique(summary_table(:, {'method_name','B','overall_joint_success_rate','overall_az_rmse_deg', ...
    'overall_el_rmse_deg','worst_case_success','projection_loss','max_corr','cond_WHW','mean_num_pairs'}), 'rows');
end

function out_path = plot_success_compare_local(summary_table, result_dir)
aggregate = aggregate_for_plot_local(summary_table);
methods = unique(cellstr(aggregate.method_name), 'stable');
fig = figure('Visible', 'off');
hold on;
for iMethod = 1:numel(methods)
    sub = aggregate(strcmp(cellstr(aggregate.method_name), methods{iMethod}), :);
    [B_vals, order] = sort(sub.B);
    plot(B_vals, sub.overall_joint_success_rate(order), '-o', 'LineWidth', 1.4);
end
hold off;
grid on;
xlabel('B');
ylabel('overall joint success');
title('W method success comparison');
legend(methods, 'Location', 'best');
out_path = fullfile(result_dir, 'w_method_success_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_rmse_compare_local(summary_table, result_dir)
aggregate = aggregate_for_plot_local(summary_table);
methods = unique(cellstr(aggregate.method_name), 'stable');
fig = figure('Visible', 'off');
hold on;
for iMethod = 1:numel(methods)
    sub = aggregate(strcmp(cellstr(aggregate.method_name), methods{iMethod}), :);
    [B_vals, order] = sort(sub.B);
    vals = hypot(sub.overall_az_rmse_deg, sub.overall_el_rmse_deg);
    plot(B_vals, vals(order), '-o', 'LineWidth', 1.4);
end
hold off;
grid on;
xlabel('B');
ylabel('combined RMSE (deg)');
title('W method RMSE comparison');
legend(methods, 'Location', 'best');
out_path = fullfile(result_dir, 'w_method_rmse_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_worst_case_compare_local(summary_table, result_dir)
aggregate = aggregate_for_plot_local(summary_table);
methods = unique(cellstr(aggregate.method_name), 'stable');
fig = figure('Visible', 'off');
hold on;
for iMethod = 1:numel(methods)
    sub = aggregate(strcmp(cellstr(aggregate.method_name), methods{iMethod}), :);
    [B_vals, order] = sort(sub.B);
    plot(B_vals, sub.worst_case_success(order), '-o', 'LineWidth', 1.4);
end
hold off;
grid on;
xlabel('B');
ylabel('worst-case scenario success');
title('Worst-case success by W method');
legend(methods, 'Location', 'best');
out_path = fullfile(result_dir, 'w_method_worst_case_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_metric_vs_success_local(summary_table, result_dir, metric_name, x_label, file_name)
aggregate = aggregate_for_plot_local(summary_table);
fig = figure('Visible', 'off');
scatter(aggregate.(metric_name), aggregate.overall_joint_success_rate, 60, aggregate.B, 'filled');
grid on;
xlabel(x_label);
ylabel('overall joint success');
title(strrep(file_name, '_', '\_'));
colorbar;
out_path = fullfile(result_dir, file_name);
saveas(fig, out_path);
close(fig);
end

function out_path = plot_complexity_compare_local(summary_table, result_dir)
aggregate = aggregate_for_plot_local(summary_table);
methods = unique(cellstr(aggregate.method_name), 'stable');
fig = figure('Visible', 'off');
hold on;
for iMethod = 1:numel(methods)
    sub = aggregate(strcmp(cellstr(aggregate.method_name), methods{iMethod}), :);
    [B_vals, order] = sort(sub.B);
    plot(B_vals, sub.mean_num_pairs(order), '-o', 'LineWidth', 1.4);
end
hold off;
grid on;
xlabel('beam count B');
ylabel('backend pair candidates');
title('Pair2d backend complexity comparison');
legend(methods, 'Location', 'best');
out_path = fullfile(result_dir, 'w_method_complexity_compare.png');
saveas(fig, out_path);
close(fig);
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

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage2_w_selection_validation:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
