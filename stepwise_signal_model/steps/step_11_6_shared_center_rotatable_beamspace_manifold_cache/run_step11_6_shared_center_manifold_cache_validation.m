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
step11_5_common_dir = fullfile(project_dir, 'steps', 'step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search', 'common');
result_dir = fullfile(step_dir, 'results_step11_6_shared_center_rotatable_beamspace_manifold_cache');

addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(step11_3_common_dir);
addpath(step11_5_common_dir);
addpath(common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

rng(20260609, 'twister');
log_lines = {};
log_lines = append_log_step11_6_local(log_lines, 'Step11.6 shared-center rotatable beamspace manifold cache validation starts');
log_lines = append_log_step11_6_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_step11_6_local(log_lines, 'Result directory: %s', result_dir);
log_lines = append_log_step11_6_local(log_lines, 'No Step11.1/11.2/11.3/11.4/11.5 files are modified.');
log_lines = append_log_step11_6_local(log_lines, 'Truth is used only for final success/RMSE/same-estimate metrics.');

try
    cfg = sim_cfg();
    cfg.beam.azSectorCenter = 0;
    cfg.beam.azSteer = 0;
    phase_factor = cfg.beam.spatialPhaseFactor;
    phase_sign = 1;
    reg = 1e-10;

    canonical_geom = build_step11_6_canonical_geometry(cfg, 0);
    [W, w_info] = build_recommended_w_from_step11_2(step11_2_dir, cfg, canonical_geom.canonical_arr, ...
        'B', 7, 'Criterion', 'combined', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
    log_lines = append_log_step11_6_local(log_lines, 'W reconstructed as greedy_%s_B%d on canonical local order', w_info.criterion, w_info.B);

    scenarios = build_step11_6_scenarios_local();
    params = build_params_local(cfg, phase_factor, phase_sign, reg);
    [params.policy_cfg, c05_config_table, stage2_reference] = build_step11_5_stage3_selected_c05_config(struct('topK_max', 7, 'tau', 0.02));
    params.policy_cfg.topK_max = 7;
    params.policy_cfg.tau = 0.02;
    params.W_method = sprintf('greedy_%s_B%d', w_info.criterion, w_info.B);
    params.w_info = w_info;
    params.stage2_reference = stage2_reference;

    [cache_delta_grid, cache_el_grid] = build_cache_union_grid_local(params);
    [cache, cache_metadata] = build_step11_6_canonical_beamspace_cache(W, canonical_geom, cache_delta_grid, cache_el_grid, params.lambda, ...
        'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'WMethod', params.W_method);
    cache_metadata_table = struct2table(cache_metadata);
    log_lines = append_log_step11_6_local(log_lines, 'Cache built: N_delta=%d, N_el=%d, memory=%.6f MB, build=%.6f s', ...
        cache.N_delta_az, cache.N_el, cache.cache_memory_MB, cache.cache_build_once_time_sec);

    [stage1_trial_table, stage1_summary_table] = evaluate_step11_6_cache_equivalence(W, cfg, cache, params);
    log_lines = append_log_step11_6_local(log_lines, 'Stage1 complete: pass=%d, max_rel_G=%.3g', ...
        stage1_summary_table.manifold_equivalence_pass_flag(1), stage1_summary_table.max_rel_G_error(1));

    [stage2_trial_table, stage2_summary_table] = evaluate_step11_6_search_consistency(W, cfg, cache, scenarios, params);
    log_lines = append_log_step11_6_local(log_lines, 'Stage2 complete: pass=%d, same_estimate_rate=%.6f, cache_miss=%g', ...
        stage2_summary_table.search_consistency_pass_flag(1), stage2_summary_table.same_estimate_rate(1), ...
        stage2_summary_table.cache_miss_count(1));

    [stage3_trial_table, stage3_summary_table] = evaluate_step11_6_runtime_benchmark(W, cfg, cache, scenarios, params, ...
        stage2_summary_table.search_consistency_pass_flag(1));
    log_lines = append_log_step11_6_local(log_lines, 'Stage3 complete: manifold_pass=%d, search_pass=%d, median_manifold_reduction=%.6f', ...
        stage3_summary_table.runtime_manifold_pass_flag(1), stage3_summary_table.runtime_search_pass_flag(1), ...
        stage3_summary_table.median_manifold_time_reduction_ratio(1));

    [stage4_trial_table, stage4_summary_table] = evaluate_stage4_cross_center_local(W, cfg, cache, scenarios, params);
    log_lines = append_log_step11_6_local(log_lines, 'Stage4 complete: pass=%d, passed_centers=%.0f/%.0f', ...
        stage4_summary_table.cross_center_reuse_pass_flag(1), stage4_summary_table.num_passed_centers(1), ...
        stage4_summary_table.num_tested_centers(1));

    [keypoint_table, keypoints, final_recommendation_table] = summarize_step11_6_keypoints(stage1_summary_table, stage2_summary_table, ...
        stage3_summary_table, stage4_summary_table, cache_metadata_table);
    log_lines = append_log_step11_6_local(log_lines, 'Final recommendation: %s', keypoints.step11_6_recommendation);

    write_all_csv_local(result_dir, stage1_trial_table, stage1_summary_table, stage2_trial_table, stage2_summary_table, ...
        stage3_trial_table, stage3_summary_table, stage4_trial_table, stage4_summary_table, cache_metadata_table, ...
        keypoint_table, final_recommendation_table);
    plot_paths = plot_step11_6_results(stage1_trial_table, stage2_trial_table, stage3_trial_table, stage4_trial_table, ...
        cache_metadata_table, result_dir);
    doc_paths = write_step11_6_docs(result_dir, keypoints, stage1_summary_table, stage2_summary_table, ...
        stage3_summary_table, stage4_summary_table, cache_metadata_table);

    mat_path = fullfile(result_dir, 'step11_6_result.mat');
    save(mat_path, 'cache', 'cache_metadata', 'cache_metadata_table', ...
        'stage1_trial_table', 'stage1_summary_table', 'stage2_trial_table', 'stage2_summary_table', ...
        'stage3_trial_table', 'stage3_summary_table', 'stage4_trial_table', 'stage4_summary_table', ...
        'keypoint_table', 'keypoints', 'final_recommendation_table', 'params', 'W', 'w_info', ...
        'c05_config_table', 'scenarios', 'plot_paths', 'doc_paths');
    log_lines = append_log_step11_6_local(log_lines, 'Wrote MAT: %s', mat_path);
    for idx = 1:numel(plot_paths)
        log_lines = append_log_step11_6_local(log_lines, 'Wrote PNG: %s', plot_paths{idx});
    end
    for idx = 1:numel(doc_paths)
        log_lines = append_log_step11_6_local(log_lines, 'Wrote Markdown: %s', doc_paths{idx});
    end
    log_lines = append_keypoints_to_log_local(log_lines, keypoints);
    log_path = fullfile(result_dir, 'step11_6.log');
    write_log_local(log_path, log_lines);
    fprintf('Step11.6 complete. Log written: %s\n', log_path);
catch ME
    log_path = fullfile(result_dir, 'step11_6.log');
    log_lines = append_log_step11_6_local(log_lines, 'ERROR: %s', ME.message);
    for iStack = 1:numel(ME.stack)
        log_lines = append_log_step11_6_local(log_lines, '  at %s:%d', ME.stack(iStack).file, ME.stack(iStack).line);
    end
    write_log_local(log_path, log_lines);
    rethrow(ME);
end

function params = build_params_local(cfg, phase_factor, phase_sign, reg)
%BUILD_PARAMS_LOCAL Create fixed Step11.6 validation parameters.
params = struct();
params.method_name_en = 'Shared-Center Rotatable Beamspace Manifold Cache for Cylindrical-Array Beamspace ML';
params.method_name_zh = '基于 shared-center 圆柱阵旋转等价性的可复用波束域流形缓存方法';
params.lambda = cfg.arr.lambda;
params.phase_factor = phase_factor;
params.phase_sign = phase_sign;
params.reg = reg;
params.el_center_nominal = cfg.beam.elSectorCenter;
params.el_center_offset = 0.31;
params.L = 64;
params.Metkl = 10;
params.repeat_runtime = 3;
params.base_seed = 20260609;
params.whitening_mode = 'white';
params.az_tol_deg = 0.15;
params.el_tol_deg = 0.20;
params.el_sep_tol_deg = 0.25;
params.alternate_true_orientation = true;
params.full_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
params.coarse_el_sep_deg_list = [0, 0.36, 0.72];
params.fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
params.full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, params.full_el_sep_deg_list);
params.coarse_search_cfg = make_search_cfg_local(1.5, 1.2, 0.16, 0.24, params.coarse_el_sep_deg_list);
params.base_refine_cfg = make_refine_cfg_local(0.32, 0.48, 0.08, 0.12, params.fine_el_sep_deg_list);
params.stage1_center_az_list = [0, 5, 8, 15, 30];
params.stage1_delta_az_grid = unique(round((-1.5:0.08:1.5) * 1e10) / 1e10);
params.stage1_el_values = build_stage1_el_values_local(cfg, params);
params.stage2_center_az_list = [0, 8, 15];
params.stage3_center_az_list = [0, 8, 15, 30];
params.stage4_center_az_list = [-30, -15, 0, 8, 15, 30];
end

function scenarios = build_step11_6_scenarios_local()
%BUILD_STEP11_6_SCENARIOS_LOCAL Return Step11.5 representative scenarios.
rows = [ ...
    make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30); ...
    make_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30); ...
    make_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30); ...
    make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30); ...
    make_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20)];
scenarios = struct2table(rows);
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
%MAKE_SCENARIO_LOCAL Create one representative scenario row.
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end

function search_cfg = make_search_cfg_local(az_half_width, el_half_width, az_step, el_step, el_sep_deg_list)
%MAKE_SEARCH_CFG_LOCAL Create Step11.3 degree-grid search config.
search_cfg = struct('az_half_width', az_half_width, 'el_half_width', el_half_width, ...
    'az_step', az_step, 'el_step', el_step, 'el_sep_deg_list', el_sep_deg_list, ...
    'search_orientations', [1, -1]);
end

function refine_cfg = make_refine_cfg_local(local_az_half_width, local_el_center_half_width, fine_az_step, fine_el_step, fine_el_sep_deg_list)
%MAKE_REFINE_CFG_LOCAL Create Step11.3 local refine config.
refine_cfg = struct('local_az_half_width', local_az_half_width, ...
    'local_el_center_half_width', local_el_center_half_width, 'fine_az_step', fine_az_step, ...
    'fine_el_step', fine_el_step, 'fine_el_sep_deg_list', fine_el_sep_deg_list, ...
    'search_orientations', [1, -1]);
end

function el_values = build_stage1_el_values_local(cfg, params)
%BUILD_STAGE1_EL_VALUES_LOCAL Build Stage1 elevation values around nominal center.
el_center_nominal = cfg.beam.elSectorCenter + params.el_center_offset;
el_center_grid = unique(round((el_center_nominal - 1.2:0.12:el_center_nominal + 1.2) * 1e10) / 1e10);
values = [];
for idx = 1:numel(params.full_el_sep_deg_list)
    sep = params.full_el_sep_deg_list(idx);
    values = [values, el_center_grid - sep / 2, el_center_grid + sep / 2]; %#ok<AGROW>
end
valid_mask = values >= cfg.beam.elBeamMinDeg & values <= cfg.beam.elBeamMaxDeg;
el_values = unique(round(values(valid_mask) * 1e10) / 1e10);
end

function [delta_grid, el_grid] = build_cache_union_grid_local(params)
%BUILD_CACHE_UNION_GRID_LOCAL Cover Stage1, coarse, fixed refine, and C05 refine exact grids.
delta_values = params.stage1_delta_az_grid(:).';
coarse_delta = unique(round((-1.5:params.coarse_search_cfg.az_step:1.5) * 1e10) / 1e10);
delta_values = [delta_values, coarse_delta, -1.5:0.08:1.5]; %#ok<AGROW>
az_widths = unique(round([params.base_refine_cfg.local_az_half_width, ...
    params.base_refine_cfg.local_az_half_width * params.policy_cfg.easy_window_scale, ...
    params.base_refine_cfg.local_az_half_width * params.policy_cfg.boundary_window_scale] * 1e10) / 1e10);
for iBase = 1:numel(coarse_delta)
    for iWidth = 1:numel(az_widths)
        bounds = clamp_bounds_local(coarse_delta(iBase) + [-az_widths(iWidth), az_widths(iWidth)], [-1.5, 1.5]);
        delta_values = [delta_values, make_axis_local(bounds(1), bounds(2), params.base_refine_cfg.fine_az_step)]; %#ok<AGROW>
    end
end
delta_grid = unique(round(delta_values * 1e10) / 1e10);

el_values = params.stage1_el_values(:).';
coarse_center = unique(round((params.el_center_nominal - 1.2:params.coarse_search_cfg.el_step:params.el_center_nominal + 1.2) * 1e10) / 1e10);
el_values = [el_values, pair_el_values_local(coarse_center, params.coarse_el_sep_deg_list, [params.el_center_nominal - 1.2, params.el_center_nominal + 1.2])]; %#ok<AGROW>
el_widths = unique(round([params.base_refine_cfg.local_el_center_half_width, ...
    params.base_refine_cfg.local_el_center_half_width * params.policy_cfg.easy_window_scale, ...
    params.base_refine_cfg.local_el_center_half_width * params.policy_cfg.boundary_window_scale] * 1e10) / 1e10);
for iBase = 1:numel(coarse_center)
    for iWidth = 1:numel(el_widths)
        bounds = clamp_bounds_local(coarse_center(iBase) + [-el_widths(iWidth), el_widths(iWidth)], ...
            [params.el_center_nominal - 1.2, params.el_center_nominal + 1.2]);
        centers_now = make_axis_local(bounds(1), bounds(2), params.base_refine_cfg.fine_el_step);
        el_values = [el_values, pair_el_values_local(centers_now, params.fine_el_sep_deg_list, ...
            [params.el_center_nominal - 1.2, params.el_center_nominal + 1.2])]; %#ok<AGROW>
    end
end
el_grid = unique(round(el_values * 1e10) / 1e10);
end

function values = pair_el_values_local(el_center_grid, el_sep_deg_list, el_bounds)
%PAIR_EL_VALUES_LOCAL Enumerate exact elevation pair values for degree-based rows.
values = [];
[~, ~, valid_mask, info] = make_el_pair_list_degree_based(el_center_grid, el_sep_deg_list, [1, -1], el_bounds);
rows = info.rows(valid_mask);
if ~isempty(rows)
    values = unique(round([[rows.el1], [rows.el2]] * 1e10) / 1e10);
end
end

function [stage4_trial_table, stage4_summary_table] = evaluate_stage4_cross_center_local(W, cfg, cache, scenarios, params)
%EVALUATE_STAGE4_CROSS_CENTER_LOCAL Validate cross-center reuse on a subset.
rows = repmat(make_stage4_row_template_local(), numel(params.stage4_center_az_list), 1);
stage4_scenarios = scenarios(1:min(2, height(scenarios)), :);
stage4_params = params;
stage4_params.Metkl = 2;
stage4_params.stage1_delta_az_grid = -1.5:0.24:1.5;
stage4_params.stage1_el_values = params.stage1_el_values(1:3:end);
if isempty(stage4_params.stage1_el_values)
    stage4_params.stage1_el_values = params.stage1_el_values;
end
for idx = 1:numel(params.stage4_center_az_list)
    center = params.stage4_center_az_list(idx);
    stage4_params.stage1_center_az_list = center;
    stage4_params.stage2_center_az_list = center;
    [man_trial, man_summary] = evaluate_step11_6_cache_equivalence(W, cfg, cache, stage4_params);
    [search_trial, search_summary] = evaluate_step11_6_search_consistency(W, cfg, cache, stage4_scenarios, stage4_params);
    geom = build_step11_6_canonical_geometry(cfg, center);
    rows(idx) = make_stage4_row_local(center, geom, man_summary, search_summary);
end
stage4_trial_table = struct2table(rows);
summary = struct();
summary.stage_name = 'stage4_cross_center_cache_reuse';
summary.num_tested_centers = height(stage4_trial_table);
summary.num_passed_centers = sum(stage4_trial_table.manifold_equivalence_pass & stage4_trial_table.search_consistency_pass & stage4_trial_table.cache_miss_count == 0);
summary.cross_center_reuse_pass_flag = summary.num_passed_centers == summary.num_tested_centers;
summary.cache_miss_count = sum(stage4_trial_table.cache_miss_count);
summary.fail_center_list = fail_center_list_local(stage4_trial_table);
stage4_summary_table = struct2table(summary);
end

function row = make_stage4_row_template_local()
%MAKE_STAGE4_ROW_TEMPLATE_LOCAL Create one Stage4 center summary row.
row = struct();
row.center_az = NaN;
row.actual_center_az = NaN;
row.selected_center_column = NaN;
row.manifold_equivalence_pass = false;
row.search_consistency_pass = false;
row.same_estimate_rate = NaN;
row.same_policy_rate = NaN;
row.max_rel_G_error = NaN;
row.max_score_diff = NaN;
row.cache_miss_count = NaN;
end

function row = make_stage4_row_local(center, geom, man_summary, search_summary)
%MAKE_STAGE4_ROW_LOCAL Convert Stage4 summaries into one center row.
row = make_stage4_row_template_local();
row.center_az = center;
row.actual_center_az = geom.actual_center_az_deg;
row.selected_center_column = geom.selected_center_column;
row.manifold_equivalence_pass = logical(man_summary.manifold_equivalence_pass_flag(1));
row.search_consistency_pass = logical(search_summary.search_consistency_pass_flag(1));
row.same_estimate_rate = search_summary.same_estimate_rate(1);
row.same_policy_rate = search_summary.same_policy_rate(1);
row.max_rel_G_error = man_summary.max_rel_G_error(1);
row.max_score_diff = search_summary.max_abs_score_diff(1);
row.cache_miss_count = search_summary.cache_miss_count(1) + man_summary.max_cache_miss_count(1);
end

function text = fail_center_list_local(T)
%FAIL_CENTER_LIST_LOCAL Format failed Stage4 centers.
mask = ~(T.manifold_equivalence_pass & T.search_consistency_pass & T.cache_miss_count == 0);
if ~any(mask)
    text = 'none';
    return;
end
vals = T.actual_center_az(mask);
parts = cell(1, numel(vals));
for idx = 1:numel(vals)
    parts{idx} = sprintf('%.12g', vals(idx));
end
text = strjoin(parts, ',');
end

function write_all_csv_local(result_dir, stage1_trial_table, stage1_summary_table, stage2_trial_table, stage2_summary_table, ...
    stage3_trial_table, stage3_summary_table, stage4_trial_table, stage4_summary_table, cache_metadata_table, ...
    keypoint_table, final_recommendation_table)
%WRITE_ALL_CSV_LOCAL Write all required Step11.6 CSV files with writetable.
writetable(stage1_trial_table, fullfile(result_dir, 'step11_6_stage1_manifold_equivalence_trial.csv'));
writetable(stage1_summary_table, fullfile(result_dir, 'step11_6_stage1_manifold_equivalence_summary.csv'));
writetable(stage2_trial_table, fullfile(result_dir, 'step11_6_stage2_search_consistency_trial.csv'));
writetable(stage2_summary_table, fullfile(result_dir, 'step11_6_stage2_search_consistency_summary.csv'));
writetable(stage3_trial_table, fullfile(result_dir, 'step11_6_stage3_runtime_benchmark_trial.csv'));
writetable(stage3_summary_table, fullfile(result_dir, 'step11_6_stage3_runtime_benchmark_summary.csv'));
writetable(stage4_trial_table, fullfile(result_dir, 'step11_6_stage4_cross_center_cache_reuse_trial.csv'));
writetable(stage4_summary_table, fullfile(result_dir, 'step11_6_stage4_cross_center_cache_reuse_summary.csv'));
writetable(cache_metadata_table, fullfile(result_dir, 'step11_6_cache_metadata.csv'));
writetable(keypoint_table, fullfile(result_dir, 'step11_6_keypoints.csv'));
writetable(final_recommendation_table, fullfile(result_dir, 'step11_6_final_recommendation.csv'));
end

function bounds = clamp_bounds_local(bounds, global_bounds)
%CLAMP_BOUNDS_LOCAL Clamp sorted bounds to sorted global bounds.
global_bounds = sort(global_bounds(:).');
bounds = sort(bounds(:).');
bounds(1) = max(bounds(1), global_bounds(1));
bounds(2) = min(bounds(2), global_bounds(2));
end

function axis = make_axis_local(lo, hi, step)
%MAKE_AXIS_LOCAL Match Step11.3 local refine axis construction.
axis = lo:step:hi;
if isempty(axis) || abs(axis(end) - hi) > 1e-9
    axis = [axis, hi];
end
axis = unique(round(axis * 1e10) / 1e10);
end

function log_lines = append_log_step11_6_local(log_lines, fmt, varargin)
%APPEND_LOG_STEP11_6_LOCAL Append one timestamped log line.
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
if isempty(varargin)
    line = fmt;
else
    line = sprintf(fmt, varargin{:});
end
log_lines{end + 1, 1} = sprintf('[%s] %s', timestamp, line);
end

function log_lines = append_keypoints_to_log_local(log_lines, keypoints)
%APPEND_KEYPOINTS_TO_LOG_LOCAL Append final keypoints to the log.
log_lines = append_log_step11_6_local(log_lines, 'Keypoints:');
names = fieldnames(keypoints);
for idx = 1:numel(names)
    value = keypoints.(names{idx});
    if isnumeric(value) || islogical(value)
        log_lines = append_log_step11_6_local(log_lines, '  %s = %.12g', names{idx}, double(value));
    else
        log_lines = append_log_step11_6_local(log_lines, '  %s = %s', names{idx}, char(value));
    end
end
end

function write_log_local(log_path, log_lines)
%WRITE_LOG_LOCAL Write Step11.6 UTF-8 log.
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_step11_6:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end
