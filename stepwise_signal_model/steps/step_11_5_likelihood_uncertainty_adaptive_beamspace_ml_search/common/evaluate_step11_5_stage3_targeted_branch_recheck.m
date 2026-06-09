function [branch_trial_table, branch_summary_table] = evaluate_step11_5_stage3_targeted_branch_recheck(W, scenarios, cfg_eval, policy_cfg, varargin)
%EVALUATE_STEP11_5_STAGE3_TARGETED_BRANCH_RECHECK Exercise BOUNDARY and ILL_CONDITIONED branches.
%
% The branch checks fix Stage2 selected C05. Truth is used only for final
% metric evaluation on real-search stress cases. The deterministic
% ill-conditioned probe directly exercises the policy guard branch when the
% representative real-search set does not naturally cross the condition
% threshold.

if nargin < 4
    error('evaluate_step11_5_stage3_targeted_branch_recheck:NotEnoughInputs', ...
        'W, scenarios, cfg_eval, and policy_cfg are required.');
end
unused = scenarios; %#ok<NASGU>
opts = parse_opts_local(varargin{:});
cfg_eval = fill_defaults_local(cfg_eval, W);
policy_cfg = normalize_policy_cfg_local(policy_cfg, cfg_eval);

manifold_opts = struct('phase_factor', cfg_eval.phase_factor, 'phase_sign', cfg_eval.phase_sign);
search_opts = struct('whitening_mode', cfg_eval.whitening_mode, 'reg', cfg_eval.reg, ...
    'topK_max', cfg_eval.topK_max, 'likelihood_tau', cfg_eval.tau);

base_refine_cfg_nominal = normalize_refine_cfg_local(cfg_eval.base_refine_cfg);
rows = repmat(make_branch_row_template_local(), 0, 1);
row_idx = 0;

real_cases = build_real_branch_cases_local();
for iCase = 1:numel(real_cases)
    row_idx = row_idx + 1;
    row_now = run_real_branch_case_local(row_idx, real_cases(iCase), W, cfg_eval, policy_cfg, ...
        manifold_opts, search_opts, base_refine_cfg_nominal, opts.seed_offset);
    rows(end + 1, 1) = row_now; %#ok<AGROW>
end

probe_cases = build_policy_probe_cases_local();
for iCase = 1:numel(probe_cases)
    row_idx = row_idx + 1;
    row_now = run_policy_probe_case_local(row_idx, probe_cases(iCase), policy_cfg, base_refine_cfg_nominal);
    rows(end + 1, 1) = row_now; %#ok<AGROW>
end

branch_trial_table = struct2table(rows);
branch_summary_table = build_branch_summary_table_local(branch_trial_table);
end

function row = run_real_branch_case_local(row_id, branch_case, W, cfg_eval, policy_cfg, ...
    manifold_opts, search_opts, base_refine_cfg_nominal, seed_offset)

az_center_search = cfg_eval.az_center_true + branch_case.az_center_bias_deg;
el_center_search = cfg_eval.el_center_nominal + branch_case.el_center_bias_deg;
full_grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.full_search_cfg);
coarse_grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.coarse_search_cfg);
base_refine_cfg = base_refine_cfg_nominal;
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;

scenario = branch_case.scenario;
az_true = cfg_eval.az_center_true + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
el_center_true = cfg_eval.el_center_nominal + cfg_eval.el_center_offset;
if scenario.el_sep_deg == 0
    el_true = [el_center_true, el_center_true];
    true_orientation = 0;
else
    el_true = el_center_true + [-scenario.el_sep_deg / 2, scenario.el_sep_deg / 2];
    true_orientation = 1;
end
seed_now = cfg_eval.base_seed + seed_offset + 900000 + 1000 * row_id + branch_case.trial_id;

[Y, ~] = make_cyl_pair2d_correlated_snapshots(cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    az_true, el_true, cfg_eval.lambda, cfg_eval.L, scenario.snr_db, ...
    'PhaseFactor', cfg_eval.phase_factor, 'PhaseSign', cfg_eval.phase_sign, ...
    'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
    'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);
Z = W' * Y;

[est_full, debug_full] = search_pair2d_full_fine_grid(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    cfg_eval.lambda, full_grid_cfg, manifold_opts, search_opts);
est_full = attach_score_local(est_full, debug_full.max_score);
metrics_full = eval_el_separation_pair_metrics(est_full, az_true, el_true, ...
    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);

[top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    cfg_eval.lambda, coarse_grid_cfg, manifold_opts, search_opts, cfg_eval.topK_max);
[est_adaptive, debug_adaptive] = search_pair2d_adaptive_topk_window_v2(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    cfg_eval.lambda, coarse_grid_cfg, base_refine_cfg, manifold_opts, search_opts, policy_cfg, top_candidates, coarse_debug);
metrics_adaptive = eval_el_separation_pair_metrics(est_adaptive, az_true, el_true, ...
    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
compare_adaptive = compare_search_outputs(est_adaptive, est_full, metrics_adaptive, metrics_full, ...
    'AzMatchTolDeg', cfg_eval.full_search_cfg.az_step / 2, 'ElMatchTolDeg', cfg_eval.full_search_cfg.el_step / 2);
adaptive_topK_miss = ~topk_covers_full_estimate_local(debug_adaptive.selected_candidates, est_full, ...
    debug_adaptive.adaptive_refine_cfg);

row = make_branch_row_template_local();
row.row_id = row_id;
row.branch_case_name = branch_case.branch_case_name;
row.branch_case_type = branch_case.branch_case_type;
row.uses_real_search = 1;
row.expected_policy_name = branch_case.expected_policy_name;
row.observed_policy_name = debug_adaptive.policy.policy_name;
row.branch_triggered = double(strcmp(row.observed_policy_name, row.expected_policy_name));
row.adaptive_confidence = debug_adaptive.confidence;
row.adaptive_boundary_flag = debug_adaptive.boundary_flag;
row.high_confidence_misuse = double(strcmp(debug_adaptive.confidence, 'high'));
row.reasonable_safe_output = double(reasonable_safe_output_local(branch_case.expected_policy_name, ...
    debug_adaptive.policy.policy_name, debug_adaptive.confidence, debug_adaptive.boundary_flag, ...
    debug_adaptive.policy.az_window_scale, debug_adaptive.policy.el_window_scale, debug_adaptive.adaptive_topK, policy_cfg));
row.seed = seed_now;
row.trial_id = branch_case.trial_id;
row.az_center_bias_deg = branch_case.az_center_bias_deg;
row.el_center_bias_deg = branch_case.el_center_bias_deg;
row.truth_az1 = az_true(1);
row.truth_az2 = az_true(2);
row.truth_el1 = el_true(1);
row.truth_el2 = el_true(2);
row.true_orientation = true_orientation;
row.full_success = double(metrics_full.joint_pair_tol_success);
row.adaptive_success = double(metrics_adaptive.joint_pair_tol_success);
row.full_rmse = hypot(metrics_full.az_rmse_deg, metrics_full.el_rmse_deg);
row.adaptive_rmse = hypot(metrics_adaptive.az_rmse_deg, metrics_adaptive.el_rmse_deg);
row.full_num_pairs = debug_full.num_pairs;
row.adaptive_num_pairs = debug_adaptive.num_pairs_total;
row.adaptive_full_grid_match = double(compare_adaptive.same_as_full_grid);
row.adaptive_topK_miss = double(adaptive_topK_miss);
row.adaptive_boundary_hit = double(metrics_adaptive.boundary_hit);
row.H_norm = debug_adaptive.features.H_norm;
row.gap_13 = debug_adaptive.features.gap_13;
row.gap_17 = debug_adaptive.features.gap_17;
row.boundary_risk = debug_adaptive.features.boundary_risk;
row.cond_risk = debug_adaptive.features.cond_risk;
row.U_search = debug_adaptive.features.U_search;
row.U_confidence = debug_adaptive.features.U_confidence;
row.adaptive_topK = debug_adaptive.adaptive_topK;
row.az_window_scale = debug_adaptive.policy.az_window_scale;
row.el_window_scale = debug_adaptive.policy.el_window_scale;
row.failure_reason = debug_adaptive.failure_reason;
end

function row = run_policy_probe_case_local(row_id, probe_case, policy_cfg, base_refine_cfg)
features = probe_case.features;
features.topK_available = 7;
features.topK_max = policy_cfg.topK_max;
policy = select_adaptive_topk_window_policy_v2(features, base_refine_cfg, policy_cfg);

row = make_branch_row_template_local();
row.row_id = row_id;
row.branch_case_name = probe_case.branch_case_name;
row.branch_case_type = probe_case.branch_case_type;
row.uses_real_search = 0;
row.expected_policy_name = probe_case.expected_policy_name;
row.observed_policy_name = policy.policy_name;
row.branch_triggered = double(strcmp(policy.policy_name, probe_case.expected_policy_name));
row.adaptive_confidence = policy.confidence;
row.adaptive_boundary_flag = policy.boundary_flag;
row.high_confidence_misuse = double(strcmp(policy.confidence, 'high'));
row.reasonable_safe_output = double(reasonable_safe_output_local(probe_case.expected_policy_name, ...
    policy.policy_name, policy.confidence, policy.boundary_flag, policy.az_window_scale, ...
    policy.el_window_scale, policy.adaptive_topK, policy_cfg));
row.H_norm = features.H_norm;
row.gap_13 = features.gap_13;
row.gap_17 = features.gap_17;
row.boundary_risk = features.boundary_risk;
row.cond_risk = features.cond_risk;
row.U_search = features.U_search;
row.U_confidence = features.U_confidence;
row.adaptive_topK = policy.adaptive_topK;
row.az_window_scale = policy.az_window_scale;
row.el_window_scale = policy.el_window_scale;
end

function branch_cases = build_real_branch_cases_local()
easy = make_scenario_local('boundary_easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30);
ill = make_scenario_local('ill_conditioned_near_coincident_real_search', 1.00, 0, 1.0, 0.16, 0.00, 30);
branch_cases = [ ...
    make_branch_case_local('boundary_az_lower_edge_real_search', 'BOUNDARY_real_search', 'BOUNDARY', 1.48, 0.00, 1, easy); ...
    make_branch_case_local('boundary_az_upper_edge_real_search', 'BOUNDARY_real_search', 'BOUNDARY', -1.48, 0.00, 2, easy); ...
    make_branch_case_local('ill_conditioned_near_coincident_real_search', 'ILL_CONDITIONED_real_search', 'ILL_CONDITIONED', 0.00, 0.00, 3, ill)];
end

function probe_cases = build_policy_probe_cases_local()
features = struct();
features.H_norm = 0.95;
features.gap_13 = 0.0030;
features.gap_17 = 0.0045;
features.boundary_risk = 0;
features.cond_risk = 0.96;
features.U_search = 0.12;
features.U_confidence = 0.91;
probe_cases = struct('branch_case_name', 'ill_conditioned_policy_guard_probe', ...
    'branch_case_type', 'ILL_CONDITIONED_policy_probe', ...
    'expected_policy_name', 'ILL_CONDITIONED', ...
    'features', features);
end

function branch_case = make_branch_case_local(name, type_name, expected_policy, az_bias, el_bias, trial_id, scenario)
branch_case = struct();
branch_case.branch_case_name = name;
branch_case.branch_case_type = type_name;
branch_case.expected_policy_name = expected_policy;
branch_case.az_center_bias_deg = az_bias;
branch_case.el_center_bias_deg = el_bias;
branch_case.trial_id = trial_id;
branch_case.scenario = scenario;
end

function scenario = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
scenario = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end

function tf = reasonable_safe_output_local(expected_policy, observed_policy, confidence, boundary_flag, az_scale, el_scale, adaptive_topK, policy_cfg)
tf = false;
if strcmp(expected_policy, 'BOUNDARY')
    tf = strcmp(observed_policy, 'BOUNDARY') && ~strcmp(confidence, 'high') && ...
        ~isempty(boundary_flag) && az_scale > 1.0 && el_scale > 1.0 && ...
        adaptive_topK == policy_cfg.boundary_topK;
elseif strcmp(expected_policy, 'ILL_CONDITIONED')
    tf = strcmp(observed_policy, 'ILL_CONDITIONED') && strcmp(confidence, 'low') && ...
        ~isempty(strfind(boundary_flag, 'ill_conditioned')) && abs(az_scale - 1.0) < 1e-12 && ...
        abs(el_scale - 1.0) < 1e-12 && adaptive_topK == 3;
end
end

function summary_table = build_branch_summary_table_local(T)
rows = repmat(make_branch_summary_row_template_local(), 0, 1);
types = unique(cellstr(T.branch_case_type), 'stable');
for idx = 1:numel(types)
    type_name = types{idx};
    rows(end + 1, 1) = aggregate_branch_subset_local(T, type_name, strcmp(T.branch_case_type, type_name)); %#ok<AGROW>
end
rows(end + 1, 1) = aggregate_branch_subset_local(T, 'all_targeted_branch_cases', true(height(T), 1));
summary_table = struct2table(rows);
end

function row = aggregate_branch_subset_local(T, scope, mask)
row = make_branch_summary_row_template_local();
row.summary_scope = scope;
if ~any(mask)
    row.n_cases = 0;
    return;
end
sub = T(mask, :);
row.n_cases = height(sub);
row.trigger_rate = mean_or_nan_local(sub.branch_triggered);
row.reasonable_safe_output_rate = mean_or_nan_local(sub.reasonable_safe_output);
row.high_confidence_misuse_rate = mean_or_nan_local(sub.high_confidence_misuse);
row.boundary_real_trigger_count = sum(strcmp(T.branch_case_type, 'BOUNDARY_real_search') & T.branch_triggered == 1);
row.ill_conditioned_real_trigger_count = sum(strcmp(T.branch_case_type, 'ILL_CONDITIONED_real_search') & T.branch_triggered == 1);
row.ill_conditioned_policy_probe_trigger_count = sum(strcmp(T.branch_case_type, 'ILL_CONDITIONED_policy_probe') & T.branch_triggered == 1);
row.targeted_branch_pass_flag = double(row.boundary_real_trigger_count >= 1 && ...
    (row.ill_conditioned_real_trigger_count >= 1 || row.ill_conditioned_policy_probe_trigger_count >= 1) && ...
    max(T.high_confidence_misuse) == 0 && min(T.reasonable_safe_output(T.branch_triggered == 1)) == 1);
end

function opts = parse_opts_local(varargin)
opts = struct('seed_offset', 250000);
if mod(numel(varargin), 2) ~= 0
    error('evaluate_step11_5_stage3_targeted_branch_recheck:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'seedoffset'
            opts.seed_offset = value;
        otherwise
            error('evaluate_step11_5_stage3_targeted_branch_recheck:UnknownOption', ...
                'Unknown option: %s.', name);
    end
end
end

function cfg_eval = fill_defaults_local(cfg_eval, W)
if ~isfield(cfg_eval, 'el_center_offset')
    cfg_eval.el_center_offset = 0.31;
end
if ~isfield(cfg_eval, 'topK_max')
    cfg_eval.topK_max = 7;
end
if ~isfield(cfg_eval, 'tau')
    cfg_eval.tau = 0.02;
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
if ~isfield(cfg_eval, 'B')
    cfg_eval.B = size(W, 2);
end
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

function row = make_branch_row_template_local()
row = struct();
char_fields = {'branch_case_name','branch_case_type','expected_policy_name','observed_policy_name', ...
    'adaptive_confidence','adaptive_boundary_flag','failure_reason'};
for idx = 1:numel(char_fields)
    row.(char_fields{idx}) = '';
end
num_fields = {'row_id','uses_real_search','branch_triggered','reasonable_safe_output','high_confidence_misuse', ...
    'seed','trial_id','az_center_bias_deg','el_center_bias_deg','truth_az1','truth_az2','truth_el1','truth_el2', ...
    'true_orientation','full_success','adaptive_success','full_rmse','adaptive_rmse','full_num_pairs', ...
    'adaptive_num_pairs','adaptive_full_grid_match','adaptive_topK_miss','adaptive_boundary_hit', ...
    'H_norm','gap_13','gap_17','boundary_risk','cond_risk','U_search','U_confidence', ...
    'adaptive_topK','az_window_scale','el_window_scale'};
for idx = 1:numel(num_fields)
    row.(num_fields{idx}) = NaN;
end
end

function row = make_branch_summary_row_template_local()
row = struct();
row.summary_scope = '';
num_fields = {'n_cases','trigger_rate','reasonable_safe_output_rate','high_confidence_misuse_rate', ...
    'boundary_real_trigger_count','ill_conditioned_real_trigger_count', ...
    'ill_conditioned_policy_probe_trigger_count','targeted_branch_pass_flag'};
for idx = 1:numel(num_fields)
    row.(num_fields{idx}) = NaN;
end
end

function s = table_row_to_struct_local(row_table)
s = struct();
names = row_table.Properties.VariableNames;
for idx = 1:numel(names)
    value = row_table.(names{idx});
    if iscell(value)
        value = value{1};
    elseif isstring(value)
        value = char(value);
    end
    s.(names{idx}) = value;
end
end

function value = mean_or_nan_local(x)
if isempty(x)
    value = NaN;
else
    value = mean(x);
end
end
