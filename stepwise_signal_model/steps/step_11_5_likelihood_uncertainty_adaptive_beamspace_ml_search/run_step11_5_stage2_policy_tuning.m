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
result_dir = fullfile(step_dir, 'results_step11_5_stage2_policy_tuning');

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
log_lines = append_log_local(log_lines, 'Step11.5 Stage2 policy tuning starts');
log_lines = append_log_local(log_lines, 'Based on latest Step11.5 commit a7b741e329d118a039f1da4f00ed86f35b33fad1');
log_lines = append_log_local(log_lines, 'Stage1 preserved label: original uncertainty policy negative result / safety passed but complexity failed');
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

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
    config_table = build_stage2_config_table_local();
    log_lines = append_log_local(log_lines, 'Explicit Stage2 config count = %d', height(config_table));

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
    cfg_eval.seed_offset = 250000;
    cfg_eval.full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, [0, 0.24, 0.36, 0.48, 0.60, 0.72]);
    cfg_eval.coarse_search_cfg = make_search_cfg_local(1.5, 1.2, 0.16, 0.24, [0, 0.36, 0.72]);
    cfg_eval.base_refine_cfg = make_refine_cfg_local(0.32, 0.48, 0.08, 0.12, [0, 0.24, 0.36, 0.48, 0.60, 0.72]);
    cfg_eval.topK_max = 7;
    cfg_eval.tau = 0.02;
    cfg_eval.bias_cases = [0, 0; 0.20, 0; -0.20, 0; 0, 0.20; 0, -0.20; 0.20, 0.20; -0.20, -0.20];
    cfg_eval.whitening_mode = 'white';
    cfg_eval.reg = reg;
    cfg_eval.az_tol_deg = 0.15;
    cfg_eval.el_tol_deg = 0.20;
    cfg_eval.el_sep_tol_deg = 0.25;
    cfg_eval.B = w_info.B;

    tic;
    [trial_table, summary_table, config_table, config_summary_table, policy_summary_table, ...
        bias_summary_table, selected_recommendation] = evaluate_step11_5_policy_tuning_backend(W, scenarios, cfg_eval, config_table);
    elapsed_sec = toc;
    log_lines = append_log_local(log_lines, 'Stage2 evaluation finished: trial rows=%d, elapsed %.2f s', ...
        height(trial_table), elapsed_sec);

    keypoints_csv = fullfile(result_dir, 'step11_5_stage2_keypoints.csv');
    [keypoint_table, keypoints] = summarize_step11_5_stage2_keypoints(trial_table, config_summary_table, ...
        bias_summary_table, selected_recommendation, 'OutputCSV', keypoints_csv);
    plot_paths = plot_step11_5_stage2_results(trial_table, config_summary_table, ...
        policy_summary_table, bias_summary_table, keypoints, result_dir);
    doc_paths = write_step11_5_stage2_docs(result_dir, keypoints, config_summary_table, ...
        policy_summary_table, bias_summary_table);
    selected_recommendation_table = struct2table(selected_recommendation);

    trial_csv = fullfile(result_dir, 'step11_5_stage2_trial.csv');
    summary_csv = fullfile(result_dir, 'step11_5_stage2_summary.csv');
    config_csv = fullfile(result_dir, 'step11_5_stage2_config_table.csv');
    config_summary_csv = fullfile(result_dir, 'step11_5_stage2_config_summary.csv');
    policy_csv = fullfile(result_dir, 'step11_5_stage2_policy_summary.csv');
    bias_csv = fullfile(result_dir, 'step11_5_stage2_bias_summary.csv');
    selected_csv = fullfile(result_dir, 'step11_5_stage2_selected_recommendation.csv');
    mat_path = fullfile(result_dir, 'step11_5_stage2_result.mat');
    log_path = fullfile(result_dir, 'step11_5_stage2.log');

    writetable(trial_table, trial_csv);
    writetable(summary_table, summary_csv);
    writetable(config_table, config_csv);
    writetable(config_summary_table, config_summary_csv);
    writetable(policy_summary_table, policy_csv);
    writetable(bias_summary_table, bias_csv);
    writetable(selected_recommendation_table, selected_csv);

    params = struct();
    params.stage_name = 'Step11.5 Stage2: calibrated search-budget policy tuning';
    params.stage1_label = 'Step11.5 Stage1: original uncertainty policy negative result / safety passed but complexity failed';
    params.cfg_eval = cfg_eval;
    params.scenarios = scenarios;
    params.elapsed_sec = elapsed_sec;
    save(mat_path, 'params', 'W', 'w_info', 'config_table', 'trial_table', 'summary_table', ...
        'config_summary_table', 'policy_summary_table', 'bias_summary_table', 'selected_recommendation', ...
        'selected_recommendation_table', 'keypoint_table', 'keypoints', 'plot_paths', 'doc_paths');

    log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
    log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
    log_lines = append_log_local(log_lines, 'Wrote config table CSV: %s', config_csv);
    log_lines = append_log_local(log_lines, 'Wrote config summary CSV: %s', config_summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote policy summary CSV: %s', policy_csv);
    log_lines = append_log_local(log_lines, 'Wrote bias summary CSV: %s', bias_csv);
    log_lines = append_log_local(log_lines, 'Wrote selected recommendation CSV: %s', selected_csv);
    log_lines = append_log_local(log_lines, 'Wrote MAT: %s', mat_path);
    for idx = 1:numel(plot_paths)
        log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{idx});
    end
    for idx = 1:numel(doc_paths)
        log_lines = append_log_local(log_lines, 'Wrote markdown: %s', doc_paths{idx});
    end
    log_lines = append_keypoints_to_log_local(log_lines, keypoints);
    write_log_local(log_path, log_lines);
    fprintf('Step11.5 Stage2 complete. Log written: %s\n', log_path);
catch ME
    log_path = fullfile(result_dir, 'step11_5_stage2.log');
    log_lines = append_log_local(log_lines, 'ERROR: %s', ME.message);
    for idx = 1:numel(ME.stack)
        log_lines = append_log_local(log_lines, '  at %s:%d', ME.stack(idx).file, ME.stack(idx).line);
    end
    write_log_local(log_path, log_lines);
    rethrow(ME);
end

function config_table = build_stage2_config_table_local()
rows = [ ...
    make_config_local(1, 'C01_normal_only_control', Inf, Inf, 3, 1.0, -Inf, 3, 3, 1.0, 0.85, 'fixed topK3-equivalent control', true); ...
    make_config_local(2, 'C02_easy_conservative', 0.003, 0.0030, 2, 0.75, 0.0008, 5, 5, 1.15, 0.85, 'conservative easy saving', false); ...
    make_config_local(3, 'C03_easy_moderate', 0.003, 0.0025, 2, 0.65, 0.0008, 5, 5, 1.15, 0.85, 'moderate easy saving', false); ...
    make_config_local(4, 'C04_easy_aggressive', 0.003, 0.0025, 1, 0.65, 0.0008, 5, 5, 1.15, 0.85, 'aggressive top1 easy', false); ...
    make_config_local(5, 'C05_easy_very_aggressive', 0.003, 0.0020, 1, 0.60, 0.0008, 5, 5, 1.15, 0.85, 'very aggressive easy', false); ...
    make_config_local(6, 'C06_no_window_expand', 0.003, 0.0025, 2, 0.65, 0.0010, 5, 5, 1.00, 0.85, 'no boundary window expansion', false); ...
    make_config_local(7, 'C07_topK_only', 0.003, 0.0025, 2, 0.75, 0.0012, 5, 5, 1.00, 0.85, 'topK only adjustment', false); ...
    make_config_local(8, 'C08_safe_default', 0.004, 0.0035, 2, 0.75, 0.0006, 5, 5, 1.15, 0.85, 'safe default candidate', false); ...
    make_config_local(9, 'C09_gap_low', 0.002, 0.0020, 2, 0.65, 0.0006, 5, 5, 1.15, 0.85, 'low gap scale', false); ...
    make_config_local(10, 'C10_easy_top1_window075', 0.003, 0.0030, 1, 0.75, 0.0008, 5, 5, 1.15, 0.85, 'top1 easy with wider easy window', false); ...
    make_config_local(11, 'C11_default_plus_low_conf', 0.003, Inf, 3, 1.0, -Inf, 3, 3, 1.0, 0.85, 'confidence decoupling control', true); ...
    make_config_local(12, 'C12_balanced_candidate', 0.003, 0.0028, 2, 0.70, 0.0008, 5, 5, 1.10, 0.85, 'balanced candidate', false)];
config_table = struct2table(rows);
end

function row = make_config_local(config_id, config_name, gap_scale, easy_gap_threshold, easy_topK, easy_window_scale, ...
    ambiguous_gap_threshold, ambiguous_topK, boundary_topK, boundary_window_scale, cond_threshold, notes, is_control_config)
row = struct();
row.config_id = config_id;
row.config_name = config_name;
row.gap_scale = gap_scale;
row.easy_gap_threshold = easy_gap_threshold;
row.easy_topK = easy_topK;
row.easy_window_scale = easy_window_scale;
row.ambiguous_gap_threshold = ambiguous_gap_threshold;
row.ambiguous_topK = ambiguous_topK;
row.boundary_topK = boundary_topK;
row.boundary_window_scale = boundary_window_scale;
row.cond_threshold = cond_threshold;
row.notes = notes;
row.is_control_config = is_control_config;
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
    error('run_step11_5_stage2:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
