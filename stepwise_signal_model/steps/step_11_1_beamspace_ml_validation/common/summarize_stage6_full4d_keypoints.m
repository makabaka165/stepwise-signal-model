function [keypoint_rows, keypoints] = summarize_stage6_full4d_keypoints(summary_table)
%SUMMARIZE_STAGE6_FULL4D_KEYPOINTS Build keypoints for Stage6 full4d comparison.

if nargin ~= 1 || ~istable(summary_table)
    error('summarize_stage6_full4d_keypoints:InvalidInput', 'summary_table must be a table.');
end
required = {'model_mode','whitening_mode','beam_layout_name','snr_db','az_center_bias_deg','el_center_bias_deg', ...
    'joint_tol_success_rate','mean_az_rmse_deg','mean_el_rmse_deg','boundary_hit_rate','mean_num_pairs'};
for idx = 1:numel(required)
    if ~ismember(required{idx}, summary_table.Properties.VariableNames)
        error('summarize_stage6_full4d_keypoints:MissingField', 'summary_table.%s is required.', required{idx});
    end
end

pass_mask = string_match_local(summary_table.whitening_mode, 'white') & ...
    string_match_local(summary_table.beam_layout_name, 'az5_el5') & ...
    abs(summary_table.snr_db - 30) < 1e-12 & ...
    abs(summary_table.az_center_bias_deg) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg) < 1e-12;
if ismember('source_mode', summary_table.Properties.VariableNames)
    pass_mask = pass_mask & (string_match_local(summary_table.source_mode, 'noncoherent') | ...
        string_match_local(summary_table.source_mode, 'correlated_main'));
end
pass_sub = summary_table(pass_mask, :);
if isempty(pass_sub)
    error('summarize_stage6_full4d_keypoints:MissingPassSubset', 'Missing Stage6 pass subset.');
end

full_sub = pass_sub(string_match_local(pass_sub.model_mode, 'full4d'), :);
pair_sub = pass_sub(string_match_local(pass_sub.model_mode, 'controlled_pair2d'), :);
common_sub = pass_sub(string_match_local(pass_sub.model_mode, 'common_el_restricted'), :);
if isempty(full_sub) || isempty(pair_sub) || isempty(common_sub)
    error('summarize_stage6_full4d_keypoints:MissingModels', 'All three model modes are required.');
end

best_full = mean_omitnan_local(full_sub.joint_tol_success_rate);
best_pair = mean_omitnan_local(pair_sub.joint_tol_success_rate);
best_common = mean_omitnan_local(common_sub.joint_tol_success_rate);
full_boundary = mean_omitnan_local(full_sub.boundary_hit_rate);
pair_boundary = mean_omitnan_local(pair_sub.boundary_hit_rate);
full_pairs = mean_omitnan_local(full_sub.mean_num_pairs);
pair_pairs = mean_omitnan_local(pair_sub.mean_num_pairs);
complexity_ratio = full_pairs / max(pair_pairs, eps);
full_minus_pair = best_full - best_pair;
full_minus_common = best_full - best_common;
pair_minus_common = best_pair - best_common;

pass_flag = double(best_full >= 0.8 && full_boundary <= 0.2);
if full_minus_pair <= 0.05
    full4d_role = 'upper_bound_only_pair2d_is_sufficient';
elseif full_minus_pair > 0.10 && complexity_ratio <= 5
    full4d_role = 'candidate_for_small_local_refinement';
elseif full_minus_pair > 0.05 && complexity_ratio > 5
    full4d_role = 'future_work_high_complexity_upper_bound';
else
    full4d_role = 'upper_bound_only_pair2d_is_sufficient';
end

if strcmp(full4d_role, 'upper_bound_only_pair2d_is_sufficient')
    recommended_next_step = 'proceed_to_final_paper_evidence_summary';
else
    recommended_next_step = 'document_full4d_upper_bound_and_keep_pair2d_as_default';
end

keypoints = struct();
keypoints.full4d_pass_flag = pass_flag;
keypoints.best_full4d_joint_success = best_full;
keypoints.best_pair2d_joint_success = best_pair;
keypoints.best_common_joint_success = best_common;
keypoints.full4d_minus_pair2d_success_gap = full_minus_pair;
keypoints.full4d_minus_common_success_gap = full_minus_common;
keypoints.pair2d_minus_common_success_gap = pair_minus_common;
keypoints.full4d_mean_az_rmse = mean_omitnan_local(full_sub.mean_az_rmse_deg);
keypoints.pair2d_mean_az_rmse = mean_omitnan_local(pair_sub.mean_az_rmse_deg);
keypoints.full4d_mean_el_rmse = mean_omitnan_local(full_sub.mean_el_rmse_deg);
keypoints.pair2d_mean_el_rmse = mean_omitnan_local(pair_sub.mean_el_rmse_deg);
keypoints.full4d_runtime_proxy_num_pairs = full_pairs;
keypoints.pair2d_runtime_proxy_num_pairs = pair_pairs;
keypoints.complexity_ratio_full4d_over_pair2d = complexity_ratio;
keypoints.full4d_boundary_hit_rate = full_boundary;
keypoints.pair2d_boundary_hit_rate = pair_boundary;
keypoints.full4d_recommended_role = full4d_role;
keypoints.recommended_next_step = recommended_next_step;

metric_names = fieldnames(keypoints);
keypoint_rows = repmat(make_keypoint_row_template_local(), numel(metric_names), 1);
for idx = 1:numel(metric_names)
    name = metric_names{idx};
    value = keypoints.(name);
    if isnumeric(value) || islogical(value)
        keypoint_rows(idx) = make_keypoint_row_local(name, double(value), '');
    else
        keypoint_rows(idx) = make_keypoint_row_local(name, NaN, char(value));
    end
end
end

function row = make_keypoint_row_template_local()
row = struct();
row.metric = '';
row.metric_value = NaN;
row.metric_text = '';
end

function row = make_keypoint_row_local(metric, metric_value, metric_text)
row = make_keypoint_row_template_local();
row.metric = metric;
row.metric_value = metric_value;
row.metric_text = metric_text;
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

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end
