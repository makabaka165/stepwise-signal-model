function [sTx, tTx] = tx_lfm(wf)
%TX_LFM 生成单个复基带 LFM 发射脉冲。
% 输入:
%   wf.Tp  - 脉冲宽度，单位 s
%   wf.K   - 调频斜率，单位 Hz/s
%   wf.tTx - 脉冲内部时间轴，单位 s
% 输出:
%   sTx - 复基带 LFM 发射信号，长度与 wf.tTx 一致
%   tTx - 返回的发射脉冲内部时间轴

% 单个发射脉冲的内部时间轴。
tTx = wf.tTx;

% 有限时宽门控 × LFM 二次相位。
sTx = (abs(tTx) <= wf.Tp / 2) .* exp(1j * pi * wf.K * tTx .^ 2);

end
