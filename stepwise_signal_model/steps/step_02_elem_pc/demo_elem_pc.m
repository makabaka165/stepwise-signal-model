thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% 第 3 步：检查阵元时延差、空间相位和阵元级脉压测距。
cfg = sim_cfg();
rng(cfg.sim.seed);

arrInfo = arr_cyl(cfg, cfg.tgt.az);
[sTx, ~] = tx_lfm(cfg.wf);
[echoMat, truth] = echo_elem(cfg, cfg.sim.pElem);
[pcMat, pcInfo] = pc_range(echoMat, sTx, cfg, true);

% 当前阵元矩阵尺寸。
[nAzUse, nElUse] = size(truth.aMat);
midEl = ceil(nElUse / 2);
midAz = ceil(nAzUse / 2);

% 中间高度层的左、中、右三个代表性阵元。
idxLeft = sub2ind([nAzUse, nElUse], 1, midEl);
idxMid = sub2ind([nAzUse, nElUse], midAz, midEl);
idxRight = sub2ind([nAzUse, nElUse], nAzUse, midEl);

% 三个代表性阵元的局部距离窗。
maskPc = (pcInfo.rAxis >= cfg.tgt.R0 - 30) & (pcInfo.rAxis <= cfg.tgt.R0 + 30);

% 所有阵元的脉压峰值距离。
[~, idxPkAll] = max(abs(pcMat), [], 2);
rPkAll = pcInfo.rAxis(idxPkAll);
peakErrAll = rPkAll - cfg.tgt.R0;

% 两程时延矩阵与相对中心时延差。
tauMat = reshape(truth.tauVec, size(truth.xMat));
dTauNs = (truth.tauVec - truth.tau) * 1e9;

fprintf('第 3 步：阵元级回波与阵元级脉压验证\n');
fprintf('当前模式 = %s\n', truth.modeName);
fprintf('全阵阵元数 = %d\n', arrInfo.nAll);
fprintf('工作子阵列数 = %d, 阵元数 = %d\n', numel(arrInfo.colsAct), arrInfo.nAct);
fprintf('目标方位 = %.3f deg, 俯仰 = %.3f deg\n', cfg.tgt.az, cfg.tgt.el);
fprintf('当前脉冲编号 = %d\n', truth.pIdx);
fprintf('当前脉冲目标中心距离 = %.3f m\n', truth.Rp);
fprintf('目标中心往返时延 = %.6f us\n', truth.tau * 1e6);
fprintf('各阵元两程时延相对中心的偏差范围 = [%.6f, %.6f] ns\n', min(dTauNs), max(dTauNs));
fprintf('代表性阵元脉压峰值距离: 左 = %.3f m, 中 = %.3f m, 右 = %.3f m\n', ...
    rPkAll(idxLeft), rPkAll(idxMid), rPkAll(idxRight));
fprintf('全部阵元峰值距离误差范围 = [%.3f, %.3f] m\n', min(peakErrAll), max(peakErrAll));
fprintf('说明：这一步已经按每个阵元单独算距离和时延的方式生成回波，并完成阵元级脉压测距。\n');

figure('Name', '第 3 步 阵元级几何与相位');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
% 图1：当前工作子阵的阵元空间分布。
plot3(truth.xMat(:), truth.yMat(:), truth.zMat(:), '.', 'MarkerSize', 10);
grid on;
axis equal;
xlabel('x (m)');
ylabel('y (m)');
zlabel('z (m)');
title('当前工作子阵阵元分布');

nexttile;
% 图2：固定中间高度层，观察阵元实际两程时延沿方位列的变化。
plot(truth.phiUseRel, (tauMat(:, midEl) - truth.tau) * 1e9, 'o-', 'LineWidth', 1.1, 'MarkerSize', 4);
grid on;
xlabel('相对目标方位的列角 (deg)');
ylabel('相对中心两程时延 (ns)');
title('中间高度层的方位向两程时延差');

nexttile;
% 图3：固定中间方位列，观察空间相位沿高度的变化。
plot(arrInfo.zRow, unwrap(angle(truth.aMat(midAz, :))), 'o-', 'LineWidth', 1.1, 'MarkerSize', 4);
grid on;
xlabel('阵元高度 z (m)');
ylabel('展开相位 (rad)');
title('中间方位列的俯仰向空间相位');

figure('Name', '第 3 步 阵元级脉压测距');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
% 图4：三个代表性阵元的脉压后距离像。
plot(pcInfo.rAxis(maskPc), abs(pcMat(idxLeft, maskPc)), 'LineWidth', 1.1);
hold on;
plot(pcInfo.rAxis(maskPc), abs(pcMat(idxMid, maskPc)), '--', 'LineWidth', 1.1);
plot(pcInfo.rAxis(maskPc), abs(pcMat(idxRight, maskPc)), ':', 'LineWidth', 1.4);
xline(cfg.tgt.R0, ':k', 'LineWidth', 1.0);
grid on;
xlabel('距离 (m)');
ylabel('幅值');
title('三个代表性阵元的脉压后距离像');
legend('左侧阵元', '中心阵元', '右侧阵元', '真实距离', 'Location', 'best');

nexttile;
% 图5：全部阵元的脉压峰值距离。
plot(rPkAll, '.');
hold on;
yline(cfg.tgt.R0, ':k', 'LineWidth', 1.0);
grid on;
xlabel('阵元编号');
ylabel('脉压峰值距离 (m)');
title('全部阵元的脉压峰值距离');
legend('各阵元峰值', '真实距离', 'Location', 'best');

result = struct();
result.cfg = cfg;
result.arrInfo = arrInfo;
result.sTx = sTx;
result.echoMat = echoMat;
result.truth = truth;
result.pcMat = pcMat;
result.pcInfo = pcInfo;
result.rPkAll = rPkAll;
result.peakErrAll = peakErrAll;

assignin('base', 'step_03_result', result);
