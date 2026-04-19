thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% 第 5 步演示链路:
% 1. 生成多脉冲阵元回波立方体 echoCube(阵元, 快时间, 脉冲)
% 2. 对每个脉冲做距离压缩，得到 pcCube(阵元, 距离, 脉冲)
% 3. 对每个二维波束做联合波束形成，得到波束域数据
% 4. 沿慢时间做 MTD，形成每个波束对应的 RD 图
% 5. 在每个 RD 图上做 1D CA-CFAR，并分别展示未加 CFAR 和加 CFAR 的结果
cfg = sim_cfg();

% 通过预留的噪声入口加入复高斯白噪声，先观察加噪后的 CFAR 表现。
cfg.sim.addNoise = true;
cfg.sim.sigmaN = 0.05;
rng(cfg.sim.seed);

[sTx, ~] = tx_lfm(cfg.wf);
[echoCube, truth] = echo_elem_cube(cfg);
[pcCube, ~] = pc_range_cube(echoCube, sTx, cfg, true);
jointOut = bf_joint_2d(pcCube, cfg, truth);
[elMesh, azMesh] = meshgrid(jointOut.elBeam, jointOut.azBeam);

% 多脉冲链路里用整段 CPI 上目标距离的平均值作为参考真值，更贴近当前 RD 结果。
rTruthRef = mean(truth.RpSeq);

% 同时给出两类结果:
% 1. 未加 CFAR 时，纯幅度意义上的最强二维波束和最强 RD 峰值
% 2. 加了 CFAR 之后，所有检测里度量值最高的那个最优检测
fprintf('第 5 步: 二维联合波束形成 + MTD + CFAR\n');
fprintf('当前模式 = %s\n', jointOut.modeName);
fprintf('工作子阵 = %d x %d\n', jointOut.nAzUse, jointOut.nElUse);
fprintf('目标真值 = (az, el) = (%.3f, %.3f) deg\n', cfg.tgt.az, cfg.tgt.el);
fprintf('是否加噪 = %d, sigmaN = %.3f\n', cfg.sim.addNoise, cfg.sim.sigmaN);
fprintf('方位波束数 = %d, dAz = %.3f deg\n', numel(jointOut.azBeam), jointOut.dAz);
fprintf('俯仰波束数 = %d, dU = %.5f\n', numel(jointOut.elBeam), jointOut.dU);
fprintf('未加 CFAR 的峰值波束 = (%.3f, %.3f) deg\n', jointOut.peakAz, jointOut.peakEl);
fprintf('未加 CFAR 的 RD 峰值 = (R, v) = (%.3f m, %.3f m/s)\n', jointOut.peakRange, jointOut.peakVel);
fprintf('CFAR 最优检测 = (az, el, R, v) = (%.3f deg, %.3f deg, %.3f m, %.3f m/s)\n', ...
    jointOut.cfar.best.az, jointOut.cfar.best.el, ...
    jointOut.cfar.best.range, jointOut.cfar.best.velocity);
fprintf('CFAR 检测点数量 = %d\n', jointOut.cfar.count);

% 图 1: 不加 CFAR，只看“哪一个二维波束最强，以及该波束的 RD 图长什么样”。
figure('Name', '第 5 步: 二维联合波束形成 + MTD（未加 CFAR）');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
% 左上: 二维波束热图。
% jointOut.beamPeakMetricGridDb 表示“每个二维波束对应的 RD 图里最大幅值是多少”。
% 白圈是真值角度，红叉是未加 CFAR 时按峰值挑出的最强二维波束。
surf(elMesh, azMesh, zeros(size(jointOut.beamPeakMetricGridDb)), ...
    jointOut.beamPeakMetricGridDb, 'EdgeColor', 'none');
view(2);
axis tight;
set(gca, 'YDir', 'normal');
colorbar;
clim([-20 0]);
hold on;
plot(cfg.tgt.el, cfg.tgt.az, 'wo', 'MarkerSize', 7, 'LineWidth', 1.2);
plot(jointOut.peakEl, jointOut.peakAz, 'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
xlabel('俯仰角 (deg)');
ylabel('方位角 (deg)');
title('二维波束网格的 MTD 峰值度量');
legend('目标真值', '未加 CFAR 的峰值', 'Location', 'best');

nexttile;
% 右上: 未加 CFAR 的最强二维波束对应的 RD 图。
% 红叉标出该 RD 图里的最大响应位置，也就是纯峰值法得到的 (R, v) 估计。
imagesc(jointOut.rAxis, jointOut.vAxis, jointOut.peakRdMapDb);
axis xy;
colorbar;
clim([-40 0]);
hold on;
plot(jointOut.peakRange, jointOut.peakVel, 'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title(sprintf('未加 CFAR 峰值波束的 RD 图 (%.3f, %.3f) deg', jointOut.peakAz, jointOut.peakEl));

nexttile;
% 左下: 在峰值多普勒单元处截取距离切片。
% 红虚线是未加 CFAR 的峰值距离，黑点虚线是理论距离。
plot(jointOut.rAxis, jointOut.peakRangeCutDb, 'LineWidth', 1.2);
hold on;
xline(jointOut.peakRange, '--r', 'LineWidth', 1.0);
xline(rTruthRef, ':k', 'LineWidth', 1.0);
grid on;
xlabel('距离 (m)');
ylabel('相对响应 (dB)');
title('未加 CFAR 峰值波束的距离切片');
legend('距离切片', '未加 CFAR 的峰值', '理论距离', 'Location', 'best');

nexttile;
% 右下: 在峰值距离单元处截取多普勒切片。
% 红虚线是未加 CFAR 的峰值速度，黑点虚线是真值速度。
plot(jointOut.vAxis, jointOut.peakDoppCutDb, 'LineWidth', 1.2);
hold on;
xline(jointOut.peakVel, '--r', 'LineWidth', 1.0);
xline(cfg.tgt.v, ':k', 'LineWidth', 1.0);
grid on;
xlabel('速度 (m/s)');
ylabel('相对响应 (dB)');
title('未加 CFAR 峰值波束的多普勒切片');
legend('多普勒切片', '未加 CFAR 的峰值', '理论速度', 'Location', 'best');

% 图 2: 加入 CFAR 之后，只展示 CFAR 选出的检测结果。
figure('Name', '第 5 步: 二维联合波束形成 + CFAR');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
% 左上: 仍用同一张二维波束热图做背景，但叠加 CFAR 检测结果。
% 青色圆圈表示至少出现过一次 CFAR 检测的二维波束中心。
% 红叉表示 metric 最高的最优检测所在二维波束。
surf(elMesh, azMesh, zeros(size(jointOut.beamPeakMetricGridDb)), ...
    jointOut.beamPeakMetricGridDb, 'EdgeColor', 'none');
view(2);
axis tight;
set(gca, 'YDir', 'normal');
colorbar;
clim([-20 0]);
hold on;
plot(cfg.tgt.el, cfg.tgt.az, 'wo', 'MarkerSize', 7, 'LineWidth', 1.2);
cfarBeamUnique = unique(jointOut.cfar.beamIdx);
plot(jointOut.elGrid(cfarBeamUnique), jointOut.azGrid(cfarBeamUnique), ...
    'co', 'MarkerSize', 5, 'LineWidth', 1.0);
plot(jointOut.cfar.best.el, jointOut.cfar.best.az, 'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
legend('目标真值', 'CFAR 检出的波束', 'CFAR 最优检测', 'Location', 'best');
xlabel('俯仰角 (deg)');
ylabel('方位角 (deg)');
title('带 CFAR 检测结果的二维波束图');

nexttile;
% 右上: CFAR 最优检测所在二维波束的 RD 图。
% 青色圆圈是该二维波束内所有通过 CFAR 的 (R, v) 检测点。
% 红叉是其中 metric 最大的最优检测点。
bestBeamMask = jointOut.cfar.beamIdx == jointOut.cfar.best.beamIdx;
imagesc(jointOut.rAxis, jointOut.vAxis, jointOut.cfar.best.rdMapDb);
axis xy;
colorbar;
clim([-40 0]);
hold on;
plot(jointOut.cfar.range(bestBeamMask), jointOut.cfar.velocity(bestBeamMask), ...
    'co', 'MarkerSize', 5, 'LineWidth', 1.0);
plot(jointOut.cfar.best.range, jointOut.cfar.best.velocity, ...
    'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title(sprintf('CFAR 最优波束的 RD 图 (%.3f, %.3f) deg', ...
    jointOut.cfar.best.az, jointOut.cfar.best.el));

nexttile;
% 左下: CFAR 最优二维波束的距离切片。
% 红虚线表示最优检测对应的距离位置，黑点虚线表示理论距离。
plot(jointOut.rAxis, jointOut.cfar.best.rangeCutDb, 'LineWidth', 1.2);
hold on;
xline(jointOut.cfar.best.range, '--r', 'LineWidth', 1.0);
xline(rTruthRef, ':k', 'LineWidth', 1.0);
grid on;
xlabel('距离 (m)');
ylabel('相对响应 (dB)');
title('CFAR 最优波束的距离切片');
legend('距离切片', 'CFAR 最优检测', '理论距离', 'Location', 'best');

nexttile;
% 右下: CFAR 最优二维波束的多普勒切片。
% 红虚线表示最优检测对应的速度位置，黑点虚线表示理论速度。
plot(jointOut.vAxis, jointOut.cfar.best.doppCutDb, 'LineWidth', 1.2);
hold on;
xline(jointOut.cfar.best.velocity, '--r', 'LineWidth', 1.0);
xline(cfg.tgt.v, ':k', 'LineWidth', 1.0);
grid on;
xlabel('速度 (m/s)');
ylabel('相对响应 (dB)');
title('CFAR 最优波束的多普勒切片');
legend('多普勒切片', 'CFAR 最优检测', '理论速度', 'Location', 'best');

% 将本步输入、输出和关键中间结果打包，便于在工作区继续查看。
result = struct();
result.cfg = cfg;
result.echoCube = echoCube;
result.truth = truth;
result.pcCube = pcCube;
result.jointOut = jointOut;

assignin('base', 'step_05_result', result);
