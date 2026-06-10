function [trial_table, summary_table] = evaluate_step11_7_interface_smoke(context)
%EVALUATE_STEP11_7_INTERFACE_SMOKE Validate Step11.7 backend I/O behavior.

scenario = make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30);
case_names = {'valid_single_local_cluster','valid_controlled_pair2d_candidate','invalid_Ywork_shape', ...
    'missing_frontend_state','two_separated_peaks_out_of_scope','weak_secondary_candidate','empty_detection'};
frontend_states = {'single_peak_in_scope','controlled_pair2d_candidate','controlled_pair2d_candidate', ...
    '', 'two_separated_peaks_out_of_scope','weak_secondary_candidate','empty_detection'};
expected_status = {'ok','ok','invalid_input','invalid_input','out_of_scope','out_of_scope','out_of_scope'};
rows = repmat(make_row_template_local(), numel(case_names), 1);
opts = struct('use_cache', true, 'run_direct_reference', false, 'allow_cache_fallback', true, 'runtime_timing', true);

for idx = 1:numel(case_names)
    [input, ~, meta] = build_step11_7_frontend_like_input(context, scenario, 0, idx, ...
        'FrontendState', frontend_states{idx}, 'Seed', context.base_seed + idx, 'L', context.L_default);
    if strcmp(case_names{idx}, 'invalid_Ywork_shape')
        input.Y_work = zeros(3, 4);
        meta.input_shape = '3x4';
    elseif strcmp(case_names{idx}, 'missing_frontend_state')
        input = rmfield(input, 'frontend_state');
    end
    out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, opts);
    rows(idx) = make_row_local(case_names{idx}, frontend_states{idx}, meta.input_shape, expected_status{idx}, out);
end

trial_table = struct2table(rows);
summary = struct();
summary.stage_name = 'stage1_interface_smoke';
summary.num_cases = height(trial_table);
summary.valid_cases_ok_rate = mean(double(trial_table.backend_ran_flag(strcmp(trial_table.expected_status, 'ok')) & strcmp(trial_table.actual_status(strcmp(trial_table.expected_status, 'ok')), 'ok')));
summary.invalid_oos_low_rate = mean(double(~strcmp(trial_table.expected_status, 'ok') & (strcmp(trial_table.actual_confidence, 'low') | strcmp(trial_table.actual_status, 'out_of_scope') | strcmp(trial_table.actual_status, 'invalid_input'))));
summary.output_fields_present_rate = mean(double(trial_table.output_fields_present_flag));
summary.high_confidence_oos_count = sum(~strcmp(trial_table.expected_status, 'ok') & is_high_confidence_local(trial_table.actual_confidence));
summary.interface_smoke_pass_flag = all(trial_table.pass_flag);
summary.final_backend_output_fields_pass_flag = all(trial_table.output_fields_present_flag);
summary_table = struct2table(summary);
end

function row = make_row_template_local()
row = struct();
row.case_name = '';
row.frontend_state = '';
row.input_shape = '';
row.expected_status = '';
row.actual_status = '';
row.expected_confidence_class = '';
row.actual_confidence = '';
row.backend_ran_flag = false;
row.error_message = '';
row.output_fields_present_flag = false;
row.pass_flag = false;
end

function row = make_row_local(case_name, frontend_state, input_shape, expected_status, out)
row = make_row_template_local();
row.case_name = case_name;
row.frontend_state = frontend_state;
row.input_shape = input_shape;
row.expected_status = expected_status;
row.actual_status = out.status;
if strcmp(expected_status, 'ok')
    row.expected_confidence_class = 'nonlow';
else
    row.expected_confidence_class = 'low_or_out_of_scope';
end
row.actual_confidence = out.confidence;
row.backend_ran_flag = isfield(out.debug, 'validation') && isfield(out.debug.validation, 'backend_ran_flag') && logical(out.debug.validation.backend_ran_flag);
row.error_message = out.error_message;
row.output_fields_present_flag = output_fields_present_local(out);
if strcmp(expected_status, 'ok')
    row.pass_flag = strcmp(out.status, 'ok') && row.backend_ran_flag && row.output_fields_present_flag;
else
    row.pass_flag = ~strcmp(out.status, 'ok') && ~is_high_confidence_local(out.confidence) && row.output_fields_present_flag;
end
end

function tf = output_fields_present_local(out)
required = {'status','route_name','method_name','used_cache','cache_miss_count','fallback_used','confidence','boundary_flag', ...
    'az_hat','el_hat','el_center_hat','el_sep_hat','orientation_hat','max_score','policy_name','adaptive_topK', ...
    'window_scale_az','window_scale_el','num_pairs_total','num_pairs_coarse','num_pairs_refine','runtime_total_sec', ...
    'runtime_cache_lookup_sec','runtime_search_sec','selectedCenterColumn','selectedCenterAz','input_shape','Z_shape','debug','error_message'};
tf = all(isfield(out, required));
end

function tf = is_high_confidence_local(confidence)
tf = strcmp(confidence, 'high');
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end
