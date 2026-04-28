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
jointOut = bf_joint_2d_step5(pcCube, cfg);

fprintf('=== 第 5 步：局部五波束 MTD + 中心波束 CFAR + 三波束比幅测角 ===\n');
fprintf('目标真值 = (az %.3f deg, el %.3f deg, R0 %.1f m, v %.1f m/s)\n', ...
    cfg.tgt.az, cfg.tgt.el, cfg.tgt.R0, cfg.tgt.v);
fprintf('pcCube 维度      = %s\n', size_string_local(size(pcCube)));
fprintf('局部 beamCube    = %s\n', size_string_local(size(jointOut.local.beamCube)));
fprintf('局部 rdCube      = %s\n', size_string_local(size(jointOut.local.rdCube)));
fprintf('MTD 慢时间窗     = %s\n', jointOut.mtd.winType);
fprintf('工作子阵规模     = %d x %d = %d 个阵元\n', ...
    jointOut.nAzUse, jointOut.nElUse, jointOut.nAzUse * jointOut.nElUse);
fprintf('扇区中心         = (az %.3f deg, el %.3f deg)\n', ...
    jointOut.azCenter, jointOut.elCenter);
fprintf('波束间隔         = dAz %.3f deg, dEl %.3f deg, dU %.5f\n', ...
    jointOut.dAz, jointOut.dEl, jointOut.dU);

fprintf('\n--- 局部波束选择 ---\n');
fprintf('中心波束         = az[%d] %.3f deg, el[%d] %.3f deg\n', ...
    jointOut.selection.coarseCenter.azIdx, jointOut.selection.coarseCenter.az, ...
    jointOut.selection.coarseCenter.elIdx, jointOut.selection.coarseCenter.el);
fprintf('方位三波束       = [%.3f, %.3f, %.3f] deg\n', jointOut.selection.azTriplet);
fprintf('俯仰三波束       = [%.3f, %.3f, %.3f] deg\n', jointOut.selection.elTriplet);
fprintf('俯仰 u 三点      = [%.5f, %.5f, %.5f]\n', jointOut.selection.uTriplet);

fprintf('\n--- 中心波束检测结果 ---\n');
fprintf('raw 过门限点数     = %d\n', jointOut.singleTargetSelectInfo.rawThresholdCrossingCount);
fprintf('最终检测单元数     = %d\n', jointOut.singleTargetSelectInfo.singleDetectionCellCount);
fprintf('CFAR 后处理       = 不做目标聚类，直接取 raw CFAR 最强单点作为单目标检测单元\n');
fprintf('门限公式          = %s\n', jointOut.cfarRaw.thresholdInfo.formula);
if strcmp(jointOut.cfarRaw.thresholdInfo.mode, 'pfa_formula')
    fprintf('虚警概率 Pfa      = %.3e\n', jointOut.cfarRaw.thresholdInfo.falseAlarmRate);
    fprintf('参考单元 Nref     = 单侧 %d，双侧 %d\n', ...
        jointOut.cfarRaw.thresholdInfo.referenceCellOneSided, ...
        jointOut.cfarRaw.thresholdInfo.referenceCellTwoSided);
    fprintf('门限系数 alpha    = 单侧 %.4f，双侧 %.4f\n', ...
        jointOut.cfarRaw.thresholdInfo.scaleOneSided, ...
        jointOut.cfarRaw.thresholdInfo.scaleTwoSided);
else
    fprintf('门限系数 alpha    = %.4f\n', jointOut.cfarRaw.thresholdInfo.scaleTwoSided);
end
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
    if jointOut.targets.count > 0
        fprintf('最终选中的 1 个检测单元：\n');
        for iDet = 1:jointOut.targets.count
            fprintf(['  Pick %d: rangeIdx = %d, doppIdx = %d, ' ...
                'R = %.3f m, v = %.3f m/s, metric = %.4f\n'], ...
                iDet, jointOut.targets.rangeIdx(iDet), jointOut.targets.dopplerIdx(iDet), ...
                jointOut.targets.range(iDet), jointOut.targets.velocity(iDet), jointOut.targets.metric(iDet));
        end
    end
end

fprintf('\n--- 最终单目标输出 ---\n');
if jointOut.targets.count == 0
    fprintf('中心束 CFAR 未检出目标，因此没有最终测角结果。\n');
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
plot_signal_chain_figure_local(sTx, echoCube, pcCube, jointOut, truth, cfg);
plot_center_rd_figure_local(jointOut, truth, cfg);
plot_cfar_window_teaching_local(jointOut, cfg);
if jointOut.targets.count > 0
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

% 左侧大图叠加 raw CFAR 检测点和最终选中的单目标点。
nexttile([2 1]);
imagesc(jointOut.rAxis, jointOut.vAxis, rdMapDb);
axis xy;
colorbar;
clim([-40 0]);
hold on;
hLegend = gobjects(0);
legendText = {};
if jointOut.cfarRaw.count > 0
    hRaw = plot(jointOut.cfarRaw.range, jointOut.cfarRaw.velocity, 'k.', 'MarkerSize', 6);
    hLegend(end + 1) = hRaw;
    legendText{end + 1} = '原始 CFAR';
end
if jointOut.targets.count > 0
    hFinal = plot(jointOut.finalDetection.range, jointOut.finalDetection.velocity, 'rx', 'MarkerSize', 10, 'LineWidth', 1.4);
    hLegend(end + 1) = hFinal;
    legendText{end + 1} = '最终目标';
end
hTruthRange = xline(mean(truth.RpSeq), ':w', 'LineWidth', 0.8);
hLegend(end + 1) = hTruthRange;
legendText{end + 1} = '真值距离';
hTruthVelocity = yline(cfg.tgt.v, ':w', 'LineWidth', 0.8);
hLegend(end + 1) = hTruthVelocity;
legendText{end + 1} = '真值速度';
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title(sprintf('中心波束 RD 图，中心角度为 (%.2f, %.2f) deg', ...
    jointOut.selection.coarseCenterAz, jointOut.selection.coarseCenterEl));
legend(hLegend, legendText, 'Location', 'northeastoutside');

% 右上图固定在最终目标速度单元，观察距离切片及 CFAR 门限。
nexttile;
if jointOut.targets.count == 0
    axis off;
    text(0.0, 0.5, '中心束 CFAR 未检出最终目标', 'Interpreter', 'none');
else
    rangeCutAmp = squeeze(abs(jointOut.local.rdCube(2, :, jointOut.finalDetection.dopplerIdx)));
    if strcmpi(cfg.cfar.detectorType, 'Square')
        rangeCut = rangeCutAmp .^ 2;
        dbScale = 10;
        yText = '相对功率 (dB)';
    else
        rangeCut = rangeCutAmp;
        dbScale = 20;
        yText = '相对幅度 (dB)';
    end
    rangeRef = max(rangeCut);
    thresholdCut = jointOut.cfarRaw.thresholdMap(jointOut.finalDetection.dopplerIdx, :);
    rangeCutDb = dbScale * log10(rangeCut / rangeRef + eps);
    thresholdCutDb = dbScale * log10(thresholdCut / rangeRef + eps);
    plot(jointOut.rAxis, rangeCutDb, 'LineWidth', 1.2);
    hold on;
    plot(jointOut.rAxis, thresholdCutDb, '--', 'LineWidth', 1.1);
    xline(cfg.tgt.R0, ':k', 'LineWidth', 0.8);
    xline(jointOut.finalDetection.range, '--r', 'LineWidth', 1.0);
    grid on;
    xlabel('距离 (m)');
    ylabel(yText);
    title(sprintf('速度 %.2f m/s 处的距离切片与门限', jointOut.finalDetection.velocity));
    legend('检测量', 'CFAR 门限', '真值距离', '最终距离', 'Location', 'best');
end

% 右下图固定在最终目标距离单元，观察多普勒切片。
nexttile;
if jointOut.targets.count == 0
    axis off;
    text(0.0, 0.5, '中心束 CFAR 未检出最终目标', 'Interpreter', 'none');
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

function plot_signal_chain_figure_local(sTx, echoCube, pcCube, jointOut, truth, cfg)
txMag = abs(sTx);
txRef = max(txMag);
if txRef <= 0
    txRef = 1;
end
txMagDb = 20 * log10(txMag / txRef + eps);

echoAxis = truth.rAxis;
pcAxis = jointOut.rAxis;
echoRaw = abs(squeeze(echoCube(1, :, 1)));
pcRaw = abs(squeeze(pcCube(1, :, 1)));

if jointOut.targets.count > 0
    rangeIdxFocus = jointOut.finalDetection.rangeIdx;
else
    [~, rangeIdxFocus] = min(abs(jointOut.rAxis - cfg.tgt.R0));
end

slowTimeMs = cfg.wf.tSlow * 1e3;
slowSeq = squeeze(jointOut.local.beamCube(2, rangeIdxFocus, :));
slowMag = abs(slowSeq);
slowPhase = unwrap(angle(slowSeq));
slowPhaseDeg = slowPhase * 180 / pi;

rdAtRange = squeeze(abs(jointOut.local.rdCube(2, rangeIdxFocus, :)));
rdAtRangeDb = 20 * log10(rdAtRange / max(rdAtRange) + eps);

figure('Name', '第 5 步信号链教学图', 'Position', fit_figure_position_local([80, 40, 1180, 760]));
tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(cfg.wf.tTx * 1e6, real(sTx), 'LineWidth', 1.0);
hold on;
plot(cfg.wf.tTx * 1e6, txMagDb, '--', 'LineWidth', 1.1);
grid on;
xlabel('发射快时间 (\mus)');
ylabel('实部 / 包络(dB)');
title('发射 LFM 波形');
legend('real(sTx)', '|sTx| (dB)', 'Location', 'best');

nexttile;
plot(echoAxis, echoRaw, 'LineWidth', 1.1);
hold on;
xline(cfg.tgt.R0 - cfg.arr.c * cfg.wf.Tp / 4, ':', 'LineWidth', 0.8);
xline(cfg.tgt.R0 + cfg.arr.c * cfg.wf.Tp / 4, ':', 'LineWidth', 0.8);
xline(cfg.tgt.R0, '--r', 'LineWidth', 1.0);
grid on;
xlabel('回波快时间对应距离 (m)');
ylabel('|echo(阵元1, 脉冲1)|');
title('脉压前单阵元单脉冲回波包络');
legend('原始回波', '脉冲包络边界', '', '目标真值', 'Location', 'best');

nexttile;
plot(pcAxis, pcRaw / max(pcRaw + eps), 'LineWidth', 1.1);
hold on;
xline(cfg.tgt.R0, '--r', 'LineWidth', 1.0);
xline(pcAxis(rangeIdxFocus), ':k', 'LineWidth', 0.9);
grid on;
xlabel('距离 (m)');
ylabel('归一化幅度');
title('脉压后单阵元距离像');
legend('脉压输出', '目标真值', '当前分析距离单元', 'Location', 'best');

nexttile;
yyaxis left;
stem(slowTimeMs, slowMag / max(slowMag + eps), 'filled', 'LineWidth', 0.8, 'MarkerSize', 3);
ylabel('归一化幅度');
yyaxis right;
plot(slowTimeMs, slowPhaseDeg, '-o', 'LineWidth', 0.9, 'MarkerSize', 3);
ylabel('相位 (deg)');
grid on;
xlabel('慢时间 / 脉冲序号对应时刻 (ms)');
title(sprintf('中心束在距离 %.2f m 处的慢时间序列', pcAxis(rangeIdxFocus)));
legend('幅度', '相位', 'Location', 'best');

nexttile;
hMtd = plot(jointOut.vAxis, rdAtRangeDb, 'LineWidth', 1.2);
hold on;
hTruthVelocity = xline(cfg.tgt.v, '--r', 'LineWidth', 1.0);
hLegend = [hMtd, hTruthVelocity];
legendText = {'MTD 输出', '目标真值速度'};
if jointOut.targets.count > 0
    hFinalVelocity = xline(jointOut.finalDetection.velocity, ':k', 'LineWidth', 0.9);
    hLegend(end + 1) = hFinalVelocity;
    legendText{end + 1} = '最终检测速度';
end
grid on;
xlabel('速度 (m/s)');
ylabel('相对响应 (dB)');
title(sprintf('距离 %.2f m 处的 MTD 频谱', pcAxis(rangeIdxFocus)));
legend(hLegend, legendText, 'Location', 'best');

nexttile;
axis off;
text(0.0, 0.92, '当前链路关键参数', 'FontWeight', 'bold', 'FontSize', 11);
text(0.0, 0.76, sprintf('MTD 窗函数: %s', jointOut.mtd.winType), 'Interpreter', 'none');
text(0.0, 0.62, sprintf('CFAR 类型: %s-%s', cfg.cfar.method, cfg.cfar.detectorType), 'Interpreter', 'none');
text(0.0, 0.48, sprintf('Protect = %d, Reference(each side) = %d', ...
    cfg.cfar.protectCell, cfg.cfar.referenceCell), 'Interpreter', 'none');
text(0.0, 0.34, sprintf('Pfa = %.3e', cfg.cfar.falseAlarmRate), 'Interpreter', 'none');
text(0.0, 0.20, sprintf('目标真值 = (R %.2f m, v %.2f m/s)', cfg.tgt.R0, cfg.tgt.v), 'Interpreter', 'none');
if jointOut.targets.count > 0
    text(0.0, 0.06, sprintf('最终单元 = (rangeIdx %d, dopplerIdx %d)', ...
        jointOut.finalDetection.rangeIdx, jointOut.finalDetection.dopplerIdx), 'Interpreter', 'none');
end
end

function plot_cfar_window_teaching_local(jointOut, cfg)
if jointOut.targets.count > 0
    rangeIdxCut = jointOut.finalDetection.rangeIdx;
    doppIdxCut = jointOut.finalDetection.dopplerIdx;
else
    [~, rangeIdxCut] = min(abs(jointOut.rAxis - cfg.tgt.R0));
    [~, doppIdxCut] = min(abs(jointOut.vAxis - cfg.tgt.v));
end

protectCell = cfg.cfar.protectCell;
referenceCell = cfg.cfar.referenceCell;
detectorType = cfg.cfar.detectorType;

rangeCutAmp = squeeze(abs(jointOut.local.rdCube(2, :, doppIdxCut)));
if strcmpi(detectorType, 'Square')
    metricCut = rangeCutAmp .^ 2;
    dbScale = 10;
    yLabelText = '检测量 / 门限 (dB)';
else
    metricCut = rangeCutAmp;
    dbScale = 20;
    yLabelText = '检测量 / 门限 (dB)';
end

thresholdCut = jointOut.cfarRaw.thresholdMap(doppIdxCut, :).';
metricRef = max(metricCut);
if metricRef <= 0
    metricRef = 1;
end
metricCutDb = dbScale * log10(metricCut / metricRef + eps);
thresholdCutDb = dbScale * log10(thresholdCut / metricRef + eps);

leftTrainIdx = max(1, rangeIdxCut - protectCell - referenceCell):max(0, rangeIdxCut - protectCell - 1);
leftGuardIdx = max(1, rangeIdxCut - protectCell):max(0, rangeIdxCut - 1);
rightGuardIdx = min(numel(jointOut.rAxis), rangeIdxCut + 1):min(numel(jointOut.rAxis), rangeIdxCut + protectCell);
rightTrainIdx = min(numel(jointOut.rAxis), rangeIdxCut + protectCell + 1):min(numel(jointOut.rAxis), rangeIdxCut + protectCell + referenceCell);

figure('Name', '第 5 步 CFAR 滑窗教学图', 'Position', fit_figure_position_local([120, 60, 1120, 760]));
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile([1 2]);
plot(jointOut.rAxis, metricCutDb, 'LineWidth', 1.2);
hold on;
plot(jointOut.rAxis, thresholdCutDb, '--', 'LineWidth', 1.1);
shade_index_group_local(jointOut.rAxis, metricCutDb, leftTrainIdx, [0.76 0.88 1.00], '参考单元');
shade_index_group_local(jointOut.rAxis, metricCutDb, leftGuardIdx, [1.00 0.90 0.72], '保护单元');
shade_index_group_local(jointOut.rAxis, metricCutDb, rangeIdxCut, [1.00 0.74 0.74], 'CUT');
shade_index_group_local(jointOut.rAxis, metricCutDb, rightGuardIdx, [1.00 0.90 0.72], '');
shade_index_group_local(jointOut.rAxis, metricCutDb, rightTrainIdx, [0.76 0.88 1.00], '');
xline(jointOut.rAxis(rangeIdxCut), '--r', 'LineWidth', 1.0);
grid on;
xlabel('距离 (m)');
ylabel(yLabelText);
title(sprintf('Doppler 行 %d (v = %.2f m/s) 上的 1D CA-CFAR 滑窗', doppIdxCut, jointOut.vAxis(doppIdxCut)));
legend('检测量', 'CFAR 门限', 'Location', 'best');

nexttile;
plot(jointOut.rAxis, metricCutDb, 'LineWidth', 1.1);
hold on;
plot(jointOut.rAxis, thresholdCutDb, '--', 'LineWidth', 1.0);
shade_index_group_local(jointOut.rAxis, metricCutDb, [leftTrainIdx, leftGuardIdx, rangeIdxCut, rightGuardIdx, rightTrainIdx], [0.92 0.92 0.92], '');
windowIdx = unique([leftTrainIdx, leftGuardIdx, rangeIdxCut, rightGuardIdx, rightTrainIdx]);
if ~isempty(windowIdx)
    xlim([jointOut.rAxis(windowIdx(1)) - 2 * mean(diff(jointOut.rAxis)), ...
        jointOut.rAxis(windowIdx(end)) + 2 * mean(diff(jointOut.rAxis))]);
end
grid on;
xlabel('距离 (m)');
ylabel(yLabelText);
title('CUT 附近局部放大');

nexttile;
axis off;
text(0.0, 0.88, 'CFAR 参数解释', 'FontWeight', 'bold', 'FontSize', 11);
text(0.0, 0.72, sprintf('CUT = rangeIdx %d, DopplerIdx %d', rangeIdxCut, doppIdxCut), 'Interpreter', 'none');
text(0.0, 0.58, sprintf('左/右保护单元数 = %d', protectCell), 'Interpreter', 'none');
text(0.0, 0.44, sprintf('左/右参考单元数 = %d', referenceCell), 'Interpreter', 'none');
text(0.0, 0.30, sprintf('Pfa = %.3e, detector = %s', cfg.cfar.falseAlarmRate, detectorType), 'Interpreter', 'none');
text(0.0, 0.16, sprintf('threshold formula: %s', jointOut.cfarRaw.thresholdInfo.formula), 'Interpreter', 'none');
if strcmp(jointOut.cfarRaw.thresholdInfo.mode, 'pfa_formula')
    text(0.0, 0.02, sprintf('alpha(one-sided/two-sided) = %.3f / %.3f', ...
        jointOut.cfarRaw.thresholdInfo.scaleOneSided, ...
        jointOut.cfarRaw.thresholdInfo.scaleTwoSided), 'Interpreter', 'none');
end
end

function shade_index_group_local(axisVals, metricDb, idxGroup, faceColor, labelText)
if isempty(idxGroup)
    return;
end

yMin = min([metricDb(:); -80]);
yMax = max([metricDb(:); 5]);
idxGroup = idxGroup(:).';
segments = split_contiguous_segments_local(idxGroup);

for iSeg = 1:numel(segments)
    idxNow = segments{iSeg};
    x0 = axisVals(max(idxNow(1), 1));
    x1 = axisVals(min(idxNow(end), numel(axisVals)));
    if numel(axisVals) >= 2
        dx = mean(diff(axisVals));
    else
        dx = 1;
    end
    patch([x0 - dx / 2, x1 + dx / 2, x1 + dx / 2, x0 - dx / 2], ...
        [yMin, yMin, yMax, yMax], faceColor, ...
        'FaceAlpha', 0.22, 'EdgeColor', 'none');
    if ~isempty(labelText) && iSeg == 1
        text((x0 + x1) / 2, yMax - 0.08 * (yMax - yMin), labelText, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', 9, 'BackgroundColor', 'w', 'Margin', 1);
    end
end
ylim([yMin, yMax]);
end

function segments = split_contiguous_segments_local(idxVals)
idxVals = unique(idxVals(:).');
if isempty(idxVals)
    segments = {};
    return;
end

splitPos = [0, find(diff(idxVals) > 1), numel(idxVals)];
segments = cell(1, numel(splitPos) - 1);
for iSeg = 1:numel(segments)
    segments{iSeg} = idxVals(splitPos(iSeg) + 1:splitPos(iSeg + 1));
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
