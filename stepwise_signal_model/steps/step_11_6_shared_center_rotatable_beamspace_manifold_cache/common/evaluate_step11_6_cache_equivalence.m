function [trial_table, summary_table] = evaluate_step11_6_cache_equivalence(W, cfg, cache, params)
%EVALUATE_STEP11_6_CACHE_EQUIVALENCE Run Stage1 canonical manifold validation.

manifold_opts = struct('phase_factor', params.phase_factor, 'phase_sign', params.phase_sign);
trial_table = compare_step11_6_direct_vs_cache_manifold(W, cfg, cache, params.stage1_center_az_list, ...
    params.stage1_delta_az_grid, params.stage1_el_values, params.lambda, manifold_opts);

summary = make_summary_row_local(trial_table);
summary_table = struct2table(summary);
end

function row = make_summary_row_local(T)
row = struct();
row.stage_name = 'stage1_manifold_equivalence';
row.num_trials = height(T);
row.num_tested_centers = numel(unique(T.actual_center_az));
row.max_rel_a_error = max(T.rel_a_error);
row.max_rel_G_error = max(T.rel_G_error);
row.max_phase_aligned_rel_a_error = max(T.phase_aligned_rel_a_error);
row.max_phase_aligned_rel_G_error = max(T.phase_aligned_rel_G_error);
row.max_cache_miss_count = max(T.cache_miss_count);
row.manifold_equivalence_pass_flag = row.max_rel_a_error <= 1e-8 && row.max_rel_G_error <= 1e-8 && row.max_cache_miss_count == 0;
row.phase_aligned_equivalence_flag = row.max_phase_aligned_rel_a_error <= 1e-8 && row.max_phase_aligned_rel_G_error <= 1e-8;
if row.manifold_equivalence_pass_flag
    row.recommendation = 'canonical_cache_equivalence_verified_for_tested_shared_centers';
elseif row.phase_aligned_equivalence_flag
    row.recommendation = 'investigate_global_phase_or_ordering_before_default_cache_use';
else
    row.recommendation = 'do_not_use_cache_check_geometry_order_or_W_order';
end
end
