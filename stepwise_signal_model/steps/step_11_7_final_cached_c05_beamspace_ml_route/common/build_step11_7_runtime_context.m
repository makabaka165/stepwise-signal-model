function [context, context_metadata] = build_step11_7_runtime_context(project_dir, result_dir, varargin)
%BUILD_STEP11_7_RUNTIME_CONTEXT Build the final Step11.7 backend context.
%
% The context integrates Step11.2 W, Step11.5 fixed C05, and a Step11.6
% canonical beamspace cache.  If a prior Step11.6 result is unavailable or
% its metadata does not cover the Step11.7 grid, this function rebuilds a
% cache with the same Step11.6 exact-grid cache builder.

if nargin < 1 || isempty(project_dir)
    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin < 2 || isempty(result_dir)
    result_dir = pwd;
end
opts = parse_opts_local(varargin{:});

cfg = sim_cfg();
cfg.beam.azSectorCenter = opts.default_center_az;
cfg.beam.azSteer = opts.default_center_az;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;
reg = 1e-10;

step11_2_dir = fullfile(project_dir, 'steps', 'step_11_2_beamspace_w_design');
step11_6_dir = fullfile(project_dir, 'steps', 'step_11_6_shared_center_rotatable_beamspace_manifold_cache');
step11_6_result_mat = fullfile(step11_6_dir, 'results_step11_6_shared_center_rotatable_beamspace_manifold_cache', 'step11_6_result.mat');

canonical_geometry = build_step11_6_canonical_geometry(cfg, 0);
[W, w_info] = build_recommended_w_from_step11_2(step11_2_dir, cfg, canonical_geometry.canonical_arr, ...
    'B', 7, 'Criterion', 'combined', 'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Reg', reg);
W_method = sprintf('greedy_%s_B%d', w_info.criterion, w_info.B);

[C05_policy_cfg, C05_config_table, stage2_reference] = build_step11_5_stage3_selected_c05_config(struct('topK_max', 7, 'tau', 0.02));
C05_policy_cfg.topK_max = 7;
C05_policy_cfg.tau = 0.02;

full_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
coarse_el_sep_deg_list = [0, 0.36, 0.72];
fine_el_sep_deg_list = [0, 0.24, 0.36, 0.48, 0.60, 0.72];
full_search_cfg = make_search_cfg_local(1.5, 1.2, 0.08, 0.12, full_el_sep_deg_list);
coarse_search_cfg = make_search_cfg_local(1.5, 1.2, 0.16, 0.24, coarse_el_sep_deg_list);
base_refine_cfg = make_refine_cfg_local(0.32, 0.48, 0.08, 0.12, fine_el_sep_deg_list);

cache_source = 'rebuilt_for_step11_7';
cache_loaded_from_step11_6 = false;
cache_rebuild_reason = '';
[delta_grid, el_grid] = step11_7_build_cache_union_grid(cfg, C05_policy_cfg, full_search_cfg, coarse_search_cfg, base_refine_cfg);

cache = [];
cache_metadata = [];
if exist(step11_6_result_mat, 'file') == 2
    loaded = load(step11_6_result_mat, 'cache', 'cache_metadata');
    if isfield(loaded, 'cache') && is_cache_compatible_local(loaded.cache, W_method, delta_grid, el_grid)
        cache = loaded.cache;
        if isfield(loaded, 'cache_metadata')
            cache_metadata = loaded.cache_metadata;
        else
            cache_metadata = make_metadata_from_cache_local(cache);
        end
        cache_source = 'loaded_from_step11_6_result';
        cache_loaded_from_step11_6 = true;
    else
        cache_rebuild_reason = 'step11_6_cache_missing_required_step11_7_grid_or_metadata';
    end
else
    cache_rebuild_reason = 'step11_6_result_mat_not_found';
end

if isempty(cache)
    [cache, cache_metadata] = build_step11_6_canonical_beamspace_cache(W, canonical_geometry, delta_grid, el_grid, cfg.arr.lambda, ...
        'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'WMethod', W_method);
end

context = struct();
context.cfg = cfg;
context.arrInfo = canonical_geometry.canonical_arr;
context.geometry = canonical_geometry;
context.W = W;
context.w_info = w_info;
context.cache = cache;
context.cache_metadata = cache_metadata;
context.manifold_opts = struct('phase_factor', phase_factor, 'phase_sign', phase_sign);
context.search_opts = struct('whitening_mode', 'white', 'reg', reg, 'cache_fallback_direct', true);
context.C05_policy_cfg = C05_policy_cfg;
context.C05_config_table = C05_config_table;
context.stage2_reference = stage2_reference;
context.full_search_cfg = full_search_cfg;
context.coarse_search_cfg = coarse_search_cfg;
context.base_refine_cfg = base_refine_cfg;
context.lambda = cfg.arr.lambda;
context.phase_factor = phase_factor;
context.phase_sign = phase_sign;
context.reg = reg;
context.W_method = W_method;
context.cache_source = cache_source;
context.cache_loaded_from_step11_6 = cache_loaded_from_step11_6;
context.cache_rebuild_reason = cache_rebuild_reason;
context.result_dir = result_dir;
context.supported_frontend_states = {'single_peak_in_scope','unresolved_local_cluster','controlled_pair2d_candidate'};
context.unsupported_frontend_states = {'two_separated_peaks_out_of_scope','weak_secondary_candidate','invalid_input','empty_detection'};
context.el_center_nominal = cfg.beam.elSectorCenter;
context.el_center_offset = 0.31;
context.L_default = 64;
context.base_seed = 20260609;

context_metadata = struct();
context_metadata.route_name = 'step11_7_final_cached_c05_beamspace_ml_route';
context_metadata.W_method = W_method;
context_metadata.B = size(W, 2);
context_metadata.N_elements = size(W, 1);
context_metadata.cache_type = cache.cache_type;
context_metadata.cache_source = cache_source;
context_metadata.cache_loaded_from_step11_6 = cache_loaded_from_step11_6;
context_metadata.cache_rebuild_reason = cache_rebuild_reason;
context_metadata.cache_lookup_mode = cache.default_lookup_mode;
context_metadata.cache_supports_interpolation = logical(cache.supports_interpolation);
context_metadata.cache_valid_center_rule = cache.valid_center_rule;
context_metadata.cache_memory_MB = cache.cache_memory_MB;
context_metadata.cache_build_once_time_sec = cache.cache_build_once_time_sec;
context_metadata.C05_config_id = C05_policy_cfg.config_id;
context_metadata.C05_config_name = C05_policy_cfg.config_name;
context_metadata.phase_factor = phase_factor;
context_metadata.phase_sign = phase_sign;
context_metadata.lambda = cfg.arr.lambda;
context_metadata.created_by = 'Step11.7';
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.default_center_az = 0;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_step11_7_runtime_context:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'defaultcenteraz'
            opts.default_center_az = value;
        otherwise
            error('build_step11_7_runtime_context:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function search_cfg = make_search_cfg_local(az_half_width, el_half_width, az_step, el_step, el_sep_deg_list)
search_cfg = struct('az_half_width', az_half_width, 'el_half_width', el_half_width, ...
    'az_step', az_step, 'el_step', el_step, 'el_sep_deg_list', el_sep_deg_list, ...
    'search_orientations', [1, -1]);
end

function refine_cfg = make_refine_cfg_local(local_az_half_width, local_el_center_half_width, fine_az_step, fine_el_step, fine_el_sep_deg_list)
refine_cfg = struct('local_az_half_width', local_az_half_width, ...
    'local_el_center_half_width', local_el_center_half_width, 'fine_az_step', fine_az_step, ...
    'fine_el_step', fine_el_step, 'fine_el_sep_deg_list', fine_el_sep_deg_list, ...
    'search_orientations', [1, -1]);
end

function compatible = is_cache_compatible_local(cache, W_method, delta_grid, el_grid)
compatible = isstruct(cache) && isfield(cache, 'cache_type') && strcmp(cache.cache_type, 'canonical_beamspace_G_cache') && ...
    isfield(cache, 'W_method') && strcmp(cache.W_method, W_method) && ...
    isfield(cache, 'valid_center_rule') && strcmp(cache.valid_center_rule, 'shared_center_nearest_column_canonical_order') && ...
    isfield(cache, 'supports_interpolation') && ~logical(cache.supports_interpolation) && ...
    isfield(cache, 'default_lookup_mode') && strcmp(cache.default_lookup_mode, 'exact_grid_lookup') && ...
    all(ismember(round(delta_grid(:).' * 1e10) / 1e10, round(cache.delta_az_grid_deg(:).' * 1e10) / 1e10)) && ...
    all(ismember(round(el_grid(:).' * 1e10) / 1e10, round(cache.el_grid_deg(:).' * 1e10) / 1e10));
end

function metadata = make_metadata_from_cache_local(cache)
metadata = struct();
metadata.cache_type = cache.cache_type;
metadata.W_method = cache.W_method;
metadata.B = cache.B;
metadata.N_elements = cache.N_elements;
metadata.N_delta_az = cache.N_delta_az;
metadata.N_el = cache.N_el;
metadata.phase_factor = cache.phase_factor;
metadata.phase_sign = cache.phase_sign;
metadata.lambda = cache.lambda;
metadata.cache_memory_MB = cache.cache_memory_MB;
metadata.cache_build_time_sec = cache.cache_build_once_time_sec;
metadata.supports_interpolation = false;
metadata.default_lookup_mode = cache.default_lookup_mode;
metadata.valid_center_rule = cache.valid_center_rule;
metadata.created_by = cache.created_by;
end
