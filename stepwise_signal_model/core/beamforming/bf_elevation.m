function [beamMat, info] = bf_elevation(pcMat, cfg, truth, azSteer)
%BF_ELEVATION 对阵元级脉压结果做俯仰维接收波束形成。

arr = cfg.arr;
wf = cfg.wf;
beam = cfg.beam;

[nAzUse, nElUse] = size(truth.xMat);
xUse = truth.xMat(:);
yUse = truth.yMat(:);
zUse = truth.zMat(:);
[nElem, nFast] = size(pcMat);

phaseFactor = beam.spatialPhaseFactor;

% 先生成二维幅度窗，后续所有俯仰波束共用这一套加权。
azWin = make_window_local(nAzUse, beam, 'az');
elWin = make_window_local(nElUse, beam, 'el');
ampMat = azWin(:) * elWin(:).';
ampVec = ampMat(:);
ampVec = ampVec / norm(ampVec);

elSectorCenter = beam.elSectorCenter;
elGrid = build_sector_beam_grid('elevation', cfg, truth, azSteer, elSectorCenter);
elBwInfo = elGrid.ref;
uSectorCenter = elGrid.uCenter;
uMin = elGrid.uMin;
uMax = elGrid.uMax;
thetaAxis = elBwInfo.thetaAxis;
patternRefDb = elBwInfo.patternDb;
el3dBLeftRef = elBwInfo.leftCross;
el3dBRightRef = elBwInfo.rightCross;
bw3dBRef = elBwInfo.bw3dB;
leftCrossURef = elBwInfo.leftCrossU;
rightCrossURef = elBwInfo.rightCrossU;
bw3dBURef = elBwInfo.bw3dBU;
dU = elGrid.spacing;
uBeam = elGrid.uBeam;
elBeam = elGrid.beam;

nBeam = numel(elBeam);
beamMat = complex(zeros(nBeam, nFast));

for ibeam = 1:nBeam
    aRef = steer_vec_local(azSteer, elBeam(ibeam), xUse, yUse, zUse, arr.lambda, phaseFactor);
    wNow = ampVec .* aRef;
    wNow = wNow / norm(wNow);
    beamMat(ibeam, :) = wNow' * pcMat;
end

rAxis = arr.c * (wf.tFast + wf.Tp / 2) / 2;
rRefTarget = truth.Rp;
[~, idxRef] = min(abs(rAxis - rRefTarget));

respRef = abs(beamMat(:, idxRef));
[peakAmp, idxPk] = max(abs(beamMat), [], 2);
rPk = rAxis(idxPk);

% 先找到目标距离单元上的最强粗扫波束，再围绕它取左中右三束。
[~, idxCoarse] = max(respRef);
if idxCoarse == 1 || idxCoarse == nBeam
    error('最强俯仰波束落在扫描边界上，无法形成左中右三波束组合。');
end

idxTriplet = [idxCoarse - 1, idxCoarse, idxCoarse + 1];
elTriplet = elBeam(idxTriplet);
uTriplet = uBeam(idxTriplet);

xRef = pcMat(:, idxRef);
aTriplet = complex(zeros(nElem, 3));
zTriplet = complex(zeros(3, 1));
for k = 1:3
    aNow = steer_vec_local(azSteer, elTriplet(k), xUse, yUse, zUse, arr.lambda, phaseFactor);
    aNow = ampVec .* aNow;
    aNow = aNow / norm(aNow);
    aTriplet(:, k) = aNow;
    zTriplet(k) = aNow' * xRef;
end

zTripletAbs = abs(zTriplet);
zTripletDb = 20 * log10(zTripletAbs / max(zTripletAbs) + eps);
[~, idxTripletBestLocal] = max(zTripletAbs);
leftGreater = zTripletAbs(1) > zTripletAbs(3);
rightGreater = zTripletAbs(3) > zTripletAbs(1);
leftRightEqual = ~(leftGreater || rightGreater);

info = struct();

info.azSteer = azSteer;
info.phaseFactor = phaseFactor;
info.elSectorCenter = elSectorCenter;
info.uSectorCenter = uSectorCenter;
info.elBeam = elBeam;
info.elBeamRel = elBeam - cfg.tgt.el;
info.elBeamRelSector = elBeam - elSectorCenter;
info.uBeam = uBeam;
info.uMin = uMin;
info.uMax = uMax;
info.dU = dU;
info.ruleName = '先在 u = sin(theta) 空间测参考波束宽度，再围绕扇区中心生成波束网格';
info.el3dBLeftRef = el3dBLeftRef;
info.el3dBRightRef = el3dBRightRef;
info.leftCrossURef = leftCrossURef;
info.rightCrossURef = rightCrossURef;
info.bw3dBRef = bw3dBRef;
info.bw3dBURef = bw3dBURef;
info.patternRefDb = patternRefDb;
info.thetaAxis = thetaAxis;
info.rAxis = rAxis;
info.rRef = rAxis(idxRef);
info.idxRef = idxRef;
info.respRef = respRef;
info.respRefDb = 20 * log10(respRef / max(respRef) + eps);
info.idxCoarse = idxCoarse;
info.elCoarse = elBeam(idxCoarse);
info.elCoarseRel = info.elCoarse - cfg.tgt.el;
info.elCoarseRelSector = info.elCoarse - elSectorCenter;
info.uCoarse = uBeam(idxCoarse);

info.idxTriplet = idxTriplet;
info.elTriplet = elTriplet;
info.uTriplet = uTriplet;
info.xRef = xRef;
info.aTriplet = aTriplet;
info.zTriplet = zTriplet;
info.zTripletAbs = zTripletAbs;
info.zTripletDb = zTripletDb;
info.idxTripletBestLocal = idxTripletBestLocal;
info.elTripletBest = elTriplet(idxTripletBestLocal);
info.uTripletBest = uTriplet(idxTripletBestLocal);
info.leftGreater = leftGreater;
info.rightGreater = rightGreater;
info.leftRightEqual = leftRightEqual;
info.idxLeft = idxTriplet(1);
info.idxMid = idxTriplet(2);
info.idxRight = idxTriplet(3);
info.elLeft = elTriplet(1);
info.elMid = elTriplet(2);
info.elRight = elTriplet(3);
info.uLeft = uTriplet(1);
info.uMid = uTriplet(2);
info.uRight = uTriplet(3);
info.elSpacing = diff(elBeam);
info.uSpacing = diff(uBeam);

info.peakAmp = peakAmp;
info.peakDb = 20 * log10(peakAmp / max(peakAmp) + eps);
info.idxPk = idxPk;
info.rPk = rPk;
info.peakErr = rPk - rRefTarget;
info.azWin = azWin;
info.elWin = elWin;
info.ampMat = ampMat;
info.nAzUse = nAzUse;
info.nElUse = nElUse;
info.modeName = truth.modeName;
end

function win = make_window_local(n, beam, dimName)
% 按维度读取窗函数配置。
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
% phaseFactor=1 对应单程相位，phaseFactor=2 对应双程相位。
phase = phaseFactor * 2 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end
