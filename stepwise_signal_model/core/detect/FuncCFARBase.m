function FuncCFAR = FuncCFARBase
    FuncCFAR.CFType = @CFType;
    FuncCFAR.DetectorType = @DetectorType;
    FuncCFAR.CFAR01 = @CFAR01;
    FuncCFAR.CFAR02 = @CFAR02;
end

function [NeedSum] = CFType(RightSum, LeftSum, TypeCase)
    switch TypeCase
        case 'GO'
            NeedSum = max(RightSum, LeftSum);
        case 'SO'
            NeedSum = min(RightSum, LeftSum);
        case 'CA'
            NeedSum = mean([RightSum, LeftSum], 2);
    end
end

function [MTDModule] = DetectorType(MTDModule, DeTypeCase)
    % 线性或平方
    switch DeTypeCase
        case 'Linear'
            MTDModule = abs(MTDModule);
        case 'Square'
            MTDModule = (abs(MTDModule)).^2;
    end
end

function [y1, y2] = CFAR01(CFARInput, D_Threshold, ProtectCell, ReferenCell, TypeCase, DeTypeCase)
    [~, N] = size(CFARInput);
    CFARInput = DetectorType(CFARInput, DeTypeCase);
    
    y1 = [];
    y2 = zeros(size(CFARInput));
    
    for jj = 1 : ReferenCell + ProtectCell
        Q = jj + ProtectCell + 1 : jj + ProtectCell + ReferenCell;
        miu = mean(CFARInput(:, Q), 2);
        y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
        temp = find(y2(:, jj) >= 1) .';
        range_idx = jj * ones(1, length(temp));
        y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']];
    end
    
    for jj = ReferenCell + ProtectCell + 1 : N - ReferenCell - ProtectCell
        Q1 = jj - ProtectCell - 1 - ReferenCell + 1 : jj - ProtectCell - 1;
        Q2 = jj + ProtectCell + 1 : jj + ProtectCell + ReferenCell;
        miu = CFType(mean(CFARInput(:, Q1), 2), mean(CFARInput(:, Q2), 2), TypeCase);
        
        y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
        temp = find(y2(:, jj) >= 1) .';
        range_idx = jj * ones(1, length(temp));
        y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']];
    end
    
    for jj = N - ReferenCell - ProtectCell + 1 : N
        Q = jj - ProtectCell - 1 - ReferenCell + 1 : jj - ProtectCell - 1;
        miu = mean(CFARInput(:, Q), 2);
        y2(:, jj) = CFARInput(:, jj) ./ (miu * D_Threshold);
        temp = find(y2(:, jj) >= 1) .';
        range_idx = jj * ones(1, length(temp));
        y1 = [y1, [range_idx; temp; CFARInput(temp, jj).']];
    end
end

function [EchoCfar] = CFAR02(CFARInput, DFactor, ProtectCell, ReferenCell, TypeCase, DeTypeCase)
    [NumRow, Rcell] = size(CFARInput);
    CFARInput = DetectorType(CFARInput, DeTypeCase);
    EchoCfar = nan(NumRow, Rcell);
    Split = ProtectCell + ReferenCell;
    LeftDec = 0;
    
    %% 矩阵起始段
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
    
    %% 矩阵中段
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
    
    %% 矩阵末尾
    for Raxis = Rcell - Split + 1 : Rcell
        PresentCell = CFARInput(:, Raxis);
        LeftSum = LeftSum + CFARInput(:, Raxis - ProtectCell - 1) - LeftDec;
        LeftDec = CFARInput(:, Raxis - ProtectCell - ReferenCell);
        EchoCfar(:, Raxis) = PresentCell;
        
        II = PresentCell * ReferenCell <= DFactor * LeftSum;
        EchoCfar(II, Raxis) = 0;
    end
end