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
log_lines = append_log_local(log_lines, 'Step11.3 Stage2 starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);
log_lines = append_log_local(log_lines, 'degree-based el_sep enabled');

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

scenarios = build_stage_scenarios_local();
full_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
screening_configs = build_screening_configs_local();
log_lines = append_log_local(log_lines, 'screening config count = %d', numel(screening_configs));
log_lines = append_log_local(log_lines, 'Full baseline: az_step=0.08, el_step=0.12, el_sep_deg_list=%s', ...
    mat2str(full_el_sep_deg_list));

tic;
[screening_trial, screening_summary, log_lines] = run_config_set_local(W, scenarios, screening_configs, ...
    'screening', 3, 20260625, 0, x, y, z, lambda, phase_factor, phase_sign, cfg, w_info, ...
    full_el_sep_deg_list, log_lines);
screening_metrics = build_config_metrics_table_local(screening_summary, 'screening');
screening_metrics = add_screening_score_local(screening_metrics);
[selected_names, selected_note] = select_confirmation_configs_local(screening_metrics, 5);
confirmation_configs = select_config_records_local(screening_configs, selected_names);

log_lines = append_log_local(log_lines, 'screening finished: configs=%d, trial rows=%d, summary rows=%d, elapsed %.2f s', ...
    numel(screening_configs), height(screening_trial), height(screening_summary), toc);
log_lines = append_log_local(log_lines, 'top config selection: %s', selected_note);
log_lines = append_log_local(log_lines, 'top config names: %s', strjoin(selected_names, ', '));
log_lines = append_log_local(log_lines, 'confirmation config count = %d', numel(confirmation_configs));

[confirmation_trial, confirmation_summary, log_lines] = run_config_set_local(W, scenarios, confirmation_configs, ...
    'confirmation', 10, 20260625, 50000, x, y, z, lambda, phase_factor, phase_sign, cfg, w_info, ...
    full_el_sep_deg_list, log_lines);
confirmation_metrics = build_config_metrics_table_local(confirmation_summary, 'confirmation');
confirmation_metrics = add_final_pass_local(confirmation_metrics);

[keypoint_rows, keypoints] = summarize_search_acceleration_keypoints(confirmation_summary, 'stage2');
keypoint_table = struct2table(keypoint_rows);
config_table = build_stage2_config_table_local(screening_metrics, confirmation_metrics, selected_names);
plot_paths = plot_search_acceleration_results(confirmation_summary, result_dir, 'step11_3_stage2');

screening_trial_csv = fullfile(result_dir, 'step11_3_stage2_screening_trial.csv');
screening_summary_csv = fullfile(result_dir, 'step11_3_stage2_screening_summary.csv');
confirmation_trial_csv = fullfile(result_dir, 'step11_3_stage2_confirmation_trial.csv');
confirmation_summary_csv = fullfile(result_dir, 'step11_3_stage2_confirmation_summary.csv');
config_csv = fullfile(result_dir, 'step11_3_stage2_config_table.csv');
keypoints_csv = fullfile(result_dir, 'step11_3_stage2_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_3_stage2_result.mat');
log_path = fullfile(result_dir, 'step11_3_stage2.log');

writetable(screening_trial, screening_trial_csv);
writetable(screening_summary, screening_summary_csv);
writetable(confirmation_trial, confirmation_trial_csv);
writetable(confirmation_summary, confirmation_summary_csv);
writetable(config_table, config_csv);
writetable(keypoint_table, keypoints_csv);

params = struct();
params.full_el_sep_deg_list = full_el_sep_deg_list;
params.Metkl_screen = 3;
params.Metkl_confirm = 10;
params.base_seed = 20260625;
params.scenarios = scenarios;
params.w_info = w_info;
params.selected_names = selected_names;
params.selected_note = selected_note;
cfg_records = struct();
cfg_records.screening = screening_configs;
cfg_records.confirmation = confirmation_configs;
save(mat_path, 'params', 'W', 'w_info', 'cfg_records', 'screening_trial', 'screening_summary', ...
    'confirmation_trial', 'confirmation_summary', 'screening_metrics', 'confirmation_metrics', ...
    'config_table', 'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'confirmation results: trial rows=%d, summary rows=%d, elapsed %.2f s', ...
    height(confirmation_trial), height(confirmation_summary), toc);
log_lines = append_log_local(log_lines, 'recommended config = %s', keypoints.recommended_config_name);
log_lines = append_log_local(log_lines, 'search_acceleration_pass_flag = %d', keypoints.search_acceleration_pass_flag);
log_lines = append_log_local(log_lines, 'Wrote screening trial CSV: %s', screening_trial_csv);
log_lines = append_log_local(log_lines, 'Wrote screening summary CSV: %s', screening_summary_csv);
log_lines = append_log_local(log_lines, 'Wrote confirmation trial CSV: %s', confirmation_trial_csv);
log_lines = append_log_local(log_lines, 'Wrote confirmation summary CSV: %s', confirmation_summary_csv);
log_lines = append_log_local(log_lines, 'Wrote config table CSV: %s', config_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_keypoints_to_log_local(log_lines, keypoints);
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function [trial_table, summary_table, log_lines] = run_config_set_local(W, scenarios, config_records, ...
    sweep_phase, Metkl, base_seed, seed_offset, x, y, z, lambda, phase_factor, phase_sign, cfg, w_info, ...
    full_el_sep_deg_list, log_lines)
scenario_table = normalize_scenarios_local(scenarios);
search_opts = struct('whitening_mode', 'white', 'reg', 1e-10);
manifold_opts = struct('phase_factor', phase_factor, 'phase_sign', phase_sign);
center_bias = [0, 0];
az_center_search = cfg.beam.azSectorCenter + center_bias(1);
el_center_search = cfg.beam.elSectorCenter + center_bias(2);
full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, full_el_sep_deg_list);
full_grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, full_search_cfg);
coarse_records = unique_coarse_records_local(config_records);
max_topK = max([config_records.topK]);

total_rows = height(scenario_table) * Metkl * numel(config_records) * 2;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

for iScenario = 1:height(scenario_table)
    scenario = table_row_to_struct_local(scenario_table(iScenario, :));
    az_true = cfg.beam.azSectorCenter + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
    el_center_true = cfg.beam.elSectorCenter + 0.31;
    for trial_id = 1:Metkl
        if scenario.el_sep_deg == 0
            el_true = [el_center_true, el_center_true];
            true_orientation = 0;
        elseif mod(trial_id, 2) == 0
            el_true = el_center_true + [scenario.el_sep_deg / 2, -scenario.el_sep_deg / 2];
            true_orientation = -1;
        else
            el_true = el_center_true + [-scenario.el_sep_deg / 2, scenario.el_sep_deg / 2];
            true_orientation = 1;
        end
        seed_now = base_seed + 1000 * iScenario + trial_id + seed_offset;
        [Y, truth] = make_cyl_pair2d_correlated_snapshots(x, y, z, az_true, el_true, lambda, 64, scenario.snr_db, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Rho', scenario.rho, ...
            'PhaseDeg', scenario.phase_deg, 'AmplitudeRatio', scenario.beta, 'Seed', seed_now, ...
            'NormalizeSourcePower', true);
        Z = W' * Y;

        [est_full, debug_full] = search_pair2d_full_fine_grid(Z, W, x, y, z, lambda, ...
            full_grid_cfg, manifold_opts, search_opts);
        est_full = attach_score_local(est_full, debug_full.max_score);
        metrics_full = eval_el_separation_pair_metrics(est_full, az_true, el_true, ...
            full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, 0.15, 0.20, 0.25);

        coarse_cache = build_coarse_cache_local(Z, W, x, y, z, lambda, coarse_records, max_topK, ...
            az_center_search, el_center_search, manifold_opts, search_opts);

        for iConfig = 1:numel(config_records)
            rec = config_records(iConfig);
            compare_full = make_full_compare_local(metrics_full, est_full);
            row_idx = row_idx + 1;
            trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, seed_now, 'full_fine', rec, sweep_phase, ...
                scenario, truth, true_orientation, est_full, az_true, el_true, metrics_full, compare_full, false, ...
                debug_full.num_pairs, debug_full.num_pairs, 0, 0, debug_full.max_score, debug_full.cond_best_GHG, ...
                full_grid_cfg, coarse_cache(1).grid_cfg, make_refine_cfg_from_record_local(rec, full_grid_cfg), ...
                center_bias, w_info, phase_factor, phase_sign);

            coarse_idx = find(strcmp({coarse_cache.name}, rec.coarse_config_name), 1);
            top_candidates = coarse_cache(coarse_idx).top_candidates;
            top_candidates = top_candidates(1:min(rec.topK, numel(top_candidates)));
            refine_cfg = make_refine_cfg_from_record_local(rec, full_grid_cfg);
            [est_refined, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, x, y, z, lambda, ...
                top_candidates, refine_cfg, manifold_opts, search_opts);
            est_refined = attach_score_local(est_refined, refine_debug.max_score);
            metrics_ctf = eval_el_separation_pair_metrics(est_refined, az_true, el_true, ...
                full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, 0.15, 0.20, 0.25);
            compare_ctf = compare_search_outputs(est_refined, est_full, metrics_ctf, metrics_full, ...
                'AzMatchTolDeg', full_search_cfg.az_step / 2, 'ElMatchTolDeg', full_search_cfg.el_step / 2);
            topK_miss = ~topk_covers_full_estimate_local(top_candidates, est_full, refine_cfg);
            coarse_pairs = coarse_cache(coarse_idx).debug.num_pairs;
            refine_pairs = refine_debug.num_pairs;
            total_pairs = coarse_pairs + refine_pairs;
            row_idx = row_idx + 1;
            trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, seed_now, 'coarse_to_fine', rec, sweep_phase, ...
                scenario, truth, true_orientation, est_refined, az_true, el_true, metrics_ctf, compare_ctf, topK_miss, ...
                total_pairs, debug_full.num_pairs, coarse_pairs, refine_pairs, refine_debug.max_score, ...
                refine_debug.cond_best_GHG, full_grid_cfg, coarse_cache(coarse_idx).grid_cfg, refine_cfg, ...
                center_bias, w_info, phase_factor, phase_sign);
        end
    end
    log_lines = append_log_local(log_lines, '%s scenario %d/%d finished, elapsed marker rows=%d', ...
        sweep_phase, iScenario, height(scenario_table), row_idx);
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table);
end

function coarse_cache = build_coarse_cache_local(Z, W, x, y, z, lambda, coarse_records, max_topK, ...
    az_center_search, el_center_search, manifold_opts, search_opts)
coarse_cache = repmat(struct('name', '', 'grid_cfg', struct(), 'top_candidates', [], 'debug', struct()), ...
    numel(coarse_records), 1);
for idx = 1:numel(coarse_records)
    rec = coarse_records(idx);
    search_cfg = make_search_cfg_local(1.5, 1.2, rec.coarse_az_step, rec.coarse_el_step, rec.coarse_el_sep_deg_list);
    grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, search_cfg);
    [top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, x, y, z, lambda, ...
        grid_cfg, manifold_opts, search_opts, max_topK);
    coarse_cache(idx).name = rec.coarse_config_name;
    coarse_cache(idx).grid_cfg = grid_cfg;
    coarse_cache(idx).top_candidates = top_candidates;
    coarse_cache(idx).debug = coarse_debug;
end
end

function coarse_records = unique_coarse_records_local(config_records)
names = unique({config_records.coarse_config_name}, 'stable');
template = config_records(1);
coarse_records = repmat(template, numel(names), 1);
for idx = 1:numel(names)
    hit = find(strcmp({config_records.coarse_config_name}, names{idx}), 1);
    coarse_records(idx) = config_records(hit);
end
end

function refine_cfg = make_refine_cfg_from_record_local(rec, full_grid_cfg)
refine_cfg = make_refine_cfg_local(rec.local_az_half_width, rec.local_el_center_half_width, ...
    rec.fine_az_step, rec.fine_el_step, rec.fine_el_sep_deg_list);
refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;
end

function config_records = build_screening_configs_local()
coarse_configs = [ ...
    make_coarse_config_local('coarse_016_024_compact', 0.16, 0.24, [0, 0.36, 0.48, 0.72]), ...
    make_coarse_config_local('coarse_020_030_compact', 0.20, 0.30, [0, 0.36, 0.48, 0.72]), ...
    make_coarse_config_local('coarse_016_024_minsep', 0.16, 0.24, [0, 0.36, 0.72]), ...
    make_coarse_config_local('coarse_020_030_minsep', 0.20, 0.30, [0, 0.36, 0.72])];
refine_configs = [ ...
    make_refine_config_record_local('refine_small_compact', 0.16, 0.24, 0.08, 0.12, [0, 0.36, 0.48, 0.72]), ...
    make_refine_config_record_local('refine_mid_compact', 0.24, 0.36, 0.08, 0.12, [0, 0.36, 0.48, 0.72]), ...
    make_refine_config_record_local('refine_mid_finer', 0.24, 0.36, 0.04, 0.06, [0, 0.36, 0.48, 0.72]), ...
    make_refine_config_record_local('refine_safe_compact', 0.32, 0.48, 0.08, 0.12, [0, 0.36, 0.48, 0.72]), ...
    make_refine_config_record_local('refine_safe_fullsep', 0.32, 0.48, 0.08, 0.12, [0, 0.24, 0.36, 0.48, 0.60, 0.72]), ...
    make_refine_config_record_local('refine_stage1_safe', 0.32, 0.48, 0.04, 0.06, [0, 0.24, 0.36, 0.48, 0.60, 0.72])];
topK_list = [3, 5, 7, 10];

template = make_config_record_template_local();
config_records = repmat(template, numel(coarse_configs) * numel(topK_list) * numel(refine_configs), 1);
idx = 0;
for iCoarse = 1:numel(coarse_configs)
    for iTopK = 1:numel(topK_list)
        for iRefine = 1:numel(refine_configs)
            idx = idx + 1;
            coarse = coarse_configs(iCoarse);
            refine = refine_configs(iRefine);
            rec = template;
            rec.config_name = sprintf('%s__topK%d__%s', coarse.name, topK_list(iTopK), refine.name);
            rec.coarse_config_name = coarse.name;
            rec.refine_config_name = refine.name;
            rec.topK = topK_list(iTopK);
            rec.coarse_az_step = coarse.az_step;
            rec.coarse_el_step = coarse.el_step;
            rec.coarse_el_sep_deg_list = coarse.el_sep_deg_list;
            rec.local_az_half_width = refine.local_az_half_width;
            rec.local_el_center_half_width = refine.local_el_center_half_width;
            rec.fine_az_step = refine.fine_az_step;
            rec.fine_el_step = refine.fine_el_step;
            rec.fine_el_sep_deg_list = refine.fine_el_sep_deg_list;
            config_records(idx) = rec;
        end
    end
end
end

function row = make_config_record_template_local()
row = struct();
row.config_name = '';
row.coarse_config_name = '';
row.refine_config_name = '';
row.topK = NaN;
row.coarse_az_step = NaN;
row.coarse_el_step = NaN;
row.coarse_el_sep_deg_list = [];
row.local_az_half_width = NaN;
row.local_el_center_half_width = NaN;
row.fine_az_step = NaN;
row.fine_el_step = NaN;
row.fine_el_sep_deg_list = [];
end

function row = make_coarse_config_local(name, az_step, el_step, el_sep_deg_list)
row = struct('name', name, 'az_step', az_step, 'el_step', el_step, ...
    'el_sep_deg_list', el_sep_deg_list);
end

function row = make_refine_config_record_local(name, local_az_half_width, local_el_center_half_width, ...
    fine_az_step, fine_el_step, fine_el_sep_deg_list)
row = struct('name', name, 'local_az_half_width', local_az_half_width, ...
    'local_el_center_half_width', local_el_center_half_width, 'fine_az_step', fine_az_step, ...
    'fine_el_step', fine_el_step, 'fine_el_sep_deg_list', fine_el_sep_deg_list);
end

function [selected_names, note] = select_confirmation_configs_local(metrics_table, max_count)
pass_mask = logical(metrics_table.screening_pass);
if any(pass_mask)
    candidates = metrics_table(pass_mask, :);
    [~, order] = sortrows([-candidates.screening_score, -candidates.complexity_reduction_ratio, ...
        candidates.topK, candidates.coarse_to_fine_rmse]);
    note = 'screening_pass_then_score';
else
    candidates = metrics_table;
    [~, order] = sortrows([-candidates.coarse_to_fine_success, candidates.topK_miss_rate, ...
        -candidates.complexity_reduction_ratio, candidates.coarse_to_fine_rmse]);
    note = 'fallback_success_topK_complexity_rmse';
end
keep_n = min(max_count, height(candidates));
selected_names = cellstr(candidates.config_name(order(1:keep_n)));
end

function selected = select_config_records_local(config_records, selected_names)
template = make_config_record_template_local();
selected = repmat(template, numel(selected_names), 1);
for idx = 1:numel(selected_names)
    hit = find(strcmp({config_records.config_name}, selected_names{idx}), 1);
    if isempty(hit)
        error('run_stage2_topk_grid_sweep:MissingSelectedConfig', 'Missing selected config: %s', selected_names{idx});
    end
    selected(idx) = config_records(hit);
end
end

function metrics_table = build_config_metrics_table_local(summary_table, sweep_phase)
full_rows = summary_table(strcmp(summary_table.search_method, 'full_fine'), :);
ctf_rows = summary_table(strcmp(summary_table.search_method, 'coarse_to_fine'), :);
config_names = unique(ctf_rows.config_name, 'stable');
rows = repmat(make_metric_row_template_local(), numel(config_names), 1);
for idx = 1:numel(config_names)
    config_name = char_value_local(config_names(idx));
    full = full_rows(string_match_local(full_rows.config_name, config_name), :);
    ctf = ctf_rows(string_match_local(ctf_rows.config_name, config_name), :);
    if isempty(full)
        full = full_rows(1, :);
    end
    rows(idx).sweep_phase = sweep_phase;
    rows(idx).config_name = config_name;
    rows(idx).coarse_config_name = char_value_local(ctf.coarse_config_name(1));
    rows(idx).refine_config_name = char_value_local(ctf.refine_config_name(1));
    rows(idx).topK = ctf.topK(1);
    rows(idx).coarse_az_step = ctf.coarse_az_step(1);
    rows(idx).coarse_el_step = ctf.coarse_el_step(1);
    rows(idx).fine_az_step = ctf.fine_az_step(1);
    rows(idx).fine_el_step = ctf.fine_el_step(1);
    rows(idx).local_az_half_width = ctf.local_az_half_width(1);
    rows(idx).local_el_center_half_width = ctf.local_el_center_half_width(1);
    rows(idx).coarse_el_sep_list_text = char_value_local(ctf.coarse_el_sep_deg_list_text(1));
    rows(idx).fine_el_sep_list_text = char_value_local(ctf.fine_el_sep_deg_list_text(1));
    rows(idx).full_fine_success = full.overall_joint_success_rate(1);
    rows(idx).coarse_to_fine_success = ctf.overall_joint_success_rate(1);
    rows(idx).full_fine_rmse = full.overall_combined_rmse_mean(1);
    rows(idx).coarse_to_fine_rmse = ctf.overall_combined_rmse_mean(1);
    rows(idx).full_fine_worst_case_success = full.worst_case_success(1);
    rows(idx).coarse_to_fine_worst_case_success = ctf.worst_case_success(1);
    rows(idx).full_fine_mean_num_pairs = full.overall_mean_num_pairs(1);
    rows(idx).coarse_to_fine_mean_num_pairs = ctf.overall_mean_num_pairs(1);
    rows(idx).coarse_mean_num_pairs = mean_omitnan_local(ctf.mean_coarse_num_pairs);
    rows(idx).refine_mean_num_pairs = mean_omitnan_local(ctf.mean_refine_num_pairs);
    rows(idx).complexity_reduction_ratio = rows(idx).full_fine_mean_num_pairs / ...
        max(rows(idx).coarse_to_fine_mean_num_pairs, eps);
    rows(idx).topK_miss_rate = ctf.overall_topK_miss_rate(1);
    rows(idx).boundary_hit_rate = ctf.overall_boundary_hit_rate(1);
    rows(idx).el_sep_match_rate_vs_full = ctf.overall_el_sep_match_rate_vs_full(1);
    rows(idx).full_grid_match_rate = ctf.overall_full_grid_match_rate(1);
end
metrics_table = struct2table(rows);
end

function metrics_table = add_screening_score_local(metrics_table)
metrics_table.screening_score = metrics_table.coarse_to_fine_success - ...
    2 * max(0, 0.95 * metrics_table.full_fine_success - metrics_table.coarse_to_fine_success) - ...
    metrics_table.topK_miss_rate + ...
    0.1 * log10(max(metrics_table.complexity_reduction_ratio, 1)) - ...
    0.2 * metrics_table.boundary_hit_rate;
metrics_table.screening_pass = metrics_table.coarse_to_fine_success >= 0.95 * metrics_table.full_fine_success & ...
    metrics_table.topK_miss_rate <= 0.10 & ...
    metrics_table.coarse_to_fine_worst_case_success >= 0.8 & ...
    metrics_table.complexity_reduction_ratio >= 1.5;
metrics_table.final_pass = false(height(metrics_table), 1);
end

function metrics_table = add_final_pass_local(metrics_table)
rmse_ok = metrics_table.coarse_to_fine_rmse <= 1.05 * max(metrics_table.full_fine_rmse, eps) | ...
    metrics_table.coarse_to_fine_rmse <= metrics_table.full_fine_rmse + 0.02;
metrics_table.screening_score = metrics_table.coarse_to_fine_success - ...
    2 * max(0, 0.95 * metrics_table.full_fine_success - metrics_table.coarse_to_fine_success) - ...
    metrics_table.topK_miss_rate + ...
    0.1 * log10(max(metrics_table.complexity_reduction_ratio, 1)) - ...
    0.2 * metrics_table.boundary_hit_rate;
metrics_table.screening_pass = metrics_table.coarse_to_fine_success >= 0.95 * metrics_table.full_fine_success & ...
    metrics_table.topK_miss_rate <= 0.10 & ...
    metrics_table.coarse_to_fine_worst_case_success >= 0.8 & ...
    metrics_table.complexity_reduction_ratio >= 1.5;
metrics_table.final_pass = metrics_table.coarse_to_fine_success >= 0.95 * metrics_table.full_fine_success & ...
    rmse_ok & metrics_table.topK_miss_rate <= 0.05 & ...
    metrics_table.boundary_hit_rate <= 0.2 & metrics_table.complexity_reduction_ratio >= 2;
end

function config_table = build_stage2_config_table_local(screening_metrics, confirmation_metrics, selected_names)
screening_metrics.selected_for_confirmation = ismember(cellstr(screening_metrics.config_name), selected_names);
confirmation_metrics.selected_for_confirmation = true(height(confirmation_metrics), 1);
config_table = [screening_metrics; confirmation_metrics];
end

function row = make_metric_row_template_local()
row = struct();
row.sweep_phase = '';
row.config_name = '';
row.coarse_config_name = '';
row.refine_config_name = '';
row.topK = NaN;
row.coarse_az_step = NaN;
row.coarse_el_step = NaN;
row.fine_az_step = NaN;
row.fine_el_step = NaN;
row.local_az_half_width = NaN;
row.local_el_center_half_width = NaN;
row.coarse_el_sep_list_text = '';
row.fine_el_sep_list_text = '';
row.full_fine_success = NaN;
row.coarse_to_fine_success = NaN;
row.full_fine_rmse = NaN;
row.coarse_to_fine_rmse = NaN;
row.full_fine_worst_case_success = NaN;
row.coarse_to_fine_worst_case_success = NaN;
row.full_fine_mean_num_pairs = NaN;
row.coarse_to_fine_mean_num_pairs = NaN;
row.coarse_mean_num_pairs = NaN;
row.refine_mean_num_pairs = NaN;
row.complexity_reduction_ratio = NaN;
row.topK_miss_rate = NaN;
row.boundary_hit_rate = NaN;
row.el_sep_match_rate_vs_full = NaN;
row.full_grid_match_rate = NaN;
end

function trial_row = make_trial_row_template_local()
trial_row = struct();
num_fields = {'trial_global_id','trial_id','seed','topK','coarse_az_step','coarse_el_step','fine_az_step', ...
    'fine_el_step','local_az_half_width','local_el_center_half_width','az_center_bias_deg','el_center_bias_deg', ...
    'rho','phase_deg','beta','az_sep_deg','el_sep_deg','snr_db','source_corr_empirical','true_orientation', ...
    'az_hat_1','az_hat_2','el_hat_1','el_hat_2','az_true_1','az_true_2','el_true_1','el_true_2', ...
    'az_rmse','el_rmse','combined_rmse','boundary_hit','num_pairs','full_num_pairs','coarse_num_pairs', ...
    'refine_num_pairs','reduction_ratio_vs_full','full_grid_match','topK_miss','max_score','cond_best_GHG', ...
    'B','L','phase_factor','phase_sign','az_diff_vs_full','el_diff_vs_full','score_gap_vs_full', ...
    'full_combined_rmse','full_success_test_fail','full_el_sep_hat','test_el_sep_hat','el_sep_diff_vs_full'};
for idx = 1:numel(num_fields)
    trial_row.(num_fields{idx}) = NaN;
end
trial_row.config_name = '';
trial_row.coarse_config_name = '';
trial_row.refine_config_name = '';
trial_row.sweep_phase = '';
trial_row.scenario_name = '';
trial_row.search_method = '';
trial_row.W_method = '';
trial_row.whitening_mode = '';
trial_row.search_param_mode = '';
trial_row.full_el_sep_deg_list_text = '';
trial_row.coarse_el_sep_deg_list_text = '';
trial_row.fine_el_sep_deg_list_text = '';
trial_row.joint_success = false;
trial_row.boundary_hit = false;
trial_row.full_grid_match = false;
trial_row.topK_miss = false;
trial_row.full_success_test_fail = false;
end

function row = make_trial_row_local(row_id, trial_id, seed_now, method, rec, sweep_phase, scenario, truth, ...
    true_orientation, est, az_true, el_true, metrics, compare_now, topK_miss, num_pairs_now, full_num_pairs, ...
    coarse_num_pairs, refine_num_pairs, max_score, cond_best_GHG, full_grid_cfg, coarse_grid_cfg, refine_cfg, ...
    center_bias, w_info, phase_factor, phase_sign)
row = make_trial_row_template_local();
row.trial_global_id = row_id;
row.trial_id = trial_id;
row.seed = seed_now;
row.config_name = rec.config_name;
row.coarse_config_name = rec.coarse_config_name;
row.refine_config_name = rec.refine_config_name;
row.sweep_phase = sweep_phase;
row.scenario_name = scenario.scenario_name;
row.search_method = method;
row.W_method = sprintf('greedy_%s_B%d', w_info.criterion, w_info.B);
row.whitening_mode = 'white';
row.search_param_mode = 'degree_based_el_sep';
row.topK = rec.topK;
row.coarse_az_step = rec.coarse_az_step;
row.coarse_el_step = rec.coarse_el_step;
row.fine_az_step = rec.fine_az_step;
row.fine_el_step = rec.fine_el_step;
row.local_az_half_width = rec.local_az_half_width;
row.local_el_center_half_width = rec.local_el_center_half_width;
row.az_center_bias_deg = center_bias(1);
row.el_center_bias_deg = center_bias(2);
row.full_el_sep_deg_list_text = numeric_list_text_local(full_grid_cfg.el_sep_deg_list);
row.coarse_el_sep_deg_list_text = numeric_list_text_local(coarse_grid_cfg.el_sep_deg_list);
row.fine_el_sep_deg_list_text = numeric_list_text_local(refine_cfg.fine_el_sep_deg_list);
row.rho = scenario.rho;
row.phase_deg = scenario.phase_deg;
row.beta = scenario.beta;
row.az_sep_deg = scenario.az_sep_deg;
row.el_sep_deg = scenario.el_sep_deg;
row.snr_db = scenario.snr_db;
row.source_corr_empirical = truth.source_corr_empirical;
row.true_orientation = true_orientation;
row.az_hat_1 = est.az_hat(1);
row.az_hat_2 = est.az_hat(2);
row.el_hat_1 = est.el_hat(1);
row.el_hat_2 = est.el_hat(2);
row.az_true_1 = az_true(1);
row.az_true_2 = az_true(2);
row.el_true_1 = el_true(1);
row.el_true_2 = el_true(2);
row.joint_success = logical(metrics.joint_pair_tol_success);
row.az_rmse = metrics.az_rmse_deg;
row.el_rmse = metrics.el_rmse_deg;
row.combined_rmse = compare_now.test_rmse;
row.boundary_hit = logical(metrics.boundary_hit);
row.num_pairs = num_pairs_now;
row.full_num_pairs = full_num_pairs;
row.coarse_num_pairs = coarse_num_pairs;
row.refine_num_pairs = refine_num_pairs;
row.reduction_ratio_vs_full = full_num_pairs / max(num_pairs_now, eps);
row.full_grid_match = logical(compare_now.same_as_full_grid);
row.topK_miss = logical(topK_miss);
row.max_score = max_score;
row.cond_best_GHG = cond_best_GHG;
row.B = w_info.B;
row.L = 64;
row.phase_factor = phase_factor;
row.phase_sign = phase_sign;
row.az_diff_vs_full = compare_now.az_diff_vs_full;
row.el_diff_vs_full = compare_now.el_diff_vs_full;
row.score_gap_vs_full = compare_now.score_gap_vs_full;
row.full_combined_rmse = compare_now.full_rmse;
row.full_success_test_fail = logical(compare_now.full_success_test_fail);
row.full_el_sep_hat = compare_now.full_el_sep_hat;
row.test_el_sep_hat = compare_now.test_el_sep_hat;
row.el_sep_diff_vs_full = compare_now.el_sep_diff_vs_full;
end

function summary_table = build_summary_table_local(trial_table)
group_fields = {'search_method','scenario_name','config_name','coarse_config_name','refine_config_name','sweep_phase', ...
    'topK','coarse_az_step','coarse_el_step','fine_az_step','fine_el_step','local_az_half_width', ...
    'local_el_center_half_width','az_center_bias_deg','el_center_bias_deg','rho','phase_deg','beta', ...
    'az_sep_deg','el_sep_deg','snr_db','B','W_method','search_param_mode','full_el_sep_deg_list_text', ...
    'coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text'};
groups = unique(trial_table(:, group_fields), 'rows');
rows = repmat(make_summary_row_template_local(), height(groups), 1);
for iGroup = 1:height(groups)
    mask = true(height(trial_table), 1);
    for iField = 1:numel(group_fields)
        field = group_fields{iField};
        mask = mask & match_value_local(trial_table.(field), groups.(field)(iGroup));
    end
    sub = trial_table(mask, :);
    rows(iGroup) = make_summary_row_from_group_local(groups(iGroup, :), sub);
end
summary_table = struct2table(rows);
summary_table = add_overall_aggregates_local(summary_table);
end

function row = make_summary_row_template_local()
row = struct();
char_fields = {'search_method','scenario_name','config_name','coarse_config_name','refine_config_name','sweep_phase', ...
    'W_method','search_param_mode','full_el_sep_deg_list_text','coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text'};
for idx = 1:numel(char_fields)
    row.(char_fields{idx}) = '';
end
num_fields = {'topK','coarse_az_step','coarse_el_step','fine_az_step','fine_el_step','local_az_half_width', ...
    'local_el_center_half_width','az_center_bias_deg','el_center_bias_deg','rho','phase_deg','beta', ...
    'az_sep_deg','el_sep_deg','snr_db','B','joint_success_rate','az_rmse_mean','el_rmse_mean', ...
    'combined_rmse_mean','boundary_hit_rate','mean_num_pairs','mean_full_num_pairs','mean_coarse_num_pairs', ...
    'mean_refine_num_pairs','mean_reduction_ratio_vs_full','full_grid_match_rate','topK_miss_rate', ...
    'full_success_test_fail_rate','el_sep_match_rate_vs_full','n_trials','overall_joint_success_rate', ...
    'overall_combined_rmse_mean','worst_case_success','overall_boundary_hit_rate','overall_mean_num_pairs', ...
    'overall_az_rmse_mean','overall_el_rmse_mean','overall_mean_reduction_ratio_vs_full', ...
    'overall_full_grid_match_rate','overall_topK_miss_rate','overall_el_sep_match_rate_vs_full'};
for idx = 1:numel(num_fields)
    row.(num_fields{idx}) = NaN;
end
end

function row = make_summary_row_from_group_local(group, sub)
row = make_summary_row_template_local();
names = group.Properties.VariableNames;
for idx = 1:numel(names)
    value = group.(names{idx});
    if iscell(value) || isstring(value)
        row.(names{idx}) = char_value_local(value(1));
    else
        row.(names{idx}) = value(1);
    end
end
row.joint_success_rate = mean(double(sub.joint_success));
row.az_rmse_mean = mean_omitnan_local(sub.az_rmse);
row.el_rmse_mean = mean_omitnan_local(sub.el_rmse);
row.combined_rmse_mean = mean_omitnan_local(sub.combined_rmse);
row.boundary_hit_rate = mean(double(sub.boundary_hit));
row.mean_num_pairs = mean_omitnan_local(sub.num_pairs);
row.mean_full_num_pairs = mean_omitnan_local(sub.full_num_pairs);
row.mean_coarse_num_pairs = mean_omitnan_local(sub.coarse_num_pairs);
row.mean_refine_num_pairs = mean_omitnan_local(sub.refine_num_pairs);
row.mean_reduction_ratio_vs_full = mean_omitnan_local(sub.reduction_ratio_vs_full);
row.full_grid_match_rate = mean(double(sub.full_grid_match));
row.topK_miss_rate = mean(double(sub.topK_miss));
row.full_success_test_fail_rate = mean(double(sub.full_success_test_fail));
row.el_sep_match_rate_vs_full = mean(double(abs(sub.el_sep_diff_vs_full) <= max(sub.fine_el_step(1) / 2, 1e-9)));
row.n_trials = height(sub);
end

function summary_table = add_overall_aggregates_local(summary_table)
config_fields = {'search_method','config_name','coarse_config_name','refine_config_name','sweep_phase','topK', ...
    'coarse_az_step','coarse_el_step','fine_az_step','fine_el_step','local_az_half_width', ...
    'local_el_center_half_width','az_center_bias_deg','el_center_bias_deg','B','W_method','search_param_mode', ...
    'full_el_sep_deg_list_text','coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text'};
for idx = 1:height(summary_table)
    mask = true(height(summary_table), 1);
    for iField = 1:numel(config_fields)
        field = config_fields{iField};
        mask = mask & match_value_local(summary_table.(field), summary_table.(field)(idx));
    end
    sub = summary_table(mask, :);
    summary_table.overall_joint_success_rate(idx) = mean_omitnan_local(sub.joint_success_rate);
    summary_table.overall_az_rmse_mean(idx) = mean_omitnan_local(sub.az_rmse_mean);
    summary_table.overall_el_rmse_mean(idx) = mean_omitnan_local(sub.el_rmse_mean);
    summary_table.overall_combined_rmse_mean(idx) = mean_omitnan_local(sub.combined_rmse_mean);
    summary_table.worst_case_success(idx) = min_omitnan_local(sub.joint_success_rate);
    summary_table.overall_boundary_hit_rate(idx) = mean_omitnan_local(sub.boundary_hit_rate);
    summary_table.overall_mean_num_pairs(idx) = mean_omitnan_local(sub.mean_num_pairs);
    summary_table.overall_mean_reduction_ratio_vs_full(idx) = mean_omitnan_local(sub.mean_reduction_ratio_vs_full);
    summary_table.overall_full_grid_match_rate(idx) = mean_omitnan_local(sub.full_grid_match_rate);
    summary_table.overall_topK_miss_rate(idx) = mean_omitnan_local(sub.topK_miss_rate);
    summary_table.overall_el_sep_match_rate_vs_full(idx) = mean_omitnan_local(sub.el_sep_match_rate_vs_full);
end
end

function compare_now = make_full_compare_local(metrics_full, est_full)
compare_now = struct();
compare_now.same_as_full_grid = true;
compare_now.az_diff_vs_full = 0;
compare_now.el_diff_vs_full = 0;
compare_now.score_gap_vs_full = 0;
compare_now.test_rmse = hypot(metrics_full.az_rmse_deg, metrics_full.el_rmse_deg);
compare_now.full_rmse = compare_now.test_rmse;
compare_now.full_success_test_fail = false;
compare_now.full_el_sep_hat = est_full.el_sep_hat;
compare_now.test_el_sep_hat = est_full.el_sep_hat;
compare_now.el_sep_diff_vs_full = 0;
end

function covered = topk_covers_full_estimate_local(top_candidates, est_full, refine_cfg)
covered = false;
az_full = sort(est_full.az_hat(:).');
el_center_full = est_full.el_center_hat;
el_sep_full = est_full.el_sep_hat;
fine_sep_list = refine_cfg.fine_el_sep_deg_list(:).';
for idx = 1:numel(top_candidates)
    cand = top_candidates(idx);
    az_cand = sort(cand.az_hat(:).');
    az1_bounds = clamp_bounds_local(az_cand(1) + [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width], ...
        refine_cfg.az_global_bounds);
    az2_bounds = clamp_bounds_local(az_cand(2) + [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width], ...
        refine_cfg.az_global_bounds);
    el_center_bounds = clamp_bounds_local(cand.el_center_hat + ...
        [-refine_cfg.local_el_center_half_width, refine_cfg.local_el_center_half_width], refine_cfg.el_global_bounds);
    sep_match = any(abs(fine_sep_list - el_sep_full) <= max(refine_cfg.fine_el_step / 2, 1e-9));
    if az_full(1) >= az1_bounds(1) - 1e-9 && az_full(1) <= az1_bounds(2) + 1e-9 && ...
            az_full(2) >= az2_bounds(1) - 1e-9 && az_full(2) <= az2_bounds(2) + 1e-9 && ...
            el_center_full >= el_center_bounds(1) - 1e-9 && el_center_full <= el_center_bounds(2) + 1e-9 && ...
            sep_match
        covered = true;
        return;
    end
end
end

function bounds = clamp_bounds_local(bounds, global_bounds)
global_bounds = sort(global_bounds(:).');
bounds = sort(bounds(:).');
bounds(1) = max(bounds(1), global_bounds(1));
bounds(2) = min(bounds(2), global_bounds(2));
end

function est = attach_score_local(est, score)
est.max_score = score;
est.score = score;
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

function scenario_table = normalize_scenarios_local(scenarios)
if istable(scenarios)
    scenario_table = scenarios;
else
    scenario_table = struct2table(scenarios);
end
end

function scenario = table_row_to_struct_local(row_table)
scenario = struct();
names = row_table.Properties.VariableNames;
for idx = 1:numel(names)
    value = row_table.(names{idx});
    if iscell(value)
        value = value{1};
    elseif isstring(value)
        value = char(value);
    end
    scenario.(names{idx}) = value;
end
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

function text = numeric_list_text_local(values)
values = values(:).';
parts = cell(1, numel(values));
for idx = 1:numel(values)
    parts{idx} = sprintf('%.12g', values(idx));
end
text = ['[', strjoin(parts, ','), ']'];
end

function mask = match_value_local(values, target)
if iscell(values) || isstring(values) || ischar(target)
    mask = string_match_local(values, char_value_local(target));
else
    mask = abs(values - target) < 1e-12;
end
end

function mask = string_match_local(values, target)
if iscell(values)
    mask = strcmp(values, target);
elseif isstring(values)
    mask = strcmp(values, string(target));
else
    mask = strcmp(cellstr(values), target);
end
end

function value = char_value_local(value_in)
if iscell(value_in)
    value = value_in{1};
elseif isstring(value_in)
    value = char(value_in);
else
    value = char(value_in);
end
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

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function v = min_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = min(x);
end
end
