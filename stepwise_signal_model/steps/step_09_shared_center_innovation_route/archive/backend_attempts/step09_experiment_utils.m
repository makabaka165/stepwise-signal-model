function varargout = step09_experiment_utils(action, varargin)
%STEP09_EXPERIMENT_UTILS Shared utilities for Step 09 supplementary tests.

switch lower(action)
    case 'run_formal_mc'
        result = run_formal_mc_local(varargin{:});
    case 'run_consistency'
        result = run_consistency_local(varargin{:});
    case 'run_ablation'
        result = run_ablation_local(varargin{:});
    otherwise
        error('step09_experiment_utils:UnknownAction', 'Unknown action: %s', action);
end

if nargout > 0
    varargout{1} = result;
end
end

function result = run_formal_mc_local(script_dir, run_mode)
    t_start = tic;
    addpath(fullfile(script_dir, 'main'));
    result_dir = fullfile(script_dir, 'archive', 'diagnostic_results', 'results_step09_formal_mc');
    ensure_dir_local(result_dir);
    rng_seed_base = 902091;
    [Metkl, snr_list] = mode_settings_local(run_mode, 'formal_mc');
    rng(rng_seed_base, 'twister');

    base_cfg = make_base_cfg_local();
    array_geom = make_array_geom_local(base_cfg);
    cases = build_formal_cases_local(run_mode, snr_list, base_cfg);
    rows = cell(numel(cases) * Metkl, 1);
    irow = 0;
    for icase = 1:numel(cases)
        sc = cases(icase);
        for imc = 1:Metkl
            trial_index = irow + 1;
            rng_seed = rng_seed_base + trial_index;
            rng(rng_seed, 'twister');
            [raw_cube, frontend_out, truth, cfg] = synthesize_step09_trial_cube_local(array_geom, sc, base_cfg, rng_seed);
            t_trial = tic;
            out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
            runtime_sec = toc(t_trial);
            eval_info = evaluate_step09_output_local(out, truth, sc);
            irow = irow + 1;
            rows{irow} = make_formal_trial_row_local(run_mode, trial_index, rng_seed, sc, truth, frontend_out, out, eval_info, runtime_sec);
        end
    end
    trial_tbl = struct2table([rows{1:irow}]);
    summary_tbl = summarize_trials_local(trial_tbl, {'scenario_name', 'SNR_dB'});
    summary_scenario_tbl = summarize_trials_local(trial_tbl, {'scenario_name'});
    keypoints_tbl = formal_keypoints_local(trial_tbl, run_mode, rng_seed_base, Metkl, snr_list, base_cfg);

    writetable(trial_tbl, fullfile(result_dir, 'step09_formal_mc_trials.csv'));
    writetable(summary_tbl, fullfile(result_dir, 'step09_formal_mc_summary.csv'));
    writetable(summary_scenario_tbl, fullfile(result_dir, 'step09_formal_mc_summary_by_scenario.csv'));
    writetable(keypoints_tbl, fullfile(result_dir, 'step09_formal_mc_keypoints.csv'));

    plot_success_vs_snr_local(summary_tbl, fullfile(result_dir, 'step09_success_vs_snr.png'));
    plot_false_high_vs_snr_local(summary_tbl, fullfile(result_dir, 'step09_false_high_vs_snr.png'));
    plot_route_distribution_local(trial_tbl, fullfile(result_dir, 'step09_route_distribution.png'));
    plot_low_conf_boundary_local(trial_tbl, fullfile(result_dir, 'step09_low_confidence_boundary_rates.png'));
    plot_coarse_bias_local(trial_tbl, fullfile(result_dir, 'step09_coarseAz_bias_sweep.png'));
    plot_runtime_distribution_local(trial_tbl, fullfile(result_dir, 'step09_runtime_distribution.png'));

    write_formal_report_local(script_dir, result_dir, keypoints_tbl, summary_scenario_tbl, run_mode, Metkl, snr_list, toc(t_start));
    result = make_result_struct_local('formal_mc', result_dir, keypoint_value_local(keypoints_tbl, 'formal_mc_pass_flag'), ...
        keypoint_note_local(keypoints_tbl, 'blocker_if_any'), toc(t_start));
end

function result = run_consistency_local(script_dir, run_mode)
    t_start = tic;
    addpath(fullfile(script_dir, 'main'));
    result_dir = fullfile(script_dir, 'archive', 'diagnostic_results', 'results_step09_vs_step87_consistency');
    ensure_dir_local(result_dir);
    rng_seed_base = 902187;
    [Metkl, snr_list] = mode_settings_local(run_mode, 'consistency');
    base_cfg = make_base_cfg_local();
    array_geom = make_array_geom_local(base_cfg);
    cases = build_consistency_cases_local(snr_list, base_cfg);
    [old_callable, attempted_old_entry, blocker] = detect_step87_callable_local(script_dir);

    rows = cell(numel(cases) * Metkl, 1);
    irow = 0;
    for icase = 1:numel(cases)
        sc = cases(icase);
        for imc = 1:Metkl
            trial_index = irow + 1;
            rng_seed = rng_seed_base + trial_index;
            [raw_cube, frontend_out, truth, cfg] = synthesize_step09_trial_cube_local(array_geom, sc, base_cfg, rng_seed);
            new_out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
            new_eval = evaluate_step09_output_local(new_out, truth, sc);
            old_out = make_missing_old_output_local(blocker);
            old_eval = make_empty_eval_local();
            if old_callable
                try
                    old_out = call_step87_reference_route_local(raw_cube, frontend_out, array_geom, cfg); %#ok<UNRCH>
                    old_eval = evaluate_step09_output_local(old_out, truth, sc);
                catch ME
                    old_callable = false;
                    blocker = ['step87_call_failed:', ME.identifier];
                    old_out = make_missing_old_output_local(blocker);
                    old_eval = make_empty_eval_local();
                end
            end
            irow = irow + 1;
            rows{irow} = make_consistency_trial_row_local(trial_index, sc, old_callable, old_out, new_out, old_eval, new_eval);
        end
    end

    trial_tbl = struct2table([rows{1:irow}]);
    summary_tbl = summarize_consistency_local(trial_tbl);
    keypoints_tbl = consistency_keypoints_local(trial_tbl, old_callable, attempted_old_entry, blocker);
    confusion_tbl = route_confusion_local(trial_tbl);
    writetable(trial_tbl, fullfile(result_dir, 'step09_vs_step87_trials.csv'));
    writetable(summary_tbl, fullfile(result_dir, 'step09_vs_step87_summary.csv'));
    writetable(keypoints_tbl, fullfile(result_dir, 'step09_vs_step87_keypoints.csv'));
    writetable(confusion_tbl, fullfile(result_dir, 'step09_vs_step87_route_confusion.csv'));

    plot_consistency_blocker_local(keypoints_tbl, fullfile(result_dir, 'step09_vs_step87_callable_status.png'));
    plot_new_route_distribution_local(trial_tbl, fullfile(result_dir, 'step09_vs_step87_new_route_distribution.png'));
    plot_new_status_distribution_local(trial_tbl, fullfile(result_dir, 'step09_vs_step87_new_status_distribution.png'));
    write_consistency_report_local(script_dir, result_dir, keypoints_tbl, summary_tbl);

    result = make_result_struct_local('step09_vs_step87_consistency', result_dir, ...
        keypoint_value_local(keypoints_tbl, 'consistency_pass_flag'), blocker, toc(t_start));
end

function result = run_ablation_local(script_dir, run_mode)
    t_start = tic;
    addpath(fullfile(script_dir, 'main'));
    result_dir = fullfile(script_dir, 'archive', 'diagnostic_results', 'results_step09_ablation');
    ensure_dir_local(result_dir);
    rng_seed_base = 902333;
    [Metkl, snr_list] = mode_settings_local(run_mode, 'ablation');
    base_cfg = make_base_cfg_local();
    array_geom = make_array_geom_local(base_cfg);
    cases = build_ablation_cases_local(snr_list, base_cfg);
    modes = {'music_only', 'music_plus_rank1', 'music_plus_2d', 'full_step09', 'full_without_rejector'};

    rows = cell(numel(cases) * Metkl * numel(modes), 1);
    irow = 0;
    for imode = 1:numel(modes)
        ablation_mode = modes{imode};
        for icase = 1:numel(cases)
            sc = cases(icase);
            for imc = 1:Metkl
                trial_index = irow + 1;
                rng_seed = rng_seed_base + icase * 100000 + imc;
                [raw_cube, frontend_out, truth, cfg] = synthesize_step09_trial_cube_local(array_geom, sc, base_cfg, rng_seed);
                cfg = apply_ablation_cfg_local(cfg, ablation_mode);
                t_trial = tic;
                out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
                runtime_sec = toc(t_trial);
                eval_info = evaluate_step09_output_local(out, truth, sc);
                irow = irow + 1;
                rows{irow} = make_ablation_trial_row_local(ablation_mode, run_mode, trial_index, rng_seed, sc, truth, frontend_out, out, eval_info, runtime_sec);
            end
        end
    end

    trial_tbl = struct2table([rows{1:irow}]);
    summary_tbl = summarize_trials_local(trial_tbl, {'ablation_mode', 'scenario_name'});
    keypoints_tbl = ablation_keypoints_local(trial_tbl);
    route_tbl = summarize_trials_local(trial_tbl, {'ablation_mode', 'scenario_name', 'route_name'});
    writetable(trial_tbl, fullfile(result_dir, 'step09_ablation_trials.csv'));
    writetable(summary_tbl, fullfile(result_dir, 'step09_ablation_summary.csv'));
    writetable(keypoints_tbl, fullfile(result_dir, 'step09_ablation_keypoints.csv'));
    writetable(route_tbl, fullfile(result_dir, 'step09_ablation_route_distribution.csv'));

    plot_ablation_metric_local(summary_tbl, 'success_rate', fullfile(result_dir, 'ablation_success_by_scenario.png'));
    plot_ablation_metric_local(summary_tbl, 'false_high_rate', fullfile(result_dir, 'ablation_false_high_by_scenario.png'));
    plot_ablation_metric_local(summary_tbl, 'boundary_missed_rate', fullfile(result_dir, 'ablation_boundary_missed_by_scenario.png'));
    plot_ablation_runtime_local(trial_tbl, fullfile(result_dir, 'ablation_runtime_by_mode.png'));
    plot_ablation_low_conf_local(summary_tbl, fullfile(result_dir, 'ablation_low_confidence_by_mode.png'));
    write_ablation_report_local(script_dir, result_dir, keypoints_tbl, summary_tbl);

    result = make_result_struct_local('ablation', result_dir, keypoint_value_local(keypoints_tbl, 'ablation_pass_flag'), ...
        keypoint_note_local(keypoints_tbl, 'blocker_if_any'), toc(t_start));
end

function [Metkl, snr_list] = mode_settings_local(run_mode, experiment_name)
    switch lower(run_mode)
        case 'formal'
            Metkl = 200;
            snr_list = [0, 4, 8, 12, 16, 20];
        case 'stress'
            Metkl = 500;
            snr_list = [0, 4, 8, 12, 16, 20];
        otherwise
            if strcmp(experiment_name, 'consistency')
                Metkl = 10;
            else
                Metkl = 30;
            end
            snr_list = [8, 16];
    end
end

function cfg = make_base_cfg_local()
    cfg = struct();
    cfg.lambda = 1;
    cfg.Naz = 192;
    cfg.Nel = 32;
    cfg.radius = 14;
    cfg.dz = 0.45;
    cfg.Np = 32;
    cfg.Q_work_columns = 65;
    cfg.num_sources = 2;
    cfg.derotation_mode = 'none';
    cfg.az_grid_half_span_deg = 1.5;
    cfg.az_grid_step_deg = 0.05;
    cfg.el_grid_half_span_deg = 9;
    cfg.el_grid_step_deg = 0.5;
    cfg.min_pair_sep_deg = 0.12;
    cfg.max_pair_sep_deg = 1.2;
    cfg.music_peak2_ratio_min = 0.32;
    cfg.music_2d_peak2_ratio_min = 0.18;
    cfg.coherent_min_projection_score = 0.45;
    cfg.coherent_min_score_margin = 0;
    cfg.coherent_music_peak2_ratio_min = 0.08;
    cfg.rank1_lambda2_over_lambda1_max = 0.35;
end

function array_geom = make_array_geom_local(cfg)
    phiCol = (0:cfg.Naz - 1) / cfg.Naz * 360;
    zRow = (0:cfg.Nel - 1) * cfg.dz;
    X = zeros(cfg.Naz, cfg.Nel);
    Y = zeros(cfg.Naz, cfg.Nel);
    Z = zeros(cfg.Naz, cfg.Nel);
    for k = 1:cfg.Naz
        X(k, :) = cfg.radius * cosd(phiCol(k));
        Y(k, :) = cfg.radius * sind(phiCol(k));
        Z(k, :) = zRow;
    end
    array_geom = struct('phiCol', phiCol, 'X', X, 'Y', Y, 'Z', Z, ...
        'lambda', cfg.lambda, 'Naz', cfg.Naz, 'Nel', cfg.Nel);
end

function cases = build_formal_cases_local(run_mode, snr_list, base_cfg)
    cases = repmat(make_case_local('__template__', NaN, 0, [], [], NaN, NaN, NaN, ...
        NaN, NaN, NaN, NaN, base_cfg.Np, 'template', false, false, false), 0, 1);
    for isnr = 1:numel(snr_list)
        snr = snr_list(isnr);
        cases(end+1) = make_case_local('single_target_sanity', snr, 1, 0, 0, NaN, NaN, NaN, 0, 0, 0, 0, base_cfg.Np, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
        sep_list = [0.15, 0.25, 0.40, 0.60, 0.80, 1.00];
        for i = 1:numel(sep_list)
            beta = 1.0 - 0.2 * mod(i, 2);
            phase_deg = 60 * mod(i, 2);
            cases(end+1) = make_case_local('close_coherent_pair', snr, 2, [-sep_list(i)/2, sep_list(i)/2], [0, 0], beta, 1, phase_deg, sep_list(i), 0, 0, 0, base_cfg.Np, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
        end
        beta_list = [0.8, 0.5, 0.3];
        for i = 1:numel(beta_list)
            cases(end+1) = make_case_local('medium_beta_pair', snr, 2, [-0.25, 0.25], [0, 0], beta_list(i), 1, 0, 0.5, 0, 0, 0, base_cfg.Np, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
        end
        cases(end+1) = make_case_local('weak_target_boundary', snr, 2, [-0.25, 0.25], [0, 0], 0.1, 1, 0, 0.5, 0, 0, 0, base_cfg.Np, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
        for phase_deg = [150, 180]
            cases(end+1) = make_case_local('near_antiphase_boundary', snr, 2, [-0.25, 0.25], [0, 0], 1, 1, phase_deg, 0.5, 0, 0, 0, base_cfg.Np, 'single_peak_in_scope', true, false, true); %#ok<AGROW>
        end
        for el_sep = [2, 3, 5, 8]
            cases(end+1) = make_case_local('large_el_pair', snr, 2, [-0.28, 0.28], [0, el_sep], 0.9, 0.5, 0, 0.56, el_sep, 0, 2.5, base_cfg.Np, 'single_peak_in_scope', true, true, false); %#ok<AGROW>
        end
        cases(end+1) = make_case_local('two_separated_coarse_peaks', snr, 2, [-2, 2], [0, 0], 1, 0, 0, 4, 0, 0, 0, base_cfg.Np, 'two_separated_peaks_out_of_scope', false, false, false); %#ok<AGROW>
        for coarse_err = [-1, -0.5, 0, 0.5, 1]
            cases(end+1) = make_case_local('coarseAz_bias_sweep', snr, 2, [-0.25, 0.25], [0, 0], 1, 1, 0, 0.5, 0, coarse_err, 0, base_cfg.Np, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
        end
        for coarse_az = [0, 359]
            target_az = wrap180_vec_local([coarse_az - 0.20, coarse_az + 0.20]);
            cases(end+1) = make_case_local('center_wraparound_case', snr, 2, target_az, [0, 0], 1, 1, 0, 0.4, 0, 0, coarse_az, base_cfg.Np, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
        end
    end
    if strcmpi(run_mode, 'stress')
        keep = ismember(string({cases.scenario_name}), ["close_coherent_pair", "medium_beta_pair", "weak_target_boundary", "near_antiphase_boundary", "large_el_pair"]);
        cases = cases(keep);
    end
end

function cases = build_ablation_cases_local(snr_list, base_cfg)
    all_cases = build_formal_cases_local('quick', snr_list, base_cfg);
    cases = repmat(all_cases(1), 0, 1);
    for isnr = 1:numel(snr_list)
        snr = snr_list(isnr);
        cases(end+1) = select_case_local(all_cases, snr, "single_target_sanity", "", NaN); %#ok<AGROW>
        cases(end+1) = select_case_local(all_cases, snr, "close_coherent_pair", "az_sep_deg", 0.60); %#ok<AGROW>
        cases(end+1) = select_case_local(all_cases, snr, "medium_beta_pair", "beta", 0.5); %#ok<AGROW>
        cases(end+1) = select_case_local(all_cases, snr, "weak_target_boundary", "", NaN); %#ok<AGROW>
        cases(end+1) = select_case_local(all_cases, snr, "near_antiphase_boundary", "phase_deg", 180); %#ok<AGROW>
        cases(end+1) = select_case_local(all_cases, snr, "large_el_pair", "el_sep_deg", 5); %#ok<AGROW>
        cases(end+1) = select_case_local(all_cases, snr, "two_separated_coarse_peaks", "", NaN); %#ok<AGROW>
    end
end

function cases = build_consistency_cases_local(snr_list, base_cfg)
    all_cases = build_ablation_cases_local(snr_list, base_cfg);
    cases = all_cases(1:min(numel(all_cases), 12));
end

function sc = select_case_local(cases, snr, scenario_name, field_name, field_value)
    mask = [cases.SNR_dB] == snr & string({cases.scenario_name}) == scenario_name;
    if strlength(field_name) > 0
        vals = [cases.(char(field_name))];
        mask = mask & abs(vals - field_value) < 1e-9;
    end
    idx = find(mask, 1);
    if isempty(idx)
        error('step09:MissingExperimentCase', ...
            'Missing ablation case scenario=%s SNR=%g field=%s.', scenario_name, snr, field_name);
    end
    sc = cases(idx);
end

function sc = make_case_local(name, snr_db, target_count, az, el, beta, rho, phase_deg, az_sep, el_sep, coarse_err, coarse_az, Np, state, unresolved, need2d, boundary)
    sc = struct();
    sc.scenario_name = char(name);
    sc.SNR_dB = snr_db;
    sc.target_count = target_count;
    sc.az = az;
    sc.el = el;
    sc.beta = beta;
    sc.rho = rho;
    sc.phase_deg = phase_deg;
    sc.az_sep_deg = az_sep;
    sc.el_sep_deg = el_sep;
    sc.coarseAz_error = coarse_err;
    sc.coarseAz = coarse_az + coarse_err;
    sc.coarseEl = coarse_el_from_truth_local(el);
    sc.Np = Np;
    sc.frontend_state = char(state);
    sc.unresolved_cluster_flag = unresolved;
    sc.need_2d_refinement = need2d;
    sc.boundary_unreliable_flag = boundary;
end

function el0 = coarse_el_from_truth_local(el)
    if isempty(el) || any(isnan(el))
        el0 = 0;
    else
        el0 = mean(el);
    end
end

function [raw_cube, frontend_out, truth, cfg] = synthesize_step09_trial_cube_local(array_geom, sc, base_cfg, rng_seed)
    rng(rng_seed, 'twister');
    cfg = base_cfg;
    cfg.Np = sc.Np;
    cfg.coarseEl = sc.coarseEl;
    raw_cube_clean = zeros(array_geom.Naz, array_geom.Nel, sc.Np);
    p = 0:sc.Np-1;
    s1 = exp(1j * 2 * pi * 0.07 * p);
    signals = zeros(max(1, sc.target_count), sc.Np);
    signals(1, :) = s1;
    if sc.target_count >= 2
        beta = sc.beta;
        rho = sc.rho;
        phase = exp(1j * deg2rad(sc.phase_deg));
        if rho >= 1
            s2 = beta * phase * s1;
        else
            v = exp(1j * (2 * pi * 0.19 * p + 2 * pi * rand()));
            s2 = beta * phase * (rho * s1 + sqrt(max(0, 1 - rho^2)) * v);
        end
        signals(2, :) = s2;
    end
    for it = 1:sc.target_count
        a = steering_full_local(array_geom, sc.az(it), sc.el(it));
        for ip = 1:sc.Np
            raw_cube_clean(:, :, ip) = raw_cube_clean(:, :, ip) + a * signals(it, ip);
        end
    end
    clean_power = mean(abs(raw_cube_clean(:)).^2);
    noise_power = clean_power / max(10^(sc.SNR_dB / 10), eps);
    noise = sqrt(noise_power / 2) * (randn(size(raw_cube_clean)) + 1j * randn(size(raw_cube_clean)));
    raw_cube = raw_cube_clean + noise;
    frontend_out = struct('rangeIdx', 1, 'dopplerIdx', 1, ...
        'coarseAz', sc.coarseAz, 'coarseEl', sc.coarseEl, ...
        'frontend_state', sc.frontend_state, ...
        'unresolved_cluster_flag', sc.unresolved_cluster_flag, ...
        'need_2d_refinement', sc.need_2d_refinement, ...
        'boundary_unreliable_flag', sc.boundary_unreliable_flag);
    truth = struct('target_count', sc.target_count, 'az', sc.az, 'el', sc.el, ...
        'SNR_dB', sc.SNR_dB, 'rng_seed', rng_seed, 'noise_power', noise_power, ...
        'clean_power', clean_power);
end

function a = steering_full_local(array_geom, az_deg, el_deg)
    kx = cosd(el_deg) * cosd(az_deg);
    ky = cosd(el_deg) * sind(az_deg);
    kz = sind(el_deg);
    phase = 2 * pi / array_geom.lambda * (array_geom.X * kx + array_geom.Y * ky + array_geom.Z * kz);
    a = exp(1j * phase);
end

function eval_info = evaluate_step09_output_local(out, truth, sc)
    eval_info = make_empty_eval_local();
    route = string(getfield_default_local(out, 'route_name', ''));
    status = string(getfield_default_local(out, 'status', ''));
    conf = string(getfield_default_local(out, 'confidence', 'low'));
    az_est = getfield_default_local(out, 'az_est', []);
    el_est = getfield_default_local(out, 'el_est', []);
    high_medium = conf == "high" || conf == "medium";
    eval_info.low_confidence = conf == "low" || route == "low_confidence";
    eval_info.out_of_scope = route == "frontend_reject" || contains(route, "out_of_scope");
    eval_info.boundary_missed = false;
    eval_info.failure_reason = "";

    if truth.target_count == 1
        if numel(az_est) == 1 && high_medium
            eval_info.az_error_mean = abs(wrap180_vec_local(az_est(1) - truth.az(1)));
            eval_info.el_error_mean = abs(el_est(1) - truth.el(1));
            eval_info.az_error_max = eval_info.az_error_mean;
            eval_info.el_error_max = eval_info.el_error_mean;
            eval_info.success = eval_info.az_error_mean <= 0.3 && eval_info.el_error_mean <= 0.5;
        elseif numel(az_est) >= 2 && high_medium
            eval_info.false_high = true;
            eval_info.failure_reason = "single_target_false_split";
        end
        eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
        return
    end

    [az_mean, el_mean, az_max, el_max, pair_ok] = pair_error_local(az_est, el_est, truth.az, truth.el);
    eval_info.az_error_mean = az_mean;
    eval_info.el_error_mean = el_mean;
    eval_info.az_error_max = az_max;
    eval_info.el_error_max = el_max;

    switch string(sc.scenario_name)
        case {"close_coherent_pair", "coarseAz_bias_sweep", "center_wraparound_case"}
            eval_info.success = pair_ok && az_mean <= 0.25 && el_mean <= 0.5 && high_medium && ...
                (route == "common_el_rank1_refocus" || route == "music_two_peak" || route == "local_2d_pair_refinement");
            eval_info.false_high = high_medium && ~eval_info.success && status ~= "rejected";
            eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
        case "medium_beta_pair"
            eval_info.success = pair_ok && az_mean <= 0.25 && el_mean <= 0.5 && high_medium;
            eval_info.false_high = high_medium && ~eval_info.success && sc.beta <= 0.3;
            eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
        case "weak_target_boundary"
            eval_info.success = false;
            eval_info.false_high = high_medium && pair_ok && (az_mean > 0.25 || el_mean > 0.5);
            eval_info.safe = ~eval_info.false_high && (eval_info.low_confidence || status == "rejected" || ~high_medium);
        case "near_antiphase_boundary"
            eval_info.success = false;
            eval_info.false_high = high_medium && (~pair_ok || az_mean > 0.25 || el_mean > 0.5);
            eval_info.boundary_missed = logical(sc.boundary_unreliable_flag) && ~(status == "rejected" || route == "boundary_unreliable" || eval_info.low_confidence);
            eval_info.safe = ~eval_info.false_high && ~eval_info.boundary_missed;
        case "large_el_pair"
            eval_info.success = pair_ok && az_mean <= 0.3 && el_mean <= 1.0 && high_medium && route == "local_2d_pair_refinement";
            eval_info.false_high = high_medium && ~eval_info.success && status ~= "rejected";
            eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
        case "two_separated_coarse_peaks"
            eval_info.success = status == "rejected" && route == "frontend_reject";
            eval_info.out_of_scope = true;
            eval_info.false_high = high_medium && status ~= "rejected";
            eval_info.safe = eval_info.success && ~eval_info.false_high;
        otherwise
            eval_info.success = pair_ok && high_medium;
            eval_info.false_high = high_medium && ~eval_info.success;
            eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
    end
    if eval_info.false_high && strlength(eval_info.failure_reason) == 0
        eval_info.failure_reason = "false_high_or_wrong_pair";
    elseif eval_info.boundary_missed
        eval_info.failure_reason = "boundary_missed";
    elseif ~eval_info.success && ~eval_info.safe
        eval_info.failure_reason = "not_success_and_not_safe";
    else
        eval_info.failure_reason = "ok";
    end
end

function eval_info = make_empty_eval_local()
    eval_info = struct('success', false, 'safe', false, 'false_high', false, ...
        'boundary_missed', false, 'low_confidence', false, 'out_of_scope', false, ...
        'az_error_mean', NaN, 'el_error_mean', NaN, 'az_error_max', NaN, ...
        'el_error_max', NaN, 'failure_reason', "not_evaluated");
end

function row = make_formal_trial_row_local(run_mode, trial_index, rng_seed, sc, truth, frontend_out, out, eval_info, runtime_sec)
    selected_cols = getfield_default_local(out, 'selectedWorkColumns', []);
    row = common_trial_fields_local(sc, truth, frontend_out, out, eval_info, runtime_sec);
    row.run_mode = string(run_mode);
    row.trial_index = trial_index;
    row.rng_seed = rng_seed;
    row.selectedWorkColumns_min = min_or_nan_local(selected_cols);
    row.selectedWorkColumns_max = max_or_nan_local(selected_cols);
end

function row = make_ablation_trial_row_local(ablation_mode, run_mode, trial_index, rng_seed, sc, truth, frontend_out, out, eval_info, runtime_sec)
    row = make_formal_trial_row_local(run_mode, trial_index, rng_seed, sc, truth, frontend_out, out, eval_info, runtime_sec);
    row.ablation_mode = string(ablation_mode);
end

function row = common_trial_fields_local(sc, truth, frontend_out, out, eval_info, runtime_sec)
    row = struct();
    row.scenario_name = string(sc.scenario_name);
    row.SNR_dB = sc.SNR_dB;
    row.Np = sc.Np;
    row.target_count = truth.target_count;
    row.az_truth = string(mat2str(truth.az, 6));
    row.el_truth = string(mat2str(truth.el, 6));
    row.beta = sc.beta;
    row.rho = sc.rho;
    row.phase_deg = sc.phase_deg;
    row.az_sep_deg = sc.az_sep_deg;
    row.el_sep_deg = sc.el_sep_deg;
    row.coarseAz = frontend_out.coarseAz;
    row.coarseEl = frontend_out.coarseEl;
    row.coarseAz_error = sc.coarseAz_error;
    row.frontend_state = string(frontend_out.frontend_state);
    row.unresolved_cluster_flag = logical(frontend_out.unresolved_cluster_flag);
    row.need_2d_refinement = logical(frontend_out.need_2d_refinement);
    row.boundary_unreliable_flag = logical(frontend_out.boundary_unreliable_flag);
    row.selectedCenterColumn = getfield_default_local(out, 'selectedCenterColumn', NaN);
    row.selectedCenterAz = selected_center_az_local(out);
    row.both_targets_inside_work_subarray = targets_inside_work_subarray_local(out, truth);
    row.Y_work_shape = string(mat2str(getfield_default_local(out, 'Y_work_shape', [])));
    row.route_name = string(getfield_default_local(out, 'route_name', ''));
    row.status = string(getfield_default_local(out, 'status', ''));
    row.confidence = string(getfield_default_local(out, 'confidence', ''));
    row.az_est = string(mat2str(getfield_default_local(out, 'az_est', []), 6));
    row.el_est = string(mat2str(getfield_default_local(out, 'el_est', []), 6));
    row.reject_reason = string(getfield_default_local(out, 'reject_reason', ''));
    row.success = logical(eval_info.success);
    row.safe = logical(eval_info.safe);
    row.false_high = logical(eval_info.false_high);
    row.boundary_missed = logical(eval_info.boundary_missed);
    row.low_confidence = logical(eval_info.low_confidence);
    row.out_of_scope = logical(eval_info.out_of_scope);
    row.az_error_mean = eval_info.az_error_mean;
    row.el_error_mean = eval_info.el_error_mean;
    row.az_error_max = eval_info.az_error_max;
    row.el_error_max = eval_info.el_error_max;
    row.runtime_sec = runtime_sec;
    row.failure_reason = string(eval_info.failure_reason);
end

function val = selected_center_az_local(out)
    val = NaN;
    if isfield(out, 'selected') && isfield(out.selected, 'selectedCenterAz')
        val = out.selected.selectedCenterAz;
    elseif isfield(out, 'selectedCenterAz')
        val = out.selectedCenterAz;
    end
end

function flag = targets_inside_work_subarray_local(out, truth)
    flag = false;
    if ~isfield(out, 'selected') || ~isfield(out.selected, 'phiWorkRel') || ...
            ~isfield(out.selected, 'selectedCenterAz') || isempty(truth.az)
        return
    end
    half_span = max(abs(out.selected.phiWorkRel));
    rel_az = abs(wrap180_vec_local(truth.az - out.selected.selectedCenterAz));
    flag = all(rel_az <= half_span + 1e-9);
end

function summary_tbl = summarize_trials_local(T, group_cols)
    if isempty(T)
        summary_tbl = table();
        return
    end
    key = strings(height(T), 1);
    for i = 1:height(T)
        parts = strings(1, numel(group_cols));
        for j = 1:numel(group_cols)
            parts(j) = string(T.(group_cols{j})(i));
        end
        key(i) = strjoin(parts, "||");
    end
    u = unique(key, 'stable');
    rows = cell(numel(u), 1);
    for i = 1:numel(u)
        mask = key == u(i);
        row = struct();
        for j = 1:numel(group_cols)
            value = T.(group_cols{j})(find(mask, 1));
            row.(group_cols{j}) = value;
        end
        row.trials = sum(mask);
        row.success_rate = mean(double(T.success(mask)));
        row.safe_rate = mean(double(T.safe(mask)));
        row.false_high_rate = mean(double(T.false_high(mask)));
        row.boundary_missed_rate = mean(double(T.boundary_missed(mask)));
        row.low_confidence_rate = mean(double(T.low_confidence(mask)));
        row.out_of_scope_rate = mean(double(T.out_of_scope(mask)));
        smask = mask & T.success;
        row.mean_az_error_success = mean_or_nan_local(T.az_error_mean(smask));
        row.mean_el_error_success = mean_or_nan_local(T.el_error_mean(smask));
        row.median_runtime_sec = median(T.runtime_sec(mask));
        row.mean_runtime_sec = mean(T.runtime_sec(mask));
        row.route_distribution = string(distribution_string_local(T.route_name(mask)));
        row.confidence_distribution = string(distribution_string_local(T.confidence(mask)));
        rows{i} = row;
    end
    summary_tbl = struct2table([rows{:}]);
end

function keypoints_tbl = formal_keypoints_local(T, run_mode, rng_seed_base, Metkl, snr_list, cfg)
    rows = {};
    rows = add_kp_local(rows, 'run_mode', run_mode, 'formal MC run mode');
    rows = add_kp_local(rows, 'rng_seed_base', rng_seed_base, 'base seed; each trial stores rng_seed');
    rows = add_kp_local(rows, 'Metkl', Metkl, 'Monte Carlo trials per scenario/SNR case');
    rows = add_kp_local(rows, 'SNR_list', mat2str(snr_list), 'SNR_dB values');
    rows = add_kp_local(rows, 'total_trials', height(T), 'trial rows');
    rows = add_kp_local(rows, 'Q_work_columns', cfg.Q_work_columns, 'shared-center work columns');
    rows = add_kp_local(rows, 'Y_work_shape_default', '65 x 32 x Np', 'default formal MC cube extraction');
    rows = add_kp_local(rows, 'default_derotation_mode', cfg.derotation_mode, 'default is no Doppler de-rotation');
    rows = add_kp_local(rows, 'overall_success_rate', mean(double(T.success)), 'overall');
    rows = add_kp_local(rows, 'overall_safe_rate', mean(double(T.safe)), 'overall');
    rows = add_kp_local(rows, 'overall_false_high_rate', mean(double(T.false_high)), 'overall');
    rows = add_kp_local(rows, 'overall_boundary_missed_rate', mean(double(T.boundary_missed)), 'overall');
    rows = add_kp_local(rows, 'overall_low_confidence_rate', mean(double(T.low_confidence)), 'overall');
    rows = add_kp_local(rows, 'single_target_false_split_rate', scenario_mean_local(T, 'single_target_sanity', 'false_high'), 'single target');
    rows = add_kp_local(rows, 'close_coherent_success_rate', scenario_mean_local(T, 'close_coherent_pair', 'success'), 'close coherent pair');
    rows = add_kp_local(rows, 'medium_beta_success_rate', scenario_mean_local(T, 'medium_beta_pair', 'success'), 'medium beta pair');
    rows = add_kp_local(rows, 'weak_target_false_high_rate', scenario_mean_local(T, 'weak_target_boundary', 'false_high'), 'weak target boundary');
    rows = add_kp_local(rows, 'near_antiphase_false_high_rate', scenario_mean_local(T, 'near_antiphase_boundary', 'false_high'), 'near anti-phase boundary');
    rows = add_kp_local(rows, 'near_antiphase_boundary_missed_rate', scenario_mean_local(T, 'near_antiphase_boundary', 'boundary_missed'), 'near anti-phase boundary');
    rows = add_kp_local(rows, 'large_el_success_rate', scenario_mean_local(T, 'large_el_pair', 'success'), 'large elevation pair');
    rows = add_kp_local(rows, 'two_separated_out_of_scope_reject_rate', scenario_mean_local(T, 'two_separated_coarse_peaks', 'success'), 'frontend out-of-scope reject');
    [bias_min, bias_max] = bias_success_minmax_local(T);
    rows = add_kp_local(rows, 'coarseAz_bias_success_min', bias_min, 'min success across coarseAz_error sweep');
    rows = add_kp_local(rows, 'coarseAz_bias_success_max', bias_max, 'max success across coarseAz_error sweep');
    wrap_flag = center_wraparound_pass_local(T);
    rows = add_kp_local(rows, 'center_wraparound_pass_flag', wrap_flag, 'selected columns valid at wrap boundary');
    [pass_flag, blocker] = formal_pass_local(T, wrap_flag);
    rows = add_kp_local(rows, 'formal_mc_pass_flag', pass_flag, 'formal MC pass/fail');
    rows = add_kp_local(rows, 'blocker_if_any', blocker, 'comma-separated blocker list; none if pass');
    keypoints_tbl = struct2table([rows{:}]);
end

function [pass_flag, blocker] = formal_pass_local(T, wrap_flag)
    blockers = strings(0, 1);
    if mean(double(T.false_high)) > 0.01, blockers(end+1) = "overall_false_high_rate_gt_0p01"; end
    if mean(double(T.boundary_missed)) > 0.01, blockers(end+1) = "overall_boundary_missed_rate_gt_0p01"; end
    if scenario_mean_local(T, 'weak_target_boundary', 'false_high') > 0.01, blockers(end+1) = "weak_target_false_high_nonzero"; end
    if scenario_mean_local(T, 'near_antiphase_boundary', 'false_high') > 0.01, blockers(end+1) = "near_antiphase_false_high_nonzero"; end
    if scenario_mean_local(T, 'two_separated_coarse_peaks', 'success') < 0.99, blockers(end+1) = "out_of_scope_reject_failed"; end
    if wrap_flag ~= 1, blockers(end+1) = "center_wraparound_failed"; end
    if scenario_mean_local(T, 'close_coherent_pair', 'success') < 0.50, blockers(end+1) = "close_coherent_success_low"; end
    if scenario_mean_local(T, 'large_el_pair', 'success') < 0.70, blockers(end+1) = "large_el_success_low"; end
    pass_flag = double(isempty(blockers));
    if isempty(blockers)
        blocker = "none";
    else
        blocker = strjoin(blockers, ",");
    end
end

function row = make_consistency_trial_row_local(trial_index, sc, old_callable, old_out, new_out, old_eval, new_eval)
    row = struct();
    row.trial_index = trial_index;
    row.scenario_name = string(sc.scenario_name);
    row.SNR_dB = sc.SNR_dB;
    row.old_callable = logical(old_callable);
    row.old_route_name = string(getfield_default_local(old_out, 'route_name', 'not_callable'));
    row.new_route_name = string(getfield_default_local(new_out, 'route_name', ''));
    row.old_status = string(getfield_default_local(old_out, 'status', 'not_callable'));
    row.new_status = string(getfield_default_local(new_out, 'status', ''));
    row.old_confidence = string(getfield_default_local(old_out, 'confidence', 'not_callable'));
    row.new_confidence = string(getfield_default_local(new_out, 'confidence', ''));
    row.old_az_est = string(mat2str(getfield_default_local(old_out, 'az_est', []), 6));
    row.new_az_est = string(mat2str(getfield_default_local(new_out, 'az_est', []), 6));
    row.old_el_est = string(mat2str(getfield_default_local(old_out, 'el_est', []), 6));
    row.new_el_est = string(mat2str(getfield_default_local(new_out, 'el_est', []), 6));
    row.route_agree = row.old_route_name == row.new_route_name;
    row.status_agree = row.old_status == row.new_status;
    row.confidence_agree = row.old_confidence == row.new_confidence;
    row.az_diff_mean = NaN;
    row.el_diff_mean = NaN;
    row.old_success = logical(old_eval.success);
    row.new_success = logical(new_eval.success);
    row.old_false_high = logical(old_eval.false_high);
    row.new_false_high = logical(new_eval.false_high);
    row.old_boundary_missed = logical(old_eval.boundary_missed);
    row.new_boundary_missed = logical(new_eval.boundary_missed);
end

function summary_tbl = summarize_consistency_local(T)
    row = struct();
    row.total_trials = height(T);
    row.old_callable = any(T.old_callable);
    row.route_agreement_rate = mean(double(T.route_agree));
    row.status_agreement_rate = mean(double(T.status_agree));
    row.confidence_agreement_rate = mean(double(T.confidence_agree));
    row.success_gap_new_minus_old = mean(double(T.new_success)) - mean(double(T.old_success));
    row.false_high_gap_new_minus_old = mean(double(T.new_false_high)) - mean(double(T.old_false_high));
    row.boundary_missed_gap_new_minus_old = mean(double(T.new_boundary_missed)) - mean(double(T.old_boundary_missed));
    row.mean_az_diff_when_both_success = mean_or_nan_local(T.az_diff_mean(T.old_success & T.new_success));
    row.mean_el_diff_when_both_success = mean_or_nan_local(T.el_diff_mean(T.old_success & T.new_success));
    summary_tbl = struct2table(row);
end

function keypoints_tbl = consistency_keypoints_local(T, old_callable, attempted_old_entry, ~)
    route_agree = mean(double(T.route_agree));
    conf_agree = mean(double(T.confidence_agree));
    status_agree = mean(double(T.status_agree));
    success_gap = mean(double(T.new_success)) - mean(double(T.old_success));
    false_gap = mean(double(T.new_false_high)) - mean(double(T.old_false_high));
    boundary_gap = mean(double(T.new_boundary_missed)) - mean(double(T.old_boundary_missed));
    pass_flag = old_callable && route_agree >= 0.85 && conf_agree >= 0.85 && ...
        abs(success_gap) <= 0.05 && false_gap <= 0.005 && boundary_gap <= 0.005;
    if ~old_callable
        blocker = "step87_reference_not_functionalized";
    elseif ~pass_flag
        blocker = "consistency_threshold_failed";
    else
        blocker = "none";
    end
    rows = {};
    rows = add_kp_local(rows, 'old_route_callable', double(old_callable), attempted_old_entry);
    rows = add_kp_local(rows, 'attempted_old_entry', attempted_old_entry, 'first historical Step 8.7/8.8 candidate found');
    rows = add_kp_local(rows, 'total_trials', height(T), 'consistency trial rows');
    rows = add_kp_local(rows, 'route_agreement_rate', route_agree, 'old vs new route_name agreement');
    rows = add_kp_local(rows, 'status_agreement_rate', status_agree, 'old vs new status agreement');
    rows = add_kp_local(rows, 'confidence_agreement_rate', conf_agree, 'old vs new confidence agreement');
    rows = add_kp_local(rows, 'success_gap_new_minus_old', success_gap, 'new minus old success rate');
    rows = add_kp_local(rows, 'false_high_gap_new_minus_old', false_gap, 'new minus old false-high rate');
    rows = add_kp_local(rows, 'boundary_missed_gap_new_minus_old', boundary_gap, 'new minus old boundary missed rate');
    rows = add_kp_local(rows, 'mean_az_diff_when_both_success', NaN, 'not available unless old route is callable');
    rows = add_kp_local(rows, 'mean_el_diff_when_both_success', NaN, 'not available unless old route is callable');
    rows = add_kp_local(rows, 'consistency_pass_flag', double(pass_flag), 'pass/fail');
    rows = add_kp_local(rows, 'blocker_if_any', blocker, 'clear blocker if old route cannot be called');
    rows = add_kp_local(rows, 'failure_reason', blocker, 'same as blocker_if_any for non-callable old route');
    if old_callable
        fallback_policy = 'old callable; direct route comparison used';
    else
        fallback_policy = 'Step09 formal MC is used as final validation';
    end
    rows = add_kp_local(rows, 'fallback_policy', fallback_policy, 'policy when old Step 8.7 is not callable');
    keypoints_tbl = struct2table([rows{:}]);
end

function confusion_tbl = route_confusion_local(T)
    key = string(T.old_route_name) + "||" + string(T.new_route_name);
    u = unique(key, 'stable');
    rows = cell(numel(u), 1);
    for i = 1:numel(u)
        parts = split(u(i), "||");
        rows{i} = struct('old_route_name', parts(1), 'new_route_name', parts(2), 'count', sum(key == u(i)));
    end
    confusion_tbl = struct2table([rows{:}]);
end

function keypoints_tbl = ablation_keypoints_local(T)
    mo = @(mode, scenario, col) mode_scenario_mean_local(T, mode, scenario, col);
    music_only_close = mo('music_only', 'close_coherent_pair', 'success');
    rank1_close = mo('music_plus_rank1', 'close_coherent_pair', 'success');
    rank1_large = mo('music_plus_rank1', 'large_el_pair', 'success');
    full_large = mo('full_step09', 'large_el_pair', 'success');
    without_false = mode_mean_local(T, 'full_without_rejector', 'false_high');
    full_false = mode_mean_local(T, 'full_step09', 'false_high');
    without_boundary = mode_mean_local(T, 'full_without_rejector', 'boundary_missed');
    full_boundary = mode_mean_local(T, 'full_step09', 'boundary_missed');
    full_success = mode_mean_local(T, 'full_step09', 'success');
    full_safe = mode_mean_local(T, 'full_step09', 'safe');
    full_low = mode_mean_local(T, 'full_step09', 'low_confidence');
    local2d_share = route_share_local(T, 'full_step09', 'large_el_pair', 'local_2d_pair_refinement');
    blockers = strings(0, 1);
    if rank1_close < music_only_close + 0.10, blockers(end+1) = "rank1_gain_close_coherent_low"; end
    if ~(full_large >= rank1_large + 0.10 || (local2d_share >= 0.50 && full_large >= 0.70)), blockers(end+1) = "local_2d_gain_large_el_low"; end
    if full_false > without_false, blockers(end+1) = "rejector_false_high_not_reduced"; end
    if full_boundary > without_boundary, blockers(end+1) = "rejector_boundary_missed_not_reduced"; end
    if full_false > 0.01, blockers(end+1) = "full_step09_false_high_gt_0p01"; end
    pass_flag = double(isempty(blockers));
    if isempty(blockers), blocker = "none"; else, blocker = strjoin(blockers, ","); end
    rows = {};
    rows = add_kp_local(rows, 'music_only_close_coherent_success', music_only_close, 'close coherent success');
    rows = add_kp_local(rows, 'music_plus_rank1_close_coherent_success', rank1_close, 'close coherent success');
    rows = add_kp_local(rows, 'rank1_gain_close_coherent', rank1_close - music_only_close, 'rank1 gain');
    rows = add_kp_local(rows, 'music_plus_rank1_large_el_success', rank1_large, 'large-el success without 2-D refinement');
    rows = add_kp_local(rows, 'music_plus_2d_large_el_success', mo('music_plus_2d', 'large_el_pair', 'success'), 'large-el success');
    rows = add_kp_local(rows, 'full_step09_large_el_success', full_large, 'large-el success');
    rows = add_kp_local(rows, 'twoD_gain_large_el', full_large - rank1_large, '2D gain relative to no-2D mode');
    rows = add_kp_local(rows, 'full_without_rejector_false_high', without_false, 'false-high without rejector');
    rows = add_kp_local(rows, 'full_step09_false_high', full_false, 'false-high with rejector');
    rows = add_kp_local(rows, 'rejector_false_high_reduction', without_false - full_false, 'rejector reduction');
    rows = add_kp_local(rows, 'full_without_rejector_boundary_missed', without_boundary, 'boundary missed without rejector');
    rows = add_kp_local(rows, 'full_step09_boundary_missed', full_boundary, 'boundary missed with rejector');
    rows = add_kp_local(rows, 'rejector_boundary_missed_reduction', without_boundary - full_boundary, 'rejector reduction');
    rows = add_kp_local(rows, 'full_step09_success_rate', full_success, 'overall full Step 09');
    rows = add_kp_local(rows, 'full_step09_safe_rate', full_safe, 'overall full Step 09');
    rows = add_kp_local(rows, 'full_step09_low_confidence_rate', full_low, 'overall full Step 09');
    rows = add_kp_local(rows, 'ablation_pass_flag', pass_flag, 'pass/fail');
    rows = add_kp_local(rows, 'blocker_if_any', blocker, 'comma-separated blocker list');
    keypoints_tbl = struct2table([rows{:}]);
end

function cfg = apply_ablation_cfg_local(cfg, ablation_mode)
    cfg.enable_music = true;
    cfg.enable_rank1_fallback = true;
    cfg.enable_2d_refinement = true;
    cfg.enable_rejector = true;
    switch char(ablation_mode)
        case 'music_only'
            cfg.enable_rank1_fallback = false;
            cfg.enable_2d_refinement = false;
        case 'music_plus_rank1'
            cfg.enable_2d_refinement = false;
        case 'music_plus_2d'
            cfg.enable_rank1_fallback = false;
        case 'full_without_rejector'
            cfg.enable_rejector = false;
    end
end

function [old_callable, attempted_old_entry, blocker] = detect_step87_callable_local(script_dir)
    candidates = {
        fullfile(script_dir, '..', 'step_08_7_routeB_array_level3', 'space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m')
        fullfile(script_dir, '..', 'step_08_7_routeB_array_level3', 'space_smooth_music_B_cylindrical_level3_lazy_runtime.m')
        fullfile(script_dir, '..', 'step_08_7_routeB_array_level3')
        fullfile(script_dir, '..', 'step_08_8_frontend_to_shared_center_closure')
        };
    attempted_old_entry = 'no_step87_candidate_found';
    old_callable = false;
    blocker = "step87_reference_not_functionalized";
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file') || exist(candidates{i}, 'dir')
            attempted_old_entry = candidates{i};
            if exist(candidates{i}, 'file')
                txt = fileread(candidates{i});
                first_function = ~isempty(regexp(txt, '^\s*function\s+', 'once'));
                if first_function && contains(candidates{i}, 'call_step87_reference_route')
                    old_callable = true;
                    blocker = "none";
                end
            end
            return
        end
    end
end

function old_out = call_step87_reference_route_local(~, ~, ~, ~)
    old_out = []; %#ok<NASGU>
    error('step09:Step87NotFunctionalized', 'Step 8.7 reference route is not available as a callable function.');
end

function out = make_missing_old_output_local(blocker)
    out = struct('route_name', char(blocker), 'status', 'not_callable', ...
        'confidence', 'not_callable', 'az_est', [], 'el_est', [], 'reject_reason', char(blocker));
end

function write_formal_report_local(script_dir, ~, keypoints_tbl, summary_tbl, run_mode, Metkl, snr_list, elapsed_sec)
    report_path = fullfile(script_dir, 'docs', '09_FORMAL_MONTE_CARLO_RESULTS.md');
    fid = fopen(report_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Formal Monte Carlo Results\n\n');
    fprintf(fid, '- run_mode: `%s`\n- Metkl: `%d`\n- SNR list: `%s`\n- total trials: `%s`\n- elapsed_sec: `%.3f`\n\n', ...
        run_mode, Metkl, mat2str(snr_list), string(keypoint_value_local(keypoints_tbl, 'total_trials')), elapsed_sec);
    fprintf(fid, '## Keypoints\n\n');
    write_keypoints_md_local(fid, keypoints_tbl);
    fprintf(fid, '\n## Scenario Summary\n\n');
    write_table_preview_md_local(fid, summary_tbl, 40);
    fprintf(fid, '\n## Figures\n\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_formal_mc/step09_success_vs_snr.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_formal_mc/step09_false_high_vs_snr.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_formal_mc/step09_route_distribution.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_formal_mc/step09_low_confidence_boundary_rates.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_formal_mc/step09_coarseAz_bias_sweep.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_formal_mc/step09_runtime_distribution.png`\n\n');
    if keypoint_value_local(keypoints_tbl, 'formal_mc_pass_flag') == 1
        fprintf(fid, '## Conclusion\n\nStep 09 formal MC supports the final shared-center MUSIC enhanced DOA route under the tested local unresolved-cluster scope.\n');
    else
        fprintf(fid, '## Conclusion\n\nStep 09 formal MC found blockers. The final route remains plausible, but the blocker must be reported and the method should not overclaim beyond validated cases.\n');
    end
end

function write_consistency_report_local(script_dir, result_dir, keypoints_tbl, summary_tbl)
    report_path = fullfile(result_dir, 'step09_vs_step87_report.md');
    fid = fopen(report_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Step09 vs Step87 Consistency\n\n');
    fprintf(fid, '## Keypoints\n\n');
    write_keypoints_md_local(fid, keypoints_tbl);
    fprintf(fid, '\n## Summary\n\n');
    write_table_preview_md_local(fid, summary_tbl, 20);
    fprintf(fid, '\nIf `old_route_callable = 0`, Step 8.7 was found as script-oriented historical code rather than a directly callable reference route. In that case Step 09 formal MC is the final statistical validation basis.\n');
    copyfile(report_path, fullfile(script_dir, 'docs', '10_STEP09_VS_STEP87_CONSISTENCY.md'));
end

function write_ablation_report_local(script_dir, result_dir, keypoints_tbl, summary_tbl)
    report_path = fullfile(result_dir, 'step09_ablation_report.md');
    fid = fopen(report_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Ablation Study Results\n\n');
    fprintf(fid, 'Modes: `music_only`, `music_plus_rank1`, `music_plus_2d`, `full_step09`, `full_without_rejector`.\n\n');
    fprintf(fid, '## Keypoints\n\n');
    write_keypoints_md_local(fid, keypoints_tbl);
    fprintf(fid, '\n## Summary\n\n');
    write_table_preview_md_local(fid, summary_tbl, 80);
    fprintf(fid, '\n## Figures\n\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_ablation/ablation_success_by_scenario.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_ablation/ablation_false_high_by_scenario.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_ablation/ablation_boundary_missed_by_scenario.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_ablation/ablation_runtime_by_mode.png`\n');
    fprintf(fid, '- `../archive/diagnostic_results/results_step09_ablation/ablation_low_confidence_by_mode.png`\n');
    copyfile(report_path, fullfile(script_dir, 'docs', '11_ABLATION_STUDY_RESULTS.md'));
end

function plot_success_vs_snr_local(S, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    hold on
    scenarios = unique(string(S.scenario_name), 'stable');
    for i = 1:numel(scenarios)
        mask = string(S.scenario_name) == scenarios(i);
        plot(S.SNR_dB(mask), S.success_rate(mask), '-o', 'DisplayName', scenarios(i));
    end
    xlabel('SNR (dB)'); ylabel('success rate'); ylim([0, 1.05]); grid on
    legend('Location', 'eastoutside', 'Interpreter', 'none');
    title('Step 09 success vs SNR');
    saveas(fig, path_out); close(fig);
end

function plot_false_high_vs_snr_local(S, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    hold on
    scenarios = ["weak_target_boundary", "near_antiphase_boundary"];
    for i = 1:numel(scenarios)
        mask = string(S.scenario_name) == scenarios(i);
        plot(S.SNR_dB(mask), S.false_high_rate(mask), '-o', 'DisplayName', scenarios(i));
    end
    snr_vals = unique(S.SNR_dB);
    overall = zeros(size(snr_vals));
    for i = 1:numel(snr_vals)
        mask = S.SNR_dB == snr_vals(i);
        overall(i) = mean(S.false_high_rate(mask));
    end
    plot(snr_vals, overall, '-ks', 'DisplayName', 'overall');
    xlabel('SNR (dB)'); ylabel('false-high rate'); ylim([0, 1.05]); grid on
    legend('Location', 'best', 'Interpreter', 'none');
    title('Step 09 false-high vs SNR');
    saveas(fig, path_out); close(fig);
end

function plot_route_distribution_local(T, path_out)
    scenarios = unique(string(T.scenario_name), 'stable');
    routes = unique(string(T.route_name), 'stable');
    M = zeros(numel(scenarios), numel(routes));
    for i = 1:numel(scenarios)
        for j = 1:numel(routes)
            mask = string(T.scenario_name) == scenarios(i);
            M(i, j) = mean(string(T.route_name(mask)) == routes(j));
        end
    end
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1100, 520]);
    bar(categorical(scenarios), M, 'stacked');
    ylabel('route share'); ylim([0, 1.05]); grid on
    legend(routes, 'Location', 'eastoutside', 'Interpreter', 'none');
    title('Step 09 route distribution');
    saveas(fig, path_out); close(fig);
end

function plot_low_conf_boundary_local(T, path_out)
    scenarios = unique(string(T.scenario_name), 'stable');
    M = zeros(numel(scenarios), 3);
    for i = 1:numel(scenarios)
        mask = string(T.scenario_name) == scenarios(i);
        M(i, :) = [mean(T.low_confidence(mask)), mean(string(T.route_name(mask)) == "boundary_unreliable"), mean(T.out_of_scope(mask))];
    end
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1000, 500]);
    bar(categorical(scenarios), M);
    ylabel('rate'); ylim([0, 1.05]); grid on
    legend({'low confidence', 'boundary unreliable', 'out of scope'}, 'Location', 'eastoutside');
    title('Low-confidence and boundary rates');
    saveas(fig, path_out); close(fig);
end

function plot_coarse_bias_local(T, path_out)
    mask = string(T.scenario_name) == "coarseAz_bias_sweep";
    vals = unique(T.coarseAz_error(mask));
    succ = zeros(size(vals));
    center_ok = zeros(size(vals));
    for i = 1:numel(vals)
        m = mask & T.coarseAz_error == vals(i);
        succ(i) = mean(T.success(m));
        center_ok(i) = mean(~isnan(T.selectedCenterColumn(m)));
    end
    fig = figure('Visible', 'off', 'Color', 'w');
    plot(vals, succ, '-o', vals, center_ok, '-s');
    xlabel('coarseAz error (deg)'); ylabel('rate'); ylim([0, 1.05]); grid on
    legend({'success', 'center selection valid'}, 'Location', 'best');
    title('CoarseAz bias sweep');
    saveas(fig, path_out); close(fig);
end

function plot_runtime_distribution_local(T, path_out)
    routes = unique(string(T.route_name), 'stable');
    data = cell(numel(routes), 1);
    for i = 1:numel(routes)
        data{i} = T.runtime_sec(string(T.route_name) == routes(i));
    end
    fig = figure('Visible', 'off', 'Color', 'w');
    boxplot_cell_local(data, routes);
    ylabel('runtime (sec)'); title('Runtime distribution by route'); grid on
    saveas(fig, path_out); close(fig);
end

function plot_consistency_blocker_local(K, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    bar(categorical({'old callable', 'pass'}), [keypoint_value_local(K, 'old_route_callable'), keypoint_value_local(K, 'consistency_pass_flag')]);
    ylim([0, 1.1]); grid on; title('Step87 callable status');
    saveas(fig, path_out); close(fig);
end

function plot_new_route_distribution_local(T, path_out)
    tmp = T;
    tmp.route_name = T.new_route_name;
    plot_route_distribution_local(tmp, path_out);
end

function plot_new_status_distribution_local(T, path_out)
    statuses = unique(string(T.new_status), 'stable');
    counts = zeros(size(statuses));
    for i = 1:numel(statuses), counts(i) = mean(string(T.new_status) == statuses(i)); end
    fig = figure('Visible', 'off', 'Color', 'w');
    bar(categorical(statuses), counts); ylim([0, 1.05]); grid on
    title('New Step09 status distribution');
    saveas(fig, path_out); close(fig);
end

function plot_ablation_metric_local(S, metric_name, path_out)
    modes = unique(string(S.ablation_mode), 'stable');
    scenarios = unique(string(S.scenario_name), 'stable');
    M = zeros(numel(scenarios), numel(modes));
    for i = 1:numel(scenarios)
        for j = 1:numel(modes)
            mask = string(S.scenario_name) == scenarios(i) & string(S.ablation_mode) == modes(j);
            if any(mask), M(i, j) = S.(metric_name)(find(mask, 1)); end
        end
    end
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1100, 520]);
    bar(categorical(scenarios), M);
    ylabel(strrep(metric_name, '_', ' ')); ylim([0, 1.05]); grid on
    legend(modes, 'Location', 'eastoutside', 'Interpreter', 'none');
    title(['Ablation ', strrep(metric_name, '_', ' ')]);
    saveas(fig, path_out); close(fig);
end

function plot_ablation_runtime_local(T, path_out)
    modes = unique(string(T.ablation_mode), 'stable');
    data = cell(numel(modes), 1);
    for i = 1:numel(modes)
        data{i} = T.runtime_sec(string(T.ablation_mode) == modes(i));
    end
    fig = figure('Visible', 'off', 'Color', 'w');
    boxplot_cell_local(data, modes);
    ylabel('runtime (sec)'); title('Ablation runtime by mode'); grid on
    saveas(fig, path_out); close(fig);
end

function plot_ablation_low_conf_local(S, path_out)
    modes = unique(string(S.ablation_mode), 'stable');
    vals = zeros(size(modes));
    for i = 1:numel(modes)
        mask = string(S.ablation_mode) == modes(i);
        vals(i) = mean(S.low_confidence_rate(mask));
    end
    fig = figure('Visible', 'off', 'Color', 'w');
    bar(categorical(modes), vals); ylim([0, 1.05]); grid on
    ylabel('low-confidence rate'); title('Ablation low-confidence by mode');
    saveas(fig, path_out); close(fig);
end

function boxplot_cell_local(data, labels)
    hold on
    for i = 1:numel(data)
        x = data{i};
        if isempty(x), x = NaN; end
        q = prctile_no_toolbox_local(x, [25, 50, 75]);
        lo = min(x); hi = max(x);
        rectangle('Position', [i-0.25, q(1), 0.5, max(q(3)-q(1), eps)], 'FaceColor', [0.85, 0.9, 1], 'EdgeColor', 'k');
        plot([i-0.25, i+0.25], [q(2), q(2)], 'k-', 'LineWidth', 1.3);
        plot([i, i], [lo, q(1)], 'k-');
        plot([i, i], [q(3), hi], 'k-');
        plot(i * ones(size(x)), x, '.', 'Color', [0.4, 0.4, 0.4]);
    end
    xlim([0.5, numel(data)+0.5]);
    set(gca, 'XTick', 1:numel(labels), 'XTickLabel', cellstr(labels));
    xtickangle(30);
end

function [az_mean, el_mean, az_max, el_max, ok] = pair_error_local(az_est, el_est, az_true, el_true)
    ok = false; az_mean = NaN; el_mean = NaN; az_max = NaN; el_max = NaN;
    if numel(az_est) < 2 || numel(el_est) < 2 || numel(az_true) < 2
        return
    end
    az_est = az_est(1:2); el_est = el_est(1:2);
    e1az = abs(wrap180_vec_local(az_est - az_true));
    e1el = abs(el_est - el_true);
    e2az = abs(wrap180_vec_local(fliplr(az_est) - az_true));
    e2el = abs(fliplr(el_est) - el_true);
    if mean(e2az) + mean(e2el) < mean(e1az) + mean(e1el)
        eaz = e2az; eel = e2el;
    else
        eaz = e1az; eel = e1el;
    end
    az_mean = mean(eaz); el_mean = mean(eel); az_max = max(eaz); el_max = max(eel); ok = true;
end

function rows = add_kp_local(rows, key, value, note)
    rows{end+1, 1} = struct('keypoint', safe_string_local(key), ...
        'value', safe_string_local(value), 'note', safe_string_local(note));
end

function val = keypoint_value_local(K, key)
    idx = find(string(K.keypoint) == string(key), 1);
    if isempty(idx)
        val = NaN;
        return
    end
    raw = K.value(idx);
    val = str2double(raw);
    if isnan(val)
        val = raw;
    end
end

function note = keypoint_note_local(K, key)
    idx = find(string(K.keypoint) == string(key), 1);
    if isempty(idx)
        note = "";
    else
        note = K.value(idx);
    end
end

function val = scenario_mean_local(T, scenario, col)
    mask = string(T.scenario_name) == string(scenario);
    if ~any(mask), val = NaN; else, val = mean(double(T.(col)(mask))); end
end

function val = mode_mean_local(T, mode, col)
    mask = string(T.ablation_mode) == string(mode);
    if ~any(mask), val = NaN; else, val = mean(double(T.(col)(mask))); end
end

function val = mode_scenario_mean_local(T, mode, scenario, col)
    mask = string(T.ablation_mode) == string(mode) & string(T.scenario_name) == string(scenario);
    if ~any(mask), val = NaN; else, val = mean(double(T.(col)(mask))); end
end

function val = route_share_local(T, mode, scenario, route)
    mask = string(T.ablation_mode) == string(mode) & string(T.scenario_name) == string(scenario);
    if ~any(mask), val = NaN; else, val = mean(string(T.route_name(mask)) == string(route)); end
end

function [bias_min, bias_max] = bias_success_minmax_local(T)
    mask = string(T.scenario_name) == "coarseAz_bias_sweep";
    vals = unique(T.coarseAz_error(mask));
    rates = NaN(size(vals));
    for i = 1:numel(vals)
        m = mask & T.coarseAz_error == vals(i);
        rates(i) = mean(double(T.success(m)));
    end
    bias_min = min(rates); bias_max = max(rates);
end

function flag = center_wraparound_pass_local(T)
    mask = string(T.scenario_name) == "center_wraparound_case";
    if ~any(mask)
        flag = 0;
    else
        valid_idx = T.selectedWorkColumns_min(mask) >= 1 & T.selectedWorkColumns_max(mask) <= 192;
        shape_ok = contains(string(T.Y_work_shape(mask)), "65") & contains(string(T.Y_work_shape(mask)), "32");
        flag = double(all(valid_idx & shape_ok));
    end
end

function txt = distribution_string_local(vals)
    vals = string(vals);
    u = unique(vals, 'stable');
    parts = strings(numel(u), 1);
    for i = 1:numel(u)
        parts(i) = sprintf('%s:%.3f', u(i), mean(vals == u(i)));
    end
    txt = strjoin(parts, ';');
end

function x = wrap180_vec_local(x)
    x = mod(x + 180, 360) - 180;
end

function val = mean_or_nan_local(x)
    if isempty(x) || all(isnan(x))
        val = NaN;
    else
        val = mean(x, 'omitnan');
    end
end

function val = min_or_nan_local(x)
    if isempty(x), val = NaN; else, val = min(x); end
end

function val = max_or_nan_local(x)
    if isempty(x), val = NaN; else, val = max(x); end
end

function q = prctile_no_toolbox_local(x, pct)
    x = sort(x(~isnan(x)));
    if isempty(x), q = NaN(size(pct)); return; end
    q = zeros(size(pct));
    for i = 1:numel(pct)
        pos = 1 + (numel(x) - 1) * pct(i) / 100;
        lo = floor(pos); hi = ceil(pos);
        if lo == hi
            q(i) = x(lo);
        else
            q(i) = x(lo) + (pos - lo) * (x(hi) - x(lo));
        end
    end
end

function write_keypoints_md_local(fid, K)
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(K)
        fprintf(fid, '| `%s` | %s | %s |\n', safe_string_local(K.keypoint(i)), ...
            safe_string_local(K.value(i)), safe_string_local(K.note(i)));
    end
end

function write_table_preview_md_local(fid, T, max_rows)
    if isempty(T) || height(T) == 0
        fprintf(fid, 'No rows.\n');
        return
    end
    vars = T.Properties.VariableNames;
    n = min(height(T), max_rows);
    fprintf(fid, '| %s |\n', strjoin(vars, ' | '));
    fprintf(fid, '|%s|\n', strjoin(repmat({'---'}, 1, numel(vars)), '|'));
    for i = 1:n
        parts = strings(1, numel(vars));
        for j = 1:numel(vars)
            v = T.(vars{j})(i);
            parts(j) = safe_string_local(v);
        end
        fprintf(fid, '| %s |\n', strjoin(parts, ' | '));
    end
end

function s = safe_string_local(value)
    if isnumeric(value)
        if isscalar(value)
            if isnan(value)
                s = "NaN";
            else
                s = string(value);
            end
        else
            s = string(mat2str(value));
        end
    elseif islogical(value)
        s = string(double(value));
    else
        s = string(value);
    end
    s(ismissing(s)) = "NaN";
end

function ensure_dir_local(path_in)
    if ~exist(path_in, 'dir')
        mkdir(path_in);
    end
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end

function result = make_result_struct_local(name, result_dir, pass_flag, blocker, elapsed_sec)
    result = struct('experiment_name', string(name), 'status', "completed", ...
        'result_dir', string(result_dir), 'pass_flag', string(pass_flag), ...
        'blocker_if_any', string(blocker), 'elapsed_sec', elapsed_sec);
end
