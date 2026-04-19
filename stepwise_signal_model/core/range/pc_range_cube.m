function [pcCube, info] = pc_range_cube(echoCube, sTx, cfg, useWin)
%PC_RANGE_CUBE 对阵元级多脉冲回波逐脉冲做距离向脉压。
% 输出:
%   pcCube - 脉压结果，大小为 [阵元数, 快时间采样点数, 脉冲数]
%   info   - 距离轴与脉压配置

[nElem, nFast, nPulse] = size(echoCube);
pcCube = complex(zeros(nElem, nFast, nPulse));

for pIdx = 1:nPulse
    [pcCube(:, :, pIdx), pcInfo] = pc_range(echoCube(:, :, pIdx), sTx, cfg, useWin);
end

% info 复用单脉冲脉压的公共配置项，
% 这里只保留对整个多脉冲数据立方体都一致的距离轴和匹配滤波设置。
info = struct();
info.rAxis = pcInfo.rAxis;
info.dR = pcInfo.dR;
info.winName = pcInfo.winName;
info.winNorm = pcInfo.winNorm;
info.mfStyle = pcInfo.mfStyle;
end
