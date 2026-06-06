function backend_cfg = build_step11_backend_config_from_frontend(frontend_out, varargin)
%BUILD_STEP11_BACKEND_CONFIG_FROM_FRONTEND Convert frontend prior to backend cfg.

if nargin < 1
    error('build_step11_backend_config_from_frontend:NotEnoughInputs', 'frontend_out is required.');
end
validate_frontend_out_local(frontend_out);
opts = parse_opts_local(varargin{:});
validate_opts_local(opts);

coarse_search_cfg = struct();
coarse_search_cfg.az_half_width = frontend_out.search_window.az_half_width_deg;
coarse_search_cfg.el_half_width = frontend_out.search_window.el_half_width_deg;
coarse_search_cfg.az_step = opts.coarse_az_step;
coarse_search_cfg.el_step = opts.coarse_el_step;
coarse_search_cfg.el_sep_deg_list = opts.coarse_el_sep_deg_list;
coarse_search_cfg.search_orientations = [1, -1];

coarse_grid_cfg = make_grid_cfg_local(frontend_out.coarse_az_deg, ...
    frontend_out.coarse_el_deg, coarse_search_cfg);

refine_cfg = struct();
refine_cfg.local_az_half_width = opts.local_az_half_width;
refine_cfg.local_el_center_half_width = opts.local_el_center_half_width;
refine_cfg.fine_az_step = opts.fine_az_step;
refine_cfg.fine_el_step = opts.fine_el_step;
refine_cfg.fine_el_sep_deg_list = opts.fine_el_sep_deg_list;
refine_cfg.search_orientations = [1, -1];
refine_cfg.az_global_bounds = coarse_grid_cfg.az_bounds;
refine_cfg.el_global_bounds = coarse_grid_cfg.el_bounds;

backend_cfg = struct();
backend_cfg.interface_version = 'step11_4_backend_cfg_v1';
backend_cfg.coarse_center_deg = frontend_out.coarse_center_deg;
backend_cfg.coarse_search_cfg = coarse_search_cfg;
backend_cfg.coarse_grid_cfg = coarse_grid_cfg;
backend_cfg.refine_cfg = refine_cfg;
backend_cfg.manifold_opts = struct('phase_factor', opts.phase_factor, 'phase_sign', opts.phase_sign);
backend_cfg.search_opts = struct('whitening_mode', opts.whitening_mode, 'reg', opts.reg);
backend_cfg.topK = opts.topK;
backend_cfg.truth_policy = 'frontend coarse center is observable; truth may be carried only for offline metrics';
backend_cfg.source_frontend_method = frontend_out.method;
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.topK = 3;
opts.coarse_az_step = 0.16;
opts.coarse_el_step = 0.24;
opts.coarse_el_sep_deg_list = [0, 0.36, 0.72];
opts.fine_az_step = 0.08;
opts.fine_el_step = 0.12;
opts.local_az_half_width = 0.32;
opts.local_el_center_half_width = 0.48;
opts.fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.whitening_mode = 'white';
opts.reg = 1e-10;

if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_step11_backend_config_from_frontend:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'topk'
            opts.topK = value;
        case 'coarseazstep'
            opts.coarse_az_step = value;
        case 'coarseelstep'
            opts.coarse_el_step = value;
        case 'coarseelsepdeglist'
            opts.coarse_el_sep_deg_list = value;
        case 'fineazstep'
            opts.fine_az_step = value;
        case 'fineelstep'
            opts.fine_el_step = value;
        case 'localazhalfwidth'
            opts.local_az_half_width = value;
        case 'localelcenterhalfwidth'
            opts.local_el_center_half_width = value;
        case 'fineelsepdeglist'
            opts.fine_el_sep_deg_list = value;
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'whiteningmode'
            opts.whitening_mode = char(value);
        case 'reg'
            opts.reg = value;
        otherwise
            error('build_step11_backend_config_from_frontend:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function validate_opts_local(opts)
positive_scalars = {'topK','coarse_az_step','coarse_el_step','fine_az_step', ...
    'fine_el_step','local_az_half_width','local_el_center_half_width','phase_factor','reg'};
for idx = 1:numel(positive_scalars)
    field = positive_scalars{idx};
    value = opts.(field);
    if ~(isscalar(value) && isfinite(value) && value > 0)
        error('build_step11_backend_config_from_frontend:InvalidOption', '%s must be positive finite scalar.', field);
    end
end
if opts.phase_sign ~= 1 && opts.phase_sign ~= -1
    error('build_step11_backend_config_from_frontend:InvalidPhaseSign', 'PhaseSign must be +1 or -1.');
end
if isempty(opts.coarse_el_sep_deg_list) || any(~isfinite(opts.coarse_el_sep_deg_list(:)))
    error('build_step11_backend_config_from_frontend:InvalidCoarseElSep', ...
        'CoarseElSepDegList must contain finite values.');
end
if isempty(opts.fine_el_sep_deg_list) || any(~isfinite(opts.fine_el_sep_deg_list(:)))
    error('build_step11_backend_config_from_frontend:InvalidFineElSep', ...
        'FineElSepDegList must contain finite values.');
end
end

function validate_frontend_out_local(frontend_out)
required = {'coarse_az_deg','coarse_el_deg','coarse_center_deg','search_window','method'};
for idx = 1:numel(required)
    if ~isfield(frontend_out, required{idx})
        error('build_step11_backend_config_from_frontend:MissingFrontendField', ...
            'frontend_out.%s is required.', required{idx});
    end
end
if numel(frontend_out.coarse_center_deg) ~= 2
    error('build_step11_backend_config_from_frontend:InvalidCoarseCenter', ...
        'frontend_out.coarse_center_deg must have two values.');
end
end

function grid_cfg = make_grid_cfg_local(az_center, el_center, search_cfg)
az_bounds = az_center + [-search_cfg.az_half_width, search_cfg.az_half_width];
el_bounds = el_center + [-search_cfg.el_half_width, search_cfg.el_half_width];
az_grid = unique(round((az_bounds(1):search_cfg.az_step:az_bounds(2)) * 1e10) / 1e10);
el_grid = unique(round((el_bounds(1):search_cfg.el_step:el_bounds(2)) * 1e10) / 1e10);
el_sep_deg_list = unique(round(search_cfg.el_sep_deg_list(:).' * 1e10) / 1e10);

num_oriented_sep = 0;
for idx = 1:numel(el_sep_deg_list)
    if abs(el_sep_deg_list(idx)) < 1e-12
        num_oriented_sep = num_oriented_sep + 1;
    else
        num_oriented_sep = num_oriented_sep + numel(search_cfg.search_orientations);
    end
end

grid_cfg = struct();
grid_cfg.az_grid = az_grid;
grid_cfg.el_grid = el_grid;
grid_cfg.el_center_grid = el_grid;
grid_cfg.az_step = search_cfg.az_step;
grid_cfg.el_step = search_cfg.el_step;
grid_cfg.el_sep_deg_list = el_sep_deg_list;
grid_cfg.search_orientations = search_cfg.search_orientations;
grid_cfg.az_bounds = az_bounds;
grid_cfg.el_bounds = el_bounds;
grid_cfg.estimated_num_candidates = nchoosek(numel(az_grid), 2) * numel(el_grid) * num_oriented_sep;
grid_cfg.az_center = az_center;
grid_cfg.el_center = el_center;
grid_cfg.mode = 'degree_based_el_sep';
grid_cfg.legacy_index_based_fallback = false;
grid_cfg.legacy_note = '';
end
