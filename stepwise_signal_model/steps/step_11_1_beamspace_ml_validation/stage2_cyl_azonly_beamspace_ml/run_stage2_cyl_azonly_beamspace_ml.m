clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_1_cyl_azonly_beamspace_ml');

addpath(common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.1 Stage2 starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

cfg = sim_cfg();
az_sector_center = cfg.beam.azSectorCenter;
el0 = cfg.beam.elSectorCenter;
arrInfo = arr_cyl(cfg, az_sector_center);

x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
N_elem = numel(x);
expected_N_elem = cfg.beam.subNaz * cfg.arr.Nel;
if N_elem ~= expected_N_elem
    error('run_stage2:NelemMismatch', 'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;
lambda = cfg.arr.lambda;

base_seed = 20260612;
L = 64;
Metkl = 20;
az_center_true = az_sector_center;
el0_deg = el0;
az_sep_list = [0.6, 1.0, 1.4];
snr_list = [10, 20, 30];
beam_count_list = [9, 16, 25];
center_bias_list = [-0.2, 0, 0.2];
source_mode_list = {'noncoherent', 'coherent'};
whitening_mode_list = {'none', 'white'};
search_half_width = 1.8;
beam_span = 2.4;
grid_step_deg = 0.02;
tol_deg = 0.1;
reg = 1e-10;

log_lines = append_log_local(log_lines, 'cfg.arr: Naz=%d, Nel=%d, fc=%.6g, lambda=%.12g, R=%.6g, dz=%.6g', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.fc, cfg.arr.lambda, cfg.arr.R, cfg.arr.dz);
log_lines = append_log_local(log_lines, 'cfg.beam.subNaz=%d, arrInfo.nAct=%d, expected_N_elem=%d', ...
    cfg.beam.subNaz, arrInfo.nAct, expected_N_elem);
log_lines = append_log_local(log_lines, 'phase_factor=%.6g, phase_sign=%+.0f', phase_factor, phase_sign);
log_lines = append_log_local(log_lines, 'L=%d, Metkl=%d, az_sep_list=%s, snr_list=%s', ...
    L, Metkl, mat2str(az_sep_list), mat2str(snr_list));
log_lines = append_log_local(log_lines, 'beam_count_list=%s, center_bias_list=%s', ...
    mat2str(beam_count_list), mat2str(center_bias_list));
log_lines = append_log_local(log_lines, 'source_mode_list=%s, whitening_mode_list=%s', ...
    strjoin(source_mode_list, ','), strjoin(whitening_mode_list, ','));
log_lines = append_log_local(log_lines, 'search_half_width=%.3f, beam_span=%.3f, grid_step_deg=%.3f, tol_deg=%.3f', ...
    search_half_width, beam_span, grid_step_deg, tol_deg);

cache = build_beam_grid_cache_local(x, y, z, center_bias_list, beam_count_list, ...
    az_center_true, el0_deg, lambda, phase_factor, phase_sign, search_half_width, beam_span, grid_step_deg);
log_lines = append_log_local(log_lines, 'Precomputed %d beam/grid cache entries.', numel(cache));

total_rows = numel(source_mode_list) * numel(az_sep_list) * numel(snr_list) * ...
    numel(center_bias_list) * numel(beam_count_list) * numel(whitening_mode_list) * Metkl;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

tic;
for iSource = 1:numel(source_mode_list)
    source_mode = source_mode_list{iSource};
    for iSep = 1:numel(az_sep_list)
        az_sep = az_sep_list(iSep);
        az_true = [az_center_true - az_sep/2, az_center_true + az_sep/2];
        for iSnr = 1:numel(snr_list)
            snr_db = snr_list(iSnr);

            for trial_id = 1:Metkl
                seed_now = base_seed + 100000*iSource + 10000*iSep + 1000*iSnr + trial_id;
                [Y, truth] = make_cyl_azonly_snapshots(x, y, z, az_true, el0_deg, lambda, L, snr_db, source_mode, ...
                    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Seed', seed_now);
                if ~isequal(size(Y), [N_elem, L])
                    error('run_stage2:YShapeMismatch', 'Y must be N_elem x L.');
                end

                for iCache = 1:numel(cache)
                    W = cache(iCache).W;
                    beam_info = cache(iCache).beam_info;
                    grid = cache(iCache).grid;
                    Z = W' * Y;
                    if ~isequal(size(Z), [cache(iCache).beam_count, L])
                        error('run_stage2:ZShapeMismatch', 'Z must be beam_count x L.');
                    end

                    A_truth = build_cyl_pair_manifold_azonly(x, y, z, az_true, el0_deg, lambda, ...
                        'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
                    G_truth = W' * A_truth;

                    for iWhite = 1:numel(whitening_mode_list)
                        whitening_mode = whitening_mode_list{iWhite};
                        search_cfg = struct();
                        search_cfg.whitening_mode = whitening_mode;
                        search_cfg.reg = reg;

                        [az_hat, ~, search_debug] = search_pair_grid_ordered_precomputed(Z, W, grid, search_cfg);
                        metrics = eval_pair_metrics(az_hat, az_true, cache(iCache).search_bounds, tol_deg);

                        [~, G_truth_use] = apply_beamspace_whitening(Z, G_truth, W, whitening_mode, 'eps_reg', reg);
                        g1 = G_truth_use(:, 1);
                        g2 = G_truth_use(:, 2);
                        manifold_corr = abs(g1' * g2) / max(norm(g1) * norm(g2), eps);

                        row_idx = row_idx + 1;
                        trial_rows(row_idx).trial_id = trial_id;
                        trial_rows(row_idx).source_mode = truth.source_mode;
                        trial_rows(row_idx).whitening_mode = whitening_mode;
                        trial_rows(row_idx).beam_count = cache(iCache).beam_count;
                        trial_rows(row_idx).center_bias_deg = cache(iCache).center_bias_deg;
                        trial_rows(row_idx).beam_c = cache(iCache).beam_c;
                        trial_rows(row_idx).az_sep_deg = az_sep;
                        trial_rows(row_idx).snr_db = snr_db;
                        trial_rows(row_idx).az_hat_1 = az_hat(1);
                        trial_rows(row_idx).az_hat_2 = az_hat(2);
                        trial_rows(row_idx).az_true_1 = az_true(1);
                        trial_rows(row_idx).az_true_2 = az_true(2);
                        trial_rows(row_idx).el0_deg = el0_deg;
                        trial_rows(row_idx).raw_success = metrics.raw_success;
                        trial_rows(row_idx).tol_success = metrics.tol_success;
                        trial_rows(row_idx).rmse_deg = metrics.rmse_deg;
                        trial_rows(row_idx).center_error_deg = metrics.center_error_deg;
                        trial_rows(row_idx).sep_error_deg = metrics.sep_error_deg;
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
                'Completed source=%s, az_sep=%.2f, snr=%.1f dB, rows=%d/%d, elapsed %.2f s', ...
                source_mode, az_sep, snr_db, row_idx, total_rows, toc);
        end
    end
end

if row_idx ~= total_rows
    error('run_stage2:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
if isempty(trial_table)
    error('run_stage2:EmptyTrialTable', 'trial_table is empty.');
end

summary_rows = build_summary_rows_local(trial_table, source_mode_list, whitening_mode_list, ...
    beam_count_list, center_bias_list, az_sep_list, snr_list);
summary_table = struct2table(summary_rows);
if isempty(summary_table)
    error('run_stage2:EmptySummaryTable', 'summary_table is empty.');
end

[keypoint_rows, keypoints] = build_keypoints_local(summary_table);
keypoint_table = struct2table(keypoint_rows);
if isempty(keypoint_table)
    error('run_stage2:EmptyKeypointTable', 'keypoint_table is empty.');
end

trial_csv = fullfile(result_dir, 'step11_1_cyl_azonly_trial.csv');
summary_csv = fullfile(result_dir, 'step11_1_cyl_azonly_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_1_cyl_azonly_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_1_cyl_azonly_result.mat');
log_path = fullfile(result_dir, 'step11_1_cyl_azonly.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
plot_paths = make_plots_local(summary_table, result_dir, beam_count_list, az_sep_list, snr_list, center_bias_list);

params = struct();
params.base_seed = base_seed;
params.L = L;
params.Metkl = Metkl;
params.az_center_true = az_center_true;
params.el0_deg = el0_deg;
params.az_sep_list = az_sep_list;
params.snr_list = snr_list;
params.beam_count_list = beam_count_list;
params.center_bias_list = center_bias_list;
params.source_mode_list = source_mode_list;
params.whitening_mode_list = whitening_mode_list;
params.search_half_width = search_half_width;
params.beam_span = beam_span;
params.grid_step_deg = grid_step_deg;
params.tol_deg = tol_deg;
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
log_lines = append_log_local(log_lines, 'cyl_azonly_pass_flag=%d', keypoints.cyl_azonly_pass_flag);
log_lines = append_log_local(log_lines, 'recommended_next_step=%s', keypoints.recommended_next_step);
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function cache = build_beam_grid_cache_local(x, y, z, center_bias_list, beam_count_list, ...
    az_center_true, el0_deg, lambda, phase_factor, phase_sign, search_half_width, beam_span, grid_step_deg)
template = struct();
template.center_bias_deg = NaN;
template.beam_count = NaN;
template.beam_c = NaN;
template.search_bounds = [NaN, NaN];
template.az_grid = [];
template.beam_az = [];
template.W = [];
template.beam_info = struct();
template.grid = struct();

cache = repmat(template, numel(center_bias_list) * numel(beam_count_list), 1);
idx = 0;
for iBias = 1:numel(center_bias_list)
    center_bias = center_bias_list(iBias);
    beam_c = az_center_true + center_bias;
    search_bounds = [beam_c - search_half_width, beam_c + search_half_width];
    az_grid = search_bounds(1):grid_step_deg:search_bounds(2);
    for iBeam = 1:numel(beam_count_list)
        beam_count = beam_count_list(iBeam);
        beam_az = linspace(beam_c - beam_span, beam_c + beam_span, beam_count);
        [W, beam_info] = build_cyl_az_beam_transform(x, y, z, beam_az, el0_deg, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
        grid = precompute_beamspace_grid(W, x, y, z, az_grid, el0_deg, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);

        idx = idx + 1;
        cache(idx).center_bias_deg = center_bias;
        cache(idx).beam_count = beam_count;
        cache(idx).beam_c = beam_c;
        cache(idx).search_bounds = search_bounds;
        cache(idx).az_grid = az_grid;
        cache(idx).beam_az = beam_az;
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
row.beam_count = NaN;
row.center_bias_deg = NaN;
row.beam_c = NaN;
row.az_sep_deg = NaN;
row.snr_db = NaN;
row.az_hat_1 = NaN;
row.az_hat_2 = NaN;
row.az_true_1 = NaN;
row.az_true_2 = NaN;
row.el0_deg = NaN;
row.raw_success = false;
row.tol_success = false;
row.rmse_deg = NaN;
row.center_error_deg = NaN;
row.sep_error_deg = NaN;
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
    beam_count_list, center_bias_list, az_sep_list, snr_list)
template = struct();
template.source_mode = '';
template.whitening_mode = '';
template.beam_count = NaN;
template.center_bias_deg = NaN;
template.az_sep_deg = NaN;
template.snr_db = NaN;
template.raw_success_rate = NaN;
template.tol_success_rate = NaN;
template.mean_rmse_deg = NaN;
template.median_rmse_deg = NaN;
template.mean_abs_center_error_deg = NaN;
template.mean_abs_sep_error_deg = NaN;
template.boundary_hit_rate = NaN;
template.mean_manifold_corr_truth = NaN;
template.mean_cond_WHW = NaN;
template.mean_cond_best_GHG = NaN;
template.mean_num_pairs = NaN;

nRows = numel(source_mode_list) * numel(whitening_mode_list) * numel(beam_count_list) * ...
    numel(center_bias_list) * numel(az_sep_list) * numel(snr_list);
rows = repmat(template, nRows, 1);
idx = 0;

for iSource = 1:numel(source_mode_list)
    source_mode = source_mode_list{iSource};
    source_mask = string_match_local(trial_table.source_mode, source_mode);
    for iWhite = 1:numel(whitening_mode_list)
        whitening_mode = whitening_mode_list{iWhite};
        white_mask = string_match_local(trial_table.whitening_mode, whitening_mode);
        for iBeam = 1:numel(beam_count_list)
            beam_count = beam_count_list(iBeam);
            for iBias = 1:numel(center_bias_list)
                center_bias = center_bias_list(iBias);
                for iSep = 1:numel(az_sep_list)
                    az_sep = az_sep_list(iSep);
                    for iSnr = 1:numel(snr_list)
                        snr_db = snr_list(iSnr);
                        mask = source_mask & white_mask & ...
                            trial_table.beam_count == beam_count & ...
                            abs(trial_table.center_bias_deg - center_bias) < 1e-12 & ...
                            abs(trial_table.az_sep_deg - az_sep) < 1e-12 & ...
                            abs(trial_table.snr_db - snr_db) < 1e-12;
                        sub = trial_table(mask, :);
                        if isempty(sub)
                            error('run_stage2:MissingSummaryGroup', ...
                                'Missing group source=%s white=%s beam=%d bias=%.3f sep=%.3f snr=%.3f.', ...
                                source_mode, whitening_mode, beam_count, center_bias, az_sep, snr_db);
                        end

                        idx = idx + 1;
                        rows(idx).source_mode = source_mode;
                        rows(idx).whitening_mode = whitening_mode;
                        rows(idx).beam_count = beam_count;
                        rows(idx).center_bias_deg = center_bias;
                        rows(idx).az_sep_deg = az_sep;
                        rows(idx).snr_db = snr_db;
                        rows(idx).raw_success_rate = mean(double(sub.raw_success));
                        rows(idx).tol_success_rate = mean(double(sub.tol_success));
                        rows(idx).mean_rmse_deg = mean_omitnan_local(sub.rmse_deg);
                        rows(idx).median_rmse_deg = median_omitnan_local(sub.rmse_deg);
                        rows(idx).mean_abs_center_error_deg = mean_omitnan_local(abs(sub.center_error_deg));
                        rows(idx).mean_abs_sep_error_deg = mean_omitnan_local(abs(sub.sep_error_deg));
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

function [rows, keypoints] = build_keypoints_local(summary_table)
white_sub = select_summary_local(summary_table, 'noncoherent', 'white', 0, 1.0, 20);
none_sub = select_summary_local(summary_table, 'noncoherent', 'none', 0, 1.0, 20);

[best_white_tol, best_white_idx] = max(white_sub.tol_success_rate);
[best_none_tol, ~] = max(none_sub.tol_success_rate);
white_gap = best_white_tol - best_none_tol;
best_beam_count_white = white_sub.beam_count(best_white_idx);
mean_corr_best = white_sub.mean_manifold_corr_truth(best_white_idx);
best_boundary = white_sub.boundary_hit_rate(best_white_idx);

pass_flag = double(best_white_tol >= 0.9 && best_boundary <= 0.2);
if pass_flag == 1
    recommended_next_step = 'proceed_to_cylindrical_2d_beamspace_ml_or_coherence_stress';
else
    recommended_next_step = 'debug_cyl_beam_transform_search_window_or_phase_convention';
end

keypoints = struct();
keypoints.best_white_tol_success_bias0_snr20 = best_white_tol;
keypoints.best_none_tol_success_bias0_snr20 = best_none_tol;
keypoints.white_minus_none_success_gap_bias0_snr20 = white_gap;
keypoints.best_beam_count_white_bias0_snr20 = best_beam_count_white;
keypoints.max_boundary_hit_rate = max(summary_table.boundary_hit_rate);
keypoints.mean_manifold_corr_at_best = mean_corr_best;
keypoints.cyl_azonly_pass_flag = pass_flag;
keypoints.recommended_next_step = recommended_next_step;

rows = repmat(make_keypoint_row_template_local(), 8, 1);
rows(1) = make_keypoint_row_local('best_white_tol_success_bias0_snr20', best_white_tol, '');
rows(2) = make_keypoint_row_local('best_none_tol_success_bias0_snr20', best_none_tol, '');
rows(3) = make_keypoint_row_local('white_minus_none_success_gap_bias0_snr20', white_gap, '');
rows(4) = make_keypoint_row_local('best_beam_count_white_bias0_snr20', best_beam_count_white, '');
rows(5) = make_keypoint_row_local('max_boundary_hit_rate', keypoints.max_boundary_hit_rate, '');
rows(6) = make_keypoint_row_local('mean_manifold_corr_at_best', mean_corr_best, '');
rows(7) = make_keypoint_row_local('cyl_azonly_pass_flag', pass_flag, '');
rows(8) = make_keypoint_row_local('recommended_next_step', NaN, recommended_next_step);
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

function sub = select_summary_local(summary_table, source_mode, whitening_mode, center_bias, az_sep, snr_db)
mask = string_match_local(summary_table.source_mode, source_mode) & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    abs(summary_table.center_bias_deg - center_bias) < 1e-12 & ...
    abs(summary_table.az_sep_deg - az_sep) < 1e-12 & ...
    abs(summary_table.snr_db - snr_db) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage2:MissingSelectedSummary', ...
        'Missing selected summary source=%s white=%s bias=%.3f sep=%.3f snr=%.3f.', ...
        source_mode, whitening_mode, center_bias, az_sep, snr_db);
end
end

function plot_paths = make_plots_local(summary_table, result_dir, beam_count_list, az_sep_list, snr_list, center_bias_list)
plot_paths = {};
plot_paths{end + 1} = plot_tol_vs_beam_count_local(summary_table, result_dir, beam_count_list, az_sep_list);
plot_paths{end + 1} = plot_rmse_vs_snr_local(summary_table, result_dir, snr_list, az_sep_list);
plot_paths{end + 1} = plot_whitening_compare_local(summary_table, result_dir, beam_count_list);
plot_paths{end + 1} = plot_boundary_hit_local(summary_table, result_dir, center_bias_list);
plot_paths{end + 1} = plot_manifold_corr_local(summary_table, result_dir, az_sep_list);
end

function out_path = plot_tol_vs_beam_count_local(summary_table, result_dir, beam_count_list, az_sep_list)
fig = figure('Visible', 'off');
hold on;
style_list = {'-o', '-s', '-^'};
for iSep = 1:numel(az_sep_list)
    vals = nan(size(beam_count_list));
    for iBeam = 1:numel(beam_count_list)
        sub = select_summary_specific_local(summary_table, 'noncoherent', 'white', beam_count_list(iBeam), 0, az_sep_list(iSep), 20);
        vals(iBeam) = sub.tol_success_rate;
    end
    plot(beam_count_list, vals, style_list{iSep}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
grid on;
xlabel('beam count');
ylabel('tol success rate');
title('Cyl az-only tol success vs beam count');
legend(make_sep_legend_local(az_sep_list), 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_azonly_tol_success_vs_beam_count.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_rmse_vs_snr_local(summary_table, result_dir, snr_list, az_sep_list)
fig = figure('Visible', 'off');
hold on;
style_list = {'-o', '-s', '-^'};
for iSep = 1:numel(az_sep_list)
    vals = nan(size(snr_list));
    for iSnr = 1:numel(snr_list)
        sub = select_summary_best_beam_local(summary_table, 'noncoherent', 'white', 0, az_sep_list(iSep), snr_list(iSnr));
        vals(iSnr) = min(sub.mean_rmse_deg);
    end
    plot(snr_list, vals, style_list{iSep}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
grid on;
xlabel('SNR (dB)');
ylabel('best mean RMSE (deg)');
title('Cyl az-only RMSE vs SNR');
legend(make_sep_legend_local(az_sep_list), 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_azonly_rmse_vs_snr.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_whitening_compare_local(summary_table, result_dir, beam_count_list)
none_vals = nan(size(beam_count_list));
white_vals = nan(size(beam_count_list));
for iBeam = 1:numel(beam_count_list)
    none_sub = select_summary_specific_local(summary_table, 'noncoherent', 'none', beam_count_list(iBeam), 0, 1.0, 20);
    white_sub = select_summary_specific_local(summary_table, 'noncoherent', 'white', beam_count_list(iBeam), 0, 1.0, 20);
    none_vals(iBeam) = none_sub.tol_success_rate;
    white_vals(iBeam) = white_sub.tol_success_rate;
end
fig = figure('Visible', 'off');
bar(beam_count_list, [none_vals(:), white_vals(:)], 'grouped');
grid on;
xlabel('beam count');
ylabel('tol success rate');
title('Whitening compare at sep=1.0, SNR=20, bias=0');
legend({'none', 'white'}, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_azonly_whitening_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_boundary_hit_local(summary_table, result_dir, center_bias_list)
fig = figure('Visible', 'off');
hold on;
mode_list = {'none', 'white'};
style_list = {'-o', '-s'};
for iMode = 1:numel(mode_list)
    vals = nan(size(center_bias_list));
    for iBias = 1:numel(center_bias_list)
        sub = select_summary_bias_mode_local(summary_table, 'noncoherent', mode_list{iMode}, center_bias_list(iBias));
        vals(iBias) = max(sub.boundary_hit_rate);
    end
    plot(center_bias_list, vals, style_list{iMode}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
grid on;
xlabel('center bias (deg)');
ylabel('max boundary hit rate');
title('Cyl az-only boundary hit risk');
legend(mode_list, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_azonly_boundary_hit_rate.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_manifold_corr_local(summary_table, result_dir, az_sep_list)
fig = figure('Visible', 'off');
hold on;
mode_list = {'none', 'white'};
style_list = {'-o', '-s'};
for iMode = 1:numel(mode_list)
    vals = nan(size(az_sep_list));
    for iSep = 1:numel(az_sep_list)
        sub = select_summary_sep_mode_local(summary_table, 'noncoherent', mode_list{iMode}, iSep, az_sep_list);
        vals(iSep) = mean_omitnan_local(sub.mean_manifold_corr_truth);
    end
    plot(az_sep_list, vals, style_list{iMode}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
grid on;
xlabel('az separation (deg)');
ylabel('mean truth manifold correlation');
title('Truth beamspace manifold correlation vs separation');
legend(mode_list, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_azonly_manifold_corr_vs_sep.png');
saveas(fig, out_path);
close(fig);
end

function sub = select_summary_specific_local(summary_table, source_mode, whitening_mode, beam_count, center_bias, az_sep, snr_db)
mask = string_match_local(summary_table.source_mode, source_mode) & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    summary_table.beam_count == beam_count & ...
    abs(summary_table.center_bias_deg - center_bias) < 1e-12 & ...
    abs(summary_table.az_sep_deg - az_sep) < 1e-12 & ...
    abs(summary_table.snr_db - snr_db) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage2:MissingPlotSummary', 'Missing summary row for plot.');
end
end

function sub = select_summary_best_beam_local(summary_table, source_mode, whitening_mode, center_bias, az_sep, snr_db)
mask = string_match_local(summary_table.source_mode, source_mode) & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    abs(summary_table.center_bias_deg - center_bias) < 1e-12 & ...
    abs(summary_table.az_sep_deg - az_sep) < 1e-12 & ...
    abs(summary_table.snr_db - snr_db) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage2:MissingBestBeamSummary', 'Missing best-beam summary subset.');
end
end

function sub = select_summary_bias_mode_local(summary_table, source_mode, whitening_mode, center_bias)
mask = string_match_local(summary_table.source_mode, source_mode) & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    abs(summary_table.center_bias_deg - center_bias) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage2:MissingBiasModeSummary', 'Missing bias/mode summary subset.');
end
end

function sub = select_summary_sep_mode_local(summary_table, source_mode, whitening_mode, iSep, az_sep_list)
az_sep = az_sep_list(iSep);
mask = string_match_local(summary_table.source_mode, source_mode) & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    abs(summary_table.center_bias_deg) < 1e-12 & ...
    abs(summary_table.az_sep_deg - az_sep) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage2:MissingSepModeSummary', 'Missing sep/mode summary subset.');
end
end

function labels = make_sep_legend_local(az_sep_list)
labels = cell(size(az_sep_list));
for idx = 1:numel(az_sep_list)
    labels{idx} = sprintf('sep %.1f deg', az_sep_list(idx));
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
    error('run_stage2:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
