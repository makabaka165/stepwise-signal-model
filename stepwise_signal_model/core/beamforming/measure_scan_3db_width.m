function info = measure_scan_3db_width(scanAxis, w, steerScan)
%MEASURE_SCAN_3DB_WIDTH 在给定扫描轴上测量 3 dB 主瓣宽度。
% scanAxis 为扫描采样轴，w 为参考波束权向量，
% steerScan 为该扫描轴上的导向矩阵。

patternLin = abs(w' * steerScan);
patternLin = patternLin / max(patternLin);
patternDb = 20 * log10(patternLin + eps);

[~, peakIdx] = max(patternDb);

% 采用“主峰两侧第一次跌破 -3 dB 前一个采样点”作为交点近似。
leftBelowIdx = find(patternDb(1:peakIdx) < -3, 1, 'last');
if isempty(leftBelowIdx)
    leftCross = scanAxis(1);
else
    leftCross = scanAxis(min(leftBelowIdx + 1, numel(scanAxis)));
end

rightBelowRelIdx = find(patternDb(peakIdx:end) < -3, 1, 'first');
if isempty(rightBelowRelIdx)
    rightCross = scanAxis(end);
else
    rightBelowIdx = peakIdx + rightBelowRelIdx - 1;
    rightCross = scanAxis(max(rightBelowIdx - 1, 1));
end

info = struct();
info.patternDb = patternDb;
info.leftCross = leftCross;
info.rightCross = rightCross;
info.bw3dB = rightCross - leftCross;
end
