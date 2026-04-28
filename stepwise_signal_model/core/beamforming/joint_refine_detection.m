function fine = joint_refine_detection(jointOut, detection, cfg)
%JOINT_REFINE_DETECTION 对单个二维候选点做三波束比幅精测角。
if ~isstruct(jointOut) || ~isstruct(detection) || ~isstruct(cfg)
    error('joint_refine_detection:InvalidInput', ...
        'jointOut、detection 和 cfg 都必须是 struct。');
end

if ~isfield(jointOut, 'local') || ~isfield(jointOut, 'selection')
    error('joint_refine_detection:MissingContext', ...
        'jointOut 必须包含 bf_joint_2d 或 bf_joint_2d_step5 输出的 local 和 selection 字段。');
end

if ~is_valid_detection_local(detection)
    fine = empty_fine_result_local('没有可用于精测角的有效候选点');
    return;
end

requiredLocal = {'rdCube', 'weights', 'xUse', 'yUse', 'zUse'};
for iField = 1:numel(requiredLocal)
        fieldName = requiredLocal{iField};
        if ~isfield(jointOut.local, fieldName)
            error('joint_refine_detection:MissingLocalField', ...
                'jointOut.local.%s 是必需字段。', fieldName);
        end
end

requiredSelection = {'azTriplet', 'elTriplet', 'uTriplet', 'coarseCenterAz', 'coarseCenterEl'};
for iField = 1:numel(requiredSelection)
        fieldName = requiredSelection{iField};
        if ~isfield(jointOut.selection, fieldName)
            error('joint_refine_detection:MissingSelectionField', ...
                'jointOut.selection.%s 是必需字段。', fieldName);
        end
end

fine = estimate_fine_angles_local( ...
    jointOut.local.rdCube, ...
    jointOut.local.weights, ...
    jointOut.local.xUse, ...
    jointOut.local.yUse, ...
    jointOut.local.zUse, ...
    jointOut.selection.azTriplet, ...
    jointOut.selection.elTriplet, ...
    jointOut.selection.uTriplet, ...
    jointOut.selection.coarseCenterAz, ...
    jointOut.selection.coarseCenterEl, ...
    detection.rangeIdx, ...
    detection.dopplerIdx, ...
    cfg);
end

function tf = is_valid_detection_local(detection)
tf = isfield(detection, 'rangeIdx') && isfield(detection, 'dopplerIdx') ...
    && isfinite(detection.rangeIdx) && isfinite(detection.dopplerIdx) ...
    && detection.rangeIdx >= 1 && detection.dopplerIdx >= 1;
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
fine.coarseCenterAz = centerAz;
fine.coarseCenterEl = centerEl;
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
    fallbackReason = 'side-beam amplitude sum is too small';
    return;
end

validMask = isfinite(axisScan) & isfinite(rhoLut);
axisScan = axisScan(validMask);
rhoLut = rhoLut(validMask);
if numel(axisScan) < 2
    valueEst = fallbackVal;
    fallbackReason = 'ratio LUT has too few valid samples';
    return;
end

[axisBranch, rhoBranch, sideName] = select_main_ratio_branch_local(axisScan, rhoLut, tripletAmps, fallbackVal);
invertInfo.axisBranch = axisBranch;
invertInfo.rhoBranch = rhoBranch;
invertInfo.sideName = sideName;
if numel(axisBranch) < 2
    valueEst = fallbackVal;
    fallbackReason = 'missing usable monotonic branch near beam center';
    return;
end

[rhoUnique, idxUnique] = unique(rhoBranch, 'stable');
axisUnique = axisBranch(idxUnique);
if numel(rhoUnique) < 2
    valueEst = fallbackVal;
    fallbackReason = 'ratio LUT branch is not invertible';
    return;
end

rhoClamped = min(max(rhoMeas, min(rhoUnique)), max(rhoUnique));
invertInfo.rhoClamped = rhoClamped;
valueEst = interp1(rhoUnique, axisUnique, rhoClamped, 'linear');
if ~isfinite(valueEst)
    valueEst = fallbackVal;
    fallbackReason = 'ratio LUT interpolation failed';
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
out.coarseCenterAz = NaN;
out.coarseCenterEl = NaN;
end

function a = steer_vec_local(azDeg, elDeg, x, y, z, lambda, phaseFactor)
phase = phaseFactor * 2 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end
