% Step09-vs-Step87 consistency check.
% Purpose: check whether the historical Step 8.7 route can be called and compared.
% Run mode: default quick; set STEP09_CONSISTENCY_MODE=quick|formal|stress to override.
% Output directory: results_step09_vs_step87_consistency/.
% Main algorithm change: none; this script only runs validation and comparison logic.

default_run_mode = 'quick';
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
addpath(fullfile(script_dir, 'main'));

run_mode = resolve_run_mode_local('STEP09_CONSISTENCY_MODE', default_run_mode);
result = step09_experiment_utils('run_consistency', script_dir, run_mode);
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
