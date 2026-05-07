clc;
clear;
close all;

% 第6步蒙特卡洛趋势绘图脚本
% 只读取前两层汇总 CSV，不重新仿真。
% 第1层按当前结果优先使用输出端 SNR 作为横轴。
% 第2层保留热力图，并补充更直观的折线趋势图。

plotDir   = fileparts(mfilename('fullpath'));
rootDir   = fileparts(plotDir);
layer1Dir = fullfile(rootDir, 'layer_1_snr');
layer2Dir = fullfile(rootDir, 'layer_2_angle_offset');

T1 = readtable(fullfile(layer1Dir, 'snr_monte_carlo_summary.csv'));
T2 = readtable(fullfile(layer2Dir, 'angle_offset_monte_carlo_summary.csv'));

if ismember('snrOutDb', T1.Properties.VariableNames)
    snrAxis  = T1.snrOutDb;
    snrLabel = '输出 SNR / dB';
    figTitle = '第1层：测角误差随输出端 SNR 变化';
else
    snrAxis  = T1.snrDb;
    snrLabel = '输入信噪比 / dB';
    figTitle = '第1层：测角误差随输入信噪比变化';
end

% 第1层：SNR 扫描下的方位/俯仰 RMSE 趋势
fig1 = figure('Name', '第1层 SNR-RMSE 趋势', 'Position', [100, 100, 760, 420]);
plot(snrAxis, T1.azRmseDeg, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(snrAxis, T1.elRmseDeg, '-s', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on;
xlabel(snrLabel);
ylabel('RMSE / deg');
legend('方位 RMSE', '俯仰 RMSE', 'Location', 'best');
title(figTitle);
saveas(fig1, fullfile(layer1Dir, 'snr_rmse_trend.png'));

% 第2层：方位/俯仰 RMSE 热力图
fig2 = plot_heatmap_local(T2.azOffsetDeg, T2.uOffset, T2.azRmseDeg, ...
    '第2层：方位 RMSE 热力图', '方位偏移 / deg', '俯仰 u 偏移', '方位 RMSE / deg');
saveas(fig2, fullfile(layer2Dir, 'angle_offset_az_rmse.png'));

fig3 = plot_heatmap_local(T2.azOffsetDeg, T2.uOffset, T2.elRmseDeg, ...
    '第2层：俯仰 RMSE 热力图', '方位偏移 / deg', '俯仰 u 偏移', '俯仰 RMSE / deg');
saveas(fig3, fullfile(layer2Dir, 'angle_offset_el_rmse.png'));

% 第2层：更直观的趋势折线图
fig4 = plot_grouped_lines_local(T2.azOffsetDeg, T2.uOffset, T2.azRmseDeg, ...
    '第2层：方位 RMSE 随方位偏移变化', '方位偏移 / deg', '方位 RMSE / deg', ...
    'u偏移 = %.5f');
saveas(fig4, fullfile(layer2Dir, 'angle_offset_az_trend_by_u.png'));

fig5 = plot_grouped_lines_local(T2.uOffset, T2.azOffsetDeg, T2.elRmseDeg, ...
    '第2层：俯仰 RMSE 随 u 偏移变化', '俯仰 u 偏移', '俯仰 RMSE / deg', ...
    '方位偏移 = %.2f deg');
saveas(fig5, fullfile(layer2Dir, 'angle_offset_el_trend_by_az.png'));


function figHandle = plot_heatmap_local(x, y, z, figName, xLabelText, yLabelText, colorbarText)
% 把三列离散数据整理成二维网格，然后绘制热力图。
xVals = unique(x(:).');
yVals = unique(y(:).');
Z     = zeros(numel(yVals), numel(xVals));

for i = 1:numel(z)
    ix = find(abs(xVals - x(i)) < 1e-12, 1);
    iy = find(abs(yVals - y(i)) < 1e-12, 1);
    Z(iy, ix) = z(i);
end

figHandle = figure('Name', figName, 'Position', [120, 120, 680, 520]);
imagesc(xVals, yVals, Z);
set(gca, 'YDir', 'normal');
grid on;
cb              = colorbar;
cb.Label.String = colorbarText;
xlabel(xLabelText);
ylabel(yLabelText);
title(figName);
end


function figHandle = plot_grouped_lines_local(x, group, z, figName, xLabelText, yLabelText, legendFmt)
% 固定一组参数，观察另一组参数变化时的趋势。
groupVals = unique(group(:).');
colors    = lines(numel(groupVals));

figHandle = figure('Name', figName, 'Position', [140, 140, 760, 420]);
hold on;

for iGroup = 1:numel(groupVals)
    mask   = abs(group - groupVals(iGroup)) < 1e-12;
    xGroup = x(mask);
    zGroup = z(mask);
    [xSort, order] = sort(xGroup);
    zSort = zGroup(order);

    plot(xSort, zSort, '-o', ...
        'LineWidth', 1.5, ...
        'MarkerSize', 7, ...
        'Color', colors(iGroup, :), ...
        'DisplayName', sprintf(legendFmt, groupVals(iGroup)));
end

grid on;
xlabel(xLabelText);
ylabel(yLabelText);
title(figName);
legend('Location', 'best');
end
