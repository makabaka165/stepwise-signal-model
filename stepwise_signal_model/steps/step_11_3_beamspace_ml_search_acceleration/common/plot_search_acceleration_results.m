function plot_paths = plot_search_acceleration_results(summary_table, result_dir, tag)
%PLOT_SEARCH_ACCELERATION_RESULTS Generate Step11.3 summary figures.

if nargin < 3
    tag = 'step11_3';
end
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

tag = char(tag);
plot_paths = {};
plot_paths{end + 1} = plot_method_bar_local(summary_table, result_dir, tag, 'overall_joint_success_rate', ...
    'overall joint success', 'search_success_compare.png');
plot_paths{end + 1} = plot_method_bar_local(summary_table, result_dir, tag, 'overall_combined_rmse_mean', ...
    'combined RMSE (deg)', 'search_rmse_compare.png');
plot_paths{end + 1} = plot_method_bar_local(summary_table, result_dir, tag, 'overall_mean_num_pairs', ...
    'mean candidate count', 'search_num_pairs_compare.png');
plot_paths{end + 1} = plot_method_bar_local(summary_table, result_dir, tag, 'overall_mean_reduction_ratio_vs_full', ...
    'reduction ratio vs full', 'search_reduction_ratio.png');
plot_paths{end + 1} = plot_method_bar_local(summary_table, result_dir, tag, 'overall_full_grid_match_rate', ...
    'full-grid match rate', 'search_full_grid_match_rate.png');
plot_paths{end + 1} = plot_method_bar_local(summary_table, result_dir, tag, 'overall_topK_miss_rate', ...
    'topK miss rate', 'search_topK_miss_rate.png');
plot_paths{end + 1} = plot_success_vs_topk_local(summary_table, result_dir, tag);
plot_paths{end + 1} = plot_success_vs_coarse_step_local(summary_table, result_dir, tag);
if any(abs(summary_table.az_center_bias_deg) > 1e-12 | abs(summary_table.el_center_bias_deg) > 1e-12)
    plot_paths{end + 1} = plot_bias_robustness_local(summary_table, result_dir, tag);
end
end

function out_path = plot_method_bar_local(summary_table, result_dir, tag, metric_name, y_label, file_name)
agg = aggregate_by_method_local(summary_table);
methods = cellstr_local(agg.search_method);
vals = agg.(metric_name);
fig = figure('Visible', 'off');
bar(vals);
grid on;
set(gca, 'XTick', 1:numel(methods), 'XTickLabel', methods);
xtickangle(20);
ylabel(y_label);
title(strrep(sprintf('%s %s', tag, file_name), '_', '\_'));
out_path = fullfile(result_dir, file_name);
saveas(fig, out_path);
close(fig);
end

function out_path = plot_success_vs_topk_local(summary_table, result_dir, tag)
sub = aggregate_ctf_by_config_local(summary_table);
fig = figure('Visible', 'off');
if isempty(sub)
    plot(0, 0);
else
    topks = unique(sub.topK);
    vals = nan(numel(topks), 1);
    miss = nan(numel(topks), 1);
    for idx = 1:numel(topks)
        rows = sub(abs(sub.topK - topks(idx)) < 1e-12, :);
        vals(idx) = mean_omitnan_local(rows.overall_joint_success_rate);
        miss(idx) = mean_omitnan_local(rows.overall_topK_miss_rate);
    end
    yyaxis left;
    plot(topks, vals, '-o', 'LineWidth', 1.3);
    ylabel('joint success');
    yyaxis right;
    plot(topks, miss, '-s', 'LineWidth', 1.3);
    ylabel('topK miss');
    xlabel('topK');
end
grid on;
title(strrep(sprintf('%s success vs topK', tag), '_', '\_'));
out_path = fullfile(result_dir, 'search_success_vs_topK.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_success_vs_coarse_step_local(summary_table, result_dir, tag)
sub = aggregate_ctf_by_config_local(summary_table);
fig = figure('Visible', 'off');
if isempty(sub)
    plot(0, 0);
else
    x = sub.coarse_az_step;
    y = sub.coarse_el_step;
    c = sub.overall_joint_success_rate;
    scatter(x, y, 72, c, 'filled');
    colorbar;
    xlabel('coarse az step (deg)');
    ylabel('coarse el step (deg)');
end
grid on;
title(strrep(sprintf('%s success vs coarse step', tag), '_', '\_'));
out_path = fullfile(result_dir, 'search_success_vs_coarse_step.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_bias_robustness_local(summary_table, result_dir, tag)
sub = aggregate_ctf_by_config_local(summary_table);
fig = figure('Visible', 'off');
labels = cell(height(sub), 1);
vals = nan(height(sub), 3);
for idx = 1:height(sub)
    labels{idx} = sprintf('[%.1f %.1f]', sub.az_center_bias_deg(idx), sub.el_center_bias_deg(idx));
    vals(idx, :) = [sub.overall_joint_success_rate(idx), sub.overall_topK_miss_rate(idx), sub.overall_boundary_hit_rate(idx)];
end
bar(vals);
grid on;
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
xtickangle(30);
xlabel('[az bias, el bias] deg');
legend({'success','topK miss','boundary hit'}, 'Location', 'best');
title(strrep(sprintf('%s bias robustness', tag), '_', '\_'));
out_path = fullfile(result_dir, 'search_bias_robustness.png');
saveas(fig, out_path);
close(fig);
end

function agg = aggregate_ctf_by_config_local(summary_table)
sub = summary_table(string_match_local(summary_table.search_method, 'coarse_to_fine'), :);
if isempty(sub)
    agg = sub;
    return;
end
config_fields = {'search_method','topK','coarse_az_step','coarse_el_step','fine_az_step','fine_el_step', ...
    'az_center_bias_deg','el_center_bias_deg','B','W_method'};
agg = unique(sub(:, config_fields), 'rows');
metric_fields = {'overall_joint_success_rate','overall_combined_rmse_mean','overall_mean_num_pairs', ...
    'overall_mean_reduction_ratio_vs_full','overall_full_grid_match_rate','overall_topK_miss_rate', ...
    'overall_boundary_hit_rate'};
for iField = 1:numel(metric_fields)
    agg.(metric_fields{iField}) = nan(height(agg), 1);
end
for idx = 1:height(agg)
    mask = true(height(sub), 1);
    for iField = 1:numel(config_fields)
        field = config_fields{iField};
        mask = mask & match_value_local(sub.(field), agg.(field)(idx));
    end
    rows = sub(mask, :);
    for iField = 1:numel(metric_fields)
        field = metric_fields{iField};
        agg.(field)(idx) = mean_omitnan_local(rows.(field));
    end
end
end

function agg = aggregate_by_method_local(summary_table)
methods = unique(cellstr_local(summary_table.search_method), 'stable');
template = struct();
template.search_method = '';
template.overall_joint_success_rate = NaN;
template.overall_combined_rmse_mean = NaN;
template.overall_mean_num_pairs = NaN;
template.overall_mean_reduction_ratio_vs_full = NaN;
template.overall_full_grid_match_rate = NaN;
template.overall_topK_miss_rate = NaN;
rows = repmat(template, numel(methods), 1);
for idx = 1:numel(methods)
    sub = summary_table(string_match_local(summary_table.search_method, methods{idx}), :);
    rows(idx).search_method = methods{idx};
    rows(idx).overall_joint_success_rate = mean_omitnan_local(sub.overall_joint_success_rate);
    rows(idx).overall_combined_rmse_mean = mean_omitnan_local(sub.overall_combined_rmse_mean);
    rows(idx).overall_mean_num_pairs = mean_omitnan_local(sub.overall_mean_num_pairs);
    rows(idx).overall_mean_reduction_ratio_vs_full = mean_omitnan_local(sub.overall_mean_reduction_ratio_vs_full);
    rows(idx).overall_full_grid_match_rate = mean_omitnan_local(sub.overall_full_grid_match_rate);
    rows(idx).overall_topK_miss_rate = mean_omitnan_local(sub.overall_topK_miss_rate);
end
agg = struct2table(rows);
end

function mask = match_value_local(values, target)
if iscell(values) || isstring(values) || ischar(target)
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

function values = cellstr_local(values_in)
if iscell(values_in)
    values = values_in;
elseif isstring(values_in)
    values = cellstr(values_in);
else
    values = cellstr(values_in);
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
