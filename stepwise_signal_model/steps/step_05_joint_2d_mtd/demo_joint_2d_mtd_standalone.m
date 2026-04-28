clc;
clear;
close all;


% 第 5 步独立演示脚本。
% 固定处理链路：
% 圆柱阵工作子阵 -> 阵元级多脉冲回波 -> 距离脉压 -> 局部五波束形成
% -> 慢时间 MTD -> 中心束距离向 CA-CFAR -> raw 检测单元显示。

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
% 1 取当前扇区的工作子阵。
% x/y/z 是参与波束形成的阵元坐标；nAz/nEl 保留当前子阵的方位列数和俯仰行数。
[xVec, yVec, zVec, nAz, nEl, phiRel] = ...
    select_work_array_local(Naz, Nel, Rcyl, dz, azC, subNaz);

% 2 生成阵元级回波，并逐脉冲做距离向脉压。
% pcCube 维度为 阵元 x 距离采样 x 脉冲，是后续接收波束形成的输入。
[pcCube, rAxis, RpSeq] = simulate_pc_cube_local( ...
    xVec, yVec, zVec, c, lambda, Tp, K, tTx, tFast, tSlow, ...
    R0, vTgt, azTgt, elTgt, ampTgt, sigmaN);

% 3 在目标附近选取局部五波束：中心束、方位左右束、俯仰上下束。
% 这一步直接沿用第 3/4 步确定的波束间隔，排布粗波束网格。
[beamCube, azAxis, elAxis, locAz, locEl, locLbl] = ...
    build_local_five_beams_local( ...
        pcCube, xVec, yVec, zVec, phiRel, ...
        nAz, nEl, lambda, dAz, dU, ...
        azC, elMin, elMax, azTgt, elTgt);

% 4 对五个波束分别做慢时间 FFT，得到 RD cube。
% rdCube 维度为 波束 x 距离 x Doppler；第 2 个波束固定为中心束。
[rdCube, vAxis] = mtd_process_local(beamCube, nfft, PRI, lambda);

% 5 只取中心束做 CFAR。raw 是所有过门限检测单元，不等同于物理目标数。
[thrMap, rawRIdx, rawDIdx, rawPow, nRaw, pickRIdx, pickDIdx, pickPow, alpha] = ...
    center_cfar_1d_local(rdCube, Pfa, nGuard, nRef, TypeCase, DeTypeCase);

%% 输出
fprintf('=== 第5步：局部五波束 MTD + 中心束 1D 距离 CFAR ===\n');
fprintf('[参数] ampTgt=%.4f, sigmaN=%.4f, Pfa=%.1e, Np=%d, MTD=%s, CFAR=%s-%s, guard/ref=%d/%d, alpha=%.4f\n', ...
    ampTgt, sigmaN, Pfa, Np, mtdWin, TypeCase, DeTypeCase, nGuard, nRef, alpha);
fprintf('[真值] R=%.1f m, v=%.1f m/s, az=%.1f deg, el=%.1f deg\n', ...
    R0, vTgt, azTgt, elTgt);
fprintf('[结果] raw=%d\n', nRaw);
fprintf('[选取] R=%.1f m, v=%.1f m/s, metric=%.4f\n', ...
    rAxis(pickRIdx), vAxis(pickDIdx), pickPow);

% 打印所有 raw CFAR 点，便于和 RD 图上的黑点对应。
for iDet = 1:nRaw
    thrNow = thrMap(rawDIdx(iDet), rawRIdx(iDet));
    ratio = rawPow(iDet) / thrNow;
    fprintf('  [%d] rangeIdx=%d, doppIdx=%d, R=%.1f m, v=%.1f m/s, metric=%.4f, threshold=%.4f, ratio=%.4f\n', ...
        iDet, rawRIdx(iDet), rawDIdx(iDet), ...
        rAxis(rawRIdx(iDet)), vAxis(rawDIdx(iDet)), ...
        rawPow(iDet), thrNow, ratio);
end

%% 定位图和 CFAR 对照图
% 横轴俯仰、纵轴方位
allAz = repelem(azAxis(:), numel(elAxis), 1);
allEl = repmat(elAxis(:), numel(azAxis), 1);
zoomEl = [locEl(:); elTgt];
zoomAz = [locAz(:); azTgt];

% 局部视图留一点边界
elPad = max(1.0, 0.35 * (max(zoomEl) - min(zoomEl)));
azPad = max(1.0, 0.35 * (max(zoomAz) - min(zoomAz)));

figure('Name', '第5步 波束选择', 'Position', [90, 60, 760, 500]);
hGrid = plot(allEl, allAz, '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 8);
hold on;
hTarget = plot(elTgt, azTgt, 'ko', 'MarkerSize', 7, 'LineWidth', 1.2);
hLocal = plot(locEl, locAz, 'rs', 'MarkerSize', 8, 'LineWidth', 1.2);
text(locEl + 0.08 * elPad, locAz + 0.08 * azPad, locLbl, 'FontSize', 9);
xlim([min(zoomEl) - elPad, max(zoomEl) + elPad]);
ylim([min(zoomAz) - azPad, max(zoomAz) + azPad]);
grid on;
xlabel('俯仰角 (deg)');
ylabel('方位角 (deg)');
title('波束网格与选中的局部五波束');
legend([hGrid, hTarget, hLocal], {'全部波束中心', '目标真值', '局部五波束'}, 'Location', 'eastoutside');

% 图 2：中心束 RD 图。黑点是所有 CFAR 过门限单元。
rdMap = squeeze(abs(rdCube(2, :, :))).';
rdMapDb = 20 * log10(rdMap / max(rdMap(:)) + eps);

figure('Name', '第5步 中心波束RD图', 'Position', [110, 80, 780, 520]);
imagesc(rAxis, vAxis, rdMapDb);
axis xy;
colorbar;
clim([-40 0]);
hold on;
hRaw = plot(rAxis(rawRIdx), vAxis(rawDIdx), 'k.', 'MarkerSize', 6);
hPick = plot(rAxis(pickRIdx), vAxis(pickDIdx), 'rx', 'MarkerSize', 10, 'LineWidth', 1.4);
hTruthRange = xline(mean(RpSeq), ':w', 'LineWidth', 0.8);
hTruthVelocity = yline(vTgt, ':w', 'LineWidth', 0.8);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title('中心波束 RD 图');
legend([hRaw, hPick, hTruthRange, hTruthVelocity], ...
    {'raw CFAR', '最大 metric', '真值距离', '真值速度'}, 'Location', 'northeastoutside');

% 图 3：把 raw 检测所在 Doppler 行的距离向响应和 CFAR 门限分开画。
% 每个子图对应一个 Doppler 行，实线是检测量，虚线是 CFAR 门限，圆圈标出 raw 过门限单元。
rdCtrMap = squeeze(rdCube(2, :, :)).';
switch DeTypeCase
    case 'Linear'
        respMap = abs(rdCtrMap);
    case 'Square'
        respMap = abs(rdCtrMap) .^ 2;
end

dShow = unique(rawDIdx(:).', 'stable');
figure('Name', '第5步 CFAR响应与门限', 'Position', [130, 100, 920, 720]);
tiledlayout(numel(dShow), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for iLine = 1:numel(dShow)
    dIdx = dShow(iLine);
    refVal = max([respMap(dIdx, :), thrMap(dIdx, :)]);
    respDb = 10 * log10(respMap(dIdx, :) / refVal + eps);
    thrDb = 10 * log10(thrMap(dIdx, :) / refVal + eps);
    hitRIdx = rawRIdx(rawDIdx == dIdx);
    hitDb = 10 * log10(respMap(dIdx, hitRIdx) / refVal + eps);

    nexttile;
    plot(rAxis, respDb, 'LineWidth', 1.2);
    hold on;
    plot(rAxis, thrDb, '--', 'LineWidth', 1.1);
    plot(rAxis(hitRIdx), hitDb, 'ro', 'MarkerSize', 5.5, 'LineWidth', 1.1);
    xline(mean(RpSeq), ':k', 'LineWidth', 0.9);
    grid on;
    ylabel('相对功率 (dB)');
    title(sprintf('v = %.1f m/s 的距离向 CFAR', vAxis(dIdx)));
    legend('检测量', 'CFAR门限', 'raw过门限点', '真值距离', 'Location', 'eastoutside');
end
xlabel('距离 (m)');

function [xVec, yVec, zVec, nAz, nEl, phiRelUse] = ...
    select_work_array_local(Naz, Nel, Rcyl, dz, azCtr, subNaz)
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

function [beamCube, azAxis, elAxis, locAz, locEl, locLbl] = ...
    build_local_five_beams_local( ...
        pcCube, xVec, yVec, zVec, phiRel, ...
        nAz, nEl, lambda, dAz, dU, ...
        azC, elMin, elMax, azTgt, elTgt)

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
beamCube = form_local_beams_local( ...
    pcCube, locAz, locEl, xVec, yVec, zVec, ...
    lambda, ampVec);
end

function grid = build_left_aligned_beam_grid_local(minVal, spacing, maxVal)
% 从左边界开始按固定间隔排布，最后一个点不超过右边界。
nBeam = floor((maxVal - minVal) / spacing) + 1;
grid = minVal + (0:nBeam - 1) * spacing;
grid = grid(:).';
end

function beamCube = form_local_beams_local( ...
    pcCube, beamAz, beamEl, xVec, yVec, zVec, lambda, ampVec)
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
% 单个方向的阵列导向矢量。前面的系数 2 表示单站往返相位模型。
phase = 2 * 2 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end

function ang = wrap180_local(ang)
% 把角度差归一化到 [-180, 180)，便于处理圆周方位的最近距离。
ang = mod(ang + 180, 360) - 180;
end
