function [keypoint_table, keypoints] = summarize_step11_5_stage3_keypoints(alt_summary_table, repeat_summary_table, branch_summary_table, stage2_reference, varargin)
%SUMMARIZE_STEP11_5_STAGE3_KEYPOINTS Build Stage3 required enhancement keypoints.

if nargin < 4
    error('summarize_step11_5_stage3_keypoints:NotEnoughInputs', ...
        'alt_summary_table, repeat_summary_table, branch_summary_table, and stage2_reference are required.');
end
opts = parse_opts_local(varargin{:});

keypoints = stage2_reference;
keypoints.stage3_result_label = 'Step11.5 Stage3: required enhancement validation for Stage2 selected C05';
keypoints.stage3_fixed_config_name = 'C05_easy_very_aggressive';

alt_val = alt_summary_table(strcmp(alt_summary_table.summary_scope, 'split_scheme_split') & ...
    strcmp(alt_summary_table.split_name, 'validation'), :);
keypoints.alt_split_num_validation_schemes = height(alt_val);
keypoints.alt_split_min_adaptive_success = min_or_nan_local(alt_val.adaptive_success);
keypoints.alt_split_max_adaptive_rmse = max_or_nan_local(alt_val.adaptive_rmse);
keypoints.alt_split_max_pair_count_ratio = max_or_nan_local(alt_val.adaptive_vs_fixed_pair_count_ratio);
keypoints.alt_split_min_full_grid_match_rate = min_or_nan_local(alt_val.adaptive_full_grid_match_rate);
keypoints.alt_split_max_topK_miss_rate = max_or_nan_local(alt_val.adaptive_topK_miss_rate);
keypoints.alt_split_max_boundary_hit_rate = max_or_nan_local(alt_val.adaptive_boundary_hit_rate);
keypoints.alt_split_max_policy_degeneracy_flag = max_or_nan_local(alt_val.policy_degeneracy_flag);
keypoints.alt_split_recheck_pass_flag = double(~isempty(alt_val) && all(alt_val.stage3_pass_flag == 1));

repeat_seed = repeat_summary_table(strcmp(repeat_summary_table.summary_scope, 'seed_group_all'), :);
repeat_overall = repeat_summary_table(strcmp(repeat_summary_table.summary_scope, 'overall'), :);
keypoints.repeat_seed_num_seed_groups = height(repeat_seed);
keypoints.repeat_seed_metkl_per_seed = infer_repeat_metkl_local(repeat_seed);
keypoints.repeat_seed_min_adaptive_success = min_or_nan_local(repeat_seed.adaptive_success);
keypoints.repeat_seed_max_adaptive_rmse = max_or_nan_local(repeat_seed.adaptive_rmse);
keypoints.repeat_seed_max_pair_count_ratio = max_or_nan_local(repeat_seed.adaptive_vs_fixed_pair_count_ratio);
keypoints.repeat_seed_min_full_grid_match_rate = min_or_nan_local(repeat_seed.adaptive_full_grid_match_rate);
keypoints.repeat_seed_max_topK_miss_rate = max_or_nan_local(repeat_seed.adaptive_topK_miss_rate);
keypoints.repeat_seed_max_boundary_hit_rate = max_or_nan_local(repeat_seed.adaptive_boundary_hit_rate);
keypoints.repeat_seed_max_policy_degeneracy_flag = max_or_nan_local(repeat_seed.policy_degeneracy_flag);
keypoints.repeat_seed_metkl_recheck_pass_flag = double(~isempty(repeat_seed) && all(repeat_seed.stage3_pass_flag == 1) && ...
    ~isempty(repeat_overall) && repeat_overall.stage3_pass_flag(1) == 1);

branch_all = branch_summary_table(strcmp(branch_summary_table.summary_scope, 'all_targeted_branch_cases'), :);
if isempty(branch_all)
    keypoints.boundary_real_trigger_count = NaN;
    keypoints.ill_conditioned_real_trigger_count = NaN;
    keypoints.ill_conditioned_policy_probe_trigger_count = NaN;
    keypoints.targeted_branch_high_confidence_misuse_rate = NaN;
    keypoints.targeted_branch_recheck_pass_flag = 0;
else
    keypoints.boundary_real_trigger_count = branch_all.boundary_real_trigger_count(1);
    keypoints.ill_conditioned_real_trigger_count = branch_all.ill_conditioned_real_trigger_count(1);
    keypoints.ill_conditioned_policy_probe_trigger_count = branch_all.ill_conditioned_policy_probe_trigger_count(1);
    keypoints.targeted_branch_high_confidence_misuse_rate = branch_all.high_confidence_misuse_rate(1);
    keypoints.targeted_branch_recheck_pass_flag = branch_all.targeted_branch_pass_flag(1);
end

keypoints.stage3_required_enhancement_pass_flag = double(keypoints.alt_split_recheck_pass_flag == 1 && ...
    keypoints.repeat_seed_metkl_recheck_pass_flag == 1 && keypoints.targeted_branch_recheck_pass_flag == 1);
if keypoints.stage3_required_enhancement_pass_flag == 1
    keypoints.stage3_recommended_next_step = 'keep_step11_5_stage2_c05_as_positive_adaptive_enhancement_with_stage3_required_rechecks';
else
    keypoints.stage3_recommended_next_step = 'keep_stage2_positive_result_but_document_stage3_failed_or_limited_recheck';
end

keypoint_table = struct2table(keypoints_to_rows_local(keypoints));
if ~isempty(opts.output_csv)
    writetable(keypoint_table, opts.output_csv);
end
end

function opts = parse_opts_local(varargin)
opts = struct('output_csv', '');
if mod(numel(varargin), 2) ~= 0
    error('summarize_step11_5_stage3_keypoints:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case {'outputcsv','output_csv'}
            opts.output_csv = char(value);
        otherwise
            error('summarize_step11_5_stage3_keypoints:UnknownOption', ...
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

function value = infer_repeat_metkl_local(repeat_seed)
if isempty(repeat_seed) || ~ismember('n_trials', repeat_seed.Properties.VariableNames)
    value = NaN;
else
    value = repeat_seed.n_trials(1) / 5;
end
end

function value = min_or_nan_local(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = min(x);
end
end

function value = max_or_nan_local(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x);
end
end
