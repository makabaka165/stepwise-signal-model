function [beamMat, info] = bf_azimuth(pcMat, cfg, truth, azBeam)
%BF_AZIMUTH 对阵元级脉压结果做方位维接收波束形成。
% 输入:
%   pcMat  - 阵元级脉压矩阵，大小为 [阵元数, 快时间采样点数]
%   cfg    - 仿真参数结构体
%   truth  - echo_elem 输出的真值结构体，提供工作子阵几何
%   azBeam - 方位波束中心，单位 deg
% 输出:
%   beamMat - 波束输出矩阵，大小为 [波束数, 快时间采样点数]
%   info    - 粗扫结果与三波束导向矢量判别信息

arr = cfg.arr;
wf = cfg.wf;
beam = cfg.beam;

[nAzUse, nElUse] = size(truth.xMat);
xUse = truth.xMat(:);
yUse = truth.yMat(:);
zUse = truth.zMat(:);
[nElem, nFast] = size(pcMat);

% 方位维构权时俯仰角先固定；下一步再单独接俯仰维波束形成。
elSteer = beam.elSteer;
phaseFactor = beam.spatialPhaseFactor;
azBeam = azBeam(:).';

% 先生成二维幅度窗，后续每个波束都用同一套窗函数做加权。
azWin = make_window_local(nAzUse, beam, 'az');
elWin = make_window_local(nElUse, beam, 'el');
ampMat = azWin(:) * elWin(:).';
ampVec = ampMat(:);
ampVec = ampVec / norm(ampVec);

nBeam = numel(azBeam);
beamMat = complex(zeros(nBeam, nFast));

for ibeam = 1:nBeam
    % 当前回波模型按双程相位建模，因此构权导向矢量保持同样相位形式。
    aRef = steer_vec_local(azBeam(ibeam), elSteer, xUse, yUse, zUse, arr.lambda, phaseFactor);
    wNow = ampVec .* aRef;
    wNow = wNow / norm(wNow);
    beamMat(ibeam, :) = wNow' * pcMat;
end

rAxis = arr.c * (wf.tFast + wf.Tp / 2) / 2;
rRefTarget = truth.Rp;

% 先在目标参考距离单元上比较全部粗扫波束，确定候选三波束的中心束。
[~, idxRef] = min(abs(rAxis - rRefTarget));

respRef = abs(beamMat(:, idxRef));
[peakAmp, idxPk] = max(abs(beamMat), [], 2);
rPk = rAxis(idxPk);

[~, idxCoarse] = max(respRef);
if idxCoarse == 1 || idxCoarse == nBeam
    error('最强波束落在扫描边界，无法构成左中右三波束。');
end

idxTriplet = [idxCoarse - 1, idxCoarse, idxCoarse + 1];
azTriplet = azBeam(idxTriplet);

% 取目标距离单元上的阵列回波向量 xRef，与左中右三束的加窗导向矢量做内积。
xRef = pcMat(:, idxRef);
aTriplet = complex(zeros(nElem, 3));
zTriplet = complex(zeros(3, 1));
for k = 1:3
    %第 k 个候选波束的导向矢量
    aNow = steer_vec_local(azTriplet(k), elSteer, xUse, yUse, zUse, arr.lambda, phaseFactor);
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

% info 按“扫描网格 + 参考距离响应 + 三波束判别量 + 诊断辅助量”组织。
% 其中 azBeam/idxRef/respRef 描述整段粗扫；
% idxTriplet/zTriplet 系列字段对应左中右三波束判别；
% peakAmp/peakErr 和窗函数字段用于后续验证波束输出质量。
info = struct();

% 方位粗扫网格、参考距离单元与整体响应。
info.azBeam = azBeam;
info.azBeamRel = wrap180_local(azBeam - cfg.tgt.az);
info.azBeamRelSector = wrap180_local(azBeam - cfg.beam.azSectorCenter);
info.azSectorCenter = cfg.beam.azSectorCenter;
info.elSteer = elSteer;
info.phaseFactor = phaseFactor;
info.rAxis = rAxis;
info.rRef = rAxis(idxRef);
info.idxRef = idxRef;
info.respRef = respRef;
info.respRefDb = 20 * log10(respRef / max(respRef) + eps);
info.idxCoarse = idxCoarse;
info.azCoarse = azBeam(idxCoarse);
info.azCoarseRel = wrap180_local(info.azCoarse - cfg.tgt.az);
info.azCoarseRelSector = wrap180_local(info.azCoarse - cfg.beam.azSectorCenter);

% 左中右三波束候选组及其内积判别结果。
info.idxTriplet = idxTriplet;
info.azTriplet = azTriplet;
info.xRef = xRef;
info.aTriplet = aTriplet;
info.zTriplet = zTriplet;
info.zTripletAbs = zTripletAbs;
info.zTripletDb = zTripletDb;
info.idxTripletBestLocal = idxTripletBestLocal;
info.azTripletBest = azTriplet(idxTripletBestLocal);
info.leftGreater = leftGreater;
info.rightGreater = rightGreater;
info.leftRightEqual = leftRightEqual;
info.idxLeft = idxTriplet(1);
info.idxMid = idxTriplet(2);
info.idxRight = idxTriplet(3);
info.azLeft = azTriplet(1);
info.azMid = azTriplet(2);
info.azRight = azTriplet(3);
info.azSpacing = diff(azBeam);

% 每条粗扫波束的峰值测距结果，以及构权时使用的加窗信息。
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
% 根据配置生成一维加窗。
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

function ang = wrap180_local(ang)
ang = mod(ang + 180, 360) - 180;
end
