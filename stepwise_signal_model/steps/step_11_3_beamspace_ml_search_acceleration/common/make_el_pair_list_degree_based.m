function [el1, el2, valid_mask, info] = make_el_pair_list_degree_based(el_center_grid, el_sep_deg_list, orientation_list, el_bounds)
%MAKE_EL_PAIR_LIST_DEGREE_BASED Build physical elevation pair candidates.

if nargin < 4
    error('make_el_pair_list_degree_based:NotEnoughInputs', ...
        'el_center_grid, el_sep_deg_list, orientation_list, and el_bounds are required.');
end
el_center_grid = el_center_grid(:);
el_sep_deg_list = el_sep_deg_list(:).';
orientation_list = orientation_list(:).';
el_bounds = sort(el_bounds(:).');

if isempty(el_center_grid) || isempty(el_sep_deg_list)
    error('make_el_pair_list_degree_based:EmptyInput', 'Elevation center and sep lists must be non-empty.');
end
if any(~isfinite(el_center_grid)) || any(~isfinite(el_sep_deg_list)) || any(~isfinite(el_bounds))
    error('make_el_pair_list_degree_based:InvalidInput', 'Elevation inputs must be finite.');
end
if any(el_sep_deg_list < -1e-12)
    error('make_el_pair_list_degree_based:InvalidSep', 'el_sep_deg_list must be non-negative.');
end
if any(~ismember(orientation_list, [-1, 1]))
    error('make_el_pair_list_degree_based:InvalidOrientation', 'orientation_list must contain +1 and/or -1.');
end

rows = repmat(make_row_local(), numel(el_center_grid) * numel(el_sep_deg_list) * max(1, numel(orientation_list)), 1);
idx = 0;
for iCenter = 1:numel(el_center_grid)
    center = el_center_grid(iCenter);
    for iSep = 1:numel(el_sep_deg_list)
        sep_deg = el_sep_deg_list(iSep);
        if abs(sep_deg) < 1e-12
            orientations_now = 1;
        else
            orientations_now = orientation_list;
        end
        for iOri = 1:numel(orientations_now)
            orientation = orientations_now(iOri);
            idx = idx + 1;
            if orientation == 1
                rows(idx).el1 = center - sep_deg / 2;
                rows(idx).el2 = center + sep_deg / 2;
            else
                rows(idx).el1 = center + sep_deg / 2;
                rows(idx).el2 = center - sep_deg / 2;
            end
            rows(idx).el_center = center;
            rows(idx).el_sep_deg = sep_deg;
            rows(idx).orientation = orientation;
            rows(idx).i_el_center = iCenter;
            rows(idx).i_el_sep = iSep;
            rows(idx).valid = rows(idx).el1 >= el_bounds(1) - 1e-12 && rows(idx).el1 <= el_bounds(2) + 1e-12 && ...
                rows(idx).el2 >= el_bounds(1) - 1e-12 && rows(idx).el2 <= el_bounds(2) + 1e-12;
        end
    end
end
rows = rows(1:idx);

el1 = [rows.el1].';
el2 = [rows.el2].';
valid_mask = [rows.valid].';

info = struct();
info.num_candidates = numel(rows);
info.num_valid = nnz(valid_mask);
info.el_sep_deg_list = el_sep_deg_list;
info.orientation_list = orientation_list;
info.el_bounds = el_bounds;
info.el_center_grid = el_center_grid;
info.rows = rows;
end

function row = make_row_local()
row = struct();
row.el1 = NaN;
row.el2 = NaN;
row.el_center = NaN;
row.el_sep_deg = NaN;
row.orientation = NaN;
row.i_el_center = NaN;
row.i_el_sep = NaN;
row.valid = false;
end

