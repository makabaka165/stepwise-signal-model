clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_3_final_search_acceleration_evidence_summary');

addpath(common_dir);

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Stage4 starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

evidence = collect_step11_3_search_evidence(step_dir);
log_lines = append_log_local(log_lines, 'final recommendation = %s', evidence.final_recommendation);
log_lines = append_log_local(log_lines, 'stage2 pass flag = %.12g', ...
    read_keypoint_numeric_local(evidence.stage2_keypoints, 'search_acceleration_pass_flag', NaN));
log_lines = append_log_local(log_lines, 'stage3 pass flag = %.12g', ...
    read_keypoint_numeric_local(evidence.stage3_keypoints, 'frontend_prior_robustness_pass_flag', NaN));

collected_files = list_collected_files_local(step_dir);
log_lines = append_log_local(log_lines, 'collected files:');
for idx = 1:numel(collected_files)
    status = 'present';
    if exist(collected_files{idx}, 'file') ~= 2
        status = 'missing';
    end
    log_lines = append_log_local(log_lines, '  [%s] %s', status, collected_files{idx});
end

log_lines = append_log_local(log_lines, 'missing files:');
if isempty(evidence.missing_files)
    log_lines = append_log_local(log_lines, '  none');
else
    for idx = 1:numel(evidence.missing_files)
        log_lines = append_log_local(log_lines, '  %s', evidence.missing_files{idx});
    end
end

stage_status_csv = fullfile(result_dir, 'step11_3_final_stage_status.csv');
key_metrics_csv = fullfile(result_dir, 'step11_3_final_key_metrics.csv');
recommendation_csv = fullfile(result_dir, 'step11_3_final_recommendation.csv');
writetable(evidence.final_stage_status_table, stage_status_csv);
writetable(evidence.final_key_metrics_table, key_metrics_csv);
writetable(evidence.final_recommendation_table, recommendation_csv);
log_lines = append_log_local(log_lines, 'Wrote CSV: %s', stage_status_csv);
log_lines = append_log_local(log_lines, 'Wrote CSV: %s', key_metrics_csv);
log_lines = append_log_local(log_lines, 'Wrote CSV: %s', recommendation_csv);

doc_paths = write_step11_3_final_docs(evidence, result_dir);
plot_paths = plot_step11_3_final_overview(evidence, result_dir);
log_lines = append_log_local(log_lines, 'written docs:');
for idx = 1:numel(doc_paths)
    log_lines = append_log_local(log_lines, '  %s', doc_paths{idx});
end
log_lines = append_log_local(log_lines, 'written plots:');
for idx = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, '  %s', plot_paths{idx});
end

mat_path = fullfile(result_dir, 'step11_3_final_search_acceleration_evidence_result.mat');
save(mat_path, 'evidence', 'doc_paths', 'plot_paths', 'collected_files');
log_lines = append_log_local(log_lines, 'Wrote MAT: %s', mat_path);

log_path = fullfile(result_dir, 'step11_3_final_search_acceleration_evidence.log');
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function files = list_collected_files_local(step_dir)
files = { ...
    fullfile(step_dir, 'results_step11_3_stage1_coarse_to_fine_sanity', 'step11_3_stage1_keypoints.csv'); ...
    fullfile(step_dir, 'results_step11_3_stage1_coarse_to_fine_sanity', 'step11_3_stage1_summary.csv'); ...
    fullfile(step_dir, 'results_step11_3_stage2_topk_grid_sweep', 'step11_3_stage2_keypoints.csv'); ...
    fullfile(step_dir, 'results_step11_3_stage2_topk_grid_sweep', 'step11_3_stage2_screening_summary.csv'); ...
    fullfile(step_dir, 'results_step11_3_stage2_topk_grid_sweep', 'step11_3_stage2_confirmation_summary.csv'); ...
    fullfile(step_dir, 'results_step11_3_stage2_topk_grid_sweep', 'step11_3_stage2_config_table.csv'); ...
    fullfile(step_dir, 'results_step11_3_stage3_frontend_prior_bias_robustness', 'step11_3_stage3_keypoints.csv'); ...
    fullfile(step_dir, 'results_step11_3_stage3_frontend_prior_bias_robustness', 'step11_3_stage3_summary.csv')};
end

function value = read_keypoint_numeric_local(T, key, fallback)
if isempty(T)
    value = fallback;
    return;
end
mask = strcmp(T.keypoint, string(key));
if ~any(mask)
    value = fallback;
    return;
end
value = str2double(T.value(find(mask, 1)));
if ~isfinite(value)
    value = fallback;
end
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage4_final_search_acceleration_evidence_summary:LogOpenFailed', ...
        'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
