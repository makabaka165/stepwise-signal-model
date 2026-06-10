function [cache, cache_metadata] = build_step11_6_canonical_beamspace_cache(W, geom, delta_az_grid_deg, el_grid_deg, lambda, varargin)
%BUILD_STEP11_6_CANONICAL_BEAMSPACE_CACHE Precompute canonical G(delta,el)=W'*a(delta,el).
%
% The cache stores the beamspace manifold on an exact canonical local grid.
% It does not interpolate.  Element-domain steering is intentionally built
% only while constructing G to keep the persistent cache small.

if nargin < 5
    error('build_step11_6_canonical_beamspace_cache:NotEnoughInputs', ...
        'W, geom, delta_az_grid_deg, el_grid_deg, and lambda are required.');
end
opts = parse_opts_local(varargin{:});
delta_az_grid_deg = unique(round(delta_az_grid_deg(:).' * 1e10) / 1e10);
el_grid_deg = unique(round(el_grid_deg(:).' * 1e10) / 1e10);
if isempty(delta_az_grid_deg) || any(~isfinite(delta_az_grid_deg))
    error('build_step11_6_canonical_beamspace_cache:InvalidDeltaGrid', 'delta_az_grid_deg must be finite and non-empty.');
end
if isempty(el_grid_deg) || any(~isfinite(el_grid_deg))
    error('build_step11_6_canonical_beamspace_cache:InvalidElGrid', 'el_grid_deg must be finite and non-empty.');
end
if size(W, 1) ~= geom.N_elements
    error('build_step11_6_canonical_beamspace_cache:WElementMismatch', 'size(W,1) must match canonical element count.');
end

x = geom.x_canonical(:);
y = geom.y_canonical(:);
z = geom.z_canonical(:);
B = size(W, 2);
N_delta = numel(delta_az_grid_deg);
N_el = numel(el_grid_deg);
G_grid = complex(zeros(B, N_delta, N_el));

tic;
for iEl = 1:N_el
    A_el = complex(zeros(numel(x), N_delta));
    for iAz = 1:N_delta
        A_el(:, iAz) = build_cyl_steering_vec(x, y, z, delta_az_grid_deg(iAz), el_grid_deg(iEl), lambda, ...
            'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
    end
    G_grid(:, :, iEl) = W' * A_el;
end
cache_build_time_sec = toc;

cache = struct();
cache.cache_type = 'canonical_beamspace_G_cache';
cache.method_name_en = 'Shared-Center Rotatable Beamspace Manifold Cache for Cylindrical-Array Beamspace ML';
cache.method_name_zh = '基于 shared-center 圆柱阵旋转等价性的可复用波束域流形缓存方法';
cache.delta_az_grid_deg = delta_az_grid_deg;
cache.el_grid_deg = el_grid_deg;
cache.G_grid = G_grid;
cache.B = B;
cache.N_elements = geom.N_elements;
cache.N_delta_az = N_delta;
cache.N_el = N_el;
cache.lambda = lambda;
cache.phase_factor = opts.phase_factor;
cache.phase_sign = opts.phase_sign;
cache.supports_interpolation = false;
cache.default_lookup_mode = 'exact_grid_lookup';
cache.valid_center_rule = 'shared_center_nearest_column_canonical_order';
cache.W_method = opts.W_method;
cache.cache_build_once_time_sec = cache_build_time_sec;
cache.cache_memory_MB = bytes_to_mb_local(numel(G_grid) * 16);
cache.canonical_center_column = geom.canonical_center_column;
cache.canonical_actual_center_az_deg = geom.canonical_actual_center_az_deg;
cache.created_by = 'Step11.6';
cache.created_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');

cache_metadata = struct();
cache_metadata.cache_type = cache.cache_type;
cache_metadata.W_method = cache.W_method;
cache_metadata.B = cache.B;
cache_metadata.N_elements = cache.N_elements;
cache_metadata.N_delta_az = cache.N_delta_az;
cache_metadata.N_el = cache.N_el;
cache_metadata.delta_az_min = min(delta_az_grid_deg);
cache_metadata.delta_az_max = max(delta_az_grid_deg);
cache_metadata.delta_az_step = infer_constant_step_local(delta_az_grid_deg);
cache_metadata.delta_az_list_text = numeric_list_text_local(delta_az_grid_deg);
cache_metadata.el_min = min(el_grid_deg);
cache_metadata.el_max = max(el_grid_deg);
cache_metadata.el_step = infer_constant_step_local(el_grid_deg);
cache_metadata.el_list_text = numeric_list_text_local(el_grid_deg);
cache_metadata.phase_factor = cache.phase_factor;
cache_metadata.phase_sign = cache.phase_sign;
cache_metadata.lambda = cache.lambda;
cache_metadata.cache_memory_MB = cache.cache_memory_MB;
cache_metadata.cache_build_time_sec = cache.cache_build_once_time_sec;
cache_metadata.supports_interpolation = false;
cache_metadata.default_lookup_mode = cache.default_lookup_mode;
cache_metadata.valid_center_rule = cache.valid_center_rule;
cache_metadata.created_by = cache.created_by;
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.W_method = 'greedy_combined_B7';
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_step11_6_canonical_beamspace_cache:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'wmethod'
            opts.W_method = char(value);
        otherwise
            error('build_step11_6_canonical_beamspace_cache:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function mb = bytes_to_mb_local(bytes)
mb = double(bytes) / 1024 / 1024;
end

function step = infer_constant_step_local(values)
values = unique(round(values(:).' * 1e10) / 1e10);
if numel(values) < 2
    step = NaN;
    return;
end
d = diff(values);
if max(abs(d - median(d))) <= 1e-10
    step = median(d);
else
    step = NaN;
end
end

function text = numeric_list_text_local(values)
values = values(:).';
if numel(values) > 80
    values_show = [values(1:20), NaN, values(end-19:end)];
else
    values_show = values;
end
parts = cell(1, numel(values_show));
for idx = 1:numel(values_show)
    if isnan(values_show(idx))
        parts{idx} = '...';
    else
        parts{idx} = sprintf('%.12g', values_show(idx));
    end
end
text = ['[', strjoin(parts, ','), ']'];
end
