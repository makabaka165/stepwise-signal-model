function [keypoint_table, keypoints, final_recommendation_table] = summarize_step11_7_keypoints(stage1_summary, stage2_summary, stage3_summary, stage4_summary, stage5_summary)
%SUMMARIZE_STEP11_7_KEYPOINTS Build final Step11.7 pass/fail keypoints.

keypoints = struct();
keypoints.interface_smoke_pass_flag = logical_value_local(stage1_summary, 'interface_smoke_pass_flag', false);
keypoints.cached_direct_consistency_pass_flag = logical_value_local(stage2_summary, 'cached_direct_consistency_pass_flag', false);
keypoints.frontend_prior_bias_recheck_pass_flag = logical_value_local(stage3_summary, 'frontend_prior_bias_recheck_pass_flag', false);
keypoints.cache_fallback_behavior_pass_flag = logical_value_local(stage4_summary, 'cache_fallback_behavior_pass_flag', false);
keypoints.runtime_packaging_pass_flag = logical_value_local(stage5_summary, 'runtime_packaging_pass_flag', false);
keypoints.same_estimate_rate = numeric_value_local(stage2_summary, 'same_estimate_rate', NaN);
keypoints.same_policy_rate = numeric_value_local(stage2_summary, 'same_policy_rate', NaN);
keypoints.same_score_rate = numeric_value_local(stage2_summary, 'same_score_rate', NaN);
keypoints.max_score_diff_rel = numeric_value_local(stage2_summary, 'max_score_diff_rel', NaN);
keypoints.cache_miss_count = numeric_value_local(stage2_summary, 'cache_miss_count', 0) + ...
    numeric_value_local(stage3_summary, 'cache_miss_count', 0) + numeric_value_local(stage5_summary, 'cache_miss_count', 0);
keypoints.fallback_expected_case_pass_rate = numeric_value_local(stage4_summary, 'fallback_expected_case_pass_rate', NaN);
keypoints.frontend_bias_max_topK_miss_rate = numeric_value_local(stage3_summary, 'max_topK_miss_rate', NaN);
keypoints.frontend_bias_max_boundary_hit_rate = numeric_value_local(stage3_summary, 'max_boundary_hit_rate', NaN);
keypoints.frontend_bias_max_success_drop = numeric_value_local(stage3_summary, 'max_success_drop_vs_zero', NaN);
keypoints.median_runtime_reduction_ratio = numeric_value_local(stage5_summary, 'median_runtime_reduction_ratio', NaN);
keypoints.final_backend_output_fields_pass_flag = logical_value_local(stage1_summary, 'final_backend_output_fields_pass_flag', false);
keypoints.step11_7_overall_pass_flag = keypoints.interface_smoke_pass_flag && ...
    keypoints.cached_direct_consistency_pass_flag && keypoints.frontend_prior_bias_recheck_pass_flag && ...
    keypoints.cache_fallback_behavior_pass_flag && keypoints.final_backend_output_fields_pass_flag;

if keypoints.step11_7_overall_pass_flag && keypoints.runtime_packaging_pass_flag
    keypoints.step11_7_recommendation = 'use_step11_7_cached_c05_backend_as_final_step11_beamspace_ml_route';
elseif keypoints.step11_7_overall_pass_flag && ~keypoints.runtime_packaging_pass_flag
    keypoints.step11_7_recommendation = 'use_step11_7_cached_c05_backend_as_final_functional_route_runtime_gain_limited_in_matlab';
else
    keypoints.step11_7_recommendation = 'do_not_use_step11_7_as_final_entry_keep_step11_5_and_step11_6_separate_until_interface_fixed';
end

names = fieldnames(keypoints);
key_col = strings(numel(names), 1);
value_col = strings(numel(names), 1);
for idx = 1:numel(names)
    key_col(idx) = string(names{idx});
    value_col(idx) = value_to_string_local(keypoints.(names{idx}));
end
keypoint_table = table(key_col, value_col, 'VariableNames', {'keypoint','value'});
final_recommendation_table = table(string(keypoints.step11_7_recommendation), logical(keypoints.step11_7_overall_pass_flag), ...
    logical(keypoints.runtime_packaging_pass_flag), 'VariableNames', {'step11_7_recommendation','step11_7_overall_pass_flag','runtime_packaging_pass_flag'});
end

function value = numeric_value_local(T, field, fallback)
value = fallback;
if istable(T) && ismember(field, T.Properties.VariableNames) && height(T) >= 1
    value = T.(field)(1);
elseif isstruct(T) && isfield(T, field)
    value = T.(field);
end
if islogical(value)
    value = double(value);
end
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    value = fallback;
end
end

function value = logical_value_local(T, field, fallback)
value = logical(numeric_value_local(T, field, double(fallback)));
end

function text = value_to_string_local(value)
if isnumeric(value) || islogical(value)
    text = string(sprintf('%.12g', double(value)));
else
    text = string(value);
end
end
