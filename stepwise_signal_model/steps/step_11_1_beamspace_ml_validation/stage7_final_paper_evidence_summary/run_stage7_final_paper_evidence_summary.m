clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_1_final_paper_evidence_summary');

addpath(common_dir);
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.1 Stage7 starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

evidence = collect_step11_1_evidence_tables(step_dir);
doc_paths = write_step11_1_final_docs(evidence, result_dir);
plot_paths = plot_step11_1_final_overview(evidence, result_dir);

stage_status_csv = fullfile(result_dir, 'step11_1_final_stage_status.csv');
key_metrics_csv = fullfile(result_dir, 'step11_1_final_key_metrics.csv');
recommendation_csv = fullfile(result_dir, 'step11_1_final_recommendation.csv');
mat_path = fullfile(result_dir, 'step11_1_final_evidence_result.mat');
log_path = fullfile(result_dir, 'step11_1_final_evidence.log');

writetable(evidence.stage_status_table, stage_status_csv);
writetable(evidence.final_key_metrics_table, key_metrics_csv);
recommendation_table = table(string(evidence.final_recommendation), string(strjoin(evidence.missing_files(:).', '; ')), ...
    'VariableNames', {'final_recommendation','missing_files'});
writetable(recommendation_table, recommendation_csv);
save(mat_path, 'evidence', 'doc_paths', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote stage status CSV: %s', stage_status_csv);
log_lines = append_log_local(log_lines, 'Wrote key metrics CSV: %s', key_metrics_csv);
log_lines = append_log_local(log_lines, 'Wrote recommendation CSV: %s', recommendation_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for idx = 1:numel(doc_paths)
    log_lines = append_log_local(log_lines, 'Wrote doc: %s', doc_paths{idx});
end
for idx = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{idx});
end
log_lines = append_log_local(log_lines, 'final_recommendation=%s', evidence.final_recommendation);
if isempty(evidence.missing_files)
    log_lines = append_log_local(log_lines, 'missing_files=none');
else
    log_lines = append_log_local(log_lines, 'missing_files=%s', strjoin(evidence.missing_files(:).', '; '));
end
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage7:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
