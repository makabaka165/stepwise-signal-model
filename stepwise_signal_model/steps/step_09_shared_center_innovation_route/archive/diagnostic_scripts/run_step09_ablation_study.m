% Step 09 ablation study.
% Purpose: test the necessity of MUSIC, rank1 fallback, 2-D refinement, and rejector.
% Run mode: default quick; set STEP09_ABLATION_MODE=quick|formal|stress to override.
% Output directory: results_step09_ablation/.
% Main algorithm change: none; cfg switches preserve full Step 09 as default.

default_run_mode = 'quick';
archive_script_dir = fileparts(mfilename('fullpath'));
if isempty(archive_script_dir)
    archive_script_dir = pwd;
end
script_dir = fullfile(archive_script_dir, '..', '..');
addpath(fullfile(script_dir, 'main'));
addpath(fullfile(script_dir, 'archive', 'backend_attempts'));

run_mode = resolve_run_mode_local('STEP09_ABLATION_MODE', default_run_mode);
result = step09_experiment_utils('run_ablation', script_dir, run_mode);
disp(result);

function run_mode = resolve_run_mode_local(env_name, default_run_mode)
    env_value = strtrim(getenv(env_name));
    if isempty(env_value)
        env_value = strtrim(getenv('STEP09_MC_MODE'));
    end
    if isempty(env_value)
        run_mode = default_run_mode;
    else
        run_mode = lower(env_value);
    end
    valid_modes = {'quick', 'formal', 'stress'};
    assert(ismember(run_mode, valid_modes), ...
        'STEP09:InvalidRunMode', 'run_mode must be quick, formal, or stress.');
end
