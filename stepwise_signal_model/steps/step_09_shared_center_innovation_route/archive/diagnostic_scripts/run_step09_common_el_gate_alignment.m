% Step09 common-el gate alignment decision experiment.
% Purpose: decide whether replacing the current common-el proxy gate with a
% rank1/refocus consensus gate can recover close-coherent cases safely.
%
% This is a focused decision experiment only:
% - no formal=200 run;
% - no stress=500 run;
% - no default-backend change;
% - no truth in route decisions.
%
% Output directory: results_step09_common_el_gate_alignment/.

clc
clear

archive_script_dir = fileparts(mfilename('fullpath'));
if isempty(archive_script_dir)
    archive_script_dir = pwd;
end
script_dir = fullfile(archive_script_dir, '..', '..');
addpath(fullfile(script_dir, 'main'));
addpath(fullfile(script_dir, 'archive', 'backend_attempts'));

result_dir = fullfile(script_dir, 'archive', 'diagnostic_results', 'results_step09_common_el_gate_alignment');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

array_geom = make_array_geom_local();
base_cfg = make_base_cfg_local();
gate_modes = {'current_common_el_proxy', ...
    'rank1_reliable_without_common_el_proxy', ...
    'rank1_refocus_consensus_gate'};
Metkl = 30;
snr_list = [8, 16];
scenarios = build_gate_alignment_scenarios_local(snr_list);
rng_seed_base = 916701;
rows = cell(numel(scenarios) * Metkl * numel(gate_modes), 1);
irow = 0;

for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    fprintf('scenario %d/%d: %s SNR=%g sep=%g beta=%g phase=%g\n', ...
        isc, numel(scenarios), sc.scenario_name, sc.SNR_dB, ...
        sc.az_sep_deg, sc.beta, sc.phase_deg);
    for imc = 1:Metkl
        scenario_trial_index = (isc - 1) * Metkl + imc;
        rng_seed = rng_seed_base + scenario_trial_index;
        [raw_cube, frontend_out, truth, cfg0] = synthesize_alignment_trial_local( ...
            array_geom, sc, base_cfg, rng_seed);
        for imode = 1:numel(gate_modes)
            cfg = cfg0;
            cfg.backend_mode = 'step87_reference';
            cfg.common_el_gate_mode = gate_modes{imode};
            cfg.rank1_refocus_pair_agree_tol_deg = 0.12;
            t0 = tic;
            out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
            runtime_sec = toc(t0);
            eval_info = evaluate_alignment_output_local(out, truth, sc);
            truth_diag = truth_only_diagnostics_local(out, truth, eval_info);
            irow = irow + 1;
            rows{irow} = make_alignment_trial_row_local(irow, scenario_trial_index, ...
                rng_seed, gate_modes{imode}, sc, truth, frontend_out, out, ...
                eval_info, truth_diag, runtime_sec);
        end
    end
end

trial_tbl = struct2table([rows{1:irow}]);
writetable(trial_tbl, fullfile(result_dir, 'step09_common_el_gate_alignment_trials.csv'));
summary_tbl = summarize_alignment_trials_local(trial_tbl, gate_modes);
keypoints_tbl = alignment_keypoints_local(trial_tbl, gate_modes);

writetable(summary_tbl, fullfile(result_dir, 'step09_common_el_gate_alignment_summary.csv'));
writetable(keypoints_tbl, fullfile(result_dir, 'step09_common_el_gate_alignment_keypoints.csv'));

plot_alignment_metric_local(summary_tbl, gate_modes, 'success_rate', ...
    fullfile(result_dir, 'gate_alignment_success_by_mode.png'), 'success rate');
plot_alignment_metric_local(summary_tbl, gate_modes, 'false_high_rate', ...
    fullfile(result_dir, 'gate_alignment_false_high_by_mode.png'), 'false-high rate');
plot_alignment_metric_local(summary_tbl, gate_modes, 'low_confidence_rate', ...
    fullfile(result_dir, 'gate_alignment_low_confidence_by_mode.png'), 'low-confidence rate');
plot_alignment_route_distribution_local(trial_tbl, gate_modes, ...
    fullfile(result_dir, 'gate_alignment_route_distribution.png'));

write_alignment_report_local(fullfile(result_dir, 'step09_common_el_gate_alignment_report.md'), ...
    summary_tbl, keypoints_tbl);
write_doc16_local(fullfile(script_dir, 'docs', '16_COMMON_EL_GATE_ALIGNMENT.md'), ...
    summary_tbl, keypoints_tbl, result_dir);
write_doc17_local(fullfile(script_dir, 'docs', '17_FINAL_BACKEND_DECISION.md'), ...
    keypoints_tbl, result_dir);

if str2double(string(keypoint_value_local(keypoints_tbl, 'gate_alignment_pass_flag'))) ~= 1
    write_prompt_b_outputs_local(script_dir, result_dir, keypoints_tbl);
end

disp(keypoints_tbl);

function scenarios = build_gate_alignment_scenarios_local(snr_list)
    template = make_alignment_scenario_local('template', NaN, 0, [], [], ...
        NaN, NaN, NaN, NaN, 'template', false, false, false);
    scenarios = repmat(template, 0, 1);

    az_sep_list = [0.15, 0.25, 0.4, 0.6, 0.8];
    phase_list = [0, 60];
    for isnr = 1:numel(snr_list)
        for isep = 1:numel(az_sep_list)
            for iphase = 1:numel(phase_list)
                sep = az_sep_list(isep);
                scenarios(end+1) = make_alignment_scenario_local( ... %#ok<AGROW>
                    'close_coherent_pair', snr_list(isnr), 2, ...
                    [-sep/2, sep/2], [0, 0], 1.0, 1.0, ...
                    phase_list(iphase), sep, 'single_peak_in_scope', true, false, false);
            end
        end
    end

    medium_sep = [0.25, 0.4, 0.6];
    medium_beta = [0.8, 0.5, 0.3];
    for isnr = 1:numel(snr_list)
        for isep = 1:numel(medium_sep)
            for ibeta = 1:numel(medium_beta)
                sep = medium_sep(isep);
                scenarios(end+1) = make_alignment_scenario_local( ... %#ok<AGROW>
                    'medium_beta_pair', snr_list(isnr), 2, ...
                    [-sep/2, sep/2], [0, 0], medium_beta(ibeta), ...
                    1.0, 0, sep, 'single_peak_in_scope', true, false, false);
            end
        end
    end

    for isnr = 1:numel(snr_list)
        scenarios(end+1) = make_alignment_scenario_local( ... %#ok<AGROW>
            'weak_target_boundary', snr_list(isnr), 2, [-0.125, 0.125], ...
            [0, 0], 0.1, 1.0, 0, 0.25, 'single_peak_in_scope', true, false, false);
    end

    for isnr = 1:numel(snr_list)
        for phase_deg = [150, 180]
            scenarios(end+1) = make_alignment_scenario_local( ... %#ok<AGROW>
                'near_antiphase_boundary', snr_list(isnr), 2, [-0.125, 0.125], ...
                [0, 0], 1.0, 1.0, phase_deg, 0.25, ...
                'single_peak_in_scope', true, false, true);
        end
    end

    for isnr = 1:numel(snr_list)
        scenarios(end+1) = make_alignment_scenario_local( ... %#ok<AGROW>
            'single_target_sanity', snr_list(isnr), 1, 0, 0, ...
            NaN, NaN, NaN, NaN, 'single_peak_in_scope', true, false, false);
    end

    for isnr = 1:numel(snr_list)
        scenarios(end+1) = make_alignment_scenario_local( ... %#ok<AGROW>
            'two_separated_coarse_peaks', snr_list(isnr), 2, [-2, 2], ...
            [0, 0], 1.0, 0.0, 0, 4.0, ...
            'two_separated_peaks_out_of_scope', false, false, false);
    end
end

function sc = make_alignment_scenario_local(name, snr_db, target_count, az, el, ...
    beta, rho, phase_deg, az_sep, frontend_state, unresolved, need2d, boundary)
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
    sc.frontend_state = char(frontend_state);
    sc.unresolved_cluster_flag = unresolved;
    sc.need_2d_refinement = need2d;
    sc.boundary_unreliable_flag = boundary;
    sc.coarseAz = mean_or_zero_local(az);
    sc.coarseEl = mean_or_zero_local(el);
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
    cfg.derotation_mode = 'none';
    cfg.min_pair_sep_deg = 0.12;
    cfg.max_pair_sep_deg = 1.2;
    cfg.music_peak2_ratio_min = 0.32;
    cfg.music_2d_peak2_ratio_min = 0.18;
    cfg.coherent_min_projection_score = 0.45;
    cfg.coherent_min_score_margin = 0;
    cfg.coherent_music_peak2_ratio_min = 0.08;
    cfg.rank1_lambda2_over_lambda1_max = 0.35;
end

function array_geom = make_array_geom_local()
    cfg = make_base_cfg_local();
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

function [raw_cube, frontend_out, truth, cfg] = synthesize_alignment_trial_local( ...
    array_geom, sc, base_cfg, rng_seed)
    rng(rng_seed, 'twister');
    cfg = base_cfg;
    raw_cube_clean = zeros(array_geom.Naz, array_geom.Nel, cfg.Np);
    p = 0:cfg.Np-1;
    s1 = exp(1j * 2 * pi * 0.07 * p);
    signals = zeros(max(1, sc.target_count), cfg.Np);
    signals(1, :) = s1;
    if sc.target_count >= 2
        phase = exp(1j * deg2rad(sc.phase_deg));
        if sc.rho >= 1
            s2 = sc.beta * phase * s1;
        else
            v = exp(1j * (2 * pi * 0.19 * p + 2 * pi * rand()));
            s2 = sc.beta * phase * (sc.rho * s1 + sqrt(max(0, 1 - sc.rho^2)) * v);
        end
        signals(2, :) = s2;
    end
    for it = 1:sc.target_count
        a = steering_full_local(array_geom, sc.az(it), sc.el(it));
        for ip = 1:cfg.Np
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
        'az_sep_deg', sc.az_sep_deg, 'SNR_dB', sc.SNR_dB, ...
        'rng_seed', rng_seed, 'noise_power', noise_power, 'clean_power', clean_power);
end

function a = steering_full_local(array_geom, az_deg, el_deg)
    kx = cosd(el_deg) * cosd(az_deg);
    ky = cosd(el_deg) * sind(az_deg);
    kz = sind(el_deg);
    phase = 2 * pi / array_geom.lambda * (array_geom.X * kx + array_geom.Y * ky + array_geom.Z * kz);
    a = exp(1j * phase);
end

function eval_info = evaluate_alignment_output_local(out, truth, sc)
    eval_info = struct();
    eval_info.success = false;
    eval_info.safe = false;
    eval_info.false_high = false;
    eval_info.false_split = false;
    eval_info.boundary_missed = false;
    eval_info.low_confidence = strcmp(string(getfield_default_local(out, 'confidence', 'low')), "low");
    eval_info.boundary_unreliable = strcmp(string(getfield_default_local(out, 'route_name', '')), "boundary_unreliable");
    eval_info.out_of_scope_reject = strcmp(string(getfield_default_local(out, 'route_name', '')), "frontend_reject") && ...
        strcmp(string(getfield_default_local(out, 'status', '')), "rejected");
    eval_info.az_error_mean = NaN;
    eval_info.el_error_mean = NaN;
    eval_info.az_error_max = NaN;
    eval_info.el_error_max = NaN;
    eval_info.failure_reason = "ok";
    status = string(getfield_default_local(out, 'status', ''));
    conf = string(getfield_default_local(out, 'confidence', 'low'));
    route = string(getfield_default_local(out, 'route_name', ''));
    high_medium = (conf == "medium" || conf == "high") && status ~= "rejected";
    az_est = getfield_default_local(out, 'az_est', []);
    el_est = getfield_default_local(out, 'el_est', []);

    if truth.target_count == 1
        if numel(az_est) >= 2 && high_medium
            eval_info.false_split = true;
            eval_info.false_high = true;
            eval_info.failure_reason = "single_target_false_split";
        elseif numel(az_est) == 1 && numel(el_est) == 1 && high_medium
            eval_info.az_error_mean = abs(wrap180_local(az_est(1) - truth.az(1)));
            eval_info.el_error_mean = abs(el_est(1) - truth.el(1));
            eval_info.az_error_max = eval_info.az_error_mean;
            eval_info.el_error_max = eval_info.el_error_mean;
            eval_info.success = eval_info.az_error_mean <= 0.3 && eval_info.el_error_mean <= 0.5;
        end
        eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
        return
    end

    [az_mean, el_mean, az_max, el_max, pair_ok] = pair_error_local( ...
        az_est, el_est, truth.az, truth.el);
    eval_info.az_error_mean = az_mean;
    eval_info.el_error_mean = el_mean;
    eval_info.az_error_max = az_max;
    eval_info.el_error_max = el_max;
    pair_success = pair_ok && az_mean <= 0.25 && el_mean <= 0.5;

    switch string(sc.scenario_name)
        case {"close_coherent_pair", "medium_beta_pair"}
            eval_info.success = pair_success && high_medium;
            eval_info.false_high = high_medium && ~eval_info.success;
            eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
        case "weak_target_boundary"
            eval_info.false_high = high_medium && ~pair_success;
            eval_info.safe = eval_info.low_confidence || eval_info.boundary_unreliable || ...
                status == "rejected" || (high_medium && pair_success);
        case "near_antiphase_boundary"
            eval_info.false_high = high_medium && ~pair_success;
            eval_info.boundary_missed = logical(sc.boundary_unreliable_flag) && ...
                ~(status == "rejected" || route == "boundary_unreliable" || eval_info.low_confidence);
            eval_info.safe = ~eval_info.false_high && ~eval_info.boundary_missed;
        case "two_separated_coarse_peaks"
            eval_info.success = eval_info.out_of_scope_reject;
            eval_info.false_high = high_medium;
            eval_info.safe = eval_info.out_of_scope_reject && ~eval_info.false_high;
        otherwise
            eval_info.success = pair_success && high_medium;
            eval_info.false_high = high_medium && ~eval_info.success;
            eval_info.safe = eval_info.success || eval_info.low_confidence || status == "rejected";
    end

    if eval_info.false_high
        eval_info.failure_reason = "false_high";
    elseif eval_info.boundary_missed
        eval_info.failure_reason = "boundary_missed";
    elseif ~eval_info.success && ~eval_info.safe
        eval_info.failure_reason = "not_success_and_not_safe";
    end
end

function truth_diag = truth_only_diagnostics_local(out, truth, eval_info)
    dbg = getfield_default_local(out, 'debug_info', struct());
    rank1_pair = getfield_default_local(dbg, 'rank1_best_az_pair', [NaN, NaN]);
    refocus_pair = getfield_default_local(dbg, 'refocus_best_az_pair', [NaN, NaN]);
    rank1_topk = getfield_default_local(dbg, 'rank1_topk_az_pairs', zeros(0, 2));
    refocus_topk = getfield_default_local(dbg, 'refocus_topk_az_pairs', zeros(0, 2));
    truth_diag = struct();
    truth_diag.rank1_truth_az_error = az_pair_error_only_local(rank1_pair, truth.az);
    truth_diag.refocus_truth_az_error = az_pair_error_only_local(refocus_pair, truth.az);
    truth_diag.truth_pair_in_rank1_top1 = truth_pair_in_topk_local(rank1_topk, truth.az, 1);
    truth_diag.truth_pair_in_rank1_top3 = truth_pair_in_topk_local(rank1_topk, truth.az, 3);
    truth_diag.truth_pair_in_rank1_top5 = truth_pair_in_topk_local(rank1_topk, truth.az, 5);
    truth_diag.truth_pair_in_refocus_top1 = truth_pair_in_topk_local(refocus_topk, truth.az, 1);
    truth_diag.truth_pair_in_refocus_top3 = truth_pair_in_topk_local(refocus_topk, truth.az, 3);
    truth_diag.truth_pair_in_refocus_top5 = truth_pair_in_topk_local(refocus_topk, truth.az, 5);
    rejected = strcmp(string(getfield_default_local(out, 'status', '')), "rejected");
    truth_diag.rank1_candidate_correct_but_rejected = ...
        truth_diag.truth_pair_in_rank1_top3 && rejected && ~eval_info.success;
    truth_diag.refocus_candidate_correct_but_rejected = ...
        truth_diag.truth_pair_in_refocus_top3 && rejected && ~eval_info.success;
end

function row = make_alignment_trial_row_local(trial_index, scenario_trial_index, ...
    rng_seed, gate_mode, sc, truth, frontend_out, out, eval_info, truth_diag, runtime_sec)
    dbg = getfield_default_local(out, 'debug_info', struct());
    row = struct();
    row.trial_index = trial_index;
    row.scenario_trial_index = scenario_trial_index;
    row.rng_seed = rng_seed;
    row.gate_mode = string(gate_mode);
    row.backend_mode = string(getfield_default_local(out, 'backend_mode', ''));
    row.scenario_name = string(sc.scenario_name);
    row.SNR_dB = sc.SNR_dB;
    row.target_count = sc.target_count;
    row.az_sep_deg = sc.az_sep_deg;
    row.beta = sc.beta;
    row.rho = sc.rho;
    row.phase_deg = sc.phase_deg;
    row.frontend_state = string(getfield_default_local(frontend_out, 'frontend_state', ''));
    row.frontend_boundary_unreliable_flag = logical(getfield_default_local(frontend_out, 'boundary_unreliable_flag', false));
    row.az_truth = string(mat2str(truth.az, 6));
    row.el_truth = string(mat2str(truth.el, 6));
    row.route_name = string(getfield_default_local(out, 'route_name', ''));
    row.status = string(getfield_default_local(out, 'status', ''));
    row.confidence = string(getfield_default_local(out, 'confidence', ''));
    row.az_est = string(mat2str(getfield_default_local(out, 'az_est', []), 6));
    row.el_est = string(mat2str(getfield_default_local(out, 'el_est', []), 6));
    row.reject_reason = string(getfield_default_local(out, 'reject_reason', ''));
    row.success = logical(eval_info.success);
    row.safe = logical(eval_info.safe);
    row.false_high = logical(eval_info.false_high);
    row.false_split = logical(eval_info.false_split);
    row.boundary_missed = logical(eval_info.boundary_missed);
    row.low_confidence = logical(eval_info.low_confidence);
    row.boundary_unreliable = logical(eval_info.boundary_unreliable);
    row.out_of_scope_reject = logical(eval_info.out_of_scope_reject);
    row.az_error_mean = eval_info.az_error_mean;
    row.el_error_mean = eval_info.el_error_mean;
    row.az_error_max = eval_info.az_error_max;
    row.el_error_max = eval_info.el_error_max;
    row.eval_failure_reason = string(eval_info.failure_reason);

    row.common_el_gate_mode_debug = string(getfield_default_local(dbg, 'common_el_gate_mode', gate_mode));
    row.common_el_proxy_flag = logical(getfield_default_local(dbg, 'common_el_proxy_flag', false));
    row.selected_common_el_gate_pass = logical(getfield_default_local(dbg, 'selected_common_el_gate_pass', false));
    row.rank1_without_common_el_gate_pass = logical(getfield_default_local(dbg, 'rank1_without_common_el_gate_pass', false));
    row.rank1_refocus_consensus_gate_pass = logical(getfield_default_local(dbg, 'rank1_refocus_consensus_gate_pass', false));
    row.rank1_refocus_pair_error_deg = getfield_default_local(dbg, 'rank1_refocus_pair_error_deg', NaN);
    row.rank1_refocus_pair_agree_tol_deg = getfield_default_local(dbg, 'rank1_refocus_pair_agree_tol_deg', NaN);
    row.low_cost_boundary_flag = logical(getfield_default_local(dbg, 'low_cost_boundary_flag', false));
    row.boundary_unreliable_flag_debug = logical(getfield_default_local(dbg, 'boundary_unreliable_flag', false));

    row.music_peak_count = getfield_default_local(dbg, 'music_peak_count', NaN);
    row.music_peak_sep_deg = getfield_default_local(dbg, 'music_peak_sep_deg', NaN);
    row.music_peak2_ratio = getfield_default_local(dbg, 'music_peak2_ratio', NaN);
    row.music_reliable_flag = logical(getfield_default_local(dbg, 'music_reliable_flag', false));
    row.music_failure_reason = string(getfield_default_local(dbg, 'music_failure_reason', 'not_available'));

    row.refocus_route_reliable = logical(getfield_default_local(dbg, 'refocus_route_reliable', false));
    row.refocus_score = getfield_default_local(dbg, 'refocus_score', NaN);
    row.refocus_score_gap = getfield_default_local(dbg, 'refocus_score_gap', NaN);
    row.refocus_peak_sharpness = getfield_default_local(dbg, 'refocus_peak_sharpness', NaN);
    row.refocus_best_az_pair = string(mat2str(getfield_default_local(dbg, 'refocus_best_az_pair', [NaN, NaN]), 6));
    row.common_el_proxy_failure_reason = string(getfield_default_local(dbg, 'common_el_proxy_failure_reason', 'not_available'));

    row.rank1_route_reliable = logical(getfield_default_local(dbg, 'rank1_route_reliable', false));
    row.rank1_score = getfield_default_local(dbg, 'rank1_score', NaN);
    row.rank1_score_gap = getfield_default_local(dbg, 'rank1_score_gap', NaN);
    row.rank1_residual = getfield_default_local(dbg, 'rank1_residual', NaN);
    row.rank1_best_az_pair = string(mat2str(getfield_default_local(dbg, 'rank1_best_az_pair', [NaN, NaN]), 6));
    row.rank1_failure_reason = string(getfield_default_local(dbg, 'rank1_failure_reason', 'not_available'));

    row.rank1_truth_az_error = truth_diag.rank1_truth_az_error;
    row.refocus_truth_az_error = truth_diag.refocus_truth_az_error;
    row.truth_pair_in_rank1_top1 = logical(truth_diag.truth_pair_in_rank1_top1);
    row.truth_pair_in_rank1_top3 = logical(truth_diag.truth_pair_in_rank1_top3);
    row.truth_pair_in_rank1_top5 = logical(truth_diag.truth_pair_in_rank1_top5);
    row.truth_pair_in_refocus_top1 = logical(truth_diag.truth_pair_in_refocus_top1);
    row.truth_pair_in_refocus_top3 = logical(truth_diag.truth_pair_in_refocus_top3);
    row.truth_pair_in_refocus_top5 = logical(truth_diag.truth_pair_in_refocus_top5);
    row.rank1_candidate_correct_but_rejected = logical(truth_diag.rank1_candidate_correct_but_rejected);
    row.refocus_candidate_correct_but_rejected = logical(truth_diag.refocus_candidate_correct_but_rejected);

    row.final_step87_route = string(getfield_default_local(dbg, 'final_step87_route', ''));
    row.final_confidence_flag = string(getfield_default_local(dbg, 'final_confidence_flag', ''));
    row.final_failure_reason = string(getfield_default_local(dbg, 'final_failure_reason', ''));
    row.runtime_sec = runtime_sec;
end

function summary_tbl = summarize_alignment_trials_local(T, gate_modes)
    rows = {};
    for imode = 1:numel(gate_modes)
        mode = string(gate_modes{imode});
        rows{end+1, 1} = summary_row_local(T, mode, "overall", NaN, NaN); %#ok<AGROW>
        mask_mode = string(T.gate_mode) == mode;
        idx = find(mask_mode).';
        scenario_u = strings(0, 1);
        az_u = zeros(0, 1);
        snr_u = zeros(0, 1);
        for ii = idx
            sc_now = string(T.scenario_name(ii));
            az_now = T.az_sep_deg(ii);
            snr_now = T.SNR_dB(ii);
            found = false;
            for iu = 1:numel(scenario_u)
                if scenario_u(iu) == sc_now && ...
                        same_scalar_nan_local(az_u(iu), az_now) && ...
                        same_scalar_nan_local(snr_u(iu), snr_now)
                    found = true;
                    break
                end
            end
            if ~found
                scenario_u(end+1, 1) = sc_now; %#ok<AGROW>
                az_u(end+1, 1) = az_now; %#ok<AGROW>
                snr_u(end+1, 1) = snr_now; %#ok<AGROW>
            end
        end
        for iu = 1:numel(scenario_u)
            rows{end+1, 1} = summary_row_local(T, mode, scenario_u(iu), ... %#ok<AGROW>
                az_u(iu), snr_u(iu));
        end
    end
    summary_tbl = struct2table([rows{:}]);
end

function row = summary_row_local(T, gate_mode, scenario_name, az_sep_deg, SNR_dB)
    mask = string(T.gate_mode) == gate_mode;
    if scenario_name ~= "overall"
        mask = mask & string(T.scenario_name) == scenario_name & ...
            same_nan_numeric_local(T.az_sep_deg, az_sep_deg) & T.SNR_dB == SNR_dB;
    end
    row = struct();
    row.gate_mode = gate_mode;
    row.scenario_name = scenario_name;
    row.az_sep_deg = az_sep_deg;
    row.SNR_dB = SNR_dB;
    row.trials = sum(mask);
    row.success_rate = mean_bool_local(T.success(mask));
    row.safe_rate = mean_bool_local(T.safe(mask));
    row.false_high_rate = mean_bool_local(T.false_high(mask));
    row.false_split_rate = mean_bool_local(T.false_split(mask));
    row.boundary_missed_rate = mean_bool_local(T.boundary_missed(mask));
    row.low_confidence_rate = mean_bool_local(T.low_confidence(mask));
    row.boundary_unreliable_rate = mean_bool_local(T.boundary_unreliable(mask));
    row.out_of_scope_reject_rate = mean_bool_local(T.out_of_scope_reject(mask));
    row.common_el_proxy_pass_rate = mean_bool_local(T.common_el_proxy_flag(mask));
    row.selected_gate_pass_rate = mean_bool_local(T.selected_common_el_gate_pass(mask));
    row.rank1_without_common_el_gate_pass_rate = mean_bool_local(T.rank1_without_common_el_gate_pass(mask));
    row.rank1_refocus_consensus_gate_pass_rate = mean_bool_local(T.rank1_refocus_consensus_gate_pass(mask));
    row.rank1_route_reliable_rate = mean_bool_local(T.rank1_route_reliable(mask));
    row.refocus_route_reliable_rate = mean_bool_local(T.refocus_route_reliable(mask));
    row.truth_rank1_top3_rate = mean_bool_local(T.truth_pair_in_rank1_top3(mask));
    row.truth_refocus_top3_rate = mean_bool_local(T.truth_pair_in_refocus_top3(mask));
    row.mean_az_error_success = mean_or_nan_local(T.az_error_mean(mask & T.success));
    row.mean_el_error_success = mean_or_nan_local(T.el_error_mean(mask & T.success));
    row.median_runtime_sec = median_or_nan_local(T.runtime_sec(mask));
    row.route_distribution = distribution_string_local(T.route_name(mask));
    row.confidence_distribution = distribution_string_local(T.confidence(mask));
end

function keypoints_tbl = alignment_keypoints_local(T, gate_modes)
    current = string(gate_modes{1});
    gate1 = string(gate_modes{2});
    gate2 = string(gate_modes{3});
    current_close = mode_scenario_mean_local(T, current, 'close_coherent_pair', 'success');
    gate1_close = mode_scenario_mean_local(T, gate1, 'close_coherent_pair', 'success');
    gate2_close = mode_scenario_mean_local(T, gate2, 'close_coherent_pair', 'success');
    close_improvement = gate2_close - current_close;
    gate1_false = mode_scenario_mean_local(T, gate1, 'overall', 'false_high');
    gate2_false = mode_scenario_mean_local(T, gate2, 'overall', 'false_high');
    gate2_weak_false = mode_scenario_mean_local(T, gate2, 'weak_target_boundary', 'false_high');
    gate2_near_false = mode_scenario_mean_local(T, gate2, 'near_antiphase_boundary', 'false_high');
    gate2_near_boundary_missed = mode_scenario_mean_local(T, gate2, 'near_antiphase_boundary', 'boundary_missed');
    gate2_single_false_split = mode_scenario_mean_local(T, gate2, 'single_target_sanity', 'false_split');
    gate2_two_reject = mode_scenario_mean_local(T, gate2, 'two_separated_coarse_peaks', 'out_of_scope_reject');

    pass_flag = gate2_close >= 0.50 && gate2_false <= 0.01 && ...
        gate2_weak_false <= 0.01 && gate2_near_false <= 0.01 && ...
        gate2_single_false_split <= 0.01 && gate2_two_reject >= 0.99 && ...
        close_improvement >= 0.30;
    blocker = classify_alignment_blocker_local(pass_flag, current_close, gate1_close, ...
        gate2_close, gate1_false, gate2_false, gate2_weak_false, gate2_near_false, ...
        gate2_single_false_split, gate2_two_reject, close_improvement);
    if pass_flag
        recommendation = "adopt_step09_interface_step87_reference_rank1_refocus_consensus_gate";
    else
        recommendation = "freeze_step09_backend_use_step87_verified_lazy_cascade";
    end

    rows = {};
    rows = add_kp_local(rows, 'total_trials', height(T), 'trial rows across all gate modes');
    rows = add_kp_local(rows, 'Metkl', 30, 'Monte Carlo trials per scenario point');
    rows = add_kp_local(rows, 'gate_modes', strjoin(string(gate_modes), ','), 'tested gate modes');
    rows = add_kp_local(rows, 'current_close_coherent_success_rate', current_close, 'Gate 0 current common-el proxy');
    rows = add_kp_local(rows, 'gate1_close_coherent_success_rate', gate1_close, 'rank1 without common-el proxy');
    rows = add_kp_local(rows, 'gate2_close_coherent_success_rate', gate2_close, 'rank1/refocus consensus gate');
    rows = add_kp_local(rows, 'gate2_close_improvement_over_current', close_improvement, 'Gate 2 minus Gate 0');
    rows = add_kp_local(rows, 'gate1_overall_false_high_rate', gate1_false, 'safety diagnostic');
    rows = add_kp_local(rows, 'gate2_overall_false_high_rate', gate2_false, 'must be <= 0.01');
    rows = add_kp_local(rows, 'gate2_weak_false_high_rate', gate2_weak_false, 'must be <= 0.01');
    rows = add_kp_local(rows, 'gate2_near_antiphase_false_high_rate', gate2_near_false, 'must be <= 0.01');
    rows = add_kp_local(rows, 'gate2_near_antiphase_boundary_missed_rate', gate2_near_boundary_missed, 'diagnostic');
    rows = add_kp_local(rows, 'gate2_single_target_false_split_rate', gate2_single_false_split, 'must be <= 0.01');
    rows = add_kp_local(rows, 'gate2_two_separated_reject_out_of_scope_rate', gate2_two_reject, 'must be >= 0.99');
    rows = add_kp_local(rows, 'current_common_el_proxy_pass_rate', ...
        mode_scenario_mean_local(T, current, 'overall', 'common_el_proxy_flag'), 'current common-el proxy pass');
    rows = add_kp_local(rows, 'gate2_rank1_route_reliable_rate', ...
        mode_scenario_mean_local(T, gate2, 'overall', 'rank1_route_reliable'), 'rank1 route reliable');
    rows = add_kp_local(rows, 'gate2_rank1_refocus_consensus_gate_pass_rate', ...
        mode_scenario_mean_local(T, gate2, 'overall', 'rank1_refocus_consensus_gate_pass'), 'shadow/selected gate pass');
    rows = add_kp_local(rows, 'gate2_truth_rank1_top3_rate', ...
        mode_scenario_mean_local(T, gate2, 'overall', 'truth_pair_in_rank1_top3'), 'truth-only diagnostic');
    rows = add_kp_local(rows, 'gate2_truth_refocus_top3_rate', ...
        mode_scenario_mean_local(T, gate2, 'overall', 'truth_pair_in_refocus_top3'), 'truth-only diagnostic');
    rows = add_kp_local(rows, 'gate_alignment_pass_flag', double(pass_flag), 'Gate 2 pass/fail');
    rows = add_kp_local(rows, 'main_blocker_type', blocker, 'rule-based blocker classification');
    rows = add_kp_local(rows, 'blocker_if_any', blocker, 'rule-based blocker');
    rows = add_kp_local(rows, 'final_recommendation', recommendation, 'decision');
    keypoints_tbl = struct2table([rows{:}]);
end

function blocker = classify_alignment_blocker_local(pass_flag, current_close, gate1_close, ...
    gate2_close, gate1_false, gate2_false, gate2_weak_false, gate2_near_false, ...
    gate2_single_false_split, gate2_two_reject, close_improvement)
    if pass_flag
        blocker = "none";
    elseif gate1_close > current_close + 0.10 && gate1_false > 0.01 && gate2_close < 0.50
        blocker = "consensus_gate_failed_rank1_only_unsafe";
    elseif gate1_close <= current_close + 0.01 && gate2_close <= current_close + 0.01
        blocker = "gate_alignment_failed_close_coherent_not_recoverable";
    elseif gate2_close > current_close && (gate2_false > 0.01 || gate2_weak_false > 0.01 || ...
            gate2_near_false > 0.01 || gate2_single_false_split > 0.01 || gate2_two_reject < 0.99)
        blocker = "gate_alignment_failed_false_high";
    elseif close_improvement < 0.30 || gate2_close < 0.50
        blocker = "gate_alignment_failed_close_coherent_not_recoverable";
    else
        blocker = "gate_alignment_failed_false_high";
    end
end

function plot_alignment_metric_local(S, gate_modes, metric_name, path_out, y_label)
    S = S(string(S.scenario_name) ~= "overall", :);
    scenarios = unique(string(S.scenario_name), 'stable');
    data = NaN(numel(scenarios), numel(gate_modes));
    for is = 1:numel(scenarios)
        for im = 1:numel(gate_modes)
            mask = string(S.scenario_name) == scenarios(is) & string(S.gate_mode) == string(gate_modes{im});
            if any(mask)
                data(is, im) = S.(metric_name)(find(mask, 1));
            end
        end
    end
    fig = figure('Visible', 'off');
    bar(data);
    grid on
    ylim([0, 1]);
    ylabel(y_label);
    title(strrep(metric_name, '_', ' '));
    xticks(1:numel(scenarios));
    xticklabels(strrep(cellstr(scenarios), '_', '\_'));
    xtickangle(25);
    legend(strrep(gate_modes, '_', '\_'), 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_alignment_route_distribution_local(T, gate_modes, path_out)
    routes = unique(string(T.route_name), 'stable');
    data = zeros(numel(gate_modes), numel(routes));
    for im = 1:numel(gate_modes)
        for ir = 1:numel(routes)
            data(im, ir) = sum(string(T.gate_mode) == string(gate_modes{im}) & ...
                string(T.route_name) == routes(ir));
        end
    end
    fig = figure('Visible', 'off');
    bar(data, 'stacked');
    grid on
    ylabel('trials');
    title('Route Distribution by Gate Mode');
    xticks(1:numel(gate_modes));
    xticklabels(strrep(gate_modes, '_', '\_'));
    xtickangle(20);
    legend(strrep(cellstr(routes), '_', '\_'), 'Location', 'bestoutside');
    saveas(fig, path_out);
    close(fig);
end

function write_alignment_report_local(report_path, S, K)
    fid = fopen(report_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Step09 Common-El Gate Alignment\n\n');
    fprintf(fid, 'This decision run uses only `cfg.backend_mode = ''step87_reference''` and tests three common-el gate modes. It does not use truth in route decisions.\n\n');
    write_keypoints_table_local(fid, K);
    fprintf(fid, '\n## Summary\n\n');
    write_summary_table_local(fid, S);
    fprintf(fid, '\n## Figures\n\n');
    fprintf(fid, '- `gate_alignment_success_by_mode.png`\n');
    fprintf(fid, '- `gate_alignment_false_high_by_mode.png`\n');
    fprintf(fid, '- `gate_alignment_low_confidence_by_mode.png`\n');
    fprintf(fid, '- `gate_alignment_route_distribution.png`\n');
end

function write_doc16_local(doc_path, S, K, result_dir)
    gate2_pass = str2double(string(keypoint_value_local(K, 'gate_alignment_pass_flag'))) == 1;
    blocker = string(keypoint_value_local(K, 'blocker_if_any'));
    cand_fail = str2double(string(keypoint_value_local(K, 'gate2_truth_rank1_top3_rate'))) < 0.5 && ...
        str2double(string(keypoint_value_local(K, 'gate2_truth_refocus_top3_rate'))) < 0.5;
    truth_rank1 = str2double(string(keypoint_value_local(K, 'gate2_truth_rank1_top3_rate')));
    truth_refocus = str2double(string(keypoint_value_local(K, 'gate2_truth_refocus_top3_rate')));
    current_close = str2double(string(keypoint_value_local(K, 'current_close_coherent_success_rate')));
    common_el = str2double(string(keypoint_value_local(K, 'current_common_el_proxy_pass_rate')));
    rank1_reliable = str2double(string(keypoint_value_local(K, 'gate2_rank1_route_reliable_rate')));
    fid = fopen(doc_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Common-El Gate Alignment\n\n');
    fprintf(fid, '## Motivation\n\n');
    fprintf(fid, 'Commit `d4d025d` showed that the Step09 `step87_reference` backend is callable and recovers the large-elevation bridge case, but close-coherent trials still collapse to low confidence. The focused diagnostics reported `rank1_truth_top3_rate = 0.70439`, `refocus_truth_top3_rate = 0.68684`, `common_el_proxy_pass_rate = 0`, and `rank1_route_reliable_rate = 0.91491`. That points to a common-el gate mismatch rather than a pure candidate-generation failure.\n\n');
    fprintf(fid, '## Answers\n\n');
    fprintf(fid, '1. Candidate generation fails: %s.\n', yes_no_text_local(cand_fail));
    fprintf(fid, '2. Truth enters top-K: rank1 top3 = %.6f, refocus top3 = %.6f.\n', truth_rank1, truth_refocus);
    fprintf(fid, '3. Gate that rejects it: the current common-el proxy pass rate is %.6f and close-coherent success under Gate 0 is %.6f; Gate 2 replaces only the rank1 fallback gate with rank1/refocus consensus.\n', common_el, current_close);
    fprintf(fid, '4. Common-el proxy pass rate: %.6f.\n', common_el);
    fprintf(fid, '5. Rank1 route reliable rate: %.6f.\n', rank1_reliable);
    fprintf(fid, '6. Main blocker: `%s`.\n', blocker);
    fprintf(fid, '7. Next step: %s.\n\n', next_step_text_local(gate2_pass));
    fprintf(fid, '## Gate Definitions\n\n');
    fprintf(fid, '- Gate 0, `current_common_el_proxy`: the historical common-el proxy remains unchanged and is the default.\n');
    fprintf(fid, '- Gate 1, `rank1_reliable_without_common_el_proxy`: rank1 can pass when rank1 reliability, finite pair, separation, and boundary guards pass, without using the common-el proxy.\n');
    fprintf(fid, '- Gate 2, `rank1_refocus_consensus_gate`: rank1 can pass only when rank1 and refocus are both reliable, both pairs are valid, boundary guards pass, and swap-invariant pair disagreement is <= `0.12 deg`.\n\n');
    fprintf(fid, 'Result directory: `%s`.\n\n', result_dir);
    fprintf(fid, '## Result\n\n');
    write_keypoints_table_local(fid, K);
    fprintf(fid, '\n## Scenario Summary\n\n');
    write_summary_table_local(fid, S);
    fprintf(fid, '\n## Gate 2 Decision\n\n');
    if gate2_pass
        fprintf(fid, 'Gate 2 passed the requested decision rule. The next route is Step09 interface plus `step87_reference` backend with `rank1_refocus_consensus_gate`.\n');
    else
        fprintf(fid, 'Gate 2 did not pass the requested decision rule. Main blocker: `%s`. The next route is to stop tuning the Step09 backend and use the Step8.7 verified lazy cascade as the final backend evidence, while Step09 remains the interface/documentation layer.\n', blocker);
    end
end

function write_doc17_local(doc_path, K, result_dir)
    gate2_pass = str2double(string(keypoint_value_local(K, 'gate_alignment_pass_flag'))) == 1;
    recommendation = string(keypoint_value_local(K, 'final_recommendation'));
    blocker = string(keypoint_value_local(K, 'blocker_if_any'));
    fid = fopen(doc_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Final Backend Decision\n\n');
    fprintf(fid, 'Decision source: `%s`.\n\n', result_dir);
    if gate2_pass
        fprintf(fid, 'Final decision: use the Step09 interface with `cfg.backend_mode = ''step87_reference''` and `cfg.common_el_gate_mode = ''rank1_refocus_consensus_gate''`.\n\n');
    else
        fprintf(fid, 'Final decision: do not adopt `step87_reference` as the Step09 default backend. Freeze Step09 backend tuning. Use the original Step8.7 verified lazy cascade as the final backend evidence; keep Step09 as the interface and documentation layer.\n\n');
    end
    fprintf(fid, '- `gate_alignment_pass_flag`: `%s`\n', safe_string_local(keypoint_value_local(K, 'gate_alignment_pass_flag')));
    fprintf(fid, '- `blocker_if_any`: `%s`\n', blocker);
    fprintf(fid, '- `final_recommendation`: `%s`\n', recommendation);
end

function write_prompt_b_outputs_local(script_dir, result_dir, K)
    write_doc18_local(fullfile(script_dir, 'docs', '18_FALLBACK_TO_STEP87_FINAL_DECISION.md'), K, result_dir);
    write_doc19_local(fullfile(script_dir, 'docs', '19_FINAL_THESIS_ROUTE_SUMMARY.md'), K, result_dir);
    write_final_decision_csv_local(fullfile(script_dir, 'results_step09_final_decision.csv'), K, result_dir);
end

function write_doc18_local(doc_path, K, result_dir)
    fid = fopen(doc_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Fallback to Step8.7 Final Decision\n\n');
    fprintf(fid, 'The common-el gate alignment experiment failed the requested Gate 2 pass rule. Step09 backend tuning is frozen.\n\n');
    fprintf(fid, '- Result directory: `%s`\n', result_dir);
    fprintf(fid, '- `gate_alignment_pass_flag`: `%s`\n', safe_string_local(keypoint_value_local(K, 'gate_alignment_pass_flag')));
    fprintf(fid, '- `blocker_if_any`: `%s`\n', safe_string_local(keypoint_value_local(K, 'blocker_if_any')));
    fprintf(fid, '- Recommendation: `freeze_step09_backend_use_step87_verified_lazy_cascade`\n\n');
    fprintf(fid, 'Final route: use the original Step8.7 verified lazy cascade as the backend evidence. Step09 remains the interface/documentation layer and should not be tuned further for close-coherent recovery in this thesis line.\n');
end

function write_doc19_local(doc_path, K, result_dir)
    fid = fopen(doc_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Final Thesis Route Summary\n\n');
    fprintf(fid, 'The thesis route keeps the frontend-to-shared-center interface and the conservative route evidence, but it does not claim a new Step09 backend threshold fix.\n\n');
    fprintf(fid, '- Step09 interface: retained.\n');
    fprintf(fid, '- Step87 reference backend inside Step09: diagnostic only, not default.\n');
    fprintf(fid, '- Final backend evidence: original Step8.7 verified lazy cascade.\n');
    fprintf(fid, '- Frozen blocker: `%s`.\n', safe_string_local(keypoint_value_local(K, 'blocker_if_any')));
    fprintf(fid, '- Decision evidence: `%s`.\n\n', result_dir);
    fprintf(fid, 'Do not add dual-center, V2/complex-gain, Step8.10 unified model selection, learning, or extra threshold tuning to close this route.\n');
end

function write_final_decision_csv_local(csv_path, K, result_dir)
    rows = {};
    rows = add_kp_local(rows, 'decision_source', result_dir, 'common-el gate alignment output directory');
    rows = add_kp_local(rows, 'gate_alignment_pass_flag', keypoint_value_local(K, 'gate_alignment_pass_flag'), 'Gate 2 pass/fail');
    rows = add_kp_local(rows, 'blocker_if_any', keypoint_value_local(K, 'blocker_if_any'), 'failure blocker');
    rows = add_kp_local(rows, 'final_recommendation', 'freeze_step09_backend_use_step87_verified_lazy_cascade', 'final fallback decision');
    T = struct2table([rows{:}]);
    writetable(T, csv_path);
end

function write_keypoints_table_local(fid, K)
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(K)
        fprintf(fid, '| `%s` | %s | %s |\n', safe_string_local(K.keypoint(i)), ...
            safe_string_local(K.value(i)), safe_string_local(K.note(i)));
    end
end

function write_summary_table_local(fid, S)
    fprintf(fid, '| gate_mode | scenario_name | az_sep_deg | SNR_dB | trials | success_rate | false_high_rate | false_split_rate | low_confidence_rate | out_of_scope_reject_rate | selected_gate_pass_rate | route_distribution |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n');
    for i = 1:height(S)
        fprintf(fid, '| `%s` | `%s` | %.3g | %.3g | %d | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | `%s` |\n', ...
            safe_string_local(S.gate_mode(i)), safe_string_local(S.scenario_name(i)), ...
            S.az_sep_deg(i), S.SNR_dB(i), S.trials(i), S.success_rate(i), S.false_high_rate(i), ...
            S.false_split_rate(i), S.low_confidence_rate(i), ...
            S.out_of_scope_reject_rate(i), S.selected_gate_pass_rate(i), ...
            safe_string_local(S.route_distribution(i)));
    end
end

function txt = yes_no_text_local(tf)
    if tf
        txt = 'yes';
    else
        txt = 'no';
    end
end

function txt = next_step_text_local(gate2_pass)
    if gate2_pass
        txt = 'adopt threshold-free consensus gating on the Step09 interface and keep the Step87 reference backend as the active decision path';
    else
        txt = 'freeze Step09 backend tuning and fall back to the original Step8.7 verified lazy cascade as final backend evidence';
    end
end

function tf = same_nan_numeric_local(values, target)
    if isnan(target)
        tf = isnan(values);
    else
        tf = abs(values - target) < 1e-9;
    end
end

function tf = same_scalar_nan_local(a, b)
    if isnan(a) && isnan(b)
        tf = true;
    else
        tf = abs(a - b) < 1e-9;
    end
end

function [az_mean, el_mean, az_max, el_max, ok] = pair_error_local(az_est, el_est, az_true, el_true)
    az_mean = NaN;
    el_mean = NaN;
    az_max = NaN;
    el_max = NaN;
    ok = false;
    if numel(az_est) < 2 || numel(el_est) < 2 || numel(az_true) < 2 || numel(el_true) < 2
        return
    end
    est = [az_est(:), el_est(:)];
    truth = [az_true(:), el_true(:)];
    d11 = norm(est(1, :) - truth(1, :)) + norm(est(2, :) - truth(2, :));
    d12 = norm(est(1, :) - truth(2, :)) + norm(est(2, :) - truth(1, :));
    if d12 < d11
        truth = flipud(truth);
    end
    az_err = wrap180_local(est(:, 1).' - truth(:, 1).');
    el_err = est(:, 2).' - truth(:, 2).';
    az_mean = mean(abs(az_err));
    el_mean = mean(abs(el_err));
    az_max = max(abs(az_err));
    el_max = max(abs(el_err));
    ok = all(isfinite([az_mean, el_mean, az_max, el_max]));
end

function err = az_pair_error_only_local(az_est, az_true)
    err = NaN;
    if numel(az_est) < 2 || numel(az_true) < 2
        return
    end
    az_est = sort(az_est(1:2));
    az_true = sort(az_true(1:2));
    if any(~isfinite(az_est)) || any(~isfinite(az_true))
        return
    end
    err = max(abs(wrap180_local(az_est - az_true)));
end

function tf = truth_pair_in_topk_local(topk_pairs, az_true, k)
    tf = false;
    if isempty(topk_pairs) || numel(az_true) < 2
        return
    end
    n = min(k, size(topk_pairs, 1));
    for i = 1:n
        err = az_pair_error_only_local(topk_pairs(i, :), az_true);
        if isfinite(err) && err <= 0.05
            tf = true;
            return
        end
    end
end

function value = mode_scenario_mean_local(T, gate_mode, scenario_name, col)
    mask = string(T.gate_mode) == string(gate_mode);
    if string(scenario_name) ~= "overall"
        mask = mask & string(T.scenario_name) == string(scenario_name);
    end
    if ~any(mask)
        value = NaN;
        return
    end
    value = mean(double(T.(char(col))(mask)));
end

function rows = add_kp_local(rows, key, value, note)
    rows{end+1, 1} = struct('keypoint', safe_string_local(key), ...
        'value', safe_string_local(value), 'note', safe_string_local(note));
end

function value = keypoint_value_local(K, key)
    mask = string(K.keypoint) == string(key);
    if any(mask)
        value = K.value(find(mask, 1, 'first'));
    else
        value = "NaN";
    end
end

function txt = distribution_string_local(vals)
    vals = string(vals);
    if isempty(vals)
        txt = "";
        return
    end
    u = unique(vals, 'stable');
    parts = strings(1, numel(u));
    for i = 1:numel(u)
        parts(i) = sprintf('%s:%d', u(i), sum(vals == u(i)));
    end
    txt = strjoin(parts, ';');
end

function val = mean_bool_local(x)
    if isempty(x)
        val = NaN;
    else
        val = mean(double(x));
    end
end

function val = mean_or_nan_local(x)
    x = x(isfinite(x));
    if isempty(x)
        val = NaN;
    else
        val = mean(x);
    end
end

function val = median_or_nan_local(x)
    x = x(isfinite(x));
    if isempty(x)
        val = NaN;
    else
        val = median(x);
    end
end

function val = mean_or_zero_local(x)
    if isempty(x) || all(isnan(x))
        val = 0;
    else
        val = mean(x, 'omitnan');
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

function val = getfield_default_local(s, name, default_val)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        val = s.(name);
    else
        val = default_val;
    end
end

function x = wrap180_local(x)
    x = mod(x + 180, 360) - 180;
end
