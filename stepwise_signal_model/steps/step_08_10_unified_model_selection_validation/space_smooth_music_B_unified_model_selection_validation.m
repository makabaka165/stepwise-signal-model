% Step 8.10 unified model selection validation.
%
% Scope:
% 1) Reuse the Step 8.8 frontend-to-shared-center observation interface.
% 2) Run the copied Step 8.7 shared-center lazy cascade on the same Y_work.
% 3) Compare H1/H2/H3/H0 with one covariance residual score J(A).
%
% This is not FPGA, not fixed point, not MC=100, not dual-center, and not a
% weak-target SIC or anti-phase derivative steering experiment.

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
cfg810 = make_step810_cfg_local(cfg88);

result_dir = fullfile(script_dir, 'results_step8_10_unified_model_selection_validation');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_10_unified_model_selection_validation.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

trial_csv_path = fullfile(result_dir, 'step8_10_unified_model_selection_trial.csv');
summary_csv_path = fullfile(result_dir, 'step8_10_unified_model_selection_summary.csv');
keypoints_csv_path = fullfile(result_dir, 'step8_10_unified_model_selection_keypoints.csv');
candidate_scores_csv_path = fullfile(result_dir, 'step8_10_unified_model_selection_candidate_scores.csv');
threshold_sweep_csv_path = fullfile(result_dir, 'step8_10_unified_model_selection_threshold_sweep.csv');
model_confusion_csv_path = fullfile(result_dir, 'step8_10_unified_model_selection_model_confusion.csv');
mat_path = fullfile(result_dir, 'step8_10_unified_model_selection_result.mat');
formula_doc_path = fullfile(script_dir, '第8.10步_统一模型选择公式与流程说明.md');
record_doc_path = fullfile(script_dir, '第8.10步_统一模型选择增强测角验证记录.md');

quick_mode = strcmpi(getenv('STEP810_QUICK_MODE'), '1');
if quick_mode
    Metkl = 5;
else
    Metkl = 30;
end

snr_list = [8, 16];
base_seed = 20261010;
scenarios = build_step810_scenarios_local(cfg810, snr_list);
total_trials = numel(scenarios) * Metkl;

log_msg_local(fid_log, 'Step 8.10 unified model selection validation');
log_msg_local(fid_log, 'quick_mode=%d, Metkl=%d, total_trials=%d, SNR=%s', ...
    quick_mode, Metkl, total_trials, mat2str(snr_list));
if quick_mode
    log_msg_local(fid_log, 'WARNING: STEP810_QUICK_MODE=1. Results are quick trend only and not a formal conclusion.');
end
log_msg_local(fid_log, 'Scope: single coarse peak / unresolved local cluster -> 65x32 Y_work -> Step 8.7 cascade and Step 8.10 unified model selection.');
log_msg_local(fid_log, 'No true-angle-assisted candidate generation or model selection. Truth is used only for validation metrics.');
log_msg_local(fid_log, 'Default thresholds: tau_improve=%.3f, tau_model_margin=%.3f, tau_h3_over_h2=%.3f, tau_abs_residual=%.3f.', ...
    cfg810.tau_improve, cfg810.tau_model_margin, cfg810.tau_h3_over_h2, cfg810.tau_abs_residual);

[array_geom, pc_model] = init_frontend_models_local(cfg88);
log_msg_local(fid_log, 'Array: Naz=%d, Nel=%d, selected work columns=%d, column spacing=%.6f deg.', ...
    cfg88.Naz, cfg88.Nel, cfg88.workColumns, cfg88.columnSpacingDeg);
log_msg_local(fid_log, 'Pulse model: Np=%d, nRange=%d, rangeIdxTruth=%d, velocity=%.3f m/s.', ...
    cfg88.Np, cfg88.nRange, pc_model.rangeIdxTruth, cfg88.velocity_mps);

context_cache = struct('key', {}, 'ctx', {});
model_context_cache = struct('key', {}, 'ctx', {});
trial_rows = cell(total_trials, 1);
candidate_score_rows = {};
example_store = struct('scenario_name', {}, 'snr_db', {}, 'az_scan', {}, 'power', {}, ...
    'coarseAz', {}, 'trueAz', {}, 'selectedCenterAz', {});
row_idx = 0;
score_row_idx = 0;
tic_all = tic;

for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    log_msg_local(fid_log, 'Scenario %02d/%02d: %s, SNR=%g, target_count=%d, sep=%.6f, beta=%.3g, phase=%.1f, el=[%.1f %.1f].', ...
        isc, numel(scenarios), sc.scenario_name, sc.snr_db, sc.target_count, sc.pair_sep, ...
        sc.beta, sc.phase_deg, sc.el1, sc.el2);
    for imc = 1:Metkl
        rng(base_seed + 1000 * isc + imc);
        [frontend_out, pc_like, frontend_diag] = run_frontend_chain_local(sc, cfg88, array_geom, pc_model);
        if imc == 1
            example_store(end+1) = make_example_entry_local(sc, frontend_out, frontend_diag); %#ok<SAGROW>
        end

        two_out = frontend_out.two_coarse_peaks_out_of_scope;
        cfar_ok = frontend_out.cfar_detected_flag;
        if cfar_ok && ~two_out
            enhance_in = frontend_to_step87_input_local(frontend_out, pc_like, cfg88, array_geom);
            [ctx, context_cache] = get_or_build_step87_context_local(context_cache, enhance_in, cfg88, array_geom, fid_log);
            [cascade_out, cascade_timing] = run_step87_shared_center_lazy_local(enhance_in, sc, ctx, cfg88);
            [model_ctx, model_context_cache] = get_or_build_unified_context_local(model_context_cache, enhance_in, cfg810, fid_log);
            [unified_out, unified_timing] = run_unified_model_selection_local(enhance_in, model_ctx, cfg810, cfg810.default_thresholds);
        else
            enhance_in = make_empty_enhance_input_local(frontend_out, cfg88);
            cascade_out = make_empty_route_result_local("frontend_not_in_shared_center_scope");
            if ~cfar_ok
                cascade_out.recommended_route = "cfar_not_detected";
                cascade_out.failure_reason = "cfar_not_detected";
            else
                cascade_out.recommended_route = "two_coarse_peaks_out_of_scope";
                cascade_out.failure_reason = "two_coarse_peaks_out_of_scope";
            end
            cascade_out.confidence_flag = "low";
            cascade_out.low_confidence_flag = true;
            cascade_timing = init_wallclock_timing_local();
            unified_out = make_empty_unified_result_local("frontend_not_in_shared_center_scope");
            unified_out.model_selected = "H0_boundary";
            unified_out.confidence_flag = "low";
            unified_out.boundary_reason = string(cascade_out.failure_reason);
            unified_timing = init_unified_timing_local();
        end

        row_idx = row_idx + 1;
        trial_rows{row_idx} = make_step810_trial_row_local(sc, imc, frontend_out, enhance_in, ...
            cascade_out, cascade_timing, unified_out, unified_timing, cfg810);
        if isfield(unified_out, 'candidate_scores') && ~isempty(unified_out.candidate_scores)
            rows_now = unified_out.candidate_scores;
            for ir = 1:numel(rows_now)
                score_row_idx = score_row_idx + 1;
                rows_now(ir).scenario_name = sc.scenario_name;
                rows_now(ir).snr_db = sc.snr_db;
                rows_now(ir).mc = imc;
                candidate_score_rows{score_row_idx, 1} = rows_now(ir); %#ok<SAGROW>
            end
        end
    end
end

elapsed_sec = toc(tic_all);
trial_rows = trial_rows(1:row_idx);
trial_tbl = struct2table([trial_rows{:}]);
trial_tbl.Properties.UserData.recommended_frontend_policy = cfg88.recommended_frontend_policy;
if isempty(candidate_score_rows)
    candidate_scores_tbl = table();
else
    candidate_scores_tbl = struct2table([candidate_score_rows{:}]);
end
threshold_sweep_tbl = build_step810_threshold_sweep_local(trial_tbl, cfg810);
model_confusion_tbl = build_step810_model_confusion_local(trial_tbl);
summary_tbl = build_step810_summary_table_local(trial_tbl);
keypoints_tbl = build_step810_keypoints_local(trial_tbl, summary_tbl, threshold_sweep_tbl, ...
    Metkl, quick_mode, cfg810);

log_msg_local(fid_log, 'Runtime loops finished in %.2f sec.', elapsed_sec);
log_msg_local(fid_log, 'Writing CSV/MAT outputs.');
writetable(trial_tbl, trial_csv_path);
writetable(summary_tbl, summary_csv_path);
writetable(keypoints_tbl, keypoints_csv_path);
writetable(candidate_scores_tbl, candidate_scores_csv_path);
writetable(threshold_sweep_tbl, threshold_sweep_csv_path);
writetable(model_confusion_tbl, model_confusion_csv_path);

log_msg_local(fid_log, 'Rendering plots.');
plot_step810_score_example_local(candidate_scores_tbl, "single_target_sanity", fullfile(result_dir, 'model_score_example_single_target.png'));
plot_step810_score_example_local(candidate_scores_tbl, "close_coherent_pair", fullfile(result_dir, 'model_score_example_close_coherent.png'));
plot_step810_score_example_local(candidate_scores_tbl, "large_el_pair", fullfile(result_dir, 'model_score_example_large_el.png'));
plot_step810_model_distribution_local(trial_tbl, fullfile(result_dir, 'model_selection_distribution.png'));
plot_step810_success_compare_local(summary_tbl, fullfile(result_dir, 'unified_vs_cascade_success.png'));
plot_step810_false_boundary_local(summary_tbl, fullfile(result_dir, 'unified_vs_cascade_false_high_boundary.png'));
plot_step810_residual_by_scenario_local(trial_tbl, fullfile(result_dir, 'model_residual_by_scenario.png'));
plot_step810_margin_by_scenario_local(trial_tbl, fullfile(result_dir, 'model_margin_by_scenario.png'));
plot_step810_threshold_sweep_local(threshold_sweep_tbl, fullfile(result_dir, 'threshold_sweep_validation.png'));
plot_step810_flowchart_local(fullfile(result_dir, 'final_flowchart_unified_model_selection.png'));

save(mat_path, 'trial_tbl', 'summary_tbl', 'keypoints_tbl', 'candidate_scores_tbl', ...
    'threshold_sweep_tbl', 'model_confusion_tbl', 'cfg88', 'cfg810', 'array_geom', ...
    'pc_model', 'example_store', 'elapsed_sec', 'Metkl', 'quick_mode', '-v7.3');

write_step810_formula_doc_local(formula_doc_path, cfg810);
write_step810_record_doc_local(record_doc_path, keypoints_tbl, summary_tbl, threshold_sweep_tbl, ...
    result_dir, elapsed_sec, Metkl, quick_mode);

log_msg_local(fid_log, 'Outputs written to %s', result_dir);
log_msg_local(fid_log, 'Record doc: %s', record_doc_path);
log_msg_local(fid_log, 'Formula doc: %s', formula_doc_path);

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

function enhance_in = frontend_to_step87_input_local(frontend_out, pc_like, cfg88, array_geom)
    cols = frontend_out.selectedWorkColumns;
    centerAz = frontend_out.selectedCenterAz_deg;
    X = array_geom.X(cols, :);
    Y = array_geom.Y(cols, :);
    Z = array_geom.Z(cols, :);
    Y_raw = pc_like.Y_full_range(cols, :, :);
    A_ref = exp(-1j * 2*pi / cfg88.lambda * (X * cosd(centerAz) + Y * sind(centerAz)));
    Y_cal = Y_raw .* repmat(conj(A_ref), 1, 1, cfg88.Np);
    if isfinite(frontend_out.dopplerIdx)
        fd_hat = pc_like.fdAxis(frontend_out.dopplerIdx);
    else
        fd_hat = 0;
    end
    derot = exp(-1j * 2*pi * fd_hat * pc_like.tSlow);
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

function cfg810 = make_step810_cfg_local(cfg88)
    cfg810 = cfg88;
    cfg810.K_phi_score = 20;
    cfg810.K_z_score = 8;
    cfg810.M_score = cfg810.K_phi_score * cfg810.K_z_score;
    cfg810.R_template_deg = 2.0;
    cfg810.h1_delta_grid_deg = -2.0:0.04:2.0;
    cfg810.h1_el_grid_deg = -2:0.5:12;
    cfg810.h1_refine_theta_half_deg = 0.04;
    cfg810.h1_refine_theta_step_deg = 0.01;
    cfg810.h1_refine_el_half_deg = 0.5;
    cfg810.h1_refine_el_step_deg = 0.25;
    cfg810.h2_mid_delta_grid_deg = -1.2:0.2:1.2;
    cfg810.h2_sep_grid_deg = unique([0.05, 0.1, 0.2, 0.263775444933353, 0.4, 0.5, 0.8, 1.2, 1.6]);
    cfg810.h2_el_grid_deg = -2:0.5:12;
    cfg810.h2_extra_el_grid_deg = [-2:1:12, 0, 5];
    cfg810.h2_top_coarse = 5;
    cfg810.h2_top_el_from_projection = 3;
    cfg810.h2_refine_theta_half_deg = 0.02;
    cfg810.h2_refine_theta_step_deg = 0.02;
    cfg810.h2_refine_sep_half_deg = 0.02;
    cfg810.h2_refine_sep_step_deg = 0.02;
    cfg810.h2_refine_el_half_deg = 0.25;
    cfg810.h2_refine_el_step_deg = 0.25;
    cfg810.h3_top_peaks = 8;
    cfg810.h3_min_pair_candidates = 20;
    cfg810.h3_top_refine = 2;
    cfg810.h3_refine_theta_half_deg = 0.02;
    cfg810.h3_refine_theta_step_deg = 0.02;
    cfg810.h3_refine_el_half_deg = 0.25;
    cfg810.h3_refine_el_step_deg = 0.25;
    cfg810.eps_reg = 1e-8;
    cfg810.low_r_norm_eps = 1e-12;
    cfg810.tau_improve = 0.05;
    cfg810.tau_model_margin = 0.02;
    cfg810.tau_h3_over_h2 = 0.03;
    cfg810.tau_abs_residual = 0.35;
    cfg810.default_thresholds = struct('tau_improve', cfg810.tau_improve, ...
        'tau_model_margin', cfg810.tau_model_margin, ...
        'tau_h3_over_h2', cfg810.tau_h3_over_h2, ...
        'tau_abs_residual', cfg810.tau_abs_residual);
    cfg810.sweep_tau_improve = [0.03, 0.05, 0.08];
    cfg810.sweep_tau_model_margin = [0.01, 0.02, 0.05];
    cfg810.sweep_tau_abs_residual = [0.25, 0.35, 0.50];
    cfg810.az_tol_deg = cfg88.az_tol_deg;
    cfg810.el_tol_deg = cfg88.el_tol_deg;
    cfg810.min_pair_sep_deg = cfg88.min_pair_sep_deg;
    cfg810.max_pair_sep_deg = 1.6;
end

function scenarios = build_step810_scenarios_local(cfg810, snr_list)
    scenarios = repmat(make_scenario_local("", 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN), 0, 1);
    idx = 0;
    theta0 = 0;
    for el0 = [0, 5]
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_scenario_local("single_target_sanity", 1, theta0, NaN, el0, NaN, ...
                NaN, 1, 0, NaN, 0, snr_list(is));
        end
    end

    sep_list = [0.263775444933353, 0.5, 0.8];
    offset_list = [-0.5 * cfg810.halfColumnSpacingDeg, 0, 0.5 * cfg810.halfColumnSpacingDeg];
    for sep = sep_list
        for off = offset_list
            for is = 1:numel(snr_list)
                idx = idx + 1;
                scenarios(idx) = make_scenario_pair_local("close_coherent_pair", sep, off, 1, 1, 0, [0, 0], snr_list(is));
            end
        end
    end

    for sep = [0.5, 0.8]
        for off = offset_list
            for is = 1:numel(snr_list)
                idx = idx + 1;
                scenarios(idx) = make_scenario_pair_local("medium_beta_pair", sep, off, 0.5, 1, 0, [0, 0], snr_list(is));
            end
        end
    end

    for sep = [0.263775444933353, 0.5]
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios(idx) = make_scenario_pair_local("large_el_pair", sep, 0, 1, 1, 0, [0, 5], snr_list(is));
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
end

function [ctx, cache] = get_or_build_unified_context_local(cache, enhance_in, cfg810, fid_log)
    center_col = enhance_in.selectedWorkColumns(cfg810.workHalfColumns + 1);
    key = sprintf('col_%03d_center_%0.6f', center_col, enhance_in.thetaCenter_deg);
    for i = 1:numel(cache)
        if strcmp(cache(i).key, key)
            ctx = cache(i).ctx;
            return
        end
    end

    X = enhance_in.arrayInfo.X;
    Y = enhance_in.arrayInfo.Y;
    Z = enhance_in.arrayInfo.Z;
    A_ref = enhance_in.arrayInfo.A_ref;
    q0 = floor((size(X, 1) - cfg810.K_phi_score) / 2) + 1;
    z0 = floor((size(X, 2) - cfg810.K_z_score) / 2) + 1;
    q_idx = q0:(q0 + cfg810.K_phi_score - 1);
    z_idx = z0:(z0 + cfg810.K_z_score - 1);
    Xs = X(q_idx, z_idx);
    Ys = Y(q_idx, z_idx);
    Zs = Z(q_idx, z_idx);
    Arefs = A_ref(q_idx, z_idx);

    theta_grid = enhance_in.thetaCenter_deg + cfg810.h1_delta_grid_deg;
    el_grid = cfg810.h1_el_grid_deg;
    A_grid = build_score_steering_grid_local(Xs, Ys, Zs, Arefs, cfg810.lambda, theta_grid, el_grid);

    ctx = struct();
    ctx.key = key;
    ctx.theta_center = enhance_in.thetaCenter_deg;
    ctx.q_idx = q_idx;
    ctx.z_idx = z_idx;
    ctx.Xs = Xs;
    ctx.Ys = Ys;
    ctx.Zs = Zs;
    ctx.Arefs = Arefs;
    ctx.theta_grid = theta_grid;
    ctx.el_grid = el_grid;
    ctx.A_grid = A_grid;
    ctx.M = cfg810.M_score;
    cache(end+1).key = key;
    cache(end).ctx = ctx;
    log_msg_local(fid_log, 'Built Step 8.10 model context center=%.6f deg, score grid=%d x %d.', ...
        enhance_in.thetaCenter_deg, numel(theta_grid), numel(el_grid));
end

function A_grid = build_score_steering_grid_local(Xs, Ys, Zs, Arefs, lambda, theta_grid, el_grid)
    M = numel(Xs);
    A_grid = complex(zeros(M, numel(theta_grid) * numel(el_grid)));
    idx = 0;
    for ie = 1:numel(el_grid)
        for it = 1:numel(theta_grid)
            idx = idx + 1;
            A_grid(:, idx) = score_steering_local(Xs, Ys, Zs, Arefs, lambda, theta_grid(it), el_grid(ie));
        end
    end
end

function a = score_steering_local(Xs, Ys, Zs, Arefs, lambda, theta_deg, el_deg)
    A = steering_2d_full_local(Xs, Ys, Zs, Arefs, lambda, theta_deg, el_deg);
    a = A(:);
    a = a / max(norm(a), eps);
end

function [Y_score, R, R_norm] = make_score_covariance_local(Y_work, ctx)
    sub = Y_work(ctx.q_idx, ctx.z_idx, :);
    T = size(sub, 3);
    Y_score = reshape(sub, ctx.M, T);
    R = (Y_score * Y_score') / max(T, 1);
    R = 0.5 * (R + R');
    R_norm = norm(R, 'fro');
end

function [result, timing] = run_unified_model_selection_local(enhance_in, ctx, cfg810, thresholds)
    timing = init_unified_timing_local();
    t_all = tic;
    result = make_empty_unified_result_local("");
    [Y_score, R, R_norm] = make_score_covariance_local(enhance_in.Y_work, ctx);
    result.R_norm = R_norm;
    if R_norm < 1e-12
        result.model_selected = "H0_boundary";
        result.confidence_flag = "low";
        result.boundary_reason = "low_R_norm";
        timing.t_total = toc(t_all);
        return
    end

    t0 = tic;
    [h1, rows1, projection_power] = fit_H1_single_local(Y_score, R, ctx, cfg810);
    timing.t_H1 = toc(t0);
    t0 = tic;
    [h2, rows2] = fit_H2_coherent_pair_local(Y_score, R, ctx, cfg810, projection_power);
    timing.t_H2 = toc(t0);
    t0 = tic;
    [h3, rows3] = fit_H3_2d_pair_local(Y_score, R, ctx, cfg810, projection_power);
    timing.t_H3 = toc(t0);

    decision = select_unified_model_local(h1, h2, h3, thresholds);
    result = merge_unified_outputs_local(result, h1, h2, h3, decision);
    result.candidate_scores = [rows1(:); rows2(:); rows3(:)];
    timing.t_total = toc(t_all);
end

function timing = init_unified_timing_local()
    timing = struct('t_H1', 0, 't_H2', 0, 't_H3', 0, 't_total', 0);
end

function result = make_empty_unified_result_local(reason)
    result = struct();
    result.model_selected = "H0_boundary";
    result.confidence_flag = "low";
    result.boundary_reason = string(reason);
    result.H1_theta = NaN;
    result.H1_el = NaN;
    result.J1 = Inf;
    result.H2_theta1 = NaN;
    result.H2_theta2 = NaN;
    result.H2_el = NaN;
    result.J2 = Inf;
    result.H2_sep = NaN;
    result.H2_gain_vector_summary = "";
    result.H2_candidate_count = 0;
    result.H3_theta1 = NaN;
    result.H3_theta2 = NaN;
    result.H3_el1 = NaN;
    result.H3_el2 = NaN;
    result.J3 = Inf;
    result.H3_el_sep = NaN;
    result.H3_candidate_count = 0;
    result.improve_21 = NaN;
    result.improve_31 = NaN;
    result.improve_32 = NaN;
    result.model_margin = NaN;
    result.R_norm = NaN;
    result.candidate_scores = struct([]);
end

function [h1, rows, projection_power] = fit_H1_single_local(Y_score, R, ctx, cfg810)
    Z = ctx.A_grid' * Y_score;
    projection_power = mean(abs(Z).^2, 2);
    [~, ord] = sort(projection_power, 'descend');
    n_top = min(5, numel(ord));
    rows = repmat(make_candidate_score_row_local("H1", NaN, NaN, NaN, NaN, Inf, NaN, "coarse"), n_top, 1);
    best = struct('theta', NaN, 'el', NaN, 'J', Inf);
    for k = 1:n_top
        idx = ord(k);
        [it, ie] = ind2sub([numel(ctx.theta_grid), numel(ctx.el_grid)], idx);
        theta0 = ctx.theta_grid(it);
        el0 = ctx.el_grid(ie);
        [theta_ref, el_ref, J_ref] = refine_H1_candidate_local(R, ctx, cfg810, theta0, el0);
        rows(k) = make_candidate_score_row_local("H1", theta_ref, NaN, el_ref, NaN, J_ref, projection_power(idx), "refined_top5");
        if J_ref < best.J
            best.theta = theta_ref;
            best.el = el_ref;
            best.J = J_ref;
        end
    end
    h1 = struct('theta', best.theta, 'el', best.el, 'J', best.J);
end

function [theta_best, el_best, J_best] = refine_H1_candidate_local(R, ctx, cfg810, theta0, el0)
    theta_axis = unique(max(min(theta0 + (-cfg810.h1_refine_theta_half_deg:cfg810.h1_refine_theta_step_deg:cfg810.h1_refine_theta_half_deg), ...
        ctx.theta_center + cfg810.R_template_deg), ctx.theta_center - cfg810.R_template_deg));
    el_axis = unique(max(min(el0 + (-cfg810.h1_refine_el_half_deg:cfg810.h1_refine_el_step_deg:cfg810.h1_refine_el_half_deg), 12), -2));
    theta_best = NaN;
    el_best = NaN;
    J_best = Inf;
    for ie = 1:numel(el_axis)
        for it = 1:numel(theta_axis)
            a = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, theta_axis(it), el_axis(ie));
            J = covariance_residual_score_local(R, a, cfg810.eps_reg);
            if J < J_best
                J_best = J;
                theta_best = theta_axis(it);
                el_best = el_axis(ie);
            end
        end
    end
end

function [h2, rows] = fit_H2_coherent_pair_local(Y_score, R, ctx, cfg810, projection_power)
    P = reshape(projection_power, numel(ctx.theta_grid), numel(ctx.el_grid));
    [~, ord_el] = sort(max(P, [], 1), 'descend');
    el_keep = ctx.el_grid(ord_el(1:min(cfg810.h2_top_el_from_projection, numel(ord_el))));
    el_keep = unique([el_keep(:).', cfg810.h2_extra_el_grid_deg]);
    el_keep = el_keep(el_keep >= -2 & el_keep <= 12);

    candidates = struct('theta1', {}, 'theta2', {}, 'el', {}, 'proxy', {});
    idx = 0;
    for ie = 1:numel(el_keep)
        el_c = el_keep(ie);
        for im = 1:numel(cfg810.h2_mid_delta_grid_deg)
            theta_mid = ctx.theta_center + cfg810.h2_mid_delta_grid_deg(im);
            for isep = 1:numel(cfg810.h2_sep_grid_deg)
                sep = cfg810.h2_sep_grid_deg(isep);
                theta1 = theta_mid - sep / 2;
                theta2 = theta_mid + sep / 2;
                if theta1 < ctx.theta_center - cfg810.R_template_deg || theta2 > ctx.theta_center + cfg810.R_template_deg
                    continue
                end
                if theta2 <= theta1 || sep < cfg810.min_pair_sep_deg || sep > cfg810.max_pair_sep_deg
                    continue
                end
                a1 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, theta1, el_c);
                a2 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, theta2, el_c);
                c = a1 + a2;
                c = c / max(norm(c), eps);
                proxy = mean(abs(c' * Y_score).^2);
                idx = idx + 1;
                candidates(idx).theta1 = theta1; %#ok<AGROW>
                candidates(idx).theta2 = theta2;
                candidates(idx).el = el_c;
                candidates(idx).proxy = proxy;
            end
        end
    end
    if isempty(candidates)
        h2 = struct('theta1', NaN, 'theta2', NaN, 'el', NaN, 'J', Inf, 'sep', NaN, ...
            'gain_summary', "", 'candidate_count', 0);
        rows = make_candidate_score_row_local("H2", NaN, NaN, NaN, NaN, Inf, NaN, "no_candidate");
        return
    end

    [~, ord] = sort([candidates.proxy], 'descend');
    n_top = min(cfg810.h2_top_coarse, numel(ord));
    rows = repmat(make_candidate_score_row_local("H2", NaN, NaN, NaN, NaN, Inf, NaN, "coarse"), n_top, 1);
    best = struct('theta1', NaN, 'theta2', NaN, 'el', NaN, 'J', Inf, 'sep', NaN, 'gain_summary', "");
    for k = 1:n_top
        c0 = candidates(ord(k));
        [theta1, theta2, el_c, J, gain_summary] = refine_H2_candidate_local(R, ctx, cfg810, c0.theta1, c0.theta2, c0.el);
        rows(k) = make_candidate_score_row_local("H2", theta1, theta2, el_c, el_c, J, c0.proxy, "refined_top10");
        if J < best.J
            best.theta1 = theta1;
            best.theta2 = theta2;
            best.el = el_c;
            best.J = J;
            best.sep = theta2 - theta1;
            best.gain_summary = gain_summary;
        end
    end
    h2 = best;
    h2.candidate_count = numel(candidates);
end

function [theta1_best, theta2_best, el_best, J_best, gain_summary_best] = refine_H2_candidate_local(R, ctx, cfg810, theta1_0, theta2_0, el0)
    mid0 = 0.5 * (theta1_0 + theta2_0);
    sep0 = theta2_0 - theta1_0;
    mid_axis = unique(max(min(mid0 + (-cfg810.h2_refine_theta_half_deg:cfg810.h2_refine_theta_step_deg:cfg810.h2_refine_theta_half_deg), ...
        ctx.theta_center + 1.5), ctx.theta_center - 1.5));
    sep_axis = unique(max(min(sep0 + (-cfg810.h2_refine_sep_half_deg:cfg810.h2_refine_sep_step_deg:cfg810.h2_refine_sep_half_deg), ...
        cfg810.max_pair_sep_deg), cfg810.min_pair_sep_deg));
    el_axis = unique(max(min(el0 + (-cfg810.h2_refine_el_half_deg:cfg810.h2_refine_el_step_deg:cfg810.h2_refine_el_half_deg), 12), -2));
    theta1_best = NaN;
    theta2_best = NaN;
    el_best = NaN;
    J_best = Inf;
    gain_summary_best = "";
    for ie = 1:numel(el_axis)
        for im = 1:numel(mid_axis)
            for isep = 1:numel(sep_axis)
                theta1 = mid_axis(im) - sep_axis(isep) / 2;
                theta2 = mid_axis(im) + sep_axis(isep) / 2;
                if theta1 < ctx.theta_center - cfg810.R_template_deg || theta2 > ctx.theta_center + cfg810.R_template_deg
                    continue
                end
                a1 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, theta1, el_axis(ie));
                a2 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, theta2, el_axis(ie));
                [c, gain_summary] = concentrated_coherent_vector_local(R, [a1, a2], cfg810.eps_reg);
                J = covariance_residual_score_local(R, c, cfg810.eps_reg);
                if J < J_best
                    J_best = J;
                    theta1_best = theta1;
                    theta2_best = theta2;
                    el_best = el_axis(ie);
                    gain_summary_best = gain_summary;
                end
            end
        end
    end
end

function [h3, rows] = fit_H3_2d_pair_local(Y_score, R, ctx, cfg810, projection_power)
    P = reshape(projection_power, numel(ctx.theta_grid), numel(ctx.el_grid));
    peaks = find_projection_peaks_2d_local(P, ctx.theta_grid, ctx.el_grid, cfg810.h3_top_peaks);
    pair_candidates = make_H3_pair_candidates_local(peaks, cfg810);
    if isempty(pair_candidates)
        h3 = struct('theta1', NaN, 'theta2', NaN, 'el1', NaN, 'el2', NaN, 'J', Inf, ...
            'el_sep', NaN, 'candidate_count', 0);
        rows = make_candidate_score_row_local("H3", NaN, NaN, NaN, NaN, Inf, NaN, "no_candidate");
        return
    end

    for i = 1:numel(pair_candidates)
        a1 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, pair_candidates(i).theta1, pair_candidates(i).el1);
        a2 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, pair_candidates(i).theta2, pair_candidates(i).el2);
        pair_candidates(i).J = covariance_residual_score_local(R, [a1, a2], cfg810.eps_reg);
    end
    [~, ord] = sort([pair_candidates.J], 'ascend');
    n_top = min(cfg810.h3_top_refine, numel(ord));
    rows = repmat(make_candidate_score_row_local("H3", NaN, NaN, NaN, NaN, Inf, NaN, "coarse_pair"), n_top, 1);
    best = struct('theta1', NaN, 'theta2', NaN, 'el1', NaN, 'el2', NaN, 'J', Inf, 'el_sep', NaN);
    for k = 1:n_top
        c0 = pair_candidates(ord(k));
        [theta1, theta2, el1, el2, J] = refine_H3_candidate_local(R, ctx, cfg810, c0.theta1, c0.theta2, c0.el1, c0.el2);
        rows(k) = make_candidate_score_row_local("H3", theta1, theta2, el1, el2, J, c0.proxy, "refined_top5");
        if J < best.J
            best.theta1 = theta1;
            best.theta2 = theta2;
            best.el1 = el1;
            best.el2 = el2;
            best.J = J;
            best.el_sep = abs(el2 - el1);
        end
    end
    h3 = best;
    h3.candidate_count = numel(pair_candidates);
end

function peaks = find_projection_peaks_2d_local(P, theta_grid, el_grid, L)
    peaks = struct('theta', {}, 'el', {}, 'proxy', {});
    idx = 0;
    for it = 2:(size(P, 1) - 1)
        for ie = 2:(size(P, 2) - 1)
            block = P(it-1:it+1, ie-1:ie+1);
            if P(it, ie) >= max(block(:))
                idx = idx + 1;
                peaks(idx).theta = theta_grid(it); %#ok<AGROW>
                peaks(idx).el = el_grid(ie);
                peaks(idx).proxy = P(it, ie);
            end
        end
    end
    if isempty(peaks)
        [vals, ord] = sort(P(:), 'descend');
        n = min(L, numel(ord));
        for i = 1:n
            [it, ie] = ind2sub(size(P), ord(i));
            peaks(i).theta = theta_grid(it); %#ok<AGROW>
            peaks(i).el = el_grid(ie);
            peaks(i).proxy = vals(i);
        end
    else
        [~, ord] = sort([peaks.proxy], 'descend');
        peaks = peaks(ord(1:min(L, numel(ord))));
    end
end

function pairs = make_H3_pair_candidates_local(peaks, cfg810)
    pairs = struct('theta1', {}, 'theta2', {}, 'el1', {}, 'el2', {}, 'proxy', {}, 'J', {});
    idx = 0;
    for i = 1:numel(peaks)
        for j = i+1:numel(peaks)
            sep = abs(peaks(i).theta - peaks(j).theta);
            if sep < cfg810.min_pair_sep_deg
                continue
            end
            idx = idx + 1;
            pairs(idx).theta1 = peaks(i).theta; %#ok<AGROW>
            pairs(idx).theta2 = peaks(j).theta;
            pairs(idx).el1 = peaks(i).el;
            pairs(idx).el2 = peaks(j).el;
            pairs(idx).proxy = peaks(i).proxy + peaks(j).proxy;
            pairs(idx).J = Inf;
        end
    end
    if numel(pairs) < cfg810.h3_min_pair_candidates && numel(peaks) >= 2
        [~, ord] = sort([peaks.proxy], 'descend');
        peaks = peaks(ord);
        for i = 1:numel(peaks)
            for j = 1:numel(peaks)
                if i == j
                    continue
                end
                sep = abs(peaks(i).theta - peaks(j).theta);
                if sep < cfg810.min_pair_sep_deg && abs(peaks(i).el - peaks(j).el) < 0.5
                    continue
                end
                idx = idx + 1;
                pairs(idx).theta1 = peaks(i).theta; %#ok<AGROW>
                pairs(idx).theta2 = peaks(j).theta + sign(j - i) * cfg810.min_pair_sep_deg;
                pairs(idx).el1 = peaks(i).el;
                pairs(idx).el2 = peaks(j).el;
                pairs(idx).proxy = peaks(i).proxy + peaks(j).proxy;
                pairs(idx).J = Inf;
                if numel(pairs) >= cfg810.h3_min_pair_candidates
                    return
                end
            end
        end
    end
end

function [theta1_best, theta2_best, el1_best, el2_best, J_best] = refine_H3_candidate_local(R, ctx, cfg810, theta1_0, theta2_0, el1_0, el2_0)
    theta1_axis = unique(max(min(theta1_0 + (-cfg810.h3_refine_theta_half_deg:cfg810.h3_refine_theta_step_deg:cfg810.h3_refine_theta_half_deg), ...
        ctx.theta_center + cfg810.R_template_deg), ctx.theta_center - cfg810.R_template_deg));
    theta2_axis = unique(max(min(theta2_0 + (-cfg810.h3_refine_theta_half_deg:cfg810.h3_refine_theta_step_deg:cfg810.h3_refine_theta_half_deg), ...
        ctx.theta_center + cfg810.R_template_deg), ctx.theta_center - cfg810.R_template_deg));
    el1_axis = unique(max(min(el1_0 + (-cfg810.h3_refine_el_half_deg:cfg810.h3_refine_el_step_deg:cfg810.h3_refine_el_half_deg), 12), -2));
    el2_axis = unique(max(min(el2_0 + (-cfg810.h3_refine_el_half_deg:cfg810.h3_refine_el_step_deg:cfg810.h3_refine_el_half_deg), 12), -2));
    theta1_best = NaN;
    theta2_best = NaN;
    el1_best = NaN;
    el2_best = NaN;
    J_best = Inf;
    for it1 = 1:numel(theta1_axis)
        for it2 = 1:numel(theta2_axis)
            if abs(theta2_axis(it2) - theta1_axis(it1)) < cfg810.min_pair_sep_deg
                continue
            end
            for ie1 = 1:numel(el1_axis)
                a1 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, theta1_axis(it1), el1_axis(ie1));
                for ie2 = 1:numel(el2_axis)
                    a2 = score_steering_local(ctx.Xs, ctx.Ys, ctx.Zs, ctx.Arefs, cfg810.lambda, theta2_axis(it2), el2_axis(ie2));
                    J = covariance_residual_score_local(R, [a1, a2], cfg810.eps_reg);
                    if J < J_best
                        J_best = J;
                        theta1_best = theta1_axis(it1);
                        theta2_best = theta2_axis(it2);
                        el1_best = el1_axis(ie1);
                        el2_best = el2_axis(ie2);
                    end
                end
            end
        end
    end
end

function [c, gain_summary] = concentrated_coherent_vector_local(R, A12, eps_reg)
    Q = orthonormalize_model_local(A12, eps_reg);
    B = 0.5 * (Q' * R * Q + (Q' * R * Q)');
    [V, D] = eig(B);
    [~, idx] = max(real(diag(D)));
    u = V(:, idx);
    c = Q * u;
    c = c / max(norm(c), eps);
    if numel(u) >= 2
        gain_summary = sprintf('amp_ratio=%.3g,phase_deg=%.3g', abs(u(2))/max(abs(u(1)), eps), angle(u(2)/(u(1) + eps))*180/pi);
    else
        gain_summary = "single_basis";
    end
end

function Q = orthonormalize_model_local(A, eps_reg)
    A = normalize_columns_local(A);
    G = A' * A + eps_reg * eye(size(A, 2));
    [C, p] = chol(G);
    if p == 0
        Q = A / C;
    else
        [Q, ~] = qr(A, 0);
    end
end

function J = covariance_residual_score_local(R, A, eps_reg)
    M = size(R, 1);
    A = normalize_columns_local(A);
    K = size(A, 2);
    G = A' * A + eps_reg * eye(K);
    P = A / G * A';
    P = 0.5 * (P + P');
    I = eye(M);
    sigma2 = max(real(trace((I - P) * R)) / max(M - K, 1), 0);
    R_A = P * R * P + sigma2 * (I - P);
    J = norm(R - R_A, 'fro')^2 / max(norm(R, 'fro')^2, eps);
    J = real(J);
end

function row = make_candidate_score_row_local(model_name, theta1, theta2, el1, el2, J, proxy, stage)
    row = struct();
    row.scenario_name = "";
    row.snr_db = NaN;
    row.mc = NaN;
    row.model_name = string(model_name);
    row.theta1 = theta1;
    row.theta2 = theta2;
    row.el1 = el1;
    row.el2 = el2;
    row.J = J;
    row.proxy_power = proxy;
    row.stage = string(stage);
end

function decision = select_unified_model_local(h1, h2, h3, thresholds)
    J1 = h1.J;
    J2 = h2.J;
    J3 = h3.J;
    improve_21 = (J1 - J2) / max(J1, eps);
    improve_31 = (J1 - J3) / max(J1, eps);
    improve_32 = (J2 - J3) / max(J2, eps);
    Js = sort([J1, J2, J3]);
    model_margin = (Js(2) - Js(1)) / max(Js(1), eps);
    [Jmin, best_idx] = min([J1, J2, J3]);

    decision = struct();
    decision.improve_21 = improve_21;
    decision.improve_31 = improve_31;
    decision.improve_32 = improve_32;
    decision.model_margin = model_margin;
    decision.model_selected = "H0_boundary";
    decision.confidence_flag = "low";
    decision.boundary_reason = "";

    if Jmin > thresholds.tau_abs_residual
        decision.boundary_reason = "abs_residual_too_large";
        return
    end
    if model_margin < thresholds.tau_model_margin
        decision.boundary_reason = "model_margin_too_small";
        return
    end
    if best_idx == 1 || (improve_21 < thresholds.tau_improve && improve_31 < thresholds.tau_improve)
        decision.model_selected = "H1_single";
        decision.confidence_flag = "high";
        decision.boundary_reason = "H1_best_or_pair_improvement_insufficient";
        return
    end
    if best_idx == 2 && improve_21 >= thresholds.tau_improve
        decision.model_selected = "H2_coherent_pair";
        decision.confidence_flag = "high";
        decision.boundary_reason = "H2_residual_best";
        return
    end
    if best_idx == 3 && improve_31 >= thresholds.tau_improve
        if improve_32 >= thresholds.tau_h3_over_h2 || abs(h3.el2 - h3.el1) >= 1.0
            decision.model_selected = "H3_2d_pair";
            decision.confidence_flag = "high";
            decision.boundary_reason = "H3_residual_best";
            return
        elseif improve_21 >= thresholds.tau_improve
            decision.model_selected = "H2_coherent_pair";
            decision.confidence_flag = "high";
            decision.boundary_reason = "H2_preferred_over_close_H3";
            return
        end
    end
    if J1 <= thresholds.tau_abs_residual
        decision.model_selected = "H1_single";
        decision.confidence_flag = "medium";
        decision.boundary_reason = "fallback_H1_safe";
    else
        decision.boundary_reason = "no_clear_improvement";
    end
end

function result = merge_unified_outputs_local(result, h1, h2, h3, decision)
    result.H1_theta = h1.theta;
    result.H1_el = h1.el;
    result.J1 = h1.J;
    result.H2_theta1 = h2.theta1;
    result.H2_theta2 = h2.theta2;
    result.H2_el = h2.el;
    result.J2 = h2.J;
    result.H2_sep = h2.sep;
    result.H2_gain_vector_summary = string(h2.gain_summary);
    result.H2_candidate_count = h2.candidate_count;
    result.H3_theta1 = h3.theta1;
    result.H3_theta2 = h3.theta2;
    result.H3_el1 = h3.el1;
    result.H3_el2 = h3.el2;
    result.J3 = h3.J;
    result.H3_el_sep = h3.el_sep;
    result.H3_candidate_count = h3.candidate_count;
    result.improve_21 = decision.improve_21;
    result.improve_31 = decision.improve_31;
    result.improve_32 = decision.improve_32;
    result.model_margin = decision.model_margin;
    result.model_selected = decision.model_selected;
    result.confidence_flag = decision.confidence_flag;
    result.boundary_reason = decision.boundary_reason;
end

function row = make_step810_trial_row_local(sc, imc, frontend_out, enhance_in, cascade_out, cascade_timing, unified_out, unified_timing, cfg810)
    target2 = sc.target_count == 2;
    if target2
        pair_center = mean([sc.theta1, sc.theta2]);
        delta2 = wrap180_local(sc.theta2 - frontend_out.selectedCenterAz_deg);
    else
        pair_center = sc.theta1;
        delta2 = NaN;
    end
    delta1 = wrap180_local(sc.theta1 - frontend_out.selectedCenterAz_deg);
    t1R15 = abs(delta1) <= cfg810.R_runtime_default_deg;
    t2R15 = ~target2 || abs(delta2) <= cfg810.R_runtime_default_deg;
    t1R20 = abs(delta1) <= cfg810.R_runtime_expand_deg;
    t2R20 = ~target2 || abs(delta2) <= cfg810.R_runtime_expand_deg;
    bothR15 = t1R15 && t2R15;
    bothR20 = t1R20 && t2R20;

    cascade_route = string(getfield_default_local(cascade_out, 'recommended_route', ""));
    cascade_conf = string(getfield_default_local(cascade_out, 'confidence_flag', ""));
    if cascade_route == ""
        cascade_route = "not_run";
    end
    [cascade_success, cascade_false_high, cascade_boundary_missed] = evaluate_cascade_safety_local(sc, frontend_out, cascade_out, cfg810);
    [unified_success, unified_false_high, unified_boundary_missed, unified_low_conf] = evaluate_unified_success_local(sc, unified_out.model_selected, unified_out.confidence_flag, ...
        unified_out.H1_theta, unified_out.H1_el, unified_out.H2_theta1, unified_out.H2_theta2, unified_out.H2_el, ...
        unified_out.H3_theta1, unified_out.H3_theta2, unified_out.H3_el1, unified_out.H3_el2, cfg810);

    row = struct();
    row.scenario_name = sc.scenario_name;
    row.SNR = sc.snr_db;
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
    row.frontend_state = frontend_out.frontend_state;
    row.coarse_peak_count = frontend_out.peakCountCoarse;
    row.in_scope_shared_center_flag = frontend_out.in_scope_shared_center_flag;
    row.selectedCenterAz = frontend_out.selectedCenterAz_deg;
    row.both_inside_R15 = bothR15;
    row.both_inside_R20 = bothR20;
    row.center_error_to_pair_center = wrap180_local(frontend_out.selectedCenterAz_deg - pair_center);
    row.out_of_scope_reason = frontend_out.out_of_scope_reason;
    row.two_coarse_peaks_out_of_scope = frontend_out.two_coarse_peaks_out_of_scope;
    row.cfar_detected_flag = frontend_out.cfar_detected_flag;
    row.H1_theta = unified_out.H1_theta;
    row.H1_el = unified_out.H1_el;
    row.J1 = unified_out.J1;
    row.H2_theta1 = unified_out.H2_theta1;
    row.H2_theta2 = unified_out.H2_theta2;
    row.H2_el = unified_out.H2_el;
    row.J2 = unified_out.J2;
    row.H2_sep = unified_out.H2_sep;
    row.H2_gain_vector_summary = unified_out.H2_gain_vector_summary;
    row.H2_candidate_count = unified_out.H2_candidate_count;
    row.H3_theta1 = unified_out.H3_theta1;
    row.H3_theta2 = unified_out.H3_theta2;
    row.H3_el1 = unified_out.H3_el1;
    row.H3_el2 = unified_out.H3_el2;
    row.J3 = unified_out.J3;
    row.H3_el_sep = unified_out.H3_el_sep;
    row.H3_candidate_count = unified_out.H3_candidate_count;
    row.improve_21 = unified_out.improve_21;
    row.improve_31 = unified_out.improve_31;
    row.improve_32 = unified_out.improve_32;
    row.model_margin = unified_out.model_margin;
    row.model_selected = unified_out.model_selected;
    row.confidence_flag = unified_out.confidence_flag;
    row.boundary_reason = unified_out.boundary_reason;
    row.success = unified_success;
    row.false_high = unified_false_high;
    row.boundary_missed = unified_boundary_missed;
    row.low_confidence = unified_low_conf;
    row.runtime_sec = unified_timing.t_total;
    row.runtime_H1_sec = unified_timing.t_H1;
    row.runtime_H2_sec = unified_timing.t_H2;
    row.runtime_H3_sec = unified_timing.t_H3;
    row.cascade_route = cascade_route;
    row.cascade_confidence = cascade_conf;
    row.cascade_success = cascade_success;
    row.cascade_false_high = cascade_false_high;
    row.cascade_boundary_missed = cascade_boundary_missed;
    row.cascade_runtime_sec = cascade_timing.t_total;
    row.result_agreement = string(unified_out.model_selected) == cascade_model_family_local(cascade_route);
    row.output_equivalent = row.success == row.cascade_success && row.false_high == row.cascade_false_high && row.boundary_missed == row.cascade_boundary_missed;
    row.weak_target_truth_flag = sc.weak_target_truth_flag;
    row.anti_phase_truth_flag = sc.anti_phase_truth_flag;
    row.large_el_truth_flag = sc.large_el_truth_flag;
    row.enhance_thetaCenter_deg = enhance_in.thetaCenter_deg;
    row.enhance_elAssumed_deg = enhance_in.elAssumed_deg;
end

function fam = cascade_model_family_local(route)
    route = string(route);
    if any(strcmp(route, ["low_confidence", "boundary_unreliable", "cfar_not_detected", "two_coarse_peaks_out_of_scope"]))
        fam = "H0_boundary";
    elseif contains(route, "2d") || contains(route, "pair")
        fam = "H3_2d_pair";
    elseif contains(route, "rank1") || contains(route, "refocus")
        fam = "H2_coherent_pair";
    else
        fam = "H1_single";
    end
end

function [success, false_high, boundary_missed] = evaluate_cascade_safety_local(sc, frontend_out, result, cfg810)
    target2 = sc.target_count == 2;
    conf = string(getfield_default_local(result, 'confidence_flag', ""));
    route = string(getfield_default_local(result, 'recommended_route', ""));
    in_scope = frontend_out.cfar_detected_flag && ~frontend_out.two_coarse_peaks_out_of_scope;
    if target2 && in_scope
        success = joint_success_from_result_local(result, sort([sc.theta1, sc.theta2]), [sc.el1, sc.el2], cfg810.az_tol_deg, cfg810.el_tol_deg);
    elseif ~target2 && in_scope
        finite_pair = all(isfinite(getfield_default_local(result, 'az_est', [NaN, NaN])));
        success = ~(strcmp(conf, "high") && finite_pair);
    else
        success = false;
    end
    low_conf = strcmp(conf, "low") || any(strcmp(route, ["low_confidence", "boundary_unreliable", "cfar_not_detected", "two_coarse_peaks_out_of_scope"]));
    false_high = strcmp(conf, "high") && ~success;
    boundary_truth = sc.weak_target_truth_flag || sc.anti_phase_truth_flag;
    boundary_missed = boundary_truth && strcmp(conf, "high") && ~low_conf && ~success;
end

function [success, false_high, boundary_missed, low_conf] = evaluate_unified_success_local(sc, model_selected, conf, H1_theta, H1_el, H2_theta1, H2_theta2, H2_el, H3_theta1, H3_theta2, H3_el1, H3_el2, cfg810)
    model_selected = string(model_selected);
    conf = string(conf);
    low_conf = strcmp(conf, "low") || model_selected == "H0_boundary";
    target2 = sc.target_count == 2;
    success = false;
    if ~target2
        if model_selected == "H1_single"
            success = abs(H1_theta - sc.theta1) <= cfg810.az_tol_deg && abs(H1_el - sc.el1) <= cfg810.el_tol_deg;
        else
            success = false;
        end
    else
        if model_selected == "H2_coherent_pair"
            [az_err, el_err] = pair_errors_local([H2_theta1, H2_theta2], [H2_el, H2_el], sort([sc.theta1, sc.theta2]), [sc.el1, sc.el2]);
            success = all(abs(az_err) <= cfg810.az_tol_deg) && all(abs(el_err) <= cfg810.el_tol_deg) && all(isfinite(az_err));
        elseif model_selected == "H3_2d_pair"
            [az_err, el_err] = pair_errors_local([H3_theta1, H3_theta2], [H3_el1, H3_el2], sort([sc.theta1, sc.theta2]), [sc.el1, sc.el2]);
            success = all(abs(az_err) <= cfg810.az_tol_deg) && all(abs(el_err) <= cfg810.el_tol_deg) && all(isfinite(az_err));
        end
    end
    pair_high = any(strcmp(model_selected, ["H2_coherent_pair", "H3_2d_pair"])) && strcmp(conf, "high");
    false_high = strcmp(conf, "high") && ~success;
    boundary_truth = sc.weak_target_truth_flag || sc.anti_phase_truth_flag;
    boundary_missed = boundary_truth && pair_high && ~success;
end

function summary_tbl = build_step810_summary_table_local(T)
    names = unique(T.scenario_name, 'stable');
    rows = cell(numel(names) + 1, 1);
    rows{1} = make_step810_summary_row_local(T, true(height(T), 1), "overall");
    for i = 1:numel(names)
        rows{i+1} = make_step810_summary_row_local(T, T.scenario_name == names(i), names(i));
    end
    summary_tbl = struct2table([rows{:}]);
end

function row = make_step810_summary_row_local(T, mask, name)
    mask = mask & T.in_scope_shared_center_flag;
    n = sum(mask);
    row = struct();
    row.scenario_name = string(name);
    row.in_scope_trials = n;
    row.H1_select_rate = mean_or_nan_local(T.model_selected(mask) == "H1_single");
    row.H2_select_rate = mean_or_nan_local(T.model_selected(mask) == "H2_coherent_pair");
    row.H3_select_rate = mean_or_nan_local(T.model_selected(mask) == "H3_2d_pair");
    row.H0_select_rate = mean_or_nan_local(T.model_selected(mask) == "H0_boundary");
    row.unified_success_rate = mean_or_nan_local(T.success(mask));
    row.cascade_success_rate = mean_or_nan_local(T.cascade_success(mask));
    row.success_gap_unified_vs_cascade = row.unified_success_rate - row.cascade_success_rate;
    row.unified_false_high_rate = mean_or_nan_local(T.false_high(mask));
    row.cascade_false_high_rate = mean_or_nan_local(T.cascade_false_high(mask));
    row.unified_boundary_missed_rate = mean_or_nan_local(T.boundary_missed(mask));
    row.cascade_boundary_missed_rate = mean_or_nan_local(T.cascade_boundary_missed(mask));
    row.low_confidence_rate = mean_or_nan_local(T.low_confidence(mask));
    row.model_margin_mean = mean_or_nan_local(T.model_margin(mask));
    row.J1_mean = mean_or_nan_local(T.J1(mask));
    row.J2_mean = mean_or_nan_local(T.J2(mask));
    row.J3_mean = mean_or_nan_local(T.J3(mask));
    row.runtime_mean = mean_or_nan_local(T.runtime_sec(mask));
    row.cascade_runtime_mean = mean_or_nan_local(T.cascade_runtime_sec(mask));
end

function tbl = build_step810_threshold_sweep_local(T, cfg810)
    rows = {};
    idx = 0;
    cal_max = min(10, max(1, floor(max(T.mc) / 3)));
    in_scope = T.in_scope_shared_center_flag;
    cal_mask = in_scope & T.mc <= cal_max;
    val_mask = in_scope & T.mc > cal_max;
    if ~any(val_mask)
        val_mask = cal_mask;
    end
    for ti = cfg810.sweep_tau_improve
        for tm = cfg810.sweep_tau_model_margin
            for ta = cfg810.sweep_tau_abs_residual
                thr = cfg810.default_thresholds;
                thr.tau_improve = ti;
                thr.tau_model_margin = tm;
                thr.tau_abs_residual = ta;
                cal = evaluate_threshold_metrics_local(T, cal_mask, thr, cfg810);
                val = evaluate_threshold_metrics_local(T, val_mask, thr, cfg810);
                idx = idx + 1;
                row = struct();
                row.tau_improve = ti;
                row.tau_model_margin = tm;
                row.tau_h3_over_h2 = thr.tau_h3_over_h2;
                row.tau_abs_residual = ta;
                row.calibration_trials = cal.n;
                row.validation_trials = val.n;
                row.calibration_success = cal.success_rate;
                row.calibration_false_high = cal.false_high_rate;
                row.calibration_boundary_missed = cal.boundary_missed_rate;
                row.calibration_H0_rate = cal.H0_rate;
                row.calibration_score = cal.success_rate - 5 * cal.false_high_rate - 5 * cal.boundary_missed_rate - 0.5 * cal.H0_rate;
                row.validation_success = val.success_rate;
                row.validation_false_high = val.false_high_rate;
                row.validation_boundary_missed = val.boundary_missed_rate;
                row.validation_H0_rate = val.H0_rate;
                row.is_default_threshold = abs(ti - cfg810.tau_improve) < 1e-12 && ...
                    abs(tm - cfg810.tau_model_margin) < 1e-12 && abs(ta - cfg810.tau_abs_residual) < 1e-12;
                rows{idx, 1} = row; %#ok<AGROW>
            end
        end
    end
    tbl = struct2table([rows{:}]);
    [~, best_idx] = max(tbl.calibration_score);
    tbl.best_by_calibration = false(height(tbl), 1);
    tbl.best_by_calibration(best_idx) = true;
end

function metrics = evaluate_threshold_metrics_local(T, mask, thr, cfg810)
    idx = find(mask);
    n = numel(idx);
    success = false(n, 1);
    false_high = false(n, 1);
    boundary_missed = false(n, 1);
    h0 = false(n, 1);
    for k = 1:n
        r = T(idx(k), :);
        [model, conf] = select_model_from_table_row_local(r, thr);
        [success(k), false_high(k), boundary_missed(k), low_conf] = evaluate_unified_row_selection_local(r, model, conf, cfg810);
        h0(k) = low_conf || model == "H0_boundary";
    end
    metrics = struct();
    metrics.n = n;
    metrics.success_rate = mean_or_nan_local(success);
    metrics.false_high_rate = mean_or_nan_local(false_high);
    metrics.boundary_missed_rate = mean_or_nan_local(boundary_missed);
    metrics.H0_rate = mean_or_nan_local(h0);
end

function [model, conf] = select_model_from_table_row_local(r, thr)
    h1 = struct('J', r.J1, 'theta', r.H1_theta, 'el', r.H1_el);
    h2 = struct('J', r.J2, 'theta1', r.H2_theta1, 'theta2', r.H2_theta2, 'el', r.H2_el);
    h3 = struct('J', r.J3, 'theta1', r.H3_theta1, 'theta2', r.H3_theta2, 'el1', r.H3_el1, 'el2', r.H3_el2);
    d = select_unified_model_local(h1, h2, h3, thr);
    model = d.model_selected;
    conf = d.confidence_flag;
end

function [success, false_high, boundary_missed, low_conf] = evaluate_unified_row_selection_local(r, model, conf, cfg810)
    sc = struct();
    sc.target_count = r.target_count;
    sc.theta1 = r.true_az1;
    sc.theta2 = r.true_az2;
    sc.el1 = r.true_el1;
    sc.el2 = r.true_el2;
    sc.weak_target_truth_flag = r.weak_target_truth_flag;
    sc.anti_phase_truth_flag = r.anti_phase_truth_flag;
    [success, false_high, boundary_missed, low_conf] = evaluate_unified_success_local(sc, model, conf, ...
        r.H1_theta, r.H1_el, r.H2_theta1, r.H2_theta2, r.H2_el, ...
        r.H3_theta1, r.H3_theta2, r.H3_el1, r.H3_el2, cfg810);
end

function tbl = build_step810_model_confusion_local(T)
    truth = strings(height(T), 1);
    for i = 1:height(T)
        if T.target_count(i) == 1
            truth(i) = "single";
        elseif T.large_el_truth_flag(i)
            truth(i) = "large_el_pair";
        elseif T.weak_target_truth_flag(i)
            truth(i) = "weak_boundary";
        elseif T.anti_phase_truth_flag(i)
            truth(i) = "antiphase_boundary";
        elseif T.beta(i) == 0.5
            truth(i) = "medium_beta_pair";
        else
            truth(i) = "close_coherent_pair";
        end
    end
    truth_names = unique(truth, 'stable');
    model_names = ["H1_single", "H2_coherent_pair", "H3_2d_pair", "H0_boundary"];
    rows = {};
    idx = 0;
    for it = 1:numel(truth_names)
        for im = 1:numel(model_names)
            mask = T.in_scope_shared_center_flag & truth == truth_names(it);
            idx = idx + 1;
            row = struct();
            row.truth_class = truth_names(it);
            row.model_selected = model_names(im);
            row.count = sum(mask & T.model_selected == model_names(im));
            row.rate = row.count / max(sum(mask), 1);
            rows{idx, 1} = row; %#ok<AGROW>
        end
    end
    tbl = struct2table([rows{:}]);
end

function keypoints_tbl = build_step810_keypoints_local(T, S, sweep_tbl, Metkl, quick_mode, cfg810)
    rows = {};
    rows = add_step810_kp_local(rows, "Metkl", Metkl, "Monte Carlo trials per scenario-SNR case");
    rows = add_step810_kp_local(rows, "quick_mode_flag", double(quick_mode), "1 means quick trend only");
    rows = add_step810_kp_local(rows, "total_trials", height(T), "all trials");
    rows = add_step810_kp_local(rows, "in_scope_trials", sum(T.in_scope_shared_center_flag), "shared-center trials");
    overall = S(S.scenario_name == "overall", :);
    rows = add_step810_kp_local(rows, "unified_success_overall", overall.unified_success_rate, "in-scope default threshold");
    rows = add_step810_kp_local(rows, "cascade_success_overall", overall.cascade_success_rate, "same Y_work cascade baseline");
    rows = add_step810_kp_local(rows, "success_gap_unified_vs_cascade", overall.success_gap_unified_vs_cascade, "unified minus cascade");
    rows = add_step810_kp_local(rows, "unified_false_high", overall.unified_false_high_rate, "default threshold");
    rows = add_step810_kp_local(rows, "unified_boundary_missed", overall.unified_boundary_missed_rate, "default threshold");
    rows = add_step810_kp_local(rows, "cascade_false_high", overall.cascade_false_high_rate, "cascade baseline");
    rows = add_step810_kp_local(rows, "cascade_boundary_missed", overall.cascade_boundary_missed_rate, "cascade baseline");
    rows = add_step810_kp_local(rows, "single_target_H1_rate", scenario_metric_local(S, "single_target_sanity", "H1_select_rate"), "single target model distribution");
    rows = add_step810_kp_local(rows, "close_coherent_H2_rate", scenario_metric_local(S, "close_coherent_pair", "H2_select_rate"), "close coherent model distribution");
    rows = add_step810_kp_local(rows, "large_el_H3_rate", scenario_metric_local(S, "large_el_pair", "H3_select_rate"), "large elevation model distribution");
    weak_h0 = scenario_metric_local(S, "weak_target_boundary", "H0_select_rate");
    anti_h0 = scenario_metric_local(S, "near_antiphase_boundary", "H0_select_rate");
    rows = add_step810_kp_local(rows, "weak_target_boundary_rate", weak_h0, "weak target H0 rate");
    rows = add_step810_kp_local(rows, "antiphase_boundary_rate", anti_h0, "near anti-phase H0 rate");
    rows = add_step810_kp_local(rows, "unified_runtime_mean", overall.runtime_mean, "seconds");
    rows = add_step810_kp_local(rows, "cascade_runtime_mean", overall.cascade_runtime_mean, "seconds");
    default_row = sweep_tbl(sweep_tbl.is_default_threshold, :);
    best_row = sweep_tbl(sweep_tbl.best_by_calibration, :);
    default_pass = default_row.validation_false_high == 0 && default_row.validation_boundary_missed == 0;
    best_pass = best_row.validation_false_high == 0 && best_row.validation_boundary_missed == 0;
    rows = add_step810_kp_local(rows, "threshold_default_pass_flag", double(default_pass), "validation safety for default thresholds");
    rows = add_step810_kp_local(rows, "threshold_sweep_best_pass_flag", double(best_pass), "validation safety for calibration-selected thresholds");
    safe = overall.unified_false_high_rate == 0 && overall.unified_boundary_missed_rate == 0;
    close_ok = scenario_metric_local(S, "close_coherent_pair", "unified_success_rate") >= scenario_metric_local(S, "close_coherent_pair", "cascade_success_rate") - 0.08;
    large_ok = scenario_metric_local(S, "large_el_pair", "unified_success_rate") >= 0.90;
    success_ok = overall.unified_success_rate >= overall.cascade_success_rate - 0.05;
    physics_ok = scenario_metric_local(S, "single_target_sanity", "H1_select_rate") >= 0.50 && ...
        scenario_metric_local(S, "close_coherent_pair", "H2_select_rate") >= 0.40 && ...
        scenario_metric_local(S, "large_el_pair", "H3_select_rate") >= 0.40;
    adopt = safe && close_ok && large_ok && success_ok && physics_ok;
    if adopt
        route = "unified_model_selection";
        blocker = "";
    elseif safe
        route = "keep_cascade_but_explain_as_model_selection_approximation";
        blocker = "success_or_model_distribution_not_enough";
    else
        route = "keep_cascade";
        blocker = "unified_model_selection_not_safe";
    end
    rows = add_step810_kp_local(rows, "recommended_final_route", NaN, route);
    rows = add_step810_kp_local(rows, "adopt_unified_model_selection_flag", double(adopt), "1 means replace cascade");
    rows = add_step810_kp_local(rows, "blocker_if_any", NaN, blocker);
    rows = add_step810_kp_local(rows, "no_true_angle_assisted_selection_flag", 1, "truth is only used for validation");
    rows = add_step810_kp_local(rows, "H2_concentrated_coherent_gain_flag", 1, "rank-1 coherent concentrated gain is used");
    rows = add_step810_kp_local(rows, "H3_candidate_only_no_truth_flag", 1, "H3 candidates come from projection peaks");
    keypoints_tbl = struct2table([rows{:}]);
end

function rows = add_step810_kp_local(rows, key, value, note)
    row = struct('keypoint', string(key), 'value', value, 'note', string(note));
    rows{end+1, 1} = row;
end

function val = scenario_metric_local(S, scenario_name, colname)
    mask = S.scenario_name == string(scenario_name);
    if any(mask)
        val = S.(colname)(find(mask, 1));
    else
        val = NaN;
    end
end

function m = mean_or_nan_local(x)
    x = x(:);
    if isempty(x)
        m = NaN;
    else
        x = double(x);
        x = x(isfinite(x));
        if isempty(x)
            m = NaN;
        else
            m = mean(x);
        end
    end
end

function plot_step810_score_example_local(C, scenario_name, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    if isempty(C) || ~any(C.scenario_name == string(scenario_name))
        text(0.1, 0.5, sprintf('No candidate score example: %s', scenario_name), 'Interpreter', 'none');
        axis off
    else
        mask = C.scenario_name == string(scenario_name);
        mc0 = C.mc(find(mask, 1));
        snr0 = C.snr_db(find(mask, 1));
        mask = mask & C.mc == mc0 & C.snr_db == snr0;
        models = unique(C.model_name(mask), 'stable');
        vals = NaN(numel(models), 1);
        for i = 1:numel(models)
            vals(i) = min(C.J(mask & C.model_name == models(i)));
        end
        bar(categorical(models), vals);
        ylabel('min residual J');
        title(sprintf('%s candidate residual example', scenario_name), 'Interpreter', 'none');
        grid on
    end
    saveas(fig, path_out);
    close(fig);
end

function plot_step810_model_distribution_local(T, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    names = unique(T.scenario_name, 'stable');
    models = ["H1_single", "H2_coherent_pair", "H3_2d_pair", "H0_boundary"];
    Y = zeros(numel(names), numel(models));
    for i = 1:numel(names)
        mask = T.in_scope_shared_center_flag & T.scenario_name == names(i);
        for j = 1:numel(models)
            Y(i, j) = mean_or_nan_local(T.model_selected(mask) == models(j));
        end
    end
    bar(categorical(names), Y, 'stacked');
    ylabel('selection rate');
    legend(models, 'Location', 'eastoutside', 'Interpreter', 'none');
    title('Unified model selection distribution');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_step810_success_compare_local(S, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    S2 = S(S.scenario_name ~= "overall", :);
    Y = [S2.unified_success_rate, S2.cascade_success_rate];
    bar(categorical(S2.scenario_name), Y);
    ylabel('success rate');
    legend(["unified", "cascade"], 'Location', 'southoutside');
    title('Unified vs cascade success');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_step810_false_boundary_local(S, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    S2 = S(S.scenario_name ~= "overall", :);
    Y = [S2.unified_false_high_rate, S2.unified_boundary_missed_rate, ...
        S2.cascade_false_high_rate, S2.cascade_boundary_missed_rate];
    bar(categorical(S2.scenario_name), Y);
    ylabel('rate');
    legend(["unified false-high", "unified boundary-missed", "cascade false-high", "cascade boundary-missed"], ...
        'Location', 'southoutside', 'Interpreter', 'none');
    title('False-high and boundary-missed safety');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_step810_residual_by_scenario_local(T, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    names = unique(T.scenario_name, 'stable');
    Y = zeros(numel(names), 3);
    for i = 1:numel(names)
        mask = T.in_scope_shared_center_flag & T.scenario_name == names(i);
        Y(i, :) = [mean_or_nan_local(T.J1(mask)), mean_or_nan_local(T.J2(mask)), mean_or_nan_local(T.J3(mask))];
    end
    bar(categorical(names), Y);
    ylabel('mean residual J');
    legend(["H1", "H2", "H3"], 'Location', 'southoutside');
    title('Model residual by scenario');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_step810_margin_by_scenario_local(T, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    names = unique(T.scenario_name, 'stable');
    y = zeros(numel(names), 1);
    for i = 1:numel(names)
        mask = T.in_scope_shared_center_flag & T.scenario_name == names(i);
        y(i) = mean_or_nan_local(T.model_margin(mask));
    end
    bar(categorical(names), y);
    ylabel('mean model margin');
    title('Model margin by scenario');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_step810_threshold_sweep_local(tbl, path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    x = 1:height(tbl);
    yyaxis left
    plot(x, tbl.validation_success, '-o', 'LineWidth', 1);
    ylabel('validation success');
    yyaxis right
    plot(x, tbl.validation_false_high + tbl.validation_boundary_missed, '-s', 'LineWidth', 1);
    ylabel('safety violation rate');
    hold on
    best = find(tbl.best_by_calibration, 1);
    if ~isempty(best)
        xline(best, '--k', 'best');
    end
    title('Threshold sweep validation');
    xlabel('sweep index');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_step810_flowchart_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1200, 500]);
    axis off
    boxes = {
        [0.03, 0.58, 0.18, 0.22], 'frontend single coarse peak';
        [0.27, 0.58, 0.16, 0.22], '65x32 Y\_work';
        [0.49, 0.72, 0.14, 0.16], 'H1 single';
        [0.49, 0.52, 0.14, 0.16], 'H2 coherent pair';
        [0.49, 0.32, 0.14, 0.16], 'H3 2D pair';
        [0.70, 0.52, 0.18, 0.22], 'compare J, improvement, margin';
        [0.91, 0.58, 0.08, 0.14], 'H0/H1/H2/H3'
        };
    for i = 1:size(boxes, 1)
        rectangle('Position', boxes{i, 1}, 'Curvature', 0.02, 'LineWidth', 1.5);
        text(boxes{i, 1}(1)+boxes{i, 1}(3)/2, boxes{i, 1}(2)+boxes{i, 1}(4)/2, boxes{i, 2}, ...
            'HorizontalAlignment', 'center', 'Interpreter', 'tex');
    end
    annotation('arrow', [0.21, 0.27], [0.69, 0.69]);
    annotation('arrow', [0.43, 0.49], [0.69, 0.80]);
    annotation('arrow', [0.43, 0.49], [0.69, 0.60]);
    annotation('arrow', [0.43, 0.49], [0.69, 0.40]);
    annotation('arrow', [0.63, 0.70], [0.80, 0.63]);
    annotation('arrow', [0.63, 0.70], [0.60, 0.63]);
    annotation('arrow', [0.63, 0.70], [0.40, 0.63]);
    annotation('arrow', [0.88, 0.91], [0.63, 0.65]);
    title('Step 8.10 unified model selection flow');
    saveas(fig, path_out);
    close(fig);
end

function write_step810_formula_doc_local(path_out, cfg810)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.10步 统一模型选择公式与流程说明\n\n');
    fprintf(fid, '## 1. 输入观测\n\n');
    fprintf(fid, '输入来自第 8.8 shared-center 接口：`Y_work(q,m,p)`，其中 `q=1...65`，`m=1...32`，`p=1...T_snap`，默认 `T_snap=Np=32`，默认不启用 Doppler de-rotation。two separated coarse peaks 仍为 out-of-scope。\n\n');
    fprintf(fid, '评分子阵固定为 `K_phi_score=%d`、`K_z_score=%d`，从 65x32 工作子阵中心抽取，列优先向量化：`Y_score(:,p)=subarray_20x8(:,:,p)(:)`，`M=%d`。\n\n', cfg810.K_phi_score, cfg810.K_z_score, cfg810.M_score);
    fprintf(fid, '样本协方差：`R=(1/T)Y_score Y_score^H`，并记录 `R_norm=||R||_F`。若 `R_norm` 过小，直接输出 `H0_boundary/low_confidence`。\n\n');
    fprintf(fid, '## 2. steering 定义\n\n');
    fprintf(fid, '`a(theta,el)` 使用与第 8.7/8.8 一致的圆柱阵 calibrated steering，并统一归一化：`a_bar=a/max(||a||_2,eps)`。H1/H2/H3 全部使用归一化 steering。\n\n');
    fprintf(fid, '## 3. 通用残差评分\n\n');
    fprintf(fid, '对任意 `A in C^(M x K)`：`P_A=A inv(A^H A + eps_reg I) A^H`，`eps_reg=%.1e`。\n\n', cfg810.eps_reg);
    fprintf(fid, '`sigma2_A=max(real(trace((I-P_A)R))/max(M-K,1),0)`。\n\n');
    fprintf(fid, '`R_A=P_A R P_A + sigma2_A (I-P_A)`。\n\n');
    fprintf(fid, '`J(A)=||R-R_A||_F^2 / max(||R||_F^2,eps)`。J 越小，模型解释能力越强。\n\n');
    fprintf(fid, '## 4. H1/H2/H3/H0\n\n');
    fprintf(fid, '- H1: `A1=a_bar(theta,el)`，搜索 `theta_center+[-2,2] deg` 与 `el=-2:0.5:12 deg`，top 5 局部细化。\n');
    fprintf(fid, '- H2: `A12=[a(theta_a,el_c),a(theta_b,el_c)]`，构造 `Q=A12 inv(chol(A12^H A12+eps_reg I))`，在 `B=Q^H R Q` 中取最大特征向量，得到 `c=Q u_max/max(||Q u_max||,eps)`，以 `J(c)` 评分。\n');
    fprintf(fid, '- H3: `A3=[a(theta_a,el_a),a(theta_b,el_b)]`。候选只来自 2D projection/MUSIC-like 峰及两两组合，不使用真值；最终仍用 `J(A3)` 选择。\n');
    fprintf(fid, '- H0: 当绝对残差过大、模型 margin 太小或改善量不足时，输出 `H0_boundary`。\n\n');
    fprintf(fid, '## 5. 默认选择规则\n\n');
    fprintf(fid, '`improve_21=(J1-J2)/max(J1,eps)`，`improve_31=(J1-J3)/max(J1,eps)`，`improve_32=(J2-J3)/max(J2,eps)`。\n\n');
    fprintf(fid, '`model_margin=(J_sorted(2)-J_sorted(1))/max(J_sorted(1),eps)`。\n\n');
    fprintf(fid, '默认阈值：`tau_improve=%.2f`，`tau_model_margin=%.2f`，`tau_h3_over_h2=%.2f`，`tau_abs_residual=%.2f`。\n\n', cfg810.tau_improve, cfg810.tau_model_margin, cfg810.tau_h3_over_h2, cfg810.tau_abs_residual);
    fprintf(fid, '本轮同时输出 default threshold 与 small sweep；Metkl=30 时 mc=1:10 为 calibration，mc=11:30 为 validation。quick mode 只作为趋势检查。\n');
end

function write_step810_record_doc_local(path_out, keypoints_tbl, summary_tbl, sweep_tbl, result_dir, elapsed_sec, Metkl, quick_mode)
    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.10步 统一模型选择增强测角验证记录\n\n');
    fprintf(fid, '## 1. 本轮目的\n\n');
    fprintf(fid, '验证在同一个第 8.8 `Y_work` 局部观测下，用 H1/H2/H3/H0 统一模型选择替代或解释第 8.7 级联分流是否可行。\n\n');
    fprintf(fid, '## 2. 运行范围\n\n');
    fprintf(fid, '- 脚本：`space_smooth_music_B_unified_model_selection_validation.m`\n');
    fprintf(fid, '- 短名 runner：`unified_model_selection_validation.m`\n');
    fprintf(fid, '- 结果目录：`%s`\n', result_dir);
    fprintf(fid, '- Metkl=%d，quick_mode=%d，elapsed_sec=%.2f\n\n', Metkl, quick_mode, elapsed_sec);
    if quick_mode
        fprintf(fid, '> 注意：quick mode 结果不是正式结论。\n\n');
    end
    fprintf(fid, '## 3. 方法摘要\n\n');
    fprintf(fid, 'H1/H2/H3 使用同一个评分子阵和同一个协方差拟合残差 `J(A)`；H2 使用 concentrated coherent gain；H3 候选来自二维投影峰，不使用真值参与候选生成或模型选择。\n\n');
    fprintf(fid, '## 4. Keypoints\n\n');
    write_markdown_table_local(fid, keypoints_tbl);
    fprintf(fid, '\n## 5. Scenario summary\n\n');
    write_markdown_table_local(fid, summary_tbl);
    fprintf(fid, '\n## 6. Threshold sweep\n\n');
    write_markdown_table_local(fid, sweep_tbl);
    fprintf(fid, '\n## 7. 与第8.7 cascade 的关系\n\n');
    route = string(keypoint_note_local(keypoints_tbl, "recommended_final_route"));
    adopt = keypoint_value_from_table_local(keypoints_tbl, "adopt_unified_model_selection_flag");
    if adopt == 1
        fprintf(fid, '本轮 validation 满足采用条件，建议将第 8.10 作为最终主线，并把 cascade 简化为 unified model selection 的工程实现形式。\n');
    elseif contains(route, "explain")
        fprintf(fid, '本轮未建议直接替代第 8.7 cascade，但安全性可接受；建议论文中把 cascade 解释为模型选择近似和预算感知实现。\n');
    else
        fprintf(fid, '本轮不建议替代第 8.7 cascade。统一模型选择存在安全性或稳定性 blocker，应保留 cascade。\n');
    end
end

function write_markdown_table_local(fid, tbl)
    if isempty(tbl) || height(tbl) == 0
        fprintf(fid, '_empty_\n');
        return
    end
    names = tbl.Properties.VariableNames;
    fprintf(fid, '| %s |\n', strjoin(names, ' | '));
    fprintf(fid, '|%s|\n', strjoin(repmat({'---'}, 1, numel(names)), '|'));
    for i = 1:height(tbl)
        vals = strings(1, numel(names));
        for j = 1:numel(names)
            v = tbl.(names{j})(i);
            if isnumeric(v) || islogical(v)
                vals(j) = string(num2str(v, '%.6g'));
            else
                vals(j) = string(v);
            end
        end
        fprintf(fid, '| %s |\n', strjoin(vals, ' | '));
    end
end

function note = keypoint_note_local(tbl, key)
    mask = tbl.keypoint == string(key);
    if any(mask)
        note = tbl.note(find(mask, 1));
    else
        note = "";
    end
end
