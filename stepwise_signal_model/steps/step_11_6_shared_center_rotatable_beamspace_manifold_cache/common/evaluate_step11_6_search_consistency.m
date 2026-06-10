function [trial_table, summary_table] = evaluate_step11_6_search_consistency(W, cfg, cache, scenarios, params)
%EVALUATE_STEP11_6_SEARCH_CONSISTENCY Validate direct-vs-cached search equivalence.
%
% Truth is used only after both searches finish, for success/RMSE/boundary
% metrics.  Search centers, C05 policy decisions, topK, windows, and cache
% lookup never read target truth.

scenario_table = normalize_scenarios_local(scenarios);
methods = {'fixed_topK3','c05_adaptive'};
total_rows = numel(params.stage2_center_az_list) * height(scenario_table) * params.Metkl * numel(methods);
rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

for iCenter = 1:numel(params.stage2_center_az_list)
    geom = build_step11_6_canonical_geometry(cfg, params.stage2_center_az_list(iCenter));
    [grid_cfg_coarse, base_refine_cfg, full_grid_cfg] = make_search_configs_local(geom.actual_center_az_deg, params);
    manifold_direct = struct('phase_factor', params.phase_factor, 'phase_sign', params.phase_sign);
    manifold_cached = manifold_direct;
    manifold_cached.actual_center_az_deg = geom.actual_center_az_deg;
    search_opts = struct('whitening_mode', params.whitening_mode, 'reg', params.reg, 'cache_fallback_direct', true);

    for iScenario = 1:height(scenario_table)
        scenario = table_row_to_struct_local(scenario_table(iScenario, :));
        az_true = geom.actual_center_az_deg + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
        el_center_true = params.el_center_nominal + params.el_center_offset;

        for trial_id = 1:params.Metkl
            [el_true, true_orientation] = make_true_el_pair_local(el_center_true, scenario.el_sep_deg, trial_id, params);
            seed_now = params.base_seed + 100000 * iCenter + 1000 * iScenario + trial_id;
            [Y, truth] = make_cyl_pair2d_correlated_snapshots(geom.x_actual, geom.y_actual, geom.z_actual, ...
                az_true, el_true, params.lambda, params.L, scenario.snr_db, ...
                'PhaseFactor', params.phase_factor, 'PhaseSign', params.phase_sign, ...
                'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
                'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
            Z = W' * Y;

            [top_direct, coarse_direct] = search_pair2d_coarse_grid_topk(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, manifold_direct, search_opts, params.policy_cfg.topK_max);
            [~, score_info_cached, coarse_cached0] = search_pair2d_degree_grid_cached(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, manifold_cached, search_opts, cache, 'ReturnTopK', true, 'TopK', params.policy_cfg.topK_max);
            top_cached = score_info_cached.top_candidates;
            coarse_cached = make_cached_coarse_debug_local(coarse_cached0, params.policy_cfg.topK_max);

            [est_direct_fixed, debug_direct_fixed] = run_direct_fixed_topk3_local(Z, W, geom, params, top_direct, coarse_direct, ...
                base_refine_cfg, manifold_direct, search_opts);
            policy_fixed = params.policy_cfg;
            policy_fixed.force_fixed_topK3 = true;
            [est_cached_fixed, debug_cached_fixed] = search_pair2d_adaptive_c05_cached(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, base_refine_cfg, manifold_cached, search_opts, policy_fixed, cache, top_cached, coarse_cached);

            [est_direct_c05, debug_direct_c05] = search_pair2d_adaptive_topk_window_v2(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, base_refine_cfg, manifold_direct, search_opts, params.policy_cfg, top_direct, coarse_direct);
            [est_cached_c05, debug_cached_c05] = search_pair2d_adaptive_c05_cached(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
                params.lambda, grid_cfg_coarse, base_refine_cfg, manifold_cached, search_opts, params.policy_cfg, cache, top_cached, coarse_cached);

            row_idx = row_idx + 1;
            rows(row_idx) = make_trial_row_local(params.stage2_center_az_list(iCenter), geom, scenario, trial_id, seed_now, ...
                'fixed_topK3', truth, true_orientation, est_direct_fixed, debug_direct_fixed, est_cached_fixed, debug_cached_fixed, ...
                az_true, el_true, full_grid_cfg, params);

            row_idx = row_idx + 1;
            rows(row_idx) = make_trial_row_local(params.stage2_center_az_list(iCenter), geom, scenario, trial_id, seed_now, ...
                'c05_adaptive', truth, true_orientation, est_direct_c05, debug_direct_c05, est_cached_c05, debug_cached_c05, ...
                az_true, el_true, full_grid_cfg, params);
        end
    end
end

trial_table = struct2table(rows(1:row_idx));
summary_table = build_summary_table_local(trial_table);
end

function [grid_cfg_coarse, base_refine_cfg, full_grid_cfg] = make_search_configs_local(center_az, params)
grid_cfg_coarse = build_pair2d_search_grids(center_az, params.el_center_nominal, params.coarse_search_cfg);
full_grid_cfg = build_pair2d_search_grids(center_az, params.el_center_nominal, params.full_search_cfg);
base_refine_cfg = params.base_refine_cfg;
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;
end

function [est_fixed, debug_fixed] = run_direct_fixed_topk3_local(Z, W, geom, params, top_candidates, coarse_debug, refine_cfg, manifold_opts, search_opts)
selected = top_candidates(1:min(3, numel(top_candidates)));
[est_fixed, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, geom.x_actual, geom.y_actual, geom.z_actual, ...
    params.lambda, selected, refine_cfg, manifold_opts, search_opts);
est_fixed.max_score = refine_debug.max_score;
est_fixed.score = refine_debug.max_score;
debug_fixed = struct();
debug_fixed.search_mode = 'direct_fixed_topK3';
debug_fixed.policy = struct('policy_name', 'FIXED_TOPK3', 'config_name', 'fixed_topK3');
debug_fixed.num_pairs_coarse = coarse_debug.num_pairs;
debug_fixed.num_pairs_refine = refine_debug.num_pairs;
debug_fixed.num_pairs_total = coarse_debug.num_pairs + refine_debug.num_pairs;
debug_fixed.num_pairs = debug_fixed.num_pairs_total;
debug_fixed.max_score = refine_debug.max_score;
debug_fixed.cond_best_GHG = refine_debug.cond_best_GHG;
debug_fixed.rank_best_G = refine_debug.rank_best_G;
debug_fixed.topK_miss = false;
debug_fixed.cache_miss_count = 0;
debug_fixed.boundary_flag = '';
end

function row = make_trial_row_template_local()
row = struct();
row.center_az = NaN;
row.actual_center_az = NaN;
row.selected_center_column = NaN;
row.scenario_name = '';
row.trial_id = NaN;
row.seed = NaN;
row.method_name = '';
row.true_orientation = NaN;
row.source_corr_empirical = NaN;
row.direct_success = false;
row.cached_success = false;
row.direct_rmse = NaN;
row.cached_rmse = NaN;
row.direct_num_pairs = NaN;
row.cached_num_pairs = NaN;
row.same_estimate_flag = false;
row.same_score_flag = false;
row.max_abs_score_diff = NaN;
row.relative_score_diff = NaN;
row.az_diff_max = NaN;
row.el_diff_max = NaN;
row.direct_policy_name = '';
row.cached_policy_name = '';
row.same_policy_flag = false;
row.direct_topK_miss = false;
row.cached_topK_miss = false;
row.direct_boundary_hit = false;
row.cached_boundary_hit = false;
row.cache_miss_count = NaN;
row.direct_az_hat_1 = NaN;
row.direct_az_hat_2 = NaN;
row.cached_az_hat_1 = NaN;
row.cached_az_hat_2 = NaN;
row.direct_el_hat_1 = NaN;
row.direct_el_hat_2 = NaN;
row.cached_el_hat_1 = NaN;
row.cached_el_hat_2 = NaN;
row.az_true_1 = NaN;
row.az_true_2 = NaN;
row.el_true_1 = NaN;
row.el_true_2 = NaN;
row.direct_score = NaN;
row.cached_score = NaN;
row.pass_flag = false;
end

function row = make_trial_row_local(requested_center, geom, scenario, trial_id, seed_now, method_name, truth, true_orientation, ...
    est_direct, debug_direct, est_cached, debug_cached, az_true, el_true, full_grid_cfg, params)
direct_metrics = eval_el_separation_pair_metrics(est_direct, az_true, el_true, full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, ...
    params.az_tol_deg, params.el_tol_deg, params.el_sep_tol_deg);
cached_metrics = eval_el_separation_pair_metrics(est_cached, az_true, el_true, full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, ...
    params.az_tol_deg, params.el_tol_deg, params.el_sep_tol_deg);
[az_diff_max, el_diff_max] = estimate_diff_local(est_direct, est_cached);
direct_score = extract_score_local(est_direct, debug_direct);
cached_score = extract_score_local(est_cached, debug_cached);
score_diff = abs(direct_score - cached_score);
rel_score_diff = score_diff / max(abs(direct_score), eps);
direct_policy = policy_name_local(debug_direct);
cached_policy = policy_name_local(debug_cached);

row = make_trial_row_template_local();
row.center_az = requested_center;
row.actual_center_az = geom.actual_center_az_deg;
row.selected_center_column = geom.selected_center_column;
row.scenario_name = scenario.scenario_name;
row.trial_id = trial_id;
row.seed = seed_now;
row.method_name = method_name;
row.true_orientation = true_orientation;
row.source_corr_empirical = truth.source_corr_empirical;
row.direct_success = logical(direct_metrics.joint_pair_tol_success);
row.cached_success = logical(cached_metrics.joint_pair_tol_success);
row.direct_rmse = hypot(direct_metrics.az_rmse_deg, direct_metrics.el_rmse_deg);
row.cached_rmse = hypot(cached_metrics.az_rmse_deg, cached_metrics.el_rmse_deg);
row.direct_num_pairs = safe_field_local(debug_direct, 'num_pairs', NaN);
row.cached_num_pairs = safe_field_local(debug_cached, 'num_pairs', NaN);
row.same_estimate_flag = az_diff_max <= 1e-10 && el_diff_max <= 1e-10;
row.same_score_flag = rel_score_diff <= 1e-8;
row.max_abs_score_diff = score_diff;
row.relative_score_diff = rel_score_diff;
row.az_diff_max = az_diff_max;
row.el_diff_max = el_diff_max;
row.direct_policy_name = direct_policy;
row.cached_policy_name = cached_policy;
row.same_policy_flag = strcmp(direct_policy, cached_policy);
row.direct_topK_miss = logical(safe_field_local(debug_direct, 'topK_miss', false));
row.cached_topK_miss = logical(safe_field_local(debug_cached, 'topK_miss', false));
row.direct_boundary_hit = logical(direct_metrics.boundary_hit);
row.cached_boundary_hit = logical(cached_metrics.boundary_hit);
row.cache_miss_count = safe_field_local(debug_cached, 'cache_miss_count', 0);
row.direct_az_hat_1 = est_direct.az_hat(1);
row.direct_az_hat_2 = est_direct.az_hat(2);
row.cached_az_hat_1 = est_cached.az_hat(1);
row.cached_az_hat_2 = est_cached.az_hat(2);
row.direct_el_hat_1 = est_direct.el_hat(1);
row.direct_el_hat_2 = est_direct.el_hat(2);
row.cached_el_hat_1 = est_cached.el_hat(1);
row.cached_el_hat_2 = est_cached.el_hat(2);
row.az_true_1 = az_true(1);
row.az_true_2 = az_true(2);
row.el_true_1 = el_true(1);
row.el_true_2 = el_true(2);
row.direct_score = direct_score;
row.cached_score = cached_score;
row.pass_flag = row.same_estimate_flag && row.same_score_flag && row.same_policy_flag && ...
    row.direct_success == row.cached_success && row.direct_topK_miss == row.cached_topK_miss && ...
    row.direct_boundary_hit == row.cached_boundary_hit && row.cache_miss_count == 0;
end

function summary_table = build_summary_table_local(T)
row = struct();
row.stage_name = 'stage2_search_consistency';
row.num_trials = height(T);
row.num_tested_centers = numel(unique(T.actual_center_az));
row.same_estimate_rate = mean(double(T.same_estimate_flag));
row.same_policy_rate = mean(double(T.same_policy_flag));
row.same_score_rate = mean(double(T.same_score_flag));
row.max_relative_score_diff = max(T.relative_score_diff);
row.max_abs_score_diff = max(T.max_abs_score_diff);
row.cache_miss_count = sum(T.cache_miss_count);
row.max_cache_miss_count = max(T.cache_miss_count);
row.success_match_rate = mean(double(T.direct_success == T.cached_success));
row.topK_miss_match_rate = mean(double(T.direct_topK_miss == T.cached_topK_miss));
row.boundary_hit_match_rate = mean(double(T.direct_boundary_hit == T.cached_boundary_hit));
row.search_consistency_pass_flag = row.same_estimate_rate == 1 && row.same_policy_rate == 1 && ...
    row.max_relative_score_diff <= 1e-8 && row.cache_miss_count == 0 && ...
    row.success_match_rate == 1 && row.topK_miss_match_rate == 1 && row.boundary_hit_match_rate == 1;
summary_table = struct2table(row);
end

function coarse_debug = make_cached_coarse_debug_local(debug0, topK)
coarse_debug = struct();
coarse_debug.search_mode = 'coarse_degree_grid_topk_cached';
coarse_debug.whitening_mode = debug0.whitening_mode;
coarse_debug.num_pairs = debug0.num_pairs;
coarse_debug.topK_requested = topK;
coarse_debug.topK_returned = debug0.topK_returned;
coarse_debug.finite_slice_count = NaN;
coarse_debug.max_score = debug0.max_score;
coarse_debug.score_gap_top1_topK = NaN;
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

function name = policy_name_local(debug)
if isstruct(debug) && isfield(debug, 'policy') && isstruct(debug.policy) && isfield(debug.policy, 'policy_name')
    name = char(debug.policy.policy_name);
elseif isfield(debug, 'policy_name')
    name = char(debug.policy_name);
else
    name = 'UNKNOWN';
end
end

function scenario_table = normalize_scenarios_local(scenarios)
if istable(scenarios)
    scenario_table = scenarios;
elseif isstruct(scenarios)
    scenario_table = struct2table(scenarios);
else
    error('evaluate_step11_6_search_consistency:InvalidScenarios', 'scenarios must be a table or struct array.');
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

function value = safe_field_local(s, field, default_value)
if isstruct(s) && isfield(s, field)
    value = s.(field);
else
    value = default_value;
end
end
