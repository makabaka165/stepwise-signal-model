% Step09 close-coherent gate diagnostics.
% Purpose: locate why close-coherent Step87 reference backend trials are
% rejected by route gates. This script is diagnostic only: it does not tune
% thresholds or change the Step09 default backend.
% Output directory: results_step09_close_coherent_gate_diagnostics/.

clc
clear

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
addpath(fullfile(script_dir, 'main'));

result_dir = fullfile(script_dir, 'results_step09_close_coherent_gate_diagnostics');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

array_geom = make_array_geom_local();
base_cfg = make_base_cfg_local();
Metkl = 30;
scenarios = build_gate_diagnostic_scenarios_local([8, 16]);
rng_seed_base = 909701;
rows = cell(numel(scenarios) * Metkl, 1);
irow = 0;

for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    for imc = 1:Metkl
        trial_index = irow + 1;
        rng_seed = rng_seed_base + trial_index;
        [raw_cube, frontend_out, truth, cfg] = synthesize_gate_trial_local( ...
            array_geom, sc, base_cfg, rng_seed);

        cfg.backend_mode = 'step09_light';
        out_light = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);

        cfg.backend_mode = 'step87_reference';
        t0 = tic;
        out_ref = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
        runtime_sec = toc(t0);

        eval_info = evaluate_gate_output_local(out_ref, truth);
        truth_diag = truth_only_diagnostics_local(out_ref, truth, eval_info);

        irow = irow + 1;
        rows{irow} = make_gate_trial_row_local(trial_index, rng_seed, sc, truth, ...
            out_ref, out_light, eval_info, truth_diag, runtime_sec);
    end
end

trial_tbl = struct2table([rows{1:irow}]);
summary_tbl = summarize_gate_trials_local(trial_tbl);
keypoints_tbl = gate_keypoints_local(trial_tbl);

writetable(trial_tbl, fullfile(result_dir, 'step09_close_coherent_gate_trials.csv'));
writetable(summary_tbl, fullfile(result_dir, 'step09_close_coherent_gate_summary.csv'));
writetable(keypoints_tbl, fullfile(result_dir, 'step09_close_coherent_gate_keypoints.csv'));

plot_rank1_truth_error_hist_local(trial_tbl, ...
    fullfile(result_dir, 'step09_rank1_truth_error_hist.png'));
plot_rank1_score_vs_error_local(trial_tbl, ...
    fullfile(result_dir, 'step09_rank1_score_vs_error.png'));
plot_refocus_score_vs_rank1_score_local(trial_tbl, ...
    fullfile(result_dir, 'step09_refocus_score_vs_rank1_score.png'));
plot_gate_failure_distribution_local(trial_tbl, ...
    fullfile(result_dir, 'step09_gate_failure_distribution.png'));

write_gate_report_local(fullfile(result_dir, 'step09_close_coherent_gate_report.md'), ...
    summary_tbl, keypoints_tbl);
write_gate_doc_local(fullfile(script_dir, 'docs', '15_CLOSE_COHERENT_GATE_DIAGNOSTICS.md'), ...
    summary_tbl, keypoints_tbl, result_dir);

disp(keypoints_tbl);

function scenarios = build_gate_diagnostic_scenarios_local(snr_list)
    template = make_gate_scenario_local('template', NaN, NaN, NaN, NaN, NaN, NaN);
    scenarios = repmat(template, 0, 1);

    az_sep_list = [0.15, 0.25, 0.4, 0.6, 0.8];
    phase_list = [0, 60];
    for isnr = 1:numel(snr_list)
        for isep = 1:numel(az_sep_list)
            for iphase = 1:numel(phase_list)
                scenarios(end+1) = make_gate_scenario_local('close_coherent_pair', ...
                    snr_list(isnr), az_sep_list(isep), 1.0, 1.0, phase_list(iphase), 0); %#ok<AGROW>
            end
        end
    end

    medium_sep = [0.25, 0.4, 0.6];
    medium_beta = [0.8, 0.5, 0.3];
    for isnr = 1:numel(snr_list)
        for isep = 1:numel(medium_sep)
            for ibeta = 1:numel(medium_beta)
                scenarios(end+1) = make_gate_scenario_local('medium_beta_pair', ...
                    snr_list(isnr), medium_sep(isep), medium_beta(ibeta), 1.0, 0, 0); %#ok<AGROW>
            end
        end
    end
end

function sc = make_gate_scenario_local(name, snr_db, az_sep, beta, rho, phase_deg, el_common)
    az = [-az_sep/2, az_sep/2];
    el = [el_common, el_common];
    sc = struct('scenario_name', char(name), 'SNR_dB', snr_db, ...
        'target_count', 2, 'az_sep_deg', az_sep, 'az', az, 'el', el, ...
        'beta', beta, 'rho', rho, 'phase_deg', phase_deg, ...
        'frontend_state', 'single_peak_in_scope', 'unresolved_cluster_flag', true, ...
        'need_2d_refinement', false, 'boundary_unreliable_flag', false, ...
        'coarseAz', mean(az), 'coarseEl', mean(el));
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

function [raw_cube, frontend_out, truth, cfg] = synthesize_gate_trial_local(array_geom, sc, base_cfg, rng_seed)
    rng(rng_seed, 'twister');
    cfg = base_cfg;
    raw_cube_clean = zeros(array_geom.Naz, array_geom.Nel, cfg.Np);
    p = 0:cfg.Np-1;
    s1 = exp(1j * 2 * pi * 0.07 * p);
    phase = exp(1j * deg2rad(sc.phase_deg));
    if sc.rho >= 1
        s2 = sc.beta * phase * s1;
    else
        v = exp(1j * (2 * pi * 0.19 * p + 2 * pi * rand()));
        s2 = sc.beta * phase * (sc.rho * s1 + sqrt(max(0, 1 - sc.rho^2)) * v);
    end
    signals = [s1; s2];
    for it = 1:2
        a = steering_full_local(array_geom, sc.az(it), sc.el(it));
        for ip = 1:cfg.Np
            raw_cube_clean(:, :, ip) = raw_cube_clean(:, :, ip) + a * signals(it, ip);
        end
    end
    clean_power = mean(abs(raw_cube_clean(:)).^2);
    noise_power = clean_power / max(10^(sc.SNR_dB / 10), eps);
    noise = sqrt(noise_power / 2) * (randn(size(raw_cube_clean)) + 1j * randn(size(raw_cube_clean)));
    raw_cube = raw_cube_clean + noise;
    frontend_out = struct('rangeIdx', 1, 'dopplerIdx', 1, 'coarseAz', sc.coarseAz, ...
        'coarseEl', sc.coarseEl, 'frontend_state', sc.frontend_state, ...
        'unresolved_cluster_flag', sc.unresolved_cluster_flag, ...
        'need_2d_refinement', sc.need_2d_refinement, ...
        'boundary_unreliable_flag', sc.boundary_unreliable_flag);
    truth = struct('target_count', 2, 'az', sc.az, 'el', sc.el, ...
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

function eval_info = evaluate_gate_output_local(out, truth)
    eval_info = struct();
    eval_info.success = false;
    eval_info.false_high = false;
    eval_info.boundary_missed = false;
    eval_info.low_confidence = strcmp(string(getfield_default_local(out, 'confidence', 'low')), 'low');
    eval_info.az_error_mean = NaN;
    eval_info.el_error_mean = NaN;
    az_est = getfield_default_local(out, 'az_est', []);
    el_est = getfield_default_local(out, 'el_est', []);
    [az_mean, el_mean, pair_ok] = pair_error_local(az_est, el_est, truth.az, truth.el);
    eval_info.az_error_mean = az_mean;
    eval_info.el_error_mean = el_mean;
    eval_info.success = pair_ok && az_mean <= 0.25 && el_mean <= 0.5 && ~eval_info.low_confidence;
    eval_info.false_high = ~eval_info.success && ~eval_info.low_confidence && ...
        ~strcmp(string(getfield_default_local(out, 'status', '')), 'rejected');
    eval_info.boundary_missed = false;
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
    rejected = strcmp(string(getfield_default_local(out, 'status', '')), 'rejected');
    truth_diag.rank1_candidate_correct_but_rejected = ...
        truth_diag.truth_pair_in_rank1_top3 && rejected && ~eval_info.success;
    truth_diag.refocus_candidate_correct_but_rejected = ...
        truth_diag.truth_pair_in_refocus_top3 && rejected && ~eval_info.success;
end

function row = make_gate_trial_row_local(trial_index, rng_seed, sc, truth, out_ref, out_light, eval_info, truth_diag, runtime_sec)
    dbg = getfield_default_local(out_ref, 'debug_info', struct());
    row = struct();
    row.trial_index = trial_index;
    row.rng_seed = rng_seed;
    row.scenario_name = string(sc.scenario_name);
    row.SNR_dB = sc.SNR_dB;
    row.az_sep_deg = sc.az_sep_deg;
    row.beta = sc.beta;
    row.rho = sc.rho;
    row.phase_deg = sc.phase_deg;
    row.az_truth = string(mat2str(truth.az, 6));
    row.el_truth = string(mat2str(truth.el, 6));
    row.route_name = string(getfield_default_local(out_ref, 'route_name', ''));
    row.status = string(getfield_default_local(out_ref, 'status', ''));
    row.confidence = string(getfield_default_local(out_ref, 'confidence', ''));
    row.az_est = string(mat2str(getfield_default_local(out_ref, 'az_est', []), 6));
    row.el_est = string(mat2str(getfield_default_local(out_ref, 'el_est', []), 6));
    row.success = logical(eval_info.success);
    row.false_high = logical(eval_info.false_high);
    row.boundary_missed = logical(eval_info.boundary_missed);
    row.reject_reason = string(getfield_default_local(out_ref, 'reject_reason', ''));
    row.light_route_name = string(getfield_default_local(out_light, 'route_name', ''));
    row.light_status = string(getfield_default_local(out_light, 'status', ''));
    row.light_confidence = string(getfield_default_local(out_light, 'confidence', ''));

    row.music_peak_count = getfield_default_local(dbg, 'music_peak_count', NaN);
    row.music_peak_sep_deg = getfield_default_local(dbg, 'music_peak_sep_deg', NaN);
    row.music_peak2_ratio = getfield_default_local(dbg, 'music_peak2_ratio', NaN);
    row.music_reliable_flag = logical(getfield_default_local(dbg, 'music_reliable_flag', false));

    row.common_el_proxy_flag = logical(getfield_default_local(dbg, 'common_el_proxy_flag', false));
    row.common_el_proxy_failure_reason = string(getfield_default_local(dbg, 'common_el_proxy_failure_reason', 'not_available'));
    row.refocus_score = getfield_default_local(dbg, 'refocus_score', NaN);
    row.refocus_score_gap = getfield_default_local(dbg, 'refocus_score_gap', NaN);
    row.refocus_best_az_pair = string(mat2str(getfield_default_local(dbg, 'refocus_best_az_pair', [NaN, NaN]), 6));
    row.refocus_truth_az_error = truth_diag.refocus_truth_az_error;
    row.refocus_candidate_correct_but_rejected = logical(truth_diag.refocus_candidate_correct_but_rejected);
    row.truth_pair_in_refocus_top1 = logical(truth_diag.truth_pair_in_refocus_top1);
    row.truth_pair_in_refocus_top3 = logical(truth_diag.truth_pair_in_refocus_top3);
    row.truth_pair_in_refocus_top5 = logical(truth_diag.truth_pair_in_refocus_top5);

    row.rank1_score = getfield_default_local(dbg, 'rank1_score', NaN);
    row.rank1_score_gap = getfield_default_local(dbg, 'rank1_score_gap', NaN);
    row.rank1_residual = getfield_default_local(dbg, 'rank1_residual', NaN);
    row.rank1_best_az_pair = string(mat2str(getfield_default_local(dbg, 'rank1_best_az_pair', [NaN, NaN]), 6));
    row.rank1_truth_az_error = truth_diag.rank1_truth_az_error;
    row.rank1_route_reliable = logical(getfield_default_local(dbg, 'rank1_route_reliable', false));
    row.rank1_candidate_correct_but_rejected = logical(truth_diag.rank1_candidate_correct_but_rejected);
    row.truth_pair_in_rank1_top1 = logical(truth_diag.truth_pair_in_rank1_top1);
    row.truth_pair_in_rank1_top3 = logical(truth_diag.truth_pair_in_rank1_top3);
    row.truth_pair_in_rank1_top5 = logical(truth_diag.truth_pair_in_rank1_top5);

    row.low_cost_boundary_flag = logical(getfield_default_local(dbg, 'low_cost_boundary_flag', false));
    row.boundary_unreliable_flag = logical(getfield_default_local(dbg, 'boundary_unreliable_flag', false));
    row.final_step87_route = string(getfield_default_local(dbg, 'final_step87_route', ''));
    row.final_confidence_flag = string(getfield_default_local(dbg, 'final_confidence_flag', ''));
    row.final_failure_reason = string(getfield_default_local(dbg, 'final_failure_reason', ''));
    row.rank1_failure_reason = string(getfield_default_local(dbg, 'rank1_failure_reason', 'not_available'));
    row.runtime_sec = runtime_sec;
end

function summary_tbl = summarize_gate_trials_local(T)
    [G, scenario_name, az_sep_deg, SNR_dB] = findgroups(T.scenario_name, T.az_sep_deg, T.SNR_dB);
    rows = cell(max(G), 1);
    for ig = 1:max(G)
        mask = G == ig;
        row = struct();
        row.scenario_name = scenario_name(ig);
        row.az_sep_deg = az_sep_deg(ig);
        row.SNR_dB = SNR_dB(ig);
        row.trials = sum(mask);
        row.success_rate = mean(double(T.success(mask)));
        row.low_confidence_rate = mean(string(T.confidence(mask)) == "low");
        row.boundary_unreliable_rate = mean(string(T.route_name(mask)) == "boundary_unreliable");
        row.false_high_rate = mean(double(T.false_high(mask)));
        row.rank1_truth_top1_rate = mean(double(T.truth_pair_in_rank1_top1(mask)));
        row.rank1_truth_top3_rate = mean(double(T.truth_pair_in_rank1_top3(mask)));
        row.rank1_truth_top5_rate = mean(double(T.truth_pair_in_rank1_top5(mask)));
        row.refocus_truth_top1_rate = mean(double(T.truth_pair_in_refocus_top1(mask)));
        row.refocus_truth_top3_rate = mean(double(T.truth_pair_in_refocus_top3(mask)));
        row.refocus_truth_top5_rate = mean(double(T.truth_pair_in_refocus_top5(mask)));
        row.rank1_correct_but_rejected_rate = mean(double(T.rank1_candidate_correct_but_rejected(mask)));
        row.refocus_correct_but_rejected_rate = mean(double(T.refocus_candidate_correct_but_rejected(mask)));
        row.common_el_proxy_pass_rate = mean(double(T.common_el_proxy_flag(mask)));
        row.rank1_route_reliable_rate = mean(double(T.rank1_route_reliable(mask)));
        row.median_rank1_truth_error = median(T.rank1_truth_az_error(mask), 'omitnan');
        row.median_refocus_truth_error = median(T.refocus_truth_az_error(mask), 'omitnan');
        row.dominant_failure_reason = dominant_string_local(T.final_failure_reason(mask));
        rows{ig} = row;
    end
    summary_tbl = struct2table([rows{:}]);
end

function keypoints_tbl = gate_keypoints_local(T)
    rows = {};
    success_rate = mean(double(T.success));
    low_confidence_rate = mean(string(T.confidence) == "low");
    boundary_unreliable_rate = mean(string(T.route_name) == "boundary_unreliable");
    false_high_rate = mean(double(T.false_high));
    rank1_top1 = mean(double(T.truth_pair_in_rank1_top1));
    rank1_top3 = mean(double(T.truth_pair_in_rank1_top3));
    rank1_top5 = mean(double(T.truth_pair_in_rank1_top5));
    refocus_top1 = mean(double(T.truth_pair_in_refocus_top1));
    refocus_top3 = mean(double(T.truth_pair_in_refocus_top3));
    refocus_top5 = mean(double(T.truth_pair_in_refocus_top5));
    rank1_rejected = mean(double(T.rank1_candidate_correct_but_rejected));
    refocus_rejected = mean(double(T.refocus_candidate_correct_but_rejected));
    common_el = mean(double(T.common_el_proxy_flag));
    rank1_reliable = mean(double(T.rank1_route_reliable));
    blocker = classify_main_blocker_local(success_rate, false_high_rate, rank1_top3, ...
        rank1_rejected, refocus_top3, common_el, rank1_top5, refocus_top5);
    rows = add_kp_local(rows, 'total_trials', height(T), 'diagnostic trial rows');
    rows = add_kp_local(rows, 'success_rate', success_rate, 'step87_reference');
    rows = add_kp_local(rows, 'low_confidence_rate', low_confidence_rate, 'step87_reference');
    rows = add_kp_local(rows, 'boundary_unreliable_rate', boundary_unreliable_rate, 'step87_reference');
    rows = add_kp_local(rows, 'false_high_rate', false_high_rate, 'step87_reference');
    rows = add_kp_local(rows, 'rank1_truth_top1_rate', rank1_top1, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'rank1_truth_top3_rate', rank1_top3, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'rank1_truth_top5_rate', rank1_top5, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'refocus_truth_top1_rate', refocus_top1, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'refocus_truth_top3_rate', refocus_top3, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'refocus_truth_top5_rate', refocus_top5, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'rank1_correct_but_rejected_rate', rank1_rejected, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'refocus_correct_but_rejected_rate', refocus_rejected, 'truth-only diagnostic');
    rows = add_kp_local(rows, 'common_el_proxy_pass_rate', common_el, 'route gate');
    rows = add_kp_local(rows, 'rank1_route_reliable_rate', rank1_reliable, 'route gate');
    rows = add_kp_local(rows, 'main_blocker_type', blocker, 'rule-based blocker classification');
    keypoints_tbl = struct2table([rows{:}]);
end

function blocker = classify_main_blocker_local(success_rate, false_high_rate, rank1_top3, rank1_rejected, refocus_top3, common_el, rank1_top5, refocus_top5)
    if success_rate >= 0.5 && false_high_rate <= 0.01
        blocker = "no_major_blocker";
    elseif rank1_top3 >= 0.7 && rank1_rejected >= 0.5
        blocker = "rank1_gate_too_strict_or_common_el_proxy_mismatch";
    elseif refocus_top3 >= 0.7 && common_el < 0.5
        blocker = "common_el_proxy_too_strict";
    elseif rank1_top3 < 0.3 && refocus_top3 < 0.3
        blocker = "data_or_reference_frame_mismatch";
    elseif rank1_top3 < 0.3
        blocker = "rank1_candidate_generation_failure";
    else
        blocker = "mixed_gate_and_candidate_generation_blocker";
    end
end

function plot_rank1_truth_error_hist_local(T, path_out)
    fig = figure('Visible', 'off');
    histogram(T.rank1_truth_az_error, 'BinWidth', 0.02);
    grid on
    xlabel('rank1 truth az error (deg)');
    ylabel('trials');
    title('Rank1 Truth Error');
    saveas(fig, path_out);
    close(fig);
end

function plot_rank1_score_vs_error_local(T, path_out)
    fig = figure('Visible', 'off');
    scatter(T.rank1_score, T.rank1_truth_az_error, 16, double(T.rank1_route_reliable), 'filled');
    grid on
    xlabel('rank1 score');
    ylabel('rank1 truth az error (deg)');
    title('Rank1 Score vs Truth Error');
    colorbar;
    saveas(fig, path_out);
    close(fig);
end

function plot_refocus_score_vs_rank1_score_local(T, path_out)
    fig = figure('Visible', 'off');
    scatter(T.rank1_score, T.refocus_score, 16, double(T.common_el_proxy_flag), 'filled');
    grid on
    xlabel('rank1 score');
    ylabel('refocus score');
    title('Refocus Score vs Rank1 Score');
    colorbar;
    saveas(fig, path_out);
    close(fig);
end

function plot_gate_failure_distribution_local(T, path_out)
    reasons = string(T.final_failure_reason);
    u = unique(reasons, 'stable');
    counts = zeros(numel(u), 1);
    for i = 1:numel(u)
        counts(i) = sum(reasons == u(i));
    end
    fig = figure('Visible', 'off');
    bar(counts);
    grid on
    xticks(1:numel(u));
    xticklabels(u);
    xtickangle(30);
    ylabel('trials');
    title('Gate Failure Distribution');
    saveas(fig, path_out);
    close(fig);
end

function write_gate_report_local(report_path, S, K)
    fid = fopen(report_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Step09 Close-Coherent Gate Diagnostics\n\n');
    fprintf(fid, 'This run is diagnostic only. It uses `cfg.backend_mode = ''step87_reference''` as the primary backend and does not tune route thresholds.\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(K)
        fprintf(fid, '| `%s` | %s | %s |\n', safe_string_local(K.keypoint(i)), safe_string_local(K.value(i)), safe_string_local(K.note(i)));
    end
    fprintf(fid, '\n## Summary\n\n');
    fprintf(fid, '| scenario_name | az_sep_deg | SNR_dB | trials | success_rate | low_confidence_rate | boundary_unreliable_rate | rank1_truth_top3_rate | refocus_truth_top3_rate | common_el_proxy_pass_rate | rank1_route_reliable_rate | dominant_failure_reason |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n');
    for i = 1:height(S)
        fprintf(fid, '| `%s` | %.3g | %.3g | %d | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | `%s` |\n', ...
            S.scenario_name(i), S.az_sep_deg(i), S.SNR_dB(i), S.trials(i), ...
            S.success_rate(i), S.low_confidence_rate(i), S.boundary_unreliable_rate(i), ...
            S.rank1_truth_top3_rate(i), S.refocus_truth_top3_rate(i), ...
            S.common_el_proxy_pass_rate(i), S.rank1_route_reliable_rate(i), ...
            S.dominant_failure_reason(i));
    end
    fprintf(fid, '\n## Figures\n\n');
    fprintf(fid, '- `step09_rank1_truth_error_hist.png`\n');
    fprintf(fid, '- `step09_rank1_score_vs_error.png`\n');
    fprintf(fid, '- `step09_refocus_score_vs_rank1_score.png`\n');
    fprintf(fid, '- `step09_gate_failure_distribution.png`\n');
end

function write_gate_doc_local(doc_path, S, K, result_dir)
    kp = @(key) keypoint_value_local(K, key);
    main_blocker = string(kp('main_blocker_type'));
    rank1_top3 = str2double(string(kp('rank1_truth_top3_rate')));
    refocus_top3 = str2double(string(kp('refocus_truth_top3_rate')));
    common_el = str2double(string(kp('common_el_proxy_pass_rate')));
    rank1_reliable = str2double(string(kp('rank1_route_reliable_rate')));
    rank1_rejected = str2double(string(kp('rank1_correct_but_rejected_rate')));
    fid = fopen(doc_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Close-Coherent Gate Diagnostics\n\n');
    fprintf(fid, 'This note records a focused diagnostic run for Step 09 close-coherent and medium-beta cases using `cfg.backend_mode = ''step87_reference''`. It does not modify thresholds, default backend selection, or the thesis route.\n\n');
    fprintf(fid, 'Result directory: `%s`.\n\n', result_dir);
    fprintf(fid, '## Answers\n\n');
    fprintf(fid, '1. Candidate generation failure: %s. Truth reaches rank1/refocus top-K often enough that candidate generation is not the primary blocker.\n', yes_no_candidate_failure_local(main_blocker));
    fprintf(fid, '2. Truth pair top-K entry: rank1 top3 rate = %.6f, refocus top3 rate = %.6f.\n', rank1_top3, refocus_top3);
    fprintf(fid, '3. Rejection gate: rank1 correct-but-rejected rate = %.6f; common-el proxy pass rate = %.6f; main blocker = `%s`.\n', rank1_rejected, common_el, main_blocker);
    fprintf(fid, '4. Common-el proxy pass rate: %.6f.\n', common_el);
    fprintf(fid, '5. Rank1 route reliable rate: %.6f.\n', rank1_reliable);
    fprintf(fid, '6. Main blocker: `%s`.\n', main_blocker);
    fprintf(fid, '7. Next step: do not tune thresholds from this run alone. The immediate action is to inspect the rank1/common-el gate mismatch; only if top-K rates were low would reference-frame/data repair move ahead of gate analysis.\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(K)
        fprintf(fid, '| `%s` | %s | %s |\n', safe_string_local(K.keypoint(i)), safe_string_local(K.value(i)), safe_string_local(K.note(i)));
    end
    fprintf(fid, '\n## Summary CSV Scope\n\n');
    fprintf(fid, 'Summary rows are grouped by `scenario_name`, `az_sep_deg`, and `SNR_dB`. `medium_beta_pair` uses the requested Cartesian product of azimuth separation and beta values.\n\n');
    fprintf(fid, '| scenario_name | az_sep_deg | SNR_dB | trials | success_rate | rank1_truth_top3_rate | refocus_truth_top3_rate | common_el_proxy_pass_rate | rank1_route_reliable_rate |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(S)
        fprintf(fid, '| `%s` | %.3g | %.3g | %d | %.6f | %.6f | %.6f | %.6f | %.6f |\n', ...
            S.scenario_name(i), S.az_sep_deg(i), S.SNR_dB(i), S.trials(i), ...
            S.success_rate(i), S.rank1_truth_top3_rate(i), S.refocus_truth_top3_rate(i), ...
            S.common_el_proxy_pass_rate(i), S.rank1_route_reliable_rate(i));
    end
end

function text = yes_no_candidate_failure_local(main_blocker)
    if main_blocker == "rank1_candidate_generation_failure" || main_blocker == "data_or_reference_frame_mismatch"
        text = "yes, top-K candidate generation/reference-frame evidence is weak";
    else
        text = "not primarily, based on the rule-based blocker classification";
    end
end

function [az_mean, el_mean, ok] = pair_error_local(az_est, el_est, az_true, el_true)
    az_mean = NaN;
    el_mean = NaN;
    ok = false;
    if numel(az_est) < 2 || numel(el_est) < 2
        return
    end
    est = [az_est(:), el_est(:)];
    truth = [az_true(:), el_true(:)];
    d11 = norm(est(1, :) - truth(1, :)) + norm(est(2, :) - truth(2, :));
    d12 = norm(est(1, :) - truth(2, :)) + norm(est(2, :) - truth(1, :));
    if d12 < d11
        truth = flipud(truth);
    end
    az_mean = mean(abs(wrap180_local(est(:, 1).' - truth(:, 1).')));
    el_mean = mean(abs(est(:, 2).' - truth(:, 2).'));
    ok = all(isfinite([az_mean, el_mean]));
end

function err = az_pair_error_only_local(az_est, az_true)
    err = NaN;
    if numel(az_est) < 2
        return
    end
    az_est = sort(az_est(:).');
    az_true = sort(az_true(:).');
    if any(~isfinite(az_est))
        return
    end
    err = max(abs(wrap180_local(az_est(1:2) - az_true(1:2))));
end

function tf = truth_pair_in_topk_local(topk_pairs, az_true, k)
    tf = false;
    if isempty(topk_pairs)
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

function txt = dominant_string_local(vals)
    vals = string(vals);
    if isempty(vals)
        txt = "";
        return
    end
    u = unique(vals, 'stable');
    counts = zeros(numel(u), 1);
    for i = 1:numel(u)
        counts(i) = sum(vals == u(i));
    end
    [~, idx] = max(counts);
    txt = u(idx);
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
