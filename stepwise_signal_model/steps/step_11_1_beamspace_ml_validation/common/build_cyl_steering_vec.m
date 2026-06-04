function a = build_cyl_steering_vec(x, y, z, az_deg, el_deg, lambda, varargin)
%BUILD_CYL_STEERING_VEC Build a cylindrical-array steering vector.

if nargin < 6
    error('build_cyl_steering_vec:NotEnoughInputs', 'x, y, z, az_deg, el_deg, and lambda are required.');
end

[phase_factor, phase_sign] = parse_options_local(varargin{:});
[xv, yv, zv] = validate_xyz_local(x, y, z);

if ~(isscalar(az_deg) && isfinite(az_deg))
    error('build_cyl_steering_vec:InvalidAz', 'az_deg must be a finite scalar.');
end
if ~(isscalar(el_deg) && isfinite(el_deg))
    error('build_cyl_steering_vec:InvalidEl', 'el_deg must be a finite scalar.');
end
if ~(isscalar(lambda) && isfinite(lambda) && lambda > 0)
    error('build_cyl_steering_vec:InvalidLambda', 'lambda must be a positive finite scalar.');
end

ux = cosd(el_deg) * cosd(az_deg);
uy = cosd(el_deg) * sind(az_deg);
uz = sind(el_deg);
phase = xv * ux + yv * uy + zv * uz;
a = exp(1j * phase_sign * phase_factor * 2*pi/lambda * phase);

if ~isequal(size(a), [numel(xv), 1])
    error('build_cyl_steering_vec:ShapeMismatch', 'Steering vector must be N_elem x 1.');
end
end

function [xv, yv, zv] = validate_xyz_local(x, y, z)
xv = x(:);
yv = y(:);
zv = z(:);
if isempty(xv) || isempty(yv) || isempty(zv)
    error('build_cyl_steering_vec:EmptyCoords', 'x, y, and z must be non-empty.');
end
if numel(xv) ~= numel(yv) || numel(xv) ~= numel(zv)
    error('build_cyl_steering_vec:CoordLengthMismatch', 'x, y, and z must have the same number of elements.');
end
if any(~isfinite(xv)) || any(~isfinite(yv)) || any(~isfinite(zv))
    error('build_cyl_steering_vec:InvalidCoords', 'x, y, and z must be finite.');
end
end

function [phase_factor, phase_sign] = parse_options_local(varargin)
phase_factor = 1;
phase_sign = 1;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_cyl_steering_vec:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            phase_factor = value;
        case 'phasesign'
            phase_sign = value;
        otherwise
            error('build_cyl_steering_vec:UnknownOption', 'Unknown option: %s', name);
    end
end
if ~(isscalar(phase_factor) && isfinite(phase_factor))
    error('build_cyl_steering_vec:InvalidPhaseFactor', 'PhaseFactor must be a finite scalar.');
end
if ~(isscalar(phase_sign) && isfinite(phase_sign) && (phase_sign == 1 || phase_sign == -1))
    error('build_cyl_steering_vec:InvalidPhaseSign', 'PhaseSign must be +1 or -1.');
end
end
