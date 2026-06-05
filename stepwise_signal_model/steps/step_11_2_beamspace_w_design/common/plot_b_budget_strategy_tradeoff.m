function plot_paths = plot_b_budget_strategy_tradeoff(summary_table, diagnostics_table, result_dir)
%PLOT_B_BUDGET_STRATEGY_TRADEOFF Generate Stage3 B-budget plots.

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
aggregate = unique(summary_table(:, {'method_name','method_type','B','overall_joint_success_rate', ...
    'overall_az_rmse_deg','overall_el_rmse_deg','worst_case_success','projection_loss','max_corr', ...
    'cond_WHW','mean_num_pairs'}), 'rows');
aggregate.combined_rmse_deg = hypot(aggregate.overall_az_rmse_deg, aggregate.overall_el_rmse_deg);

plot_paths = {};
plot_paths{end + 1} = plot_line_metric_local(aggregate, result_dir, 'overall_joint_success_rate', ...
    'overall joint success', 'b_budget_success_vs_B.png');
plot_paths{end + 1} = plot_line_metric_local(aggregate, result_dir, 'combined_rmse_deg', ...
    'combined RMSE (deg)', 'b_budget_rmse_vs_B.png');
plot_paths{end + 1} = plot_line_metric_local(aggregate, result_dir, 'worst_case_success', ...
    'worst-case success', 'b_budget_worst_case_vs_B.png');
plot_paths{end + 1} = plot_line_metric_local(diagnostics_table, result_dir, 'projection_loss', ...
    'projection loss', 'b_budget_projection_loss_vs_B.png');
plot_paths{end + 1} = plot_line_metric_local(diagnostics_table, result_dir, 'max_corr', ...
    'max manifold corr', 'b_budget_max_corr_vs_B.png');
plot_paths{end + 1} = plot_line_metric_local(diagnostics_table, result_dir, 'cond_WHW', ...
    'cond(W''W)', 'b_budget_cond_WHW_vs_B.png');
plot_paths{end + 1} = plot_scatter_local(aggregate, result_dir, 'projection_loss', ...
    'projection loss', 'b_budget_success_vs_projection_loss.png');
plot_paths{end + 1} = plot_scatter_local(aggregate, result_dir, 'max_corr', ...
    'max corr', 'b_budget_success_vs_max_corr.png');
plot_paths{end + 1} = plot_recommended_summary_local(aggregate, result_dir);
end

function out_path = plot_line_metric_local(T, result_dir, metric_name, y_label, file_name)
methods = unique(cellstr(T.method_name), 'stable');
fig = figure('Visible', 'off');
hold on;
for iMethod = 1:numel(methods)
    sub = T(strcmp(cellstr(T.method_name), methods{iMethod}), :);
    [B_vals, order] = sort(sub.B);
    vals = sub.(metric_name);
    plot(B_vals, vals(order), '-o', 'LineWidth', 1.3);
end
hold off;
grid on;
xlabel('B');
ylabel(y_label);
title(strrep(file_name, '_', '\_'));
legend(methods, 'Location', 'best');
out_path = fullfile(result_dir, file_name);
saveas(fig, out_path);
close(fig);
end

function out_path = plot_scatter_local(T, result_dir, metric_name, x_label, file_name)
fig = figure('Visible', 'off');
methods = unique(cellstr(T.method_name), 'stable');
markers = {'o','s','^','d','v','>'};
hold on;
for iMethod = 1:numel(methods)
    sub = T(strcmp(cellstr(T.method_name), methods{iMethod}), :);
    marker = markers{mod(iMethod - 1, numel(markers)) + 1};
    scatter(sub.(metric_name), sub.overall_joint_success_rate, 48, sub.B, marker, 'filled');
end
hold off;
grid on;
xlabel(x_label);
ylabel('overall joint success');
title(strrep(file_name, '_', '\_'));
legend(methods, 'Location', 'best');
colorbar;
out_path = fullfile(result_dir, file_name);
saveas(fig, out_path);
close(fig);
end

function out_path = plot_recommended_summary_local(aggregate, result_dir)
nonrandom = aggregate(~strcmp(cellstr(aggregate.method_type), 'random_pool_baseline'), :);
[~, best_idx] = max(nonrandom.overall_joint_success_rate + 0.25 * nonrandom.worst_case_success - ...
    0.05 * nonrandom.combined_rmse_deg);
best = nonrandom(best_idx, :);
best_success = max(nonrandom.overall_joint_success_rate);
best_rmse = min(nonrandom.combined_rmse_deg);
mask = nonrandom.overall_joint_success_rate >= 0.95 * best_success & ...
    nonrandom.combined_rmse_deg <= 1.05 * best_rmse;
if any(mask)
    candidates = nonrandom(mask, :);
else
    candidates = nonrandom;
end
[~, eng_idx] = sortrows([candidates.B, log10(max(candidates.cond_WHW, 1)), candidates.combined_rmse_deg]);
engineering = candidates(eng_idx(1), :);

fig = figure('Visible', 'off');
values = [engineering.B(1), best.B(1), engineering.overall_joint_success_rate(1), best.overall_joint_success_rate(1)];
bar(values);
grid on;
set(gca, 'XTickLabel', {'eng B','perf B','eng success','perf success'});
title(sprintf('Recommended B summary: eng=%s B%d, perf=%s B%d', ...
    char_value_local(engineering.method_name(1)), engineering.B(1), ...
    char_value_local(best.method_name(1)), best.B(1)));
out_path = fullfile(result_dir, 'b_budget_recommended_summary.png');
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

