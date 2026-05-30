% Step 8.9C shared-center mixed precision validation.
%
% Scope:
% 1) Reuse Step 8.9 simulation/frontend and Step 8.7 shared-center lazy cascade.
% 2) Validate mixed precision Y_work / coefficient policies after Step 8.9B
%    identified coefficient/template/cache sensitivity.
% 3) This is numerical influence validation only: no FPGA HDL, no bit-true
%    EVD, no algorithm/threshold/CFAR/frontend changes, and no dual-center.

clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
addpath(fullfile(project_dir, 'core', 'config'));

cfg_base = sim_cfg();
cfg88 = make_step88_cfg_local(cfg_base);

result_dir = fullfile(script_dir, 'results_step8_9c_mixed_precision_validation');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_9c_mixed_precision_validation.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

trial_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_trial.csv');
summary_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_summary.csv');
keypoints_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_keypoints.csv');
storage_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_storage_estimate.csv');
worst_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_worst_cases.csv');
recommendations_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_recommendations.csv');
route_summary_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_route_summary.csv');
confidence_summary_csv_path = fullfile(result_dir, 'step8_9c_mixed_precision_confidence_summary.csv');
mat_path = fullfile(result_dir, 'step8_9c_mixed_precision_result.mat');
record_doc_path = fullfile(script_dir, '第8.9C步_shared-center混合精度定点验证记录.md');

quick_mode = strcmpi(getenv('STEP89C_QUICK_MODE'), '1');
if quick_mode
    Metkl = 5;
else
    Metkl = 30;
end

snr_list = [8, 16];
base_seed = 20261089;
scenarios = build_step88_scenarios_local(cfg88, snr_list);
quant_modes = build_step89c_quant_modes_local();
total_base_trials = numel(scenarios) * Metkl;
total_mode_trials = total_base_trials * numel(quant_modes);
reuse_step89_observations_flag = 0;
rerun_base_trials_flag = 1;
exact_same_trial_replication_flag = 1;
replication_note = "Step 8.9 did not persist Y_work/base observations; Step 8.9C replays the same scenarios with the same base_seed and simulation logic.";

log_msg_local(fid_log, 'Step 8.9C shared-center mixed precision validation');
log_msg_local(fid_log, 'quick_mode=%d, Metkl=%d, base_trials=%d, mode_trials=%d, SNR=%s', ...
    quick_mode, Metkl, total_base_trials, total_mode_trials, mat2str(snr_list));
if quick_mode
    log_msg_local(fid_log, 'WARNING: quick_mode=1. This run is a quick smoke test only and not formal conclusion.');
end
log_msg_local(fid_log, 'Mixed modes: %s', strjoin(cellstr([quant_modes.name]), ', '));
log_msg_local(fid_log, 'reuse_step89_observations_flag=%d, rerun_base_trials_flag=%d, exact_same_trial_replication_flag=%d', ...
    reuse_step89_observations_flag, rerun_base_trials_flag, exact_same_trial_replication_flag);
log_msg_local(fid_log, '%s', replication_note);
log_msg_local(fid_log, 'No changes to Step 8.7 algorithms, Step 8.8 frontend, CFAR, dispatch thresholds, or original Step 8.9/8.9B results.');

[array_geom, pc_model] = init_frontend_models_local(cfg88);
log_msg_local(fid_log, 'Array: Naz=%d, Nel=%d, selected work columns=%d, column spacing=%.6f deg.', ...
    cfg88.Naz, cfg88.Nel, cfg88.workColumns, cfg88.columnSpacingDeg);
log_msg_local(fid_log, 'Pulse model: Np=%d, nRange=%d, rangeIdxTruth=%d, velocity=%.3f m/s.', ...
    cfg88.Np, cfg88.nRange, pc_model.rangeIdxTruth, cfg88.velocity_mps);

context_cache = struct('key', {}, 'ctx', {});
quant_context_cache = struct('key', {}, 'ctx', {}, 'diag', {});
trial_rows = cell(total_mode_trials, 1);
row_idx = 0;
tic_all = tic;

for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    log_msg_local(fid_log, 'Scenario %02d/%02d: %s, SNR=%g, target_count=%d, sep=%.6f, beta=%.3g, phase=%.1f, el=[%.1f %.1f].', ...
        isc, numel(scenarios), sc.scenario_name, sc.snr_db, sc.target_count, sc.pair_sep, ...
        sc.beta, sc.phase_deg, sc.el1, sc.el2);
    for imc = 1:Metkl
        rng(base_seed + 1000 * isc + imc);
        [frontend_out, pc_like] = run_frontend_chain_local(sc, cfg88, array_geom, pc_model);
        cfar_ok = frontend_out.cfar_detected_flag;
        in_scope = logical(frontend_out.in_scope_shared_center_flag);
        if cfar_ok && frontend_out.selected_center_valid_flag
            enhance_base = frontend_to_step87_input_derot_local(frontend_out, pc_like, cfg88, array_geom, "no_derotation");
        else
            enhance_base = make_empty_enhance_input_local(frontend_out, cfg88);
            enhance_base.derotation_mode = "no_derotation";
            enhance_base.fd_hat = NaN;
            enhance_base.v_hat = NaN;
            enhance_base.fd_hat_source = "not_available";
            enhance_base.fd_true_if_available = cfg88.fd_true;
            enhance_base.fd_error = NaN;
            enhance_base.derotation_sign_used = 0;
        end

        if cfar_ok && in_scope
            [ctx_base, context_cache] = get_or_build_step87_context_local(context_cache, enhance_base, cfg88, array_geom, fid_log);
        else
            ctx_base = struct();
        end

        mode_rows = cell(numel(quant_modes), 1);
        for imode = 1:numel(quant_modes)
            qmode = quant_modes(imode);
            [enhance_in, yq] = apply_ywork_quant_mode_local(enhance_base, qmode);
            if cfar_ok && in_scope
                [ctx_q, qctx_diag, quant_context_cache] = get_or_build_quant_context_local( ...
                    quant_context_cache, ctx_base, enhance_in, cfg88, qmode);
                [enhance_out, timing] = run_step87_shared_center_lazy_local(enhance_in, sc, ctx_q, cfg88);
            else
                enhance_out = make_empty_route_result_local("frontend_not_in_shared_center_scope");
                if ~cfar_ok
                    enhance_out.recommended_route = "cfar_not_detected";
                    enhance_out.failure_reason = "cfar_not_detected";
                else
                    enhance_out.recommended_route = "two_coarse_peaks_out_of_scope";
                    enhance_out.failure_reason = "two_coarse_peaks_out_of_scope";
                end
                enhance_out.confidence_flag = "low";
                enhance_out.low_confidence_flag = true;
                timing = init_wallclock_timing_local();
                qctx_diag = empty_steering_diag_local(qmode.name);
            end
            mode_rows{imode} = make_fixed_trial_row_local(sc, imc, qmode, frontend_out, enhance_in, ...
                enhance_out, timing, yq, qctx_diag, cfg88);
        end
        mode_rows = add_quant_mode_comparisons_local(mode_rows);
        for imode = 1:numel(quant_modes)
            row_idx = row_idx + 1;
            trial_rows{row_idx} = mode_rows{imode};
        end
    end
end

elapsed_sec = toc(tic_all);
trial_rows = trial_rows(1:row_idx);
trial_tbl = struct2table([trial_rows{:}]);
trial_tbl.Properties.UserData.recommended_frontend_policy = cfg88.recommended_frontend_policy;
steering_error_tbl = collect_quant_context_diag_table_local(quant_context_cache);
storage_tbl = build_step89c_storage_estimate_local(cfg88, quant_modes);
summary_tbl = build_step89c_summary_table_local(trial_tbl, steering_error_tbl, storage_tbl, quant_modes);
route_summary_tbl = build_step89c_route_summary_local(trial_tbl, quant_modes);
confidence_summary_tbl = build_step89c_confidence_summary_local(trial_tbl, quant_modes);
worst_cases_tbl = build_step89c_worst_cases_local(trial_tbl, 50);
recommendations_tbl = build_step89c_recommendations_local(summary_tbl, storage_tbl);
keypoints_tbl = build_step89c_keypoints_local(trial_tbl, summary_tbl, storage_tbl, recommendations_tbl, Metkl, quick_mode);

log_msg_local(fid_log, 'Runtime loops finished in %.2f sec.', elapsed_sec);
log_msg_local(fid_log, 'Writing CSV/MAT outputs.');
writetable(trial_tbl, trial_csv_path);
writetable(summary_tbl, summary_csv_path);
writetable(keypoints_tbl, keypoints_csv_path);
writetable(storage_tbl, storage_csv_path);
writetable(worst_cases_tbl, worst_csv_path);
writetable(recommendations_tbl, recommendations_csv_path);
writetable(route_summary_tbl, route_summary_csv_path);
writetable(confidence_summary_tbl, confidence_summary_csv_path);

log_msg_local(fid_log, 'Rendering plots.');
plot_step89c_metric_local(summary_tbl, 'success_rate', 'mixed precision success', fullfile(result_dir, 'mixed_precision_success.png'));
plot_step89c_metric_local(summary_tbl, 'route_agreement_vs_double', 'mixed precision route agreement', fullfile(result_dir, 'mixed_precision_route_agreement.png'));
plot_step89c_metric_local(summary_tbl, 'confidence_agreement_vs_double', 'mixed precision confidence agreement', fullfile(result_dir, 'mixed_precision_confidence_agreement.png'));
plot_step89c_metric_local(summary_tbl, 'output_equivalent_rate', 'mixed precision output equivalent', fullfile(result_dir, 'mixed_precision_output_equivalent.png'));
plot_step89c_az_diff_local(summary_tbl, fullfile(result_dir, 'mixed_precision_az_diff.png'));
plot_step89c_false_boundary_local(summary_tbl, fullfile(result_dir, 'mixed_precision_false_high_boundary.png'));
plot_step89c_by_scenario_local(summary_tbl, fullfile(result_dir, 'mixed_precision_by_scenario.png'));
plot_step89c_by_route_local(trial_tbl, fullfile(result_dir, 'mixed_precision_by_route.png'));
plot_step89c_storage_local(storage_tbl, fullfile(result_dir, 'mixed_precision_storage_tradeoff.png'));
plot_step89c_recommended_modes_local(recommendations_tbl, fullfile(result_dir, 'mixed_precision_recommended_modes.png'));

save(mat_path, 'trial_tbl', 'summary_tbl', 'keypoints_tbl', 'storage_tbl', ...
    'route_summary_tbl', 'confidence_summary_tbl', 'worst_cases_tbl', ...
    'recommendations_tbl', 'steering_error_tbl', 'cfg88', 'array_geom', ...
    'pc_model', 'elapsed_sec', 'Metkl', 'quick_mode', 'quant_modes', ...
    'reuse_step89_observations_flag', 'rerun_base_trials_flag', 'exact_same_trial_replication_flag', '-v7.3');

write_step89c_record_doc_local(record_doc_path, keypoints_tbl, summary_tbl, storage_tbl, ...
    worst_cases_tbl, recommendations_tbl, result_dir, elapsed_sec, Metkl, quick_mode, quant_modes, ...
    reuse_step89_observations_flag, rerun_base_trials_flag, exact_same_trial_replication_flag, replication_note);

log_msg_local(fid_log, 'Outputs written to %s', result_dir);
log_msg_local(fid_log, 'Record doc: %s', record_doc_path);
function cfg88 = make_step88_cfg_local(cfg)
    cfg88 = struct();
    cfg88.c = cfg.arr.c;
    cfg88.fc = cfg.arr.fc;
    cfg88.lambda = cfg.arr.lambda;
    cfg88.Naz = cfg.arr.Naz;
    cfg88.Nel = cfg.arr.Nel;
    cfg88.Rcyl = cfg.arr.R;
    cfg88.dz = cfg.arr.dz;
    cfg88.columnSpacingDeg = 360 / cfg.arr.Naz;
    cfg88.halfColumnSpacingDeg = cfg88.columnSpacingDeg / 2;
    cfg88.workColumns = 65;
    cfg88.workHalfColumns = 32;
    cfg88.coarseTempColumns = 65;
    cfg88.frontendSectorCenterAz_deg = 0;
    cfg88.elAssumedFrontend_deg = 0;
    cfg88.coarseScanAz_deg = -4:0.02:4;
    cfg88.coarsePeakMergeThreshold_deg = min(1.5, cfg88.columnSpacingDeg);
    cfg88.coarsePeakProminenceThreshold = 0.45;
    cfg88.weakSecondaryProminenceFloor = 0.20;
    cfg88.recommended_frontend_policy = "single coarse peak -> shared_center_enhancement; " + ...
        "two close coarse peaks -> merge_candidate_or_future_validation; " + ...
        "two separated coarse peaks -> front-end multi-target branch / out-of-scope; " + ...
        "weak secondary peak -> low-confidence secondary candidate";
    cfg88.dAzThreeBeam_deg = 1.24;
    cfg88.dUThreeBeam = 0.02921876244;
    cfg88.dElThreeBeam_deg = asind(min(max(sind(0) + cfg88.dUThreeBeam, -1), 1));
    cfg88.Np = 32;
    cfg88.PRI = 50e-6;
    cfg88.velocity_mps = 45;
    cfg88.fd_true = -2 * cfg88.velocity_mps / cfg88.lambda;
    cfg88.nfft = cfg88.Np;
    cfg88.fdAxis = ((0:cfg88.nfft - 1) - floor(cfg88.nfft / 2)) / (cfg88.nfft * cfg88.PRI);
    cfg88.vAxis = -cfg88.fdAxis * cfg88.lambda / 2;
    cfg88.nRange = 96;
    cfg88.rangeIdxTruth = 48;
    cfg88.range0_m = 3200;
    cfg88.Fs = 60e6;
    cfg88.Tp = 1e-6;
    cfg88.B = 20e6;
    cfg88.K = cfg88.B / cfg88.Tp;
    cfg88.tTx = (-cfg88.Tp / 2):(1 / cfg88.Fs):(cfg88.Tp / 2 - 1 / cfg88.Fs);
    cfg88.tSlow = (0:cfg88.Np - 1) * cfg88.PRI;
    cfg88.Pfa = 1e-6;
    cfg88.nGuard = 2;
    cfg88.nRef = 8;
    cfg88.cfarType = 'CA';
    cfg88.detectorType = 'Square';
    cfg88.R_runtime_default_deg = 1.5;
    cfg88.R_runtime_expand_deg = 2.0;
    cfg88.template_R_deg = 2.0;
    cfg88.azGridStep_deg = 0.02;
    cfg88.elGrid_deg = -2:0.5:12;
    cfg88.elRefocusGrid_deg = -2:0.5:12;
    cfg88.elBank_deg = -5:1:15;
    cfg88.Lc = 2;
    cfg88.K_phi_level2 = 20;
    cfg88.K_phi_music = 20;
    cfg88.K_z_music = 8;
    cfg88.K_phi_covfit = 6;
    cfg88.K_z_covfit = 3;
    cfg88.az_tol_deg = 0.1;
    cfg88.el_tol_deg = 0.5;
    cfg88.min_pair_sep_deg = 0.05;
    cfg88.max_pair_sep_deg = 0.80;
    cfg88.fixed_point_blocker_default = 0;
end

function [array_geom, pc_model] = init_frontend_models_local(cfg88)
    phiCol = (0:cfg88.Naz - 1) / cfg88.Naz * 360;
    zRow = (0:cfg88.Nel - 1) * cfg88.dz;
    X = zeros(cfg88.Naz, cfg88.Nel);
    Y = zeros(cfg88.Naz, cfg88.Nel);
    Z = zeros(cfg88.Naz, cfg88.Nel);
    for iaz = 1:cfg88.Naz
        X(iaz, :) = cfg88.Rcyl * cosd(phiCol(iaz));
        Y(iaz, :) = cfg88.Rcyl * sind(phiCol(iaz));
        Z(iaz, :) = zRow;
    end
    array_geom = struct('phiCol', phiCol, 'zRow', zRow, 'X', X, 'Y', Y, 'Z', Z);

    sTx = (abs(cfg88.tTx) <= cfg88.Tp / 2) .* exp(1j * pi * cfg88.K * cfg88.tTx .^ 2);
    mfAuto = conv(sTx, conj(fliplr(sTx)));
    mfAuto = mfAuto / max(abs(mfAuto));
    Ns = numel(sTx);
    pcResp = zeros(1, cfg88.nRange);
    for ir = 1:cfg88.nRange
        idx = Ns + (ir - cfg88.rangeIdxTruth);
        if idx >= 1 && idx <= numel(mfAuto)
            pcResp(ir) = mfAuto(idx);
        end
    end
    dR = cfg88.c / (2 * cfg88.Fs);
    rAxis = cfg88.range0_m + ((1:cfg88.nRange) - cfg88.rangeIdxTruth) * dR;
    pc_model = struct('sTx', sTx, 'pcResp', pcResp, 'rAxis', rAxis, ...
        'rangeIdxTruth', cfg88.rangeIdxTruth, 'dR', dR);
end

function scenarios = build_step88_scenarios_local(cfg88, snr_list)
    scenarios = repmat(make_scenario_local("", 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN), 0, 1);
    idx = 0;
    theta0 = 0;
    for is = 1:numel(snr_list)
        idx = idx + 1;
        scenarios(idx) = make_scenario_local("single_target_sanity", 1, theta0, NaN, 0, NaN, ...
            NaN, 1, 0, NaN, 0, snr_list(is));
    end

    sep_list = [0.263775444933353, 0.5, 0.8];
    offset_list = [-0.5 * cfg88.halfColumnSpacingDeg, 0, 0.5 * cfg88.halfColumnSpacingDeg];
    for sep = sep_list
        for off = offset_list
            for is = 1:numel(snr_list)
                idx = idx + 1;
                scenarios(idx) = make_scenario_pair_local("close_coherent_pair", sep, off, 1, 1, 0, [0, 0], snr_list(is));
            end
        end
    end

    sep_list = [0.5, 0.8];
    for sep = sep_list
        for off = offset_list
            for is = 1:numel(snr_list)
                idx = idx + 1;
                scenarios(idx) = make_scenario_pair_local("medium_beta_pair", sep, off, 0.5, 1, 0, [0, 0], snr_list(is));
            end
        end
    end

    for sep = [0.5, 0.8]
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_scenario_pair_local("weak_target_boundary", sep, 0, 0.3, 1, 0, [0, 0], snr_list(is));
        end
    end

    for phase = [150, 180]
        for sep = [0.5, 0.8]
            for is = 1:numel(snr_list)
                idx = idx + 1;
                scenarios(idx) = make_scenario_pair_local("near_antiphase_boundary", sep, 0, 1, 1, phase, [0, 0], snr_list(is));
            end
        end
    end

    for sep = [0.263775444933353, 0.5]
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_scenario_pair_local("large_el_pair", sep, 0, 1, 1, 0, [0, 5], snr_list(is));
        end
    end
end

function sc = make_scenario_pair_local(name, sep, center_offset, beta, rho, phase_deg, el_pair, snr_db)
    theta0 = center_offset;
    theta1 = theta0 - sep / 2;
    theta2 = theta0 + sep / 2;
    sc = make_scenario_local(name, 2, theta1, theta2, el_pair(1), el_pair(2), ...
        sep, beta, phase_deg, rho, center_offset, snr_db);
end

function sc = make_scenario_local(name, target_count, theta1, theta2, el1, el2, pair_sep, beta, phase_deg, rho, center_offset, snr_db)
    sc = struct();
    sc.scenario_name = string(name);
    sc.target_count = target_count;
    sc.theta1 = theta1;
    sc.theta2 = theta2;
    sc.el1 = el1;
    sc.el2 = el2;
    sc.pair_sep = pair_sep;
    sc.beta = beta;
    sc.rho = rho;
    sc.phase_deg = phase_deg;
    sc.pair_center_offset = center_offset;
    sc.snr_db = snr_db;
    sc.weak_target_truth_flag = target_count == 2 && isfinite(beta) && beta <= 0.3;
    sc.anti_phase_truth_flag = target_count == 2 && isfinite(phase_deg) && phase_deg >= 150;
    sc.large_el_truth_flag = target_count == 2 && isfinite(el2) && abs(el2 - el1) >= 2;
end

function [frontend_out, pc_like, diag] = run_frontend_chain_local(sc, cfg88, array_geom, pc_model)
    [Y_clean_full, Y_noisy_full, noise_sigma2] = make_observation_snapshot_local(sc, cfg88, array_geom);
    coarse_cols = work_columns_from_az_local(cfg88.frontendSectorCenterAz_deg, cfg88.coarseTempColumns, array_geom.phiCol);
    [coarseAz0, coarseMetric, coarsePeakCount, coarseWidth, coarseProm, coarsePeakSepDeg, ...
        secondPeakProminence, rawCoarsePeakCount, closeMergeCandidateFlag, coarsePower] = ...
        coarse_az_beamformer_local(Y_noisy_full, coarse_cols, cfg88, array_geom);

    preliminary_cols = work_columns_from_az_local(coarseAz0, cfg88.workColumns, array_geom.phiCol);
    [rdCube, vAxis, beamW, locAz, locEl] = make_frontend_five_beam_rd_local( ...
        Y_clean_full, Y_noisy_full, preliminary_cols, coarseAz0, cfg88.elAssumedFrontend_deg, ...
        noise_sigma2, cfg88, array_geom, pc_model);

    [thrMap, rawRIdx, rawDIdx, rawPow, nRaw, pickRIdx, pickDIdx, pickPow, alpha] = ...
        center_cfar_1d_step88_local(rdCube, cfg88.Pfa, cfg88.nGuard, cfg88.nRef, cfg88.cfarType, cfg88.detectorType);
    cfar_detected = nRaw > 0;

    if cfar_detected
        zDet = squeeze(rdCube(:, pickRIdx, pickDIdx));
        [azEst, elEst] = three_beam_ratio_angle_local(zDet, beamW, locAz, locEl, preliminary_cols, cfg88, array_geom);
        coarseAz = azEst;
        coarseEl = elEst;
        rangeIdx = pickRIdx;
        dopplerIdx = pickDIdx;
        range_m = pc_model.rAxis(pickRIdx);
        velocity_mps = vAxis(pickDIdx);
        cfarBestMetric = pickPow;
    else
        coarseAz = coarseAz0;
        coarseEl = cfg88.elAssumedFrontend_deg;
        rangeIdx = NaN;
        dopplerIdx = NaN;
        range_m = NaN;
        velocity_mps = NaN;
        cfarBestMetric = NaN;
    end

    [selectedCenterColumn, selectedCenterAz] = nearest_column_local(coarseAz, array_geom.phiCol);
    selectedWorkColumns = work_columns_from_center_col_local(selectedCenterColumn, cfg88.workColumns, cfg88.Naz);
    two_out = coarsePeakCount > 1;
    [frontend_state, in_scope_shared_center_flag, out_of_scope_reason, ...
        merge_candidate_flag, weak_secondary_candidate_flag, selected_center_valid_flag] = ...
        classify_frontend_state_local(coarsePeakCount, coarsePeakSepDeg, secondPeakProminence, ...
        closeMergeCandidateFlag, cfar_detected, selectedCenterColumn, cfg88);

    frontend_out = struct();
    frontend_out.rangeIdx = rangeIdx;
    frontend_out.dopplerIdx = dopplerIdx;
    frontend_out.range_m = range_m;
    frontend_out.velocity_mps = velocity_mps;
    frontend_out.coarseAz_deg = coarseAz;
    frontend_out.coarseEl_deg = coarseEl;
    frontend_out.coarseMetric = coarseMetric;
    frontend_out.peakCountCoarse = coarsePeakCount;
    frontend_out.coarsePeakSep_deg = coarsePeakSepDeg;
    frontend_out.secondPeakProminence = secondPeakProminence;
    frontend_out.rawCoarsePeakCount = rawCoarsePeakCount;
    frontend_out.coarsePeakWidth = coarseWidth;
    frontend_out.coarsePeakProminence = coarseProm;
    frontend_out.selectedCenterColumn = selectedCenterColumn;
    frontend_out.selectedCenterAz_deg = selectedCenterAz;
    frontend_out.selectedWorkColumns = selectedWorkColumns;
    frontend_out.cfarCount = nRaw;
    frontend_out.cfarBestMetric = cfarBestMetric;
    frontend_out.cfar_detected_flag = cfar_detected;
    frontend_out.two_coarse_peaks_out_of_scope = two_out;
    frontend_out.frontend_state = frontend_state;
    frontend_out.in_scope_shared_center_flag = in_scope_shared_center_flag;
    frontend_out.out_of_scope_reason = out_of_scope_reason;
    frontend_out.merge_candidate_flag = merge_candidate_flag;
    frontend_out.weak_secondary_candidate_flag = weak_secondary_candidate_flag;
    frontend_out.selected_center_valid_flag = selected_center_valid_flag;
    frontend_out.cfarAlpha = alpha;
    frontend_out.cfarThresholdMap = thrMap;
    frontend_out.cfarRawRangeIdx = rawRIdx;
    frontend_out.cfarRawDopplerIdx = rawDIdx;
    frontend_out.cfarRawMetric = rawPow;
    frontend_out.coarse_mode = "beamformer";

    pc_like = struct();
    pc_like.Y_full_range = Y_noisy_full;
    pc_like.Y_clean_full_range = Y_clean_full;
    pc_like.noise_sigma2 = noise_sigma2;
    pc_like.rangeIdxTruth = pc_model.rangeIdxTruth;
    pc_like.rAxis = pc_model.rAxis;
    pc_like.vAxis = vAxis;
    pc_like.fdAxis = cfg88.fdAxis;
    pc_like.tSlow = cfg88.tSlow;
    pc_like.pcResp = pc_model.pcResp;

    diag = struct();
    diag.az_scan = cfg88.coarseScanAz_deg;
    diag.coarse_power = coarsePower;
    diag.coarseAz0 = coarseAz0;
    diag.selectedCenterAz = selectedCenterAz;
end

function [Y_clean_full, Y_noisy_full, noise_sigma2] = make_observation_snapshot_local(sc, cfg88, array_geom)
    slow = exp(1j * 2*pi * cfg88.fd_true * cfg88.tSlow);
    s1 = exp(1j * 2*pi * rand) * slow;
    if sc.target_count == 1
        s2 = zeros(size(s1));
    else
        v = exp(1j * 2*pi * rand) * slow .* exp(1j * 2*pi * (0:cfg88.Np-1) / 23 + 1j*pi/7);
        rho = min(max(sc.rho, 0), 1);
        s2 = sc.beta * exp(1j * deg2rad(sc.phase_deg)) * ...
            (rho * s1 + sqrt(max(1 - rho^2, 0)) * v);
    end
    A1 = steer_raw_array_local(array_geom.X, array_geom.Y, array_geom.Z, cfg88.lambda, sc.theta1, sc.el1);
    Y_clean = A1(:) * s1;
    if sc.target_count == 2
        A2 = steer_raw_array_local(array_geom.X, array_geom.Y, array_geom.Z, cfg88.lambda, sc.theta2, sc.el2);
        Y_clean = Y_clean + A2(:) * s2;
    end
    Y_clean_full = reshape(Y_clean, cfg88.Naz, cfg88.Nel, cfg88.Np);
    sig_power = mean(abs(Y_clean_full(:)).^2);
    noise_sigma2 = sig_power / 10^(sc.snr_db / 10);
    noise = sqrt(noise_sigma2 / 2) * (randn(size(Y_clean_full)) + 1j * randn(size(Y_clean_full)));
    Y_noisy_full = Y_clean_full + noise;
end

function a = steer_raw_array_local(X, Y, Z, lambda, az_deg, el_deg)
    k = 2*pi / lambda;
    phase = X * (cosd(el_deg) * cosd(az_deg)) + ...
        Y * (cosd(el_deg) * sind(az_deg)) + Z * sind(el_deg);
    a = exp(-1j * k * phase);
end

function [coarseAz, coarseMetric, peakCount, peakWidth, peakProminence, peakSepDeg, ...
    secondPeakProminence, rawPeakCount, closeMergeCandidateFlag, P] = ...
    coarse_az_beamformer_local(Y_full, cols, cfg88, array_geom)
    X = array_geom.X(cols, :);
    Y = array_geom.Y(cols, :);
    Z = array_geom.Z(cols, :);
    Ymat = reshape(Y_full(cols, :, :), numel(cols) * cfg88.Nel, cfg88.Np);
    ampVec = make_amp_vec_local(numel(cols), cfg88.Nel);
    P = zeros(size(cfg88.coarseScanAz_deg));
    for ia = 1:numel(cfg88.coarseScanAz_deg)
        a = steer_raw_array_local(X, Y, Z, cfg88.lambda, cfg88.coarseScanAz_deg(ia), cfg88.elAssumedFrontend_deg);
        w = ampVec .* a(:);
        w = w / max(norm(w), eps);
        z = w' * Ymat;
        P(ia) = mean(abs(z).^2);
    end
    [coarseMetric, idx] = max(P);
    coarseAz = cfg88.coarseScanAz_deg(idx);
    [peakCount, peakWidth, peakProminence, peakSepDeg, secondPeakProminence, ...
        rawPeakCount, closeMergeCandidateFlag] = coarse_peak_metrics_local( ...
        cfg88.coarseScanAz_deg, P, cfg88.coarsePeakMergeThreshold_deg, cfg88.coarsePeakProminenceThreshold);
end

function [peakCount, width, prominence, peakSepDeg, secondPeakProminence, rawPeakCount, closeMergeCandidateFlag] = ...
    coarse_peak_metrics_local(axis, P, mergeThresh, promThresh)
    P = real(P(:)).';
    axis = axis(:).';
    [pmax, imax] = max(P);
    idx_all = [];
    for i = 2:numel(P)-1
        if P(i) >= P(i-1) && P(i) >= P(i+1)
            idx_all(end+1) = i; %#ok<AGROW>
        end
    end
    if isempty(idx_all)
        idx_all = imax;
    end
    [~, ord_all] = sort(P(idx_all), 'descend');
    idx_all = idx_all(ord_all);
    rawPeakCount = numel(idx_all);
    if numel(idx_all) >= 2
        peakSepDeg = abs(axis(idx_all(1)) - axis(idx_all(2)));
        secondPeakProminence = P(idx_all(2)) / max(P(idx_all(1)), eps);
    else
        peakSepDeg = NaN;
        secondPeakProminence = 0;
    end

    idx = idx_all(P(idx_all) >= promThresh * pmax);
    if isempty(idx)
        idx = imax;
    end
    kept = [];
    for i = 1:numel(idx)
        if isempty(kept) || all(abs(axis(idx(i)) - axis(kept)) > mergeThresh)
            kept(end+1) = idx(i); %#ok<AGROW>
        end
    end
    peakCount = numel(kept);
    if numel(idx) >= 2
        prominence = (P(idx(1)) - P(idx(2))) / max(P(idx(1)), eps);
    else
        prominence = 1;
    end
    mask = P >= 0.5 * pmax;
    if any(mask)
        width = axis(find(mask, 1, 'last')) - axis(find(mask, 1, 'first'));
    else
        width = NaN;
    end
    closeMergeCandidateFlag = rawPeakCount >= 2 && peakSepDeg < mergeThresh && secondPeakProminence >= promThresh;
end

function [frontend_state, in_scope_shared_center_flag, out_of_scope_reason, ...
    merge_candidate_flag, weak_secondary_candidate_flag, selected_center_valid_flag] = ...
    classify_frontend_state_local(coarsePeakCount, coarsePeakSepDeg, secondPeakProminence, ...
    closeMergeCandidateFlag, cfar_detected, selectedCenterColumn, cfg88)
    selected_center_valid_flag = cfar_detected && isfinite(selectedCenterColumn);
    merge_candidate_flag = closeMergeCandidateFlag;
    weak_secondary_candidate_flag = cfar_detected && coarsePeakCount == 1 && ...
        isfinite(coarsePeakSepDeg) && coarsePeakSepDeg >= cfg88.coarsePeakMergeThreshold_deg && ...
        secondPeakProminence >= cfg88.weakSecondaryProminenceFloor && ...
        secondPeakProminence < cfg88.coarsePeakProminenceThreshold;

    if ~selected_center_valid_flag
        frontend_state = "no_valid_coarse_peak";
        out_of_scope_reason = "cfar_not_detected_or_invalid_center";
    elseif coarsePeakCount >= 2 && isfinite(coarsePeakSepDeg) && coarsePeakSepDeg < cfg88.coarsePeakMergeThreshold_deg
        frontend_state = "two_close_peaks_merge_candidate";
        out_of_scope_reason = "";
    elseif coarsePeakCount >= 2
        frontend_state = "two_separated_peaks_out_of_scope";
        out_of_scope_reason = "multi_coarse_peak_out_of_scope";
    elseif merge_candidate_flag
        frontend_state = "two_close_peaks_merge_candidate";
        out_of_scope_reason = "";
    else
        frontend_state = "single_peak_in_scope";
        out_of_scope_reason = "";
    end

    in_scope_shared_center_flag = selected_center_valid_flag && ...
        (frontend_state == "single_peak_in_scope" || frontend_state == "two_close_peaks_merge_candidate") && ...
        coarsePeakCount <= 1;
end

function [rdCube, vAxis, W, locAz, locEl] = make_frontend_five_beam_rd_local( ...
    Y_clean_full, Y_noisy_full, cols, centerAz, centerEl, noise_sigma2, cfg88, array_geom, pc_model)
    X = array_geom.X(cols, :);
    Y = array_geom.Y(cols, :);
    Z = array_geom.Z(cols, :);
    nAz = numel(cols);
    ampVec = make_amp_vec_local(nAz, cfg88.Nel);
    locAz = [centerAz - cfg88.dAzThreeBeam_deg, centerAz, centerAz + cfg88.dAzThreeBeam_deg, centerAz, centerAz];
    locEl = [centerEl, centerEl, centerEl, centerEl - cfg88.dElThreeBeam_deg, centerEl + cfg88.dElThreeBeam_deg];
    W = form_beam_weights_raw_local(locAz, locEl, X, Y, Z, cfg88.lambda, ampVec);
    Yclean = reshape(Y_clean_full(cols, :, :), nAz * cfg88.Nel, cfg88.Np);
    Ynoisy = reshape(Y_noisy_full(cols, :, :), nAz * cfg88.Nel, cfg88.Np);
    beamCleanAtRange = W' * Yclean;
    beamNoisyAtRange = W' * Ynoisy;
    beamCube = complex(zeros(5, cfg88.nRange, cfg88.Np));
    for ir = 1:cfg88.nRange
        beamCube(:, ir, :) = reshape(beamCleanAtRange * pc_model.pcResp(ir), 5, 1, cfg88.Np);
    end
    beamNoise = sqrt(noise_sigma2 / 2) * (randn(size(beamCube)) + 1j * randn(size(beamCube)));
    beamCube = beamCube + beamNoise;
    beamCube(:, pc_model.rangeIdxTruth, :) = reshape(beamNoisyAtRange, 5, 1, cfg88.Np);
    [rdCube, vAxis] = mtd_process_step88_local(beamCube, cfg88);
end

function W = form_beam_weights_raw_local(azList, elList, X, Y, Z, lambda, ampVec)
    nBeam = numel(azList);
    W = complex(zeros(numel(X), nBeam));
    for ib = 1:nBeam
        a = steer_raw_array_local(X, Y, Z, lambda, azList(ib), elList(ib));
        w = ampVec .* a(:);
        W(:, ib) = w / max(norm(w), eps);
    end
end

function ampVec = make_amp_vec_local(nAz, nEl)
    azWin = taylorwin(nAz, 4, -30);
    elWin = taylorwin(nEl, 4, -30);
    amp = (azWin(:) / max(abs(azWin))) * (elWin(:).' / max(abs(elWin)));
    ampVec = amp(:);
    ampVec = ampVec / max(norm(ampVec), eps);
end

function [rdCube, vAxis] = mtd_process_step88_local(beamCube, cfg88)
    slowWin = hamming(size(beamCube, 3));
    slowWin = slowWin(:) / norm(slowWin);
    rdCube = fftshift(fft(beamCube .* reshape(slowWin, 1, 1, []), cfg88.nfft, 3), 3);
    vAxis = cfg88.vAxis;
end

function [thrMap, rawRIdx, rawDIdx, rawPow, nRaw, pickRIdx, pickDIdx, pickPow, alpha] = ...
    center_cfar_1d_step88_local(rdCube, Pfa, nGuard, nRef, TypeCase, DeTypeCase)
    rdCtr = squeeze(rdCube(2, :, :));
    X = rdCtr.';
    switch DeTypeCase
        case 'Linear'
            X = abs(X);
        case 'Square'
            X = abs(X).^2;
    end
    [nD, nR] = size(X);
    alpha = 2 * nRef * (Pfa ^ (-1 / (2 * nRef)) - 1);
    ratio = zeros(nD, nR);
    thrMap = inf(nD, nR);
    det = [];
    for ir = 1:nR
        left = max(1, ir - nGuard - nRef):max(0, ir - nGuard - 1);
        right = min(nR + 1, ir + nGuard + 1):min(nR, ir + nGuard + nRef);
        refs = [left, right];
        if isempty(refs)
            continue
        end
        switch TypeCase
            case 'GO'
                mu = max(mean(X(:, left), 2, 'omitnan'), mean(X(:, right), 2, 'omitnan'));
            case 'SO'
                mu = min(mean(X(:, left), 2, 'omitnan'), mean(X(:, right), 2, 'omitnan'));
            otherwise
                mu = mean(X(:, refs), 2);
        end
        thr = mu * alpha;
        thrMap(:, ir) = thr;
        ratio(:, ir) = X(:, ir) ./ max(thr, eps);
        hit = find(ratio(:, ir) >= 1);
        if ~isempty(hit)
            det = [det; [ir * ones(numel(hit), 1), hit(:), X(hit, ir)]]; %#ok<AGROW>
        end
    end
    if isempty(det)
        rawRIdx = zeros(0, 1);
        rawDIdx = zeros(0, 1);
        rawPow = zeros(0, 1);
        nRaw = 0;
        pickRIdx = NaN;
        pickDIdx = NaN;
        pickPow = NaN;
        return
    end
    rawRIdx = det(:, 1);
    rawDIdx = det(:, 2);
    rawPow = det(:, 3);
    nRaw = numel(rawPow);
    [pickPow, idx] = max(rawPow);
    pickRIdx = rawRIdx(idx);
    pickDIdx = rawDIdx(idx);
end

function [azEst, elEst] = three_beam_ratio_angle_local(zDet, W, locAz, locEl, cols, cfg88, array_geom)
    ampAz = abs(zDet([1, 2, 3])).';
    ampEl = abs(zDet([4, 2, 5])).';
    rhoAz = (ampAz(3) - ampAz(1)) / max(ampAz(3) + ampAz(1), eps);
    rhoEl = (ampEl(3) - ampEl(1)) / max(ampEl(3) + ampEl(1), eps);
    X = array_geom.X(cols, :);
    Y = array_geom.Y(cols, :);
    Z = array_geom.Z(cols, :);
    azScan = linspace(locAz(1), locAz(3), 401);
    uScan = linspace(sind(locEl(4)), sind(locEl(5)), 401);
    elScan = asind(uScan);
    rhoAzLut = zeros(size(azScan));
    rhoElLut = zeros(size(elScan));
    mainAz = zeros(size(azScan));
    mainEl = zeros(size(elScan));
    for i = 1:numel(azScan)
        a = steer_raw_array_local(X, Y, Z, cfg88.lambda, azScan(i), locEl(2));
        a = a(:);
        aL = abs(W(:, 1)' * a);
        aC = abs(W(:, 2)' * a);
        aR = abs(W(:, 3)' * a);
        rhoAzLut(i) = (aR - aL) / max(aR + aL, eps);
        mainAz(i) = aC - max(aL, aR);
    end
    for i = 1:numel(elScan)
        a = steer_raw_array_local(X, Y, Z, cfg88.lambda, locAz(2), elScan(i));
        a = a(:);
        aD = abs(W(:, 4)' * a);
        aC = abs(W(:, 2)' * a);
        aU = abs(W(:, 5)' * a);
        rhoElLut(i) = (aU - aD) / max(aU + aD, eps);
        mainEl(i) = aC - max(aD, aU);
    end
    idxAz = find(mainAz >= 0);
    idxEl = find(mainEl >= 0);
    if isempty(idxAz)
        azEst = locAz(2);
    else
        azEst = invert_ratio_monotonic_local(azScan(idxAz), rhoAzLut(idxAz), rhoAz, ampAz, locAz(2));
    end
    if isempty(idxEl)
        elEst = locEl(2);
    else
        elEst = invert_ratio_monotonic_local(elScan(idxEl), rhoElLut(idxEl), rhoEl, ampEl, locEl(2));
    end
end

function valEst = invert_ratio_monotonic_local(ax, rhoLut, rhoIn, amp3, ctr)
    ax = ax(:);
    rhoLut = rhoLut(:);
    [~, idxCtr] = min(abs(ax - ctr));
    if amp3(3) == amp3(1)
        valEst = ctr;
        return
    end
    if amp3(3) > amp3(1)
        idx1 = walk_monotonic_local(rhoLut, idxCtr, +1);
        idxBr = idxCtr:idx1;
    else
        idx0 = walk_monotonic_local(rhoLut, idxCtr - 1, -1);
        idxBr = idx0:idxCtr;
    end
    axBr = ax(idxBr);
    rhoBr = rhoLut(idxBr);
    if rhoBr(1) > rhoBr(end)
        rhoBr = flipud(rhoBr);
        axBr = flipud(axBr);
    end
    rhoLim = min(max(rhoIn, min(rhoBr)), max(rhoBr));
    valEst = interp1(rhoBr, axBr, rhoLim, 'linear', 'extrap');
end

function idx = walk_monotonic_local(rhoLut, idx0, dir)
    idx0 = min(max(idx0, 1), numel(rhoLut) - 1);
    dRho = diff(rhoLut(:));
    sRef = sign(dRho(idx0));
    if sRef == 0
        sRef = sign(dir);
    end
    idx = idx0;
    if dir < 0
        kVals = idx0:-1:1;
    else
        kVals = idx0:numel(dRho);
    end
    for k = kVals
        sNow = sign(dRho(k));
        if sNow == 0
            sNow = sRef;
        end
        if sNow ~= sRef
            break
        end
        if dir < 0
            idx = k;
        else
            idx = k + 1;
        end
    end
end

function enhance_in = frontend_to_step87_input_derot_local(frontend_out, pc_like, cfg88, array_geom, derotation_mode)
    cols = frontend_out.selectedWorkColumns;
    centerAz = frontend_out.selectedCenterAz_deg;
    X = array_geom.X(cols, :);
    Y = array_geom.Y(cols, :);
    Z = array_geom.Z(cols, :);
    Y_raw = pc_like.Y_full_range(cols, :, :);
    A_ref = exp(-1j * 2*pi / cfg88.lambda * (X * cosd(centerAz) + Y * sind(centerAz)));
    Y_cal = Y_raw .* repmat(conj(A_ref), 1, 1, cfg88.Np);
    if isfinite(frontend_out.dopplerIdx) && frontend_out.dopplerIdx >= 1 && frontend_out.dopplerIdx <= numel(pc_like.fdAxis)
        fd_hat = pc_like.fdAxis(frontend_out.dopplerIdx);
        v_hat = pc_like.vAxis(frontend_out.dopplerIdx);
        fd_source = "fdAxis(dopplerIdx)";
    else
        fd_hat = 0;
        v_hat = NaN;
        fd_source = "fallback_zero";
    end
    derotation_sign = derotation_sign_from_mode_local(derotation_mode);
    derot = exp(1j * derotation_sign * 2*pi * fd_hat * pc_like.tSlow);
    Y_work = Y_cal .* reshape(derot, 1, 1, []);
    enhance_in = struct();
    enhance_in.Y_work = Y_work;
    enhance_in.thetaCenter_deg = centerAz;
    enhance_in.elAssumed_deg = frontend_out.coarseEl_deg;
    enhance_in.rangeIdx = frontend_out.rangeIdx;
    enhance_in.dopplerIdx = frontend_out.dopplerIdx;
    enhance_in.R_runtime_default_deg = cfg88.R_runtime_default_deg;
    enhance_in.R_runtime_expand_deg = cfg88.R_runtime_expand_deg;
    enhance_in.template_R_deg = cfg88.template_R_deg;
    enhance_in.selectedWorkColumns = cols;
    enhance_in.arrayInfo = struct('X', X, 'Y', Y, 'Z', Z, 'A_ref', A_ref);
    enhance_in.cfg = cfg88;
    enhance_in.derotation_mode = string(derotation_mode);
    enhance_in.derotation_sign_used = derotation_sign;
    enhance_in.fd_hat = fd_hat;
    enhance_in.v_hat = v_hat;
    enhance_in.fd_hat_source = fd_source;
    enhance_in.fd_true_if_available = cfg88.fd_true;
    enhance_in.fd_error = fd_hat - cfg88.fd_true;
end

function derotation_sign = derotation_sign_from_mode_local(mode_name)
    switch string(mode_name)
        case "derotation_minus"
            derotation_sign = -1;
        case "derotation_plus"
            derotation_sign = +1;
        otherwise
            derotation_sign = 0;
    end
end

function enhance_in = make_empty_enhance_input_local(frontend_out, cfg88)
    enhance_in = struct();
    enhance_in.Y_work = complex(zeros(cfg88.workColumns, cfg88.Nel, cfg88.Np));
    enhance_in.thetaCenter_deg = frontend_out.selectedCenterAz_deg;
    enhance_in.elAssumed_deg = frontend_out.coarseEl_deg;
    enhance_in.rangeIdx = frontend_out.rangeIdx;
    enhance_in.dopplerIdx = frontend_out.dopplerIdx;
    enhance_in.R_runtime_default_deg = cfg88.R_runtime_default_deg;
    enhance_in.R_runtime_expand_deg = cfg88.R_runtime_expand_deg;
    enhance_in.template_R_deg = cfg88.template_R_deg;
    enhance_in.selectedWorkColumns = frontend_out.selectedWorkColumns;
    enhance_in.cfg = cfg88;
    enhance_in.arrayInfo = struct();
    enhance_in.derotation_mode = "not_available";
    enhance_in.derotation_sign_used = NaN;
    enhance_in.fd_hat = NaN;
    enhance_in.v_hat = NaN;
    enhance_in.fd_hat_source = "not_available";
    enhance_in.fd_true_if_available = cfg88.fd_true;
    enhance_in.fd_error = NaN;
end

function [ctx, cache] = get_or_build_step87_context_local(cache, enhance_in, cfg88, array_geom, fid_log)
    key = sprintf('col_%03d_R_%g', enhance_in.selectedWorkColumns(cfg88.workHalfColumns + 1), cfg88.R_runtime_default_deg);
    for i = 1:numel(cache)
        if strcmp(cache(i).key, key)
            ctx = cache(i).ctx;
            return
        end
    end
    cols = enhance_in.selectedWorkColumns;
    X3d = array_geom.X(cols, :);
    Y3d = array_geom.Y(cols, :);
    Z3d = array_geom.Z(cols, :);
    thetaCenter = enhance_in.thetaCenter_deg;
    A_ref_2d = exp(-1j * 2*pi / cfg88.lambda * (X3d * cosd(thetaCenter) + Y3d * sind(thetaCenter)));
    R = cfg88.R_runtime_default_deg;
    az_grid = thetaCenter - R:cfg88.azGridStep_deg:thetaCenter + R;
    level2_pair_candidates = make_pair_candidates_local(az_grid, cfg88.min_pair_sep_deg, cfg88.max_pair_sep_deg);
    log_msg_local(fid_log, 'Building Step 8.7 context for selected center %.6f deg, grid points=%d, pair candidates=%d.', ...
        thetaCenter, numel(az_grid), size(level2_pair_candidates, 1));
    level2_cache_map = precompute_level2_bank_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg88.lambda, az_grid, cfg88.elBank_deg, cfg88.K_phi_level2, level2_pair_candidates);
    level2_refocus_cache_map = precompute_level2_bank_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg88.lambda, az_grid, cfg88.elRefocusGrid_deg, cfg88.K_phi_level2, level2_pair_candidates);
    music_cache = make_level3_grid_cache_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg88.lambda, az_grid, cfg88.elGrid_deg, cfg88.K_phi_music, cfg88.K_z_music);
    [p_sel, r_sel] = make_selected_2d_subarray_positions_local(cfg88.workColumns, cfg88.Nel, cfg88.K_phi_covfit, cfg88.K_z_covfit);
    ctx = struct('X3d', X3d, 'Y3d', Y3d, 'Z3d', Z3d, 'A_ref_2d', A_ref_2d, ...
        'az_grid', az_grid, 'el_grid', cfg88.elGrid_deg, 'el_refocus_grid', cfg88.elRefocusGrid_deg, ...
        'level2_cache_map', level2_cache_map, 'level2_refocus_cache_map', level2_refocus_cache_map, ...
        'music_cache', music_cache, 'p_sel', p_sel, 'r_sel', r_sel);
    cache(end+1).key = key;
    cache(end).ctx = ctx;
end

function [result, timing] = run_step87_shared_center_lazy_local(enhance_in, sc, ctx, cfg88)
    sc87 = struct();
    sc87.el_assumed = enhance_in.elAssumed_deg;
    if sc.target_count == 1
        sc87.el_true = [sc.el1, sc.el1];
        theta_true = [sc.theta1, sc.theta1 + cfg88.min_pair_sep_deg];
    else
        sc87.el_true = [sc.el1, sc.el2];
        theta_true = sort([sc.theta1, sc.theta2]);
    end
    [result, timing] = run_lazy_cascade_wallclock_local( ...
        enhance_in.Y_work, sc87, ctx.X3d, ctx.Y3d, ctx.Z3d, ctx.A_ref_2d, cfg88.lambda, ...
        ctx.az_grid, ctx.el_refocus_grid, cfg88.K_phi_level2, cfg88.K_phi_music, cfg88.K_z_music, ...
        cfg88.K_phi_covfit, cfg88.K_z_covfit, cfg88.Lc, ctx.level2_cache_map, ...
        ctx.level2_refocus_cache_map, ctx.music_cache, ctx.p_sel, ctx.r_sel, theta_true, ...
        cfg88.min_pair_sep_deg, cfg88.max_pair_sep_deg);
end

function row = make_trial_row_local(sc, imc, frontend_out, enhance_in, result, timing, cfg88)
    target2 = sc.target_count == 2;
    if target2
        pair_center = mean([sc.theta1, sc.theta2]);
        strong_target = sc.theta1;
        delta1 = wrap180_local(sc.theta1 - frontend_out.selectedCenterAz_deg);
        delta2 = wrap180_local(sc.theta2 - frontend_out.selectedCenterAz_deg);
    else
        pair_center = sc.theta1;
        strong_target = sc.theta1;
        delta1 = wrap180_local(sc.theta1 - frontend_out.selectedCenterAz_deg);
        delta2 = NaN;
    end
    t1R15 = abs(delta1) <= cfg88.R_runtime_default_deg;
    t2R15 = ~target2 || abs(delta2) <= cfg88.R_runtime_default_deg;
    t1R20 = abs(delta1) <= cfg88.R_runtime_expand_deg;
    t2R20 = ~target2 || abs(delta2) <= cfg88.R_runtime_expand_deg;
    bothR15 = t1R15 && t2R15;
    bothR20 = t1R20 && t2R20;
    route = string(getfield_default_local(result, 'recommended_route', ""));
    conf = string(getfield_default_local(result, 'confidence_flag', ""));
    if route == ""
        route = "not_run";
    end
    if target2 && frontend_out.cfar_detected_flag && ~frontend_out.two_coarse_peaks_out_of_scope
        success = joint_success_from_result_local(result, sort([sc.theta1, sc.theta2]), [sc.el1, sc.el2], cfg88.az_tol_deg, cfg88.el_tol_deg);
    elseif ~target2 && frontend_out.cfar_detected_flag && ~frontend_out.two_coarse_peaks_out_of_scope
        finite_pair = all(isfinite(getfield_default_local(result, 'az_est', [NaN, NaN])));
        success = ~(strcmp(conf, "high") && finite_pair);
    else
        success = false;
    end
    boundary_truth = sc.weak_target_truth_flag || sc.anti_phase_truth_flag;
    false_high = strcmp(conf, "high") && ~success;
    low_conf = strcmp(conf, "low") || any(strcmp(route, ["low_confidence", "boundary_unreliable", "cfar_not_detected", "two_coarse_peaks_out_of_scope"]));
    boundary_unreliable = strcmp(route, "boundary_unreliable");
    boundary_missed = boundary_truth && strcmp(conf, "high") && ~low_conf && ~success;
    center_success = (target2 && bothR20) || (~target2 && t1R15);
    row = struct();
    row.scenario_name = sc.scenario_name;
    row.snr_db = sc.snr_db;
    row.mc = imc;
    row.target_count = sc.target_count;
    row.beta = sc.beta;
    row.rho = sc.rho;
    row.phase = sc.phase_deg;
    row.pair_sep = sc.pair_sep;
    row.true_az1 = sc.theta1;
    row.true_az2 = sc.theta2;
    row.true_el1 = sc.el1;
    row.true_el2 = sc.el2;
    row.coarse_peak_count = frontend_out.peakCountCoarse;
    row.raw_coarse_peak_count = frontend_out.rawCoarsePeakCount;
    row.coarse_peak_sep_deg = frontend_out.coarsePeakSep_deg;
    row.second_peak_prominence = frontend_out.secondPeakProminence;
    row.frontend_state = frontend_out.frontend_state;
    row.in_scope_shared_center_flag = frontend_out.in_scope_shared_center_flag;
    row.out_of_scope_reason = frontend_out.out_of_scope_reason;
    row.merge_candidate_flag = frontend_out.merge_candidate_flag;
    row.weak_secondary_candidate_flag = frontend_out.weak_secondary_candidate_flag;
    row.selected_center_valid_flag = frontend_out.selected_center_valid_flag;
    row.coarseAz = frontend_out.coarseAz_deg;
    row.coarseEl = frontend_out.coarseEl_deg;
    row.selectedCenterAz = frontend_out.selectedCenterAz_deg;
    row.selectedCenterColumn = frontend_out.selectedCenterColumn;
    row.center_error_to_pair_center = wrap180_local(frontend_out.selectedCenterAz_deg - pair_center);
    row.center_error_to_strong_target = wrap180_local(frontend_out.selectedCenterAz_deg - strong_target);
    row.delta_theta1 = delta1;
    row.delta_theta2 = delta2;
    row.target1_inside_R15 = t1R15;
    row.target2_inside_R15 = t2R15;
    row.both_inside_R15 = bothR15;
    row.target1_inside_R20 = t1R20;
    row.target2_inside_R20 = t2R20;
    row.both_inside_R20 = bothR20;
    row.rangeIdx = frontend_out.rangeIdx;
    row.dopplerIdx = frontend_out.dopplerIdx;
    row.cfar_detected_flag = frontend_out.cfar_detected_flag;
    row.cfarCount = frontend_out.cfarCount;
    row.cfarBestMetric = frontend_out.cfarBestMetric;
    row.two_coarse_peaks_out_of_scope = frontend_out.two_coarse_peaks_out_of_scope;
    row.route_used = route;
    row.confidence_flag = conf;
    row.success = success;
    row.false_high = false_high;
    row.boundary_missed = boundary_missed;
    row.low_confidence = low_conf;
    row.boundary_unreliable = boundary_unreliable;
    row.center_selection_success = center_success;
    row.runtime_sec = timing.t_total;
    row.executed_level2_music = timing.executed_level2_music;
    row.executed_refocus = timing.executed_refocus;
    row.executed_level2_rank1 = timing.executed_level2_rank1;
    row.executed_2dmusic = timing.executed_2dmusic;
    row.executed_pair_local = timing.executed_pair_local;
    row.enhance_thetaCenter_deg = enhance_in.thetaCenter_deg;
    row.enhance_elAssumed_deg = enhance_in.elAssumed_deg;
    row.weak_target_truth_flag = sc.weak_target_truth_flag;
    row.anti_phase_truth_flag = sc.anti_phase_truth_flag;
    row.large_el_truth_flag = sc.large_el_truth_flag;
end

function diag = compute_ywork_diagnostics_local(Y_work)
    Ymat = reshape(Y_work, [], size(Y_work, 3));
    nSnap = max(size(Ymat, 2), 1);
    C = (Ymat' * Ymat) / nSnap;
    C = 0.5 * (C + C');
    vals = sort(real(eig(C)), 'descend');
    vals = max(vals, 0);
    if isempty(vals)
        vals = 0;
    end
    lambda1 = vals(1);
    if numel(vals) >= 2
        lambda2 = vals(2);
    else
        lambda2 = 0;
    end
    if numel(vals) >= 3
        noise_mean = mean(vals(3:end), 'omitnan');
    else
        noise_mean = eps;
    end
    diag = struct();
    diag.covariance_trace = real(trace(C));
    diag.eigen_ratio_1_2 = lambda1 / max(lambda2, eps);
    diag.eigen_ratio_2_noise = lambda2 / max(noise_mean, eps);
    diag.covariance_condition_proxy = lambda1 / max(vals(end), eps);
    diag.snapshot_coherence_proxy = snapshot_coherence_proxy_local(Ymat);
end

function coh = snapshot_coherence_proxy_local(Ymat)
    if size(Ymat, 2) < 2
        coh = NaN;
        return
    end
    vals = zeros(size(Ymat, 2) - 1, 1);
    for k = 1:numel(vals)
        a = Ymat(:, k);
        b = Ymat(:, k + 1);
        vals(k) = abs(a' * b) / max(norm(a) * norm(b), eps);
    end
    coh = mean(vals, 'omitnan');
end

function row = make_derot_trial_row_local(sc, imc, mode_name, frontend_out, enhance_in, result, timing, ydiag, cfg88)
    target2 = sc.target_count == 2;
    if target2
        pair_center = mean([sc.theta1, sc.theta2]);
        strong_target = sc.theta1;
        delta1 = wrap180_local(sc.theta1 - frontend_out.selectedCenterAz_deg);
        delta2 = wrap180_local(sc.theta2 - frontend_out.selectedCenterAz_deg);
    else
        pair_center = sc.theta1;
        strong_target = sc.theta1;
        delta1 = wrap180_local(sc.theta1 - frontend_out.selectedCenterAz_deg);
        delta2 = NaN;
    end
    t1R15 = abs(delta1) <= cfg88.R_runtime_default_deg;
    t2R15 = ~target2 || abs(delta2) <= cfg88.R_runtime_default_deg;
    t1R20 = abs(delta1) <= cfg88.R_runtime_expand_deg;
    t2R20 = ~target2 || abs(delta2) <= cfg88.R_runtime_expand_deg;
    bothR15 = t1R15 && t2R15;
    bothR20 = t1R20 && t2R20;

    route = string(getfield_default_local(result, 'recommended_route', ""));
    conf = string(getfield_default_local(result, 'confidence_flag', ""));
    if route == ""
        route = "not_run";
    end
    in_scope = logical(frontend_out.in_scope_shared_center_flag);
    if target2 && frontend_out.cfar_detected_flag && in_scope
        success = joint_success_from_result_local(result, sort([sc.theta1, sc.theta2]), [sc.el1, sc.el2], cfg88.az_tol_deg, cfg88.el_tol_deg);
    elseif ~target2 && frontend_out.cfar_detected_flag && in_scope
        finite_pair = all(isfinite(getfield_default_local(result, 'az_est', [NaN, NaN])));
        success = ~(strcmp(conf, "high") && finite_pair);
    else
        success = false;
    end

    boundary_truth = sc.weak_target_truth_flag || sc.anti_phase_truth_flag;
    false_high = strcmp(conf, "high") && ~success;
    low_conf = strcmp(conf, "low") || any(strcmp(route, ["low_confidence", "boundary_unreliable", "cfar_not_detected", "two_coarse_peaks_out_of_scope"]));
    boundary_unreliable = strcmp(route, "boundary_unreliable");
    boundary_missed = boundary_truth && strcmp(conf, "high") && ~low_conf && ~success;
    az_est_vec = vec2_local(getfield_default_local(result, 'az_est', [NaN, NaN]));
    el_est_vec = vec2_local(getfield_default_local(result, 'el_est', [NaN, NaN]));

    row = struct();
    row.scenario_name = sc.scenario_name;
    row.snr_db = sc.snr_db;
    row.mc = imc;
    row.mode = string(mode_name);
    row.target_count = sc.target_count;
    row.beta = sc.beta;
    row.rho = sc.rho;
    row.phase = sc.phase_deg;
    row.pair_sep = sc.pair_sep;
    row.true_az1 = sc.theta1;
    row.true_az2 = sc.theta2;
    row.true_el1 = sc.el1;
    row.true_el2 = sc.el2;
    row.rangeIdx = frontend_out.rangeIdx;
    row.dopplerIdx = frontend_out.dopplerIdx;
    row.fd_hat = enhance_in.fd_hat;
    row.v_hat = enhance_in.v_hat;
    row.fd_hat_source = enhance_in.fd_hat_source;
    row.fd_true_if_available = enhance_in.fd_true_if_available;
    row.fd_error = enhance_in.fd_error;
    row.derotation_sign_used = enhance_in.derotation_sign_used;
    row.coarse_peak_count = frontend_out.peakCountCoarse;
    row.coarse_peak_sep_deg = frontend_out.coarsePeakSep_deg;
    row.second_peak_prominence = frontend_out.secondPeakProminence;
    row.frontend_state = frontend_out.frontend_state;
    row.in_scope_shared_center_flag = in_scope;
    row.out_of_scope_reason = frontend_out.out_of_scope_reason;
    row.selectedCenterAz = frontend_out.selectedCenterAz_deg;
    row.selectedCenterColumn = frontend_out.selectedCenterColumn;
    row.center_error_to_pair_center = wrap180_local(frontend_out.selectedCenterAz_deg - pair_center);
    row.center_error_to_strong_target = wrap180_local(frontend_out.selectedCenterAz_deg - strong_target);
    row.delta_theta1 = delta1;
    row.delta_theta2 = delta2;
    row.both_inside_R15 = bothR15;
    row.both_inside_R20 = bothR20;
    row.route_used = route;
    row.confidence_flag = conf;
    row.success = success;
    row.false_high = false_high;
    row.boundary_missed = boundary_missed;
    row.low_confidence = low_conf;
    row.boundary_unreliable = boundary_unreliable;
    row.az_est = sprintf('%.9g;%.9g', az_est_vec(1), az_est_vec(2));
    row.el_est = sprintf('%.9g;%.9g', el_est_vec(1), el_est_vec(2));
    row.az_est1 = az_est_vec(1);
    row.az_est2 = az_est_vec(2);
    row.el_est1 = el_est_vec(1);
    row.el_est2 = el_est_vec(2);
    row.runtime_sec = timing.t_total;
    row.covariance_trace = ydiag.covariance_trace;
    row.eigen_ratio_1_2 = ydiag.eigen_ratio_1_2;
    row.eigen_ratio_2_noise = ydiag.eigen_ratio_2_noise;
    row.covariance_condition_proxy = ydiag.covariance_condition_proxy;
    row.snapshot_coherence_proxy = ydiag.snapshot_coherence_proxy;
    row.weak_target_truth_flag = sc.weak_target_truth_flag;
    row.anti_phase_truth_flag = sc.anti_phase_truth_flag;
    row.large_el_truth_flag = sc.large_el_truth_flag;
    row.route_changed_minus_vs_no = false;
    row.route_changed_plus_vs_no = false;
    row.confidence_changed_minus_vs_no = false;
    row.confidence_changed_plus_vs_no = false;
    row.az_diff_minus_vs_no = NaN;
    row.az_diff_plus_vs_no = NaN;
    row.el_diff_minus_vs_no = NaN;
    row.el_diff_plus_vs_no = NaN;
end

function mode_rows = add_mode_comparisons_local(mode_rows)
    no_row = mode_rows{find_mode_row_local(mode_rows, "no_derotation")};
    minus_row = mode_rows{find_mode_row_local(mode_rows, "derotation_minus")};
    plus_row = mode_rows{find_mode_row_local(mode_rows, "derotation_plus")};

    route_changed_minus = minus_row.route_used ~= no_row.route_used;
    route_changed_plus = plus_row.route_used ~= no_row.route_used;
    conf_changed_minus = minus_row.confidence_flag ~= no_row.confidence_flag;
    conf_changed_plus = plus_row.confidence_flag ~= no_row.confidence_flag;
    az_diff_minus = pair_estimate_diff_local([minus_row.az_est1, minus_row.az_est2], [no_row.az_est1, no_row.az_est2]);
    az_diff_plus = pair_estimate_diff_local([plus_row.az_est1, plus_row.az_est2], [no_row.az_est1, no_row.az_est2]);
    el_diff_minus = pair_estimate_diff_local([minus_row.el_est1, minus_row.el_est2], [no_row.el_est1, no_row.el_est2]);
    el_diff_plus = pair_estimate_diff_local([plus_row.el_est1, plus_row.el_est2], [no_row.el_est1, no_row.el_est2]);

    for i = 1:numel(mode_rows)
        mode_rows{i}.route_changed_minus_vs_no = route_changed_minus;
        mode_rows{i}.route_changed_plus_vs_no = route_changed_plus;
        mode_rows{i}.confidence_changed_minus_vs_no = conf_changed_minus;
        mode_rows{i}.confidence_changed_plus_vs_no = conf_changed_plus;
        mode_rows{i}.az_diff_minus_vs_no = az_diff_minus;
        mode_rows{i}.az_diff_plus_vs_no = az_diff_plus;
        mode_rows{i}.el_diff_minus_vs_no = el_diff_minus;
        mode_rows{i}.el_diff_plus_vs_no = el_diff_plus;
    end
end

function idx = find_mode_row_local(mode_rows, mode_name)
    idx = 1;
    for i = 1:numel(mode_rows)
        if mode_rows{i}.mode == mode_name
            idx = i;
            return
        end
    end
end

function v = vec2_local(x)
    x = x(:).';
    if isempty(x)
        v = [NaN, NaN];
    elseif numel(x) == 1
        v = [x(1), NaN];
    else
        v = x(1:2);
    end
end

function d = pair_estimate_diff_local(a, b)
    a = sort(a(isfinite(a)));
    b = sort(b(isfinite(b)));
    if isempty(a) && isempty(b)
        d = 0;
    elseif numel(a) ~= numel(b)
        d = NaN;
    else
        d = max(abs(a(:) - b(:)));
    end
end

function quant_modes = build_step89c_quant_modes_local()
    q0 = make_quant_mode_local("double_baseline", "double", NaN, "double", NaN, "all_double", ...
        NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        "all-double Step 8.7/8.8 shared-center baseline");
    quant_modes = repmat(q0, 1, 10);
    quant_modes(1) = q0;
    quant_modes(2) = make_quant_mode_local("float32_all", "float32", NaN, "float32", NaN, "all_float32", ...
        NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        "Y_work and complex steering/cache cast to single then back to double");
    quant_modes(3) = make_quant_mode_local("y16_coeff24_all", "fixed", 24, "fixed", 16, "all_fixed", ...
        24, 24, 24, 24, 24, 24, 24, ...
        "Y_work int16, all complex steering/template/cache coefficients int24");
    quant_modes(4) = make_quant_mode_local("y16_coeff18_all", "fixed", 18, "fixed", 16, "all_fixed", ...
        18, 18, 18, 18, 18, 18, 18, ...
        "Y_work int16, all complex steering/template/cache coefficients int18");
    quant_modes(5) = make_quant_mode_local("y18_coeff24_all", "fixed", 24, "fixed", 18, "all_fixed", ...
        24, 24, 24, 24, 24, 24, 24, ...
        "Y_work int18, all complex steering/template/cache coefficients int24");
    quant_modes(6) = make_quant_mode_local("y16_coeff32float", "float32", NaN, "fixed", 16, "all_float32", ...
        NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        "Y_work int16, coefficients float32; upper bound for input quantization only");
    quant_modes(7) = make_quant_mode_local("y32float_coeff24", "fixed", 24, "float32", NaN, "all_fixed", ...
        24, 24, 24, 24, 24, 24, 24, ...
        "Y_work float32, all coefficients int24; upper bound for coefficient int24");
    quant_modes(8) = make_quant_mode_local("y16_rank1_coeff24_rest16", "mixed", NaN, "fixed", 16, "route_specific", ...
        16, 16, 24, 16, 16, 16, 16, ...
        "Y_work int16, rank1-related caches int24, other complex coefficients int16");
    quant_modes(9) = make_quant_mode_local("y16_2d_pair_coeff24_rest16", "mixed", NaN, "fixed", 16, "route_specific", ...
        16, 16, 16, 24, 16, 24, 16, ...
        "Y_work int16, 2D MUSIC and pair-local reference coefficients int24, other coefficients int16");
    quant_modes(10) = make_quant_mode_local("y16_rank1_2d_coeff24_rest16", "mixed", NaN, "fixed", 16, "route_specific", ...
        16, 16, 24, 24, 16, 24, 16, ...
        "Y_work int16, rank1 + 2D/pair-local coefficients int24, other coefficients int16");
    quant_modes(11) = make_quant_mode_local("y16_refocus_rank1_coeff24_rest16", "mixed", NaN, "fixed", 16, "route_specific", ...
        16, 16, 16, 16, 24, 16, 16, ...
        "Y_work int16, refocus rank1/cache coefficients int24, other coefficients int16");
end

function quant_modes = build_step89_quant_modes_local()
    quant_modes = build_step89c_quant_modes_local();
end

function qmode = make_quant_mode_local(name, coeff_kind, coeff_bits, y_kind, y_bits, coeff_policy, ...
        default_coeff_bits, level2_music_bits, rank1_bits, two_d_bits, refocus_bits, pair_local_bits, common_bits, note)
    if nargin <= 6
        coeff_policy = "all_fixed";
        default_coeff_bits = coeff_bits;
        level2_music_bits = coeff_bits;
        rank1_bits = coeff_bits;
        two_d_bits = coeff_bits;
        refocus_bits = coeff_bits;
        pair_local_bits = coeff_bits;
        common_bits = coeff_bits;
    end
    qmode = struct('name', string(name), 'coeff_kind', string(coeff_kind), 'coeff_bits', coeff_bits, ...
        'y_kind', string(y_kind), 'y_bits', y_bits, 'coeff_policy', string(coeff_policy), ...
        'default_coeff_bits', default_coeff_bits, 'level2_music_coeff_bits', level2_music_bits, ...
        'rank1_coeff_bits', rank1_bits, 'two_d_coeff_bits', two_d_bits, ...
        'refocus_coeff_bits', refocus_bits, 'pair_local_coeff_bits', pair_local_bits, ...
        'common_coeff_bits', common_bits, 'note', string(note));
end

function [enhance_q, yq] = apply_ywork_quant_mode_local(enhance_in, qmode)
    enhance_q = enhance_in;
    Y_ref = enhance_in.Y_work;
    switch qmode.y_kind
        case "fixed"
            [Y_q, yq] = quantize_ywork_block_float_local(Y_ref, qmode.y_bits, qmode.name);
        case "float32"
            Y_q = double(single(Y_ref));
            yq = compute_ywork_quant_diag_local(Y_ref, Y_q, qmode.name, "float32", NaN, NaN, 0, 0);
        otherwise
            Y_q = Y_ref;
            yq = compute_ywork_quant_diag_local(Y_ref, Y_q, qmode.name, "double", NaN, NaN, 0, 0);
    end
    enhance_q.Y_work = Y_q;
    enhance_q.quant_mode = qmode.name;
    enhance_q.coeff_quant_kind = qmode.coeff_kind;
    enhance_q.coeff_quant_bits = qmode.coeff_bits;
    enhance_q.ywork_quant_kind = qmode.y_kind;
    enhance_q.ywork_quant_bits = qmode.y_bits;
end

function [Y_q, diag] = quantize_ywork_block_float_local(Y, bits, mode_name)
    vals = [abs(real(Y(:))); abs(imag(Y(:)))];
    scale_y = max([vals; eps]);
    Yn = Y / scale_y;
    [Qr, clip_r] = quantize_real_unit_local(real(Yn), bits);
    [Qi, clip_i] = quantize_real_unit_local(imag(Yn), bits);
    Y_q = complex(Qr, Qi) * scale_y;
    diag = compute_ywork_quant_diag_local(Y, Y_q, mode_name, "fixed", bits, scale_y, clip_r, clip_i);
end

function diag = compute_ywork_quant_diag_local(Y_ref, Y_q, mode_name, y_kind, bits, scale_y, clip_r, clip_i)
    err = Y_q - Y_ref;
    ref_norm = norm(Y_ref(:));
    err_norm = norm(err(:));
    if ref_norm <= eps
        rel_err = 0;
    else
        rel_err = err_norm / ref_norm;
    end
    if err_norm <= eps
        snr_db = Inf;
    else
        snr_db = 20 * log10(max(ref_norm, eps) / err_norm);
    end
    if isnan(scale_y)
        vals = [abs(real(Y_ref(:))); abs(imag(Y_ref(:)))];
        scale_y = max([vals; eps]);
    end
    diag = struct();
    diag.quant_mode = string(mode_name);
    diag.ywork_quant_kind = string(y_kind);
    diag.ywork_quant_bits = bits;
    diag.ywork_scale = scale_y;
    diag.ywork_rel_err = rel_err;
    diag.ywork_snr_quant_db = snr_db;
    diag.ywork_max_abs_err = max(abs(err(:)));
    diag.ywork_clip_rate_real = clip_r;
    diag.ywork_clip_rate_imag = clip_i;
end

function [xq, clip_rate] = quantize_real_unit_local(x, bits)
    imax = 2^(bits - 1) - 1;
    xi = round(x * imax);
    clip_mask = xi < -imax | xi > imax;
    xi = min(max(xi, -imax), imax);
    xq = xi / imax;
    clip_rate = mean(clip_mask(:));
end

function [ctx_q, diag, cache] = get_or_build_quant_context_local(cache, ctx_base, enhance_in, cfg88, qmode)
    center_col = enhance_in.selectedWorkColumns(cfg88.workHalfColumns + 1);
    key = sprintf('col_%03d_%s', center_col, char(qmode.name));
    for i = 1:numel(cache)
        if strcmp(cache(i).key, key)
            ctx_q = cache(i).ctx;
            diag = cache(i).diag;
            return
        end
    end
    ctx_q = apply_context_quant_mode_local(ctx_base, qmode);
    diag = compute_steering_error_diag_local(ctx_base, ctx_q, qmode, cfg88, center_col);
    cache(end+1).key = key;
    cache(end).ctx = ctx_q;
    cache(end).diag = diag;
end

function ctx_q = apply_context_quant_mode_local(ctx, qmode)
    switch qmode.coeff_kind
        case "fixed"
            ctx_q = quantize_complex_recursive_local(ctx, qmode.coeff_bits);
            ctx_q = refresh_rank1_precomp_from_subcache_local(ctx_q);
        case "float32"
            ctx_q = cast_complex_recursive_single_local(ctx);
            ctx_q = refresh_rank1_precomp_from_subcache_local(ctx_q);
        case "mixed"
            ctx_q = quantize_mixed_context_local(ctx, qmode);
            ctx_q = refresh_rank1_precomp_from_subcache_local(ctx_q);
        otherwise
            ctx_q = ctx;
    end
end

function ctx_q = quantize_mixed_context_local(ctx, qmode)
    default_bits = finite_or_default_local(qmode.default_coeff_bits, 16);
    ctx_q = quantize_complex_recursive_local(ctx, default_bits);

    if isfinite(qmode.common_coeff_bits) && qmode.common_coeff_bits ~= default_bits
        ctx_common = quantize_complex_recursive_local(ctx, qmode.common_coeff_bits);
        ctx_q.A_ref_2d = ctx_common.A_ref_2d;
    end
    if isfinite(qmode.level2_music_coeff_bits) && qmode.level2_music_coeff_bits ~= default_bits
        ctx_l2 = quantize_complex_recursive_local(ctx, qmode.level2_music_coeff_bits);
        ctx_q.A_ref_2d = ctx_l2.A_ref_2d;
    end
    if isfinite(qmode.rank1_coeff_bits) && qmode.rank1_coeff_bits ~= default_bits
        ctx_rank1 = quantize_complex_recursive_local(ctx, qmode.rank1_coeff_bits);
        ctx_q.level2_cache_map = ctx_rank1.level2_cache_map;
    end
    if isfinite(qmode.refocus_coeff_bits) && qmode.refocus_coeff_bits ~= default_bits
        ctx_refocus = quantize_complex_recursive_local(ctx, qmode.refocus_coeff_bits);
        ctx_q.level2_refocus_cache_map = ctx_refocus.level2_refocus_cache_map;
    end
    if isfinite(qmode.two_d_coeff_bits) && qmode.two_d_coeff_bits ~= default_bits
        ctx_2d = quantize_complex_recursive_local(ctx, qmode.two_d_coeff_bits);
        ctx_q.music_cache = ctx_2d.music_cache;
        ctx_q.A_ref_2d = ctx_2d.A_ref_2d;
    end
    if isfinite(qmode.pair_local_coeff_bits) && qmode.pair_local_coeff_bits ~= default_bits
        ctx_pair = quantize_complex_recursive_local(ctx, qmode.pair_local_coeff_bits);
        ctx_q.A_ref_2d = ctx_pair.A_ref_2d;
    end
end

function v = finite_or_default_local(v, default_v)
    if ~isfinite(v)
        v = default_v;
    end
end

function ctx = refresh_rank1_precomp_from_subcache_local(ctx)
    if isfield(ctx, 'level2_cache_map')
        for i = 1:numel(ctx.level2_cache_map)
            pairs = ctx.level2_cache_map(i).precomp.candidate_pairs;
            ctx.level2_cache_map(i).precomp = precompute_rank1_pair_bases_local(ctx.level2_cache_map(i).sub_cache, pairs);
        end
    end
    if isfield(ctx, 'level2_refocus_cache_map')
        for i = 1:numel(ctx.level2_refocus_cache_map)
            pairs = ctx.level2_refocus_cache_map(i).precomp.candidate_pairs;
            ctx.level2_refocus_cache_map(i).precomp = precompute_rank1_pair_bases_local(ctx.level2_refocus_cache_map(i).sub_cache, pairs);
        end
    end
end

function y = quantize_complex_recursive_local(x, bits)
    if isnumeric(x)
        if ~isreal(x)
            [yr, ~] = quantize_real_unit_local(real(x), bits);
            [yi, ~] = quantize_real_unit_local(imag(x), bits);
            y = complex(yr, yi);
        else
            y = x;
        end
    elseif isstruct(x)
        y = x;
        f = fieldnames(x);
        for k = 1:numel(x)
            for i = 1:numel(f)
                y(k).(f{i}) = quantize_complex_recursive_local(x(k).(f{i}), bits);
            end
        end
    elseif iscell(x)
        y = x;
        for i = 1:numel(x)
            y{i} = quantize_complex_recursive_local(x{i}, bits);
        end
    else
        y = x;
    end
end

function y = cast_complex_recursive_single_local(x)
    if isnumeric(x)
        if ~isreal(x)
            y = double(single(x));
        else
            y = x;
        end
    elseif isstruct(x)
        y = x;
        f = fieldnames(x);
        for k = 1:numel(x)
            for i = 1:numel(f)
                y(k).(f{i}) = cast_complex_recursive_single_local(x(k).(f{i}));
            end
        end
    elseif iscell(x)
        y = x;
        for i = 1:numel(x)
            y{i} = cast_complex_recursive_single_local(x{i});
        end
    else
        y = x;
    end
end

function diag = compute_steering_error_diag_local(ctx_ref, ctx_q, qmode, cfg88, center_col)
    mode_name = qmode.name;
    rows = repmat(empty_steering_diag_row_local(mode_name, center_col, ""), 1, 5);
    theta0 = mean(ctx_ref.az_grid);
    el0 = 0;
    Afull_ref = steering_2d_full_local(ctx_ref.X3d, ctx_ref.Y3d, ctx_ref.Z3d, ctx_ref.A_ref_2d, cfg88.lambda, theta0, el0);
    Afull_q = steering_2d_full_local(ctx_q.X3d, ctx_q.Y3d, ctx_q.Z3d, ctx_q.A_ref_2d, cfg88.lambda, theta0, el0);
    rows(1) = make_steering_error_row_local(mode_name, center_col, "full_65x32", Afull_ref, Afull_q);

    rows(2) = make_steering_error_row_local(mode_name, center_col, "music2d_center_subarray", ...
        ctx_ref.music_cache.A_center, ctx_q.music_cache.A_center);

    p0 = ctx_ref.p_sel(ceil(numel(ctx_ref.p_sel) / 2));
    r0 = ctx_ref.r_sel(ceil(numel(ctx_ref.r_sel) / 2));
    As_ref = Afull_ref(p0:p0+cfg88.K_phi_covfit-1, r0:r0+cfg88.K_z_covfit-1);
    As_q = Afull_q(p0:p0+cfg88.K_phi_covfit-1, r0:r0+cfg88.K_z_covfit-1);
    rows(3) = make_steering_error_row_local(mode_name, center_col, "pairlocal_selected_subarray", ...
        As_ref(:) / max(norm(As_ref(:)), eps), As_q(:) / max(norm(As_q(:)), eps));

    idx_el = nearest_index_local([ctx_ref.level2_cache_map.el], el0);
    rows(4) = make_steering_error_row_local(mode_name, center_col, "level2_combined", ...
        ctx_ref.level2_cache_map(idx_el).sub_cache.A_forward, ...
        ctx_q.level2_cache_map(idx_el).sub_cache.A_forward);

    z_col = ctx_ref.Z3d(1, :).';
    W_ref = exp(-1j * 2*pi / cfg88.lambda * z_col * sind(cfg88.elRefocusGrid_deg)) / sqrt(cfg88.Nel);
    if qmode.coeff_kind == "fixed" || qmode.coeff_kind == "mixed"
        if qmode.coeff_kind == "mixed"
            w_bits = finite_or_default_local(qmode.refocus_coeff_bits, qmode.default_coeff_bits);
        else
            w_bits = qmode.coeff_bits;
        end
        [Wr, ~] = quantize_real_unit_local(real(W_ref), w_bits);
        [Wi, ~] = quantize_real_unit_local(imag(W_ref), w_bits);
        W_q = complex(Wr, Wi);
    elseif qmode.coeff_kind == "float32"
        W_q = double(single(W_ref));
    else
        W_q = W_ref;
    end
    rows(5) = make_steering_error_row_local(mode_name, center_col, "refocus_weight", W_ref, W_q);
    diag = rows;
end

function idx = nearest_index_local(v, x)
    [~, idx] = min(abs(v - x));
end

function row = empty_steering_diag_row_local(mode_name, center_col, steering_type)
    row = struct('quant_mode', string(mode_name), 'center_col', center_col, ...
        'steering_type', string(steering_type), 'rel_err_raw', NaN, ...
        'rel_err_aligned', NaN, 'coherence', NaN, 'phase_err_rms', NaN, ...
        'phase_err_max', NaN);
end

function diag = empty_steering_diag_local(mode_name)
    diag = empty_steering_diag_row_local(mode_name, NaN, "not_available");
end

function row = make_steering_error_row_local(mode_name, center_col, steering_type, a_ref, a_q)
    a = a_ref(:);
    b = a_q(:);
    nr = norm(a);
    nq = norm(b);
    if nr <= eps || nq <= eps
        coh = NaN;
        rel_raw = NaN;
        rel_aligned = NaN;
        phase_rms = NaN;
        phase_max = NaN;
    else
        inner = a' * b;
        coh = abs(inner) / max(nr * nq, eps);
        rel_raw = norm(b - a) / nr;
        phase0 = angle(inner);
        b_aligned = b * exp(-1j * phase0);
        rel_aligned = norm(b_aligned - a) / nr;
        valid = abs(a) > 1e-12 & abs(b_aligned) > 1e-12;
        ph = angle(b_aligned(valid) .* conj(a(valid)));
        if isempty(ph)
            phase_rms = NaN;
            phase_max = NaN;
        else
            phase_rms = sqrt(mean(ph.^2));
            phase_max = max(abs(ph));
        end
    end
    row = struct('quant_mode', string(mode_name), 'center_col', center_col, ...
        'steering_type', string(steering_type), 'rel_err_raw', rel_raw, ...
        'rel_err_aligned', rel_aligned, 'coherence', coh, ...
        'phase_err_rms', phase_rms, 'phase_err_max', phase_max);
end

function tbl = collect_quant_context_diag_table_local(cache)
    rows = {};
    for i = 1:numel(cache)
        d = cache(i).diag;
        if numel(d) == 1
            rows{end+1, 1} = d; %#ok<AGROW>
        else
            for k = 1:numel(d)
                rows{end+1, 1} = d(k); %#ok<AGROW>
            end
        end
    end
    if isempty(rows)
        tbl = struct2table(empty_steering_diag_row_local("none", NaN, "none"));
        tbl(1, :) = [];
    else
        tbl = struct2table([rows{:}]);
    end
end

function agg = aggregate_steering_diag_local(diag)
    vals_rel = [diag.rel_err_aligned];
    vals_coh = [diag.coherence];
    vals_phase = [diag.phase_err_max];
    agg = struct();
    agg.mean_steering_rel_err_aligned = mean(vals_rel, 'omitnan');
    agg.max_steering_rel_err_aligned = max_or_nan_local(vals_rel);
    agg.min_steering_coherence = min_or_nan_local(vals_coh);
    agg.max_steering_phase_err = max_or_nan_local(vals_phase);
end

function val = min_or_nan_local(x)
    x = x(isfinite(x));
    if isempty(x)
        val = NaN;
    else
        val = min(x);
    end
end

function row = make_fixed_trial_row_local(sc, imc, qmode, frontend_out, enhance_in, result, timing, yq, qctx_diag, cfg88)
    target2 = sc.target_count == 2;
    if target2
        pair_center = mean([sc.theta1, sc.theta2]);
        strong_target = sc.theta1;
        delta1 = wrap180_local(sc.theta1 - frontend_out.selectedCenterAz_deg);
        delta2 = wrap180_local(sc.theta2 - frontend_out.selectedCenterAz_deg);
    else
        pair_center = sc.theta1;
        strong_target = sc.theta1;
        delta1 = wrap180_local(sc.theta1 - frontend_out.selectedCenterAz_deg);
        delta2 = NaN;
    end
    t1R15 = abs(delta1) <= cfg88.R_runtime_default_deg;
    t2R15 = ~target2 || abs(delta2) <= cfg88.R_runtime_default_deg;
    t1R20 = abs(delta1) <= cfg88.R_runtime_expand_deg;
    t2R20 = ~target2 || abs(delta2) <= cfg88.R_runtime_expand_deg;
    bothR15 = t1R15 && t2R15;
    bothR20 = t1R20 && t2R20;
    route = string(getfield_default_local(result, 'recommended_route', ""));
    conf = string(getfield_default_local(result, 'confidence_flag', ""));
    if route == ""
        route = "not_run";
    end
    in_scope = logical(frontend_out.in_scope_shared_center_flag);
    if target2 && frontend_out.cfar_detected_flag && in_scope
        success = joint_success_from_result_local(result, sort([sc.theta1, sc.theta2]), [sc.el1, sc.el2], cfg88.az_tol_deg, cfg88.el_tol_deg);
    elseif ~target2 && frontend_out.cfar_detected_flag && in_scope
        finite_pair = all(isfinite(getfield_default_local(result, 'az_est', [NaN, NaN])));
        success = ~(strcmp(conf, "high") && finite_pair);
    else
        success = false;
    end
    boundary_truth = sc.weak_target_truth_flag || sc.anti_phase_truth_flag;
    false_high = strcmp(conf, "high") && ~success;
    low_conf = strcmp(conf, "low") || any(strcmp(route, ["low_confidence", "boundary_unreliable", "cfar_not_detected", "two_coarse_peaks_out_of_scope"]));
    boundary_unreliable = strcmp(route, "boundary_unreliable");
    boundary_missed = boundary_truth && strcmp(conf, "high") && ~low_conf && ~success;
    az_est_vec = vec2_local(getfield_default_local(result, 'az_est', [NaN, NaN]));
    el_est_vec = vec2_local(getfield_default_local(result, 'el_est', [NaN, NaN]));
    sagg = aggregate_steering_diag_local(qctx_diag);

    row = struct();
    row.scenario_name = sc.scenario_name;
    row.snr_db = sc.snr_db;
    row.mc = imc;
    row.quant_mode = qmode.name;
    row.coeff_quant_kind = qmode.coeff_kind;
    row.coeff_quant_bits = qmode.coeff_bits;
    row.ywork_quant_kind = qmode.y_kind;
    row.ywork_quant_bits = qmode.y_bits;
    row.target_count = sc.target_count;
    row.beta = sc.beta;
    row.rho = sc.rho;
    row.phase = sc.phase_deg;
    row.pair_sep = sc.pair_sep;
    row.true_az1 = sc.theta1;
    row.true_az2 = sc.theta2;
    row.true_el1 = sc.el1;
    row.true_el2 = sc.el2;
    row.rangeIdx = frontend_out.rangeIdx;
    row.dopplerIdx = frontend_out.dopplerIdx;
    row.fd_hat = enhance_in.fd_hat;
    row.v_hat = enhance_in.v_hat;
    row.derotation_mode = "none";
    row.derotation_sign_used = 0;
    row.coarse_peak_count = frontend_out.peakCountCoarse;
    row.coarse_peak_sep_deg = frontend_out.coarsePeakSep_deg;
    row.second_peak_prominence = frontend_out.secondPeakProminence;
    row.frontend_state = frontend_out.frontend_state;
    row.in_scope_shared_center_flag = in_scope;
    row.out_of_scope_reason = frontend_out.out_of_scope_reason;
    row.selectedCenterAz = frontend_out.selectedCenterAz_deg;
    row.selectedCenterColumn = frontend_out.selectedCenterColumn;
    row.center_error_to_pair_center = wrap180_local(frontend_out.selectedCenterAz_deg - pair_center);
    row.center_error_to_strong_target = wrap180_local(frontend_out.selectedCenterAz_deg - strong_target);
    row.delta_theta1 = delta1;
    row.delta_theta2 = delta2;
    row.both_inside_R15 = bothR15;
    row.both_inside_R20 = bothR20;
    row.route_used = route;
    row.confidence_flag = conf;
    row.success = success;
    row.false_high = false_high;
    row.boundary_missed = boundary_missed;
    row.low_confidence = low_conf;
    row.boundary_unreliable = boundary_unreliable;
    row.az_est = sprintf('%.9g;%.9g', az_est_vec(1), az_est_vec(2));
    row.el_est = sprintf('%.9g;%.9g', el_est_vec(1), el_est_vec(2));
    row.az_est1 = az_est_vec(1);
    row.az_est2 = az_est_vec(2);
    row.el_est1 = el_est_vec(1);
    row.el_est2 = el_est_vec(2);
    row.output_count = sum(isfinite(az_est_vec));
    row.runtime_sec = timing.t_total;
    row.ywork_scale = yq.ywork_scale;
    row.ywork_rel_err = yq.ywork_rel_err;
    row.ywork_snr_quant_db = yq.ywork_snr_quant_db;
    row.ywork_max_abs_err = yq.ywork_max_abs_err;
    row.ywork_clip_rate_real = yq.ywork_clip_rate_real;
    row.ywork_clip_rate_imag = yq.ywork_clip_rate_imag;
    row.mean_steering_rel_err_aligned = sagg.mean_steering_rel_err_aligned;
    row.max_steering_rel_err_aligned = sagg.max_steering_rel_err_aligned;
    row.min_steering_coherence = sagg.min_steering_coherence;
    row.max_steering_phase_err = sagg.max_steering_phase_err;
    row.weak_target_truth_flag = sc.weak_target_truth_flag;
    row.anti_phase_truth_flag = sc.anti_phase_truth_flag;
    row.large_el_truth_flag = sc.large_el_truth_flag;
    if any(sc.scenario_name == ["single_target_sanity", "close_coherent_pair", "large_el_pair"])
        row.scenario_class = "core_in_scope";
    else
        row.scenario_class = "boundary_scenario";
    end
    row.route_agreement_vs_double_flag = true;
    row.confidence_agreement_vs_double_flag = true;
    row.double_confidence_group = conf;
    row.quant_confidence_group = conf;
    row.medium_or_above_double_flag = any(conf == ["medium", "high"]);
    row.dangerous_confidence_upgrade = false;
    row.medium_to_high_upgrade = false;
    row.output_equivalent = true;
    row.output_equivalent_strict = true;
    row.output_equivalent_relaxed = true;
    row.route_changed_flag = false;
    row.confidence_changed_flag = false;
    row.success_gap_vs_double = 0;
    row.az_est_diff_vs_double = 0;
    row.el_est_diff_vs_double = 0;
    row.output_count_diff_vs_double = 0;
end

function mode_rows = add_quant_mode_comparisons_local(mode_rows)
    ibase = find_quant_row_local(mode_rows, "double_baseline");
    base = mode_rows{ibase};
    base_group = confidence_group_step89c_local(base.confidence_flag, base.route_used, base.in_scope_shared_center_flag);
    base_rank = confidence_rank_step89c_local(base_group);
    for i = 1:numel(mode_rows)
        r = mode_rows{i};
        q_group = confidence_group_step89c_local(r.confidence_flag, r.route_used, r.in_scope_shared_center_flag);
        q_rank = confidence_rank_step89c_local(q_group);
        r.route_changed_flag = r.route_used ~= base.route_used;
        r.confidence_changed_flag = r.confidence_flag ~= base.confidence_flag;
        r.route_agreement_vs_double_flag = ~r.route_changed_flag;
        r.confidence_agreement_vs_double_flag = ~r.confidence_changed_flag;
        r.success_gap_vs_double = double(r.success) - double(base.success);
        r.az_est_diff_vs_double = pair_estimate_diff_local([r.az_est1, r.az_est2], [base.az_est1, base.az_est2]);
        r.el_est_diff_vs_double = pair_estimate_diff_local([r.el_est1, r.el_est2], [base.el_est1, base.el_est2]);
        r.output_count_diff_vs_double = r.output_count - base.output_count;
        r.double_confidence_group = base_group;
        r.quant_confidence_group = q_group;
        r.medium_or_above_double_flag = any(base_group == ["medium", "high"]);
        r.dangerous_confidence_upgrade = any(base_group == ["low", "boundary"]) && r.confidence_flag == "high";
        r.medium_to_high_upgrade = base_group == "medium" && r.confidence_flag == "high";

        az_eff = abs(r.az_est_diff_vs_double);
        el_eff = abs(r.el_est_diff_vs_double);
        no_output_both = r.output_count == 0 && base.output_count == 0;
        if no_output_both && ~isfinite(az_eff)
            az_eff = 0;
        end
        if no_output_both && ~isfinite(el_eff)
            el_eff = 0;
        end
        if ~isfinite(az_eff)
            az_eff = Inf;
        end
        if ~isfinite(el_eff)
            el_eff = Inf;
        end
        same_count = r.output_count_diff_vs_double == 0;
        confidence_downgrade_or_same = q_rank <= base_rank;
        r.output_equivalent = same_count && az_eff <= 0.05 && el_eff <= 0.5 && ...
            ~r.dangerous_confidence_upgrade && ~r.false_high && ~r.boundary_missed;
        r.output_equivalent_strict = same_count && az_eff <= 0.03 && el_eff <= 0.3 && ...
            confidence_downgrade_or_same && ~r.false_high && ~r.boundary_missed;
        r.output_equivalent_relaxed = same_count && az_eff <= 0.10 && el_eff <= 1.0 && ...
            ~r.dangerous_confidence_upgrade && ~r.false_high && ~r.boundary_missed;
        if r.quant_mode == "double_baseline"
            r.output_equivalent = true;
            r.output_equivalent_strict = true;
            r.output_equivalent_relaxed = true;
        end
        mode_rows{i} = r;
    end
end

function group = confidence_group_step89c_local(conf, route, in_scope)
    if ~logical(in_scope)
        group = "out_of_scope";
    elseif route == "boundary_unreliable"
        group = "boundary";
    elseif route == "two_coarse_peaks_out_of_scope"
        group = "out_of_scope";
    elseif conf == ""
        group = "low";
    else
        group = string(conf);
    end
end

function rank = confidence_rank_step89c_local(conf_group)
    switch string(conf_group)
        case "high"
            rank = 3;
        case "medium"
            rank = 2;
        case {"low", "boundary"}
            rank = 1;
        otherwise
            rank = 0;
    end
end

function idx = find_quant_row_local(mode_rows, mode_name)
    idx = 1;
    for i = 1:numel(mode_rows)
        if mode_rows{i}.quant_mode == mode_name
            idx = i;
            return
        end
    end
end

function summary_tbl = build_step89c_summary_table_local(T, steering_error_tbl, storage_tbl, quant_modes)
    scenario_names = unique(T.scenario_name, 'stable');
    groups = ["overall"; "core_in_scope"; "boundary_scenarios"; scenario_names(:)];
    rows = {};
    for ig = 1:numel(groups)
        group = groups(ig);
        if group == "overall"
            smask = true(height(T), 1);
        elseif group == "core_in_scope"
            smask = T.scenario_class == "core_in_scope";
        elseif group == "boundary_scenarios"
            smask = T.scenario_class == "boundary_scenario";
        else
            smask = T.scenario_name == group;
        end
        dmask = smask & T.quant_mode == "double_baseline" & logical(T.in_scope_shared_center_flag);
        double_success = mean_or_nan_local(double(T.success(dmask)));
        for im = 1:numel(quant_modes)
            qname = quant_modes(im).name;
            rows{end+1, 1} = make_step89c_summary_row_local(T, smask & T.quant_mode == qname, ...
                group, qname, double_success, steering_error_tbl, storage_tbl); %#ok<AGROW>
        end
    end
    summary_tbl = struct2table([rows{:}]);
end

function row = make_step89c_summary_row_local(T, mask, scenario_name, mode_name, double_success, steering_error_tbl, storage_tbl)
    in_scope = mask & logical(T.in_scope_shared_center_flag);
    med_scope = in_scope & logical(T.medium_or_above_double_flag);
    core_scope = in_scope & T.scenario_class == "core_in_scope";
    row = struct();
    row.scenario_name = string(scenario_name);
    row.quant_mode = string(mode_name);
    row.trial_count = sum(mask);
    row.in_scope_trial_count = sum(in_scope);
    if any(in_scope)
        row.success_rate = mean(double(T.success(in_scope)), 'omitnan');
        row.success_gap_vs_double = row.success_rate - double_success;
        row.route_agreement_vs_double = mean(double(T.route_agreement_vs_double_flag(in_scope)), 'omitnan');
        row.confidence_agreement_vs_double = mean(double(T.confidence_agreement_vs_double_flag(in_scope)), 'omitnan');
        row.output_equivalent_rate = mean(double(T.output_equivalent(in_scope)), 'omitnan');
        row.output_equivalent_strict_rate = mean(double(T.output_equivalent_strict(in_scope)), 'omitnan');
        row.output_equivalent_relaxed_rate = mean(double(T.output_equivalent_relaxed(in_scope)), 'omitnan');
        row.false_high_rate = mean(double(T.false_high(in_scope)), 'omitnan');
        row.boundary_missed_rate = mean(double(T.boundary_missed(in_scope)), 'omitnan');
        row.low_confidence_rate = mean(double(T.low_confidence(in_scope)), 'omitnan');
        row.boundary_unreliable_rate = mean(double(T.boundary_unreliable(in_scope)), 'omitnan');
        row.max_abs_az_diff_vs_double = max_or_nan_local(abs(T.az_est_diff_vs_double(in_scope)));
        row.p95_abs_az_diff_vs_double = percentile_no_toolbox_local(abs(T.az_est_diff_vs_double(in_scope)), 95);
        row.mean_abs_az_diff_vs_double = mean(abs(T.az_est_diff_vs_double(in_scope)), 'omitnan');
        row.max_abs_el_diff_vs_double = max_or_nan_local(abs(T.el_est_diff_vs_double(in_scope)));
        row.p95_abs_el_diff_vs_double = percentile_no_toolbox_local(abs(T.el_est_diff_vs_double(in_scope)), 95);
        row.mean_abs_el_diff_vs_double = mean(abs(T.el_est_diff_vs_double(in_scope)), 'omitnan');
        row.ywork_quant_snr_db = mean(T.ywork_snr_quant_db(in_scope), 'omitnan');
        row.max_ywork_clip_rate = max_or_nan_local(max(T.ywork_clip_rate_real(in_scope), T.ywork_clip_rate_imag(in_scope)));
        row.coeff_max_rel_err_aligned = max_or_nan_local(T.max_steering_rel_err_aligned(in_scope));
        row.coeff_min_coherence = min_or_nan_local(T.min_steering_coherence(in_scope));
        row.runtime_mean = mean(T.runtime_sec(in_scope), 'omitnan');
        row.route_distribution = distribution_string_local(T.route_used(in_scope));
    else
        row.success_rate = NaN;
        row.success_gap_vs_double = NaN;
        row.route_agreement_vs_double = NaN;
        row.confidence_agreement_vs_double = NaN;
        row.output_equivalent_rate = NaN;
        row.output_equivalent_strict_rate = NaN;
        row.output_equivalent_relaxed_rate = NaN;
        row.false_high_rate = NaN;
        row.boundary_missed_rate = NaN;
        row.low_confidence_rate = NaN;
        row.boundary_unreliable_rate = NaN;
        row.max_abs_az_diff_vs_double = NaN;
        row.p95_abs_az_diff_vs_double = NaN;
        row.mean_abs_az_diff_vs_double = NaN;
        row.max_abs_el_diff_vs_double = NaN;
        row.p95_abs_el_diff_vs_double = NaN;
        row.mean_abs_el_diff_vs_double = NaN;
        row.ywork_quant_snr_db = NaN;
        row.max_ywork_clip_rate = NaN;
        row.coeff_max_rel_err_aligned = NaN;
        row.coeff_min_coherence = NaN;
        row.runtime_mean = NaN;
        row.route_distribution = "";
    end
    if any(med_scope)
        row.medium_or_above_output_equivalent_rate = mean(double(T.output_equivalent(med_scope)), 'omitnan');
    else
        row.medium_or_above_output_equivalent_rate = NaN;
    end
    if any(core_scope)
        row.core_scenario_output_equivalent_rate = mean(double(T.output_equivalent(core_scope)), 'omitnan');
        row.max_core_abs_az_diff_vs_double = max_or_nan_local(abs(T.az_est_diff_vs_double(core_scope)));
    else
        row.core_scenario_output_equivalent_rate = NaN;
        row.max_core_abs_az_diff_vs_double = NaN;
    end
    low_boundary_scope = in_scope & ~logical(T.medium_or_above_double_flag);
    if any(low_boundary_scope)
        row.low_boundary_output_equivalent_rate = mean(double(T.output_equivalent(low_boundary_scope)), 'omitnan');
    else
        row.low_boundary_output_equivalent_rate = NaN;
    end
    dmask = steering_error_tbl.quant_mode == string(mode_name);
    if any(dmask)
        row.coeff_max_rel_err_from_templates = max_or_nan_local(steering_error_tbl.rel_err_aligned(dmask));
        row.coeff_min_coherence_from_templates = min_or_nan_local(steering_error_tbl.coherence(dmask));
    else
        row.coeff_max_rel_err_from_templates = row.coeff_max_rel_err_aligned;
        row.coeff_min_coherence_from_templates = row.coeff_min_coherence;
    end
    smask = storage_tbl.quant_mode == string(mode_name);
    if any(smask)
        row.storage_MB_total_est = storage_tbl.total_storage_MB(find(smask, 1));
        row.storage_BRAM36_equivalent = storage_tbl.BRAM36_equivalent(find(smask, 1));
    else
        row.storage_MB_total_est = NaN;
        row.storage_BRAM36_equivalent = NaN;
    end
end

function route_tbl = build_step89c_route_summary_local(T, quant_modes)
    routes = unique(T.route_used(T.quant_mode == "double_baseline" & logical(T.in_scope_shared_center_flag)), 'stable');
    rows = {};
    base = T(T.quant_mode == "double_baseline", :);
    for ir = 1:numel(routes)
        r0 = routes(ir);
        base_route_mask = base.route_used == r0 & logical(base.in_scope_shared_center_flag);
        idx_trials = find(base_route_mask);
        for im = 1:numel(quant_modes)
            qname = quant_modes(im).name;
            qrows = T(T.quant_mode == qname, :);
            mask = false(height(qrows), 1);
            if ~isempty(idx_trials)
                mask(idx_trials) = true;
            end
            rows{end+1, 1} = make_step89c_group_row_local(qrows, mask, "double_route", r0, qname); %#ok<AGROW>
        end
    end
    if isempty(rows)
        route_tbl = table();
    else
        route_tbl = struct2table([rows{:}]);
    end
end

function conf_tbl = build_step89c_confidence_summary_local(T, quant_modes)
    confs = unique(T.double_confidence_group(T.quant_mode == "double_baseline" & logical(T.in_scope_shared_center_flag)), 'stable');
    rows = {};
    base = T(T.quant_mode == "double_baseline", :);
    for ic = 1:numel(confs)
        c0 = confs(ic);
        idx_trials = find(base.double_confidence_group == c0 & logical(base.in_scope_shared_center_flag));
        for im = 1:numel(quant_modes)
            qname = quant_modes(im).name;
            qrows = T(T.quant_mode == qname, :);
            mask = false(height(qrows), 1);
            if ~isempty(idx_trials)
                mask(idx_trials) = true;
            end
            row = make_step89c_group_row_local(qrows, mask, "double_confidence_group", c0, qname);
            row.dangerous_confidence_upgrade_rate = mean_or_nan_local(double(qrows.dangerous_confidence_upgrade(mask)));
            rows{end+1, 1} = row; %#ok<AGROW>
        end
    end
    if isempty(rows)
        conf_tbl = table();
    else
        conf_tbl = struct2table([rows{:}]);
    end
end

function row = make_step89c_group_row_local(T, mask, group_field, group_value, mode_name)
    row = struct();
    row.group_field = string(group_field);
    row.group_value = string(group_value);
    row.quant_mode = string(mode_name);
    row.trial_count = sum(mask);
    if any(mask)
        row.route_agreement_vs_double = mean(double(T.route_agreement_vs_double_flag(mask)), 'omitnan');
        row.confidence_agreement_vs_double = mean(double(T.confidence_agreement_vs_double_flag(mask)), 'omitnan');
        row.output_equivalent_rate = mean(double(T.output_equivalent(mask)), 'omitnan');
        row.output_equivalent_strict_rate = mean(double(T.output_equivalent_strict(mask)), 'omitnan');
        row.success_rate = mean(double(T.success(mask)), 'omitnan');
        row.false_high_rate = mean(double(T.false_high(mask)), 'omitnan');
        row.boundary_missed_rate = mean(double(T.boundary_missed(mask)), 'omitnan');
        row.max_abs_az_diff_vs_double = max_or_nan_local(abs(T.az_est_diff_vs_double(mask)));
        row.mean_abs_az_diff_vs_double = mean(abs(T.az_est_diff_vs_double(mask)), 'omitnan');
        row.dominant_quant_route = dominant_string_local(T.route_used(mask));
    else
        row.route_agreement_vs_double = NaN;
        row.confidence_agreement_vs_double = NaN;
        row.output_equivalent_rate = NaN;
        row.output_equivalent_strict_rate = NaN;
        row.success_rate = NaN;
        row.false_high_rate = NaN;
        row.boundary_missed_rate = NaN;
        row.max_abs_az_diff_vs_double = NaN;
        row.mean_abs_az_diff_vs_double = NaN;
        row.dominant_quant_route = "";
    end
end

function storage_tbl = build_step89c_storage_estimate_local(cfg88, quant_modes)
    delta_grid = -cfg88.template_R_deg:cfg88.azGridStep_deg:cfg88.template_R_deg;
    n_delta = numel(delta_grid);
    n_el = numel(cfg88.elGrid_deg);
    n_el_bank = numel(cfg88.elBank_deg);
    n_el_refocus = numel(cfg88.elRefocusGrid_deg);
    n_level2_music = cfg88.K_phi_level2 * n_delta;
    n_level2_rank1 = cfg88.K_phi_level2 * n_delta * n_el_bank;
    n_refocus = cfg88.Nel * n_el_refocus + cfg88.K_phi_level2 * n_delta * n_el_refocus;
    n_2d = cfg88.K_phi_music * cfg88.K_z_music * n_delta * n_el;
    n_pair = cfg88.K_phi_covfit * cfg88.K_z_covfit * n_delta * n_el;
    n_full_optional = cfg88.workColumns * cfg88.Nel * n_delta * n_el;
    rows = {};
    for im = 1:numel(quant_modes)
        q = quant_modes(im);
        b_level2_music = coeff_bits_for_category_local(q, "level2_music");
        b_rank1 = coeff_bits_for_category_local(q, "rank1");
        b_refocus = coeff_bits_for_category_local(q, "refocus");
        b_2d = coeff_bits_for_category_local(q, "two_d");
        b_pair = coeff_bits_for_category_local(q, "pair_local");
        bits_level2_music = n_level2_music * bits_per_complex_local(b_level2_music, q.coeff_kind);
        bits_rank1 = n_level2_rank1 * bits_per_complex_local(b_rank1, q.coeff_kind);
        bits_refocus = n_refocus * bits_per_complex_local(b_refocus, q.coeff_kind);
        bits_2d = n_2d * bits_per_complex_local(b_2d, q.coeff_kind);
        bits_pair = n_pair * bits_per_complex_local(b_pair, q.coeff_kind);
        bits_full_optional = n_full_optional * bits_per_complex_local(coeff_bits_for_category_local(q, "common"), q.coeff_kind);
        total_bits = bits_level2_music + bits_rank1 + bits_refocus + bits_2d + bits_pair;
        rows{end+1, 1} = struct('quant_mode', q.name, ...
            'Y_work_word_length', word_length_label_local(q.y_kind, q.y_bits), ...
            'coeff_level2_music_bits', bits_per_complex_local(b_level2_music, q.coeff_kind), ...
            'coeff_level2_rank1_bits', bits_per_complex_local(b_rank1, q.coeff_kind), ...
            'coeff_refocus_bits', bits_per_complex_local(b_refocus, q.coeff_kind), ...
            'coeff_2d_music_bits', bits_per_complex_local(b_2d, q.coeff_kind), ...
            'coeff_pair_local_bits', bits_per_complex_local(b_pair, q.coeff_kind), ...
            'level2_music_storage_MB', bits_level2_music / 8 / 1024 / 1024, ...
            'level2_rank1_storage_MB', bits_rank1 / 8 / 1024 / 1024, ...
            'refocus_storage_MB', bits_refocus / 8 / 1024 / 1024, ...
            'music2d_storage_MB', bits_2d / 8 / 1024 / 1024, ...
            'pair_local_storage_MB', bits_pair / 8 / 1024 / 1024, ...
            'optional_full_template_MB', bits_full_optional / 8 / 1024 / 1024, ...
            'total_storage_bits', total_bits, ...
            'total_storage_MB', total_bits / 8 / 1024 / 1024, ...
            'BRAM36_equivalent', ceil(total_bits / (36 * 1024)), ...
            'relative_storage_vs_combined_int16', NaN, ...
            'relative_storage_vs_combined_int24', NaN, ...
            'comment', q.note); %#ok<AGROW>
    end
    storage_tbl = struct2table([rows{:}]);
    int16_bits = (n_level2_music + n_level2_rank1 + n_refocus + n_2d + n_pair) * 32;
    int24_bits = (n_level2_music + n_level2_rank1 + n_refocus + n_2d + n_pair) * 48;
    storage_tbl.relative_storage_vs_combined_int16 = storage_tbl.total_storage_bits / int16_bits;
    storage_tbl.relative_storage_vs_combined_int24 = storage_tbl.total_storage_bits / int24_bits;
end

function bits = coeff_bits_for_category_local(q, category)
    switch string(category)
        case "level2_music"
            bits = q.level2_music_coeff_bits;
        case "rank1"
            bits = q.rank1_coeff_bits;
        case "two_d"
            bits = q.two_d_coeff_bits;
        case "refocus"
            bits = q.refocus_coeff_bits;
        case "pair_local"
            bits = q.pair_local_coeff_bits;
        otherwise
            bits = q.common_coeff_bits;
    end
    if ~isfinite(bits)
        bits = q.default_coeff_bits;
    end
    if ~isfinite(bits)
        if q.coeff_kind == "float32"
            bits = 32;
        else
            bits = 64;
        end
    end
end

function bpc = bits_per_complex_local(bits, coeff_kind)
    if string(coeff_kind) == "double"
        bpc = 128;
    elseif string(coeff_kind) == "float32"
        bpc = 64;
    else
        bpc = 2 * bits;
    end
end

function label = word_length_label_local(kind, bits)
    if string(kind) == "fixed"
        label = sprintf('int%d_complex_block_float', bits);
    elseif string(kind) == "float32"
        label = "float32_complex";
    else
        label = "double_complex";
    end
end

function W = build_step89c_worst_cases_local(T, topN)
    modes = unique(T.quant_mode(T.quant_mode ~= "double_baseline"), 'stable');
    rows = {};
    trial_id = trial_id_from_table_order_local(T);
    for im = 1:numel(modes)
        mask = T.quant_mode == modes(im) & logical(T.in_scope_shared_center_flag);
        idx = find(mask);
        [~, ord] = sort(abs(T.az_est_diff_vs_double(idx)), 'descend', 'MissingPlacement', 'last');
        idx = idx(ord(1:min(topN, numel(ord))));
        for k = 1:numel(idx)
            ii = idx(k);
            rows{end+1, 1} = struct( ...
                'trial_id', trial_id(ii), 'scenario_name', T.scenario_name(ii), ...
                'SNR', T.snr_db(ii), 'mc', T.mc(ii), 'quant_mode', T.quant_mode(ii), ...
                'double_route', route_from_base_local(T, trial_id(ii)), ...
                'quant_route', T.route_used(ii), ...
                'double_confidence', confidence_from_base_local(T, trial_id(ii)), ...
                'quant_confidence', T.confidence_flag(ii), ...
                'double_success', success_from_base_local(T, trial_id(ii)), ...
                'quant_success', T.success(ii), ...
                'double_az_est', az_from_base_local(T, trial_id(ii)), ...
                'quant_az_est', T.az_est(ii), ...
                'az_diff', abs(T.az_est_diff_vs_double(ii)), ...
                'double_el_est', el_from_base_local(T, trial_id(ii)), ...
                'quant_el_est', T.el_est(ii), ...
                'el_diff', abs(T.el_est_diff_vs_double(ii)), ...
                'true_az1', T.true_az1(ii), 'true_az2', T.true_az2(ii), ...
                'true_el1', T.true_el1(ii), 'true_el2', T.true_el2(ii), ...
                'frontend_state', T.frontend_state(ii), 'coarse_peak_count', T.coarse_peak_count(ii), ...
                'in_scope_shared_center_flag', T.in_scope_shared_center_flag(ii), ...
                'low_confidence_double', low_from_base_local(T, trial_id(ii)), ...
                'boundary_double', boundary_from_base_local(T, trial_id(ii)), ...
                'ywork_snr_quant_db', T.ywork_snr_quant_db(ii), ...
                'steering_rel_err_aligned', T.max_steering_rel_err_aligned(ii), ...
                'score_margin_if_available', NaN, 'peak_margin_if_available', NaN, ...
                'failure_hypothesis', failure_hypothesis_step89c_local(T, ii)); %#ok<AGROW>
        end
    end
    if isempty(rows)
        W = table();
    else
        W = struct2table([rows{:}]);
    end
end

function id = trial_id_from_table_order_local(T)
    modes = unique(T.quant_mode, 'stable');
    id = ceil((1:height(T)).' / numel(modes));
end

function idx = base_index_from_trial_local(T, tid)
    id = trial_id_from_table_order_local(T);
    idx = find(id == tid & T.quant_mode == "double_baseline", 1);
end

function v = route_from_base_local(T, tid)
    v = T.route_used(base_index_from_trial_local(T, tid));
end

function v = confidence_from_base_local(T, tid)
    v = T.confidence_flag(base_index_from_trial_local(T, tid));
end

function v = success_from_base_local(T, tid)
    v = T.success(base_index_from_trial_local(T, tid));
end

function v = az_from_base_local(T, tid)
    v = T.az_est(base_index_from_trial_local(T, tid));
end

function v = el_from_base_local(T, tid)
    v = T.el_est(base_index_from_trial_local(T, tid));
end

function v = low_from_base_local(T, tid)
    v = T.low_confidence(base_index_from_trial_local(T, tid));
end

function v = boundary_from_base_local(T, tid)
    v = T.boundary_unreliable(base_index_from_trial_local(T, tid));
end

function h = failure_hypothesis_step89c_local(T, idx)
    if T.weak_target_truth_flag(idx)
        h = "weak_target_case";
    elseif T.anti_phase_truth_flag(idx)
        h = "near_antiphase_case";
    elseif T.boundary_unreliable(idx) || T.double_confidence_group(idx) == "boundary"
        h = "boundary_route_flip";
    elseif T.route_changed_flag(idx) && abs(T.az_est_diff_vs_double(idx)) <= 0.05
        h = "route_label_changed_output_equivalent";
    elseif T.route_changed_flag(idx)
        h = "candidate_tie_or_route_threshold_flip";
    elseif T.max_steering_rel_err_aligned(idx) > 1e-4
        h = "coeff_sensitive";
    else
        h = "unknown";
    end
end

function R = build_step89c_recommendations_local(S, storage_tbl)
    O = S(S.scenario_name == "overall", :);
    modes = O.quant_mode(O.quant_mode ~= "double_baseline");
    rows = {};
    pass_flags = false(numel(modes), 1);
    for i = 1:numel(modes)
        sm = O(O.quant_mode == modes(i), :);
        candidate_mode = is_fpga_candidate_mode_local(modes(i));
        pass_flags(i) = candidate_mode && mixed_mode_pass_local(sm);
        evidence = sprintf('output_equiv=%.3f, core=%.3f, med+=%.3f, false_high=%.3g, boundary_missed=%.3g, p95_az=%.4f, max_core_az=%.4f', ...
            sm.output_equivalent_rate, sm.core_scenario_output_equivalent_rate, ...
            sm.medium_or_above_output_equivalent_rate, sm.false_high_rate, sm.boundary_missed_rate, ...
            sm.p95_abs_az_diff_vs_double, sm.max_core_abs_az_diff_vs_double);
        storage = storage_value_local(storage_tbl, modes(i), "total_storage_MB");
        if ~candidate_mode
            action = "diagnostic_reference_not_fpga_candidate";
            nextv = "use only as upper-bound reference";
            risk = "not_fixed_point_candidate";
        elseif pass_flags(i)
            action = "candidate_for_fpga_numerical_format";
            nextv = "run MC=100 confirmation before FPGA kernel design";
            risk = "low_to_medium";
        elseif sm.core_scenario_output_equivalent_rate >= 0.99 && sm.false_high_rate == 0 && sm.boundary_missed_rate == 0
            action = "core_pass_boundary_needs_confidence_calibration";
            nextv = "margin-aware confidence and failure_reason calibration";
            risk = "boundary_label_sensitivity";
        else
            action = "mixed_precision_not_closed";
            nextv = "add margin/tie guards or higher precision route-specific coefficients";
            risk = "route_or_output_sensitivity";
        end
        rows{end+1, 1} = rec_step89c_row_local(modes(i), double(pass_flags(i)), evidence, ...
            sprintf('%.6f MB', storage), risk, action, nextv); %#ok<AGROW>
    end
    [best_mode, best_storage_mode, best_core_mode] = best_modes_step89c_local(O, storage_tbl);
    blocker = "none";
    if ~any(pass_flags)
        blocker = "mixed_precision_not_closed";
    end
    rows{end+1, 1} = rec_step89c_row_local("best_overall_mode", double(any(pass_flags)), sprintf('best output-equivalent mode=%s', best_mode), "", "", best_mode, "use this as primary candidate if pass_flag=1"); %#ok<AGROW>
    rows{end+1, 1} = rec_step89c_row_local("best_storage_efficient_mode", double(any(pass_flags)), sprintf('storage-efficient candidate=%s', best_storage_mode), "", "", best_storage_mode, "prefer if metrics are close to best overall"); %#ok<AGROW>
    rows{end+1, 1} = rec_step89c_row_local("best_core_scenario_mode", double(any(pass_flags)), sprintf('best core-scenario candidate=%s', best_core_mode), "", "", best_core_mode, "use for core-only follow-up if all-scope remains sensitive"); %#ok<AGROW>
    rows{end+1, 1} = rec_step89c_row_local("blocker_if_any", double(~any(pass_flags)), blocker, "", blocker, "block_fpga_kernel_design_if_not_none", "close blocker before FPGA kernel design"); %#ok<AGROW>
    rows{end+1, 1} = rec_step89c_row_local("whether_margin_guard_needed", 1, "candidate tie / flat objective risk remains a diagnostic target.", "", "candidate_tie_margin_risk", "add_margin_aware_confidence", "validate margin guard if mixed precision does not fully close"); %#ok<AGROW>
    rows{end+1, 1} = rec_step89c_row_local("whether_confidence_calibration_needed", 1, "low/boundary confidence bins are tracked separately after Step 8.9B.", "", "boundary_confidence_risk", "confidence_failure_reason_calibration", "validate after numerical format selection"); %#ok<AGROW>
    rows{end+1, 1} = rec_step89c_row_local("proceed_to_fpga_kernel_design_flag", double(any(pass_flags)), sprintf('mixed_precision_pass_flag=%d', any(pass_flags)), "", "", string(double(any(pass_flags))), "only after this validation and later MC=100 confirmation"); %#ok<AGROW>
    rows{end+1, 1} = rec_step89c_row_local("proceed_to_mc100_flag", double(any(pass_flags)), sprintf('mixed_precision_pass_flag=%d', any(pass_flags)), "", "", string(double(any(pass_flags))), "MC=100 is next only if a mode passes"); %#ok<AGROW>
    R = struct2table([rows{:}]);
end

function row = rec_step89c_row_local(candidate_mode, pass_flag, evidence, storage_cost, risk, action, next_validation)
    row = struct('candidate_mode', string(candidate_mode), 'pass_flag', pass_flag, ...
        'evidence', string(evidence), 'storage_cost', string(storage_cost), ...
        'risk', string(risk), 'recommended_action', string(action), ...
        'next_validation', string(next_validation));
end

function tf = mixed_mode_pass_local(row)
    tf = row.output_equivalent_rate >= 0.98 && ...
        row.core_scenario_output_equivalent_rate >= 0.99 && ...
        row.medium_or_above_output_equivalent_rate >= 0.98 && ...
        row.false_high_rate == 0 && row.boundary_missed_rate == 0 && ...
        row.p95_abs_az_diff_vs_double <= 0.05 && ...
        row.max_core_abs_az_diff_vs_double <= 0.1;
end

function tf = is_fpga_candidate_mode_local(mode_name)
    mode_name = string(mode_name);
    tf = ~any(mode_name == ["double_baseline", "float32_all", "y16_coeff32float", "y32float_coeff24"]);
end

function [best_mode, best_storage_mode, best_core_mode] = best_modes_step89c_local(O, storage_tbl)
    C = O(O.quant_mode ~= "double_baseline" & arrayfun(@is_fpga_candidate_mode_local, O.quant_mode), :);
    if isempty(C)
        C = O(O.quant_mode ~= "double_baseline", :);
    end
    score = C.output_equivalent_rate - 0.2 * max(C.p95_abs_az_diff_vs_double, 0) - 0.05 * C.false_high_rate - 0.05 * C.boundary_missed_rate;
    [~, ib] = max(score);
    best_mode = C.quant_mode(ib);
    core_score = C.core_scenario_output_equivalent_rate - 0.2 * max(C.max_core_abs_az_diff_vs_double, 0);
    [~, ic] = max(core_score);
    best_core_mode = C.quant_mode(ic);
    pass_like = C.output_equivalent_rate >= max(C.output_equivalent_rate) - 0.01 & ...
        C.core_scenario_output_equivalent_rate >= max(C.core_scenario_output_equivalent_rate) - 0.01;
    candidates = C(pass_like, :);
    if isempty(candidates)
        candidates = C;
    end
    storage = NaN(height(candidates), 1);
    for i = 1:height(candidates)
        storage(i) = storage_value_local(storage_tbl, candidates.quant_mode(i), "total_storage_MB");
    end
    [~, is] = min(storage);
    best_storage_mode = candidates.quant_mode(is);
end

function K = build_step89c_keypoints_local(T, S, storage_tbl, recommendations_tbl, Metkl, quick_mode) %#ok<INUSD>
    O = S(S.scenario_name == "overall", :);
    total_modes = numel(unique(T.quant_mode, 'stable'));
    [best_mode, best_storage_mode, ~] = best_modes_step89c_local(O, storage_tbl);
    best = O(O.quant_mode == best_mode, :);
    y24 = O(O.quant_mode == "y16_coeff24_all", :);
    y_rank2d = O(O.quant_mode == "y16_rank1_2d_coeff24_rest16", :);
    pass = is_fpga_candidate_mode_local(best_mode) && mixed_mode_pass_local(best);
    blocker = "none";
    if ~pass
        blocker = "mixed_precision_not_closed";
    end
    rows = {};
    rows = add_kp_local(rows, 'Metkl', Metkl, 'Monte Carlo trials per scenario-SNR case');
    rows = add_kp_local(rows, 'quick_mode_flag', double(quick_mode), '1 means quick smoke test only');
    rows = add_kp_local(rows, 'total_base_trials', height(T) / total_modes, 'base trials before mixed-mode expansion');
    rows = add_kp_local(rows, 'total_mode_trials', height(T), 'trial rows after mixed-mode expansion');
    rows = add_kp_local(rows, 'best_mode_by_output_equivalent', NaN, best_mode);
    rows = add_kp_local(rows, 'best_mode_by_storage', NaN, best_storage_mode);
    rows = add_kp_local(rows, 'y16_coeff24_all_output_equivalent', y24.output_equivalent_rate, 'regular output equivalence');
    rows = add_kp_local(rows, 'y16_coeff24_all_core_output_equivalent', y24.core_scenario_output_equivalent_rate, 'core scenario output equivalence');
    rows = add_kp_local(rows, 'y16_coeff24_all_route_agreement', y24.route_agreement_vs_double, 'route agreement vs double');
    rows = add_kp_local(rows, 'y16_coeff24_all_confidence_agreement', y24.confidence_agreement_vs_double, 'confidence agreement vs double');
    rows = add_kp_local(rows, 'y16_coeff24_all_false_high', y24.false_high_rate, 'false-high rate');
    rows = add_kp_local(rows, 'y16_coeff24_all_boundary_missed', y24.boundary_missed_rate, 'boundary-missed rate');
    rows = add_kp_local(rows, 'y16_rank1_2d_coeff24_rest16_output_equivalent', y_rank2d.output_equivalent_rate, 'regular output equivalence');
    rows = add_kp_local(rows, 'y16_rank1_2d_coeff24_rest16_core_output_equivalent', y_rank2d.core_scenario_output_equivalent_rate, 'core scenario output equivalence');
    rows = add_kp_local(rows, 'best_mode_p95_az_diff', best.p95_abs_az_diff_vs_double, 'p95 az diff vs double for best mode');
    rows = add_kp_local(rows, 'best_mode_max_core_az_diff', best.max_core_abs_az_diff_vs_double, 'max core scenario az diff vs double for best mode');
    rows = add_kp_local(rows, 'best_mode_storage_MB', storage_value_local(storage_tbl, best_mode, "total_storage_MB"), 'estimated coefficient/template storage');
    rows = add_kp_local(rows, 'mixed_precision_pass_flag', double(pass), '1 means at least one mixed mode meets Step 8.9C pass criteria');
    rows = add_kp_local(rows, 'recommended_fixed_point_architecture', NaN, architecture_from_mode_local(best_mode, pass));
    rows = add_kp_local(rows, 'proceed_to_fpga_kernel_design_flag', double(pass), '1 means FPGA kernel design can start after this numerical validation');
    rows = add_kp_local(rows, 'proceed_to_mc100_flag', double(pass), '1 means MC=100 confirmation is recommended next');
    rows = add_kp_local(rows, 'next_step_recommendation', NaN, next_step_from_pass_local(pass));
    rows = add_kp_local(rows, 'blocker_if_any', NaN, blocker);
    K = cell2table(rows, 'VariableNames', {'keypoint', 'value', 'note'});
end

function arch = architecture_from_mode_local(mode, pass)
    if ~pass
        arch = "not_recommended_until_mixed_precision_closes";
    elseif mode == "y16_coeff24_all"
        arch = "Y_work_int16_plus_all_coeff_int24";
    elseif mode == "y16_rank1_2d_coeff24_rest16"
        arch = "Y_work_int16_rank1_2D_pair_coeff_int24_other_coeff_int16";
    elseif mode == "y16_rank1_coeff24_rest16"
        arch = "Y_work_int16_rank1_coeff_int24_other_coeff_int16";
    else
        arch = "candidate_architecture_" + mode;
    end
end

function next_step = next_step_from_pass_local(pass)
    if pass
        next_step = "run MC=100 confirmation before FPGA kernel design";
    else
        next_step = "add margin-aware confidence / candidate tie guard or raise route-specific coefficient precision";
    end
end

function val = storage_value_local(storage_tbl, mode_name, field_name)
    mask = storage_tbl.quant_mode == string(mode_name);
    if any(mask)
        val = storage_tbl.(char(field_name))(find(mask, 1));
    else
        val = NaN;
    end
end

function s = dominant_string_local(vals)
    vals = string(vals);
    vals = vals(vals ~= "");
    if isempty(vals)
        s = "";
        return
    end
    u = unique(vals, 'stable');
    counts = zeros(numel(u), 1);
    for i = 1:numel(u)
        counts(i) = sum(vals == u(i));
    end
    [~, idx] = max(counts);
    s = u(idx);
end

function summary_tbl = build_step89_summary_table_local(T, steering_error_tbl, quant_modes)
    scenario_names = unique(T.scenario_name, 'stable');
    scenarios = ["overall"; scenario_names(:)];
    rows = {};
    for is = 1:numel(scenarios)
        if scenarios(is) == "overall"
            smask = true(height(T), 1);
        else
            smask = T.scenario_name == scenarios(is);
        end
        double_mask = smask & T.quant_mode == "double_baseline" & logical(T.in_scope_shared_center_flag);
        double_success = mean_or_nan_local(double(T.success(double_mask)));
        for im = 1:numel(quant_modes)
            qname = quant_modes(im).name;
            rows{end+1, 1} = make_step89_summary_row_local(T, smask & T.quant_mode == qname, ...
                scenarios(is), qname, double_success, steering_error_tbl); %#ok<AGROW>
        end
    end
    summary_tbl = struct2table([rows{:}]);
end

function row = make_step89_summary_row_local(T, mask, scenario_name, mode_name, double_success, steering_error_tbl)
    in_scope = mask & logical(T.in_scope_shared_center_flag);
    row = struct();
    row.scenario_name = string(scenario_name);
    row.quant_mode = string(mode_name);
    row.trial_count = sum(mask);
    row.in_scope_trial_count = sum(in_scope);
    if any(in_scope)
        row.success_rate = mean(double(T.success(in_scope)), 'omitnan');
        row.success_gap_vs_double = row.success_rate - double_success;
        row.route_agreement_vs_double = 1 - mean(double(T.route_changed_flag(in_scope)), 'omitnan');
        row.confidence_agreement_vs_double = 1 - mean(double(T.confidence_changed_flag(in_scope)), 'omitnan');
        row.false_high_rate = mean(double(T.false_high(in_scope)), 'omitnan');
        row.boundary_missed_rate = mean(double(T.boundary_missed(in_scope)), 'omitnan');
        row.low_confidence_rate = mean(double(T.low_confidence(in_scope)), 'omitnan');
        row.boundary_unreliable_rate = mean(double(T.boundary_unreliable(in_scope)), 'omitnan');
        row.mean_abs_az_diff_vs_double = mean(abs(T.az_est_diff_vs_double(in_scope)), 'omitnan');
        row.max_abs_az_diff_vs_double = max_or_nan_local(abs(T.az_est_diff_vs_double(in_scope)));
        row.mean_abs_el_diff_vs_double = mean(abs(T.el_est_diff_vs_double(in_scope)), 'omitnan');
        row.max_abs_el_diff_vs_double = max_or_nan_local(abs(T.el_est_diff_vs_double(in_scope)));
        row.mean_ywork_snr_quant_db = mean(T.ywork_snr_quant_db(in_scope), 'omitnan');
        row.max_ywork_clip_rate = max_or_nan_local(max(T.ywork_clip_rate_real(in_scope), T.ywork_clip_rate_imag(in_scope)));
        row.mean_steering_rel_err_aligned = mean(T.mean_steering_rel_err_aligned(in_scope), 'omitnan');
        row.max_steering_rel_err_aligned = max_or_nan_local(T.max_steering_rel_err_aligned(in_scope));
        row.min_steering_coherence = min_or_nan_local(T.min_steering_coherence(in_scope));
        row.mean_runtime = mean(T.runtime_sec(in_scope), 'omitnan');
        row.p90_runtime = percentile_no_toolbox_local(T.runtime_sec(in_scope), 90);
        row.route_distribution = distribution_string_local(T.route_used(in_scope));
    else
        row.success_rate = NaN;
        row.success_gap_vs_double = NaN;
        row.route_agreement_vs_double = NaN;
        row.confidence_agreement_vs_double = NaN;
        row.false_high_rate = NaN;
        row.boundary_missed_rate = NaN;
        row.low_confidence_rate = NaN;
        row.boundary_unreliable_rate = NaN;
        row.mean_abs_az_diff_vs_double = NaN;
        row.max_abs_az_diff_vs_double = NaN;
        row.mean_abs_el_diff_vs_double = NaN;
        row.max_abs_el_diff_vs_double = NaN;
        row.mean_ywork_snr_quant_db = NaN;
        row.max_ywork_clip_rate = NaN;
        row.mean_steering_rel_err_aligned = NaN;
        row.max_steering_rel_err_aligned = NaN;
        row.min_steering_coherence = NaN;
        row.mean_runtime = NaN;
        row.p90_runtime = NaN;
        row.route_distribution = "";
    end
    dmask = steering_error_tbl.quant_mode == string(mode_name);
    if any(dmask)
        row.max_steering_rel_err_from_templates = max_or_nan_local(steering_error_tbl.rel_err_aligned(dmask));
        row.min_steering_coherence_from_templates = min_or_nan_local(steering_error_tbl.coherence(dmask));
    else
        row.max_steering_rel_err_from_templates = row.max_steering_rel_err_aligned;
        row.min_steering_coherence_from_templates = row.min_steering_coherence;
    end
end

function storage_tbl = build_step89_storage_estimate_local(cfg88)
    delta_grid = -cfg88.template_R_deg:cfg88.azGridStep_deg:cfg88.template_R_deg;
    n_delta = numel(delta_grid);
    n_el = numel(cfg88.elGrid_deg);
    rows = {};
    rows{end+1, 1} = make_storage_object_local("2d_music_center_subarray_template", cfg88.K_phi_music * cfg88.K_z_music * n_delta * n_el, ...
        "K_phi_music*K_z_music*Delta*el_grid");
    rows{end+1, 1} = make_storage_object_local("level2_combined_steering_template", cfg88.K_phi_level2 * n_delta * numel(cfg88.elBank_deg), ...
        "K_phi_level2*Delta*el_bank");
    rows{end+1, 1} = make_storage_object_local("refocus_elevation_weight_table", cfg88.Nel * numel(cfg88.elRefocusGrid_deg), ...
        "Nel*elRefocusGrid");
    rows{end+1, 1} = make_storage_object_local("optional_full_65x32_template", cfg88.workColumns * cfg88.Nel * n_delta * n_el, ...
        "65*32*Delta*el_grid");
    objects = [rows{:}];
    fmts = [make_storage_format_local("float32_complex", 64), make_storage_format_local("int16_complex", 32), ...
        make_storage_format_local("int18_complex", 36), make_storage_format_local("int24_complex", 48)];
    out = {};
    for io = 1:numel(objects)
        for ifmt = 1:numel(fmts)
            bits = objects(io).num_complex * fmts(ifmt).bits_per_complex;
            out{end+1, 1} = struct('object_name', objects(io).object_name, ...
                'format', fmts(ifmt).format, 'num_complex', objects(io).num_complex, ...
                'bits_per_complex', fmts(ifmt).bits_per_complex, 'total_bits', bits, ...
                'total_MB', bits / 8 / 1024 / 1024, ...
                'BRAM36_equivalent', ceil(bits / (36 * 1024)), 'comment', objects(io).comment); %#ok<AGROW>
        end
    end
    storage_tbl = struct2table([out{:}]);
end

function obj = make_storage_object_local(name, num_complex, comment)
    obj = struct('object_name', string(name), 'num_complex', double(num_complex), 'comment', string(comment));
end

function fmt = make_storage_format_local(name, bits_per_complex)
    fmt = struct('format', string(name), 'bits_per_complex', double(bits_per_complex));
end

function keypoints_tbl = build_step89_keypoints_local(T, S, Metkl, quick_mode)
    O = S(S.scenario_name == "overall", :);
    d = O(O.quant_mode == "double_baseline", :);
    f32 = O(O.quant_mode == "float32_all", :);
    c16 = O(O.quant_mode == "coeff_int16_only", :);
    y16 = O(O.quant_mode == "ywork_int16_only", :);
    i16 = O(O.quant_mode == "combined_int16", :);
    i18 = O(O.quant_mode == "combined_int18", :);
    i24 = O(O.quant_mode == "combined_int24", :);
    pass16 = fixed_mode_pass_local(i16);
    pass18 = fixed_mode_pass_local(i18);
    pass24 = fixed_mode_pass_local(i24);
    if pass16
        rec = "int16_complex";
        pass = 1;
        blocker = "";
    elseif pass18
        rec = "int18_complex";
        pass = 1;
        blocker = "";
    elseif pass24
        rec = "int24_complex_or_mixed_precision";
        pass = 1;
        blocker = "caution_int16_int18_not_closed";
    else
        rec = "not_recommended";
        pass = 0;
        blocker = "quantization_not_closed";
    end
    rows = {};
    rows = add_kp_local(rows, 'Metkl', Metkl, 'Monte Carlo trials per scenario-SNR case');
    rows = add_kp_local(rows, 'quick_mode_flag', double(quick_mode), '1 means quick smoke test only');
    rows = add_kp_local(rows, 'total_base_trials', height(T) / numel(unique(T.quant_mode, 'stable')), 'base trials before quant-mode expansion');
    rows = add_kp_local(rows, 'total_mode_trials', height(T), 'trial rows after quant-mode expansion');
    rows = add_kp_local(rows, 'in_scope_trials', d.in_scope_trial_count, 'in-scope base trials used for fixed-point comparison');
    rows = add_kp_local(rows, 'double_success', d.success_rate, 'double baseline success');
    rows = add_kp_local(rows, 'float32_success', f32.success_rate, 'float32_all success');
    rows = add_kp_local(rows, 'coeff_int16_success', c16.success_rate, 'coeff_int16_only success');
    rows = add_kp_local(rows, 'ywork_int16_success', y16.success_rate, 'ywork_int16_only success');
    rows = add_kp_local(rows, 'combined_int16_success', i16.success_rate, 'combined_int16 success');
    rows = add_kp_local(rows, 'combined_int18_success', i18.success_rate, 'combined_int18 success');
    rows = add_kp_local(rows, 'combined_int24_success', i24.success_rate, 'combined_int24 success');
    rows = add_kp_local(rows, 'combined_int16_success_gap', i16.success_gap_vs_double, 'combined_int16 minus double success');
    rows = add_kp_local(rows, 'combined_int18_success_gap', i18.success_gap_vs_double, 'combined_int18 minus double success');
    rows = add_kp_local(rows, 'combined_int24_success_gap', i24.success_gap_vs_double, 'combined_int24 minus double success');
    rows = add_kp_local(rows, 'combined_int16_route_agreement', i16.route_agreement_vs_double, 'route agreement vs double');
    rows = add_kp_local(rows, 'combined_int18_route_agreement', i18.route_agreement_vs_double, 'route agreement vs double');
    rows = add_kp_local(rows, 'combined_int24_route_agreement', i24.route_agreement_vs_double, 'route agreement vs double');
    rows = add_kp_local(rows, 'combined_int16_confidence_agreement', i16.confidence_agreement_vs_double, 'confidence agreement vs double');
    rows = add_kp_local(rows, 'combined_int18_confidence_agreement', i18.confidence_agreement_vs_double, 'confidence agreement vs double');
    rows = add_kp_local(rows, 'combined_int24_confidence_agreement', i24.confidence_agreement_vs_double, 'confidence agreement vs double');
    rows = add_kp_local(rows, 'combined_int16_false_high', i16.false_high_rate, 'false-high rate');
    rows = add_kp_local(rows, 'combined_int18_false_high', i18.false_high_rate, 'false-high rate');
    rows = add_kp_local(rows, 'combined_int24_false_high', i24.false_high_rate, 'false-high rate');
    rows = add_kp_local(rows, 'combined_int16_boundary_missed', i16.boundary_missed_rate, 'boundary-missed rate');
    rows = add_kp_local(rows, 'combined_int18_boundary_missed', i18.boundary_missed_rate, 'boundary-missed rate');
    rows = add_kp_local(rows, 'combined_int24_boundary_missed', i24.boundary_missed_rate, 'boundary-missed rate');
    rows = add_kp_local(rows, 'combined_int16_max_az_diff', i16.max_abs_az_diff_vs_double, 'max az diff vs double');
    rows = add_kp_local(rows, 'combined_int18_max_az_diff', i18.max_abs_az_diff_vs_double, 'max az diff vs double');
    rows = add_kp_local(rows, 'combined_int24_max_az_diff', i24.max_abs_az_diff_vs_double, 'max az diff vs double');
    rows = add_kp_local(rows, 'combined_int16_max_el_diff', i16.max_abs_el_diff_vs_double, 'max el diff vs double');
    rows = add_kp_local(rows, 'combined_int18_max_el_diff', i18.max_abs_el_diff_vs_double, 'max el diff vs double');
    rows = add_kp_local(rows, 'combined_int24_max_el_diff', i24.max_abs_el_diff_vs_double, 'max el diff vs double');
    rows = add_kp_local(rows, 'recommended_fixed_point_format', NaN, rec);
    rows = add_kp_local(rows, 'fixed_point_pass_flag', pass, '1 means a candidate finite-wordlength format passed this influence validation');
    rows = add_kp_local(rows, 'fixed_point_blocker_if_any', NaN, blocker);
    rows = add_kp_local(rows, 'proceed_to_fpga_kernel_design_flag', double(pass), '1 means proceed to FPGA kernel design preparation');
    rows = add_kp_local(rows, 'default_derotation_mode', NaN, 'none, inherited from Step 8.8B');
    keypoints_tbl = cell2table(rows, 'VariableNames', {'keypoint', 'value', 'note'});
end

function tf = fixed_mode_pass_local(row)
    tf = row.success_gap_vs_double >= -0.02 && ...
        row.route_agreement_vs_double >= 0.98 && ...
        row.confidence_agreement_vs_double >= 0.98 && ...
        row.false_high_rate == 0 && ...
        row.boundary_missed_rate == 0 && ...
        row.max_abs_az_diff_vs_double <= 0.03 && ...
        row.max_abs_el_diff_vs_double <= 0.5 && ...
        row.max_ywork_clip_rate <= 1e-6;
end

function plot_step89c_metric_local(S, metric_name, plot_title, path_out)
    O = S(S.scenario_name == "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 520]);
    bar(categorical(cellstr(O.quant_mode)), O.(metric_name));
    grid on
    ylabel(strrep(metric_name, '_', '\_'));
    title(plot_title, 'Interpreter', 'none');
    xtickangle(35);
    saveas(fig, path_out);
    close(fig);
end

function plot_step89c_az_diff_local(S, path_out)
    O = S(S.scenario_name == "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 520]);
    bar(categorical(cellstr(O.quant_mode)), [O.p95_abs_az_diff_vs_double, O.max_abs_az_diff_vs_double]);
    grid on
    ylabel('az diff vs double (deg)');
    legend({'p95', 'max'}, 'Location', 'best');
    title('mixed precision az diff', 'Interpreter', 'none');
    xtickangle(35);
    saveas(fig, path_out);
    close(fig);
end

function plot_step89c_false_boundary_local(S, path_out)
    O = S(S.scenario_name == "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 520]);
    bar(categorical(cellstr(O.quant_mode)), [O.false_high_rate, O.boundary_missed_rate]);
    grid on
    ylabel('rate');
    legend({'false-high', 'boundary-missed'}, 'Location', 'best');
    title('mixed precision safety rates', 'Interpreter', 'none');
    xtickangle(35);
    saveas(fig, path_out);
    close(fig);
end

function plot_step89c_by_scenario_local(S, path_out)
    S2 = S(S.scenario_name ~= "overall" & S.scenario_name ~= "core_in_scope" & S.scenario_name ~= "boundary_scenarios", :);
    modes = unique(S2.quant_mode, 'stable');
    scenarios = unique(S2.scenario_name, 'stable');
    M = NaN(numel(scenarios), numel(modes));
    for is = 1:numel(scenarios)
        for im = 1:numel(modes)
            idx = S2.scenario_name == scenarios(is) & S2.quant_mode == modes(im);
            if any(idx)
                M(is, im) = S2.output_equivalent_rate(find(idx, 1));
            end
        end
    end
    fig = figure('Visible', 'off', 'Position', [100, 100, 1300, 620]);
    imagesc(M, [0, 1]);
    colorbar
    yticks(1:numel(scenarios));
    yticklabels(cellstr(scenarios));
    xticks(1:numel(modes));
    xticklabels(cellstr(modes));
    xtickangle(35);
    title('output equivalent by scenario', 'Interpreter', 'none');
    saveas(fig, path_out);
    close(fig);
end

function plot_step89c_by_route_local(T, path_out)
    mode_names = cellstr(unique(T.quant_mode, 'stable'));
    qstruct = repmat(struct('name', ""), 1, numel(mode_names));
    for i = 1:numel(mode_names)
        qstruct(i).name = string(mode_names{i});
    end
    R = build_step89c_route_summary_local(T, qstruct);
    if isempty(R)
        return
    end
    R = R(R.quant_mode ~= "double_baseline", :);
    modes = unique(R.quant_mode, 'stable');
    routes = unique(R.group_value, 'stable');
    M = NaN(numel(routes), numel(modes));
    for ir = 1:numel(routes)
        for im = 1:numel(modes)
            idx = R.group_value == routes(ir) & R.quant_mode == modes(im);
            if any(idx)
                M(ir, im) = R.output_equivalent_rate(find(idx, 1));
            end
        end
    end
    fig = figure('Visible', 'off', 'Position', [100, 100, 1300, 620]);
    imagesc(M, [0, 1]);
    colorbar
    yticks(1:numel(routes));
    yticklabels(cellstr(routes));
    xticks(1:numel(modes));
    xticklabels(cellstr(modes));
    xtickangle(35);
    title('output equivalent by double route', 'Interpreter', 'none');
    saveas(fig, path_out);
    close(fig);
end

function plot_step89c_storage_local(storage_tbl, path_out)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 520]);
    bar(categorical(cellstr(storage_tbl.quant_mode)), storage_tbl.total_storage_MB);
    grid on
    ylabel('estimated coefficient/template storage (MB)');
    title('mixed precision storage tradeoff', 'Interpreter', 'none');
    xtickangle(35);
    saveas(fig, path_out);
    close(fig);
end

function plot_step89c_recommended_modes_local(R, path_out)
    mode_rows = R(~contains(R.candidate_mode, ["best_", "blocker", "whether_", "proceed_"]), :);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 520]);
    bar(categorical(cellstr(mode_rows.candidate_mode)), mode_rows.pass_flag);
    ylim([0, 1.1]);
    grid on
    ylabel('pass flag');
    title('recommended mixed precision modes', 'Interpreter', 'none');
    xtickangle(35);
    saveas(fig, path_out);
    close(fig);
end

function write_step89c_record_doc_local(path_out, keypoints_tbl, summary_tbl, storage_tbl, ...
        worst_cases_tbl, recommendations_tbl, result_dir, elapsed_sec, Metkl, quick_mode, quant_modes, ...
        reuse_step89_observations_flag, rerun_base_trials_flag, exact_same_trial_replication_flag, replication_note)
    O = summary_tbl(summary_tbl.scenario_name == "overall", :);
    best_mode = string(keypoint_note_from_table_local(keypoints_tbl, 'best_mode_by_output_equivalent'));
    best = O(O.quant_mode == best_mode, :);
    y24 = O(O.quant_mode == "y16_coeff24_all", :);
    yr2d = O(O.quant_mode == "y16_rank1_2d_coeff24_rest16", :);
    fid = fopen(path_out, 'w');
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '# 第8.9C步 shared-center混合精度定点验证记录\n\n');
    fprintf(fid, '## 1. 本轮目的\n\n');
    fprintf(fid, '本轮验证 shared-center 主线在混合精度数值表示下是否能改善第 8.9 / 8.9B 暴露的量化敏感性。验证对象仍限定为 single coarse peak / unresolved local cluster -> shared-center -> 65列工作子阵 -> 第 8.7 lazy cascade。\n\n');
    fprintf(fid, '## 2. 为什么统一定点失败后仍做 mixed precision\n\n');
    fprintf(fid, '第 8.9 的统一 int16/int18/int24 结果保持 success 和安全性，但 route/confidence/output agreement 不足。第 8.9B 进一步定位到主要敏感源为 steering/template/cache 系数量化，Y_work int16 相对更稳。因此本轮测试低位宽 Y_work + 高位宽关键系数、以及 route-specific 高精度系数组合，而不是简单把所有数据统一高位宽。\n\n');
    fprintf(fid, '## 3. 本轮不是完整 FPGA bit-true\n\n');
    fprintf(fid, '本轮是 mixed precision numerical influence validation，不验证硬件流水线、定点 EVD、FFT/CFAR bit-true、BRAM/DDR 调度或 HDL。EVD、矩阵运算和 route 逻辑仍在 MATLAB 中执行，只在进入计算前对 Y_work 和 coefficient/cache 做量化再反量化。\n\n');
    fprintf(fid, '## 4. 当前默认接口\n\n');
    fprintf(fid, '- shared-center 主线；\n');
    fprintf(fid, '- Doppler de-rotation 默认 none；\n');
    fprintf(fid, '- R_runtime_default = 1.5 deg；\n');
    fprintf(fid, '- R_runtime_expand = 2.0 deg；\n');
    fprintf(fid, '- R_template = 2.0 deg；\n');
    fprintf(fid, '- dual-center / two separated coarse peaks / weak-target 求解 / near anti-phase 求解均不纳入默认主线。\n\n');
    fprintf(fid, '## 5. 运行策略\n\n');
    fprintf(fid, '- Metkl = %d；\n', Metkl);
    fprintf(fid, '- quick_mode = %d；\n', quick_mode);
    if quick_mode
        fprintf(fid, '- 本轮为 quick smoke test，不作为正式统计结论；\n');
    end
    fprintf(fid, '- reuse_step89_observations_flag = %d；\n', reuse_step89_observations_flag);
    fprintf(fid, '- rerun_base_trials_flag = %d；\n', rerun_base_trials_flag);
    fprintf(fid, '- exact_same_trial_replication_flag = %d；\n', exact_same_trial_replication_flag);
    fprintf(fid, '- 说明：%s\n\n', replication_note);
    fprintf(fid, 'Step 8.9 未持久化 Y_work/base observations，本轮用同一 base_seed 和同一场景逻辑重放 base trials；结果目录独立，不覆盖第 8.9 / 8.9B 原结果。\n\n');
    fprintf(fid, '## 6. mixed precision modes\n\n');
    for i = 1:numel(quant_modes)
        fprintf(fid, '- `%s`: %s\n', quant_modes(i).name, quant_modes(i).note);
    end
    fprintf(fid, '\n## 7. 量化模型\n\n');
    fprintf(fid, '复数实部/虚部分别使用饱和均匀量化：Q_B(x)=clip(round(x*S),-Imax,Imax)/S，其中 Imax=2^(B-1)-1，S=Imax。Y_work 使用 block floating scale，scale_y=max(abs(real(Y_work(:))), abs(imag(Y_work(:))), eps)，再对 Y_work/scale_y 做同样量化。\n\n');
    fprintf(fid, '## 8. 总体结果\n\n');
    fprintf(fid, '| mode | success | route agree | confidence agree | output equiv | core equiv | med+ equiv | false-high | boundary-missed | p95 az diff | max core az diff | storage MB |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(O)
        fprintf(fid, '| %s | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f |\n', ...
            O.quant_mode(i), O.success_rate(i), O.route_agreement_vs_double(i), ...
            O.confidence_agreement_vs_double(i), O.output_equivalent_rate(i), ...
            O.core_scenario_output_equivalent_rate(i), O.medium_or_above_output_equivalent_rate(i), ...
            O.false_high_rate(i), O.boundary_missed_rate(i), O.p95_abs_az_diff_vs_double(i), ...
            O.max_core_abs_az_diff_vs_double(i), O.storage_MB_total_est(i));
    end
    fprintf(fid, '\n## 9. 关键候选模式\n\n');
    fprintf(fid, '- y16_coeff24_all: output_equivalent=%.6f, core=%.6f, route_agreement=%.6f, confidence_agreement=%.6f, false-high=%.6f, boundary-missed=%.6f。\n', ...
        y24.output_equivalent_rate, y24.core_scenario_output_equivalent_rate, y24.route_agreement_vs_double, ...
        y24.confidence_agreement_vs_double, y24.false_high_rate, y24.boundary_missed_rate);
    fprintf(fid, '- y16_rank1_2d_coeff24_rest16: output_equivalent=%.6f, core=%.6f, p95_az=%.6f, max_core_az=%.6f。\n', ...
        yr2d.output_equivalent_rate, yr2d.core_scenario_output_equivalent_rate, ...
        yr2d.p95_abs_az_diff_vs_double, yr2d.max_core_abs_az_diff_vs_double);
    fprintf(fid, '- best overall mode: `%s`，output_equivalent=%.6f，core=%.6f，p95 az diff=%.6f deg。\n\n', ...
        best_mode, best.output_equivalent_rate, best.core_scenario_output_equivalent_rate, best.p95_abs_az_diff_vs_double);
    fprintf(fid, '## 10. worst cases\n\n');
    fprintf(fid, 'worst_cases.csv 为每个 mixed mode 保留 az diff 最大的前 50 个 in-scope 样本。弱目标和近反相场景仍作为边界场景，不把其 failure 解释成默认主线求解失败。\n\n');
    fprintf(fid, '## 11. storage estimate\n\n');
    fprintf(fid, 'storage estimate 按 coefficient/template 类别估算，包括 level2 music、level2 rank1、refocus、2D MUSIC、pair-local；该估算不代表最终 FPGA 资源映射。\n\n');
    fprintf(fid, '## 12. 推荐结论\n\n');
    fprintf(fid, '- mixed_precision_pass_flag = %.0f；\n', keypoint_value_from_table_local(keypoints_tbl, 'mixed_precision_pass_flag'));
    fprintf(fid, '- recommended_fixed_point_architecture = %s；\n', keypoint_note_from_table_local(keypoints_tbl, 'recommended_fixed_point_architecture'));
    fprintf(fid, '- proceed_to_fpga_kernel_design_flag = %.0f；\n', keypoint_value_from_table_local(keypoints_tbl, 'proceed_to_fpga_kernel_design_flag'));
    fprintf(fid, '- proceed_to_mc100_flag = %.0f；\n', keypoint_value_from_table_local(keypoints_tbl, 'proceed_to_mc100_flag'));
    fprintf(fid, '- blocker_if_any = %s；\n', keypoint_note_from_table_local(keypoints_tbl, 'blocker_if_any'));
    fprintf(fid, '- next_step_recommendation = %s。\n\n', keypoint_note_from_table_local(keypoints_tbl, 'next_step_recommendation'));
    fprintf(fid, '## 13. 输出文件\n\n');
    fprintf(fid, '结果目录：`%s`。\n\n', result_dir);
    fprintf(fid, '- `step8_9c_mixed_precision_validation.log`\n');
    fprintf(fid, '- `step8_9c_mixed_precision_trial.csv`\n');
    fprintf(fid, '- `step8_9c_mixed_precision_summary.csv`\n');
    fprintf(fid, '- `step8_9c_mixed_precision_keypoints.csv`\n');
    fprintf(fid, '- `step8_9c_mixed_precision_storage_estimate.csv`\n');
    fprintf(fid, '- `step8_9c_mixed_precision_worst_cases.csv`\n');
    fprintf(fid, '- `step8_9c_mixed_precision_recommendations.csv`\n');
    fprintf(fid, '- `step8_9c_mixed_precision_result.mat`\n');
    fprintf(fid, '\n运行耗时 %.2f s。\n', elapsed_sec);
    clear cleaner
end

function plot_step89_steering_error_local(T, path_out)
    fig = figure('Visible', 'off', 'Position', [100, 80, 1050, 430]);
    modes = unique(T.quant_mode, 'stable');
    vals = zeros(numel(modes), 1);
    for i = 1:numel(modes)
        vals(i) = max_or_nan_local(T.rel_err_aligned(T.quant_mode == modes(i)));
    end
    bar(vals);
    grid on;
    set(gca, 'XTick', 1:numel(modes), 'XTickLabel', cellstr(modes), 'XTickLabelRotation', 25);
    ylabel('max aligned relative error');
    title('Steering/template quantization error');
    saveas(fig, path_out);
    close(fig);
end

function plot_step89_ywork_error_local(S, path_out)
    O = S(S.scenario_name == "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 80, 1050, 430]);
    snr_plot = O.mean_ywork_snr_quant_db;
    finite_snr = snr_plot(isfinite(snr_plot));
    if isempty(finite_snr)
        snr_plot(:) = 0;
    else
        snr_plot(~isfinite(snr_plot)) = max(finite_snr) + 10;
    end
    yyaxis left;
    bar(snr_plot);
    ylabel('mean Y\_work quant SNR (dB)');
    yyaxis right;
    plot(1:height(O), O.max_ywork_clip_rate, 'o-', 'LineWidth', 1.5);
    ylabel('max clip rate');
    grid on;
    set(gca, 'XTick', 1:height(O), 'XTickLabel', cellstr(O.quant_mode), 'XTickLabelRotation', 25);
    title('Y\_work quantization error');
    saveas(fig, path_out);
    close(fig);
end

function plot_step89_success_local(S, path_out)
    T = S(S.scenario_name ~= "overall", :);
    scenarios = unique(T.scenario_name, 'stable');
    modes = unique(T.quant_mode, 'stable');
    vals = matrix_by_scenario_mode_local(T, scenarios, modes, 'success_rate');
    fig = figure('Visible', 'off', 'Position', [100, 80, 1180, 470]);
    bar(vals);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:numel(scenarios), 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
    ylabel('success rate');
    title('Success by quant mode');
    legend(cellstr(modes), 'Interpreter', 'none', 'Location', 'eastoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_step89_agreement_local(S, metric_name, path_out)
    O = S(S.scenario_name == "overall", :);
    if strcmp(metric_name, 'route')
        vals = O.route_agreement_vs_double;
        ttl = 'Route agreement vs double';
    else
        vals = O.confidence_agreement_vs_double;
        ttl = 'Confidence agreement vs double';
    end
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 420]);
    bar(vals);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(O), 'XTickLabel', cellstr(O.quant_mode), 'XTickLabelRotation', 25);
    ylabel('agreement');
    title(ttl);
    saveas(fig, path_out);
    close(fig);
end

function plot_step89_az_el_error_local(S, path_out)
    O = S(S.scenario_name == "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 420]);
    bar([O.max_abs_az_diff_vs_double, O.max_abs_el_diff_vs_double]);
    grid on;
    set(gca, 'XTick', 1:height(O), 'XTickLabel', cellstr(O.quant_mode), 'XTickLabelRotation', 25);
    ylabel('max abs difference vs double (deg)');
    title('Az/el output difference by quant mode');
    legend({'az', 'el'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_step89_false_high_boundary_local(S, path_out)
    O = S(S.scenario_name == "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 420]);
    bar([O.false_high_rate, O.boundary_missed_rate, O.low_confidence_rate]);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(O), 'XTickLabel', cellstr(O.quant_mode), 'XTickLabelRotation', 25);
    ylabel('rate');
    title('False-high and boundary summary by quant mode');
    legend({'false high', 'boundary missed', 'low confidence'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_step89_storage_local(T, path_out)
    objects = unique(T.object_name, 'stable');
    formats = unique(T.format, 'stable');
    vals = zeros(numel(objects), numel(formats));
    for i = 1:numel(objects)
        for j = 1:numel(formats)
            idx = T.object_name == objects(i) & T.format == formats(j);
            vals(i, j) = T.total_MB(idx);
        end
    end
    fig = figure('Visible', 'off', 'Position', [100, 80, 1080, 440]);
    bar(vals);
    grid on;
    set(gca, 'XTick', 1:numel(objects), 'XTickLabel', cellstr(objects), 'XTickLabelRotation', 18);
    ylabel('MB');
    title('Template storage estimate by wordlength');
    legend(cellstr(formats), 'Interpreter', 'none', 'Location', 'eastoutside');
    saveas(fig, path_out);
    close(fig);
end

function vals = matrix_by_scenario_mode_local(T, scenarios, modes, field_name)
    vals = NaN(numel(scenarios), numel(modes));
    for i = 1:numel(scenarios)
        for j = 1:numel(modes)
            idx = T.scenario_name == scenarios(i) & T.quant_mode == modes(j);
            if any(idx)
                tmp = T.(field_name);
                vals(i, j) = tmp(find(idx, 1));
            end
        end
    end
end

function write_step89_record_doc_local(path_out, keypoints_tbl, summary_tbl, storage_tbl, steering_error_tbl, result_dir, elapsed_sec, Metkl, quick_mode, cfg88, quant_modes)
    fid = fopen(path_out, 'w', 'n', 'UTF-8');
    cleaner = onCleanup(@() safe_fclose_local(fid));
    if quick_mode
        fprintf(fid, '# 第8.9步 shared-center主线定点量化影响验证记录（quick mode，仅 smoke test）\n\n');
    else
        fprintf(fid, '# 第8.9步 shared-center主线定点量化影响验证记录\n\n');
    end
    fprintf(fid, '本轮定位为 negative / blocker validation。结论不是成功闭合；本轮发现 `quantization_not_closed` blocker。\n\n');
    fprintf(fid, '## 1. 本轮目的\n\n');
    fprintf(fid, '第 8.7 / 8.8 shared-center 主线已在 double 精度下闭合。本轮验证 canonical local steering template、2D MUSIC center-subarray steering、level2 combined steering、refocus elevation weights、Y_work 输入快拍和 rank1 fallback candidate basis 在有限字长表示后，route、confidence、success 和 safety 是否保持稳定。\n\n');
    fprintf(fid, '## 2. 本轮不是完整 FPGA bit-true\n\n');
    fprintf(fid, '本轮是 fixed-point influence validation，不是 FPGA HDL，也不是完整 bit-true fixed-point pipeline。EVD、矩阵乘法、CFAR、FFT 等仍在 MATLAB double 中执行；只有输入数据和 steering/template/cache 先按指定格式量化再反量化进入同一套第 8.7 lazy cascade。因此本轮验证的是数值量化敏感性，不等价于完整 FPGA bit-true 实现。\n\n');
    fprintf(fid, '## 3. 量化公式\n\n');
    fprintf(fid, '对复数 `z=x+j y`，实部和虚部分别采用饱和均匀量化：`Q_B(x)=clip(round(x*S), -Imax, Imax)/S`，其中 `Imax=2^(B-1)-1`，`S=Imax`。单位幅值 steering/template 直接按近似 `[-1,1]` 范围量化。\n\n');
    fprintf(fid, '## 4. Y_work block floating scale\n\n');
    fprintf(fid, '对每个 trial 的 `Y_work` 先取 `scale_y=max(abs(real(Y_work(:))), abs(imag(Y_work(:))), eps)`，再归一化、量化并恢复：`Y_q=Q_B(Y_work/scale_y)*scale_y`。trial CSV 记录 `ywork_scale`、`ywork_snr_quant_db`、`ywork_rel_err` 和实/虚部 clip rate。\n\n');
    fprintf(fid, '## 5. 默认 Doppler de-rotation\n\n');
    fprintf(fid, '根据第 8.8B 结果，本轮默认 `derotation_mode=none`。接口中仍保留 `fd_hat`、`derotation_mode`、`derotation_sign_used` 字段，但主线输入使用 no_derotation。\n\n');
    fprintf(fid, '## 6. 本轮只验证 shared-center 主线\n\n');
    fprintf(fid, '主统计仅包含 `single coarse peak / unresolved local cluster` 的 in-scope trial。two coarse peaks 继续标记 out-of-scope，不进入 shared-center 主线，也不运行 dual-center。weak target 和 near anti-phase 作为边界 safety 场景，不把失败解释为量化失败。\n\n');
    fprintf(fid, '## 7. quant_mode 列表\n\n');
    fprintf(fid, '| mode | coeff | Y_work | note |\n|---|---|---|---|\n');
    for i = 1:numel(quant_modes)
        fprintf(fid, '| %s | %s %.0f | %s %.0f | %s |\n', quant_modes(i).name, ...
            quant_modes(i).coeff_kind, quant_modes(i).coeff_bits, quant_modes(i).y_kind, ...
            quant_modes(i).y_bits, quant_modes(i).note);
    end
    fprintf(fid, '\n## 8. 场景设置\n\n');
    fprintf(fid, '默认 `Metkl=30`、`SNR=[8,16]`、`Np=32`。本次实际 `Metkl=%d`、`quick_mode=%d`。\n\n', Metkl, quick_mode);
    if quick_mode
        fprintf(fid, '本轮为 quick smoke test，不作为正式统计结论。\n\n');
    end
    fprintf(fid, '## 9. Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.6g | %s |\n', keypoints_tbl.keypoint(i), keypoints_tbl.value(i), keypoints_tbl.note(i));
    end
    fprintf(fid, '\n## 10. route / confidence / success / safety\n\n');
    fprintf(fid, '| scenario | quant_mode | in_scope | success | gap | route agree | confidence agree | false-high | boundary-missed | max az diff | max el diff |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary_tbl)
        fprintf(fid, '| %s | %s | %.0f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.6g | %.6g |\n', ...
            table_text_at_local(summary_tbl.scenario_name, i), table_text_at_local(summary_tbl.quant_mode, i), ...
            summary_tbl.in_scope_trial_count(i), summary_tbl.success_rate(i), summary_tbl.success_gap_vs_double(i), ...
            summary_tbl.route_agreement_vs_double(i), summary_tbl.confidence_agreement_vs_double(i), ...
            summary_tbl.false_high_rate(i), summary_tbl.boundary_missed_rate(i), ...
            summary_tbl.max_abs_az_diff_vs_double(i), summary_tbl.max_abs_el_diff_vs_double(i));
    end
    fprintf(fid, '\n## 11. steering/template 误差\n\n');
    fprintf(fid, '| quant_mode | steering_type | max aligned rel err | min coherence | max phase err |\n');
    fprintf(fid, '|---|---|---:|---:|---:|\n');
    modes = unique(steering_error_tbl.quant_mode, 'stable');
    types = unique(steering_error_tbl.steering_type, 'stable');
    for im = 1:numel(modes)
        for it = 1:numel(types)
            mask = steering_error_tbl.quant_mode == modes(im) & steering_error_tbl.steering_type == types(it);
            if any(mask)
                fprintf(fid, '| %s | %s | %.6g | %.9f | %.6g |\n', modes(im), types(it), ...
                    max_or_nan_local(steering_error_tbl.rel_err_aligned(mask)), ...
                    min_or_nan_local(steering_error_tbl.coherence(mask)), ...
                    max_or_nan_local(steering_error_tbl.phase_err_max(mask)));
            end
        end
    end
    fprintf(fid, '\n## 12. Y_work 误差\n\n');
    O = summary_tbl(summary_tbl.scenario_name == "overall", :);
    fprintf(fid, '| quant_mode | mean Y_work SNR dB | max clip rate |\n|---|---:|---:|\n');
    for i = 1:height(O)
        fprintf(fid, '| %s | %.6g | %.6g |\n', O.quant_mode(i), O.mean_ywork_snr_quant_db(i), O.max_ywork_clip_rate(i));
    end
    fprintf(fid, '\n## 13. 模板存储量\n\n');
    fprintf(fid, '| object | format | num_complex | total_MB | BRAM36 |\n|---|---|---:|---:|---:|\n');
    for i = 1:height(storage_tbl)
        fprintf(fid, '| %s | %s | %.0f | %.6g | %.0f |\n', storage_tbl.object_name(i), storage_tbl.format(i), ...
            storage_tbl.num_complex(i), storage_tbl.total_MB(i), storage_tbl.BRAM36_equivalent(i));
    end
    rec = keypoint_note_from_table_local(keypoints_tbl, 'recommended_fixed_point_format');
    pass = keypoint_value_from_table_local(keypoints_tbl, 'fixed_point_pass_flag');
    blocker = keypoint_note_from_table_local(keypoints_tbl, 'fixed_point_blocker_if_any');
    fprintf(fid, '\n## 14. 判断\n\n');
    if pass == 1
        fprintf(fid, '本轮推荐定点格式为 `%s`。在该有限字长影响验证中，success gap、route agreement、confidence agreement、false-high、boundary-missed 和输出角误差满足当前门限，可进入 FPGA kernel design 准备阶段。\n\n', rec);
    else
        fprintf(fid, '本轮不是成功闭合。虽然 success 和 safety 指标未恶化到 false-high / boundary-missed，但 route agreement、confidence agreement 和最大 az 差异未达到当前 fixed-point pass 门限，因此第 8.9 的正式结论是 negative / blocker validation。\n\n');
        fprintf(fid, '当前不建议进入 FPGA kernel design，阻塞原因：`%s`。\n\n', blocker);
    end
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
    fprintf(fid, '- R_runtime_default=%.1f deg, R_runtime_expand=%.1f deg, R_template=%.1f deg\n', ...
        cfg88.R_runtime_default_deg, cfg88.R_runtime_expand_deg, cfg88.template_R_deg);
end

function summary_tbl = build_step88b_summary_table_local(T, modes)
    scenario_names = unique(T.scenario_name, 'stable');
    scenarios = ["overall"; scenario_names(:)];
    rows = {};
    for is = 1:numel(scenarios)
        if scenarios(is) == "overall"
            smask = true(height(T), 1);
        else
            smask = T.scenario_name == scenarios(is);
        end
        comp = make_step88b_comparison_metrics_local(T, smask);
        for im = 1:numel(modes)
            rows{end+1, 1} = make_step88b_summary_row_local(T, smask & T.mode == modes(im), scenarios(is), modes(im), comp); %#ok<AGROW>
        end
    end
    summary_tbl = struct2table([rows{:}]);
end

function row = make_step88b_summary_row_local(T, mask, scenario_name, mode_name, comp)
    in_scope = mask & logical(T.in_scope_shared_center_flag);
    row = struct();
    row.scenario_name = string(scenario_name);
    row.mode = string(mode_name);
    row.trial_count = sum(mask);
    row.in_scope_trial_count = sum(in_scope);
    if any(in_scope)
        row.success_rate = mean(double(T.success(in_scope)), 'omitnan');
        row.false_high_rate = mean(double(T.false_high(in_scope)), 'omitnan');
        row.boundary_missed_rate = mean(double(T.boundary_missed(in_scope)), 'omitnan');
        row.low_confidence_rate = mean(double(T.low_confidence(in_scope)), 'omitnan');
        row.boundary_unreliable_rate = mean(double(T.boundary_unreliable(in_scope)), 'omitnan');
        row.mean_runtime = mean(T.runtime_sec(in_scope), 'omitnan');
        row.p90_runtime = percentile_no_toolbox_local(T.runtime_sec(in_scope), 90);
        row.route_distribution = distribution_string_local(T.route_used(in_scope));
        row.mean_eigen_ratio_1_2 = mean(T.eigen_ratio_1_2(in_scope), 'omitnan');
        row.mean_eigen_ratio_2_noise = mean(T.eigen_ratio_2_noise(in_scope), 'omitnan');
        row.mean_covariance_condition_proxy = mean(T.covariance_condition_proxy(in_scope), 'omitnan');
    else
        row.success_rate = NaN;
        row.false_high_rate = NaN;
        row.boundary_missed_rate = NaN;
        row.low_confidence_rate = NaN;
        row.boundary_unreliable_rate = NaN;
        row.mean_runtime = NaN;
        row.p90_runtime = NaN;
        row.route_distribution = "";
        row.mean_eigen_ratio_1_2 = NaN;
        row.mean_eigen_ratio_2_noise = NaN;
        row.mean_covariance_condition_proxy = NaN;
    end
    fields = fieldnames(comp);
    for i = 1:numel(fields)
        row.(fields{i}) = comp.(fields{i});
    end
end

function comp = make_step88b_comparison_metrics_local(T, scenario_mask)
    no = scenario_mask & T.mode == "no_derotation" & logical(T.in_scope_shared_center_flag);
    minus = scenario_mask & T.mode == "derotation_minus" & logical(T.in_scope_shared_center_flag);
    plus = scenario_mask & T.mode == "derotation_plus" & logical(T.in_scope_shared_center_flag);
    comp = struct();
    comp.success_no_derotation = mean_or_nan_local(double(T.success(no)));
    comp.success_derotation_minus = mean_or_nan_local(double(T.success(minus)));
    comp.success_derotation_plus = mean_or_nan_local(double(T.success(plus)));
    comp.success_gain_minus = comp.success_derotation_minus - comp.success_no_derotation;
    comp.success_gain_plus = comp.success_derotation_plus - comp.success_no_derotation;
    no_base = scenario_mask & T.mode == "no_derotation" & logical(T.in_scope_shared_center_flag);
    comp.route_agreement_minus_vs_no = 1 - mean_or_nan_local(double(T.route_changed_minus_vs_no(no_base)));
    comp.route_agreement_plus_vs_no = 1 - mean_or_nan_local(double(T.route_changed_plus_vs_no(no_base)));
    comp.confidence_agreement_minus_vs_no = 1 - mean_or_nan_local(double(T.confidence_changed_minus_vs_no(no_base)));
    comp.confidence_agreement_plus_vs_no = 1 - mean_or_nan_local(double(T.confidence_changed_plus_vs_no(no_base)));
    comp.max_az_diff_minus_vs_no = max_or_nan_local(T.az_diff_minus_vs_no(no_base));
    comp.max_az_diff_plus_vs_no = max_or_nan_local(T.az_diff_plus_vs_no(no_base));
    comp.max_el_diff_minus_vs_no = max_or_nan_local(T.el_diff_minus_vs_no(no_base));
    comp.max_el_diff_plus_vs_no = max_or_nan_local(T.el_diff_plus_vs_no(no_base));
end

function keypoints_tbl = build_step88b_keypoints_local(T, S, Metkl, quick_mode, cfg88)
    O = S(S.scenario_name == "overall" & S.mode == "no_derotation", :);
    minus = S(S.scenario_name == "overall" & S.mode == "derotation_minus", :);
    plus = S(S.scenario_name == "overall" & S.mode == "derotation_plus", :);
    success_diff_max = max(abs([O.success_gain_minus, O.success_gain_plus]));
    safety_ok = O.false_high_rate == 0 && minus.false_high_rate == 0 && plus.false_high_rate == 0 && ...
        O.boundary_missed_rate == 0 && minus.boundary_missed_rate == 0 && plus.boundary_missed_rate == 0;
    route_stable = O.route_agreement_minus_vs_no >= 0.99 && O.route_agreement_plus_vs_no >= 0.99;
    conf_stable = O.confidence_agreement_minus_vs_no >= 0.99 && O.confidence_agreement_plus_vs_no >= 0.99;
    no_enough = route_stable && conf_stable && success_diff_max <= 0.01 && safety_ok;
    minus_better = O.success_gain_minus > 0.01 && O.success_gain_minus >= O.success_gain_plus && safety_ok;
    plus_better = O.success_gain_plus > 0.01 && O.success_gain_plus > O.success_gain_minus && safety_ok;
    if no_enough
        recommended_mode = "no_derotation_or_optional_derotation";
        enable_derot = 0;
        sign_rec = "none";
        blocker = "";
    elseif minus_better
        recommended_mode = "derotation_minus";
        enable_derot = 1;
        sign_rec = "minus";
        blocker = "";
    elseif plus_better
        recommended_mode = "derotation_plus";
        enable_derot = 1;
        sign_rec = "plus";
        blocker = "";
    else
        recommended_mode = "no_derotation";
        enable_derot = 0;
        sign_rec = "not_closed";
        blocker = "ywork_derotation_sign_not_closed";
    end
    proceed_fixed = safety_ok && enable_derot == 0;
    rows = {};
    rows = add_kp_local(rows, 'Metkl', Metkl, 'Monte Carlo trials per scenario-SNR case');
    rows = add_kp_local(rows, 'quick_mode_flag', double(quick_mode), '1 means quick trend only');
    rows = add_kp_local(rows, 'total_trials', height(T) / 3, 'base trials before mode expansion');
    rows = add_kp_local(rows, 'in_scope_trials', O.in_scope_trial_count, 'in-scope base trials used for mode comparison');
    rows = add_kp_local(rows, 'success_no_derotation', O.success_no_derotation, 'overall in-scope success without Doppler de-rotation');
    rows = add_kp_local(rows, 'success_derotation_minus', O.success_derotation_minus, 'overall in-scope success with exp(-j2pifdt)');
    rows = add_kp_local(rows, 'success_derotation_plus', O.success_derotation_plus, 'overall in-scope success with exp(+j2pifdt)');
    rows = add_kp_local(rows, 'success_gain_minus', O.success_gain_minus, 'minus success minus no-derotation success');
    rows = add_kp_local(rows, 'success_gain_plus', O.success_gain_plus, 'plus success minus no-derotation success');
    rows = add_kp_local(rows, 'false_high_no_derotation', O.false_high_rate, 'false-high rate without de-rotation');
    rows = add_kp_local(rows, 'false_high_derotation_minus', minus.false_high_rate, 'false-high rate with minus de-rotation');
    rows = add_kp_local(rows, 'false_high_derotation_plus', plus.false_high_rate, 'false-high rate with plus de-rotation');
    rows = add_kp_local(rows, 'boundary_missed_no_derotation', O.boundary_missed_rate, 'boundary-missed rate without de-rotation');
    rows = add_kp_local(rows, 'boundary_missed_derotation_minus', minus.boundary_missed_rate, 'boundary-missed rate with minus de-rotation');
    rows = add_kp_local(rows, 'boundary_missed_derotation_plus', plus.boundary_missed_rate, 'boundary-missed rate with plus de-rotation');
    rows = add_kp_local(rows, 'route_agreement_minus_vs_no', O.route_agreement_minus_vs_no, 'route agreement on in-scope trials');
    rows = add_kp_local(rows, 'route_agreement_plus_vs_no', O.route_agreement_plus_vs_no, 'route agreement on in-scope trials');
    rows = add_kp_local(rows, 'confidence_agreement_minus_vs_no', O.confidence_agreement_minus_vs_no, 'confidence agreement on in-scope trials');
    rows = add_kp_local(rows, 'confidence_agreement_plus_vs_no', O.confidence_agreement_plus_vs_no, 'confidence agreement on in-scope trials');
    rows = add_kp_local(rows, 'max_az_diff_minus_vs_no', O.max_az_diff_minus_vs_no, 'max azimuth estimate difference');
    rows = add_kp_local(rows, 'max_az_diff_plus_vs_no', O.max_az_diff_plus_vs_no, 'max azimuth estimate difference');
    rows = add_kp_local(rows, 'max_el_diff_minus_vs_no', O.max_el_diff_minus_vs_no, 'max elevation estimate difference');
    rows = add_kp_local(rows, 'max_el_diff_plus_vs_no', O.max_el_diff_plus_vs_no, 'max elevation estimate difference');
    rows = add_kp_local(rows, 'recommended_ywork_mode', NaN, recommended_mode);
    rows = add_kp_local(rows, 'recommend_enable_derotation_flag', enable_derot, '1 means enable Doppler de-rotation by default');
    rows = add_kp_local(rows, 'derotation_sign_recommendation', NaN, sign_rec);
    rows = add_kp_local(rows, 'proceed_to_fixed_point_flag', double(proceed_fixed), 'whether shared-center mainline can proceed without derotation blocker');
    rows = add_kp_local(rows, 'fixed_point_blocker_if_any', NaN, blocker);
    rows = add_kp_local(rows, 'fd_hat_source', NaN, 'fdAxis(dopplerIdx), consistent with fftshift MTD axis');
    rows = add_kp_local(rows, 'fd_true_reference_hz', cfg88.fd_true, 'simulation truth used only for sanity comparison');
    keypoints_tbl = cell2table(rows, 'VariableNames', {'keypoint', 'value', 'note'});
end

function val = mean_or_nan_local(x)
    if isempty(x)
        val = NaN;
    else
        val = mean(x, 'omitnan');
    end
end

function val = max_or_nan_local(x)
    x = x(isfinite(x));
    if isempty(x)
        val = NaN;
    else
        val = max(x);
    end
end

function summary_tbl = build_step88_summary_table_local(T)
    names = unique(T.scenario_name, 'stable');
    rows = cell(numel(names) + 1, 1);
    rows{1} = make_summary_row_step88_local(T, true(height(T), 1), "overall");
    for i = 1:numel(names)
        mask = T.scenario_name == names(i);
        rows{i+1} = make_summary_row_step88_local(T, mask, names(i));
    end
    summary_tbl = struct2table([rows{:}]);
end

function row = make_summary_row_step88_local(T, mask, name)
    idx = find(mask);
    in_scope = mask & logical(T.in_scope_shared_center_flag);
    out_scope = mask & ~logical(T.in_scope_shared_center_flag);
    route_dist = distribution_string_local(T.route_used(mask));
    row = struct();
    row.scenario_name = string(name);
    row.num_trials = numel(idx);
    row.cfar_detection_rate = mean(double(T.cfar_detected_flag(mask)), 'omitnan');
    row.single_coarse_peak_rate = mean(double(T.coarse_peak_count(mask) == 1), 'omitnan');
    row.two_coarse_peak_rate = mean(double(T.two_coarse_peaks_out_of_scope(mask)), 'omitnan');
    row.two_coarse_peak_out_of_scope_rate = row.two_coarse_peak_rate;
    row.single_peak_in_scope_rate = mean(double(T.frontend_state(mask) == "single_peak_in_scope"), 'omitnan');
    row.two_close_peaks_merge_candidate_rate = mean(double(T.frontend_state(mask) == "two_close_peaks_merge_candidate"), 'omitnan');
    row.two_separated_peaks_out_of_scope_rate = mean(double(T.frontend_state(mask) == "two_separated_peaks_out_of_scope"), 'omitnan');
    row.weak_secondary_candidate_rate = mean(double(T.weak_secondary_candidate_flag(mask)), 'omitnan');
    row.multi_coarse_peak_total_rate = row.two_close_peaks_merge_candidate_rate + row.two_separated_peaks_out_of_scope_rate;
    row.in_scope_shared_center_rate = mean(double(T.in_scope_shared_center_flag(mask)), 'omitnan');
    row.out_of_scope_rate = 1 - row.in_scope_shared_center_rate;
    row.center_selection_success_rate = mean(double(T.center_selection_success(mask)), 'omitnan');
    row.both_inside_R15_rate = mean(double(T.both_inside_R15(mask)), 'omitnan');
    row.both_inside_R20_rate = mean(double(T.both_inside_R20(mask)), 'omitnan');
    if any(in_scope)
        row.step87_success_rate = mean(double(T.success(in_scope)), 'omitnan');
        row.false_high_rate = mean(double(T.false_high(in_scope)), 'omitnan');
        row.boundary_missed_rate = mean(double(T.boundary_missed(in_scope)), 'omitnan');
        row.low_confidence_rate = mean(double(T.low_confidence(in_scope)), 'omitnan');
        row.boundary_unreliable_rate = mean(double(T.boundary_unreliable(in_scope)), 'omitnan');
        row.mean_runtime = mean(T.runtime_sec(in_scope), 'omitnan');
        row.p90_runtime = percentile_no_toolbox_local(T.runtime_sec(in_scope), 90);
    else
        row.step87_success_rate = NaN;
        row.false_high_rate = NaN;
        row.boundary_missed_rate = NaN;
        row.low_confidence_rate = NaN;
        row.boundary_unreliable_rate = NaN;
        row.mean_runtime = NaN;
        row.p90_runtime = NaN;
    end
    if any(in_scope)
        row.false_high_rate_in_scope = mean(double(T.false_high(in_scope)), 'omitnan');
        row.boundary_missed_rate_in_scope = mean(double(T.boundary_missed(in_scope)), 'omitnan');
    else
        row.false_high_rate_in_scope = NaN;
        row.boundary_missed_rate_in_scope = NaN;
    end
    if any(out_scope)
        row.false_high_rate_out_of_scope = mean(double(T.false_high(out_scope)), 'omitnan');
    else
        row.false_high_rate_out_of_scope = NaN;
    end
    row.mean_abs_center_error_to_pair_center = mean(abs(T.center_error_to_pair_center(mask)), 'omitnan');
    row.mean_abs_center_error_to_strong_target = mean(abs(T.center_error_to_strong_target(mask)), 'omitnan');
    row.route_distribution = route_dist;
    row.recommended_frontend_policy = string(T.Properties.UserData.recommended_frontend_policy);
end

function keypoints_tbl = build_step88_keypoints_local(T, S, Metkl, quick_mode, cfg88)
    overall = S(S.scenario_name == "overall", :);
    weak = T(T.scenario_name == "weak_target_boundary", :);
    anti = T(T.scenario_name == "near_antiphase_boundary", :);
    large = S(S.scenario_name == "large_el_pair", :);
    interface_pass = overall.cfar_detection_rate >= 0.95 && overall.single_coarse_peak_rate >= 0.90 && ...
        overall.false_high_rate <= 0.01 && overall.boundary_missed_rate <= 0.01;
    proceed_fixed = interface_pass && overall.false_high_rate == 0 && overall.boundary_missed_rate == 0;
    rows = {};
    rows = add_kp_local(rows, 'Metkl', Metkl, 'Monte Carlo trials per scenario-SNR case');
    rows = add_kp_local(rows, 'quick_mode_flag', double(quick_mode), '1 means quick trend only');
    rows = add_kp_local(rows, 'total_trials', height(T), 'total scenario/SNR/MC trials');
    rows = add_kp_local(rows, 'cfar_detection_rate_overall', overall.cfar_detection_rate, 'overall CFAR detection rate');
    rows = add_kp_local(rows, 'single_coarse_peak_rate_overall', overall.single_coarse_peak_rate, 'overall unresolved coarse cluster rate');
    rows = add_kp_local(rows, 'two_coarse_peak_rate_overall', overall.two_coarse_peak_rate, 'overall two coarse peaks out-of-scope rate');
    rows = add_kp_local(rows, 'single_peak_in_scope_rate', overall.single_peak_in_scope_rate, 'frontend_state single_peak_in_scope rate');
    rows = add_kp_local(rows, 'two_close_peaks_merge_candidate_rate', overall.two_close_peaks_merge_candidate_rate, 'frontend close-peak merge-candidate rate');
    rows = add_kp_local(rows, 'two_separated_peaks_out_of_scope_rate', overall.two_separated_peaks_out_of_scope_rate, 'frontend separated multi-peak out-of-scope rate');
    rows = add_kp_local(rows, 'weak_secondary_candidate_rate', overall.weak_secondary_candidate_rate, 'weak or unstable secondary coarse-peak candidate rate');
    rows = add_kp_local(rows, 'multi_coarse_peak_total_rate', overall.multi_coarse_peak_total_rate, 'two-close plus two-separated coarse-peak state rate');
    rows = add_kp_local(rows, 'in_scope_shared_center_rate', overall.in_scope_shared_center_rate, 'frontend states routed into shared-center enhancement');
    rows = add_kp_local(rows, 'out_of_scope_rate', overall.out_of_scope_rate, 'frontend states not routed into shared-center enhancement');
    rows = add_kp_local(rows, 'false_high_rate_in_scope', overall.false_high_rate_in_scope, 'high-confidence wrong output rate on in-scope trials');
    rows = add_kp_local(rows, 'boundary_missed_rate_in_scope', overall.boundary_missed_rate_in_scope, 'boundary missed rate on in-scope trials');
    rows = add_kp_local(rows, 'false_high_rate_out_of_scope', overall.false_high_rate_out_of_scope, 'false-high rate on out-of-scope trials');
    rows = add_kp_local(rows, 'center_selection_success_rate_overall', overall.center_selection_success_rate, 'selected center coverage success');
    rows = add_kp_local(rows, 'both_inside_R15_rate_overall', overall.both_inside_R15_rate, 'both targets within runtime R=1.5');
    rows = add_kp_local(rows, 'both_inside_R20_rate_overall', overall.both_inside_R20_rate, 'both targets within expansion R=2.0');
    rows = add_kp_local(rows, 'step87_success_rate_overall', overall.step87_success_rate, 'shared-center lazy cascade success on in-scope trials');
    rows = add_kp_local(rows, 'false_high_rate_overall', overall.false_high_rate, 'high-confidence wrong output rate');
    rows = add_kp_local(rows, 'boundary_missed_rate_overall', overall.boundary_missed_rate, 'missed weak/anti boundary rate');
    rows = add_kp_local(rows, 'low_confidence_rate_overall', overall.low_confidence_rate, 'low-confidence rate');
    if isempty(weak)
        weak_false_high = NaN;
    else
        weak_false_high = mean(double(weak.false_high), 'omitnan');
    end
    if isempty(anti)
        anti_false_high = NaN;
    else
        anti_false_high = mean(double(anti.false_high), 'omitnan');
    end
    rows = add_kp_local(rows, 'weak_target_false_high', weak_false_high, 'weak-target boundary false-high rate');
    rows = add_kp_local(rows, 'antiphase_false_high', anti_false_high, 'near anti-phase boundary false-high rate');
    if isempty(large)
        large_val = NaN;
        large_note = 'large-el scenario missing';
    else
        large_val = large.step87_success_rate;
        large_note = char("large-el success; route distribution: " + large.route_distribution);
    end
    rows = add_kp_local(rows, 'large_el_branch_behavior', large_val, large_note);
    rows = add_kp_local(rows, 'frontend_to_step87_interface_pass_flag', double(interface_pass), 'interface closure safety flag');
    rows = add_kp_local(rows, 'proceed_to_fixed_point_flag', double(proceed_fixed), 'whether shared-center mainline may proceed to fixed-point quantization');
    rows = add_kp_local(rows, 'fixed_point_blocker', cfg88.fixed_point_blocker_default + double(~proceed_fixed), '0 means no closure blocker; 1 means review closure metrics first');
    rows = add_kp_local(rows, 'recommended_frontend_policy', NaN, cfg88.recommended_frontend_policy);
    keypoints_tbl = cell2table(rows, 'VariableNames', {'keypoint', 'value', 'note'});
end

function rows = add_kp_local(rows, key, value, note)
    rows(end+1, :) = {string(key), double(value), string(note)}; %#ok<AGROW>
end

function example = make_example_entry_local(sc, frontend_out, diag)
    example = struct();
    example.scenario_name = sc.scenario_name;
    example.snr_db = sc.snr_db;
    example.az_scan = diag.az_scan;
    example.power = diag.coarse_power;
    example.coarseAz = frontend_out.coarseAz_deg;
    if sc.target_count == 1
        example.trueAz = sc.theta1;
    else
        example.trueAz = mean([sc.theta1, sc.theta2]);
    end
    example.selectedCenterAz = frontend_out.selectedCenterAz_deg;
end

function plot_success_no_vs_derotation_local(S, path_out)
    C = comparison_rows_for_plot_local(S);
    fig = figure('Visible', 'off', 'Position', [100, 80, 1080, 430]);
    vals = [C.success_no_derotation, C.success_derotation_minus, C.success_derotation_plus];
    bar(vals);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(C), 'XTickLabel', cellstr(C.scenario_name), 'XTickLabelRotation', 25);
    ylabel('success rate');
    title('Y\_work de-rotation success comparison');
    legend({'no', 'minus', 'plus'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_agreement_metric_local(S, metric_name, path_out)
    C = comparison_rows_for_plot_local(S);
    if strcmp(metric_name, 'route')
        vals = [C.route_agreement_minus_vs_no, C.route_agreement_plus_vs_no];
        ttl = 'Route agreement vs no de-rotation';
        ylab = 'route agreement';
    else
        vals = [C.confidence_agreement_minus_vs_no, C.confidence_agreement_plus_vs_no];
        ttl = 'Confidence agreement vs no de-rotation';
        ylab = 'confidence agreement';
    end
    fig = figure('Visible', 'off', 'Position', [100, 80, 1080, 430]);
    bar(vals);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(C), 'XTickLabel', cellstr(C.scenario_name), 'XTickLabelRotation', 25);
    ylabel(ylab);
    title(ttl);
    legend({'minus vs no', 'plus vs no'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_az_el_diff_between_modes_local(S, path_out)
    C = comparison_rows_for_plot_local(S);
    vals = [C.max_az_diff_minus_vs_no, C.max_az_diff_plus_vs_no, C.max_el_diff_minus_vs_no, C.max_el_diff_plus_vs_no];
    fig = figure('Visible', 'off', 'Position', [100, 80, 1120, 430]);
    bar(vals);
    grid on;
    set(gca, 'XTick', 1:height(C), 'XTickLabel', cellstr(C.scenario_name), 'XTickLabelRotation', 25);
    ylabel('max difference (deg)');
    title('Az/el estimate difference between Y\_work modes');
    legend({'az minus', 'az plus', 'el minus', 'el plus'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_eigen_ratio_no_vs_derotation_local(S, path_out)
    T = S(S.scenario_name ~= "overall", :);
    scenarios = unique(T.scenario_name, 'stable');
    modes = ["no_derotation", "derotation_minus", "derotation_plus"];
    vals = nan(numel(scenarios), numel(modes));
    for i = 1:numel(scenarios)
        for j = 1:numel(modes)
            r = T(T.scenario_name == scenarios(i) & T.mode == modes(j), :);
            if ~isempty(r)
                vals(i, j) = r.mean_eigen_ratio_1_2(1);
            end
        end
    end
    fig = figure('Visible', 'off', 'Position', [100, 80, 1080, 430]);
    bar(vals);
    grid on;
    set(gca, 'XTick', 1:numel(scenarios), 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
    ylabel('mean lambda1/lambda2');
    title('Subspace diagnostic by Y\_work mode');
    legend({'no', 'minus', 'plus'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_runtime_no_vs_derotation_local(S, path_out)
    T = S(S.scenario_name ~= "overall", :);
    scenarios = unique(T.scenario_name, 'stable');
    modes = ["no_derotation", "derotation_minus", "derotation_plus"];
    vals = nan(numel(scenarios), numel(modes));
    for i = 1:numel(scenarios)
        for j = 1:numel(modes)
            r = T(T.scenario_name == scenarios(i) & T.mode == modes(j), :);
            if ~isempty(r)
                vals(i, j) = r.mean_runtime(1);
            end
        end
    end
    fig = figure('Visible', 'off', 'Position', [100, 80, 1080, 430]);
    bar(vals);
    grid on;
    set(gca, 'XTick', 1:numel(scenarios), 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
    ylabel('mean runtime (sec)');
    title('Lazy cascade runtime by Y\_work mode');
    legend({'no', 'minus', 'plus'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function C = comparison_rows_for_plot_local(S)
    C = S(S.scenario_name ~= "overall" & S.mode == "no_derotation", :);
end

function plot_coarse_peak_examples_local(examples, path_out)
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 620]);
    nshow = min(numel(examples), 6);
    tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    for i = 1:nshow
        nexttile;
        P = examples(i).power;
        P = P / max(P);
        plot(examples(i).az_scan, P, 'LineWidth', 1.1);
        hold on;
        xline(examples(i).coarseAz, 'r-', 'LineWidth', 0.9);
        xline(examples(i).selectedCenterAz, 'k--', 'LineWidth', 0.9);
        xline(examples(i).trueAz, ':', 'Color', [0.1 0.5 0.1], 'LineWidth', 0.9);
        grid on;
        ylim([0, 1.05]);
        title(sprintf('%s / SNR=%g', examples(i).scenario_name, examples(i).snr_db), 'Interpreter', 'none');
        xlabel('azimuth (deg)');
        ylabel('normalized power');
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_center_error_local(S, path_out)
    T = S(S.scenario_name ~= "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 420]);
    vals = [T.mean_abs_center_error_to_pair_center, T.mean_abs_center_error_to_strong_target];
    bar(vals);
    grid on;
    set(gca, 'XTick', 1:height(T), 'XTickLabel', cellstr(T.scenario_name), 'XTickLabelRotation', 25);
    ylabel('mean abs error (deg)');
    title('Selected work-array center error');
    legend({'to pair center', 'to strong target'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_delta_coverage_local(S, path_out)
    T = S(S.scenario_name ~= "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 420]);
    bar([T.both_inside_R15_rate, T.both_inside_R20_rate]);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(T), 'XTickLabel', cellstr(T.scenario_name), 'XTickLabelRotation', 25);
    ylabel('coverage rate');
    title('Delta-theta coverage');
    legend({'R=1.5 deg', 'R=2.0 deg'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_route_distribution_local(T, path_out)
    scenarios = unique(T.scenario_name, 'stable');
    routes = unique(T.route_used, 'stable');
    vals = zeros(numel(scenarios), numel(routes));
    for i = 1:numel(scenarios)
        maskS = T.scenario_name == scenarios(i);
        n = sum(maskS);
        for j = 1:numel(routes)
            vals(i, j) = sum(maskS & T.route_used == routes(j)) / max(n, 1);
        end
    end
    fig = figure('Visible', 'off', 'Position', [100, 80, 1080, 460]);
    bar(vals, 'stacked');
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:numel(scenarios), 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
    ylabel('route fraction');
    title('Shared-center route distribution by scenario');
    legend(cellstr(routes), 'Interpreter', 'none', 'Location', 'eastoutside');
    saveas(fig, path_out);
    close(fig);
end

function plot_success_false_high_local(S, path_out)
    T = S(S.scenario_name ~= "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 420]);
    bar([T.step87_success_rate, T.false_high_rate, T.boundary_missed_rate, T.low_confidence_rate]);
    grid on;
    ylim([0, 1.05]);
    set(gca, 'XTick', 1:height(T), 'XTickLabel', cellstr(T.scenario_name), 'XTickLabelRotation', 25);
    ylabel('rate');
    title('Success and safety summary');
    legend({'success', 'false high', 'boundary missed', 'low confidence'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_runtime_local(S, path_out)
    T = S(S.scenario_name ~= "overall", :);
    fig = figure('Visible', 'off', 'Position', [100, 80, 980, 420]);
    bar([T.mean_runtime, T.p90_runtime]);
    grid on;
    set(gca, 'XTick', 1:height(T), 'XTickLabel', cellstr(T.scenario_name), 'XTickLabelRotation', 25);
    ylabel('runtime (sec)');
    title('Shared-center lazy cascade runtime');
    legend({'mean', 'p90'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function write_step88b_record_doc_local(path_out, keypoints_tbl, summary_tbl, result_dir, elapsed_sec, Metkl, quick_mode, cfg88)
    fid = fopen(path_out, 'w', 'n', 'UTF-8');
    cleaner = onCleanup(@() safe_fclose_local(fid));
    if quick_mode
        fprintf(fid, '# 第8.8B步 Y_work多普勒补偿接口验证记录（quick mode，仅 smoke test）\n\n');
    else
        fprintf(fid, '# 第8.8B步 Y_work多普勒补偿接口验证记录\n\n');
    end
    fprintf(fid, '## 1. 本轮目的\n\n');
    fprintf(fid, '本轮验证第 8.8 前端输出到第 8.7 shared-center lazy cascade 输入之间，`Y_work` 是否需要按检测 Doppler bin 做慢时间相位补偿。验证只改变 `Y_work` 的慢时间相位，不改第 8.7 算法、route 逻辑或阈值，也不改第 8.8 前端 CFAR/coarse detector 主逻辑。\n\n');
    fprintf(fid, '- 脚本：`space_smooth_music_B_frontend_ywork_derotation_validation.m`\n');
    fprintf(fid, '- 短名 runner：`frontend_ywork_derot.m`\n');
    fprintf(fid, '- 结果目录：`%s`\n', result_dir);
    fprintf(fid, '- Metkl=%d，quick_mode=%d。\n', Metkl, quick_mode);
    if quick_mode
        fprintf(fid, '- 本轮为 quick trend，不作为正式统计结论。\n');
    end
    fprintf(fid, '\n## 2. 当前 Y_work 的物理含义\n\n');
    fprintf(fid, '第 8.8 前端经过 LFM 回波、阵元级距离脉压、MTD、CFAR、粗测角和 65 列动态选阵后，第 8.7 需要的局部工作子阵空间快拍为 `Y_work(q,m,p)`。\n\n');
    fprintf(fid, '- `q=1...65` 是工作子阵方位列。\n');
    fprintf(fid, '- `m=1...32` 是俯仰层。\n');
    fprintf(fid, '- `p=1...Np` 是脉冲/慢时间快拍。\n\n');
    fprintf(fid, '当前构造来自检测距离单元：\n\n');
    fprintf(fid, '`Y_elem(:, p) = pcCube(:, rangeIdx, p)`\n\n');
    fprintf(fid, '随后按 `selectedWorkColumns` 和 32 层 reshape 成 `Y_work = 65 x 32 x Np`。该数据表示同一个检测 range bin 上，各阵元随脉冲变化的空间观测。\n\n');
    fprintf(fid, '## 3. Doppler 相位影响\n\n');
    fprintf(fid, '若目标速度非零，慢时间信号可写为 `s(p) ~= s0 * exp(j*2*pi*fd*p*PRI)`。单源理想协方差中公共相位对 `a*a^H` 影响可能很小，但在双相干分量、有限快拍、噪声、MTD bin 选择、rank1 fallback、MUSIC 谱形和 confidence 判据中，是否补偿需要实测验证，不能直接假设。\n\n');
    fprintf(fid, '## 4. de-rotation 公式与符号\n\n');
    fprintf(fid, '慢时间为 `tSlow(p)=(p-1)*PRI`。本轮对同一份观测、同一 `frontend_out`、同一 `selectedWorkColumns` 同时比较三种模式：\n\n');
    fprintf(fid, '- `no_derotation`: `Y(:,p)=Y_raw(:,p)`\n');
    fprintf(fid, '- `derotation_minus`: `Y(:,p)=Y_raw(:,p)*exp(-j*2*pi*fd_hat*tSlow(p))`\n');
    fprintf(fid, '- `derotation_plus`: `Y(:,p)=Y_raw(:,p)*exp(+j*2*pi*fd_hat*tSlow(p))`\n\n');
    fprintf(fid, '同时测试 plus 和 minus 是因为 MTD 轴、echo 生成符号、FFT shift 和速度正负号约定可能不同；最终以 route consistency、success 和安全指标判断。\n\n');
    fprintf(fid, '## 5. fd_hat 来源\n\n');
    fprintf(fid, '本轮优先使用前端 MTD 的 `dopplerIdx` 和 fftshift 后的 `fdAxis`：`fd_hat = fdAxis(dopplerIdx)`。当前配置 `fd_true = %.6f Hz`，`vAxis = -fdAxis*lambda/2`，与 `mtd_process.m` 的 `fftshift(fft(...,3),3)` 频率轴保持一致。若 `fdAxis` 不可用才退回 `vAxis` 换算；本轮正式结果使用 `fdAxis(dopplerIdx)`。\n\n', cfg88.fd_true);
    fprintf(fid, '## 6. 场景设置\n\n');
    fprintf(fid, '默认 `Metkl=30`，`SNR=[8,16]`，`Np=32`。主统计限定在 `single coarse peak / unresolved local cluster` 的 in-scope shared-center trial；two coarse peaks 仍标记 out-of-scope，不用于判断 de-rotation 是否有效。weak target 和 near anti-phase 仅作为边界 sanity，主要检查 false-high 是否保持为 0。\n\n');
    fprintf(fid, '## 7. Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.6g | %s |\n', keypoints_tbl.keypoint(i), keypoints_tbl.value(i), keypoints_tbl.note(i));
    end
    fprintf(fid, '\n## 8. no / minus / plus 结果\n\n');
    fprintf(fid, '| scenario | mode | in_scope | success | false-high | boundary-missed | low-conf | boundary-unreliable | mean runtime | route distribution |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|---:|---|\n');
    for i = 1:height(summary_tbl)
        scenario_i = table_text_at_local(summary_tbl.scenario_name, i);
        mode_i = table_text_at_local(summary_tbl.mode, i);
        route_i = table_text_at_local(summary_tbl.route_distribution, i);
        fprintf(fid, '| %s | %s | %.0f | %.3f | %.3f | %.3f | %.3f | %.3f | %.4f | %s |\n', ...
            scenario_i, mode_i, summary_tbl.in_scope_trial_count(i), ...
            summary_tbl.success_rate(i), summary_tbl.false_high_rate(i), summary_tbl.boundary_missed_rate(i), ...
            summary_tbl.low_confidence_rate(i), summary_tbl.boundary_unreliable_rate(i), ...
            summary_tbl.mean_runtime(i), route_i);
    end
    fprintf(fid, '\n## 9. mode 间比较\n\n');
    C = summary_tbl(summary_tbl.mode == "no_derotation", :);
    fprintf(fid, '| scenario | success no | success minus | success plus | route agree minus | route agree plus | confidence agree minus | confidence agree plus | max az diff minus | max az diff plus | max el diff minus | max el diff plus |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(C)
        scenario_i = table_text_at_local(C.scenario_name, i);
        fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.6g | %.6g | %.6g | %.6g |\n', ...
            scenario_i, C.success_no_derotation(i), C.success_derotation_minus(i), C.success_derotation_plus(i), ...
            C.route_agreement_minus_vs_no(i), C.route_agreement_plus_vs_no(i), ...
            C.confidence_agreement_minus_vs_no(i), C.confidence_agreement_plus_vs_no(i), ...
            C.max_az_diff_minus_vs_no(i), C.max_az_diff_plus_vs_no(i), ...
            C.max_el_diff_minus_vs_no(i), C.max_el_diff_plus_vs_no(i));
    end
    fprintf(fid, '\n## 10. 子空间诊断\n\n');
    fprintf(fid, '`covariance_trace`、`eigen_ratio_1_2`、`eigen_ratio_2_noise` 和 `covariance_condition_proxy` 只用于解释，不参与 route 判决。若 de-rotation 真正改善空间快拍质量，应体现为 success 或 route/confidence 稳定性改善，并且不能提升 false-high 或 boundary-missed。\n\n');
    rec_mode = keypoint_note_from_table_local(keypoints_tbl, 'recommended_ywork_mode');
    rec_flag = keypoint_value_from_table_local(keypoints_tbl, 'recommend_enable_derotation_flag');
    rec_sign = keypoint_note_from_table_local(keypoints_tbl, 'derotation_sign_recommendation');
    proceed = keypoint_value_from_table_local(keypoints_tbl, 'proceed_to_fixed_point_flag');
    fprintf(fid, '## 11. 判断\n\n');
    if rec_flag == 0
        fprintf(fid, '结论：当前第 8.8B 场景下，Doppler de-rotation 不应被强制设为默认接口。推荐 `recommended_ywork_mode=%s`，推荐符号 `%s`。接口中可保留 de-rotation 作为工程严谨选项或后续平台一致性检查项。\n\n', rec_mode, rec_sign);
    else
        fprintf(fid, '结论：当前结果支持默认启用 Doppler de-rotation。推荐 `recommended_ywork_mode=%s`，推荐符号 `%s`。\n\n', rec_mode, rec_sign);
    end
    if proceed == 1
        fprintf(fid, 'shared-center 主线可继续进入定点量化准备；本轮未引入新的 de-rotation blocker。\n\n');
    else
        fprintf(fid, '本轮存在 de-rotation 接口 blocker，进入定点量化前需先闭合 MTD 轴和符号约定。\n\n');
    end
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
end

function note = keypoint_note_from_table_local(tbl, key)
    idx = strcmp(string(tbl.keypoint), string(key));
    if any(idx)
        note = string(tbl.note(find(idx, 1)));
    else
        note = "";
    end
end

function txt = table_text_at_local(col, idx)
    if iscell(col)
        txt = string(col{idx});
    else
        txt = string(col(idx));
    end
    txt = char(txt);
end

function write_interface_doc_local(path_out, cfg88)
    fid = fopen(path_out, 'w', 'n', 'UTF-8');
    cleaner = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.8步 前端到第8.7接口定义\n\n');
    fprintf(fid, '## 1. 默认适用场景\n\n');
    fprintf(fid, '第 8.8 默认处理 `single coarse peak / unresolved local cluster`：前端在某个距离-多普勒单元或局部角域中检测到一个粗峰，该粗峰可能对应一个真实目标，也可能包含两个相干或近邻空间分量。系统以该粗峰方位吸附最近实际阵元列，选择 65 列工作子阵，再进入第 8.7 shared-center lazy cascade。\n\n');
    fprintf(fid, '若角度粗扫描已经出现两个稳定粗峰，则该场景不进入本文默认 shared-center 主线，而标记为 `multi-coarse-peak / out-of-scope`，交给前端多目标分支、上层跟踪、后续 CPI 调度或未来工作。本轮只标记状态，不实现 dual-center。\n\n');
    fprintf(fid, '## 2. 前端输出 frontend_out\n\n');
    fprintf(fid, '第 5/6 步前端输出以下基础字段：`rangeIdx`、`dopplerIdx`、`range_m`、`velocity_mps`、`coarseAz_deg`、`coarseEl_deg`、`coarseMetric`、`peakCountCoarse`、`coarsePeakWidth`、`coarsePeakProminence`、`selectedCenterColumn`、`selectedCenterAz_deg`、`selectedWorkColumns`、`cfarCount`、`cfarBestMetric`。\n\n');
    fprintf(fid, '- `rangeIdx / dopplerIdx` 来自 MTD + CFAR。\n');
    fprintf(fid, '- `coarseAz / coarseEl` 来自低成本粗方位 beamformer 和检测单元上的三波束比幅。\n');
    fprintf(fid, '- `selectedCenterColumn` 是 `coarseAz` 吸附到最近实际阵元列后的中心列。\n');
    fprintf(fid, '- `selectedWorkColumns` 是中心列左右各 32 列，总共 65 列，按圆柱阵列周期回绕。\n\n');
    fprintf(fid, '第 8.8 状态整理新增字段：`coarse_peak_sep_deg`、`second_peak_prominence`、`frontend_state`、`in_scope_shared_center_flag`、`out_of_scope_reason`、`merge_candidate_flag`、`weak_secondary_candidate_flag`、`selected_center_valid_flag`。\n\n');
    fprintf(fid, '## 3. 前端状态机\n\n');
    fprintf(fid, '状态集合为：`single_peak_in_scope`、`two_close_peaks_merge_candidate`、`two_separated_peaks_out_of_scope`、`weak_secondary_candidate`、`no_valid_coarse_peak`。\n\n');
    fprintf(fid, '- `single_peak_in_scope`：`coarse_peak_count == 1`，默认进入 shared-center 增强测角。\n');
    fprintf(fid, '- `two_close_peaks_merge_candidate`：粗峰间隔小于 `merge_threshold`，当前只作为合并候选或未来验证状态；若原粗峰合并逻辑已经把它视作单粗峰，则仍可沿原 shared-center 路径验证。\n');
    fprintf(fid, '- `two_separated_peaks_out_of_scope`：粗峰间隔不小于 `merge_threshold`，表示前端已有多目标迹象，不进入默认 shared-center 主线。\n');
    fprintf(fid, '- `weak_secondary_candidate`：第二粗峰弱或不稳定，只作为低置信二级候选标签，不作为高置信双目标输出依据。\n');
    fprintf(fid, '- `no_valid_coarse_peak`：CFAR 未形成有效检测或中心列无效。\n\n');
    fprintf(fid, '`merge_threshold = min(1.5 deg, column_spacing_deg)`，当前 `column_spacing_deg = %.3f deg`，因此 `merge_threshold = %.3f deg`。\n\n', cfg88.columnSpacingDeg, cfg88.coarsePeakMergeThreshold_deg);
    fprintf(fid, '## 4. 第8.7 shared-center 输入 enhance_in\n\n');
    fprintf(fid, '第 8.7 shared-center 增强测角输入：`Y_work`、`thetaCenter_deg`、`elAssumed_deg`、`rangeIdx`、`dopplerIdx`、`R_runtime_default_deg`、`R_runtime_expand_deg`、`template_R_deg`、`cfg`、`arrayInfo`。\n\n');
    fprintf(fid, '- `R_runtime_default_deg = %.1f deg`\n', cfg88.R_runtime_default_deg);
    fprintf(fid, '- `R_runtime_expand_deg = %.1f deg`\n', cfg88.R_runtime_expand_deg);
    fprintf(fid, '- `template_R_deg = %.1f deg`\n', cfg88.template_R_deg);
    fprintf(fid, '- `Y_work` 的尺寸为 `65 x 32 x T_snap`，本轮 `T_snap=Np=%d`。\n\n', cfg88.Np);
    fprintf(fid, '## 5. Y_work 构造\n\n');
    fprintf(fid, '本轮优先使用 MTD 前慢时间快拍。理论形式为：\n\n');
    fprintf(fid, '`Y_elem(:, p) = pcCube(:, rangeIdx, p)`\n\n');
    fprintf(fid, '若目标有 Doppler，则按检测到的 Doppler bin 做去旋：\n\n');
    fprintf(fid, '`Y_elem(:, p) = pcCube(:, rangeIdx, p) * exp(-j*2*pi*fd_hat*tSlow(p))`\n\n');
    fprintf(fid, '随后按 `selectedWorkColumns` 抽取 65 列，并 reshape 为 `Y_work = [65, 32, T_snap]`。本轮脚本为节省运行时间，保存的是检测距离单元的阵元级快拍 `pc_like.Y_full_range`，它等价于 `pcCube(:, rangeIdx, :)`；完整全阵版本只需把该快拍替换为实际 `pcCube` 抽取。\n\n');
    fprintf(fid, '## 6. 一次观测双空间分量模型\n\n');
    fprintf(fid, '两个空间分量属于同一次观测、同一 CPI、同一距离-多普勒单元中的叠加：\n\n');
    fprintf(fid, '`x(t) = a(theta1, el1) s1(t) + a(theta2, el2) s2(t) + n(t)`\n\n');
    fprintf(fid, '`s2(t) = beta * exp(j*phi) * (rho*s1(t) + sqrt(1-rho^2)*v(t))`\n\n');
    fprintf(fid, '- `rho=1` 表示完全相干，`rho<1` 表示部分相干。\n');
    fprintf(fid, '- `beta` 表示幅度比，`phi` 表示固定相位差。\n');
    fprintf(fid, '- 前端 LFM/脉压/MTD 将叠加信号定位到一个 RD 检测单元。\n');
    fprintf(fid, '- 第 8.7 只作为该检测单元内的 shared-center 增强测角模块。\n\n');
    fprintf(fid, '## 7. 推荐前端策略\n\n');
    fprintf(fid, '- single coarse peak -> shared_center_enhancement\n');
    fprintf(fid, '- two close coarse peaks -> merge_candidate_or_future_validation\n');
    fprintf(fid, '- two separated coarse peaks -> front-end multi-target branch / out-of-scope\n');
    fprintf(fid, '- weak secondary peak -> low-confidence secondary candidate\n');
end

function write_record_doc_local(path_out, keypoints_tbl, summary_tbl, result_dir, elapsed_sec, Metkl, quick_mode)
    fid = fopen(path_out, 'w', 'n', 'UTF-8');
    cleaner = onCleanup(@() safe_fclose_local(fid));
    if quick_mode
        fprintf(fid, '# 第8.8步 前端检测到shared-center增强测角接口与闭环验证记录（quick mode，仅 smoke test）\n\n');
    else
        fprintf(fid, '# 第8.8步 前端检测到shared-center增强测角接口与闭环验证记录\n\n');
    end
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 脚本：`space_smooth_music_B_frontend_shared_center_closure.m`\n');
    fprintf(fid, '- 短名 runner：`frontend_shared_center_closure.m`\n');
    fprintf(fid, '- 状态整理检查结果目录：`%s`\n', result_dir);
    fprintf(fid, '- 原始结果目录 `results_step8_8_frontend_shared_center_closure/` 未覆盖。\n');
    fprintf(fid, '- Metkl=%d，quick_mode=%d。\n', Metkl, quick_mode);
    if quick_mode
        fprintf(fid, '- quick mode 仅用于 smoke test，不作为正式统计结论。\n');
    end
    fprintf(fid, '- 本轮只做文档和状态机输出整理，不改第 8.7 lazy cascade，不改阈值，不改第 8.8 数据生成、CFAR 或 coarse detector 主逻辑。\n\n');
    fprintf(fid, '## 主链路定位\n\n');
    fprintf(fid, '- 第 1/2 步的 LFM 和脉压负责距离维压缩。\n');
    fprintf(fid, '- 第 5 步的 MTD/CFAR 负责检测距离-多普勒单元。\n');
    fprintf(fid, '- 第 6 步的三波束比幅负责提供 coarse az/el。\n');
    fprintf(fid, '- 第 8.7 只作为某个检测单元内的 shared-center 增强测角模块。\n\n');
    fprintf(fid, '## 默认适用场景\n\n');
    fprintf(fid, '第 8.8 默认处理的是 `single coarse peak / unresolved local cluster`：前端在某个距离-多普勒单元或局部角域中检测到一个粗峰，该粗峰可能对应一个真实目标，也可能包含两个相干或近邻空间分量。系统以该粗峰方位吸附最近实际阵元列，选择 65 列工作子阵，再进入第 8.7 shared-center lazy cascade。\n\n');
    fprintf(fid, '如果角度粗扫描已经出现两个稳定粗峰，则该场景不进入本文默认 shared-center 主线，而标记为 `multi-coarse-peak / out-of-scope`，交给前端多目标分支、上层跟踪、后续 CPI 调度或未来工作。本轮不做 dual-center，也不把 two coarse peaks 强行塞入 shared-center。\n\n');
    fprintf(fid, '## 前端状态机\n\n');
    fprintf(fid, '- `single_peak_in_scope`：单粗峰，默认进入 shared-center 增强测角。\n');
    fprintf(fid, '- `two_close_peaks_merge_candidate`：双粗峰距离小于 `merge_threshold`，只作为合并候选或未来验证状态；若原脚本已有合并逻辑，则保持原 shared-center 验证路径。\n');
    fprintf(fid, '- `two_separated_peaks_out_of_scope`：双粗峰距离大于等于 `merge_threshold`，作为前端多目标迹象标记，不进入默认 shared-center 主线。\n');
    fprintf(fid, '- `weak_secondary_candidate`：第二峰弱或不稳定，仅作为低置信二级候选标签。\n');
    fprintf(fid, '- `no_valid_coarse_peak`：CFAR 未形成有效检测或中心列无效。\n\n');
    fprintf(fid, '`merge_threshold = min(1.5 deg, column_spacing_deg)`，当前为 1.5 deg。\n\n');
    fprintf(fid, '## two coarse peaks 论文说明\n\n');
    fprintf(fid, '本轮第 8.8 正式结果中 two coarse peak out-of-scope rate 约为 0.083。该比例不高，但需要明确算法适用边界。本文默认增强测角链路只对 `single coarse peak / unresolved local cluster` 启动；two coarse peaks 表示前端角度粗检测已具有多目标迹象，当前不强行并入 shared-center 主线。\n\n');
    fprintf(fid, '## weak target 标签说明\n\n');
    fprintf(fid, 'weak target 场景中当前 false-high=0，说明未出现高置信错误输出；但 low-confidence 标记并不总是稳定触发，因此弱目标仍作为边界场景，后续可优化 failure_reason / confidence calibration。该现象不应解释为选列失败。\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.6g | %s |\n', keypoints_tbl.keypoint(i), keypoints_tbl.value(i), keypoints_tbl.note(i));
    end
    fprintf(fid, '\n## Scenario summary\n\n');
    fprintf(fid, '| scenario | CFAR | single coarse | two coarse | in-scope | out-scope | R15 | R20 | success | false-high | boundary-missed | low-conf |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary_tbl)
        fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
            summary_tbl.scenario_name(i), summary_tbl.cfar_detection_rate(i), summary_tbl.single_coarse_peak_rate(i), ...
            summary_tbl.two_coarse_peak_rate(i), summary_tbl.in_scope_shared_center_rate(i), summary_tbl.out_of_scope_rate(i), ...
            summary_tbl.both_inside_R15_rate(i), summary_tbl.both_inside_R20_rate(i), ...
            summary_tbl.step87_success_rate(i), summary_tbl.false_high_rate(i), summary_tbl.boundary_missed_rate(i), ...
            summary_tbl.low_confidence_rate(i));
    end
    fprintf(fid, '\n## Frontend state summary\n\n');
    fprintf(fid, '| scenario | single_peak_in_scope | two_close_merge_candidate | two_separated_out_of_scope | weak_secondary_candidate | multi_coarse_total | false_high_in_scope | boundary_missed_in_scope | false_high_out_scope |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary_tbl)
        fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
            summary_tbl.scenario_name(i), summary_tbl.single_peak_in_scope_rate(i), ...
            summary_tbl.two_close_peaks_merge_candidate_rate(i), summary_tbl.two_separated_peaks_out_of_scope_rate(i), ...
            summary_tbl.weak_secondary_candidate_rate(i), summary_tbl.multi_coarse_peak_total_rate(i), ...
            summary_tbl.false_high_rate_in_scope(i), summary_tbl.boundary_missed_rate_in_scope(i), ...
            summary_tbl.false_high_rate_out_of_scope(i));
    end
    fprintf(fid, '\n## 判断\n\n');
    fh = keypoint_value_from_table_local(keypoints_tbl, 'false_high_rate_overall');
    bm = keypoint_value_from_table_local(keypoints_tbl, 'boundary_missed_rate_overall');
    iface = keypoint_value_from_table_local(keypoints_tbl, 'frontend_to_step87_interface_pass_flag');
    if iface == 1 && fh == 0 && bm == 0
        fprintf(fid, '结论：前端检测到第 8.7 shared-center 增强测角接口基本闭合。默认主线仍是 `single coarse peak / unresolved local cluster`。two coarse peaks 明确作为 out-of-scope 或 merge candidate 状态标记，不触发 dual-center。弱目标边界保持 false-high=0，但当前观测量不总是降为 low confidence；近反相边界主要由 two-coarse-peaks out-of-scope、low_confidence 或 boundary_unreliable 保护。本轮不解决弱目标和近反相问题。\n\n');
    else
        fprintf(fid, '结论：接口已跑通，但需要优先复核 CFAR、粗峰或安全指标后再进入后续工程阶段。\n\n');
    end
    fprintf(fid, '推荐前端策略：single coarse peak -> shared_center_enhancement；two close coarse peaks -> merge_candidate_or_future_validation；two separated coarse peaks -> front-end multi-target branch / out-of-scope；weak secondary peak -> low-confidence secondary candidate。\n\n');
    fprintf(fid, '- elapsed_sec=%.2f\n', elapsed_sec);
end

function val = keypoint_value_from_table_local(tbl, key)
    idx = strcmp(string(tbl.keypoint), string(key));
    if any(idx)
        val = tbl.value(find(idx, 1));
    else
        val = NaN;
    end
end

function result = run_level2_music_route_local( ...
    y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, el_assumed, az_grid, K_phi, Lc)
    y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_assumed);
    Rfb = level2_fbss_cov_local(y_combined, K_phi);
    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_assumed, el_assumed);
    sub_cache = make_subarray_steer_cache_local(B_grid, K_phi);
    p0 = ceil(sub_cache.P_phi / 2);
    A = sub_cache.A_forward(:, :, p0);
    [V, D] = eig(0.5 * (Rfb + Rfb'));
    [~, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    evals = real(diag(D));
    evals = evals(ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(A) .* (Cn * A), 1));
    spectrum = 1 ./ max(den, eps);
    peaks = find_1d_peaks_local(spectrum, az_grid, Lc);
    result = make_result_local(peaks.az_est, [el_assumed, el_assumed], peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum_1d = spectrum;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.spectrum_width = peaks.spectrum_width;
    result.pair_sep_est = peaks.peak_separation_az;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, result.lambda2_over_noise, ...
        result.lambda2_over_lambda1, result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_bank, K_phi, candidate_pairs)
    cache_map = struct([]);
    for ie = 1:numel(el_bank)
        B = build_level2_combined_az_steer_grid_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_bank(ie), el_bank(ie));
        sub_cache = make_subarray_steer_cache_local(B, K_phi);
        precomp = precompute_rank1_pair_bases_local(sub_cache, candidate_pairs);
        cache_map(ie).el = el_bank(ie);
        cache_map(ie).sub_cache = sub_cache;
        cache_map(ie).precomp = precomp;
    end
end

function result = run_level2_rank1_route_local( ...
    y_noisy_2d, Z3d, lambda, el_assumed, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    [~, idx] = min(abs([cache_map.el] - el_assumed));
    y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, cache_map(idx).el);
    Rfb = level2_fbss_cov_local(y_combined, K_phi);
    result = score_level2_cache_local(Rfb, cache_map(idx), az_grid, theta_true);
    result.el_est = [cache_map(idx).el, cache_map(idx).el];
    result.peak_count = 2;
    result.failure_reason = failure_reason_pair_local(result.az_est, result.el_est, min_sep, max_sep);
end

function result = score_level2_cache_local(Rfb, cache, az_grid, theta_true)
    score = score_rank1_all_local(Rfb, cache.precomp);
    [best_score, best_idx] = min(score);
    score2 = second_score_local(score, best_idx);
    pair_idx = cache.precomp.candidate_pairs(best_idx, :);
    true_precomp = precompute_rank1_pair_bases_local(cache.sub_cache, nearest_pair_indices_local(az_grid, theta_true));
    true_score = score_rank1_all_local(Rfb, true_precomp);
    result = make_result_local(sort(az_grid(pair_idx)), [NaN, NaN], 2, best_score, true_score(1), 'ok');
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est));
end

function result = run_common_el_refocus_power_route_local( ...
    y_noisy_2d, Z3d, lambda, el_grid, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    n = numel(el_grid);
    power_curve = zeros(1, n);
    lambda1_curve = zeros(1, n);
    for ie = 1:n
        y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_grid(ie));
        power_curve(ie) = mean(abs(y_combined(:)).^2);
        Rfb = level2_fbss_cov_local(y_combined, K_phi);
        lambda1_curve(ie) = max(real(eig(0.5 * (Rfb + Rfb'))));
    end
    [~, idx] = max(power_curve);
    el_hat = el_grid(idx);
    result = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, el_hat, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep);
    result.el_hat = el_hat;
    result.el_est = [el_hat, el_hat];
    result.el_common_est = el_hat;
    result.el_selection_method = "focused_power";
    result.focused_power_peak_sharpness = peak_sharpness_local(power_curve);
    result.lambda1_peak_sharpness = peak_sharpness_local(lambda1_curve);
    result.rank1_objective_valley_width_el = NaN;
    result.rank1_objective_selected_el_rank = NaN;
    result.power_curve = power_curve;
    result.lambda1_curve = lambda1_curve;
    result.el_grid = el_grid;
end

function sharpness = peak_sharpness_local(curve)
    curve = real(curve(:));
    [mx, idx] = max(curve);
    tmp = curve;
    tmp(idx) = -inf;
    second = max(tmp);
    sharpness = (mx - second) / max(abs(mx), eps);
end

function y_combined = combine_layers_level2_local(y_2d, Z3d, lambda, el_assumed_deg)
    Nel = size(y_2d, 2);
    z_col = Z3d(1, :).';
    steer_el = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    W = steer_el' / sqrt(Nel);
    tmp = W * reshape(permute(y_2d, [2, 1, 3]), Nel, []);
    y_combined = reshape(tmp, size(y_2d, 1), size(y_2d, 3));
end

function Rfb = level2_fbss_cov_local(y_combined, K_phi)
    Rxx = y_combined * y_combined' / size(y_combined, 2);
    Rxx = 0.5 * (Rxx + Rxx');
    Rfb = mssp_array_fb_local(Rxx, K_phi);
    Rfb = 0.5 * (Rfb + Rfb');
end

function b = build_level2_combined_az_steer_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg, el_assumed_deg)
    Nel = size(X3d, 2);
    a_norm = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg);
    z_col = Z3d(1, :).';
    a_z = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    w_z = a_z / sqrt(Nel);
    b = (w_z' * a_norm.').';
    b = b / max(norm(b), eps);
end

function B_grid = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid, el_scan_deg, el_assumed_deg)
    B_grid = zeros(size(X3d, 1), numel(angle_grid));
    for ia = 1:numel(angle_grid)
        B_grid(:, ia) = build_level2_combined_az_steer_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid(ia), el_scan_deg, el_assumed_deg);
    end
end

function A = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_deg)
    k = 2*pi / lambda;
    phase = X3d * (cosd(el_deg) * cosd(az_deg)) + ...
        Y3d * (cosd(el_deg) * sind(az_deg)) + Z3d * sind(el_deg);
    A = conj(A_ref_2d) .* exp(-1j * k * phase);
end

function cache = make_subarray_steer_cache_local(B_grid, K_phi)
    Q = size(B_grid, 1);
    ngrid = size(B_grid, 2);
    P_phi = Q - K_phi + 1;
    J = fliplr(eye(K_phi));
    A_forward = complex(zeros(K_phi, ngrid, P_phi));
    for p = 1:P_phi
        A_forward(:, :, p) = normalize_columns_local(B_grid(p:p+K_phi-1, :));
    end
    cache = struct('K_phi', K_phi, 'P_phi', P_phi, 'J', J, 'A_forward', A_forward);
end

function result = run_level3_2d_music_route_local(Rfb, grid_cache, Lc)
    [V, D] = eig(0.5 * (Rfb + Rfb'));
    [~, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    evals = real(diag(D));
    evals = evals(ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(grid_cache.A_center) .* (Cn * grid_cache.A_center), 1));
    P = reshape(1 ./ max(den, eps), numel(grid_cache.az_grid), numel(grid_cache.el_grid));
    peaks = find_2d_peaks_local(P, grid_cache.az_grid, grid_cache.el_grid, Lc);
    result = make_result_local(peaks.az_est, peaks.el_est, peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum = P;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_separation_el = peaks.peak_separation_el;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.global_peak_el = peaks.global_peak_el;
    result.two_peak_flag = peaks.two_peak_flag;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, result.lambda2_over_noise, ...
        result.lambda2_over_lambda1, result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function Rfb = level3_fbss_cov_from_observation_local(y_2d, K_phi, K_z)
    [Q, Nel, T_snap] = size(y_2d);
    P_phi = Q - K_phi + 1;
    P_z = Nel - K_z + 1;
    K = K_phi * K_z;
    Rf = complex(zeros(K, K));
    for p = 1:P_phi
        for r = 1:P_z
            Y = reshape(y_2d(p:p+K_phi-1, r:r+K_z-1, :), K, T_snap);
            Rf = Rf + (Y * Y') / T_snap;
        end
    end
    Rf = Rf / (P_phi * P_z);
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Rfb = 0.5 * (Rf + J * conj(Rf) * J);
    Rfb = 0.5 * (Rfb + Rfb');
end

function Rfb = level3_fbss_cov_selected_from_observation_local(y_2d, K_phi, K_z, p_sel, r_sel)
    T_snap = size(y_2d, 3);
    K = K_phi * K_z;
    Rf = complex(zeros(K, K));
    count = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            p = p_sel(ip);
            r = r_sel(ir);
            Y = reshape(y_2d(p:p+K_phi-1, r:r+K_z-1, :), K, T_snap);
            Rf = Rf + (Y * Y') / T_snap;
            count = count + 1;
        end
    end
    Rf = Rf / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Rfb = 0.5 * (Rf + J * conj(Rf) * J);
    Rfb = 0.5 * (Rfb + Rfb');
end

function result = run_level3_pair_el_local_rank1_covfit_local( ...
    Rfb, music_result, X3d, Y3d, Z3d, A_ref_2d, lambda, K_phi, K_z, p_sel, r_sel, theta_true, el_true, min_sep, max_sep)
    if any(~isfinite(music_result.az_est)) || music_result.peak_count < 2
        result = make_result_local([NaN, NaN], [NaN, NaN], music_result.peak_count, NaN, NaN, 'no_2d_peaks');
        return
    end
    candidates = make_pair_el_local_candidates_local(music_result.az_est, music_result.el_est, min_sep, max_sep);
    scores = zeros(size(candidates, 1), 1);
    for ic = 1:size(candidates, 1)
        G = build_level3_rank1_model_fbss_selected_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, candidates(ic, 1:2), candidates(ic, 3:4), ...
            1, 0, K_phi, K_z, p_sel, r_sel);
        scores(ic) = solve_covfit_score_local(Rfb, G);
    end
    [best_score, best_idx] = min(scores);
    score2 = second_score_local(scores, best_idx);
    true_idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true);
    true_score = scores(true_idx);
    best = candidates(best_idx, :);
    result = make_result_local(sort(best(1:2)), best(3:4), 2, best_score, true_score, 'ok');
    [result.az_est, order] = sort(best(1:2));
    result.el_est = best(2 + order);
    result.objective_true_rank = 1 + sum(scores < true_score);
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est)) && all(isfinite(result.el_est));
    result.pair_local_confidence_proxy = result.score_gap_ratio / max(1 + result.residual_norm, eps);
end

function Gfb = build_level3_rank1_model_fbss_selected_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair, el_pair, beta, phi_deg, K_phi, K_z, p_sel, r_sel)
    A1 = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(1), el_pair(1));
    A2 = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(2), el_pair(2));
    q = beta * exp(1j * deg2rad(phi_deg));
    K = K_phi * K_z;
    G = complex(zeros(K, K));
    count = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            p = p_sel(ip);
            r = r_sel(ir);
            a1 = A1(p:p+K_phi-1, r:r+K_z-1);
            a2 = A2(p:p+K_phi-1, r:r+K_z-1);
            c = a1(:) / max(norm(a1(:)), eps) + q * a2(:) / max(norm(a2(:)), eps);
            G = G + c * c';
            count = count + 1;
        end
    end
    G = G / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Gfb = 0.5 * (G + J * conj(G) * J);
    Gfb = 0.5 * (Gfb + Gfb');
end

function grid_cache = make_level3_grid_cache_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_grid, K_phi, K_z)
    p0 = floor((size(X3d, 1) - K_phi) / 2) + 1;
    r0 = floor((size(X3d, 2) - K_z) / 2) + 1;
    K = K_phi * K_z;
    A = complex(zeros(K, numel(az_grid) * numel(el_grid)));
    idx = 0;
    for ie = 1:numel(el_grid)
        for ia = 1:numel(az_grid)
            idx = idx + 1;
            Afull = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid(ia), el_grid(ie));
            sub = Afull(p0:p0+K_phi-1, r0:r0+K_z-1);
            A(:, idx) = sub(:) / max(norm(sub(:)), eps);
        end
    end
    grid_cache = struct('az_grid', az_grid, 'el_grid', el_grid, 'K_phi', K_phi, 'K_z', K_z, 'A_center', A);
end

function [p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi, K_z)
    p_all = 1:(Q - K_phi + 1);
    r_all = 1:(Nel - K_z + 1);
    p_sel = unique(round(linspace(1, numel(p_all), 7)));
    r_sel = unique(round(linspace(1, numel(r_all), 5)));
    p_sel = p_all(p_sel);
    r_sel = r_all(r_sel);
end

function candidates = make_pair_el_local_candidates_local(az_est, el_est, min_sep, max_sep)
    az1 = az_est(1) + [-0.04, 0, 0.04];
    az2 = az_est(2) + [-0.04, 0, 0.04];
    el1 = el_est(1) + [-0.5, 0, 0.5];
    el2 = el_est(2) + [-0.5, 0, 0.5];
    candidates = zeros(numel(az1)*numel(az2)*numel(el1)*numel(el2), 4);
    count = 0;
    for i1 = 1:numel(az1)
        for i2 = 1:numel(az2)
            th = sort([az1(i1), az2(i2)]);
            sep = diff(th);
            if sep < min_sep || sep > max_sep
                continue
            end
            for e1 = 1:numel(el1)
                for e2 = 1:numel(el2)
                    count = count + 1;
                    candidates(count, :) = [th, el1(e1), el2(e2)];
                end
            end
        end
    end
    candidates = candidates(1:count, :);
end

function idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true)
    if isempty(candidates)
        idx = 1;
        return
    end
    truth = [theta_true(:).', el_true(:).'];
    d = sum((candidates - truth).^2, 2);
    [~, idx] = min(d);
end

function peaks = find_2d_peaks_local(P, az_axis, el_axis, Lc)
    Pwork = real(P);
    mask = false(size(Pwork));
    for ia = 2:size(Pwork, 1)-1
        for ie = 2:size(Pwork, 2)-1
            win = Pwork(ia-1:ia+1, ie-1:ie+1);
            mask(ia, ie) = Pwork(ia, ie) == max(win(:)) && Pwork(ia, ie) > median(win(:));
        end
    end
    idx = find(mask);
    vals = Pwork(idx);
    [~, ord] = sort(vals, 'descend');
    idx = idx(ord);
    peak_count = numel(idx);
    az_est = nan(1, Lc);
    el_est = nan(1, Lc);
    if peak_count >= Lc
        [ia, ie] = ind2sub(size(Pwork), idx(1:Lc));
        az_est = az_axis(ia);
        el_est = el_axis(ie);
        [az_est, order] = sort(az_est);
        el_est = el_est(order);
        reason = 'ok';
    else
        reason = 'peak_count_lt_2';
    end
    peak_vals = vals(:).';
    if numel(peak_vals) >= 2
        peak_prominence_ratio = peak_vals(2) / max(peak_vals(1), eps);
    else
        peak_prominence_ratio = 0;
    end
    if numel(az_est) >= 2 && all(isfinite(az_est))
        peak_separation_az = diff(sort(az_est));
        peak_separation_el = abs(diff(el_est));
        two_peak_flag = true;
    else
        peak_separation_az = NaN;
        peak_separation_el = NaN;
        two_peak_flag = false;
    end
    if isempty(idx)
        global_peak_el = NaN;
    else
        [~, ie0] = ind2sub(size(Pwork), idx(1));
        global_peak_el = el_axis(ie0);
    end
    peaks = struct('az_est', az_est, 'el_est', el_est, 'peak_count', peak_count, ...
        'failure_reason', reason, 'peak_separation_az', peak_separation_az, ...
        'peak_separation_el', peak_separation_el, 'peak_prominence_ratio', peak_prominence_ratio, ...
        'global_peak_el', global_peak_el, 'two_peak_flag', two_peak_flag);
end

function peaks = find_1d_peaks_local(P, az_axis, Lc)
    Pwork = real(P(:)).';
    idx = [];
    for ii = 2:numel(Pwork)-1
        if Pwork(ii) >= Pwork(ii-1) && Pwork(ii) >= Pwork(ii+1) && Pwork(ii) > median(Pwork)
            idx(end+1) = ii; %#ok<AGROW>
        end
    end
    if isempty(idx)
        [~, imax] = max(Pwork);
        idx = imax;
    end
    [~, ord] = sort(Pwork(idx), 'descend');
    idx = idx(ord);
    peak_count = numel(idx);
    az_est = nan(1, Lc);
    if peak_count >= Lc
        az_est = sort(az_axis(idx(1:Lc)));
        reason = 'ok';
    else
        reason = 'peak_count_lt_2';
    end
    peak_vals = Pwork(idx);
    if numel(peak_vals) >= 2
        peak_prominence_ratio = peak_vals(2) / max(peak_vals(1), eps);
    else
        peak_prominence_ratio = 0;
    end
    if numel(az_est) >= 2 && all(isfinite(az_est))
        peak_separation_az = diff(sort(az_est));
    else
        peak_separation_az = NaN;
    end
    mask = Pwork >= 0.5 * max(Pwork);
    if any(mask)
        spectrum_width = az_axis(find(mask, 1, 'last')) - az_axis(find(mask, 1, 'first'));
    else
        spectrum_width = NaN;
    end
    peaks = struct('az_est', az_est, 'peak_count', peak_count, 'failure_reason', reason, ...
        'peak_separation_az', peak_separation_az, 'peak_prominence_ratio', peak_prominence_ratio, ...
        'spectrum_width', spectrum_width);
end

function score2 = second_score_local(score, best_idx)
    if isempty(score)
        score2 = NaN;
        return
    end
    mask = true(size(score));
    mask(best_idx) = false;
    if any(mask)
        score2 = min(score(mask));
    else
        score2 = score(best_idx);
    end
end

function [lambda1, lambda2, lambda_noise_mean, lambda2_over_noise, lambda2_over_lambda1, effective_rank_proxy] = eigen_proxy_from_vals_local(evals)
    evals = real(evals(:));
    evals = max(evals, 0);
    if isempty(evals)
        lambda1 = NaN; lambda2 = NaN; lambda_noise_mean = NaN;
        lambda2_over_noise = NaN; lambda2_over_lambda1 = NaN; effective_rank_proxy = NaN;
        return
    end
    lambda1 = evals(min(1, numel(evals)));
    lambda2 = evals(min(2, numel(evals)));
    if numel(evals) >= 3
        lambda_noise_mean = mean(evals(3:end));
    else
        lambda_noise_mean = mean(evals);
    end
    lambda2_over_noise = lambda2 / max(lambda_noise_mean, eps);
    lambda2_over_lambda1 = lambda2 / max(lambda1, eps);
    effective_rank_proxy = (sum(evals)^2) / max(sum(evals.^2), eps);
end

function result = apply_observable_dispatch_rule_local(route_map, min_sep, max_sep)
    music = route_map.music;
    rank1 = route_map.rank1_fallback;
    refocus = route_map.common_el_refocus_rank1;
    music2d = route_map.level3_2d_music;
    pair2d = route_map.pair_el_local_covfit;
    music2d_ok = is_music2d_reliable_local(music2d, min_sep, max_sep);
    pair_ok = is_pair_route_reliable_local(pair2d, min_sep, max_sep);
    music_ok = is_level2_music_reliable_local(music, min_sep, max_sep);
    refocus_ok = is_refocus_route_reliable_local(refocus, min_sep, max_sep);
    rank1_ok = is_rank1_route_reliable_local(rank1, min_sep, max_sep);
    route_conflict = has_route_conflict_local(route_map);
    boundary_proxy = is_boundary_unreliable_local(route_map, min_sep, max_sep);
    if music2d_ok && pair_ok
        result = pair2d;
        result.recommended_route = "pair_el_local_covfit";
        if is_pair_route_high_confidence_local(pair2d, music2d, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "ok";
    elseif music2d_ok
        result = music2d;
        result.recommended_route = "level3_2d_music";
        result.confidence_flag = "medium";
        result.failure_reason = "ok";
    elseif music_ok
        result = music;
        result.recommended_route = "level2_music_or_center_real";
        if is_level2_music_high_confidence_local(music, route_map, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        if route_conflict
            result.failure_reason = "route_conflict";
        else
            result.failure_reason = "ok";
        end
    elseif boundary_proxy
        result = make_boundary_result_local(route_map, 'boundary_unreliable', 'low', 'boundary_unreliable', false, false);
    elseif refocus_ok
        result = refocus;
        result.recommended_route = "common_el_refocus_power_rank1";
        if is_refocus_route_high_confidence_local(refocus, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        if route_conflict
            result.failure_reason = "route_conflict";
        else
            result.failure_reason = "ok";
        end
    elseif rank1_ok
        result = rank1;
        result.recommended_route = "level2_rank1_fallback";
        if is_rank1_route_high_confidence_local(rank1, min_sep, max_sep) && ~route_conflict
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "music_single_rank1_fallback";
    else
        result = make_boundary_result_local(route_map, 'low_confidence', 'low', 'boundary_unreliable', false, false);
    end
    result.weak_target_boundary_flag = false;
    result.anti_phase_boundary_flag = false;
    result.low_confidence_flag = strcmp(result.confidence_flag, "low") || ...
        any(strcmp(result.recommended_route, ["low_confidence", "boundary_unreliable"]));
end

function ok = is_level2_music_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'peak_separation_az', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    width = getfield_default_local(result, 'spectrum_width', NaN);
    l2n = getfield_default_local(result, 'lambda2_over_noise', NaN);
    ok = result.peak_count >= 2 && all(isfinite(result.az_est)) && isfinite(sep) && ...
        sep >= min_sep && sep <= max_sep && isfinite(prom) && prom >= 0.55 && ...
        (~isfinite(width) || width <= 0.45) && (~isfinite(l2n) || l2n >= 1.10);
end

function ok = is_music2d_reliable_local(result, min_sep, max_sep)
    sep_az = getfield_default_local(result, 'peak_separation_az', NaN);
    sep_el = getfield_default_local(result, 'peak_separation_el', NaN);
    max_el = max(abs(getfield_default_local(result, 'el_est', [NaN, NaN])));
    ok = result.peak_count >= 2 && all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep_az) && isfinite(sep_el) && sep_az >= min_sep && sep_az <= max_sep && ...
        sep_el >= 1.0 && isfinite(max_el) && max_el >= 1.0;
end

function ok = is_rank1_route_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    gap = getfield_default_local(result, 'score_gap_ratio', NaN);
    ok = all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep) && sep >= min_sep && sep <= max_sep && ...
        isfinite(residual) && residual < 2e-3 && isfinite(gap) && gap >= 2e-3;
end

function ok = is_refocus_route_reliable_local(result, min_sep, max_sep)
    sharp = getfield_default_local(result, 'focused_power_peak_sharpness', NaN);
    lambda_sharp = getfield_default_local(result, 'lambda1_peak_sharpness', NaN);
    ok = is_rank1_route_reliable_local(result, min_sep, max_sep) && ...
        isfinite(sharp) && sharp >= 0.03 && isfinite(lambda_sharp) && lambda_sharp >= 0.03;
end

function ok = is_pair_route_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    max_el = max(abs(getfield_default_local(result, 'el_est', [NaN, NaN])));
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    ok = all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep) && sep >= min_sep && sep <= max_sep && ...
        isfinite(residual) && residual < 0.05 && isfinite(max_el) && max_el >= 1.0 && ...
        (~isfinite(prom) || prom >= 0.45);
end

function ok = is_level2_music_high_confidence_local(result, route_map, min_sep, max_sep)
    width = getfield_default_local(result, 'spectrum_width', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    l2n = getfield_default_local(result, 'lambda2_over_noise', NaN);
    l21 = getfield_default_local(result, 'lambda2_over_lambda1', NaN);
    refocus = route_map.common_el_refocus_rank1;
    refocus_gap = getfield_default_local(refocus, 'score_gap_ratio', NaN);
    ok = is_level2_music_reliable_local(result, min_sep, max_sep) && ...
        isfinite(prom) && prom >= 0.82 && (~isfinite(width) || width <= 0.24) && ...
        (~isfinite(l2n) || l2n >= 1.35) && (~isfinite(l21) || l21 >= 0.18) && ...
        (~isfinite(refocus_gap) || refocus_gap >= 2e-3);
end

function ok = is_rank1_route_high_confidence_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    gap = getfield_default_local(result, 'score_gap_ratio', NaN);
    ok = is_rank1_route_reliable_local(result, min_sep, max_sep) && ...
        isfinite(residual) && residual < 7e-4 && isfinite(gap) && gap >= 1e-2 && ...
        ~is_sep_edge_local(sep, min_sep, max_sep, 0.015);
end

function ok = is_refocus_route_high_confidence_local(result, min_sep, max_sep)
    sharp = getfield_default_local(result, 'focused_power_peak_sharpness', NaN);
    lambda_sharp = getfield_default_local(result, 'lambda1_peak_sharpness', NaN);
    ok = is_rank1_route_high_confidence_local(result, min_sep, max_sep) && ...
        isfinite(sharp) && sharp >= 0.09 && isfinite(lambda_sharp) && lambda_sharp >= 0.09;
end

function ok = is_pair_route_high_confidence_local(result, music2d_result, min_sep, max_sep)
    proxy = getfield_default_local(result, 'pair_local_confidence_proxy', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    sep_el = getfield_default_local(music2d_result, 'peak_separation_el', NaN);
    prom = getfield_default_local(music2d_result, 'peak_prominence_ratio', NaN);
    ok = is_pair_route_reliable_local(result, min_sep, max_sep) && ...
        isfinite(proxy) && proxy >= 0.12 && isfinite(residual) && residual < 0.02 && ...
        isfinite(sep_el) && sep_el >= 1.5 && isfinite(prom) && prom >= 0.55;
end

function tf = is_boundary_unreliable_local(route_map, min_sep, max_sep)
    music = route_map.music;
    rank1 = route_map.rank1_fallback;
    refocus = route_map.common_el_refocus_rank1;
    music2d = route_map.level3_2d_music;
    pair2d = route_map.pair_el_local_covfit;
    no_reliable_2d = ~is_music2d_reliable_local(music2d, min_sep, max_sep) && ...
        ~is_pair_route_reliable_local(pair2d, min_sep, max_sep);
    music_single = music.peak_count < 2 || any(~isfinite(music.az_est));
    rank1_finite = all(isfinite(rank1.az_est)) && all(isfinite(rank1.el_est));
    rank1_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    rank1_sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    refocus_sharp = min( ...
        getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    route_conflict = has_route_conflict_local(route_map);
    strong_single_peak = music.peak_count < 2 && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;
    weak_rank1 = (~isfinite(rank1_gap) || rank1_gap < 5e-3) && ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3);
    sep_edge = is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;
    tf = (no_reliable_2d && music_single && rank1_finite && weak_rank1) || ...
        (no_reliable_2d && music_single && rank1_finite && sep_edge) || ...
        (no_reliable_2d && strong_single_peak && refocus_unsharp) || ...
        (no_reliable_2d && route_conflict && ~is_level2_music_reliable_local(music, min_sep, max_sep));
end

function tf = has_route_conflict_local(route_map)
    az_list = {};
    route_fields = {'music', 'rank1_fallback', 'common_el_refocus_rank1', 'level3_2d_music', 'pair_el_local_covfit'};
    for i = 1:numel(route_fields)
        now = route_map.(route_fields{i});
        az_est = getfield_default_local(now, 'az_est', [NaN, NaN]);
        if numel(az_est) >= 2 && all(isfinite(az_est))
            az_list{end+1} = sort(az_est(:)).'; %#ok<AGROW>
        end
    end
    tf = false;
    if numel(az_list) < 2
        return
    end
    for i = 1:numel(az_list)-1
        for j = (i+1):numel(az_list)
            if max(abs(az_list{i} - az_list{j})) > 0.14
                tf = true;
                return
            end
        end
    end
end

function tf = is_sep_edge_local(sep, min_sep, max_sep, edge_margin)
    tf = ~isfinite(sep) || sep <= (min_sep + edge_margin) || sep >= (max_sep - edge_margin);
end

function result = make_boundary_result_local(route_map, route_name, confidence, reason, weak_flag, anti_flag)
    fallback = route_map.music;
    result = make_result_local(fallback.az_est, fallback.el_est, fallback.peak_count, NaN, NaN, reason);
    result.recommended_route = string(route_name);
    result.confidence_flag = string(confidence);
    result.failure_reason = string(reason);
    result.weak_target_boundary_flag = weak_flag;
    result.anti_phase_boundary_flag = anti_flag;
    result.low_confidence_flag = true;
end

function candidate_pairs = make_pair_candidates_local(angle_grid, min_sep, max_sep)
    n = numel(angle_grid);
    candidate_pairs = zeros(n*n, 2);
    count = 0;
    for ii = 1:(n-1)
        sep_vec = angle_grid((ii+1):end) - angle_grid(ii);
        jj_rel = find(sep_vec >= min_sep & sep_vec <= max_sep);
        jj = jj_rel + ii;
        nadd = numel(jj);
        candidate_pairs(count+1:count+nadd, :) = [repmat(ii, nadd, 1), jj(:)];
        count = count + nadd;
    end
    candidate_pairs = candidate_pairs(1:count, :);
end

function pair_idx = nearest_pair_indices_local(grid, theta_pair)
    [~, i1] = min(abs(grid - theta_pair(1)));
    [~, i2] = min(abs(grid - theta_pair(2)));
    pair_idx = sort([i1, i2]);
    if pair_idx(1) == pair_idx(2)
        pair_idx(2) = min(pair_idx(1) + 1, numel(grid));
    end
end

function precomp = precompute_rank1_pair_bases_local(cache, candidate_pairs)
    K = cache.K_phi;
    P_phi = cache.P_phi;
    J = cache.J;
    Nc = size(candidate_pairs, 1);
    L = 2 * K * K;
    g_basis = zeros(L, Nc, 'single');
    gg = zeros(Nc, 1);
    gi = zeros(Nc, 1);
    ivec = matrix_to_realvec_local(eye(K));
    ii = real(ivec' * ivec);
    for ic = 1:Nc
        i1 = candidate_pairs(ic, 1);
        i2 = candidate_pairs(ic, 2);
        A1 = reshape(cache.A_forward(:, i1, :), K, P_phi);
        A2 = reshape(cache.A_forward(:, i2, :), K, P_phi);
        C = A1 + A2;
        F = (C * C') / P_phi;
        G = 0.5 * (F + J * conj(F) * J);
        v = matrix_to_realvec_local(G);
        g_basis(:, ic) = single(v);
        gg(ic) = real(v' * v);
        gi(ic) = real(v' * ivec);
    end
    precomp = struct('K_phi', K, 'P_phi', P_phi, 'candidate_pairs', candidate_pairs, ...
        'g_basis', g_basis, 'gg', gg, 'gi', gi, 'ivec', single(ivec), 'ii', ii);
end

function score = score_rank1_all_local(Robs, precomp)
    y = matrix_to_realvec_local(Robs);
    yy = real(y' * y);
    gy = double(precomp.g_basis' * single(y));
    iy = double(precomp.ivec' * single(y));
    gg = precomp.gg;
    gi = precomp.gi;
    ii = precomp.ii;
    detv = gg * ii - gi.^2;
    valid = abs(detv) > 1e-12;
    alpha = zeros(size(gg));
    sigma2 = zeros(size(gg));
    alpha(valid) = (gy(valid) * ii - gi(valid) * iy) ./ detv(valid);
    sigma2(valid) = (gg(valid) * iy - gi(valid) .* gy(valid)) ./ detv(valid);
    val_both = inf(size(gg));
    ok_both = valid & alpha >= 0 & sigma2 >= 0;
    val_both(ok_both) = -2*(alpha(ok_both).*gy(ok_both) + sigma2(ok_both)*iy) + ...
        alpha(ok_both).^2 .* gg(ok_both) + 2*alpha(ok_both).*sigma2(ok_both).*gi(ok_both) + sigma2(ok_both).^2 * ii;
    alpha_only = max(gy ./ max(gg, eps), 0);
    val_alpha = -2*alpha_only.*gy + alpha_only.^2 .* gg;
    sigma_only = max(iy / max(ii, eps), 0);
    val_sigma = -2*sigma_only*iy + sigma_only.^2 * ii;
    val_zero = zeros(size(gg));
    best_delta = min([val_both, val_alpha, repmat(val_sigma, size(gg)), val_zero], [], 2);
    score = max(yy + best_delta, 0) / max(yy, eps);
end

function score = solve_covfit_score_local(Robs, G)
    y = matrix_to_realvec_local(Robs);
    g = matrix_to_realvec_local(G);
    ivec = matrix_to_realvec_local(eye(size(Robs)));
    yy = real(y' * y);
    gg = real(g' * g);
    gi = real(g' * ivec);
    ii = real(ivec' * ivec);
    gy = real(g' * y);
    iy = real(ivec' * y);
    detv = gg * ii - gi^2;
    vals = zeros(4, 1);
    if abs(detv) > 1e-12
        alpha = (gy * ii - gi * iy) / detv;
        sigma2 = (gg * iy - gi * gy) / detv;
        if alpha >= 0 && sigma2 >= 0
            vals(1) = -2*(alpha*gy + sigma2*iy) + alpha^2*gg + 2*alpha*sigma2*gi + sigma2^2*ii;
        else
            vals(1) = inf;
        end
    else
        vals(1) = inf;
    end
    alpha_only = max(gy / max(gg, eps), 0);
    vals(2) = -2*alpha_only*gy + alpha_only^2*gg;
    sigma_only = max(iy / max(ii, eps), 0);
    vals(3) = -2*sigma_only*iy + sigma_only^2*ii;
    vals(4) = 0;
    score = max(yy + min(vals), 0) / max(yy, eps);
end

function v = matrix_to_realvec_local(M)
    m = M(:);
    v = [real(m); imag(m)];
end

function A = normalize_columns_local(A)
    nrm = sqrt(sum(abs(A).^2, 1));
    nrm(nrm == 0) = 1;
    A = A ./ nrm;
end

function result = make_result_local(az_est, el_est, peak_count, objective_best, objective_true, reason)
    result = struct();
    result.az_est = az_est;
    result.el_est = el_est;
    result.peak_count = peak_count;
    result.objective_best = objective_best;
    result.objective_true_pair = objective_true;
    result.objective_margin = objective_true - objective_best;
    result.objective_true_rank = NaN;
    result.el_common_est = NaN;
    result.el_hat = NaN;
    result.el_selection_method = "";
    result.focused_power_peak_sharpness = NaN;
    result.lambda1_peak_sharpness = NaN;
    result.rank1_objective_valley_width_el = NaN;
    result.rank1_objective_selected_el_rank = NaN;
    result.failure_reason = reason;
    result.spectrum = [];
    result.spectrum_1d = [];
    result.peak_separation_az = NaN;
    result.peak_separation_el = NaN;
    result.peak_prominence_ratio = NaN;
    result.spectrum_width = NaN;
    result.score_gap_abs = NaN;
    result.score_gap_ratio = NaN;
    result.residual_norm = objective_best;
    result.pair_sep_est = NaN;
    result.finite_output_flag = all(isfinite(az_est)) && all(isfinite(el_est));
    result.two_peak_flag = false;
    result.global_peak_el = NaN;
    result.pair_local_confidence_proxy = NaN;
    result.lambda1 = NaN;
    result.lambda2 = NaN;
    result.lambda_noise_mean = NaN;
    result.lambda2_over_noise = NaN;
    result.lambda2_over_lambda1 = NaN;
    result.effective_rank_proxy = NaN;
    result.recommended_route = "";
    result.confidence_flag = "";
    result.weak_target_boundary_flag = false;
    result.anti_phase_boundary_flag = false;
    result.low_confidence_flag = false;
end

function [result, timing] = run_lazy_cascade_wallclock_local( ...
    y_noisy_2d, sc, X3d, Y3d, Z3d, A_ref_2d, lambda, ...
    az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, ...
    Lc, level2_cache_map, level2_refocus_cache_map, music_cache, p_sel, r_sel, theta_true, ...
    min_pair_sep_deg, max_pair_sep_deg)
    timing = init_wallclock_timing_local();
    t_all = tic;
    empty_result = make_empty_route_result_local("not_executed");
    music = empty_result;
    rank1 = empty_result;
    refocus = empty_result;
    music2d = empty_result;
    pair2d = empty_result;

    t0 = tic;
    music = run_level2_music_route_local( ...
        y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, sc.el_assumed, az_grid, K_phi_level2, Lc);
    timing.t_level2_music = toc(t0);
    timing.executed_level2_music = true;

    t0 = tic;
    refocus = run_common_el_refocus_power_route_local( ...
        y_noisy_2d, Z3d, lambda, el_refocus_grid, level2_refocus_cache_map, az_grid, K_phi_level2, ...
        theta_true, min_pair_sep_deg, max_pair_sep_deg);
    timing.t_refocus = toc(t0);
    timing.executed_refocus = true;

    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    common_el_proxy = is_strong_common_el_proxy_local(music, refocus);
    low_cost_boundary_partial = is_low_cost_boundary_proxy_from_partial_local( ...
        music, rank1, refocus, min_pair_sep_deg, max_pair_sep_deg);

    if is_level2_music_reliable_local(music, min_pair_sep_deg, max_pair_sep_deg) && common_el_proxy
        result = music;
        result.recommended_route = "level2_music_or_center_real";
        if is_level2_music_high_confidence_local(music, route_map, min_pair_sep_deg, max_pair_sep_deg)
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "ok";
        timing = finish_lazy_timing_local(timing, t_all, 1, true, route_map);
        return
    end

    if is_refocus_route_reliable_local(refocus, min_pair_sep_deg, max_pair_sep_deg) && ...
            ~low_cost_boundary_partial && common_el_proxy
        result = refocus;
        result.recommended_route = "common_el_refocus_power_rank1";
        result.confidence_flag = "medium";
        result.failure_reason = "ok";
        timing = finish_lazy_timing_local(timing, t_all, 2, true, route_map);
        return
    end

    t0 = tic;
    rank1 = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, sc.el_assumed, level2_cache_map, az_grid, K_phi_level2, ...
        theta_true, min_pair_sep_deg, max_pair_sep_deg);
    timing.t_level2_rank1 = toc(t0);
    timing.executed_level2_rank1 = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    low_cost_boundary = is_low_cost_boundary_proxy_from_partial_local( ...
        music, rank1, refocus, min_pair_sep_deg, max_pair_sep_deg);

    if is_rank1_route_reliable_local(rank1, min_pair_sep_deg, max_pair_sep_deg) && ...
            ~low_cost_boundary && common_el_proxy
        result = rank1;
        result.recommended_route = "level2_rank1_fallback";
        result.confidence_flag = "medium";
        result.failure_reason = "music_single_rank1_fallback";
        timing = finish_lazy_timing_local(timing, t_all, 3, true, route_map);
        return
    end

    t0 = tic;
    Rfb_2d = level3_fbss_cov_from_observation_local(y_noisy_2d, K_phi_music, K_z_music);
    music2d = run_level3_2d_music_route_local(Rfb_2d, music_cache, Lc);
    timing.t_2dmusic = toc(t0);
    timing.executed_2dmusic = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);

    if is_music2d_reliable_local(music2d, min_pair_sep_deg, max_pair_sep_deg)
        pair_available = music2d.peak_count >= 2 && all(isfinite(music2d.az_est)) && all(isfinite(music2d.el_est));
        if pair_available && is_cascade_pair_refinement_needed_local(music2d, min_pair_sep_deg, max_pair_sep_deg)
            t0 = tic;
            Rfb_pair = level3_fbss_cov_selected_from_observation_local(y_noisy_2d, K_phi_covfit, K_z_covfit, p_sel, r_sel);
            pair2d = run_level3_pair_el_local_rank1_covfit_local( ...
                Rfb_pair, music2d, X3d, Y3d, Z3d, A_ref_2d, lambda, K_phi_covfit, K_z_covfit, ...
                p_sel, r_sel, theta_true, sc.el_true, min_pair_sep_deg, max_pair_sep_deg);
            timing.t_pair_local = toc(t0);
            timing.executed_pair_local = true;
            route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
            if is_pair_route_reliable_local(pair2d, min_pair_sep_deg, max_pair_sep_deg)
                result = pair2d;
                result.recommended_route = "pair_el_local_covfit";
                result.confidence_flag = "medium";
                result.failure_reason = "ok";
                timing = finish_lazy_timing_local(timing, t_all, 5, true, route_map);
                return
            end
        end
        result = music2d;
        result.recommended_route = "level3_2d_music";
        result.confidence_flag = "medium";
        if timing.executed_pair_local
            result.failure_reason = "pair_local_not_reliable";
        else
            result.failure_reason = "ok";
        end
        timing = finish_lazy_timing_local(timing, t_all, 4, true, route_map);
        return
    end

    if is_boundary_unreliable_local(route_map, min_pair_sep_deg, max_pair_sep_deg) || low_cost_boundary
        result = make_boundary_result_local(route_map, 'boundary_unreliable', 'low', 'boundary_unreliable', false, false);
    else
        result = make_boundary_result_local(route_map, 'low_confidence', 'low', 'no_reliable_observable_route', false, false);
    end
    timing = finish_lazy_timing_local(timing, t_all, 6, false, route_map);
end

function timing = init_wallclock_timing_local()
    timing = struct();
    timing.t_level2_music = 0;
    timing.t_level2_rank1 = 0;
    timing.t_refocus = 0;
    timing.t_2dmusic = 0;
    timing.t_pair_local = 0;
    timing.t_dispatch = 0;
    timing.t_total = 0;
    timing.executed_level2_music = false;
    timing.executed_refocus = false;
    timing.executed_level2_rank1 = false;
    timing.executed_2dmusic = false;
    timing.executed_pair_local = false;
    timing.executed_stage_count = 0;
    timing.early_stop_stage = NaN;
    timing.early_stop_flag = false;
    timing.route_map = struct();
end

function timing = finish_lazy_timing_local(timing, t_all, early_stop_stage, early_stop_flag, route_map)
    timing.t_total = toc(t_all);
    timing.executed_stage_count = double(timing.executed_level2_music) + double(timing.executed_refocus) + ...
        double(timing.executed_level2_rank1) + double(timing.executed_2dmusic) + double(timing.executed_pair_local);
    timing.early_stop_stage = early_stop_stage;
    timing.early_stop_flag = early_stop_flag;
    timing.route_map = route_map;
end

function route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d)
    route_map = struct();
    route_map.music = music;
    route_map.rank1_fallback = rank1;
    route_map.common_el_refocus_rank1 = refocus;
    route_map.level3_2d_music = music2d;
    route_map.pair_el_local_covfit = pair2d;
end

function result = make_empty_route_result_local(reason)
    result = make_result_local([NaN, NaN], [NaN, NaN], 0, NaN, NaN, reason);
    result.recommended_route = "";
    result.confidence_flag = "";
    result.failure_reason = reason;
end

function tf = is_low_cost_boundary_proxy_from_partial_local(music, rank1, refocus, min_sep, max_sep)
    music_single = music.peak_count < 2 || any(~isfinite(music.az_est));
    strong_single_peak = music_single && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;
    rank1_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    rank1_sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    weak_rank1 = (~isfinite(rank1_gap) || rank1_gap < 5e-3) || ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3);
    sep_edge = is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_sharp = min( ...
        getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;
    refocus_rank1_conflict = false;
    if all(isfinite(getfield_default_local(refocus, 'az_est', [NaN, NaN]))) && ...
            all(isfinite(getfield_default_local(rank1, 'az_est', [NaN, NaN])))
        refocus_rank1_conflict = max(abs(sort(refocus.az_est) - sort(rank1.az_est))) > 0.14;
    end
    tf = (music_single && refocus_unsharp && weak_rank1) || ...
        (strong_single_peak && refocus_unsharp) || ...
        (music_single && sep_edge && weak_rank1) || ...
        (refocus_rank1_conflict && ~is_refocus_route_reliable_local(refocus, min_sep, max_sep));
end

function tf = is_strong_common_el_proxy_local(music, refocus)
    el_music = getfield_default_local(music, 'el_est', [NaN, NaN]);
    el_assumed = mean(el_music(isfinite(el_music)), 'omitnan');
    if ~isfinite(el_assumed)
        el_assumed = 0;
    end
    el_hat = getfield_default_local(refocus, 'el_hat', NaN);
    refocus_sharp = min( ...
        getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    tf = isfinite(el_hat) && isfinite(refocus_sharp) && ...
        abs(el_hat - el_assumed) <= 0.75 && refocus_sharp >= 0.075;
end

function ok = is_music2d_high_confidence_local(result, min_sep, max_sep)
    sep_az = getfield_default_local(result, 'peak_separation_az', NaN);
    sep_el = getfield_default_local(result, 'peak_separation_el', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    ok = is_music2d_reliable_local(result, min_sep, max_sep) && ...
        isfinite(prom) && prom >= 0.75 && isfinite(sep_el) && sep_el >= 2.5 && ...
        ~is_sep_edge_local(sep_az, min_sep, max_sep, 0.02);
end

function tf = is_cascade_pair_refinement_needed_local(music2d_result, min_sep, max_sep)
    tf = is_music2d_reliable_local(music2d_result, min_sep, max_sep) && ...
        ~is_music2d_high_confidence_local(music2d_result, min_sep, max_sep);
end

function Rfbss = mssp_array_fb_local(Rxx, K)
    N = size(Rxx, 1);
    P = N - K + 1;
    Rf = zeros(K, K);
    for p = 1:P
        idx = p:p+K-1;
        Rf = Rf + Rxx(idx, idx);
    end
    Rf = Rf / P;
    J = fliplr(eye(K));
    Rfbss = 0.5 * (Rf + J * conj(Rf) * J);
    Rfbss = 0.5 * (Rfbss + Rfbss');
end

function ok = joint_success_from_result_local(result, theta_true, el_true, az_tol, el_tol)
    [az_err, el_err] = pair_errors_local(result.az_est, result.el_est, theta_true, el_true);
    ok = all(abs(az_err) <= az_tol) && all(abs(el_err) <= el_tol);
    ok = ok && all(isfinite(az_err)) && all(isfinite(el_err));
end

function [az_err, el_err, pair_rmse] = pair_errors_local(az_est, el_est, az_true, el_true)
    az_est = az_est(:).';
    el_est = el_est(:).';
    if numel(az_est) < 2 || any(~isfinite(az_est)) || any(~isfinite(el_est))
        az_err = [NaN, NaN];
        el_err = [NaN, NaN];
        pair_rmse = NaN;
        return
    end
    est = [az_est(:), el_est(:)];
    truth = [az_true(:), el_true(:)];
    d11 = norm(est(1, :) - truth(1, :)) + norm(est(2, :) - truth(2, :));
    d12 = norm(est(1, :) - truth(2, :)) + norm(est(2, :) - truth(1, :));
    if d12 < d11
        truth = flipud(truth);
    end
    az_err = est(:, 1).' - truth(:, 1).';
    el_err = est(:, 2).' - truth(:, 2).';
    pair_rmse = sqrt(mean(sum((est - truth).^2, 2)));
end

function reason = failure_reason_pair_local(az_est, el_est, min_sep, max_sep)
    if any(~isfinite(az_est)) || any(~isfinite(el_est))
        reason = 'nan_estimate';
    elseif diff(sort(az_est)) < min_sep
        reason = 'pair_too_close';
    elseif diff(sort(az_est)) > max_sep
        reason = 'pair_too_wide';
    else
        reason = 'ok';
    end
end

function [idx, az] = nearest_column_local(azDeg, phiCol)
    d = abs(wrap180_local(phiCol - azDeg));
    [~, idx] = min(d);
    az = phiCol(idx);
    if az > 180
        az = az - 360;
    end
end

function cols = work_columns_from_az_local(azDeg, nCols, phiCol)
    [centerCol, ~] = nearest_column_local(azDeg, phiCol);
    cols = work_columns_from_center_col_local(centerCol, nCols, numel(phiCol));
end

function cols = work_columns_from_center_col_local(centerCol, nCols, Naz)
    half = (nCols - 1) / 2;
    cols = mod((centerCol - half - 1):(centerCol + half - 1), Naz) + 1;
end

function ang = wrap180_local(ang)
    ang = mod(ang + 180, 360) - 180;
end

function val = getfield_default_local(s, name, default_val)
    if isfield(s, name)
        val = s.(name);
    else
        val = default_val;
    end
end

function p = percentile_no_toolbox_local(x, pct)
    x = sort(x(isfinite(x)));
    if isempty(x)
        p = NaN;
        return
    end
    pos = 1 + (numel(x) - 1) * pct / 100;
    lo = floor(pos);
    hi = ceil(pos);
    if lo == hi
        p = x(lo);
    else
        p = x(lo) + (x(hi) - x(lo)) * (pos - lo);
    end
end

function txt = distribution_string_local(vals)
    vals = string(vals);
    vals = vals(vals ~= "");
    if isempty(vals)
        txt = "";
        return
    end
    u = unique(vals, 'stable');
    parts = strings(numel(u), 1);
    n = numel(vals);
    for i = 1:numel(u)
        parts(i) = sprintf('%s:%.3f', u(i), sum(vals == u(i)) / n);
    end
    txt = strjoin(cellstr(parts), ';');
end

function log_msg_local(fid, varargin)
    msg = sprintf(varargin{:});
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    line = sprintf('[%s] %s\n', stamp, msg);
    fprintf('%s', line);
    if fid > 0
        fprintf(fid, '%s', line);
    end
end

function safe_fclose_local(fid)
    if ~isempty(fid) && fid > 0
        fclose(fid);
    end
end
