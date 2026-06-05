clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
step11_1_common_dir = fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common');
result_dir = fullfile(step_dir, 'results_step11_2_recommended_w_robustness_confirmation');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.2 Stage4 recommended W robustness confirmation starts');
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
    error('run_stage4_recommended_w_robustness_confirmation:NelemMismatch', ...
        'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;
az_c = cfg.beam.azSectorCenter;
el_c = cfg.beam.elSectorCenter;
el_center_offset = 0.31;
reg = 1e-10;

[W_pool, pool_info] = build_existing_2d_beam_pool(x, y, z, az_c, el_c, lambda, cfg, ...
    'Mode', 'legacy_or_fallback', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, ...
    'AzPoolOffsets', -2.4:0.4:2.4, 'ElPoolOffsets', -1.6:0.4:1.6);
az_patch = az_c + (-1.5:0.15:1.5);
el_patch = el_c + (-1.0:0.15:1.0);
[A_patch, patch_info] = build_local_patch_dictionary(x, y, z, az_patch, el_patch, lambda, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
pair_set = build_pair_set_local(az_c, el_c + el_center_offset, [0.83, 1.27], [0, 0.37, 0.67], [1, -1]);

log_lines = append_log_local(log_lines, 'W_pool M=%d, mode=%s', pool_info.M, pool_info.mode_used);
log_lines = append_log_local(log_lines, 'A_patch columns=%d, pair_set rows=%d', size(A_patch, 2), size(pair_set, 1));

tic;
W_cases = build_stage4_w_cases_local(W_pool, pool_info, A_patch, pair_set, x, y, z, lambda, ...
    phase_factor, phase_sign, reg);
log_lines = append_log_local(log_lines, 'Built W cases=%d, elapsed %.2f s', numel(W_cases), toc);

scenario_table = build_scenario_table_local();
cfg_eval = struct();
cfg_eval.x = x;
cfg_eval.y = y;
cfg_eval.z = z;
cfg_eval.lambda = lambda;
cfg_eval.phase_factor = phase_factor;
cfg_eval.phase_sign = phase_sign;
cfg_eval.az_center_true = az_c;
cfg_eval.el_center_nominal = el_c;
cfg_eval.el_center_offset = el_center_offset;
cfg_eval.L = 64;
cfg_eval.Metkl = 30;
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
cfg_eval.base_seed = 20260623;

log_lines = append_log_local(log_lines, 'Scenarios=%d, Metkl=%d, total trials=%d', ...
    height(scenario_table), cfg_eval.Metkl, numel(W_cases) * height(scenario_table) * cfg_eval.Metkl);

tic;
[trial_table, summary_table] = evaluate_w_pair2d_backend(W_cases, scenario_table, cfg_eval);
log_lines = append_log_local(log_lines, 'Backend validation finished: rows=%d, elapsed %.2f s', height(trial_table), toc);

[keypoint_table, keypoints] = summarize_stage4_keypoints_local(summary_table);
plot_paths = make_stage4_plots_local(summary_table, result_dir);

trial_csv = fullfile(result_dir, 'step11_2_w_robustness_trial.csv');
summary_csv = fullfile(result_dir, 'step11_2_w_robustness_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_2_w_robustness_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_2_w_robustness_result.mat');
log_path = fullfile(result_dir, 'step11_2_w_robustness.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);

params = struct();
params.N_elem = N_elem;
params.lambda = lambda;
params.phase_factor = phase_factor;
params.phase_sign = phase_sign;
params.az_c = az_c;
params.el_c = el_c;
params.el_center_offset = el_center_offset;
params.az_patch = az_patch;
params.el_patch = el_patch;
params.pair_set = pair_set;
params.reg = reg;
params.cfg_eval = cfg_eval;
save(mat_path, 'params', 'pool_info', 'patch_info', 'W_cases', 'scenario_table', ...
    'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'plot_paths');

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

function W_cases = build_stage4_w_cases_local(W_pool, pool_info, A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg)
W_cases = struct([]);

[idx_regular, W_regular, info_regular] = select_regular_center_beams_from_pool(W_pool, pool_info, 7);
W_cases = add_case_local(W_cases, 'regular_B7', 'regular', 7, W_regular, idx_regular, info_regular.note, ...
    [], A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg);

combined_B_list = [7, 9, 15, 25];
for iB = 1:numel(combined_B_list)
    B = combined_B_list(iB);
    [idx, W, history] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, ...
        'Criterion', 'combined', 'Alpha', 1, 'Beta', 1, 'Gamma', 0.05, ...
        'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
    W_cases = add_case_local(W_cases, sprintf('greedy_combined_B%d', B), 'greedy_combined', B, W, idx, ...
        'Stage4 greedy combined confirmation case', history, A_patch, pair_set, x, y, z, lambda, ...
        phase_factor, phase_sign, reg);
end

[idx_lowcorr, W_lowcorr, hist_lowcorr] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, 25, ...
    'Criterion', 'lowcorr', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
W_cases = add_case_local(W_cases, 'greedy_lowcorr_B25', 'greedy_lowcorr', 25, W_lowcorr, idx_lowcorr, ...
    'Stage4 greedy low-correlation B25 comparator', hist_lowcorr, A_patch, pair_set, x, y, z, lambda, ...
    phase_factor, phase_sign, reg);
end

function W_cases = add_case_local(W_cases, name, method_type, B, W, selected_idx, note, history, A_patch, pair_set, ...
    x, y, z, lambda, phase_factor, phase_sign, reg)
metrics = collect_w_design_metrics(name, B, W, A_patch, pair_set, x, y, z, lambda, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
entry = struct();
entry.name = name;
entry.method_type = method_type;
entry.B = B;
entry.W = W;
entry.selected_idx = selected_idx;
entry.projection_loss = metrics.projection_loss;
entry.projected_energy_ratio = metrics.projected_energy_ratio;
entry.mean_corr = metrics.mean_corr;
entry.p90_corr = metrics.p90_corr;
entry.max_corr = metrics.max_corr;
entry.cond_WHW = metrics.cond_WHW;
entry.rank_W = metrics.rank_W;
entry.effective_rank = metrics.effective_rank;
entry.selection_history = history;
entry.note = note;
W_cases = [W_cases; entry]; %#ok<AGROW>
end

function [keypoint_table, keypoints] = summarize_stage4_keypoints_local(summary_table)
aggregate = unique(summary_table(:, {'method_name','method_type','B','overall_joint_success_rate', ...
    'overall_az_rmse_deg','overall_el_rmse_deg','worst_case_success','projection_loss','max_corr', ...
    'cond_WHW','mean_num_pairs'}), 'rows');
aggregate.combined_rmse_deg = hypot(aggregate.overall_az_rmse_deg, aggregate.overall_el_rmse_deg);

best_success = max(aggregate.overall_joint_success_rate);
best_rmse = min(aggregate.combined_rmse_deg);
best_worst = max(aggregate.worst_case_success);
score = aggregate.overall_joint_success_rate + 0.25 * aggregate.worst_case_success - ...
    0.05 * aggregate.combined_rmse_deg;
[~, best_idx] = max(score);
best = aggregate(best_idx, :);

b7 = select_case_local(aggregate, 'greedy_combined_B7');
b25_combined = select_case_local(aggregate, 'greedy_combined_B25');
b25_lowcorr = select_case_local(aggregate, 'greedy_lowcorr_B25');

keypoints = struct();
keypoints.b7_success = b7.overall_joint_success_rate(1);
keypoints.b7_rmse = b7.combined_rmse_deg(1);
keypoints.b7_worst_case_success = b7.worst_case_success(1);
keypoints.best_success_overall = best_success;
keypoints.best_rmse_overall = best_rmse;
keypoints.best_worst_case_success = best_worst;
keypoints.best_method_overall = char_value_local(best.method_name(1));
keypoints.b7_minus_best_success_gap = b7.overall_joint_success_rate(1) - best_success;
keypoints.b7_rmse_over_best_ratio = b7.combined_rmse_deg(1) / max(best_rmse, eps);
keypoints.b7_worst_case_minus_best_worst_case = b7.worst_case_success(1) - best_worst;
keypoints.b25_combined_success = b25_combined.overall_joint_success_rate(1);
keypoints.b25_lowcorr_success = b25_lowcorr.overall_joint_success_rate(1);

pass_flag = b7.overall_joint_success_rate(1) >= 0.95 * best_success && ...
    b7.combined_rmse_deg(1) <= 1.05 * best_rmse && ...
    b7.worst_case_success(1) >= best_worst - 0.1;
keypoints.robustness_pass_flag = pass_flag;

if pass_flag
    keypoints.recommended_final_W = 'greedy_combined';
    keypoints.recommended_final_B = 7;
    keypoints.recommended_next_step = 'finalize_step11_2_w_design_evidence_summary';
else
    near_mask = aggregate.overall_joint_success_rate >= 0.95 * best_success & ...
        aggregate.combined_rmse_deg <= 1.05 * best_rmse & ...
        aggregate.worst_case_success >= best_worst - 0.1;
    if any(near_mask)
        candidates = aggregate(near_mask, :);
        [~, order] = sortrows([candidates.B, candidates.combined_rmse_deg]);
        rec = candidates(order(1), :);
    else
        rec = best;
    end
    [rec_W, rec_B] = split_recommendation_local(char_value_local(rec.method_name(1)), rec.B(1));
    keypoints.recommended_final_W = rec_W;
    keypoints.recommended_final_B = rec_B;
    keypoints.recommended_next_step = 'use_stage4_fallback_recommendation_and_document_B7_not_confirmed';
end

keypoint_table = struct2table(keypoints_to_rows_local(keypoints));
end

function row = select_case_local(T, method_name)
mask = strcmp(cellstr(T.method_name), method_name);
if ~any(mask)
    error('run_stage4_recommended_w_robustness_confirmation:MissingCase', 'Missing case: %s', method_name);
end
row = T(find(mask, 1), :);
end

function [rec_W, rec_B] = split_recommendation_local(method_name, B)
rec_B = B;
if startsWith(method_name, 'greedy_combined')
    rec_W = 'greedy_combined';
elseif startsWith(method_name, 'greedy_lowcorr')
    rec_W = 'greedy_lowcorr';
elseif startsWith(method_name, 'regular')
    rec_W = 'regular_3dB_grid';
else
    rec_W = method_name;
end
end

function plot_paths = make_stage4_plots_local(summary_table, result_dir)
aggregate = unique(summary_table(:, {'method_name','B','overall_joint_success_rate','overall_az_rmse_deg', ...
    'overall_el_rmse_deg','worst_case_success'}), 'rows');
aggregate.combined_rmse_deg = hypot(aggregate.overall_az_rmse_deg, aggregate.overall_el_rmse_deg);
plot_paths = {};
plot_paths{end + 1} = plot_bar_local(aggregate, result_dir, 'overall_joint_success_rate', ...
    'overall joint success', 'w_robustness_success_compare.png');
plot_paths{end + 1} = plot_bar_local(aggregate, result_dir, 'combined_rmse_deg', ...
    'combined RMSE (deg)', 'w_robustness_rmse_compare.png');
plot_paths{end + 1} = plot_bar_local(aggregate, result_dir, 'worst_case_success', ...
    'worst-case success', 'w_robustness_worst_case_compare.png');
plot_paths{end + 1} = plot_b7_vs_b25_local(aggregate, result_dir);
end

function out_path = plot_bar_local(aggregate, result_dir, field_name, y_label, file_name)
fig = figure('Visible', 'off');
bar(aggregate.(field_name));
grid on;
set(gca, 'XTick', 1:height(aggregate), 'XTickLabel', cellstr(aggregate.method_name));
xtickangle(35);
ylabel(y_label);
title(strrep(file_name, '_', '\_'));
out_path = fullfile(result_dir, file_name);
saveas(fig, out_path);
close(fig);
end

function out_path = plot_b7_vs_b25_local(aggregate, result_dir)
names = {'greedy_combined_B7','greedy_combined_B25','greedy_lowcorr_B25'};
vals = nan(numel(names), 3);
for iName = 1:numel(names)
    row = select_case_local(aggregate, names{iName});
    vals(iName, :) = [row.overall_joint_success_rate(1), row.combined_rmse_deg(1), row.worst_case_success(1)];
end
fig = figure('Visible', 'off');
bar(vals);
grid on;
set(gca, 'XTick', 1:numel(names), 'XTickLabel', names);
xtickangle(25);
legend({'success','combined RMSE','worst-case'}, 'Location', 'best');
title('B7 vs B25 robustness comparison');
out_path = fullfile(result_dir, 'w_robustness_b7_vs_b25.png');
saveas(fig, out_path);
close(fig);
end

function pair_set = build_pair_set_local(az_c, el_c, az_sep_list, el_sep_list, orientation_list)
pair_set = zeros(numel(az_sep_list) * numel(el_sep_list) * numel(orientation_list), 4);
idx = 0;
for iAz = 1:numel(az_sep_list)
    az_sep = az_sep_list(iAz);
    az_pair = az_c + [-az_sep/2, az_sep/2];
    for iEl = 1:numel(el_sep_list)
        el_sep = el_sep_list(iEl);
        for iOri = 1:numel(orientation_list)
            orientation = orientation_list(iOri);
            if el_sep == 0 && orientation == -1
                continue;
            end
            idx = idx + 1;
            if orientation == 1
                el_pair = el_c + [-el_sep/2, el_sep/2];
            else
                el_pair = el_c + [el_sep/2, -el_sep/2];
            end
            pair_set(idx, :) = [az_pair(1), el_pair(1), az_pair(2), el_pair(2)];
        end
    end
end
pair_set = pair_set(1:idx, :);
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

function rows = keypoints_to_rows_local(keypoints)
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
    error('run_stage4_recommended_w_robustness_confirmation:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end

