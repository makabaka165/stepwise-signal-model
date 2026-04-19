function FuncCFAR = FuncCFARBase
%FUNCCFARBASE 汇总本工程使用的 CFAR 相关函数句柄。
% 返回字段:
%   CFType       - 左右参考窗统计量的组合方式(GO/SO/CA)
%   DetectorType - 对输入数据做幅度检测或功率检测
%   CFAR01       - 输出检测点列表和归一化检测图
%   CFAR02       - 输出经过 CFAR 门限筛选后的矩阵
    FuncCFAR.CFType = @CFType;
    FuncCFAR.DetectorType = @DetectorType;
    FuncCFAR.CFAR01 = @CFAR01;
    FuncCFAR.CFAR02 = @CFAR02;
end

function NeedSum = CFType(RightSum, LeftSum, TypeCase)
%CFTYPE 根据 CFAR 类型组合左右参考窗的统计量。
% GO: 取较大值，SO: 取较小值，CA: 取两侧平均。
    switch TypeCase
        case 'GO'
            NeedSum = max(RightSum, LeftSum);
        case 'SO'
            NeedSum = min(RightSum, LeftSum);
        case 'CA'
            NeedSum = mean([RightSum, LeftSum], 2);
        otherwise
            error('不支持的 CFAR 类型: %s', TypeCase);
    end
end

function MTDModule = DetectorType(MTDModule, DeTypeCase)
%DETECTORTYPE 先把输入 RD 图转换成用于门限比较的检测量。
% 线性检测: 使用幅度 abs(x) 作为检测量
% 平方律检测: 使用功率 |x|^2 作为检测量
    switch DeTypeCase
        case 'Linear'
            MTDModule = abs(MTDModule);
        case 'Square'
            MTDModule = (abs(MTDModule)).^2;
        otherwise
            error('不支持的检测类型: %s', DeTypeCase);
    end
end

function [y1, y2] = CFAR01(CFARInput, D_Threshold, ProtectCell, ReferenCell, TypeCase, DeTypeCase)
%CFAR01 在每一行上沿列方向做 1D CFAR。
% 对当前工程的 RD 图而言，输入通常是 [doppler, range]，因此:
%   每个多普勒单元对应一行；
%   在每一行内部沿距离单元做滑窗检测。
% 输入:
%   CFARInput    - 待检测矩阵
%   D_Threshold  - 门限系数
%   ProtectCell  - 保护单元数
%   ReferenCell  - 参考单元数
%   TypeCase     - GO/SO/CA
%   DeTypeCase   - Linear/Square
% 输出:
%   y1           - 检测点列表，格式为 [距离索引; 多普勒索引; 检测度量]
%   y2           - 归一化检测图，>= 1 表示通过门限

    [~, N] = size(CFARInput);
    CFARInput = DetectorType(CFARInput, DeTypeCase);

    y1 = [];
    y2 = zeros(size(CFARInput));

    % 左边界: 只有右参考窗完整，因此只用右侧估计噪声背景。
    for jj = 1 : ReferenCell + ProtectCell
        Q = jj + ProtectCell + 1 : jj + ProtectCell + ReferenCell;
        miu = mean(CFARInput(:, Q), 2);
        y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
        temp = find(y2(:, jj) >= 1).';
        range_idx = jj * ones(1, length(temp));
        y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']];
    end

    % 中间区域: 左右参考窗都完整，可按 GO/SO/CA 组合两侧统计量。
    for jj = ReferenCell + ProtectCell + 1 : N - ReferenCell - ProtectCell
        Q1 = jj - ProtectCell - ReferenCell : jj - ProtectCell - 1;
        Q2 = jj + ProtectCell + 1 : jj + ProtectCell + ReferenCell;
        miu = CFType(mean(CFARInput(:, Q1), 2), mean(CFARInput(:, Q2), 2), TypeCase);

        y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
        temp = find(y2(:, jj) >= 1).';
        range_idx = jj * ones(1, length(temp));
        y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']];
    end

    % 右边界: 只有左参考窗完整，因此只用左侧估计噪声背景。
    for jj = N - ReferenCell - ProtectCell + 1 : N
        Q = jj - ProtectCell - ReferenCell : jj - ProtectCell - 1;
        miu = mean(CFARInput(:, Q), 2);
        y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
        temp = find(y2(:, jj) >= 1).';
        range_idx = jj * ones(1, length(temp));
        y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']];
    end
end

function EchoCfar = CFAR02(CFARInput, DFactor, ProtectCell, ReferenCell, TypeCase, DeTypeCase)
%CFAR02 在每一行上沿列方向做滑窗 CFAR，并返回筛选后的矩阵。
% 未过门限的单元置零，过门限的单元保留原检测量。
    [NumRow, Rcell] = size(CFARInput);
    CFARInput = DetectorType(CFARInput, DeTypeCase);
    EchoCfar = nan(NumRow, Rcell);
    Split = ProtectCell + ReferenCell;
    LeftDec = 0;

    % 左边界区域: 仅使用右参考窗。
    RightSum = sum(CFARInput(:, ProtectCell + 1 : ProtectCell + ReferenCell), 2);

    for Raxis = 1 : Split
        PresentCell = CFARInput(:, Raxis);
        RightDec = CFARInput(:, Raxis + ProtectCell);
        RightSum = RightSum + CFARInput(:, Raxis + ProtectCell + ReferenCell) - RightDec;

        EchoCfar(:, Raxis) = PresentCell;
        II = (PresentCell * ReferenCell <= DFactor * RightSum);
        EchoCfar(II, Raxis) = 0;
    end

    LeftSum = sum(CFARInput(:, 1 : ReferenCell - 1), 2);

    % 中间区域: 同时使用左右参考窗。
    for Raxis = Split + 1 : Rcell - Split
        PresentCell = CFARInput(:, Raxis);
        RightDec = CFARInput(:, Raxis + ProtectCell);
        RightSum = RightSum + CFARInput(:, Raxis + ProtectCell + ReferenCell) - RightDec;

        LeftSum = LeftSum + CFARInput(:, Raxis - ProtectCell - 1) - LeftDec;
        LeftDec = CFARInput(:, Raxis - ProtectCell - ReferenCell);

        EchoCfar(:, Raxis) = PresentCell;

        NeedSum = CFType(RightSum, LeftSum, TypeCase);
        II = PresentCell * ReferenCell <= DFactor * NeedSum;
        EchoCfar(II, Raxis) = 0;
    end

    % 右边界区域: 仅使用左参考窗。
    for Raxis = Rcell - Split + 1 : Rcell
        PresentCell = CFARInput(:, Raxis);
        LeftSum = LeftSum + CFARInput(:, Raxis - ProtectCell - 1) - LeftDec;
        LeftDec = CFARInput(:, Raxis - ProtectCell - ReferenCell);
        EchoCfar(:, Raxis) = PresentCell;

        II = PresentCell * ReferenCell <= DFactor * LeftSum;
        EchoCfar(II, Raxis) = 0;
    end
end
