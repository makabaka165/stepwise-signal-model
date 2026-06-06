function frontend_out = make_frontend_out_struct(varargin)
%MAKE_FRONTEND_OUT_STRUCT Build the Step11.4 frontend_out contract object.

opts = parse_opts_local(varargin{:});
validate_opts_local(opts);

frontend_out = struct();
frontend_out.interface_version = 'step11_4_frontend_out_v1';
frontend_out.coarse_az_deg = opts.coarse_az_deg;
frontend_out.coarse_el_deg = opts.coarse_el_deg;
frontend_out.coarse_center_deg = [opts.coarse_az_deg, opts.coarse_el_deg];
frontend_out.search_window = opts.search_window;
frontend_out.beam_energy = opts.beam_energy;
frontend_out.cluster_indicator = opts.cluster_indicator;
frontend_out.method = opts.method;
frontend_out.quality = opts.quality;
frontend_out.truth_for_metrics = opts.truth_for_metrics;
frontend_out.truth_is_for_metrics_only = true;
frontend_out.created_by = 'make_frontend_out_struct';
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.coarse_az_deg = NaN;
opts.coarse_el_deg = NaN;
opts.search_window = struct('az_half_width_deg', 1.5, 'el_half_width_deg', 1.2);
opts.beam_energy = [];
opts.cluster_indicator = struct('beam_spread_indicator', NaN, ...
    'local_peak_count', NaN, 'cluster_score', NaN);
opts.method = 'unspecified';
opts.quality = struct();
opts.truth_for_metrics = struct();

if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('make_frontend_out_struct:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'coarseazdeg'
            opts.coarse_az_deg = value;
        case 'coarseeldeg'
            opts.coarse_el_deg = value;
        case 'searchwindow'
            opts.search_window = value;
        case 'beamenergy'
            opts.beam_energy = value;
        case 'clusterindicator'
            opts.cluster_indicator = value;
        case 'method'
            opts.method = char(value);
        case 'quality'
            opts.quality = value;
        case 'truthformetrics'
            opts.truth_for_metrics = value;
        otherwise
            error('make_frontend_out_struct:UnknownOption', 'Unknown option: %s', name);
    end
end
end
function validate_opts_local(opts)
if ~(isscalar(opts.coarse_az_deg) && isfinite(opts.coarse_az_deg))
    error('make_frontend_out_struct:InvalidCoarseAz', 'CoarseAzDeg must be a finite scalar.');
end
if ~(isscalar(opts.coarse_el_deg) && isfinite(opts.coarse_el_deg))
    error('make_frontend_out_struct:InvalidCoarseEl', 'CoarseElDeg must be a finite scalar.');
end
if ~isstruct(opts.search_window)
    error('make_frontend_out_struct:InvalidSearchWindow', 'SearchWindow must be a struct.');
end
required_window_fields = {'az_half_width_deg','el_half_width_deg'};
for idx = 1:numel(required_window_fields)
    field = required_window_fields{idx};
    if ~isfield(opts.search_window, field)
        error('make_frontend_out_struct:MissingSearchWindowField', 'SearchWindow.%s is required.', field);
    end
    value = opts.search_window.(field);
    if ~(isscalar(value) && isfinite(value) && value > 0)
        error('make_frontend_out_struct:InvalidSearchWindowField', ...
            'SearchWindow.%s must be a positive finite scalar.', field);
    end
end
if ~isempty(opts.beam_energy) && (~isnumeric(opts.beam_energy) || any(~isfinite(opts.beam_energy(:))))
    error('make_frontend_out_struct:InvalidBeamEnergy', 'BeamEnergy must be finite numeric when non-empty.');
end
if ~isstruct(opts.cluster_indicator)
    error('make_frontend_out_struct:InvalidClusterIndicator', 'ClusterIndicator must be a struct.');
end
if ~(ischar(opts.method) || isstring(opts.method)) || strlength(string(opts.method)) == 0
    error('make_frontend_out_struct:InvalidMethod', 'Method must be non-empty text.');
end
if ~isstruct(opts.quality)
    error('make_frontend_out_struct:InvalidQuality', 'Quality must be a struct.');
end
if ~isstruct(opts.truth_for_metrics)
    error('make_frontend_out_struct:InvalidTruthForMetrics', 'TruthForMetrics must be a struct.');
end
end
