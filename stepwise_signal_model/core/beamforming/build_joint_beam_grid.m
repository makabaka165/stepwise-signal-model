function [azBeam, elBeam, info] = build_joint_beam_grid(cfg, truth)
%BUILD_JOINT_BEAM_GRID 基于统一的一维网格构造规则生成二维联合波束网格。
% 输出:
%   azBeam - 方位波束中心序列
%   elBeam - 俯仰波束中心序列
%   info   - 当前第 5 步真正用到的二维网格信息

beam = cfg.beam;

azCenter = beam.azSectorCenter;
elCenter = beam.elSectorCenter;

% 二维网格并不是单独重新设计一套规则，
% 而是分别复用方位和俯仰的一维网格构造结果。
azGrid = build_sector_beam_grid('azimuth', cfg, truth, azCenter, elCenter);
elGrid = build_sector_beam_grid('elevation', cfg, truth, azCenter, elCenter);

azBeam = azGrid.beam;
elBeam = elGrid.beam;

% 当前第 5 步 demo 复用第 3/4 步的一维网格规则：
% 先测参考波束宽度，再从各自扫描边界的左侧起按固定间隔排布。
info = struct();
info.dAz = azGrid.spacing;
info.dU = elGrid.spacing;
info.azMin = azGrid.minVal;
info.azMax = azGrid.maxVal;
info.elMin = elGrid.minVal;
info.elMax = elGrid.maxVal;
info.uMin = elGrid.uMin;
info.uMax = elGrid.uMax;
info.azFirst = azBeam(1);
info.azLast = azBeam(end);
info.elFirst = elBeam(1);
info.elLast = elBeam(end);
info.ruleName = '方位和俯仰两个维度都从各自扇区左边界起按固定间隔排布';
end
