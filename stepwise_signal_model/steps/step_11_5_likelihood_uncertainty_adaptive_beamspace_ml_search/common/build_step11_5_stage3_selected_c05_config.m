function [policy_cfg, config_table, stage2_reference] = build_step11_5_stage3_selected_c05_config(cfg_eval)
%BUILD_STEP11_5_STAGE3_SELECTED_C05_CONFIG Return the fixed Stage2 C05 policy.
%
% Stage3 is a robustness and branch-behavior validation of the Stage2
% selected C05 policy. This function intentionally returns only C05 and does
% not scan or reselect C01-C12.

if nargin < 1 || isempty(cfg_eval)
    cfg_eval = struct();
end

topK_max = scalar_field_local(cfg_eval, 'topK_max', 7);
tau = scalar_field_local(cfg_eval, 'tau', 0.02);

policy_cfg = struct();
policy_cfg.config_id = 5;
policy_cfg.config_name = 'C05_easy_very_aggressive';
policy_cfg.gap_scale = 0.003;
policy_cfg.easy_gap_threshold = 0.0020;
policy_cfg.easy_topK = 1;
policy_cfg.easy_window_scale = 0.60;
policy_cfg.ambiguous_gap_threshold = 0.0008;
policy_cfg.ambiguous_topK = 5;
policy_cfg.boundary_topK = 5;
policy_cfg.boundary_window_scale = 1.15;
policy_cfg.cond_threshold = 0.85;
policy_cfg.topK_max = topK_max;
policy_cfg.tau = tau;
policy_cfg.is_control_config = false;
policy_cfg.notes = 'Stage2 selected C05 fixed for Step11.5 Stage3 required enhancement validation';

config_table = struct2table(policy_cfg);

stage2_reference = struct();
stage2_reference.stage1_result_label = 'Step11.5 Stage1: original uncertainty policy negative result / safety passed but complexity failed';
stage2_reference.stage2_result_label = 'Step11.5 Stage2: calibrated search-budget policy tuning positive result';
stage2_reference.selected_config_name = 'C05_easy_very_aggressive';
stage2_reference.stage2_adaptive_pass_flag = 1;
stage2_reference.recommended_next_step = 'use_step11_5_stage2_as_positive_adaptive_enhancement';
stage2_reference.validation_fixed_success = 1;
stage2_reference.validation_adaptive_success = 1;
stage2_reference.validation_fixed_rmse = 0.0743030112986;
stage2_reference.validation_adaptive_rmse = 0.0527528990405;
stage2_reference.validation_fixed_mean_num_pairs = 18558;
stage2_reference.validation_adaptive_mean_num_pairs = 13242.6;
stage2_reference.validation_pair_count_ratio = 0.713579049467;
stage2_reference.adaptive_full_grid_match_rate = 1;
stage2_reference.adaptive_topK_miss_rate = 0;
stage2_reference.adaptive_boundary_hit_rate = 0;
stage2_reference.validation_policy_degeneracy_flag = 0;
stage2_reference.fixed_topK3_mean_num_pairs = 19090.62;
stage2_reference.stage2_selected_adaptive_mean_num_pairs = 13668.3;
stage2_reference.stage2_selected_pair_count_ratio = 0.715969413251;
stage2_reference.max_bias_adaptive_topK_miss_rate = 0;
stage2_reference.max_bias_adaptive_boundary_hit_rate = 0;
stage2_reference.max_bias_adaptive_success_drop = 0.04;
stage2_reference.bias_robustness_pass_flag = 1;
stage2_reference.valid_bias_range_text = 'az_bias=[-0.20,0.20], el_bias=[-0.20,0.20]';
end

function value = scalar_field_local(s, field_name, fallback)
value = fallback;
if isstruct(s) && isfield(s, field_name)
    candidate = s.(field_name);
    if isscalar(candidate) && isfinite(candidate)
        value = candidate;
    end
end
end
