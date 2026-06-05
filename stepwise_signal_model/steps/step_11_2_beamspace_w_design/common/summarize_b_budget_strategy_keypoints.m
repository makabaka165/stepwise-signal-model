function [keypoint_rows, keypoints] = summarize_b_budget_strategy_keypoints(summary_table, diagnostics_table)
%SUMMARIZE_B_BUDGET_STRATEGY_KEYPOINTS Summarize Stage3 tradeoff keypoints.

if nargin < 2
    error('summarize_b_budget_strategy_keypoints:NotEnoughInputs', ...
        'summary_table and diagnostics_table are required.');
end

aggregate = unique(summary_table(:, {'method_name','method_type','B','overall_joint_success_rate', ...
    'overall_az_rmse_deg','overall_el_rmse_deg','worst_case_success','projection_loss','max_corr', ...
    'cond_WHW','mean_num_pairs'}), 'rows');
aggregate.combined_rmse_deg = hypot(aggregate.overall_az_rmse_deg, aggregate.overall_el_rmse_deg);

nonrandom = aggregate(~strcmp(cellstr(aggregate.method_type), 'random_pool_baseline'), :);
backend_score = nonrandom.overall_joint_success_rate + 0.25 * nonrandom.worst_case_success - ...
    0.05 * nonrandom.combined_rmse_deg - 0.005 * max(nonrandom.B - min(nonrandom.B), 0);
[~, best_idx] = max(backend_score);
best = nonrandom(best_idx, :);

best_success = max(nonrandom.overall_joint_success_rate);
best_rmse = min(nonrandom.combined_rmse_deg);
perf_mask = nonrandom.overall_joint_success_rate >= 0.95 * best_success & ...
    nonrandom.combined_rmse_deg <= 1.05 * best_rmse;
if any(perf_mask)
    candidates = nonrandom(perf_mask, :);
else
    candidates = nonrandom;
end
[~, eng_idx] = sortrows([candidates.B, log10(max(candidates.cond_WHW, 1)), candidates.combined_rmse_deg]);
engineering = candidates(eng_idx(1), :);

low = nonrandom(nonrandom.B <= 15, :);
[~, low_idx] = max(low.overall_joint_success_rate + 0.25 * low.worst_case_success - 0.05 * low.combined_rmse_deg);
best_low = low(low_idx, :);

high = nonrandom(nonrandom.B >= 25, :);
[~, high_idx] = max(high.overall_joint_success_rate + 0.25 * high.worst_case_success - 0.05 * high.combined_rmse_deg);
best_high = high(high_idx, :);

diag_nonrandom = diagnostics_table(~strcmp(cellstr(diagnostics_table.method_type), 'random_pool_baseline'), :);
min_B_info = min_B_for_diag_local(diag_nonrandom, 'projection_loss', 0.2, '<=');
min_B_corr = min_B_for_diag_local(diag_nonrandom, 'max_corr', 0.3, '<=');
min_B_success = min_B_for_perf_local(nonrandom, 'overall_joint_success_rate', 0.95 * best_success, '>=');
min_B_rmse = min_B_for_perf_local(nonrandom, 'combined_rmse_deg', 1.05 * best_rmse, '<=');

regular_wins = count_method_beats_regular_local(nonrandom, 'regular_3dB_grid');
greedy_lowcorr_wins = count_method_beats_regular_local(nonrandom, 'greedy_lowcorr');
greedy_combined_wins = count_method_beats_regular_local(nonrandom, 'greedy_combined');

keypoints = struct();
keypoints.best_backend_method_overall = char_value_local(best.method_name(1));
keypoints.best_backend_B_overall = best.B(1);
keypoints.best_backend_success_overall = best.overall_joint_success_rate(1);
keypoints.best_backend_rmse_overall = best.combined_rmse_deg(1);
keypoints.best_backend_worst_case_success = best.worst_case_success(1);

keypoints.best_engineering_method = char_value_local(engineering.method_name(1));
keypoints.best_engineering_B = engineering.B(1);
keypoints.best_engineering_success = engineering.overall_joint_success_rate(1);
keypoints.best_engineering_rmse = engineering.combined_rmse_deg(1);

keypoints.best_low_B_method = char_value_local(best_low.method_name(1));
keypoints.best_low_B = best_low.B(1);
keypoints.best_low_B_success = best_low.overall_joint_success_rate(1);
keypoints.best_high_B_method = char_value_local(best_high.method_name(1));
keypoints.best_high_B = best_high.B(1);
keypoints.best_high_B_success = best_high.overall_joint_success_rate(1);

keypoints.min_B_for_95pct_best_success = min_B_success;
keypoints.min_B_for_105pct_best_rmse = min_B_rmse;
keypoints.min_B_for_projection_loss_below_0p2 = min_B_info;
keypoints.min_B_for_max_corr_below_0p3 = min_B_corr;
keypoints.min_B_for_information_retention = min_B_info;
keypoints.min_B_for_low_correlation = min_B_corr;
keypoints.min_B_for_backend_performance = min_B_success;

if engineering.B(1) < best.B(1)
    keypoints.recommended_engineering_B = engineering.B(1);
    keypoints.recommended_W_strategy = char_value_local(engineering.method_name(1));
else
    keypoints.recommended_engineering_B = best.B(1);
    keypoints.recommended_W_strategy = char_value_local(best.method_name(1));
end
keypoints.recommended_high_performance_B = best.B(1);
keypoints.recommended_fallback_strategy = 'regular_3dB_grid_if_greedy_selection_is_not_available';
keypoints.greedy_lowcorr_beats_regular_B_count = greedy_lowcorr_wins;
keypoints.greedy_combined_beats_regular_B_count = greedy_combined_wins;
keypoints.regular_reference_B_count = regular_wins;
keypoints.stage3_pass_flag = any(nonrandom.overall_joint_success_rate >= 0.95 * best_success & nonrandom.B <= 25);

if greedy_lowcorr_wins + greedy_combined_wins >= max(1, numel(unique(nonrandom.B)) / 2)
    keypoints.recommended_next_step = 'finalize_W_design_summary_for_thesis';
else
    keypoints.recommended_next_step = 'keep_regular_3dB_layout_and_document_greedy_no_major_gain';
end

keypoint_rows = keypoints_to_rows_local(keypoints);
end

function min_B = min_B_for_diag_local(T, field_name, threshold, mode)
switch mode
    case '<='
        mask = T.(field_name) <= threshold;
    case '>='
        mask = T.(field_name) >= threshold;
    otherwise
        error('summarize_b_budget_strategy_keypoints:UnknownMode', 'Unknown mode.');
end
if any(mask)
    min_B = min(T.B(mask));
else
    min_B = NaN;
end
end

function min_B = min_B_for_perf_local(T, field_name, threshold, mode)
switch mode
    case '<='
        mask = T.(field_name) <= threshold;
    case '>='
        mask = T.(field_name) >= threshold;
    otherwise
        error('summarize_b_budget_strategy_keypoints:UnknownMode', 'Unknown mode.');
end
if any(mask)
    min_B = min(T.B(mask));
else
    min_B = NaN;
end
end

function wins = count_method_beats_regular_local(T, method_name)
B_vals = unique(T.B);
wins = 0;
for iB = 1:numel(B_vals)
    B = B_vals(iB);
    regular = select_row_local(T, 'regular_3D_grid', B);
    if isempty(regular)
        regular = select_row_local(T, 'regular_3dB_grid', B);
    end
    method = select_row_local(T, method_name, B);
    if isempty(method) || isempty(regular)
        continue;
    end
    if method.overall_joint_success_rate > regular.overall_joint_success_rate || ...
            (abs(method.overall_joint_success_rate - regular.overall_joint_success_rate) < 1e-12 && ...
            method.combined_rmse_deg < regular.combined_rmse_deg)
        wins = wins + 1;
    end
end
end

function row = select_row_local(T, method_name, B)
mask = strcmp(cellstr(T.method_name), method_name) & abs(T.B - B) < 1e-12;
if any(mask)
    row = T(find(mask, 1), :);
else
    row = [];
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

function value = char_value_local(value_in)
if iscell(value_in)
    value = value_in{1};
elseif isstring(value_in)
    value = char(value_in);
else
    value = char(value_in);
end
end
