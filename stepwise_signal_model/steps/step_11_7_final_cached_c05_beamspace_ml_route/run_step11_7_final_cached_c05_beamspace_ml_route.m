clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = script_dir;
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_7_final_cached_c05_beamspace_ml_route');

addpath(fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_2_beamspace_w_design', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_3_beamspace_ml_search_acceleration', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_6_shared_center_rotatable_beamspace_manifold_cache', 'common'));
addpath(common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

rng(20260609, 'twister');
log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.7 final cached C05 beamspace ML route starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);
log_lines = append_log_local(log_lines, 'Step11.7 is integration/packaging, not a new algorithm.');
log_lines = append_log_local(log_lines, 'Truth is used only for final evaluation metrics.');

try
    [context, context_metadata] = build_step11_7_runtime_context(project_dir, result_dir, 'DefaultCenterAz', 0);
    context_metadata_table = struct2table(context_metadata);
    log_lines = append_log_local(log_lines, 'Context ready: W=%s, cache_source=%s, cache_memory=%.6f MB', ...
        context.W_method, context.cache_source, context.cache.cache_memory_MB);

    scenarios = build_scenarios_local();
    common_params = build_common_params_local(context);

    [stage1_trial_table, stage1_summary_table] = evaluate_step11_7_interface_smoke(context);
    log_lines = append_log_local(log_lines, 'Stage1 interface smoke pass=%d', stage1_summary_table.interface_smoke_pass_flag(1));

    stage2_params = common_params;
    stage2_params.center_az_list = [0, 8, 15, 30];
    [stage2_trial_table, stage2_summary_table] = evaluate_step11_7_cached_vs_direct_consistency(context, scenarios, stage2_params);
    log_lines = append_log_local(log_lines, 'Stage2 cached/direct pass=%d, same_estimate=%.6f, cache_miss=%g', ...
        stage2_summary_table.cached_direct_consistency_pass_flag(1), stage2_summary_table.same_estimate_rate(1), ...
        stage2_summary_table.cache_miss_count(1));

    stage3_params = common_params;
    stage3_params.center_az = 0;
    [stage3_trial_table, stage3_summary_table] = evaluate_step11_7_frontend_prior_bias_recheck(context, scenarios, stage3_params);
    log_lines = append_log_local(log_lines, 'Stage3 frontend bias pass=%d, max_success_drop=%.6f', ...
        stage3_summary_table.frontend_prior_bias_recheck_pass_flag(1), stage3_summary_table.max_success_drop_vs_zero(1));

    [stage4_trial_table, stage4_summary_table] = evaluate_step11_7_cache_fallback_and_oos(context);
    log_lines = append_log_local(log_lines, 'Stage4 cache fallback pass=%d', stage4_summary_table.cache_fallback_behavior_pass_flag(1));

    stage5_params = common_params;
    stage5_params.center_az_list = [0, 8, 15];
    stage5_params.repeat_runtime = 3;
    [stage5_trial_table, stage5_summary_table] = evaluate_step11_7_runtime_packaging(context, scenarios, stage5_params);
    log_lines = append_log_local(log_lines, 'Stage5 runtime pass=%d, median_reduction=%.6f', ...
        stage5_summary_table.runtime_packaging_pass_flag(1), stage5_summary_table.median_runtime_reduction_ratio(1));

    [keypoint_table, keypoints, final_recommendation_table] = summarize_step11_7_keypoints(stage1_summary_table, ...
        stage2_summary_table, stage3_summary_table, stage4_summary_table, stage5_summary_table);
    log_lines = append_log_local(log_lines, 'Final recommendation: %s', keypoints.step11_7_recommendation);

    write_csv_local(result_dir, stage1_trial_table, stage2_trial_table, stage2_summary_table, stage3_trial_table, ...
        stage3_summary_table, stage4_trial_table, stage4_summary_table, stage5_trial_table, stage5_summary_table, ...
        context_metadata_table, keypoint_table, final_recommendation_table);
    plot_paths = plot_step11_7_results(stage1_trial_table, stage2_trial_table, stage3_trial_table, stage4_trial_table, ...
        stage5_trial_table, result_dir);
    doc_paths = write_step11_7_docs(result_dir, keypoints, stage1_summary_table, stage2_summary_table, ...
        stage3_summary_table, stage4_summary_table, stage5_summary_table);

    cache = context.cache;
    W = context.W;
    params = struct('common_params', common_params, 'stage2_params', stage2_params, 'stage3_params', stage3_params, 'stage5_params', stage5_params);
    mat_path = fullfile(result_dir, 'step11_7_result.mat');
    save(mat_path, 'context', 'cache', 'W', 'stage1_trial_table', 'stage1_summary_table', ...
        'stage2_trial_table', 'stage2_summary_table', 'stage3_trial_table', 'stage3_summary_table', ...
        'stage4_trial_table', 'stage4_summary_table', 'stage5_trial_table', 'stage5_summary_table', ...
        'context_metadata_table', 'keypoint_table', 'keypoints', 'final_recommendation_table', ...
        'params', 'scenarios', 'plot_paths', 'doc_paths');

    log_lines = append_log_local(log_lines, 'Wrote MAT: %s', mat_path);
    for idx = 1:numel(plot_paths)
        log_lines = append_log_local(log_lines, 'Wrote PNG: %s', plot_paths{idx});
    end
    for idx = 1:numel(doc_paths)
        log_lines = append_log_local(log_lines, 'Wrote Markdown: %s', doc_paths{idx});
    end
    log_lines = append_keypoints_local(log_lines, keypoints);
    write_log_local(fullfile(result_dir, 'step11_7.log'), log_lines);
    fprintf('Step11.7 complete. Log written: %s\n', fullfile(result_dir, 'step11_7.log'));
catch ME
    log_lines = append_log_local(log_lines, 'ERROR: %s', ME.message);
    for idx = 1:numel(ME.stack)
        log_lines = append_log_local(log_lines, '  at %s:%d', ME.stack(idx).file, ME.stack(idx).line);
    end
    write_log_local(fullfile(result_dir, 'step11_7.log'), log_lines);
    rethrow(ME);
end

function params = build_common_params_local(context)
%BUILD_COMMON_PARAMS_LOCAL Build shared Step11.7 evaluation parameters.
params = struct();
params.Metkl = 10;
params.L = context.L_default;
params.repeat_runtime = 3;
params.el_center_nominal = context.el_center_nominal;
params.az_tol_deg = 0.15;
params.el_tol_deg = 0.20;
params.el_sep_tol_deg = 0.25;
end

function scenarios = build_scenarios_local()
%BUILD_SCENARIOS_LOCAL Return Step11 representative scenarios.
rows = [ ...
    make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30); ...
    make_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30); ...
    make_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30); ...
    make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30); ...
    make_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20)];
scenarios = struct2table(rows);
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
%MAKE_SCENARIO_LOCAL Create one scenario row.
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end

function write_csv_local(result_dir, stage1_trial_table, stage2_trial_table, stage2_summary_table, stage3_trial_table, ...
    stage3_summary_table, stage4_trial_table, stage4_summary_table, stage5_trial_table, stage5_summary_table, ...
    context_metadata_table, keypoint_table, final_recommendation_table)
%WRITE_CSV_LOCAL Write all required Step11.7 CSV files.
writetable(stage1_trial_table, fullfile(result_dir, 'step11_7_stage1_interface_smoke.csv'));
writetable(stage2_trial_table, fullfile(result_dir, 'step11_7_stage2_cached_direct_consistency_trial.csv'));
writetable(stage2_summary_table, fullfile(result_dir, 'step11_7_stage2_cached_direct_consistency_summary.csv'));
writetable(stage3_trial_table, fullfile(result_dir, 'step11_7_stage3_frontend_bias_trial.csv'));
writetable(stage3_summary_table, fullfile(result_dir, 'step11_7_stage3_frontend_bias_summary.csv'));
writetable(stage4_trial_table, fullfile(result_dir, 'step11_7_stage4_cache_fallback_trial.csv'));
writetable(stage4_summary_table, fullfile(result_dir, 'step11_7_stage4_cache_fallback_summary.csv'));
writetable(stage5_trial_table, fullfile(result_dir, 'step11_7_stage5_runtime_trial.csv'));
writetable(stage5_summary_table, fullfile(result_dir, 'step11_7_stage5_runtime_summary.csv'));
writetable(context_metadata_table, fullfile(result_dir, 'step11_7_context_metadata.csv'));
writetable(keypoint_table, fullfile(result_dir, 'step11_7_keypoints.csv'));
writetable(final_recommendation_table, fullfile(result_dir, 'step11_7_final_recommendation.csv'));
end

function log_lines = append_log_local(log_lines, fmt, varargin)
%APPEND_LOG_LOCAL Append timestamped log line.
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
if isempty(varargin)
    line = fmt;
else
    line = sprintf(fmt, varargin{:});
end
log_lines{end + 1, 1} = sprintf('[%s] %s', timestamp, line);
end

function log_lines = append_keypoints_local(log_lines, keypoints)
%APPEND_KEYPOINTS_LOCAL Append keypoint fields to log.
log_lines = append_log_local(log_lines, 'Keypoints:');
names = fieldnames(keypoints);
for idx = 1:numel(names)
    value = keypoints.(names{idx});
    if isnumeric(value) || islogical(value)
        log_lines = append_log_local(log_lines, '  %s = %.12g', names{idx}, double(value));
    else
        log_lines = append_log_local(log_lines, '  %s = %s', names{idx}, char(value));
    end
end
end

function write_log_local(log_path, log_lines)
%WRITE_LOG_LOCAL Write UTF-8 log file.
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_step11_7:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
