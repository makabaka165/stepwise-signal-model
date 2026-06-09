function [trial_table, summary_table, policy_summary_table, bias_summary_table] = evaluate_step11_5_adaptive_backend(W, scenarios, cfg_eval)
%EVALUATE_STEP11_5_ADAPTIVE_BACKEND Compare full, fixed topK3, and Step11.5.
%
% This evaluator keeps target truth outside all search functions. Truth is
% used only after estimates are produced to compute success, RMSE, topK miss,
% boundary hit, and full-grid match evidence.

if nargin < 3
    error('evaluate_step11_5_adaptive_backend:NotEnoughInputs', ...
        'W, scenarios, and cfg_eval are required.');
end
cfg_eval = fill_defaults_local(cfg_eval, W);
validate_cfg_local(cfg_eval);
scenario_table = normalize_scenarios_local(scenarios);
bias_cases = cfg_eval.center_bias_cases;

total_rows = height(scenario_table) * cfg_eval.Metkl * size(bias_cases, 1);
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

manifold_opts = struct('phase_factor', cfg_eval.phase_factor, 'phase_sign', cfg_eval.phase_sign);
search_opts = struct('whitening_mode', cfg_eval.whitening_mode, 'reg', cfg_eval.reg, ...
    'topK_max', cfg_eval.topK_max, 'likelihood_tau', cfg_eval.policy_cfg.tau);

for iBias = 1:size(bias_cases, 1)
    center_bias = bias_cases(iBias, :);
    az_center_search = cfg_eval.az_center_true + center_bias(1);
    el_center_search = cfg_eval.el_center_nominal + center_bias(2);
    full_grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.full_search_cfg);
    coarse_grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.coarse_search_cfg);
    base_refine_cfg = normalize_refine_cfg_local(cfg_eval.base_refine_cfg);
    base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
    base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;

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

            seed_now = cfg_eval.base_seed + 100000 * iBias + 1000 * iScenario + trial_id + cfg_eval.seed_offset;
            [Y, truth] = make_cyl_pair2d_correlated_snapshots(cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                az_true, el_true, cfg_eval.lambda, cfg_eval.L, scenario.snr_db, ...
                'PhaseFactor', cfg_eval.phase_factor, 'PhaseSign', cfg_eval.phase_sign, ...
                'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
                'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
            Z = W' * Y;

            [est_full, debug_full] = search_pair2d_full_fine_grid(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                cfg_eval.lambda, full_grid_cfg, manifold_opts, search_opts);
            est_full = attach_score_local(est_full, debug_full.max_score);
            metrics_full = eval_el_separation_pair_metrics(est_full, az_true, el_true, ...
                full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, ...
                cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);

            [top_candidates_fixed, coarse_debug_fixed] = search_pair2d_coarse_grid_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                cfg_eval.lambda, coarse_grid_cfg, manifold_opts, search_opts, cfg_eval.topK_max);
            fixed_candidates = top_candidates_fixed(1:min(cfg_eval.fixed_topK, numel(top_candidates_fixed)));
            fixed_debug = make_empty_debug_local('fixed_topK3');
            fixed_failure_reason = '';
            try
                [est_fixed, refine_debug_fixed] = search_pair2d_local_refine_from_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                    cfg_eval.lambda, fixed_candidates, base_refine_cfg, manifold_opts, search_opts);
                est_fixed = attach_score_local(est_fixed, refine_debug_fixed.max_score);
                fixed_debug.coarse_debug = coarse_debug_fixed;
                fixed_debug.refine_debug = refine_debug_fixed;
                fixed_debug.num_pairs_coarse = coarse_debug_fixed.num_pairs;
                fixed_debug.num_pairs_refine = refine_debug_fixed.num_pairs;
                fixed_debug.num_pairs_total = coarse_debug_fixed.num_pairs + refine_debug_fixed.num_pairs;
                fixed_debug.max_score = refine_debug_fixed.max_score;
                fixed_debug.cond_best_GHG = refine_debug_fixed.cond_best_GHG;
            catch ME
                est_fixed = make_failed_est_local();
                fixed_failure_reason = ME.message;
                fixed_debug.num_pairs_coarse = coarse_debug_fixed.num_pairs;
                fixed_debug.num_pairs_refine = 0;
                fixed_debug.num_pairs_total = coarse_debug_fixed.num_pairs;
            end
            metrics_fixed = eval_el_separation_pair_metrics(est_fixed, az_true, el_true, ...
                full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, ...
                cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
            compare_fixed = compare_search_outputs(est_fixed, est_full, metrics_fixed, metrics_full, ...
                'AzMatchTolDeg', cfg_eval.full_search_cfg.az_step / 2, ...
                'ElMatchTolDeg', cfg_eval.full_search_cfg.el_step / 2);
            fixed_topK_miss = ~topk_covers_full_estimate_local(fixed_candidates, est_full, base_refine_cfg);

            [est_adaptive, debug_adaptive] = search_pair2d_adaptive_topk_window(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                cfg_eval.lambda, coarse_grid_cfg, base_refine_cfg, manifold_opts, search_opts, cfg_eval.policy_cfg);
            metrics_adaptive = eval_el_separation_pair_metrics(est_adaptive, az_true, el_true, ...
                full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, ...
                cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
            compare_adaptive = compare_search_outputs(est_adaptive, est_full, metrics_adaptive, metrics_full, ...
                'AzMatchTolDeg', cfg_eval.full_search_cfg.az_step / 2, ...
                'ElMatchTolDeg', cfg_eval.full_search_cfg.el_step / 2);
            adaptive_topK_miss = ~topk_covers_full_estimate_local(debug_adaptive.selected_candidates, est_full, ...
                debug_adaptive.adaptive_refine_cfg);

            row_idx = row_idx + 1;
            trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, seed_now, iBias, center_bias, ...
                scenario, truth, true_orientation, az_true, el_true, est_full, metrics_full, est_fixed, metrics_fixed, ...
                compare_fixed, fixed_topK_miss, fixed_failure_reason, fixed_debug, est_adaptive, metrics_adaptive, ...
                compare_adaptive, adaptive_topK_miss, debug_adaptive, debug_full, full_grid_cfg, coarse_grid_cfg, ...
                base_refine_cfg, cfg_eval);
        end
    end
end

trial_table = struct2table(trial_rows);
summary_table = build_summary_table_local(trial_table);
policy_summary_table = build_policy_summary_table_local(trial_table);
bias_summary_table = build_bias_summary_table_local(trial_table);
end

function cfg_eval = fill_defaults_local(cfg_eval, W)
if ~isfield(cfg_eval, 'el_center_offset')
    cfg_eval.el_center_offset = 0.31;
end
if ~isfield(cfg_eval, 'center_bias_cases')
    cfg_eval.center_bias_cases = [0, 0];
end
if ~isfield(cfg_eval, 'fixed_topK')
    cfg_eval.fixed_topK = 3;
end
if ~isfield(cfg_eval, 'topK_max')
    cfg_eval.topK_max = 7;
end
if ~isfield(cfg_eval, 'policy_cfg')
    cfg_eval.policy_cfg = struct();
end
if ~isfield(cfg_eval.policy_cfg, 'topK_max')
    cfg_eval.policy_cfg.topK_max = cfg_eval.topK_max;
end
if ~isfield(cfg_eval.policy_cfg, 'tau')
    cfg_eval.policy_cfg.tau = 0.02;
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
if ~isfield(cfg_eval, 'snr_or_case_id')
    cfg_eval.snr_or_case_id = 'representative_case';
end
end

function validate_cfg_local(cfg_eval)
required = {'x','y','z','lambda','phase_factor','phase_sign','az_center_true','el_center_nominal', ...
    'L','Metkl','base_seed','full_search_cfg','coarse_search_cfg','base_refine_cfg'};
for idx = 1:numel(required)
    if ~isfield(cfg_eval, required{idx})
        error('evaluate_step11_5_adaptive_backend:MissingCfgField', 'cfg_eval.%s is required.', required{idx});
    end
end
if size(cfg_eval.center_bias_cases, 2) ~= 2
    error('evaluate_step11_5_adaptive_backend:InvalidBiasCases', ...
        'center_bias_cases must be an Nx2 matrix.');
end
end

function refine_cfg = normalize_refine_cfg_local(refine_cfg)
if ~isfield(refine_cfg, 'local_el_center_half_width') && isfield(refine_cfg, 'local_el_half_width')
    refine_cfg.local_el_center_half_width = refine_cfg.local_el_half_width;
end
if ~isfield(refine_cfg, 'fine_el_sep_deg_list') && isfield(refine_cfg, 'el_sep_deg_list')
    refine_cfg.fine_el_sep_deg_list = refine_cfg.el_sep_deg_list;
end
end

function row = make_trial_row_template_local()
row = struct();
char_fields = {'scenario_name','snr_or_case_id','adaptive_policy_name','adaptive_confidence', ...
    'adaptive_boundary_flag','adaptive_failure_reason','fixed_failure_reason','W_method','search_mode'};
for idx = 1:numel(char_fields)
    row.(char_fields{idx}) = '';
end
num_fields = {'trial_global_id','trial_id','seed','bias_case_id','az_center_bias_deg','el_center_bias_deg', ...
    'truth_az1','truth_az2','truth_el1','truth_el2','true_orientation','rho','phase_deg','beta', ...
    'az_sep_deg','el_sep_deg','snr_db','source_corr_empirical','full_success','fixed_success', ...
    'adaptive_success','full_rmse','fixed_rmse','adaptive_rmse','full_num_pairs','fixed_num_pairs', ...
    'adaptive_num_pairs','fixed_full_grid_match','adaptive_full_grid_match','fixed_topK_miss', ...
    'adaptive_topK_miss','fixed_boundary_hit','adaptive_boundary_hit','adaptive_U','adaptive_H_norm', ...
    'adaptive_gap_13','adaptive_gap_17','adaptive_boundary_risk','adaptive_cond_risk','adaptive_topK', ...
    'adaptive_num_pairs_coarse','adaptive_num_pairs_refine','fixed_num_pairs_coarse','fixed_num_pairs_refine', ...
    'full_az_hat1','full_az_hat2','full_el_hat1','full_el_hat2','fixed_az_hat1','fixed_az_hat2', ...
    'fixed_el_hat1','fixed_el_hat2','adaptive_az_hat1','adaptive_az_hat2','adaptive_el_hat1', ...
    'adaptive_el_hat2','adaptive_boundary_margin','adaptive_cond_best_GHG'};
for idx = 1:numel(num_fields)
    row.(num_fields{idx}) = NaN;
end
end

function row = make_trial_row_local(row_id, trial_id, seed_now, bias_case_id, center_bias, scenario, truth, ...
    true_orientation, az_true, el_true, est_full, metrics_full, est_fixed, metrics_fixed, compare_fixed, ...
    fixed_topK_miss, fixed_failure_reason, fixed_debug, est_adaptive, metrics_adaptive, compare_adaptive, ...
    adaptive_topK_miss, debug_adaptive, debug_full, full_grid_cfg, coarse_grid_cfg, base_refine_cfg, cfg_eval)
row = make_trial_row_template_local();
row.trial_global_id = row_id;
row.trial_id = trial_id;
row.seed = seed_now;
row.bias_case_id = bias_case_id;
row.scenario_name = scenario.scenario_name;
row.snr_or_case_id = cfg_eval.snr_or_case_id;
row.az_center_bias_deg = center_bias(1);
row.el_center_bias_deg = center_bias(2);
row.truth_az1 = az_true(1);
row.truth_az2 = az_true(2);
row.truth_el1 = el_true(1);
row.truth_el2 = el_true(2);
row.true_orientation = true_orientation;
row.rho = scenario.rho;
row.phase_deg = scenario.phase_deg;
row.beta = scenario.beta;
row.az_sep_deg = scenario.az_sep_deg;
row.el_sep_deg = scenario.el_sep_deg;
row.snr_db = scenario.snr_db;
row.source_corr_empirical = truth.source_corr_empirical;
row.full_success = double(metrics_full.joint_pair_tol_success);
row.fixed_success = double(metrics_fixed.joint_pair_tol_success);
row.adaptive_success = double(metrics_adaptive.joint_pair_tol_success);
row.full_rmse = hypot(metrics_full.az_rmse_deg, metrics_full.el_rmse_deg);
row.fixed_rmse = hypot(metrics_fixed.az_rmse_deg, metrics_fixed.el_rmse_deg);
row.adaptive_rmse = hypot(metrics_adaptive.az_rmse_deg, metrics_adaptive.el_rmse_deg);
row.full_num_pairs = debug_full.num_pairs;
row.fixed_num_pairs = fixed_debug.num_pairs_total;
row.adaptive_num_pairs = debug_adaptive.num_pairs_total;
row.fixed_full_grid_match = double(compare_fixed.same_as_full_grid);
row.adaptive_full_grid_match = double(compare_adaptive.same_as_full_grid);
row.fixed_topK_miss = double(fixed_topK_miss);
row.adaptive_topK_miss = double(adaptive_topK_miss);
row.fixed_boundary_hit = double(metrics_fixed.boundary_hit);
row.adaptive_boundary_hit = double(metrics_adaptive.boundary_hit);
row.adaptive_policy_name = debug_adaptive.policy.policy_name;
row.adaptive_U = debug_adaptive.features.U;
row.adaptive_H_norm = debug_adaptive.features.H_norm;
row.adaptive_gap_13 = debug_adaptive.features.gap_13;
row.adaptive_gap_17 = debug_adaptive.features.gap_17;
row.adaptive_boundary_risk = debug_adaptive.features.boundary_risk;
row.adaptive_cond_risk = debug_adaptive.features.cond_risk;
row.adaptive_confidence = debug_adaptive.confidence;
row.adaptive_boundary_flag = debug_adaptive.boundary_flag;
row.adaptive_failure_reason = debug_adaptive.failure_reason;
row.fixed_failure_reason = fixed_failure_reason;
row.adaptive_topK = debug_adaptive.adaptive_topK;
row.adaptive_num_pairs_coarse = debug_adaptive.num_pairs_coarse;
row.adaptive_num_pairs_refine = debug_adaptive.num_pairs_refine;
row.fixed_num_pairs_coarse = fixed_debug.num_pairs_coarse;
row.fixed_num_pairs_refine = fixed_debug.num_pairs_refine;
row.search_mode = debug_adaptive.search_mode;
row.W_method = cfg_eval.W_method;
row.full_az_hat1 = est_full.az_hat(1);
row.full_az_hat2 = est_full.az_hat(2);
row.full_el_hat1 = est_full.el_hat(1);
row.full_el_hat2 = est_full.el_hat(2);
row.fixed_az_hat1 = est_fixed.az_hat(1);
row.fixed_az_hat2 = est_fixed.az_hat(2);
row.fixed_el_hat1 = est_fixed.el_hat(1);
row.fixed_el_hat2 = est_fixed.el_hat(2);
row.adaptive_az_hat1 = est_adaptive.az_hat(1);
row.adaptive_az_hat2 = est_adaptive.az_hat(2);
row.adaptive_el_hat1 = est_adaptive.el_hat(1);
row.adaptive_el_hat2 = est_adaptive.el_hat(2);
row.adaptive_boundary_margin = debug_adaptive.features.boundary_margin;
row.adaptive_cond_best_GHG = debug_adaptive.features.cond_best_GHG;

% Keep these assignments alive for MAT debugging and static inspection.
unused = {full_grid_cfg, coarse_grid_cfg, base_refine_cfg}; %#ok<NASGU>
end

function summary_table = build_summary_table_local(T)
rows = repmat(make_summary_row_template_local(), 1, 1);
rows(1) = aggregate_trials_local(T, 'all_bias_cases');
summary_table = struct2table(rows);
end

function row = make_summary_row_template_local()
row = struct();
row.summary_name = '';
fields = {'n_trials','full_fine_success','fixed_topK3_success','adaptive_success','full_fine_rmse', ...
    'fixed_topK3_rmse','adaptive_rmse','full_fine_mean_num_pairs','fixed_topK3_mean_num_pairs', ...
    'adaptive_mean_num_pairs','fixed_topK3_reduction_ratio','adaptive_reduction_ratio', ...
    'adaptive_vs_fixed_pair_count_ratio','adaptive_vs_fixed_reduction_gain','fixed_full_grid_match_rate', ...
    'adaptive_full_grid_match_rate','fixed_topK_miss_rate','adaptive_topK_miss_rate', ...
    'fixed_boundary_hit_rate','adaptive_boundary_hit_rate','mean_adaptive_U','mean_adaptive_topK'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
end

function row = aggregate_trials_local(T, name)
row = make_summary_row_template_local();
row.summary_name = name;
row.n_trials = height(T);
row.full_fine_success = mean(T.full_success);
row.fixed_topK3_success = mean(T.fixed_success);
row.adaptive_success = mean(T.adaptive_success);
row.full_fine_rmse = mean_omitnan_local(T.full_rmse);
row.fixed_topK3_rmse = mean_omitnan_local(T.fixed_rmse);
row.adaptive_rmse = mean_omitnan_local(T.adaptive_rmse);
row.full_fine_mean_num_pairs = mean_omitnan_local(T.full_num_pairs);
row.fixed_topK3_mean_num_pairs = mean_omitnan_local(T.fixed_num_pairs);
row.adaptive_mean_num_pairs = mean_omitnan_local(T.adaptive_num_pairs);
row.fixed_topK3_reduction_ratio = row.full_fine_mean_num_pairs / max(row.fixed_topK3_mean_num_pairs, eps);
row.adaptive_reduction_ratio = row.full_fine_mean_num_pairs / max(row.adaptive_mean_num_pairs, eps);
row.adaptive_vs_fixed_pair_count_ratio = row.adaptive_mean_num_pairs / max(row.fixed_topK3_mean_num_pairs, eps);
row.adaptive_vs_fixed_reduction_gain = row.adaptive_reduction_ratio / max(row.fixed_topK3_reduction_ratio, eps);
row.fixed_full_grid_match_rate = mean(T.fixed_full_grid_match);
row.adaptive_full_grid_match_rate = mean(T.adaptive_full_grid_match);
row.fixed_topK_miss_rate = mean(T.fixed_topK_miss);
row.adaptive_topK_miss_rate = mean(T.adaptive_topK_miss);
row.fixed_boundary_hit_rate = mean(T.fixed_boundary_hit);
row.adaptive_boundary_hit_rate = mean(T.adaptive_boundary_hit);
row.mean_adaptive_U = mean_omitnan_local(T.adaptive_U);
row.mean_adaptive_topK = mean_omitnan_local(T.adaptive_topK);
end

function policy_summary_table = build_policy_summary_table_local(T)
names = {'EASY','NORMAL','HARD','UNSAFE'};
rows = repmat(struct('policy_name', '', 'n_trials', 0, 'policy_rate', NaN, ...
    'success_rate', NaN, 'mean_num_pairs', NaN, 'mean_U', NaN, 'mean_topK', NaN), numel(names), 1);
for idx = 1:numel(names)
    mask = strcmp(T.adaptive_policy_name, names{idx});
    rows(idx).policy_name = names{idx};
    rows(idx).n_trials = nnz(mask);
    rows(idx).policy_rate = nnz(mask) / max(height(T), 1);
    rows(idx).success_rate = mean_or_nan_local(T.adaptive_success(mask));
    rows(idx).mean_num_pairs = mean_omitnan_local(T.adaptive_num_pairs(mask));
    rows(idx).mean_U = mean_omitnan_local(T.adaptive_U(mask));
    rows(idx).mean_topK = mean_omitnan_local(T.adaptive_topK(mask));
end
policy_summary_table = struct2table(rows);
end

function bias_summary_table = build_bias_summary_table_local(T)
bias_pairs = unique(T(:, {'az_center_bias_deg','el_center_bias_deg'}), 'rows');
rows = repmat(struct('bias_case_id', NaN, 'az_center_bias_deg', NaN, 'el_center_bias_deg', NaN, ...
    'n_trials', NaN, 'fixed_success', NaN, 'adaptive_success', NaN, 'adaptive_success_drop_vs_zero', NaN, ...
    'adaptive_topK_miss_rate', NaN, 'adaptive_boundary_hit_rate', NaN, 'adaptive_full_grid_match_rate', NaN, ...
    'adaptive_mean_num_pairs', NaN, 'bias_robustness_pass_020', false), height(bias_pairs), 1);
zero_mask = abs(T.az_center_bias_deg) < 1e-12 & abs(T.el_center_bias_deg) < 1e-12;
zero_success = mean(T.adaptive_success(zero_mask));
for idx = 1:height(bias_pairs)
    mask = abs(T.az_center_bias_deg - bias_pairs.az_center_bias_deg(idx)) < 1e-12 & ...
        abs(T.el_center_bias_deg - bias_pairs.el_center_bias_deg(idx)) < 1e-12;
    rows(idx).bias_case_id = idx;
    rows(idx).az_center_bias_deg = bias_pairs.az_center_bias_deg(idx);
    rows(idx).el_center_bias_deg = bias_pairs.el_center_bias_deg(idx);
    rows(idx).n_trials = nnz(mask);
    rows(idx).fixed_success = mean(T.fixed_success(mask));
    rows(idx).adaptive_success = mean(T.adaptive_success(mask));
    rows(idx).adaptive_success_drop_vs_zero = zero_success - rows(idx).adaptive_success;
    rows(idx).adaptive_topK_miss_rate = mean(T.adaptive_topK_miss(mask));
    rows(idx).adaptive_boundary_hit_rate = mean(T.adaptive_boundary_hit(mask));
    rows(idx).adaptive_full_grid_match_rate = mean(T.adaptive_full_grid_match(mask));
    rows(idx).adaptive_mean_num_pairs = mean_omitnan_local(T.adaptive_num_pairs(mask));
    in020 = abs(rows(idx).az_center_bias_deg) <= 0.20 + 1e-12 && abs(rows(idx).el_center_bias_deg) <= 0.20 + 1e-12;
    rows(idx).bias_robustness_pass_020 = in020 && rows(idx).adaptive_topK_miss_rate == 0 && ...
        rows(idx).adaptive_boundary_hit_rate == 0 && rows(idx).adaptive_success_drop_vs_zero <= 0.06 + 1e-12;
end
bias_summary_table = struct2table(rows);
end

function debug = make_empty_debug_local(mode_name)
debug = struct();
debug.search_mode = mode_name;
debug.coarse_debug = struct();
debug.refine_debug = struct();
debug.num_pairs_coarse = NaN;
debug.num_pairs_refine = NaN;
debug.num_pairs_total = NaN;
debug.max_score = NaN;
debug.cond_best_GHG = NaN;
end

function est = make_failed_est_local()
est = struct('az_hat', [NaN, NaN], 'el_hat', [NaN, NaN], ...
    'el_center_hat', NaN, 'el_sep_hat', NaN, 'orientation_hat', NaN, ...
    'max_score', NaN, 'score', NaN);
end

function covered = topk_covers_full_estimate_local(top_candidates, est_full, refine_cfg)
covered = false;
if isempty(top_candidates) || ~isfield(est_full, 'az_hat') || any(~isfinite(est_full.az_hat))
    return;
end
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
            el_center_full >= el_center_bounds(1) - 1e-9 && el_center_full <= el_center_bounds(2) + 1e-9 && sep_match
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

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function v = mean_or_nan_local(x)
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end
