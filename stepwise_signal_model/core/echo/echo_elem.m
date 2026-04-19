function [echoMat, truth] = echo_elem(cfg, pIdx)
%ECHO_ELEM 生成单目标、单脉冲的阵元级 LFM 回波。

arr = cfg.arr;
wf = cfg.wf;
tgt = cfg.tgt;
sim = cfg.sim;

if pIdx < 1 || pIdx > wf.Np
    error('pIdx 超出脉冲编号范围。');
end

% 围绕当前扇区中心选择工作子阵。
sectorAz = cfg.beam.azSectorCenter;
sectorEl = cfg.beam.elSectorCenter;
arrInfo = arr_cyl(cfg, sectorAz);

if sim.useSector
    xUse = arrInfo.xActVec;
    yUse = arrInfo.yActVec;
    zUse = arrInfo.zActVec;
    xMat = arrInfo.XAct;
    yMat = arrInfo.YAct;
    zMat = arrInfo.ZAct;
    phiUse = arrInfo.phiAct;
    phiUseRel = arrInfo.phiActRel;
    modeName = '扇区中心对应工作子阵';
else
    xUse = arrInfo.xVec;
    yUse = arrInfo.yVec;
    zUse = arrInfo.zVec;
    xMat = arrInfo.X;
    yMat = arrInfo.Y;
    zMat = arrInfo.Z;
    phiUse = arrInfo.phiCol;
    phiUseRel = wrap180_local(phiUse - sectorAz);
    modeName = '全阵';
end

% 当前脉冲时刻的目标中心距离。
tSlow = wf.tSlow(pIdx);
Rp = tgt.R0 + tgt.v * tSlow;

% 目标直角坐标，约定 az=0 指向 +x，az=90 指向 +y。
xTgt = Rp * cosd(tgt.az) * cosd(tgt.el);
yTgt = Rp * sind(tgt.az) * cosd(tgt.el);
zTgt = Rp * sind(tgt.el);

% 各阵元到目标的传播距离及双程时延。
Rm = sqrt((xTgt - xUse).^2 + (yTgt - yUse).^2 + (zTgt - zUse).^2);
tauVec = 2 * Rm / arr.c;

tFast = wf.tFast(:).';
dtMat = tFast - tauVec;

% 阵元级延时 LFM 回波，并叠加双程传播相位。
echoMat = tgt.amp ...
    * (abs(dtMat) <= wf.Tp / 2) ...
    .* exp(1j * pi * wf.K * dtMat .^ 2) ...
    .* exp(-1j * 4 * pi * Rm / arr.lambda);

if sim.addNoise
    noise = sim.sigmaN / sqrt(2) * (randn(size(echoMat)) + 1j * randn(size(echoMat)));
    echoMat = echoMat + noise;
end

% 仅反映阵列几何的一程导向矢量，保留给可视化/检查使用。
uDir = [cosd(tgt.az) * cosd(tgt.el), ...
        sind(tgt.az) * cosd(tgt.el), ...
        sind(tgt.el)];
aVec = exp(1j * 2 * pi / arr.lambda * ...
    (xUse * uDir(1) + yUse * uDir(2) + zUse * uDir(3)));

tauCtr = 2 * Rp / arr.c;
[~, idxTau] = min(abs(tFast - tauCtr));

truth = struct();

truth.pIdx = pIdx;
truth.tSlow = tSlow;
truth.Rp = Rp;
truth.tau = tauCtr;
truth.idxTau = idxTau;
truth.rAxis = arr.c * tFast / 2;

truth.xTgt = xTgt;
truth.yTgt = yTgt;
truth.zTgt = zTgt;
truth.Rm = Rm;
truth.tauVec = tauVec;
truth.uDir = uDir;
truth.aVec = aVec;
truth.aMat = reshape(aVec, size(xMat));

truth.xMat = xMat;
truth.yMat = yMat;
truth.zMat = zMat;
truth.phiUse = phiUse;
truth.phiUseRel = phiUseRel;
truth.modeName = modeName;
truth.arrInfo = arrInfo;
truth.azSectorCenter = sectorAz;
truth.elSectorCenter = sectorEl;
end

function ang = wrap180_local(ang)
%WRAP180_LOCAL 将角度映射到 [-180, 180)。
ang = mod(ang + 180, 360) - 180;
end
