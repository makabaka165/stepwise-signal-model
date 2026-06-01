% Step 09 supplementary experiment runner.
% Purpose: run smoke validation, quick formal MC, quick ablation, and Step87 check.
% Run mode: default quick; set STEP09_MC_MODE=quick|formal|stress to override MC stages.
% Output directory: per-experiment result dirs plus results_step09_supplementary_overview.csv.
% Main algorithm change: none; this script orchestrates validation only.

default_run_mode = 'quick';
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
addpath(fullfile(script_dir, 'main'));

run_mode = resolve_run_mode_local('STEP09_MC_MODE', default_run_mode);
rows = {};

t_start = tic;
try
    run_smoke_validation_local(script_dir);
    rows = add_result_row_local(rows, 'smoke_validation', 'completed', ...
        fullfile(script_dir, 'results'), "1", "none", toc(t_start));
catch ME
    rows = add_result_row_local(rows, 'smoke_validation', 'failed', ...
        fullfile(script_dir, 'results'), "0", failure_text_local(ME), toc(t_start));
end

t_start = tic;
try
    result = step09_experiment_utils('run_formal_mc', script_dir, run_mode);
    rows = add_result_struct_local(rows, result);
catch ME
    rows = add_result_row_local(rows, 'formal_mc', 'failed', ...
        fullfile(script_dir, 'results_step09_formal_mc'), "0", failure_text_local(ME), toc(t_start));
end

t_start = tic;
try
    result = step09_experiment_utils('run_ablation', script_dir, run_mode);
    rows = add_result_struct_local(rows, result);
catch ME
    rows = add_result_row_local(rows, 'ablation', 'failed', ...
        fullfile(script_dir, 'results_step09_ablation'), "0", failure_text_local(ME), toc(t_start));
end

t_start = tic;
try
    result = step09_experiment_utils('run_consistency', script_dir, run_mode);
    rows = add_result_struct_local(rows, result);
catch ME
    rows = add_result_row_local(rows, 'step09_vs_step87_consistency', 'failed', ...
        fullfile(script_dir, 'results_step09_vs_step87_consistency'), "0", failure_text_local(ME), toc(t_start));
end

overview_tbl = struct2table([rows{:}]);
overview_path = fullfile(script_dir, 'results_step09_supplementary_overview.csv');
writetable(overview_tbl, overview_path);
write_overview_report_local(fullfile(script_dir, 'docs', '13_SUPPLEMENTARY_EXPERIMENT_OVERVIEW.md'), ...
    overview_tbl, run_mode);

disp(overview_tbl);
fprintf('Supplementary overview written to: %s\n', overview_path);

function run_mode = resolve_run_mode_local(env_name, default_run_mode)
    env_value = strtrim(getenv(env_name));
    if isempty(env_value)
        run_mode = default_run_mode;
    else
        run_mode = lower(env_value);
    end
    valid_modes = {'quick', 'formal', 'stress'};
    assert(ismember(run_mode, valid_modes), ...
        'STEP09:InvalidRunMode', 'run_mode must be quick, formal, or stress.');
end

function run_smoke_validation_local(script_dir)
    run(fullfile(script_dir, 'run_final_shared_center_validation.m'));
end

function rows = add_result_struct_local(rows, result)
    rows = add_result_row_local(rows, result.experiment_name, result.status, ...
        result.result_dir, result.pass_flag, result.blocker_if_any, result.elapsed_sec);
end

function rows = add_result_row_local(rows, experiment_name, status, result_dir, pass_flag, blocker, elapsed_sec)
    rows{end+1, 1} = struct('experiment_name', string(experiment_name), ...
        'status', string(status), 'result_dir', string(result_dir), ...
        'pass_flag', string(pass_flag), 'blocker_if_any', string(blocker), ...
        'elapsed_sec', elapsed_sec);
end

function txt = failure_text_local(ME)
    if isempty(ME.identifier)
        txt = "matlab_error";
    else
        txt = string(ME.identifier);
    end
    if ~isempty(ME.message)
        txt = txt + ":" + string(ME.message);
    end
end

function write_overview_report_local(report_path, T, run_mode)
    fid = fopen(report_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Supplementary Experiment Overview\n\n');
    fprintf(fid, '- run_mode: `%s`\n- overview_csv: `../results_step09_supplementary_overview.csv`\n\n', run_mode);
    fprintf(fid, '| experiment_name | status | pass_flag | blocker_if_any | result_dir | elapsed_sec |\n');
    fprintf(fid, '|---|---|---:|---|---|---:|\n');
    for i = 1:height(T)
        fprintf(fid, '| `%s` | %s | %s | %s | `%s` | %.3f |\n', ...
            T.experiment_name(i), T.status(i), T.pass_flag(i), ...
            T.blocker_if_any(i), T.result_dir(i), T.elapsed_sec(i));
    end
    fprintf(fid, '\nFormal MC and ablation blockers are reported as validation evidence, not hidden by retuning. ');
    fprintf(fid, 'If the Step 8.7 route is not callable, the Step 09 formal MC remains the final statistical validation basis.\n');
end
