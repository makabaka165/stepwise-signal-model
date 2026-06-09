function [keypoint_table, keypoints] = summarize_step11_5_keypoints(trial_table, summary_table, policy_summary_table, bias_summary_table, varargin)
%SUMMARIZE_STEP11_5_KEYPOINTS Build Step11.5 pass/fail evidence.
%
% The main adaptive pass/fail decision is computed on the zero-bias Stage A
% representative trials. Bias robustness is summarized separately.

if nargin < 4
    error('summarize_step11_5_keypoints:NotEnoughInputs', ...
        'trial_table, summary_table, policy_summary_table, and bias_summary_table are required.');
end
opts = parse_opts_local(varargin{:});
zero_mask = abs(trial_table.az_center_bias_deg) < 1e-12 & abs(trial_table.el_center_bias_deg) < 1e-12;
if ~any(zero_mask)
    error('summarize_step11_5_keypoints:MissingZeroBias', ...
        'Step11.5 keypoints require zero-bias Stage A trials.');
end
T = trial_table(zero_mask, :);

keypoints = struct();
keypoints.full_fine_success = mean(T.full_success);
keypoints.fixed_topK3_success = mean(T.fixed_success);
keypoints.adaptive_success = mean(T.adaptive_success);
keypoints.full_fine_rmse = mean_omitnan_local(T.full_rmse);
keypoints.fixed_topK3_rmse = mean_omitnan_local(T.fixed_rmse);
keypoints.adaptive_rmse = mean_omitnan_local(T.adaptive_rmse);
keypoints.full_fine_mean_num_pairs = mean_omitnan_local(T.full_num_pairs);
keypoints.fixed_topK3_mean_num_pairs = mean_omitnan_local(T.fixed_num_pairs);
keypoints.adaptive_mean_num_pairs = mean_omitnan_local(T.adaptive_num_pairs);
keypoints.fixed_topK3_reduction_ratio = keypoints.full_fine_mean_num_pairs / max(keypoints.fixed_topK3_mean_num_pairs, eps);
keypoints.adaptive_reduction_ratio = keypoints.full_fine_mean_num_pairs / max(keypoints.adaptive_mean_num_pairs, eps);
keypoints.adaptive_vs_fixed_pair_count_ratio = keypoints.adaptive_mean_num_pairs / max(keypoints.fixed_topK3_mean_num_pairs, eps);
keypoints.adaptive_vs_fixed_reduction_gain = keypoints.adaptive_reduction_ratio / max(keypoints.fixed_topK3_reduction_ratio, eps);
keypoints.adaptive_full_grid_match_rate = mean(T.adaptive_full_grid_match);
keypoints.adaptive_topK_miss_rate = mean(T.adaptive_topK_miss);
keypoints.adaptive_boundary_hit_rate = mean(T.adaptive_boundary_hit);
keypoints.easy_policy_rate = policy_rate_local(policy_summary_table, 'EASY');
keypoints.normal_policy_rate = policy_rate_local(policy_summary_table, 'NORMAL');
keypoints.hard_policy_rate = policy_rate_local(policy_summary_table, 'HARD');
keypoints.unsafe_policy_rate = policy_rate_local(policy_summary_table, 'UNSAFE');
keypoints.low_confidence_rate = mean(strcmp(T.adaptive_confidence, 'low'));

if ~isempty(bias_summary_table)
    bias020_mask = abs(bias_summary_table.az_center_bias_deg) <= 0.20 + 1e-12 & ...
        abs(bias_summary_table.el_center_bias_deg) <= 0.20 + 1e-12;
    B020 = bias_summary_table(bias020_mask, :);
    keypoints.max_bias_adaptive_topK_miss_rate = max_or_nan_local(B020.adaptive_topK_miss_rate);
    keypoints.max_bias_adaptive_boundary_hit_rate = max_or_nan_local(B020.adaptive_boundary_hit_rate);
    keypoints.max_bias_adaptive_success_drop = max_or_nan_local(B020.adaptive_success_drop_vs_zero);
    keypoints.bias_robustness_pass_flag = keypoints.max_bias_adaptive_topK_miss_rate == 0 && ...
        keypoints.max_bias_adaptive_boundary_hit_rate == 0 && keypoints.max_bias_adaptive_success_drop <= 0.06 + 1e-12;
    if keypoints.bias_robustness_pass_flag
        keypoints.valid_bias_range_text = 'az_bias=[-0.20,0.20], el_bias=[-0.20,0.20]';
    else
        keypoints.valid_bias_range_text = 'bias_robustness_not_passed_under_required_0p20_range';
    end
else
    keypoints.max_bias_adaptive_topK_miss_rate = NaN;
    keypoints.max_bias_adaptive_boundary_hit_rate = NaN;
    keypoints.max_bias_adaptive_success_drop = NaN;
    keypoints.bias_robustness_pass_flag = 0;
    keypoints.valid_bias_range_text = 'bias_summary_missing';
end

criteria_1_to_5 = keypoints.adaptive_success >= keypoints.fixed_topK3_success - 1e-12 && ...
    keypoints.adaptive_rmse <= keypoints.fixed_topK3_rmse + 1e-12 && ...
    keypoints.adaptive_topK_miss_rate == 0 && ...
    keypoints.adaptive_boundary_hit_rate == 0 && ...
    keypoints.adaptive_full_grid_match_rate >= 0.98;
criterion_6 = keypoints.adaptive_mean_num_pairs <= 0.95 * keypoints.fixed_topK3_mean_num_pairs;
keypoints.adaptive_pass_flag = double(criteria_1_to_5 && criterion_6);
if keypoints.adaptive_pass_flag == 1
    keypoints.recommended_next_step = 'use_step11_5_adaptive_topk_window_as_thesis_enhancement';
elseif criteria_1_to_5
    keypoints.recommended_next_step = 'tune_policy_thresholds_for_more_complexity_reduction';
else
    keypoints.recommended_next_step = 'keep_fixed_topK3_or_add_safety_fallback';
end

keypoint_table = struct2table(keypoints_to_rows_local(keypoints));
if ~isempty(opts.output_csv)
    writetable(keypoint_table, opts.output_csv);
end
unused = summary_table; %#ok<NASGU>
end

function opts = parse_opts_local(varargin)
opts = struct('output_csv', '');
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('summarize_step11_5_keypoints:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case {'outputcsv','output_csv'}
            opts.output_csv = char(value);
        otherwise
            error('summarize_step11_5_keypoints:UnknownOption', 'Unknown option: %s.', name);
    end
end
end

function rate = policy_rate_local(policy_summary_table, policy_name)
mask = strcmp(policy_summary_table.policy_name, policy_name);
if any(mask)
    rate = policy_summary_table.policy_rate(find(mask, 1));
else
    rate = 0;
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

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function v = max_or_nan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = max(x);
end
end
