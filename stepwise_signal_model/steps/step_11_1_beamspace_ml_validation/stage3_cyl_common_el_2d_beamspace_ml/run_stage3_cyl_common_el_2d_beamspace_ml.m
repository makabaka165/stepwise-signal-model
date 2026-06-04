clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_1_cyl_common_el_2d_beamspace_ml');

addpath(common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.1 Stage3 starts');
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
    error('run_stage3:NelemMismatch', 'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;

base_seed = 20260613;
L = 64;
Metkl = 5;
az_center_true = cfg.beam.azSectorCenter;
el_center_nominal = cfg.beam.elSectorCenter;
az_sep_list = [0.73, 1.17];
el_true_offset_list = [-0.37, 0.43];
snr_list = [15, 25];
center_bias_cases = [ ...
     0.0,  0.0; ...
     0.2,  0.0; ...
     0.0,  0.2; ...
    -0.2, -0.2];

beam_layouts = struct( ...
    'name', {'az3_el3', 'az5_el3', 'az5_el5'}, ...
    'az_count', {3, 5, 5}, ...
    'el_count', {3, 3, 5});

source_mode_list = {'noncoherent'};
whitening_mode_list = {'none', 'white'};
az_search_half_width = 1.4;
el_search_half_width = 1.0;
az_beam_span = 2.0;
el_beam_span = 1.4;
az_grid_step_deg = 0.05;
el_grid_step_deg = 0.10;
az_tol_deg = 0.12;
el_tol_deg = 0.15;
reg = 1e-10;

log_lines = append_log_local(log_lines, 'cfg.arr: Naz=%d, Nel=%d, fc=%.6g, lambda=%.12g, R=%.6g, dz=%.6g', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.fc, cfg.arr.lambda, cfg.arr.R, cfg.arr.dz);
log_lines = append_log_local(log_lines, 'cfg.beam.subNaz=%d, arrInfo.nAct=%d, expected_N_elem=%d', ...
    cfg.beam.subNaz, arrInfo.nAct, expected_N_elem);
log_lines = append_log_local(log_lines, 'phase_factor=%.6g, phase_sign=%+.0f', phase_factor, phase_sign);
log_lines = append_log_local(log_lines, 'base_seed=%d, L=%d, Metkl=%d', base_seed, L, Metkl);
log_lines = append_log_local(log_lines, 'az_sep_list=%s, el_true_offset_list=%s, snr_list=%s', ...
    mat2str(az_sep_list), mat2str(el_true_offset_list), mat2str(snr_list));
log_lines = append_log_local(log_lines, 'center_bias_cases=%s', mat2str(center_bias_cases));
log_lines = append_log_local(log_lines, 'beam_layouts=%s', strjoin({beam_layouts.name}, ','));
log_lines = append_log_local(log_lines, 'source_mode_list=%s, whitening_mode_list=%s', ...
    strjoin(source_mode_list, ','), strjoin(whitening_mode_list, ','));
log_lines = append_log_local(log_lines, ...
    'az_search_half_width=%.3f, el_search_half_width=%.3f, az_beam_span=%.3f, el_beam_span=%.3f', ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span);
log_lines = append_log_local(log_lines, ...
    'az_grid_step_deg=%.3f, el_grid_step_deg=%.3f, az_tol_deg=%.3f, el_tol_deg=%.3f', ...
    az_grid_step_deg, el_grid_step_deg, az_tol_deg, el_tol_deg);

cache = build_beam_grid_cache_local(x, y, z, center_bias_cases, beam_layouts, ...
    az_center_true, el_center_nominal, lambda, phase_factor, phase_sign, ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span, ...
    az_grid_step_deg, el_grid_step_deg);
log_lines = append_log_local(log_lines, 'Precomputed %d beam/grid cache entries.', numel(cache));

total_rows = numel(source_mode_list) * numel(az_sep_list) * numel(el_true_offset_list) * ...
    numel(snr_list) * size(center_bias_cases, 1) * numel(beam_layouts) * ...
    numel(whitening_mode_list) * Metkl;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

tic;
for iSource = 1:numel(source_mode_list)
    source_mode = source_mode_list{iSource};
    for iSep = 1:numel(az_sep_list)
        az_sep = az_sep_list(iSep);
        az_true = [az_center_true - az_sep/2, az_center_true + az_sep/2];
        for iElOff = 1:numel(el_true_offset_list)
            el_true_offset = el_true_offset_list(iElOff);
            el_true = el_center_nominal + el_true_offset;
            for iSnr = 1:numel(snr_list)
                snr_db = snr_list(iSnr);

                for trial_id = 1:Metkl
                    seed_now = base_seed + 100000*iSource + 10000*iSep + 1000*iElOff + 100*iSnr + trial_id;
                    [Y, truth] = make_cyl_common_el_snapshots(x, y, z, az_true, el_true, lambda, L, snr_db, source_mode, ...
                        'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Seed', seed_now);
                    if ~isequal(size(Y), [N_elem, L])
                        error('run_stage3:YShapeMismatch', 'Y must be N_elem x L.');
                    end

                    for iCache = 1:numel(cache)
                        W = cache(iCache).W;
                        beam_info = cache(iCache).beam_info;
                        grid = cache(iCache).grid;
                        Z = W' * Y;
                        if ~isequal(size(Z), [cache(iCache).beam_count, L])
                            error('run_stage3:ZShapeMismatch', 'Z must be beam_count x L.');
                        end

                        A_truth = build_cyl_pair_manifold_common_el(x, y, z, az_true, el_true, lambda, ...
                            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
                        G_truth = W' * A_truth;

                        for iWhite = 1:numel(whitening_mode_list)
                            whitening_mode = whitening_mode_list{iWhite};
                            search_cfg = struct();
                            search_cfg.whitening_mode = whitening_mode;
                            search_cfg.reg = reg;

                            [est, ~, search_debug] = search_pair_grid_common_el_precomputed(Z, W, grid, search_cfg);
                            metrics = eval_common_el_pair_metrics(est, az_true, el_true, cache(iCache).az_bounds, ...
                                cache(iCache).el_bounds, az_tol_deg, el_tol_deg);

                            [~, G_truth_use] = apply_beamspace_whitening(Z, G_truth, W, whitening_mode, 'eps_reg', reg);
                            g1 = G_truth_use(:, 1);
                            g2 = G_truth_use(:, 2);
                            manifold_corr = abs(g1' * g2) / max(norm(g1) * norm(g2), eps);

                            row_idx = row_idx + 1;
                            trial_rows(row_idx).trial_id = trial_id;
                            trial_rows(row_idx).source_mode = truth.source_mode;
                            trial_rows(row_idx).whitening_mode = whitening_mode;
                            trial_rows(row_idx).beam_layout_name = cache(iCache).beam_layout_name;
                            trial_rows(row_idx).beam_az_count = cache(iCache).beam_az_count;
                            trial_rows(row_idx).beam_el_count = cache(iCache).beam_el_count;
                            trial_rows(row_idx).beam_count = cache(iCache).beam_count;
                            trial_rows(row_idx).az_center_bias_deg = cache(iCache).az_center_bias_deg;
                            trial_rows(row_idx).el_center_bias_deg = cache(iCache).el_center_bias_deg;
                            trial_rows(row_idx).az_beam_c = cache(iCache).az_beam_c;
                            trial_rows(row_idx).el_beam_c = cache(iCache).el_beam_c;
                            trial_rows(row_idx).az_sep_deg = az_sep;
                            trial_rows(row_idx).el_true_offset_deg = el_true_offset;
                            trial_rows(row_idx).snr_db = snr_db;
                            trial_rows(row_idx).az_hat_1 = est.az_hat(1);
                            trial_rows(row_idx).az_hat_2 = est.az_hat(2);
                            trial_rows(row_idx).el_hat = est.el_hat;
                            trial_rows(row_idx).az_true_1 = az_true(1);
                            trial_rows(row_idx).az_true_2 = az_true(2);
                            trial_rows(row_idx).el_true = el_true;
                            trial_rows(row_idx).raw_success = metrics.raw_success;
                            trial_rows(row_idx).az_tol_success = metrics.az_tol_success;
                            trial_rows(row_idx).el_tol_success = metrics.el_tol_success;
                            trial_rows(row_idx).joint_tol_success = metrics.joint_tol_success;
                            trial_rows(row_idx).az_rmse_deg = metrics.az_rmse_deg;
                            trial_rows(row_idx).az_center_error_deg = metrics.az_center_error_deg;
                            trial_rows(row_idx).az_sep_error_deg = metrics.az_sep_error_deg;
                            trial_rows(row_idx).el_error_deg = metrics.el_error_deg;
                            trial_rows(row_idx).abs_el_error_deg = metrics.abs_el_error_deg;
                            trial_rows(row_idx).boundary_hit = metrics.boundary_hit;
                            trial_rows(row_idx).manifold_corr_truth = manifold_corr;
                            trial_rows(row_idx).cond_WHW = beam_info.cond_WHW;
                            trial_rows(row_idx).cond_best_GHG = search_debug.cond_best_GHG;
                            trial_rows(row_idx).max_score = search_debug.max_score;
                            trial_rows(row_idx).num_pairs = search_debug.num_pairs;
                            trial_rows(row_idx).N_elem = N_elem;
                            trial_rows(row_idx).L = L;
                            trial_rows(row_idx).phase_factor = phase_factor;
                            trial_rows(row_idx).phase_sign = phase_sign;
                        end
                    end
                end

                log_lines = append_log_local(log_lines, ...
                    'Completed az_sep=%.2f, el_offset=%.2f, snr=%.1f dB, rows=%d/%d, elapsed %.2f s', ...
                    az_sep, el_true_offset, snr_db, row_idx, total_rows, toc);
            end
        end
    end
end

if row_idx ~= total_rows
    error('run_stage3:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
if isempty(trial_table)
    error('run_stage3:EmptyTrialTable', 'trial_table is empty.');
end

summary_rows = build_summary_rows_local(trial_table, source_mode_list, whitening_mode_list, ...
    beam_layouts, center_bias_cases, az_sep_list, el_true_offset_list, snr_list);
summary_table = struct2table(summary_rows);
if isempty(summary_table)
    error('run_stage3:EmptySummaryTable', 'summary_table is empty.');
end

[keypoint_rows, keypoints] = build_keypoints_local(summary_table, beam_layouts);
keypoint_table = struct2table(keypoint_rows);
if isempty(keypoint_table)
    error('run_stage3:EmptyKeypointTable', 'keypoint_table is empty.');
end

trial_csv = fullfile(result_dir, 'step11_1_cyl_common_el_2d_trial.csv');
summary_csv = fullfile(result_dir, 'step11_1_cyl_common_el_2d_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_1_cyl_common_el_2d_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_1_cyl_common_el_2d_result.mat');
log_path = fullfile(result_dir, 'step11_1_cyl_common_el_2d.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
plot_paths = make_plots_local(summary_table, result_dir, beam_layouts, snr_list, center_bias_cases);

params = struct();
params.base_seed = base_seed;
params.L = L;
params.Metkl = Metkl;
params.az_center_true = az_center_true;
params.el_center_nominal = el_center_nominal;
params.az_sep_list = az_sep_list;
params.el_true_offset_list = el_true_offset_list;
params.snr_list = snr_list;
params.center_bias_cases = center_bias_cases;
params.beam_layouts = beam_layouts;
params.source_mode_list = source_mode_list;
params.whitening_mode_list = whitening_mode_list;
params.az_search_half_width = az_search_half_width;
params.el_search_half_width = el_search_half_width;
params.az_beam_span = az_beam_span;
params.el_beam_span = el_beam_span;
params.az_grid_step_deg = az_grid_step_deg;
params.el_grid_step_deg = el_grid_step_deg;
params.az_tol_deg = az_tol_deg;
params.el_tol_deg = el_tol_deg;
params.N_elem = N_elem;
params.phase_factor = phase_factor;
params.phase_sign = phase_sign;
params.lambda = lambda;

save(mat_path, 'params', 'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_log_local(log_lines, 'cyl_common_el_2d_pass_flag=%d', keypoints.cyl_common_el_2d_pass_flag);
log_lines = append_log_local(log_lines, 'recommended_next_step=%s', keypoints.recommended_next_step);
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function cache = build_beam_grid_cache_local(x, y, z, center_bias_cases, beam_layouts, ...
    az_center_true, el_center_nominal, lambda, phase_factor, phase_sign, ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span, ...
    az_grid_step_deg, el_grid_step_deg)
template = struct();
template.az_center_bias_deg = NaN;
template.el_center_bias_deg = NaN;
template.az_beam_c = NaN;
template.el_beam_c = NaN;
template.az_bounds = [NaN, NaN];
template.el_bounds = [NaN, NaN];
template.beam_layout_name = '';
template.beam_az_count = NaN;
template.beam_el_count = NaN;
template.beam_count = NaN;
template.beam_az = [];
template.beam_el = [];
template.az_grid = [];
template.el_grid = [];
template.W = [];
template.beam_info = struct();
template.grid = struct();

cache = repmat(template, size(center_bias_cases, 1) * numel(beam_layouts), 1);
idx = 0;
for iBias = 1:size(center_bias_cases, 1)
    az_center_bias = center_bias_cases(iBias, 1);
    el_center_bias = center_bias_cases(iBias, 2);
    az_beam_c = az_center_true + az_center_bias;
    el_beam_c = el_center_nominal + el_center_bias;
    az_bounds = [az_beam_c - az_search_half_width, az_beam_c + az_search_half_width];
    el_bounds = [el_beam_c - el_search_half_width, el_beam_c + el_search_half_width];
    az_grid = az_bounds(1):az_grid_step_deg:az_bounds(2);
    el_grid = el_bounds(1):el_grid_step_deg:el_bounds(2);

    for iLayout = 1:numel(beam_layouts)
        layout = beam_layouts(iLayout);
        beam_az = linspace(az_beam_c - az_beam_span, az_beam_c + az_beam_span, layout.az_count);
        beam_el = linspace(el_beam_c - el_beam_span, el_beam_c + el_beam_span, layout.el_count);
        [W, beam_info] = build_cyl_azel_beam_transform(x, y, z, beam_az, beam_el, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
        grid = precompute_beamspace_azel_grid(W, x, y, z, az_grid, el_grid, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);

        idx = idx + 1;
        cache(idx).az_center_bias_deg = az_center_bias;
        cache(idx).el_center_bias_deg = el_center_bias;
        cache(idx).az_beam_c = az_beam_c;
        cache(idx).el_beam_c = el_beam_c;
        cache(idx).az_bounds = az_bounds;
        cache(idx).el_bounds = el_bounds;
        cache(idx).beam_layout_name = layout.name;
        cache(idx).beam_az_count = layout.az_count;
        cache(idx).beam_el_count = layout.el_count;
        cache(idx).beam_count = layout.az_count * layout.el_count;
        cache(idx).beam_az = beam_az;
        cache(idx).beam_el = beam_el;
        cache(idx).az_grid = az_grid;
        cache(idx).el_grid = el_grid;
        cache(idx).W = W;
        cache(idx).beam_info = beam_info;
        cache(idx).grid = grid;
    end
end
end

function row = make_trial_row_template_local()
row = struct();
row.trial_id = NaN;
row.source_mode = '';
row.whitening_mode = '';
row.beam_layout_name = '';
row.beam_az_count = NaN;
row.beam_el_count = NaN;
row.beam_count = NaN;
row.az_center_bias_deg = NaN;
row.el_center_bias_deg = NaN;
row.az_beam_c = NaN;
row.el_beam_c = NaN;
row.az_sep_deg = NaN;
row.el_true_offset_deg = NaN;
row.snr_db = NaN;
row.az_hat_1 = NaN;
row.az_hat_2 = NaN;
row.el_hat = NaN;
row.az_true_1 = NaN;
row.az_true_2 = NaN;
row.el_true = NaN;
row.raw_success = false;
row.az_tol_success = false;
row.el_tol_success = false;
row.joint_tol_success = false;
row.az_rmse_deg = NaN;
row.az_center_error_deg = NaN;
row.az_sep_error_deg = NaN;
row.el_error_deg = NaN;
row.abs_el_error_deg = NaN;
row.boundary_hit = false;
row.manifold_corr_truth = NaN;
row.cond_WHW = NaN;
row.cond_best_GHG = NaN;
row.max_score = NaN;
row.num_pairs = NaN;
row.N_elem = NaN;
row.L = NaN;
row.phase_factor = NaN;
row.phase_sign = NaN;
end

function rows = build_summary_rows_local(trial_table, source_mode_list, whitening_mode_list, ...
    beam_layouts, center_bias_cases, az_sep_list, el_true_offset_list, snr_list)
template = struct();
template.source_mode = '';
template.whitening_mode = '';
template.beam_layout_name = '';
template.beam_count = NaN;
template.az_center_bias_deg = NaN;
template.el_center_bias_deg = NaN;
template.az_sep_deg = NaN;
template.el_true_offset_deg = NaN;
template.snr_db = NaN;
template.raw_success_rate = NaN;
template.az_tol_success_rate = NaN;
template.el_tol_success_rate = NaN;
template.joint_tol_success_rate = NaN;
template.mean_az_rmse_deg = NaN;
template.median_az_rmse_deg = NaN;
template.mean_abs_az_center_error_deg = NaN;
template.mean_abs_az_sep_error_deg = NaN;
template.mean_abs_el_error_deg = NaN;
template.boundary_hit_rate = NaN;
template.mean_manifold_corr_truth = NaN;
template.mean_cond_WHW = NaN;
template.mean_cond_best_GHG = NaN;
template.mean_num_pairs = NaN;

nRows = numel(source_mode_list) * numel(whitening_mode_list) * numel(beam_layouts) * ...
    size(center_bias_cases, 1) * numel(az_sep_list) * numel(el_true_offset_list) * numel(snr_list);
rows = repmat(template, nRows, 1);
idx = 0;

for iSource = 1:numel(source_mode_list)
    source_mode = source_mode_list{iSource};
    source_mask = string_match_local(trial_table.source_mode, source_mode);
    for iWhite = 1:numel(whitening_mode_list)
        whitening_mode = whitening_mode_list{iWhite};
        white_mask = string_match_local(trial_table.whitening_mode, whitening_mode);
        for iLayout = 1:numel(beam_layouts)
            layout = beam_layouts(iLayout);
            layout_mask = string_match_local(trial_table.beam_layout_name, layout.name);
            for iBias = 1:size(center_bias_cases, 1)
                az_bias = center_bias_cases(iBias, 1);
                el_bias = center_bias_cases(iBias, 2);
                for iSep = 1:numel(az_sep_list)
                    az_sep = az_sep_list(iSep);
                    for iElOff = 1:numel(el_true_offset_list)
                        el_off = el_true_offset_list(iElOff);
                        for iSnr = 1:numel(snr_list)
                            snr_db = snr_list(iSnr);
                            mask = source_mask & white_mask & layout_mask & ...
                                abs(trial_table.az_center_bias_deg - az_bias) < 1e-12 & ...
                                abs(trial_table.el_center_bias_deg - el_bias) < 1e-12 & ...
                                abs(trial_table.az_sep_deg - az_sep) < 1e-12 & ...
                                abs(trial_table.el_true_offset_deg - el_off) < 1e-12 & ...
                                abs(trial_table.snr_db - snr_db) < 1e-12;
                            sub = trial_table(mask, :);
                            if isempty(sub)
                                error('run_stage3:MissingSummaryGroup', ...
                                    'Missing group source=%s white=%s layout=%s bias=[%.2f %.2f] sep=%.2f eloff=%.2f snr=%.1f.', ...
                                    source_mode, whitening_mode, layout.name, az_bias, el_bias, az_sep, el_off, snr_db);
                            end

                            idx = idx + 1;
                            rows(idx).source_mode = source_mode;
                            rows(idx).whitening_mode = whitening_mode;
                            rows(idx).beam_layout_name = layout.name;
                            rows(idx).beam_count = layout.az_count * layout.el_count;
                            rows(idx).az_center_bias_deg = az_bias;
                            rows(idx).el_center_bias_deg = el_bias;
                            rows(idx).az_sep_deg = az_sep;
                            rows(idx).el_true_offset_deg = el_off;
                            rows(idx).snr_db = snr_db;
                            rows(idx).raw_success_rate = mean(double(sub.raw_success));
                            rows(idx).az_tol_success_rate = mean(double(sub.az_tol_success));
                            rows(idx).el_tol_success_rate = mean(double(sub.el_tol_success));
                            rows(idx).joint_tol_success_rate = mean(double(sub.joint_tol_success));
                            rows(idx).mean_az_rmse_deg = mean_omitnan_local(sub.az_rmse_deg);
                            rows(idx).median_az_rmse_deg = median_omitnan_local(sub.az_rmse_deg);
                            rows(idx).mean_abs_az_center_error_deg = mean_omitnan_local(abs(sub.az_center_error_deg));
                            rows(idx).mean_abs_az_sep_error_deg = mean_omitnan_local(abs(sub.az_sep_error_deg));
                            rows(idx).mean_abs_el_error_deg = mean_omitnan_local(sub.abs_el_error_deg);
                            rows(idx).boundary_hit_rate = mean(double(sub.boundary_hit));
                            rows(idx).mean_manifold_corr_truth = mean_omitnan_local(sub.manifold_corr_truth);
                            rows(idx).mean_cond_WHW = mean_omitnan_local(sub.cond_WHW);
                            rows(idx).mean_cond_best_GHG = mean_omitnan_local(sub.cond_best_GHG);
                            rows(idx).mean_num_pairs = mean_omitnan_local(sub.num_pairs);
                        end
                    end
                end
            end
        end
    end
end
end

function [rows, keypoints] = build_keypoints_local(summary_table, beam_layouts)
white_sub = select_pass_subset_local(summary_table, 'white');
none_sub = select_pass_subset_local(summary_table, 'none');
[best_white_joint, best_white_layout, mean_corr_best, mean_el_err_best, boundary_best] = ...
    best_layout_stats_local(white_sub, beam_layouts);
[best_none_joint, ~, ~, ~, ~] = best_layout_stats_local(none_sub, beam_layouts);
white_gap = best_white_joint - best_none_joint;

pass_flag = double(best_white_joint >= 0.8 && mean_el_err_best <= 0.15 && boundary_best <= 0.2);
if pass_flag == 1
    recommended_next_step = 'proceed_to_cylindrical_el_separation_or_coherence_stress';
else
    recommended_next_step = 'debug_2d_beam_layout_el_grid_or_phase_convention';
end

keypoints = struct();
keypoints.best_white_joint_success_bias0_snr25 = best_white_joint;
keypoints.best_none_joint_success_bias0_snr25 = best_none_joint;
keypoints.white_minus_none_joint_success_gap_bias0_snr25 = white_gap;
keypoints.best_layout_white_bias0_snr25 = best_white_layout;
keypoints.max_boundary_hit_rate = max(summary_table.boundary_hit_rate);
keypoints.mean_manifold_corr_at_best = mean_corr_best;
keypoints.mean_abs_el_error_at_best = mean_el_err_best;
keypoints.cyl_common_el_2d_pass_flag = pass_flag;
keypoints.recommended_next_step = recommended_next_step;

rows = repmat(make_keypoint_row_template_local(), 9, 1);
rows(1) = make_keypoint_row_local('best_white_joint_success_bias0_snr25', best_white_joint, '');
rows(2) = make_keypoint_row_local('best_none_joint_success_bias0_snr25', best_none_joint, '');
rows(3) = make_keypoint_row_local('white_minus_none_joint_success_gap_bias0_snr25', white_gap, '');
rows(4) = make_keypoint_row_local('best_layout_white_bias0_snr25', NaN, best_white_layout);
rows(5) = make_keypoint_row_local('max_boundary_hit_rate', keypoints.max_boundary_hit_rate, '');
rows(6) = make_keypoint_row_local('mean_manifold_corr_at_best', mean_corr_best, '');
rows(7) = make_keypoint_row_local('mean_abs_el_error_at_best', mean_el_err_best, '');
rows(8) = make_keypoint_row_local('cyl_common_el_2d_pass_flag', pass_flag, '');
rows(9) = make_keypoint_row_local('recommended_next_step', NaN, recommended_next_step);
end

function sub = select_pass_subset_local(summary_table, whitening_mode)
mask = string_match_local(summary_table.source_mode, 'noncoherent') & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    abs(summary_table.az_center_bias_deg) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg) < 1e-12 & ...
    abs(summary_table.snr_db - 25) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage3:MissingPassSubset', 'Missing pass subset for whitening mode %s.', whitening_mode);
end
end

function [best_joint, best_layout, mean_corr_best, mean_el_err_best, boundary_best] = best_layout_stats_local(sub, beam_layouts)
best_joint = -Inf;
best_layout = '';
mean_corr_best = NaN;
mean_el_err_best = NaN;
boundary_best = NaN;
for iLayout = 1:numel(beam_layouts)
    layout_name = beam_layouts(iLayout).name;
    layout_sub = sub(string_match_local(sub.beam_layout_name, layout_name), :);
    if isempty(layout_sub)
        error('run_stage3:MissingLayoutSubset', 'Missing layout subset: %s.', layout_name);
    end
    mean_joint = mean(layout_sub.joint_tol_success_rate);
    mean_el_err = mean_omitnan_local(layout_sub.mean_abs_el_error_deg);
    max_boundary = max(layout_sub.boundary_hit_rate);
    mean_corr = mean_omitnan_local(layout_sub.mean_manifold_corr_truth);
    if mean_joint > best_joint || (mean_joint == best_joint && mean_el_err < mean_el_err_best)
        best_joint = mean_joint;
        best_layout = layout_name;
        mean_corr_best = mean_corr;
        mean_el_err_best = mean_el_err;
        boundary_best = max_boundary;
    end
end
end

function row = make_keypoint_row_template_local()
row = struct();
row.metric = '';
row.metric_value = NaN;
row.metric_text = '';
end

function row = make_keypoint_row_local(metric, metric_value, metric_text)
row = make_keypoint_row_template_local();
row.metric = metric;
row.metric_value = metric_value;
row.metric_text = metric_text;
end

function plot_paths = make_plots_local(summary_table, result_dir, beam_layouts, snr_list, center_bias_cases)
plot_paths = {};
plot_paths{end + 1} = plot_joint_success_by_layout_local(summary_table, result_dir, beam_layouts);
plot_paths{end + 1} = plot_az_rmse_vs_snr_local(summary_table, result_dir, snr_list, beam_layouts);
plot_paths{end + 1} = plot_el_error_vs_snr_local(summary_table, result_dir, snr_list, beam_layouts);
plot_paths{end + 1} = plot_whitening_compare_local(summary_table, result_dir, beam_layouts);
plot_paths{end + 1} = plot_boundary_hit_local(summary_table, result_dir, center_bias_cases);
plot_paths{end + 1} = plot_manifold_corr_local(summary_table, result_dir, beam_layouts);
end

function out_path = plot_joint_success_by_layout_local(summary_table, result_dir, beam_layouts)
white_sub = select_pass_subset_local(summary_table, 'white');
vals = nan(1, numel(beam_layouts));
labels = cell(1, numel(beam_layouts));
for idx = 1:numel(beam_layouts)
    layout_sub = white_sub(string_match_local(white_sub.beam_layout_name, beam_layouts(idx).name), :);
    vals(idx) = mean(layout_sub.joint_tol_success_rate);
    labels{idx} = beam_layouts(idx).name;
end
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean joint success rate');
title('Common-el joint success by layout');
out_path = fullfile(result_dir, 'cyl_common_el_joint_success_by_layout.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_az_rmse_vs_snr_local(summary_table, result_dir, snr_list, beam_layouts)
fig = figure('Visible', 'off');
hold on;
style_list = {'-o', '-s', '-^'};
for iLayout = 1:numel(beam_layouts)
    vals = nan(size(snr_list));
    for iSnr = 1:numel(snr_list)
        sub = select_summary_plot_subset_local(summary_table, 'white', beam_layouts(iLayout).name, 0, 0, snr_list(iSnr));
        vals(iSnr) = mean_omitnan_local(sub.mean_az_rmse_deg);
    end
    plot(snr_list, vals, style_list{iLayout}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
grid on;
xlabel('SNR (dB)');
ylabel('mean az RMSE (deg)');
title('Common-el az RMSE vs SNR');
legend({beam_layouts.name}, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_common_el_az_rmse_vs_snr.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_el_error_vs_snr_local(summary_table, result_dir, snr_list, beam_layouts)
fig = figure('Visible', 'off');
hold on;
style_list = {'-o', '-s', '-^'};
for iLayout = 1:numel(beam_layouts)
    vals = nan(size(snr_list));
    for iSnr = 1:numel(snr_list)
        sub = select_summary_plot_subset_local(summary_table, 'white', beam_layouts(iLayout).name, 0, 0, snr_list(iSnr));
        vals(iSnr) = mean_omitnan_local(sub.mean_abs_el_error_deg);
    end
    plot(snr_list, vals, style_list{iLayout}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
grid on;
xlabel('SNR (dB)');
ylabel('mean abs el error (deg)');
title('Common-el elevation error vs SNR');
legend({beam_layouts.name}, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_common_el_el_error_vs_snr.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_whitening_compare_local(summary_table, result_dir, beam_layouts)
none_sub = select_pass_subset_local(summary_table, 'none');
white_sub = select_pass_subset_local(summary_table, 'white');
none_vals = nan(1, numel(beam_layouts));
white_vals = nan(1, numel(beam_layouts));
labels = cell(1, numel(beam_layouts));
for idx = 1:numel(beam_layouts)
    labels{idx} = beam_layouts(idx).name;
    none_vals(idx) = mean(none_sub.joint_tol_success_rate(string_match_local(none_sub.beam_layout_name, labels{idx})));
    white_vals(idx) = mean(white_sub.joint_tol_success_rate(string_match_local(white_sub.beam_layout_name, labels{idx})));
end
fig = figure('Visible', 'off');
bar([none_vals(:), white_vals(:)], 'grouped');
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean joint success rate');
title('Common-el whitening compare at bias=0, SNR=25');
legend({'none', 'white'}, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_common_el_whitening_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_boundary_hit_local(summary_table, result_dir, center_bias_cases)
fig = figure('Visible', 'off');
vals = nan(size(center_bias_cases, 1), 1);
labels = cell(size(center_bias_cases, 1), 1);
for iBias = 1:size(center_bias_cases, 1)
    az_bias = center_bias_cases(iBias, 1);
    el_bias = center_bias_cases(iBias, 2);
    mask = string_match_local(summary_table.source_mode, 'noncoherent') & ...
        string_match_local(summary_table.whitening_mode, 'white') & ...
        abs(summary_table.az_center_bias_deg - az_bias) < 1e-12 & ...
        abs(summary_table.el_center_bias_deg - el_bias) < 1e-12;
    sub = summary_table(mask, :);
    vals(iBias) = max(sub.boundary_hit_rate);
    labels{iBias} = sprintf('[%.1f %.1f]', az_bias, el_bias);
end
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
xlabel('[az bias, el bias] deg');
ylabel('max boundary hit rate');
title('Common-el boundary hit risk');
out_path = fullfile(result_dir, 'cyl_common_el_boundary_hit_rate.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_manifold_corr_local(summary_table, result_dir, beam_layouts)
fig = figure('Visible', 'off');
vals = nan(1, numel(beam_layouts));
labels = cell(1, numel(beam_layouts));
for idx = 1:numel(beam_layouts)
    sub = select_summary_plot_subset_local(summary_table, 'white', beam_layouts(idx).name, 0, 0, 25);
    vals(idx) = mean_omitnan_local(sub.mean_manifold_corr_truth);
    labels{idx} = beam_layouts(idx).name;
end
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean truth manifold correlation');
title('Common-el beamspace manifold correlation');
out_path = fullfile(result_dir, 'cyl_common_el_manifold_corr.png');
saveas(fig, out_path);
close(fig);
end

function sub = select_summary_plot_subset_local(summary_table, whitening_mode, layout_name, az_bias, el_bias, snr_db)
mask = string_match_local(summary_table.source_mode, 'noncoherent') & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    string_match_local(summary_table.beam_layout_name, layout_name) & ...
    abs(summary_table.az_center_bias_deg - az_bias) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg - el_bias) < 1e-12 & ...
    abs(summary_table.snr_db - snr_db) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage3:MissingPlotSubset', 'Missing plot subset.');
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

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function v = median_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = median(x);
end
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage3:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
