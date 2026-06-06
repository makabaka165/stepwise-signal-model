function [frontend_beam_pool, pool_info] = build_frontend_beam_pool_from_existing_layout(step11_2_dir, cfg, arrInfo, varargin)
%BUILD_FRONTEND_BEAM_POOL_FROM_EXISTING_LAYOUT Reuse the existing 2D beam pool.

if nargin < 3
    error('build_frontend_beam_pool_from_existing_layout:NotEnoughInputs', ...
        'step11_2_dir, cfg, and arrInfo are required.');
end
opts = parse_opts_local(varargin{:});
common112_dir = fullfile(step11_2_dir, 'common');
if exist(common112_dir, 'dir') ~= 7
    error('build_frontend_beam_pool_from_existing_layout:MissingStep112Common', ...
        'Missing Step11.2 common dir: %s', common112_dir);
end
addpath(common112_dir);

x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
lambda = cfg.arr.lambda;
az_c = cfg.beam.azSectorCenter;
el_c = cfg.beam.elSectorCenter;

[W_pool, pool_info_raw] = build_existing_2d_beam_pool(x, y, z, az_c, el_c, lambda, cfg, ...
    'Mode', 'legacy_or_fallback', ...
    'PhaseFactor', opts.phase_factor, ...
    'PhaseSign', opts.phase_sign, ...
    'AzPoolOffsets', opts.az_pool_offsets, ...
    'ElPoolOffsets', opts.el_pool_offsets, ...
    'Window', opts.window);

pool_info = pool_info_raw;
pool_info.az_grid = unique(round(pool_info.beam_az_col(:).' * 1e10) / 1e10);
pool_info.el_grid = unique(round(pool_info.beam_el_col(:).' * 1e10) / 1e10);
pool_info.center_deg = [az_c, el_c];
pool_info.note_step11_4 = 'frontend pool reuses existing Step11.2-compatible 2D beam layout';

frontend_beam_pool = struct();
frontend_beam_pool.W = W_pool;
frontend_beam_pool.info = pool_info;
frontend_beam_pool.az_col = pool_info.beam_az_col(:);
frontend_beam_pool.el_col = pool_info.beam_el_col(:);
frontend_beam_pool.az_grid = pool_info.az_grid;
frontend_beam_pool.el_grid = pool_info.el_grid;
frontend_beam_pool.phase_factor = opts.phase_factor;
frontend_beam_pool.phase_sign = opts.phase_sign;
frontend_beam_pool.source = 'Step11.2 build_existing_2d_beam_pool';
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.az_pool_offsets = -2.4:0.4:2.4;
opts.el_pool_offsets = -1.6:0.4:1.6;
opts.window = 'taylor';
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_frontend_beam_pool_from_existing_layout:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
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
            error('build_frontend_beam_pool_from_existing_layout:UnknownOption', ...
                'Unknown option: %s', name);
    end
end
end
