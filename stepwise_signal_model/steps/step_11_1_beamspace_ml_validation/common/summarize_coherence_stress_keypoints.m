function [keypoint_rows, keypoints] = summarize_coherence_stress_keypoints(summary_table)
%SUMMARIZE_COHERENCE_STRESS_KEYPOINTS Build Stage5 keypoint metrics.

if nargin ~= 1 || ~istable(summary_table)
    error('summarize_coherence_stress_keypoints:InvalidInput', 'summary_table must be a table.');
end
required = {'model_mode','whitening_mode','beam_layout_name','rho','phase_deg','beta', ...
    'az_center_bias_deg','el_center_bias_deg','el_sep_deg','snr_db', ...
    'joint_pair_tol_success_rate','boundary_hit_rate','false_el_split_rate'};
for idx = 1:numel(required)
    if ~ismember(required{idx}, summary_table.Properties.VariableNames)
        error('summarize_coherence_stress_keypoints:MissingField', 'summary_table.%s is required.', required{idx});
    end
end

main_mask = string_match_local(summary_table.model_mode, 'pair2d') & ...
    string_match_local(summary_table.whitening_mode, 'white');
pass_mask = main_mask & abs(summary_table.az_center_bias_deg) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg) < 1e-12 & abs(summary_table.snr_db - 30) < 1e-12;
main_sub = summary_table(main_mask, :);
pass_sub = summary_table(pass_mask, :);
if isempty(main_sub) || isempty(pass_sub)
    error('summarize_coherence_stress_keypoints:MissingMainSubset', 'pair2d white subsets are required.');
end

moderate_sub = pass_sub(pass_sub.rho <= 0.9, :);
strong_sub = pass_sub(pass_sub.rho >= 0.99, :);
phase0_sub = pass_sub(abs(pass_sub.phase_deg) < 1e-12, :);
weak_sub = pass_sub(pass_sub.beta <= 0.3, :);
zero_sep_sub = main_sub(abs(main_sub.el_sep_deg) < 1e-12, :);

keypoints = struct();
keypoints.pass_rate_moderate_coherence = mean_omitnan_local(moderate_sub.joint_pair_tol_success_rate);
keypoints.pass_rate_strong_coherence = mean_omitnan_local(strong_sub.joint_pair_tol_success_rate);
keypoints.worst_case_joint_success = min_omitnan_local(pass_sub.joint_pair_tol_success_rate);
keypoints.best_layout_overall = best_layout_local(pass_sub);
keypoints.max_boundary_hit_rate = max_omitnan_local(main_sub.boundary_hit_rate);
keypoints.max_false_split_rate_true_sep0 = max_omitnan_local(zero_sep_sub.false_el_split_rate);
if ismember('false_high_like_rate', summary_table.Properties.VariableNames)
    keypoints.max_false_high_like_rate = max_omitnan_local(main_sub.false_high_like_rate);
else
    keypoints.max_false_high_like_rate = NaN;
end
keypoints.rho90_or_highest_reliable_rho = highest_reliable_rho_local(pass_sub);
keypoints.phase0_success_rate = mean_omitnan_local(phase0_sub.joint_pair_tol_success_rate);
keypoints.weak_target_beta03_success_rate = mean_omitnan_local(weak_sub.joint_pair_tol_success_rate);
if ismember('whitening_gain_pair2d', summary_table.Properties.VariableNames)
    gain_vals = summary_table.whitening_gain_pair2d(main_mask);
    keypoints.whitening_gain_mean = mean_omitnan_local(gain_vals);
else
    keypoints.whitening_gain_mean = NaN;
end

rho_values = [0, 0.9, 0.99, 1.0];
for idx = 1:numel(rho_values)
    rho_now = rho_values(idx);
    sub = pass_sub(abs(pass_sub.rho - rho_now) < 1e-12, :);
    field_name = sprintf('pair2d_white_success_rho%s', rho_label_local(rho_now));
    keypoints.(field_name) = mean_omitnan_local(sub.joint_pair_tol_success_rate);
end
keypoints.phase0_success_rate_pair2d_white = keypoints.phase0_success_rate;
keypoints.weak_target_beta03_success_rate_pair2d_white = keypoints.weak_target_beta03_success_rate;
keypoints.worst_case_joint_success_pair2d_white = keypoints.worst_case_joint_success;
keypoints.max_boundary_hit_rate_pair2d_white = keypoints.max_boundary_hit_rate;
keypoints.max_false_el_split_rate_true_sep0_pair2d_white = keypoints.max_false_split_rate_true_sep0;
keypoints.highest_reliable_rho_pair2d_white = keypoints.rho90_or_highest_reliable_rho;
if ismember('pair2d_minus_common_joint_success_gap', summary_table.Properties.VariableNames)
    keypoints.pair2d_minus_common_mean_success_gap = mean_omitnan_local(main_sub.pair2d_minus_common_joint_success_gap);
else
    keypoints.pair2d_minus_common_mean_success_gap = NaN;
end
keypoints.whitening_gain_mean_pair2d = keypoints.whitening_gain_mean;

pass1 = keypoints.pass_rate_moderate_coherence >= 0.75;
pass3 = keypoints.max_false_split_rate_true_sep0 <= 0.2;
pass4 = keypoints.max_boundary_hit_rate <= 0.3;
keypoints.coherence_stress_pass_flag = double(pass1 && pass3 && pass4);
if keypoints.coherence_stress_pass_flag == 1
    keypoints.recommended_next_step = 'proceed_to_model_selection_and_confidence_boundary';
else
    keypoints.recommended_next_step = 'document_coherence_limit_and_tune_beam_layout_or_regularization';
end

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

function label = rho_label_local(rho)
if abs(rho) < 1e-12
    label = '0';
elseif abs(rho - 0.9) < 1e-12
    label = '09';
elseif abs(rho - 0.99) < 1e-12
    label = '099';
elseif abs(rho - 1.0) < 1e-12
    label = '1';
else
    label = regexprep(sprintf('%.3g', rho), '[^0-9]', '');
end
end

function best_layout = best_layout_local(sub)
layouts = unique(cellstr_local(sub.beam_layout_name), 'stable');
best_layout = '';
best_success = -Inf;
for idx = 1:numel(layouts)
    mask = string_match_local(sub.beam_layout_name, layouts{idx});
    val = mean_omitnan_local(sub.joint_pair_tol_success_rate(mask));
    if val > best_success
        best_success = val;
        best_layout = layouts{idx};
    end
end
end

function rho_best = highest_reliable_rho_local(sub)
rho_vals = unique(sub.rho(isfinite(sub.rho)));
rho_best = NaN;
for idx = 1:numel(rho_vals)
    rho_now = rho_vals(idx);
    mask = abs(sub.rho - rho_now) < 1e-12;
    mean_success = mean_omitnan_local(sub.joint_pair_tol_success_rate(mask));
    max_boundary = max_omitnan_local(sub.boundary_hit_rate(mask));
    if mean_success >= 0.8 && max_boundary <= 0.2
        rho_best = rho_now;
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

function out = cellstr_local(values)
if iscell(values)
    out = values;
elseif isstring(values)
    out = cellstr(values);
else
    out = cellstr(values);
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

function v = max_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = max(x);
end
end
