function geom = build_step11_6_canonical_geometry(cfg, requested_center_az_deg)
%BUILD_STEP11_6_CANONICAL_GEOMETRY Build canonical and requested-center local cylinder geometry.
%
% The canonical local subarray is the shared-center subarray at the nearest
% physical column to 0 deg.  A requested working center is snapped to the
% nearest physical column center, then the same 65-column local order is
% used.  This is the ordering assumed by the Step11.6 cache.

if nargin < 2
    requested_center_az_deg = 0;
end
if ~(isstruct(cfg) && isfield(cfg, 'arr') && isfield(cfg, 'beam'))
    error('build_step11_6_canonical_geometry:InvalidCfg', 'cfg must contain arr and beam fields.');
end
if ~(isscalar(requested_center_az_deg) && isfinite(requested_center_az_deg))
    error('build_step11_6_canonical_geometry:InvalidCenter', 'requested_center_az_deg must be finite scalar.');
end

phi_col = (0:cfg.arr.Naz - 1) / cfg.arr.Naz * 360;
[selected_center_column, actual_center_az_deg] = nearest_column_center_local(phi_col, requested_center_az_deg);

cfg0 = cfg;
cfg0.beam.azSectorCenter = 0;
cfg0.beam.azSteer = 0;
canonical_arr = arr_cyl(cfg0, 0);
[canonical_center_column, canonical_actual_center_az_deg] = nearest_column_center_local(phi_col, 0);

actual_arr = arr_cyl(cfg, requested_center_az_deg);
if actual_arr.colCtr ~= selected_center_column
    error('build_step11_6_canonical_geometry:CenterColumnMismatch', ...
        'arr_cyl selected column %d, expected %d.', actual_arr.colCtr, selected_center_column);
end

rotated = rotate_xyz_local(canonical_arr.xActVec, canonical_arr.yActVec, canonical_arr.zActVec, actual_center_az_deg);

geom = struct();
geom.cache_order_name = 'shared_center_nearest_column_canonical_order';
geom.requested_center_az_deg = requested_center_az_deg;
geom.actual_center_az_deg = actual_center_az_deg;
geom.selected_center_column = selected_center_column;
geom.canonical_requested_center_az_deg = 0;
geom.canonical_actual_center_az_deg = canonical_actual_center_az_deg;
geom.canonical_center_column = canonical_center_column;
geom.colsAct = actual_arr.colsAct;
geom.canonical_colsAct = canonical_arr.colsAct;
geom.phi_col_deg = phi_col;
geom.canonical_arr = canonical_arr;
geom.actual_arr = actual_arr;
geom.x_canonical = canonical_arr.xActVec(:);
geom.y_canonical = canonical_arr.yActVec(:);
geom.z_canonical = canonical_arr.zActVec(:);
geom.x_actual = actual_arr.xActVec(:);
geom.y_actual = actual_arr.yActVec(:);
geom.z_actual = actual_arr.zActVec(:);
geom.x_rotated_from_canonical = rotated.x(:);
geom.y_rotated_from_canonical = rotated.y(:);
geom.z_rotated_from_canonical = rotated.z(:);
geom.max_geometry_rotation_error = max([ ...
    max(abs(geom.x_actual - geom.x_rotated_from_canonical)), ...
    max(abs(geom.y_actual - geom.y_rotated_from_canonical)), ...
    max(abs(geom.z_actual - geom.z_rotated_from_canonical))]);
geom.N_elements = numel(geom.x_canonical);
geom.N_columns = cfg.beam.subNaz;
geom.N_layers = cfg.arr.Nel;
end

function [idx, center_az] = nearest_column_center_local(phi_col, requested)
delta = wrap180_step11_6_local(phi_col - requested);
[~, idx] = min(abs(delta));
center_az = phi_col(idx);
if center_az >= 180
    center_az = center_az - 360;
end
end

function out = rotate_xyz_local(x, y, z, az_deg)
c = cosd(az_deg);
s = sind(az_deg);
out = struct();
out.x = c .* x(:) - s .* y(:);
out.y = s .* x(:) + c .* y(:);
out.z = z(:);
end

function ang = wrap180_step11_6_local(ang)
ang = mod(ang + 180, 360) - 180;
end
