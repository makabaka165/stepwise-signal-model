clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
step11_1_common_dir = fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common');
result_dir = fullfile(step_dir, 'results_step11_2_b_budget_strategy_tradeoff');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.2 Stage3 B-budget strategy tradeoff starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

cfg = sim_cfg();
arrInfo = arr_cyl(cfg, cfg.beam.azSectorCenter);
x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
N_elem = numel(x);
expected_N_elem = cfg.beam.subNaz * cfg.arr.Nel;
if N_elem ~= expected_N_elem
    error('run_stage3_b_budget_strategy_tradeoff:NelemMismatch', ...
        'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;
az_c = cfg.beam.azSectorCenter;
el_c = cfg.beam.elSectorCenter;
reg = 1e-10;

[W_pool, pool_info] = build_existing_2d_beam_pool(x, y, z, az_c, el_c, lambda, cfg, ...
    'Mode', 'legacy_or_fallback', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, ...
    'AzPoolOffsets', -2.4:0.4:2.4, 'ElPoolOffsets', -1.6:0.4:1.6);

az_patch = az_c + (-1.5:0.15:1.5);
el_patch = el_c + (-1.0:0.15:1.0);
[A_patch, patch_info] = build_local_patch_dictionary(x, y, z, az_patch, el_patch, lambda, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);

el_center_offset = 0.31;
pair_set = build_pair_set_local(az_c, el_c + el_center_offset, [0.83, 1.27], [0, 0.37, 0.67], [1, -1]);
B_list = [5, 7, 9, 11, 15, 19, 21, 25, 31];

opts = struct();
opts.phase_factor = phase_factor;
opts.phase_sign = phase_sign;
opts.random_seed = 20260617;
opts.include_random = true;
opts.random_repeats = 3;
opts.greedy_alpha = 1;
opts.greedy_beta = 1;
opts.greedy_gamma = 0.05;
opts.reg = reg;

log_lines = append_log_local(log_lines, 'W_pool mode=%s, M=%d, note=%s', pool_info.mode_used, pool_info.M, pool_info.note);
log_lines = append_log_local(log_lines, 'B_list=%s', mat2str(B_list));
log_lines = append_log_local(log_lines, 'A_patch: az [%g,%g] count=%d, el [%g,%g] count=%d', ...
    az_patch(1), az_patch(end), numel(az_patch), el_patch(1), el_patch(end), numel(el_patch));
log_lines = append_log_local(log_lines, 'pair_set rows=%d, el_center_offset=%.3f', size(pair_set, 1), el_center_offset);

tic;
[W_cases, diagnostics] = build_w_cases_for_b_budget_sweep(W_pool, pool_info, A_patch, pair_set, ...
    x, y, z, lambda, B_list, opts);
diagnostics_table = diagnostics.table;
log_lines = append_log_local(log_lines, 'Built W cases=%d, elapsed %.2f s', numel(W_cases), toc);
log_lines = append_log_local(log_lines, 'Methods=%s', strjoin(diagnostics.methods, ','));

scenario_table = build_scenario_table_local();
cfg_eval = struct();
cfg_eval.x = x;
cfg_eval.y = y;
cfg_eval.z = z;
cfg_eval.lambda = lambda;
cfg_eval.phase_factor = phase_factor;
cfg_eval.phase_sign = phase_sign;
cfg_eval.az_center_true = az_c;
cfg_eval.el_center_nominal = el_c;
cfg_eval.el_center_offset = el_center_offset;
cfg_eval.L = 64;
cfg_eval.Metkl = 3;
cfg_eval.az_search_half_width = 1.5;
cfg_eval.el_search_half_width = 1.2;
cfg_eval.az_grid_step_deg = 0.08;
cfg_eval.el_grid_step_deg = 0.12;
cfg_eval.el_sep_index_list = [0, 1, 2];
cfg_eval.search_orientations = [1, -1];
cfg_eval.az_tol_deg = 0.15;
cfg_eval.el_tol_deg = 0.20;
cfg_eval.el_sep_tol_deg = 0.25;
cfg_eval.reg = reg;
cfg_eval.base_seed = 20260617;

log_lines = append_log_local(log_lines, 'Scenario count=%d, Metkl=%d, L=%d', height(scenario_table), cfg_eval.Metkl, cfg_eval.L);
log_lines = append_log_local(log_lines, 'Total backend trials=%d', numel(W_cases) * height(scenario_table) * cfg_eval.Metkl);

tic;
[trial_table, summary_table] = evaluate_w_pair2d_backend(W_cases, scenario_table, cfg_eval);
log_lines = append_log_local(log_lines, 'Backend validation finished: trial rows=%d, elapsed %.2f s', height(trial_table), toc);

[keypoint_rows, keypoints] = summarize_b_budget_strategy_keypoints(summary_table, diagnostics_table);
keypoint_table = struct2table(keypoint_rows);
plot_paths = plot_b_budget_strategy_tradeoff(summary_table, diagnostics_table, result_dir);

trial_csv = fullfile(result_dir, 'step11_2_b_budget_trial.csv');
summary_csv = fullfile(result_dir, 'step11_2_b_budget_summary.csv');
diagnostics_csv = fullfile(result_dir, 'step11_2_b_budget_diagnostics.csv');
keypoints_csv = fullfile(result_dir, 'step11_2_b_budget_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_2_b_budget_result.mat');
log_path = fullfile(result_dir, 'step11_2_b_budget.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(diagnostics_table, diagnostics_csv);
writetable(keypoint_table, keypoints_csv);

params = struct();
params.B_list = B_list;
params.az_patch = az_patch;
params.el_patch = el_patch;
params.pair_set = pair_set;
params.el_center_offset = el_center_offset;
params.N_elem = N_elem;
params.lambda = lambda;
params.phase_factor = phase_factor;
params.phase_sign = phase_sign;
params.reg = reg;
params.cfg_eval = cfg_eval;
save(mat_path, 'params', 'pool_info', 'patch_info', 'scenario_table', 'W_cases', 'diagnostics', ...
    'diagnostics_table', 'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote diagnostics CSV: %s', diagnostics_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_log_local(log_lines, 'Keypoints:');
names = fieldnames(keypoints);
for iName = 1:numel(names)
    value = keypoints.(names{iName});
    if isnumeric(value) || islogical(value)
        log_lines = append_log_local(log_lines, '  %s = %.12g', names{iName}, double(value));
    else
        log_lines = append_log_local(log_lines, '  %s = %s', names{iName}, char(value));
    end
end
log_lines = append_log_local(log_lines, 'recommended_engineering_B=%.12g', double(keypoints.recommended_engineering_B));
log_lines = append_log_local(log_lines, 'recommended_high_performance_B=%.12g', double(keypoints.recommended_high_performance_B));
log_lines = append_log_local(log_lines, 'recommended_W_strategy=%s', char(keypoints.recommended_W_strategy));
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function pair_set = build_pair_set_local(az_c, el_c, az_sep_list, el_sep_list, orientation_list)
pair_set = zeros(numel(az_sep_list) * numel(el_sep_list) * numel(orientation_list), 4);
idx = 0;
for iAz = 1:numel(az_sep_list)
    az_sep = az_sep_list(iAz);
    az_pair = az_c + [-az_sep/2, az_sep/2];
    for iEl = 1:numel(el_sep_list)
        el_sep = el_sep_list(iEl);
        for iOri = 1:numel(orientation_list)
            orientation = orientation_list(iOri);
            if el_sep == 0 && orientation == -1
                continue;
            end
            idx = idx + 1;
            if orientation == 1
                el_pair = el_c + [-el_sep/2, el_sep/2];
            else
                el_pair = el_c + [el_sep/2, -el_sep/2];
            end
            pair_set(idx, :) = [az_pair(1), el_pair(1), az_pair(2), el_pair(2)];
        end
    end
end
pair_set = pair_set(1:idx, :);
end

function scenario_table = build_scenario_table_local()
rows = [ ...
    make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30); ...
    make_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30); ...
    make_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30); ...
    make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30); ...
    make_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20)];
scenario_table = struct2table(rows);
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
row = struct();
row.scenario_name = name;
row.rho = rho;
row.phase_deg = phase_deg;
row.beta = beta;
row.az_sep_deg = az_sep_deg;
row.el_sep_deg = el_sep_deg;
row.snr_db = snr_db;
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage3_b_budget_strategy_tradeoff:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end

