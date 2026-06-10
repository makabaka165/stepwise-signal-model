function [keypoint_table, keypoints, final_recommendation_table] = summarize_step11_6_keypoints(stage1_summary, stage2_summary, stage3_summary, stage4_summary, cache_metadata)
%SUMMARIZE_STEP11_6_KEYPOINTS Build final Step11.6 pass/fail keypoints.

keypoints = struct();
keypoints.manifold_equivalence_pass_flag = logical_value_local(stage1_summary, 'manifold_equivalence_pass_flag', false);
keypoints.phase_aligned_equivalence_flag = logical_value_local(stage1_summary, 'phase_aligned_equivalence_flag', false);
keypoints.max_rel_a_error = numeric_value_local(stage1_summary, 'max_rel_a_error', NaN);
keypoints.max_rel_G_error = numeric_value_local(stage1_summary, 'max_rel_G_error', NaN);
keypoints.search_consistency_pass_flag = logical_value_local(stage2_summary, 'search_consistency_pass_flag', false);
keypoints.same_estimate_rate = numeric_value_local(stage2_summary, 'same_estimate_rate', NaN);
keypoints.same_policy_rate = numeric_value_local(stage2_summary, 'same_policy_rate', NaN);
keypoints.max_relative_score_diff = numeric_value_local(stage2_summary, 'max_relative_score_diff', NaN);
keypoints.cache_miss_count = numeric_value_local(stage2_summary, 'cache_miss_count', 0) + ...
    numeric_value_local(stage3_summary, 'cache_miss_count', 0) + numeric_value_local(stage4_summary, 'cache_miss_count', 0);
keypoints.runtime_manifold_pass_flag = logical_value_local(stage3_summary, 'runtime_manifold_pass_flag', false);
keypoints.runtime_search_pass_flag = logical_value_local(stage3_summary, 'runtime_search_pass_flag', false);
keypoints.median_manifold_time_reduction_ratio = numeric_value_local(stage3_summary, 'median_manifold_time_reduction_ratio', NaN);
keypoints.median_search_time_reduction_ratio = numeric_value_local(stage3_summary, 'median_search_time_reduction_ratio', NaN);
keypoints.cache_build_once_time_sec = numeric_value_local(stage3_summary, 'cache_build_once_time_sec', numeric_value_local(cache_metadata, 'cache_build_time_sec', NaN));
keypoints.cache_memory_MB = numeric_value_local(stage3_summary, 'cache_memory_MB', numeric_value_local(cache_metadata, 'cache_memory_MB', NaN));
keypoints.cross_center_reuse_pass_flag = logical_value_local(stage4_summary, 'cross_center_reuse_pass_flag', false);
keypoints.num_tested_centers = numeric_value_local(stage4_summary, 'num_tested_centers', NaN);
keypoints.num_passed_centers = numeric_value_local(stage4_summary, 'num_passed_centers', NaN);
keypoints.step11_6_overall_pass_flag = keypoints.manifold_equivalence_pass_flag && ...
    keypoints.search_consistency_pass_flag && keypoints.cross_center_reuse_pass_flag && keypoints.runtime_manifold_pass_flag;

if keypoints.step11_6_overall_pass_flag && keypoints.runtime_search_pass_flag
    keypoints.step11_6_recommendation = 'use_canonical_beamspace_manifold_cache_as_default_for_step11_5_c05_runtime_acceleration';
elseif keypoints.step11_6_overall_pass_flag && ~keypoints.runtime_search_pass_flag
    keypoints.step11_6_recommendation = 'use_canonical_beamspace_manifold_cache_as_manifold_build_acceleration_option_total_runtime_gain_limited_in_matlab';
else
    keypoints.step11_6_recommendation = 'do_not_use_cache_by_default_keep_direct_precompute_until_geometry_ordering_fixed';
end

names = fieldnames(keypoints);
key_col = strings(numel(names), 1);
value_col = strings(numel(names), 1);
for idx = 1:numel(names)
    key_col(idx) = string(names{idx});
    value_col(idx) = value_to_string_local(keypoints.(names{idx}));
end
keypoint_table = table(key_col, value_col, 'VariableNames', {'keypoint','value'});
final_recommendation_table = table(string(keypoints.step11_6_recommendation), logical(keypoints.step11_6_overall_pass_flag), ...
    logical(keypoints.runtime_search_pass_flag), 'VariableNames', {'step11_6_recommendation','step11_6_overall_pass_flag','runtime_search_pass_flag'});
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
