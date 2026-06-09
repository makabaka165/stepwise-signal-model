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
result_dir = fullfile(step_dir, 'results_step11_5_stage3_required_enhancement_validation');

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
log_lines = append_log_local(log_lines, 'Step11.5 Stage3 required enhancement validation starts');
log_lines = append_log_local(log_lines, 'Based on commit b6e5fcdf5b0554b374ae6da2b911eb4abcf95ed9');
log_lines = append_log_local(log_lines, 'Stage1 preserved label: original uncertainty policy negative result / safety passed but complexity failed');
log_lines = append_log_local(log_lines, 'Stage2 preserved positive result: selected_config_name=C05_easy_very_aggressive, stage2_adaptive_pass_flag=1');
log_lines = append_log_local(log_lines, 'Stage3 fixes C05 and does not scan C01-C12 or modify Step11.1/11.2/11.3/11.4');
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

    scenarios = build_step11_5_stage3_scenarios_local();
    cfg_eval = build_stage3_eval_cfg_local(cfg, x, y, z, lambda, phase_factor, phase_sign, reg, w_info.B);
    [policy_cfg, selected_c05_config_table, stage2_reference] = build_step11_5_stage3_selected_c05_config(cfg_eval);
    log_lines = append_log_local(log_lines, 'Fixed Stage3 policy config = %s', policy_cfg.config_name);

    tic;
    [alt_trial_table, alt_summary_table] = evaluate_step11_5_stage3_alternative_split_recheck(W, scenarios, ...
        cfg_eval, policy_cfg, 'Metkl', 10, 'SeedOffsets', cfg_eval.seed_offset, ...
        'SplitSchemes', {'alt_mod3_validation', 'alt_tail_block_validation'});
    alt_elapsed_sec = toc;
    log_lines = append_log_local(log_lines, 'Alternative split recheck finished: rows=%d, elapsed %.2f s', ...
        height(alt_trial_table), alt_elapsed_sec);

    tic;
    [repeat_trial_table, repeat_summary_table] = evaluate_step11_5_stage3_repeat_seed_metkl_recheck(W, scenarios, ...
        cfg_eval, policy_cfg, 'Metkl', 20, 'SeedOffsets', cfg_eval.seed_offset + [0, 100000, 200000]);
    repeat_elapsed_sec = toc;
    log_lines = append_log_local(log_lines, 'Repeat-seed larger-Metkl recheck finished: rows=%d, elapsed %.2f s', ...
        height(repeat_trial_table), repeat_elapsed_sec);

    tic;
    [branch_trial_table, branch_summary_table] = evaluate_step11_5_stage3_targeted_branch_recheck(W, scenarios, ...
        cfg_eval, policy_cfg, 'SeedOffset', cfg_eval.seed_offset);
    branch_elapsed_sec = toc;
    log_lines = append_log_local(log_lines, 'Targeted branch recheck finished: rows=%d, elapsed %.2f s', ...
        height(branch_trial_table), branch_elapsed_sec);

    keypoints_csv = fullfile(result_dir, 'step11_5_stage3_keypoints.csv');
    [keypoint_table, keypoints] = summarize_step11_5_stage3_keypoints(alt_summary_table, repeat_summary_table, ...
        branch_summary_table, stage2_reference, 'OutputCSV', keypoints_csv);
    stage2_reference_table = struct2table(keypoints_to_rows_local(stage2_reference));

    plot_paths = plot_step11_5_stage3_results(alt_summary_table, repeat_summary_table, branch_trial_table, keypoints, result_dir);
    doc_paths = write_step11_5_stage3_docs(result_dir, keypoints, alt_summary_table, repeat_summary_table, ...
        branch_trial_table, branch_summary_table);

    alt_trial_csv = fullfile(result_dir, 'step11_5_stage3_alt_split_trial.csv');
    alt_summary_csv = fullfile(result_dir, 'step11_5_stage3_alt_split_summary.csv');
    repeat_trial_csv = fullfile(result_dir, 'step11_5_stage3_repeat_seed_metkl_trial.csv');
    repeat_summary_csv = fullfile(result_dir, 'step11_5_stage3_repeat_seed_metkl_summary.csv');
    branch_trial_csv = fullfile(result_dir, 'step11_5_stage3_targeted_branch_trial.csv');
    branch_summary_csv = fullfile(result_dir, 'step11_5_stage3_targeted_branch_summary.csv');
    selected_c05_csv = fullfile(result_dir, 'step11_5_stage3_selected_c05_config.csv');
    stage2_reference_csv = fullfile(result_dir, 'step11_5_stage3_stage2_reference.csv');
    mat_path = fullfile(result_dir, 'step11_5_stage3_result.mat');
    log_path = fullfile(result_dir, 'step11_5_stage3.log');

    writetable(alt_trial_table, alt_trial_csv);
    writetable(alt_summary_table, alt_summary_csv);
    writetable(repeat_trial_table, repeat_trial_csv);
    writetable(repeat_summary_table, repeat_summary_csv);
    writetable(branch_trial_table, branch_trial_csv);
    writetable(branch_summary_table, branch_summary_csv);
    writetable(selected_c05_config_table, selected_c05_csv);
    writetable(stage2_reference_table, stage2_reference_csv);

    params = struct();
    params.stage_name = 'Step11.5 Stage3: required enhancement validation for Stage2 selected C05';
    params.stage1_label = stage2_reference.stage1_result_label;
    params.stage2_label = stage2_reference.stage2_result_label;
    params.cfg_eval = cfg_eval;
    params.scenarios = scenarios;
    params.alt_elapsed_sec = alt_elapsed_sec;
    params.repeat_elapsed_sec = repeat_elapsed_sec;
    params.branch_elapsed_sec = branch_elapsed_sec;
    save(mat_path, 'params', 'W', 'w_info', 'policy_cfg', 'selected_c05_config_table', ...
        'stage2_reference', 'alt_trial_table', 'alt_summary_table', 'repeat_trial_table', ...
        'repeat_summary_table', 'branch_trial_table', 'branch_summary_table', 'keypoint_table', ...
        'keypoints', 'plot_paths', 'doc_paths');

    log_lines = append_log_local(log_lines, 'Wrote alt split trial CSV: %s', alt_trial_csv);
    log_lines = append_log_local(log_lines, 'Wrote alt split summary CSV: %s', alt_summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote repeat seed trial CSV: %s', repeat_trial_csv);
    log_lines = append_log_local(log_lines, 'Wrote repeat seed summary CSV: %s', repeat_summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote targeted branch trial CSV: %s', branch_trial_csv);
    log_lines = append_log_local(log_lines, 'Wrote targeted branch summary CSV: %s', branch_summary_csv);
    log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
    log_lines = append_log_local(log_lines, 'Wrote selected C05 config CSV: %s', selected_c05_csv);
    log_lines = append_log_local(log_lines, 'Wrote Stage2 reference CSV: %s', stage2_reference_csv);
    log_lines = append_log_local(log_lines, 'Wrote MAT: %s', mat_path);
    for idx = 1:numel(plot_paths)
        log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{idx});
    end
    for idx = 1:numel(doc_paths)
        log_lines = append_log_local(log_lines, 'Wrote markdown: %s', doc_paths{idx});
    end
    log_lines = append_keypoints_to_log_local(log_lines, keypoints);
    write_log_local(log_path, log_lines);
    fprintf('Step11.5 Stage3 complete. Log written: %s\n', log_path);
catch ME
    log_path = fullfile(result_dir, 'step11_5_stage3.log');
    log_lines = append_log_local(log_lines, 'ERROR: %s', ME.message);
    for idx = 1:numel(ME.stack)
        log_lines = append_log_local(log_lines, '  at %s:%d', ME.stack(idx).file, ME.stack(idx).line);
    end
    write_log_local(log_path, log_lines);
    rethrow(ME);
end

function cfg_eval = build_stage3_eval_cfg_local(cfg, x, y, z, lambda, phase_factor, phase_sign, reg, B)
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
cfg_eval.whitening_mode = 'white';
cfg_eval.reg = reg;
cfg_eval.az_tol_deg = 0.15;
cfg_eval.el_tol_deg = 0.20;
cfg_eval.el_sep_tol_deg = 0.25;
cfg_eval.B = B;
cfg_eval.alternate_true_orientation = true;
end

function scenarios = build_step11_5_stage3_scenarios_local()
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

function rows = keypoints_to_rows_local(s)
names = fieldnames(s);
rows = repmat(struct('keypoint', '', 'value', ''), numel(names), 1);
for idx = 1:numel(names)
    rows(idx).keypoint = names{idx};
    value = s.(names{idx});
    if isnumeric(value) || islogical(value)
        rows(idx).value = sprintf('%.12g', double(value));
    else
        rows(idx).value = char(value);
    end
end
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
    error('run_step11_5_stage3:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
