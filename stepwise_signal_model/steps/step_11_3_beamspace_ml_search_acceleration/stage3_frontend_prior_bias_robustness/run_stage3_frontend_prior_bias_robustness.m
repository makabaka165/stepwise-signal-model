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
stage2_result_dir = fullfile(step_dir, 'results_step11_3_stage2_topk_grid_sweep');
result_dir = fullfile(step_dir, 'results_step11_3_stage3_frontend_prior_bias_robustness');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.3 Stage3 frontend-prior bias robustness starts');
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
[rec_cfg, rec_note] = load_stage2_recommendation_local(stage2_result_dir);
log_lines = append_log_local(log_lines, 'Stage2 recommendation source: %s', rec_note);
log_lines = append_log_local(log_lines, 'degree-based el_sep enabled for Stage3');
log_lines = append_log_local(log_lines, 'Recommended config: topK=%d, coarse=[%.3f %.3f], fine=[%.3f %.3f], local=[%.3f %.3f]', ...
    rec_cfg.topK, rec_cfg.coarse_az_step, rec_cfg.coarse_el_step, rec_cfg.fine_az_step, rec_cfg.fine_el_step, ...
    rec_cfg.local_az_half_width, rec_cfg.local_el_center_half_width);
log_lines = append_log_local(log_lines, 'Recommended coarse_el_sep_deg_list=%s', mat2str(rec_cfg.coarse_el_sep_deg_list));
log_lines = append_log_local(log_lines, 'Recommended fine_el_sep_deg_list=%s', mat2str(rec_cfg.fine_el_sep_deg_list));
log_lines = append_log_local(log_lines, 'Recommended config name: %s', rec_cfg.config_name);

center_bias_cases = [ ...
    0.0, 0.0; ...
    0.2, 0.0; ...
    0.0, 0.2; ...
    0.2, 0.2; ...
   -0.2, 0.0; ...
    0.0,-0.2];

trial_tables = cell(size(center_bias_cases, 1), 1);
summary_tables = cell(size(center_bias_cases, 1), 1);
tic;
for iBias = 1:size(center_bias_cases, 1)
    cfg_eval = build_base_eval_cfg_local(x, y, z, lambda, phase_factor, phase_sign, cfg, w_info);
    cfg_eval.Metkl = 10;
    cfg_eval.L = 64;
    cfg_eval.base_seed = 20260624;
    cfg_eval.seed_offset = 10000 * iBias;
    cfg_eval.center_bias = center_bias_cases(iBias, :);
    cfg_eval.full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, rec_cfg.full_el_sep_deg_list);
    cfg_eval.coarse_search_cfg = make_search_cfg_local(1.5, 1.2, ...
        rec_cfg.coarse_az_step, rec_cfg.coarse_el_step, rec_cfg.coarse_el_sep_deg_list);
    cfg_eval.refine_cfg = make_refine_cfg_local(rec_cfg.local_az_half_width, rec_cfg.local_el_center_half_width, ...
        rec_cfg.fine_az_step, rec_cfg.fine_el_step, rec_cfg.fine_el_sep_deg_list);
    cfg_eval.topK = rec_cfg.topK;
    cfg_eval.search_methods = {'full_fine','coarse_to_fine'};

    log_lines = append_log_local(log_lines, 'Bias case %d/%d: [%.2f %.2f]', ...
        iBias, size(center_bias_cases, 1), cfg_eval.center_bias(1), cfg_eval.center_bias(2));
    [trial_tables{iBias}, summary_tables{iBias}] = evaluate_search_acceleration_backend(W, scenarios, cfg_eval);
    log_lines = append_log_local(log_lines, '  rows: trial=%d, summary=%d, elapsed %.2f s', ...
        height(trial_tables{iBias}), height(summary_tables{iBias}), toc);
end

trial_table = vertcat(trial_tables{:});
summary_table = vertcat(summary_tables{:});
[keypoint_rows, keypoints] = summarize_search_acceleration_keypoints(summary_table, 'stage3');
keypoint_table = struct2table(keypoint_rows);
plot_paths = plot_search_acceleration_results(summary_table, result_dir, 'step11_3_stage3');

trial_csv = fullfile(result_dir, 'step11_3_stage3_trial.csv');
summary_csv = fullfile(result_dir, 'step11_3_stage3_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_3_stage3_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_3_stage3_result.mat');
log_path = fullfile(result_dir, 'step11_3_stage3.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
params = struct();
params.center_bias_cases = center_bias_cases;
params.rec_cfg = rec_cfg;
params.rec_note = rec_note;
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

function [rec_cfg, note] = load_stage2_recommendation_local(stage2_result_dir)
rec_cfg = struct();
rec_cfg.config_name = 'fallback_stage1_degree_based_default';
rec_cfg.topK = 10;
rec_cfg.coarse_az_step = 0.16;
rec_cfg.coarse_el_step = 0.24;
rec_cfg.fine_az_step = 0.04;
rec_cfg.fine_el_step = 0.06;
rec_cfg.local_az_half_width = 0.32;
rec_cfg.local_el_center_half_width = 0.48;
rec_cfg.full_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
rec_cfg.coarse_el_sep_deg_list = [0, 0.36, 0.48, 0.72];
rec_cfg.fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
note = 'fallback_stage1_conservative_default';
keypoints_csv = fullfile(stage2_result_dir, 'step11_3_stage2_keypoints.csv');
if exist(keypoints_csv, 'file') ~= 2
    return;
end
opts = detectImportOptions(keypoints_csv, 'TextType', 'string');
opts.DataLines = [2, Inf];
opts = setvartype(opts, {'keypoint','value'}, 'string');
T = readtable(keypoints_csv, opts);
pass_flag = read_keypoint_numeric_local(T, 'search_acceleration_pass_flag', 0);
if pass_flag ~= 1
    note = sprintf('fallback_stage1_default_stage2_not_passed_%s', keypoints_csv);
    return;
end
rec_cfg.config_name = read_keypoint_text_local(T, 'recommended_config_name', rec_cfg.config_name);
rec_cfg.topK = read_keypoint_numeric_local(T, 'recommended_topK', rec_cfg.topK);
rec_cfg.coarse_az_step = read_keypoint_numeric_local(T, 'recommended_coarse_az_step', rec_cfg.coarse_az_step);
rec_cfg.coarse_el_step = read_keypoint_numeric_local(T, 'recommended_coarse_el_step', rec_cfg.coarse_el_step);
rec_cfg.fine_az_step = read_keypoint_numeric_local(T, 'recommended_fine_az_step', rec_cfg.fine_az_step);
rec_cfg.fine_el_step = read_keypoint_numeric_local(T, 'recommended_fine_el_step', rec_cfg.fine_el_step);
rec_cfg.local_az_half_width = read_keypoint_numeric_local(T, 'recommended_local_az_half_width', rec_cfg.local_az_half_width);
rec_cfg.local_el_center_half_width = read_keypoint_numeric_local(T, 'recommended_local_el_center_half_width', ...
    rec_cfg.local_el_center_half_width);
rec_cfg.coarse_el_sep_deg_list = read_keypoint_list_local(T, 'recommended_coarse_el_sep_list_text', rec_cfg.coarse_el_sep_deg_list);
rec_cfg.fine_el_sep_deg_list = read_keypoint_list_local(T, 'recommended_fine_el_sep_list_text', rec_cfg.fine_el_sep_deg_list);
note = sprintf('loaded_from_%s', keypoints_csv);
end

function value = read_keypoint_numeric_local(T, key, fallback)
mask = strcmp(T.keypoint, string(key));
if ~any(mask)
    value = fallback;
    return;
end
raw = T.value(find(mask, 1));
if isnumeric(raw)
    value = raw;
else
    value = str2double(raw);
end
if ~isfinite(value)
    value = fallback;
end
end

function value = read_keypoint_text_local(T, key, fallback)
mask = strcmp(T.keypoint, string(key));
if ~any(mask)
    value = fallback;
    return;
end
value = char(T.value(find(mask, 1)));
if isempty(value)
    value = fallback;
end
end

function values = read_keypoint_list_local(T, key, fallback)
mask = strcmp(T.keypoint, string(key));
if ~any(mask)
    values = fallback;
    return;
end
raw = char(T.value(find(mask, 1)));
raw = regexprep(raw, '[\[\]]', '');
parts = regexp(strtrim(raw), '[,\s]+', 'split');
parts = parts(~cellfun(@isempty, parts));
values = str2double(parts);
if isempty(values) || any(~isfinite(values))
    values = fallback;
end
end

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

function search_cfg = make_search_cfg_local(az_half_width, el_half_width, az_step, el_step, el_sep_deg_list)
search_cfg = struct('az_half_width', az_half_width, 'el_half_width', el_half_width, ...
    'az_step', az_step, 'el_step', el_step, 'el_sep_deg_list', el_sep_deg_list, ...
    'search_orientations', [1, -1]);
end

function refine_cfg = make_refine_cfg_local(local_az_half_width, local_el_center_half_width, fine_az_step, fine_el_step, fine_el_sep_deg_list)
refine_cfg = struct('local_az_half_width', local_az_half_width, 'local_el_center_half_width', local_el_center_half_width, ...
    'fine_az_step', fine_az_step, 'fine_el_step', fine_el_step, ...
    'fine_el_sep_deg_list', fine_el_sep_deg_list, 'search_orientations', [1, -1]);
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
    error('run_stage3_frontend_prior_bias_robustness:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
