function out = step11_7_make_backend_output()
%STEP11_7_MAKE_BACKEND_OUTPUT Create the standard Step11.7 backend output.

out = struct();
out.status = 'uninitialized';
out.route_name = 'step11_7_final_cached_c05_beamspace_ml_route';
out.method_name = 'final_cached_c05_beamspace_ml_backend';
out.used_cache = false;
out.cache_miss_count = NaN;
out.fallback_used = false;
out.confidence = 'low';
out.boundary_flag = '';
out.az_hat = [NaN, NaN];
out.el_hat = [NaN, NaN];
out.el_center_hat = NaN;
out.el_sep_hat = NaN;
out.orientation_hat = NaN;
out.max_score = NaN;
out.policy_name = '';
out.adaptive_topK = NaN;
out.window_scale_az = NaN;
out.window_scale_el = NaN;
out.num_pairs_total = NaN;
out.num_pairs_coarse = NaN;
out.num_pairs_refine = NaN;
out.runtime_total_sec = NaN;
out.runtime_cache_lookup_sec = NaN;
out.runtime_search_sec = NaN;
out.selectedCenterColumn = NaN;
out.selectedCenterAz = NaN;
out.input_shape = '';
out.Z_shape = '';
out.debug = struct();
out.error_message = '';
end
