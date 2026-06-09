function [trial_table, summary_table, config_table, config_summary_table, policy_summary_table, bias_summary_table, selected_recommendation] = evaluate_step11_5_policy_tuning_backend(W, scenarios, cfg_eval, config_table)
%EVALUATE_STEP11_5_POLICY_TUNING_BACKEND Run Stage2 policy tuning scan.
%
% Zero-bias trials scan all explicit configs with calibration/validation
% splits. Bias cases are run only for the selected config. Truth values are
% used only after search outputs are produced.

if nargin < 4
    error('evaluate_step11_5_policy_tuning_backend:NotEnoughInputs', ...
        'W, scenarios, cfg_eval, and config_table are required.');
end
cfg_eval = fill_defaults_local(cfg_eval, W);
validate_cfg_local(cfg_eval);
scenario_table = normalize_scenarios_local(scenarios);
config_table = normalize_config_table_local(config_table, cfg_eval);

zero_bias_cases = [0, 0];
zero_trial_table = run_stage2_trials_local(W, scenario_table, cfg_eval, config_table, zero_bias_cases, 'config_scan');
zero_summary = build_stage2_summary_table_local(zero_trial_table, 'config_scan');
zero_config_summary = build_config_summary_table_local(zero_trial_table, config_table);
selected_recommendation = select_stage2_config_local(zero_config_summary, config_table);

selected_config_table = config_table(config_table.config_id == selected_recommendation.selected_config_id, :);
bias_trial_table = run_stage2_trials_local(W, scenario_table, cfg_eval, selected_config_table, cfg_eval.bias_cases, 'selected_bias');

trial_table = [zero_trial_table; bias_trial_table];
summary_table = [zero_summary; build_stage2_summary_table_local(bias_trial_table, 'selected_bias')];
config_summary_table = zero_config_summary;
policy_summary_table = build_policy_summary_table_local(trial_table, selected_recommendation.selected_config_id);
bias_summary_table = build_bias_summary_table_local(bias_trial_table, selected_recommendation.selected_config_id);
end

function trial_table = run_stage2_trials_local(W, scenario_table, cfg_eval, config_table, bias_cases, run_phase)
manifold_opts = struct('phase_factor', cfg_eval.phase_factor, 'phase_sign', cfg_eval.phase_sign);
search_opts = struct('whitening_mode', cfg_eval.whitening_mode, 'reg', cfg_eval.reg, ...
    'topK_max', cfg_eval.topK_max, 'likelihood_tau', cfg_eval.tau);

total_rows = height(scenario_table) * cfg_eval.Metkl * size(bias_cases, 1) * height(config_table);
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

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
            split_name = split_name_local(trial_id);
            seed_now = cfg_eval.base_seed + 100000 * iBias + 1000 * iScenario + trial_id + cfg_eval.seed_offset;
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

            for iConfig = 1:height(config_table)
                policy_cfg = table_row_to_policy_cfg_local(config_table(iConfig, :), cfg_eval);
                [est_adaptive, debug_adaptive] = search_pair2d_adaptive_topk_window_v2(Z, W, cfg_eval.x, cfg_eval.y, cfg_eval.z, ...
                    cfg_eval.lambda, coarse_grid_cfg, base_refine_cfg, manifold_opts, search_opts, policy_cfg, top_candidates, coarse_debug);
                metrics_adaptive = eval_el_separation_pair_metrics(est_adaptive, az_true, el_true, ...
                    full_grid_cfg.az_bounds, full_grid_cfg.el_bounds, cfg_eval.az_tol_deg, cfg_eval.el_tol_deg, cfg_eval.el_sep_tol_deg);
                compare_adaptive = compare_search_outputs(est_adaptive, est_full, metrics_adaptive, metrics_full, ...
                    'AzMatchTolDeg', cfg_eval.full_search_cfg.az_step / 2, 'ElMatchTolDeg', cfg_eval.full_search_cfg.el_step / 2);
                adaptive_topK_miss = ~topk_covers_full_estimate_local(debug_adaptive.selected_candidates, est_full, ...
                    debug_adaptive.adaptive_refine_cfg);

                row_idx = row_idx + 1;
                trial_rows(row_idx) = make_trial_row_local(row_idx, policy_cfg, split_name, run_phase, iBias, center_bias, ...
                    scenario, trial_id, seed_now, true_orientation, az_true, el_true, metrics_full, metrics_fixed, ...
                    metrics_adaptive, debug_full, fixed_debug, debug_adaptive, compare_fixed, compare_adaptive, ...
                    fixed_topK_miss, adaptive_topK_miss);
            end
        end
    end
end

if row_idx ~= total_rows
    trial_rows = trial_rows(1:row_idx);
end
trial_table = struct2table(trial_rows);
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

function summary_table = build_stage2_summary_table_local(trial_table, source_name)
rows = repmat(make_summary_row_template_local(), 0, 1);
rows(end + 1) = aggregate_subset_local(trial_table, 'config overall', source_name, true(height(trial_table), 1), NaN, '');
config_ids = unique(trial_table.config_id).';
for iConfig = 1:numel(config_ids)
    cid = config_ids(iConfig);
    cfg_mask = trial_table.config_id == cid;
    cname = char_value_local(trial_table.config_name(find(cfg_mask, 1)));
    rows(end + 1) = aggregate_subset_local(trial_table, 'config overall', source_name, cfg_mask, cid, cname);
    rows(end + 1) = aggregate_subset_local(trial_table, 'config calibration', source_name, cfg_mask & strcmp(trial_table.split_name, 'calibration'), cid, cname);
    rows(end + 1) = aggregate_subset_local(trial_table, 'config validation', source_name, cfg_mask & strcmp(trial_table.split_name, 'validation'), cid, cname);
    rows(end + 1) = aggregate_subset_local(trial_table, 'config zero-bias', source_name, cfg_mask & zero_bias_mask_local(trial_table), cid, cname);
    rows(end + 1) = aggregate_subset_local(trial_table, 'config all-bias', source_name, cfg_mask & ~zero_bias_mask_local(trial_table), cid, cname);

    if strcmp(source_name, 'selected_bias')
        bias_pairs = unique(trial_table(cfg_mask, {'az_center_bias_deg','el_center_bias_deg'}), 'rows');
        for iBias = 1:height(bias_pairs)
            mask = cfg_mask & abs(trial_table.az_center_bias_deg - bias_pairs.az_center_bias_deg(iBias)) < 1e-12 & ...
                abs(trial_table.el_center_bias_deg - bias_pairs.el_center_bias_deg(iBias)) < 1e-12;
            label = sprintf('selected config per bias case az=%.2f el=%.2f', ...
                bias_pairs.az_center_bias_deg(iBias), bias_pairs.el_center_bias_deg(iBias));
            rows(end + 1) = aggregate_subset_local(trial_table, label, source_name, mask, cid, cname);
        end
        scenarios = unique(cellstr(trial_table.scenario_name(cfg_mask)), 'stable');
        for iScenario = 1:numel(scenarios)
            mask = cfg_mask & strcmp(trial_table.scenario_name, scenarios{iScenario});
            rows(end + 1) = aggregate_subset_local(trial_table, ['selected config per scenario ', scenarios{iScenario}], source_name, mask, cid, cname);
        end
        policies = {'EASY','NORMAL','SCORE_AMBIGUOUS','BOUNDARY','ILL_CONDITIONED'};
        for iPolicy = 1:numel(policies)
            mask = cfg_mask & strcmp(trial_table.adaptive_policy_name, policies{iPolicy});
            rows(end + 1) = aggregate_subset_local(trial_table, ['selected config per policy ', policies{iPolicy}], source_name, mask, cid, cname);
        end
    end
end
summary_table = struct2table(rows);
end

function config_summary_table = build_config_summary_table_local(trial_table, config_table)
rows = repmat(make_config_summary_row_template_local(), height(config_table), 1);
for idx = 1:height(config_table)
    cid = config_table.config_id(idx);
    cname = char_value_local(config_table.config_name(idx));
    cal = aggregate_values_local(trial_table(trial_table.config_id == cid & strcmp(trial_table.split_name, 'calibration'), :));
    val = aggregate_values_local(trial_table(trial_table.config_id == cid & strcmp(trial_table.split_name, 'validation'), :));
    allz = aggregate_values_local(trial_table(trial_table.config_id == cid, :));
    rows(idx).config_id = cid;
    rows(idx).config_name = cname;
    rows(idx).calibration_fixed_success = cal.fixed_success;
    rows(idx).calibration_adaptive_success = cal.adaptive_success;
    rows(idx).calibration_fixed_rmse = cal.fixed_rmse;
    rows(idx).calibration_adaptive_rmse = cal.adaptive_rmse;
    rows(idx).calibration_fixed_mean_num_pairs = cal.fixed_mean_num_pairs;
    rows(idx).calibration_adaptive_mean_num_pairs = cal.adaptive_mean_num_pairs;
    rows(idx).calibration_pair_count_ratio = cal.adaptive_mean_num_pairs / max(cal.fixed_mean_num_pairs, eps);
    rows(idx).calibration_adaptive_full_grid_match_rate = cal.adaptive_full_grid_match_rate;
    rows(idx).calibration_adaptive_topK_miss_rate = cal.adaptive_topK_miss_rate;
    rows(idx).calibration_adaptive_boundary_hit_rate = cal.adaptive_boundary_hit_rate;
    rows(idx).calibration_policy_degeneracy_flag = cal.policy_degeneracy_flag;
    rows(idx).calibration_safety_pass = safety_pass_local(cal);
    rows(idx).calibration_selectable_pass = rows(idx).calibration_safety_pass && cal.policy_degeneracy_flag == 0;
    rows(idx).validation_fixed_success = val.fixed_success;
    rows(idx).validation_adaptive_success = val.adaptive_success;
    rows(idx).validation_fixed_rmse = val.fixed_rmse;
    rows(idx).validation_adaptive_rmse = val.adaptive_rmse;
    rows(idx).validation_fixed_mean_num_pairs = val.fixed_mean_num_pairs;
    rows(idx).validation_adaptive_mean_num_pairs = val.adaptive_mean_num_pairs;
    rows(idx).validation_pair_count_ratio = val.adaptive_mean_num_pairs / max(val.fixed_mean_num_pairs, eps);
    rows(idx).validation_adaptive_full_grid_match_rate = val.adaptive_full_grid_match_rate;
    rows(idx).validation_adaptive_topK_miss_rate = val.adaptive_topK_miss_rate;
    rows(idx).validation_adaptive_boundary_hit_rate = val.adaptive_boundary_hit_rate;
    rows(idx).validation_policy_degeneracy_flag = val.policy_degeneracy_flag;
    rows(idx).validation_stage2_pass = safety_pass_local(val) && ...
        val.adaptive_mean_num_pairs <= 0.95 * val.fixed_mean_num_pairs && val.policy_degeneracy_flag == 0;
    rows(idx).overall_fixed_mean_num_pairs = allz.fixed_mean_num_pairs;
    rows(idx).overall_adaptive_mean_num_pairs = allz.adaptive_mean_num_pairs;
    rows(idx).overall_pair_count_ratio = allz.adaptive_mean_num_pairs / max(allz.fixed_mean_num_pairs, eps);
    rows(idx).max_policy_rate = allz.max_policy_rate;
    rows(idx).policy_degeneracy_flag = allz.policy_degeneracy_flag;
    rows(idx).is_control_config = logical(config_table.is_control_config(idx));
end
config_summary_table = struct2table(rows);
end

function selected = select_stage2_config_local(config_summary_table, config_table)
eligible = config_summary_table(config_summary_table.calibration_selectable_pass & ~config_summary_table.is_control_config, :);
if ~isempty(eligible)
    [~, order] = sortrows([eligible.calibration_adaptive_mean_num_pairs, eligible.calibration_pair_count_ratio, eligible.config_id]);
    rec = eligible(order(1), :);
    reason = 'calibration_safety_and_non_degenerate_min_candidate_count';
else
    c01 = config_summary_table(strcmp(config_summary_table.config_name, 'C01_normal_only_control'), :);
    if ~isempty(c01) && c01.calibration_safety_pass(1)
        rec = c01(1, :);
        reason = 'no_non_degenerate_config_passed_calibration_use_C01_control_keep_fixed_topK3';
    else
        [~, order] = sortrows([config_summary_table.calibration_adaptive_topK_miss_rate, ...
            config_summary_table.calibration_adaptive_boundary_hit_rate, config_summary_table.calibration_adaptive_mean_num_pairs]);
        rec = config_summary_table(order(1), :);
        reason = 'fallback_best_available_config_safety_not_fully_passed';
    end
end
val_safety_pass = rec.validation_adaptive_success >= rec.validation_fixed_success - 1e-12 && ...
    rec.validation_adaptive_rmse <= rec.validation_fixed_rmse + 1e-12 && ...
    rec.validation_adaptive_topK_miss_rate == 0 && rec.validation_adaptive_boundary_hit_rate == 0 && ...
    rec.validation_adaptive_full_grid_match_rate >= 0.98;
val_complexity_pass = rec.validation_adaptive_mean_num_pairs <= 0.95 * rec.validation_fixed_mean_num_pairs;
val_degen_pass = rec.validation_policy_degeneracy_flag == 0;
stage2_pass = val_safety_pass && val_complexity_pass && val_degen_pass;
if stage2_pass
    next_step = 'use_step11_5_stage2_as_positive_adaptive_enhancement';
elseif val_safety_pass
    next_step = 'keep_step11_3_fixed_topK3_as_default_step11_5_policy_tuning_negative_or_inconclusive';
else
    next_step = 'reject_adaptive_policy_keep_fixed_topK3';
end

selected = struct();
selected.selected_config_id = rec.config_id(1);
selected.selected_config_name = char_value_local(rec.config_name(1));
selected.selection_reason = reason;
selected.validation_safety_pass = double(val_safety_pass);
selected.validation_complexity_pass = double(val_complexity_pass);
selected.validation_policy_degeneracy_pass = double(val_degen_pass);
selected.stage2_adaptive_pass_flag = double(stage2_pass);
selected.recommended_next_step = next_step;
selected.calibration_fixed_success = rec.calibration_fixed_success(1);
selected.calibration_adaptive_success = rec.calibration_adaptive_success(1);
selected.calibration_fixed_rmse = rec.calibration_fixed_rmse(1);
selected.calibration_adaptive_rmse = rec.calibration_adaptive_rmse(1);
selected.calibration_fixed_mean_num_pairs = rec.calibration_fixed_mean_num_pairs(1);
selected.calibration_adaptive_mean_num_pairs = rec.calibration_adaptive_mean_num_pairs(1);
selected.calibration_pair_count_ratio = rec.calibration_pair_count_ratio(1);
selected.calibration_adaptive_full_grid_match_rate = rec.calibration_adaptive_full_grid_match_rate(1);
selected.calibration_adaptive_topK_miss_rate = rec.calibration_adaptive_topK_miss_rate(1);
selected.calibration_adaptive_boundary_hit_rate = rec.calibration_adaptive_boundary_hit_rate(1);
selected.calibration_policy_degeneracy_flag = rec.calibration_policy_degeneracy_flag(1);
selected.validation_fixed_success = rec.validation_fixed_success(1);
selected.validation_adaptive_success = rec.validation_adaptive_success(1);
selected.validation_fixed_rmse = rec.validation_fixed_rmse(1);
selected.validation_adaptive_rmse = rec.validation_adaptive_rmse(1);
selected.validation_fixed_mean_num_pairs = rec.validation_fixed_mean_num_pairs(1);
selected.validation_adaptive_mean_num_pairs = rec.validation_adaptive_mean_num_pairs(1);
selected.validation_pair_count_ratio = rec.validation_pair_count_ratio(1);
selected.validation_adaptive_full_grid_match_rate = rec.validation_adaptive_full_grid_match_rate(1);
selected.validation_adaptive_topK_miss_rate = rec.validation_adaptive_topK_miss_rate(1);
selected.validation_adaptive_boundary_hit_rate = rec.validation_adaptive_boundary_hit_rate(1);
selected.validation_policy_degeneracy_flag = rec.validation_policy_degeneracy_flag(1);
unused = config_table; %#ok<NASGU>
end

function policy_summary_table = build_policy_summary_table_local(trial_table, selected_config_id)
sub = trial_table(trial_table.config_id == selected_config_id, :);
policies = {'EASY','NORMAL','SCORE_AMBIGUOUS','BOUNDARY','ILL_CONDITIONED'};
rows = repmat(struct('policy_name', '', 'n_trials', 0, 'policy_rate', NaN, ...
    'success_rate', NaN, 'mean_num_pairs', NaN, 'mean_U_search', NaN, 'mean_U_confidence', NaN), numel(policies), 1);
for idx = 1:numel(policies)
    mask = strcmp(sub.adaptive_policy_name, policies{idx});
    rows(idx).policy_name = policies{idx};
    rows(idx).n_trials = nnz(mask);
    rows(idx).policy_rate = nnz(mask) / max(height(sub), 1);
    rows(idx).success_rate = mean_or_nan_local(sub.adaptive_success(mask));
    rows(idx).mean_num_pairs = mean_omitnan_local(sub.adaptive_num_pairs(mask));
    rows(idx).mean_U_search = mean_omitnan_local(sub.U_search(mask));
    rows(idx).mean_U_confidence = mean_omitnan_local(sub.U_confidence(mask));
end
policy_summary_table = struct2table(rows);
end

function bias_summary_table = build_bias_summary_table_local(trial_table, selected_config_id)
sub = trial_table(trial_table.config_id == selected_config_id, :);
bias_pairs = unique(sub(:, {'az_center_bias_deg','el_center_bias_deg'}), 'rows');
rows = repmat(struct('bias_case_id', NaN, 'az_center_bias_deg', NaN, 'el_center_bias_deg', NaN, ...
    'n_trials', NaN, 'fixed_success', NaN, 'adaptive_success', NaN, 'adaptive_success_drop_vs_zero', NaN, ...
    'adaptive_topK_miss_rate', NaN, 'adaptive_boundary_hit_rate', NaN, 'adaptive_full_grid_match_rate', NaN, ...
    'adaptive_mean_num_pairs', NaN, 'bias_robustness_pass_020', false), height(bias_pairs), 1);
zero_mask = zero_bias_mask_local(sub);
zero_success = mean_or_nan_local(sub.adaptive_success(zero_mask));
for idx = 1:height(bias_pairs)
    mask = abs(sub.az_center_bias_deg - bias_pairs.az_center_bias_deg(idx)) < 1e-12 & ...
        abs(sub.el_center_bias_deg - bias_pairs.el_center_bias_deg(idx)) < 1e-12;
    rows(idx).bias_case_id = idx;
    rows(idx).az_center_bias_deg = bias_pairs.az_center_bias_deg(idx);
    rows(idx).el_center_bias_deg = bias_pairs.el_center_bias_deg(idx);
    rows(idx).n_trials = nnz(mask);
    rows(idx).fixed_success = mean_or_nan_local(sub.fixed_success(mask));
    rows(idx).adaptive_success = mean_or_nan_local(sub.adaptive_success(mask));
    rows(idx).adaptive_success_drop_vs_zero = zero_success - rows(idx).adaptive_success;
    rows(idx).adaptive_topK_miss_rate = mean_or_nan_local(sub.adaptive_topK_miss(mask));
    rows(idx).adaptive_boundary_hit_rate = mean_or_nan_local(sub.adaptive_boundary_hit(mask));
    rows(idx).adaptive_full_grid_match_rate = mean_or_nan_local(sub.adaptive_full_grid_match(mask));
    rows(idx).adaptive_mean_num_pairs = mean_omitnan_local(sub.adaptive_num_pairs(mask));
    in020 = abs(rows(idx).az_center_bias_deg) <= 0.20 + 1e-12 && abs(rows(idx).el_center_bias_deg) <= 0.20 + 1e-12;
    rows(idx).bias_robustness_pass_020 = in020 && rows(idx).adaptive_topK_miss_rate == 0 && ...
        rows(idx).adaptive_boundary_hit_rate == 0 && rows(idx).adaptive_success_drop_vs_zero <= 0.06 + 1e-12;
end
bias_summary_table = struct2table(rows);
end

function row = make_trial_row_template_local()
row = struct();
char_fields = {'config_name','split_name','run_phase','scenario_name','adaptive_policy_name', ...
    'adaptive_confidence','adaptive_boundary_flag','failure_reason'};
for idx = 1:numel(char_fields)
    row.(char_fields{idx}) = '';
end
num_fields = {'row_id','config_id','trial_id','seed','bias_case_id','az_center_bias_deg','el_center_bias_deg', ...
    'truth_az1','truth_az2','truth_el1','truth_el2','true_orientation','full_success','fixed_success', ...
    'adaptive_success','full_rmse','fixed_rmse','adaptive_rmse','full_num_pairs','fixed_num_pairs', ...
    'adaptive_num_pairs','adaptive_num_pairs_coarse','adaptive_num_pairs_refine','adaptive_vs_fixed_pair_count_ratio', ...
    'fixed_full_grid_match','adaptive_full_grid_match','fixed_topK_miss','adaptive_topK_miss', ...
    'fixed_boundary_hit','adaptive_boundary_hit','H_norm','gap_13','gap_17','boundary_risk','cond_risk', ...
    'U_search','U_confidence','adaptive_topK','az_window_scale','el_window_scale'};
for idx = 1:numel(num_fields)
    row.(num_fields{idx}) = NaN;
end
end

function row = make_trial_row_local(row_id, policy_cfg, split_name, run_phase, bias_case_id, center_bias, scenario, trial_id, ...
    seed_now, true_orientation, az_true, el_true, metrics_full, metrics_fixed, metrics_adaptive, debug_full, fixed_debug, ...
    debug_adaptive, compare_fixed, compare_adaptive, fixed_topK_miss, adaptive_topK_miss)
row = make_trial_row_template_local();
row.row_id = row_id;
row.config_id = policy_cfg.config_id;
row.config_name = policy_cfg.config_name;
row.split_name = split_name;
row.run_phase = run_phase;
row.scenario_name = scenario.scenario_name;
row.trial_id = trial_id;
row.seed = seed_now;
row.bias_case_id = bias_case_id;
row.az_center_bias_deg = center_bias(1);
row.el_center_bias_deg = center_bias(2);
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
row.adaptive_num_pairs_coarse = debug_adaptive.num_pairs_coarse;
row.adaptive_num_pairs_refine = debug_adaptive.num_pairs_refine;
row.adaptive_vs_fixed_pair_count_ratio = row.adaptive_num_pairs / max(row.fixed_num_pairs, eps);
row.fixed_full_grid_match = double(compare_fixed.same_as_full_grid);
row.adaptive_full_grid_match = double(compare_adaptive.same_as_full_grid);
row.fixed_topK_miss = double(fixed_topK_miss);
row.adaptive_topK_miss = double(adaptive_topK_miss);
row.fixed_boundary_hit = double(metrics_fixed.boundary_hit);
row.adaptive_boundary_hit = double(metrics_adaptive.boundary_hit);
row.adaptive_policy_name = debug_adaptive.policy.policy_name;
row.adaptive_confidence = debug_adaptive.confidence;
row.adaptive_boundary_flag = debug_adaptive.boundary_flag;
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

function row = make_summary_row_template_local()
row = struct();
row.summary_scope = '';
row.source_name = '';
row.config_id = NaN;
row.config_name = '';
fields = {'n_trials','fixed_success','adaptive_success','fixed_rmse','adaptive_rmse', ...
    'fixed_mean_num_pairs','adaptive_mean_num_pairs','adaptive_vs_fixed_pair_count_ratio', ...
    'adaptive_full_grid_match_rate','adaptive_topK_miss_rate','adaptive_boundary_hit_rate', ...
    'policy_degeneracy_flag','max_policy_rate'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
end

function row = aggregate_subset_local(T, scope, source_name, mask, config_id, config_name)
row = make_summary_row_template_local();
row.summary_scope = scope;
row.source_name = source_name;
row.config_id = config_id;
row.config_name = config_name;
if ~any(mask)
    row.n_trials = 0;
    return;
end
vals = aggregate_values_local(T(mask, :));
names = fieldnames(vals);
for idx = 1:numel(names)
    row.(names{idx}) = vals.(names{idx});
end
end

function vals = aggregate_values_local(T)
vals = struct();
vals.n_trials = height(T);
vals.fixed_success = mean_or_nan_local(T.fixed_success);
vals.adaptive_success = mean_or_nan_local(T.adaptive_success);
vals.fixed_rmse = mean_omitnan_local(T.fixed_rmse);
vals.adaptive_rmse = mean_omitnan_local(T.adaptive_rmse);
vals.fixed_mean_num_pairs = mean_omitnan_local(T.fixed_num_pairs);
vals.adaptive_mean_num_pairs = mean_omitnan_local(T.adaptive_num_pairs);
vals.adaptive_vs_fixed_pair_count_ratio = vals.adaptive_mean_num_pairs / max(vals.fixed_mean_num_pairs, eps);
vals.adaptive_full_grid_match_rate = mean_or_nan_local(T.adaptive_full_grid_match);
vals.adaptive_topK_miss_rate = mean_or_nan_local(T.adaptive_topK_miss);
vals.adaptive_boundary_hit_rate = mean_or_nan_local(T.adaptive_boundary_hit);
policies = unique(cellstr(T.adaptive_policy_name), 'stable');
max_rate = 0;
for idx = 1:numel(policies)
    max_rate = max(max_rate, mean(strcmp(T.adaptive_policy_name, policies{idx})));
end
vals.max_policy_rate = max_rate;
vals.policy_degeneracy_flag = double(max_rate >= 0.95);
end

function row = make_config_summary_row_template_local()
row = struct();
row.config_id = NaN;
row.config_name = '';
fields = {'calibration_fixed_success','calibration_adaptive_success','calibration_fixed_rmse', ...
    'calibration_adaptive_rmse','calibration_fixed_mean_num_pairs','calibration_adaptive_mean_num_pairs', ...
    'calibration_pair_count_ratio','calibration_adaptive_full_grid_match_rate','calibration_adaptive_topK_miss_rate', ...
    'calibration_adaptive_boundary_hit_rate','calibration_policy_degeneracy_flag','calibration_safety_pass', ...
    'calibration_selectable_pass','validation_fixed_success','validation_adaptive_success','validation_fixed_rmse', ...
    'validation_adaptive_rmse','validation_fixed_mean_num_pairs','validation_adaptive_mean_num_pairs', ...
    'validation_pair_count_ratio','validation_adaptive_full_grid_match_rate','validation_adaptive_topK_miss_rate', ...
    'validation_adaptive_boundary_hit_rate','validation_policy_degeneracy_flag','validation_stage2_pass', ...
    'overall_fixed_mean_num_pairs','overall_adaptive_mean_num_pairs','overall_pair_count_ratio','max_policy_rate', ...
    'policy_degeneracy_flag','is_control_config'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
end

function tf = safety_pass_local(vals)
tf = vals.adaptive_success >= vals.fixed_success - 1e-12 && ...
    vals.adaptive_rmse <= vals.fixed_rmse + 1e-12 && ...
    vals.adaptive_topK_miss_rate == 0 && ...
    vals.adaptive_boundary_hit_rate == 0 && ...
    vals.adaptive_full_grid_match_rate >= 0.98;
end

function cfg_eval = fill_defaults_local(cfg_eval, W)
if ~isfield(cfg_eval, 'el_center_offset')
    cfg_eval.el_center_offset = 0.31;
end
if ~isfield(cfg_eval, 'bias_cases')
    cfg_eval.bias_cases = [0, 0; 0.2, 0; -0.2, 0; 0, 0.2; 0, -0.2; 0.2, 0.2; -0.2, -0.2];
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
    cfg_eval.seed_offset = 0;
end
if ~isfield(cfg_eval, 'B')
    cfg_eval.B = size(W, 2);
end
end

function validate_cfg_local(cfg_eval)
required = {'x','y','z','lambda','phase_factor','phase_sign','az_center_true','el_center_nominal', ...
    'L','Metkl','base_seed','full_search_cfg','coarse_search_cfg','base_refine_cfg'};
for idx = 1:numel(required)
    if ~isfield(cfg_eval, required{idx})
        error('evaluate_step11_5_policy_tuning_backend:MissingCfgField', 'cfg_eval.%s is required.', required{idx});
    end
end
if cfg_eval.Metkl < 10
    error('evaluate_step11_5_policy_tuning_backend:MetklTooSmall', 'Metkl must not be lower than 10.');
end
end

function config_table = normalize_config_table_local(config_table, cfg_eval)
if ~ismember('topK_max', config_table.Properties.VariableNames)
    config_table.topK_max = repmat(cfg_eval.topK_max, height(config_table), 1);
end
if ~ismember('tau', config_table.Properties.VariableNames)
    config_table.tau = repmat(cfg_eval.tau, height(config_table), 1);
end
if ~ismember('is_control_config', config_table.Properties.VariableNames)
    config_table.is_control_config = false(height(config_table), 1);
end
end

function policy_cfg = table_row_to_policy_cfg_local(row, cfg_eval)
names = row.Properties.VariableNames;
policy_cfg = struct();
for idx = 1:numel(names)
    value = row.(names{idx});
    if iscell(value)
        value = value{1};
    elseif isstring(value)
        value = char(value);
    end
    policy_cfg.(names{idx}) = value;
end
policy_cfg.topK_max = cfg_eval.topK_max;
policy_cfg.tau = cfg_eval.tau;
end

function refine_cfg = normalize_refine_cfg_local(refine_cfg)
if ~isfield(refine_cfg, 'local_el_center_half_width') && isfield(refine_cfg, 'local_el_half_width')
    refine_cfg.local_el_center_half_width = refine_cfg.local_el_half_width;
end
if ~isfield(refine_cfg, 'fine_el_sep_deg_list') && isfield(refine_cfg, 'el_sep_deg_list')
    refine_cfg.fine_el_sep_deg_list = refine_cfg.el_sep_deg_list;
end
end

function split_name = split_name_local(trial_id)
if mod(trial_id, 2) == 1
    split_name = 'calibration';
else
    split_name = 'validation';
end
end

function mask = zero_bias_mask_local(T)
mask = abs(T.az_center_bias_deg) < 1e-12 & abs(T.el_center_bias_deg) < 1e-12;
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

function v = mean_or_nan_local(x)
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end
