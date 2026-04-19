function info = analyze_reference_beam(modeName, cfg, truth, azCenterDeg, elCenterDeg)
%ANALYZE_REFERENCE_BEAM 构造扇区中心参考波束，并测量其主瓣宽度。
% 输入:
%   modeName    - 'azimuth' 或 'elevation'
%   cfg         - 全局配置
%   truth       - 当前工作子阵的几何真值信息
%   azCenterDeg - 当前扇区中心方位角
%   elCenterDeg - 当前扇区中心俯仰角
% 输出:
%   info        - 参考波束的扫描轴、方向图和 3 dB 宽度信息
%
% 说明:
%   该函数不直接输出波束形成结果，而是先基于当前工作子阵、
%   当前加窗和当前扇区中心构造一个参考波束，再测量这个参考波束的宽度。
%   后续 build_sector_beam_grid 会直接使用这里得到的宽度来决定波束间隔。

beam = cfg.beam;
arr = cfg.arr;

% 将二维工作子阵坐标拉直成列向量，便于统一构造导向矢量和扫描矩阵。
[nAzUse, nElUse] = size(truth.xMat);
xUse = truth.xMat(:);
yUse = truth.yMat(:);
zUse = truth.zMat(:);

% 构造参考波束使用的二维幅度加权。
azWin = make_window_local(nAzUse, beam, 'az');
elWin = make_window_local(nElUse, beam, 'el');
ampMat = azWin(:) * elWin(:).';
ampVec = ampMat(:);
ampVec = ampVec / norm(ampVec);

% 扇区中心方向上的导向矢量乘上幅度窗后，得到测宽所用的参考权向量。
aRef = steer_vec_local(azCenterDeg, elCenterDeg, xUse, yUse, zUse, ...
    arr.lambda, beam.spatialPhaseFactor);
wRef = normalize_weight_local(ampVec .* aRef);

if strcmpi(modeName, 'azimuth')
    % 方位模式下保持俯仰固定，只沿方位轴扫描。
    scanAxis = azCenterDeg + beam.azPatternAxisDeg(:).';
    steerScan = steer_scan_local('azimuth', scanAxis, elCenterDeg, ...
        xUse, yUse, zUse, arr.lambda, beam.spatialPhaseFactor);

    bwInfo = measure_scan_3db_width(scanAxis, wRef, steerScan);

    info = struct();
    info.scanAxis = scanAxis;
    info.patternDb = bwInfo.patternDb;
    info.leftCross = bwInfo.leftCross;
    info.rightCross = bwInfo.rightCross;
    info.bw3dB = bwInfo.bw3dB;
    return;
end

% 俯仰模式下先在角度轴 theta 上扫描，再映射到 u = sin(theta) 轴。
% 这样可同时得到角度域和 u 域的 3 dB 宽度。
thetaAxis = beam.elPatternAxisDeg(:).';
uAxis = sind(thetaAxis);
steerScan = steer_scan_local('elevation', thetaAxis, azCenterDeg, ...
    xUse, yUse, zUse, arr.lambda, beam.spatialPhaseFactor);

% 同一个参考波束响应分别在 theta 轴和 u 轴上测宽。
bwInfoTheta = measure_scan_3db_width(thetaAxis, wRef, steerScan);
bwInfoU = measure_scan_3db_width(uAxis, wRef, steerScan);

info = struct();
info.scanAxis = thetaAxis;
info.thetaAxis = thetaAxis;
info.uAxis = uAxis;
info.patternDb = bwInfoTheta.patternDb;
info.leftCross = bwInfoTheta.leftCross;
info.rightCross = bwInfoTheta.rightCross;
info.bw3dB = bwInfoTheta.bw3dB;
info.leftCrossU = bwInfoU.leftCross;
info.rightCrossU = bwInfoU.rightCross;
info.bw3dBU = bwInfoU.bw3dB;
end

function win = make_window_local(n, beam, dimName)
%MAKE_WINDOW_LOCAL 按维度读取配置并生成对应的幅度窗。
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
%STEER_VEC_LOCAL 构造单个方向上的阵列导向矢量。
phase = phaseFactor * 2 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end

function steerMat = steer_scan_local(modeName, scanAxisAbs, fixedAngleDeg, x, y, z, lambda, phaseFactor)
%STEER_SCAN_LOCAL 构造整条扫描轴上的导向矩阵。
% 输出 steerMat 的每一列对应扫描轴上的一个候选方向。
if strcmpi(modeName, 'azimuth')
    % 方位扫描: 俯仰固定，只改变方位角。
    projX = cosd(scanAxisAbs) * cosd(fixedAngleDeg);
    projY = sind(scanAxisAbs) * cosd(fixedAngleDeg);
    projZ = sind(fixedAngleDeg) * ones(size(scanAxisAbs));
else
    % 俯仰扫描: 方位固定，只改变俯仰角。
    projX = cosd(fixedAngleDeg) * cosd(scanAxisAbs);
    projY = sind(fixedAngleDeg) * cosd(scanAxisAbs);
    projZ = sind(scanAxisAbs);
end

phase = phaseFactor * 2 * pi / lambda * ...
    (x * projX + y * projY + z * projZ);
steerMat = exp(1j * phase);
end

function w = normalize_weight_local(w)
%NORMALIZE_WEIGHT_LOCAL 将权向量做二范数归一化。
w = w / norm(w);
end
