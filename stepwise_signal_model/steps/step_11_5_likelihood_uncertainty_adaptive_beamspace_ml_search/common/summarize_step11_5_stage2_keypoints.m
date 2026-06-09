function [keypoint_table, keypoints] = summarize_step11_5_stage2_keypoints(trial_table, config_summary_table, bias_summary_table, selected_recommendation, varargin)
%SUMMARIZE_STEP11_5_STAGE2_KEYPOINTS Build Stage2 policy tuning keypoints.

if nargin < 4
    error('summarize_step11_5_stage2_keypoints:NotEnoughInputs', ...
        'trial_table, config_summary_table, bias_summary_table, and selected_recommendation are required.');
end
opts = parse_opts_local(varargin{:});
sid = selected_recommendation.selected_config_id;
selected_trials = trial_table(trial_table.config_id == sid, :);
selected_zero = selected_trials(abs(selected_trials.az_center_bias_deg) < 1e-12 & abs(selected_trials.el_center_bias_deg) < 1e-12, :);
if isempty(selected_zero)
    selected_zero = selected_trials;
end
selected_cfg_row = config_summary_table(config_summary_table.config_id == sid, :);

stage1 = struct();
stage1.fixed_topK3_mean_num_pairs = 19126.26;
stage1.stage1_adaptive_mean_num_pairs = 38749.86;
stage1.adaptive_pass_flag = 0;
stage1.policy_text = 'EASY=0,NORMAL=0,HARD=1,UNSAFE=0';

keypoints = selected_recommendation;
keypoints.stage1_result_label = 'Step11.5 Stage1: original uncertainty policy negative result / safety passed but complexity failed';
keypoints.stage1_fixed_topK3_mean_num_pairs = stage1.fixed_topK3_mean_num_pairs;
keypoints.stage1_adaptive_mean_num_pairs = stage1.stage1_adaptive_mean_num_pairs;
keypoints.stage1_adaptive_pass_flag = stage1.adaptive_pass_flag;
keypoints.stage1_policy_distribution_text = stage1.policy_text;
keypoints.fixed_topK3_mean_num_pairs = mean_omitnan_local(selected_zero.fixed_num_pairs);
keypoints.stage2_selected_adaptive_mean_num_pairs = mean_omitnan_local(selected_zero.adaptive_num_pairs);
keypoints.stage2_selected_pair_count_ratio = keypoints.stage2_selected_adaptive_mean_num_pairs / max(keypoints.fixed_topK3_mean_num_pairs, eps);

if ~isempty(selected_cfg_row)
    keypoints.selected_config_overall_policy_degeneracy_flag = selected_cfg_row.policy_degeneracy_flag(1);
    keypoints.selected_config_max_policy_rate = selected_cfg_row.max_policy_rate(1);
end

if ~isempty(bias_summary_table)
    bias020 = bias_summary_table(abs(bias_summary_table.az_center_bias_deg) <= 0.20 + 1e-12 & ...
        abs(bias_summary_table.el_center_bias_deg) <= 0.20 + 1e-12, :);
    keypoints.max_bias_adaptive_topK_miss_rate = max_or_nan_local(bias020.adaptive_topK_miss_rate);
    keypoints.max_bias_adaptive_boundary_hit_rate = max_or_nan_local(bias020.adaptive_boundary_hit_rate);
    keypoints.max_bias_adaptive_success_drop = max_or_nan_local(bias020.adaptive_success_drop_vs_zero);
    keypoints.bias_robustness_pass_flag = double(keypoints.max_bias_adaptive_topK_miss_rate == 0 && ...
        keypoints.max_bias_adaptive_boundary_hit_rate == 0 && keypoints.max_bias_adaptive_success_drop <= 0.06 + 1e-12);
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

keypoint_table = struct2table(keypoints_to_rows_local(keypoints));
if ~isempty(opts.output_csv)
    writetable(keypoint_table, opts.output_csv);
end
end

function opts = parse_opts_local(varargin)
opts = struct('output_csv', '');
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('summarize_step11_5_stage2_keypoints:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case {'outputcsv','output_csv'}
            opts.output_csv = char(value);
        otherwise
            error('summarize_step11_5_stage2_keypoints:UnknownOption', 'Unknown option: %s.', name);
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
