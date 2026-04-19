function [echoMat, truth] = echo_1ch(cfg)
%ECHO_1CH 生成单目标等效单通道 LFM 回波矩阵。
% 输入:
%   cfg - 仿真参数结构体，包含阵列、波形、目标和噪声配置
% 输出:
%   echoMat - 二维复回波矩阵，大小为 [脉冲数, 快时间采样点数]
%   truth   - 真值信息，包括距离、时延、距离轴和理论多普勒

arr = cfg.arr;
wf = cfg.wf;
tgt = cfg.tgt;
sim = cfg.sim;

% 一个 PRI 内的快时间采样点。
tFast = wf.tFast(:).';
% 一个 CPI 内各脉冲对应的慢时间时刻。
tSlow = wf.tSlow(:);
Np = numel(tSlow);
Nf = numel(tFast);

% 行对应脉冲编号，列对应快时间采样点。
echoMat = complex(zeros(Np, Nf));
% 每个脉冲对应的真实目标距离。
Rp = zeros(Np, 1);
% 每个脉冲对应的往返时延。
taup = zeros(Np, 1);

for p = 1:Np
    % 匀速目标模型: R = R0 + v * tSlow。
    Rp(p) = tgt.R0 + tgt.v * tSlow(p);

    % 单站往返时延 tau = 2R / c。
    taup(p) = 2 * Rp(p) / arr.c;

    % 当前快时间采样点相对回波中心时刻的偏移。
    dt = tFast - taup(p);

    % 延时 LFM 包络 × 传播相位。
    echoP = tgt.amp ...
        * (abs(dt) <= wf.Tp / 2) ...
        .* exp(1j * pi * wf.K * dt .^ 2) ...
        .* exp(-1j * 4 * pi * Rp(p) / arr.lambda);

    % 将第 p 个脉冲的整条快时间回波写入第 p 行。
    echoMat(p, :) = echoP;
end

if sim.addNoise
    % 按配置加入复高斯白噪声。
    noise = sim.sigmaN / sqrt(2) * (randn(Np, Nf) + 1j * randn(Np, Nf));
    echoMat = echoMat + noise;
end

% truth 只保留单通道链路最核心的运动真值，
% 包括每个脉冲的距离/时延、对应距离轴，以及理论多普勒参数。
truth = struct();
truth.Rp = Rp;
truth.taup = taup;
truth.rAxis = arr.c * tFast / 2;
truth.fd = -2 * tgt.v / arr.lambda;
truth.dphi = -4 * pi * tgt.v * wf.PRI / arr.lambda;

end
