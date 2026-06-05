function [trial_table, summary_table] = evaluate_search_acceleration_backend(W, scenarios, cfg_eval)
%EVALUATE_SEARCH_ACCELERATION_BACKEND Evaluate full/coarse/coarse-to-fine pair2d searches.

if nargin < 3
    error('evaluate_search_acceleration_backend:NotEnoughInputs', 'W, scenarios, and cfg_eval are required.');
end
cfg_eval = fill_defaults_local(cfg_eval, W);
validate_cfg_local(cfg_eval);
scenario_table = normalize_scenarios_local(scenarios);

search_methods = cfg_eval.search_methods(:).';
total_rows = height(scenario_table) * cfg_eval.Metkl * numel(search_methods);
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

center_bias = cfg_eval.center_bias(:).';
az_center_search = cfg_eval.az_center_true + center_bias(1);
el_center_search = cfg_eval.el_center_nominal + center_bias(2);
full_grid_cfg_base = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.full_search_cfg);
coarse_grid_cfg_base = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.coarse_search_cfg);
refine_cfg_base = cfg_eval.refine_cfg;
refine_cfg_base = normalize_refine_cfg_local(refine_cfg_base);
refine_cfg_base.az_global_bounds = full_grid_cfg_base.az_bounds;
refine_cfg_base.el_global_bounds = full_grid_cfg_base.el_bounds;

manifold_opts = struct();
manifold_opts.phase_factor = cfg_eval.phase_factor;
manifold_opts.phase_sign = cfg_eval.phase_sign;
search_opts = struct();
search_opts.whitening_mode = cfg_eval.whitening_mode;
search_opts.reg = cfg_eval.reg;

for iScenario = 1:height(scenario_table)
    scenario = table_row_to_struct_local(scenario_table(iScenario, :));
    az_true = cfg_eval.az_center_true + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
    el_center_true = cfg_eval.el_center_nominal + cfg_eval.el_center_offset;

    for trial_id = 1:cfg_eval.Metkl
        if scenario.el_sep_deg == 0
            el_true = [el_center_true, el_center_true];
            true_orientation = 0;
        elseif cfg_eval.alternate_true_orientation && mod(trial_id, 2) == 0
            el_true = el_center_true + [scenario.el_sep_deg / 2, -scenario.el_sep_deg / 2];
            true_orientation = -1;
        else
            el_true = el_center_true + [-scenario.el_sep_deg / 2, scenario.el_sep_deg / 2];
            true_orientation = 1;
        end

        seed_now = cfg_eval.base_seed + 1000 * iScenario + trial_id + cfg_eval.seed_offset;
        [Y, truth] = make_cyl_pair2d_correlated_snapshots(cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
            az_true, el_true, cfg_eval.lambda, cfg_eval.L, scenario.snr_db, ...
            'PhaseFactor', cfg_eval.phase_factor, 'PhaseSign', cfg_eval.phase_sign, ...
            'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
            'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
        Z = W' * Y;

        [est_full, debug_full] = search_pair2d_full_fine_grid(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
            cfg_eval.lambda, full_grid_cfg_base, manifold_opts, search_opts);
        est_full_score = attach_score_local(est_full, debug_full.max_score);
        metrics_full = eval_el_separation_pair_metrics(est_full, az_true, el_true, ...
            full_grid_cfg_base.az_bounds, full_grid_cfg_base.el_bounds, ...
            cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);

        need_coarse = any(strcmp(search_methods, 'coarse_only')) || any(strcmp(search_methods, 'coarse_to_fine'));
        top_candidates = [];
        coarse_debug = struct();
        if need_coarse
            [top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                cfg_eval.lambda, coarse_grid_cfg_base, manifold_opts, search_opts, cfg_eval.topK);
        end

        for iMethod = 1:numel(search_methods)
            method = search_methods{iMethod};
            switch method
                case 'full_fine'
                    est_now = est_full_score;
                    debug_now = debug_full;
                    debug_now.full_num_pairs = debug_full.num_pairs;
                    debug_now.coarse_num_pairs = 0;
                    debug_now.refine_num_pairs = 0;
                    debug_now.total_num_pairs = debug_full.num_pairs;
                    metrics_now = metrics_full;
                    compare_now = make_full_compare_local(metrics_full);
                    topK_miss = false;
                    num_pairs_now = debug_full.num_pairs;

                case 'coarse_only'
                    est_now = candidate_to_est_local(top_candidates(1));
                    est_now = attach_score_local(est_now, top_candidates(1).score);
                    debug_now = coarse_debug;
                    debug_now.full_num_pairs = debug_full.num_pairs;
                    debug_now.coarse_num_pairs = coarse_debug.num_pairs;
                    debug_now.refine_num_pairs = 0;
                    debug_now.total_num_pairs = coarse_debug.num_pairs;
                    metrics_now = eval_el_separation_pair_metrics(est_now, az_true, el_true, ...
                        full_grid_cfg_base.az_bounds, full_grid_cfg_base.el_bounds, ...
                        cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
                    compare_now = compare_search_outputs(est_now, est_full_score, metrics_now, metrics_full, ...
                        'AzMatchTolDeg', cfg_eval.full_match_az_tol_deg, ...
                        'ElMatchTolDeg', cfg_eval.full_match_el_tol_deg);
                    topK_miss = ~compare_now.same_as_full_grid;
                    num_pairs_now = coarse_debug.num_pairs;

                case 'coarse_to_fine'
                    [est_refined, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                        cfg_eval.lambda, top_candidates, refine_cfg_base, manifold_opts, search_opts);
                    est_now = attach_score_local(est_refined, refine_debug.max_score);
                    debug_now = struct();
                    debug_now.search_mode = 'degree_based_coarse_to_fine';
                    debug_now.full_num_pairs = debug_full.num_pairs;
                    debug_now.coarse_num_pairs = coarse_debug.num_pairs;
                    debug_now.refine_num_pairs = refine_debug.num_pairs;
                    debug_now.total_num_pairs = coarse_debug.num_pairs + refine_debug.num_pairs;
                    debug_now.num_pairs = debug_now.total_num_pairs;
                    debug_now.max_score = refine_debug.max_score;
                    debug_now.cond_best_GHG = refine_debug.cond_best_GHG;
                    debug_now.rank_best_G = refine_debug.rank_best_G;
                    debug_now.top_candidates = top_candidates;
                    debug_now.coarse_debug = coarse_debug;
                    debug_now.refine_debug = refine_debug;
                    metrics_now = eval_el_separation_pair_metrics(est_now, az_true, el_true, ...
                        full_grid_cfg_base.az_bounds, full_grid_cfg_base.el_bounds, ...
                        cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
                    compare_now = compare_search_outputs(est_now, est_full_score, metrics_now, metrics_full, ...
                        'AzMatchTolDeg', cfg_eval.full_match_az_tol_deg, ...
                        'ElMatchTolDeg', cfg_eval.full_match_el_tol_deg);
                    topK_miss = ~topk_covers_full_estimate_local(top_candidates, est_full, refine_cfg_base);
                    num_pairs_now = debug_now.total_num_pairs;

                otherwise
                    error('evaluate_search_acceleration_backend:UnknownSearchMethod', 'Unknown search method: %s', method);
            end

            row_idx = row_idx + 1;
            trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, seed_now, method, ...
                scenario, truth, true_orientation, est_now, az_true, el_true, metrics_now, ...
                compare_now, topK_miss, num_pairs_now, debug_now, debug_full.num_pairs, ...
                full_grid_cfg_base, coarse_grid_cfg_base, refine_cfg_base, cfg_eval);
        end
    end
end

if row_idx ~= total_rows
    error('evaluate_search_acceleration_backend:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table);
end

function cfg_eval = fill_defaults_local(cfg_eval, W)
if ~isfield(cfg_eval, 'el_center_offset')
    cfg_eval.el_center_offset = 0.31;
end
if ~isfield(cfg_eval, 'center_bias')
    cfg_eval.center_bias = [0, 0];
end
if ~isfield(cfg_eval, 'search_methods')
    cfg_eval.search_methods = {'full_fine','coarse_only','coarse_to_fine'};
end
if ~isfield(cfg_eval, 'whitening_mode')
    cfg_eval.whitening_mode = 'white';
end
if ~isfield(cfg_eval, 'reg')
    cfg_eval.reg = 1e-10;
end
if ~isfield(cfg_eval, 'az_tol_deg')
    cfg_eval.az_tol_deg = 0.15;
end
if ~isfield(cfg_eval, 'el_tol_deg')
    cfg_eval.el_tol_deg = 0.20;
end
if ~isfield(cfg_eval, 'el_sep_tol_deg')
    cfg_eval.el_sep_tol_deg = 0.25;
end
if ~isfield(cfg_eval, 'full_match_az_tol_deg')
    cfg_eval.full_match_az_tol_deg = cfg_eval.full_search_cfg.az_step / 2;
end
if ~isfield(cfg_eval, 'full_match_el_tol_deg')
    cfg_eval.full_match_el_tol_deg = cfg_eval.full_search_cfg.el_step / 2;
end
if ~isfield(cfg_eval, 'alternate_true_orientation')
    cfg_eval.alternate_true_orientation = true;
end
if ~isfield(cfg_eval, 'seed_offset')
    cfg_eval.seed_offset = 0;
end
if ~isfield(cfg_eval, 'W_method')
    cfg_eval.W_method = sprintf('greedy_combined_B%d', size(W, 2));
end
if ~isfield(cfg_eval, 'B')
    cfg_eval.B = size(W, 2);
end
if ~isfield(cfg_eval, 'config_name')
    cfg_eval.config_name = 'default_config';
end
if ~isfield(cfg_eval, 'coarse_config_name')
    cfg_eval.coarse_config_name = 'default_coarse';
end
if ~isfield(cfg_eval, 'refine_config_name')
    cfg_eval.refine_config_name = 'default_refine';
end
if ~isfield(cfg_eval, 'sweep_phase')
    cfg_eval.sweep_phase = 'single';
end
end

function refine_cfg = normalize_refine_cfg_local(refine_cfg)
if ~isfield(refine_cfg, 'local_el_center_half_width') && isfield(refine_cfg, 'local_el_half_width')
    refine_cfg.local_el_center_half_width = refine_cfg.local_el_half_width;
end
if ~isfield(refine_cfg, 'fine_el_sep_deg_list')
    if isfield(refine_cfg, 'el_sep_deg_list')
        refine_cfg.fine_el_sep_deg_list = refine_cfg.el_sep_deg_list;
    elseif isfield(refine_cfg, 'el_sep_index_list')
        refine_cfg.fine_el_sep_deg_list = refine_cfg.el_sep_index_list(:).' * refine_cfg.fine_el_step * 2;
    end
end
end

function validate_cfg_local(cfg_eval)
required_cfg = {'x','y','z','lambda','phase_factor','phase_sign','az_center_true','el_center_nominal', ...
    'L','Metkl','base_seed','full_search_cfg','coarse_search_cfg','refine_cfg','topK'};
for idx = 1:numel(required_cfg)
    if ~isfield(cfg_eval, required_cfg{idx})
        error('evaluate_search_acceleration_backend:MissingCfgField', 'cfg_eval.%s is required.', required_cfg{idx});
    end
end
if numel(cfg_eval.center_bias) ~= 2
    error('evaluate_search_acceleration_backend:InvalidCenterBias', 'center_bias must contain [az_bias, el_bias].');
end
if ~(isscalar(cfg_eval.Metkl) && cfg_eval.Metkl >= 1 && cfg_eval.Metkl == floor(cfg_eval.Metkl))
    error('evaluate_search_acceleration_backend:InvalidMetkl', 'Metkl must be a positive integer.');
end
end

function scenario_table = normalize_scenarios_local(scenarios)
if istable(scenarios)
    scenario_table = scenarios;
elseif isstruct(scenarios)
    scenario_table = struct2table(scenarios);
else
    error('evaluate_search_acceleration_backend:InvalidScenarios', 'scenarios must be a table or struct array.');
end
required = {'scenario_name','rho','phase_deg','beta','az_sep_deg','el_sep_deg','snr_db'};
for idx = 1:numel(required)
    if ~ismember(required{idx}, scenario_table.Properties.VariableNames)
        error('evaluate_search_acceleration_backend:MissingScenarioField', 'scenario.%s is required.', required{idx});
    end
end
end

function compare_now = make_full_compare_local(metrics_full)
compare_now = struct();
compare_now.same_as_full_grid = true;
compare_now.az_diff_vs_full = 0;
compare_now.el_diff_vs_full = 0;
compare_now.score_gap_vs_full = 0;
compare_now.test_joint_success = logical(metrics_full.joint_pair_tol_success);
compare_now.full_joint_success = logical(metrics_full.joint_pair_tol_success);
compare_now.test_rmse = hypot(metrics_full.az_rmse_deg, metrics_full.el_rmse_deg);
compare_now.full_rmse = compare_now.test_rmse;
compare_now.test_worse_than_full = false;
compare_now.full_success_test_fail = false;
compare_now.test_success_full_fail = false;
end

function est = candidate_to_est_local(candidate)
est = struct();
est.az_hat = candidate.az_hat;
est.el_hat = candidate.el_hat;
est.el_center_hat = candidate.el_center_hat;
est.el_sep_hat = candidate.el_sep_hat;
est.orientation_hat = candidate.orientation_hat;
end

function est = attach_score_local(est, score)
est.max_score = score;
est.score = score;
end

function covered = topk_covers_full_estimate_local(top_candidates, est_full, refine_cfg)
covered = false;
az_full = sort(est_full.az_hat(:).');
el_center_full = est_full.el_center_hat;
el_sep_full = est_full.el_sep_hat;
if ~isfield(refine_cfg, 'local_el_center_half_width')
    refine_cfg.local_el_center_half_width = refine_cfg.local_el_half_width;
end
fine_sep_list = refine_cfg.fine_el_sep_deg_list(:).';
for idx = 1:numel(top_candidates)
    cand = top_candidates(idx);
    az_cand = sort(cand.az_hat(:).');
    az1_bounds = az_cand(1) + [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width];
    az2_bounds = az_cand(2) + [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width];
    el_center_bounds = cand.el_center_hat + [-refine_cfg.local_el_center_half_width, refine_cfg.local_el_center_half_width];
    az1_bounds = clamp_bounds_local(az1_bounds, refine_cfg.az_global_bounds);
    az2_bounds = clamp_bounds_local(az2_bounds, refine_cfg.az_global_bounds);
    el_center_bounds = clamp_bounds_local(el_center_bounds, refine_cfg.el_global_bounds);
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

function row = make_trial_row_template_local()
row = struct();
numeric_fields = {'trial_global_id','trial_id','seed','topK','coarse_az_step','coarse_el_step','fine_az_step', ...
    'fine_el_step','local_az_half_width','local_el_center_half_width','az_center_search','el_center_search','az_center_bias_deg','el_center_bias_deg', ...
    'rho','phase_deg','beta','az_sep_deg','el_sep_deg','snr_db','source_corr_empirical','true_orientation', ...
    'az_hat_1','az_hat_2','el_hat_1','el_hat_2','az_true_1','az_true_2','el_true_1','el_true_2', ...
    'az_rmse','el_rmse','boundary_hit','num_pairs','full_num_pairs','coarse_num_pairs','refine_num_pairs', ...
    'reduction_ratio_vs_full','full_grid_match','topK_miss','max_score','cond_best_GHG','B','L','phase_factor', ...
    'phase_sign','az_bound_min','az_bound_max','el_bound_min','el_bound_max','az_diff_vs_full','el_diff_vs_full', ...
    'score_gap_vs_full','combined_rmse','full_combined_rmse','full_success_test_fail','full_el_sep_hat', ...
    'test_el_sep_hat','el_sep_diff_vs_full'};
for idx = 1:numel(numeric_fields)
    row.(numeric_fields{idx}) = NaN;
end
row.scenario_name = '';
row.search_method = '';
row.config_name = '';
row.coarse_config_name = '';
row.refine_config_name = '';
row.sweep_phase = '';
row.W_method = '';
row.whitening_mode = '';
row.search_param_mode = '';
row.full_el_sep_deg_list_text = '';
row.coarse_el_sep_deg_list_text = '';
row.fine_el_sep_deg_list_text = '';
row.joint_success = false;
row.boundary_hit = false;
row.full_grid_match = false;
row.topK_miss = false;
row.full_success_test_fail = false;
end

function row = make_trial_row_local(row_id, trial_id, seed_now, method, scenario, truth, true_orientation, est, ...
    az_true, el_true, metrics, compare_now, topK_miss, num_pairs_now, debug_now, full_num_pairs, ...
    full_grid_cfg, coarse_grid_cfg, refine_cfg, cfg_eval)
row = make_trial_row_template_local();
row.trial_global_id = row_id;
row.trial_id = trial_id;
row.seed = seed_now;
row.scenario_name = scenario.scenario_name;
row.search_method = method;
row.config_name = cfg_eval.config_name;
row.coarse_config_name = cfg_eval.coarse_config_name;
row.refine_config_name = cfg_eval.refine_config_name;
row.sweep_phase = cfg_eval.sweep_phase;
row.W_method = cfg_eval.W_method;
row.whitening_mode = cfg_eval.whitening_mode;
row.topK = cfg_eval.topK;
row.coarse_az_step = coarse_grid_cfg.az_step;
row.coarse_el_step = coarse_grid_cfg.el_step;
row.fine_az_step = refine_cfg.fine_az_step;
row.fine_el_step = refine_cfg.fine_el_step;
row.local_az_half_width = refine_cfg.local_az_half_width;
row.local_el_center_half_width = refine_cfg.local_el_center_half_width;
row.search_param_mode = 'degree_based_el_sep';
row.full_el_sep_deg_list_text = numeric_list_text_local(full_grid_cfg.el_sep_deg_list);
row.coarse_el_sep_deg_list_text = numeric_list_text_local(coarse_grid_cfg.el_sep_deg_list);
row.fine_el_sep_deg_list_text = numeric_list_text_local(refine_cfg.fine_el_sep_deg_list);
row.az_center_search = full_grid_cfg.az_center;
row.el_center_search = full_grid_cfg.el_center;
row.az_center_bias_deg = cfg_eval.center_bias(1);
row.el_center_bias_deg = cfg_eval.center_bias(2);
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
row.boundary_hit = logical(metrics.boundary_hit);
row.num_pairs = num_pairs_now;
row.full_num_pairs = full_num_pairs;
row.coarse_num_pairs = safe_field_local(debug_now, 'coarse_num_pairs', 0);
row.refine_num_pairs = safe_field_local(debug_now, 'refine_num_pairs', 0);
row.reduction_ratio_vs_full = full_num_pairs / max(num_pairs_now, eps);
row.full_grid_match = logical(compare_now.same_as_full_grid);
row.topK_miss = logical(topK_miss);
row.max_score = safe_field_local(debug_now, 'max_score', NaN);
row.cond_best_GHG = safe_field_local(debug_now, 'cond_best_GHG', NaN);
row.B = cfg_eval.B;
row.L = cfg_eval.L;
row.phase_factor = cfg_eval.phase_factor;
row.phase_sign = cfg_eval.phase_sign;
row.az_bound_min = full_grid_cfg.az_bounds(1);
row.az_bound_max = full_grid_cfg.az_bounds(2);
row.el_bound_min = full_grid_cfg.el_bounds(1);
row.el_bound_max = full_grid_cfg.el_bounds(2);
row.az_diff_vs_full = compare_now.az_diff_vs_full;
row.el_diff_vs_full = compare_now.el_diff_vs_full;
row.score_gap_vs_full = compare_now.score_gap_vs_full;
row.combined_rmse = compare_now.test_rmse;
row.full_combined_rmse = compare_now.full_rmse;
row.full_success_test_fail = logical(compare_now.full_success_test_fail);
row.full_el_sep_hat = safe_est_field_local(compare_now, 'full_el_sep_hat', est.el_sep_hat);
row.test_el_sep_hat = est.el_sep_hat;
row.el_sep_diff_vs_full = abs(row.test_el_sep_hat - row.full_el_sep_hat);
end

function value = safe_field_local(s, field, default_value)
if isstruct(s) && isfield(s, field)
    value = s.(field);
else
    value = default_value;
end
end

function value = safe_est_field_local(s, field, default_value)
if isstruct(s) && isfield(s, field)
    value = s.(field);
else
    value = default_value;
end
end

function summary_table = build_summary_table_local(trial_table)
group_fields = {'search_method','scenario_name','config_name','coarse_config_name','refine_config_name','sweep_phase', ...
    'topK','coarse_az_step','coarse_el_step','fine_az_step', ...
    'fine_el_step','local_az_half_width','local_el_center_half_width','az_center_bias_deg','el_center_bias_deg', ...
    'rho','phase_deg','beta','az_sep_deg','el_sep_deg','snr_db','B','W_method','search_param_mode', ...
    'full_el_sep_deg_list_text','coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text'};
groups = unique(trial_table(:, group_fields), 'rows');
rows = repmat(make_summary_row_template_local(), height(groups), 1);
for iGroup = 1:height(groups)
    mask = true(height(trial_table), 1);
    for iField = 1:numel(group_fields)
        field = group_fields{iField};
        mask = mask & match_value_local(trial_table.(field), groups.(field)(iGroup));
    end
    sub = trial_table(mask, :);
    rows(iGroup).search_method = char_value_local(groups.search_method(iGroup));
    rows(iGroup).scenario_name = char_value_local(groups.scenario_name(iGroup));
    rows(iGroup).config_name = char_value_local(groups.config_name(iGroup));
    rows(iGroup).coarse_config_name = char_value_local(groups.coarse_config_name(iGroup));
    rows(iGroup).refine_config_name = char_value_local(groups.refine_config_name(iGroup));
    rows(iGroup).sweep_phase = char_value_local(groups.sweep_phase(iGroup));
    rows(iGroup).topK = groups.topK(iGroup);
    rows(iGroup).coarse_az_step = groups.coarse_az_step(iGroup);
    rows(iGroup).coarse_el_step = groups.coarse_el_step(iGroup);
    rows(iGroup).fine_az_step = groups.fine_az_step(iGroup);
    rows(iGroup).fine_el_step = groups.fine_el_step(iGroup);
    rows(iGroup).local_az_half_width = groups.local_az_half_width(iGroup);
    rows(iGroup).local_el_center_half_width = groups.local_el_center_half_width(iGroup);
    rows(iGroup).az_center_bias_deg = groups.az_center_bias_deg(iGroup);
    rows(iGroup).el_center_bias_deg = groups.el_center_bias_deg(iGroup);
    rows(iGroup).rho = groups.rho(iGroup);
    rows(iGroup).phase_deg = groups.phase_deg(iGroup);
    rows(iGroup).beta = groups.beta(iGroup);
    rows(iGroup).az_sep_deg = groups.az_sep_deg(iGroup);
    rows(iGroup).el_sep_deg = groups.el_sep_deg(iGroup);
    rows(iGroup).snr_db = groups.snr_db(iGroup);
    rows(iGroup).B = groups.B(iGroup);
    rows(iGroup).W_method = char_value_local(groups.W_method(iGroup));
    rows(iGroup).search_param_mode = char_value_local(groups.search_param_mode(iGroup));
    rows(iGroup).full_el_sep_deg_list_text = char_value_local(groups.full_el_sep_deg_list_text(iGroup));
    rows(iGroup).coarse_el_sep_deg_list_text = char_value_local(groups.coarse_el_sep_deg_list_text(iGroup));
    rows(iGroup).fine_el_sep_deg_list_text = char_value_local(groups.fine_el_sep_deg_list_text(iGroup));
    rows(iGroup).joint_success_rate = mean(double(sub.joint_success));
    rows(iGroup).az_rmse_mean = mean_omitnan_local(sub.az_rmse);
    rows(iGroup).el_rmse_mean = mean_omitnan_local(sub.el_rmse);
    rows(iGroup).combined_rmse_mean = mean_omitnan_local(sub.combined_rmse);
    rows(iGroup).boundary_hit_rate = mean(double(sub.boundary_hit));
    rows(iGroup).mean_num_pairs = mean_omitnan_local(sub.num_pairs);
    rows(iGroup).mean_full_num_pairs = mean_omitnan_local(sub.full_num_pairs);
    rows(iGroup).mean_coarse_num_pairs = mean_omitnan_local(sub.coarse_num_pairs);
    rows(iGroup).mean_refine_num_pairs = mean_omitnan_local(sub.refine_num_pairs);
    rows(iGroup).mean_reduction_ratio_vs_full = mean_omitnan_local(sub.reduction_ratio_vs_full);
    rows(iGroup).full_grid_match_rate = mean(double(sub.full_grid_match));
    rows(iGroup).topK_miss_rate = mean(double(sub.topK_miss));
    rows(iGroup).full_success_test_fail_rate = mean(double(sub.full_success_test_fail));
    rows(iGroup).el_sep_match_rate_vs_full = mean(double(abs(sub.el_sep_diff_vs_full) <= max(sub.fine_el_step(1) / 2, 1e-9)));
    rows(iGroup).max_score_mean = mean_omitnan_local(sub.max_score);
    rows(iGroup).cond_best_GHG_mean = mean_omitnan_local(sub.cond_best_GHG);
    rows(iGroup).n_trials = height(sub);
end
summary_table = struct2table(rows);
summary_table = add_config_aggregates_local(summary_table);
end

function row = make_summary_row_template_local()
row = struct();
fields = {'search_method','scenario_name','topK','coarse_az_step','coarse_el_step','fine_az_step','fine_el_step', ...
    'config_name','coarse_config_name','refine_config_name','sweep_phase', ...
    'local_az_half_width','local_el_center_half_width','az_center_bias_deg','el_center_bias_deg','rho','phase_deg', ...
    'beta','az_sep_deg','el_sep_deg','snr_db','B','W_method','search_param_mode','full_el_sep_deg_list_text', ...
    'coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text', ...
    'joint_success_rate','az_rmse_mean','el_rmse_mean','combined_rmse_mean','boundary_hit_rate', ...
    'mean_num_pairs','mean_full_num_pairs','mean_coarse_num_pairs','mean_refine_num_pairs', ...
    'mean_reduction_ratio_vs_full','full_grid_match_rate','topK_miss_rate','full_success_test_fail_rate', ...
    'el_sep_match_rate_vs_full','max_score_mean','cond_best_GHG_mean','n_trials','overall_joint_success_rate','overall_az_rmse_mean', ...
    'overall_el_rmse_mean','overall_combined_rmse_mean','worst_case_success','overall_boundary_hit_rate', ...
    'overall_mean_num_pairs','overall_mean_reduction_ratio_vs_full','overall_full_grid_match_rate', ...
    'overall_topK_miss_rate','overall_el_sep_match_rate_vs_full'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.search_method = '';
row.scenario_name = '';
row.config_name = '';
row.coarse_config_name = '';
row.refine_config_name = '';
row.sweep_phase = '';
row.W_method = '';
row.search_param_mode = '';
row.full_el_sep_deg_list_text = '';
row.coarse_el_sep_deg_list_text = '';
row.fine_el_sep_deg_list_text = '';
end

function summary_table = add_config_aggregates_local(summary_table)
config_fields = {'search_method','config_name','coarse_config_name','refine_config_name','sweep_phase', ...
    'topK','coarse_az_step','coarse_el_step','fine_az_step','fine_el_step', ...
    'local_az_half_width','local_el_center_half_width','az_center_bias_deg','el_center_bias_deg','B','W_method', ...
    'search_param_mode','full_el_sep_deg_list_text','coarse_el_sep_deg_list_text','fine_el_sep_deg_list_text'};
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

function text = numeric_list_text_local(values)
values = values(:).';
parts = cell(1, numel(values));
for idx = 1:numel(values)
    parts{idx} = sprintf('%.12g', values(idx));
end
text = ['[', strjoin(parts, ','), ']'];
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
