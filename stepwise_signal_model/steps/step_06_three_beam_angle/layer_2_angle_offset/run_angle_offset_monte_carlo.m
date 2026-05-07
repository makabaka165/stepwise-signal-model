clc;
clear;
close all;

% =========================================================================
% 第 2 层蒙特卡洛：固定输入信噪比和中心五波束，仅扫描目标角度偏移
% -------------------------------------------------------------------------
% 目的：观察目标在中心波束主瓣内不同位置时, 三波束比幅测角误差的分布,
%       即验证 "目标越偏离中心束、比幅反演误差越大" 的趋势.
%
% 偏移量定义:
%   azOffset 在角度域内, 取范围 ±0.5 dAz, 涵盖中心 + 主瓣边界
%   uOffset  在 u=sin(el) 域内, 取范围 ±0.5 dU, 同样涵盖中心 + 边界
% 真实俯仰角通过 elTgt = asind(sind(centerEl) + uOffset) 映射回去,
% 这样在 u 域均匀采样 = 在阵元相位差上均匀采样.
%
% 假设: 输入信噪比足够目标稳定通过 CFAR; 不再做检测失败兜底.
% =========================================================================

% --------------- 阵面与频率 ----------------------------------------------
c      = 3e8;            % 光速 m/s
fc     = 10e9;           % 载频 Hz
lambda = c / fc;         % 波长 m
Naz    = 192;            % 圆柱阵方位向阵元数
Nel    = 32;             % 圆柱阵俯仰向阵元数
Rcyl   = 0.4;            % 圆柱阵半径 m
dz     = 17e-3;          % 俯仰向阵元间距 m
dPhi   = 360 / Naz;      % 方位阵元角间距 deg

% --------------- 波形与采样 ----------------------------------------------
Tp    = 1e-6;            % LFM 脉宽 s
B     = 20e6;            % LFM 带宽 Hz
Fs    = 60e6;            % 快时间采样率 Hz
PRI   = 50e-6;           % 脉冲重复间隔 s
Np    = 32;              % 慢时间脉冲数 (用于 MTD)
K     = B / Tp;          % LFM 调频率 Hz/s
tTx   = (-Tp / 2):(1 / Fs):(Tp / 2 - 1 / Fs);   % 发射波形快时间轴
tFast = 0:(1 / Fs):(PRI - 1 / Fs);              % 接收快时间轴
tSlow = (0:Np - 1) * PRI;                       % 慢时间轴
nfft  = Np;              % MTD FFT 点数 (= 脉冲数)

% --------------- 工作扇区与波束栅格 --------------------------------------
secHalf = 60;            % 子阵覆盖的方位半角 deg
subNaz  = 2 * floor(secHalf / dPhi) + 1;   % 子阵方位列数 (奇数)
azC     = 8;             % 工作扇区中心方位角 deg
elMin   = -5;            % 俯仰栅格下限 deg
elMax   = 60;            % 俯仰栅格上限 deg
dAz     = 1.24;          % 方位向波束间距 deg
dU      = 0.02921876244; % 俯仰向 u=sin(el) 域波束间距

% --------------- 目标参数 (本层用 centerAz/centerEl + 偏移作为真实角) ----
R0     = 3200;           % 目标距离 m
vTgt   = 45;             % 目标速度 m/s
azTgt  = 8;              % 用于挑选离它最近的栅格点作为中心束
elTgt  = 10;
ampTgt = 0.01;           % 目标回波幅度

% --------------- CFAR 参数 -----------------------------------------------
nGuard     = 2;
nRef       = 8;
Pfa        = 1e-7;
TypeCase   = 'CA';
DeTypeCase = 'Square';

% --------------- 蒙特卡洛扫描配置 ----------------------------------------
snrDb        = -14;                                   % 固定输入信噪比 dB
azOffsetList = linspace(-0.5 * dAz, 0.5 * dAz, 3);    % 方位偏移 (3 点: 中心 + 两边界)
uOffsetList  = linspace(-0.5 * dU,  0.5 * dU,  3);    % 俯仰偏移 (u 域 3 点)
nTrial       = 3;                                     % 每个 (az, u) 偏移点试验数
baseSeed     = 2000;

timerStart = tic;
sigmaN     = ampTgt / (10^(snrDb / 20));   % 由 snrDb 反推噪声标准差

% =========================================================================
% 1) 阵面几何 + 中心五波束 + ρ-角度 LUT (跨试验都不变, 主循环外只做一次)
% =========================================================================
[xVec, yVec, zVec, nAz, nEl, phiRel] = ...
    select_work_array_local(Naz, Nel, Rcyl, dz, azC, subNaz);

azAxis = build_left_aligned_beam_grid_local(azC + min(phiRel), dAz, azC + max(phiRel));
uAxis  = build_left_aligned_beam_grid_local(sind(elMin), dU, sind(elMax));
elAxis = asind(uAxis);

% 中心束 = 离 (azTgt, elTgt) 最近的栅格点; 后续偏移在 (centerAz, centerEl) 周围
[~, azCenterIdx] = min(abs(azAxis - azTgt));
[~, elCenterIdx] = min(abs(elAxis - elTgt));
centerAz = azAxis(azCenterIdx);
centerEl = elAxis(elCenterIdx);

% 五波束顺序: 1=左方位 2=中心 3=右方位 4=下俯仰 5=上俯仰
[beamW, locAz, locEl] = build_local_five_beams_local( ...
    xVec, yVec, zVec, nAz, nEl, lambda, centerAz, centerEl, dAz, dU);

% ρ-角度 LUT: 先预扫主瓣区间内的 ρ-角度曲线, 试验时只做支路选择 + 查表反推
[azScan, rhoAzCurve, elScan, rhoElCurve] = build_rho_lut_local( ...
    beamW, xVec, yVec, zVec, lambda, locAz, locEl);

% =========================================================================
% 2) 主循环: 双层扫描 (azOffset x uOffset), 每个网格点 nTrial 次
% =========================================================================
nGrid          = numel(azOffsetList) * numel(uOffsetList);
nRow           = nGrid * nTrial;
seedCol        = zeros(nRow, 1);
azOffsetCol    = zeros(nRow, 1);
uOffsetCol     = zeros(nRow, 1);
targetAzCol    = zeros(nRow, 1);
targetElCol    = zeros(nRow, 1);
azEstCol       = zeros(nRow, 1);
elEstCol       = zeros(nRow, 1);
azErrCol       = zeros(nRow, 1);
elErrCol       = zeros(nRow, 1);

row = 0;
for iU = 1:numel(uOffsetList)
    for iAz = 1:numel(azOffsetList)
        azOffset = azOffsetList(iAz);
        uOffset  = uOffsetList(iU);

        % 真实目标角度 = 中心束角度 + 偏移; 俯仰偏移在 u 域加完再映射回 el
        targetAz = centerAz + azOffset;
        targetEl = asind(sind(centerEl) + uOffset);

        gridIdx = (iU - 1) * numel(azOffsetList) + iAz;
        for iTrial = 1:nTrial
            row  = row + 1;
            seed = baseSeed + (gridIdx - 1) * nTrial + iTrial;

            [azEst, elEst] = run_once_local( ...
                xVec, yVec, zVec, beamW, locAz, locEl, ...
                c, lambda, Tp, K, tTx, tFast, tSlow, ...
                R0, vTgt, targetAz, targetEl, ampTgt, sigmaN, ...
                nfft, Pfa, nGuard, nRef, TypeCase, DeTypeCase, seed, ...
                azScan, rhoAzCurve, elScan, rhoElCurve);

            seedCol(row)     = seed;
            azOffsetCol(row) = azOffset;
            uOffsetCol(row)  = uOffset;
            targetAzCol(row) = targetAz;
            targetElCol(row) = targetEl;
            azEstCol(row)    = azEst;
            elEstCol(row)    = elEst;
            azErrCol(row)    = azEst - targetAz;
            elErrCol(row)    = elEst - targetEl;
        end
    end
end

% =========================================================================
% 3) 试验级 / 汇总级表格 (按 (azOffset, uOffset) 网格点统计 RMSE)
% =========================================================================
trialTable = table( ...
    seedCol, azOffsetCol, uOffsetCol, targetAzCol, targetElCol, ...
    azEstCol, elEstCol, azErrCol, elErrCol, ...
    'VariableNames', {'seed', 'azOffsetDeg', 'uOffset', 'targetAzDeg', ...
    'targetElDeg', 'azEstDeg', 'elEstDeg', 'azErrDeg', 'elErrDeg'});

summaryAzOffset = zeros(nGrid, 1);
summaryUOffset  = zeros(nGrid, 1);
summaryAzRmse   = zeros(nGrid, 1);
summaryElRmse   = zeros(nGrid, 1);

row = 0;
for iU = 1:numel(uOffsetList)
    for iAz = 1:numel(azOffsetList)
        row      = row + 1;
        azOffset = azOffsetList(iAz);
        uOffset  = uOffsetList(iU);
        idx      = abs(trialTable.azOffsetDeg - azOffset) < 1e-12 & ...
                   abs(trialTable.uOffset    - uOffset)  < 1e-12;

        summaryAzOffset(row) = azOffset;
        summaryUOffset(row)  = uOffset;
        summaryAzRmse(row)   = sqrt(mean(trialTable.azErrDeg(idx) .^ 2));
        summaryElRmse(row)   = sqrt(mean(trialTable.elErrDeg(idx) .^ 2));
    end
end

summaryTable = table( ...
    summaryAzOffset, summaryUOffset, summaryAzRmse, summaryElRmse, ...
    'VariableNames', {'azOffsetDeg', 'uOffset', 'azRmseDeg', 'elRmseDeg'});

elapsedSec = toc(timerStart);
disp(summaryTable);
fprintf('第 2 层蒙特卡洛耗时 %.1f 秒。\n', elapsedSec);

% =========================================================================
% 4) 持久化结果
% =========================================================================
outDir = fileparts(mfilename('fullpath'));
outMat = fullfile(outDir, 'angle_offset_monte_carlo_result.mat');
outCsv = fullfile(outDir, 'angle_offset_monte_carlo_summary.csv');

save(outMat, ...
    'summaryTable', 'trialTable', ...
    'snrDb', 'sigmaN', 'azOffsetList', 'uOffsetList', ...
    'nTrial', 'baseSeed', ...
    'centerAz', 'centerEl', 'azCenterIdx', 'elCenterIdx', ...
    'elapsedSec');
writetable(summaryTable, outCsv);

fprintf('已保存 MAT: %s\n', outMat);
fprintf('已保存 CSV: %s\n', outCsv);


% =========================================================================
%                              本地函数
% =========================================================================

function [azEst, elEst] = run_once_local( ...
    xVec, yVec, zVec, beamW, locAz, locEl, ...
    c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, targetAz, targetEl, ampTgt, sigmaN, ...
    nfft, Pfa, nGuard, nRef, TypeCase, DeTypeCase, seed, ...
    azScan, rhoAzCurve, elScan, rhoElCurve)
rng(seed);

% (1) 阵元级多脉冲回波：LFM + 多普勒走动 + 双程相位 + 复高斯噪声
pcCube   = simulate_pc_cube_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, targetAz, targetEl, ampTgt, sigmaN);

% (2) 距离脉压后做五波束相干合成：beamW' * 阵元
beamCube = form_local_beams_local(pcCube, beamW);

% (3) 慢时间方向加窗、FFT、fftshift，形成距离-多普勒立方
rdCube   = mtd_process_local(beamCube, nfft);

% (4) 在中心束 RD 平面上做 1D CA-CFAR，选最强检测单元
[pickRIdx, pickDIdx] = ...
    center_cfar_1d_local(rdCube, Pfa, nGuard, nRef, TypeCase, DeTypeCase);

% (5) 读取最强单元处五个波束的复值；beam 顺序：1 左 2 中 3 右 4 下 5 上
zPick = squeeze(rdCube(:, pickRIdx, pickDIdx));
azAmp = abs(zPick([1, 2, 3]));
elAmp = abs(zPick([4, 2, 5]));

% (6) 三波束比幅 + LUT：先按幅度选单调支路，再线性插值反推精确角度
rhoAz = (azAmp(3) - azAmp(1)) / (azAmp(3) + azAmp(1));
rhoEl = (elAmp(3) - elAmp(1)) / (elAmp(3) + elAmp(1));
[azEst, ~, ~, ~, ~] = invert_ratio_monotonic_local( ...
    azScan, rhoAzCurve, rhoAz, azAmp, locAz(2));
[elEst, ~, ~, ~, ~] = invert_ratio_monotonic_local( ...
    elScan, rhoElCurve, rhoEl, elAmp, locEl(2));
end


function [xVec, yVec, zVec, nAz, nEl, phiRelUse] = ...
    select_work_array_local(Naz, Nel, Rcyl, dz, azCtr, subNaz)
% 圆柱阵中以 azCtr 为方位中心, 取 subNaz 列子阵 (含全部 Nel 行).
% 圆柱面阵列模型: x = R cos(phi), y = R sin(phi), z 沿圆柱轴线.

phiCol      = (0:Naz - 1) / Naz * 360;     % 全阵阵元方位角 (0~360 deg)
zRow        = (0:Nel - 1) * dz;            % 各俯仰行的 z 坐标
phiRel      = wrap180_local(phiCol - azCtr);
[~, colCtr] = min(abs(phiRel));
halfSpan    = (subNaz - 1) / 2;
colsAct     = mod((colCtr - halfSpan - 1):(colCtr + halfSpan - 1), Naz) + 1;

% 仅构造子阵阵元的 (x, y, z), 不再先建全阵再切片
phiUse         = phiCol(colsAct);
[zMat, phiMat] = meshgrid(zRow, phiUse);   % 都是 (subNaz, Nel)
xMat           = Rcyl * cosd(phiMat);
yMat           = Rcyl * sind(phiMat);
phiRelUse      = wrap180_local(phiUse - azCtr);

nAz  = size(xMat, 1);
nEl  = size(xMat, 2);
xVec = xMat(:);
yVec = yMat(:);
zVec = zMat(:);
end


function [beamW, locAz, locEl] = build_local_five_beams_local( ...
    xVec, yVec, zVec, nAz, nEl, lambda, centerAz, centerEl, dAz, dU)
% 5 个相干波束 (顺序: 1 左 2 中 3 右 4 下 5 上),
% 权重 = 二维 Taylor 幅度加权 (-30 dB, n_bar=4) 与导向矢量逐元素乘, 单位 L2 归一.

azWin  = taylorwin(nAz, 4, -30);
elWin  = taylorwin(nEl, 4, -30);
ampMat = (azWin(:) / max(abs(azWin))) * (elWin(:).' / max(abs(elWin)));
ampVec = ampMat(:);
ampVec = ampVec / norm(ampVec);

centerU = sind(centerEl);
locAz   = [centerAz - dAz, centerAz, centerAz + dAz, centerAz, centerAz];
locEl   = [centerEl, centerEl, centerEl, asind(centerU - dU), asind(centerU + dU)];

nBeam = numel(locAz);
beamW = complex(zeros(numel(xVec), nBeam));
for iBeam = 1:nBeam
    aNow            = steer_vec_local(locAz(iBeam), locEl(iBeam), xVec, yVec, zVec, lambda);
    w               = ampVec .* aNow;
    beamW(:, iBeam) = w / norm(w);
end
end


function [azScanMain, rhoAzMain, elScanMain, rhoElMain] = build_rho_lut_local( ...
    beamW, xVec, yVec, zVec, lambda, locAz, locEl)
% 主瓣内 ρ-角度查找表 (跨试验完全不变, 主循环外只算一次):
%   让单源沿 θ ∈ [θ-Δ, θ+Δ] 扫描, 打到左/中/右 (或下/中/上) 三束上,
%   形成响应幅度, 进而得到比幅
%       ρ_az(θ) = (a_R(θ) - a_L(θ)) / (a_R(θ) + a_L(θ))
%   这里先只保留“中心束压过相邻束”的主瓣区间, 后续某次试验再根据 amp3
%   判断目标落在左支还是右支, 在该单调支路上做 interp1 反查.

azScan = linspace(locAz(1), locAz(3), 401);
uScan  = linspace(sind(locEl(4)), sind(locEl(5)), 401);
elScan = asind(uScan);

rhoAzCurve = zeros(size(azScan));
mainAz = zeros(size(azScan));
for i = 1:numel(azScan)
    aSrc = steer_vec_local(azScan(i), locEl(2), xVec, yVec, zVec, lambda);
    aL   = abs(beamW(:, 1)' * aSrc);
    aC   = abs(beamW(:, 2)' * aSrc);
    aR   = abs(beamW(:, 3)' * aSrc);
    rhoAzCurve(i) = (aR - aL) / (aR + aL);
    mainAz(i) = aC - max(aL, aR);
end

rhoElCurve = zeros(size(elScan));
mainEl = zeros(size(elScan));
for i = 1:numel(elScan)
    aSrc = steer_vec_local(locAz(2), elScan(i), xVec, yVec, zVec, lambda);
    aD   = abs(beamW(:, 4)' * aSrc);
    aC   = abs(beamW(:, 2)' * aSrc);
    aU   = abs(beamW(:, 5)' * aSrc);
    rhoElCurve(i) = (aU - aD) / (aU + aD);
    mainEl(i) = aC - max(aD, aU);
end

azMainIdx = mainAz >= 0;
elMainIdx = mainEl >= 0;
azScanMain = azScan(azMainIdx);
rhoAzMain = rhoAzCurve(azMainIdx);
elScanMain = elScan(elMainIdx);
rhoElMain = rhoElCurve(elMainIdx);
end


function pcCube = simulate_pc_cube_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, sigmaN)
% 阵元级多脉冲回波 + 距离脉压, 输出 pcCube: [Element, FastTime, Pulse]

sTx    = (abs(tTx) <= Tp / 2) .* exp(1j * pi * K * tTx .^ 2);
nElem  = numel(xVec);
nFast  = numel(tFast);
nPulse = numel(tSlow);

echoCube = complex(zeros(nElem, nFast, nPulse));
for pIdx = 1:nPulse
    echoCube(:, :, pIdx) = echo_single_pulse_local( ...
        xVec, yVec, zVec, c, lambda, Tp, K, tFast, tSlow(pIdx), ...
        R0, vTgt, azTgt, elTgt, ampTgt, sigmaN);
end

pcCube = pc_range_cube_local(echoCube, sTx);
end


function echoMat = echo_single_pulse_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tFast, tSlowNow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, sigmaN)
% 单脉冲 + 多阵元回波模型: 多普勒走动 + 各阵元双程相位 + LFM 包络 + 复高斯噪声.

Rp     = R0 + vTgt * tSlowNow;
xTgt   = Rp * cosd(azTgt) * cosd(elTgt);
yTgt   = Rp * sind(azTgt) * cosd(elTgt);
zTgt   = Rp * sind(elTgt);
Rm     = sqrt((xTgt - xVec) .^ 2 + (yTgt - yVec) .^ 2 + (zTgt - zVec) .^ 2);
tauVec = 2 * Rm / c;
dtMat  = tFast - tauVec;

echoMat = ampTgt ...
    * (abs(dtMat) <= Tp / 2) ...
    .* exp(1j * pi * K * dtMat .^ 2) ...
    .* exp(-1j * 4 * pi * Rm / lambda);

noise   = sigmaN / sqrt(2) * (randn(size(echoMat)) + 1j * randn(size(echoMat)));
echoMat = echoMat + noise;
end


function pcCube = pc_range_cube_local(echoCube, sTx)
% 沿 fast time 距离脉压, 逐脉冲独立处理 (脉冲数 32, 直接循环更直观)
[~, ~, nPulse] = size(echoCube);
pcCube = complex(zeros(size(echoCube)));
for pIdx = 1:nPulse
    pcCube(:, :, pIdx) = pc_single_local(echoCube(:, :, pIdx), sTx);
end
end


function pcMat = pc_single_local(echoMat, sTx)
% 距离脉压: 加 Hamming 窗的发射 LFM 反转共轭得到匹配滤波核;
% 一次批量 FFT 把 nElem 个阵元同时做完, 切回原始 fast time 长度.
Nf = size(echoMat, 2);
Ns = numel(sTx);

win      = hamming(Ns);
win      = win / norm(win);
sRefBase = sTx .* win.';                  % 加窗后的发射波形
sRef     = conj(fliplr(sRefBase));        % 反转共轭 = 匹配滤波核

Nfft = 2 ^ nextpow2(Nf + Ns - 1);
H    = fft(sRef, Nfft);                   % 1 x Nfft 滤波核

S     = fft(echoMat, Nfft, 2);            % nElem x Nfft, 沿快时间 FFT
y     = ifft(S .* H, [], 2);              % nElem x Nfft (隐式广播 H)
pcMat = y(:, Ns:(Ns + Nf - 1));           % 切卷积有效段
end


function beamCube = form_local_beams_local(pcCube, beamW)
% 五波束相干合成: beamCube[ib, ir, ip] = sum_k conj(beamW[k, ib]) * pcCube[k, ir, ip]
[nElem, nRange, nPulse] = size(pcCube);
pcFlat   = reshape(pcCube, nElem, nRange * nPulse);
beamMat  = beamW' * pcFlat;
beamCube = reshape(beamMat, size(beamW, 2), nRange, nPulse);
end


function rdCube = mtd_process_local(beamCube, nfft)
% MTD: 慢时间 Hamming -> FFT(nfft) -> fftshift 把零频搬到中央
nPulse  = size(beamCube, 3);
slowWin = hamming(nPulse);
slowWin = slowWin(:) / norm(slowWin);
winCube = beamCube .* reshape(slowWin, 1, 1, []);
rdCube  = fftshift(fft(winCube, nfft, 3), 3);
end


function [pickRIdx, pickDIdx] = ...
    center_cfar_1d_local(rdCube, Pfa, nGuard, nRef, TypeCase, DeTypeCase)
% 中心束 1D 距离向 CA/GO/SO-CFAR (alpha = 2R(Pfa^(-1/(2R))-1)).
% 三段处理: 左边界单边窗, 中段双边窗 (CA/GO/SO 聚合), 右边界单边窗;
% 在过门限单元中取 raw power 最大者.

P     = nGuard;
R     = nRef;
alpha = 2 * R * (Pfa ^ (-1 / (2 * R)) - 1);

rdCtr = squeeze(rdCube(2, :, :));
X     = rdCtr.';
switch DeTypeCase
    case 'Linear', X = abs(X);
    case 'Square', X = abs(X) .^ 2;
end
[~, N] = size(X);

y2 = zeros(size(X));

% 左边界
for jj = 1:(R + P)
    Q   = jj + P + 1 : jj + P + R;
    miu = mean(X(:, Q), 2);
    y2(:, jj) = X(:, jj) ./ (miu * alpha);
end

% 中段
for jj = R + P + 1 : N - R - P
    Q1 = jj - P - R : jj - P - 1;
    Q2 = jj + P + 1 : jj + P + R;
    leftMean  = mean(X(:, Q1), 2);
    rightMean = mean(X(:, Q2), 2);
    switch TypeCase
        case 'CA', miu = (leftMean + rightMean) / 2;
        case 'GO', miu = max(leftMean, rightMean);
        case 'SO', miu = min(leftMean, rightMean);
    end
    y2(:, jj) = X(:, jj) ./ (miu * alpha);
end

% 右边界
for jj = N - R - P + 1 : N
    Q   = jj - P - R : jj - P - 1;
    miu = mean(X(:, Q), 2);
    y2(:, jj) = X(:, jj) ./ (miu * alpha);
end

% 在过门限单元中取 raw power 最大者
Xpass = X .* (y2 >= 1);
[~, linIdx] = max(Xpass(:));
[pickDIdx, pickRIdx] = ind2sub(size(X), linIdx);
end


function [valEst, axBr, rhoBr, rhoLim, side] = ...
    invert_ratio_monotonic_local(ax, rhoLut, rhoIn, amp3, ctr)
% 在已预存的主瓣 LUT 中, 先按左/右邻束幅度选支路, 再在该单调支路上反查角度.
ax = ax(:);
rhoLut = rhoLut(:);
[~, idxCtr] = min(abs(ax - ctr));

if amp3(3) == amp3(1)
    valEst = ctr;
    axBr = ax(idxCtr);
    rhoBr = rhoLut(idxCtr);
    rhoLim = rhoIn;
    side = 'center';
    return;
end

if amp3(3) > amp3(1)
    side = 'right';
    idx1 = walk_monotonic_local(rhoLut, idxCtr, +1);
    idxBr = idxCtr:idx1;
else
    side = 'left';
    idx0 = walk_monotonic_local(rhoLut, idxCtr - 1, -1);
    idxBr = idx0:idxCtr;
end

axBr = ax(idxBr);
rhoBr = rhoLut(idxBr);

if rhoBr(1) > rhoBr(end)
    rhoBr = flipud(rhoBr);
    axBr = flipud(axBr);
end

rhoMin = min(rhoBr);
rhoMax = max(rhoBr);
rhoLim = min(max(rhoIn, rhoMin), rhoMax);
valEst = interp1(rhoBr, axBr, rhoLim, 'linear');
end


function idx = walk_monotonic_local(rhoLut, idx0, dir)
% 从中心附近沿指定方向向外走, 直到 rho 差分符号变化, 返回该单调支路边界.
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
        break;
    end
    if dir < 0
        idx = k;
    else
        idx = k + 1;
    end
end
end


function a = steer_vec_local(azDeg, elDeg, x, y, z, lambda)
% 双程导向矢量 (因子 4π/λ 是双程相位)
phase = 4 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end


function grid = build_left_aligned_beam_grid_local(minVal, spacing, maxVal)
% 等间距栅格: 从 minVal 起, 步长 spacing, 覆盖到 maxVal 内的整数倍位置
nBeam = floor((maxVal - minVal) / spacing) + 1;
grid  = minVal + (0:nBeam - 1) * spacing;
grid  = grid(:).';
end


function ang = wrap180_local(ang)
% 角度归一化到 (-180, 180]
ang = mod(ang + 180, 360) - 180;
end
