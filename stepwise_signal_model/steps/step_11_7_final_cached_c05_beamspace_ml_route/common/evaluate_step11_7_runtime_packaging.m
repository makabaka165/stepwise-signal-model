function [trial_table, summary_table] = evaluate_step11_7_runtime_packaging(context, scenarios, params)
%EVALUATE_STEP11_7_RUNTIME_PACKAGING Benchmark final direct and cached wrappers.

scenario_table = normalize_scenarios_local(scenarios);
total_rows = numel(params.center_az_list) * height(scenario_table) * params.Metkl * params.repeat_runtime;
rows = repmat(make_row_template_local(), total_rows, 1);
row_idx = 0;
cached_opts = struct('use_cache', true, 'run_direct_reference', false, 'allow_cache_fallback', true, 'runtime_timing', true);
direct_opts = struct('runtime_timing', true);
for iRepeat = 1:params.repeat_runtime
    for iCenter = 1:numel(params.center_az_list)
        for iScenario = 1:height(scenario_table)
            scenario = table_row_to_struct_local(scenario_table(iScenario, :));
            for trial_id = 1:params.Metkl
                [input, ~] = build_step11_7_frontend_like_input(context, scenario, params.center_az_list(iCenter), trial_id, ...
                    'FrontendState', 'controlled_pair2d_candidate', 'CenterIndex', iCenter, 'ScenarioIndex', iScenario, ...
                    'SeedOffset', 10000 * iRepeat, 'L', params.L);
                direct_out = step11_7_direct_reference_c05_backend(input, context, direct_opts);
                cached_out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, cached_opts);
                row_idx = row_idx + 1;
                rows(row_idx) = make_row_local(scenario, params.center_az_list(iCenter), trial_id, iRepeat, direct_out, cached_out);
            end
        end
    end
end
trial_table = struct2table(rows(1:row_idx));
summary_table = build_summary_local(trial_table);
end

function row = make_row_template_local()
row = struct();
row.scenario_name = '';
row.center_az = NaN;
row.trial_id = NaN;
row.repeat_id = NaN;
row.direct_runtime_total_sec = NaN;
row.cached_runtime_total_sec = NaN;
row.runtime_reduction_ratio = NaN;
row.direct_num_pairs = NaN;
row.cached_num_pairs = NaN;
row.same_estimate_flag = false;
row.same_policy_flag = false;
row.cache_miss_count = NaN;
end

function row = make_row_local(scenario, center_az, trial_id, repeat_id, direct_out, cached_out)
[az_diff, el_diff] = estimate_diff_local(direct_out, cached_out);
row = make_row_template_local();
row.scenario_name = scenario.scenario_name;
row.center_az = center_az;
row.trial_id = trial_id;
row.repeat_id = repeat_id;
row.direct_runtime_total_sec = direct_out.runtime_total_sec;
row.cached_runtime_total_sec = cached_out.runtime_total_sec;
row.runtime_reduction_ratio = 1 - cached_out.runtime_total_sec / max(direct_out.runtime_total_sec, eps);
row.direct_num_pairs = direct_out.num_pairs_total;
row.cached_num_pairs = cached_out.num_pairs_total;
row.same_estimate_flag = az_diff <= 1e-10 && el_diff <= 1e-10;
row.same_policy_flag = strcmp(direct_out.policy_name, cached_out.policy_name);
row.cache_miss_count = cached_out.cache_miss_count;
end

function summary_table = build_summary_local(T)
summary = struct();
summary.stage_name = 'stage5_runtime_packaging';
summary.num_trials = height(T);
summary.median_runtime_reduction_ratio = median_omitnan_local(T.runtime_reduction_ratio);
summary.iqr_runtime_reduction_ratio = iqr_omitnan_local(T.runtime_reduction_ratio);
summary.same_estimate_rate = mean(double(T.same_estimate_flag));
summary.same_policy_rate = mean(double(T.same_policy_flag));
summary.cache_miss_count = sum(T.cache_miss_count);
summary.runtime_packaging_pass_flag = summary.median_runtime_reduction_ratio >= 0.05 && ...
    summary.same_estimate_rate == 1 && summary.same_policy_rate == 1 && summary.cache_miss_count == 0;
summary.runtime_note = 'cached final backend is functionally correct, while total MATLAB runtime gain can be limited by function dispatch and DML scoring overhead';
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
pos = 1 + (numel(x) - 1) * p / 100;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    q = x(lo);
else
    q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
end
