function out = detect_rd_cfar_1d(rdCube, cfarCfg)
%DETECT_RD_CFAR_1D 对每个二维波束的 RD 图沿距离维做 1D CA-CFAR。
% 说明:
%   rdCube 的维度约定为 [beam, range, doppler]。
%   进入 FuncCFARBase.CFAR01 前，会先转成 [doppler, range]，
%   然后对每一条多普勒切片沿距离方向做滑窗检测。
% 当前验证流程默认“整体上能检测到目标”，因此这里只保留主路径代码。

funcCfar = FuncCFARBase;
nBeam = size(rdCube, 1);
thresholdParam = make_threshold_parameter_local(cfarCfg);

beamIdxCell = cell(nBeam, 1);
rangeIdxCell = cell(nBeam, 1);
doppIdxCell = cell(nBeam, 1);
metricCell = cell(nBeam, 1);
normMapCell = cell(nBeam, 1);
thresholdMapCell = cell(nBeam, 1);
thresholdScaleMapCell = cell(nBeam, 1);

bestMetric = -inf;
best = struct();

for iBeam = 1:nBeam
    % 取出当前波束的 RD 图，并整理成 [doppler, range] 供 CFAR 处理。
    rdMap = squeeze(rdCube(iBeam, :, :)).';

    % detList 为 3 x N:
    % 第 1 行: 距离单元索引
    % 第 2 行: 多普勒单元索引
    % 第 3 行: 检测度量值(用于后续选“最佳检测”)
    [detList, normMap, thresholdMap, thresholdScaleMap] = funcCfar.CFAR01( ...
        rdMap, ...
        thresholdParam, ...
        cfarCfg.protectCell, ...
        cfarCfg.referenceCell, ...
        cfarCfg.method, ...
        cfarCfg.detectorType);
    normMapCell{iBeam} = normMap;
    thresholdMapCell{iBeam} = thresholdMap;
    thresholdScaleMapCell{iBeam} = thresholdScaleMap;

    if isempty(detList)
        continue;
    end

    % 当前函数只保留后续真正会用到的索引和检测度量。
    nDet = size(detList, 2);
    beamIdxNow = iBeam * ones(nDet, 1);
    rangeIdxNow = detList(1, :).';
    doppIdxNow = detList(2, :).';
    metricNow = detList(3, :).';

    beamIdxCell{iBeam} = beamIdxNow;
    rangeIdxCell{iBeam} = rangeIdxNow;
    doppIdxCell{iBeam} = doppIdxNow;
    metricCell{iBeam} = metricNow;

    % “最佳检测”按 metric 最大来定义。
    [metricBeamBest, idxBeamBest] = max(metricNow);
    if metricBeamBest > bestMetric
        bestMetric = metricBeamBest;
        best.beamIdx = beamIdxNow(idxBeamBest);
        best.rangeIdx = rangeIdxNow(idxBeamBest);
        best.dopplerIdx = doppIdxNow(idxBeamBest);
        best.metric = metricBeamBest;
    end
end

out = struct();
out.beamIdx = concat_column_cells_local(beamIdxCell);
out.rangeIdx = concat_column_cells_local(rangeIdxCell);
out.dopplerIdx = concat_column_cells_local(doppIdxCell);
out.metric = concat_column_cells_local(metricCell);
out.count = numel(out.metric);

% 将所有检测按 metric 从大到小排序，便于后续直接取最强检测。
[metricSorted, order] = sort(out.metric, 'descend');
out.metric = metricSorted;
out.beamIdx = out.beamIdx(order);
out.rangeIdx = out.rangeIdx(order);
out.dopplerIdx = out.dopplerIdx(order);
out.best = best;
out.thresholdInfo = make_threshold_info_local(cfarCfg, thresholdParam);
out.normalizedMapByBeam = normMapCell;
out.thresholdMapByBeam = thresholdMapCell;
out.thresholdScaleMapByBeam = thresholdScaleMapCell;
if nBeam == 1
    out.normalizedMap = normMapCell{1};
    out.thresholdMap = thresholdMapCell{1};
    out.thresholdScaleMap = thresholdScaleMapCell{1};
end
end

function thresholdParam = make_threshold_parameter_local(cfarCfg)
if isfield(cfarCfg, 'falseAlarmRate') && ~isempty(cfarCfg.falseAlarmRate)
    thresholdParam = struct('falseAlarmRate', cfarCfg.falseAlarmRate);
    return;
end

if isfield(cfarCfg, 'thresholdScale') && ~isempty(cfarCfg.thresholdScale)
    thresholdParam = cfarCfg.thresholdScale;
    return;
end

error('detect_rd_cfar_1d:MissingThreshold', ...
    'CFAR 配置必须提供 falseAlarmRate 或 thresholdScale。');
end

function info = make_threshold_info_local(cfarCfg, thresholdParam)
info = struct();
info.method = cfarCfg.method;
info.detectorType = cfarCfg.detectorType;
info.protectCell = cfarCfg.protectCell;
info.referenceCellEachSide = cfarCfg.referenceCell;

if isnumeric(thresholdParam)
    info.mode = 'manual_scale';
    info.falseAlarmRate = NaN;
    info.formula = 'manual alpha';
    info.scaleOneSided = thresholdParam;
    info.scaleTwoSided = thresholdParam;
    return;
end

pfa = thresholdParam.falseAlarmRate;
info.mode = 'pfa_formula';
info.falseAlarmRate = pfa;
info.formula = 'alpha = Nref * (Pfa^(-1/Nref) - 1)';
info.referenceCellOneSided = cfarCfg.referenceCell;
if strcmpi(cfarCfg.method, 'CA')
    info.referenceCellTwoSided = 2 * cfarCfg.referenceCell;
else
    info.referenceCellTwoSided = cfarCfg.referenceCell;
end
info.scaleOneSided = threshold_scale_from_pfa_local(pfa, info.referenceCellOneSided);
info.scaleTwoSided = threshold_scale_from_pfa_local(pfa, info.referenceCellTwoSided);
end

function alpha = threshold_scale_from_pfa_local(pfa, nReferenceCell)
alpha = nReferenceCell * (pfa^(-1 / nReferenceCell) - 1);
end

function vec = concat_column_cells_local(cellArray)
% 将每个波束的列向量结果拼成一个总列向量。
nonEmpty = ~cellfun('isempty', cellArray);
if ~any(nonEmpty)
    vec = zeros(0, 1);
    return;
end
vec = vertcat(cellArray{nonEmpty});
end
