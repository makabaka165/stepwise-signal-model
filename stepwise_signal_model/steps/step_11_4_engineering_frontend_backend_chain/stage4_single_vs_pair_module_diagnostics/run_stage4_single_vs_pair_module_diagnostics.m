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
result_dir = fullfile(step_dir, 'results_step11_4_stage4_single_vs_pair_module_diagnostics');

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
log_lines = append_log_local(log_lines, 'Step11.4 Stage4 single-vs-pair module diagnostics starts');
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
Metkl = 5;
L = 64;
base_seed = 20260624;
az_center_true = cfg.beam.azSectorCenter;
el_center_nominal = cfg.beam.elSectorCenter;
el_center_offset = 0.31;
single_scenarios = build_single_scenarios_local(az_center_true, el_center_nominal + el_center_offset);
pair_scenarios = build_pair_scenarios_local();

total_rows = height(single_scenarios) * Metkl + height(pair_scenarios) * Metkl;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;
tic;

for iScenario = 1:height(single_scenarios)
    scenario = table_row_to_struct_local(single_scenarios(iScenario, :));
    for trial_id = 1:Metkl
        seed_now = base_seed + 20000 + 1000 * iScenario + trial_id;
        [Y, truth] = make_single_target_snapshots_local(x, y, z, scenario.az_deg, scenario.el_deg, ...
            lambda, L, scenario.snr_db, 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Seed', seed_now);
        [frontend_out, truth_center] = make_frontend_from_y_local(Y, frontend_beam_pool, frontend_method, truth);
        backend_cfg = build_step11_backend_config_from_frontend(frontend_out, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
        backend_in = make_backend_in_from_frontend_out(frontend_out, Y, W, 'BackendCfg', backend_cfg);
        [est, debug] = run_step11_pair2d_backend_from_interface(backend_in, x, y, z, lambda);
        row_idx = row_idx + 1;
        trial_rows(row_idx) = make_single_trial_row_local(row_idx, scenario, iScenario, trial_id, seed_now, ...
            frontend_out, truth_center, est, debug);
    end
end

for iScenario = 1:height(pair_scenarios)
    scenario = table_row_to_struct_local(pair_scenarios(iScenario, :));
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
        seed_now = base_seed + 30000 + 1000 * iScenario + trial_id;
        [Y, truth] = make_cyl_pair2d_correlated_snapshots(x, y, z, az_true, el_true, ...
            lambda, L, scenario.snr_db, 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, ...
            'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
            'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
        [frontend_out, truth_center] = make_frontend_from_y_local(Y, frontend_beam_pool, frontend_method, truth);
        backend_cfg = build_step11_backend_config_from_frontend(frontend_out, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
        backend_in = make_backend_in_from_frontend_out(frontend_out, Y, W, 'BackendCfg', backend_cfg);
        [est, debug] = run_step11_pair2d_backend_from_interface(backend_in, x, y, z, lambda);
        metrics = evaluate_frontend_backend_chain_metrics(est, debug, truth, backend_in);
        row_idx = row_idx + 1;
        trial_rows(row_idx) = make_pair_trial_row_local(row_idx, scenario, iScenario, trial_id, seed_now, ...
            true_orientation, frontend_out, truth_center, est, debug, metrics);
    end
end

elapsed_sec = toc;
if row_idx ~= total_rows
    error('run_stage4_single_vs_pair_module_diagnostics:RowCountMismatch', ...
        'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table);
[keypoint_table, keypoints] = build_keypoints_local(summary_table);
plot_paths = plot_stage4_results_local(summary_table, result_dir);

trial_csv = fullfile(result_dir, 'step11_4_stage4_trial.csv');
summary_csv = fullfile(result_dir, 'step11_4_stage4_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_4_stage4_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_4_stage4_result.mat');
log_path = fullfile(result_dir, 'step11_4_stage4.log');
readme_path = fullfile(result_dir, 'README.md');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
params = struct('Metkl', Metkl, 'L', L, 'base_seed', base_seed, ...
    'frontend_method', frontend_method, 'phase_factor', phase_factor, 'phase_sign', phase_sign);
save(mat_path, 'params', 'W', 'w_info', 'frontend_beam_pool', 'pool_info', ...
    'single_scenarios', 'pair_scenarios', 'trial_table', 'summary_table', ...
    'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Evaluation finished: rows=%d, elapsed=%.2f sec', height(trial_table), elapsed_sec);
log_lines = append_log_local(log_lines, 'single_target_false_split_rate = %.12g', keypoints.single_target_false_split_rate);
log_lines = append_log_local(log_lines, 'pair_target_success_rate = %.12g', keypoints.pair_target_success_rate);
log_lines = append_log_local(log_lines, 'stage4_module_diagnostics_pass_flag = %d', keypoints.stage4_module_diagnostics_pass_flag);
log_lines = append_log_local(log_lines, 'recommended_trigger_policy_text = %s', keypoints.recommended_trigger_policy_text);
write_text_local(log_path, sprintf('%s\n', log_lines{:}));

status_lines = { ...
    '# Stage4 Single-vs-Pair Module Diagnostics Status', ...
    '', ...
    sprintf('- single_target_false_split_rate = %.6g', keypoints.single_target_false_split_rate), ...
    sprintf('- pair_target_success_rate = %.6g', keypoints.pair_target_success_rate), ...
    sprintf('- stage4_module_diagnostics_pass_flag = %d', keypoints.stage4_module_diagnostics_pass_flag), ...
    sprintf('- recommended_trigger_policy_text = %s', keypoints.recommended_trigger_policy_text), ...
    '', ...
    'This is a trigger-policy diagnostic, not a complete automatic model-selection solution.'};
write_text_local(readme_path, sprintf('%s\n', status_lines{:}));
fprintf('Stage4 single-vs-pair diagnostics finished. Pass flag=%d. Results: %s\n', ...
    keypoints.stage4_module_diagnostics_pass_flag, result_dir);

function [frontend_out, truth_center] = make_frontend_from_y_local(Y, frontend_beam_pool, frontend_method, truth)
scan_out = run_synthetic_frontend_beam_scan(Y, frontend_beam_pool);
cluster_indicator = compute_frontend_cluster_indicators(scan_out);
coarse_est = estimate_coarse_angle_from_frontend_beams(scan_out, frontend_method);
truth_center = [mean(truth.az_pair_deg), mean(truth.el_pair_deg)];
frontend_out = make_frontend_out_struct( ...
    'CoarseAzDeg', coarse_est.coarse_az_deg, ...
    'CoarseElDeg', coarse_est.coarse_el_deg, ...
    'SearchWindow', struct('az_half_width_deg', 1.5, 'el_half_width_deg', 1.2), ...
    'BeamEnergy', scan_out.beam_energy_norm_grid, ...
    'ClusterIndicator', cluster_indicator, ...
    'Method', frontend_method, ...
    'Quality', struct('selected_beam_count', coarse_est.selected_beam_count), ...
    'TruthForMetrics', truth);
end

function [Y, truth] = make_single_target_snapshots_local(x, y, z, az_deg, el_deg, lambda, L, snr_db, varargin)
opts = parse_single_opts_local(varargin{:});
if ~isempty(opts.seed)
    rng(opts.seed, 'twister');
end
a = build_cyl_steering_vec(x, y, z, az_deg, el_deg, lambda, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
s = exp(1j * 2*pi * rand(1, L));
s = s / sqrt(mean(abs(s).^2));
Y_clean = a * s;
noise_power = mean(abs(Y_clean(:)).^2) / 10^(snr_db/10);
noise = sqrt(noise_power/2) * (randn(size(Y_clean)) + 1j * randn(size(Y_clean)));
Y = Y_clean + noise;
truth = struct();
truth.az_pair_deg = [az_deg, az_deg];
truth.el_pair_deg = [el_deg, el_deg];
truth.single_target = true;
truth.snr_db = snr_db;
truth.noise_power = noise_power;
end

function opts = parse_single_opts_local(varargin)
opts = struct('phase_factor', 1, 'phase_sign', 1, 'seed', []);
if isempty(varargin)
    return;
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'seed'
            opts.seed = value;
        otherwise
            error('run_stage4_single_vs_pair_module_diagnostics:UnknownSingleOption', ...
                'Unknown option: %s', name);
    end
end
end

function scenarios = build_single_scenarios_local(az_center, el_center)
rows = [ ...
    make_single_scenario_local('single_center_high_snr', az_center, el_center, 30); ...
    make_single_scenario_local('single_az_offset_high_snr', az_center + 0.35, el_center, 30); ...
    make_single_scenario_local('single_low_snr', az_center, el_center + 0.2, 20)];
scenarios = struct2table(rows);
end

function row = make_single_scenario_local(name, az_deg, el_deg, snr_db)
row = struct('scenario_name', name, 'az_deg', az_deg, 'el_deg', el_deg, 'snr_db', snr_db);
end

function scenarios = build_pair_scenarios_local()
rows = [ ...
    make_pair_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30); ...
    make_pair_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30); ...
    make_pair_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30); ...
    make_pair_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30); ...
    make_pair_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20)];
scenarios = struct2table(rows);
end

function row = make_pair_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end

function row = make_trial_row_template_local()
row = struct();
row.row_id = NaN;
row.case_type = "";
row.scenario_id = NaN;
row.scenario_name = "";
row.trial_id = NaN;
row.seed = NaN;
row.snr_db = NaN;
row.frontend_method = "";
row.frontend_coarse_az_error_deg = NaN;
row.frontend_coarse_el_error_deg = NaN;
row.true_orientation = NaN;
row.pair_target_success = false;
row.single_false_split = false;
row.estimated_az_sep_deg = NaN;
row.estimated_el_sep_deg = NaN;
row.estimated_pair_sep_norm_deg = NaN;
row.boundary_hit = false;
row.topK_miss = false;
row.num_pairs = NaN;
row.est_az1_deg = NaN;
row.est_az2_deg = NaN;
row.est_el1_deg = NaN;
row.est_el2_deg = NaN;
end

function row = make_single_trial_row_local(row_id, scenario, scenario_id, trial_id, seed_now, ...
    frontend_out, truth_center, est, debug)
row = make_trial_row_template_local();
row.row_id = row_id;
row.case_type = "single_forced_pair2d";
row.scenario_id = scenario_id;
row.scenario_name = string(scenario.scenario_name);
row.trial_id = trial_id;
row.seed = seed_now;
row.snr_db = scenario.snr_db;
row.frontend_method = string(frontend_out.method);
row.frontend_coarse_az_error_deg = frontend_out.coarse_az_deg - truth_center(1);
row.frontend_coarse_el_error_deg = frontend_out.coarse_el_deg - truth_center(2);
row.true_orientation = 0;
[az_sep, el_sep, sep_norm] = estimate_pair_separation_local(est);
row.single_false_split = az_sep > 0.15 || el_sep > 0.15 || sep_norm > 0.20;
row.estimated_az_sep_deg = az_sep;
row.estimated_el_sep_deg = el_sep;
row.estimated_pair_sep_norm_deg = sep_norm;
row.num_pairs = debug.num_pairs;
row.est_az1_deg = est.az_hat(1);
row.est_az2_deg = est.az_hat(2);
row.est_el1_deg = est.el_hat(1);
row.est_el2_deg = est.el_hat(2);
end

function row = make_pair_trial_row_local(row_id, scenario, scenario_id, trial_id, seed_now, ...
    true_orientation, frontend_out, truth_center, est, debug, metrics)
row = make_trial_row_template_local();
row.row_id = row_id;
row.case_type = "pair_enhanced_mode";
row.scenario_id = scenario_id;
row.scenario_name = string(scenario.scenario_name);
row.trial_id = trial_id;
row.seed = seed_now;
row.snr_db = scenario.snr_db;
row.frontend_method = string(frontend_out.method);
row.frontend_coarse_az_error_deg = frontend_out.coarse_az_deg - truth_center(1);
row.frontend_coarse_el_error_deg = frontend_out.coarse_el_deg - truth_center(2);
row.true_orientation = true_orientation;
row.pair_target_success = metrics.joint_pair_tol_success;
[az_sep, el_sep, sep_norm] = estimate_pair_separation_local(est);
row.estimated_az_sep_deg = az_sep;
row.estimated_el_sep_deg = el_sep;
row.estimated_pair_sep_norm_deg = sep_norm;
row.boundary_hit = metrics.boundary_hit;
row.topK_miss = metrics.topK_miss;
row.num_pairs = debug.num_pairs;
row.est_az1_deg = est.az_hat(1);
row.est_az2_deg = est.az_hat(2);
row.est_el1_deg = est.el_hat(1);
row.est_el2_deg = est.el_hat(2);
end

function [az_sep, el_sep, sep_norm] = estimate_pair_separation_local(est)
[az_sorted, order] = sort(est.az_hat(:).');
el_sorted = est.el_hat(order);
az_sep = abs(diff(az_sorted));
el_sep = abs(diff(el_sorted));
sep_norm = sqrt(az_sep.^2 + el_sep.^2);
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
case_types = unique(trial_table.case_type, 'stable');
rows = repmat(make_summary_row_template_local(), numel(case_types), 1);
for iCase = 1:numel(case_types)
    case_type = case_types(iCase);
    mask = trial_table.case_type == case_type;
    rows(iCase).case_type = case_type;
    rows(iCase).num_trials = sum(mask);
    rows(iCase).single_target_false_split_rate = mean(trial_table.single_false_split(mask));
    rows(iCase).pair_target_success_rate = mean(trial_table.pair_target_success(mask));
    rows(iCase).mean_estimated_pair_sep_norm_deg = mean(trial_table.estimated_pair_sep_norm_deg(mask), 'omitnan');
    rows(iCase).boundary_hit_rate = mean(trial_table.boundary_hit(mask));
    rows(iCase).topK_miss_rate = mean(trial_table.topK_miss(mask));
    rows(iCase).mean_num_pairs = mean(trial_table.num_pairs(mask), 'omitnan');
end
summary_table = struct2table(rows);
end

function row = make_summary_row_template_local()
row = struct();
row.case_type = "";
row.num_trials = NaN;
row.single_target_false_split_rate = NaN;
row.pair_target_success_rate = NaN;
row.mean_estimated_pair_sep_norm_deg = NaN;
row.boundary_hit_rate = NaN;
row.topK_miss_rate = NaN;
row.mean_num_pairs = NaN;
end

function [keypoint_table, keypoints] = build_keypoints_local(summary_table)
single_row = summary_table(summary_table.case_type == "single_forced_pair2d", :);
pair_row = summary_table(summary_table.case_type == "pair_enhanced_mode", :);
if height(single_row) ~= 1 || height(pair_row) ~= 1
    error('run_stage4_single_vs_pair_module_diagnostics:MissingCaseType', ...
        'Single and pair summary rows are required.');
end
keypoints = struct();
keypoints.single_target_false_split_rate = single_row.single_target_false_split_rate;
keypoints.pair_target_success_rate = pair_row.pair_target_success_rate;
keypoints.pair_boundary_hit_rate = pair_row.boundary_hit_rate;
keypoints.pair_topK_miss_rate = pair_row.topK_miss_rate;
keypoints.stage4_module_diagnostics_pass_flag = keypoints.single_target_false_split_rate >= 0.5 && ...
    keypoints.pair_target_success_rate >= 0.8;
keypoints.recommended_trigger_policy_text = ['Default ordinary single-target path should keep frontend coarse angle; ' ...
    'call pair2d only for unresolved-cluster indicators such as broad beam spread, ambiguous local peak structure, ' ...
    'or downstream need for local pair enhancement.'];

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

function plot_paths = plot_stage4_results_local(summary_table, result_dir)
plot_paths = {};
fig = figure('Visible', 'off');
case_types = categorical(cellstr(summary_table.case_type));
bar(case_types, [summary_table.single_target_false_split_rate, summary_table.pair_target_success_rate]);
ylim([0, 1]);
ylabel('rate');
legend({'single false split','pair success'}, 'Location', 'best');
grid on;
plot_path = fullfile(result_dir, 'single_vs_pair_diagnostics_summary.png');
saveas(fig, plot_path);
close(fig);
plot_paths{end + 1} = plot_path;
end

function write_text_local(path_now, text_now)
fid = fopen(path_now, 'w');
if fid < 0
    error('run_stage4_single_vs_pair_module_diagnostics:WriteFailed', ...
        'Could not open file: %s', path_now);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text_now);
clear cleanup;
end
