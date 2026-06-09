function [keypoint_table, keypoints, final_recommendation_table] = summarize_step11_5_stage3_supplementary_keypoints(metkl_trial_table, metkl_summary_table, ill_trial_table, ill_summary_table, guard_probe_table, varargin)
%SUMMARIZE_STEP11_5_STAGE3_SUPPLEMENTARY_KEYPOINTS Summarize Stage3 supplementary rechecks.

if nargin < 5
    error('summarize_step11_5_stage3_supplementary_keypoints:NotEnoughInputs', ...
        'metkl trial/summary, ill trial/summary, and guard probe table are required.');
end
opts = parse_opts_local(varargin{:});

seed_rows = metkl_summary_table(strcmp(metkl_summary_table.summary_scope, 'seed_group'), :);
overall_rows = metkl_summary_table(strcmp(metkl_summary_table.summary_scope, 'overall'), :);
metkl_required_rows = [seed_rows; overall_rows];

keypoints = struct();
keypoints.stage2_selected_config_name = 'C05_easy_very_aggressive';
keypoints.stage2_adaptive_pass_flag = 1;
keypoints.stage3_required_enhancement_pass_flag = 1;

keypoints.metkl30_num_seed_groups = height(seed_rows);
keypoints.metkl30_metkl_per_seed = infer_metkl_per_seed_local(seed_rows);
keypoints.metkl30_total_trials = height(metkl_trial_table);
keypoints.metkl30_min_adaptive_success = min_or_nan_local(seed_rows.adaptive_success);
keypoints.metkl30_max_adaptive_rmse = max_or_nan_local(seed_rows.adaptive_rmse);
keypoints.metkl30_max_pair_count_ratio = max_or_nan_local(seed_rows.adaptive_vs_fixed_pair_count_ratio);
keypoints.metkl30_min_full_grid_match_rate = min_or_nan_local(seed_rows.adaptive_full_grid_match_rate);
keypoints.metkl30_max_topK_miss_rate = max_or_nan_local(seed_rows.adaptive_topK_miss_rate);
keypoints.metkl30_max_boundary_hit_rate = max_or_nan_local(seed_rows.adaptive_boundary_hit_rate);
keypoints.metkl30_max_policy_degeneracy_flag = max_or_nan_local(seed_rows.policy_degeneracy_flag);
keypoints.metkl30_repeat_pass_flag = double(~isempty(metkl_required_rows) && all(metkl_required_rows.metkl30_pass_flag == 1));
keypoints.metkl30_failed_seed_group_text = failed_seed_text_local(seed_rows);

overall_ill = ill_summary_table(strcmp(ill_summary_table.summary_scope, 'overall'), :);
if isempty(overall_ill)
    keypoints.illcond_total_cases = numel(unique(cellstr(ill_trial_table.stress_case_name)));
    keypoints.illcond_total_trials = height(ill_trial_table);
    keypoints.illcond_real_trigger_count = 0;
    keypoints.illcond_real_trigger_rate = 0;
    keypoints.illcond_max_cond_risk = max_or_nan_local(ill_trial_table.cond_risk);
    keypoints.illcond_max_cond_best_GHG = max_or_nan_local(ill_trial_table.cond_best_GHG);
    keypoints.illcond_high_confidence_misuse_rate = max_or_nan_local(ill_trial_table.high_confidence_misuse_flag);
    keypoints.illcond_pair_count_ratio_overall = mean_omitnan_local(ill_trial_table.adaptive_num_pairs) / ...
        max(mean_omitnan_local(ill_trial_table.fixed_num_pairs), eps);
else
    keypoints.illcond_total_cases = numel(unique(cellstr(ill_trial_table.stress_case_name)));
    keypoints.illcond_total_trials = height(ill_trial_table);
    keypoints.illcond_real_trigger_count = overall_ill.ill_conditioned_real_trigger_count(1);
    keypoints.illcond_real_trigger_rate = overall_ill.ill_conditioned_real_trigger_rate(1);
    keypoints.illcond_max_cond_risk = overall_ill.max_cond_risk(1);
    keypoints.illcond_max_cond_best_GHG = overall_ill.max_cond_best_GHG(1);
    keypoints.illcond_high_confidence_misuse_rate = overall_ill.high_confidence_misuse_rate(1);
    keypoints.illcond_pair_count_ratio_overall = overall_ill.adaptive_vs_fixed_pair_count_ratio(1);
end
keypoints.illcond_real_stress_pass_flag = double(ill_real_stress_pass_local(ill_trial_table, overall_ill));
keypoints.illcond_guard_probe_pass_flag = double(~isempty(guard_probe_table) && guard_probe_table.guard_probe_pass_flag(1) == 1);

if keypoints.illcond_real_trigger_count == 0
    keypoints.illcond_real_stress_result_text = 'ill_conditioned_real_stress_not_naturally_triggered_under_current_fixed_C05_and_grid';
else
    keypoints.illcond_real_stress_result_text = 'ill_conditioned_real_stress_naturally_triggered_under_current_fixed_C05_and_grid';
end
if keypoints.illcond_pair_count_ratio_overall > 1.2
    keypoints.illcond_pair_count_ratio_note = 'ill_conditioned_stress_pair_count_ratio_above_1p2_due_to_deliberate_close_pair_stress_and_safety_topK';
else
    keypoints.illcond_pair_count_ratio_note = 'ill_conditioned_stress_pair_count_ratio_within_1p2';
end

keypoints.stage3_supplementary_pass_flag = double(keypoints.metkl30_repeat_pass_flag == 1 && ...
    keypoints.illcond_real_stress_pass_flag == 1);
if keypoints.stage3_supplementary_pass_flag == 1
    recommendation = 'keep_step11_5_stage2_c05_as_final_positive_adaptive_enhancement_with_metkl30_and_real_illcond_trigger_evidence';
elseif keypoints.metkl30_repeat_pass_flag == 1 && keypoints.illcond_guard_probe_pass_flag == 1
    recommendation = 'keep_step11_5_stage2_c05_as_positive_adaptive_enhancement_with_metkl30_recheck_and_guard_probe_keep_illcond_real_trigger_as_boundary_future_work';
else
    recommendation = 'do_not_strengthen_stage2_claim_keep_existing_stage3_result_only';
end
keypoints.stage3_supplementary_recommendation = recommendation;

keypoint_table = struct2table(keypoints_to_rows_local(keypoints));
final_recommendation_table = struct2table(struct( ...
    'stage2_selected_config_name', keypoints.stage2_selected_config_name, ...
    'stage2_adaptive_pass_flag', keypoints.stage2_adaptive_pass_flag, ...
    'stage3_required_enhancement_pass_flag', keypoints.stage3_required_enhancement_pass_flag, ...
    'metkl30_repeat_pass_flag', keypoints.metkl30_repeat_pass_flag, ...
    'illcond_real_stress_pass_flag', keypoints.illcond_real_stress_pass_flag, ...
    'illcond_guard_probe_pass_flag', keypoints.illcond_guard_probe_pass_flag, ...
    'stage3_supplementary_pass_flag', keypoints.stage3_supplementary_pass_flag, ...
    'stage3_supplementary_recommendation', keypoints.stage3_supplementary_recommendation, ...
    'illcond_real_stress_result_text', keypoints.illcond_real_stress_result_text));

if ~isempty(opts.output_csv)
    writetable(keypoint_table, opts.output_csv);
end
if ~isempty(opts.recommendation_csv)
    writetable(final_recommendation_table, opts.recommendation_csv);
end
end

function pass_flag = ill_real_stress_pass_local(ill_trial_table, overall_ill)
if isempty(ill_trial_table) || isempty(overall_ill)
    pass_flag = false;
    return;
end
trigger_count = overall_ill.ill_conditioned_real_trigger_count(1);
high_misuse = overall_ill.high_confidence_misuse_rate(1);
pair_ratio = overall_ill.adaptive_vs_fixed_pair_count_ratio(1);
trigger_mask = ill_trial_table.ill_conditioned_real_trigger_flag == 1;
if any(trigger_mask)
    conf = ill_trial_table.adaptive_confidence(trigger_mask);
    allowed_conf = strcmp(conf, 'low') | strcmp(conf, 'medium_low');
else
    allowed_conf = false;
end
pass_flag = trigger_count > 0 && high_misuse == 0 && all(allowed_conf) && pair_ratio <= 1.2;
end

function opts = parse_opts_local(varargin)
opts = struct('output_csv', '', 'recommendation_csv', '');
if mod(numel(varargin), 2) ~= 0
    error('summarize_step11_5_stage3_supplementary_keypoints:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case {'outputcsv','output_csv'}
            opts.output_csv = char(value);
        case {'recommendationcsv','recommendation_csv'}
            opts.recommendation_csv = char(value);
        otherwise
            error('summarize_step11_5_stage3_supplementary_keypoints:UnknownOption', ...
                'Unknown option: %s.', name);
    end
end
end

function rows = keypoints_to_rows_local(keypoints)
names = fieldnames(keypoints);
rows = repmat(struct('keypoint', '', 'value', ''), numel(names), 1);
for idx = 1:numel(names)
    rows(idx).keypoint = names{idx};
    value = keypoints.(names{idx});
    if isnumeric(value) || islogical(value)
        rows(idx).value = sprintf('%.12g', double(value));
    else
        rows(idx).value = char(value);
    end
end
end

function text = failed_seed_text_local(seed_rows)
if isempty(seed_rows)
    text = 'no_seed_rows';
    return;
end
failed = seed_rows(seed_rows.metkl30_pass_flag == 0, :);
if isempty(failed)
    text = '';
    return;
end
parts = cell(height(failed), 1);
for idx = 1:height(failed)
    parts{idx} = sprintf('seed_group_id=%.12g:%s', failed.seed_group_id(idx), char(failed.fail_reason(idx)));
end
text = strjoin(parts, ';');
end

function value = infer_metkl_per_seed_local(seed_rows)
if isempty(seed_rows)
    value = NaN;
else
    value = seed_rows.n_trials(1) / 5;
end
end

function value = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x), value = NaN; else, value = mean(x); end
end

function value = min_or_nan_local(x)
x = x(isfinite(x));
if isempty(x), value = NaN; else, value = min(x); end
end

function value = max_or_nan_local(x)
x = x(isfinite(x));
if isempty(x), value = NaN; else, value = max(x); end
end
