function [pcMat, info] = pc_range(echoMat, sTx, cfg, useWin)
%PC_RANGE 对二维回波做距离向匹配滤波脉压。
% 输入:
%   echoMat - 脉压前二维回波矩阵，大小为 [通道数, 快时间采样点数]
%   sTx     - 发射 LFM 参考信号
%   cfg     - 仿真参数结构体
%   useWin  - 是否对匹配滤波器参考信号加窗
% 输出:
%   pcMat - 脉压后二维结果矩阵，大小与 echoMat 相同
%   info  - 脉压结果信息，包括距离轴、峰值位置和主瓣宽度

arr = cfg.arr;
wf = cfg.wf;

nRow = size(echoMat, 1);
Nf = size(echoMat, 2);
Ns = numel(sTx);

% 匹配滤波器：conj(fliplr(sRefBase))，可选 Hamming 窗。
if useWin
    % Hamming 窗并做 L2 归一化。
    win = hamming(Ns);
    win = win ./ norm(win);
    sRefBase = sTx .* win.';
    winName = 'Hamming';
else
    % 不加窗。
    sRefBase = sTx;
    winName = 'None';
end

sRef = conj(fliplr(sRefBase));

% FFT 线性卷积。
Nfft = 2 ^ nextpow2(Nf + Ns - 1);
H = fft(sRef, Nfft);

pcMat = complex(zeros(nRow, Nf));
for irow = 1:nRow
    % 每行沿快时间做匹配滤波。
    S = fft(echoMat(irow, :), Nfft);
    y = ifft(S .* H);

    % 截取有效段。
    pcMat(irow, :) = y(Ns:(Ns + Nf - 1));
end

% info 按“脉压配置 + 主峰测量结果 + 归一化剖面”组织。
% 前几项说明本次匹配滤波器怎样构造；
% 后几项给出第 1 行距离像的峰值位置、-3 dB 主瓣宽度和可直接画图的剖面数据。
info = struct();

% 脉压配置与距离轴定义。
info.rAxis = arr.c * (wf.tFast + wf.Tp / 2) / 2;
info.dR = wf.dR;
info.winName = winName;
info.winNorm = 'L2';
info.mfStyle = 'conj(fliplr(sRefBase))';

% 用第 1 行估计峰值与主瓣宽度。
prof = abs(pcMat(1, :));
[~, idxPk] = max(prof);
profN = prof / max(prof);
profDb = 20 * log10(profN + eps);

left = idxPk;
while left > 1 && profDb(left - 1) >= -3
    left = left - 1;
end

right = idxPk;
while right < numel(profDb) && profDb(right + 1) >= -3
    right = right + 1;
end

% 主峰位置、测距误差与主瓣宽度测量结果。
info.idxPk = idxPk;
info.rPk = info.rAxis(idxPk);
info.peakErr = info.rPk - cfg.tgt.R0;
info.left3dB = info.rAxis(left);
info.right3dB = info.rAxis(right);
info.bw3dB = info.right3dB - info.left3dB;

% 供外部直接分析或绘图使用的距离剖面。
info.prof = prof;
info.profDb = profDb;

end
