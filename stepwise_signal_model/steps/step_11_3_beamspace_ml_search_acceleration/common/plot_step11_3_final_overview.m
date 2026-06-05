function plot_paths = plot_step11_3_final_overview(evidence, result_dir)
%PLOT_STEP11_3_FINAL_OVERVIEW Generate final Step11.3 overview figures.

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

plot_paths = cell(6, 1);
plot_paths{1} = plot_algorithm_flow_local(result_dir);
plot_paths{2} = plot_success_compare_local(evidence, result_dir);
plot_paths{3} = plot_rmse_compare_local(evidence, result_dir);
plot_paths{4} = plot_num_pairs_compare_local(evidence, result_dir);
plot_paths{5} = plot_reduction_ratio_local(evidence, result_dir);
plot_paths{6} = plot_bias_robustness_local(evidence, result_dir);
end

function out_path = plot_algorithm_flow_local(result_dir)
fig = figure('Visible', 'off', 'Position', [100, 100, 1100, 420]);
axis off;
steps = {'Frontend center', 'W=greedy\_combined\_B7', 'Coarse grid', 'topK=3', 'Local refine', 'ML output'};
x = linspace(0.08, 0.88, numel(steps));
y = 0.55 * ones(size(x));
for idx = 1:numel(steps)
    annotation('textbox', [x(idx), y(idx), 0.12, 0.16], 'String', steps{idx}, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 10, 'LineWidth', 1.2, 'BackgroundColor', [0.94, 0.97, 1.00]);
    if idx < numel(steps)
        annotation('arrow', [x(idx) + 0.12, x(idx + 1)], [y(idx) + 0.08, y(idx + 1) + 0.08], ...
            'LineWidth', 1.2);
    end
end
annotation('textbox', [0.12, 0.20, 0.76, 0.18], 'String', ...
    'Same controlled pair2d beamspace ML score; only candidate search is reduced.', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 11, 'LineStyle', 'none');
title('Step11.3 final algorithm flow');
out_path = fullfile(result_dir, 'final_step11_3_algorithm_flow.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_success_compare_local(evidence, result_dir)
vals = [key_num_local(evidence.stage2_keypoints, 'full_fine_success', NaN), ...
    key_num_local(evidence.stage2_keypoints, 'coarse_to_fine_success', NaN)];
fig = figure('Visible', 'off');
bar(vals);
grid on;
ylim([0, max(1.05, max(vals) * 1.1)]);
set(gca, 'XTick', 1:2, 'XTickLabel', {'full fine','coarse-to-fine'});
ylabel('success');
title('Final Step11.3 success compare');
out_path = fullfile(result_dir, 'final_step11_3_success_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_rmse_compare_local(evidence, result_dir)
vals = [key_num_local(evidence.stage2_keypoints, 'full_fine_rmse', NaN), ...
    key_num_local(evidence.stage2_keypoints, 'coarse_to_fine_rmse', NaN)];
fig = figure('Visible', 'off');
bar(vals);
grid on;
set(gca, 'XTick', 1:2, 'XTickLabel', {'full fine','coarse-to-fine'});
ylabel('combined RMSE (deg)');
title('Final Step11.3 RMSE compare');
out_path = fullfile(result_dir, 'final_step11_3_rmse_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_num_pairs_compare_local(evidence, result_dir)
vals = [key_num_local(evidence.stage2_keypoints, 'full_fine_mean_num_pairs', NaN), ...
    key_num_local(evidence.stage2_keypoints, 'coarse_to_fine_mean_num_pairs', NaN)];
fig = figure('Visible', 'off');
bar(vals);
grid on;
set(gca, 'XTick', 1:2, 'XTickLabel', {'full fine','coarse-to-fine'});
ylabel('mean candidate count');
title('Final Step11.3 candidate count compare');
out_path = fullfile(result_dir, 'final_step11_3_num_pairs_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_reduction_ratio_local(evidence, result_dir)
val = key_num_local(evidence.stage2_keypoints, 'complexity_reduction_ratio', NaN);
fig = figure('Visible', 'off');
bar(val);
grid on;
set(gca, 'XTick', 1, 'XTickLabel', {'coarse-to-fine'});
ylabel('reduction ratio');
title('Final Step11.3 complexity reduction ratio');
text(1, val, sprintf(' %.3fx', val), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
out_path = fullfile(result_dir, 'final_step11_3_reduction_ratio.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_bias_robustness_local(evidence, result_dir)
vals = [key_num_local(evidence.stage3_keypoints, 'zero_bias_success', NaN), ...
    key_num_local(evidence.stage3_keypoints, 'max_bias_success_drop', NaN), ...
    key_num_local(evidence.stage3_keypoints, 'max_bias_topK_miss_rate', NaN), ...
    key_num_local(evidence.stage3_keypoints, 'max_bias_boundary_hit_rate', NaN)];
fig = figure('Visible', 'off');
bar(vals);
grid on;
set(gca, 'XTick', 1:4, 'XTickLabel', {'zero success','max drop','topK miss','boundary hit'});
xtickangle(20);
ylabel('rate');
title('Final Step11.3 frontend-prior bias robustness');
out_path = fullfile(result_dir, 'final_step11_3_bias_robustness.png');
saveas(fig, out_path);
close(fig);
end

function value = key_num_local(T, key, fallback)
if isempty(T)
    value = fallback;
    return;
end
mask = strcmp(T.keypoint, string(key));
if ~any(mask)
    value = fallback;
    return;
end
value = str2double(T.value(find(mask, 1)));
if ~isfinite(value)
    value = fallback;
end
end
