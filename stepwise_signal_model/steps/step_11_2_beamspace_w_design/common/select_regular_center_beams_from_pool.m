function [selected_idx, W_sel, info] = select_regular_center_beams_from_pool(W_pool, pool_info, B)
%SELECT_REGULAR_CENTER_BEAMS_FROM_POOL Select center-nearest regular beams.

if nargin < 3
    error('select_regular_center_beams_from_pool:NotEnoughInputs', 'W_pool, pool_info, and B are required.');
end
if ~isfield(pool_info, 'beam_az_col') || ~isfield(pool_info, 'beam_el_col')
    error('select_regular_center_beams_from_pool:MissingPoolInfo', ...
        'pool_info.beam_az_col and pool_info.beam_el_col are required.');
end
M = size(W_pool, 2);
if ~(isscalar(B) && isfinite(B) && B > 0 && B == floor(B))
    error('select_regular_center_beams_from_pool:InvalidB', 'B must be a positive integer.');
end
if B > M
    error('select_regular_center_beams_from_pool:TooManyBeams', 'B=%d exceeds pool size M=%d.', B, M);
end

[az_c, el_c] = get_center_local(pool_info);
az_col = pool_info.beam_az_col(:).';
el_col = pool_info.beam_el_col(:).';
az_step = median_step_local(unique(round(az_col, 10)));
el_step = median_step_local(unique(round(el_col, 10)));

[rect_az_count, rect_el_count, rect_name] = preferred_rectangle_local(B);
idx = [];
if ~isempty(rect_name)
    az_vals = sort_by_center_local(unique(round(az_col, 10)), az_c);
    el_vals = sort_by_center_local(unique(round(el_col, 10)), el_c);
    az_sel = sort(az_vals(1:min(rect_az_count, numel(az_vals))));
    el_sel = sort(el_vals(1:min(rect_el_count, numel(el_vals))));
    idx = find(ismembertol(az_col, az_sel, 1e-9) & ismembertol(el_col, el_sel, 1e-9));
    idx = idx(:).';
end

if numel(idx) ~= B
    d2 = ((az_col - az_c) ./ max(az_step, eps)).^2 + ((el_col - el_c) ./ max(el_step, eps)).^2;
    [~, order] = sortrows([d2(:), abs(el_col(:) - el_c), abs(az_col(:) - az_c), (1:M).']);
    idx = order(1:B).';
    selection_mode = sprintf('center_nearest_%d', B);
else
    selection_mode = rect_name;
end

[~, order_final] = sortrows([el_col(idx).', az_col(idx).', idx(:)]);
selected_idx = idx(order_final);
W_sel = W_pool(:, selected_idx);

info = struct();
info.B = B;
info.selection_mode = selection_mode;
info.selected_az = az_col(selected_idx);
info.selected_el = el_col(selected_idx);
info.selected_idx = selected_idx;
info.az_center = az_c;
info.el_center = el_c;
info.az_step = az_step;
info.el_step = el_step;
info.note = 'regular center-nearest subset from the compatible existing 2D beam pool';
end

function [az_c, el_c] = get_center_local(pool_info)
if isfield(pool_info, 'cfg_beam_center')
    az_c = pool_info.cfg_beam_center(1);
    el_c = pool_info.cfg_beam_center(2);
elseif isfield(pool_info, 'az_center') && isfield(pool_info, 'el_center')
    az_c = pool_info.az_center;
    el_c = pool_info.el_center;
else
    az_c = median(pool_info.beam_az_col);
    el_c = median(pool_info.beam_el_col);
end
end

function step = median_step_local(values)
values = sort(values(:));
if numel(values) < 2
    step = 1;
else
    d = diff(values);
    d = d(d > 1e-9);
    if isempty(d)
        step = 1;
    else
        step = median(d);
    end
end
end

function [az_count, el_count, name] = preferred_rectangle_local(B)
switch B
    case 9
        az_count = 3;
        el_count = 3;
        name = 'az3_el3';
    case 15
        az_count = 5;
        el_count = 3;
        name = 'az5_el3';
    case 25
        az_count = 5;
        el_count = 5;
        name = 'az5_el5';
    case 35
        az_count = 7;
        el_count = 5;
        name = 'az7_el5';
    otherwise
        az_count = NaN;
        el_count = NaN;
        name = '';
end
end

function values_sorted = sort_by_center_local(values, center)
[~, order] = sort(abs(values(:).' - center), 'ascend');
values_sorted = values(order);
end

