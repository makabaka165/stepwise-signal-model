function backend_in = make_backend_in_from_frontend_out(frontend_out, Y, W, varargin)
%MAKE_BACKEND_IN_FROM_FRONTEND_OUT Build the Step11.4 backend_in contract object.

if nargin < 3
    error('make_backend_in_from_frontend_out:NotEnoughInputs', 'frontend_out, Y, and W are required.');
end
opts = parse_opts_local(varargin{:});
validate_numeric_inputs_local(Y, W);
if isempty(opts.backend_cfg)
    opts.backend_cfg = build_step11_backend_config_from_frontend(frontend_out);
end
validate_backend_cfg_local(opts.backend_cfg);

backend_in = struct();
backend_in.interface_version = 'step11_4_backend_in_v1';
backend_in.Y = Y;
backend_in.W = W;
backend_in.Z = W' * Y;
backend_in.coarse_center_deg = opts.backend_cfg.coarse_center_deg;
backend_in.backend_cfg = opts.backend_cfg;
backend_in.coarse_grid_cfg = opts.backend_cfg.coarse_grid_cfg;
backend_in.refine_cfg = opts.backend_cfg.refine_cfg;
backend_in.manifold_opts = opts.backend_cfg.manifold_opts;
backend_in.search_opts = opts.backend_cfg.search_opts;
backend_in.topK = opts.backend_cfg.topK;
backend_in.metadata = struct();
backend_in.metadata.frontend_interface_version = frontend_out.interface_version;
backend_in.metadata.frontend_method = frontend_out.method;
backend_in.metadata.truth_not_used_for_coarse_center = true;
backend_in.metadata.created_by = 'make_backend_in_from_frontend_out';
backend_in.backend_ready_flag = true;
end

function opts = parse_opts_local(varargin)
opts = struct('backend_cfg', []);
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('make_backend_in_from_frontend_out:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'backendcfg'
            opts.backend_cfg = value;
        otherwise
            error('make_backend_in_from_frontend_out:UnknownOption', 'Unknown option: %s', name);
    end
end
end
function validate_numeric_inputs_local(Y, W)
if ~isnumeric(Y) || ndims(Y) ~= 2 || isempty(Y) || any(~isfinite(Y(:)))
    error('make_backend_in_from_frontend_out:InvalidY', 'Y must be a finite numeric 2D matrix.');
end
if ~isnumeric(W) || ndims(W) ~= 2 || isempty(W) || any(~isfinite(W(:)))
    error('make_backend_in_from_frontend_out:InvalidW', 'W must be a finite numeric 2D matrix.');
end
if size(W, 1) ~= size(Y, 1)
    error('make_backend_in_from_frontend_out:DimensionMismatch', ...
        'size(W,1) must equal size(Y,1).');
end
end

function validate_backend_cfg_local(backend_cfg)
required = {'coarse_center_deg','coarse_grid_cfg','refine_cfg','manifold_opts','search_opts','topK'};
for idx = 1:numel(required)
    if ~isfield(backend_cfg, required{idx})
        error('make_backend_in_from_frontend_out:MissingBackendCfgField', ...
            'backend_cfg.%s is required.', required{idx});
    end
end
if numel(backend_cfg.coarse_center_deg) ~= 2 || any(~isfinite(backend_cfg.coarse_center_deg(:)))
    error('make_backend_in_from_frontend_out:InvalidCoarseCenter', ...
        'backend_cfg.coarse_center_deg must have two finite values.');
end
end
