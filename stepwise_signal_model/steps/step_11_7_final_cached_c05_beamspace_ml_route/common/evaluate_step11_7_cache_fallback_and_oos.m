function [trial_table, summary_table] = evaluate_step11_7_cache_fallback_and_oos(context)
%EVALUATE_STEP11_7_CACHE_FALLBACK_AND_OOS Validate cache miss and fallback behavior.

scenario = make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30);
[input, ~] = build_step11_7_frontend_like_input(context, scenario, 0, 1, 'FrontendState', 'controlled_pair2d_candidate', 'Seed', context.base_seed + 900);
case_names = {'valid_cache_exact_lookup','cache_missing_metadata','cache_grid_missing_one_delta','cache_grid_missing_one_el', ...
    'wrong_W_method','wrong_canonical_order_tag','allow_cache_fallback_false'};
expected_behavior = {'cache_hit_ok','fallback_recorded','fallback_recorded','fallback_recorded','reject_wrong_cache_and_fallback', ...
    'reject_wrong_cache_and_fallback','cache_miss_error_no_silent_direct'};
rows = repmat(make_row_template_local(), numel(case_names), 1);
for idx = 1:numel(case_names)
    ctx = context;
    opts = struct('use_cache', true, 'run_direct_reference', false, 'allow_cache_fallback', true, 'runtime_timing', true);
    switch case_names{idx}
        case 'cache_missing_metadata'
            ctx.cache_metadata = struct();
        case 'cache_grid_missing_one_delta'
            ctx.cache = remove_delta_zero_local(ctx.cache);
        case 'cache_grid_missing_one_el'
            ctx.cache = remove_one_el_local(ctx.cache, context.el_center_nominal);
        case 'wrong_W_method'
            ctx.cache.W_method = 'wrong_W_method';
            ctx.cache_metadata.W_method = 'wrong_W_method';
        case 'wrong_canonical_order_tag'
            ctx.cache.valid_center_rule = 'wrong_order_tag';
            ctx.cache_metadata.valid_center_rule = 'wrong_order_tag';
        case 'allow_cache_fallback_false'
            ctx.cache = remove_delta_zero_local(ctx.cache);
            opts.allow_cache_fallback = false;
    end
    out = step11_7_final_cached_c05_beamspace_ml_backend(input, ctx, opts);
    rows(idx) = make_row_local(case_names{idx}, expected_behavior{idx}, out);
end
trial_table = struct2table(rows);
summary = struct();
summary.stage_name = 'stage4_cache_fallback_and_oos';
summary.num_cases = height(trial_table);
summary.fallback_expected_case_pass_rate = mean(double(trial_table.pass_flag));
summary.cache_fallback_behavior_pass_flag = all(trial_table.pass_flag);
summary.high_confidence_misuse_count = sum(trial_table.high_confidence_misuse_flag);
summary_table = struct2table(summary);
end

function row = make_row_template_local()
row = struct();
row.case_name = '';
row.expected_behavior = '';
row.actual_behavior = '';
row.cache_miss_count = NaN;
row.fallback_used = false;
row.status = '';
row.error_message = '';
row.high_confidence_misuse_flag = false;
row.pass_flag = false;
end

function row = make_row_local(case_name, expected_behavior, out)
row = make_row_template_local();
row.case_name = case_name;
row.expected_behavior = expected_behavior;
row.cache_miss_count = out.cache_miss_count;
row.fallback_used = logical(out.fallback_used);
row.status = out.status;
row.error_message = out.error_message;
row.high_confidence_misuse_flag = ~strcmp(out.status, 'ok') && strcmp(out.confidence, 'high');
if strcmp(case_name, 'valid_cache_exact_lookup')
    row.actual_behavior = 'cache_hit_ok';
    row.pass_flag = strcmp(out.status, 'ok') && out.cache_miss_count == 0 && ~out.fallback_used;
elseif strcmp(case_name, 'allow_cache_fallback_false')
    row.actual_behavior = 'cache_miss_error_no_silent_direct';
    row.pass_flag = ~strcmp(out.status, 'ok') && ~out.fallback_used && out.cache_miss_count > 0 && ~row.high_confidence_misuse_flag;
else
    row.actual_behavior = 'fallback_recorded';
    row.pass_flag = strcmp(out.status, 'ok') && out.fallback_used && ~row.high_confidence_misuse_flag;
end
end

function cache = remove_delta_zero_local(cache)
[~, idx] = min(abs(cache.delta_az_grid_deg + 1.5));
cache.delta_az_grid_deg(idx) = [];
cache.G_grid(:, idx, :) = [];
cache.N_delta_az = numel(cache.delta_az_grid_deg);
end

function cache = remove_one_el_local(cache, el_target)
[~, idx] = min(abs(cache.el_grid_deg - el_target));
cache.el_grid_deg(idx) = [];
cache.G_grid(:, :, idx) = [];
cache.N_el = numel(cache.el_grid_deg);
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end
