thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% Step 4: elevation-dimension coarse beamforming.
cfg = sim_cfg();
rng(cfg.sim.seed);

[sTx, ~] = tx_lfm(cfg.wf);
[echoMat, truth] = echo_elem(cfg, cfg.sim.pElem);
[pcMat, pcInfo] = pc_range(echoMat, sTx, cfg, true);

% Build elevation coarse-scan beams under a fixed azimuth steering angle.
[beamMat, bfInfo] = bf_elevation(pcMat, cfg, truth, cfg.beam.azSteer);

% Only keep the range window near the target so beam differences are visible.
nBeam = numel(bfInfo.elBeam);
idxShow = bfInfo.idxTriplet;
maskRange = (pcInfo.rAxis >= truth.Rp - 40) & (pcInfo.rAxis <= truth.Rp + 40);
beamCubeDb = 20 * log10(abs(beamMat) / max(abs(beamMat(:))) + eps);

fprintf('第 4 步: 俯仰维粗波束形成\n');
fprintf('当前模式 = %s\n', truth.modeName);
fprintf('工作子阵 = %d 列 x %d 层\n', bfInfo.nAzUse, bfInfo.nElUse);
fprintf('固定方位指向 = %.3f deg\n', bfInfo.azSteer);
fprintf('俯仰扇区中心 = %.3f deg\n', bfInfo.elSectorCenter);
fprintf('参考束角度域 3 dB 宽度 = %.3f deg\n', bfInfo.bw3dBRef);
fprintf('参考束 u 域 3 dB 宽度 = %.5f\n', bfInfo.bw3dBURef);
fprintf('波束间隔 dU = %.5f\n', bfInfo.dU);
fprintf('粗扫波束数 = %d\n', nBeam);
fprintf('目标俯仰 = %.3f deg\n', cfg.tgt.el);
fprintf('粗测俯仰 = %.3f deg\n', bfInfo.elCoarse);
fprintf('三波束 = [%.3f, %.3f, %.3f] deg\n', bfInfo.elLeft, bfInfo.elMid, bfInfo.elRight);
fprintf('三波束响应 = [%.3f, %.3f, %.3f]\n', ...
    bfInfo.zTripletAbs(1), bfInfo.zTripletAbs(2), bfInfo.zTripletAbs(3));

% Four subplots: coarse scan, range image, triplet range cuts, triplet metric.
figure('Name', '第 4 步: 俯仰维粗波束形成');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(bfInfo.elBeam, bfInfo.respRefDb, 'o-', 'LineWidth', 1.1, 'MarkerSize', 4);
hold on;
plot(bfInfo.elTriplet, bfInfo.respRefDb(bfInfo.idxTriplet), 's', 'MarkerSize', 7, 'LineWidth', 1.2);
xline(cfg.tgt.el, ':k', 'LineWidth', 1.0);
xline(bfInfo.elSectorCenter, '-.b', 'LineWidth', 1.0);
xline(bfInfo.elCoarse, '--r', 'LineWidth', 1.0);
grid on;
xlabel('波束中心俯仰 \theta (deg)');
ylabel('目标距离单元响应 (dB)');
title('俯仰粗扫响应');
legend('粗扫响应', '三波束位置', '目标俯仰', '扇区中心俯仰', '粗测波束', 'Location', 'best');

nexttile;
imagesc(pcInfo.rAxis(maskRange), bfInfo.elBeam, beamCubeDb(:, maskRange));
axis xy;
colorbar;
clim([-40 0]);
hold on;
yline(bfInfo.elLeft, '--w', 'LineWidth', 1.0);
yline(bfInfo.elMid, '-w', 'LineWidth', 1.2);
yline(bfInfo.elRight, '--w', 'LineWidth', 1.0);
xlabel('距离 (m)');
ylabel('波束中心俯仰 (deg)');
title('俯仰波束输出距离像');

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
legendText = arrayfun(@(idx) sprintf('波束 %.3f deg', bfInfo.elBeam(idx)), idxShow, 'UniformOutput', false);
legend([hLines; hTrue], [legendText(:); {'目标距离'}], 'Location', 'best');

nexttile;
plot(bfInfo.elTriplet, bfInfo.zTripletDb, 'o-', 'LineWidth', 1.2, 'MarkerSize', 6);
hold on;
xline(bfInfo.elTripletBest, '--r', 'LineWidth', 1.0);
grid on;
xlabel('波束中心俯仰 \theta (deg)');
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

assignin('base', 'step_04_result', result);
