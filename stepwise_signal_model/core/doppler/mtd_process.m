function [rdCube, info] = mtd_process(dataCube, cfg)
%MTD_PROCESS 对脉冲维做慢时间加窗和 FFT，得到距离-多普勒结果。
% 输入:
%   dataCube - 大小为 [通道(或波束), 距离单元, 脉冲] 的三维数据立方体
% 输出:
%   rdCube   - 大小为 [通道(或波束), 距离单元, 多普勒单元] 的 RD 结果
%   info     - 返回本次 MTD 使用的窗函数和多普勒/速度坐标轴

mtd = cfg.mtd;
nPulse = size(dataCube, 3);

% 先按配置选择慢时间窗。
% 这里的慢时间就是“跨脉冲”方向，也就是第 3 维。
switch lower(mtd.winType)
    case 'hann'
        slowWin = hann(nPulse);
    case 'hamming'
        slowWin = hamming(nPulse);
    case 'rect'
        slowWin = ones(nPulse, 1);
    otherwise
        error('不支持的慢时间窗类型: %s', mtd.winType);
end

slowWin = cast(slowWin(:), 'like', dataCube);

% 归一化窗函数，避免不同窗型只因整体增益不同而影响后续幅度对比。
slowWin = slowWin / norm(slowWin);

% 将慢时间窗沿第 3 维广播到整个数据立方体，对每个距离单元的脉冲序列加窗。
windowedCube = dataCube .* reshape(slowWin, 1, 1, []);

% 沿脉冲维做 FFT，并用 fftshift 将零多普勒移到频谱中心，便于观察正负速度。
rdCube = fftshift(fft(windowedCube, mtd.nfft, 3), 3);

% info 主要给后续绘图和结果解释使用:
% - slowWin: 当前采用的慢时间窗
% - fdAxis / vAxis: 多普勒频率轴与速度轴
% - nfft / winType: 本次 MTD 的配置记录
info = struct();
info.slowWin = slowWin;
info.fdAxis = mtd.fdAxis;
info.vAxis = mtd.vAxis;
info.nfft = mtd.nfft;
info.winType = mtd.winType;
end
