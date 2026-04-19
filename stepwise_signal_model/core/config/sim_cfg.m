function cfg = sim_cfg()
%SIM_CFG 分步信号模型的默认配置。

cfg = struct();

% 阵列参数。
cfg.arr = struct();
cfg.arr.fc = 10e9;
cfg.arr.c = 3e8;
cfg.arr.lambda = cfg.arr.c / cfg.arr.fc;
cfg.arr.Naz = 192;
cfg.arr.Nel = 32;
cfg.arr.R = 0.4;
cfg.arr.dz = 17e-3;
cfg.arr.dPhi = 360 / cfg.arr.Naz;

% 波形参数。
cfg.wf = struct();
cfg.wf.Tp = 1e-6;
cfg.wf.B = 20e6;
cfg.wf.Fs = 60e6;
cfg.wf.PRI = 50e-6;
cfg.wf.Np = 32;
cfg.wf.K = cfg.wf.B / cfg.wf.Tp;
cfg.wf.dR = cfg.arr.c / (2 * cfg.wf.B);
cfg.wf.Rmax = cfg.arr.c * cfg.wf.PRI / 2;
cfg.wf.tTx = (-cfg.wf.Tp / 2):(1 / cfg.wf.Fs):(cfg.wf.Tp / 2 - 1 / cfg.wf.Fs);
cfg.wf.tFast = 0:(1 / cfg.wf.Fs):(cfg.wf.PRI - 1 / cfg.wf.Fs);
cfg.wf.tSlow = (0:cfg.wf.Np - 1) * cfg.wf.PRI;

% 波束形成参数。
cfg.beam = struct();
% dAz 作为兼容字段保留，实际会在方位验证链路/二维链路中
% 按扇区中心参考束的 3 dB 主瓣宽度重新测量。
cfg.beam.dAz = 1.3130;
cfg.beam.sectorHalf = 60;
cfg.beam.subNaz = 2 * floor(cfg.beam.sectorHalf / cfg.arr.dPhi) + 1;
cfg.beam.elBeamMinDeg = -5;
cfg.beam.elBeamMaxDeg = 60;
cfg.beam.azPatternAxisDeg = -10:0.02:10;
cfg.beam.elPatternAxisDeg = -5:0.05:60;
cfg.beam.azWinType = 'taylor';
cfg.beam.azTaylorNbar = 4;
cfg.beam.azTaylorSLL = -30;
cfg.beam.elWinType = 'taylor';
cfg.beam.elTaylorNbar = 4;
cfg.beam.elTaylorSLL = -30;
% phaseFactor = 2 表示导向相位按双程传播模型构造。
cfg.beam.spatialPhaseFactor = 2;

% 单目标参数。
cfg.tgt = struct();
cfg.tgt.R0 = 3200;
cfg.tgt.v = 45;
cfg.tgt.az = 8;
cfg.tgt.el = 10;
cfg.tgt.amp = 1.0;

% 验证阶段默认将目标真值作为当前扇区中心。
% 工程阶段可在选取工作子阵/排布波束前，将这两个量替换为
% 粗扫或扇区调度模块给出的结果。
cfg.beam.azSectorCenter = cfg.tgt.az;
cfg.beam.elSectorCenter = cfg.tgt.el;

% 一维验证脚本中，另一维先固定指向扇区中心。
cfg.beam.azSteer = cfg.beam.azSectorCenter;
cfg.beam.elSteer = cfg.beam.elSectorCenter;

% 仿真控制。
cfg.sim = struct();
cfg.sim.seed = 1;
cfg.sim.addNoise = false;
cfg.sim.sigmaN = 0.0;
cfg.sim.pElem = 1;
cfg.sim.useSector = true;

% 当前二维联合链路只在目标邻近距离窗内验证，避免数据立方体过大。
cfg.proc = struct();
cfg.proc.rangeMargin = 40;

% CFAR 参数。
cfg.cfar = struct();
cfg.cfar.method = 'CA';
cfg.cfar.detectorType = 'Square';
cfg.cfar.protectCell = 2;
cfg.cfar.referenceCell = 8;
cfg.cfar.thresholdScale = 10;

% MTD 参数。
cfg.mtd = struct();
cfg.mtd.nfft = cfg.wf.Np;
cfg.mtd.winType = 'hamming';
cfg.mtd.fdAxis = ((0:cfg.mtd.nfft - 1) - floor(cfg.mtd.nfft / 2)) / (cfg.mtd.nfft * cfg.wf.PRI);
cfg.mtd.vAxis = -cfg.mtd.fdAxis * cfg.arr.lambda / 2;

end
