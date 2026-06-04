clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_1_ula_prior_ablation');

addpath(common_dir);
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.1 Stage1 ULA prior ablation starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

array_num = 256;
numSnapshots = 130;
lambda = 0.3 / 2.7;
d = 0.047;
theta_true = [12.7, 14.3];
true_center = mean(theta_true);
beam_width = 2.8;
beam_count_list = [16, 20, 24, 28, 32];
center_bias_list = [-0.6, -0.4, -0.2, 0, 0.2, 0.4, 0.6];
search_modes = {'left_right', 'ordered'};
grid_step_deg = 0.01;
snr_db = 20;
Metkl = 50;
tol_deg = 0.1;
base_seed = 20260611;

rng(base_seed, 'twister');

log_lines = append_log_local(log_lines, 'array_num=%d, snapshots=%d, snr=%.1f dB, Metkl=%d', ...
    array_num, numSnapshots, snr_db, Metkl);
log_lines = append_log_local(log_lines, 'theta_true=[%.3f %.3f], true_center=%.3f, beam_width=%.3f', ...
    theta_true(1), theta_true(2), true_center, beam_width);
log_lines = append_log_local(log_lines, 'beam_count_list=%s', mat2str(beam_count_list));
log_lines = append_log_local(log_lines, 'center_bias_list=%s', mat2str(center_bias_list));

total_rows = Metkl * numel(center_bias_list) * numel(beam_count_list) * numel(search_modes);
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

tic;
for trial_id = 1:Metkl
    rng(base_seed + trial_id, 'twister');
    L = numSnapshots;

    A_true = build_ula_pair_manifold(theta_true, array_num, d, lambda);
    s1 = exp(1j * 2*pi * rand(1, L));
    s2 = 0.8 * exp(1j * 2*pi * rand(1, L));
    Y_clean = A_true * [s1; s2];
    noise_power = mean(abs(Y_clean(:)).^2) / 10^(snr_db/10);
    noise = sqrt(noise_power/2) * (randn(size(Y_clean)) + 1j*randn(size(Y_clean)));
    Y = Y_clean + noise;

    if ~isequal(size(Y), [array_num, L])
        error('run_stage1:SnapshotShapeMismatch', 'Y must be array_num x numSnapshots.');
    end

    for iBias = 1:numel(center_bias_list)
        center_bias = center_bias_list(iBias);
        beam_c = true_center + center_bias;
        search_bounds = [beam_c - beam_width/2, beam_c + beam_width/2];

        for iBeam = 1:numel(beam_count_list)
            beam_count = beam_count_list(iBeam);
            beam_angles = linspace(beam_c - beam_width, beam_c + beam_width, beam_count);
            [W, winfo] = build_ula_beam_transform(array_num, d, lambda, beam_angles);
            if ~isequal(size(W), [array_num, beam_count])
                error('run_stage1:WShapeMismatch', 'W shape mismatch.');
            end

            Z = W' * Y;
            if ~isequal(size(Z), [beam_count, L])
                error('run_stage1:ZShapeMismatch', 'Z must be beam_count x numSnapshots.');
            end

            cfg = struct();
            cfg.beam_c = beam_c;
            cfg.beam_width = beam_width;
            cfg.grid_step_deg = grid_step_deg;
            cfg.array_num = array_num;
            cfg.d = d;
            cfg.lambda = lambda;
            cfg.reg = 1e-10;

            for iMode = 1:numel(search_modes)
                search_mode = search_modes{iMode};
                switch search_mode
                    case 'left_right'
                        [theta_hat, ~, search_debug] = search_pair_grid_left_right(Z, W, cfg);
                    case 'ordered'
                        [theta_hat, ~, search_debug] = search_pair_grid_ordered(Z, W, cfg);
                    otherwise
                        error('run_stage1:UnknownSearchMode', 'Unknown search mode: %s', search_mode);
                end

                metrics = eval_pair_metrics(theta_hat, theta_true, search_bounds, tol_deg);

                row_idx = row_idx + 1;
                trial_rows(row_idx).trial_id = trial_id;
                trial_rows(row_idx).search_mode = search_mode;
                trial_rows(row_idx).beam_count = beam_count;
                trial_rows(row_idx).center_bias_deg = center_bias;
                trial_rows(row_idx).beam_c = beam_c;
                trial_rows(row_idx).snr_db = snr_db;
                trial_rows(row_idx).theta_hat_1 = theta_hat(1);
                trial_rows(row_idx).theta_hat_2 = theta_hat(2);
                trial_rows(row_idx).theta_true_1 = theta_true(1);
                trial_rows(row_idx).theta_true_2 = theta_true(2);
                trial_rows(row_idx).raw_success = metrics.raw_success;
                trial_rows(row_idx).tol_success = metrics.tol_success;
                trial_rows(row_idx).rmse_deg = metrics.rmse_deg;
                trial_rows(row_idx).center_error_deg = metrics.center_error_deg;
                trial_rows(row_idx).sep_error_deg = metrics.sep_error_deg;
                trial_rows(row_idx).boundary_hit = metrics.boundary_hit;
                trial_rows(row_idx).max_score = search_debug.max_score;
                trial_rows(row_idx).num_pairs = search_debug.num_pairs;
                trial_rows(row_idx).window_name = winfo.windowName;
                trial_rows(row_idx).window_fallback = winfo.windowFallback;
            end
        end
    end

    if mod(trial_id, 5) == 0 || trial_id == 1 || trial_id == Metkl
        log_lines = append_log_local(log_lines, 'Completed trial %d / %d, elapsed %.2f s', ...
            trial_id, Metkl, toc);
    end
end

if row_idx ~= total_rows
    error('run_stage1:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
if isempty(trial_table)
    error('run_stage1:EmptyTrialTable', 'trial_table is empty.');
end

summary_rows = build_summary_rows_local(trial_table, search_modes, beam_count_list, center_bias_list);
summary_table = struct2table(summary_rows);
if isempty(summary_table)
    error('run_stage1:EmptySummaryTable', 'summary_table is empty.');
end

[keypoint_rows, keypoints] = build_keypoints_local(summary_table);
keypoint_table = struct2table(keypoint_rows);
if isempty(keypoint_table)
    error('run_stage1:EmptyKeypointTable', 'keypoint_table is empty.');
end

trial_csv = fullfile(result_dir, 'step11_1_ula_prior_ablation_trial.csv');
summary_csv = fullfile(result_dir, 'step11_1_ula_prior_ablation_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_1_ula_prior_ablation_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_1_ula_prior_ablation_result.mat');
log_path = fullfile(result_dir, 'step11_1_ula_prior_ablation.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);

plot_paths = make_plots_local(summary_table, result_dir, center_bias_list, beam_count_list);

params = struct();
params.array_num = array_num;
params.numSnapshots = numSnapshots;
params.lambda = lambda;
params.d = d;
params.theta_true = theta_true;
params.true_center = true_center;
params.beam_width = beam_width;
params.beam_count_list = beam_count_list;
params.center_bias_list = center_bias_list;
params.search_modes = search_modes;
params.grid_step_deg = grid_step_deg;
params.snr_db = snr_db;
params.Metkl = Metkl;
params.tol_deg = tol_deg;
params.base_seed = base_seed;

save(mat_path, 'params', 'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_log_local(log_lines, 'prior_dependency_flag=%d', keypoints.prior_dependency_flag);
log_lines = append_log_local(log_lines, 'recommended_next_step=%s', keypoints.recommended_next_step);
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function row = make_trial_row_template_local()
row = struct();
row.trial_id = NaN;
row.search_mode = '';
row.beam_count = NaN;
row.center_bias_deg = NaN;
row.beam_c = NaN;
row.snr_db = NaN;
row.theta_hat_1 = NaN;
row.theta_hat_2 = NaN;
row.theta_true_1 = NaN;
row.theta_true_2 = NaN;
row.raw_success = false;
row.tol_success = false;
row.rmse_deg = NaN;
row.center_error_deg = NaN;
row.sep_error_deg = NaN;
row.boundary_hit = false;
row.max_score = NaN;
row.num_pairs = NaN;
row.window_name = '';
row.window_fallback = '';
end

function rows = build_summary_rows_local(trial_table, search_modes, beam_count_list, center_bias_list)
template = struct();
template.search_mode = '';
template.beam_count = NaN;
template.center_bias_deg = NaN;
template.raw_success_rate = NaN;
template.tol_success_rate = NaN;
template.mean_rmse_deg = NaN;
template.median_rmse_deg = NaN;
template.mean_abs_center_error_deg = NaN;
template.mean_abs_sep_error_deg = NaN;
template.boundary_hit_rate = NaN;
template.mean_num_pairs = NaN;

rows = repmat(template, numel(search_modes) * numel(beam_count_list) * numel(center_bias_list), 1);
idx = 0;
for iMode = 1:numel(search_modes)
    mode_now = search_modes{iMode};
    mode_col = trial_table.search_mode;
    if iscell(mode_col)
        mode_mask = strcmp(mode_col, mode_now);
    else
        mode_mask = strcmp(cellstr(mode_col), mode_now);
    end

    for iBeam = 1:numel(beam_count_list)
        beam_count = beam_count_list(iBeam);
        for iBias = 1:numel(center_bias_list)
            center_bias = center_bias_list(iBias);
            mask = mode_mask & trial_table.beam_count == beam_count & ...
                abs(trial_table.center_bias_deg - center_bias) < 1e-12;
            sub = trial_table(mask, :);
            if isempty(sub)
                error('run_stage1:MissingSummaryGroup', ...
                    'Missing summary group mode=%s beam_count=%d center_bias=%.3f.', ...
                    mode_now, beam_count, center_bias);
            end

            idx = idx + 1;
            rows(idx).search_mode = mode_now;
            rows(idx).beam_count = beam_count;
            rows(idx).center_bias_deg = center_bias;
            rows(idx).raw_success_rate = mean(double(sub.raw_success));
            rows(idx).tol_success_rate = mean(double(sub.tol_success));
            rows(idx).mean_rmse_deg = mean_omitnan_local(sub.rmse_deg);
            rows(idx).median_rmse_deg = median_omitnan_local(sub.rmse_deg);
            rows(idx).mean_abs_center_error_deg = mean_omitnan_local(abs(sub.center_error_deg));
            rows(idx).mean_abs_sep_error_deg = mean_omitnan_local(abs(sub.sep_error_deg));
            rows(idx).boundary_hit_rate = mean(double(sub.boundary_hit));
            rows(idx).mean_num_pairs = mean_omitnan_local(sub.num_pairs);
        end
    end
end
end

function [rows, keypoints] = build_keypoints_local(summary_table)
lr0 = select_summary_local(summary_table, 'left_right', 0);
ord0 = select_summary_local(summary_table, 'ordered', 0);

[best_lr_tol, best_lr_idx] = max(lr0.tol_success_rate);
[best_ord_tol, best_ord_idx] = max(ord0.tol_success_rate);
best_lr_beam = lr0.beam_count(best_lr_idx);
best_ord_beam = ord0.beam_count(best_ord_idx);
gap_at_bias0 = best_lr_tol - best_ord_tol;
max_boundary_hit_rate = max(summary_table.boundary_hit_rate);

prior_dependency_flag = double(gap_at_bias0 > 0.2 || best_ord_tol < 0.7);
if prior_dependency_flag == 0
    recommended_next_step = 'proceed_to_cylindrical_azonly_beamspace_ml';
else
    recommended_next_step = 'fix_search_prior_before_cylindrical_migration';
end

keypoints = struct();
keypoints.best_left_right_tol_success_at_bias0 = best_lr_tol;
keypoints.best_ordered_tol_success_at_bias0 = best_ord_tol;
keypoints.left_right_minus_ordered_success_gap_at_bias0 = gap_at_bias0;
keypoints.max_boundary_hit_rate = max_boundary_hit_rate;
keypoints.recommended_next_step = recommended_next_step;
keypoints.prior_dependency_flag = prior_dependency_flag;
keypoints.best_left_right_beam_count_at_bias0 = best_lr_beam;
keypoints.best_ordered_beam_count_at_bias0 = best_ord_beam;

rows = repmat(make_keypoint_row_template_local(), 8, 1);
rows(1) = make_keypoint_row_local('best_left_right_tol_success_at_bias0', best_lr_tol, '');
rows(2) = make_keypoint_row_local('best_ordered_tol_success_at_bias0', best_ord_tol, '');
rows(3) = make_keypoint_row_local('left_right_minus_ordered_success_gap_at_bias0', gap_at_bias0, '');
rows(4) = make_keypoint_row_local('max_boundary_hit_rate', max_boundary_hit_rate, '');
rows(5) = make_keypoint_row_local('recommended_next_step', NaN, recommended_next_step);
rows(6) = make_keypoint_row_local('prior_dependency_flag', prior_dependency_flag, '');
rows(7) = make_keypoint_row_local('best_left_right_beam_count_at_bias0', best_lr_beam, '');
rows(8) = make_keypoint_row_local('best_ordered_beam_count_at_bias0', best_ord_beam, '');
end

function row = make_keypoint_row_template_local()
row = struct();
row.metric = '';
row.metric_value = NaN;
row.metric_text = '';
end

function row = make_keypoint_row_local(metric, metric_value, metric_text)
row = make_keypoint_row_template_local();
row.metric = metric;
row.metric_value = metric_value;
row.metric_text = metric_text;
end

function sub = select_summary_local(summary_table, search_mode, center_bias)
mode_col = summary_table.search_mode;
if iscell(mode_col)
    mode_mask = strcmp(mode_col, search_mode);
else
    mode_mask = strcmp(cellstr(mode_col), search_mode);
end
mask = mode_mask & abs(summary_table.center_bias_deg - center_bias) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage1:MissingBias0Summary', 'Missing bias0 summary for %s.', search_mode);
end
end

function plot_paths = make_plots_local(summary_table, result_dir, center_bias_list, beam_count_list)
plot_paths = {};
plot_paths{end + 1} = plot_metric_by_bias_local(summary_table, result_dir, center_bias_list, ...
    'tol_success_rate', 'max', 'Tolerance success vs center bias', ...
    'center bias (deg)', 'best tolerance success rate', ...
    'ula_prior_ablation_tol_success_vs_center_bias.png');
plot_paths{end + 1} = plot_metric_by_bias_local(summary_table, result_dir, center_bias_list, ...
    'mean_rmse_deg', 'min', 'RMSE vs center bias', ...
    'center bias (deg)', 'best mean RMSE (deg)', ...
    'ula_prior_ablation_rmse_vs_center_bias.png');
plot_paths{end + 1} = plot_metric_by_bias_local(summary_table, result_dir, center_bias_list, ...
    'boundary_hit_rate', 'max', 'Boundary hit rate vs center bias', ...
    'center bias (deg)', 'max boundary hit rate', ...
    'ula_prior_ablation_boundary_hit_rate.png');
plot_paths{end + 1} = plot_bias0_bar_local(summary_table, result_dir, beam_count_list);
end

function out_path = plot_metric_by_bias_local(summary_table, result_dir, center_bias_list, metric_name, reducer, title_text, x_text, y_text, file_name)
fig = figure('Visible', 'off');
hold on;
mode_list = {'left_right', 'ordered'};
style_list = {'-o', '-s'};
for iMode = 1:numel(mode_list)
    values = nan(size(center_bias_list));
    for iBias = 1:numel(center_bias_list)
        sub = select_summary_local(summary_table, mode_list{iMode}, center_bias_list(iBias));
        metric_values = sub.(metric_name);
        switch reducer
            case 'max'
                values(iBias) = max(metric_values);
            case 'min'
                values(iBias) = min(metric_values);
            otherwise
                error('run_stage1:UnknownReducer', 'Unknown reducer: %s', reducer);
        end
    end
    plot(center_bias_list, values, style_list{iMode}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
grid on;
xlabel(x_text);
ylabel(y_text);
title(title_text);
legend(mode_list, 'Location', 'best');
out_path = fullfile(result_dir, file_name);
saveas(fig, out_path);
close(fig);
end

function out_path = plot_bias0_bar_local(summary_table, result_dir, beam_count_list)
lr0 = select_summary_local(summary_table, 'left_right', 0);
ord0 = select_summary_local(summary_table, 'ordered', 0);
lr_vals = nan(size(beam_count_list));
ord_vals = nan(size(beam_count_list));
for iBeam = 1:numel(beam_count_list)
    lr_vals(iBeam) = lr0.tol_success_rate(lr0.beam_count == beam_count_list(iBeam));
    ord_vals(iBeam) = ord0.tol_success_rate(ord0.beam_count == beam_count_list(iBeam));
end

fig = figure('Visible', 'off');
bar(beam_count_list, [lr_vals(:), ord_vals(:)], 'grouped');
grid on;
xlabel('beam count');
ylabel('tolerance success rate at center bias 0');
title('Left-right vs ordered search at center bias 0');
legend({'left_right', 'ordered'}, 'Location', 'best');
out_path = fullfile(result_dir, 'ula_prior_ablation_left_right_vs_ordered_bias0.png');
saveas(fig, out_path);
close(fig);
end

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function v = median_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = median(x);
end
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage1:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
