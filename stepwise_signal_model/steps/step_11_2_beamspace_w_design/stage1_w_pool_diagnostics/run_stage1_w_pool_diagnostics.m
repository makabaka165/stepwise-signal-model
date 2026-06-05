clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
step11_1_common_dir = fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common');
result_dir = fullfile(step_dir, 'results_step11_2_w_pool_diagnostics');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.2 Stage1 W pool diagnostics starts');
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
    error('run_stage1_w_pool_diagnostics:NelemMismatch', 'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;
az_c = cfg.beam.azSectorCenter;
el_c = cfg.beam.elSectorCenter;
B_list = [9, 15, 25];
reg = 1e-10;

az_patch = az_c + (-1.5:0.15:1.5);
el_patch = el_c + (-1.0:0.15:1.0);
pair_set = build_pair_set_local(az_c, el_c, [0.83, 1.27], [0, 0.37, 0.67], [1, -1]);

log_lines = append_log_local(log_lines, 'N_elem=%d, expected_N_elem=%d, lambda=%.12g', N_elem, expected_N_elem, lambda);
log_lines = append_log_local(log_lines, 'phase_factor=%.6g, phase_sign=%+.0f, center=(%.3f, %.3f)', phase_factor, phase_sign, az_c, el_c);
log_lines = append_log_local(log_lines, 'B_list=%s, reg=%.3g', mat2str(B_list), reg);
log_lines = append_log_local(log_lines, 'A_patch az=%s, el=%s', compact_range_string_local(az_patch), compact_range_string_local(el_patch));
log_lines = append_log_local(log_lines, 'pair_set rows=%d', size(pair_set, 1));

[W_pool, pool_info] = build_existing_2d_beam_pool(x, y, z, az_c, el_c, lambda, cfg, ...
    'Mode', 'legacy_or_fallback', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
log_lines = append_log_local(log_lines, 'Built W_pool: N_elem=%d, M=%d, mode=%s', size(W_pool, 1), size(W_pool, 2), pool_info.mode_used);
log_lines = append_log_local(log_lines, 'Pool note: %s', pool_info.note);

[A_patch, patch_info] = build_local_patch_dictionary(x, y, z, az_patch, el_patch, lambda, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
log_lines = append_log_local(log_lines, 'Built A_patch: N_elem=%d, N_patch=%d', size(A_patch, 1), size(A_patch, 2));

summary_rows = repmat(make_summary_template_local(), 0, 1);
W_case_bank = struct([]);
greedy_history_bank = struct([]);
svd_energy = [];

tic;
for iB = 1:numel(B_list)
    B = B_list(iB);
    log_lines = append_log_local(log_lines, 'Evaluating B=%d', B);

    [idx_regular, regular_layout] = select_regular_indices_local(pool_info, B, az_c, el_c);
    W_regular = W_pool(:, idx_regular);
    [summary_rows, W_case_bank] = add_case_local(summary_rows, W_case_bank, ...
        'regular_3dB_grid', 'regular', B, W_regular, idx_regular, regular_layout, ...
        A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg);

    [idx_gproj, W_gproj, hist_gproj] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, ...
        'Criterion', 'projection', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
    [summary_rows, W_case_bank] = add_case_local(summary_rows, W_case_bank, ...
        'greedy_projection', 'greedy_projection', B, W_gproj, idx_gproj, 'greedy_projection', ...
        A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg);
    greedy_history_bank = add_history_local(greedy_history_bank, 'greedy_projection', B, hist_gproj);

    [idx_glow, W_glow, hist_glow] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, ...
        'Criterion', 'lowcorr', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
    [summary_rows, W_case_bank] = add_case_local(summary_rows, W_case_bank, ...
        'greedy_lowcorr', 'greedy_lowcorr', B, W_glow, idx_glow, 'greedy_lowcorr', ...
        A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg);
    greedy_history_bank = add_history_local(greedy_history_bank, 'greedy_lowcorr', B, hist_glow);

    [idx_gcomb, W_gcomb, hist_gcomb] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, ...
        'Criterion', 'combined', 'Alpha', 1, 'Beta', 1, 'Gamma', 0.05, ...
        'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
    [summary_rows, W_case_bank] = add_case_local(summary_rows, W_case_bank, ...
        'greedy_combined', 'greedy_combined', B, W_gcomb, idx_gcomb, 'greedy_combined', ...
        A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg);
    greedy_history_bank = add_history_local(greedy_history_bank, 'greedy_combined', B, hist_gcomb);

    [W_svd, svd_info] = build_svd_beamspace_basis(A_patch, B);
    if isempty(svd_energy)
        svd_energy = svd_info.energy_cumsum;
    end
    [summary_rows, W_case_bank] = add_case_local(summary_rows, W_case_bank, ...
        'svd_upper_bound', 'svd_upper_bound', B, W_svd, 1:B, 'svd_upper_bound', ...
        A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg);
    W_case_bank(end).svd_energy_retained_B = svd_info.energy_retained_B;

    [W_rand, idx_rand] = build_random_w_from_pool(W_pool, B, 20260625 + B);
    [summary_rows, W_case_bank] = add_case_local(summary_rows, W_case_bank, ...
        'random_pool_baseline', 'random_pool_baseline', B, W_rand, idx_rand, 'random_pool_baseline', ...
        A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg);

    log_lines = append_log_local(log_lines, 'Finished B=%d, elapsed %.2f s', B, toc);
end

summary_table = struct2table(summary_rows);
keypoints = build_keypoints_local(summary_table);
keypoint_table = keypoints_to_table_local(keypoints);
plot_paths = make_plots_local(summary_table, svd_energy, result_dir);

summary_csv = fullfile(result_dir, 'step11_2_w_pool_diagnostics_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_2_w_pool_diagnostics_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_2_w_pool_diagnostics_result.mat');
log_path = fullfile(result_dir, 'step11_2_w_pool_diagnostics.log');

writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);

params = struct();
params.B_list = B_list;
params.az_patch = az_patch;
params.el_patch = el_patch;
params.pair_set = pair_set;
params.reg = reg;
params.N_elem = N_elem;
params.phase_factor = phase_factor;
params.phase_sign = phase_sign;
params.lambda = lambda;
params.az_c = az_c;
params.el_c = el_c;
save(mat_path, 'params', 'pool_info', 'patch_info', 'summary_table', 'keypoint_table', ...
    'keypoints', 'W_case_bank', 'greedy_history_bank', 'svd_energy', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_log_local(log_lines, 'Keypoints:');
names = fieldnames(keypoints);
for iName = 1:numel(names)
    value = keypoints.(names{iName});
    if isnumeric(value) || islogical(value)
        log_lines = append_log_local(log_lines, '  %s = %.12g', names{iName}, double(value));
    else
        log_lines = append_log_local(log_lines, '  %s = %s', names{iName}, char(value));
    end
end
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function pair_set = build_pair_set_local(az_c, el_c, az_sep_list, el_sep_list, orientation_list)
pair_set = zeros(numel(az_sep_list) * numel(el_sep_list) * numel(orientation_list), 4);
idx = 0;
for iAz = 1:numel(az_sep_list)
    az_sep = az_sep_list(iAz);
    az_pair = az_c + [-az_sep/2, az_sep/2];
    for iEl = 1:numel(el_sep_list)
        el_sep = el_sep_list(iEl);
        for iOri = 1:numel(orientation_list)
            orientation = orientation_list(iOri);
            if el_sep == 0 && orientation == -1
                continue;
            end
            idx = idx + 1;
            if orientation == 1
                el_pair = el_c + [-el_sep/2, el_sep/2];
            else
                el_pair = el_c + [el_sep/2, -el_sep/2];
            end
            pair_set(idx, :) = [az_pair(1), el_pair(1), az_pair(2), el_pair(2)];
        end
    end
end
pair_set = pair_set(1:idx, :);
end

function [idx_regular, layout_name] = select_regular_indices_local(pool_info, B, az_c, el_c)
switch B
    case 9
        az_count = 3;
        el_count = 3;
        layout_name = 'az3_el3';
    case 15
        az_count = 5;
        el_count = 3;
        layout_name = 'az5_el3';
    case 25
        az_count = 5;
        el_count = 5;
        layout_name = 'az5_el5';
    otherwise
        side = ceil(sqrt(B));
        az_count = side;
        el_count = ceil(B / side);
        layout_name = sprintf('center_nearest_%d', B);
end

az_vals = sort_by_center_local(unique(round(pool_info.beam_az_col, 10)), az_c);
el_vals = sort_by_center_local(unique(round(pool_info.beam_el_col, 10)), el_c);
az_sel = sort(az_vals(1:min(az_count, numel(az_vals))));
el_sel = sort(el_vals(1:min(el_count, numel(el_vals))));
idx = find(ismembertol(pool_info.beam_az_col, az_sel, 1e-9) & ismembertol(pool_info.beam_el_col, el_sel, 1e-9));
idx = idx(:).';
if numel(idx) < B
    score = hypot(pool_info.beam_az_col - az_c, pool_info.beam_el_col - el_c);
    [~, order] = sort(score, 'ascend');
    idx = order(1:B);
elseif numel(idx) > B
    score = hypot(pool_info.beam_az_col(idx) - az_c, pool_info.beam_el_col(idx) - el_c);
    [~, order] = sort(score, 'ascend');
    idx = idx(order(1:B));
end
idx_regular = sort(idx);
end

function values_sorted = sort_by_center_local(values, center)
[~, order] = sort(abs(values(:).' - center), 'ascend');
values_sorted = values(order);
end

function [summary_rows, W_case_bank] = add_case_local(summary_rows, W_case_bank, method_name, method_type, B, W, ...
    selected_idx, selection_note, A_patch, pair_set, x, y, z, lambda, phase_factor, phase_sign, reg)
metrics = collect_w_design_metrics(method_name, B, W, A_patch, pair_set, x, y, z, lambda, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
metrics.method_type = method_type;
metrics.selection_note = selection_note;
metrics.selected_idx_text = mat2str(selected_idx);
summary_rows(end + 1, 1) = metrics; %#ok<AGROW>

case_entry = struct();
case_entry.name = method_name;
case_entry.method_type = method_type;
case_entry.B = B;
case_entry.W = W;
case_entry.selected_idx = selected_idx;
case_entry.selection_note = selection_note;
case_entry.projection_loss = metrics.projection_loss;
case_entry.mean_corr = metrics.mean_corr;
case_entry.max_corr = metrics.max_corr;
case_entry.cond_WHW = metrics.cond_WHW;
case_entry.rank_W = metrics.rank_W;
case_entry.svd_energy_retained_B = NaN;
W_case_bank = [W_case_bank; case_entry]; %#ok<AGROW>
end

function greedy_history_bank = add_history_local(greedy_history_bank, method_name, B, history)
entry = struct();
entry.method_name = method_name;
entry.B = B;
entry.history = history;
greedy_history_bank = [greedy_history_bank; entry]; %#ok<AGROW>
end

function row = make_summary_template_local()
row = struct();
row.method_name = '';
row.B = NaN;
row.beam_count = NaN;
row.projection_loss = NaN;
row.projected_energy_ratio = NaN;
row.mean_corr = NaN;
row.median_corr = NaN;
row.p90_corr = NaN;
row.max_corr = NaN;
row.min_corr = NaN;
row.num_pairs = NaN;
row.cond_WHW = NaN;
row.rank_W = NaN;
row.min_sv = NaN;
row.max_sv = NaN;
row.effective_rank = NaN;
row.mean_cond_GHG = NaN;
row.max_cond_GHG = NaN;
row.method_type = '';
row.selection_note = '';
row.selected_idx_text = '';
end

function keypoints = build_keypoints_local(summary_table)
regular_B25 = select_row_local(summary_table, 'regular_3dB_grid', 25);
gproj_B25 = select_row_local(summary_table, 'greedy_projection', 25);
glow_B25 = select_row_local(summary_table, 'greedy_lowcorr', 25);
gcomb_B25 = select_row_local(summary_table, 'greedy_combined', 25);
svd_B25 = select_row_local(summary_table, 'svd_upper_bound', 25);

[best_greedy_loss, best_greedy_idx] = min([gproj_B25.projection_loss, glow_B25.projection_loss, gcomb_B25.projection_loss]);
greedy_loss_names = {'greedy_projection','greedy_lowcorr','greedy_combined'};
[best_greedy_corr, best_greedy_corr_idx] = min([gproj_B25.max_corr, glow_B25.max_corr, gcomb_B25.max_corr]);

keypoints = struct();
keypoints.best_regular_projection_loss_B25 = regular_B25.projection_loss;
keypoints.best_greedy_projection_loss_B25 = best_greedy_loss;
keypoints.best_greedy_projection_method_B25 = greedy_loss_names{best_greedy_idx};
keypoints.svd_projection_loss_B25 = svd_B25.projection_loss;
keypoints.greedy_minus_regular_projection_loss_gain_B25 = regular_B25.projection_loss - best_greedy_loss;
keypoints.greedy_to_svd_projection_loss_gap_B25 = best_greedy_loss - svd_B25.projection_loss;
keypoints.regular_max_corr_B25 = regular_B25.max_corr;
keypoints.greedy_max_corr_B25 = best_greedy_corr;
keypoints.best_greedy_corr_method_B25 = greedy_loss_names{best_greedy_corr_idx};
keypoints.svd_max_corr_B25 = svd_B25.max_corr;
keypoints.regular_cond_WHW_B25 = regular_B25.cond_WHW;
keypoints.greedy_combined_cond_WHW_B25 = gcomb_B25.cond_WHW;
keypoints.svd_cond_WHW_B25 = svd_B25.cond_WHW;
keypoints.w_pool_diagnostics_pass_flag = ...
    (best_greedy_loss < regular_B25.projection_loss) || (best_greedy_corr < regular_B25.max_corr);
if keypoints.w_pool_diagnostics_pass_flag
    keypoints.recommended_next_step = 'run_stage2_backend_validation_for_regular_greedy_svd';
else
    keypoints.recommended_next_step = 'document_regular_3dB_near_pool_best_and_run_stage2_sanity';
end
end

function row = select_row_local(T, method_name, B)
mask = strcmp(cellstr(T.method_name), method_name) & abs(T.B - B) < 1e-12;
if ~any(mask)
    error('run_stage1_w_pool_diagnostics:MissingSummaryRow', 'Missing %s B=%d.', method_name, B);
end
row = table2struct(T(find(mask, 1), :));
end

function keypoint_table = keypoints_to_table_local(keypoints)
names = fieldnames(keypoints);
rows = repmat(struct('keypoint', '', 'value', ''), numel(names), 1);
for idx = 1:numel(names)
    rows(idx).keypoint = names{idx};
    value = keypoints.(names{idx});
    if isnumeric(value) || islogical(value)
        rows(idx).value = sprintf('%.12g', double(value));
    else
        rows(idx).value = char(value);
    end
end
keypoint_table = struct2table(rows);
end

function plot_paths = make_plots_local(summary_table, svd_energy, result_dir)
plot_paths = {};
plot_paths{end + 1} = plot_metric_vs_B_local(summary_table, result_dir, 'projection_loss', ...
    'projection loss', 'w_projection_loss_vs_B.png');
plot_paths{end + 1} = plot_metric_vs_B_local(summary_table, result_dir, 'max_corr', ...
    'max manifold corr', 'w_max_corr_vs_B.png');
plot_paths{end + 1} = plot_metric_vs_B_local(summary_table, result_dir, 'cond_WHW', ...
    'cond(W''W)', 'w_cond_vs_B.png');
plot_paths{end + 1} = plot_svd_energy_local(svd_energy, result_dir);
end

function out_path = plot_metric_vs_B_local(summary_table, result_dir, metric_name, y_label, file_name)
methods = {'regular_3dB_grid','greedy_projection','greedy_lowcorr','greedy_combined','svd_upper_bound','random_pool_baseline'};
fig = figure('Visible', 'off');
hold on;
for iMethod = 1:numel(methods)
    mask = strcmp(cellstr(summary_table.method_name), methods{iMethod});
    sub = summary_table(mask, :);
    [B_vals, order] = sort(sub.B);
    vals = sub.(metric_name);
    plot(B_vals, vals(order), '-o', 'LineWidth', 1.4);
end
hold off;
grid on;
xlabel('B');
ylabel(y_label);
title(strrep(file_name, '_', '\_'));
legend(methods, 'Location', 'best');
out_path = fullfile(result_dir, file_name);
saveas(fig, out_path);
close(fig);
end

function out_path = plot_svd_energy_local(svd_energy, result_dir)
fig = figure('Visible', 'off');
plot(1:numel(svd_energy), svd_energy, '-o', 'LineWidth', 1.4);
grid on;
xlabel('SVD mode count');
ylabel('cumulative energy');
title('Local patch SVD energy curve');
ylim([0, 1.02]);
out_path = fullfile(result_dir, 'w_svd_energy_curve.png');
saveas(fig, out_path);
close(fig);
end

function s = compact_range_string_local(v)
if numel(v) < 2
    s = mat2str(v);
else
    s = sprintf('[%.3f:%.3f:%.3f] (%d)', v(1), v(2)-v(1), v(end), numel(v));
end
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage1_w_pool_diagnostics:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end

