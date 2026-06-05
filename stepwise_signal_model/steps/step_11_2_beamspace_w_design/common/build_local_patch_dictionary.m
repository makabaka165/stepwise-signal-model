function [A_patch, patch_info] = build_local_patch_dictionary(x, y, z, az_grid, el_grid, lambda, varargin)
%BUILD_LOCAL_PATCH_DICTIONARY Build a local cylindrical steering dictionary.

if nargin < 6
    error('build_local_patch_dictionary:NotEnoughInputs', ...
        'x, y, z, az_grid, el_grid, and lambda are required.');
end
opts = parse_options_local(varargin{:});
xv = x(:);
yv = y(:);
zv = z(:);
az_grid = az_grid(:).';
el_grid = el_grid(:).';

if isempty(xv) || numel(xv) ~= numel(yv) || numel(xv) ~= numel(zv)
    error('build_local_patch_dictionary:CoordMismatch', 'x, y, and z must have equal non-zero length.');
end
if isempty(az_grid) || any(~isfinite(az_grid)) || isempty(el_grid) || any(~isfinite(el_grid))
    error('build_local_patch_dictionary:InvalidGrid', 'az_grid and el_grid must be finite non-empty vectors.');
end

N_elem = numel(xv);
N_patch = numel(az_grid) * numel(el_grid);
A_patch = zeros(N_elem, N_patch);
az_col = zeros(1, N_patch);
el_col = zeros(1, N_patch);

col = 0;
for iEl = 1:numel(el_grid)
    for iAz = 1:numel(az_grid)
        col = col + 1;
        az_col(col) = az_grid(iAz);
        el_col(col) = el_grid(iEl);
        A_patch(:, col) = build_cyl_steering_vec(xv, yv, zv, az_grid(iAz), el_grid(iEl), lambda, ...
            'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    end
end

patch_info = struct();
patch_info.az_grid = az_grid;
patch_info.el_grid = el_grid;
patch_info.az_col = az_col;
patch_info.el_col = el_col;
patch_info.N_patch = N_patch;
patch_info.N_elem = N_elem;
patch_info.phase_factor = opts.phase_factor;
patch_info.phase_sign = opts.phase_sign;
patch_info.lambda = lambda;
end

function opts = parse_options_local(varargin)
opts = struct('phase_factor', 1, 'phase_sign', 1);
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_local_patch_dictionary:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        otherwise
            error('build_local_patch_dictionary:UnknownOption', 'Unknown option: %s', name);
    end
end
end

