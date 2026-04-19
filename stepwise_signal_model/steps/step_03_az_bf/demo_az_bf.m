thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% 第 3 步: 方位维粗波束形成。
cfg = sim_cfg();
rng(cfg.sim.seed);

[sTx, ~] = tx_lfm(cfg.wf);
[echoMat, truth] = echo_elem(cfg, cfg.sim.pElem);
[pcMat, pcInfo] = pc_range(echoMat, sTx, cfg, true);

% 先基于当前工作子阵测参考波束宽度，再生成方位粗扫网格。
azSectorCenter = cfg.beam.azSectorCenter;
elSectorCenter = cfg.beam.elSectorCenter;

azGrid = build_sector_beam_grid( ...
    'azimuth', cfg, truth, azSectorCenter, elSectorCenter);
azBw3dBRef = azGrid.ref.bw3dB;
cfg.beam.dAz = azGrid.spacing;
azBeam = azGrid.beam;

[beamMat, bfInfo] = bf_azimuth(pcMat, cfg, truth, azBeam);

% 只截取目标附近的距离窗，便于展示波束输出差异。
nBeam = numel(bfInfo.azBeam);
idxShow = bfInfo.idxTriplet;
maskRange = (pcInfo.rAxis >= truth.Rp - 40) & (pcInfo.rAxis <= truth.Rp + 40);
beamCubeDb = 20 * log10(abs(beamMat) / max(abs(beamMat(:))) + eps);

fprintf('第 3 步: 方位维粗波束形成\n');
fprintf('当前模式 = %s\n', truth.modeName);
fprintf('工作子阵 = %d 列 x %d 层\n', bfInfo.nAzUse, bfInfo.nElUse);
fprintf('方位扇区中心 = %.3f deg\n', azSectorCenter);
fprintf('参考束 3 dB 宽度 = %.3f deg\n', azBw3dBRef);
fprintf('波束间隔 dAz = %.3f deg\n', cfg.beam.dAz);
fprintf('粗扫波束数 = %d\n', nBeam);
fprintf('目标方位 = %.3f deg\n', cfg.tgt.az);
fprintf('粗测方位 = %.3f deg\n', bfInfo.azCoarse);
fprintf('三波束 = [%.3f, %.3f, %.3f] deg\n', bfInfo.azLeft, bfInfo.azMid, bfInfo.azRight);
fprintf('三波束响应 = [%.3f, %.3f, %.3f]\n', ...
    bfInfo.zTripletAbs(1), bfInfo.zTripletAbs(2), bfInfo.zTripletAbs(3));

% 四幅图分别展示: 粗扫响应、距离像热图、三波束距离切片和三波束判别量。
figure('Name', '第 3 步: 方位维粗波束形成');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(bfInfo.azBeam, bfInfo.respRefDb, 'o-', 'LineWidth', 1.1, 'MarkerSize', 4);
hold on;
plot(bfInfo.azTriplet, bfInfo.respRefDb(bfInfo.idxTriplet), 's', 'MarkerSize', 7, 'LineWidth', 1.2);
xline(cfg.tgt.az, ':k', 'LineWidth', 1.0);
xline(azSectorCenter, '-.b', 'LineWidth', 1.0);
xline(bfInfo.azCoarse, '--r', 'LineWidth', 1.0);
grid on;
xlabel('波束中心方位 (deg)');
ylabel('目标距离单元响应 (dB)');
title('方位粗扫响应');
legend('粗扫响应', '三波束位置', '目标方位', '扇区中心', '粗测波束', 'Location', 'best');

nexttile;
imagesc(pcInfo.rAxis(maskRange), bfInfo.azBeam, beamCubeDb(:, maskRange));
axis xy;
colorbar;
clim([-40 0]);
hold on;
yline(bfInfo.azLeft, '--w', 'LineWidth', 1.0);
yline(bfInfo.azMid, '-w', 'LineWidth', 1.2);
yline(bfInfo.azRight, '--w', 'LineWidth', 1.0);
xlabel('距离 (m)');
ylabel('波束中心方位 (deg)');
title('方位波束输出距离像');

nexttile;
hLines = gobjects(numel(idxShow), 1);
for ik = 1:numel(idxShow)
    hLines(ik) = plot(pcInfo.rAxis(maskRange), abs(beamMat(idxShow(ik), maskRange)), 'LineWidth', 1.1);
    hold on;
end
hTrue = xline(truth.Rp, ':k', 'LineWidth', 1.0);
grid on;
xlabel('距离 (m)');
ylabel('幅度');
title('三波束距离像对比');
legendText = arrayfun(@(idx) sprintf('波束 %.3f deg', bfInfo.azBeam(idx)), idxShow, 'UniformOutput', false);
legend([hLines; hTrue], [legendText(:); {'目标距离'}], 'Location', 'best');

nexttile;
plot(bfInfo.azTriplet, bfInfo.zTripletDb, 'o-', 'LineWidth', 1.2, 'MarkerSize', 6);
hold on;
xline(bfInfo.azTripletBest, '--r', 'LineWidth', 1.0);
grid on;
xlabel('波束中心方位 (deg)');
ylabel('相对响应 (dB)');
title('三波束内积响应');
legend('三波束响应', '最强波束', 'Location', 'best');

result = struct();
result.cfg = cfg;
result.sTx = sTx;
result.echoMat = echoMat;
result.truth = truth;
result.pcMat = pcMat;
result.pcInfo = pcInfo;
result.beamMat = beamMat;
result.bfInfo = bfInfo;

assignin('base', 'step_03_result', result);
