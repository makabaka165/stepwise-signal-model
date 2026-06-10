function [trial_table, summary_table] = evaluate_step11_7_frontend_prior_bias_recheck(context, scenarios, params)
%EVALUATE_STEP11_7_FRONTEND_PRIOR_BIAS_RECHECK Recheck final route under coarse-center bias.

scenario_table = normalize_scenarios_local(scenarios);
bias_cases = [0,0; 0.20,0; -0.20,0; 0,0.20; 0,-0.20; 0.20,0.20; -0.20,-0.20];
rows = repmat(make_row_template_local(), size(bias_cases, 1) * height(scenario_table) * params.Metkl, 1);
row_idx = 0;
opts = struct('use_cache', true, 'run_direct_reference', false, 'allow_cache_fallback', true, 'runtime_timing', true);
for iBias = 1:size(bias_cases, 1)
    for iScenario = 1:height(scenario_table)
        scenario = table_row_to_struct_local(scenario_table(iScenario, :));
        for trial_id = 1:params.Metkl
            [input, truth] = build_step11_7_frontend_like_input(context, scenario, params.center_az, trial_id, ...
                'FrontendState', 'controlled_pair2d_candidate', 'AzCenterBiasDeg', bias_cases(iBias, 1), ...
                'ElCenterBiasDeg', bias_cases(iBias, 2), 'ScenarioIndex', iScenario, 'CenterIndex', 1, 'L', params.L);
            out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, opts);
            row_idx = row_idx + 1;
            rows(row_idx) = make_row_local(iBias, bias_cases(iBias, :), scenario, trial_id, out, truth, params);
        end
    end
end
trial_table = struct2table(rows(1:row_idx));
summary_table = build_summary_local(trial_table);
end

function row = make_row_template_local()
row = struct();
row.bias_case_id = NaN;
row.az_center_bias_deg = NaN;
row.el_center_bias_deg = NaN;
row.scenario_name = '';
row.trial_id = NaN;
row.cached_status = '';
row.cached_success = false;
row.cached_rmse = NaN;
row.cached_num_pairs = NaN;
row.cached_policy_name = '';
row.cached_confidence = '';
row.cached_boundary_flag = '';
row.topK_miss = false;
row.boundary_hit = false;
row.cache_miss_count = NaN;
row.fallback_used = false;
row.high_confidence_misuse_flag = false;
end

function row = make_row_local(bias_case_id, bias_pair, scenario, trial_id, out, truth, params)
metrics = eval_el_separation_pair_metrics(out, truth.az_true, truth.el_true, ...
    [truth.actual_center_az - 1.8, truth.actual_center_az + 1.8], ...
    [params.el_center_nominal - 1.6, params.el_center_nominal + 1.6], ...
    params.az_tol_deg, params.el_tol_deg, params.el_sep_tol_deg);
row = make_row_template_local();
row.bias_case_id = bias_case_id;
row.az_center_bias_deg = bias_pair(1);
row.el_center_bias_deg = bias_pair(2);
row.scenario_name = scenario.scenario_name;
row.trial_id = trial_id;
row.cached_status = out.status;
row.cached_success = logical(metrics.joint_pair_tol_success);
row.cached_rmse = hypot(metrics.az_rmse_deg, metrics.el_rmse_deg);
row.cached_num_pairs = out.num_pairs_total;
row.cached_policy_name = out.policy_name;
row.cached_confidence = out.confidence;
row.cached_boundary_flag = out.boundary_flag;
row.topK_miss = false;
row.boundary_hit = logical(metrics.boundary_hit);
row.cache_miss_count = out.cache_miss_count;
row.fallback_used = logical(out.fallback_used);
row.high_confidence_misuse_flag = ~strcmp(out.status, 'ok') && strcmp(out.confidence, 'high');
end

function summary_table = build_summary_local(T)
zero_mask = abs(T.az_center_bias_deg) < 1e-12 & abs(T.el_center_bias_deg) < 1e-12;
zero_success = mean(double(T.cached_success(zero_mask)));
groups = unique(T(:, {'bias_case_id','az_center_bias_deg','el_center_bias_deg'}), 'rows');
max_success_drop = 0;
for idx = 1:height(groups)
    mask = T.bias_case_id == groups.bias_case_id(idx);
    success_now = mean(double(T.cached_success(mask)));
    max_success_drop = max(max_success_drop, max(0, zero_success - success_now));
end
summary = struct();
summary.stage_name = 'stage3_frontend_prior_bias_recheck';
summary.num_trials = height(T);
summary.num_bias_cases = height(groups);
summary.zero_bias_success_rate = zero_success;
summary.max_topK_miss_rate = max_group_rate_local(T, 'topK_miss');
summary.max_boundary_hit_rate = max_group_rate_local(T, 'boundary_hit');
summary.max_success_drop_vs_zero = max_success_drop;
summary.cache_miss_count = sum(T.cache_miss_count);
summary.fallback_used_rate = mean(double(T.fallback_used));
summary.high_confidence_misuse_count = sum(T.high_confidence_misuse_flag);
summary.frontend_prior_bias_recheck_pass_flag = summary.max_topK_miss_rate == 0 && summary.max_boundary_hit_rate == 0 && ...
    summary.max_success_drop_vs_zero <= 0.06 && summary.cache_miss_count == 0 && summary.high_confidence_misuse_count == 0;
summary.full_grid_match_note = 'bias cases require safety and success robustness; full-grid match is recorded only when a separate reference is run';
summary_table = struct2table(summary);
end

function rate = max_group_rate_local(T, field)
groups = unique(T.bias_case_id);
rate = 0;
for idx = 1:numel(groups)
    mask = T.bias_case_id == groups(idx);
    rate = max(rate, mean(double(T.(field)(mask))));
end
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
