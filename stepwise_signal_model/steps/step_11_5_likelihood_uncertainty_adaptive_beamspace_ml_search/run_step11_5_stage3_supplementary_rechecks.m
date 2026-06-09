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
result_dir = fullfile(step_dir, 'results_step11_5_stage3_supplementary_rechecks');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(step11_3_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

rng(20260609, 'twister');
log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.5 Stage3 supplementary rechecks start');
log_lines = append_log_local(log_lines, 'Based on commit c5284dd2f4449eba36cf24b48df8e3eb23c5ef6b');
log_lines = append_log_local(log_lines, 'This is not Step11.6, not Stage2 rerun, and not full Stage3 rerun');
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

    cfg_eval = build_supp_eval_cfg_local(cfg, x, y, z, lambda, phase_factor, phase_sign, reg, w_info.B);
    scenarios = build_representative_scenarios_local();
    [policy_cfg, c05_config_table, stage2_reference] = build_step11_5_stage3_selected_c05_config(cfg_eval);
    log_lines = append_log_local(log_lines, 'Fixed C05 policy config = %s', policy_cfg.config_name);

    metkl30_base_seed_list = [20260609, 20260610, 20260611];
    metkl30_Metkl = 30;
    illcond_Metkl = 10;

    tic;
    [metkl_trial_table, metkl_summary_table] = evaluate_step11_5_stage3_metkl30_repeat_recheck(W, scenarios, ...
        cfg_eval, policy_cfg, metkl30_base_seed_list, metkl30_Metkl);
    metkl_elapsed_sec = toc;
    log_lines = append_log_local(log_lines, 'Metkl30 repeat-seed recheck finished: trial rows=%d, elapsed %.2f s', ...
        height(metkl_trial_table), metkl_elapsed_sec);

    tic;
    [ill_trial_table, ill_summary_table, guard_probe_table] = evaluate_step11_5_stage3_ill_conditioned_real_stress_recheck(W, ...
        cfg_eval, policy_cfg, illcond_Metkl);
    ill_elapsed_sec = toc;
    log_lines = append_log_local(log_lines, 'Ill-conditioned real-search stress recheck finished: trial rows=%d, elapsed %.2f s', ...
        height(ill_trial_table), ill_elapsed_sec);

    keypoints_csv = fullfile(result_dir, 'step11_5_stage3_supp_keypoints.csv');
    recommendation_csv = fullfile(result_dir, 'step11_5_stage3_supp_final_recommendation.csv');
    [keypoint_table, keypoints, final_recommendation_table] = summarize_step11_5_stage3_supplementary_keypoints( ...
        metkl_trial_table, metkl_summary_table, ill_trial_table, ill_summary_table, guard_probe_table, ...
        'OutputCSV', keypoints_csv, 'RecommendationCSV', recommendation_csv);

    plot_paths = plot_step11_5_stage3_supplementary_results(metkl_summary_table, ill_trial_table, ill_summary_table, result_dir);
    doc_paths = write_step11_5_stage3_supplementary_docs(result_dir, keypoints, metkl_summary_table, ...
        ill_trial_table, ill_summary_table, guard_probe_table, final_recommendation_table);

    metkl_trial_csv = fullfile(result_dir, 'step11_5_stage3_supp_metkl30_repeat_trial.csv');
    metkl_summary_csv = fullfile(result_dir, 'step11_5_stage3_supp_metkl30_repeat_summary.csv');
    ill_trial_csv = fullfile(result_dir, 'step11_5_stage3_supp_illcond_real_stress_trial.csv');
    ill_summary_csv = fullfile(result_dir, 'step11_5_stage3_supp_illcond_real_stress_summary.csv');
    guard_probe_csv = fullfile(result_dir, 'step11_5_stage3_supp_illcond_guard_probe.csv');
    c05_config_csv = fullfile(result_dir, 'step11_5_stage3_supp_selected_c05_config.csv');
    mat_path = fullfile(result_dir, 'step11_5_stage3_supp_result.mat');
    log_path = fullfile(result_dir, 'step11_5_stage3_supp.log');

    writetable(metkl_trial_table, metkl_trial_csv);
    writetable(metkl_summary_table, metkl_summary_csv);
    writetable(ill_trial_table, ill_trial_csv);
    writetable(ill_summary_table, ill_summary_csv);
    writetable(guard_probe_table, guard_probe_csv);
    writetable(c05_config_table, c05_config_csv);

    params = struct();
    params.stage_name = 'Step11.5 Stage3 supplementary rechecks: Metkl=30 and stronger ill-conditioned real-search stress';
    params.stage2_reference = stage2_reference;
    params.stage3_required_enhancement_pass_flag = 1;
    params.cfg_eval = cfg_eval;
    params.metkl30_base_seed_list = metkl30_base_seed_list;
    params.metkl30_Metkl = metkl30_Metkl;
    params.illcond_Metkl = illcond_Metkl;
    params.representative_scenarios = scenarios;
    params.metkl_elapsed_sec = metkl_elapsed_sec;
    params.ill_elapsed_sec = ill_elapsed_sec;
    save(mat_path, 'params', 'W', 'w_info', 'policy_cfg', 'c05_config_table', ...
        'metkl_trial_table', 'metkl_summary_table', 'ill_trial_table', 'ill_summary_table', ...
        'guard_probe_table', 'keypoint_table', 'keypoints', 'final_recommendation_table', ...
        'plot_paths', 'doc_paths');

    log_lines = append_log_local(log_lines, 'Wrote Metkl30 trial CSV: %s', metkl_trial_csv);
    log_lines = append_log_local(log_lines, 'Wrote Metkl30 summary CSV: %s', metkl_summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote ill-conditioned real stress trial CSV: %s', ill_trial_csv);
    log_lines = append_log_local(log_lines, 'Wrote ill-conditioned real stress summary CSV: %s', ill_summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote guard probe CSV: %s', guard_probe_csv);
    log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
    log_lines = append_log_local(log_lines, 'Wrote final recommendation CSV: %s', recommendation_csv);
    log_lines = append_log_local(log_lines, 'Wrote selected C05 config CSV: %s', c05_config_csv);
    log_lines = append_log_local(log_lines, 'Wrote MAT: %s', mat_path);
    for idx = 1:numel(plot_paths)
        log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{idx});
    end
    for idx = 1:numel(doc_paths)
        log_lines = append_log_local(log_lines, 'Wrote markdown: %s', doc_paths{idx});
    end
    log_lines = append_keypoints_to_log_local(log_lines, keypoints);
    write_log_local(log_path, log_lines);
    fprintf('Step11.5 Stage3 supplementary rechecks complete. Log written: %s\n', log_path);
catch ME
    log_path = fullfile(result_dir, 'step11_5_stage3_supp.log');
    log_lines = append_log_local(log_lines, 'ERROR: %s', ME.message);
    for idx = 1:numel(ME.stack)
        log_lines = append_log_local(log_lines, '  at %s:%d', ME.stack(idx).file, ME.stack(idx).line);
    end
    write_log_local(log_path, log_lines);
    rethrow(ME);
end

function cfg_eval = build_supp_eval_cfg_local(cfg, x, y, z, lambda, phase_factor, phase_sign, reg, B)
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
cfg_eval.Metkl = 30;
cfg_eval.base_seed = 20260609;
cfg_eval.full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, [0, 0.24, 0.36, 0.48, 0.60, 0.72]);
cfg_eval.coarse_search_cfg = make_search_cfg_local(1.5, 1.2, 0.16, 0.24, [0, 0.36, 0.72]);
cfg_eval.base_refine_cfg = make_refine_cfg_local(0.32, 0.48, 0.08, 0.12, [0, 0.24, 0.36, 0.48, 0.60, 0.72]);
cfg_eval.topK_max = 7;
cfg_eval.tau = 0.02;
cfg_eval.whitening_mode = 'white';
cfg_eval.reg = reg;
cfg_eval.az_tol_deg = 0.15;
cfg_eval.el_tol_deg = 0.20;
cfg_eval.el_sep_tol_deg = 0.25;
cfg_eval.B = B;
cfg_eval.alternate_true_orientation = true;
end

function scenarios = build_representative_scenarios_local()
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
    error('run_step11_5_stage3_supplementary_rechecks:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
