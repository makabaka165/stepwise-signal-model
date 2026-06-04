function grid = precompute_beamspace_azel_grid(W, x, y, z, az_grid_deg, el_grid_deg, lambda, varargin)
%PRECOMPUTE_BEAMSPACE_AZEL_GRID Precompute W' * a_cyl(az, el) over az/el grids.

if nargin < 7
    error('precompute_beamspace_azel_grid:NotEnoughInputs', 'W, x, y, z, az_grid_deg, el_grid_deg, and lambda are required.');
end
opts = parse_options_local(varargin{:});
xv = x(:);
yv = y(:);
zv = z(:);
az_grid_deg = az_grid_deg(:).';
el_grid_deg = el_grid_deg(:).';
if isempty(az_grid_deg) || any(~isfinite(az_grid_deg))
    error('precompute_beamspace_azel_grid:InvalidAzGrid', 'az_grid_deg must be a finite non-empty vector.');
end
if isempty(el_grid_deg) || any(~isfinite(el_grid_deg))
    error('precompute_beamspace_azel_grid:InvalidElGrid', 'el_grid_deg must be a finite non-empty vector.');
end
if size(W, 1) ~= numel(xv)
    error('precompute_beamspace_azel_grid:WElementMismatch', 'size(W,1) must equal active element count.');
end

N_az = numel(az_grid_deg);
N_el = numel(el_grid_deg);
B = size(W, 2);
G_grid = zeros(B, N_az, N_el);

for iEl = 1:N_el
    A_grid_el = zeros(numel(xv), N_az);
    for iAz = 1:N_az
        A_grid_el(:, iAz) = build_cyl_steering_vec(xv, yv, zv, az_grid_deg(iAz), el_grid_deg(iEl), lambda, ...
            'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    end
    G_grid(:, :, iEl) = W' * A_grid_el;
end

grid = struct();
grid.az_grid_deg = az_grid_deg;
grid.el_grid_deg = el_grid_deg;
grid.N_az = N_az;
grid.N_el = N_el;
grid.B = B;
grid.G_grid = G_grid;
grid.G_grid_shape = size(G_grid);
grid.lambda = lambda;
grid.phase_factor = opts.phase_factor;
grid.phase_sign = opts.phase_sign;
end

function opts = parse_options_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('precompute_beamspace_azel_grid:InvalidNameValue', 'Name-value options must be paired.');
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
            error('precompute_beamspace_azel_grid:UnknownOption', 'Unknown option: %s', name);
    end
end
end
