function [G_grid, lookup_info] = lookup_step11_6_beamspace_cache(cache, az_grid_deg, el_grid_deg, varargin)
%LOOKUP_STEP11_6_BEAMSPACE_CACHE Exact lookup of canonical cached G grid.
%
% By default az_grid_deg is interpreted as global azimuth and converted to
% canonical delta azimuth using CenterAzDeg.  Set InputAzMode='delta' to use
% local delta-az directly.  No interpolation is performed.

if nargin < 3
    error('lookup_step11_6_beamspace_cache:NotEnoughInputs', 'cache, az_grid_deg, and el_grid_deg are required.');
end
opts = parse_opts_local(varargin{:});
az_grid_deg = az_grid_deg(:).';
el_grid_deg = el_grid_deg(:).';
if strcmpi(opts.InputAzMode, 'global')
    if ~isfinite(opts.CenterAzDeg)
        error('lookup_step11_6_beamspace_cache:MissingCenter', 'CenterAzDeg is required for global az lookup.');
    end
    delta_az = wrap180_local(az_grid_deg - opts.CenterAzDeg);
else
    delta_az = az_grid_deg;
end
delta_key = round(delta_az * 1e10) / 1e10;
el_key = round(el_grid_deg * 1e10) / 1e10;

[tf_az, i_az] = ismember(delta_key, round(cache.delta_az_grid_deg(:).' * 1e10) / 1e10);
[tf_el, i_el] = ismember(el_key, round(cache.el_grid_deg(:).' * 1e10) / 1e10);
cache_miss_count = nnz(~tf_az) + nnz(~tf_el);

lookup_info = struct();
lookup_info.lookup_mode = 'exact_grid_lookup';
lookup_info.input_az_mode = opts.InputAzMode;
lookup_info.center_az_deg = opts.CenterAzDeg;
lookup_info.delta_az_requested_deg = delta_key;
lookup_info.el_requested_deg = el_key;
lookup_info.missing_delta_az_deg = delta_key(~tf_az);
lookup_info.missing_el_deg = el_key(~tf_el);
lookup_info.cache_miss_count = cache_miss_count;
lookup_info.used_interpolation = false;
lookup_info.fallback_used = false;
lookup_info.lookup_time_sec = NaN;

if cache_miss_count > 0
    G_grid = [];
    if opts.ErrorOnMiss
        error('lookup_step11_6_beamspace_cache:CacheMiss', ...
            'Exact cache lookup missed %d grid entries. Interpolation is disabled.', cache_miss_count);
    end
    return;
end

tic;
G_grid = cache.G_grid(:, i_az, i_el);
lookup_info.lookup_time_sec = toc;
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.CenterAzDeg = NaN;
opts.InputAzMode = 'global';
opts.ErrorOnMiss = false;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('lookup_step11_6_beamspace_cache:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'centerazdeg'
            opts.CenterAzDeg = value;
        case 'inputazmode'
            opts.InputAzMode = char(value);
        case 'erroronmiss'
            opts.ErrorOnMiss = logical(value);
        otherwise
            error('lookup_step11_6_beamspace_cache:UnknownOption', 'Unknown option: %s', name);
    end
end
if ~any(strcmpi(opts.InputAzMode, {'global','delta'}))
    error('lookup_step11_6_beamspace_cache:InvalidInputAzMode', 'InputAzMode must be global or delta.');
end
end

function ang = wrap180_local(ang)
ang = mod(ang + 180, 360) - 180;
end
