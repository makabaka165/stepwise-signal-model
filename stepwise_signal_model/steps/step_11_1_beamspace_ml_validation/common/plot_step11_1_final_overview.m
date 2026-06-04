function plot_paths = plot_step11_1_final_overview(evidence, result_dir)
%PLOT_STEP11_1_FINAL_OVERVIEW Create Stage7 final overview figures.

if nargin ~= 2
    error('plot_step11_1_final_overview:InvalidInputCount', 'evidence and result_dir are required.');
end
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

plot_paths = {};
plot_paths{end + 1} = plot_stage_pass_flags_local(evidence, result_dir);
plot_paths{end + 1} = plot_algorithm_route_flowchart_local(result_dir);
plot_paths{end + 1} = plot_model_comparison_success_local(evidence, result_dir);
plot_paths{end + 1} = plot_complexity_comparison_local(evidence, result_dir);
plot_paths{end + 1} = plot_coherence_success_summary_local(evidence, result_dir);
plot_paths{end + 1} = plot_boundary_case_summary_local(evidence, result_dir);
end

function out_path = plot_stage_pass_flags_local(evidence, result_dir)
tbl = evidence.stage_status_table;
vals = tbl.pass_flag_value;
labels = short_stage_labels_local(height(tbl));
fig = figure('Visible', 'off');
bar(vals);
ylim([0, 1.1]);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('pass flag / decision value');
title('Step11.1 stage pass flags');
out_path = fullfile(result_dir, 'final_stage_pass_flags.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_algorithm_route_flowchart_local(result_dir)
fig = figure('Visible', 'off');
axis off;
boxes = { ...
    'coarse center', [0.08 0.65 0.18 0.16]; ...
    'work subarray', [0.30 0.65 0.18 0.16]; ...
    'W and Z=W''Y', [0.52 0.65 0.18 0.16]; ...
    'controlled pair2d DML', [0.74 0.65 0.20 0.16]; ...
    'common baseline', [0.30 0.28 0.18 0.14]; ...
    'full4d upper bound', [0.52 0.28 0.18 0.14]; ...
    'boundary notes', [0.74 0.28 0.20 0.14]};
for idx = 1:size(boxes, 1)
    annotation('textbox', boxes{idx, 2}, 'String', boxes{idx, 1}, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FitBoxToText', 'off');
end
annotation('arrow', [0.26 0.30], [0.73 0.73]);
annotation('arrow', [0.48 0.52], [0.73 0.73]);
annotation('arrow', [0.70 0.74], [0.73 0.73]);
annotation('arrow', [0.60 0.60], [0.65 0.42]);
annotation('arrow', [0.84 0.84], [0.65 0.42]);
title('Step11.1 final algorithm route');
out_path = fullfile(result_dir, 'final_algorithm_route_flowchart.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_model_comparison_success_local(evidence, result_dir)
common = get_metric_value_local(evidence, 'Stage6 full4d upper-bound comparison', 'best_common_joint_success');
pair = get_metric_value_local(evidence, 'Stage6 full4d upper-bound comparison', 'best_pair2d_joint_success');
full = get_metric_value_local(evidence, 'Stage6 full4d upper-bound comparison', 'best_full4d_joint_success');
fig = figure('Visible', 'off');
bar([common, pair, full]);
ylim([0, 1.1]);
set(gca, 'XTick', 1:3, 'XTickLabel', {'common', 'pair2d', 'full4d'});
grid on;
ylabel('joint success');
title('Final model comparison success');
out_path = fullfile(result_dir, 'final_model_comparison_success.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_complexity_comparison_local(evidence, result_dir)
pair_pairs = get_metric_value_local(evidence, 'Stage6 full4d upper-bound comparison', 'pair2d_runtime_proxy_num_pairs');
full_pairs = get_metric_value_local(evidence, 'Stage6 full4d upper-bound comparison', 'full4d_runtime_proxy_num_pairs');
fig = figure('Visible', 'off');
bar([pair_pairs, full_pairs]);
set(gca, 'XTick', 1:2, 'XTickLabel', {'pair2d', 'full4d'});
grid on;
ylabel('candidate count proxy');
title('Final complexity comparison');
out_path = fullfile(result_dir, 'final_complexity_comparison.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_coherence_success_summary_local(evidence, result_dir)
rho0 = get_metric_value_local(evidence, 'Stage5 coherence stress', 'pair2d_white_success_rho0');
rho09 = get_metric_value_local(evidence, 'Stage5 coherence stress', 'pair2d_white_success_rho09');
rho099 = get_metric_value_local(evidence, 'Stage5 coherence stress', 'pair2d_white_success_rho099');
rho1 = get_metric_value_local(evidence, 'Stage5 coherence stress', 'pair2d_white_success_rho1');
fig = figure('Visible', 'off');
bar([rho0, rho09, rho099, rho1]);
ylim([0, 1.1]);
set(gca, 'XTick', 1:4, 'XTickLabel', {'0', '0.9', '0.99', '1'});
grid on;
xlabel('rho');
ylabel('pair2d white success');
title('Final coherence success summary');
out_path = fullfile(result_dir, 'final_coherence_success_summary.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_boundary_case_summary_local(evidence, result_dir)
worst = get_metric_value_local(evidence, 'Stage5 coherence stress', 'worst_case_joint_success_pair2d_white');
false_high = get_metric_value_local(evidence, 'Stage5 coherence stress', 'max_false_high_like_rate');
boundary = get_metric_value_local(evidence, 'Stage5 coherence stress', 'max_boundary_hit_rate_pair2d_white');
false_split = get_metric_value_local(evidence, 'Stage5 coherence stress', 'max_false_el_split_rate_true_sep0_pair2d_white');
fig = figure('Visible', 'off');
bar([worst, false_high, boundary, false_split]);
set(gca, 'XTick', 1:4, 'XTickLabel', {'worst success', 'false-high', 'boundary', 'false split'});
xtickangle(20);
ylim([0, 1.1]);
grid on;
title('Final boundary case summary');
out_path = fullfile(result_dir, 'final_boundary_case_summary.png');
saveas(fig, out_path);
close(fig);
end

function labels = short_stage_labels_local(n)
labels = cell(1, n);
for idx = 1:n
    labels{idx} = sprintf('S%d', idx);
end
end

function value = get_metric_value_local(evidence, stage_name, metric)
tbl = evidence.final_key_metrics_table;
mask = strcmp(string(tbl.stage), string(stage_name)) & strcmp(string(tbl.metric), string(metric));
if any(mask)
    value = tbl.metric_value(find(mask, 1, 'first'));
else
    value = NaN;
end
end
