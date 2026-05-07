clc;
clear;
close all;


% 第 6 步独立演示脚本。
% 固定处理链路：
% 圆柱阵工作子阵 -> 阵元级多脉冲回波 -> 距离脉压 -> 局部五波束形成
% -> 慢时间 MTD -> 中心束距离向 1D CA-CFAR -> 最强检测单元 -> 三波束比幅测角。

%% 参数
% 雷达与圆柱阵列参数。
% Naz/Nel 分别是方位列数和俯仰行数；Rcyl 是圆柱半径，dz 是俯仰阵元间距。
c = 3e8;
fc = 10e9;
lambda = c / fc;
Naz = 192;
Nel = 32;
Rcyl = 0.4;
dz = 17e-3;
dPhi = 360 / Naz;

% LFM 波形与慢时间参数。
% tTx 是发射脉冲内部时间轴；tFast 是一个 PRI 内的快时间采样；
% tSlow 是 CPI 内的脉冲慢时间轴，用于后续 Doppler FFT。
Tp = 1e-6;
B = 20e6;
Fs = 60e6;
PRI = 50e-6;
Np = 32;
K = B / Tp;
tTx = (-Tp / 2):(1 / Fs):(Tp / 2 - 1 / Fs);
tFast = 0:(1 / Fs):(PRI - 1 / Fs);
tSlow = (0:Np - 1) * PRI;

% 扇区截取。
% 当前只使用 azC 附近的一段方位子阵，subNaz 是实际截取的方位列数。
secHalf = 60;
subNaz = 2 * floor(secHalf / dPhi) + 1;
azC = 8;

% 俯仰波束覆盖范围
elMin = -5;
elMax = 60;

% 波束间隔沿用第 3/4 步同一套 3 dB 宽度规则的默认结果。
% 方位在角度域使用 dAz；俯仰在 u=sin(theta) 域使用 dU。
dAz = 1.24;
dU = 0.02921876244;

% 单目标真值与回波幅度。
% R0/vTgt 决定距离和 Doppler 位置；azTgt/elTgt 决定目标所在波束方向。
R0 = 3200;
vTgt = 45;
azTgt = 8;
elTgt = 10;
ampTgt = 0.01;

% 复高斯白噪声。
% 固定随机种子是为了每次演示得到同一组噪声和同一组检测结果。
seed = 1;
sigmaN = 0.05;

% CFAR 参数。
% nGuard 是保护单元数，nRef 是单侧参考单元数。
% TypeCase 指定 CA/GO/SO，DeTypeCase 指定 Linear/Square 检测量。
nGuard = 2;
nRef = 8;
Pfa = 1e-7;
TypeCase = 'CA';
DeTypeCase = 'Square';

% MTD 参数。
% nfft=Np 表示 Doppler FFT 点数等于脉冲数；慢时间固定使用 Hamming 窗。
nfft = Np;
mtdWin = 'hamming';

rng(seed);

%% 主链路
% 1 取当前扇区的工作子阵
% x/y/z 是参与波束形成的阵元坐标；nAz/nEl 保留当前子阵的方位列数和俯仰行数
[xVec, yVec, zVec, nAz, nEl, phiRel] = ...
    select_work_array_local(Naz, Nel, Rcyl, dz, azC, subNaz);

% 2 生成阵元级回波，并逐脉冲做距离向脉压
% pcCube 维度为 阵元 x 距离采样 x 脉冲，是后续接收波束形成的输入
[pcCube, rAxis] = simulate_pc_cube_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, sigmaN);

% 3 在目标附近选取局部五波束：中心束、方位左右束、俯仰上下束
% 这一步直接沿用第 3/4 步确定的波束间隔，排布粗波束网格
[beamCube, beamW, azAxis, elAxis, locAz, locEl, locLbl] = ...
    build_local_five_beams_local( ...
        pcCube, xVec, yVec, zVec, phiRel, ...
        nAz, nEl, lambda, dAz, dU, ...
        azC, elMin, elMax, azTgt, elTgt);

% 4 对五个波束分别做慢时间 FFT，得到 RD cube
% rdCube 维度为 波束 x 距离 x Doppler；第 2 个波束固定为中心束
[rdCube, vAxis] = mtd_process_local(beamCube, nfft, PRI, lambda);

% 5 只取中心束做 CFAR。raw 是所有过门限检测单元，不等同于物理目标数
[thrMap, rawRIdx, rawDIdx, rawPow, nRaw, pickRIdx, pickDIdx, pickPow, alpha] = ...
    center_cfar_1d_local(rdCube, Pfa, nGuard, nRef, TypeCase, DeTypeCase);

% 6 在最强检测单元上做三波束比幅测角
% 方位: [左, 中, 右] ；俯仰: [下, 中, 上] 
% 比幅量 rho=(右-左)/(右+左)，再通过鉴角曲线 rho(angle) 反查角度
% 取最强检测单元处 5 个局部波束的 RD 复幅度。
zDet = squeeze(rdCube(:, pickRIdx, pickDIdx));

% 方位三波束幅度：[左, 中, 右]；俯仰三波束幅度：[下, 中, 上]。
ampAz = abs(zDet([1, 2, 3])).';
ampEl = abs(zDet([4, 2, 5])).';

% 实测比幅量。中心束只用于定位主瓣，不进入 rho 公式。
rhoAz = (ampAz(3) - ampAz(1)) / (ampAz(3) + ampAz(1));
rhoEl = (ampEl(3) - ampEl(1)) / (ampEl(3) + ampEl(1));

% 方位在角度域扫描；俯仰在 u=sin(theta) 域均匀扫描后转回角度。
azScan = linspace(locAz(1), locAz(3), 401);
uScan = linspace(sind(locEl(4)), sind(locEl(5)), 401);
elScan = asind(uScan);

% 预分配鉴角 LUT 和主瓣判据数组。
% rhoAzLut/rhoElLut 保存每个扫描角的比幅量 rho。
% mainAz/mainEl = 中心束幅度 - 相邻束最大幅度；>=0 表示中心束主瓣占优。
rhoAzLut = zeros(size(azScan));
rhoElLut = zeros(size(elScan));
mainAz = zeros(size(azScan));
mainEl = zeros(size(elScan));

% 方位鉴角曲线
for i = 1:numel(azScan)
    % 当前方位角的导向矢量。
    a = steer_vec_local(azScan(i), locEl(2), xVec, yVec, zVec, lambda);

    % 左/中/右三个方位波束的幅度响应。
    aL = abs(beamW(:, 1)' * a);
    aC = abs(beamW(:, 2)' * a);
    aR = abs(beamW(:, 3)' * a);

    % 写入方位 rho LUT，并记录中心束是否压过两侧邻束。
    rhoAzLut(i) = (aR - aL) / (aR + aL);
    mainAz(i) = aC - max(aL, aR);
end

% 俯仰鉴角曲线
for i = 1:numel(elScan)
    % 当前俯仰角的导向矢量。
    a = steer_vec_local(locAz(2), elScan(i), xVec, yVec, zVec, lambda);

    % 下/中/上三个俯仰波束的幅度响应。
    aD = abs(beamW(:, 4)' * a);
    aC = abs(beamW(:, 2)' * a);
    aU = abs(beamW(:, 5)' * a);

    % 写入俯仰 rho LUT，并记录中心束是否压过上下邻束。
    rhoElLut(i) = (aU - aD) / (aU + aD);
    mainEl(i) = aC - max(aD, aU);
end

% 只在中心束强于相邻束的主瓣区间内反查，避免旁瓣段多值映射。
idxAz = find(mainAz >= 0);
idxEl = find(mainEl >= 0);

% 在主瓣区间内选择单调支路，再由实测 rho 反查角度。
[azEst, ~, ~, rhoAzLim, sideAz] = ...
    invert_ratio_monotonic_local( ...
        azScan(idxAz), rhoAzLut(idxAz), rhoAz, ampAz, locAz(2));
[elEst, ~, ~, rhoElLim, sideEl] = ...
    invert_ratio_monotonic_local( ...
        elScan(idxEl), rhoElLut(idxEl), rhoEl, ampEl, locEl(2));

%% 输出
fprintf('=== 第6步：局部五波束 MTD + 中心束 1D 距离 CFAR + 三波束比幅测角 ===\n');
fprintf('[参数] ampTgt=%.4f, sigmaN=%.4f, Pfa=%.1e, Np=%d, MTD=%s, CFAR=%s-%s, guard/ref=%d/%d, alpha=%.4f\n', ...
    ampTgt, sigmaN, Pfa, Np, mtdWin, TypeCase, DeTypeCase, nGuard, nRef, alpha);
fprintf('[真值] R=%.1f m, v=%.1f m/s, az=%.1f deg, el=%.1f deg\n', ...
    R0, vTgt, azTgt, elTgt);
fprintf('[结果] raw=%d\n', nRaw);
fprintf('[选取] R=%.1f m, v=%.1f m/s, metric=%.4f\n', ...
    rAxis(pickRIdx), vAxis(pickDIdx), pickPow);
fprintf('[测角] az=%.3f deg, el=%.3f deg, rhoAz=%.4f, rhoEl=%.4f\n', ...
    azEst, elEst, rhoAz, rhoEl);
fprintf('[LUT] azSide=%s, azRhoClamp=%.4f, elSide=%s, elRhoClamp=%.4f\n', ...
    sideAz, rhoAzLim, sideEl, rhoElLim);

% 打印所有 raw CFAR 点，便于检查最强检测单元的选取。
for iDet = 1:nRaw
    thrNow = thrMap(rawDIdx(iDet), rawRIdx(iDet));
    ratio = rawPow(iDet) / thrNow;
    fprintf('  [%d] rangeIdx=%d, doppIdx=%d, R=%.1f m, v=%.1f m/s, metric=%.4f, threshold=%.4f, ratio=%.4f\n', ...
        iDet, rawRIdx(iDet), rawDIdx(iDet), ...
        rAxis(rawRIdx(iDet)), vAxis(rawDIdx(iDet)), ...
        rawPow(iDet), thrNow, ratio);
end

%% 画图
% 图 1：在方位-俯仰二维坐标中对比全部粗波束、局部五波束、目标真值和三波束精测角。
allAz = repelem(azAxis(:), numel(elAxis), 1);
allEl = repmat(elAxis(:), numel(azAxis), 1);
zoomEl = [locEl(:); elTgt; elEst];
zoomAz = [locAz(:); azTgt; azEst];
elPad = max(1.0, 0.35 * (max(zoomEl) - min(zoomEl)));
azPad = max(1.0, 0.35 * (max(zoomAz) - min(zoomAz)));

figure('Name', '第6步 精测角对比', 'Position', [110, 80, 820, 520]);
hGrid = plot(allEl, allAz, '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 8);
hold on;
hTruth = plot(elTgt, azTgt, 'ko', 'MarkerSize', 7, 'LineWidth', 1.2);
hLocal = plot(locEl, locAz, 'rs', 'MarkerSize', 8, 'LineWidth', 1.2);
hFine = plot(elEst, azEst, 'bp', 'MarkerSize', 11, 'LineWidth', 1.5);
text(locEl + 0.08 * elPad, locAz + 0.08 * azPad, locLbl, 'FontSize', 9);
text(elEst + 0.08 * elPad, azEst - 0.08 * azPad, '精测角', 'FontSize', 9);
xlim([min(zoomEl) - elPad, max(zoomEl) + elPad]);
ylim([min(zoomAz) - azPad, max(zoomAz) + azPad]);
grid on;
xlabel('俯仰角 (deg)');
ylabel('方位角 (deg)');
title('第6步 三波束比幅精测角与五波束/真值对比');
legend([hGrid, hTruth, hLocal, hFine], ...
    {'全部波束中心', '目标真值', '局部五波束', '三波束精测角'}, ...
    'Location', 'eastoutside');

% 图 2：三波束测角实际使用的是最强检测单元上的 RD 复幅度模值。
figure('Name', '第6步 三波束幅度', 'Position', [130, 100, 820, 360]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
bar(ampAz);
grid on;
set(gca, 'XTickLabel', locLbl([1, 2, 3]));
ylabel('幅度');
title('方位三波束幅度');

nexttile;
bar(ampEl);
grid on;
set(gca, 'XTickLabel', locLbl([4, 2, 5]));
ylabel('幅度');
title('俯仰三波束幅度');

% 图 3：鉴角曲线。红叉表示实测比幅量落在曲线上的反查位置。
figure('Name', '第6步 鉴角曲线', 'Position', [150, 120, 900, 380]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(azScan, rhoAzLut, 'LineWidth', 1.2);
hold on;
plot(azEst, rhoAz, 'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
xline(azTgt, ':k', 'LineWidth', 0.9);
grid on;
xlabel('方位角 (deg)');
ylabel('\rho_{az}');
title(sprintf('方位测角 %.3f deg', azEst));
legend('鉴角曲线', '实测比幅点', '真值方位', 'Location', 'best');

nexttile;
plot(elScan, rhoElLut, 'LineWidth', 1.2);
hold on;
plot(elEst, rhoEl, 'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
xline(elTgt, ':k', 'LineWidth', 0.9);
grid on;
xlabel('俯仰角 (deg)');
ylabel('\rho_{el}');
title(sprintf('俯仰测角 %.3f deg', elEst));
legend('鉴角曲线', '实测比幅点', '真值俯仰', 'Location', 'best');

function [xVec, yVec, zVec, nAz, nEl, phiRelUse] = ...
    select_work_array_local(Naz, Nel, Rcyl, dz, azCtr, subNaz)
% 输入: 阵列规模 Naz/Nel、圆柱半径 Rcyl、行间距 dz、扇区中心 azCtr、方位列数 subNaz。
% 输出: 工作子阵坐标向量 xVec/yVec/zVec、子阵规模 nAz/nEl、相对方位 phiRelUse。
% 生成完整圆柱阵坐标，并截取 azCtr 附近的方位扇区。
% 圆柱阵的方位维是周期结构，所以扇区越过 0/360 度时用 mod 自动回绕。
phiCol = (0:Naz - 1) / Naz * 360;
zRow = (0:Nel - 1) * dz;

% X/Y/Z 保留为 Naz x Nel，后续可以直接按方位列截取工作子阵。
X = zeros(Naz, Nel);
Y = zeros(Naz, Nel);
Z = zeros(Naz, Nel);
for iaz = 1:Naz
    X(iaz, :) = Rcyl * cosd(phiCol(iaz));
    Y(iaz, :) = Rcyl * sind(phiCol(iaz));
    Z(iaz, :) = zRow;
end

% 找到最接近扇区中心 azCtr 的方位列，再向两侧各取 halfSpan 列。
phiRel = wrap180_local(phiCol - azCtr);
[~, colCtr] = min(abs(phiRel));
halfSpan = (subNaz - 1) / 2;
colsAct = mod((colCtr - halfSpan - 1):(colCtr + halfSpan - 1), Naz) + 1;
xMat = X(colsAct, :);
yMat = Y(colsAct, :);
zMat = Z(colsAct, :);
phiRelUse = wrap180_local(phiCol(colsAct) - azCtr);
nAz = size(xMat, 1);
nEl = size(xMat, 2);

% Vec 形式用于回波建模和波束形成矩阵运算。
xVec = xMat(:);
yVec = yMat(:);
zVec = zMat(:);
end

function [pcCube, rAxis, RpSeq] = simulate_pc_cube_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, sigmaN)
% 输入: 阵元坐标、雷达/波形时间参数、目标真值、噪声标准差。
% 输出: 脉压数据 pcCube、距离轴 rAxis、逐脉冲目标距离 RpSeq。
% 阵元级回波 + 脉压
% sTx 是基带 LFM 发射信号，后面用它构造匹配滤波器。
sTx = (abs(tTx) <= Tp / 2) .* exp(1j * pi * K * tTx .^ 2);

nElem = numel(xVec);
nFast = numel(tFast);
nPulse = numel(tSlow);

echoCube = complex(zeros(nElem, nFast, nPulse));
RpSeq = zeros(1, nPulse);

% 对 CPI 内每个脉冲分别生成阵元级回波。目标距离随慢时间变化，
% 因此每个脉冲的距离、延迟和传播相位都会略有不同。
for pIdx = 1:nPulse
    [echoMat, Rp] = echo_single_pulse_local( ...
        xVec, yVec, zVec, c, lambda, Tp, K, tFast, tSlow(pIdx), ...
        R0, vTgt, azTgt, elTgt, ampTgt, sigmaN);
    echoCube(:, :, pIdx) = echoMat;
    RpSeq(pIdx) = Rp;
end

[pcCube, rAxis] = pc_range_cube_local(echoCube, sTx, c, Tp, tFast);
end

function [echoMat, Rp] = echo_single_pulse_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tFast, tSlowNow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, sigmaN)
% 输入: 阵元坐标、单脉冲时间轴、当前慢时间、目标真值、噪声标准差。
% 输出: 单脉冲阵元回波 echoMat、当前目标距离 Rp。
% 单脉冲目标回波：距离随慢时间按 R(t)=R0+v*t 更新。
Rp = R0 + vTgt * tSlowNow;

% 将目标球坐标真值转成当前脉冲时刻的三维直角坐标。
xTgt = Rp * cosd(azTgt) * cosd(elTgt);
yTgt = Rp * sind(azTgt) * cosd(elTgt);
zTgt = Rp * sind(elTgt);

% Rm 是目标到每个接收阵元的单程距离。tauVec 是对应的往返时延。
Rm = sqrt((xTgt - xVec) .^ 2 + (yTgt - yVec) .^ 2 + (zTgt - zVec) .^ 2);
tauVec = 2 * Rm / c;
dtMat = tFast - tauVec;

% 第一项限制回波只出现在脉冲宽度内；chirp 项给出 LFM 调频相位；
% exp(-j4piR/lambda) 是单站雷达往返传播相位。
echoMat = ampTgt ...
    * (abs(dtMat) <= Tp / 2) ...
    .* exp(1j * pi * K * dtMat .^ 2) ...
    .* exp(-1j * 4 * pi * Rm / lambda);

noise = sigmaN / sqrt(2) * (randn(size(echoMat)) + 1j * randn(size(echoMat)));
echoMat = echoMat + noise;
end

function [pcCube, rAxis] = pc_range_cube_local(echoCube, sTx, c, Tp, tFast)
% 输入: 阵元回波 echoCube、发射参考 sTx、光速 c、脉宽 Tp、快时间 tFast。
% 输出: 脉压数据 pcCube、距离轴 rAxis。
% 对每个脉冲、每个阵元做匹配滤波；输出: [阵元 x 距离 x 脉冲]
[nElem, nFast, nPulse] = size(echoCube);
pcCube = complex(zeros(nElem, nFast, nPulse));

for pIdx = 1:nPulse
    pcCube(:, :, pIdx) = pc_single_local(echoCube(:, :, pIdx), sTx);
end

% 脉压输出截取后，第一个有效点对应 tFast + Tp/2，因此距离轴这样换算。
rAxis = c * (tFast + Tp / 2) / 2;
end

function pcMat = pc_single_local(echoMat, sTx)
% 输入: 单脉冲阵元回波 echoMat、发射参考 sTx。
% 输出: 单脉冲脉压结果 pcMat。
% 频域卷积实现脉压，参考信号加 Hamming 窗抑制距离旁瓣。
nRow = size(echoMat, 1);
Nf = size(echoMat, 2);
Ns = numel(sTx);

win = hamming(Ns);
win = win / norm(win);
sRefBase = sTx .* win.';

% 匹配滤波器为发射信号的共轭时间反转，频域相乘等价于时域卷积。
sRef = conj(fliplr(sRefBase));
Nfft = 2 ^ nextpow2(Nf + Ns - 1);
H = fft(sRef, Nfft);

pcMat = complex(zeros(nRow, Nf));
for irow = 1:nRow
    S = fft(echoMat(irow, :), Nfft);
    y = ifft(S .* H);
    % 只保留与原快时间长度一致的一段，便于后续按 rAxis 解释距离。
    pcMat(irow, :) = y(Ns:(Ns + Nf - 1));
end
end

function [beamCube, beamW, azAxis, elAxis, locAz, locEl, locLbl] = ...
    build_local_five_beams_local( ...
        pcCube, xVec, yVec, zVec, phiRel, ...
        nAz, nEl, lambda, dAz, dU, ...
        azC, elMin, elMax, azTgt, elTgt)
% 输入: 脉压数据、阵元坐标、扫描扇区、波束间隔、目标角度真值。
% 输出: 五波束数据 beamCube、权向量 beamW、全局网格 azAxis/elAxis、局部波束坐标和标签。

% 使用第 3/4 步已经确定的波束间隔生成网格，再取离目标最近的中心束及四个邻束。
azWin = taylorwin(nAz, 4, -30);
elWin = taylorwin(nEl, 4, -30);
ampMat = (azWin(:) / max(abs(azWin))) * (elWin(:).' / max(abs(elWin)));
ampVec = ampMat(:);
ampVec = ampVec / norm(ampVec);

% dAz 在方位角度域使用；dU 在俯仰 u=sin(theta) 域使用。
azAxis = build_left_aligned_beam_grid_local( ...
    azC + min(phiRel), dAz, azC + max(phiRel));
uAxis = build_left_aligned_beam_grid_local( ...
    sind(elMin), dU, sind(elMax));
elAxis = asind(uAxis);

% 假定选取目标波束————在目标真值附近取局部五波束
[~, az0Idx] = min(abs(azAxis - azTgt));
[~, el0Idx] = min(abs(elAxis - elTgt));

% 方位和俯仰的各自三波束
az3 = azAxis(az0Idx + (-1:1));
el3 = elAxis(el0Idx + (-1:1));
az0 = azAxis(az0Idx);
el0 = elAxis(el0Idx);

% 5 个波束的角度坐标
locAz = [az3(1), az0, az3(3), az0, az0];
locEl = [el0, el0, el0, el3(1), el3(3)];
locLbl = {'方位左束', '中心束', '方位右束', '俯仰下束', '俯仰上束'};

% 对五个局部波束统一做接收波束形成，得到 beamCube: [5 x 距离 x 脉冲]。
% beamW 保留同一组接收权，后续用于生成三波束比幅鉴角曲线。
[beamCube, beamW] = form_local_beams_local( ...
    pcCube, locAz, locEl, xVec, yVec, zVec, ...
    lambda, ampVec);
end

function grid = build_left_aligned_beam_grid_local(minVal, spacing, maxVal)
% 输入: 左边界 minVal、间隔 spacing、右边界 maxVal。
% 输出: 从左边界开始的波束中心 grid。
% 从左边界开始按固定间隔排布，最后一个点不超过右边界。
nBeam = floor((maxVal - minVal) / spacing) + 1;
grid = minVal + (0:nBeam - 1) * spacing;
grid = grid(:).';
end

function [beamCube, W] = form_local_beams_local( ...
    pcCube, beamAz, beamEl, xVec, yVec, zVec, lambda, ampVec)
% 输入: 脉压数据、波束角度、阵元坐标、波长、幅度加权。
% 输出: 波束域数据 beamCube、接收权矩阵 W。
% beamCube 维度：[波束 x 距离 x 脉冲] 第 2 个波束固定为中心束
nBeam = numel(beamAz);
nElem = numel(xVec);
[~, nRange, nPulse] = size(pcCube);
pcFlat = reshape(pcCube, nElem, nRange * nPulse);

% 每一列是一个接收波束权；先把 pcCube 拉平，统一做一次矩阵乘法。
W = complex(zeros(nElem, nBeam));
for iBeam = 1:nBeam
    aNow = steer_vec_local(beamAz(iBeam), beamEl(iBeam), ...
        xVec, yVec, zVec, lambda);
    w = ampVec .* aNow;
    W(:, iBeam) = w / norm(w);
end

beamMat = W' * pcFlat;
beamCube = reshape(beamMat, nBeam, nRange, nPulse);
end

function [rdCube, vAxis] = mtd_process_local(beamCube, nfft, PRI, lambda)
% 输入: 波束域数据 beamCube、Doppler FFT 点数 nfft、PRI、波长 lambda。
% 输出: 距离-Doppler 数据 rdCube、速度轴 vAxis。
% 沿脉冲维做 Doppler FFT；Hamming 慢时间窗会加宽主瓣但降低远旁瓣。
nPulse = size(beamCube, 3);
slowWin = hamming(nPulse);
slowWin = slowWin(:) / norm(slowWin);

% MTD 只沿第 3 维，即脉冲慢时间维做 FFT；前两维波束和距离保持不变。
winCube = beamCube .* reshape(slowWin, 1, 1, []);
rdCube = fftshift(fft(winCube, nfft, 3), 3);

% 多普勒频率转速度。vAxis = -fd * lambda / 2。
fdAxis = ((0:nfft - 1) - floor(nfft / 2)) / (nfft * PRI);
vAxis = -fdAxis * lambda / 2;
end

function [thrMap, rawRIdx, rawDIdx, rawPow, nRaw, pickRIdx, pickDIdx, pickPow, alpha] = ...
    center_cfar_1d_local(rdCube, Pfa, nGuard, nRef, TypeCase, DeTypeCase)
% 输入: RD 数据、虚警概率、保护/参考单元数、CFAR 类型、检测量类型。
% 输出: 门限图、raw 检测点、检测点数、最强检测单元、CFAR 系数 alpha。
% 中心束为第 2 个波束。下面这段用 FuncCFARBase.CFAR01 
ProtectCell = nGuard;
ReferenCell = nRef;
D_Threshold = 2 * ReferenCell * (Pfa ^ (-1 / (2 * ReferenCell)) - 1);
alpha = D_Threshold;

% 中心束 RD 变成 [Doppler x Range]，对中心波束CFAR，固定doppler维度对距离1D CFAR
rdCtr = squeeze(rdCube(2, :, :));
CFARInput = rdCtr.';
[~, N] = size(CFARInput);

% DetectorType：线性或平方检测。
switch DeTypeCase
    case 'Linear'
        CFARInput = abs(CFARInput);
    case 'Square'
        CFARInput = abs(CFARInput) .^ 2;
end

y1 = [];
y2 = zeros(size(CFARInput));

% 左边界：待检测单元左侧没有完整参考窗，只使用右侧参考单元估计背景。
for jj = 1 : ReferenCell + ProtectCell
    Q = jj + ProtectCell + 1 : jj + ProtectCell + ReferenCell;
    miu = mean(CFARInput(:, Q), 2);
    y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
    temp = find(y2(:, jj) >= 1) .';
    range_idx = jj * ones(1, length(temp));
    y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']]; %#ok<AGROW>
end

% 中间区域：左右参考窗都完整，CFType 取 CA/GO/SO。
for jj = ReferenCell + ProtectCell + 1 : N - ReferenCell - ProtectCell
    Q1 = jj - ProtectCell - 1 - ReferenCell + 1 : jj - ProtectCell - 1;
    Q2 = jj + ProtectCell + 1 : jj + ProtectCell + ReferenCell;
    RightSum = mean(CFARInput(:, Q1), 2);
    LeftSum = mean(CFARInput(:, Q2), 2);
    switch TypeCase
        case 'GO'
            miu = max(RightSum, LeftSum);
        case 'SO'
            miu = min(RightSum, LeftSum);
        case 'CA'
            miu = mean([RightSum, LeftSum], 2);
    end
    y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
    temp = find(y2(:, jj) >= 1) .';
    range_idx = jj * ones(1, length(temp));
    y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']]; %#ok<AGROW>
end

% 右边界：待检测单元右侧没有完整参考窗，只使用左侧参考单元估计背景。
for jj = N - ReferenCell - ProtectCell + 1 : N
    Q = jj - ProtectCell - 1 - ReferenCell + 1 : jj - ProtectCell - 1;
    miu = mean(CFARInput(:, Q), 2);
    y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
    temp = find(y2(:, jj) >= 1) .';
    range_idx = jj * ones(1, length(temp));
    y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']]; %#ok<AGROW>
end

% y2 是检测量/threshold 比值；这里反推出门限图用于打印和画图。
thrMap = CFARInput ./ y2;
rawRIdx = y1(1, :).';
rawDIdx = y1(2, :).';
rawPow = y1(3, :).';
nRaw = numel(rawPow);

[pickPow, pickSel] = max(rawPow);
pickRIdx = rawRIdx(pickSel);
pickDIdx = rawDIdx(pickSel);
end

function a = steer_vec_local(azDeg, elDeg, x, y, z, lambda)
% 输入: 方位/俯仰角、阵元坐标、波长。
% 输出: 对应方向的导向矢量 a。
% 单个方向的阵列导向矢量。前面的系数 2 表示单站往返相位模型。
phase = 2 * 2 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end

function [valEst, axBr, rhoBr, rhoLim, side] = ...
    invert_ratio_monotonic_local(ax, rhoLut, rhoIn, amp3, ctr)
% 输入: 扫描角 ax、鉴角 LUT、实测 rho、三波束幅度 amp3、中心角 ctr。
% 输出: 估计角 valEst、单调支路 axBr/rhoBr、限幅 rhoLim、支路 side。
% 在选中的单调鉴角支路上，用实测比幅量反插值角度。
ax = ax(:);
rhoLut = rhoLut(:);
[~, idxCtr] = min(abs(ax - ctr));

% 两侧邻束幅度相等时，rho=0，目标就在中心波束方向。
if amp3(3) == amp3(1)
    valEst = ctr;
    axBr = ax(idxCtr);
    rhoBr = rhoLut(idxCtr);
    rhoLim = rhoIn;
    side = 'center';
    return;
end

% 由左右/上下邻束幅度选择目标所在支路。
if amp3(3) > amp3(1)
    side = 'right';
else
    side = 'left';
end

% 从中心点向选中方向走到单调性改变处，得到可反查的一值段。
if strcmp(side, 'left')
    idx0 = walk_monotonic_local(rhoLut, idxCtr - 1, -1);
    idxBr = idx0:idxCtr;
else
    idx1 = walk_monotonic_local(rhoLut, idxCtr, +1);
    idxBr = idxCtr:idx1;
end

axBr = ax(idxBr);
rhoBr = rhoLut(idxBr);

% interp1 要求自变量递增；若该支路 rho 递减，则同步翻转 rho 和角度。
if rhoBr(1) > rhoBr(end)
    rhoBr = flipud(rhoBr);
    axBr = flipud(axBr);
end

% rhoIn 小于 rhoMin，就取 rhoMin
% rhoIn 大于 rhoMax，就取 rhoMax
% rhoIn 在范围内，就保持不变
rhoMin = min(rhoBr);
rhoMax = max(rhoBr);
rhoLim = min(max(rhoIn, rhoMin), rhoMax);
valEst = interp1(rhoBr, axBr, rhoLim, 'linear');
end

function idx = walk_monotonic_local(rhoLut, idx0, dir)
% 输入: 鉴角 LUT、中心邻点索引 idx0、行走方向 dir(-1 或 +1)。
% 输出: 单调支路边界索引 idx。
% 从中心邻点开始沿指定方向行走，直到 rho 差分符号改变。

% 计算差分
dRho = diff(rhoLut(:));
sRef = sign(dRho(idx0));
if sRef == 0
    sRef = sign(dir);
end
% 输出边界初始化为起点
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

function ang = wrap180_local(ang)
% 输入: 任意角度 ang。
% 输出: 归一化到 [-180, 180) 的角度 ang。
% 把角度差归一化到 [-180, 180)，便于处理圆周方位的最近距离。
ang = mod(ang + 180, 360) - 180;
end
