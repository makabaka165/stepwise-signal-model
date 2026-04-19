function out = bf_joint_2d(pcCube, cfg, truth)
%BF_JOINT_2D Joint 2D beamforming, then MTD and CFAR on the beam-domain cube.

arr = cfg.arr;
wf = cfg.wf;
beam = cfg.beam;

[nAzUse, nElUse] = size(truth.xMat);
xUse = truth.xMat(:);
yUse = truth.yMat(:);
zUse = truth.zMat(:);
[nElem, ~, nPulse] = size(pcCube);

if nElem ~= numel(xUse)
    error('pcCube element count does not match the active subarray geometry.');
end

phaseFactor = beam.spatialPhaseFactor;

azWin = make_window_local(nAzUse, beam, 'az');
elWin = make_window_local(nElUse, beam, 'el');
ampMat = azWin(:) * elWin(:).';
ampVec = ampMat(:);
ampVec = ampVec / norm(ampVec);

[azBeam, elBeam, gridInfo] = build_joint_beam_grid(cfg, truth);
nAzBeam = numel(azBeam);
nElBeam = numel(elBeam);
nBeam = nAzBeam * nElBeam;

azGrid = repelem(azBeam(:), nElBeam, 1);
elGrid = repmat(elBeam(:), nAzBeam, 1);

rAxisFull = arr.c * (wf.tFast + wf.Tp / 2) / 2;
rangeTrack = cfg.tgt.R0 + cfg.tgt.v * wf.tSlow;
rMinProc = min(rangeTrack) - cfg.proc.rangeMargin;
rMaxProc = max(rangeTrack) + cfg.proc.rangeMargin;
rangeMask = (rAxisFull >= rMinProc) & (rAxisFull <= rMaxProc);
if ~any(rangeMask)
    error('No sample falls inside the configured processing range window.');
end

pcCube = pcCube(:, rangeMask, :);
rAxis = rAxisFull(rangeMask);
nRange = size(pcCube, 2);

wFull = build_weight_matrix_local( ...
    azGrid, elGrid, xUse, yUse, zUse, arr.lambda, phaseFactor, ampVec);

beamCube = reshape( ...
    wFull' * reshape(pcCube, nElem, nRange * nPulse), ...
    nBeam, nRange, nPulse);

[rdCube, mtdInfo] = mtd_process(beamCube, cfg);
rdMag = abs(rdCube);

beamPeakMetric = squeeze(max(max(rdMag, [], 2), [], 3));
[~, peakLinIdx] = max(rdMag(:));
[idxBeamPeak, idxRangePeak, idxDoppPeak] = ind2sub(size(rdMag), peakLinIdx);

peakRdMap = squeeze(rdMag(idxBeamPeak, :, :)).';
peakRangeCut = squeeze(rdMag(idxBeamPeak, :, idxDoppPeak)).';
peakDoppCut = squeeze(rdMag(idxBeamPeak, idxRangePeak, :));

cfarRaw = detect_rd_cfar_1d(rdCube, cfg.cfar);
cfarBest = cfarRaw.best;
cfarBestRdMap = squeeze(rdMag(cfarBest.beamIdx, :, :)).';
cfarBestRangeCut = squeeze(rdMag(cfarBest.beamIdx, :, cfarBest.dopplerIdx)).';
cfarBestDoppCut = squeeze(rdMag(cfarBest.beamIdx, cfarBest.rangeIdx, :));

beamPeakMetricGrid = reshape(beamPeakMetric, nElBeam, nAzBeam).';
beamPeakMetricGridDb = 20 * log10(beamPeakMetricGrid / max(beamPeakMetricGrid(:)) + eps);
peakRdMapDb = 20 * log10(peakRdMap / max(peakRdMap(:)) + eps);
peakRangeCutDb = 20 * log10(peakRangeCut / max(peakRangeCut) + eps);
peakDoppCutDb = 20 * log10(peakDoppCut / max(peakDoppCut) + eps);

idxElPeak = mod(idxBeamPeak - 1, nElBeam) + 1;
idxAzPeak = floor((idxBeamPeak - 1) / nElBeam) + 1;

out = struct();
out.rAxis = rAxis;
out.vAxis = mtdInfo.vAxis;
out.nAzUse = nAzUse;
out.nElUse = nElUse;
out.modeName = truth.modeName;

out.azBeam = azBeam;
out.elBeam = elBeam;
out.azGrid = azGrid;
out.elGrid = elGrid;
out.dAz = gridInfo.dAz;
out.dU = gridInfo.dU;
out.gridInfo = gridInfo;
out.gridRuleName = gridInfo.ruleName;
out.beamPeakMetricGridDb = beamPeakMetricGridDb;

out.peakAz = azBeam(idxAzPeak);
out.peakEl = elBeam(idxElPeak);
out.peakRange = rAxis(idxRangePeak);
out.peakVel = mtdInfo.vAxis(idxDoppPeak);
out.peakRdMapDb = peakRdMapDb;
out.peakRangeCutDb = peakRangeCutDb;
out.peakDoppCutDb = peakDoppCutDb;

out.cfar = build_cfar_output_local( ...
    cfarRaw, cfarBestRdMap, cfarBestRangeCut, cfarBestDoppCut, ...
    azGrid, elGrid, rAxis, mtdInfo.vAxis);
end

function wFull = build_weight_matrix_local(azVec, elVec, x, y, z, lambda, phaseFactor, ampVec)
nElem = numel(x);
nBeam = numel(azVec);
wFull = complex(zeros(nElem, nBeam));
for iBeam = 1:nBeam
    aNow = steer_vec_local(azVec(iBeam), elVec(iBeam), x, y, z, lambda, phaseFactor);
    wNow = ampVec .* aNow;
    wFull(:, iBeam) = wNow / norm(wNow);
end
end

function win = make_window_local(n, beam, dimName)
if strcmpi(dimName, 'az')
    type = beam.azWinType;
    nbar = beam.azTaylorNbar;
    sll = beam.azTaylorSLL;
else
    type = beam.elWinType;
    nbar = beam.elTaylorNbar;
    sll = beam.elTaylorSLL;
end

switch lower(type)
    case 'taylor'
        win = taylorwin(n, nbar, sll);
    case 'hamming'
        win = hamming(n);
    case 'hann'
        win = hann(n);
    otherwise
        error('Unsupported window type: %s', type);
end

win = win(:);
win = win / max(abs(win));
end

function a = steer_vec_local(azDeg, elDeg, x, y, z, lambda, phaseFactor)
phase = phaseFactor * 2 * pi / lambda * ...
    (x * cosd(azDeg) * cosd(elDeg) + ...
     y * sind(azDeg) * cosd(elDeg) + ...
     z * sind(elDeg));
a = exp(1j * phase);
end

function out = build_cfar_output_local(cfarRaw, bestRdMap, bestRangeCut, bestDoppCut, azGrid, elGrid, rAxis, vAxis)
% Keep raw hits for diagnostics, but collapse the default output to one target:
% 1) strongest hit in each beam
% 2) cluster around the global strongest candidate
% 3) keep only the strongest detection in that cluster

out = struct();

rawOut = make_detection_output_local(cfarRaw, azGrid, elGrid, rAxis, vAxis);
perBeamRaw = keep_strongest_per_beam_local(cfarRaw);
perBeamOut = make_detection_output_local(perBeamRaw, azGrid, elGrid, rAxis, vAxis);

clusterRaw = cluster_around_global_best_local(perBeamRaw, elGrid);
clusterOut = make_detection_output_local(clusterRaw, azGrid, elGrid, rAxis, vAxis);

finalRaw = keep_global_best_local(clusterRaw);
finalOut = make_detection_output_local(finalRaw, azGrid, elGrid, rAxis, vAxis);

out.raw = rawOut;
out.perBeam = perBeamOut;
out.cluster = clusterOut;
out.rawCount = rawOut.count;
out.perBeamCount = perBeamOut.count;
out.clusterCount = clusterOut.count;

out.count = finalOut.count;
out.beamIdx = finalOut.beamIdx;
out.rangeIdx = finalOut.rangeIdx;
out.dopplerIdx = finalOut.dopplerIdx;
out.metric = finalOut.metric;
out.az = finalOut.az;
out.el = finalOut.el;
out.range = finalOut.range;
out.velocity = finalOut.velocity;

best = finalOut.best;
best.rdMapDb = 20 * log10(bestRdMap / max(bestRdMap(:)) + eps);
best.rangeCutDb = 20 * log10(bestRangeCut / max(bestRangeCut) + eps);
best.doppCutDb = 20 * log10(bestDoppCut / max(bestDoppCut) + eps);
out.best = best;
end

function out = make_detection_output_local(detIn, azGrid, elGrid, rAxis, vAxis)
out = struct();

if detIn.count == 0
    out.count = 0;
    out.beamIdx = zeros(0, 1);
    out.rangeIdx = zeros(0, 1);
    out.dopplerIdx = zeros(0, 1);
    out.metric = zeros(0, 1);
    out.az = zeros(0, 1);
    out.el = zeros(0, 1);
    out.range = zeros(0, 1);
    out.velocity = zeros(0, 1);
    out.best = struct();
    return;
end

out.count = detIn.count;
out.beamIdx = detIn.beamIdx;
out.rangeIdx = detIn.rangeIdx;
out.dopplerIdx = detIn.dopplerIdx;
out.metric = detIn.metric;
out.az = azGrid(detIn.beamIdx);
out.el = elGrid(detIn.beamIdx);
out.range = rAxis(detIn.rangeIdx).';
out.velocity = vAxis(detIn.dopplerIdx).';

best = detIn.best;
best.az = azGrid(best.beamIdx);
best.el = elGrid(best.beamIdx);
best.range = rAxis(best.rangeIdx);
best.velocity = vAxis(best.dopplerIdx);
out.best = best;
end

function out = keep_strongest_per_beam_local(detIn)
if detIn.count == 0
    out = make_empty_detection_local();
    return;
end

[beamUnique, ~, groupIdx] = unique(detIn.beamIdx, 'stable');
nGroup = numel(beamUnique);
pickIdx = zeros(nGroup, 1);

for iGroup = 1:nGroup
    idxNow = find(groupIdx == iGroup);
    [~, idxBestLocal] = max(detIn.metric(idxNow));
    pickIdx(iGroup) = idxNow(idxBestLocal);
end

out = slice_detection_local(detIn, pickIdx);
end

function out = cluster_around_global_best_local(detIn, elGrid)
if detIn.count == 0
    out = make_empty_detection_local();
    return;
end

nElBeam = numel(unique(elGrid));
[azIdxAll, elIdxAll] = beam_subscripts_local(detIn.beamIdx, nElBeam);
[azIdxBest, elIdxBest] = beam_subscripts_local(detIn.best.beamIdx, nElBeam);

azTol = 1;
elTol = 1;
rangeTol = 1;
doppTol = 1;

keepMask = abs(azIdxAll - azIdxBest) <= azTol ...
    & abs(elIdxAll - elIdxBest) <= elTol ...
    & abs(detIn.rangeIdx - detIn.best.rangeIdx) <= rangeTol ...
    & abs(detIn.dopplerIdx - detIn.best.dopplerIdx) <= doppTol;

out = slice_detection_local(detIn, find(keepMask));
end

function out = keep_global_best_local(detIn)
if detIn.count == 0
    out = make_empty_detection_local();
    return;
end

out = slice_detection_local(detIn, 1);
end

function out = slice_detection_local(detIn, pickIdx)
if isempty(pickIdx)
    out = make_empty_detection_local();
    return;
end

pickIdx = pickIdx(:);
out = struct();
out.beamIdx = detIn.beamIdx(pickIdx);
out.rangeIdx = detIn.rangeIdx(pickIdx);
out.dopplerIdx = detIn.dopplerIdx(pickIdx);
out.metric = detIn.metric(pickIdx);
out.count = numel(pickIdx);

[metricSorted, order] = sort(out.metric, 'descend');
out.metric = metricSorted;
out.beamIdx = out.beamIdx(order);
out.rangeIdx = out.rangeIdx(order);
out.dopplerIdx = out.dopplerIdx(order);

out.best = struct();
out.best.beamIdx = out.beamIdx(1);
out.best.rangeIdx = out.rangeIdx(1);
out.best.dopplerIdx = out.dopplerIdx(1);
out.best.metric = out.metric(1);
end

function out = make_empty_detection_local()
out = struct();
out.beamIdx = zeros(0, 1);
out.rangeIdx = zeros(0, 1);
out.dopplerIdx = zeros(0, 1);
out.metric = zeros(0, 1);
out.count = 0;
out.best = struct();
end

function [azIdx, elIdx] = beam_subscripts_local(beamIdx, nElBeam)
azIdx = floor((beamIdx - 1) / nElBeam) + 1;
elIdx = mod(beamIdx - 1, nElBeam) + 1;
end
