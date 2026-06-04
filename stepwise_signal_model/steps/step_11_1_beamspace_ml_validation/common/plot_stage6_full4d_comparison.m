function plot_paths = plot_stage6_full4d_comparison(summary_table, result_dir)
%PLOT_STAGE6_FULL4D_COMPARISON Create Stage6 comparison figures.

if nargin ~= 2
    error('plot_stage6_full4d_comparison:InvalidInputCount', 'summary_table and result_dir are required.');
end
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

plot_paths = {};
plot_paths{end + 1} = plot_model_joint_success_local(summary_table, result_dir);
plot_paths{end + 1} = plot_model_az_rmse_local(summary_table, result_dir);
plot_paths{end + 1} = plot_model_el_rmse_local(summary_table, result_dir);
plot_paths{end + 1} = plot_full4d_pair2d_gap_local(summary_table, result_dir);
plot_paths{end + 1} = plot_complexity_num_pairs_local(summary_table, result_dir);
plot_paths{end + 1} = plot_boundary_hit_local(summary_table, result_dir);
plot_paths{end + 1} = plot_score_margin_local(summary_table, result_dir);
end

function sub = select_plot_subset_local(summary_table)
sub = summary_table(string_match_local(summary_table.whitening_mode, 'white') & ...
    string_match_local(summary_table.beam_layout_name, 'az5_el5') & ...
    abs(summary_table.az_center_bias_deg) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg) < 1e-12 & ...
    abs(summary_table.snr_db - 30) < 1e-12, :);
if isempty(sub)
    sub = summary_table;
end
end

function [models, labels] = model_order_local()
models = {'common_el_restricted', 'controlled_pair2d', 'full4d'};
labels = {'common', 'pair2d', 'full4d'};
end

function vals = model_means_local(sub, field_name)
[models, ~] = model_order_local();
vals = nan(1, numel(models));
for idx = 1:numel(models)
    vals(idx) = mean_omitnan_local(sub.(field_name)(string_match_local(sub.model_mode, models{idx})));
end
end

function out_path = plot_model_joint_success_local(summary_table, result_dir)
sub = select_plot_subset_local(summary_table);
[~, labels] = model_order_local();
vals = model_means_local(sub, 'joint_tol_success_rate');
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
ylim([0, 1]);
grid on;
ylabel('joint success rate');
title('Stage6 model joint success comparison');
out_path = fullfile(result_dir, 'stage6_model_joint_success_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_model_az_rmse_local(summary_table, result_dir)
sub = select_plot_subset_local(summary_table);
[~, labels] = model_order_local();
vals = model_means_local(sub, 'mean_az_rmse_deg');
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean az RMSE (deg)');
title('Stage6 azimuth RMSE comparison');
out_path = fullfile(result_dir, 'stage6_model_az_rmse_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_model_el_rmse_local(summary_table, result_dir)
sub = select_plot_subset_local(summary_table);
[~, labels] = model_order_local();
vals = model_means_local(sub, 'mean_el_rmse_deg');
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean el RMSE (deg)');
title('Stage6 elevation RMSE comparison');
out_path = fullfile(result_dir, 'stage6_model_el_rmse_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_full4d_pair2d_gap_local(summary_table, result_dir)
sub = select_plot_subset_local(summary_table);
full_sub = sub(string_match_local(sub.model_mode, 'full4d'), :);
labels = cellstr_local(full_sub.scenario_name);
vals = full_sub.full4d_minus_pair2d_joint_success_gap;
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
xtickangle(35);
grid on;
ylabel('full4d - pair2d success gap');
title('Stage6 full4d/pair2d gap by scenario');
out_path = fullfile(result_dir, 'stage6_full4d_pair2d_gap_by_scenario.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_complexity_num_pairs_local(summary_table, result_dir)
sub = select_plot_subset_local(summary_table);
[~, labels] = model_order_local();
vals = model_means_local(sub, 'mean_num_pairs');
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean candidate count');
title('Stage6 runtime proxy: candidate count');
out_path = fullfile(result_dir, 'stage6_complexity_num_pairs_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_boundary_hit_local(summary_table, result_dir)
sub = select_plot_subset_local(summary_table);
[~, labels] = model_order_local();
vals = model_means_local(sub, 'boundary_hit_rate');
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
ylim([0, max(1, max(vals) * 1.1)]);
grid on;
ylabel('boundary hit rate');
title('Stage6 boundary hit comparison');
out_path = fullfile(result_dir, 'stage6_boundary_hit_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_score_margin_local(summary_table, result_dir)
sub = select_plot_subset_local(summary_table);
full_sub = sub(string_match_local(sub.model_mode, 'full4d'), :);
labels = cellstr_local(full_sub.scenario_name);
vals1 = full_sub.score_margin_full4d_minus_pair2d;
vals2 = full_sub.score_margin_pair2d_minus_common;
fig = figure('Visible', 'off');
bar([vals1, vals2], 'grouped');
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
xtickangle(35);
grid on;
ylabel('mean score margin');
title('Stage6 model score margin comparison');
legend({'full4d-pair2d', 'pair2d-common'}, 'Location', 'best');
out_path = fullfile(result_dir, 'stage6_model_score_margin_compare.png');
saveas(fig, out_path);
close(fig);
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

function out = cellstr_local(values)
if iscell(values)
    out = values;
elseif isstring(values)
    out = cellstr(values);
else
    out = cellstr(values);
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
