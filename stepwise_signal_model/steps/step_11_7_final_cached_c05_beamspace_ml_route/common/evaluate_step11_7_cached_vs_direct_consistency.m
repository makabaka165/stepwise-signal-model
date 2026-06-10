function [trial_table, summary_table] = evaluate_step11_7_cached_vs_direct_consistency(context, scenarios, params)
%EVALUATE_STEP11_7_CACHED_VS_DIRECT_CONSISTENCY Compare final cached and direct routes.

scenario_table = normalize_scenarios_local(scenarios);
rows = repmat(make_row_template_local(), numel(params.center_az_list) * height(scenario_table) * params.Metkl, 1);
row_idx = 0;
cached_opts = struct('use_cache', true, 'run_direct_reference', false, 'allow_cache_fallback', true, 'runtime_timing', true);
direct_opts = struct('runtime_timing', true);
for iCenter = 1:numel(params.center_az_list)
    for iScenario = 1:height(scenario_table)
        scenario = table_row_to_struct_local(scenario_table(iScenario, :));
        for trial_id = 1:params.Metkl
            [input, truth] = build_step11_7_frontend_like_input(context, scenario, params.center_az_list(iCenter), trial_id, ...
                'FrontendState', 'controlled_pair2d_candidate', 'CenterIndex', iCenter, 'ScenarioIndex', iScenario, 'L', params.L);
            cached_out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, cached_opts);
            direct_out = step11_7_direct_reference_c05_backend(input, context, direct_opts);
            row_idx = row_idx + 1;
            rows(row_idx) = make_row_local(params.center_az_list(iCenter), truth, scenario, trial_id, cached_out, direct_out, params);
        end
    end
end
trial_table = struct2table(rows(1:row_idx));
summary_table = build_summary_local(trial_table);
end

function row = make_row_template_local()
row = struct();
row.center_az = NaN;
row.actual_center_az = NaN;
row.selected_center_column = NaN;
row.scenario_name = '';
row.trial_id = NaN;
row.seed = NaN;
row.truth_az1 = NaN;
row.truth_az2 = NaN;
row.truth_el1 = NaN;
row.truth_el2 = NaN;
row.cached_status = '';
row.direct_status = '';
row.cached_success = false;
row.direct_success = false;
row.cached_rmse = NaN;
row.direct_rmse = NaN;
row.same_estimate_flag = false;
row.same_policy_flag = false;
row.same_score_flag = false;
row.az_diff_max = NaN;
row.el_diff_max = NaN;
row.score_diff_abs = NaN;
row.score_diff_rel = NaN;
row.cached_policy_name = '';
row.direct_policy_name = '';
row.cached_confidence = '';
row.direct_confidence = '';
row.cached_boundary_flag = '';
row.direct_boundary_flag = '';
row.cached_num_pairs = NaN;
row.direct_num_pairs = NaN;
row.cached_cache_miss_count = NaN;
row.cached_fallback_used = false;
row.cached_runtime_total_sec = NaN;
row.direct_runtime_total_sec = NaN;
row.pass_flag = false;
end

function row = make_row_local(center_az, truth, scenario, trial_id, cached_out, direct_out, params)
[az_diff, el_diff] = estimate_diff_local(cached_out, direct_out);
score_diff_abs = abs(cached_out.max_score - direct_out.max_score);
score_diff_rel = score_diff_abs / max(abs(direct_out.max_score), eps);
cached_metrics = eval_el_separation_pair_metrics(cached_out, truth.az_true, truth.el_true, ...
    [center_az - 1.7, center_az + 1.7], [params.el_center_nominal - 1.5, params.el_center_nominal + 1.5], ...
    params.az_tol_deg, params.el_tol_deg, params.el_sep_tol_deg);
direct_metrics = eval_el_separation_pair_metrics(direct_out, truth.az_true, truth.el_true, ...
    [center_az - 1.7, center_az + 1.7], [params.el_center_nominal - 1.5, params.el_center_nominal + 1.5], ...
    params.az_tol_deg, params.el_tol_deg, params.el_sep_tol_deg);
row = make_row_template_local();
row.center_az = center_az;
row.actual_center_az = truth.actual_center_az;
row.selected_center_column = truth.selected_center_column;
row.scenario_name = scenario.scenario_name;
row.trial_id = trial_id;
row.seed = truth.seed;
row.truth_az1 = truth.az_true(1);
row.truth_az2 = truth.az_true(2);
row.truth_el1 = truth.el_true(1);
row.truth_el2 = truth.el_true(2);
row.cached_status = cached_out.status;
row.direct_status = direct_out.status;
row.cached_success = logical(cached_metrics.joint_pair_tol_success);
row.direct_success = logical(direct_metrics.joint_pair_tol_success);
row.cached_rmse = hypot(cached_metrics.az_rmse_deg, cached_metrics.el_rmse_deg);
row.direct_rmse = hypot(direct_metrics.az_rmse_deg, direct_metrics.el_rmse_deg);
row.same_estimate_flag = az_diff <= 1e-10 && el_diff <= 1e-10;
row.same_policy_flag = strcmp(cached_out.policy_name, direct_out.policy_name);
row.same_score_flag = score_diff_rel <= 1e-8;
row.az_diff_max = az_diff;
row.el_diff_max = el_diff;
row.score_diff_abs = score_diff_abs;
row.score_diff_rel = score_diff_rel;
row.cached_policy_name = cached_out.policy_name;
row.direct_policy_name = direct_out.policy_name;
row.cached_confidence = cached_out.confidence;
row.direct_confidence = direct_out.confidence;
row.cached_boundary_flag = cached_out.boundary_flag;
row.direct_boundary_flag = direct_out.boundary_flag;
row.cached_num_pairs = cached_out.num_pairs_total;
row.direct_num_pairs = direct_out.num_pairs_total;
row.cached_cache_miss_count = cached_out.cache_miss_count;
row.cached_fallback_used = logical(cached_out.fallback_used);
row.cached_runtime_total_sec = cached_out.runtime_total_sec;
row.direct_runtime_total_sec = direct_out.runtime_total_sec;
row.pass_flag = strcmp(cached_out.status, direct_out.status) && row.same_estimate_flag && row.same_policy_flag && ...
    row.same_score_flag && row.cached_cache_miss_count == 0 && ~row.cached_fallback_used && ...
    row.cached_success == row.direct_success && strcmp(row.cached_boundary_flag, row.direct_boundary_flag) && ...
    strcmp(row.cached_confidence, row.direct_confidence);
end

function summary_table = build_summary_local(T)
summary = struct();
summary.stage_name = 'stage2_cached_direct_consistency';
summary.num_trials = height(T);
summary.same_estimate_rate = mean(double(T.same_estimate_flag));
summary.same_policy_rate = mean(double(T.same_policy_flag));
summary.same_score_rate = mean(double(T.same_score_flag));
summary.max_score_diff_rel = max(T.score_diff_rel);
summary.cache_miss_count = sum(T.cached_cache_miss_count);
summary.fallback_used_rate = mean(double(T.cached_fallback_used));
summary.success_match_rate = mean(double(T.cached_success == T.direct_success));
summary.boundary_flag_match_rate = mean(double(strcmp(T.cached_boundary_flag, T.direct_boundary_flag)));
summary.confidence_match_rate = mean(double(strcmp(T.cached_confidence, T.direct_confidence)));
summary.cached_direct_consistency_pass_flag = summary.same_estimate_rate == 1 && summary.same_policy_rate == 1 && ...
    (summary.same_score_rate == 1 || summary.max_score_diff_rel <= 1e-8) && summary.cache_miss_count == 0 && ...
    summary.fallback_used_rate == 0 && summary.success_match_rate == 1 && summary.boundary_flag_match_rate == 1 && ...
    summary.confidence_match_rate == 1;
summary_table = struct2table(summary);
end

function [az_diff, el_diff] = estimate_diff_local(a, b)
[az_a, el_a] = sorted_pair_local(a);
[az_b, el_b] = sorted_pair_local(b);
az_diff = max(abs(az_a - az_b));
el_diff = max(abs(el_a - el_b));
end

function [az_sorted, el_sorted] = sorted_pair_local(out)
az = out.az_hat(:).';
el = out.el_hat(:).';
[az_sorted, order] = sort(az);
el_sorted = el(order);
end

function T = normalize_scenarios_local(scenarios)
if istable(scenarios)
    T = scenarios;
else
    T = struct2table(scenarios);
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
