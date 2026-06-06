function [est, debug] = run_step11_pair2d_backend_from_interface(backend_in, x, y, z, lambda)
%RUN_STEP11_PAIR2D_BACKEND_FROM_INTERFACE Run Step11.3 backend from backend_in.

if nargin < 5
    error('run_step11_pair2d_backend_from_interface:NotEnoughInputs', ...
        'backend_in, x, y, z, and lambda are required.');
end
validate_backend_in_local(backend_in);
if exist('search_pair2d_coarse_to_fine', 'file') ~= 2
    error('run_step11_pair2d_backend_from_interface:MissingSearchFunction', ...
        'search_pair2d_coarse_to_fine is not on the MATLAB path.');
end

cfg = struct();
cfg.coarse_grid_cfg = backend_in.coarse_grid_cfg;
cfg.refine_cfg = backend_in.refine_cfg;
cfg.manifold_opts = backend_in.manifold_opts;
cfg.search_opts = backend_in.search_opts;
cfg.topK = backend_in.topK;

[est, debug] = search_pair2d_coarse_to_fine(backend_in.Z, backend_in.W, x, y, z, lambda, cfg);
end

function validate_backend_in_local(backend_in)
required = {'Z','W','coarse_grid_cfg','refine_cfg','manifold_opts','search_opts','topK'};
for idx = 1:numel(required)
    if ~isfield(backend_in, required{idx})
        error('run_step11_pair2d_backend_from_interface:MissingBackendInField', ...
            'backend_in.%s is required.', required{idx});
    end
end
if size(backend_in.Z, 1) ~= size(backend_in.W, 2)
    error('run_step11_pair2d_backend_from_interface:DimensionMismatch', ...
        'size(backend_in.Z,1) must equal size(backend_in.W,2).');
end
end
