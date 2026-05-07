clc;
clear;
close all;

% =========================================================================
% 第 1 层蒙特卡洛：固定目标位置/距离/速度，仅扫描输入信噪比 (snrDb)
% -------------------------------------------------------------------------
% 目的：在简化的单目标 + 白噪声场景下，观察输入信噪比变化对
%       三波束比幅测角误差 (azRmse / elRmse) 的趋势影响。
%
% 假设：
%   1) 单点目标，回波幅度 ampTgt 已知；
%   2) 阵元噪声为零均值圆对称复高斯，方差 sigmaN^2；
%   3) 距离脉压 + 阵列相干合成 + MTD 相干积累 后处理增益足够，
%      在所有扫描的 snrDb 点上目标都能稳定通过 CFAR 门限。
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

% --------------- 目标参数 ------------------------------------------------
R0     = 3200;           % 目标初始距离 m
vTgt   = 45;             % 目标径向速度 m/s
azTgt  = 8;              % 目标方位角 deg
elTgt  = 10;             % 目标俯仰角 deg
ampTgt = 0.01;           % 目标回波线性复包络幅度

% --------------- CFAR 参数 -----------------------------------------------
nGuard     = 2;          % CFAR 保护单元数
nRef       = 8;          % CFAR 单边参考单元数
Pfa        = 1e-7;       % 设计虚警概率
TypeCase   = 'CA';       % 'CA' / 'GO' / 'SO'
DeTypeCase = 'Square';   % 'Linear' (取 |x|) / 'Square' (取 |x|^2)

% --------------- 蒙特卡洛扫描配置 ----------------------------------------
% 输入信噪比按阵元快时间样本定义：snrDb = 20*log10(ampTgt / sigmaN)
snrOutDbList = [12, 15, 20, 25, 30, 35, 40];
nTrial       = 100;      % 每个输出 SNR 点的随机种子重复次数
baseSeed     = 1000;     % 起始种子, 保证不同点之间种子不冲突
noiseCalSeed = 9000;     % noise-only 标定使用的随机种子

timerStart = tic;

% =========================================================================
% 1) 阵面几何 + 中心五波束 + ρ-角度 LUT (跨试验都不变, 主循环外只做一次)
% =========================================================================
[xVec, yVec, zVec, nAz, nEl, phiRel] = ...
    select_work_array_local(Naz, Nel, Rcyl, dz, azC, subNaz);

azAxis = build_left_aligned_beam_grid_local(azC + min(phiRel), dAz, azC + max(phiRel));
uAxis  = build_left_aligned_beam_grid_local(sind(elMin), dU, sind(elMax));
elAxis = asind(uAxis);

% 中心束 = 离目标最近的栅格点
[~, azCenterIdx] = min(abs(azAxis - azTgt));
[~, elCenterIdx] = min(abs(elAxis - elTgt));
centerAz = azAxis(azCenterIdx);
centerEl = elAxis(elCenterIdx);

% 五波束顺序: 1=左方位 2=中心 3=右方位 4=下俯仰 5=上俯仰
% 比幅时用 (1,2,3) 求方位、(4,2,5) 求俯仰
[beamW, locAz, locEl] = build_local_five_beams_local( ...
    xVec, yVec, zVec, nAz, nEl, lambda, centerAz, centerEl, dAz, dU);

% ρ-角度 LUT: 先预扫主瓣区间内的 ρ-角度曲线, 试验时只做支路选择 + 查表反推.
% 这条 LUT 仅依赖几何与波束权重, 跨试验完全不变, 放到主循环外只算一次.
[azScan, rhoAzCurve, elScan, rhoElCurve] = build_rho_lut_local( ...
    beamW, xVec, yVec, zVec, lambda, locAz, locEl);

% =========================================================================
% 2) 主循环：扫描 snrDb，每个点用 nTrial 个随机种子
% =========================================================================
% 输出端 SNR 标定分成两步：
% 1) signal-only:
%    令 sigmaN = 0，只保留目标信号，通过“阵元回波 -> 脉压 -> 波束形成 -> MTD”
%    整条链路，得到中心束 RD 图中的纯信号结果。
% 2) noise-only:
%    令 ampTgt = 0，只保留噪声，通过同一条链路，得到中心束 RD 图中的纯噪声结果。
%
% 这里之所以不能直接拿输入端噪声 sigmaN^2 当作分母，是因为当前定义的是
% “输出端 SNR”。既然分子是 RD 域目标单元的输出功率，分母也必须是 RD 域噪声
% 功率，只有这样口径才一致。
rdCtrSig = build_center_rd_local( ...
    xVec, yVec, zVec, beamW, ...
    c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, 0, ...
    nfft, 0);

sigPowMap = abs(rdCtrSig) .^ 2;
% signal-only:
% rdCtrSig 表示“只保留目标、完全不加噪声”时，目标经过
%   阵元回波 -> 距离脉压 -> 五波束形成 -> MTD
% 后，在中心束上形成的 RD 图。
%
% 这里先把复数 RD 图转成功率图，再找整张图中的最大值。
% 这个最大值对应的就是“当前目标在输出端最强的 RD 单元功率”，记为 PsOut。
% 后续所有输出端 SNR 的定义，都是围绕这个参考峰值单元展开的。
[psOutRef, linIdx] = max(sigPowMap(:));
[peakRIdx, peakDIdx] = ind2sub(size(sigPowMap), linIdx);

sigmaNoiseRef = 1;
% noise-only:
% 这里令 ampTgt = 0，只保留噪声。得到的 rdCtrNoise 就是“纯噪声经过同一条
% 信号处理链路后”的中心束 RD 图。
%
% 为什么要单独算这一份噪声 RD 图？
% 因为我们现在定义的是输出端 SNR，分母必须是输出端噪声功率。
% 如果直接用输入端 sigmaN^2，当中间经历了脉压、加窗、波束形成、MTD 之后，
% 信号和噪声已经不在同一个数据域里，口径是不一致的。
rdCtrNoise = build_center_rd_local( ...
    xVec, yVec, zVec, beamW, ...
    c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, azTgt, elTgt, 0, sigmaNoiseRef, ...
    nfft, noiseCalSeed);

rangeMargin = numel(tTx);
% 这里不直接取整张 rdCtrNoise 的均值，而是先去掉距离向两端的边界区。
% 原因是距离脉压本质上是卷积，距离向前后两端更容易受到卷积截断和边缘效应影响，
% 那些位置的噪声统计特性不够稳定，不适合直接作为背景噪声估计。
%
% 因此：
%   rangeMargin = 发射 LFM 样本数
%   noiseRowIdx = 去掉前后边界后的有效距离行
%
% 最终在这些有效距离行、以及全部多普勒列上，对功率做整体平均，
% 得到参考输出噪声功率 PnOutRef。
noiseRowIdx = (rangeMargin + 1):(size(rdCtrNoise, 1) - rangeMargin);
pnOutRef = mean(abs(rdCtrNoise(noiseRowIdx, :)) .^ 2, 'all');

% 有了 signal-only 得到的 PsOutRef 和 noise-only 得到的 PnOutRef 之后，
% 对任意目标输出端 SNR，都可以直接反解本次仿真应使用的输入噪声标准差 sigmaN。
%
% 推导如下：
%   snrOutDb = 10*log10(PsOutRef / PnOut)
%   PnOut    = PnOutRef * sigmaN^2       (这里 PnOutRef 对应 sigmaNoiseRef = 1)
% 所以：
%   sigmaN   = sqrt(PsOutRef / (PnOutRef * 10^(snrOutDb/10)))
%
% 这样主循环中虽然仍然是向阵元回波里注入 sigmaN 对应的输入噪声，
% 但这个 sigmaN 已经是“为了达到指定输出端 SNR”而反解出来的结果。
sigmaNList = sqrt(psOutRef ./ (pnOutRef * 10 .^ (snrOutDbList / 10)));

% snrInEqDb 是一个辅助对照量。
% 它把当前反解得到的 sigmaN，再换算回旧版本的“输入端 SNR”口径：
%   snrInEqDb = 20*log10(ampTgt / sigmaN)
% 这样可以方便对比“旧图上的 -30 dB”在新口径下大概对应什么位置。
snrInEqDbList = 20 * log10(ampTgt ./ sigmaNList);

calibrationTable = table( ...
    snrOutDbList(:), sigmaNList(:), snrInEqDbList(:), ...
    'VariableNames', {'snrOutDb', 'sigmaN', 'snrInEqDb'});

disp(calibrationTable);
fprintf('输出端标定: peakRIdx = %d, peakDIdx = %d, PsOut = %.6g, PnOutRef = %.6g\n', ...
    peakRIdx, peakDIdx, psOutRef, pnOutRef);

nRow     = numel(snrOutDbList) * nTrial;
snrOutDbCol  = zeros(nRow, 1);
snrInEqDbCol = zeros(nRow, 1);
sigmaNCol    = zeros(nRow, 1);
seedCol      = zeros(nRow, 1);
azEstCol     = zeros(nRow, 1);
elEstCol     = zeros(nRow, 1);
azErrCol     = zeros(nRow, 1);
elErrCol     = zeros(nRow, 1);

row = 0;
for iSnr = 1:numel(snrOutDbList)
    snrOutDb = snrOutDbList(iSnr);
    snrInEqDb = snrInEqDbList(iSnr);
    sigmaN = sigmaNList(iSnr);

    for iTrial = 1:nTrial
        row  = row + 1;
        seed = baseSeed + (iSnr - 1) * nTrial + iTrial;

        [azEst, elEst] = run_once_local( ...
            xVec, yVec, zVec, beamW, locAz, locEl, ...
            c, lambda, Tp, K, tTx, tFast, tSlow, ...
            R0, vTgt, azTgt, elTgt, ampTgt, sigmaN, ...
            nfft, Pfa, nGuard, nRef, TypeCase, DeTypeCase, seed, ...
            azScan, rhoAzCurve, elScan, rhoElCurve);

        snrOutDbCol(row)  = snrOutDb;
        snrInEqDbCol(row) = snrInEqDb;
        sigmaNCol(row)    = sigmaN;
        seedCol(row)      = seed;
        azEstCol(row)     = azEst;
        elEstCol(row)     = elEst;
        azErrCol(row)     = azEst - azTgt;
        elErrCol(row)     = elEst - elTgt;
    end
end

% =========================================================================
% 3) 试验级 / 汇总级表格 (汇总只统计每个 snr 点的 RMSE)
% =========================================================================
trialTable = table( ...
    snrOutDbCol, snrInEqDbCol, sigmaNCol, seedCol, ...
    azEstCol, elEstCol, azErrCol, elErrCol, ...
    'VariableNames', {'snrOutDb', 'snrInEqDb', 'sigmaN', 'seed', ...
    'azEstDeg', 'elEstDeg', 'azErrDeg', 'elErrDeg'});

nSnr           = numel(snrOutDbList);
summarySnrOut  = snrOutDbList(:);
summarySnrInEq = snrInEqDbList(:);
summaryAzRmse  = zeros(nSnr, 1);
summaryElRmse  = zeros(nSnr, 1);
% 某一个 SNR 条件下，所有随机种子重复试验的 RMSE
for iSnr = 1:nSnr
    idx = abs(trialTable.snrOutDb - snrOutDbList(iSnr)) < 1e-12;
    summaryAzRmse(iSnr) = sqrt(mean(trialTable.azErrDeg(idx) .^ 2));
    summaryElRmse(iSnr) = sqrt(mean(trialTable.elErrDeg(idx) .^ 2));
end

summaryTable = table( ...
    summarySnrOut, summarySnrInEq, summaryAzRmse, summaryElRmse, ...
    'VariableNames', {'snrOutDb', 'snrInEqDb', 'azRmseDeg', 'elRmseDeg'});

elapsedSec = toc(timerStart);
disp(summaryTable);
fprintf('第 1 层蒙特卡洛耗时 %.1f 秒。\n', elapsedSec);

% =========================================================================
% 4) 持久化结果 (供 plot_monte_carlo_trends.m 后处理)
% =========================================================================
outDir = fileparts(mfilename('fullpath'));
outMat = fullfile(outDir, 'snr_monte_carlo_result.mat');
outCsv = fullfile(outDir, 'snr_monte_carlo_summary.csv');

save(outMat, ...
    'summaryTable', 'trialTable', 'calibrationTable', ...
    'snrOutDbList', 'snrInEqDbList', 'sigmaNList', ...
    'nTrial', 'baseSeed', 'noiseCalSeed', ...
    'centerAz', 'centerEl', ...
    'peakRIdx', 'peakDIdx', 'psOutRef', 'pnOutRef', ...
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


function rdCtr = build_center_rd_local( ...
    xVec, yVec, zVec, beamW, ...
    c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, targetAz, targetEl, ampTgt, sigmaN, ...
    nfft, seed)
% 这个辅助函数只跑到“中心束 RD 图”这一级就返回，不继续做 CFAR 和测角。
% 它专门服务于第1层输出端 SNR 标定。
%
% 用法上有三种典型情况：
%   1) ampTgt > 0, sigmaN = 0  : signal-only
%   2) ampTgt = 0, sigmaN > 0  : noise-only
%   3) ampTgt > 0, sigmaN > 0  : 正常带噪仿真
%
% 返回的 rdCtr 是中心束 RD 图：
%   rdCtr(rangeIdx, doppIdx)
% 也就是中心束在某个距离单元、某个多普勒单元上的复数输出。
%
% 第1层之所以只取中心束，是因为输出端 SNR 的定义本身就是：
% “中心束目标 RD 峰值单元的功率 SNR”。
% 只跑到中心束 RD 图，用于输出端 SNR 标定。
rng(seed);
pcCube = simulate_pc_cube_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, targetAz, targetEl, ampTgt, sigmaN);
beamCube = form_local_beams_local(pcCube, beamW);
rdCube   = mtd_process_local(beamCube, nfft);
rdCtr    = squeeze(rdCube(2, :, :));
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

% 仅构造子阵阵元的 (x, y, z), 不再先建全阵再切片.
% meshgrid: 行变化的是 phi (子阵列), 列变化的是 z (俯仰行)
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
%
% 输出:
%   azScanMain / rhoAzMain : 方位主瓣区间内的 LUT
%   elScanMain / rhoElMain : 俯仰主瓣区间内的 LUT

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

% 发射基带 LFM: s(t) = exp(j*pi*K*t^2), |t|<=Tp/2
sTx    = (abs(tTx) <= Tp / 2) .* exp(1j * pi * K * tTx .^ 2);
nElem  = numel(xVec);
nFast  = numel(tFast);
nPulse = numel(tSlow);

% 逐脉冲生成阵元回波 (脉冲间多普勒走动靠 Rp = R0 + v*t_slow 体现)
echoCube = complex(zeros(nElem, nFast, nPulse));
for pIdx = 1:nPulse
    echoCube(:, :, pIdx) = echo_single_pulse_local( ...
        xVec, yVec, zVec, c, lambda, Tp, K, tFast, tSlow(pIdx), ...
        R0, vTgt, azTgt, elTgt, ampTgt, sigmaN);
end

% 距离脉压 (匹配滤波)
pcCube = pc_range_cube_local(echoCube, sTx);
end


function echoMat = echo_single_pulse_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tFast, tSlowNow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, sigmaN)
% 单脉冲 + 多阵元回波模型：
%   - 多普勒走动: R(t_slow) = R0 + v*t_slow, 反映脉冲间目标距离平移
%   - 各阵元到目标距离 Rm 不同, 引入 (-4π/λ) Rm 的双程相位
%   - 时延 tau = 2 Rm / c, 回波包络 = LFM(t_fast - tau)
%   - 加复高斯白噪声 (实/虚两路独立, 总功率 sigmaN^2)

Rp     = R0 + vTgt * tSlowNow;             % 当前慢时刻目标径向距离
xTgt   = Rp * cosd(azTgt) * cosd(elTgt);   % 目标笛卡尔坐标
yTgt   = Rp * sind(azTgt) * cosd(elTgt);
zTgt   = Rp * sind(elTgt);
Rm     = sqrt((xTgt - xVec) .^ 2 + (yTgt - yVec) .^ 2 + (zTgt - zVec) .^ 2);
tauVec = 2 * Rm / c;
dtMat  = tFast - tauVec;                    % 各阵元各快时间样本相对回波包络的偏移

echoMat = ampTgt ...
    * (abs(dtMat) <= Tp / 2) ...                % LFM 持续时间内有支持
    .* exp(1j * pi * K * dtMat .^ 2) ...        % LFM 相位
    .* exp(-1j * 4 * pi * Rm / lambda);         % 双程载频相位

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
% MTD: 慢时间方向加 Hamming 窗 (压低多普勒旁瓣) -> FFT (大小 = nfft)
%      -> fftshift 把零频搬到中央, 便于看正/负多普勒
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

rdCtr = squeeze(rdCube(2, :, :));   % 中心束 RD 平面 (Range, Doppler)
X     = rdCtr.';                     % 转成 (Doppler, Range), 沿距离做行向滑窗
switch DeTypeCase
    case 'Linear', X = abs(X);
    case 'Square', X = abs(X) .^ 2;
end
[~, N] = size(X);

y2 = zeros(size(X));

% 左边界: 只能用右侧参考窗
for jj = 1:(R + P)
    Q   = jj + P + 1 : jj + P + R;
    miu = mean(X(:, Q), 2);
    y2(:, jj) = X(:, jj) ./ (miu * alpha);
end

% 中段: 双边参考窗, 由 TypeCase 决定如何聚合 (CA=平均, GO=取大, SO=取小)
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

% 右边界: 只能用左侧参考窗
for jj = N - R - P + 1 : N
    Q   = jj - P - R : jj - P - 1;
    miu = mean(X(:, Q), 2);
    y2(:, jj) = X(:, jj) ./ (miu * alpha);
end

% 在过门限单元中取 raw power 最大者; 非过门限位置置 0
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
% 双程导向矢量 (因子 4π/λ 是双程相位):
%   a_k = exp(j * 4π/λ * (x_k cosE cosA + y_k cosE sinA + z_k sinE))
phase = 4 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end


function grid = build_left_aligned_beam_grid_local(minVal, spacing, maxVal)
% 等间距栅格: 从 minVal 起以 spacing 为步长, 覆盖到不超过 maxVal 的整数倍位置
nBeam = floor((maxVal - minVal) / spacing) + 1;
grid  = minVal + (0:nBeam - 1) * spacing;
grid  = grid(:).';
end


function ang = wrap180_local(ang)
% 角度归一化到 (-180, 180]
ang = mod(ang + 180, 360) - 180;
end
