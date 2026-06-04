clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_1_cyl_el_separation_beamspace_ml');

addpath(common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.1 Stage4 starts');
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
    error('run_stage4:NelemMismatch', 'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;

base_seed = 20260614;
L = 64;
Metkl = 3;
az_center_true = cfg.beam.azSectorCenter;
el_center_nominal = cfg.beam.elSectorCenter;
az_sep_list = [0.83, 1.21];
el_sep_true_list = [0.0, 0.31, 0.57];
el_center_offset_list = [-0.27, 0.33];
snr_list = [20, 30];
center_bias_cases = [ ...
    0.0, 0.0; ...
    0.2, 0.0; ...
    0.0, 0.2];
beam_layouts = struct( ...
    'name', {'az3_el3', 'az5_el3', 'az5_el5'}, ...
    'az_count', {3, 5, 5}, ...
    'el_count', {3, 3, 5});
source_mode_list = {'noncoherent'};
whitening_mode_list = {'none', 'white'};
az_search_half_width = 1.4;
el_search_half_width = 1.1;
az_beam_span = 2.0;
el_beam_span = 1.5;
az_grid_step_deg = 0.07;
el_grid_step_deg = 0.15;
el_sep_index_list = [0, 1, 2];
search_orientations = [1, -1];
az_tol_deg = 0.15;
el_tol_deg = 0.22;
el_sep_tol_deg = 0.25;
reg = 1e-10;

log_lines = append_log_local(log_lines, 'cfg.arr: Naz=%d, Nel=%d, fc=%.6g, lambda=%.12g, R=%.6g, dz=%.6g', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.fc, cfg.arr.lambda, cfg.arr.R, cfg.arr.dz);
log_lines = append_log_local(log_lines, 'cfg.beam.subNaz=%d, arrInfo.nAct=%d, expected_N_elem=%d', ...
    cfg.beam.subNaz, arrInfo.nAct, expected_N_elem);
log_lines = append_log_local(log_lines, 'phase_factor=%.6g, phase_sign=%+.0f', phase_factor, phase_sign);
log_lines = append_log_local(log_lines, 'base_seed=%d, L=%d, Metkl=%d', base_seed, L, Metkl);
log_lines = append_log_local(log_lines, 'az_sep_list=%s, el_sep_true_list=%s, el_center_offset_list=%s, snr_list=%s', ...
    mat2str(az_sep_list), mat2str(el_sep_true_list), mat2str(el_center_offset_list), mat2str(snr_list));
log_lines = append_log_local(log_lines, 'center_bias_cases=%s', mat2str(center_bias_cases));
log_lines = append_log_local(log_lines, 'beam_layouts=%s', strjoin({beam_layouts.name}, ','));
log_lines = append_log_local(log_lines, 'source_mode_list=%s, whitening_mode_list=%s', ...
    strjoin(source_mode_list, ','), strjoin(whitening_mode_list, ','));
log_lines = append_log_local(log_lines, ...
    'az_search_half_width=%.3f, el_search_half_width=%.3f, az_beam_span=%.3f, el_beam_span=%.3f', ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span);
log_lines = append_log_local(log_lines, ...
    'az_grid_step_deg=%.3f, el_grid_step_deg=%.3f, el_sep_index_list=%s, search_orientations=%s', ...
    az_grid_step_deg, el_grid_step_deg, mat2str(el_sep_index_list), mat2str(search_orientations));
log_lines = append_log_local(log_lines, 'az_tol_deg=%.3f, el_tol_deg=%.3f, el_sep_tol_deg=%.3f', ...
    az_tol_deg, el_tol_deg, el_sep_tol_deg);

cache = build_beam_grid_cache_local(x, y, z, center_bias_cases, beam_layouts, ...
    az_center_true, el_center_nominal, lambda, phase_factor, phase_sign, ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span, ...
    az_grid_step_deg, el_grid_step_deg);
log_lines = append_log_local(log_lines, 'Precomputed %d beam/grid cache entries.', numel(cache));

total_rows = numel(source_mode_list) * numel(az_sep_list) * numel(el_sep_true_list) * ...
    numel(el_center_offset_list) * numel(snr_list) * size(center_bias_cases, 1) * ...
    numel(beam_layouts) * numel(whitening_mode_list) * Metkl;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

tic;
for iSource = 1:numel(source_mode_list)
    source_mode = source_mode_list{iSource};
    for iAzSep = 1:numel(az_sep_list)
        az_sep = az_sep_list(iAzSep);
        az_true = [az_center_true - az_sep/2, az_center_true + az_sep/2];
        for iElSep = 1:numel(el_sep_true_list)
            el_sep_true = el_sep_true_list(iElSep);
            for iElOff = 1:numel(el_center_offset_list)
                el_center_offset = el_center_offset_list(iElOff);
                el_center_true = el_center_nominal + el_center_offset;
                for iSnr = 1:numel(snr_list)
                    snr_db = snr_list(iSnr);

                    for trial_id = 1:Metkl
                        if el_sep_true == 0
                            el_true_pair = [el_center_true, el_center_true];
                            true_orientation = 0;
                        elseif mod(trial_id, 2) == 1
                            el_true_pair = [el_center_true - el_sep_true/2, el_center_true + el_sep_true/2];
                            true_orientation = 1;
                        else
                            el_true_pair = [el_center_true + el_sep_true/2, el_center_true - el_sep_true/2];
                            true_orientation = -1;
                        end

                        seed_now = base_seed + 100000*iSource + 10000*iAzSep + 1000*iElSep + 100*iElOff + 10*iSnr + trial_id;
                        [Y, truth] = make_cyl_el_separation_snapshots(x, y, z, az_true, el_true_pair, lambda, L, snr_db, source_mode, ...
                            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Seed', seed_now);
                        if ~isequal(size(Y), [N_elem, L])
                            error('run_stage4:YShapeMismatch', 'Y must be N_elem x L.');
                        end

                        for iCache = 1:numel(cache)
                            W = cache(iCache).W;
                            beam_info = cache(iCache).beam_info;
                            grid = cache(iCache).grid;
                            Z = W' * Y;
                            if ~isequal(size(Z), [cache(iCache).beam_count, L])
                                error('run_stage4:ZShapeMismatch', 'Z must be beam_count x L.');
                            end

                            A_truth = build_cyl_pair_manifold_el_separated(x, y, z, az_true, el_true_pair, lambda, ...
                                'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
                            G_truth = W' * A_truth;

                            for iWhite = 1:numel(whitening_mode_list)
                                whitening_mode = whitening_mode_list{iWhite};
                                search_cfg = struct();
                                search_cfg.whitening_mode = whitening_mode;
                                search_cfg.reg = reg;
                                search_cfg.el_sep_index_list = el_sep_index_list;
                                search_cfg.search_orientations = search_orientations;
                                search_cfg.keep_score_cube = false;

                                [est_sep, ~, debug_sep] = search_pair_grid_el_separation_precomputed(Z, W, grid, search_cfg);
                                [est_common, ~, debug_common] = search_pair_grid_common_el_precomputed(Z, W, grid, search_cfg);
                                est_common_pair = struct();
                                est_common_pair.az_hat = est_common.az_hat;
                                est_common_pair.el_hat = [est_common.el_hat, est_common.el_hat];

                                metrics_sep = eval_el_separation_pair_metrics(est_sep, az_true, el_true_pair, ...
                                    cache(iCache).az_bounds, cache(iCache).el_bounds, az_tol_deg, el_tol_deg, el_sep_tol_deg);
                                metrics_common = eval_el_separation_pair_metrics(est_common_pair, az_true, el_true_pair, ...
                                    cache(iCache).az_bounds, cache(iCache).el_bounds, az_tol_deg, el_tol_deg, el_sep_tol_deg);

                                score_margin = debug_sep.max_score - debug_common.max_score;
                                score_ratio = debug_sep.max_score / max(abs(debug_common.max_score), eps);

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
                                trial_rows(row_idx).el_sep_true_deg = el_sep_true;
                                trial_rows(row_idx).el_center_offset_deg = el_center_offset;
                                trial_rows(row_idx).true_orientation = true_orientation;
                                trial_rows(row_idx).snr_db = snr_db;

                                trial_rows(row_idx).az_hat_sep_1 = est_sep.az_hat(1);
                                trial_rows(row_idx).az_hat_sep_2 = est_sep.az_hat(2);
                                trial_rows(row_idx).el_hat_sep_1 = est_sep.el_hat(1);
                                trial_rows(row_idx).el_hat_sep_2 = est_sep.el_hat(2);
                                trial_rows(row_idx).el_sep_hat_deg = est_sep.el_sep_hat;
                                trial_rows(row_idx).orientation_hat = est_sep.orientation_hat;

                                trial_rows(row_idx).az_hat_common_1 = est_common_pair.az_hat(1);
                                trial_rows(row_idx).az_hat_common_2 = est_common_pair.az_hat(2);
                                trial_rows(row_idx).el_hat_common_1 = est_common_pair.el_hat(1);
                                trial_rows(row_idx).el_hat_common_2 = est_common_pair.el_hat(2);

                                trial_rows(row_idx).az_true_1 = az_true(1);
                                trial_rows(row_idx).az_true_2 = az_true(2);
                                trial_rows(row_idx).el_true_1 = el_true_pair(1);
                                trial_rows(row_idx).el_true_2 = el_true_pair(2);

                                trial_rows(row_idx).sep_raw_success = metrics_sep.raw_success;
                                trial_rows(row_idx).sep_az_tol_success = metrics_sep.az_tol_success;
                                trial_rows(row_idx).sep_el_pair_tol_success = metrics_sep.el_pair_tol_success;
                                trial_rows(row_idx).sep_joint_pair_tol_success = metrics_sep.joint_pair_tol_success;
                                trial_rows(row_idx).sep_az_rmse_deg = metrics_sep.az_rmse_deg;
                                trial_rows(row_idx).sep_el_rmse_deg = metrics_sep.el_rmse_deg;
                                trial_rows(row_idx).sep_el_sep_error_deg = metrics_sep.el_sep_error_deg;
                                trial_rows(row_idx).sep_false_el_split = metrics_sep.false_el_split;
                                trial_rows(row_idx).sep_boundary_hit = metrics_sep.boundary_hit;

                                trial_rows(row_idx).common_raw_success = metrics_common.raw_success;
                                trial_rows(row_idx).common_az_tol_success = metrics_common.az_tol_success;
                                trial_rows(row_idx).common_el_pair_tol_success = metrics_common.el_pair_tol_success;
                                trial_rows(row_idx).common_joint_pair_tol_success = metrics_common.joint_pair_tol_success;
                                trial_rows(row_idx).common_az_rmse_deg = metrics_common.az_rmse_deg;
                                trial_rows(row_idx).common_el_rmse_deg = metrics_common.el_rmse_deg;
                                trial_rows(row_idx).common_el_sep_error_deg = metrics_common.el_sep_error_deg;
                                trial_rows(row_idx).common_false_el_split = metrics_common.false_el_split;
                                trial_rows(row_idx).common_boundary_hit = metrics_common.boundary_hit;

                                trial_rows(row_idx).score_margin_sep_minus_common = score_margin;
                                trial_rows(row_idx).score_ratio_sep_over_common = score_ratio;
                                trial_rows(row_idx).manifold_corr_truth = manifold_corr;
                                trial_rows(row_idx).cond_WHW = beam_info.cond_WHW;
                                trial_rows(row_idx).cond_best_GHG_sep = debug_sep.cond_best_GHG;
                                trial_rows(row_idx).cond_best_GHG_common = debug_common.cond_best_GHG;
                                trial_rows(row_idx).max_score_sep = debug_sep.max_score;
                                trial_rows(row_idx).max_score_common = debug_common.max_score;
                                trial_rows(row_idx).num_pairs_sep = debug_sep.num_pairs;
                                trial_rows(row_idx).num_pairs_common = debug_common.num_pairs;
                                trial_rows(row_idx).N_elem = N_elem;
                                trial_rows(row_idx).L = L;
                                trial_rows(row_idx).phase_factor = phase_factor;
                                trial_rows(row_idx).phase_sign = phase_sign;
                            end
                        end
                    end

                    log_lines = append_log_local(log_lines, ...
                        'Completed az_sep=%.2f, el_sep_true=%.2f, snr=%.1f dB, rows=%d/%d, elapsed %.2f s', ...
                        az_sep, el_sep_true, snr_db, row_idx, total_rows, toc);
                end
            end
        end
    end
end

if row_idx ~= total_rows
    error('run_stage4:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
if isempty(trial_table)
    error('run_stage4:EmptyTrialTable', 'trial_table is empty.');
end

summary_rows = build_summary_rows_local(trial_table, source_mode_list, whitening_mode_list, ...
    beam_layouts, center_bias_cases, az_sep_list, el_sep_true_list, el_center_offset_list, snr_list);
summary_table = struct2table(summary_rows);
if isempty(summary_table)
    error('run_stage4:EmptySummaryTable', 'summary_table is empty.');
end

[keypoint_rows, keypoints] = build_keypoints_local(summary_table, beam_layouts);
keypoint_table = struct2table(keypoint_rows);
if isempty(keypoint_table)
    error('run_stage4:EmptyKeypointTable', 'keypoint_table is empty.');
end

trial_csv = fullfile(result_dir, 'step11_1_cyl_el_separation_trial.csv');
summary_csv = fullfile(result_dir, 'step11_1_cyl_el_separation_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_1_cyl_el_separation_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_1_cyl_el_separation_result.mat');
log_path = fullfile(result_dir, 'step11_1_cyl_el_separation.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
plot_paths = make_plots_local(summary_table, result_dir, beam_layouts, center_bias_cases);

params = struct();
params.base_seed = base_seed;
params.L = L;
params.Metkl = Metkl;
params.az_center_true = az_center_true;
params.el_center_nominal = el_center_nominal;
params.az_sep_list = az_sep_list;
params.el_sep_true_list = el_sep_true_list;
params.el_center_offset_list = el_center_offset_list;
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
params.el_sep_index_list = el_sep_index_list;
params.search_orientations = search_orientations;
params.az_tol_deg = az_tol_deg;
params.el_tol_deg = el_tol_deg;
params.el_sep_tol_deg = el_sep_tol_deg;
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
log_lines = append_log_local(log_lines, 'cyl_el_separation_pass_flag=%d', keypoints.cyl_el_separation_pass_flag);
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
        cache(idx).W = W;
        cache(idx).beam_info = beam_info;
        cache(idx).grid = grid;
    end
end
end

function row = make_trial_row_template_local()
row = struct();
fields = { ...
    'trial_id','source_mode','whitening_mode','beam_layout_name','beam_az_count','beam_el_count','beam_count', ...
    'az_center_bias_deg','el_center_bias_deg','az_beam_c','el_beam_c','az_sep_deg','el_sep_true_deg', ...
    'el_center_offset_deg','true_orientation','snr_db','az_hat_sep_1','az_hat_sep_2','el_hat_sep_1', ...
    'el_hat_sep_2','el_sep_hat_deg','orientation_hat','az_hat_common_1','az_hat_common_2', ...
    'el_hat_common_1','el_hat_common_2','az_true_1','az_true_2','el_true_1','el_true_2', ...
    'sep_raw_success','sep_az_tol_success','sep_el_pair_tol_success','sep_joint_pair_tol_success', ...
    'sep_az_rmse_deg','sep_el_rmse_deg','sep_el_sep_error_deg','sep_false_el_split','sep_boundary_hit', ...
    'common_raw_success','common_az_tol_success','common_el_pair_tol_success','common_joint_pair_tol_success', ...
    'common_az_rmse_deg','common_el_rmse_deg','common_el_sep_error_deg','common_false_el_split','common_boundary_hit', ...
    'score_margin_sep_minus_common','score_ratio_sep_over_common','manifold_corr_truth','cond_WHW', ...
    'cond_best_GHG_sep','cond_best_GHG_common','max_score_sep','max_score_common','num_pairs_sep', ...
    'num_pairs_common','N_elem','L','phase_factor','phase_sign'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.source_mode = '';
row.whitening_mode = '';
row.beam_layout_name = '';
bool_fields = {'sep_raw_success','sep_az_tol_success','sep_el_pair_tol_success','sep_joint_pair_tol_success', ...
    'sep_false_el_split','sep_boundary_hit','common_raw_success','common_az_tol_success', ...
    'common_el_pair_tol_success','common_joint_pair_tol_success','common_false_el_split','common_boundary_hit'};
for idx = 1:numel(bool_fields)
    row.(bool_fields{idx}) = false;
end
end

function rows = build_summary_rows_local(trial_table, source_mode_list, whitening_mode_list, ...
    beam_layouts, center_bias_cases, az_sep_list, el_sep_true_list, el_center_offset_list, snr_list)
template = make_summary_row_template_local();
nRows = numel(source_mode_list) * numel(whitening_mode_list) * numel(beam_layouts) * ...
    size(center_bias_cases, 1) * numel(az_sep_list) * numel(el_sep_true_list) * ...
    numel(el_center_offset_list) * numel(snr_list);
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
                for iAzSep = 1:numel(az_sep_list)
                    az_sep = az_sep_list(iAzSep);
                    for iElSep = 1:numel(el_sep_true_list)
                        el_sep_true = el_sep_true_list(iElSep);
                        for iElOff = 1:numel(el_center_offset_list)
                            el_off = el_center_offset_list(iElOff);
                            for iSnr = 1:numel(snr_list)
                                snr_db = snr_list(iSnr);
                                mask = source_mask & white_mask & layout_mask & ...
                                    abs(trial_table.az_center_bias_deg - az_bias) < 1e-12 & ...
                                    abs(trial_table.el_center_bias_deg - el_bias) < 1e-12 & ...
                                    abs(trial_table.az_sep_deg - az_sep) < 1e-12 & ...
                                    abs(trial_table.el_sep_true_deg - el_sep_true) < 1e-12 & ...
                                    abs(trial_table.el_center_offset_deg - el_off) < 1e-12 & ...
                                    abs(trial_table.snr_db - snr_db) < 1e-12;
                                sub = trial_table(mask, :);
                                if isempty(sub)
                                    error('run_stage4:MissingSummaryGroup', 'Missing summary group.');
                                end
                                idx = idx + 1;
                                rows(idx).source_mode = source_mode;
                                rows(idx).whitening_mode = whitening_mode;
                                rows(idx).beam_layout_name = layout.name;
                                rows(idx).beam_count = layout.az_count * layout.el_count;
                                rows(idx).az_center_bias_deg = az_bias;
                                rows(idx).el_center_bias_deg = el_bias;
                                rows(idx).az_sep_deg = az_sep;
                                rows(idx).el_sep_true_deg = el_sep_true;
                                rows(idx).el_center_offset_deg = el_off;
                                rows(idx).snr_db = snr_db;
                                rows(idx).sep_raw_success_rate = mean(double(sub.sep_raw_success));
                                rows(idx).sep_az_tol_success_rate = mean(double(sub.sep_az_tol_success));
                                rows(idx).sep_el_pair_tol_success_rate = mean(double(sub.sep_el_pair_tol_success));
                                rows(idx).sep_joint_pair_tol_success_rate = mean(double(sub.sep_joint_pair_tol_success));
                                rows(idx).sep_mean_az_rmse_deg = mean_omitnan_local(sub.sep_az_rmse_deg);
                                rows(idx).sep_mean_el_rmse_deg = mean_omitnan_local(sub.sep_el_rmse_deg);
                                rows(idx).sep_mean_abs_el_sep_error_deg = mean_omitnan_local(abs(sub.sep_el_sep_error_deg));
                                rows(idx).sep_false_el_split_rate = mean(double(sub.sep_false_el_split));
                                rows(idx).sep_boundary_hit_rate = mean(double(sub.sep_boundary_hit));
                                rows(idx).common_joint_pair_tol_success_rate = mean(double(sub.common_joint_pair_tol_success));
                                rows(idx).common_mean_az_rmse_deg = mean_omitnan_local(sub.common_az_rmse_deg);
                                rows(idx).common_mean_el_rmse_deg = mean_omitnan_local(sub.common_el_rmse_deg);
                                rows(idx).common_mean_abs_el_sep_error_deg = mean_omitnan_local(abs(sub.common_el_sep_error_deg));
                                rows(idx).common_false_el_split_rate = mean(double(sub.common_false_el_split));
                                rows(idx).common_boundary_hit_rate = mean(double(sub.common_boundary_hit));
                                rows(idx).sep_minus_common_joint_success_gap = rows(idx).sep_joint_pair_tol_success_rate - rows(idx).common_joint_pair_tol_success_rate;
                                rows(idx).sep_minus_common_el_rmse_reduction = rows(idx).common_mean_el_rmse_deg - rows(idx).sep_mean_el_rmse_deg;
                                rows(idx).mean_score_margin_sep_minus_common = mean_omitnan_local(sub.score_margin_sep_minus_common);
                                rows(idx).mean_score_ratio_sep_over_common = mean_omitnan_local(sub.score_ratio_sep_over_common);
                                rows(idx).mean_manifold_corr_truth = mean_omitnan_local(sub.manifold_corr_truth);
                                rows(idx).mean_cond_WHW = mean_omitnan_local(sub.cond_WHW);
                                rows(idx).mean_cond_best_GHG_sep = mean_omitnan_local(sub.cond_best_GHG_sep);
                                rows(idx).mean_cond_best_GHG_common = mean_omitnan_local(sub.cond_best_GHG_common);
                                rows(idx).mean_num_pairs_sep = mean_omitnan_local(sub.num_pairs_sep);
                                rows(idx).mean_num_pairs_common = mean_omitnan_local(sub.num_pairs_common);
                            end
                        end
                    end
                end
            end
        end
    end
end
end

function row = make_summary_row_template_local()
row = struct();
names = {'source_mode','whitening_mode','beam_layout_name','beam_count','az_center_bias_deg','el_center_bias_deg', ...
    'az_sep_deg','el_sep_true_deg','el_center_offset_deg','snr_db','sep_raw_success_rate','sep_az_tol_success_rate', ...
    'sep_el_pair_tol_success_rate','sep_joint_pair_tol_success_rate','sep_mean_az_rmse_deg','sep_mean_el_rmse_deg', ...
    'sep_mean_abs_el_sep_error_deg','sep_false_el_split_rate','sep_boundary_hit_rate','common_joint_pair_tol_success_rate', ...
    'common_mean_az_rmse_deg','common_mean_el_rmse_deg','common_mean_abs_el_sep_error_deg','common_false_el_split_rate', ...
    'common_boundary_hit_rate','sep_minus_common_joint_success_gap','sep_minus_common_el_rmse_reduction', ...
    'mean_score_margin_sep_minus_common','mean_score_ratio_sep_over_common','mean_manifold_corr_truth','mean_cond_WHW', ...
    'mean_cond_best_GHG_sep','mean_cond_best_GHG_common','mean_num_pairs_sep','mean_num_pairs_common'};
for idx = 1:numel(names)
    row.(names{idx}) = NaN;
end
row.source_mode = '';
row.whitening_mode = '';
row.beam_layout_name = '';
end

function [rows, keypoints] = build_keypoints_local(summary_table, beam_layouts)
pass_sub = select_pass_subset_local(summary_table, 'white');
common_sub = select_pass_subset_local(summary_table, 'white');
[best_sep_joint, best_common_joint, best_layout, mean_corr_best, mean_el_sep_err_best, boundary_best, false_split_best] = ...
    best_layout_stats_local(pass_sub, beam_layouts);
none_sub = select_pass_subset_local(summary_table, 'none');
[best_sep_none, ~, ~, ~, ~, ~, ~] = best_layout_stats_local(none_sub, beam_layouts);

pass_flag = double(best_sep_joint >= 0.75 && mean_el_sep_err_best <= 0.25 && boundary_best <= 0.2 && false_split_best <= 0.2);
if pass_flag == 1
    recommended_next_step = 'proceed_to_cylindrical_coherence_stress_or_model_selection';
else
    recommended_next_step = 'debug_el_separation_grid_layout_or_regularization';
end

keypoints = struct();
keypoints.best_sep_joint_success_bias0_snr30 = best_sep_joint;
keypoints.best_common_joint_success_bias0_snr30 = best_common_joint;
keypoints.sep_minus_common_joint_success_gap_bias0_snr30 = best_sep_joint - best_common_joint;
keypoints.best_layout_sep_bias0_snr30 = best_layout;
keypoints.max_sep_boundary_hit_rate = max(summary_table.sep_boundary_hit_rate);
keypoints.max_sep_false_el_split_rate_when_true_sep0 = max(summary_table.sep_false_el_split_rate(summary_table.el_sep_true_deg == 0));
keypoints.mean_manifold_corr_at_best = mean_corr_best;
keypoints.mean_abs_el_sep_error_at_best = mean_el_sep_err_best;
keypoints.cyl_el_separation_pass_flag = pass_flag;
keypoints.recommended_next_step = recommended_next_step;
keypoints.best_sep_none_joint_success_bias0_snr30 = best_sep_none;
keypoints.white_minus_none_sep_joint_success_gap_bias0_snr30 = best_sep_joint - best_sep_none;

rows = repmat(make_keypoint_row_template_local(), 12, 1);
rows(1) = make_keypoint_row_local('best_sep_joint_success_bias0_snr30', best_sep_joint, '');
rows(2) = make_keypoint_row_local('best_common_joint_success_bias0_snr30', best_common_joint, '');
rows(3) = make_keypoint_row_local('sep_minus_common_joint_success_gap_bias0_snr30', best_sep_joint - best_common_joint, '');
rows(4) = make_keypoint_row_local('best_layout_sep_bias0_snr30', NaN, best_layout);
rows(5) = make_keypoint_row_local('max_sep_boundary_hit_rate', keypoints.max_sep_boundary_hit_rate, '');
rows(6) = make_keypoint_row_local('max_sep_false_el_split_rate_when_true_sep0', keypoints.max_sep_false_el_split_rate_when_true_sep0, '');
rows(7) = make_keypoint_row_local('mean_manifold_corr_at_best', mean_corr_best, '');
rows(8) = make_keypoint_row_local('mean_abs_el_sep_error_at_best', mean_el_sep_err_best, '');
rows(9) = make_keypoint_row_local('cyl_el_separation_pass_flag', pass_flag, '');
rows(10) = make_keypoint_row_local('recommended_next_step', NaN, recommended_next_step);
rows(11) = make_keypoint_row_local('best_sep_none_joint_success_bias0_snr30', best_sep_none, '');
rows(12) = make_keypoint_row_local('white_minus_none_sep_joint_success_gap_bias0_snr30', best_sep_joint - best_sep_none, '');
end

function sub = select_pass_subset_local(summary_table, whitening_mode)
mask = string_match_local(summary_table.source_mode, 'noncoherent') & ...
    string_match_local(summary_table.whitening_mode, whitening_mode) & ...
    abs(summary_table.az_center_bias_deg) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg) < 1e-12 & ...
    abs(summary_table.snr_db - 30) < 1e-12;
sub = summary_table(mask, :);
if isempty(sub)
    error('run_stage4:MissingPassSubset', 'Missing pass subset.');
end
end

function [best_sep_joint, best_common_joint, best_layout, mean_corr_best, mean_el_sep_err_best, boundary_best, false_split_best] = best_layout_stats_local(sub, beam_layouts)
best_sep_joint = -Inf;
best_common_joint = NaN;
best_layout = '';
mean_corr_best = NaN;
mean_el_sep_err_best = NaN;
boundary_best = NaN;
false_split_best = NaN;
for iLayout = 1:numel(beam_layouts)
    layout_name = beam_layouts(iLayout).name;
    layout_sub = sub(string_match_local(sub.beam_layout_name, layout_name), :);
    positive_sub = layout_sub(layout_sub.el_sep_true_deg > 0, :);
    zero_sub = layout_sub(layout_sub.el_sep_true_deg == 0, :);
    mean_sep_joint = mean_omitnan_local(positive_sub.sep_joint_pair_tol_success_rate);
    mean_common_joint = mean_omitnan_local(positive_sub.common_joint_pair_tol_success_rate);
    mean_el_sep_err = mean_omitnan_local(positive_sub.sep_mean_abs_el_sep_error_deg);
    max_boundary = max(layout_sub.sep_boundary_hit_rate);
    max_false_split = max(zero_sub.sep_false_el_split_rate);
    mean_corr = mean_omitnan_local(layout_sub.mean_manifold_corr_truth);
    if mean_sep_joint > best_sep_joint || (mean_sep_joint == best_sep_joint && mean_el_sep_err < mean_el_sep_err_best)
        best_sep_joint = mean_sep_joint;
        best_common_joint = mean_common_joint;
        best_layout = layout_name;
        mean_corr_best = mean_corr;
        mean_el_sep_err_best = mean_el_sep_err;
        boundary_best = max_boundary;
        false_split_best = max_false_split;
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

function plot_paths = make_plots_local(summary_table, result_dir, beam_layouts, center_bias_cases)
plot_paths = {};
plot_paths{end + 1} = plot_joint_success_by_layout_local(summary_table, result_dir, beam_layouts);
plot_paths{end + 1} = plot_el_rmse_compare_local(summary_table, result_dir, beam_layouts);
plot_paths{end + 1} = plot_success_gap_local(summary_table, result_dir, beam_layouts);
plot_paths{end + 1} = plot_false_split_local(summary_table, result_dir, beam_layouts);
plot_paths{end + 1} = plot_boundary_hit_local(summary_table, result_dir, center_bias_cases);
plot_paths{end + 1} = plot_manifold_corr_local(summary_table, result_dir, beam_layouts);
plot_paths{end + 1} = plot_score_margin_local(summary_table, result_dir, beam_layouts);
end

function out_path = plot_joint_success_by_layout_local(summary_table, result_dir, beam_layouts)
sub = select_pass_subset_local(summary_table, 'white');
vals = nan(1, numel(beam_layouts));
labels = {beam_layouts.name};
for idx = 1:numel(beam_layouts)
    layout_sub = sub(string_match_local(sub.beam_layout_name, labels{idx}) & sub.el_sep_true_deg > 0, :);
    vals(idx) = mean_omitnan_local(layout_sub.sep_joint_pair_tol_success_rate);
end
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('sep model joint success');
title('El-separated joint success by layout');
out_path = fullfile(result_dir, 'cyl_el_sep_joint_success_by_layout.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_el_rmse_compare_local(summary_table, result_dir, beam_layouts)
sub = select_pass_subset_local(summary_table, 'white');
sep_vals = nan(1, numel(beam_layouts));
common_vals = nan(1, numel(beam_layouts));
labels = {beam_layouts.name};
for idx = 1:numel(beam_layouts)
    layout_sub = sub(string_match_local(sub.beam_layout_name, labels{idx}) & sub.el_sep_true_deg > 0, :);
    sep_vals(idx) = mean_omitnan_local(layout_sub.sep_mean_el_rmse_deg);
    common_vals(idx) = mean_omitnan_local(layout_sub.common_mean_el_rmse_deg);
end
fig = figure('Visible', 'off');
bar([sep_vals(:), common_vals(:)], 'grouped');
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean el RMSE (deg)');
title('El-separated vs common-el elevation RMSE');
legend({'el-separated', 'common-el'}, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_el_sep_el_rmse_compare.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_success_gap_local(summary_table, result_dir, beam_layouts)
sub = select_pass_subset_local(summary_table, 'white');
vals = nan(1, numel(beam_layouts));
labels = {beam_layouts.name};
for idx = 1:numel(beam_layouts)
    layout_sub = sub(string_match_local(sub.beam_layout_name, labels{idx}) & sub.el_sep_true_deg > 0, :);
    vals(idx) = mean_omitnan_local(layout_sub.sep_minus_common_joint_success_gap);
end
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('joint success gap');
title('El-separated minus common-el success gap');
out_path = fullfile(result_dir, 'cyl_el_sep_vs_common_success_gap.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_false_split_local(summary_table, result_dir, beam_layouts)
sub = select_pass_subset_local(summary_table, 'white');
vals = nan(1, numel(beam_layouts));
labels = {beam_layouts.name};
for idx = 1:numel(beam_layouts)
    layout_sub = sub(string_match_local(sub.beam_layout_name, labels{idx}) & sub.el_sep_true_deg == 0, :);
    vals(idx) = max(layout_sub.sep_false_el_split_rate);
end
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('false split rate');
title('False elevation split when true sep=0');
out_path = fullfile(result_dir, 'cyl_el_sep_false_split_true_sep0.png');
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
    vals(iBias) = max(summary_table.sep_boundary_hit_rate(mask));
    labels{iBias} = sprintf('[%.1f %.1f]', az_bias, el_bias);
end
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
xlabel('[az bias, el bias] deg');
ylabel('max sep boundary hit rate');
title('El-separated boundary hit risk');
out_path = fullfile(result_dir, 'cyl_el_sep_boundary_hit_rate.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_manifold_corr_local(summary_table, result_dir, beam_layouts)
sub = select_pass_subset_local(summary_table, 'white');
vals = nan(1, numel(beam_layouts));
labels = {beam_layouts.name};
for idx = 1:numel(beam_layouts)
    layout_sub = sub(string_match_local(sub.beam_layout_name, labels{idx}), :);
    vals(idx) = mean_omitnan_local(layout_sub.mean_manifold_corr_truth);
end
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean truth manifold correlation');
title('El-separated beamspace manifold correlation');
out_path = fullfile(result_dir, 'cyl_el_sep_manifold_corr.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_score_margin_local(summary_table, result_dir, beam_layouts)
sub = select_pass_subset_local(summary_table, 'white');
vals = nan(1, numel(beam_layouts));
labels = {beam_layouts.name};
for idx = 1:numel(beam_layouts)
    layout_sub = sub(string_match_local(sub.beam_layout_name, labels{idx}), :);
    vals(idx) = mean_omitnan_local(layout_sub.mean_score_margin_sep_minus_common);
end
fig = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
grid on;
ylabel('mean score margin');
title('DML score margin: el-separated minus common-el');
out_path = fullfile(result_dir, 'cyl_el_sep_score_margin.png');
saveas(fig, out_path);
close(fig);
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

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage4:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
