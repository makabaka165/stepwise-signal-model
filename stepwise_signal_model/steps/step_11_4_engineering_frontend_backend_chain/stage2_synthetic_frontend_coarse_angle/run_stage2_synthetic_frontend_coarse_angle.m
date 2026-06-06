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
result_dir = fullfile(step_dir, 'results_step11_4_stage2_synthetic_frontend_coarse_angle');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.4 Stage2 synthetic frontend coarse-angle starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

cfg = sim_cfg();
arrInfo = arr_cyl(cfg, cfg.beam.azSectorCenter);
x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;

[frontend_beam_pool, pool_info] = build_frontend_beam_pool_from_existing_layout(step11_2_dir, cfg, arrInfo, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
log_lines = append_log_local(log_lines, 'Frontend beam pool: beams=%d, az=%d, el=%d', ...
    size(frontend_beam_pool.W, 2), numel(frontend_beam_pool.az_grid), numel(frontend_beam_pool.el_grid));

scenarios = build_stage_scenarios_local();
methods = {'peak','centroid_top9','centroid_threshold'};
Metkl = 10;
L = 64;
base_seed = 20260624;
az_center_true = cfg.beam.azSectorCenter;
el_center_nominal = cfg.beam.elSectorCenter;
el_center_offset = 0.31;

total_rows = height(scenarios) * Metkl * numel(methods);
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;
sample_frontend_out = struct();
sample_scan_out = struct();

tic;
for iScenario = 1:height(scenarios)
    scenario = table_row_to_struct_local(scenarios(iScenario, :));
    az_true = az_center_true + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
    el_center_true = el_center_nominal + el_center_offset;
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
        seed_now = base_seed + 1000 * iScenario + trial_id;
        [Y, truth] = make_cyl_pair2d_correlated_snapshots(x, y, z, az_true, el_true, ...
            lambda, L, scenario.snr_db, 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, ...
            'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
            'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
        scan_out = run_synthetic_frontend_beam_scan(Y, frontend_beam_pool);
        cluster_indicator = compute_frontend_cluster_indicators(scan_out);
        truth_center = [mean(truth.az_pair_deg), mean(truth.el_pair_deg)];

        for iMethod = 1:numel(methods)
            coarse_est = estimate_coarse_angle_from_frontend_beams(scan_out, methods{iMethod});
            frontend_out = make_frontend_out_struct( ...
                'CoarseAzDeg', coarse_est.coarse_az_deg, ...
                'CoarseElDeg', coarse_est.coarse_el_deg, ...
                'SearchWindow', struct('az_half_width_deg', 1.5, 'el_half_width_deg', 1.2), ...
                'BeamEnergy', scan_out.beam_energy_norm_grid, ...
                'ClusterIndicator', cluster_indicator, ...
                'Method', coarse_est.method, ...
                'Quality', struct('selected_beam_count', coarse_est.selected_beam_count), ...
                'TruthForMetrics', truth);
            if row_idx == 0
                sample_frontend_out = frontend_out;
                sample_scan_out = scan_out;
            end

            row_idx = row_idx + 1;
            az_error = frontend_out.coarse_az_deg - truth_center(1);
            el_error = frontend_out.coarse_el_deg - truth_center(2);
            trial_rows(row_idx) = make_trial_row_local(row_idx, iScenario, trial_id, seed_now, ...
                scenario, true_orientation, methods{iMethod}, frontend_out, truth_center, ...
                az_error, el_error, cluster_indicator);
        end
    end
end
elapsed_sec = toc;
if row_idx ~= total_rows
    error('run_stage2_synthetic_frontend_coarse_angle:RowCountMismatch', ...
        'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table, methods);
[keypoint_table, keypoints] = build_keypoints_local(summary_table);
plot_paths = plot_stage2_results_local(summary_table, result_dir);

trial_csv = fullfile(result_dir, 'step11_4_stage2_trial.csv');
summary_csv = fullfile(result_dir, 'step11_4_stage2_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_4_stage2_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_4_stage2_result.mat');
log_path = fullfile(result_dir, 'step11_4_stage2.log');
readme_path = fullfile(result_dir, 'README.md');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
params = struct('Metkl', Metkl, 'L', L, 'base_seed', base_seed, ...
    'az_center_true', az_center_true, 'el_center_nominal', el_center_nominal, ...
    'el_center_offset', el_center_offset, 'phase_factor', phase_factor, 'phase_sign', phase_sign);
save(mat_path, 'params', 'frontend_beam_pool', 'pool_info', 'scenarios', 'trial_table', ...
    'summary_table', 'keypoint_table', 'keypoints', 'sample_frontend_out', 'sample_scan_out', 'plot_paths');

log_lines = append_log_local(log_lines, 'Evaluation finished: rows=%d, elapsed=%.2f sec', height(trial_table), elapsed_sec);
log_lines = append_log_local(log_lines, 'Best method: %s', keypoints.best_method);
log_lines = append_log_local(log_lines, 'best_within_pm02deg_rate = %.12g', keypoints.best_within_pm02deg_rate);
log_lines = append_log_local(log_lines, 'best_az_rmse_deg = %.12g', keypoints.best_az_rmse_deg);
log_lines = append_log_local(log_lines, 'best_el_rmse_deg = %.12g', keypoints.best_el_rmse_deg);
log_lines = append_log_local(log_lines, 'frontend_coarse_angle_pass_flag = %d', keypoints.frontend_coarse_angle_pass_flag);
write_text_local(log_path, sprintf('%s\n', log_lines{:}));

status_lines = { ...
    '# Stage2 Synthetic Frontend Coarse-Angle Status', ...
    '', ...
    sprintf('- best_method = %s', keypoints.best_method), ...
    sprintf('- best_within_pm02deg_rate = %.6g', keypoints.best_within_pm02deg_rate), ...
    sprintf('- best_az_rmse_deg = %.6g', keypoints.best_az_rmse_deg), ...
    sprintf('- best_el_rmse_deg = %.6g', keypoints.best_el_rmse_deg), ...
    sprintf('- frontend_coarse_angle_pass_flag = %d', keypoints.frontend_coarse_angle_pass_flag), ...
    '', ...
    'The coarse center is estimated from beam energy. Truth is used only for offline error metrics.'};
write_text_local(readme_path, sprintf('%s\n', status_lines{:}));
fprintf('Stage2 synthetic frontend coarse-angle finished. Pass flag=%d. Results: %s\n', ...
    keypoints.frontend_coarse_angle_pass_flag, result_dir);

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

function row = make_trial_row_template_local()
row = struct();
row.row_id = NaN;
row.scenario_id = NaN;
row.scenario_name = "";
row.trial_id = NaN;
row.seed = NaN;
row.method = "";
row.rho = NaN;
row.phase_deg = NaN;
row.beta = NaN;
row.snr_db = NaN;
row.az_sep_deg = NaN;
row.el_sep_deg = NaN;
row.true_orientation = NaN;
row.truth_az_center_deg = NaN;
row.truth_el_center_deg = NaN;
row.coarse_az_deg = NaN;
row.coarse_el_deg = NaN;
row.coarse_az_error_deg = NaN;
row.coarse_el_error_deg = NaN;
row.within_pm02deg = false;
row.selected_beam_count = NaN;
row.beam_spread_indicator = NaN;
row.local_peak_count = NaN;
row.top1_top2_ratio = NaN;
row.cluster_score = NaN;
row.used_truth_for_center = false;
end

function row = make_trial_row_local(row_id, scenario_id, trial_id, seed_now, scenario, ...
    true_orientation, method, frontend_out, truth_center, az_error, el_error, cluster_indicator)
row = make_trial_row_template_local();
row.row_id = row_id;
row.scenario_id = scenario_id;
row.scenario_name = string(scenario.scenario_name);
row.trial_id = trial_id;
row.seed = seed_now;
row.method = string(method);
row.rho = scenario.rho;
row.phase_deg = scenario.phase_deg;
row.beta = scenario.beta;
row.snr_db = scenario.snr_db;
row.az_sep_deg = scenario.az_sep_deg;
row.el_sep_deg = scenario.el_sep_deg;
row.true_orientation = true_orientation;
row.truth_az_center_deg = truth_center(1);
row.truth_el_center_deg = truth_center(2);
row.coarse_az_deg = frontend_out.coarse_az_deg;
row.coarse_el_deg = frontend_out.coarse_el_deg;
row.coarse_az_error_deg = az_error;
row.coarse_el_error_deg = el_error;
row.within_pm02deg = abs(az_error) <= 0.2 && abs(el_error) <= 0.2;
row.selected_beam_count = frontend_out.quality.selected_beam_count;
row.beam_spread_indicator = cluster_indicator.beam_spread_indicator;
row.local_peak_count = cluster_indicator.local_peak_count;
row.top1_top2_ratio = cluster_indicator.top1_top2_ratio;
row.cluster_score = cluster_indicator.cluster_score;
row.used_truth_for_center = false;
end

function s = table_row_to_struct_local(Trow)
s = struct();
names = Trow.Properties.VariableNames;
for idx = 1:numel(names)
    value = Trow.(names{idx});
    if iscell(value)
        value = value{1};
    end
    if isstring(value)
        value = char(value);
    end
    s.(names{idx}) = value;
end
end

function summary_table = build_summary_table_local(trial_table, methods)
rows = repmat(make_summary_row_template_local(), numel(methods), 1);
for iMethod = 1:numel(methods)
    method = string(methods{iMethod});
    mask = trial_table.method == method;
    az_err = trial_table.coarse_az_error_deg(mask);
    el_err = trial_table.coarse_el_error_deg(mask);
    rows(iMethod).method = method;
    rows(iMethod).num_trials = sum(mask);
    rows(iMethod).az_rmse_deg = sqrt(mean(az_err.^2));
    rows(iMethod).el_rmse_deg = sqrt(mean(el_err.^2));
    rows(iMethod).az_mean_abs_error_deg = mean(abs(az_err));
    rows(iMethod).el_mean_abs_error_deg = mean(abs(el_err));
    rows(iMethod).az_max_abs_error_deg = max(abs(az_err));
    rows(iMethod).el_max_abs_error_deg = max(abs(el_err));
    rows(iMethod).within_pm02deg_rate = mean(trial_table.within_pm02deg(mask));
    rows(iMethod).mean_beam_spread_indicator = mean(trial_table.beam_spread_indicator(mask));
    rows(iMethod).mean_local_peak_count = mean(trial_table.local_peak_count(mask));
    rows(iMethod).used_truth_for_center_rate = mean(trial_table.used_truth_for_center(mask));
end
summary_table = struct2table(rows);
end

function row = make_summary_row_template_local()
row = struct();
row.method = "";
row.num_trials = NaN;
row.az_rmse_deg = NaN;
row.el_rmse_deg = NaN;
row.az_mean_abs_error_deg = NaN;
row.el_mean_abs_error_deg = NaN;
row.az_max_abs_error_deg = NaN;
row.el_max_abs_error_deg = NaN;
row.within_pm02deg_rate = NaN;
row.mean_beam_spread_indicator = NaN;
row.mean_local_peak_count = NaN;
row.used_truth_for_center_rate = NaN;
end

function [keypoint_table, keypoints] = build_keypoints_local(summary_table)
[~, order] = sortrows([ -summary_table.within_pm02deg_rate, ...
    summary_table.az_rmse_deg + summary_table.el_rmse_deg ]);
best = summary_table(order(1), :);
keypoints = struct();
keypoints.best_method = char(best.method);
keypoints.best_within_pm02deg_rate = best.within_pm02deg_rate;
keypoints.best_az_rmse_deg = best.az_rmse_deg;
keypoints.best_el_rmse_deg = best.el_rmse_deg;
keypoints.best_used_truth_for_center_rate = best.used_truth_for_center_rate;
keypoints.frontend_prior_robustness_pm02_reference = 1;
keypoints.frontend_coarse_angle_pass_flag = keypoints.best_within_pm02deg_rate >= 0.6 && ...
    keypoints.best_az_rmse_deg <= 0.25 && keypoints.best_el_rmse_deg <= 0.25 && ...
    keypoints.best_used_truth_for_center_rate == 0;

names = fieldnames(keypoints);
values = strings(numel(names), 1);
for idx = 1:numel(names)
    value = keypoints.(names{idx});
    if isnumeric(value) || islogical(value)
        values(idx) = string(num2str(double(value), '%.12g'));
    else
        values(idx) = string(value);
    end
end
keypoint_table = table(string(names), values, 'VariableNames', {'keypoint','value'});
end

function plot_paths = plot_stage2_results_local(summary_table, result_dir)
plot_paths = {};
fig = figure('Visible', 'off');
methods = categorical(cellstr(summary_table.method));
subplot(1, 2, 1);
bar(methods, summary_table.within_pm02deg_rate);
ylim([0, 1]);
ylabel('within +/-0.2 deg rate');
grid on;
subplot(1, 2, 2);
bar(methods, [summary_table.az_rmse_deg, summary_table.el_rmse_deg]);
ylabel('RMSE (deg)');
legend({'az','el'}, 'Location', 'best');
grid on;
plot_path = fullfile(result_dir, 'frontend_coarse_angle_summary.png');
saveas(fig, plot_path);
close(fig);
plot_paths{end + 1} = plot_path;
end

function write_text_local(path_now, text_now)
fid = fopen(path_now, 'w');
if fid < 0
    error('run_stage2_synthetic_frontend_coarse_angle:WriteFailed', ...
        'Could not open file: %s', path_now);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text_now);
clear cleanup;
end
