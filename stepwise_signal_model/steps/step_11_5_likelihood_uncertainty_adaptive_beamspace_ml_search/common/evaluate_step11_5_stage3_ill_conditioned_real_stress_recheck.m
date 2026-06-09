function [trial_table, summary_table, guard_probe_table] = evaluate_step11_5_stage3_ill_conditioned_real_stress_recheck(W, cfg_eval, policy_cfg, Metkl)
%EVALUATE_STEP11_5_STAGE3_ILL_CONDITIONED_REAL_STRESS_RECHECK Run stronger ill-conditioned real-search stress.
%
% This supplementary evaluator keeps the Stage2 selected C05 policy fixed.
% The real stress cases attempt to make ILL_CONDITIONED occur naturally in
% the search pipeline. If that does not happen, the deterministic guard
% probe remains a logic check and the real-search result is reported as a
% negative or partial result rather than forced to pass.

if nargin < 4
    error('evaluate_step11_5_stage3_ill_conditioned_real_stress_recheck:NotEnoughInputs', ...
        'W, cfg_eval, policy_cfg, and Metkl are required.');
end
cfg_eval = fill_defaults_local(cfg_eval, W);
policy_cfg = normalize_policy_cfg_local(policy_cfg, cfg_eval);
stress_table = build_stress_case_table_local();

manifold_opts = struct('phase_factor', cfg_eval.phase_factor, 'phase_sign', cfg_eval.phase_sign);
search_opts = struct('whitening_mode', cfg_eval.whitening_mode, 'reg', cfg_eval.reg, ...
    'topK_max', cfg_eval.topK_max, 'likelihood_tau', cfg_eval.tau);

full_grid_cfg = build_pair2d_search_grids(cfg_eval.az_center_true, cfg_eval.el_center_nominal, cfg_eval.full_search_cfg);
coarse_grid_cfg = build_pair2d_search_grids(cfg_eval.az_center_true, cfg_eval.el_center_nominal, cfg_eval.coarse_search_cfg);
base_refine_cfg = normalize_refine_cfg_local(cfg_eval.base_refine_cfg);
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;

total_rows = height(stress_table) * Metkl;
rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;
for iCase = 1:height(stress_table)
    stress_case = table_row_to_struct_local(stress_table(iCase, :));
    az_true = cfg_eval.az_center_true + [-stress_case.az_sep_deg / 2, stress_case.az_sep_deg / 2];
    el_center_true = cfg_eval.el_center_nominal + cfg_eval.el_center_offset;
    if stress_case.el_sep_deg == 0
        el_true = [el_center_true, el_center_true];
        true_orientation = 0;
    else
        el_true = el_center_true + [-stress_case.el_sep_deg / 2, stress_case.el_sep_deg / 2];
        true_orientation = 1;
    end
    for trial_id = 1:Metkl
        row_idx = row_idx + 1;
        seed_now = cfg_eval.base_seed + 700000 + 1000 * iCase + trial_id;
        rows(row_idx) = run_stress_trial_local(row_idx, W, cfg_eval, policy_cfg, manifold_opts, search_opts, ...
            full_grid_cfg, coarse_grid_cfg, base_refine_cfg, stress_case, trial_id, seed_now, ...
            az_true, el_true, true_orientation);
    end
end

trial_table = struct2table(rows);
summary_table = build_summary_table_local(trial_table);
guard_probe_table = run_guard_probe_local(policy_cfg, base_refine_cfg);
end

function row = run_stress_trial_local(row_id, W, cfg_eval, policy_cfg, manifold_opts, search_opts, ...
    full_grid_cfg, coarse_grid_cfg, base_refine_cfg, stress_case, trial_id, seed_now, az_true, el_true, true_orientation)

[Y, ~] = make_cyl_pair2d_correlated_snapshots(cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    az_true, el_true, cfg_eval.lambda, cfg_eval.L, stress_case.snr_db, ...
    'PhaseFactor', cfg_eval.phase_factor, 'PhaseSign', cfg_eval.phase_sign, ...
    'Rho', stress_case.rho, 'PhaseDeg', stress_case.phase_deg, ...
    'AmplitudeRatio', stress_case.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
Z = W' * Y;

[est_full, debug_full] = search_pair2d_full_fine_grid(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    cfg_eval.lambda, full_grid_cfg, manifold_opts, search_opts);
est_full = attach_score_local(est_full, debug_full.max_score);
metrics_full = eval_el_separation_pair_metrics(est_full, az_true, el_true, ...
    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);

[top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    cfg_eval.lambda, coarse_grid_cfg, manifold_opts, search_opts, cfg_eval.topK_max);
fixed_candidates = top_candidates(1:min(3, numel(top_candidates)));
[est_fixed, fixed_debug] = run_fixed_refine_local(Z, W, cfg_eval, fixed_candidates, base_refine_cfg, ...
    manifold_opts, search_opts, coarse_debug);
metrics_fixed = eval_el_separation_pair_metrics(est_fixed, az_true, el_true, ...
    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);

[est_adaptive, debug_adaptive] = search_pair2d_adaptive_topk_window_v2(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    cfg_eval.lambda, coarse_grid_cfg, base_refine_cfg, manifold_opts, search_opts, policy_cfg, top_candidates, coarse_debug);
metrics_adaptive = eval_el_separation_pair_metrics(est_adaptive, az_true, el_true, ...
    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
adaptive_topK_miss = ~topk_covers_full_estimate_local(debug_adaptive.selected_candidates, est_full, ...
    debug_adaptive.adaptive_refine_cfg);

ill_trigger = strcmp(debug_adaptive.policy.policy_name, 'ILL_CONDITIONED') || ...
    ~isempty(strfind(debug_adaptive.boundary_flag, 'ill_conditioned_pair_manifold'));
high_misuse = (ill_trigger && strcmp(debug_adaptive.confidence, 'high')) || ...
    (debug_adaptive.features.cond_risk >= policy_cfg.cond_threshold && strcmp(debug_adaptive.confidence, 'high'));

row = make_trial_row_template_local();
row.row_id = row_id;
row.stress_group = stress_case.stress_group;
row.stress_case_name = stress_case.stress_case_name;
row.trial_id = trial_id;
row.seed = seed_now;
row.az_sep_deg = stress_case.az_sep_deg;
row.el_sep_deg = stress_case.el_sep_deg;
row.rho = stress_case.rho;
row.phase_deg = stress_case.phase_deg;
row.beta = stress_case.beta;
row.snr_db = stress_case.snr_db;
row.truth_az1 = az_true(1);
row.truth_az2 = az_true(2);
row.truth_el1 = el_true(1);
row.truth_el2 = el_true(2);
row.true_orientation = true_orientation;
row.full_success = double(metrics_full.joint_pair_tol_success);
row.fixed_success = double(metrics_fixed.joint_pair_tol_success);
row.adaptive_success = double(metrics_adaptive.joint_pair_tol_success);
row.full_rmse = hypot(metrics_full.az_rmse_deg, metrics_full.el_rmse_deg);
row.fixed_rmse = hypot(metrics_fixed.az_rmse_deg, metrics_fixed.el_rmse_deg);
row.adaptive_rmse = hypot(metrics_adaptive.az_rmse_deg, metrics_adaptive.el_rmse_deg);
row.full_num_pairs = debug_full.num_pairs;
row.fixed_num_pairs = fixed_debug.num_pairs_total;
row.adaptive_num_pairs = debug_adaptive.num_pairs_total;
row.adaptive_vs_fixed_pair_count_ratio = row.adaptive_num_pairs / max(row.fixed_num_pairs, eps);
row.adaptive_policy_name = debug_adaptive.policy.policy_name;
row.adaptive_confidence = debug_adaptive.confidence;
row.adaptive_boundary_flag = debug_adaptive.boundary_flag;
row.cond_best_GHG = debug_adaptive.features.cond_best_GHG;
row.cond_risk = debug_adaptive.features.cond_risk;
row.boundary_margin = debug_adaptive.features.boundary_margin;
row.boundary_risk = debug_adaptive.features.boundary_risk;
row.U_search = debug_adaptive.features.U_search;
row.U_confidence = debug_adaptive.features.U_confidence;
row.H_norm = debug_adaptive.features.H_norm;
row.gap_13 = debug_adaptive.features.gap_13;
row.gap_17 = debug_adaptive.features.gap_17;
row.adaptive_topK = debug_adaptive.adaptive_topK;
row.az_window_scale = debug_adaptive.policy.az_window_scale;
row.el_window_scale = debug_adaptive.policy.el_window_scale;
row.adaptive_topK_miss = double(adaptive_topK_miss);
row.adaptive_boundary_hit = double(metrics_adaptive.boundary_hit);
row.high_confidence_misuse_flag = double(high_misuse);
row.ill_conditioned_real_trigger_flag = double(ill_trigger);
row.failure_reason = debug_adaptive.failure_reason;
end

function [est_fixed, fixed_debug] = run_fixed_refine_local(Z, W, cfg_eval, fixed_candidates, base_refine_cfg, manifold_opts, search_opts, coarse_debug)
fixed_debug = struct('num_pairs_total', NaN, 'failure_reason', '');
try
    [est_fixed, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
        cfg_eval.lambda, fixed_candidates, base_refine_cfg, manifold_opts, search_opts);
    est_fixed = attach_score_local(est_fixed, refine_debug.max_score);
    fixed_debug.num_pairs_total = coarse_debug.num_pairs + refine_debug.num_pairs;
catch ME
    est_fixed = make_failed_est_local();
    fixed_debug.num_pairs_total = coarse_debug.num_pairs;
    fixed_debug.failure_reason = ME.message;
end
end

function summary_table = build_summary_table_local(T)
rows = repmat(make_summary_row_template_local(), 0, 1);
groups = unique(cellstr(T.stress_group), 'stable');
for idx = 1:numel(groups)
    group = groups{idx};
    rows(end + 1, 1) = aggregate_subset_local(T, 'stress_group', group, '', strcmp(T.stress_group, group)); %#ok<AGROW>
end
cases = unique(cellstr(T.stress_case_name), 'stable');
for idx = 1:numel(cases)
    cname = cases{idx};
    rows(end + 1, 1) = aggregate_subset_local(T, 'stress_case', '', cname, strcmp(T.stress_case_name, cname)); %#ok<AGROW>
end
rows(end + 1, 1) = aggregate_subset_local(T, 'overall', '', '', true(height(T), 1));
summary_table = struct2table(rows);
end

function row = aggregate_subset_local(T, scope, stress_group, stress_case_name, mask)
row = make_summary_row_template_local();
row.summary_scope = scope;
row.stress_group = stress_group;
row.stress_case_name = stress_case_name;
if ~any(mask)
    row.n_trials = 0;
    row.safe_confidence_pass_flag = NaN;
    return;
end
sub = T(mask, :);
row.n_trials = height(sub);
row.fixed_success = mean_or_nan_local(sub.fixed_success);
row.adaptive_success = mean_or_nan_local(sub.adaptive_success);
row.fixed_rmse = mean_omitnan_local(sub.fixed_rmse);
row.adaptive_rmse = mean_omitnan_local(sub.adaptive_rmse);
row.fixed_mean_num_pairs = mean_omitnan_local(sub.fixed_num_pairs);
row.adaptive_mean_num_pairs = mean_omitnan_local(sub.adaptive_num_pairs);
row.adaptive_vs_fixed_pair_count_ratio = row.adaptive_mean_num_pairs / max(row.fixed_mean_num_pairs, eps);
row.ill_conditioned_real_trigger_rate = mean_or_nan_local(sub.ill_conditioned_real_trigger_flag);
row.ill_conditioned_real_trigger_count = sum(sub.ill_conditioned_real_trigger_flag == 1);
row.mean_cond_risk = mean_omitnan_local(sub.cond_risk);
row.max_cond_risk = max_or_nan_local(sub.cond_risk);
row.mean_cond_best_GHG = mean_omitnan_local(sub.cond_best_GHG);
row.max_cond_best_GHG = max_or_nan_local(sub.cond_best_GHG);
row.low_confidence_rate = mean(strcmp(sub.adaptive_confidence, 'low'));
row.medium_low_confidence_rate = mean(strcmp(sub.adaptive_confidence, 'medium_low'));
row.high_confidence_misuse_rate = mean_or_nan_local(sub.high_confidence_misuse_flag);
row.adaptive_topK_miss_rate = mean_or_nan_local(sub.adaptive_topK_miss);
row.adaptive_boundary_hit_rate = mean_or_nan_local(sub.adaptive_boundary_hit);
trigger_mask = sub.ill_conditioned_real_trigger_flag == 1;
if any(trigger_mask)
    allowed_conf = strcmp(sub.adaptive_confidence(trigger_mask), 'low') | strcmp(sub.adaptive_confidence(trigger_mask), 'medium_low');
    row.safe_confidence_pass_flag = double(all(allowed_conf) && row.high_confidence_misuse_rate == 0);
else
    row.safe_confidence_pass_flag = double(row.high_confidence_misuse_rate == 0);
end
end

function guard_probe_table = run_guard_probe_local(policy_cfg, base_refine_cfg)
features = struct();
features.H_norm = 0.8;
features.gap_13 = 0.001;
features.gap_17 = 0.002;
features.boundary_risk = 0;
features.cond_risk = 0.90;
features.topK_available = 7;
features.topK_max = policy_cfg.topK_max;
gap_risk = 1 - min(features.gap_13 / max(policy_cfg.gap_scale, eps), 1);
features.U_search = min(max(0.65 * gap_risk + 0.30 * features.boundary_risk + 0.05 * min(features.H_norm, 0.5), 0), 1);
features.U_confidence = min(max(0.35 * features.H_norm + 0.25 * gap_risk + 0.25 * features.cond_risk + 0.15 * features.boundary_risk, 0), 1);
policy = select_adaptive_topk_window_policy_v2(features, base_refine_cfg, policy_cfg);
guard_probe_pass_flag = strcmp(policy.policy_name, 'ILL_CONDITIONED') && strcmp(policy.confidence, 'low') && ...
    ~isempty(strfind(policy.boundary_flag, 'ill_conditioned_pair_manifold')) && ...
    policy.adaptive_topK == 3 && abs(policy.az_window_scale - 1.0) < 1e-12 && abs(policy.el_window_scale - 1.0) < 1e-12;
guard_probe_table = struct2table(struct( ...
    'probe_name', 'deterministic_ill_conditioned_guard_probe', ...
    'cond_risk', features.cond_risk, ...
    'boundary_risk', features.boundary_risk, ...
    'gap_13', features.gap_13, ...
    'H_norm', features.H_norm, ...
    'U_search', features.U_search, ...
    'U_confidence', features.U_confidence, ...
    'policy_name', policy.policy_name, ...
    'confidence', policy.confidence, ...
    'boundary_flag', policy.boundary_flag, ...
    'adaptive_topK', policy.adaptive_topK, ...
    'az_window_scale', policy.az_window_scale, ...
    'el_window_scale', policy.el_window_scale, ...
    'guard_probe_pass_flag', double(guard_probe_pass_flag)));
end

function stress_table = build_stress_case_table_local()
rows = [ ...
    make_case_local('close_same_elevation_coherent_pair', 'ill_real_sep_0p30_phase0', 0.30, 0, 1, 0, 1, 40); ...
    make_case_local('close_same_elevation_coherent_pair', 'ill_real_sep_0p20_phase0', 0.20, 0, 1, 0, 1, 40); ...
    make_case_local('close_same_elevation_coherent_pair', 'ill_real_sep_0p15_phase0', 0.15, 0, 1, 0, 1, 40); ...
    make_case_local('close_same_elevation_coherent_pair', 'ill_real_sep_0p10_phase0', 0.10, 0, 1, 0, 1, 40); ...
    make_case_local('near_antiphase_close_pair', 'ill_real_sep_0p30_phase180', 0.30, 0, 1, 180, 1, 40); ...
    make_case_local('near_antiphase_close_pair', 'ill_real_sep_0p20_phase180', 0.20, 0, 1, 180, 1, 40); ...
    make_case_local('near_antiphase_close_pair', 'ill_real_sep_0p15_phase180', 0.15, 0, 1, 180, 1, 40); ...
    make_case_local('near_antiphase_close_pair', 'ill_real_sep_0p10_phase180', 0.10, 0, 1, 180, 1, 40); ...
    make_case_local('weak_secondary_close_pair', 'ill_real_sep_0p20_beta03_phase0', 0.20, 0, 1, 0, 0.3, 40); ...
    make_case_local('weak_secondary_close_pair', 'ill_real_sep_0p15_beta03_phase0', 0.15, 0, 1, 0, 0.3, 40); ...
    make_case_local('lower_snr_close_pair', 'ill_real_sep_0p20_snr20', 0.20, 0, 1, 0, 1, 20); ...
    make_case_local('lower_snr_close_pair', 'ill_real_sep_0p15_snr20', 0.15, 0, 1, 0, 1, 20)];
stress_table = struct2table(rows);
end

function row = make_case_local(group, name, az_sep_deg, el_sep_deg, rho, phase_deg, beta, snr_db)
row = struct('stress_group', group, 'stress_case_name', name, 'az_sep_deg', az_sep_deg, ...
    'el_sep_deg', el_sep_deg, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, 'snr_db', snr_db);
end

function cfg_eval = fill_defaults_local(cfg_eval, W)
if ~isfield(cfg_eval, 'el_center_offset'), cfg_eval.el_center_offset = 0.31; end
if ~isfield(cfg_eval, 'topK_max'), cfg_eval.topK_max = 7; end
if ~isfield(cfg_eval, 'tau'), cfg_eval.tau = 0.02; end
if ~isfield(cfg_eval, 'whitening_mode'), cfg_eval.whitening_mode = 'white'; end
if ~isfield(cfg_eval, 'reg'), cfg_eval.reg = 1e-10; end
if ~isfield(cfg_eval, 'az_tol_deg'), cfg_eval.az_tol_deg = 0.15; end
if ~isfield(cfg_eval, 'el_tol_deg'), cfg_eval.el_tol_deg = 0.20; end
if ~isfield(cfg_eval, 'el_sep_tol_deg'), cfg_eval.el_sep_tol_deg = 0.25; end
if ~isfield(cfg_eval, 'B'), cfg_eval.B = size(W, 2); end
end

function policy_cfg = normalize_policy_cfg_local(policy_cfg, cfg_eval)
if istable(policy_cfg)
    policy_cfg = table_row_to_struct_local(policy_cfg(1, :));
end
defaults = struct('topK_max', cfg_eval.topK_max, 'tau', cfg_eval.tau, 'config_id', 5, ...
    'config_name', 'C05_easy_very_aggressive');
names = fieldnames(defaults);
for idx = 1:numel(names)
    if ~isfield(policy_cfg, names{idx})
        policy_cfg.(names{idx}) = defaults.(names{idx});
    end
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
    az1_bounds = clamp_bounds_local(az_cand(1) + [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width], refine_cfg.az_global_bounds);
    az2_bounds = clamp_bounds_local(az_cand(2) + [-refine_cfg.local_az_half_width, refine_cfg.local_az_half_width], refine_cfg.az_global_bounds);
    el_center_bounds = clamp_bounds_local(cand.el_center_hat + [-refine_cfg.local_el_center_half_width, refine_cfg.local_el_center_half_width], refine_cfg.el_global_bounds);
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

function est = make_failed_est_local()
est = struct('az_hat', [NaN, NaN], 'el_hat', [NaN, NaN], ...
    'el_center_hat', NaN, 'el_sep_hat', NaN, 'orientation_hat', NaN, ...
    'max_score', NaN, 'score', NaN);
end

function row = make_trial_row_template_local()
row = struct();
char_fields = {'stress_group','stress_case_name','adaptive_policy_name','adaptive_confidence','adaptive_boundary_flag','failure_reason'};
for idx = 1:numel(char_fields), row.(char_fields{idx}) = ''; end
num_fields = {'row_id','trial_id','seed','az_sep_deg','el_sep_deg','rho','phase_deg','beta','snr_db', ...
    'truth_az1','truth_az2','truth_el1','truth_el2','true_orientation','fixed_success','adaptive_success','full_success', ...
    'fixed_rmse','adaptive_rmse','full_rmse','fixed_num_pairs','adaptive_num_pairs','full_num_pairs', ...
    'adaptive_vs_fixed_pair_count_ratio','cond_best_GHG','cond_risk','boundary_margin','boundary_risk', ...
    'U_search','U_confidence','H_norm','gap_13','gap_17','adaptive_topK','az_window_scale','el_window_scale', ...
    'adaptive_topK_miss','adaptive_boundary_hit','high_confidence_misuse_flag','ill_conditioned_real_trigger_flag'};
for idx = 1:numel(num_fields), row.(num_fields{idx}) = NaN; end
end

function row = make_summary_row_template_local()
row = struct();
char_fields = {'summary_scope','stress_group','stress_case_name'};
for idx = 1:numel(char_fields), row.(char_fields{idx}) = ''; end
num_fields = {'n_trials','fixed_success','adaptive_success','fixed_rmse','adaptive_rmse', ...
    'fixed_mean_num_pairs','adaptive_mean_num_pairs','adaptive_vs_fixed_pair_count_ratio', ...
    'ill_conditioned_real_trigger_rate','ill_conditioned_real_trigger_count','mean_cond_risk','max_cond_risk', ...
    'mean_cond_best_GHG','max_cond_best_GHG','low_confidence_rate','medium_low_confidence_rate', ...
    'high_confidence_misuse_rate','adaptive_topK_miss_rate','adaptive_boundary_hit_rate','safe_confidence_pass_flag'};
for idx = 1:numel(num_fields), row.(num_fields{idx}) = NaN; end
end

function s = table_row_to_struct_local(row_table)
s = struct();
names = row_table.Properties.VariableNames;
for idx = 1:numel(names)
    value = row_table.(names{idx});
    if iscell(value), value = value{1}; elseif isstring(value), value = char(value); end
    s.(names{idx}) = value;
end
end

function value = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x), value = NaN; else, value = mean(x); end
end

function value = mean_or_nan_local(x)
if isempty(x), value = NaN; else, value = mean(x); end
end

function value = max_or_nan_local(x)
x = x(isfinite(x));
if isempty(x), value = NaN; else, value = max(x); end
end
