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
result_dir = fullfile(step_dir, 'results_step11_3_stage1_coarse_to_fine_sanity');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.3 Stage1 coarse-to-fine sanity starts');
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
log_lines = append_log_local(log_lines, 'Using W=%s, B=%d, projection_loss=%.6g, max_corr=%.6g, cond_WHW=%.6g', ...
    w_info.note, w_info.B, w_info.projection_loss, w_info.max_corr, w_info.cond_WHW);

scenarios = build_stage_scenarios_local();

cfg_eval = build_base_eval_cfg_local(x, y, z, lambda, phase_factor, phase_sign, cfg, w_info);
cfg_eval.Metkl = 5;
cfg_eval.L = 64;
cfg_eval.base_seed = 20260624;
cfg_eval.center_bias = [0, 0];
full_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
coarse_el_sep_deg_list = [0, 0.36, 0.48, 0.72];
fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
cfg_eval.full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, full_el_sep_deg_list);
cfg_eval.coarse_search_cfg = make_search_cfg_local(1.5, 1.2, 0.16, 0.24, coarse_el_sep_deg_list);
cfg_eval.refine_cfg = make_refine_cfg_local(0.32, 0.48, 0.04, 0.06, fine_el_sep_deg_list);
cfg_eval.topK = 10;
cfg_eval.search_methods = {'full_fine','coarse_only','coarse_to_fine'};

log_lines = append_log_local(log_lines, 'Scenarios=%d, Metkl=%d, L=%d, base_seed=%d', ...
    height(scenarios), cfg_eval.Metkl, cfg_eval.L, cfg_eval.base_seed);
log_lines = append_log_local(log_lines, 'Full fine steps: az=%.3f, el=%.3f', ...
    cfg_eval.full_search_cfg.az_step, cfg_eval.full_search_cfg.el_step);
log_lines = append_log_local(log_lines, 'degree-based el_sep enabled');
log_lines = append_log_local(log_lines, 'old index-based el_sep no longer used in Stage1');
log_lines = append_log_local(log_lines, 'Full el_sep_deg_list=%s', mat2str(cfg_eval.full_search_cfg.el_sep_deg_list));
log_lines = append_log_local(log_lines, 'Coarse el_sep_deg_list=%s', mat2str(cfg_eval.coarse_search_cfg.el_sep_deg_list));
log_lines = append_log_local(log_lines, 'Fine el_sep_deg_list=%s', mat2str(cfg_eval.refine_cfg.fine_el_sep_deg_list));
log_lines = append_log_local(log_lines, 'Coarse steps: az=%.3f, el=%.3f, topK=%d', ...
    cfg_eval.coarse_search_cfg.az_step, cfg_eval.coarse_search_cfg.el_step, cfg_eval.topK);
log_lines = append_log_local(log_lines, 'Refine steps: az=%.3f, el=%.3f, local half=[%.3f %.3f]', ...
    cfg_eval.refine_cfg.fine_az_step, cfg_eval.refine_cfg.fine_el_step, ...
    cfg_eval.refine_cfg.local_az_half_width, cfg_eval.refine_cfg.local_el_center_half_width);

tic;
[trial_table, summary_table] = evaluate_search_acceleration_backend(W, scenarios, cfg_eval);
log_lines = append_log_local(log_lines, 'Evaluation finished: trial rows=%d, summary rows=%d, elapsed %.2f s', ...
    height(trial_table), height(summary_table), toc);

[keypoint_rows, keypoints] = summarize_search_acceleration_keypoints(summary_table, 'stage1');
keypoint_table = struct2table(keypoint_rows);
plot_paths = plot_search_acceleration_results(summary_table, result_dir, 'step11_3_stage1');

trial_csv = fullfile(result_dir, 'step11_3_stage1_trial.csv');
summary_csv = fullfile(result_dir, 'step11_3_stage1_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_3_stage1_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_3_stage1_result.mat');
log_path = fullfile(result_dir, 'step11_3_stage1.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);

params = struct();
params.cfg_eval = cfg_eval;
params.scenarios = scenarios;
params.w_info = w_info;
save(mat_path, 'params', 'W', 'w_info', 'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'plot_paths');

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
row = struct();
row.scenario_name = name;
row.rho = rho;
row.phase_deg = phase_deg;
row.beta = beta;
row.az_sep_deg = az_sep_deg;
row.el_sep_deg = el_sep_deg;
row.snr_db = snr_db;
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

function search_cfg = make_search_cfg_local(az_half_width, el_half_width, az_step, el_step, el_sep_deg_list)
search_cfg = struct();
search_cfg.az_half_width = az_half_width;
search_cfg.el_half_width = el_half_width;
search_cfg.az_step = az_step;
search_cfg.el_step = el_step;
search_cfg.el_sep_deg_list = el_sep_deg_list;
search_cfg.search_orientations = [1, -1];
end

function refine_cfg = make_refine_cfg_local(local_az_half_width, local_el_center_half_width, fine_az_step, fine_el_step, fine_el_sep_deg_list)
refine_cfg = struct();
refine_cfg.local_az_half_width = local_az_half_width;
refine_cfg.local_el_center_half_width = local_el_center_half_width;
refine_cfg.fine_az_step = fine_az_step;
refine_cfg.fine_el_step = fine_el_step;
refine_cfg.fine_el_sep_deg_list = fine_el_sep_deg_list;
refine_cfg.search_orientations = [1, -1];
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
    error('run_stage1_coarse_to_fine_sanity:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
