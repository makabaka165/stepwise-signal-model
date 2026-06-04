function grid = precompute_beamspace_grid(W, x, y, z, az_grid_deg, el0_deg, lambda, varargin)
%PRECOMPUTE_BEAMSPACE_GRID Precompute W' * a_cyl(az, el0) over a grid.

if nargin < 7
    error('precompute_beamspace_grid:NotEnoughInputs', 'W, x, y, z, az_grid_deg, el0_deg, and lambda are required.');
end
if ndims(W) ~= 2
    error('precompute_beamspace_grid:InvalidW', 'W must be a matrix.');
end

opts = parse_options_local(varargin{:});
xv = x(:);
yv = y(:);
zv = z(:);
az_grid_deg = az_grid_deg(:).';
if isempty(az_grid_deg) || any(~isfinite(az_grid_deg))
    error('precompute_beamspace_grid:InvalidAzGrid', 'az_grid_deg must be a finite non-empty vector.');
end
if size(W, 1) ~= numel(xv)
    error('precompute_beamspace_grid:WElementMismatch', 'size(W,1) must equal the number of active elements.');
end

N_elem = numel(xv);
Ngrid = numel(az_grid_deg);
A_grid = zeros(N_elem, Ngrid);
for idx = 1:Ngrid
    A_grid(:, idx) = build_cyl_steering_vec(xv, yv, zv, az_grid_deg(idx), el0_deg, lambda, ...
        'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
end
G_grid = W' * A_grid;

grid = struct();
grid.az_grid_deg = az_grid_deg;
grid.A_grid_shape = size(A_grid);
grid.G_grid = G_grid;
grid.G_grid_shape = size(G_grid);
grid.el0_deg = el0_deg;
grid.lambda = lambda;
grid.phase_factor = opts.phase_factor;
grid.phase_sign = opts.phase_sign;

if ~isequal(size(G_grid), [size(W, 2), Ngrid])
    error('precompute_beamspace_grid:GGridShapeMismatch', 'G_grid must be beam_count x Ngrid.');
end
end

function opts = parse_options_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('precompute_beamspace_grid:InvalidNameValue', 'Name-value options must be paired.');
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
            error('precompute_beamspace_grid:UnknownOption', 'Unknown option: %s', name);
    end
end
end
