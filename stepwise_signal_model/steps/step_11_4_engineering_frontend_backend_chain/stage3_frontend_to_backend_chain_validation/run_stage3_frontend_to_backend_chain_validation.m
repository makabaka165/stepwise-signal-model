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
step11_3_dir = fullfile(project_dir, 'steps', 'step_11_3_beamspace_ml_search_acceleration');
step11_3_common_dir = fullfile(step11_3_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_4_stage3_frontend_to_backend_chain_validation');

addpath(common_dir);
addpath(step11_1_common_dir);
addpath(step11_2_common_dir);
addpath(step11_3_common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.4 Stage3 frontend-to-backend chain starts');
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
reg = 1e-10;

[W, w_info] = build_recommended_w_from_step11_2(step11_2_dir, cfg, arrInfo, ...
    'B', 7, 'Criterion', 'combined', 'PhaseFactor', phase_factor, ...
    'PhaseSign', phase_sign, 'Reg', reg);
[frontend_beam_pool, pool_info] = build_frontend_beam_pool_from_existing_layout(step11_2_dir, cfg, arrInfo, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);

frontend_method = 'centroid_top9';
scenarios = build_stage_scenarios_local();
Metkl = 5;
L = 64;
base_seed = 20260624;
az_center_true = cfg.beam.azSectorCenter;
el_center_nominal = cfg.beam.elSectorCenter;
el_center_offset = 0.31;

total_rows = height(scenarios) * Metkl * 2;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;
sample_debug = struct();
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
        coarse_est = estimate_coarse_angle_from_frontend_beams(scan_out, frontend_method);
        truth_center = [mean(truth.az_pair_deg), mean(truth.el_pair_deg)];

        frontend_out_syn = make_frontend_out_struct( ...
            'CoarseAzDeg', coarse_est.coarse_az_deg, ...
            'CoarseElDeg', coarse_est.coarse_el_deg, ...
            'SearchWindow', struct('az_half_width_deg', 1.5, 'el_half_width_deg', 1.2), ...
            'BeamEnergy', scan_out.beam_energy_norm_grid, ...
            'ClusterIndicator', cluster_indicator, ...
            'Method', frontend_method, ...
            'Quality', struct('selected_beam_count', coarse_est.selected_beam_count), ...
            'TruthForMetrics', truth);
        frontend_out_oracle = make_frontend_out_struct( ...
            'CoarseAzDeg', truth_center(1), ...
            'CoarseElDeg', truth_center(2), ...
            'SearchWindow', struct('az_half_width_deg', 1.5, 'el_half_width_deg', 1.2), ...
            'BeamEnergy', scan_out.beam_energy_norm_grid, ...
            'ClusterIndicator', cluster_indicator, ...
            'Method', 'oracle_center_for_backend_comparison_only', ...
            'Quality', struct('selected_beam_count', NaN), ...
            'TruthForMetrics', truth);

        [row_idx, trial_rows, sample_debug] = run_one_backend_local(row_idx, trial_rows, sample_debug, ...
            'synthetic_frontend', frontend_out_syn, Y, W, x, y, z, lambda, truth, truth_center, ...
            scenario, iScenario, trial_id, seed_now, true_orientation, phase_factor, phase_sign, reg);
        [row_idx, trial_rows, sample_debug] = run_one_backend_local(row_idx, trial_rows, sample_debug, ...
            'oracle_center', frontend_out_oracle, Y, W, x, y, z, lambda, truth, truth_center, ...
            scenario, iScenario, trial_id, seed_now, true_orientation, phase_factor, phase_sign, reg);
    end
end
elapsed_sec = toc;
if row_idx ~= total_rows
    error('run_stage3_frontend_to_backend_chain_validation:RowCountMismatch', ...
        'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table);
[keypoint_table, keypoints] = build_keypoints_local(summary_table);
plot_paths = plot_stage3_results_local(summary_table, result_dir);

trial_csv = fullfile(result_dir, 'step11_4_stage3_trial.csv');
summary_csv = fullfile(result_dir, 'step11_4_stage3_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_4_stage3_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_4_stage3_result.mat');
log_path = fullfile(result_dir, 'step11_4_stage3.log');
readme_path = fullfile(result_dir, 'README.md');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
params = struct('Metkl', Metkl, 'L', L, 'base_seed', base_seed, ...
    'frontend_method', frontend_method, 'phase_factor', phase_factor, 'phase_sign', phase_sign);
save(mat_path, 'params', 'W', 'w_info', 'frontend_beam_pool', 'pool_info', ...
    'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'sample_debug', 'plot_paths');

log_lines = append_log_local(log_lines, 'Evaluation finished: rows=%d, elapsed=%.2f sec', height(trial_table), elapsed_sec);
log_lines = append_log_local(log_lines, 'oracle_success_rate = %.12g', keypoints.oracle_success_rate);
log_lines = append_log_local(log_lines, 'synthetic_success_rate = %.12g', keypoints.synthetic_success_rate);
log_lines = append_log_local(log_lines, 'synthetic_to_oracle_success_ratio = %.12g', keypoints.synthetic_to_oracle_success_ratio);
log_lines = append_log_local(log_lines, 'synthetic_topK_miss_rate = %.12g', keypoints.synthetic_topK_miss_rate);
log_lines = append_log_local(log_lines, 'synthetic_boundary_hit_rate = %.12g', keypoints.synthetic_boundary_hit_rate);
log_lines = append_log_local(log_lines, 'chain_validation_pass_flag = %d', keypoints.chain_validation_pass_flag);
log_lines = append_log_local(log_lines, 'failure_reason = %s', keypoints.failure_reason);
write_text_local(log_path, sprintf('%s\n', log_lines{:}));

status_lines = { ...
    '# Stage3 Frontend-to-Backend Chain Status', ...
    '', ...
    sprintf('- oracle_success_rate = %.6g', keypoints.oracle_success_rate), ...
    sprintf('- synthetic_success_rate = %.6g', keypoints.synthetic_success_rate), ...
    sprintf('- synthetic_to_oracle_success_ratio = %.6g', keypoints.synthetic_to_oracle_success_ratio), ...
    sprintf('- synthetic_topK_miss_rate = %.6g', keypoints.synthetic_topK_miss_rate), ...
    sprintf('- synthetic_boundary_hit_rate = %.6g', keypoints.synthetic_boundary_hit_rate), ...
    sprintf('- chain_validation_pass_flag = %d', keypoints.chain_validation_pass_flag), ...
    sprintf('- failure_reason = %s', keypoints.failure_reason), ...
    '', ...
    'Oracle center is used only as a backend comparison baseline.'};
write_text_local(readme_path, sprintf('%s\n', status_lines{:}));
fprintf('Stage3 frontend-to-backend chain finished. Pass flag=%d. Results: %s\n', ...
    keypoints.chain_validation_pass_flag, result_dir);

function [row_idx, trial_rows, sample_debug] = run_one_backend_local(row_idx, trial_rows, sample_debug, ...
    backend_mode, frontend_out, Y, W, x, y, z, lambda, truth, truth_center, scenario, ...
    scenario_id, trial_id, seed_now, true_orientation, phase_factor, phase_sign, reg)
backend_cfg = build_step11_backend_config_from_frontend(frontend_out, ...
    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
backend_in = make_backend_in_from_frontend_out(frontend_out, Y, W, 'BackendCfg', backend_cfg);
[est, debug] = run_step11_pair2d_backend_from_interface(backend_in, x, y, z, lambda);
metrics = evaluate_frontend_backend_chain_metrics(est, debug, truth, backend_in);
if isempty(fieldnames(sample_debug))
    sample_debug = debug;
end
row_idx = row_idx + 1;
trial_rows(row_idx) = make_trial_row_local(row_idx, backend_mode, frontend_out, truth_center, ...
    est, metrics, scenario, scenario_id, trial_id, seed_now, true_orientation);
end

function row = make_trial_row_template_local()
row = struct();
row.row_id = NaN;
row.backend_mode = "";
row.scenario_id = NaN;
row.scenario_name = "";
row.trial_id = NaN;
row.seed = NaN;
row.frontend_method = "";
row.rho = NaN;
row.phase_deg = NaN;
row.beta = NaN;
row.snr_db = NaN;
row.az_sep_deg = NaN;
row.el_sep_deg = NaN;
row.true_orientation = NaN;
row.frontend_coarse_az_error_deg = NaN;
row.frontend_coarse_el_error_deg = NaN;
row.joint_pair_tol_success = false;
row.az_rmse_deg = NaN;
row.el_rmse_deg = NaN;
row.az_center_error_deg = NaN;
row.el_center_error_deg = NaN;
row.boundary_hit = false;
row.topK_miss = true;
row.num_pairs = NaN;
row.coarse_num_pairs = NaN;
row.refine_num_pairs = NaN;
row.max_score = NaN;
row.est_az1_deg = NaN;
row.est_az2_deg = NaN;
row.est_el1_deg = NaN;
row.est_el2_deg = NaN;
end

function row = make_trial_row_local(row_id, backend_mode, frontend_out, truth_center, ...
    est, metrics, scenario, scenario_id, trial_id, seed_now, true_orientation)
row = make_trial_row_template_local();
row.row_id = row_id;
row.backend_mode = string(backend_mode);
row.scenario_id = scenario_id;
row.scenario_name = string(scenario.scenario_name);
row.trial_id = trial_id;
row.seed = seed_now;
row.frontend_method = string(frontend_out.method);
row.rho = scenario.rho;
row.phase_deg = scenario.phase_deg;
row.beta = scenario.beta;
row.snr_db = scenario.snr_db;
row.az_sep_deg = scenario.az_sep_deg;
row.el_sep_deg = scenario.el_sep_deg;
row.true_orientation = true_orientation;
row.frontend_coarse_az_error_deg = frontend_out.coarse_az_deg - truth_center(1);
row.frontend_coarse_el_error_deg = frontend_out.coarse_el_deg - truth_center(2);
row.joint_pair_tol_success = metrics.joint_pair_tol_success;
row.az_rmse_deg = metrics.az_rmse_deg;
row.el_rmse_deg = metrics.el_rmse_deg;
row.az_center_error_deg = metrics.az_center_error_deg;
row.el_center_error_deg = metrics.el_center_error_deg;
row.boundary_hit = metrics.boundary_hit;
row.topK_miss = metrics.topK_miss;
row.num_pairs = metrics.num_pairs;
row.coarse_num_pairs = metrics.coarse_num_pairs;
row.refine_num_pairs = metrics.refine_num_pairs;
row.max_score = metrics.max_score;
row.est_az1_deg = est.az_hat(1);
row.est_az2_deg = est.az_hat(2);
row.est_el1_deg = est.el_hat(1);
row.est_el2_deg = est.el_hat(2);
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

function summary_table = build_summary_table_local(trial_table)
modes = unique(trial_table.backend_mode, 'stable');
rows = repmat(make_summary_row_template_local(), numel(modes), 1);
for iMode = 1:numel(modes)
    mode = modes(iMode);
    mask = trial_table.backend_mode == mode;
    rows(iMode).backend_mode = mode;
    rows(iMode).num_trials = sum(mask);
    rows(iMode).success_rate = mean(trial_table.joint_pair_tol_success(mask));
    rows(iMode).az_rmse_mean_deg = mean(trial_table.az_rmse_deg(mask), 'omitnan');
    rows(iMode).el_rmse_mean_deg = mean(trial_table.el_rmse_deg(mask), 'omitnan');
    rows(iMode).boundary_hit_rate = mean(trial_table.boundary_hit(mask));
    rows(iMode).topK_miss_rate = mean(trial_table.topK_miss(mask));
    rows(iMode).mean_num_pairs = mean(trial_table.num_pairs(mask), 'omitnan');
    rows(iMode).mean_frontend_abs_az_error_deg = mean(abs(trial_table.frontend_coarse_az_error_deg(mask)), 'omitnan');
    rows(iMode).mean_frontend_abs_el_error_deg = mean(abs(trial_table.frontend_coarse_el_error_deg(mask)), 'omitnan');
end
summary_table = struct2table(rows);
end

function row = make_summary_row_template_local()
row = struct();
row.backend_mode = "";
row.num_trials = NaN;
row.success_rate = NaN;
row.az_rmse_mean_deg = NaN;
row.el_rmse_mean_deg = NaN;
row.boundary_hit_rate = NaN;
row.topK_miss_rate = NaN;
row.mean_num_pairs = NaN;
row.mean_frontend_abs_az_error_deg = NaN;
row.mean_frontend_abs_el_error_deg = NaN;
end

function [keypoint_table, keypoints] = build_keypoints_local(summary_table)
syn = summary_table(summary_table.backend_mode == "synthetic_frontend", :);
oracle = summary_table(summary_table.backend_mode == "oracle_center", :);
if height(syn) ~= 1 || height(oracle) ~= 1
    error('run_stage3_frontend_to_backend_chain_validation:MissingSummaryMode', ...
        'Synthetic and oracle summary rows are required.');
end
keypoints = struct();
keypoints.oracle_success_rate = oracle.success_rate;
keypoints.synthetic_success_rate = syn.success_rate;
keypoints.synthetic_to_oracle_success_ratio = syn.success_rate / max(oracle.success_rate, eps);
keypoints.synthetic_topK_miss_rate = syn.topK_miss_rate;
keypoints.synthetic_boundary_hit_rate = syn.boundary_hit_rate;
keypoints.synthetic_mean_frontend_abs_az_error_deg = syn.mean_frontend_abs_az_error_deg;
keypoints.synthetic_mean_frontend_abs_el_error_deg = syn.mean_frontend_abs_el_error_deg;
keypoints.chain_validation_pass_flag = keypoints.synthetic_to_oracle_success_ratio >= 0.85 && ...
    keypoints.synthetic_topK_miss_rate <= 0.1 && keypoints.synthetic_boundary_hit_rate <= 0.2;
keypoints.failure_reason = make_failure_reason_local(keypoints);

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

function reason = make_failure_reason_local(keypoints)
if keypoints.chain_validation_pass_flag
    reason = 'none';
elseif keypoints.oracle_success_rate < 0.5
    reason = 'oracle_backend_low_success';
elseif keypoints.synthetic_to_oracle_success_ratio < 0.85
    reason = 'synthetic_frontend_prior_reduces_backend_success';
elseif keypoints.synthetic_topK_miss_rate > 0.1
    reason = 'synthetic_frontend_prior_topK_truth_proxy_miss_high';
elseif keypoints.synthetic_boundary_hit_rate > 0.2
    reason = 'synthetic_frontend_prior_boundary_hit_high';
else
    reason = 'unknown_chain_gate_failure';
end
end

function plot_paths = plot_stage3_results_local(summary_table, result_dir)
plot_paths = {};
fig = figure('Visible', 'off');
modes = categorical(cellstr(summary_table.backend_mode));
subplot(1, 2, 1);
bar(modes, summary_table.success_rate);
ylim([0, 1]);
ylabel('success rate');
grid on;
subplot(1, 2, 2);
bar(modes, [summary_table.topK_miss_rate, summary_table.boundary_hit_rate]);
ylim([0, 1]);
ylabel('rate');
legend({'topK miss','boundary hit'}, 'Location', 'best');
grid on;
plot_path = fullfile(result_dir, 'frontend_backend_chain_summary.png');
saveas(fig, plot_path);
close(fig);
plot_paths{end + 1} = plot_path;
end

function write_text_local(path_now, text_now)
fid = fopen(path_now, 'w');
if fid < 0
    error('run_stage3_frontend_to_backend_chain_validation:WriteFailed', ...
        'Could not open file: %s', path_now);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text_now);
clear cleanup;
end
