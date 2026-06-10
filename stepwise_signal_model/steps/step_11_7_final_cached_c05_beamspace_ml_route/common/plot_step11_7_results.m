function plot_paths = plot_step11_7_results(stage1_trial, stage2_trial, stage3_trial, stage4_trial, stage5_trial, result_dir)
%PLOT_STEP11_7_RESULTS Generate final Step11.7 figures.

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
plot_paths = { ...
    fullfile(result_dir, 'step11_7_final_route_flowchart.png'); ...
    fullfile(result_dir, 'step11_7_cached_vs_direct_consistency.png'); ...
    fullfile(result_dir, 'step11_7_frontend_bias_safety.png'); ...
    fullfile(result_dir, 'step11_7_cache_fallback_behavior.png'); ...
    fullfile(result_dir, 'step11_7_runtime_direct_vs_cached.png'); ...
    fullfile(result_dir, 'step11_7_output_field_summary.png')};
plot_flowchart_local(plot_paths{1});
plot_consistency_local(stage2_trial, plot_paths{2});
plot_bias_local(stage3_trial, plot_paths{3});
plot_fallback_local(stage4_trial, plot_paths{4});
plot_runtime_local(stage5_trial, plot_paths{5});
plot_output_fields_local(stage1_trial, plot_paths{6});
end

function plot_flowchart_local(path)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1100, 360]);
axis off;
nodes = {'frontend-like Y_{work}', 'validate local state', 'W=greedy B7', 'canonical G cache', 'Z=W''Y', 'cached C05 ML', 'estimate + diagnostics'};
x = linspace(0.07, 0.93, numel(nodes));
for idx = 1:numel(nodes)
    annotation(fig, 'textbox', [x(idx)-0.055, 0.42, 0.11, 0.18], 'String', nodes{idx}, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FitBoxToText', 'off', ...
        'BackgroundColor', [0.94, 0.97, 1.00], 'EdgeColor', [0.2, 0.35, 0.55]);
    if idx < numel(nodes)
        annotation(fig, 'arrow', [x(idx)+0.055, x(idx+1)-0.055], [0.51, 0.51]);
    end
end
title('Step11.7 Final Cached C05 Beamspace ML Route');
save_fig_local(fig, path);
end

function plot_consistency_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
vals = [mean(double(T.same_estimate_flag)), mean(double(T.same_policy_flag)), mean(double(T.same_score_flag)), ...
    mean(double(strcmp(T.cached_confidence, T.direct_confidence))), mean(double(T.cached_cache_miss_count == 0))];
bar(vals);
ylim([0, 1.05]);
set(gca, 'XTickLabel', {'estimate','policy','score','confidence','cache hit'});
ylabel('rate');
title('Cached vs direct final backend consistency');
grid on;
save_fig_local(fig, path);
end

function plot_bias_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
groups = unique(T.bias_case_id).';
success = zeros(size(groups));
boundary = zeros(size(groups));
for idx = 1:numel(groups)
    mask = T.bias_case_id == groups(idx);
    success(idx) = mean(double(T.cached_success(mask)));
    boundary(idx) = mean(double(T.boundary_hit(mask)));
end
bar(groups, [success(:), boundary(:)]);
legend({'success','boundary hit'}, 'Location', 'best');
xlabel('bias case id');
ylabel('rate');
title('Frontend prior bias safety');
grid on;
save_fig_local(fig, path);
end

function plot_fallback_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
bar(categorical(T.case_name), [double(T.pass_flag), double(T.fallback_used)]);
ylabel('flag');
legend({'case pass','fallback used'}, 'Location', 'best');
title('Cache fallback behavior');
grid on;
save_fig_local(fig, path);
end

function plot_runtime_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
bar([median_omitnan_local(T.direct_runtime_total_sec), median_omitnan_local(T.cached_runtime_total_sec)]);
set(gca, 'XTickLabel', {'direct','cached'});
ylabel('median runtime (s)');
title('Final backend runtime');
grid on;
save_fig_local(fig, path);
end

function plot_output_fields_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
vals = [mean(double(T.output_fields_present_flag)), mean(double(T.pass_flag)), mean(double(~strcmp(T.actual_confidence, 'high') | strcmp(T.expected_status, 'ok')))];
bar(vals);
ylim([0, 1.05]);
set(gca, 'XTickLabel', {'fields','case pass','no high-conf misuse'});
ylabel('rate');
title('Output field and interface smoke summary');
grid on;
save_fig_local(fig, path);
end

function save_fig_local(fig, path)
try
    exportgraphics(fig, path, 'Resolution', 150);
catch
    saveas(fig, path);
end
close(fig);
end

function v = median_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = median(x);
end
end
