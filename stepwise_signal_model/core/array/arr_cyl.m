function arrInfo = arr_cyl(cfg, azCtr)
%ARR_CYL 生成圆柱阵几何，以及当前方位对应的工作子阵。
% 输入:
%   cfg   - 配置结构体
%   azCtr - 当前关注的方位中心，单位为度
% 输出:
%   arrInfo - 阵列几何信息，包含全阵和工作子阵两部分

arr = cfg.arr;
beam = cfg.beam;

% 每一列在圆周上的绝对方位角。
phiCol = (0:arr.Naz - 1) / arr.Naz * 360;
% 每一层在 z 轴上的高度，保持与现有圆柱阵脚本一致，从 0 开始编号。
zRow = (0:arr.Nel - 1) * arr.dz;

% 生成全阵阵元坐标矩阵，大小均为 [Naz, Nel]。
X = zeros(arr.Naz, arr.Nel);
Y = zeros(arr.Naz, arr.Nel);
Z = zeros(arr.Naz, arr.Nel);
for iaz = 1:arr.Naz
    X(iaz, :) = arr.R * cosd(phiCol(iaz));
    Y(iaz, :) = arr.R * sind(phiCol(iaz));
    Z(iaz, :) = zRow;
end

% 以当前关注方位为中心，选出后续处理要用的工作子阵。
phiRel = wrap180_local(phiCol - azCtr);
[~, colCtr] = min(abs(phiRel));
halfSpan = (beam.subNaz - 1) / 2;
colsAct = mod((colCtr - halfSpan - 1):(colCtr + halfSpan - 1), arr.Naz) + 1;
colsAct = colsAct(:).';

XAct = X(colsAct, :);
YAct = Y(colsAct, :);
ZAct = Z(colsAct, :);
phiAct = phiCol(colsAct);
phiActRel = wrap180_local(phiAct - azCtr);

% arrInfo 按“全阵几何 + 当前工作子阵几何 + 规模统计”组织。
% 前半部分字段描述整个圆柱阵的列角度、层高和三维坐标；
% 中间部分字段给出围绕 azCtr 选中的工作子阵及其相对方位；
% 最后保留中心列编号和阵元数量，便于后续模块直接复用。
arrInfo = struct();

% 全阵的几何参考和矩阵/向量化坐标。
arrInfo.azCtr = azCtr;
arrInfo.phiCol = phiCol;
arrInfo.zRow = zRow;
arrInfo.X = X;
arrInfo.Y = Y;
arrInfo.Z = Z;
arrInfo.xVec = X(:);
arrInfo.yVec = Y(:);
arrInfo.zVec = Z(:);

% 当前工作子阵的列索引、相对方位以及对应坐标。
arrInfo.colsAct = colsAct;
arrInfo.phiAct = phiAct;
arrInfo.phiActRel = phiActRel;
arrInfo.XAct = XAct;
arrInfo.YAct = YAct;
arrInfo.ZAct = ZAct;
arrInfo.xActVec = XAct(:);
arrInfo.yActVec = YAct(:);
arrInfo.zActVec = ZAct(:);

% 与当前工作子阵相关的中心位置和规模统计。
arrInfo.colCtr = colCtr;
arrInfo.nAll = numel(arrInfo.xVec);
arrInfo.nAct = numel(arrInfo.xActVec);
end

function ang = wrap180_local(ang)
%WRAP180_LOCAL 将角度映射到 [-180, 180)。
    ang = mod(ang + 180, 360) - 180;
end
