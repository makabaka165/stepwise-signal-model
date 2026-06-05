function [W_pool, pool_info] = build_existing_2d_beam_pool(x, y, z, az_c, el_c, lambda, cfg, varargin)
%BUILD_EXISTING_2D_BEAM_POOL Build the compatible 2D engineering beam pool.

if nargin < 7
    error('build_existing_2d_beam_pool:NotEnoughInputs', ...
        'x, y, z, az_c, el_c, lambda, and cfg are required.');
end
opts = parse_options_local(varargin{:});

xv = x(:);
yv = y(:);
zv = z(:);
if isempty(xv) || numel(xv) ~= numel(yv) || numel(xv) ~= numel(zv)
    error('build_existing_2d_beam_pool:CoordMismatch', 'x, y, and z must have equal non-zero length.');
end

az_pool = az_c + opts.az_pool_offsets(:).';
el_pool = el_c + opts.el_pool_offsets(:).';
mode_used = 'fallback_grid';
note = ['compatible fallback replication of the existing 3dB-overlap 2D beam layout; ' ...
    'not a new front-end beam design'];

if strcmpi(opts.mode, 'legacy_or_fallback')
    if exist('build_cyl_azel_beam_transform', 'file') == 2
        mode_used = 'legacy_build_cyl_azel_beam_transform_with_fallback_centers';
        note = ['reuses the existing Step11.1 cylindrical az/el beam transform with a compatible ' ...
            '3dB-overlap center grid'];
    end
elseif ~strcmpi(opts.mode, 'fallback_grid')
    error('build_existing_2d_beam_pool:UnknownMode', 'Unknown Mode: %s', opts.mode);
end

[W_pool, beam_info] = build_cyl_azel_beam_transform(xv, yv, zv, az_pool, el_pool, lambda, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Window', opts.window);

pool_info = struct();
pool_info.mode_used = mode_used;
pool_info.az_pool = az_pool;
pool_info.el_pool = el_pool;
pool_info.beam_az_col = beam_info.beam_az_col;
pool_info.beam_el_col = beam_info.beam_el_col;
pool_info.M = size(W_pool, 2);
pool_info.N_elem = size(W_pool, 1);
pool_info.phase_factor = opts.phase_factor;
pool_info.phase_sign = opts.phase_sign;
pool_info.window = opts.window;
pool_info.note = note;
pool_info.cfg_beam_center = [az_c, el_c];
pool_info.beam_info = beam_info;
pool_info.cfg_subNaz = cfg.beam.subNaz;
pool_info.cfg_Nel = cfg.arr.Nel;
end

function opts = parse_options_local(varargin)
opts = struct();
opts.mode = 'legacy_or_fallback';
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.az_pool_offsets = -2.4:0.4:2.4;
opts.el_pool_offsets = -1.6:0.4:1.6;
opts.window = 'taylor';
if isempty(varargin)
    validate_opts_local(opts);
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_existing_2d_beam_pool:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'mode'
            opts.mode = char(value);
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'azpooloffsets'
            opts.az_pool_offsets = value;
        case 'elpooloffsets'
            opts.el_pool_offsets = value;
        case 'window'
            opts.window = char(value);
        otherwise
            error('build_existing_2d_beam_pool:UnknownOption', 'Unknown option: %s', name);
    end
end
validate_opts_local(opts);
end

function validate_opts_local(opts)
if ~(isscalar(opts.phase_factor) && isfinite(opts.phase_factor))
    error('build_existing_2d_beam_pool:InvalidPhaseFactor', 'PhaseFactor must be finite scalar.');
end
if ~(isscalar(opts.phase_sign) && isfinite(opts.phase_sign) && (opts.phase_sign == 1 || opts.phase_sign == -1))
    error('build_existing_2d_beam_pool:InvalidPhaseSign', 'PhaseSign must be +1 or -1.');
end
if isempty(opts.az_pool_offsets) || any(~isfinite(opts.az_pool_offsets(:)))
    error('build_existing_2d_beam_pool:InvalidAzOffsets', 'AzPoolOffsets must be finite non-empty vector.');
end
if isempty(opts.el_pool_offsets) || any(~isfinite(opts.el_pool_offsets(:)))
    error('build_existing_2d_beam_pool:InvalidElOffsets', 'ElPoolOffsets must be finite non-empty vector.');
end
end

