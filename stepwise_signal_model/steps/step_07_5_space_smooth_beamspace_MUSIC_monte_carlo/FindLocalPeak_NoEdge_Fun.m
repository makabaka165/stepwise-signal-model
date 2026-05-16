function [peak_val, peak_ind] = FindLocalPeak_NoEdge_Fun(x)
    x1 = abs(x);
    x1 = reshape(x1, 1, length(x1));

    if length(x1) < 3
        peak_val = [];
        peak_ind = [];
        return;
    end

    mid = 2:length(x1)-1;
    is_peak = x1(mid) > x1(mid-1) & x1(mid) > x1(mid+1);

    peak_ind = mid(is_peak);
    peak_val = x1(peak_ind);

    [peak_val, order] = sort(peak_val, 'descend');
    peak_ind = peak_ind(order);
end
