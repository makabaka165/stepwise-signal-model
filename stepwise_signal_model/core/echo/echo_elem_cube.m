function [echoCube, truth] = echo_elem_cube(cfg)
%ECHO_ELEM_CUBE 生成单目标阵元级多脉冲回波数据立方体。
% 输出:
%   echoCube - 阵元级回波数据，大小为 [阵元数, 快时间采样点数, 脉冲数]
%   truth    - 多脉冲真值信息，几何沿用第 1 个脉冲

wf = cfg.wf;

[echoFirst, truthFirst] = echo_elem(cfg, 1);
[nElem, nFast] = size(echoFirst);
echoCube = complex(zeros(nElem, nFast, wf.Np));
echoCube(:, :, 1) = echoFirst;

RpSeq = zeros(1, wf.Np);
tauSeq = zeros(1, wf.Np);
RpSeq(1) = truthFirst.Rp;
tauSeq(1) = truthFirst.tau;

for pIdx = 2:wf.Np
    [echoNow, truthNow] = echo_elem(cfg, pIdx);
    echoCube(:, :, pIdx) = echoNow;
    RpSeq(pIdx) = truthNow.Rp;
    tauSeq(pIdx) = truthNow.tau;
end

% 多脉冲 truth 继承第 1 个脉冲的几何与阵元级真值，
% 再补充整段 CPI 上按脉冲变化的距离/时延序列，以及理论多普勒参数。
truth = truthFirst;

% 跨脉冲变化的目标运动真值。
truth.RpSeq = RpSeq;
truth.tauSeq = tauSeq;
truth.fd = -2 * cfg.tgt.v / cfg.arr.lambda;
truth.dphiPulse = -4 * pi * cfg.tgt.v * cfg.wf.PRI / cfg.arr.lambda;
end
