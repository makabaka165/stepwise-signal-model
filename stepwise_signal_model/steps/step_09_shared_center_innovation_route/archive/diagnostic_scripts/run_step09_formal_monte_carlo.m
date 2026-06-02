% Step 09 formal Monte Carlo validation.
% Purpose: validate shared_center_enhanced_doa() over reproducible synthetic cases.
% Run mode: default quick; set STEP09_MC_MODE=quick|formal|stress to override.
% Output directory: results_step09_formal_mc/.
% Main algorithm change: none; this script only calls the public Step 09 entry.

default_run_mode = 'quick';
archive_script_dir = fileparts(mfilename('fullpath'));
if isempty(archive_script_dir)
    archive_script_dir = pwd;
end
script_dir = fullfile(archive_script_dir, '..', '..');
addpath(fullfile(script_dir, 'main'));
addpath(fullfile(script_dir, 'archive', 'backend_attempts'));

run_mode = resolve_run_mode_local('STEP09_MC_MODE', default_run_mode);
result = step09_experiment_utils('run_formal_mc', script_dir, run_mode);
disp(result);

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
