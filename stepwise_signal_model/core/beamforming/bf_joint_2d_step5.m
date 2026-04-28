function out = bf_joint_2d_step5(pcCube, cfg)
%BF_JOINT_2D_STEP5 第 5 步局部链路：当前 CPI 独立取局部三波束并完成后续处理。
% 说明：
%   - 该版本不使用上一 CPI 先验，也不做先验附近的小窗口粗选。
%   - 仿真阶段直接用“离 cfg.tgt.az / cfg.tgt.el 最近的波束中心”
%     近似当前 CPI 已经扫描到的局部中心束。
%   - 围绕该中心束构造方位三波束和俯仰三波束；由于共享中心束，
%     实际统一形成 5 个唯一局部波束。
%   - 中心束 CFAR 后直接取最强 raw 检测点作为单目标量测，不做聚类。

arr = cfg.arr;
wf = cfg.wf;
beam = cfg.beam;

[geom, arrInfo] = build_geometry_local(cfg);
[nAzUse, nElUse] = size(geom.xMat);
xUse = geom.xMat(:);
yUse = geom.yMat(:);
zUse = geom.zMat(:);
nElem = numel(xUse);

[nElemIn, ~, ~] = size(pcCube);
if nElemIn ~= nElem
    error('bf_joint_2d_step5:ElementMismatch', ...
        'pcCube 的第 1 维大小为 %d，与当前工作子阵阵元数 %d 不一致。', ...
        nElemIn, nElem);
end

azGrid = build_sector_beam_grid('azimuth', cfg, geom, beam.azSectorCenter, beam.elSectorCenter);
elGrid = build_sector_beam_grid('elevation', cfg, geom, beam.azSectorCenter, beam.elSectorCenter);

azBeamAxis = azGrid.beam(:).';
elBeamAxis = elGrid.beam(:).';
uBeamAxis = elGrid.uBeam(:).';

centerAzIdx = nearest_center_index_local(azBeamAxis, cfg.tgt.az, 'azimuth');
centerElIdx = nearest_center_index_local(elBeamAxis, cfg.tgt.el, 'elevation');

azTripletIdx = centerAzIdx + (-1:1);
elTripletIdx = centerElIdx + (-1:1);
azTriplet = azBeamAxis(azTripletIdx);
elTriplet = elBeamAxis(elTripletIdx);
uTriplet = uBeamAxis(elTripletIdx);

centerAz = azBeamAxis(centerAzIdx);
centerEl = elBeamAxis(centerElIdx);
centerU = uBeamAxis(centerElIdx);

localBeamAz = [azTriplet(1), centerAz, azTriplet(3), centerAz, centerAz];
localBeamEl = [centerEl, centerEl, centerEl, elTriplet(1), elTriplet(3)];
localLabels = {'方位左束', '中心束', '方位右束', '俯仰下束', '俯仰上束'};

ampVec = build_amplitude_template_local(nAzUse, nElUse, beam);
[beamCube, beamWeights] = form_local_beams_local(pcCube, localBeamAz, localBeamEl, ...
    xUse, yUse, zUse, arr.lambda, beam.spatialPhaseFactor, ampVec);
[rdCube, mtdInfo] = mtd_process(beamCube, cfg);
rdMag = abs(rdCube);

rAxis = arr.c * (wf.tFast + wf.Tp / 2) / 2;
vAxis = mtdInfo.vAxis;

centerLocalIdx = 2;
cfarRaw = detect_rd_cfar_1d(rdCube(centerLocalIdx, :, :), cfg.cfar);
cfarRaw = decorate_detection_output_local(cfarRaw, centerLocalIdx, localLabels{centerLocalIdx}, ...
    centerAz, centerEl, rAxis, vAxis);

peakDetections = decorate_detection_output_local(make_empty_detection_list_local(), ...
    centerLocalIdx, localLabels{centerLocalIdx}, centerAz, centerEl, rAxis, vAxis);

targetRaw = strongest_detection_local(cfarRaw);
targets = decorate_detection_output_local(targetRaw, centerLocalIdx, localLabels{centerLocalIdx}, ...
    centerAz, centerEl, rAxis, vAxis);
singleTargetSelectInfo = make_single_target_select_info_local(cfarRaw, targets);

if targets.count > 0
    finalDetection = targets.best;
else
    finalDetection = make_empty_best_detection_local(centerLocalIdx, localLabels{centerLocalIdx}, centerAz, centerEl);
end

out = struct();
out.rAxis = rAxis;
out.vAxis = vAxis;
out.nAzUse = nAzUse;
out.nElUse = nElUse;
out.azCenter = beam.azSectorCenter;
out.elCenter = beam.elSectorCenter;
out.dAz = azGrid.spacing;
out.dEl = elGrid.ref.bw3dB;
out.dU = elGrid.spacing;
out.azGrid = azBeamAxis;
out.elGrid = elBeamAxis;
out.uGrid = uBeamAxis;
out.arrInfo = arrInfo;

out.selection = struct();
out.selection.centerMethod = '第 5 步仿真近似：取离目标真值最近的波束中心';
out.selection.referenceAz = cfg.tgt.az;
out.selection.referenceEl = cfg.tgt.el;
out.selection.coarseCenterAz = centerAz;
out.selection.coarseCenterEl = centerEl;
out.selection.azTripletIdx = azTripletIdx;
out.selection.elTripletIdx = elTripletIdx;
out.selection.azTriplet = azTriplet;
out.selection.elTriplet = elTriplet;
out.selection.uTriplet = uTriplet;
out.selection.coarseSearch = struct( ...
    'mode', 'direct_truth_nearest', ...
    'referenceAz', cfg.tgt.az, ...
    'referenceEl', cfg.tgt.el);
out.selection.coarseCenter = struct( ...
    'azIdx', centerAzIdx, ...
    'elIdx', centerElIdx, ...
    'az', centerAz, ...
    'el', centerEl, ...
    'u', centerU, ...
    'score', NaN, ...
    'peakRangeIdx', NaN, ...
    'peakDopplerIdx', NaN, ...
    'source', out.selection.centerMethod);

out.local = struct();
out.local.labels = localLabels;
out.local.beamAz = localBeamAz;
out.local.beamEl = localBeamEl;
out.local.beamCube = beamCube;
out.local.rdCube = rdCube;
out.local.rdMag = rdMag;
out.local.weights = beamWeights;
out.local.xUse = xUse;
out.local.yUse = yUse;
out.local.zUse = zUse;
out.mtd = mtdInfo;

out.azGroup = struct();
out.azGroup.localIdx = [1, 2, 3];
out.azGroup.labels = localLabels(out.azGroup.localIdx);
out.azGroup.beamAz = localBeamAz(out.azGroup.localIdx);
out.azGroup.beamEl = localBeamEl(out.azGroup.localIdx);
out.azGroup.rdCube = rdCube(out.azGroup.localIdx, :, :);

out.elGroup = struct();
out.elGroup.localIdx = [4, 2, 5];
out.elGroup.labels = localLabels(out.elGroup.localIdx);
out.elGroup.beamAz = localBeamAz(out.elGroup.localIdx);
out.elGroup.beamEl = localBeamEl(out.elGroup.localIdx);
out.elGroup.beamU = [uTriplet(1), centerU, uTriplet(3)];
out.elGroup.rdCube = rdCube(out.elGroup.localIdx, :, :);

out.cfar = cfarRaw;
out.cfarRaw = cfarRaw;
out.peakDetections = peakDetections;
out.targets = targets;
out.detectionCell = targets;
out.singleTargetSelectInfo = singleTargetSelectInfo;
out.finalDetection = finalDetection;

out.fine = joint_refine_detection(out, finalDetection, cfg);
out.bestAz = out.fine.az;
out.bestEl = out.fine.el;
out.bestRange = out.fine.range;
out.bestVel = out.fine.velocity;
end

function [geom, arrInfo] = build_geometry_local(cfg)
arrInfo = arr_cyl(cfg, cfg.beam.azSectorCenter);
if cfg.sim.useSector
    geom = struct();
    geom.xMat = arrInfo.XAct;
    geom.yMat = arrInfo.YAct;
    geom.zMat = arrInfo.ZAct;
    geom.phiUseRel = arrInfo.phiActRel;
    return;
end

geom = struct();
geom.xMat = arrInfo.X;
geom.yMat = arrInfo.Y;
geom.zMat = arrInfo.Z;
geom.phiUseRel = wrap180_local(arrInfo.phiCol - cfg.beam.azSectorCenter);
end

function idx = nearest_center_index_local(axisVals, targetVal, dimName)
if numel(axisVals) < 3
    errId = sprintf('bf_joint_2d_step5:%sAxisTooShort', dimName);
    error(errId, ...
        '%s 波束轴至少需要 3 个点，才能构成三波束。', dimName);
end
[~, idx] = min(abs(axisVals - targetVal));
idx = min(max(idx, 2), numel(axisVals) - 1);
end

function ampVec = build_amplitude_template_local(nAzUse, nElUse, beam)
azWin = make_window_local(nAzUse, beam, 'az');
elWin = make_window_local(nElUse, beam, 'el');
ampMat = azWin(:) * elWin(:).';
ampVec = ampMat(:);
ampVec = ampVec / norm(ampVec);
end

function [beamCube, beamWeights] = form_local_beams_local(pcCube, beamAz, beamEl, ...
    xUse, yUse, zUse, lambda, phaseFactor, ampVec)
nBeam = numel(beamAz);
[nElem, nRange, nPulse] = size(pcCube);
pcFlat = reshape(pcCube, nElem, nRange * nPulse);

beamWeights = complex(zeros(nElem, nBeam));
for iBeam = 1:nBeam
    aNow = steer_vec_local(beamAz(iBeam), beamEl(iBeam), xUse, yUse, zUse, lambda, phaseFactor);
    beamWeights(:, iBeam) = normalize_weight_local(ampVec .* aNow);
end

beamMat = beamWeights' * pcFlat;
beamCube = reshape(beamMat, nBeam, nRange, nPulse);
end

function out = decorate_detection_output_local(detIn, localBeamIdx, localLabel, beamAz, beamEl, rAxis, vAxis)
out = detIn;
out.localBeamIdx = localBeamIdx;
out.localBeamLabel = localLabel;
out.beamAz = beamAz;
out.beamEl = beamEl;
out.range = index_to_axis_local(rAxis, out.rangeIdx);
out.velocity = index_to_axis_local(vAxis, out.dopplerIdx);

if out.count == 0
    out.best = make_empty_best_detection_local(localBeamIdx, localLabel, beamAz, beamEl);
    return;
end

out.best = decorate_best_detection_local(out.best, localBeamIdx, localLabel, beamAz, beamEl, rAxis, vAxis);
end

function vals = index_to_axis_local(axisVals, idx)
if isempty(idx)
    vals = zeros(0, 1);
    return;
end
vals = axisVals(idx);
vals = vals(:);
end

function out = strongest_detection_local(detIn)
if detIn.count == 0
    out = make_empty_detection_list_local();
    return;
end

out = slice_detection_local(detIn, 1);
end

function info = make_single_target_select_info_local(cfarRaw, targets)
info = struct();
info.rule = 'single target: use the strongest raw CFAR detection directly';
info.rawThresholdCrossingCount = cfarRaw.count;
info.rawDetectionCount = cfarRaw.count;
info.singleDetectionCellCount = targets.count;
if cfarRaw.count == 0
    info.selectedRawIndex = NaN;
    info.selectedMetric = NaN;
    info.selectedRangeIdx = NaN;
    info.selectedDopplerIdx = NaN;
else
    info.selectedRawIndex = 1;
    info.selectedMetric = cfarRaw.metric(1);
    info.selectedRangeIdx = cfarRaw.rangeIdx(1);
    info.selectedDopplerIdx = cfarRaw.dopplerIdx(1);
end
end

function out = slice_detection_local(detIn, pickIdx)
if isempty(pickIdx)
    out = make_empty_detection_list_local();
    return;
end

pickIdx = pickIdx(:);
out = struct();
out.beamIdx = detIn.beamIdx(pickIdx);
out.rangeIdx = detIn.rangeIdx(pickIdx);
out.dopplerIdx = detIn.dopplerIdx(pickIdx);
out.metric = detIn.metric(pickIdx);
out.count = numel(pickIdx);

[out.metric, order] = sort(out.metric, 'descend');
out.beamIdx = out.beamIdx(order);
out.rangeIdx = out.rangeIdx(order);
out.dopplerIdx = out.dopplerIdx(order);

out.best = struct();
out.best.beamIdx = out.beamIdx(1);
out.best.rangeIdx = out.rangeIdx(1);
out.best.dopplerIdx = out.dopplerIdx(1);
out.best.metric = out.metric(1);
end

function out = make_empty_detection_list_local()
out = struct();
out.beamIdx = zeros(0, 1);
out.rangeIdx = zeros(0, 1);
out.dopplerIdx = zeros(0, 1);
out.metric = zeros(0, 1);
out.count = 0;
out.best = struct();
end

function best = decorate_best_detection_local(best, localBeamIdx, localLabel, beamAz, beamEl, rAxis, vAxis)
best.localBeamIdx = localBeamIdx;
best.localBeamLabel = localLabel;
best.range = rAxis(best.rangeIdx);
best.velocity = vAxis(best.dopplerIdx);
best.beamAz = beamAz;
best.beamEl = beamEl;
end

function best = make_empty_best_detection_local(localBeamIdx, localLabel, beamAz, beamEl)
best = struct();
best.localBeamIdx = localBeamIdx;
best.localBeamLabel = localLabel;
best.rangeIdx = NaN;
best.dopplerIdx = NaN;
best.metric = NaN;
best.range = NaN;
best.velocity = NaN;
best.beamAz = beamAz;
best.beamEl = beamEl;
end

function win = make_window_local(n, beam, dimName)
if strcmpi(dimName, 'az')
    type = beam.azWinType;
    nbar = beam.azTaylorNbar;
    sll = beam.azTaylorSLL;
else
    type = beam.elWinType;
    nbar = beam.elTaylorNbar;
    sll = beam.elTaylorSLL;
end

switch lower(type)
    case 'taylor'
        win = taylorwin(n, nbar, sll);
    case 'hamming'
        win = hamming(n);
    case 'hann'
        win = hann(n);
    otherwise
        error('不支持的窗函数类型: %s', type);
end

win = win(:);
win = win / max(abs(win));
end

function a = steer_vec_local(azDeg, elDeg, x, y, z, lambda, phaseFactor)
phase = phaseFactor * 2 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end

function w = normalize_weight_local(w)
w = w / norm(w);
end

function ang = wrap180_local(ang)
ang = mod(ang + 180, 360) - 180;
end
