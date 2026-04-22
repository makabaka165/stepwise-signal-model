function out = bf_joint_2d(pcCube, cfg)
%BF_JOINT_2D 第 5 步局部链路：五个唯一波束、中心波束 CFAR、最强目标三波束比幅测角。

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
    error('bf_joint_2d:ElementMismatch', ...
        'pcCube 的第 1 维大小为 %d，与当前工作子阵阵元数 %d 不一致。', ...
        nElemIn, nElem);
end

azGrid = build_sector_beam_grid('azimuth', cfg, geom, beam.azSectorCenter, beam.elSectorCenter);
elGrid = build_sector_beam_grid('elevation', cfg, geom, beam.azSectorCenter, beam.elSectorCenter);

azBeamAxis = azGrid.beam(:).';
elBeamAxis = elGrid.beam(:).';
uBeamAxis = elGrid.uBeam(:).';

% 仿真阶段直接用目标真值附近的最近波束中心来定义局部处理中心。
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

% 五个唯一波束统一做波束形成和 MTD。
ampVec = build_amplitude_template_local(nAzUse, nElUse, beam);
[beamCube, beamWeights] = form_local_beams_local(pcCube, localBeamAz, localBeamEl, ...
    xUse, yUse, zUse, arr.lambda, beam.spatialPhaseFactor, ampVec);
[rdCube, mtdInfo] = mtd_process(beamCube, cfg);
rdMag = abs(rdCube);

rAxis = arr.c * (wf.tFast + wf.Tp / 2) / 2;
vAxis = mtdInfo.vAxis;

% 只在中心波束 RD 图上做检测，再从检测点中提取目标代表点。
centerLocalIdx = 2;
cfarRaw = detect_rd_cfar_1d(rdCube(centerLocalIdx, :, :), cfg.cfar);
cfarRaw = decorate_detection_output_local(cfarRaw, centerLocalIdx, localLabels{centerLocalIdx}, ...
    centerAz, centerEl, rAxis, vAxis);

peakDetections = decorate_detection_output_local(make_empty_detection_list_local(), ...
    centerLocalIdx, localLabels{centerLocalIdx}, ...
    centerAz, centerEl, rAxis, vAxis);

clustersRaw = cluster_rd_detections_local(cfarRaw, ...
    cfg.cfar.clusterRangeTol, cfg.cfar.clusterDoppTol);
candidateRaw = detections_from_clusters_local(cfarRaw, clustersRaw);
candidateTargets = decorate_detection_output_local(candidateRaw, centerLocalIdx, localLabels{centerLocalIdx}, ...
    centerAz, centerEl, rAxis, vAxis);

clusters = filter_clusters_local(clustersRaw, cfarRaw, cfg.cfar);
targetRaw = detections_from_clusters_local(cfarRaw, clusters);
targets = decorate_detection_output_local(targetRaw, centerLocalIdx, localLabels{centerLocalIdx}, ...
    centerAz, centerEl, rAxis, vAxis);

if targets.count > 0
    finalDetection = targets.best;
elseif candidateTargets.count > 0
    finalDetection = candidateTargets.best;
elseif cfarRaw.count > 0
    finalDetection = cfarRaw.best;
else
    finalDetection = make_empty_best_detection_local(centerLocalIdx, localLabels{centerLocalIdx}, centerAz, centerEl);
end

% 三波束比幅测角只对最终选中的那个目标点执行。
if finalDetection.metric == finalDetection.metric
    fine = estimate_fine_angles_local(rdCube, beamWeights, xUse, yUse, zUse, ...
        azTriplet, elTriplet, uTriplet, centerAz, centerEl, ...
        finalDetection.rangeIdx, finalDetection.dopplerIdx, cfg);
else
    fine = empty_fine_result_local('中心波束 CFAR 未检出目标');
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
out.selection.method = '仿真阶段按 cfg.tgt.az/el 选择最近波束中心';
out.selection.centerAzIdx = centerAzIdx;
out.selection.centerElIdx = centerElIdx;
out.selection.centerAz = centerAz;
out.selection.centerEl = centerEl;
out.selection.centerU = centerU;
out.selection.azTripletIdx = azTripletIdx;
out.selection.elTripletIdx = elTripletIdx;
out.selection.azTriplet = azTriplet;
out.selection.elTriplet = elTriplet;
out.selection.uTriplet = uTriplet;

out.local = struct();
out.local.labels = localLabels;
out.local.beamAz = localBeamAz;
out.local.beamEl = localBeamEl;
out.local.beamCube = beamCube;
out.local.rdCube = rdCube;
out.local.rdMag = rdMag;
out.local.weights = beamWeights;

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
out.clustersRaw = clustersRaw;
out.candidateTargets = candidateTargets;
out.clusters = clusters;
out.targets = targets;
out.finalDetection = finalDetection;
out.fine = fine;
out.bestAz = fine.az;
out.bestEl = fine.el;
out.bestRange = fine.range;
out.bestVel = fine.velocity;
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
[~, idx] = min(abs(axisVals - targetVal));
if idx == 1 || idx == numel(axisVals)
    errId = sprintf('bf_joint_2d:%sCenterAtBoundary', dimName);
    error(errId, ...
        '与目标最近的 %s 波束中心落在扫描边界，无法构成三波束。', ...
        dimName);
end
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

function fine = estimate_fine_angles_local(rdCube, beamWeights, xUse, yUse, zUse, ...
    azTriplet, elTriplet, uTriplet, centerAz, centerEl, rangeIdx, dopplerIdx, cfg)
azResp = squeeze(rdCube([1, 2, 3], rangeIdx, dopplerIdx));
elResp = squeeze(rdCube([4, 2, 5], rangeIdx, dopplerIdx));

[azVal, azInfo] = estimate_ratio_dimension_local( ...
    azResp(:), beamWeights(:, [1, 2, 3]), xUse, yUse, zUse, ...
    'azimuth', azTriplet, centerEl, cfg, azTriplet(2));
[uVal, elInfo] = estimate_ratio_dimension_local( ...
    elResp(:), beamWeights(:, [4, 2, 5]), xUse, yUse, zUse, ...
    'elevation', uTriplet, centerAz, cfg, uTriplet(2));

fine = struct();
fine.rangeIdx = rangeIdx;
fine.dopplerIdx = dopplerIdx;
fine.range = cfg.arr.c * (cfg.wf.tFast(rangeIdx) + cfg.wf.Tp / 2) / 2;
fine.velocity = cfg.mtd.vAxis(dopplerIdx);
fine.az = azVal;
fine.el = asind(uVal);
fine.u = uVal;
fine.azMethod = azInfo.method;
fine.elMethod = elInfo.method;
fine.azFallbackReason = azInfo.fallbackReason;
fine.elFallbackReason = elInfo.fallbackReason;
fine.azTripletAngles = azTriplet;
fine.elTripletAngles = elTriplet;
fine.elTripletU = uTriplet;
fine.azTripletAmps = azInfo.tripletAmps;
fine.elTripletAmps = elInfo.tripletAmps;
fine.azRatio = azInfo.rhoMeas;
fine.elRatio = elInfo.rhoMeas;
fine.azRatioLut = azInfo.rhoLut;
fine.elRatioLut = elInfo.rhoLut;
fine.azRatioAngleAxis = azInfo.axisScan;
fine.elRatioAxis = elInfo.axisScan;
fine.azRatioBranch = azInfo.rhoBranch;
fine.elRatioBranch = elInfo.rhoBranch;
fine.azRatioBranchAxis = azInfo.axisBranch;
fine.elRatioBranchAxis = elInfo.axisBranch;
fine.azRatioClamped = azInfo.rhoClamped;
fine.elRatioClamped = elInfo.rhoClamped;
fine.azRatioSide = azInfo.sideName;
fine.elRatioSide = elInfo.sideName;
fine.azTripletResponse = azResp(:).';
fine.elTripletResponse = elResp(:).';
fine.centerAz = centerAz;
fine.centerEl = centerEl;
end

function [valueEst, info] = estimate_ratio_dimension_local(zTriplet, wTriplet, xUse, yUse, zUse, ...
    modeName, axisTriplet, fixedVal, cfg, fallbackVal)
ratioEps = cfg.beam.fineRatioEps;
nLut = cfg.beam.fineRatioLutPoints;

tripletAmps = abs(zTriplet(:)).';
rhoMeas = (tripletAmps(3) - tripletAmps(1)) / (tripletAmps(3) + tripletAmps(1) + ratioEps);

if strcmpi(modeName, 'azimuth')
    axisScan = linspace(axisTriplet(1), axisTriplet(3), nLut);
    rhoLut = zeros(size(axisScan));
    for k = 1:numel(axisScan)
        aNow = steer_vec_local(axisScan(k), fixedVal, xUse, yUse, zUse, ...
            cfg.arr.lambda, cfg.beam.spatialPhaseFactor);
        aLeft = abs(wTriplet(:, 1)' * aNow);
        aRight = abs(wTriplet(:, 3)' * aNow);
        rhoLut(k) = (aRight - aLeft) / (aRight + aLeft + ratioEps);
    end
else
    axisScan = linspace(axisTriplet(1), axisTriplet(3), nLut);
    rhoLut = zeros(size(axisScan));
    for k = 1:numel(axisScan)
        aNow = steer_vec_local(fixedVal, asind(axisScan(k)), xUse, yUse, zUse, ...
            cfg.arr.lambda, cfg.beam.spatialPhaseFactor);
        aLeft = abs(wTriplet(:, 1)' * aNow);
        aRight = abs(wTriplet(:, 3)' * aNow);
        rhoLut(k) = (aRight - aLeft) / (aRight + aLeft + ratioEps);
    end
end

[valueEst, methodName, fallbackReason, invertInfo] = invert_ratio_lut_local( ...
    rhoMeas, axisScan, rhoLut, tripletAmps, fallbackVal, ratioEps);

info = struct();
info.axisScan = axisScan;
info.rhoLut = rhoLut;
info.rhoMeas = rhoMeas;
info.tripletAmps = tripletAmps;
info.method = methodName;
info.fallbackReason = fallbackReason;
info.axisBranch = invertInfo.axisBranch;
info.rhoBranch = invertInfo.rhoBranch;
info.rhoClamped = invertInfo.rhoClamped;
info.sideName = invertInfo.sideName;
end

function [valueEst, methodName, fallbackReason, invertInfo] = invert_ratio_lut_local( ...
    rhoMeas, axisScan, rhoLut, tripletAmps, fallbackVal, ratioEps)
methodName = '三波束比幅查表';
fallbackReason = '';
invertInfo = make_empty_ratio_invert_info_local(rhoMeas);

if (tripletAmps(1) + tripletAmps(3)) <= ratioEps
    valueEst = fallbackVal;
    fallbackReason = '左右波束幅度和过小';
    return;
end

validMask = isfinite(axisScan) & isfinite(rhoLut);
axisScan = axisScan(validMask);
rhoLut = rhoLut(validMask);
if numel(axisScan) < 2
    valueEst = fallbackVal;
    fallbackReason = '比幅查找表有效点不足';
    return;
end

% 三波束比幅先由左右幅度大小判定目标位于中心束左侧还是右侧，
% 再只在中心束附近的主单调分支上做反演，避免多值 LUT 跳到错误分支。
[axisBranch, rhoBranch, sideName] = select_main_ratio_branch_local(axisScan, rhoLut, tripletAmps, fallbackVal);
invertInfo.axisBranch = axisBranch;
invertInfo.rhoBranch = rhoBranch;
invertInfo.sideName = sideName;
if numel(axisBranch) < 2
    valueEst = fallbackVal;
    fallbackReason = '中心附近缺少可用单调分支';
    return;
end

[rhoUnique, idxUnique] = unique(rhoBranch, 'stable');
axisUnique = axisBranch(idxUnique);
if numel(rhoUnique) < 2
    valueEst = fallbackVal;
    fallbackReason = '比幅查找表不可反演';
    return;
end

rhoClamped = min(max(rhoMeas, min(rhoUnique)), max(rhoUnique));
invertInfo.rhoClamped = rhoClamped;
valueEst = interp1(rhoUnique, axisUnique, rhoClamped, 'linear');
if ~isfinite(valueEst)
    valueEst = fallbackVal;
    fallbackReason = '比幅插值失败';
end
end

function [axisBranch, rhoBranch, sideName] = select_main_ratio_branch_local(axisScan, rhoLut, tripletAmps, fallbackVal)
axisScan = axisScan(:);
rhoLut = rhoLut(:);
[~, idxCenter] = min(abs(axisScan - fallbackVal));
sideName = 'full';

if idxCenter <= 1 || idxCenter >= numel(axisScan)
    axisBranch = axisScan;
    rhoBranch = rhoLut;
    return;
end

if tripletAmps(3) > tripletAmps(1)
    sideName = 'right';
elseif tripletAmps(1) > tripletAmps(3)
    sideName = 'left';
else
    sideName = 'center';
end

if strcmp(sideName, 'center')
    sideName = select_stronger_slope_side_local(rhoLut, idxCenter);
end

if strcmp(sideName, 'left')
    idxStart = walk_monotonic_local(rhoLut, idxCenter - 1, -1);
    idxBranch = idxStart:idxCenter;
else
    idxEnd = walk_monotonic_local(rhoLut, idxCenter, +1);
    idxBranch = idxCenter:idxEnd;
end

axisBranch = axisScan(idxBranch);
rhoBranch = rhoLut(idxBranch);
if numel(rhoBranch) >= 2 && rhoBranch(1) > rhoBranch(end)
    rhoBranch = flipud(rhoBranch);
    axisBranch = flipud(axisBranch);
end
end

function info = make_empty_ratio_invert_info_local(rhoMeas)
info = struct();
info.axisBranch = [];
info.rhoBranch = [];
info.rhoClamped = rhoMeas;
info.sideName = '';
end

function sideName = select_stronger_slope_side_local(rhoLut, idxCenter)
leftSlope = abs(rhoLut(idxCenter) - rhoLut(idxCenter - 1));
rightSlope = abs(rhoLut(idxCenter + 1) - rhoLut(idxCenter));
if leftSlope >= rightSlope
    sideName = 'left';
else
    sideName = 'right';
end
end

function idxOut = walk_monotonic_local(rhoLut, idxStart, stepDir)
dRho = diff(rhoLut(:));
refSign = sign_with_fallback_local(dRho(idxStart), stepDir);
idxOut = idxStart;

if stepDir < 0
    kVals = idxStart:-1:1;
else
    kVals = idxStart:numel(dRho);
end

for k = kVals
    nowSign = sign_with_fallback_local(dRho(k), refSign);
    if nowSign ~= refSign
        break;
    end
    if stepDir < 0
        idxOut = k;
    else
        idxOut = k + 1;
    end
end
end

function s = sign_with_fallback_local(val, fallbackSign)
s = sign(val);
if s == 0
    s = sign(fallbackSign);
end
if s == 0
    s = 1;
end
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

function out = empty_fine_result_local(reason)
out = struct();
out.rangeIdx = NaN;
out.dopplerIdx = NaN;
out.range = NaN;
out.velocity = NaN;
out.az = NaN;
out.el = NaN;
out.u = NaN;
out.azMethod = '三波束比幅查表';
out.elMethod = '三波束比幅查表';
out.azFallbackReason = reason;
out.elFallbackReason = reason;
out.azTripletAngles = [];
out.elTripletAngles = [];
out.elTripletU = [];
out.azTripletAmps = [];
out.elTripletAmps = [];
out.azRatio = NaN;
out.elRatio = NaN;
out.azRatioLut = [];
out.elRatioLut = [];
out.azRatioAngleAxis = [];
out.elRatioAxis = [];
out.azRatioBranch = [];
out.elRatioBranch = [];
out.azRatioBranchAxis = [];
out.elRatioBranchAxis = [];
out.azRatioClamped = NaN;
out.elRatioClamped = NaN;
out.azRatioSide = '';
out.elRatioSide = '';
out.azTripletResponse = [];
out.elTripletResponse = [];
out.centerAz = NaN;
out.centerEl = NaN;
end

function vals = index_to_axis_local(axisVals, idx)
if isempty(idx)
    vals = zeros(0, 1);
    return;
end
vals = axisVals(idx);
vals = vals(:);
end

function clusters = cluster_rd_detections_local(detIn, rangeTol, doppTol)
if detIn.count == 0
    clusters = struct([]);
    return;
end

nDet = detIn.count;
visited = false(nDet, 1);
clusters = repmat(struct( ...
    'memberIndices', [], ...
    'count', 0, ...
    'bestDetectionIdx', NaN, ...
    'bestMetric', NaN, ...
    'metricSum', NaN, ...
    'rangeIdxMin', NaN, ...
    'rangeIdxMax', NaN, ...
    'doppIdxMin', NaN, ...
    'doppIdxMax', NaN), 0, 1);

for iDet = 1:nDet
    if visited(iDet)
        continue;
    end

    queue = iDet;
    visited(iDet) = true;
    members = zeros(nDet, 1);
    nMember = 0;

    while ~isempty(queue)
        idxNow = queue(1);
        queue(1) = [];
        nMember = nMember + 1;
        members(nMember) = idxNow;

        neighborMask = ~visited ...
            & abs(detIn.rangeIdx - detIn.rangeIdx(idxNow)) <= rangeTol ...
            & abs(detIn.dopplerIdx - detIn.dopplerIdx(idxNow)) <= doppTol;
        neighbors = find(neighborMask);
        if ~isempty(neighbors)
            visited(neighbors) = true;
            queue = [queue; neighbors]; %#ok<AGROW>
        end
    end

    memberIdx = members(1:nMember);
    [bestMetric, idxBestLocal] = max(detIn.metric(memberIdx));
    metricSum = sum(detIn.metric(memberIdx));

    cluster = struct();
    cluster.memberIndices = memberIdx(:);
    cluster.count = nMember;
    cluster.bestDetectionIdx = memberIdx(idxBestLocal);
    cluster.bestMetric = bestMetric;
    cluster.metricSum = metricSum;
    cluster.rangeIdxMin = min(detIn.rangeIdx(memberIdx));
    cluster.rangeIdxMax = max(detIn.rangeIdx(memberIdx));
    cluster.doppIdxMin = min(detIn.dopplerIdx(memberIdx));
    cluster.doppIdxMax = max(detIn.dopplerIdx(memberIdx));
    clusters(end + 1, 1) = cluster; %#ok<AGROW>
end
end

function out = detections_from_clusters_local(detIn, clusters)
if isempty(clusters)
    out = make_empty_detection_list_local();
    return;
end

pickIdx = zeros(numel(clusters), 1);
for iCluster = 1:numel(clusters)
    pickIdx(iCluster) = clusters(iCluster).bestDetectionIdx;
end
out = slice_detection_local(detIn, pickIdx);
end

function clustersOut = filter_clusters_local(clustersIn, ~, cfarCfg)
if isempty(clustersIn)
    clustersOut = clustersIn;
    return;
end

clusterCount = numel(clustersIn);
bestMetric = zeros(clusterCount, 1);
memberCount = zeros(clusterCount, 1);
metricSum = zeros(clusterCount, 1);
for iCluster = 1:clusterCount
    bestMetric(iCluster) = clustersIn(iCluster).bestMetric;
    memberCount(iCluster) = clustersIn(iCluster).count;
    metricSum(iCluster) = clustersIn(iCluster).metricSum;
end

metricRef = max(bestMetric);
metricSumRef = max(metricSum);

keepByPeak = bestMetric >= metricRef * cfarCfg.targetExtractMinRelMetric;
keepBySupportedEnergy = memberCount >= cfarCfg.targetExtractMinClusterSize ...
    & metricSum >= metricSumRef * cfarCfg.targetExtractMinRelMetricSum;
keepMask = keepByPeak | keepBySupportedEnergy;

if ~any(keepMask)
    [~, idxStrongest] = max(bestMetric);
    keepMask(idxStrongest) = true;
end

clustersOut = clustersIn(keepMask);
if isempty(clustersOut)
    return;
end

[~, order] = sortrows([[clustersOut.bestMetric].', [clustersOut.count].', [clustersOut.metricSum].'], ...
    [-1, -2, -3]);
clustersOut = clustersOut(order);
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
