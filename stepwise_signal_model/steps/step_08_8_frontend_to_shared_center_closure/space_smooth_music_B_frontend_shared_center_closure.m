% Step 8.8 frontend detection to shared-center enhanced DOA closure.
%
% Scope:
% 1) Define and exercise the frontend_out -> enhance_in interface.
% 2) Use one CPI observation containing two superposed spatial components.
% 3) Run the Step 8.7 shared-center lazy cascade without changing its gates.
%
% This is not FPGA, not fixed point, not MC=100, and not dual-center.

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

result_dir = fullfile(script_dir, 'results_step8_8_frontend_shared_center_closure');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_8_frontend_shared_center_closure.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

summary_csv_path = fullfile(result_dir, 'step8_8_frontend_shared_center_closure_summary.csv');
keypoints_csv_path = fullfile(result_dir, 'step8_8_frontend_shared_center_closure_keypoints.csv');
trial_csv_path = fullfile(result_dir, 'step8_8_frontend_shared_center_closure_trial.csv');
mat_path = fullfile(result_dir, 'step8_8_frontend_shared_center_closure_result.mat');
record_doc_path = fullfile(script_dir, '第8.8步_前端检测到shared-center增强测角接口与闭环验证记录.md');
interface_doc_path = fullfile(script_dir, '第8.8步_前端到第8.7接口定义.md');

quick_mode = strcmpi(getenv('STEP88_QUICK_MODE'), '1');
if quick_mode
    Metkl = 5;
else
    Metkl = 30;
end

snr_list = [8, 16];
base_seed = 20261008;
scenarios = build_step88_scenarios_local(cfg88, snr_list);
total_trials = numel(scenarios) * Metkl;

log_msg_local(fid_log, 'Step 8.8 frontend-to-shared-center closure');
log_msg_local(fid_log, 'quick_mode=%d, Metkl=%d, total_trials=%d, SNR=%s', ...
    quick_mode, Metkl, total_trials, mat2str(snr_list));
if quick_mode
    log_msg_local(fid_log, 'WARNING: quick_mode=1. Results are quick trend only and not formal conclusion.');
end
log_msg_local(fid_log, 'Scope: frontend LFM/PC/MTD/CFAR/coarse angle to Step 8.7 shared-center lazy cascade.');
log_msg_local(fid_log, 'No dual-center, no fixed point, no FPGA, no V2, no weak-target SIC, no anti-phase derivative.');
log_msg_local(fid_log, 'Step 8.7 lazy route thresholds are copied from part 7B and not changed.');

[array_geom, pc_model] = init_frontend_models_local(cfg88);
log_msg_local(fid_log, 'Array: Naz=%d, Nel=%d, selected work columns=%d, column spacing=%.6f deg.', ...
    cfg88.Naz, cfg88.Nel, cfg88.workColumns, cfg88.columnSpacingDeg);
log_msg_local(fid_log, 'Pulse model: Np=%d, nRange=%d, rangeIdxTruth=%d, velocity=%.3f m/s.', ...
    cfg88.Np, cfg88.nRange, pc_model.rangeIdxTruth, cfg88.velocity_mps);

context_cache = struct('key', {}, 'ctx', {});
trial_rows = cell(total_trials, 1);
example_store = struct('scenario_name', {}, 'snr_db', {}, 'az_scan', {}, 'power', {}, ...
    'coarseAz', {}, 'trueAz', {}, 'selectedCenterAz', {});
row_idx = 0;
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
            [enhance_out, timing] = run_step87_shared_center_lazy_local(enhance_in, sc, ctx, cfg88);
        else
            enhance_in = make_empty_enhance_input_local(frontend_out, cfg88);
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
        end

        row_idx = row_idx + 1;
        trial_rows{row_idx} = make_trial_row_local(sc, imc, frontend_out, enhance_in, enhance_out, timing, cfg88);
    end
end

elapsed_sec = toc(tic_all);
trial_rows = trial_rows(1:row_idx);
trial_tbl = struct2table([trial_rows{:}]);
summary_tbl = build_step88_summary_table_local(trial_tbl);
keypoints_tbl = build_step88_keypoints_local(trial_tbl, summary_tbl, Metkl, quick_mode, cfg88);

log_msg_local(fid_log, 'Runtime loops finished in %.2f sec.', elapsed_sec);
log_msg_local(fid_log, 'Writing CSV/MAT outputs.');
writetable(trial_tbl, trial_csv_path);
writetable(summary_tbl, summary_csv_path);
writetable(keypoints_tbl, keypoints_csv_path);

log_msg_local(fid_log, 'Rendering plots.');
plot_coarse_peak_examples_local(example_store, fullfile(result_dir, 'coarse_peak_examples.png'));
copyfile(fullfile(result_dir, 'coarse_peak_examples.png'), fullfile(result_dir, 'frontend_coarse_peak_examples.png'), 'f');
plot_center_error_local(summary_tbl, fullfile(result_dir, 'coarse_center_error_by_scenario.png'));
copyfile(fullfile(result_dir, 'coarse_center_error_by_scenario.png'), fullfile(result_dir, 'selected_work_array_center_error.png'), 'f');
plot_delta_coverage_local(summary_tbl, fullfile(result_dir, 'delta_theta_coverage_R15_R20.png'));
copyfile(fullfile(result_dir, 'delta_theta_coverage_R15_R20.png'), fullfile(result_dir, 'delta_theta_coverage.png'), 'f');
plot_route_distribution_local(trial_tbl, fullfile(result_dir, 'route_distribution_by_scenario.png'));
copyfile(fullfile(result_dir, 'route_distribution_by_scenario.png'), fullfile(result_dir, 'route_distribution.png'), 'f');
plot_success_false_high_local(summary_tbl, fullfile(result_dir, 'success_false_high_summary.png'));
copyfile(fullfile(result_dir, 'success_false_high_summary.png'), fullfile(result_dir, 'success_by_scenario.png'), 'f');
copyfile(fullfile(result_dir, 'success_false_high_summary.png'), fullfile(result_dir, 'false_high_boundary_summary.png'), 'f');
plot_runtime_local(summary_tbl, fullfile(result_dir, 'runtime_by_scenario.png'));

save(mat_path, 'trial_tbl', 'summary_tbl', 'keypoints_tbl', 'cfg88', 'array_geom', ...
    'pc_model', 'example_store', 'elapsed_sec', 'Metkl', 'quick_mode', '-v7.3');

write_interface_doc_local(interface_doc_path, cfg88);
write_record_doc_local(record_doc_path, keypoints_tbl, summary_tbl, result_dir, elapsed_sec, Metkl, quick_mode);

log_msg_local(fid_log, 'Outputs written to %s', result_dir);
log_msg_local(fid_log, 'Record doc: %s', record_doc_path);
log_msg_local(fid_log, 'Interface doc: %s', interface_doc_path);

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
    [coarseAz0, coarseMetric, coarsePeakCount, coarseWidth, coarseProm, coarsePower] = ...
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

    frontend_out = struct();
    frontend_out.rangeIdx = rangeIdx;
    frontend_out.dopplerIdx = dopplerIdx;
    frontend_out.range_m = range_m;
    frontend_out.velocity_mps = velocity_mps;
    frontend_out.coarseAz_deg = coarseAz;
    frontend_out.coarseEl_deg = coarseEl;
    frontend_out.coarseMetric = coarseMetric;
    frontend_out.peakCountCoarse = coarsePeakCount;
    frontend_out.coarsePeakWidth = coarseWidth;
    frontend_out.coarsePeakProminence = coarseProm;
    frontend_out.selectedCenterColumn = selectedCenterColumn;
    frontend_out.selectedCenterAz_deg = selectedCenterAz;
    frontend_out.selectedWorkColumns = selectedWorkColumns;
    frontend_out.cfarCount = nRaw;
    frontend_out.cfarBestMetric = cfarBestMetric;
    frontend_out.cfar_detected_flag = cfar_detected;
    frontend_out.two_coarse_peaks_out_of_scope = two_out;
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

function [coarseAz, coarseMetric, peakCount, peakWidth, peakProminence, P] = ...
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
    [peakCount, peakWidth, peakProminence] = coarse_peak_metrics_local( ...
        cfg88.coarseScanAz_deg, P, cfg88.coarsePeakMergeThreshold_deg, cfg88.coarsePeakProminenceThreshold);
end

function [peakCount, width, prominence] = coarse_peak_metrics_local(axis, P, mergeThresh, promThresh)
    P = real(P(:)).';
    axis = axis(:).';
    [pmax, imax] = max(P);
    idx = [];
    for i = 2:numel(P)-1
        if P(i) >= P(i-1) && P(i) >= P(i+1) && P(i) >= promThresh * pmax
            idx(end+1) = i; %#ok<AGROW>
        end
    end
    if isempty(idx)
        idx = imax;
    end
    [~, ord] = sort(P(idx), 'descend');
    idx = idx(ord);
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
    in_scope = mask & T.cfar_detected_flag & ~T.two_coarse_peaks_out_of_scope;
    route_dist = distribution_string_local(T.route_used(mask));
    row = struct();
    row.scenario_name = string(name);
    row.num_trials = numel(idx);
    row.cfar_detection_rate = mean(double(T.cfar_detected_flag(mask)), 'omitnan');
    row.single_coarse_peak_rate = mean(double(T.coarse_peak_count(mask) == 1), 'omitnan');
    row.two_coarse_peak_rate = mean(double(T.two_coarse_peaks_out_of_scope(mask)), 'omitnan');
    row.two_coarse_peak_out_of_scope_rate = row.two_coarse_peak_rate;
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
    row.mean_abs_center_error_to_pair_center = mean(abs(T.center_error_to_pair_center(mask)), 'omitnan');
    row.mean_abs_center_error_to_strong_target = mean(abs(T.center_error_to_strong_target(mask)), 'omitnan');
    row.route_distribution = route_dist;
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
    fprintf(fid, '## 1. 前端输出 frontend_out\n\n');
    fprintf(fid, '第 5/6 步前端输出以下字段：`rangeIdx`、`dopplerIdx`、`range_m`、`velocity_mps`、`coarseAz_deg`、`coarseEl_deg`、`coarseMetric`、`peakCountCoarse`、`coarsePeakWidth`、`coarsePeakProminence`、`selectedCenterColumn`、`selectedCenterAz_deg`、`selectedWorkColumns`、`cfarCount`、`cfarBestMetric`。\n\n');
    fprintf(fid, '- `rangeIdx / dopplerIdx` 来自 MTD + CFAR。\n');
    fprintf(fid, '- `coarseAz / coarseEl` 来自低成本粗方位 beamformer 和检测单元上的三波束比幅。\n');
    fprintf(fid, '- `selectedCenterColumn` 是 `coarseAz` 吸附到最近实际阵元列后的中心列。\n');
    fprintf(fid, '- `selectedWorkColumns` 是中心列左右各 32 列，总共 65 列，按圆柱阵列周期回绕。\n\n');
    fprintf(fid, '## 2. 第8.7 shared-center 输入 enhance_in\n\n');
    fprintf(fid, '第 8.7 shared-center 增强测角输入：`Y_work`、`thetaCenter_deg`、`elAssumed_deg`、`rangeIdx`、`dopplerIdx`、`R_runtime_default_deg`、`R_runtime_expand_deg`、`template_R_deg`、`cfg`、`arrayInfo`。\n\n');
    fprintf(fid, '- `R_runtime_default_deg = %.1f deg`\n', cfg88.R_runtime_default_deg);
    fprintf(fid, '- `R_runtime_expand_deg = %.1f deg`\n', cfg88.R_runtime_expand_deg);
    fprintf(fid, '- `template_R_deg = %.1f deg`\n', cfg88.template_R_deg);
    fprintf(fid, '- `Y_work` 的尺寸为 `65 x 32 x T_snap`，本轮 `T_snap=Np=%d`。\n\n', cfg88.Np);
    fprintf(fid, '## 3. Y_work 构造\n\n');
    fprintf(fid, '本轮优先使用 MTD 前慢时间快拍。理论形式为：\n\n');
    fprintf(fid, '`Y_elem(:, p) = pcCube(:, rangeIdx, p)`\n\n');
    fprintf(fid, '若目标有 Doppler，则按检测到的 Doppler bin 做去旋：\n\n');
    fprintf(fid, '`Y_elem(:, p) = pcCube(:, rangeIdx, p) * exp(-j*2*pi*fd_hat*tSlow(p))`\n\n');
    fprintf(fid, '随后按 `selectedWorkColumns` 抽取 65 列，并 reshape 为 `Y_work = [65, 32, T_snap]`。本轮脚本为节省运行时间，保存的是检测距离单元的阵元级快拍 `pc_like.Y_full_range`，它等价于 `pcCube(:, rangeIdx, :)`；完整全阵版本只需把该快拍替换为实际 `pcCube` 抽取。\n\n');
    fprintf(fid, '## 4. 一次观测双空间分量模型\n\n');
    fprintf(fid, '两个空间分量属于同一次观测、同一 CPI、同一距离-多普勒单元中的叠加：\n\n');
    fprintf(fid, '`x(t) = a(theta1, el1) s1(t) + a(theta2, el2) s2(t) + n(t)`\n\n');
    fprintf(fid, '`s2(t) = beta * exp(j*phi) * (rho*s1(t) + sqrt(1-rho^2)*v(t))`\n\n');
    fprintf(fid, '- `rho=1` 表示完全相干，`rho<1` 表示部分相干。\n');
    fprintf(fid, '- `beta` 表示幅度比，`phi` 表示固定相位差。\n');
    fprintf(fid, '- 前端 LFM/脉压/MTD 将叠加信号定位到一个 RD 检测单元。\n');
    fprintf(fid, '- 第 8.7 只作为该检测单元内的 shared-center 增强测角模块。\n');
end

function write_record_doc_local(path_out, keypoints_tbl, summary_tbl, result_dir, elapsed_sec, Metkl, quick_mode)
    fid = fopen(path_out, 'w', 'n', 'UTF-8');
    cleaner = onCleanup(@() safe_fclose_local(fid));
    if quick_mode
        fprintf(fid, '# 第8.8步 前端检测到shared-center增强测角接口与闭环验证记录（quick mode）\n\n');
    else
        fprintf(fid, '# 第8.8步 前端检测到shared-center增强测角接口与闭环验证记录\n\n');
    end
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 脚本：`space_smooth_music_B_frontend_shared_center_closure.m`\n');
    fprintf(fid, '- 短名 runner：`frontend_shared_center_closure.m`\n');
    fprintf(fid, '- 结果目录：`%s`\n', result_dir);
    fprintf(fid, '- Metkl=%d，quick_mode=%d。\n', Metkl, quick_mode);
    fprintf(fid, '- 本轮不是 FPGA、不是定点量化、不是 dual-center、不是 V2，也不修改第 8.7 第 7B 主线阈值。\n\n');
    fprintf(fid, '## 主链路定位\n\n');
    fprintf(fid, '- 第 1/2 步的 LFM 和脉压负责距离维压缩。\n');
    fprintf(fid, '- 第 5 步的 MTD/CFAR 负责检测距离-多普勒单元。\n');
    fprintf(fid, '- 第 6 步的三波束比幅负责提供 coarse az/el。\n');
    fprintf(fid, '- 第 8.7 只作为某个检测单元内的 shared-center 增强测角模块。\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %.6g | %s |\n', keypoints_tbl.keypoint(i), keypoints_tbl.value(i), keypoints_tbl.note(i));
    end
    fprintf(fid, '\n## Scenario summary\n\n');
    fprintf(fid, '| scenario | CFAR | single coarse | two coarse | R15 | R20 | success | false-high | boundary-missed | low-conf |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary_tbl)
        fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
            summary_tbl.scenario_name(i), summary_tbl.cfar_detection_rate(i), summary_tbl.single_coarse_peak_rate(i), ...
            summary_tbl.two_coarse_peak_rate(i), summary_tbl.both_inside_R15_rate(i), summary_tbl.both_inside_R20_rate(i), ...
            summary_tbl.step87_success_rate(i), summary_tbl.false_high_rate(i), summary_tbl.boundary_missed_rate(i), ...
            summary_tbl.low_confidence_rate(i));
    end
    fprintf(fid, '\n## 判断\n\n');
    fh = keypoint_value_from_table_local(keypoints_tbl, 'false_high_rate_overall');
    bm = keypoint_value_from_table_local(keypoints_tbl, 'boundary_missed_rate_overall');
    iface = keypoint_value_from_table_local(keypoints_tbl, 'frontend_to_step87_interface_pass_flag');
    if iface == 1 && fh == 0 && bm == 0
        fprintf(fid, '结论：前端检测到第 8.7 shared-center 增强测角接口基本闭合。弱目标边界保持 false-high=0，但当前观测量不总是降为 low confidence；近反相边界主要由 two-coarse-peaks out-of-scope、low_confidence 或 boundary_unreliable 保护。本轮不解决弱目标和近反相问题。\n\n');
    else
        fprintf(fid, '结论：接口已跑通，但需要优先复核 CFAR、粗峰或安全指标后再进入后续工程阶段。\n\n');
    end
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
