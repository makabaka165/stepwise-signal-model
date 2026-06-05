function [keypoint_rows, keypoints] = summarize_search_acceleration_keypoints(summary_table, stage_name)
%SUMMARIZE_SEARCH_ACCELERATION_KEYPOINTS Build compact evidence keypoints.

if nargin < 2
    stage_name = 'stage';
end
if isempty(summary_table)
    error('summarize_search_acceleration_keypoints:EmptySummary', 'summary_table is empty.');
end
stage_name = lower(char(stage_name));

switch stage_name
    case {'stage3','frontend_prior_bias_robustness'}
        keypoints = summarize_stage3_local(summary_table);
    otherwise
        keypoints = summarize_stage12_local(summary_table);
end
keypoint_rows = keypoints_to_rows_local(keypoints);
end

function keypoints = summarize_stage12_local(summary_table)
full = aggregate_for_method_local(summary_table, 'full_fine');
coarse_only = aggregate_for_method_local(summary_table, 'coarse_only');
ctf_all = aggregate_for_method_local(summary_table, 'coarse_to_fine');

full_success = full.overall_joint_success_rate(1);
full_rmse = full.overall_combined_rmse_mean(1);
if isempty(coarse_only)
    coarse_only_success = NaN;
else
    coarse_only_success = coarse_only.overall_joint_success_rate(1);
end

recommended = choose_recommended_ctf_local(ctf_all, full_success, full_rmse);
if isempty(recommended)
    [~, idx] = min(ctf_all.overall_mean_num_pairs);
    recommended = ctf_all(idx, :);
    pass_flag = false;
else
    pass_flag = true;
end

keypoints = struct();
keypoints.full_fine_success = full_success;
keypoints.coarse_only_success = coarse_only_success;
keypoints.coarse_to_fine_success = recommended.overall_joint_success_rate(1);
keypoints.full_fine_rmse = full_rmse;
keypoints.coarse_to_fine_rmse = recommended.overall_combined_rmse_mean(1);
keypoints.full_fine_worst_case_success = full.worst_case_success(1);
keypoints.coarse_to_fine_worst_case_success = recommended.worst_case_success(1);
keypoints.coarse_to_fine_mean_num_pairs = recommended.overall_mean_num_pairs(1);
keypoints.full_fine_mean_num_pairs = full.overall_mean_num_pairs(1);
keypoints.complexity_reduction_ratio = full.overall_mean_num_pairs(1) / max(recommended.overall_mean_num_pairs(1), eps);
keypoints.full_grid_match_rate = recommended.overall_full_grid_match_rate(1);
keypoints.topK_miss_rate = recommended.overall_topK_miss_rate(1);
keypoints.recommended_topK = recommended.topK(1);
keypoints.recommended_coarse_az_step = recommended.coarse_az_step(1);
keypoints.recommended_coarse_el_step = recommended.coarse_el_step(1);
keypoints.recommended_fine_az_step = recommended.fine_az_step(1);
keypoints.recommended_fine_el_step = recommended.fine_el_step(1);
keypoints.search_acceleration_pass_flag = pass_flag && ...
    keypoints.coarse_to_fine_success >= 0.95 * keypoints.full_fine_success && ...
    keypoints.coarse_to_fine_rmse <= 1.05 * max(keypoints.full_fine_rmse, eps) && ...
    keypoints.topK_miss_rate <= 0.05 && ...
    keypoints.complexity_reduction_ratio >= 3;
if keypoints.search_acceleration_pass_flag
    keypoints.recommended_next_step = 'proceed_to_search_acceleration_final_summary';
else
    keypoints.recommended_next_step = 'tune_topK_or_refine_window';
end
end

function keypoints = summarize_stage3_local(summary_table)
ctf = aggregate_for_method_local(summary_table, 'coarse_to_fine');
if isempty(ctf)
    error('summarize_search_acceleration_keypoints:MissingCTF', 'Stage3 summary requires coarse_to_fine rows.');
end
zero_mask = abs(ctf.az_center_bias_deg) < 1e-12 & abs(ctf.el_center_bias_deg) < 1e-12;
if ~any(zero_mask)
    error('summarize_search_acceleration_keypoints:MissingZeroBias', 'Stage3 summary requires a zero-bias case.');
end
zero = ctf(find(zero_mask, 1), :);
zero_success = zero.overall_joint_success_rate(1);
success_drop = zero_success - ctf.overall_joint_success_rate;
max_drop = max(success_drop);
max_topk_miss = max(ctf.overall_topK_miss_rate);
max_boundary = max(ctf.overall_boundary_hit_rate);
pass_mask = ctf.overall_joint_success_rate >= 0.9 * zero_success & ...
    ctf.overall_topK_miss_rate <= 0.1 & ...
    ctf.overall_boundary_hit_rate <= 0.2;
valid_bias = ctf(pass_mask, :);
if isempty(valid_bias)
    valid_text = 'no_bias_case_passed_thresholds';
else
    valid_text = sprintf('az_bias=[%.2f,%.2f], el_bias=[%.2f,%.2f]', ...
        min(valid_bias.az_center_bias_deg), max(valid_bias.az_center_bias_deg), ...
        min(valid_bias.el_center_bias_deg), max(valid_bias.el_center_bias_deg));
end

keypoints = struct();
keypoints.zero_bias_success = zero_success;
keypoints.max_bias_success_drop = max_drop;
keypoints.max_bias_topK_miss_rate = max_topk_miss;
keypoints.max_bias_boundary_hit_rate = max_boundary;
keypoints.valid_bias_range_text = valid_text;
keypoints.frontend_prior_robustness_pass_flag = all(pass_mask);
if keypoints.frontend_prior_robustness_pass_flag
    keypoints.recommended_next_step = 'proceed_to_final_search_acceleration_evidence_summary';
else
    keypoints.recommended_next_step = 'increase_search_window_or_topK_for_frontend_bias';
end
end

function aggregate = aggregate_for_method_local(summary_table, method_name)
mask = string_match_local(summary_table.search_method, method_name);
sub = summary_table(mask, :);
if isempty(sub)
    aggregate = sub;
    return;
end
config_fields = {'search_method','topK','coarse_az_step','coarse_el_step','fine_az_step','fine_el_step', ...
    'az_center_bias_deg','el_center_bias_deg','B','W_method'};
aggregate = unique(sub(:, config_fields), 'rows');
fields = {'overall_joint_success_rate','overall_az_rmse_mean','overall_el_rmse_mean','overall_combined_rmse_mean', ...
    'worst_case_success','overall_boundary_hit_rate','overall_mean_num_pairs','overall_mean_reduction_ratio_vs_full', ...
    'overall_full_grid_match_rate','overall_topK_miss_rate'};
for iField = 1:numel(fields)
    aggregate.(fields{iField}) = nan(height(aggregate), 1);
end
for iAgg = 1:height(aggregate)
    mask_cfg = true(height(sub), 1);
    for iField = 1:numel(config_fields)
        field = config_fields{iField};
        mask_cfg = mask_cfg & match_value_local(sub.(field), aggregate.(field)(iAgg));
    end
    rows = sub(mask_cfg, :);
    for iField = 1:numel(fields)
        field = fields{iField};
        aggregate.(field)(iAgg, 1) = mean_omitnan_local(rows.(field));
    end
    aggregate.worst_case_success(iAgg, 1) = min_omitnan_local(rows.joint_success_rate);
end
end

function recommended = choose_recommended_ctf_local(ctf_all, full_success, full_rmse)
eligible = ctf_all(ctf_all.overall_joint_success_rate >= 0.95 * full_success & ...
    ctf_all.overall_combined_rmse_mean <= 1.05 * max(full_rmse, eps) & ...
    ctf_all.overall_topK_miss_rate <= 0.05, :);
if isempty(eligible)
    recommended = eligible;
    return;
end
[~, order] = sortrows([eligible.overall_mean_num_pairs, -eligible.overall_full_grid_match_rate, ...
    eligible.overall_topK_miss_rate, eligible.topK]);
recommended = eligible(order(1), :);
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

function mask = match_value_local(values, target)
if iscell(values) || isstring(values) || ischar(target)
    mask = string_match_local(values, char_value_local(target));
else
    mask = abs(values - target) < 1e-12;
end
end

function mask = string_match_local(values, target)
if iscell(values)
    mask = strcmp(values, target);
elseif isstring(values)
    mask = strcmp(values, string(target));
else
    mask = strcmp(cellstr(values), target);
end
end

function value = char_value_local(value_in)
if iscell(value_in)
    value = value_in{1};
elseif isstring(value_in)
    value = char(value_in);
else
    value = char(value_in);
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

function v = min_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = min(x);
end
end
