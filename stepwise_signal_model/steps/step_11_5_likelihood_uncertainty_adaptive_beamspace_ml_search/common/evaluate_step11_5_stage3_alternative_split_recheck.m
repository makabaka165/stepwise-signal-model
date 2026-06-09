function [trial_table, summary_table] = evaluate_step11_5_stage3_alternative_split_recheck(W, scenarios, cfg_eval, policy_cfg, varargin)
%EVALUATE_STEP11_5_STAGE3_ALTERNATIVE_SPLIT_RECHECK Validate C05 on alternate splits.
%
% This evaluator fixes the Stage2 selected C05 policy and reruns the
% full/fixed/adaptive comparison. The search center, candidate generation,
% topK selection, and policy decision do not use target truth.

if nargin < 4
    error('evaluate_step11_5_stage3_alternative_split_recheck:NotEnoughInputs', ...
        'W, scenarios, cfg_eval, and policy_cfg are required.');
end
opts = parse_opts_local(varargin{:});
cfg_eval = fill_defaults_local(cfg_eval, W);
if isempty(opts.Metkl)
    opts.Metkl = cfg_eval.Metkl;
end
if isempty(opts.seed_offsets)
    opts.seed_offsets = cfg_eval.seed_offset;
end
scenario_table = normalize_scenarios_local(scenarios);
policy_cfg = normalize_policy_cfg_local(policy_cfg, cfg_eval);

manifold_opts = struct('phase_factor', cfg_eval.phase_factor, 'phase_sign', cfg_eval.phase_sign);
search_opts = struct('whitening_mode', cfg_eval.whitening_mode, 'reg', cfg_eval.reg, ...
    'topK_max', cfg_eval.topK_max, 'likelihood_tau', cfg_eval.tau);

center_bias = [0, 0];
az_center_search = cfg_eval.az_center_true + center_bias(1);
el_center_search = cfg_eval.el_center_nominal + center_bias(2);
full_grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.full_search_cfg);
coarse_grid_cfg = build_pair2d_search_grids(az_center_search, el_center_search, cfg_eval.coarse_search_cfg);
base_refine_cfg = normalize_refine_cfg_local(cfg_eval.base_refine_cfg);
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;

trial_rows = repmat(make_trial_row_template_local(), 0, 1);
row_idx = 0;
for iSeed = 1:numel(opts.seed_offsets)
    seed_offset = opts.seed_offsets(iSeed);
    for iScenario = 1:height(scenario_table)
        scenario = table_row_to_struct_local(scenario_table(iScenario, :));
        az_true = cfg_eval.az_center_true + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
        el_center_true = cfg_eval.el_center_nominal + cfg_eval.el_center_offset;

        for trial_id = 1:opts.Metkl
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

            seed_now = cfg_eval.base_seed + 100000 + 1000 * iScenario + trial_id + seed_offset;
            base_row = run_one_trial_local(W, cfg_eval, policy_cfg, manifold_opts, search_opts, ...
                full_grid_cfg, coarse_grid_cfg, base_refine_cfg, scenario, trial_id, seed_now, ...
                iSeed, seed_offset, center_bias, az_true, el_true, true_orientation, opts.run_label);

            for iScheme = 1:numel(opts.split_schemes)
                row_idx = row_idx + 1;
                scheme = char(opts.split_schemes{iScheme});
                row_now = base_row;
                row_now.row_id = row_idx;
                row_now.split_scheme = scheme;
                row_now.split_name = split_name_for_scheme_local(scheme, trial_id, iScenario, opts.Metkl);
                trial_rows(end + 1, 1) = row_now; %#ok<AGROW>
            end
        end
    end
end

trial_table = struct2table(trial_rows);
summary_table = build_stage3_summary_table_local(trial_table, opts.run_label);
end

function base_row = run_one_trial_local(W, cfg_eval, policy_cfg, manifold_opts, search_opts, ...
    full_grid_cfg, coarse_grid_cfg, base_refine_cfg, scenario, trial_id, seed_now, seed_group_id, ...
    seed_offset, center_bias, az_true, el_true, true_orientation, run_label)

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
fixed_candidates = top_candidates(1:min(3, numel(top_candidates)));
[est_fixed, fixed_debug] = run_fixed_refine_local(Z, W, cfg_eval, fixed_candidates, ...
    base_refine_cfg, manifold_opts, search_opts, coarse_debug);
metrics_fixed = eval_el_separation_pair_metrics(est_fixed, az_true, el_true, ...
    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
compare_fixed = compare_search_outputs(est_fixed, est_full, metrics_fixed, metrics_full, ...
    'AzMatchTolDeg', cfg_eval.full_search_cfg.az_step / 2, 'ElMatchTolDeg', cfg_eval.full_search_cfg.el_step / 2);
fixed_topK_miss = ~topk_covers_full_estimate_local(fixed_candidates, est_full, base_refine_cfg);

[est_adaptive, debug_adaptive] = search_pair2d_adaptive_topk_window_v2(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
    cfg_eval.lambda, coarse_grid_cfg, base_refine_cfg, manifold_opts, search_opts, policy_cfg, top_candidates, coarse_debug);
metrics_adaptive = eval_el_separation_pair_metrics(est_adaptive, az_true, el_true, ...
    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
compare_adaptive = compare_search_outputs(est_adaptive, est_full, metrics_adaptive, metrics_full, ...
    'AzMatchTolDeg', cfg_eval.full_search_cfg.az_step / 2, 'ElMatchTolDeg', cfg_eval.full_search_cfg.el_step / 2);
adaptive_topK_miss = ~topk_covers_full_estimate_local(debug_adaptive.selected_candidates, est_full, ...
    debug_adaptive.adaptive_refine_cfg);

base_row = make_trial_row_template_local();
base_row.run_label = run_label;
base_row.config_id = policy_cfg.config_id;
base_row.config_name = policy_cfg.config_name;
base_row.scenario_name = scenario.scenario_name;
base_row.seed_group_id = seed_group_id;
base_row.seed_offset = seed_offset;
base_row.trial_id = trial_id;
base_row.seed = seed_now;
base_row.az_center_bias_deg = center_bias(1);
base_row.el_center_bias_deg = center_bias(2);
base_row.truth_az1 = az_true(1);
base_row.truth_az2 = az_true(2);
base_row.truth_el1 = el_true(1);
base_row.truth_el2 = el_true(2);
base_row.true_orientation = true_orientation;
base_row.full_success = double(metrics_full.joint_pair_tol_success);
base_row.fixed_success = double(metrics_fixed.joint_pair_tol_success);
base_row.adaptive_success = double(metrics_adaptive.joint_pair_tol_success);
base_row.full_rmse = hypot(metrics_full.az_rmse_deg, metrics_full.el_rmse_deg);
base_row.fixed_rmse = hypot(metrics_fixed.az_rmse_deg, metrics_fixed.el_rmse_deg);
base_row.adaptive_rmse = hypot(metrics_adaptive.az_rmse_deg, metrics_adaptive.el_rmse_deg);
base_row.full_num_pairs = debug_full.num_pairs;
base_row.fixed_num_pairs = fixed_debug.num_pairs_total;
base_row.adaptive_num_pairs = debug_adaptive.num_pairs_total;
base_row.adaptive_num_pairs_coarse = debug_adaptive.num_pairs_coarse;
base_row.adaptive_num_pairs_refine = debug_adaptive.num_pairs_refine;
base_row.adaptive_vs_fixed_pair_count_ratio = base_row.adaptive_num_pairs / max(base_row.fixed_num_pairs, eps);
base_row.fixed_full_grid_match = double(compare_fixed.same_as_full_grid);
base_row.adaptive_full_grid_match = double(compare_adaptive.same_as_full_grid);
base_row.fixed_topK_miss = double(fixed_topK_miss);
base_row.adaptive_topK_miss = double(adaptive_topK_miss);
base_row.fixed_boundary_hit = double(metrics_fixed.boundary_hit);
base_row.adaptive_boundary_hit = double(metrics_adaptive.boundary_hit);
base_row.adaptive_policy_name = debug_adaptive.policy.policy_name;
base_row.adaptive_confidence = debug_adaptive.confidence;
base_row.adaptive_boundary_flag = debug_adaptive.boundary_flag;
base_row.H_norm = debug_adaptive.features.H_norm;
base_row.gap_13 = debug_adaptive.features.gap_13;
base_row.gap_17 = debug_adaptive.features.gap_17;
base_row.boundary_risk = debug_adaptive.features.boundary_risk;
base_row.cond_risk = debug_adaptive.features.cond_risk;
base_row.U_search = debug_adaptive.features.U_search;
base_row.U_confidence = debug_adaptive.features.U_confidence;
base_row.adaptive_topK = debug_adaptive.adaptive_topK;
base_row.az_window_scale = debug_adaptive.policy.az_window_scale;
base_row.el_window_scale = debug_adaptive.policy.el_window_scale;
base_row.failure_reason = debug_adaptive.failure_reason;
end

function [est_fixed, fixed_debug] = run_fixed_refine_local(Z, W, cfg_eval, fixed_candidates, base_refine_cfg, manifold_opts, search_opts, coarse_debug)
fixed_debug = struct('num_pairs_coarse', coarse_debug.num_pairs, 'num_pairs_refine', NaN, ...
    'num_pairs_total', NaN, 'max_score', NaN, 'cond_best_GHG', NaN, 'failure_reason', '');
try
    [est_fixed, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
        cfg_eval.lambda, fixed_candidates, base_refine_cfg, manifold_opts, search_opts);
    est_fixed = attach_score_local(est_fixed, refine_debug.max_score);
    fixed_debug.num_pairs_refine = refine_debug.num_pairs;
    fixed_debug.num_pairs_total = coarse_debug.num_pairs + refine_debug.num_pairs;
    fixed_debug.max_score = refine_debug.max_score;
    fixed_debug.cond_best_GHG = refine_debug.cond_best_GHG;
catch ME
    est_fixed = make_failed_est_local();
    fixed_debug.num_pairs_refine = 0;
    fixed_debug.num_pairs_total = coarse_debug.num_pairs;
    fixed_debug.failure_reason = ME.message;
end
end

function summary_table = build_stage3_summary_table_local(trial_table, run_label)
rows = repmat(make_summary_row_template_local(), 0, 1);
schemes = unique(cellstr(trial_table.split_scheme), 'stable');
for iScheme = 1:numel(schemes)
    scheme = schemes{iScheme};
    scheme_mask = strcmp(trial_table.split_scheme, scheme);
    rows(end + 1, 1) = aggregate_subset_local(trial_table, 'split_scheme_all', run_label, ...
        scheme, 'all', NaN, scheme_mask); %#ok<AGROW>
    split_names = unique(cellstr(trial_table.split_name(scheme_mask)), 'stable');
    for iSplit = 1:numel(split_names)
        split_name = split_names{iSplit};
        rows(end + 1, 1) = aggregate_subset_local(trial_table, 'split_scheme_split', run_label, ...
            scheme, split_name, NaN, scheme_mask & strcmp(trial_table.split_name, split_name)); %#ok<AGROW>
    end
end

seed_groups = unique(trial_table.seed_group_id).';
for iSeed = 1:numel(seed_groups)
    sid = seed_groups(iSeed);
    rows(end + 1, 1) = aggregate_subset_local(trial_table, 'seed_group_all', run_label, ...
        'all', 'all', sid, trial_table.seed_group_id == sid); %#ok<AGROW>
end
rows(end + 1, 1) = aggregate_subset_local(trial_table, 'overall', run_label, ...
    'all', 'all', NaN, true(height(trial_table), 1));
summary_table = struct2table(rows);
end

function row = aggregate_subset_local(T, scope, run_label, split_scheme, split_name, seed_group_id, mask)
row = make_summary_row_template_local();
row.summary_scope = scope;
row.run_label = run_label;
row.split_scheme = split_scheme;
row.split_name = split_name;
row.seed_group_id = seed_group_id;
if ~any(mask)
    row.n_trials = 0;
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
row.adaptive_full_grid_match_rate = mean_or_nan_local(sub.adaptive_full_grid_match);
row.adaptive_topK_miss_rate = mean_or_nan_local(sub.adaptive_topK_miss);
row.adaptive_boundary_hit_rate = mean_or_nan_local(sub.adaptive_boundary_hit);
row.max_policy_rate = max_policy_rate_local(sub.adaptive_policy_name);
row.policy_degeneracy_flag = double(row.max_policy_rate >= 0.95);
row.safety_pass_flag = double(row.adaptive_success >= row.fixed_success - 1e-12 && ...
    row.adaptive_rmse <= row.fixed_rmse + 1e-12 && ...
    row.adaptive_topK_miss_rate == 0 && row.adaptive_boundary_hit_rate == 0 && ...
    row.adaptive_full_grid_match_rate >= 0.98);
row.complexity_pass_flag = double(row.adaptive_mean_num_pairs <= 0.95 * row.fixed_mean_num_pairs);
row.stage3_pass_flag = double(row.safety_pass_flag == 1 && row.complexity_pass_flag == 1 && ...
    row.policy_degeneracy_flag == 0);
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.run_label = 'alt_split_recheck';
opts.Metkl = [];
opts.seed_offsets = [];
opts.split_schemes = {'alt_mod3_validation', 'alt_tail_block_validation'};
if mod(numel(varargin), 2) ~= 0
    error('evaluate_step11_5_stage3_alternative_split_recheck:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'runlabel'
            opts.run_label = char(value);
        case 'metkl'
            opts.Metkl = value;
        case 'seedoffsets'
            opts.seed_offsets = value;
        case 'splitschemes'
            opts.split_schemes = value;
        otherwise
            error('evaluate_step11_5_stage3_alternative_split_recheck:UnknownOption', ...
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
if ~isfield(cfg_eval, 'alternate_true_orientation')
    cfg_eval.alternate_true_orientation = true;
end
if ~isfield(cfg_eval, 'seed_offset')
    cfg_eval.seed_offset = 250000;
end
if ~isfield(cfg_eval, 'B')
    cfg_eval.B = size(W, 2);
end
required = {'x','y','z','lambda','phase_factor','phase_sign','az_center_true','el_center_nominal', ...
    'L','Metkl','base_seed','full_search_cfg','coarse_search_cfg','base_refine_cfg'};
for idx = 1:numel(required)
    if ~isfield(cfg_eval, required{idx})
        error('evaluate_step11_5_stage3_alternative_split_recheck:MissingCfgField', ...
            'cfg_eval.%s is required.', required{idx});
    end
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

function split_name = split_name_for_scheme_local(scheme, trial_id, iScenario, Metkl)
unused = iScenario; %#ok<NASGU>
switch lower(char(scheme))
    case 'alt_mod3_validation'
        if mod(trial_id, 3) == 0
            split_name = 'validation';
        else
            split_name = 'calibration';
        end
    case 'alt_tail_block_validation'
        if trial_id > floor(0.60 * Metkl)
            split_name = 'validation';
        else
            split_name = 'calibration';
        end
    case 'repeat_all'
        split_name = 'repeat_all';
    otherwise
        error('evaluate_step11_5_stage3_alternative_split_recheck:UnknownSplitScheme', ...
            'Unknown split scheme: %s.', scheme);
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
char_fields = {'run_label','split_scheme','split_name','config_name','scenario_name', ...
    'adaptive_policy_name','adaptive_confidence','adaptive_boundary_flag','failure_reason'};
for idx = 1:numel(char_fields)
    row.(char_fields{idx}) = '';
end
num_fields = {'row_id','config_id','seed_group_id','seed_offset','trial_id','seed', ...
    'az_center_bias_deg','el_center_bias_deg','truth_az1','truth_az2','truth_el1','truth_el2', ...
    'true_orientation','full_success','fixed_success','adaptive_success','full_rmse','fixed_rmse', ...
    'adaptive_rmse','full_num_pairs','fixed_num_pairs','adaptive_num_pairs','adaptive_num_pairs_coarse', ...
    'adaptive_num_pairs_refine','adaptive_vs_fixed_pair_count_ratio','fixed_full_grid_match', ...
    'adaptive_full_grid_match','fixed_topK_miss','adaptive_topK_miss','fixed_boundary_hit', ...
    'adaptive_boundary_hit','H_norm','gap_13','gap_17','boundary_risk','cond_risk', ...
    'U_search','U_confidence','adaptive_topK','az_window_scale','el_window_scale'};
for idx = 1:numel(num_fields)
    row.(num_fields{idx}) = NaN;
end
end

function row = make_summary_row_template_local()
row = struct();
char_fields = {'summary_scope','run_label','split_scheme','split_name'};
for idx = 1:numel(char_fields)
    row.(char_fields{idx}) = '';
end
num_fields = {'seed_group_id','n_trials','fixed_success','adaptive_success','fixed_rmse', ...
    'adaptive_rmse','fixed_mean_num_pairs','adaptive_mean_num_pairs', ...
    'adaptive_vs_fixed_pair_count_ratio','adaptive_full_grid_match_rate', ...
    'adaptive_topK_miss_rate','adaptive_boundary_hit_rate','max_policy_rate', ...
    'policy_degeneracy_flag','safety_pass_flag','complexity_pass_flag','stage3_pass_flag'};
for idx = 1:numel(num_fields)
    row.(num_fields{idx}) = NaN;
end
end

function scenario_table = normalize_scenarios_local(scenarios)
if istable(scenarios)
    scenario_table = scenarios;
else
    scenario_table = struct2table(scenarios);
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

function value = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = mean(x);
end
end

function value = mean_or_nan_local(x)
if isempty(x)
    value = NaN;
else
    value = mean(x);
end
end

function rate = max_policy_rate_local(policy_names)
if isempty(policy_names)
    rate = NaN;
    return;
end
policies = unique(cellstr(policy_names), 'stable');
rate = 0;
for idx = 1:numel(policies)
    rate = max(rate, mean(strcmp(policy_names, policies{idx})));
end
end
