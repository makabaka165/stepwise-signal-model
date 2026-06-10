function plot_paths = plot_step11_6_results(stage1_trial, stage2_trial, stage3_trial, stage4_trial, cache_metadata, result_dir)
%PLOT_STEP11_6_RESULTS Generate Step11.6 summary figures.

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
plot_paths = { ...
    fullfile(result_dir, 'step11_6_manifold_error_by_center.png'); ...
    fullfile(result_dir, 'step11_6_manifold_error_heatmap.png'); ...
    fullfile(result_dir, 'step11_6_search_consistency.png'); ...
    fullfile(result_dir, 'step11_6_runtime_direct_vs_cached.png'); ...
    fullfile(result_dir, 'step11_6_cache_memory_tradeoff.png'); ...
    fullfile(result_dir, 'step11_6_cross_center_reuse.png')};

plot_manifold_by_center_local(stage1_trial, plot_paths{1});
plot_manifold_heatmap_local(stage1_trial, plot_paths{2});
plot_search_consistency_local(stage2_trial, plot_paths{3});
plot_runtime_local(stage3_trial, plot_paths{4});
plot_memory_local(stage3_trial, cache_metadata, plot_paths{5});
plot_cross_center_local(stage4_trial, plot_paths{6});
end

function plot_manifold_by_center_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
centers = unique(T.actual_center_az).';
max_err = zeros(size(centers));
for idx = 1:numel(centers)
    max_err(idx) = max(T.rel_G_error(abs(T.actual_center_az - centers(idx)) < 1e-10));
end
semilogy(centers, max_err + eps, '-o', 'LineWidth', 1.5);
grid on;
xlabel('actual center az (deg)');
ylabel('max relative G error');
title('Stage1 manifold equivalence by center');
save_fig_local(fig, path);
end

function plot_manifold_heatmap_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
centers = unique(T.actual_center_az).';
deltas = unique(T.delta_az).';
M = nan(numel(centers), numel(deltas));
for i = 1:numel(centers)
    for j = 1:numel(deltas)
        mask = abs(T.actual_center_az - centers(i)) < 1e-10 & abs(T.delta_az - deltas(j)) < 1e-10;
        if any(mask)
            M(i, j) = max(T.rel_G_error(mask));
        end
    end
end
imagesc(deltas, centers, log10(M + eps));
set(gca, 'YDir', 'normal');
colorbar;
xlabel('delta az (deg)');
ylabel('actual center az (deg)');
title('log10 relative G error');
save_fig_local(fig, path);
end

function plot_search_consistency_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
vals = [mean(double(T.same_estimate_flag)), mean(double(T.same_policy_flag)), ...
    mean(double(T.same_score_flag)), mean(double(T.direct_success == T.cached_success)), ...
    mean(double(T.cache_miss_count == 0))];
bar(vals);
ylim([0, 1.05]);
set(gca, 'XTickLabel', {'estimate','policy','score','success','cache hit'});
ylabel('rate');
title('Stage2 direct vs cached consistency');
grid on;
save_fig_local(fig, path);
end

function plot_runtime_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
vals = [median_omitnan_local(T.direct_manifold_time_sec), median_omitnan_local(T.cached_lookup_time_sec); ...
    median_omitnan_local(T.direct_search_time_sec), median_omitnan_local(T.cached_search_time_sec)];
bar(vals);
set(gca, 'XTickLabel', {'manifold','full C05 search'});
legend({'direct','cached'}, 'Location', 'best');
ylabel('median time (s)');
title('Stage3 runtime benchmark');
grid on;
save_fig_local(fig, path);
end

function plot_memory_local(T, cache_metadata, path)
fig = figure('Visible', 'off', 'Color', 'w');
cache_mb = numeric_value_local(cache_metadata, 'cache_memory_MB', median_omitnan_local(T.cache_memory_MB));
build_sec = numeric_value_local(cache_metadata, 'cache_build_time_sec', median_omitnan_local(T.cache_build_once_time_sec));
yyaxis left;
bar(1, cache_mb);
ylabel('cache memory (MB)');
yyaxis right;
plot(1, build_sec, 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
ylabel('build once time (s)');
set(gca, 'XTick', 1, 'XTickLabel', {'canonical cache'});
title('Cache memory and build-time tradeoff');
grid on;
save_fig_local(fig, path);
end

function plot_cross_center_local(T, path)
fig = figure('Visible', 'off', 'Color', 'w');
centers = T.actual_center_az;
vals = double(T.manifold_equivalence_pass & T.search_consistency_pass & T.cache_miss_count == 0);
bar(centers, vals);
ylim([0, 1.05]);
xlabel('actual center az (deg)');
ylabel('center pass flag');
title('Stage4 cross-center cache reuse');
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

function value = numeric_value_local(T, field, fallback)
value = fallback;
if istable(T) && ismember(field, T.Properties.VariableNames) && height(T) >= 1
    value = T.(field)(1);
elseif isstruct(T) && isfield(T, field)
    value = T.(field);
end
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    value = fallback;
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
