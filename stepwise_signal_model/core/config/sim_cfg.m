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
cfg.beam.nBeamPerDim = 3;
cfg.beam.fineRatioLutPoints = 201;
cfg.beam.fineRatioEps = 1e-12;

% 单目标参数。
cfg.tgt = struct();
cfg.tgt.R0 = 3200;
cfg.tgt.v = 45;
cfg.tgt.az = 8;
cfg.tgt.el = 10;
cfg.tgt.amp = 1.0;
cfg.tgt.vRate = 0.0;
cfg.tgt.azRate = 0.0;
cfg.tgt.elRate = 0.0;

% 工作扇区中心 —— 仅用于从圆柱阵选"当前指向对应的工作子阵"。
% 它来自扫描调度/跟踪模块，是"雷达现在朝哪儿看"的系统参数，
% 和目标真值无关。验证阶段手动设为目标附近只是为了让目标落在
% 子阵视场内；工程阶段由外部模块赋值。
% 波束的实际位置不再由它决定，而是由全网格粗扫峰值决定。
cfg.beam.azSectorCenter = 8;
cfg.beam.elSectorCenter = 10;

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

% 第 8 步跨 CPI 跟踪扩展参数。
cfg.track = struct();
cfg.track.nCpi = 5;
cfg.track.holdPredictionOnMiss = true;
cfg.track.seedStep = 1;
cfg.track.storeJointOutHistory = false;
cfg.track.useAssociation = true;
cfg.track.associationFallbackToBestOnGateMiss = false;
cfg.track.coarseSearchHalfWidthAz = 1;
cfg.track.coarseSearchHalfWidthEl = 1;
cfg.track.coarseSearchUsePredictionGate = true;

% CFAR 参数。
cfg.cfar = struct();
cfg.cfar.method = 'CA';
cfg.cfar.detectorType = 'Square';
cfg.cfar.protectCell = 2;
cfg.cfar.referenceCell = 8;
% CA-CFAR 平方律检测门限:
%   alpha = Nref * (Pfa^(-1/Nref) - 1)
% thresholdScale 仅作为兼容字段保留；留空时由 falseAlarmRate 自动计算。
cfg.cfar.falseAlarmRate = 1e-8;
cfg.cfar.thresholdScale = [];
cfg.cfar.localPeakRangeHalfWidth = 1;
cfg.cfar.localPeakDoppHalfWidth = 1;
% 以下聚类/后筛选参数仅为兼容旧版第 5 步备份和第 8 步前端保留；
% 当前 step_05_joint_2d_mtd 不再使用这些字段。
cfg.cfar.clusterAzTol = 1;
cfg.cfar.clusterElTol = 1;
cfg.cfar.clusterRangeTol = 1;
cfg.cfar.clusterDoppTol = 2;
cfg.cfar.targetExtractMinClusterSize = 2;
% 目标提取先保留“count >= 2 且 metricSum >= Tsum”这条主规则，
% 但将 Tsum 从单目标手调常数改为“绝对下限 + 背景簇自适应门限”。
cfg.cfar.targetExtractMinMetricSum = 50;
cfg.cfar.targetExtractAdaptiveMinClusterCount = 3;
cfg.cfar.targetExtractAdaptiveExcludeTopK = 1;
cfg.cfar.targetExtractAdaptiveMadScale = 8;

% MTD 参数。
cfg.mtd = struct();
cfg.mtd.nfft = cfg.wf.Np;
% 参考 cankao2：慢时间维直接做 FFT，不额外加窗。
cfg.mtd.winType = 'rect';
cfg.mtd.fdAxis = ((0:cfg.mtd.nfft - 1) - floor(cfg.mtd.nfft / 2)) / (cfg.mtd.nfft * cfg.wf.PRI);
cfg.mtd.vAxis = -cfg.mtd.fdAxis * cfg.arr.lambda / 2;
cfg.track.associationRangeGate = 2 * cfg.wf.dR;
cfg.track.associationVelocityGate = 2 * abs(cfg.mtd.vAxis(2) - cfg.mtd.vAxis(1));

end
