clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
step11_1_common_dir = fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common');
step11_2_dir = fullfile(project_dir, 'steps', 'step_11_2_beamspace_w_design');
step11_2_common_dir = fullfile(step11_2_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_3_stage2_topk_grid_sweep');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.3 Stage2 topK/grid sweep starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

cfg = sim_cfg();
arrInfo = arr_cyl(cfg, cfg.beam.azSectorCenter);
x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;
reg = 1e-10;

[W, w_info] = build_recommended_w_from_step11_2(step11_2_dir, cfg, arrInfo, ...
    'B', 7, 'Criterion', 'combined', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
scenarios = build_stage_scenarios_local();

topK_list = [1, 3, 5, 10];
coarse_az_step_list = [0.12, 0.16, 0.20];
coarse_el_step_list = [0.18, 0.24, 0.30];
fine_az_step_list = [0.04, 0.02];
fine_el_step_list = [0.06, 0.04];

trial_tables = {};
summary_tables = {};
cfg_records = {};
cfg_idx = 0;
tic;
for iTopK = 1:numel(topK_list)
    for iCaz = 1:numel(coarse_az_step_list)
        for iCel = 1:numel(coarse_el_step_list)
            for iFaz = 1:numel(fine_az_step_list)
                for iFel = 1:numel(fine_el_step_list)
                    cfg_idx = cfg_idx + 1;
                    cfg_eval = build_base_eval_cfg_local(x, y, z, lambda, phase_factor, phase_sign, cfg, w_info);
                    cfg_eval.Metkl = 10;
                    cfg_eval.L = 64;
                    cfg_eval.base_seed = 20260624;
                    cfg_eval.seed_offset = 0;
                    cfg_eval.center_bias = [0, 0];
                    cfg_eval.full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12);
                    cfg_eval.coarse_search_cfg = make_search_cfg_local(1.5, 1.2, coarse_az_step_list(iCaz), coarse_el_step_list(iCel));
                    cfg_eval.refine_cfg = make_refine_cfg_local(0.16, 0.24, fine_az_step_list(iFaz), fine_el_step_list(iFel));
                    cfg_eval.topK = topK_list(iTopK);
                    cfg_eval.search_methods = {'full_fine','coarse_to_fine'};

                    log_lines = append_log_local(log_lines, ...
                        'Sweep %d: topK=%d, coarse=[%.2f %.2f], fine=[%.2f %.2f]', ...
                        cfg_idx, cfg_eval.topK, cfg_eval.coarse_search_cfg.az_step, cfg_eval.coarse_search_cfg.el_step, ...
                        cfg_eval.refine_cfg.fine_az_step, cfg_eval.refine_cfg.fine_el_step);
                    [trial_now, summary_now] = evaluate_search_acceleration_backend(W, scenarios, cfg_eval);
                    trial_tables{end + 1, 1} = trial_now; %#ok<SAGROW>
                    summary_tables{end + 1, 1} = summary_now; %#ok<SAGROW>
                    cfg_records{end + 1, 1} = cfg_eval; %#ok<SAGROW>
                    log_lines = append_log_local(log_lines, '  rows: trial=%d, summary=%d, elapsed %.2f s', ...
                        height(trial_now), height(summary_now), toc);
                end
            end
        end
    end
end

trial_table = vertcat(trial_tables{:});
summary_table = vertcat(summary_tables{:});
[keypoint_rows, keypoints] = summarize_search_acceleration_keypoints(summary_table, 'stage2');
keypoint_table = struct2table(keypoint_rows);
plot_paths = plot_search_acceleration_results(summary_table, result_dir, 'step11_3_stage2');

trial_csv = fullfile(result_dir, 'step11_3_stage2_trial.csv');
summary_csv = fullfile(result_dir, 'step11_3_stage2_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_3_stage2_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_3_stage2_result.mat');
log_path = fullfile(result_dir, 'step11_3_stage2.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
params = struct();
params.topK_list = topK_list;
params.coarse_az_step_list = coarse_az_step_list;
params.coarse_el_step_list = coarse_el_step_list;
params.fine_az_step_list = fine_az_step_list;
params.fine_el_step_list = fine_el_step_list;
params.scenarios = scenarios;
params.w_info = w_info;
save(mat_path, 'params', 'W', 'w_info', 'cfg_records', 'trial_table', 'summary_table', ...
    'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Sweep finished: configs=%d, trial rows=%d, summary rows=%d', ...
    cfg_idx, height(trial_table), height(summary_table));
log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_keypoints_to_log_local(log_lines, keypoints);
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function scenarios = build_stage_scenarios_local()
rows = [ ...
    make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30); ...
    make_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30); ...
    make_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30); ...
    make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30); ...
    make_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20)];
scenarios = struct2table(rows);
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end

function cfg_eval = build_base_eval_cfg_local(x, y, z, lambda, phase_factor, phase_sign, cfg, w_info)
cfg_eval = struct();
cfg_eval.x = x;
cfg_eval.y = y;
cfg_eval.z = z;
cfg_eval.lambda = lambda;
cfg_eval.phase_factor = phase_factor;
cfg_eval.phase_sign = phase_sign;
cfg_eval.az_center_true = cfg.beam.azSectorCenter;
cfg_eval.el_center_nominal = cfg.beam.elSectorCenter;
cfg_eval.el_center_offset = 0.31;
cfg_eval.whitening_mode = 'white';
cfg_eval.reg = 1e-10;
cfg_eval.az_tol_deg = 0.15;
cfg_eval.el_tol_deg = 0.20;
cfg_eval.el_sep_tol_deg = 0.25;
cfg_eval.W_method = sprintf('greedy_%s_B%d', w_info.criterion, w_info.B);
cfg_eval.B = w_info.B;
end

function search_cfg = make_search_cfg_local(az_half_width, el_half_width, az_step, el_step)
search_cfg = struct('az_half_width', az_half_width, 'el_half_width', el_half_width, ...
    'az_step', az_step, 'el_step', el_step, 'el_sep_index_list', [0, 1, 2], ...
    'search_orientations', [1, -1]);
end

function refine_cfg = make_refine_cfg_local(local_az_half_width, local_el_half_width, fine_az_step, fine_el_step)
refine_cfg = struct('local_az_half_width', local_az_half_width, 'local_el_half_width', local_el_half_width, ...
    'fine_az_step', fine_az_step, 'fine_el_step', fine_el_step, ...
    'el_sep_index_list', [0, 1, 2], 'search_orientations', [1, -1]);
end

function log_lines = append_keypoints_to_log_local(log_lines, keypoints)
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
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage2_topk_grid_sweep:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
