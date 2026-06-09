clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = script_dir;
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
step11_1_common_dir = fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common');
step11_2_dir = fullfile(project_dir, 'steps', 'step_11_2_beamspace_w_design');
step11_2_common_dir = fullfile(step11_2_dir, 'common');
step11_3_common_dir = fullfile(project_dir, 'steps', 'step_11_3_beamspace_ml_search_acceleration', 'common');
result_dir = fullfile(step_dir, 'results_step11_5_likelihood_uncertainty_adaptive_search');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(step11_3_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

rng(20260609, 'twister');
log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.5 Likelihood-Uncertainty-Aware Adaptive TopK-Window Beamspace ML Search starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);
log_lines = append_log_local(log_lines, 'Fixed backend: Step11.3 controlled pair2d beamspace DML');
log_lines = append_log_local(log_lines, 'Fixed W: Step11.2 greedy_combined_B7');
log_lines = append_log_local(log_lines, 'Truth is used only for final evaluation fields.');

try
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
    log_lines = append_log_local(log_lines, 'W method = greedy_%s_B%d', w_info.criterion, w_info.B);

    scenarios = build_step11_5_scenarios_local();
    full_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
    coarse_el_sep_deg_list = [0, 0.36, 0.72];
    fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
    bias_cases = [ ...
        0.00, 0.00; ...
        0.20, 0.00; ...
       -0.20, 0.00; ...
        0.00, 0.20; ...
        0.00,-0.20; ...
        0.20, 0.20; ...
       -0.20,-0.20];

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
    cfg_eval.L = 64;
    cfg_eval.Metkl = 10;
    cfg_eval.base_seed = 20260609;
    cfg_eval.seed_offset = 0;
    cfg_eval.full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, full_el_sep_deg_list);
    cfg_eval.coarse_search_cfg = make_search_cfg_local(1.5, 1.2, 0.16, 0.24, coarse_el_sep_deg_list);
    cfg_eval.base_refine_cfg = make_refine_cfg_local(0.32, 0.48, 0.08, 0.12, fine_el_sep_deg_list);
    cfg_eval.fixed_topK = 3;
    cfg_eval.topK_max = 7;
    cfg_eval.policy_cfg = struct('topK_max', 7, 'tau', 0.02);
    cfg_eval.center_bias_cases = bias_cases;
    cfg_eval.whitening_mode = 'white';
    cfg_eval.reg = reg;
    cfg_eval.az_tol_deg = 0.15;
    cfg_eval.el_tol_deg = 0.20;
    cfg_eval.el_sep_tol_deg = 0.25;
    cfg_eval.W_method = sprintf('greedy_%s_B%d', w_info.criterion, w_info.B);
    cfg_eval.B = w_info.B;
    cfg_eval.snr_or_case_id = 'representative_case';

    tic;
    [trial_table, summary_table, policy_summary_table, bias_summary_table] = ...
        evaluate_step11_5_adaptive_backend(W, scenarios, cfg_eval);
    elapsed_sec = toc;
    log_lines = append_log_local(log_lines, 'Evaluation finished: trial rows=%d, elapsed %.2f s', ...
        height(trial_table), elapsed_sec);

    keypoints_csv = fullfile(result_dir, 'step11_5_keypoints.csv');
    [keypoint_table, keypoints] = summarize_step11_5_keypoints(trial_table, summary_table, ...
        policy_summary_table, bias_summary_table, 'OutputCSV', keypoints_csv);
    plot_paths = plot_step11_5_results(trial_table, summary_table, policy_summary_table, result_dir);
    doc_paths = write_step11_5_docs(result_dir, keypoints, trial_table, summary_table, ...
        policy_summary_table, bias_summary_table);

    trial_csv = fullfile(result_dir, 'step11_5_trial.csv');
    summary_csv = fullfile(result_dir, 'step11_5_summary.csv');
    policy_csv = fullfile(result_dir, 'step11_5_policy_summary.csv');
    bias_csv = fullfile(result_dir, 'step11_5_bias_summary.csv');
    mat_path = fullfile(result_dir, 'step11_5_result.mat');
    log_path = fullfile(result_dir, 'step11_5.log');

    writetable(trial_table, trial_csv);
    writetable(summary_table, summary_csv);
    writetable(policy_summary_table, policy_csv);
    writetable(bias_summary_table, bias_csv);

    params = struct();
    params.method_name_en = 'Likelihood-Uncertainty-Aware Adaptive TopK-Window Beamspace ML Search';
    params.method_name_zh = '基于似然地形不确定度的自适应 TopK-窗口波束级最大似然搜索方法';
    params.scenarios = scenarios;
    params.bias_cases = bias_cases;
    params.cfg_eval = cfg_eval;
    params.w_info = w_info;
    params.elapsed_sec = elapsed_sec;
    save(mat_path, 'params', 'W', 'w_info', 'trial_table', 'summary_table', ...
        'policy_summary_table', 'bias_summary_table', 'keypoint_table', 'keypoints', 'plot_paths', 'doc_paths');

    log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
    log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
    log_lines = append_log_local(log_lines, 'Wrote policy summary CSV: %s', policy_csv);
    log_lines = append_log_local(log_lines, 'Wrote bias summary CSV: %s', bias_csv);
    log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
    for iPlot = 1:numel(plot_paths)
        log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
    end
    for iDoc = 1:numel(doc_paths)
        log_lines = append_log_local(log_lines, 'Wrote markdown: %s', doc_paths{iDoc});
    end
    log_lines = append_keypoints_to_log_local(log_lines, keypoints);
    write_log_local(log_path, log_lines);
    fprintf('Step11.5 complete. Log written: %s\n', log_path);
catch ME
    log_path = fullfile(result_dir, 'step11_5.log');
    log_lines = append_log_local(log_lines, 'ERROR: %s', ME.message);
    for iStack = 1:numel(ME.stack)
        log_lines = append_log_local(log_lines, '  at %s:%d', ME.stack(iStack).file, ME.stack(iStack).line);
    end
    write_log_local(log_path, log_lines);
    rethrow(ME);
end

function scenarios = build_step11_5_scenarios_local()
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

function search_cfg = make_search_cfg_local(az_half_width, el_half_width, az_step, el_step, el_sep_deg_list)
search_cfg = struct('az_half_width', az_half_width, 'el_half_width', el_half_width, ...
    'az_step', az_step, 'el_step', el_step, 'el_sep_deg_list', el_sep_deg_list, ...
    'search_orientations', [1, -1]);
end

function refine_cfg = make_refine_cfg_local(local_az_half_width, local_el_center_half_width, fine_az_step, fine_el_step, fine_el_sep_deg_list)
refine_cfg = struct('local_az_half_width', local_az_half_width, ...
    'local_el_center_half_width', local_el_center_half_width, 'fine_az_step', fine_az_step, ...
    'fine_el_step', fine_el_step, 'fine_el_sep_deg_list', fine_el_sep_deg_list, ...
    'search_orientations', [1, -1]);
end

function log_lines = append_log_local(log_lines, fmt, varargin)
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
if isempty(varargin)
    line = fmt;
else
    line = sprintf(fmt, varargin{:});
end
log_lines{end + 1, 1} = sprintf('[%s] %s', timestamp, line);
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
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_step11_5:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
