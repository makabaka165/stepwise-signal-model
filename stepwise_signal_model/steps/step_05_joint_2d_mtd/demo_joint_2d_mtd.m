thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% 第 5 步演示：
% 1. 生成阵元级多脉冲回波并做脉压
% 2. 在目标附近选 5 个局部唯一波束
% 3. 对中心波束 RD 图做 CFAR，再对最强目标做三波束比幅测角
cfg = sim_cfg();

cfg.sim.addNoise = true;
cfg.sim.sigmaN = 0.05;
rng(cfg.sim.seed);

[sTx, ~] = tx_lfm(cfg.wf);
[echoCube, truth] = echo_elem_cube(cfg);
[pcCube, ~] = pc_range_cube(echoCube, sTx, cfg, true);

% 第 5 步主处理链路。
jointOut = bf_joint_2d(pcCube, cfg);

fprintf('=== 第 5 步：局部五波束 MTD + 中心波束 CFAR + 三波束比幅测角 ===\n');
fprintf('目标真值 = (az %.3f deg, el %.3f deg, R0 %.1f m, v %.1f m/s)\n', ...
    cfg.tgt.az, cfg.tgt.el, cfg.tgt.R0, cfg.tgt.v);
fprintf('pcCube 维度      = %s\n', size_string_local(size(pcCube)));
fprintf('局部 beamCube    = %s\n', size_string_local(size(jointOut.local.beamCube)));
fprintf('局部 rdCube      = %s\n', size_string_local(size(jointOut.local.rdCube)));
fprintf('工作子阵规模     = %d x %d = %d 个阵元\n', ...
    jointOut.nAzUse, jointOut.nElUse, jointOut.nAzUse * jointOut.nElUse);
fprintf('扇区中心         = (az %.3f deg, el %.3f deg)\n', ...
    jointOut.azCenter, jointOut.elCenter);
fprintf('波束间隔         = dAz %.3f deg, dEl %.3f deg, dU %.5f\n', ...
    jointOut.dAz, jointOut.dEl, jointOut.dU);

fprintf('\n--- 局部波束选择 ---\n');
fprintf('中心波束         = az[%d] %.3f deg, el[%d] %.3f deg\n', ...
    jointOut.selection.centerAzIdx, jointOut.selection.centerAz, ...
    jointOut.selection.centerElIdx, jointOut.selection.centerEl);
fprintf('方位三波束       = [%.3f, %.3f, %.3f] deg\n', jointOut.selection.azTriplet);
fprintf('俯仰三波束       = [%.3f, %.3f, %.3f] deg\n', jointOut.selection.elTriplet);
fprintf('俯仰 u 三点      = [%.5f, %.5f, %.5f]\n', jointOut.selection.uTriplet);

fprintf('\n--- 中心波束检测结果 ---\n');
fprintf('原始 CFAR 点数    = %d\n', jointOut.cfarRaw.count);
fprintf('NMS 状态          = 未启用，当前直接对 raw CFAR 聚类\n');
fprintf('聚类簇个数        = %d\n', numel(jointOut.clustersRaw));
fprintf('候选目标个数      = %d\n', jointOut.candidateTargets.count);
fprintf('后筛选目标个数    = %d\n', jointOut.targets.count);
if jointOut.cfarRaw.count == 0
    fprintf('中心波束 RD 图上未检出目标。\n');
else
    nPrint = min(10, jointOut.cfarRaw.count);
    fprintf('前 %d 个原始 CFAR 检测点：\n', nPrint);
    for iDet = 1:nPrint
        fprintf(['  Det %d: rangeIdx = %d, doppIdx = %d, ' ...
            'R = %.3f m, v = %.3f m/s, metric = %.4f\n'], ...
            iDet, jointOut.cfarRaw.rangeIdx(iDet), jointOut.cfarRaw.dopplerIdx(iDet), ...
            jointOut.cfarRaw.range(iDet), jointOut.cfarRaw.velocity(iDet), jointOut.cfarRaw.metric(iDet));
    end
    if jointOut.cfarRaw.count > nPrint
        fprintf('  ... 其余 %d 个原始检测点省略\n', jointOut.cfarRaw.count - nPrint);
    end
    if jointOut.candidateTargets.count > 0
        fprintf('聚类得到的候选目标代表点：\n');
        for iDet = 1:jointOut.candidateTargets.count
            fprintf(['  Tgt %d: rangeIdx = %d, doppIdx = %d, ' ...
                'R = %.3f m, v = %.3f m/s, metric = %.4f\n'], ...
                iDet, jointOut.candidateTargets.rangeIdx(iDet), jointOut.candidateTargets.dopplerIdx(iDet), ...
                jointOut.candidateTargets.range(iDet), jointOut.candidateTargets.velocity(iDet), jointOut.candidateTargets.metric(iDet));
        end
    end
    if jointOut.targets.count > 0
        fprintf('后筛选保留的目标：\n');
        for iDet = 1:jointOut.targets.count
            fprintf(['  Keep %d: rangeIdx = %d, doppIdx = %d, ' ...
                'R = %.3f m, v = %.3f m/s, metric = %.4f\n'], ...
                iDet, jointOut.targets.rangeIdx(iDet), jointOut.targets.dopplerIdx(iDet), ...
                jointOut.targets.range(iDet), jointOut.targets.velocity(iDet), jointOut.targets.metric(iDet));
        end
    end
end

fprintf('\n--- 最终单目标输出 ---\n');
if jointOut.cfarRaw.count == 0
    fprintf('由于中心波束 CFAR 未检出目标，因此没有最终测角结果。\n');
else
    fprintf('最强粗测目标      = (az %.3f deg, el %.3f deg, R %.3f m, v %.3f m/s, metric %.4f)\n', ...
        jointOut.finalDetection.beamAz, jointOut.finalDetection.beamEl, ...
        jointOut.finalDetection.range, jointOut.finalDetection.velocity, jointOut.finalDetection.metric);
    fprintf('最强精测角        = (az %.3f deg, el %.3f deg)\n', ...
        jointOut.bestAz, jointOut.bestEl);
    fprintf('比幅结果          = (az %.4f, el %.4f)\n', ...
        jointOut.fine.azRatio, jointOut.fine.elRatio);
    fprintf('回退原因          = (%s, %s)\n', ...
        fallback_string_local(jointOut.fine.azFallbackReason), ...
        fallback_string_local(jointOut.fine.elFallbackReason));
end

plot_selection_figure_local(jointOut, cfg);
plot_center_rd_figure_local(jointOut, truth, cfg);
if jointOut.cfarRaw.count > 0
    plot_ratio_figure_local(jointOut);
end

result = struct();
result.cfg = cfg;
result.echoCube = echoCube;
result.truth = truth;
result.pcCube = pcCube;
result.jointOut = jointOut;
assignin('base', 'step_05_result', result);

function plot_selection_figure_local(jointOut, cfg)
allAz = repelem(jointOut.azGrid(:), numel(jointOut.elGrid), 1);
allEl = repmat(jointOut.elGrid(:), numel(jointOut.azGrid), 1);

figure('Name', '第 5 步 局部波束选择', 'Position', fit_figure_position_local([90, 60, 760, 500]));

% 展示完整波束中心网格以及当前选中的 5 个局部波束。
plot(allEl, allAz, '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 8);
hold on;
plot(cfg.tgt.el, cfg.tgt.az, 'ko', 'MarkerSize', 7, 'LineWidth', 1.2);
plot(jointOut.local.beamEl, jointOut.local.beamAz, 'rs', 'MarkerSize', 8, 'LineWidth', 1.2);
text(jointOut.local.beamEl + 0.2, jointOut.local.beamAz + 0.2, jointOut.local.labels, ...
    'FontSize', 9);
xMargin = max(3 * jointOut.dEl, 2.5);
yMargin = max(3 * jointOut.dAz, 2.5);
xMin = min([jointOut.local.beamEl, cfg.tgt.el]) - xMargin;
xMax = max([jointOut.local.beamEl, cfg.tgt.el]) + xMargin;
yMin = min([jointOut.local.beamAz, cfg.tgt.az]) - yMargin;
yMax = max([jointOut.local.beamAz, cfg.tgt.az]) + yMargin;
xlim([xMin, xMax]);
ylim([yMin, yMax]);
grid on;
xlabel('俯仰角 (deg)');
ylabel('方位角 (deg)');
title('波束网格与选中的局部五波束');
legend('全部波束中心', '目标真值', '选中的局部波束', ...
    'Location', 'eastoutside');
end

function plot_center_rd_figure_local(jointOut, truth, cfg)
rdMap = squeeze(abs(jointOut.local.rdCube(2, :, :))).';
rdMapDb = 20 * log10(rdMap / max(rdMap(:)) + eps);

figure('Name', '第 5 步 中心波束 RD 图', 'Position', fit_figure_position_local([110, 80, 860, 540]));
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% 左侧大图叠加原始检测点、局部峰值、提取目标和最终目标。
nexttile([2 1]);
imagesc(jointOut.rAxis, jointOut.vAxis, rdMapDb);
axis xy;
colorbar;
clim([-40 0]);
hold on;
plot(jointOut.cfarRaw.range, jointOut.cfarRaw.velocity, 'k.', 'MarkerSize', 6);
plot(jointOut.candidateTargets.range, jointOut.candidateTargets.velocity, 'yd', 'MarkerSize', 7, 'LineWidth', 1.0);
plot(jointOut.targets.range, jointOut.targets.velocity, 'ms', 'MarkerSize', 7, 'LineWidth', 1.0);
if jointOut.cfarRaw.count > 0
    plot(jointOut.finalDetection.range, jointOut.finalDetection.velocity, 'rx', 'MarkerSize', 10, 'LineWidth', 1.4);
end
xline(mean(truth.RpSeq), ':w', 'LineWidth', 0.8);
yline(cfg.tgt.v, ':w', 'LineWidth', 0.8);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title(sprintf('中心波束 RD 图，中心角度为 (%.2f, %.2f) deg', ...
    jointOut.selection.centerAz, jointOut.selection.centerEl));
legend('原始 CFAR', '候选目标', '后筛选目标', '最终目标', '真值距离', '真值速度', ...
    'Location', 'northeastoutside');

% 右上图固定在最终目标速度单元，观察距离切片。
nexttile;
if jointOut.cfarRaw.count == 0
    axis off;
    text(0.0, 0.5, '中心波束上没有 CFAR 检测结果', 'Interpreter', 'none');
else
    rangeCut = squeeze(abs(jointOut.local.rdCube(2, :, jointOut.finalDetection.dopplerIdx)));
    rangeCutDb = 20 * log10(rangeCut / max(rangeCut) + eps);
    plot(jointOut.rAxis, rangeCutDb, 'LineWidth', 1.2);
    hold on;
    xline(cfg.tgt.R0, ':k', 'LineWidth', 0.8);
    xline(jointOut.finalDetection.range, '--r', 'LineWidth', 1.0);
    grid on;
    xlabel('距离 (m)');
    ylabel('相对响应 (dB)');
    title(sprintf('速度 %.2f m/s 处的距离切片', jointOut.finalDetection.velocity));
end

% 右下图固定在最终目标距离单元，观察多普勒切片。
nexttile;
if jointOut.cfarRaw.count == 0
    axis off;
    text(0.0, 0.5, '中心波束上没有 CFAR 检测结果', 'Interpreter', 'none');
else
    doppCut = squeeze(abs(jointOut.local.rdCube(2, jointOut.finalDetection.rangeIdx, :)));
    doppCutDb = 20 * log10(doppCut / max(doppCut) + eps);
    plot(jointOut.vAxis, doppCutDb, 'LineWidth', 1.2);
    hold on;
    xline(cfg.tgt.v, ':k', 'LineWidth', 0.8);
    xline(jointOut.finalDetection.velocity, '--r', 'LineWidth', 1.0);
    grid on;
    xlabel('速度 (m/s)');
    ylabel('相对响应 (dB)');
    title(sprintf('距离 %.2f m 处的多普勒切片', jointOut.finalDetection.range));
end
end

function plot_ratio_figure_local(jointOut)
figure('Name', '第 5 步 比幅诊断', 'Position', fit_figure_position_local([130, 100, 820, 520]));
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% 左列分别看两个三波束组在最终目标单元上的幅度分布。
nexttile;
bar(jointOut.fine.azTripletAngles, jointOut.fine.azTripletAmps);
grid on;
xlabel('方位波束中心 (deg)');
ylabel('幅度');
title('方位三波束幅度');

% 右列分别看方位和俯仰的比幅查找表与测量点位置。
nexttile;
plot(jointOut.fine.azRatioAngleAxis, jointOut.fine.azRatioLut, '-', ...
    'Color', [0.70 0.70 0.70], 'LineWidth', 1.0);
hold on;
plot(jointOut.fine.azRatioBranchAxis, jointOut.fine.azRatioBranch, ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.0);
plot(jointOut.bestAz, jointOut.fine.azRatio, 'ro', 'MarkerSize', 7, 'LineWidth', 1.1);
if isfinite(jointOut.fine.azRatioClamped) && abs(jointOut.fine.azRatioClamped - jointOut.fine.azRatio) > 1e-12
    plot(jointOut.bestAz, jointOut.fine.azRatioClamped, 'rx', 'MarkerSize', 8, 'LineWidth', 1.1);
end
grid on;
xlabel('方位角 (deg)');
ylabel('\rho');
legend('完整 LUT', '有效单调分支', '测量比幅点', 'Location', 'best');
title('方位比幅查找表');

nexttile;
bar(jointOut.fine.elTripletAngles, jointOut.fine.elTripletAmps);
grid on;
xlabel('俯仰波束中心 (deg)');
ylabel('幅度');
title('俯仰三波束幅度');

nexttile;
plot(jointOut.fine.elRatioAxis, jointOut.fine.elRatioLut, '-', ...
    'Color', [0.70 0.70 0.70], 'LineWidth', 1.0);
hold on;
plot(jointOut.fine.elRatioBranchAxis, jointOut.fine.elRatioBranch, ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.0);
plot(jointOut.fine.u, jointOut.fine.elRatio, 'ro', 'MarkerSize', 7, 'LineWidth', 1.1);
if isfinite(jointOut.fine.elRatioClamped) && abs(jointOut.fine.elRatioClamped - jointOut.fine.elRatio) > 1e-12
    plot(jointOut.fine.u, jointOut.fine.elRatioClamped, 'rx', 'MarkerSize', 8, 'LineWidth', 1.1);
end
grid on;
xlabel('u = sin(el)');
ylabel('\rho');
legend('完整 LUT', '有效单调分支', '测量比幅点', 'Location', 'best');
title('俯仰比幅查找表');
end

function out = fallback_string_local(strIn)
if isempty(strIn)
    out = '无';
else
    out = strIn;
end
end

function out = size_string_local(sz)
out = sprintf('%d x %d x %d', sz(1), sz(2), sz(3));
end

function pos = fit_figure_position_local(posReq)
screenPos = get(groot, 'ScreenSize');
marginX = 40;
marginY = 70;
minWidth = 560;
minHeight = 360;

maxWidth = max(minWidth, screenPos(3) - 2 * marginX);
maxHeight = max(minHeight, screenPos(4) - 2 * marginY);

pos = posReq;
pos(3) = min(posReq(3), maxWidth);
pos(4) = min(posReq(4), maxHeight);
pos(1) = min(max(posReq(1), marginX), max(screenPos(3) - pos(3) - marginX, marginX));
pos(2) = min(max(posReq(2), marginY), max(screenPos(4) - pos(4) - marginY, marginY));
end
