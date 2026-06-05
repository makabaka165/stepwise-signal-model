function [keypoint_rows, keypoints] = summarize_search_acceleration_keypoints(summary_table, stage_name, varargin)
%SUMMARIZE_SEARCH_ACCELERATION_KEYPOINTS Build compact evidence keypoints.

if nargin < 2
    stage_name = 'stage';
end
if isempty(summary_table)
    error('summarize_search_acceleration_keypoints:EmptySummary', 'summary_table is empty.');
end
stage_name = lower(char(stage_name));

switch stage_name
    case {'stage2','topk_grid_sweep'}
        keypoints = summarize_stage2_local(summary_table);
    case {'stage3','frontend_prior_bias_robustness'}
        keypoints = summarize_stage3_local(summary_table);
    otherwise
        keypoints = summarize_stage12_local(summary_table);
end
keypoint_rows = keypoints_to_rows_local(keypoints);
end

function keypoints = summarize_stage2_local(summary_table)
config_metrics = build_stage2_config_metrics_local(summary_table);
if isempty(config_metrics)
    error('summarize_search_acceleration_keypoints:MissingStage2Configs', ...
        'Stage2 summary requires full_fine and coarse_to_fine rows.');
end

pass_mask = [config_metrics.final_pass].';
if any(pass_mask)
    candidates = config_metrics(pass_mask);
    [~, order] = sortrows([-[candidates.complexity_reduction_ratio].', ...
        [candidates.coarse_to_fine_rmse].', [candidates.topK_miss_rate].']);
    recommended = candidates(order(1));
else
    [~, order] = sortrows([-[config_metrics.coarse_to_fine_success].', ...
        [config_metrics.topK_miss_rate].', -[config_metrics.complexity_reduction_ratio].', ...
        [config_metrics.coarse_to_fine_rmse].']);
    recommended = config_metrics(order(1));
end

keypoints = struct();
keypoints.recommended_config_name = recommended.config_name;
keypoints.recommended_topK = recommended.topK;
keypoints.recommended_coarse_az_step = recommended.coarse_az_step;
keypoints.recommended_coarse_el_step = recommended.coarse_el_step;
keypoints.recommended_fine_az_step = recommended.fine_az_step;
keypoints.recommended_fine_el_step = recommended.fine_el_step;
keypoints.recommended_local_az_half_width = recommended.local_az_half_width;
keypoints.recommended_local_el_center_half_width = recommended.local_el_center_half_width;
keypoints.recommended_coarse_el_sep_list_text = recommended.coarse_el_sep_list_text;
keypoints.recommended_fine_el_sep_list_text = recommended.fine_el_sep_list_text;
keypoints.full_fine_success = recommended.full_fine_success;
keypoints.coarse_to_fine_success = recommended.coarse_to_fine_success;
keypoints.full_fine_rmse = recommended.full_fine_rmse;
keypoints.coarse_to_fine_rmse = recommended.coarse_to_fine_rmse;
keypoints.full_fine_worst_case_success = recommended.full_fine_worst_case_success;
keypoints.coarse_to_fine_worst_case_success = recommended.coarse_to_fine_worst_case_success;
keypoints.full_fine_mean_num_pairs = recommended.full_fine_mean_num_pairs;
keypoints.coarse_to_fine_mean_num_pairs = recommended.coarse_to_fine_mean_num_pairs;
keypoints.coarse_mean_num_pairs = recommended.coarse_mean_num_pairs;
keypoints.refine_mean_num_pairs = recommended.refine_mean_num_pairs;
keypoints.complexity_reduction_ratio = recommended.complexity_reduction_ratio;
keypoints.topK_miss_rate = recommended.topK_miss_rate;
keypoints.boundary_hit_rate = recommended.boundary_hit_rate;
keypoints.el_sep_match_rate_vs_full = recommended.el_sep_match_rate_vs_full;
keypoints.full_grid_match_rate = recommended.full_grid_match_rate;
keypoints.search_param_mode = recommended.search_param_mode;
keypoints.search_acceleration_pass_flag = recommended.final_pass;
if keypoints.search_acceleration_pass_flag
    keypoints.recommended_next_step = 'run_stage3_frontend_prior_bias_with_recommended_config';
else
    keypoints.recommended_next_step = 'document_search_acceleration_limit_or_expand_topK_refine_options';
end
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
keypoints.search_param_mode = char_value_local(recommended.search_param_mode(1));
keypoints.full_fine_el_sep_list_text = char_value_local(full.full_el_sep_deg_list_text(1));
keypoints.coarse_el_sep_list_text = char_value_local(recommended.coarse_el_sep_deg_list_text(1));
keypoints.fine_el_sep_list_text = char_value_local(recommended.fine_el_sep_deg_list_text(1));
keypoints.el_sep_match_rate_vs_full = recommended.overall_el_sep_match_rate_vs_full(1);
keypoints.recommended_topK = recommended.topK(1);
keypoints.recommended_coarse_az_step = recommended.coarse_az_step(1);
keypoints.recommended_coarse_el_step = recommended.coarse_el_step(1);
keypoints.recommended_fine_az_step = recommended.fine_az_step(1);
keypoints.recommended_fine_el_step = recommended.fine_el_step(1);
keypoints.recommended_local_az_half_width = recommended.local_az_half_width(1);
keypoints.recommended_local_el_center_half_width = recommended.local_el_center_half_width(1);
keypoints.search_acceleration_pass_flag = pass_flag && ...
    keypoints.coarse_to_fine_success >= 0.95 * keypoints.full_fine_success && ...
    keypoints.coarse_to_fine_rmse <= 1.05 * max(keypoints.full_fine_rmse, eps) && ...
    keypoints.topK_miss_rate <= 0.05 && ...
    keypoints.complexity_reduction_ratio >= 2;
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
keypoints.search_param_mode = char_value_local(zero.search_param_mode(1));
keypoints.coarse_el_sep_list_text = char_value_local(zero.coarse_el_sep_deg_list_text(1));
keypoints.fine_el_sep_list_text = char_value_local(zero.fine_el_sep_deg_list_text(1));
keypoints.el_sep_match_rate_vs_full = zero.overall_el_sep_match_rate_vs_full(1);
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
config_fields = {'search_method','config_name','coarse_config_name','refine_config_name','sweep_phase', ...
    'topK','coarse_az_step','coarse_el_step','fine_az_step','fine_el_step', ...
    'local_az_half_width','local_el_center_half_width','az_center_bias_deg','el_center_bias_deg','B','W_method', ...
    'search_param_mode','full_el_sep_deg_list_text','coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text'};
aggregate = unique(sub(:, config_fields), 'rows');
fields = {'overall_joint_success_rate','overall_az_rmse_mean','overall_el_rmse_mean','overall_combined_rmse_mean', ...
    'worst_case_success','overall_boundary_hit_rate','overall_mean_num_pairs','overall_mean_reduction_ratio_vs_full', ...
    'overall_full_grid_match_rate','overall_topK_miss_rate','overall_el_sep_match_rate_vs_full'};
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

function config_metrics = build_stage2_config_metrics_local(summary_table)
full = aggregate_for_method_local(summary_table, 'full_fine');
ctf = aggregate_for_method_local(summary_table, 'coarse_to_fine');
if isempty(full) || isempty(ctf)
    config_metrics = repmat(make_stage2_config_metric_template_local(), 0, 1);
    return;
end
rows = repmat(make_stage2_config_metric_template_local(), height(ctf), 1);
for idx = 1:height(ctf)
    full_idx = find(string_match_local(full.config_name, char_value_local(ctf.config_name(idx))), 1);
    if isempty(full_idx)
        full_idx = 1;
    end
    full_row = full(full_idx, :);
    ctf_row = ctf(idx, :);
    rows(idx).config_name = char_value_local(ctf_row.config_name(1));
    rows(idx).coarse_config_name = char_value_local(ctf_row.coarse_config_name(1));
    rows(idx).refine_config_name = char_value_local(ctf_row.refine_config_name(1));
    rows(idx).topK = ctf_row.topK(1);
    rows(idx).coarse_az_step = ctf_row.coarse_az_step(1);
    rows(idx).coarse_el_step = ctf_row.coarse_el_step(1);
    rows(idx).fine_az_step = ctf_row.fine_az_step(1);
    rows(idx).fine_el_step = ctf_row.fine_el_step(1);
    rows(idx).local_az_half_width = ctf_row.local_az_half_width(1);
    rows(idx).local_el_center_half_width = ctf_row.local_el_center_half_width(1);
    rows(idx).coarse_el_sep_list_text = char_value_local(ctf_row.coarse_el_sep_deg_list_text(1));
    rows(idx).fine_el_sep_list_text = char_value_local(ctf_row.fine_el_sep_deg_list_text(1));
    rows(idx).search_param_mode = char_value_local(ctf_row.search_param_mode(1));
    rows(idx).full_fine_success = full_row.overall_joint_success_rate(1);
    rows(idx).coarse_to_fine_success = ctf_row.overall_joint_success_rate(1);
    rows(idx).full_fine_rmse = full_row.overall_combined_rmse_mean(1);
    rows(idx).coarse_to_fine_rmse = ctf_row.overall_combined_rmse_mean(1);
    rows(idx).full_fine_worst_case_success = full_row.worst_case_success(1);
    rows(idx).coarse_to_fine_worst_case_success = ctf_row.worst_case_success(1);
    rows(idx).full_fine_mean_num_pairs = full_row.overall_mean_num_pairs(1);
    rows(idx).coarse_to_fine_mean_num_pairs = ctf_row.overall_mean_num_pairs(1);
    rows(idx).coarse_mean_num_pairs = mean_column_for_config_local(summary_table, rows(idx).config_name, ...
        'coarse_to_fine', 'mean_coarse_num_pairs');
    rows(idx).refine_mean_num_pairs = mean_column_for_config_local(summary_table, rows(idx).config_name, ...
        'coarse_to_fine', 'mean_refine_num_pairs');
    rows(idx).complexity_reduction_ratio = rows(idx).full_fine_mean_num_pairs / ...
        max(rows(idx).coarse_to_fine_mean_num_pairs, eps);
    rows(idx).topK_miss_rate = ctf_row.overall_topK_miss_rate(1);
    rows(idx).boundary_hit_rate = ctf_row.overall_boundary_hit_rate(1);
    rows(idx).el_sep_match_rate_vs_full = ctf_row.overall_el_sep_match_rate_vs_full(1);
    rows(idx).full_grid_match_rate = ctf_row.overall_full_grid_match_rate(1);
    rmse_ok = rows(idx).coarse_to_fine_rmse <= 1.05 * max(rows(idx).full_fine_rmse, eps) || ...
        rows(idx).coarse_to_fine_rmse <= rows(idx).full_fine_rmse + 0.02;
    rows(idx).final_pass = rows(idx).coarse_to_fine_success >= 0.95 * rows(idx).full_fine_success && ...
        rmse_ok && rows(idx).topK_miss_rate <= 0.05 && rows(idx).boundary_hit_rate <= 0.2 && ...
        rows(idx).complexity_reduction_ratio >= 2;
end
config_metrics = rows;
end

function row = make_stage2_config_metric_template_local()
row = struct();
row.config_name = '';
row.coarse_config_name = '';
row.refine_config_name = '';
row.topK = NaN;
row.coarse_az_step = NaN;
row.coarse_el_step = NaN;
row.fine_az_step = NaN;
row.fine_el_step = NaN;
row.local_az_half_width = NaN;
row.local_el_center_half_width = NaN;
row.coarse_el_sep_list_text = '';
row.fine_el_sep_list_text = '';
row.search_param_mode = '';
row.full_fine_success = NaN;
row.coarse_to_fine_success = NaN;
row.full_fine_rmse = NaN;
row.coarse_to_fine_rmse = NaN;
row.full_fine_worst_case_success = NaN;
row.coarse_to_fine_worst_case_success = NaN;
row.full_fine_mean_num_pairs = NaN;
row.coarse_to_fine_mean_num_pairs = NaN;
row.coarse_mean_num_pairs = NaN;
row.refine_mean_num_pairs = NaN;
row.complexity_reduction_ratio = NaN;
row.topK_miss_rate = NaN;
row.boundary_hit_rate = NaN;
row.el_sep_match_rate_vs_full = NaN;
row.full_grid_match_rate = NaN;
row.final_pass = false;
end

function value = mean_column_for_config_local(summary_table, config_name, method_name, field_name)
mask = string_match_local(summary_table.config_name, config_name) & ...
    string_match_local(summary_table.search_method, method_name);
if ~any(mask) || ~ismember(field_name, summary_table.Properties.VariableNames)
    value = NaN;
else
    value = mean_omitnan_local(summary_table.(field_name)(mask));
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
