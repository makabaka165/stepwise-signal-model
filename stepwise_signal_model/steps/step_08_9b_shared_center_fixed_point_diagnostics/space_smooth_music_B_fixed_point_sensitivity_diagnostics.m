% Step 8.9B shared-center fixed-point sensitivity diagnostics.
%
% This script performs offline diagnostics on Step 8.9 results. It does not
% rerun the Monte Carlo, does not change Step 8.7/8.8/8.9 algorithms, and
% does not overwrite Step 8.9 result directories.

clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);

step89_dir = fullfile(steps_dir, 'step_08_9_shared_center_fixed_point_validation');
step89_result_dir = fullfile(step89_dir, 'results_step8_9_shared_center_fixed_point_validation');
trial_csv_in = fullfile(step89_result_dir, 'step8_9_shared_center_fixed_point_trial.csv');
summary_csv_in = fullfile(step89_result_dir, 'step8_9_shared_center_fixed_point_summary.csv');
keypoints_csv_in = fullfile(step89_result_dir, 'step8_9_shared_center_fixed_point_keypoints.csv');
record89_path = fullfile(step89_dir, '第8.9步_shared-center主线定点量化影响验证记录.md');
record88b_path = fullfile(steps_dir, 'step_08_8_frontend_to_shared_center_closure', '第8.8B步_Ywork多普勒补偿接口验证记录.md');
interface88_path = fullfile(steps_dir, 'step_08_8_frontend_to_shared_center_closure', '第8.8步_前端到第8.7接口定义.md');
step87_script_path = fullfile(steps_dir, 'step_08_7_routeB_array_level3', 'space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m');

result_dir = fullfile(script_dir, 'results_step8_9b_fixed_point_sensitivity_diagnostics');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_9b_fixed_point_sensitivity_diagnostics.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

trial_diag_csv = fullfile(result_dir, 'step8_9b_fixed_point_trial_diagnostics.csv');
scenario_summary_csv = fullfile(result_dir, 'step8_9b_fixed_point_scenario_summary.csv');
route_summary_csv = fullfile(result_dir, 'step8_9b_fixed_point_route_summary.csv');
confidence_summary_csv = fullfile(result_dir, 'step8_9b_fixed_point_confidence_summary.csv');
source_summary_csv = fullfile(result_dir, 'step8_9b_fixed_point_source_summary.csv');
worst_cases_csv = fullfile(result_dir, 'step8_9b_fixed_point_worst_cases.csv');
keypoints_csv = fullfile(result_dir, 'step8_9b_fixed_point_keypoints.csv');
recommendations_csv = fullfile(result_dir, 'step8_9b_fixed_point_recommendations.csv');
mat_path = fullfile(result_dir, 'step8_9b_fixed_point_sensitivity_result.mat');
record_doc_path = fullfile(script_dir, '第8.9B步_shared-center定点量化敏感性分解诊断记录.md');

use_existing_step89_results = true;
targeted_rerun_used = false;
targeted_rerun_reason = "not_needed_existing_step89_trial_fields_sufficient_for_offline_diagnostics";

log_msg_local(fid_log, 'Step 8.9B shared-center fixed-point sensitivity diagnostics');
log_msg_local(fid_log, 'use_existing_step89_results=%d', use_existing_step89_results);
log_msg_local(fid_log, 'targeted_rerun_used=%d (%s)', targeted_rerun_used, targeted_rerun_reason);
log_msg_local(fid_log, 'Input Step 8.9 trial CSV: %s', trial_csv_in);
log_msg_local(fid_log, 'No edits to Step 8.7 / Step 8.8 / Step 8.9 original files or result directories.');

required_files = {trial_csv_in, summary_csv_in, keypoints_csv_in, record89_path, ...
    record88b_path, interface88_path, step87_script_path};
for i = 1:numel(required_files)
    if ~exist(required_files{i}, 'file')
        error('Missing required input: %s', required_files{i});
    end
end

T89 = readtable(trial_csv_in, 'TextType', 'string');
S89 = readtable(summary_csv_in, 'TextType', 'string');
K89 = readtable(keypoints_csv_in, 'TextType', 'string');
modes = ["double_baseline", "float32_all", "coeff_int16_only", "ywork_int16_only", ...
    "combined_int16", "combined_int18", "combined_int24"];

diagnostic_tbl = build_trial_diagnostics_local(T89, modes);
scenario_summary_tbl = build_group_summary_local(diagnostic_tbl, "scenario_name", modes, true);
route_summary_tbl = build_group_summary_local(diagnostic_tbl, "double_route", modes, false);
confidence_summary_tbl = build_group_summary_local(diagnostic_tbl, "double_confidence_group", modes, false);
source_summary_tbl = build_source_summary_local(diagnostic_tbl);
worst_cases_tbl = build_worst_cases_local(diagnostic_tbl, 50);
recommendations_tbl = build_recommendations_local(diagnostic_tbl, source_summary_tbl, scenario_summary_tbl, route_summary_tbl, confidence_summary_tbl);
keypoints_tbl = build_keypoints_local(diagnostic_tbl, source_summary_tbl, scenario_summary_tbl, route_summary_tbl, confidence_summary_tbl, recommendations_tbl);

log_msg_local(fid_log, 'Rows loaded from Step 8.9 trial CSV: %d', height(T89));
log_msg_local(fid_log, 'Diagnostic rows written: %d', height(diagnostic_tbl));
log_msg_local(fid_log, 'In-scope base trials: %d', keypoint_value_local(keypoints_tbl, 'total_in_scope_trials'));
log_msg_local(fid_log, 'Recommended action: %s', keypoint_note_local(keypoints_tbl, 'recommended_action'));

writetable(diagnostic_tbl, trial_diag_csv);
writetable(scenario_summary_tbl, scenario_summary_csv);
writetable(route_summary_tbl, route_summary_csv);
writetable(confidence_summary_tbl, confidence_summary_csv);
writetable(source_summary_tbl, source_summary_csv);
writetable(worst_cases_tbl, worst_cases_csv);
writetable(keypoints_tbl, keypoints_csv);
writetable(recommendations_tbl, recommendations_csv);

plot_agreement_by_group_local(scenario_summary_tbl, "scenario_name", fullfile(result_dir, 'agreement_by_scenario.png'));
plot_agreement_by_group_local(route_summary_tbl, "double_route", fullfile(result_dir, 'agreement_by_route.png'));
plot_agreement_by_group_local(confidence_summary_tbl, "double_confidence_group", fullfile(result_dir, 'agreement_by_confidence.png'));
plot_coeff_vs_ywork_sensitivity_local(source_summary_tbl, fullfile(result_dir, 'coeff_vs_ywork_sensitivity.png'));
plot_output_equivalent_vs_route_agreement_local(source_summary_tbl, fullfile(result_dir, 'output_equivalent_vs_route_agreement.png'));
plot_az_diff_hist_by_mode_local(diagnostic_tbl, fullfile(result_dir, 'az_diff_hist_by_mode.png'));
plot_worst_case_scatter_local(diagnostic_tbl, fullfile(result_dir, 'worst_case_az_diff_scatter.png'));
plot_score_margin_proxy_local(diagnostic_tbl, fullfile(result_dir, 'score_margin_vs_route_change.png'));
plot_quant_error_vs_route_change_local(diagnostic_tbl, fullfile(result_dir, 'quantization_error_vs_route_change.png'));
plot_recommended_action_summary_local(keypoints_tbl, fullfile(result_dir, 'recommended_action_summary.png'));

save(mat_path, 'diagnostic_tbl', 'scenario_summary_tbl', 'route_summary_tbl', ...
    'confidence_summary_tbl', 'source_summary_tbl', 'worst_cases_tbl', ...
    'recommendations_tbl', 'keypoints_tbl', 'S89', 'K89', ...
    'use_existing_step89_results', 'targeted_rerun_used', '-v7.3');

write_record_doc_local(record_doc_path, keypoints_tbl, source_summary_tbl, ...
    scenario_summary_tbl, route_summary_tbl, confidence_summary_tbl, ...
    worst_cases_tbl, recommendations_tbl, result_dir, targeted_rerun_used, targeted_rerun_reason);

log_msg_local(fid_log, 'Outputs written to %s', result_dir);
log_msg_local(fid_log, 'Record doc: %s', record_doc_path);

function D = build_trial_diagnostics_local(T, modes)
    T.quant_mode = string(T.quant_mode);
    T.route_used = string(T.route_used);
    T.confidence_flag = string(T.confidence_flag);
    T.scenario_name = string(T.scenario_name);
    T.frontend_state = string(T.frontend_state);
    nModes = numel(modes);
    if mod(height(T), nModes) ~= 0
        error('Step 8.9 trial rows (%d) are not divisible by mode count (%d).', height(T), nModes);
    end
    T.row_index = (1:height(T)).';
    T.trial_id = ceil(T.row_index / nModes);
    base = T(T.quant_mode == "double_baseline", :);
    base = sortrows(base, 'trial_id');
    if height(base) ~= max(T.trial_id)
        error('Cannot align double_baseline rows to base trial ids.');
    end
    idx = T.trial_id;
    in_scope = to_bool_local(T.in_scope_shared_center_flag);
    base_in_scope = to_bool_local(base.in_scope_shared_center_flag);
    q_false_high = to_bool_local(T.false_high);
    q_boundary_missed = to_bool_local(T.boundary_missed);
    q_success = to_bool_local(T.success);
    d_success = to_bool_local(base.success);
    q_low = to_bool_local(T.low_confidence);
    d_low = to_bool_local(base.low_confidence);
    q_boundary_unrel = to_bool_local(T.boundary_unreliable);
    d_boundary_unrel = to_bool_local(base.boundary_unreliable);

    d_route = base.route_used(idx);
    q_route = T.route_used;
    d_conf = base.confidence_flag(idx);
    q_conf = T.confidence_flag;
    d_conf_group = confidence_group_local(d_conf, d_route, base_in_scope(idx));
    q_conf_group = confidence_group_local(q_conf, q_route, in_scope);
    route_agree = q_route == d_route;
    conf_agree = q_conf == d_conf;
    d_rank = confidence_rank_local(d_conf_group);
    q_rank = confidence_rank_local(q_conf_group);
    dangerous_upgrade = (d_conf_group == "low" | d_conf_group == "boundary") & q_conf == "high";
    medium_to_high = d_conf_group == "medium" & q_conf == "high";
    confidence_downgrade_or_same = q_rank <= d_rank;

    az_diff = abs(T.az_est_diff_vs_double);
    el_diff = abs(T.el_est_diff_vs_double);
    same_output_count = T.output_count_diff_vs_double == 0;
    no_output_both = T.output_count == 0 & base.output_count(idx) == 0;
    az_display = az_diff;
    el_display = el_diff;
    az_display(no_output_both & ~isfinite(az_display)) = 0;
    el_display(no_output_both & ~isfinite(el_display)) = 0;
    az_eff = az_diff;
    el_eff = el_diff;
    az_eff(no_output_both & ~isfinite(az_eff)) = 0;
    el_eff(no_output_both & ~isfinite(el_eff)) = 0;
    az_eff(~isfinite(az_eff)) = Inf;
    el_eff(~isfinite(el_eff)) = Inf;

    output_equiv = same_output_count & az_eff <= 0.05 & el_eff <= 0.5 & ...
        ~dangerous_upgrade & ~q_false_high & ~q_boundary_missed;
    output_equiv_strict = same_output_count & az_eff <= 0.03 & el_eff <= 0.3 & ...
        confidence_downgrade_or_same & ~q_false_high & ~q_boundary_missed;
    output_equiv_relaxed = same_output_count & az_eff <= 0.10 & el_eff <= 1.0 & ...
        ~dangerous_upgrade & ~q_false_high & ~q_boundary_missed;
    output_equiv(T.quant_mode == "double_baseline") = true;
    output_equiv_strict(T.quant_mode == "double_baseline") = true;
    output_equiv_relaxed(T.quant_mode == "double_baseline") = true;

    yclip = max(T.ywork_clip_rate_real, T.ywork_clip_rate_imag);
    failure_h = strings(height(T), 1);
    for i = 1:height(T)
        failure_h(i) = classify_failure_hypothesis_local(T, base, idx(i), i, route_agree(i), ...
            output_equiv(i), output_equiv_relaxed(i), az_eff(i));
    end

    D = table();
    D.trial_id = T.trial_id;
    D.scenario_name = T.scenario_name;
    D.SNR = T.snr_db;
    D.mc = T.mc;
    D.quant_mode = T.quant_mode;
    D.double_route = d_route;
    D.quant_route = q_route;
    D.route_agreement = route_agree;
    D.double_confidence = d_conf;
    D.quant_confidence = q_conf;
    D.double_confidence_group = d_conf_group;
    D.quant_confidence_group = q_conf_group;
    D.confidence_agreement = conf_agree;
    D.dangerous_confidence_upgrade = dangerous_upgrade;
    D.medium_to_high_upgrade = medium_to_high;
    D.output_equivalent = output_equiv;
    D.output_equivalent_strict = output_equiv_strict;
    D.output_equivalent_relaxed = output_equiv_relaxed;
    D.double_success = d_success(idx);
    D.quant_success = q_success;
    D.success_changed = q_success ~= d_success(idx);
    D.false_high = q_false_high;
    D.boundary_missed = q_boundary_missed;
    D.double_az_est = base.az_est(idx);
    D.quant_az_est = T.az_est;
    D.az_diff = az_display;
    D.az_diff_for_equivalence = az_eff;
    D.double_el_est = base.el_est(idx);
    D.quant_el_est = T.el_est;
    D.el_diff = el_display;
    D.el_diff_for_equivalence = el_eff;
    D.output_count_diff = T.output_count_diff_vs_double;
    D.ywork_snr_quant_db = T.ywork_snr_quant_db;
    D.ywork_rel_err = T.ywork_rel_err;
    D.steering_rel_err_aligned = T.max_steering_rel_err_aligned;
    D.steering_mean_rel_err_aligned = T.mean_steering_rel_err_aligned;
    D.ywork_clip_rate = yclip;
    D.frontend_state = T.frontend_state;
    D.coarse_peak_count = T.coarse_peak_count;
    D.in_scope_shared_center_flag = in_scope;
    D.low_confidence_double = d_low(idx);
    D.boundary_double = d_boundary_unrel(idx);
    D.low_confidence_quant = q_low;
    D.boundary_quant = q_boundary_unrel;
    D.true_az1 = T.true_az1;
    D.true_az2 = T.true_az2;
    D.true_el1 = T.true_el1;
    D.true_el2 = T.true_el2;
    D.weak_target_truth_flag = to_bool_local(T.weak_target_truth_flag);
    D.anti_phase_truth_flag = to_bool_local(T.anti_phase_truth_flag);
    D.large_el_truth_flag = to_bool_local(T.large_el_truth_flag);
    D.score_margin_if_available = NaN(height(T), 1);
    D.peak_margin_if_available = NaN(height(T), 1);
    D.failure_hypothesis = failure_h;
end

function C = confidence_group_local(conf, route, in_scope)
    C = string(conf);
    C(~in_scope) = "out_of_scope";
    C(route == "boundary_unreliable") = "boundary";
    C(route == "two_coarse_peaks_out_of_scope") = "out_of_scope";
    C(C == "") = "low";
end

function r = confidence_rank_local(conf_group)
    r = zeros(numel(conf_group), 1);
    r(conf_group == "high") = 3;
    r(conf_group == "medium") = 2;
    r(conf_group == "low" | conf_group == "boundary") = 1;
    r(conf_group == "out_of_scope") = 0;
end

function h = classify_failure_hypothesis_local(T, base, base_idx, row_idx, route_agree, output_equiv, output_relaxed, az_diff)
    mode = string(T.quant_mode(row_idx));
    d_route = string(base.route_used(base_idx));
    q_route = string(T.route_used(row_idx));
    if ~to_bool_scalar_local(T.in_scope_shared_center_flag(row_idx))
        h = "out_of_scope";
    elseif to_bool_scalar_local(T.weak_target_truth_flag(row_idx))
        h = "weak_target_case";
    elseif to_bool_scalar_local(T.anti_phase_truth_flag(row_idx))
        h = "near_antiphase_case";
    elseif d_route == "boundary_unreliable" || d_route == "low_confidence"
        h = "boundary_case";
    elseif ~route_agree && output_equiv
        h = "route_threshold_flip";
    elseif ~route_agree && output_relaxed
        h = "candidate_tie_flip";
    elseif contains(d_route, "pair") || contains(q_route, "pair") || contains(d_route, "2d") || contains(q_route, "2d")
        h = "2d_peak_swap";
    elseif contains(d_route, "rank1") || contains(q_route, "rank1")
        h = "rank1_objective_flat";
    elseif contains(mode, "coeff") || contains(mode, "combined")
        h = "quant_coeff_sensitive";
    elseif contains(mode, "ywork")
        h = "quant_ywork_sensitive";
    elseif az_diff > 0.05
        h = "unknown_large_output_diff";
    else
        h = "stable_or_equivalent";
    end
end

function G = build_group_summary_local(D, group_field, modes, scenario_in_scope_only)
    groups = unique(D.(group_field), 'stable');
    rows = {};
    for ig = 1:numel(groups)
        for im = 1:numel(modes)
            mode = modes(im);
            mask = D.(group_field) == groups(ig) & D.quant_mode == mode;
            if scenario_in_scope_only || group_field ~= "double_route"
                eval_mask = mask & D.in_scope_shared_center_flag;
            else
                eval_mask = mask;
            end
            rows{end+1, 1} = make_group_row_local(D, mask, eval_mask, group_field, groups(ig), mode); %#ok<AGROW>
        end
    end
    G = struct2table([rows{:}]);
end

function row = make_group_row_local(D, raw_mask, eval_mask, group_field, group_value, mode)
    changed = eval_mask & ~D.route_agreement;
    row = struct();
    row.(char(group_field)) = string(group_value);
    row.quant_mode = string(mode);
    row.trial_count = sum(raw_mask);
    row.in_scope_trial_count = sum(raw_mask & D.in_scope_shared_center_flag);
    row.eval_count = sum(eval_mask);
    row.route_agreement_vs_double = mean_bool_or_nan_local(D.route_agreement(eval_mask));
    row.confidence_agreement_vs_double = mean_bool_or_nan_local(D.confidence_agreement(eval_mask));
    row.output_equivalent_rate = mean_bool_or_nan_local(D.output_equivalent(eval_mask));
    row.output_equivalent_strict_rate = mean_bool_or_nan_local(D.output_equivalent_strict(eval_mask));
    row.output_equivalent_relaxed_rate = mean_bool_or_nan_local(D.output_equivalent_relaxed(eval_mask));
    row.success_gap_vs_double = mean(double(D.quant_success(eval_mask)), 'omitnan') - mean(double(D.double_success(eval_mask)), 'omitnan');
    row.false_high_rate = mean_bool_or_nan_local(D.false_high(eval_mask));
    row.boundary_missed_rate = mean_bool_or_nan_local(D.boundary_missed(eval_mask));
    row.max_az_diff = max_or_nan_local(D.az_diff(eval_mask));
    row.mean_abs_az_diff = mean(D.az_diff(eval_mask), 'omitnan');
    row.max_el_diff = max_or_nan_local(D.el_diff(eval_mask));
    row.mean_abs_el_diff = mean(D.el_diff(eval_mask), 'omitnan');
    row.changed_route_count = sum(changed);
    row.changed_confidence_count = sum(eval_mask & ~D.confidence_agreement);
    row.dominant_changed_from_route = dominant_string_local(D.double_route(changed));
    row.dominant_changed_to_route = dominant_string_local(D.quant_route(changed));
    row.dominant_failure_hypothesis = dominant_string_local(D.failure_hypothesis(eval_mask & (D.az_diff > 0.05 | ~D.route_agreement)));
    row.mean_ywork_snr_quant_db = mean(D.ywork_snr_quant_db(eval_mask), 'omitnan');
    row.mean_steering_rel_err_aligned = mean(D.steering_rel_err_aligned(eval_mask), 'omitnan');
end

function S = build_source_summary_local(D)
    modes = ["float32_all", "coeff_int16_only", "ywork_int16_only", "combined_int16", "combined_int18", "combined_int24"];
    rows = cell(numel(modes), 1);
    for i = 1:numel(modes)
        mode = modes(i);
        mask = D.quant_mode == mode & D.in_scope_shared_center_flag;
        rows{i} = struct('quant_mode', mode, ...
            'trial_count', sum(mask), ...
            'route_agreement_vs_double', mean_bool_or_nan_local(D.route_agreement(mask)), ...
            'confidence_agreement_vs_double', mean_bool_or_nan_local(D.confidence_agreement(mask)), ...
            'output_equivalent_rate', mean_bool_or_nan_local(D.output_equivalent(mask)), ...
            'output_equivalent_strict_rate', mean_bool_or_nan_local(D.output_equivalent_strict(mask)), ...
            'output_equivalent_relaxed_rate', mean_bool_or_nan_local(D.output_equivalent_relaxed(mask)), ...
            'max_az_diff', max_or_nan_local(D.az_diff(mask)), ...
            'mean_abs_az_diff', mean(D.az_diff(mask), 'omitnan'), ...
            'max_el_diff', max_or_nan_local(D.el_diff(mask)), ...
            'success_gap_vs_double', mean(double(D.quant_success(mask)), 'omitnan') - mean(double(D.double_success(mask)), 'omitnan'), ...
            'false_high_rate', mean_bool_or_nan_local(D.false_high(mask)), ...
            'boundary_missed_rate', mean_bool_or_nan_local(D.boundary_missed(mask)), ...
            'mean_ywork_snr_quant_db', mean(D.ywork_snr_quant_db(mask), 'omitnan'), ...
            'max_ywork_clip_rate', max_or_nan_local(D.ywork_clip_rate(mask)), ...
            'mean_steering_rel_err_aligned', mean(D.steering_rel_err_aligned(mask), 'omitnan'), ...
            'max_steering_rel_err_aligned', max_or_nan_local(D.steering_rel_err_aligned(mask)), ...
            'route_changed_count', sum(mask & ~D.route_agreement), ...
            'output_not_equiv_count', sum(mask & ~D.output_equivalent), ...
            'dominant_failure_hypothesis', dominant_string_local(D.failure_hypothesis(mask & ~D.output_equivalent)));
    end
    S = struct2table([rows{:}]);
end

function W = build_worst_cases_local(D, topN)
    modes = unique(D.quant_mode(D.quant_mode ~= "double_baseline"), 'stable');
    rows = {};
    for im = 1:numel(modes)
        mask = D.quant_mode == modes(im) & D.in_scope_shared_center_flag;
        idx = find(mask);
        [~, ord] = sort(D.az_diff(idx), 'descend', 'MissingPlacement', 'last');
        idx = idx(ord(1:min(topN, numel(ord))));
        for k = 1:numel(idx)
            ii = idx(k);
            rows{end+1, 1} = struct( ...
                'trial_id', D.trial_id(ii), ...
                'scenario_name', D.scenario_name(ii), ...
                'SNR', D.SNR(ii), ...
                'mc', D.mc(ii), ...
                'quant_mode', D.quant_mode(ii), ...
                'double_route', D.double_route(ii), ...
                'quant_route', D.quant_route(ii), ...
                'double_confidence', D.double_confidence(ii), ...
                'quant_confidence', D.quant_confidence(ii), ...
                'double_success', D.double_success(ii), ...
                'quant_success', D.quant_success(ii), ...
                'double_az_est', D.double_az_est(ii), ...
                'quant_az_est', D.quant_az_est(ii), ...
                'az_diff', D.az_diff(ii), ...
                'double_el_est', D.double_el_est(ii), ...
                'quant_el_est', D.quant_el_est(ii), ...
                'el_diff', D.el_diff(ii), ...
                'true_az1', D.true_az1(ii), ...
                'true_az2', D.true_az2(ii), ...
                'true_el1', D.true_el1(ii), ...
                'true_el2', D.true_el2(ii), ...
                'frontend_state', D.frontend_state(ii), ...
                'coarse_peak_count', D.coarse_peak_count(ii), ...
                'in_scope_shared_center_flag', D.in_scope_shared_center_flag(ii), ...
                'low_confidence_double', D.low_confidence_double(ii), ...
                'boundary_double', D.boundary_double(ii), ...
                'ywork_snr_quant_db', D.ywork_snr_quant_db(ii), ...
                'steering_rel_err_aligned', D.steering_rel_err_aligned(ii), ...
                'score_margin_if_available', D.score_margin_if_available(ii), ...
                'peak_margin_if_available', D.peak_margin_if_available(ii), ...
                'failure_hypothesis', D.failure_hypothesis(ii)); %#ok<AGROW>
        end
    end
    W = struct2table([rows{:}]);
end

function R = build_recommendations_local(D, S, scenarioS, routeS, confS)
    coeff = S(S.quant_mode == "coeff_int16_only", :);
    ywork = S(S.quant_mode == "ywork_int16_only", :);
    comb16 = S(S.quant_mode == "combined_int16", :);
    comb24 = S(S.quant_mode == "combined_int24", :);
    false_any = any(D.false_high(D.in_scope_shared_center_flag));
    bm_any = any(D.boundary_missed(D.in_scope_shared_center_flag));
    high24 = D.quant_mode == "combined_int24" & D.double_confidence_group == "high" & D.in_scope_shared_center_flag;
    high24_equiv = mean_bool_or_nan_local(D.output_equivalent(high24));
    coeff_dominates = coeff.route_agreement_vs_double + 0.03 < ywork.route_agreement_vs_double;
    ywork_dominates = ywork.route_agreement_vs_double + 0.03 < coeff.route_agreement_vs_double;
    route_too_strict = comb24.route_agreement_vs_double < 0.98 && comb24.output_equivalent_rate >= 0.98 && ~false_any && ~bm_any;
    core_not_closed = high24_equiv < 0.99 || comb24.output_equivalent_rate < 0.98 || comb24.max_az_diff > 0.05;

    rows = {};
    if coeff_dominates
        rows{end+1, 1} = rec_row_local("coeff_dominant_sensitivity", ...
            sprintf('coeff_int16 route agreement %.3f < ywork_int16 %.3f; coeff/combined max az diff remains large.', coeff.route_agreement_vs_double, ywork.route_agreement_vs_double), ...
            "mixed_precision_coeff_high", ...
            "Validate Y_work int16 with int24/mixed route-specific steering/template coefficients.", 1); %#ok<AGROW>
    elseif ywork_dominates
        rows{end+1, 1} = rec_row_local("ywork_dominant_sensitivity", ...
            sprintf('ywork_int16 route agreement %.3f < coeff_int16 %.3f.', ywork.route_agreement_vs_double, coeff.route_agreement_vs_double), ...
            "improve_ywork_scaling", ...
            "Validate alternate block floating scales and int18/int24 Y_work.", 1); %#ok<AGROW>
    elseif comb16.route_agreement_vs_double < min(coeff.route_agreement_vs_double, ywork.route_agreement_vs_double)
        rows{end+1, 1} = rec_row_local("combined_error_boundary_flip", ...
            "combined_int16 route agreement is lower than separate coeff/ywork modes.", ...
            "combined_error_boundary_flip", ...
            "Validate mixed precision and margin-aware confidence on changed-route cases.", 1); %#ok<AGROW>
    end
    if route_too_strict
        rows{end+1, 1} = rec_row_local("route_label_vs_output_equivalence", ...
            sprintf('combined_int24 route agreement %.3f but output_equivalent %.3f.', comb24.route_agreement_vs_double, comb24.output_equivalent_rate), ...
            "route_agreement_too_strict", ...
            "Use output_equivalent + safety as pass criteria; keep route label as diagnostic.", 2); %#ok<AGROW>
    end
    if core_not_closed
        rows{end+1, 1} = rec_row_local("core_route_quantization_not_closed", ...
            sprintf('combined_int24 output_equivalent %.3f, high-conf equivalent %.3f, max az diff %.3f deg.', comb24.output_equivalent_rate, high24_equiv, comb24.max_az_diff), ...
            "mixed_precision_validation_before_fpga", ...
            "Do not enter FPGA kernel design; diagnose sensitive routes and candidate ties first.", 1); %#ok<AGROW>
    end
    if false_any || bm_any
        rows{end+1, 1} = rec_row_local("safety_regression", ...
            "false-high or boundary-missed occurred in a quantized mode.", ...
            "block_hardwareization", ...
            "Fix safety regression before any fixed-point continuation.", 0); %#ok<AGROW>
    else
        rows{end+1, 1} = rec_row_local("safety_preserved", ...
            "false-high=0 and boundary-missed=0 for all in-scope quantized modes.", ...
            "keep_safety_gate_unchanged", ...
            "Continue diagnostics without relaxing safety gates.", 3); %#ok<AGROW>
    end

    sensScenario = most_sensitive_group_local(scenarioS, "scenario_name", "combined_int24");
    sensRoute = most_sensitive_group_local(routeS, "double_route", "combined_int24");
    sensConf = most_sensitive_group_local(confS, "double_confidence_group", "combined_int24");
    rows{end+1, 1} = rec_row_local("sensitive_focus_set", ...
        sprintf('Most sensitive scenario=%s, route=%s, confidence=%s under combined_int24.', sensScenario, sensRoute, sensConf), ...
        "target_next_validation_on_sensitive_subset", ...
        "Run mixed-precision validation on the sensitive scenario/route/confidence subset first.", 2);
    R = struct2table([rows{:}]);
end

function row = rec_row_local(category, evidence, action, next_validation, priority)
    row = struct('diagnosis_category', string(category), 'evidence', string(evidence), ...
        'recommended_action', string(action), 'next_validation_needed', string(next_validation), ...
        'priority', priority);
end

function K = build_keypoints_local(D, S, scenarioS, routeS, confS, R)
    rows = {};
    base = D(D.quant_mode == "double_baseline", :);
    rows = add_kp_local(rows, 'total_trials_loaded', height(D), 'mode-expanded rows loaded from Step 8.9 trial CSV');
    rows = add_kp_local(rows, 'total_in_scope_trials', sum(base.in_scope_shared_center_flag), 'base in-scope trials');
    for mode = ["combined_int16", "combined_int18", "combined_int24"]
        sm = S(S.quant_mode == mode, :);
        rows = add_kp_local(rows, char(mode + "_route_agreement"), sm.route_agreement_vs_double, 'route agreement vs double');
        rows = add_kp_local(rows, char(mode + "_output_equivalent_rate"), sm.output_equivalent_rate, 'regular output equivalence rate');
    end
    sm16 = S(S.quant_mode == "combined_int16", :);
    sm24 = S(S.quant_mode == "combined_int24", :);
    rows = add_kp_local(rows, 'combined_int16_output_equivalent_strict_rate', sm16.output_equivalent_strict_rate, 'strict output equivalence rate');
    rows = add_kp_local(rows, 'combined_int24_output_equivalent_strict_rate', sm24.output_equivalent_strict_rate, 'strict output equivalence rate');
    high16 = high_conf_equiv_local(D, "combined_int16");
    high24 = high_conf_equiv_local(D, "combined_int24");
    high_note = 'double high-confidence regular equivalence';
    if isnan(high16) && isnan(high24)
        high_note = 'not applicable: no double high-confidence in-scope samples in Step 8.9';
    end
    rows = add_kp_local(rows, 'combined_int16_high_conf_output_equivalent_rate', high16, high_note);
    rows = add_kp_local(rows, 'combined_int24_high_conf_output_equivalent_rate', high24, high_note);
    coeff = S(S.quant_mode == "coeff_int16_only", :);
    ywork = S(S.quant_mode == "ywork_int16_only", :);
    rows = add_kp_local(rows, 'coeff_int16_route_agreement', coeff.route_agreement_vs_double, 'coeff-only int16 route agreement');
    rows = add_kp_local(rows, 'ywork_int16_route_agreement', ywork.route_agreement_vs_double, 'Y_work-only int16 route agreement');
    source = dominant_source_label_local(coeff, ywork);
    rows = add_kp_local(rows, 'coeff_vs_ywork_dominant_source', NaN, source);
    rows = add_kp_local(rows, 'worst_case_max_az_diff_int16', sm16.max_az_diff, 'combined_int16 max az diff');
    rows = add_kp_local(rows, 'worst_case_max_az_diff_int24', sm24.max_az_diff, 'combined_int24 max az diff');
    worst24 = D(D.quant_mode == "combined_int24" & D.in_scope_shared_center_flag, :);
    [~, iw] = max(worst24.az_diff);
    rows = add_kp_local(rows, 'worst_case_main_scenario', NaN, worst24.scenario_name(iw));
    rows = add_kp_local(rows, 'route_most_sensitive', NaN, most_sensitive_group_local(routeS, "double_route", "combined_int24"));
    rows = add_kp_local(rows, 'scenario_most_sensitive', NaN, most_sensitive_group_local(scenarioS, "scenario_name", "combined_int24"));
    rows = add_kp_local(rows, 'confidence_most_sensitive', NaN, most_sensitive_group_local(confS, "double_confidence_group", "combined_int24"));
    rows = add_kp_local(rows, 'false_high_any_mode', double(any(D.false_high(D.in_scope_shared_center_flag))), 'any in-scope false-high among all modes');
    rows = add_kp_local(rows, 'boundary_missed_any_mode', double(any(D.boundary_missed(D.in_scope_shared_center_flag))), 'any in-scope boundary-missed among all modes');
    primary_action = choose_primary_action_local(R);
    rows = add_kp_local(rows, 'recommended_action', NaN, primary_action);
    rows = add_kp_local(rows, 'next_step_recommendation', NaN, 'run Step 8.9C mixed-precision validation on coeff-high / route-sensitive subset');
    proceed_mixed = sm24.route_agreement_vs_double < 0.98 && sm24.output_equivalent_rate >= 0.90 && ...
        ~any(D.false_high(D.in_scope_shared_center_flag)) && ~any(D.boundary_missed(D.in_scope_shared_center_flag));
    proceed_fpga = sm24.output_equivalent_rate >= 0.98 && high_conf_equiv_local(D, "combined_int24") >= 0.99 && ...
        ~any(D.false_high(D.in_scope_shared_center_flag)) && ~any(D.boundary_missed(D.in_scope_shared_center_flag)) && sm24.max_az_diff <= 0.05;
    rows = add_kp_local(rows, 'proceed_to_mixed_precision_validation_flag', double(proceed_mixed), '1 means diagnose mixed precision next');
    rows = add_kp_local(rows, 'proceed_to_fpga_kernel_design_flag', double(proceed_fpga), '1 means hardware kernel design can start');
    K = cell2table(rows, 'VariableNames', {'keypoint', 'value', 'note'});
end

function val = high_conf_equiv_local(D, mode)
    mask = D.quant_mode == mode & D.in_scope_shared_center_flag & D.double_confidence_group == "high";
    val = mean_bool_or_nan_local(D.output_equivalent(mask));
end

function src = dominant_source_label_local(coeff, ywork)
    if coeff.route_agreement_vs_double + 0.03 < ywork.route_agreement_vs_double
        src = "coeff_int16_only_more_sensitive";
    elseif ywork.route_agreement_vs_double + 0.03 < coeff.route_agreement_vs_double
        src = "ywork_int16_only_more_sensitive";
    else
        src = "no_clear_single_source_or_combined_boundary_flip";
    end
end

function action = choose_primary_action_local(R)
    if any(R.recommended_action == "mixed_precision_coeff_high")
        action = "mixed_precision_coeff_high";
    elseif any(R.recommended_action == "mixed_precision_validation_before_fpga")
        action = "mixed_precision_validation_before_fpga";
    elseif any(R.recommended_action == "route_agreement_too_strict")
        action = "route_agreement_too_strict";
    else
        action = R.recommended_action(1);
    end
end

function group = most_sensitive_group_local(S, group_field, mode)
    mask = S.quant_mode == mode & S.eval_count > 0;
    X = S(mask, :);
    if isempty(X)
        group = "";
        return
    end
    score = (1 - X.output_equivalent_rate) + 0.5 * (1 - X.route_agreement_vs_double) + 0.1 * X.max_az_diff;
    [~, idx] = max(score);
    group = string(X.(group_field)(idx));
end

function plot_agreement_by_group_local(S, group_field, path_out)
    modes = ["coeff_int16_only", "ywork_int16_only", "combined_int16", "combined_int18", "combined_int24"];
    groups = unique(S.(group_field), 'stable');
    vals = NaN(numel(groups), numel(modes));
    for i = 1:numel(groups)
        for j = 1:numel(modes)
            idx = S.(group_field) == groups(i) & S.quant_mode == modes(j);
            if any(idx)
                vals(i, j) = S.output_equivalent_rate(find(idx, 1));
            end
        end
    end
    fig = figure('Visible', 'off', 'Position', [80, 80, 1180, 480]);
    bar(vals);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 25);
    ylabel('output equivalent rate');
    title(strrep(sprintf('Output equivalence by %s', group_field), '_', '\_'));
    legend(cellstr(modes), 'Interpreter', 'none', 'Location', 'eastoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_coeff_vs_ywork_sensitivity_local(S, path_out)
    modes = ["coeff_int16_only", "ywork_int16_only", "combined_int16"];
    T = S(ismember(S.quant_mode, modes), :);
    fig = figure('Visible', 'off', 'Position', [80, 80, 900, 420]);
    bar([T.route_agreement_vs_double, T.confidence_agreement_vs_double, T.output_equivalent_rate]);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(T), 'XTickLabel', cellstr(T.quant_mode), 'XTickLabelRotation', 15);
    ylabel('rate');
    title('Coeff-only vs Y\_work-only sensitivity');
    legend({'route agreement', 'confidence agreement', 'output equivalent'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_output_equivalent_vs_route_agreement_local(S, path_out)
    fig = figure('Visible', 'off', 'Position', [80, 80, 700, 520]);
    scatter(S.route_agreement_vs_double, S.output_equivalent_rate, 70, 'filled');
    text(S.route_agreement_vs_double + 0.003, S.output_equivalent_rate, cellstr(S.quant_mode), 'Interpreter', 'none');
    grid on;
    xlim([0.84, 1.01]);
    ylim([0.84, 1.01]);
    xlabel('route agreement vs double');
    ylabel('output equivalent rate');
    title('Route label agreement vs output equivalence');
    saveas(fig, path_out);
    close(fig);
end

function plot_az_diff_hist_by_mode_local(D, path_out)
    modes = ["coeff_int16_only", "ywork_int16_only", "combined_int16", "combined_int18", "combined_int24"];
    fig = figure('Visible', 'off', 'Position', [80, 80, 980, 440]);
    hold on;
    edges = 0:0.02:1.0;
    for i = 1:numel(modes)
        mask = D.quant_mode == modes(i) & D.in_scope_shared_center_flag;
        histogram(D.az_diff(mask), edges, 'DisplayStyle', 'stairs', 'LineWidth', 1.4);
    end
    hold off;
    grid on;
    xlabel('az diff vs double (deg)');
    ylabel('count');
    title('Azimuth difference histogram by quant mode');
    legend(cellstr(modes), 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_worst_case_scatter_local(D, path_out)
    modes = ["combined_int16", "combined_int18", "combined_int24"];
    fig = figure('Visible', 'off', 'Position', [80, 80, 980, 430]);
    hold on;
    for i = 1:numel(modes)
        mask = D.quant_mode == modes(i) & D.in_scope_shared_center_flag;
        scatter(D.trial_id(mask), D.az_diff(mask), 14, 'filled');
    end
    hold off;
    grid on;
    xlabel('base trial id');
    ylabel('az diff vs double (deg)');
    title('Worst-case azimuth sensitivity scatter');
    legend(cellstr(modes), 'Interpreter', 'none', 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_score_margin_proxy_local(D, path_out)
    modes = ["combined_int16", "combined_int18", "combined_int24"];
    vals = zeros(numel(modes), 2);
    for i = 1:numel(modes)
        m0 = D.quant_mode == modes(i) & D.in_scope_shared_center_flag & D.route_agreement;
        m1 = D.quant_mode == modes(i) & D.in_scope_shared_center_flag & ~D.route_agreement;
        vals(i, 1) = mean(D.az_diff(m0), 'omitnan');
        vals(i, 2) = mean(D.az_diff(m1), 'omitnan');
    end
    fig = figure('Visible', 'off', 'Position', [80, 80, 900, 420]);
    bar(vals);
    grid on;
    set(gca, 'XTick', 1:numel(modes), 'XTickLabel', cellstr(modes), 'XTickLabelRotation', 15);
    ylabel('mean az diff (deg)');
    title('Score-margin proxy: route-stable vs route-changed samples');
    legend({'route unchanged', 'route changed'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_quant_error_vs_route_change_local(D, path_out)
    mask = D.in_scope_shared_center_flag & D.quant_mode ~= "double_baseline";
    fig = figure('Visible', 'off', 'Position', [80, 80, 900, 480]);
    scatter(log10(D.steering_rel_err_aligned(mask) + eps), D.az_diff(mask), 16, double(~D.route_agreement(mask)), 'filled');
    grid on;
    xlabel('log10 steering rel err + eps');
    ylabel('az diff vs double (deg)');
    title('Quantization error vs route change');
    cb = colorbar;
    ylabel(cb, 'route changed flag');
    saveas(fig, path_out);
    close(fig);
end

function plot_recommended_action_summary_local(K, path_out)
    labels = ["mixed_precision", "fpga_design"];
    vals = [keypoint_value_local(K, 'proceed_to_mixed_precision_validation_flag'), ...
        keypoint_value_local(K, 'proceed_to_fpga_kernel_design_flag')];
    fig = figure('Visible', 'off', 'Position', [80, 80, 620, 360]);
    bar(vals);
    ylim([0, 1.1]);
    grid on;
    set(gca, 'XTick', 1:numel(labels), 'XTickLabel', cellstr(labels));
    ylabel('flag');
    title('Recommended action flags');
    saveas(fig, path_out);
    close(fig);
end

function write_record_doc_local(path_out, K, S, scenarioS, routeS, confS, worst, R, result_dir, targeted_rerun_used, targeted_rerun_reason)
    fid = fopen(path_out, 'w', 'n', 'UTF-8');
    cleaner = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.9B步 shared-center定点量化敏感性分解诊断记录\n\n');
    fprintf(fid, '本轮是第 8.9 negative / blocker validation 后的离线诊断步骤，目标是定位 `quantization_not_closed` 的来源和下一步改进方向。本轮不提高性能、不调阈值、不改第 8.7 算法、不改第 8.8 前端，也不覆盖第 8.9 原结果。\n\n');
    fprintf(fid, '- 结果目录：`%s`\n', result_dir);
    fprintf(fid, '- use_existing_step89_results=1\n');
    fprintf(fid, '- targeted_rerun_used=%d，原因：`%s`\n\n', targeted_rerun_used, targeted_rerun_reason);
    fprintf(fid, '## 1. 诊断方法\n\n');
    fprintf(fid, '脚本读取第 8.9 的 trial / summary / keypoints CSV，按原始行序恢复 base trial，并以 `double_baseline` 为基准对齐每个 quant mode。新增 `output_equivalent` 指标：az 差异不超过 0.05 deg、el 差异不超过 0.5 deg、无危险 confidence 升级、无 false-high、无 boundary-missed，则认为输出等价。strict 版本使用 0.03 deg / 0.3 deg 且只允许 confidence 降级；relaxed 版本使用 0.1 deg / 1.0 deg。\n\n');
    fprintf(fid, '第 8.9 trial 中未保存 rank1 best/second score、MUSIC peak margin 或 refocus sharpness，因此本轮 `score_margin_if_available` 和 `peak_margin_if_available` 保持 NaN；未使用 targeted rerun。图 `score_margin_vs_route_change.png` 使用 route_changed 与 az diff 的 proxy 展示边界翻转趋势。\n\n');
    fprintf(fid, '## 2. Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(K)
        fprintf(fid, '| %s | %.6g | %s |\n', K.keypoint(i), K.value(i), K.note(i));
    end
    fprintf(fid, '\n## 3. coeff-only vs Y_work-only\n\n');
    fprintf(fid, '| mode | route agreement | confidence agreement | output equivalent | max az diff | success gap |\n|---|---:|---:|---:|---:|---:|\n');
    for i = 1:height(S)
        fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.3f | %.4f |\n', S.quant_mode(i), ...
            S.route_agreement_vs_double(i), S.confidence_agreement_vs_double(i), ...
            S.output_equivalent_rate(i), S.max_az_diff(i), S.success_gap_vs_double(i));
    end
    fprintf(fid, '\n结论：`coeff_int16_only` 的 route agreement 明显低于 `ywork_int16_only`，说明当前敏感性主要由 steering/template/cache 系数量化触发；Y_work int16 block floating 本身相对更稳定。\n\n');
    fprintf(fid, '## 4. scenario / route / confidence 敏感性\n\n');
    fprintf(fid, '- 最敏感 scenario：`%s`\n', keypoint_note_local(K, 'scenario_most_sensitive'));
    fprintf(fid, '- 最敏感 route：`%s`\n', keypoint_note_local(K, 'route_most_sensitive'));
    fprintf(fid, '- 最敏感 confidence：`%s`\n\n', keypoint_note_local(K, 'confidence_most_sensitive'));
    fprintf(fid, '按 combined_int24 看，route agreement 低于 strict pass 门限，但 output-equivalent 能区分 route label 翻转和真实输出变化。若 route 改变但输出等价，则不应把 route label agreement 作为唯一硬门限；若 high-confidence / 主线场景输出也不等价，则必须继续定位。\n\n');
    fprintf(fid, '## 5. worst cases\n\n');
    fprintf(fid, 'worst_cases.csv 为每个 quant mode 保留 az diff 最大的前 50 个 in-scope 样本。最大差异样本多用于定位候选并列、rank1 objective flat 或 2D peak swap；弱目标和反相场景仍按边界场景处理，不解释为定点求解失败。\n\n');
    fprintf(fid, '| quant_mode | scenario | double route | quant route | az diff | hypothesis |\n|---|---|---|---|---:|---|\n');
    top = worst(1:min(12, height(worst)), :);
    for i = 1:height(top)
        fprintf(fid, '| %s | %s | %s | %s | %.3f | %s |\n', top.quant_mode(i), top.scenario_name(i), ...
            top.double_route(i), top.quant_route(i), top.az_diff(i), top.failure_hypothesis(i));
    end
    fprintf(fid, '\n## 6. Recommendations\n\n');
    fprintf(fid, '| category | evidence | action | next validation | priority |\n|---|---|---|---|---:|\n');
    for i = 1:height(R)
        fprintf(fid, '| %s | %s | %s | %s | %.0f |\n', R.diagnosis_category(i), R.evidence(i), ...
            R.recommended_action(i), R.next_validation_needed(i), R.priority(i));
    end
    fprintf(fid, '\n## 7. 判断\n\n');
    fprintf(fid, '本轮不建议进入 FPGA kernel design。推荐进入 Step 8.9C mixed-precision validation：优先验证 `Y_work int16 + coeff/template int24`，并对最敏感 route 增加 margin-aware confidence / candidate tie guard / output-equivalence 通过标准。\n\n');
end

function tf = to_bool_local(x)
    if islogical(x)
        tf = x;
    elseif isnumeric(x)
        tf = x ~= 0;
    else
        s = lower(string(x));
        tf = s == "true" | s == "1";
    end
end

function tf = to_bool_scalar_local(x)
    tf = to_bool_local(x);
    tf = tf(1);
end

function v = mean_bool_or_nan_local(x)
    if isempty(x)
        v = NaN;
    else
        v = mean(double(x), 'omitnan');
    end
end

function v = max_or_nan_local(x)
    x = x(isfinite(x));
    if isempty(x)
        v = NaN;
    else
        v = max(x);
    end
end

function s = dominant_string_local(vals)
    vals = string(vals);
    vals = vals(vals ~= "");
    if isempty(vals)
        s = "";
        return
    end
    u = unique(vals, 'stable');
    counts = zeros(numel(u), 1);
    for i = 1:numel(u)
        counts(i) = sum(vals == u(i));
    end
    [~, idx] = max(counts);
    s = u(idx);
end

function rows = add_kp_local(rows, key, value, note)
    rows(end+1, :) = {string(key), double(value), string(note)};
end

function value = keypoint_value_local(K, key)
    idx = K.keypoint == string(key);
    if any(idx)
        value = K.value(find(idx, 1));
    else
        value = NaN;
    end
end

function note = keypoint_note_local(K, key)
    idx = K.keypoint == string(key);
    if any(idx)
        note = K.note(find(idx, 1));
    else
        note = "";
    end
end

function log_msg_local(fid, fmt, varargin)
    msg = sprintf(fmt, varargin{:});
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    line = sprintf('[%s] %s', stamp, msg);
    fprintf('%s\n', line);
    if fid > 0
        fprintf(fid, '%s\n', line);
    end
end

function safe_fclose_local(fid)
    if fid > 0
        fclose(fid);
    end
end
