thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% Step 5 stability test.
% Keep the main processing chain unchanged and only prototype
% the secondary-cluster suppression inside this standalone script.
cfgBase = sim_cfg();
cfgBase.sim.addNoise = true;
cfgBase.sim.sigmaN = 0.05;

seedList = 1:10;
nSeed = numel(seedList);
rBin = cfgBase.wf.dR;
vBin = abs(cfgBase.mtd.vAxis(2) - cfgBase.mtd.vAxis(1));

protoCfg = struct();
protoCfg.rangeIdxTol = 1;
protoCfg.doppOffsetMax = 4;
protoCfg.metricSumRatioMax = 1e-3;
protoCfg.bestMetricRatioMax = 1e-3;

results = repmat(struct( ...
    'seed', NaN, ...
    'rawCount', NaN, ...
    'clusterCount', NaN, ...
    'candidateCount', NaN, ...
    'targetCount', NaN, ...
    'targetCountProto', NaN, ...
    'suppressedCountProto', NaN, ...
    'metricThreshold', NaN, ...
    'tabs', NaN, ...
    'tbg', NaN, ...
    'bestRange', NaN, ...
    'bestVel', NaN, ...
    'bestAz', NaN, ...
    'bestEl', NaN, ...
    'rangeErr', NaN, ...
    'velErr', NaN, ...
    'azErr', NaN, ...
    'elErr', NaN, ...
    'hasAzFallback', false, ...
    'hasElFallback', false, ...
    'passSingleTarget', false, ...
    'passProtoSingleTarget', false, ...
    'passNoFallback', false, ...
    'passProtoNoFallback', false), nSeed, 1);

fprintf('=== 第 5 步稳定性测试：随机种子扫描 ===\n');
fprintf('测试设置：sigmaN = %.3f, seed = [%d:%d], 不绘图，仅跑核心链路\n', ...
    cfgBase.sim.sigmaN, seedList(1), seedList(end));
fprintf('距离分辨率 dR = %.3f m, 速度栅格间隔 dV = %.3f m/s\n', rBin, vBin);
fprintf(['原型抑制规则：rangeTol = %d bin, doppOffsetMax = %d bin, ' ...
    'metricSumRatio <= %.1e, bestMetricRatio <= %.1e\n\n'], ...
    protoCfg.rangeIdxTol, protoCfg.doppOffsetMax, ...
    protoCfg.metricSumRatioMax, protoCfg.bestMetricRatioMax);

for iSeed = 1:nSeed
    cfg = cfgBase;
    cfg.sim.seed = seedList(iSeed);
    rng(cfg.sim.seed);

    [sTx, ~] = tx_lfm(cfg.wf);
    [echoCube, ~] = echo_elem_cube(cfg);
    [pcCube, ~] = pc_range_cube(echoCube, sTx, cfg, true);
    jointOut = bf_joint_2d_step5(pcCube, cfg);
    protoOut = apply_secondary_cluster_suppression_local(jointOut, protoCfg);

    results(iSeed).seed = cfg.sim.seed;
    results(iSeed).rawCount = jointOut.cfarRaw.count;
    results(iSeed).clusterCount = numel(jointOut.clustersRaw);
    results(iSeed).candidateCount = jointOut.candidateTargets.count;
    results(iSeed).targetCount = jointOut.targets.count;
    results(iSeed).targetCountProto = protoOut.targetCount;
    results(iSeed).suppressedCountProto = protoOut.suppressedCount;
    results(iSeed).metricThreshold = jointOut.targetExtractInfo.metricSumFinalThreshold;
    results(iSeed).tabs = jointOut.targetExtractInfo.metricSumAbsThreshold;
    results(iSeed).tbg = jointOut.targetExtractInfo.metricSumAdaptiveThreshold;

    if jointOut.targets.count > 0
        results(iSeed).bestRange = jointOut.bestRange;
        results(iSeed).bestVel = jointOut.bestVel;
        results(iSeed).bestAz = jointOut.bestAz;
        results(iSeed).bestEl = jointOut.bestEl;
        results(iSeed).rangeErr = jointOut.bestRange - cfg.tgt.R0;
        results(iSeed).velErr = jointOut.bestVel - cfg.tgt.v;
        results(iSeed).azErr = jointOut.bestAz - cfg.tgt.az;
        results(iSeed).elErr = jointOut.bestEl - cfg.tgt.el;
        results(iSeed).hasAzFallback = ~isempty(jointOut.fine.azFallbackReason);
        results(iSeed).hasElFallback = ~isempty(jointOut.fine.elFallbackReason);
    end

    results(iSeed).passSingleTarget = jointOut.targets.count == 1;
    results(iSeed).passProtoSingleTarget = protoOut.targetCount == 1;
    results(iSeed).passNoFallback = results(iSeed).passSingleTarget ...
        && ~results(iSeed).hasAzFallback && ~results(iSeed).hasElFallback ...
        && isfinite(results(iSeed).bestAz) && isfinite(results(iSeed).bestEl);
    results(iSeed).passProtoNoFallback = results(iSeed).passProtoSingleTarget ...
        && ~results(iSeed).hasAzFallback && ~results(iSeed).hasElFallback ...
        && isfinite(results(iSeed).bestAz) && isfinite(results(iSeed).bestEl);

    fprintf(['Seed %2d: raw=%2d, cluster=%2d, cand=%2d, keep=%d -> %d, ' ...
        'Tsum=%.3f, R=%.3f, v=%.3f, az=%.3f, el=%.3f, ' ...
        'dR=%+.3f, dV=%+.3f, dAz=%+.3f, dEl=%+.3f, fallback=(%d,%d)\n'], ...
        results(iSeed).seed, ...
        results(iSeed).rawCount, ...
        results(iSeed).clusterCount, ...
        results(iSeed).candidateCount, ...
        results(iSeed).targetCount, ...
        results(iSeed).targetCountProto, ...
        results(iSeed).metricThreshold, ...
        results(iSeed).bestRange, ...
        results(iSeed).bestVel, ...
        results(iSeed).bestAz, ...
        results(iSeed).bestEl, ...
        results(iSeed).rangeErr, ...
        results(iSeed).velErr, ...
        results(iSeed).azErr, ...
        results(iSeed).elErr, ...
        results(iSeed).hasAzFallback, ...
        results(iSeed).hasElFallback);

    if protoOut.suppressedCount > 0
        for iMsg = 1:numel(protoOut.suppressedSummaries)
            fprintf('          proto suppress: %s\n', protoOut.suppressedSummaries{iMsg});
        end
    end
end

targetCountVec = [results.targetCount];
targetCountProtoVec = [results.targetCountProto];
passSingleVec = [results.passSingleTarget];
passProtoSingleVec = [results.passProtoSingleTarget];
passNoFallbackVec = [results.passNoFallback];
passProtoNoFallbackVec = [results.passProtoNoFallback];
rangeErrVec = abs([results.rangeErr]);
velErrVec = abs([results.velErr]);
azErrVec = abs([results.azErr]);
elErrVec = abs([results.elErr]);

fprintf('\n=== 汇总 ===\n');
fprintf('原始规则下保留 1 个目标 = %d / %d\n', sum(passSingleVec), nSeed);
fprintf('原型抑制后保留 1 个目标 = %d / %d\n', sum(passProtoSingleVec), nSeed);
fprintf('原始规则下且无回退     = %d / %d\n', sum(passNoFallbackVec), nSeed);
fprintf('原型抑制后且无回退     = %d / %d\n', sum(passProtoNoFallbackVec), nSeed);
fprintf('原始目标数范围         = [%d, %d]\n', min(targetCountVec), max(targetCountVec));
fprintf('原型后目标数范围       = [%d, %d]\n', min(targetCountProtoVec), max(targetCountProtoVec));
fprintf('绝对距离误差最大值     = %.3f m\n', max(rangeErrVec));
fprintf('绝对速度误差最大值     = %.3f m/s\n', max(velErrVec));
fprintf('绝对方位误差最大值     = %.3f deg\n', max(azErrVec));
fprintf('绝对俯仰误差最大值     = %.3f deg\n', max(elErrVec));

resultSummary = struct();
resultSummary.cfg = cfgBase;
resultSummary.seedList = seedList;
resultSummary.results = results;
resultSummary.singleTargetOkCount = sum(passSingleVec);
resultSummary.prototypeSingleTargetOkCount = sum(passProtoSingleVec);
resultSummary.noFallbackOkCount = sum(passNoFallbackVec);
resultSummary.prototypeNoFallbackOkCount = sum(passProtoNoFallbackVec);
resultSummary.maxAbsRangeErr = max(rangeErrVec);
resultSummary.maxAbsVelErr = max(velErrVec);
resultSummary.maxAbsAzErr = max(azErrVec);
resultSummary.maxAbsElErr = max(elErrVec);
resultSummary.prototypeCfg = protoCfg;

assignin('base', 'step_05_seed_stability_result', resultSummary);

function protoOut = apply_secondary_cluster_suppression_local(jointOut, protoCfg)
protoOut = struct();
protoOut.keepMask = true(jointOut.targets.count, 1);
protoOut.targetCount = jointOut.targets.count;
protoOut.suppressedCount = 0;
protoOut.suppressedSummaries = {};

if jointOut.targets.count <= 1
    return;
end

mainTargetIdx = 1;
mainCluster = jointOut.clusters(mainTargetIdx);

for iTgt = 2:jointOut.targets.count
    clusterNow = jointOut.clusters(iTgt);
    rangeGap = abs(jointOut.targets.rangeIdx(iTgt) - jointOut.targets.rangeIdx(mainTargetIdx));
    doppGap = abs(jointOut.targets.dopplerIdx(iTgt) - jointOut.targets.dopplerIdx(mainTargetIdx));
    metricSumRatio = clusterNow.metricSum / max(mainCluster.metricSum, eps);
    bestMetricRatio = clusterNow.bestMetric / max(mainCluster.bestMetric, eps);

    isSameRange = rangeGap <= protoCfg.rangeIdxTol;
    isNearMainDopp = doppGap <= protoCfg.doppOffsetMax;
    isWeakEnergy = metricSumRatio <= protoCfg.metricSumRatioMax;
    isWeakPeak = bestMetricRatio <= protoCfg.bestMetricRatioMax;

    if isSameRange && isNearMainDopp && isWeakEnergy && isWeakPeak
        protoOut.keepMask(iTgt) = false;
        protoOut.suppressedSummaries{end + 1, 1} = sprintf([ ...
            'target %d suppressed: rangeGap=%d, doppGap=%d, ' ...
            'metricSumRatio=%.3e, bestMetricRatio=%.3e'], ...
            iTgt, rangeGap, doppGap, metricSumRatio, bestMetricRatio);
    end
end

protoOut.targetCount = sum(protoOut.keepMask);
protoOut.suppressedCount = jointOut.targets.count - protoOut.targetCount;
end
