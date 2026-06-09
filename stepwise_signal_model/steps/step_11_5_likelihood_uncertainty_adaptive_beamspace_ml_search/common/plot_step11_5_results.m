function plot_paths = plot_step11_5_results(trial_table, summary_table, policy_summary_table, result_dir)
%PLOT_STEP11_5_RESULTS Generate MATLAB-native PNG evidence figures.

if nargin < 4
    error('plot_step11_5_results:NotEnoughInputs', ...
        'trial_table, summary_table, policy_summary_table, and result_dir are required.');
end
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

plot_paths = {};
zero_mask = abs(trial_table.az_center_bias_deg) < 1e-12 & abs(trial_table.el_center_bias_deg) < 1e-12;
T0 = trial_table(zero_mask, :);
if isempty(T0)
    T0 = trial_table;
end

method_names = categorical({'full fine','fixed topK3','adaptive'});
method_names = reordercats(method_names, {'full fine','fixed topK3','adaptive'});

fig = figure('Visible', 'off');
bar(method_names, [mean(T0.full_num_pairs), mean(T0.fixed_num_pairs), mean(T0.adaptive_num_pairs)]);
ylabel('mean scored candidates');
title('Step11.5 candidate count comparison');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_candidate_count_comparison.png');

fig = figure('Visible', 'off');
bar(method_names, [mean_omitnan_local(T0.full_rmse), mean_omitnan_local(T0.fixed_rmse), mean_omitnan_local(T0.adaptive_rmse)]);
ylabel('combined RMSE (deg)');
title('Step11.5 RMSE comparison');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_rmse_comparison.png');

fig = figure('Visible', 'off');
bar(method_names, [mean(T0.full_success), mean(T0.fixed_success), mean(T0.adaptive_success)]);
ylim([0, 1.05]);
ylabel('success rate');
title('Step11.5 success comparison');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_success_comparison.png');

fig = figure('Visible', 'off');
if isempty(policy_summary_table)
    bar(categorical({'none'}), 0);
else
    names = categorical(policy_summary_table.policy_name);
    names = reordercats(names, cellstr(policy_summary_table.policy_name));
    bar(names, policy_summary_table.policy_rate);
end
ylim([0, 1.05]);
ylabel('policy rate');
title('Step11.5 adaptive policy distribution');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_policy_distribution.png');

fig = figure('Visible', 'off');
histogram(T0.adaptive_U, 'BinWidth', 0.05);
xlim([0, 1]);
xlabel('uncertainty U');
ylabel('trial count');
title('Step11.5 uncertainty histogram');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_uncertainty_U_histogram.png');

fig = figure('Visible', 'off');
scatter(T0.adaptive_U, T0.adaptive_num_pairs, 30, T0.adaptive_topK, 'filled');
xlabel('uncertainty U');
ylabel('adaptive scored candidates');
title('Step11.5 U vs adaptive candidate count');
cb = colorbar;
cb.Label.String = 'adaptive topK';
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_uncertainty_vs_candidate_count.png');

unused = summary_table; %#ok<NASGU>
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

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end
