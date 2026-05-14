thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% 第 9 步演示（偏跟踪扩展）：
% 1. 每个 CPI 的回波仍由当前时刻真值生成；
% 2. 上一 CPI 的结果只作为下一 CPI 的波束先验；
% 3. 当前 CPI 会先在先验附近做局部粗选束，再做三波束精测角。
% 4. 当前全息凝视探测主流程仍按“每个 CPI 独立执行第 5 步”理解。
cfg = sim_cfg();

cfg.sim.addNoise = true;
cfg.sim.sigmaN = 0.05;

% 这组参数用于把“跨 CPI 先验传递 -> 局部粗选束 -> 精测角”的效果展示得更明显。
cfg.track.nCpi = 4;
cfg.track.holdPredictionOnMiss = true;
cfg.tgt.azRate = 450.0;
cfg.tgt.elRate = 0.0;
cfg.tgt.vRate = 0.0;

trackOut = run_track_loop_single_target(cfg);
summary = trackOut.summary;
showPlot = should_plot_figures_local();

fprintf('=== 第 9 步：跨 CPI 单目标局部跟踪闭环 ===\n');
fprintf('CPI 个数         = %d\n', cfg.track.nCpi);
fprintf('单 CPI 时长      = %.6f s\n', trackOut.tCpi);
fprintf('初始扇区中心     = (az %.3f deg, el %.3f deg)\n', ...
    cfg.beam.azSectorCenter, cfg.beam.elSectorCenter);
fprintf('真值起点         = (az %.3f deg, el %.3f deg, R %.3f m, v %.3f m/s)\n', ...
    cfg.tgt.az, cfg.tgt.el, cfg.tgt.R0, cfg.tgt.v);
fprintf('真值角速率       = (az %.3f deg/s, el %.3f deg/s, vRate %.3f m/s^2)\n', ...
    cfg.tgt.azRate, cfg.tgt.elRate, cfg.tgt.vRate);
fprintf('总时间跨度       = %.6f s\n', (cfg.track.nCpi - 1) * trackOut.tCpi);
fprintf('预计真值总变化   = (dAz %.3f deg, dEl %.3f deg, dV %.3f m/s)\n', ...
    cfg.tgt.azRate * (cfg.track.nCpi - 1) * trackOut.tCpi, ...
    cfg.tgt.elRate * (cfg.track.nCpi - 1) * trackOut.tCpi, ...
    cfg.tgt.vRate * (cfg.track.nCpi - 1) * trackOut.tCpi);

if ~showPlot
    fprintf('当前为批处理/无图形窗口环境，本次只打印摘要，不弹出图窗。\n');
end

fprintf('\n--- 各 CPI 摘要 ---\n');
for iCpi = 1:cfg.track.nCpi
    entry = trackOut.history(iCpi);
    fprintf(['CPI %d: 真值 = (az %.3f, el %.3f, R %.3f, v %.3f), ' ...
        '先验 = (az %.3f, el %.3f), 粗中心束 = (az %.3f, el %.3f, score %.3f), ' ...
        '过门候选数 = %d, 检测有效 = %d'], ...
        iCpi, ...
        entry.truth.az, entry.truth.el, entry.truth.range, entry.truth.velocity, ...
        summary.priorAz(iCpi), summary.priorEl(iCpi), ...
        summary.coarseCenterAz(iCpi), summary.coarseCenterEl(iCpi), summary.coarseCenterScore(iCpi), ...
        summary.associationGatePassedCount(iCpi), ...
        entry.measurement.isValid);

    if entry.measurement.isValid
        fprintf([', 精测 = (az %.3f, el %.3f, R %.3f, v %.3f), ' ...
            '状态 = (az %.3f, el %.3f, R %.3f, v %.3f), 更新来源 = %s\n'], ...
            entry.measurement.az, entry.measurement.el, ...
            entry.measurement.range, entry.measurement.velocity, ...
            entry.state.az, entry.state.el, entry.state.range, entry.state.velocity, ...
            entry.state.updateSource);
    elseif entry.state.isValid
        fprintf([', 精测 = (无), 状态 = (az %.3f, el %.3f, R %.3f, v %.3f), ' ...
            '更新来源 = %s\n'], ...
            entry.state.az, entry.state.el, entry.state.range, entry.state.velocity, ...
            entry.state.updateSource);
    else
        fprintf(', 精测 = (无), 状态 = (无)\n');
    end
end

if showPlot
    plot_track_summary_local(summary);
end

result = struct();
result.cfg = cfg;
result.trackOut = trackOut;
result.summary = summary;
result.showPlot = showPlot;
assignin('base', 'step_09_result', result);

function plot_track_summary_local(summary)
figure('Name', '第 9 步 跨 CPI 跟踪摘要', ...
    'Position', fit_figure_position_local([100, 80, 980, 600]));
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% 当前最小闭环里，成功检测时 measurement 与 state 完全重合，
% 因此图上只保留 state，避免两条曲线叠在一起造成混乱。
nexttile;
plot_truth_and_state_panel_local(summary.cpiIndex, summary.truthRange, summary.stateRange, ...
    summary.usedPredictionHold, '距离 (m)', '距离跟踪结果');

nexttile;
plot_truth_and_state_panel_local(summary.cpiIndex, summary.truthVel, summary.stateVel, ...
    summary.usedPredictionHold, '速度 (m/s)', '速度跟踪结果');

nexttile;
plot_angle_panel_local(summary.cpiIndex, summary.truthAz, summary.priorAz, ...
    summary.coarseCenterAz, summary.stateAz, summary.usedPredictionHold, ...
    '方位角 (deg)', '方位角链路：先验 -> 粗中心束 -> 精测角');

nexttile;
plot_angle_panel_local(summary.cpiIndex, summary.truthEl, summary.priorEl, ...
    summary.coarseCenterEl, summary.stateEl, summary.usedPredictionHold, ...
    '俯仰角 (deg)', '俯仰角链路：先验 -> 粗中心束 -> 精测角');
end

function plot_truth_and_state_panel_local(cpiIndex, truthVal, stateVal, holdMask, yLabelText, titleText)
hTruth = plot(cpiIndex, truthVal, 'k-o', 'LineWidth', 1.0, 'MarkerSize', 5, ...
    'MarkerFaceColor', 'w');
hold on;
hState = plot(cpiIndex, stateVal, 'r-s', 'LineWidth', 1.4, 'MarkerSize', 6, ...
    'MarkerFaceColor', [1.00 0.88 0.88]);
if any(holdMask)
    hHold = plot(cpiIndex(holdMask), stateVal(holdMask), 'p', ...
        'Color', [0.93 0.69 0.13], 'MarkerSize', 10, 'LineWidth', 1.1, ...
        'MarkerFaceColor', [1.00 0.94 0.70]);
    legend([hTruth, hState, hHold], {'真值', '当前航迹状态', '预测保持'}, 'Location', 'best');
else
    legend([hTruth, hState], {'真值', '当前航迹状态'}, 'Location', 'best');
end
grid on;
xlabel('CPI 编号');
ylabel(yLabelText);
title(titleText);
end

function plot_angle_panel_local(cpiIndex, truthVal, priorVal, coarseVal, stateVal, holdMask, yLabelText, titleText)
hTruth = plot(cpiIndex, truthVal, 'k-o', 'LineWidth', 1.0, 'MarkerSize', 5, ...
    'MarkerFaceColor', 'w');
hold on;
hState = plot(cpiIndex, stateVal, 'r-s', 'LineWidth', 1.4, 'MarkerSize', 6, ...
    'MarkerFaceColor', [1.00 0.88 0.88]);
hPrior = plot(cpiIndex, priorVal, ':x', 'Color', [0.50 0.50 0.50], ...
    'LineWidth', 1.0, 'MarkerSize', 8);
    hCoarse = plot(cpiIndex, coarseVal, 'd-', 'Color', [0.00 0.45 0.74], 'MarkerSize', 7, ...
        'LineWidth', 1.1, 'MarkerFaceColor', [0.80 0.90 1.00]);
if any(holdMask)
    hHold = plot(cpiIndex(holdMask), stateVal(holdMask), 'p', ...
        'Color', [0.93 0.69 0.13], 'MarkerSize', 10, 'LineWidth', 1.1, ...
        'MarkerFaceColor', [1.00 0.94 0.70]);
    legend([hTruth, hState, hPrior, hCoarse, hHold], ...
        {'真值', '当前航迹状态', '上一 CPI 先验', '当前 CPI 粗中心束', '预测保持'}, ...
        'Location', 'best');
else
    legend([hTruth, hState, hPrior, hCoarse], ...
        {'真值', '当前航迹状态', '上一 CPI 先验', '当前 CPI 粗中心束'}, ...
        'Location', 'best');
end
grid on;
xlabel('CPI 编号');
ylabel(yLabelText);
title(titleText);
end

function tf = should_plot_figures_local()
tf = usejava('desktop') && usejava('awt');
try
    tf = tf && feature('ShowFigureWindows');
catch
end
end

function pos = fit_figure_position_local(posReq)
screenPos = get(groot, 'ScreenSize');
marginX = 40;
marginY = 70;
minWidth = 600;
minHeight = 420;

maxWidth = max(minWidth, screenPos(3) - 2 * marginX);
maxHeight = max(minHeight, screenPos(4) - 2 * marginY);

pos = posReq;
pos(3) = min(posReq(3), maxWidth);
pos(4) = min(posReq(4), maxHeight);
pos(1) = min(max(posReq(1), marginX), max(screenPos(3) - pos(3) - marginX, marginX));
pos(2) = min(max(posReq(2), marginY), max(screenPos(4) - pos(4) - marginY, marginY));
end
