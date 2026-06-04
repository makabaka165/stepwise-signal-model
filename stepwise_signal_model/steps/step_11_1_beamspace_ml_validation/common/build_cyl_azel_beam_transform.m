function [W, info] = build_cyl_azel_beam_transform(x, y, z, beam_az_deg, beam_el_deg, lambda, varargin)
%BUILD_CYL_AZEL_BEAM_TRANSFORM Build an az-major cylindrical az/el beam matrix.

if nargin < 6
    error('build_cyl_azel_beam_transform:NotEnoughInputs', 'x, y, z, beam_az_deg, beam_el_deg, and lambda are required.');
end
opts = parse_options_local(varargin{:});
[xv, yv, zv] = validate_xyz_local(x, y, z);
beam_az_deg = beam_az_deg(:).';
beam_el_deg = beam_el_deg(:).';
if isempty(beam_az_deg) || any(~isfinite(beam_az_deg))
    error('build_cyl_azel_beam_transform:InvalidBeamAz', 'beam_az_deg must be a finite non-empty vector.');
end
if isempty(beam_el_deg) || any(~isfinite(beam_el_deg))
    error('build_cyl_azel_beam_transform:InvalidBeamEl', 'beam_el_deg must be a finite non-empty vector.');
end
if ~(isscalar(lambda) && isfinite(lambda) && lambda > 0)
    error('build_cyl_azel_beam_transform:InvalidLambda', 'lambda must be a positive finite scalar.');
end

N_elem = numel(xv);
beam_az_count = numel(beam_az_deg);
beam_el_count = numel(beam_el_deg);
beam_count = beam_az_count * beam_el_count;
A_beam = zeros(N_elem, beam_count);
beam_az_col = zeros(1, beam_count);
beam_el_col = zeros(1, beam_count);

col = 0;
% Az-major ordering: for each elevation, azimuth changes fastest.
for iEl = 1:beam_el_count
    for iAz = 1:beam_az_count
        col = col + 1;
        beam_az_col(col) = beam_az_deg(iAz);
        beam_el_col(col) = beam_el_deg(iEl);
        A_beam(:, col) = build_cyl_steering_vec(xv, yv, zv, beam_az_deg(iAz), beam_el_deg(iEl), lambda, ...
            'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    end
end

[win, window_name, window_fallback] = make_window_local(N_elem, opts.window);
win = win(:);
win_norm = norm(win);
if ~(isfinite(win_norm) && win_norm > 0)
    error('build_cyl_azel_beam_transform:InvalidWindow', 'Window norm must be positive and finite.');
end
win = win / win_norm;

W = win .* A_beam;
if ~isequal(size(W), [N_elem, beam_count])
    error('build_cyl_azel_beam_transform:ShapeMismatch', 'W must be N_elem x B.');
end

info = struct();
info.N_elem = N_elem;
info.beam_count = beam_count;
info.beam_az_deg = beam_az_deg;
info.beam_el_deg = beam_el_deg;
info.beam_az_count = beam_az_count;
info.beam_el_count = beam_el_count;
info.beam_az_col = beam_az_col;
info.beam_el_col = beam_el_col;
info.ordering = 'az-major: elevation outer loop, azimuth inner loop';
info.lambda = lambda;
info.phase_factor = opts.phase_factor;
info.phase_sign = opts.phase_sign;
info.windowName = window_name;
info.windowFallback = window_fallback;
info.W_shape = size(W);
info.cond_WHW = cond(W' * W + 1e-12 * eye(beam_count));
end

function opts = parse_options_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.window = 'taylor';
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_cyl_azel_beam_transform:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'window'
            opts.window = lower(char(value));
        otherwise
            error('build_cyl_azel_beam_transform:UnknownOption', 'Unknown option: %s', name);
    end
end
if ~(isscalar(opts.phase_factor) && isfinite(opts.phase_factor))
    error('build_cyl_azel_beam_transform:InvalidPhaseFactor', 'PhaseFactor must be a finite scalar.');
end
if ~(isscalar(opts.phase_sign) && isfinite(opts.phase_sign) && (opts.phase_sign == 1 || opts.phase_sign == -1))
    error('build_cyl_azel_beam_transform:InvalidPhaseSign', 'PhaseSign must be +1 or -1.');
end
end

function [xv, yv, zv] = validate_xyz_local(x, y, z)
xv = x(:);
yv = y(:);
zv = z(:);
if isempty(xv) || numel(xv) ~= numel(yv) || numel(xv) ~= numel(zv)
    error('build_cyl_azel_beam_transform:CoordLengthMismatch', 'x, y, and z must be non-empty vectors with the same length.');
end
if any(~isfinite(xv)) || any(~isfinite(yv)) || any(~isfinite(zv))
    error('build_cyl_azel_beam_transform:InvalidCoords', 'x, y, and z must be finite.');
end
end

function [win, window_name, window_fallback] = make_window_local(N_elem, requested_window)
window_fallback = '';
switch lower(requested_window)
    case 'taylor'
        if exist('taylorwin', 'file') == 2
            try
                win = taylorwin(N_elem, 25, -40);
                window_name = 'taylorwin';
                return;
            catch err
                window_fallback = ['taylorwin_error:' err.identifier];
            end
        else
            window_fallback = 'taylorwin_not_found';
        end
        [win, window_name, window_fallback] = hann_or_manual_local(N_elem, window_fallback);
    case 'hann'
        [win, window_name, window_fallback] = hann_or_manual_local(N_elem, 'hann_requested');
    case 'ones'
        win = ones(N_elem, 1);
        window_name = 'ones';
        window_fallback = 'ones_requested';
    otherwise
        error('build_cyl_azel_beam_transform:UnknownWindow', 'Unknown Window option: %s', requested_window);
end
end

function [win, window_name, window_fallback] = hann_or_manual_local(N_elem, window_fallback)
if exist('hann', 'file') == 2
    try
        win = hann(N_elem);
        window_name = 'hann';
        window_fallback = [window_fallback ';hann_used'];
        return;
    catch err
        window_fallback = [window_fallback ';hann_error:' err.identifier];
    end
end

if N_elem == 1
    win = 1;
else
    n = (0:N_elem-1).';
    win = 0.5 - 0.5*cos(2*pi*n/(N_elem-1));
end
window_name = 'manual_hann';
window_fallback = [window_fallback ';manual_hann_used'];
if ~any(win)
    win = ones(N_elem, 1);
    window_name = 'ones';
    window_fallback = [window_fallback ';ones_used'];
end
end
