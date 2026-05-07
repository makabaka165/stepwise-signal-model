function out = run_track_loop_single_target(cfgBase)
%RUN_TRACK_LOOP_SINGLE_TARGET 第 8 步最小跨 CPI 单目标闭环扩展。
cfgBase = ensure_track_defaults_local(cfgBase);
nCpi = cfgBase.track.nCpi;
tCpi = cfgBase.wf.Np * cfgBase.wf.PRI;
[sTx, ~] = tx_lfm(cfgBase.wf);

history = repmat(make_empty_history_entry_local(), nCpi, 1);
trackState = make_empty_track_state_local();

for iCpi = 1:nCpi
    % 先推进到当前 CPI 起始时刻，用这一时刻的真值生成当前 CPI 回波。
    tStart = (iCpi - 1) * tCpi;
    truthState = propagate_truth_state_local(cfgBase, tStart);
    cfgNow = make_cfg_for_current_cpi_local(cfgBase, truthState);
    prevTrackState = trackState;

    if prevTrackState.isValid
        prediction = predict_track_state_local(prevTrackState, tCpi, iCpi);
        beamPrior = make_beam_prior_from_prediction_local(prediction, '上一CPI状态外推');
    else
        prediction = make_empty_prediction_local(iCpi);
        beamPrior = make_beam_prior_from_cfg_local(cfgBase, '初始扇区中心');
    end

    % 上一 CPI 的结果在这里仅作为当前 CPI 的波束先验和预测门限。
    cfgNow.beam.azSectorCenter = beamPrior.az;
    cfgNow.beam.elSectorCenter = beamPrior.el;
    cfgNow.beam.azSteer = cfgNow.beam.azSectorCenter;
    cfgNow.beam.elSteer = cfgNow.beam.elSectorCenter;
    cfgNow.beam.priorSource = beamPrior.source;
    if prediction.isValid
        cfgNow.track.priorRange = prediction.range;
        cfgNow.track.priorVelocity = prediction.velocity;
    else
        cfgNow.track.priorRange = NaN;
        cfgNow.track.priorVelocity = NaN;
    end

    rng(cfgBase.sim.seed + (iCpi - 1) * cfgBase.track.seedStep);
    [echoCube, truthCube] = echo_elem_cube(cfgNow);
    [pcCube, ~] = pc_range_cube(echoCube, sTx, cfgNow, true);
    jointOut = bf_joint_2d(pcCube, cfgNow);

    % 当前 CPI 先在候选集中做关联，再对被选中的候选点重新精测角。
    [selectedDetection, association] = select_associated_detection_local(jointOut, prediction, cfgNow);
    measurement = measurement_from_detection_local(jointOut, selectedDetection, association, cfgNow, iCpi);

    if measurement.isValid
        trackState = track_state_from_measurement_local( ...
            measurement, prevTrackState, tCpi, iCpi, measurement.source);
    elseif prevTrackState.isValid && cfgBase.track.holdPredictionOnMiss
        trackState = prediction;
        trackState.updateSource = '预测保持';
    else
        trackState = make_empty_track_state_local();
    end

    history(iCpi) = build_history_entry_local( ...
        iCpi, tStart, truthState, truthCube, beamPrior, prediction, ...
        association, measurement, trackState, cfgNow, jointOut);
end

out = struct();
out.cfg = cfgBase;
out.tCpi = tCpi;
out.history = history;
out.summary = build_track_summary_local(history);
out.finalState = trackState;
end

function cfg = ensure_track_defaults_local(cfg)
if ~isfield(cfg, 'track') || isempty(cfg.track)
    cfg.track = struct();
end
if ~isfield(cfg.track, 'nCpi') || isempty(cfg.track.nCpi)
    cfg.track.nCpi = 5;
end
if ~isfield(cfg.track, 'holdPredictionOnMiss') || isempty(cfg.track.holdPredictionOnMiss)
    cfg.track.holdPredictionOnMiss = true;
end
if ~isfield(cfg.track, 'seedStep') || isempty(cfg.track.seedStep)
    cfg.track.seedStep = 1;
end
if ~isfield(cfg.track, 'storeJointOutHistory') || isempty(cfg.track.storeJointOutHistory)
    cfg.track.storeJointOutHistory = false;
end
if ~isfield(cfg.track, 'useAssociation') || isempty(cfg.track.useAssociation)
    cfg.track.useAssociation = true;
end
if ~isfield(cfg.track, 'associationRangeGate') || isempty(cfg.track.associationRangeGate)
    cfg.track.associationRangeGate = 2 * cfg.wf.dR;
end
if ~isfield(cfg.track, 'associationVelocityGate') || isempty(cfg.track.associationVelocityGate)
    cfg.track.associationVelocityGate = 2 * velocity_resolution_local(cfg);
end
if ~isfield(cfg.track, 'associationFallbackToBestOnGateMiss') ...
        || isempty(cfg.track.associationFallbackToBestOnGateMiss)
    cfg.track.associationFallbackToBestOnGateMiss = false;
end
if ~isfield(cfg.track, 'coarseSearchHalfWidthAz') || isempty(cfg.track.coarseSearchHalfWidthAz)
    cfg.track.coarseSearchHalfWidthAz = 1;
end
if ~isfield(cfg.track, 'coarseSearchHalfWidthEl') || isempty(cfg.track.coarseSearchHalfWidthEl)
    cfg.track.coarseSearchHalfWidthEl = 1;
end
if ~isfield(cfg.track, 'coarseSearchUsePredictionGate') || isempty(cfg.track.coarseSearchUsePredictionGate)
    cfg.track.coarseSearchUsePredictionGate = true;
end

if ~isfield(cfg.tgt, 'vRate') || isempty(cfg.tgt.vRate)
    cfg.tgt.vRate = 0.0;
end
if ~isfield(cfg.tgt, 'azRate') || isempty(cfg.tgt.azRate)
    cfg.tgt.azRate = 0.0;
end
if ~isfield(cfg.tgt, 'elRate') || isempty(cfg.tgt.elRate)
    cfg.tgt.elRate = 0.0;
end
end

function ang = wrap180_local(ang)
ang = mod(ang + 180, 360) - 180;
end

function dv = velocity_resolution_local(cfg)
if isfield(cfg, 'mtd') && isfield(cfg.mtd, 'vAxis') && numel(cfg.mtd.vAxis) >= 2
    dv = abs(cfg.mtd.vAxis(2) - cfg.mtd.vAxis(1));
    return;
end

nfft = cfg.wf.Np;
if isfield(cfg, 'mtd') && isfield(cfg.mtd, 'nfft') && ~isempty(cfg.mtd.nfft)
    nfft = cfg.mtd.nfft;
end
dv = cfg.arr.lambda / (2 * nfft * cfg.wf.PRI);
end

function truthState = propagate_truth_state_local(cfgBase, tStart)
truthState = struct();
truthState.timeStart = tStart;
truthState.range = cfgBase.tgt.R0 + cfgBase.tgt.v * tStart + 0.5 * cfgBase.tgt.vRate * tStart ^ 2;
truthState.velocity = cfgBase.tgt.v + cfgBase.tgt.vRate * tStart;
truthState.az = cfgBase.tgt.az + cfgBase.tgt.azRate * tStart;
truthState.el = cfgBase.tgt.el + cfgBase.tgt.elRate * tStart;
truthState.u = sind(truthState.el);
end

function cfgNow = make_cfg_for_current_cpi_local(cfgBase, truthState)
cfgNow = cfgBase;
cfgNow.tgt.R0 = truthState.range;
cfgNow.tgt.v = truthState.velocity;
cfgNow.tgt.az = truthState.az;
cfgNow.tgt.el = truthState.el;
end

function beamPrior = make_beam_prior_from_cfg_local(cfg, sourceName)
beamPrior = struct();
beamPrior.az = cfg.beam.azSectorCenter;
beamPrior.el = cfg.beam.elSectorCenter;
beamPrior.u = sind(beamPrior.el);
beamPrior.source = sourceName;
end

function beamPrior = make_beam_prior_from_prediction_local(prediction, sourceName)
beamPrior = struct();
beamPrior.az = prediction.az;
beamPrior.el = prediction.el;
beamPrior.u = prediction.u;
beamPrior.source = sourceName;
end

function prediction = predict_track_state_local(trackState, tCpi, cpiIndex)
prediction = trackState;
prediction.cpiIndex = cpiIndex;
prediction.range = trackState.range + trackState.velocity * tCpi;
prediction.velocity = trackState.velocity;
% 最小常角速度模型：距离仍按常速度外推，角度按上一帧角速度外推。
prediction.az = wrap180_local(trackState.az + trackState.azRate * tCpi);
prediction.el = trackState.el + trackState.elRate * tCpi;
prediction.u = sind(prediction.el);
prediction.azRate = trackState.azRate;
prediction.elRate = trackState.elRate;
prediction.updateSource = '上一CPI状态外推';
prediction.isValid = true;
end

function [selectedDetection, association] = select_associated_detection_local(jointOut, prediction, cfg)
association = make_empty_association_info_local();
association.candidateCount = jointOut.targets.count;
selectedDetection = make_empty_detection_local();

if jointOut.targets.count < 1
    association.mode = 'no_candidate';
    association.reason = 'current CPI has no target candidates';
    return;
end

if ~cfg.track.useAssociation
    selectedDetection = extract_detection_from_list_local(jointOut.targets, 1);
    association.mode = 'association_disabled_default_best';
    association.reason = 'association is disabled';
    association.selectedCandidateIdx = 1;
    association.selectedMetric = selectedDetection.metric;
    return;
end

if ~prediction.isValid
    selectedDetection = extract_detection_from_list_local(jointOut.targets, 1);
    association.mode = 'default_best_no_prediction';
    association.reason = 'no valid prediction is available';
    association.selectedCandidateIdx = 1;
    association.selectedMetric = selectedDetection.metric;
    return;
end

association.usedPrediction = true;
association.rangeResidual = abs(jointOut.targets.range(:) - prediction.range);
association.velocityResidual = abs(jointOut.targets.velocity(:) - prediction.velocity);
association.gateMask = association.rangeResidual <= cfg.track.associationRangeGate ...
    & association.velocityResidual <= cfg.track.associationVelocityGate;
association.gatePassedCount = sum(association.gateMask);

if association.gatePassedCount < 1
    association.mode = 'prediction_gate_miss';
    association.reason = 'all candidates are outside the prediction gate';
    if cfg.track.associationFallbackToBestOnGateMiss
        selectedDetection = extract_detection_from_list_local(jointOut.targets, 1);
        association.mode = 'prediction_gate_miss_fallback_best';
        association.reason = 'gate miss fallback to default best candidate';
        association.usedFallbackBest = true;
        association.selectedCandidateIdx = 1;
        association.selectedRangeResidual = association.rangeResidual(1);
        association.selectedVelocityResidual = association.velocityResidual(1);
        association.selectedScore = Inf;
        association.selectedMetric = selectedDetection.metric;
    end
    return;
end

gateRange = max(cfg.track.associationRangeGate, eps);
gateVelocity = max(cfg.track.associationVelocityGate, eps);
candidateIdx = find(association.gateMask);
score = (association.rangeResidual(candidateIdx) / gateRange) .^ 2 ...
    + (association.velocityResidual(candidateIdx) / gateVelocity) .^ 2;
metricVals = jointOut.targets.metric(candidateIdx);
[~, order] = sortrows([score(:), -metricVals(:)], [1, 2]);
bestIdx = candidateIdx(order(1));

selectedDetection = extract_detection_from_list_local(jointOut.targets, bestIdx);
association.mode = 'prediction_gate_match';
association.reason = 'selected the nearest gated candidate';
association.selectedCandidateIdx = bestIdx;
association.selectedRangeResidual = association.rangeResidual(bestIdx);
association.selectedVelocityResidual = association.velocityResidual(bestIdx);
association.selectedScore = score(order(1));
association.selectedMetric = selectedDetection.metric;
end

function measurement = measurement_from_detection_local(jointOut, detection, association, cfg, cpiIndex)
measurement = make_empty_measurement_local(cpiIndex);
measurement.source = association_source_local(association);
measurement.selectionMode = association.mode;
measurement.selectedCandidateIdx = association.selectedCandidateIdx;
measurement.rangeResidual = association.selectedRangeResidual;
measurement.velocityResidual = association.selectedVelocityResidual;

if ~is_valid_detection_local(detection)
    return;
end

fine = joint_refine_detection(jointOut, detection, cfg);
measurement.fine = fine;
measurement.isValid = isfinite(fine.range) ...
    && isfinite(fine.velocity) ...
    && isfinite(fine.az) ...
    && isfinite(fine.el);
if ~measurement.isValid
    return;
end

measurement.range = fine.range;
measurement.velocity = fine.velocity;
measurement.az = fine.az;
measurement.el = fine.el;
measurement.u = fine.u;
measurement.rangeIdx = detection.rangeIdx;
measurement.dopplerIdx = detection.dopplerIdx;
measurement.metric = detection.metric;
measurement.coarseRange = detection.range;
measurement.coarseVelocity = detection.velocity;
end

function sourceName = association_source_local(association)
switch association.mode
    case 'prediction_gate_match'
        sourceName = '关联命中候选并精测角';
    case 'prediction_gate_miss_fallback_best'
        sourceName = '门限失配后回退默认最优候选并精测角';
    case 'association_disabled_default_best'
        sourceName = '关闭关联后直接取默认最优候选并精测角';
    case 'default_best_no_prediction'
        sourceName = '无预测时直接取默认最优候选并精测角';
    otherwise
        sourceName = '无有效关联量测';
end
end

function state = track_state_from_measurement_local(measurement, prevState, tCpi, cpiIndex, sourceName)
state = make_empty_track_state_local();
state.cpiIndex = cpiIndex;
state.isValid = measurement.isValid;
state.range = measurement.range;
state.velocity = measurement.velocity;
state.az = measurement.az;
state.el = measurement.el;
state.u = measurement.u;
state.metric = measurement.metric;
state.updateSource = sourceName;

if ~measurement.isValid
    return;
end

% 第 1 次成功更新时没有上一帧角速度，先置 0；
% 第 2 帧及之后再用相邻两帧角度差估计角速度。
if prevState.isValid && isfinite(prevState.az) && isfinite(prevState.el) ...
        && isfinite(prevState.cpiIndex)
    dt = (cpiIndex - prevState.cpiIndex) * tCpi;
    if ~(isfinite(dt) && dt > 0)
        dt = tCpi;
    end
    state.azRate = wrap180_local(measurement.az - prevState.az) / dt;
    state.elRate = (measurement.el - prevState.el) / dt;
else
    state.azRate = 0.0;
    state.elRate = 0.0;
end
end

function state = make_empty_track_state_local()
state = struct();
state.cpiIndex = NaN;
state.isValid = false;
state.range = NaN;
state.velocity = NaN;
state.az = NaN;
state.el = NaN;
state.u = NaN;
state.azRate = NaN;
state.elRate = NaN;
state.metric = NaN;
state.updateSource = '';
end

function prediction = make_empty_prediction_local(cpiIndex)
prediction = make_empty_track_state_local();
prediction.cpiIndex = cpiIndex;
    prediction.updateSource = '无可用历史航迹';
end

function measurement = make_empty_measurement_local(cpiIndex)
measurement = struct();
measurement.cpiIndex = cpiIndex;
measurement.isValid = false;
measurement.range = NaN;
measurement.velocity = NaN;
measurement.az = NaN;
measurement.el = NaN;
measurement.u = NaN;
measurement.rangeIdx = NaN;
measurement.dopplerIdx = NaN;
measurement.metric = NaN;
measurement.coarseRange = NaN;
measurement.coarseVelocity = NaN;
measurement.source = '';
measurement.selectionMode = '';
measurement.selectedCandidateIdx = NaN;
measurement.rangeResidual = NaN;
measurement.velocityResidual = NaN;
measurement.fine = struct();
end

function association = make_empty_association_info_local()
association = struct();
association.mode = '';
association.reason = '';
association.usedPrediction = false;
association.usedFallbackBest = false;
association.candidateCount = 0;
association.gatePassedCount = 0;
association.selectedCandidateIdx = NaN;
association.selectedRangeResidual = NaN;
association.selectedVelocityResidual = NaN;
association.selectedScore = NaN;
association.selectedMetric = NaN;
association.rangeResidual = zeros(0, 1);
association.velocityResidual = zeros(0, 1);
association.gateMask = false(0, 1);
end

function detection = make_empty_detection_local()
detection = struct();
detection.beamIdx = NaN;
detection.rangeIdx = NaN;
detection.dopplerIdx = NaN;
detection.metric = NaN;
detection.localBeamIdx = NaN;
detection.localBeamLabel = '';
detection.range = NaN;
detection.velocity = NaN;
detection.beamAz = NaN;
detection.beamEl = NaN;
end

function tf = is_valid_detection_local(detection)
tf = isfield(detection, 'rangeIdx') && isfield(detection, 'dopplerIdx') ...
    && isfinite(detection.rangeIdx) && isfinite(detection.dopplerIdx) ...
    && detection.rangeIdx >= 1 && detection.dopplerIdx >= 1;
end

function detection = extract_detection_from_list_local(detList, idx)
detection = make_empty_detection_local();
if idx < 1 || idx > detList.count
    return;
end

detection.beamIdx = detList.beamIdx(idx);
detection.rangeIdx = detList.rangeIdx(idx);
detection.dopplerIdx = detList.dopplerIdx(idx);
detection.metric = detList.metric(idx);
detection.localBeamIdx = detList.localBeamIdx;
detection.localBeamLabel = detList.localBeamLabel;
detection.range = detList.range(idx);
detection.velocity = detList.velocity(idx);
detection.beamAz = detList.beamAz;
detection.beamEl = detList.beamEl;
end

function entry = make_empty_history_entry_local()
entry = struct();
entry.cpiIndex = NaN;
entry.timeStart = NaN;
entry.truth = struct('range', NaN, 'velocity', NaN, 'az', NaN, 'el', NaN, 'u', NaN);
entry.truthCube = struct();
entry.beamPrior = struct('az', NaN, 'el', NaN, 'u', NaN, 'source', '');
entry.prediction = make_empty_track_state_local();
entry.association = make_empty_association_info_local();
entry.measurement = make_empty_measurement_local(NaN);
entry.state = make_empty_track_state_local();
entry.cfg = struct();
entry.joint = struct();
end

function entry = build_history_entry_local(iCpi, tStart, truthState, truthCube, beamPrior, ...
    prediction, association, measurement, state, cfgNow, jointOut)
entry = struct();
entry.cpiIndex = iCpi;
entry.timeStart = tStart;
entry.truth = truthState;
entry.truthCube = truthCube;
entry.beamPrior = beamPrior;
entry.prediction = prediction;
entry.association = association;
entry.measurement = measurement;
entry.state = state;
entry.cfg = cfgNow;
if cfgNow.track.storeJointOutHistory
    entry.joint = jointOut;
else
    entry.joint = compact_joint_output_local(jointOut);
end
end

function jointSummary = compact_joint_output_local(jointOut)
jointSummary = struct();
jointSummary.selection = jointOut.selection;
jointSummary.targetCounts = struct( ...
    'rawCfar', jointOut.cfarRaw.count, ...
    'candidate', jointOut.candidateTargets.count, ...
    'kept', jointOut.targets.count);
jointSummary.targets = compact_detection_list_local(jointOut.targets);
jointSummary.finalDetection = jointOut.finalDetection;
jointSummary.fine = jointOut.fine;
jointSummary.targetExtractInfo = jointOut.targetExtractInfo;
end

function detSummary = compact_detection_list_local(detList)
detSummary = struct();
detSummary.count = detList.count;
detSummary.range = detList.range;
detSummary.velocity = detList.velocity;
detSummary.metric = detList.metric;
detSummary.rangeIdx = detList.rangeIdx;
detSummary.dopplerIdx = detList.dopplerIdx;
end

function summary = build_track_summary_local(history)
nCpi = numel(history);
summary = struct();
summary.cpiIndex = (1:nCpi).';
summary.timeStart = reshape([history.timeStart], [], 1);
summary.truthRange = zeros(nCpi, 1);
summary.truthVel = zeros(nCpi, 1);
summary.truthAz = zeros(nCpi, 1);
summary.truthEl = zeros(nCpi, 1);
summary.priorRange = NaN(nCpi, 1);
summary.priorVel = NaN(nCpi, 1);
summary.priorAz = zeros(nCpi, 1);
summary.priorEl = zeros(nCpi, 1);
summary.priorAzRate = NaN(nCpi, 1);
summary.priorElRate = NaN(nCpi, 1);
summary.coarseCenterAz = NaN(nCpi, 1);
summary.coarseCenterEl = NaN(nCpi, 1);
summary.coarseCenterScore = NaN(nCpi, 1);
summary.measRange = NaN(nCpi, 1);
summary.measVel = NaN(nCpi, 1);
summary.measAz = NaN(nCpi, 1);
summary.measEl = NaN(nCpi, 1);
summary.stateRange = NaN(nCpi, 1);
summary.stateVel = NaN(nCpi, 1);
summary.stateAz = NaN(nCpi, 1);
summary.stateEl = NaN(nCpi, 1);
summary.stateAzRate = NaN(nCpi, 1);
summary.stateElRate = NaN(nCpi, 1);
summary.detected = false(nCpi, 1);
summary.usedPredictionHold = false(nCpi, 1);
summary.associationUsedPrediction = false(nCpi, 1);
summary.associationGatePassedCount = zeros(nCpi, 1);
summary.associationSelectedCandidateIdx = NaN(nCpi, 1);
summary.associationUsedFallbackBest = false(nCpi, 1);

for iCpi = 1:nCpi
    summary.truthRange(iCpi) = history(iCpi).truth.range;
    summary.truthVel(iCpi) = history(iCpi).truth.velocity;
    summary.truthAz(iCpi) = history(iCpi).truth.az;
    summary.truthEl(iCpi) = history(iCpi).truth.el;
    summary.priorAz(iCpi) = history(iCpi).beamPrior.az;
    summary.priorEl(iCpi) = history(iCpi).beamPrior.el;
    if history(iCpi).prediction.isValid
        summary.priorRange(iCpi) = history(iCpi).prediction.range;
        summary.priorVel(iCpi) = history(iCpi).prediction.velocity;
        summary.priorAzRate(iCpi) = history(iCpi).prediction.azRate;
        summary.priorElRate(iCpi) = history(iCpi).prediction.elRate;
    end
    if isfield(history(iCpi).joint, 'selection')
        sel = history(iCpi).joint.selection;
        % summary 中显式保留“先验 -> 粗中心束 -> 精测角/状态”三层结果。
        if isfield(sel, 'coarseCenterAz') && isfinite(sel.coarseCenterAz)
            summary.coarseCenterAz(iCpi) = sel.coarseCenterAz;
        end
        if isfield(sel, 'coarseCenterEl') && isfinite(sel.coarseCenterEl)
            summary.coarseCenterEl(iCpi) = sel.coarseCenterEl;
        end
        if isfield(sel, 'coarseCenter') && isstruct(sel.coarseCenter) ...
                && isfield(sel.coarseCenter, 'score') && isfinite(sel.coarseCenter.score)
            summary.coarseCenterScore(iCpi) = sel.coarseCenter.score;
        end
    end

    summary.associationUsedPrediction(iCpi) = history(iCpi).association.usedPrediction;
    summary.associationGatePassedCount(iCpi) = history(iCpi).association.gatePassedCount;
    summary.associationSelectedCandidateIdx(iCpi) = history(iCpi).association.selectedCandidateIdx;
    summary.associationUsedFallbackBest(iCpi) = history(iCpi).association.usedFallbackBest;

    if history(iCpi).measurement.isValid
        summary.detected(iCpi) = true;
        summary.measRange(iCpi) = history(iCpi).measurement.range;
        summary.measVel(iCpi) = history(iCpi).measurement.velocity;
        summary.measAz(iCpi) = history(iCpi).measurement.az;
        summary.measEl(iCpi) = history(iCpi).measurement.el;
    end

    if history(iCpi).state.isValid
        summary.stateRange(iCpi) = history(iCpi).state.range;
        summary.stateVel(iCpi) = history(iCpi).state.velocity;
        summary.stateAz(iCpi) = history(iCpi).state.az;
        summary.stateEl(iCpi) = history(iCpi).state.el;
        summary.stateAzRate(iCpi) = history(iCpi).state.azRate;
        summary.stateElRate(iCpi) = history(iCpi).state.elRate;
        summary.usedPredictionHold(iCpi) = strcmp(history(iCpi).state.updateSource, '预测保持');
    end
end
end
