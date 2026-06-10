function [trial_table, summary_table] = evaluate_step11_6_runtime_benchmark(W, cfg, cache, scenarios, params, stage2_pass_flag)
%EVALUATE_STEP11_6_RUNTIME_BENCHMARK Benchmark direct precompute vs exact cache lookup.
%
% Runtime is measured with repeat trials and summarized by median/IQR.  The
% pass flag for total search runtime is reported but is not required for the
% Step11.6 overall pass condition.

if nargin < 6
    stage2_pass_flag = false;
end
scenario_table = normalize_scenarios_local(scenarios);
total_rows = numel(params.stage3_center_az_list) * height(scenario_table) * params.repeat_runtime;
rows = repmat(make_row_template_local(), total_rows, 1);
row_idx = 0;

for iCenter = 1:numel(params.stage3_center_az_list)
    geom = build_step11_6_canonical_geometry(cfg, params.stage3_center_az_list(iCenter));
    [grid_cfg_coarse, base_refine_cfg, full_grid_cfg] = make_search_configs_local(geom.actual_center_az_deg, params);
    manifold_direct = struct('phase_factor', params.phase_factor, 'phase_sign', params.phase_sign);
    manifold_cached = manifold_direct;
    manifold_cached.actual_center_az_deg = geom.actual_center_az_deg;
    search_opts = struct('whitening_mode', params.whitening_mode, 'reg', params.reg, 'cache_fallback_direct', true);
    el_values_coarse = collect_el_values_local(grid_cfg_coarse);

    for iScenario = 1:height(scenario_table)
        scenario = table_row_to_struct_local(scenario_table(iScenario, :));
        az_true = geom.actual_center_az_deg + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
        el_center_true = params.el_center_nominal + params.el_center_offset;
        for trial_id = 1:params.repeat_runtime
            [el_true, ~] = make_true_el_pair_local(el_center_true, scenario.el_sep_deg, trial_id, params);
            seed_now = params.base_seed + 700000 + 100000 * iCenter + 1000 * iScenario + trial_id;
            [Y, ~] = make_cyl_pair2d_correlated_snapshots(geom.x_actual, geom.y_actual, geom.z_actual, ...
                az_true, el_true, params.lambda, params.L, scenario.snr_db, ...
                'PhaseFactor', params.phase_factor, 'PhaseSign', params.phase_sign, ...
                'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
                'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
            Z = W' * Y;

            tic;
            precompute_beamspace_azel_grid(W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                grid_cfg_coarse.az_grid, el_values_coarse, params.lambda, ...
                'PhaseFactor', params.phase_factor, 'PhaseSign', params.phase_sign);
            direct_manifold_time_sec = toc;

            tic;
            [~, lookup_info] = lookup_step11_6_beamspace_cache(cache, grid_cfg_coarse.az_grid, el_values_coarse, ...
                'CenterAzDeg', geom.actual_center_az_deg, 'InputAzMode', 'global', 'ErrorOnMiss', false);
            cached_lookup_time_sec = toc;

            tic;
            [top_direct, coarse_direct] = search_pair2d_coarse_grid_topk(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, manifold_direct, search_opts, params.policy_cfg.topK_max);
            [est_direct, debug_direct] = search_pair2d_adaptive_topk_window_v2(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, base_refine_cfg, manifold_direct, search_opts, params.policy_cfg, top_direct, coarse_direct);
            direct_search_time_sec = toc;

            tic;
            [~, score_info_cached, coarse_cached0] = search_pair2d_degree_grid_cached(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, manifold_cached, search_opts, cache, 'ReturnTopK', true, 'TopK', params.policy_cfg.topK_max);
            coarse_cached = make_cached_coarse_debug_local(coarse_cached0, params.policy_cfg.topK_max);
            [est_cached, debug_cached] = search_pair2d_adaptive_c05_cached(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, base_refine_cfg, manifold_cached, search_opts, params.policy_cfg, cache, score_info_cached.top_candidates, coarse_cached);
            cached_search_time_sec = toc;

            [az_diff_max, el_diff_max] = estimate_diff_local(est_direct, est_cached);
            direct_score = extract_score_local(est_direct, debug_direct);
            cached_score = extract_score_local(est_cached, debug_cached);
            rel_score_diff = abs(direct_score - cached_score) / max(abs(direct_score), eps);

            row_idx = row_idx + 1;
            rows(row_idx) = make_row_local(geom, scenario, trial_id, direct_manifold_time_sec, cached_lookup_time_sec, ...
                direct_search_time_sec, cached_search_time_sec, cache.cache_build_once_time_sec, cache.cache_memory_MB, ...
                az_diff_max <= 1e-10 && el_diff_max <= 1e-10, rel_score_diff <= 1e-8, lookup_info.cache_miss_count + debug_cached.cache_miss_count);
        end
    end
end

trial_table = struct2table(rows(1:row_idx));
summary_table = build_summary_table_local(trial_table, logical(stage2_pass_flag));
end

function row = make_row_template_local()
row = struct();
row.center_az = NaN;
row.actual_center_az = NaN;
row.selected_center_column = NaN;
row.scenario_name = '';
row.trial_id = NaN;
row.method_name = 'c05_adaptive';
row.direct_manifold_time_sec = NaN;
row.cached_lookup_time_sec = NaN;
row.direct_search_time_sec = NaN;
row.cached_search_time_sec = NaN;
row.cache_build_once_time_sec = NaN;
row.cache_memory_MB = NaN;
row.manifold_time_reduction_ratio = NaN;
row.search_time_reduction_ratio = NaN;
row.same_estimate_flag = false;
row.same_score_flag = false;
row.cache_miss_count = NaN;
end

function row = make_row_local(geom, scenario, trial_id, direct_manifold_time_sec, cached_lookup_time_sec, ...
    direct_search_time_sec, cached_search_time_sec, cache_build_once_time_sec, cache_memory_MB, same_estimate_flag, same_score_flag, cache_miss_count)
row = make_row_template_local();
row.center_az = geom.requested_center_az_deg;
row.actual_center_az = geom.actual_center_az_deg;
row.selected_center_column = geom.selected_center_column;
row.scenario_name = scenario.scenario_name;
row.trial_id = trial_id;
row.direct_manifold_time_sec = direct_manifold_time_sec;
row.cached_lookup_time_sec = cached_lookup_time_sec;
row.direct_search_time_sec = direct_search_time_sec;
row.cached_search_time_sec = cached_search_time_sec;
row.cache_build_once_time_sec = cache_build_once_time_sec;
row.cache_memory_MB = cache_memory_MB;
row.manifold_time_reduction_ratio = 1 - cached_lookup_time_sec / max(direct_manifold_time_sec, eps);
row.search_time_reduction_ratio = 1 - cached_search_time_sec / max(direct_search_time_sec, eps);
row.same_estimate_flag = logical(same_estimate_flag);
row.same_score_flag = logical(same_score_flag);
row.cache_miss_count = cache_miss_count;
end

function summary_table = build_summary_table_local(T, stage2_pass_flag)
row = struct();
row.stage_name = 'stage3_runtime_benchmark';
row.num_trials = height(T);
row.cache_build_once_time_sec = median_omitnan_local(T.cache_build_once_time_sec);
row.cache_memory_MB = median_omitnan_local(T.cache_memory_MB);
row.median_direct_manifold_time_sec = median_omitnan_local(T.direct_manifold_time_sec);
row.median_cached_lookup_time_sec = median_omitnan_local(T.cached_lookup_time_sec);
row.median_direct_search_time_sec = median_omitnan_local(T.direct_search_time_sec);
row.median_cached_search_time_sec = median_omitnan_local(T.cached_search_time_sec);
row.median_manifold_time_reduction_ratio = median_omitnan_local(T.manifold_time_reduction_ratio);
row.iqr_manifold_time_reduction_ratio = iqr_omitnan_local(T.manifold_time_reduction_ratio);
row.median_search_time_reduction_ratio = median_omitnan_local(T.search_time_reduction_ratio);
row.iqr_search_time_reduction_ratio = iqr_omitnan_local(T.search_time_reduction_ratio);
row.same_estimate_rate = mean(double(T.same_estimate_flag));
row.same_score_rate = mean(double(T.same_score_flag));
row.cache_miss_count = sum(T.cache_miss_count);
row.runtime_manifold_pass_flag = row.median_manifold_time_reduction_ratio >= 0.50 && stage2_pass_flag;
row.runtime_search_pass_flag = row.median_search_time_reduction_ratio >= 0.05 && stage2_pass_flag;
if row.runtime_manifold_pass_flag && ~row.runtime_search_pass_flag
    row.runtime_note = 'cache clearly reduces manifold construction cost, while total MATLAB search runtime improvement is limited by scoring and overhead';
elseif row.runtime_search_pass_flag
    row.runtime_note = 'cache reduces both manifold construction and total MATLAB search runtime in this benchmark';
else
    row.runtime_note = 'runtime speedup did not meet the reporting threshold in this MATLAB benchmark';
end
summary_table = struct2table(row);
end

function el_values = collect_el_values_local(grid_cfg)
[~, ~, ~, el_info] = make_el_pair_list_degree_based(grid_cfg.el_center_grid, grid_cfg.el_sep_deg_list, ...
    grid_cfg.search_orientations, grid_cfg.el_bounds);
valid_rows = el_info.rows([el_info.rows.valid]);
el_values = unique(round([[valid_rows.el1], [valid_rows.el2]] * 1e10) / 1e10);
end

function [grid_cfg_coarse, base_refine_cfg, full_grid_cfg] = make_search_configs_local(center_az, params)
grid_cfg_coarse = build_pair2d_search_grids(center_az, params.el_center_nominal, params.coarse_search_cfg);
full_grid_cfg = build_pair2d_search_grids(center_az, params.el_center_nominal, params.full_search_cfg);
base_refine_cfg = params.base_refine_cfg;
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;
end

function coarse_debug = make_cached_coarse_debug_local(debug0, topK)
coarse_debug = struct();
coarse_debug.search_mode = 'coarse_degree_grid_topk_cached';
coarse_debug.whitening_mode = debug0.whitening_mode;
coarse_debug.num_pairs = debug0.num_pairs;
coarse_debug.topK_requested = topK;
coarse_debug.topK_returned = debug0.topK_returned;
coarse_debug.max_score = debug0.max_score;
coarse_debug.best_i_az1 = debug0.best_i_az1;
coarse_debug.best_i_az2 = debug0.best_i_az2;
coarse_debug.best_i_el_center = debug0.best_i_el_center;
coarse_debug.best_el_sep_deg = debug0.best_el_sep_deg;
coarse_debug.best_orientation = debug0.best_orientation;
coarse_debug.cond_best_GHG = debug0.cond_best_GHG;
coarse_debug.rank_best_G = debug0.rank_best_G;
coarse_debug.cond_WHW = debug0.cond_WHW;
coarse_debug.whitening_info = debug0.whitening_info;
coarse_debug.grid_cfg = debug0.grid_cfg;
coarse_debug.cache_miss_count = debug0.cache_miss_count;
coarse_debug.cached_lookup_time_sec = debug0.cached_lookup_time_sec;
coarse_debug.direct_fallback_used = debug0.direct_fallback_used;
end

function [az_diff_max, el_diff_max] = estimate_diff_local(a, b)
[az_a, el_a] = sorted_pair_local(a);
[az_b, el_b] = sorted_pair_local(b);
az_diff_max = max(abs(az_a - az_b));
el_diff_max = max(abs(el_a - el_b));
end

function [az_sorted, el_sorted] = sorted_pair_local(est)
az = est.az_hat(:).';
el = est.el_hat(:).';
[az_sorted, order] = sort(az);
el_sorted = el(order);
end

function score = extract_score_local(est, debug)
if isfield(est, 'score')
    score = est.score;
elseif isfield(est, 'max_score')
    score = est.max_score;
elseif isfield(debug, 'max_score')
    score = debug.max_score;
else
    score = NaN;
end
end

function [el_true, orientation] = make_true_el_pair_local(el_center_true, el_sep_deg, trial_id, params)
if el_sep_deg == 0
    el_true = [el_center_true, el_center_true];
    orientation = 0;
elseif params.alternate_true_orientation && mod(trial_id, 2) == 0
    el_true = el_center_true + [el_sep_deg / 2, -el_sep_deg / 2];
    orientation = -1;
else
    el_true = el_center_true + [-el_sep_deg / 2, el_sep_deg / 2];
    orientation = 1;
end
end

function scenario_table = normalize_scenarios_local(scenarios)
if istable(scenarios)
    scenario_table = scenarios;
elseif isstruct(scenarios)
    scenario_table = struct2table(scenarios);
else
    error('evaluate_step11_6_runtime_benchmark:InvalidScenarios', 'scenarios must be a table or struct array.');
end
end

function s = table_row_to_struct_local(row_table)
names = row_table.Properties.VariableNames;
s = struct();
for idx = 1:numel(names)
    value = row_table.(names{idx});
    if iscell(value)
        value = value{1};
    elseif isstring(value)
        value = char(value);
    end
    s.(names{idx}) = value;
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

function v = iqr_omitnan_local(x)
x = sort(x(isfinite(x)));
if numel(x) < 2
    v = NaN;
else
    v = percentile_local(x, 75) - percentile_local(x, 25);
end
end

function q = percentile_local(x, p)
x = sort(x(:));
if isempty(x)
    q = NaN;
    return;
end
pos = 1 + (numel(x) - 1) * p / 100;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    q = x(lo);
else
    q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
end
