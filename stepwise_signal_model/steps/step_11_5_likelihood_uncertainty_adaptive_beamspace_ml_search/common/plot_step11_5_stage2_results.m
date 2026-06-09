function plot_paths = plot_step11_5_stage2_results(trial_table, config_summary_table, policy_summary_table, bias_summary_table, keypoints, result_dir)
%PLOT_STEP11_5_STAGE2_RESULTS Generate Stage2 policy tuning PNG figures.

if nargin < 6
    error('plot_step11_5_stage2_results:NotEnoughInputs', ...
        'trial_table, config_summary_table, policy_summary_table, bias_summary_table, keypoints, and result_dir are required.');
end
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
plot_paths = {};

fig = figure('Visible', 'off');
bar(config_summary_table.config_id, [config_summary_table.calibration_fixed_mean_num_pairs, ...
    config_summary_table.calibration_adaptive_mean_num_pairs]);
xlabel('config id');
ylabel('mean candidate count');
title('Stage2 calibration candidate count by config');
legend({'fixed topK3','adaptive v2'}, 'Location', 'best');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage2_config_candidate_count.png');

fig = figure('Visible', 'off');
bar(config_summary_table.config_id, [config_summary_table.calibration_fixed_success, ...
    config_summary_table.calibration_adaptive_success, config_summary_table.validation_adaptive_success]);
xlabel('config id');
ylabel('success rate');
ylim([0, 1.05]);
title('Stage2 config success');
legend({'cal fixed','cal adaptive','val adaptive'}, 'Location', 'best');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage2_config_success.png');

fig = figure('Visible', 'off');
names = categorical(policy_summary_table.policy_name);
names = reordercats(names, cellstr(policy_summary_table.policy_name));
bar(names, policy_summary_table.policy_rate);
ylim([0, 1.05]);
ylabel('policy rate');
title('Stage2 selected policy distribution');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage2_policy_distribution.png');

fig = figure('Visible', 'off');
cats = categorical({'fixed topK3','Stage1 adaptive','Stage2 selected'});
cats = reordercats(cats, {'fixed topK3','Stage1 adaptive','Stage2 selected'});
bar(cats, [keypoints.fixed_topK3_mean_num_pairs, keypoints.stage1_adaptive_mean_num_pairs, ...
    keypoints.stage2_selected_adaptive_mean_num_pairs]);
ylabel('mean candidate count');
title('Fixed vs Stage1 vs Stage2 candidate counts');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage2_fixed_vs_stage1_vs_stage2_candidates.png');

fig = figure('Visible', 'off');
sid = keypoints.selected_config_id;
sub = trial_table(trial_table.config_id == sid & strcmp(trial_table.run_phase, 'config_scan'), :);
scatter(sub.gap_13, sub.H_norm, 32, sub.U_search, 'filled');
xlabel('gap\_13');
ylabel('H\_norm');
title('Stage2 uncertainty features');
cb = colorbar;
cb.Label.String = 'U_search';
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage2_uncertainty_features.png');

fig = figure('Visible', 'off');
if isempty(bias_summary_table)
    bar(categorical({'none'}), 0);
else
    x = 1:height(bias_summary_table);
    bar(x, [bias_summary_table.adaptive_success, bias_summary_table.adaptive_topK_miss_rate, ...
        bias_summary_table.adaptive_boundary_hit_rate]);
    xlabel('bias case');
    ylabel('rate');
    ylim([0, 1.05]);
    legend({'success','topK miss','boundary hit'}, 'Location', 'best');
end
title('Stage2 selected bias robustness');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage2_bias_robustness.png');
end

function path = save_png_local(fig, result_dir, file_name)
path = fullfile(result_dir, file_name);
try
    exportgraphics(fig, path, 'Resolution', 150);
catch
    saveas(fig, path);
end
close(fig);
end
