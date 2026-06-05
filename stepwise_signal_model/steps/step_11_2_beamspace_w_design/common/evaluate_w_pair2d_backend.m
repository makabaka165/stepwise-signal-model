function [trial_table, summary_table] = evaluate_w_pair2d_backend(W_cases, scenario_table, cfg_eval)
%EVALUATE_W_PAIR2D_BACKEND Run fixed Step11.1 pair2d backend for W cases.

if nargin < 3
    error('evaluate_w_pair2d_backend:NotEnoughInputs', 'W_cases, scenario_table, and cfg_eval are required.');
end
if ~isfield(cfg_eval, 'el_center_offset')
    cfg_eval.el_center_offset = 0;
end
required_cfg = {'x','y','z','lambda','phase_factor','phase_sign','az_center_true','el_center_nominal', ...
    'L','Metkl','az_search_half_width','el_search_half_width','az_grid_step_deg','el_grid_step_deg', ...
    'el_sep_index_list','search_orientations','az_tol_deg','el_tol_deg','el_sep_tol_deg','reg','base_seed'};
for idx = 1:numel(required_cfg)
    if ~isfield(cfg_eval, required_cfg{idx})
        error('evaluate_w_pair2d_backend:MissingCfgField', 'cfg_eval.%s is required.', required_cfg{idx});
    end
end

total_rows = numel(W_cases) * height(scenario_table) * cfg_eval.Metkl;
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

for iCase = 1:numel(W_cases)
    W_case = W_cases(iCase);
    W = W_case.W;
    az_bounds = cfg_eval.az_center_true + [-cfg_eval.az_search_half_width, cfg_eval.az_search_half_width];
    el_bounds = cfg_eval.el_center_nominal + [-cfg_eval.el_search_half_width, cfg_eval.el_search_half_width];
    az_grid = az_bounds(1):cfg_eval.az_grid_step_deg:az_bounds(2);
    el_grid = el_bounds(1):cfg_eval.el_grid_step_deg:el_bounds(2);
    grid = precompute_beamspace_azel_grid(W, cfg_eval.x, cfg_eval.y, cfg_eval.z, az_grid, el_grid, cfg_eval.lambda, ...
        'PhaseFactor', cfg_eval.phase_factor, 'PhaseSign', cfg_eval.phase_sign);

    for iScenario = 1:height(scenario_table)
        scenario = table_row_to_struct_local(scenario_table(iScenario, :));
        az_true = cfg_eval.az_center_true + [-scenario.az_sep_deg/2, scenario.az_sep_deg/2];
        el_center_true = cfg_eval.el_center_nominal + cfg_eval.el_center_offset;
        el_true = el_center_true + [-scenario.el_sep_deg/2, scenario.el_sep_deg/2];

        for trial_id = 1:cfg_eval.Metkl
            seed_now = cfg_eval.base_seed + 100000*iCase + 1000*iScenario + trial_id;
            [Y, truth] = make_cyl_pair2d_correlated_snapshots(cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                az_true, el_true, cfg_eval.lambda, cfg_eval.L, scenario.snr_db, ...
                'PhaseFactor', cfg_eval.phase_factor, 'PhaseSign', cfg_eval.phase_sign, ...
                'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
                'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
            Z = W' * Y;

            search_cfg = struct();
            search_cfg.whitening_mode = 'white';
            search_cfg.reg = cfg_eval.reg;
            search_cfg.el_sep_index_list = cfg_eval.el_sep_index_list;
            search_cfg.search_orientations = cfg_eval.search_orientations;
            search_cfg.keep_score_cube = false;

            [est, ~, debug] = search_pair_grid_el_separation_precomputed(Z, W, grid, search_cfg);
            metrics = eval_el_separation_pair_metrics(est, az_true, el_true, az_bounds, el_bounds, ...
                cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);

            A_truth = build_cyl_pair_manifold_el_separated(cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                az_true, el_true, cfg_eval.lambda, 'PhaseFactor', cfg_eval.phase_factor, ...
                'PhaseSign', cfg_eval.phase_sign);
            G_truth = W' * A_truth;
            [~, G_truth_use] = apply_beamspace_whitening(Z, G_truth, W, 'white', 'eps_reg', cfg_eval.reg);
            truth_corr = abs(G_truth_use(:, 1)' * G_truth_use(:, 2)) / ...
                max(norm(G_truth_use(:, 1)) * norm(G_truth_use(:, 2)), eps);

            row_idx = row_idx + 1;
            trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, seed_now, W_case, scenario, ...
                truth, est, az_true, el_true, metrics, debug, truth_corr, cfg_eval, az_bounds, el_bounds);
        end
    end
end

if row_idx ~= total_rows
    error('evaluate_w_pair2d_backend:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table);
end

function row = make_trial_row_template_local()
row = struct();
fields = {'trial_global_id','trial_id','seed','method_name','method_type','B','beam_count','scenario_name', ...
    'rho','phase_deg','beta','az_sep_deg','el_sep_deg','snr_db','source_corr_empirical', ...
    'az_hat_1','az_hat_2','el_hat_1','el_hat_2','az_true_1','az_true_2','el_true_1','el_true_2', ...
    'raw_success','az_tol_success','el_pair_tol_success','joint_pair_tol_success','az_rmse_deg', ...
    'el_rmse_deg','az_center_error_deg','az_sep_error_deg','el_center_error_deg','el_sep_error_deg', ...
    'abs_el_sep_error_deg','estimated_el_sep_deg','true_el_sep_deg','false_el_split','boundary_hit', ...
    'projection_loss','mean_corr','max_corr','cond_WHW','cond_best_GHG','max_score','num_pairs', ...
    'tie_count','truth_manifold_corr','N_elem','L','phase_factor','phase_sign','az_bound_min','az_bound_max', ...
    'el_bound_min','el_bound_max'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.method_name = '';
row.method_type = '';
row.scenario_name = '';
row.raw_success = false;
row.az_tol_success = false;
row.el_pair_tol_success = false;
row.joint_pair_tol_success = false;
row.false_el_split = false;
row.boundary_hit = false;
end

function row = make_trial_row_local(trial_global_id, trial_id, seed_now, W_case, scenario, truth, est, ...
    az_true, el_true, metrics, debug, truth_corr, cfg_eval, az_bounds, el_bounds)
row = make_trial_row_template_local();
row.trial_global_id = trial_global_id;
row.trial_id = trial_id;
row.seed = seed_now;
row.method_name = W_case.name;
row.method_type = W_case.method_type;
row.B = W_case.B;
row.beam_count = size(W_case.W, 2);
row.scenario_name = scenario.scenario_name;
row.rho = scenario.rho;
row.phase_deg = scenario.phase_deg;
row.beta = scenario.beta;
row.az_sep_deg = scenario.az_sep_deg;
row.el_sep_deg = scenario.el_sep_deg;
row.snr_db = scenario.snr_db;
row.source_corr_empirical = truth.source_corr_empirical;
row.az_hat_1 = est.az_hat(1);
row.az_hat_2 = est.az_hat(2);
row.el_hat_1 = est.el_hat(1);
row.el_hat_2 = est.el_hat(2);
row.az_true_1 = az_true(1);
row.az_true_2 = az_true(2);
row.el_true_1 = el_true(1);
row.el_true_2 = el_true(2);
row.raw_success = metrics.raw_success;
row.az_tol_success = metrics.az_tol_success;
row.el_pair_tol_success = metrics.el_pair_tol_success;
row.joint_pair_tol_success = metrics.joint_pair_tol_success;
row.az_rmse_deg = metrics.az_rmse_deg;
row.el_rmse_deg = metrics.el_rmse_deg;
row.az_center_error_deg = metrics.az_center_error_deg;
row.az_sep_error_deg = metrics.az_sep_error_deg;
row.el_center_error_deg = metrics.el_center_error_deg;
row.el_sep_error_deg = metrics.el_sep_error_deg;
row.abs_el_sep_error_deg = metrics.abs_el_sep_error_deg;
row.estimated_el_sep_deg = metrics.estimated_el_sep_deg;
row.true_el_sep_deg = metrics.true_el_sep_deg;
row.false_el_split = metrics.false_el_split;
row.boundary_hit = metrics.boundary_hit;
row.projection_loss = W_case.projection_loss;
row.mean_corr = W_case.mean_corr;
row.max_corr = W_case.max_corr;
row.cond_WHW = W_case.cond_WHW;
row.cond_best_GHG = debug.cond_best_GHG;
row.max_score = debug.max_score;
row.num_pairs = debug.num_pairs;
row.tie_count = debug.tie_count;
row.truth_manifold_corr = truth_corr;
row.N_elem = numel(cfg_eval.x);
row.L = cfg_eval.L;
row.phase_factor = cfg_eval.phase_factor;
row.phase_sign = cfg_eval.phase_sign;
row.az_bound_min = az_bounds(1);
row.az_bound_max = az_bounds(2);
row.el_bound_min = el_bounds(1);
row.el_bound_max = el_bounds(2);
end

function summary_table = build_summary_table_local(trial_table)
group_fields = {'method_name','method_type','B','beam_count','scenario_name','rho','phase_deg','beta', ...
    'az_sep_deg','el_sep_deg','snr_db'};
groups = unique(trial_table(:, group_fields), 'rows');
rows = repmat(make_summary_row_template_local(), height(groups), 1);
for iGroup = 1:height(groups)
    mask = true(height(trial_table), 1);
    for iField = 1:numel(group_fields)
        field = group_fields{iField};
        mask = mask & match_value_local(trial_table.(field), groups.(field)(iGroup));
    end
    sub = trial_table(mask, :);
    rows(iGroup).method_name = char_value_local(groups.method_name(iGroup));
    rows(iGroup).method_type = char_value_local(groups.method_type(iGroup));
    rows(iGroup).B = groups.B(iGroup);
    rows(iGroup).beam_count = groups.beam_count(iGroup);
    rows(iGroup).scenario_name = char_value_local(groups.scenario_name(iGroup));
    rows(iGroup).rho = groups.rho(iGroup);
    rows(iGroup).phase_deg = groups.phase_deg(iGroup);
    rows(iGroup).beta = groups.beta(iGroup);
    rows(iGroup).az_sep_deg = groups.az_sep_deg(iGroup);
    rows(iGroup).el_sep_deg = groups.el_sep_deg(iGroup);
    rows(iGroup).snr_db = groups.snr_db(iGroup);
    rows(iGroup).raw_success_rate = mean(double(sub.raw_success));
    rows(iGroup).az_tol_success_rate = mean(double(sub.az_tol_success));
    rows(iGroup).el_pair_tol_success_rate = mean(double(sub.el_pair_tol_success));
    rows(iGroup).joint_success_rate = mean(double(sub.joint_pair_tol_success));
    rows(iGroup).az_rmse_deg = mean_omitnan_local(sub.az_rmse_deg);
    rows(iGroup).el_rmse_deg = mean_omitnan_local(sub.el_rmse_deg);
    rows(iGroup).mean_abs_el_sep_error_deg = mean_omitnan_local(sub.abs_el_sep_error_deg);
    rows(iGroup).false_el_split_rate = mean(double(sub.false_el_split));
    rows(iGroup).boundary_hit_rate = mean(double(sub.boundary_hit));
    rows(iGroup).projection_loss = mean_omitnan_local(sub.projection_loss);
    rows(iGroup).mean_corr = mean_omitnan_local(sub.mean_corr);
    rows(iGroup).max_corr = mean_omitnan_local(sub.max_corr);
    rows(iGroup).cond_WHW = mean_omitnan_local(sub.cond_WHW);
    rows(iGroup).cond_best_GHG = mean_omitnan_local(sub.cond_best_GHG);
    rows(iGroup).mean_num_pairs = mean_omitnan_local(sub.num_pairs);
    rows(iGroup).mean_truth_manifold_corr = mean_omitnan_local(sub.truth_manifold_corr);
    rows(iGroup).n_trials = height(sub);
end
summary_table = struct2table(rows);
summary_table = add_method_aggregates_local(summary_table);
end

function row = make_summary_row_template_local()
row = struct();
fields = {'method_name','method_type','B','beam_count','scenario_name','rho','phase_deg','beta','az_sep_deg', ...
    'el_sep_deg','snr_db','raw_success_rate','az_tol_success_rate','el_pair_tol_success_rate', ...
    'joint_success_rate','az_rmse_deg','el_rmse_deg','mean_abs_el_sep_error_deg','false_el_split_rate', ...
    'boundary_hit_rate','projection_loss','mean_corr','max_corr','cond_WHW','cond_best_GHG','mean_num_pairs', ...
    'mean_truth_manifold_corr','n_trials','overall_joint_success_rate','overall_az_rmse_deg', ...
    'overall_el_rmse_deg','worst_case_success'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.method_name = '';
row.method_type = '';
row.scenario_name = '';
end

function summary_table = add_method_aggregates_local(summary_table)
summary_table.overall_joint_success_rate(:) = NaN;
summary_table.overall_az_rmse_deg(:) = NaN;
summary_table.overall_el_rmse_deg(:) = NaN;
summary_table.worst_case_success(:) = NaN;
for idx = 1:height(summary_table)
    mask = string_match_local(summary_table.method_name, char_value_local(summary_table.method_name(idx))) & ...
        abs(summary_table.B - summary_table.B(idx)) < 1e-12;
    summary_table.overall_joint_success_rate(idx) = mean_omitnan_local(summary_table.joint_success_rate(mask));
    summary_table.overall_az_rmse_deg(idx) = mean_omitnan_local(summary_table.az_rmse_deg(mask));
    summary_table.overall_el_rmse_deg(idx) = mean_omitnan_local(summary_table.el_rmse_deg(mask));
    summary_table.worst_case_success(idx) = min_omitnan_local(summary_table.joint_success_rate(mask));
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
