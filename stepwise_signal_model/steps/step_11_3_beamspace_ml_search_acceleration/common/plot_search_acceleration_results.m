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
if contains(lower(tag), 'stage2') && ismember('config_name', summary_table.Properties.VariableNames)
    plot_paths = [plot_paths, plot_stage2_config_plots_local(summary_table, result_dir)];
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
    'local_az_half_width','local_el_center_half_width','az_center_bias_deg','el_center_bias_deg','B','W_method', ...
    'search_param_mode','full_el_sep_deg_list_text','coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text'};
agg = unique(sub(:, config_fields), 'rows');
metric_fields = {'overall_joint_success_rate','overall_combined_rmse_mean','overall_mean_num_pairs', ...
    'overall_mean_reduction_ratio_vs_full','overall_full_grid_match_rate','overall_topK_miss_rate', ...
    'overall_boundary_hit_rate','overall_el_sep_match_rate_vs_full'};
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

function plot_paths = plot_stage2_config_plots_local(summary_table, result_dir)
cfg = build_stage2_plot_config_table_local(summary_table);
plot_paths = {};
if isempty(cfg)
    return;
end
recommended_idx = choose_stage2_plot_recommendation_local(cfg);
plot_paths{end + 1} = plot_stage2_success_vs_reduction_local(cfg, recommended_idx, result_dir);
plot_paths{end + 1} = plot_stage2_topk_vs_success_local(cfg, result_dir);
plot_paths{end + 1} = plot_stage2_refine_window_vs_num_pairs_local(cfg, result_dir);
plot_paths{end + 1} = plot_stage2_rmse_vs_reduction_local(cfg, recommended_idx, result_dir);
plot_paths{end + 1} = plot_stage2_topk_miss_by_config_local(cfg, recommended_idx, result_dir);
plot_paths{end + 1} = plot_stage2_recommended_bar_local(cfg(recommended_idx, :), result_dir);
end

function cfg = build_stage2_plot_config_table_local(summary_table)
full_rows = summary_table(string_match_local(summary_table.search_method, 'full_fine'), :);
ctf_rows = summary_table(string_match_local(summary_table.search_method, 'coarse_to_fine'), :);
if isempty(full_rows) || isempty(ctf_rows)
    cfg = table();
    return;
end
names = unique(ctf_rows.config_name, 'stable');
rows = repmat(struct('config_name', '', 'topK', NaN, 'local_az_half_width', NaN, ...
    'local_el_center_half_width', NaN, 'full_success', NaN, 'success', NaN, 'full_rmse', NaN, ...
    'rmse', NaN, 'full_pairs', NaN, 'pairs', NaN, 'reduction', NaN, 'topK_miss', NaN, ...
    'boundary_hit', NaN, 'final_pass', false), numel(names), 1);
for idx = 1:numel(names)
    name = char_value_local(names(idx));
    ctf = ctf_rows(string_match_local(ctf_rows.config_name, name), :);
    full = full_rows(string_match_local(full_rows.config_name, name), :);
    if isempty(full)
        full = full_rows(1, :);
    end
    rows(idx).config_name = name;
    rows(idx).topK = ctf.topK(1);
    rows(idx).local_az_half_width = ctf.local_az_half_width(1);
    rows(idx).local_el_center_half_width = ctf.local_el_center_half_width(1);
    rows(idx).full_success = full.overall_joint_success_rate(1);
    rows(idx).success = ctf.overall_joint_success_rate(1);
    rows(idx).full_rmse = full.overall_combined_rmse_mean(1);
    rows(idx).rmse = ctf.overall_combined_rmse_mean(1);
    rows(idx).full_pairs = full.overall_mean_num_pairs(1);
    rows(idx).pairs = ctf.overall_mean_num_pairs(1);
    rows(idx).reduction = rows(idx).full_pairs / max(rows(idx).pairs, eps);
    rows(idx).topK_miss = ctf.overall_topK_miss_rate(1);
    rows(idx).boundary_hit = ctf.overall_boundary_hit_rate(1);
    rmse_ok = rows(idx).rmse <= 1.05 * max(rows(idx).full_rmse, eps) || rows(idx).rmse <= rows(idx).full_rmse + 0.02;
    rows(idx).final_pass = rows(idx).success >= 0.95 * rows(idx).full_success && rmse_ok && ...
        rows(idx).topK_miss <= 0.05 && rows(idx).boundary_hit <= 0.2 && rows(idx).reduction >= 2;
end
cfg = struct2table(rows);
end

function idx = choose_stage2_plot_recommendation_local(cfg)
pass_mask = logical(cfg.final_pass);
if any(pass_mask)
    candidates = cfg(pass_mask, :);
    [~, order] = sortrows([-candidates.reduction, candidates.rmse, candidates.topK_miss]);
    pass_indices = find(pass_mask);
    idx = pass_indices(order(1));
else
    [~, idx] = sortrows([-cfg.success, cfg.topK_miss, -cfg.reduction, cfg.rmse]);
    idx = idx(1);
end
end

function out_path = plot_stage2_success_vs_reduction_local(cfg, recommended_idx, result_dir)
fig = figure('Visible', 'off');
scatter(cfg.reduction, cfg.success, 60, double(cfg.topK), 'filled');
hold on;
scatter(cfg.reduction(recommended_idx), cfg.success(recommended_idx), 120, 'r', 'LineWidth', 1.5);
grid on;
colorbar;
xlabel('complexity reduction ratio');
ylabel('coarse-to-fine success');
title('Stage2 config success vs reduction');
out_path = fullfile(result_dir, 'stage2_config_success_vs_reduction.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_stage2_topk_vs_success_local(cfg, result_dir)
fig = figure('Visible', 'off');
topks = unique(cfg.topK);
vals = nan(numel(topks), 1);
for idx = 1:numel(topks)
    vals(idx) = mean_omitnan_local(cfg.success(abs(cfg.topK - topks(idx)) < 1e-12));
end
plot(topks, vals, '-o', 'LineWidth', 1.3);
grid on;
xlabel('topK');
ylabel('mean coarse-to-fine success');
title('Stage2 topK vs success');
out_path = fullfile(result_dir, 'stage2_topK_vs_success.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_stage2_refine_window_vs_num_pairs_local(cfg, result_dir)
fig = figure('Visible', 'off');
x = hypot(cfg.local_az_half_width, cfg.local_el_center_half_width);
scatter(x, cfg.pairs, 72, cfg.reduction, 'filled');
grid on;
colorbar;
xlabel('refine window norm (deg)');
ylabel('coarse-to-fine mean num pairs');
title('Stage2 refine window vs num pairs');
out_path = fullfile(result_dir, 'stage2_refine_window_vs_num_pairs.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_stage2_rmse_vs_reduction_local(cfg, recommended_idx, result_dir)
fig = figure('Visible', 'off');
scatter(cfg.reduction, cfg.rmse, 60, cfg.success, 'filled');
hold on;
scatter(cfg.reduction(recommended_idx), cfg.rmse(recommended_idx), 120, 'r', 'LineWidth', 1.5);
grid on;
colorbar;
xlabel('complexity reduction ratio');
ylabel('coarse-to-fine RMSE (deg)');
title('Stage2 RMSE vs reduction');
out_path = fullfile(result_dir, 'stage2_rmse_vs_reduction.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_stage2_topk_miss_by_config_local(cfg, recommended_idx, result_dir)
fig = figure('Visible', 'off');
[~, order] = sort(cfg.topK_miss, 'ascend');
vals = cfg.topK_miss(order);
bar(vals);
hold on;
hit = find(order == recommended_idx, 1);
if ~isempty(hit)
    scatter(hit, vals(hit), 100, 'r', 'filled');
end
grid on;
xlabel('config rank by topK miss');
ylabel('topK miss rate');
title('Stage2 topK miss rate by config');
out_path = fullfile(result_dir, 'stage2_topK_miss_rate_by_config.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_stage2_recommended_bar_local(row, result_dir)
fig = figure('Visible', 'off');
vals = [row.success, row.topK_miss, row.reduction, row.rmse];
bar(vals);
grid on;
set(gca, 'XTick', 1:4, 'XTickLabel', {'success','topK miss','reduction','RMSE'});
xtickangle(20);
title('Stage2 recommended config metrics');
out_path = fullfile(result_dir, 'stage2_recommended_config_bar.png');
saveas(fig, out_path);
close(fig);
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
