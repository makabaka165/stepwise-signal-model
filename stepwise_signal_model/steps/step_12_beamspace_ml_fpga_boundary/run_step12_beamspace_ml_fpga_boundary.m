clc
clear
close all

cfg12 = make_step12_cfg_local();
[cfg12, log_lines] = init_step12_paths_local(cfg12);
adapter_info = inspect_step11_adapter_local(cfg12);
modes = build_step12_quant_modes_local();

log_lines = append_log_local(log_lines, 'Step12 starts');
log_lines = append_log_local(log_lines, 'Quick mode: %d', cfg12.quick_mode_flag);
log_lines = append_log_local(log_lines, 'Step11 adapter found: %d', adapter_info.step11_adapter_found_flag);

obs = repmat(make_empty_obs_local(), 0, 1);
adapter_error = [];
if adapter_info.step11_adapter_found_flag
    try
        [obs, adapter_info] = load_or_run_step11_ml_observations_local(cfg12, adapter_info);
        log_lines = append_log_local(log_lines, 'Loaded Step11 observations: %d', numel(obs));
    catch ME
        adapter_error = ME;
        adapter_info.step11_adapter_found_flag = 0;
        adapter_info.blocker_if_any = 'step11_adapter_runtime_error';
        adapter_info.error_message = ME.message;
        log_lines = append_log_local(log_lines, 'Adapter runtime error: %s', ME.message);
    end
end

if isempty(obs)
    [trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, storage_tbl, ...
        bandwidth_tbl, worst_tbl, recommendation_tbl] = build_step12_blocker_outputs_local(cfg12, adapter_info);
    plot_paths = plot_step12_results_local(trial_tbl, summary_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, cfg12);
else
    [trial_tbl, topk_tbl, score_gap_tbl] = run_step12_quantization_trials_local(obs, modes, cfg12);
    summary_tbl = build_step12_summary_table_local(trial_tbl, modes, cfg12);
    best_info = select_best_fixed_point_mode_local(summary_tbl, modes);
    storage_tbl = build_step12_storage_estimate_local(obs(1), best_info, cfg12);
    bandwidth_tbl = build_step12_bandwidth_estimate_local(obs(1), best_info, cfg12);
    keypoints_tbl = build_step12_keypoints_local(summary_tbl, storage_tbl, bandwidth_tbl, adapter_info, best_info, cfg12);
    worst_tbl = build_step12_worst_cases_local(trial_tbl);
    recommendation_tbl = build_step12_recommendations_local(keypoints_tbl);
    plot_paths = plot_step12_results_local(trial_tbl, summary_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, cfg12);
end

write_step12_tables_local(cfg12, trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, ...
    storage_tbl, bandwidth_tbl, worst_tbl, recommendation_tbl);
doc_path = write_step12_record_doc_local(cfg12, adapter_info, summary_tbl, keypoints_tbl, storage_tbl, bandwidth_tbl, worst_tbl);
adapter_info_light = make_adapter_info_light_local(adapter_info);
mat_light_path = fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_result_light.mat');
save(mat_light_path, 'cfg12', 'adapter_info_light', 'modes', 'summary_tbl', ...
    'keypoints_tbl', 'score_gap_tbl', 'topk_tbl', 'storage_tbl', 'bandwidth_tbl', ...
    'worst_tbl', 'recommendation_tbl', 'plot_paths', 'doc_path');
mat_full_path = '';
if cfg12.save_full_mat_flag
    mat_full_path = fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_result_full.mat');
    save(mat_full_path, 'cfg12', 'adapter_info', 'modes', 'obs', 'trial_tbl', 'summary_tbl', ...
        'keypoints_tbl', 'score_gap_tbl', 'topk_tbl', 'storage_tbl', 'bandwidth_tbl', ...
        'worst_tbl', 'recommendation_tbl', 'plot_paths', 'doc_path', '-v7.3');
end
manifest_path = write_step12_mat_manifest_local(cfg12, mat_light_path, mat_full_path);

log_lines = append_log_local(log_lines, 'Wrote light MAT: %s', mat_light_path);
if cfg12.save_full_mat_flag
    log_lines = append_log_local(log_lines, 'Wrote full MAT: %s', mat_full_path);
else
    log_lines = append_log_local(log_lines, 'Full MAT not saved; set STEP12_SAVE_FULL_MAT=1 to regenerate locally.');
end
log_lines = append_log_local(log_lines, 'Wrote MAT manifest: %s', manifest_path);
log_lines = append_log_local(log_lines, 'Wrote record doc: %s', doc_path);
write_log_local(fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary.log'), log_lines);

fprintf('Step12 beamspace ML FPGA boundary validation complete.\n');
fprintf('Result directory: %s\n', cfg12.result_dir);

if ~isempty(adapter_error)
    fprintf('Step11 adapter runtime error was recorded: %s\n', adapter_error.message);
end

function cfg12 = make_step12_cfg_local()
cfg12 = struct();
cfg12.step_name = 'step_12_beamspace_ml_fpga_boundary';
cfg12.result_dir_name = 'results_step12_beamspace_ml_fpga_boundary';
cfg12.uses_step89_results_flag = 0;
cfg12.score_direction = 'higher_is_better';
cfg12.score_direction_inferred_flag = 0;
cfg12.topK_list = [1, 3, 5, 10];
cfg12.topK_default = 10;
cfg12.reliable_margin_threshold = 1e-3;
cfg12.weak_margin_threshold = 1e-4;
cfg12.max_kendall_n = 300;
cfg12.default_component_bits = 16;
cfg12.quick_mode_flag = strcmp(getenv('STEP12_QUICK_MODE'), '1');
cfg12.save_full_mat_flag = strcmp(getenv('STEP12_SAVE_FULL_MAT'), '1');
if cfg12.quick_mode_flag
    cfg12.center_az_list = 0;
    cfg12.scenario_limit = 2;
    cfg12.trials_per_scenario = 1;
    cfg12.formal_trials_per_scenario = NaN;
else
    cfg12.center_az_list = [0, 4, 8, 15];
    cfg12.scenario_limit = Inf;
    formal_trials = str2double(getenv('STEP12_FORMAL_TRIALS_PER_SCENARIO'));
    if isnan(formal_trials)
        formal_trials = 30;
    end
    cfg12.formal_trials_per_scenario = max(1, floor(formal_trials));
    cfg12.trials_per_scenario = cfg12.formal_trials_per_scenario;
end
cfg12.rng_seed = 20260611;
cfg12.formal_trial_count = 0;
cfg12.step11_entry = 'step11_7_final_cached_c05_beamspace_ml_backend';
cfg12.step11_score_function = 'beamspace_dml_score';
cfg12.step11_adapter_note = ['Step12 uses Step11.7 final backend/context for W, cache, Z, policy ', ...
    'and Step11.1 beamspace_dml_score / Step11.3 vectorized score identity for candidate scores.'];
end

function [cfg12, log_lines] = init_step12_paths_local(cfg12)
script_path = mfilename('fullpath');
if isempty(script_path)
    step_dir = pwd;
else
    step_dir = fileparts(script_path);
end
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
cfg12.step_dir = step_dir;
cfg12.steps_dir = steps_dir;
cfg12.project_dir = project_dir;
cfg12.result_dir = fullfile(step_dir, cfg12.result_dir_name);
if exist(cfg12.result_dir, 'dir') ~= 7
    mkdir(cfg12.result_dir);
end

setup_path = fullfile(project_dir, 'setup_paths.m');
if exist(setup_path, 'file') == 2
    run(setup_path);
end
addpath(fullfile(project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_2_beamspace_w_design', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_3_beamspace_ml_search_acceleration', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_5_likelihood_uncertainty_adaptive_beamspace_ml_search', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_6_shared_center_rotatable_beamspace_manifold_cache', 'common'));
addpath(fullfile(project_dir, 'steps', 'step_11_7_final_cached_c05_beamspace_ml_route', 'common'));
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

log_lines = {};
log_lines = append_log_local(log_lines, 'Script: %s', script_path);
log_lines = append_log_local(log_lines, 'Project directory: %s', project_dir);
log_lines = append_log_local(log_lines, 'Result directory: %s', cfg12.result_dir);
end

function adapter_info = inspect_step11_adapter_local(cfg12)
required_files = { ...
    fullfile(cfg12.project_dir, 'steps', 'step_11_7_final_cached_c05_beamspace_ml_route', 'common', 'step11_7_final_cached_c05_beamspace_ml_backend.m'), ...
    fullfile(cfg12.project_dir, 'steps', 'step_11_7_final_cached_c05_beamspace_ml_route', 'common', 'build_step11_7_runtime_context.m'), ...
    fullfile(cfg12.project_dir, 'steps', 'step_11_7_final_cached_c05_beamspace_ml_route', 'common', 'build_step11_7_frontend_like_input.m'), ...
    fullfile(cfg12.project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common', 'beamspace_dml_score.m'), ...
    fullfile(cfg12.project_dir, 'steps', 'step_11_1_beamspace_ml_validation', 'common', 'apply_beamspace_whitening.m'), ...
    fullfile(cfg12.project_dir, 'steps', 'step_11_6_shared_center_rotatable_beamspace_manifold_cache', 'common', 'lookup_step11_6_beamspace_cache.m')};
missing = {};
for idx = 1:numel(required_files)
    if exist(required_files{idx}, 'file') ~= 2
        missing{end + 1, 1} = required_files{idx}; %#ok<AGROW>
    end
end
score_ok = exist(cfg12.step11_score_function, 'file') == 2;
backend_ok = exist(cfg12.step11_entry, 'file') == 2;
adapter_info = struct();
adapter_info.step11_adapter_found_flag = isempty(missing) && score_ok && backend_ok;
adapter_info.uses_step89_results_flag = 0;
adapter_info.entry_function = cfg12.step11_entry;
adapter_info.score_function = cfg12.step11_score_function;
adapter_info.context_function = 'build_step11_7_runtime_context';
adapter_info.input_function = 'build_step11_7_frontend_like_input';
adapter_info.score_objective = 'J(Theta)=trace(P_G Z Z''), with Step11 whitening mode from context.search_opts';
adapter_info.candidate_scope = 'Step11.7 C05 coarse-stage controlled pair2d candidate table';
adapter_info.blocker_if_any = 'none';
adapter_info.error_message = '';
adapter_info.missing_files = missing;
if ~adapter_info.step11_adapter_found_flag
    adapter_info.blocker_if_any = 'step11_score_function_not_exposed';
    if ~score_ok
        adapter_info.error_message = 'beamspace_dml_score was not found on the MATLAB path';
    elseif ~backend_ok
        adapter_info.error_message = 'Step11.7 final backend was not found on the MATLAB path';
    elseif ~isempty(missing)
        adapter_info.error_message = strjoin(missing(:).', '; ');
    end
end
end

function modes = build_step12_quant_modes_local()
rows = {};
rows{end + 1} = make_mode_local('double_baseline', false, false, false, NaN, NaN, NaN, NaN, NaN, false);
rows{end + 1} = make_mode_local('float32_all', false, false, true, NaN, NaN, NaN, NaN, NaN, false);
rows{end + 1} = make_mode_local('W_int16_only', true, false, false, 16, NaN, NaN, NaN, NaN, false);
rows{end + 1} = make_mode_local('Gcache_int16_only', true, false, false, NaN, 16, NaN, NaN, NaN, false);
rows{end + 1} = make_mode_local('Z_int16_only', true, false, false, NaN, NaN, 16, NaN, NaN, false);
rows{end + 1} = make_mode_local('Rz_int18_only', true, false, false, NaN, NaN, NaN, 18, NaN, false);
rows{end + 1} = make_mode_local('combined_int16', true, true, false, 16, 16, 16, 16, 16, false);
rows{end + 1} = make_mode_local('combined_int18', true, true, false, 18, 18, 18, 18, 18, false);
rows{end + 1} = make_mode_local('combined_int24', true, true, false, 24, 24, 24, 24, 24, false);
rows{end + 1} = make_mode_local('mixed_Z16_G24_score_float', false, false, false, NaN, 24, 16, NaN, NaN, true);
rows{end + 1} = make_mode_local('mixed_Z16_G24_Rz24', true, true, false, NaN, 24, 16, 24, 24, false);
rows{end + 1} = make_mode_local('combined_int14', true, true, false, 14, 14, 14, 14, 14, false);
rows{end + 1} = make_mode_local('Gcache_int24_only', true, false, false, NaN, 24, NaN, NaN, NaN, false);
rows{end + 1} = make_mode_local('W_int18_G24_Z16', true, true, false, 18, 24, 16, NaN, 24, false);
modes = [rows{:}];
end

function mode = make_mode_local(name, is_fixed, recommendation_candidate, is_float_reference, W_bits, G_bits, Z_bits, Rz_bits, score_bits, score_float)
mode = struct();
mode.name = name;
mode.is_fixed_candidate = logical(is_fixed);
mode.is_recommendation_candidate = logical(recommendation_candidate);
mode.is_float_reference = logical(is_float_reference);
mode.W_bits = W_bits;
mode.Gcache_bits = G_bits;
mode.Z_bits = Z_bits;
mode.Rz_bits = Rz_bits;
mode.score_bits = score_bits;
mode.score_float = logical(score_float);
mode.storage_component_bits = max([finite_or_zero_local(W_bits), finite_or_zero_local(G_bits), ...
    finite_or_zero_local(Z_bits), finite_or_zero_local(Rz_bits), finite_or_zero_local(score_bits), 16]);
end

function [obs, adapter_info] = load_or_run_step11_ml_observations_local(cfg12, adapter_info)
rng(cfg12.rng_seed, 'twister');
[context, context_metadata] = build_step11_7_runtime_context(cfg12.project_dir, cfg12.result_dir, 'DefaultCenterAz', 0);
scenarios = build_step12_scenarios_local();
if isfinite(cfg12.scenario_limit)
    scenario_count = min(cfg12.scenario_limit, numel(scenarios));
else
    scenario_count = numel(scenarios);
end
obs = repmat(make_empty_obs_local(), 0, 1);
trial_index = 0;
for iCenter = 1:numel(cfg12.center_az_list)
    center_az = cfg12.center_az_list(iCenter);
    for iScenario = 1:scenario_count
        scenario = scenarios(iScenario);
        for iTrial = 1:cfg12.trials_per_scenario
            trial_index = trial_index + 1;
            [input, truth, input_meta] = build_step11_7_frontend_like_input(context, scenario, center_az, iTrial, ...
                'FrontendState', 'controlled_pair2d_candidate', 'L', context.L_default, ...
                'CenterIndex', iCenter, 'ScenarioIndex', iScenario);
            backend_opts = struct('use_cache', true, 'run_direct_reference', false, 'allow_cache_fallback', true, 'runtime_timing', false);
            out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, backend_opts);
            obs_now = build_step12_observation_local(trial_index, scenario, iCenter, iScenario, iTrial, ...
                input, truth, input_meta, out, context, context_metadata, cfg12);
            obs(end + 1, 1) = obs_now; %#ok<AGROW>
        end
    end
end
adapter_info.context_metadata = context_metadata;
adapter_info.cache_memory_MB_reference = context.cache.cache_memory_MB;
adapter_info.observation_count = numel(obs);
end

function scenarios = build_step12_scenarios_local()
scenarios = [ ...
    make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30); ...
    make_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30); ...
    make_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30); ...
    make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30); ...
    make_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20)];
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db)
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db);
end

function obs = make_empty_obs_local()
obs = struct();
obs.trial_index = NaN;
obs.scenario_name = '';
obs.center_az = NaN;
obs.trial_id = NaN;
obs.center_index = NaN;
obs.scenario_index = NaN;
obs.input = struct();
obs.truth = struct();
obs.input_meta = struct();
obs.backend_out = struct();
obs.context = struct();
obs.context_metadata = struct();
obs.geom = struct();
obs.W = [];
obs.Y = [];
obs.Z_raw = [];
obs.Z_use = [];
obs.Rz = [];
obs.G_grid_raw = [];
obs.G_use_grid = [];
obs.az_grid = [];
obs.el_values = [];
obs.grid_cfg_coarse = struct();
obs.base_refine_cfg = struct();
obs.candidate_table = table();
obs.candidate_ids = {};
obs.score_baseline = [];
obs.top_candidates_baseline = [];
obs.policy_baseline = '';
obs.confidence_baseline = '';
obs.fallback_baseline = false;
obs.boundary_baseline = '';
obs.score_direction = 'higher_is_better';
obs.whitening_info = struct();
obs.cache_lookup_info = struct();
obs.num_candidates = 0;
end

function obs = build_step12_observation_local(trial_index, scenario, iCenter, iScenario, iTrial, input, truth, input_meta, out, context, context_metadata, cfg12)
validation = validate_step11_7_backend_input(input, context);
if ~validation.valid
    error('step12:InvalidStep11Input', 'Step11.7 validation failed: %s', validation.error_message);
end
geom = build_step11_6_canonical_geometry(context.cfg, input.selectedCenterAz);
[grid_cfg_coarse, base_refine_cfg] = make_step12_search_configs_local(input.coarseAz, input.coarseEl, context);
score_pack = build_step12_candidate_score_pack_local(validation.Y, context.W, geom, context, grid_cfg_coarse);

obs = make_empty_obs_local();
obs.trial_index = trial_index;
obs.scenario_name = scenario.scenario_name;
obs.center_az = input.selectedCenterAz;
obs.trial_id = iTrial;
obs.center_index = iCenter;
obs.scenario_index = iScenario;
obs.input = input;
obs.truth = truth;
obs.input_meta = input_meta;
obs.backend_out = out;
obs.context = context;
obs.context_metadata = context_metadata;
obs.geom = input_meta.geom;
obs.W = context.W;
obs.Y = validation.Y;
obs.Z_raw = score_pack.Z_raw;
obs.Z_use = score_pack.Z_use;
obs.Rz = score_pack.Rz;
obs.G_grid_raw = score_pack.G_grid_raw;
obs.G_use_grid = score_pack.G_use_grid;
obs.az_grid = score_pack.az_grid;
obs.el_values = score_pack.el_values;
obs.grid_cfg_coarse = grid_cfg_coarse;
obs.base_refine_cfg = base_refine_cfg;
obs.candidate_table = score_pack.candidate_table;
obs.candidate_ids = score_pack.candidate_ids;
obs.score_baseline = score_pack.score;
obs.top_candidates_baseline = score_pack.top_candidates;
obs.policy_baseline = score_pack.policy.policy_name;
obs.confidence_baseline = safe_field_local(out, 'confidence', safe_field_local(score_pack.policy, 'confidence', ''));
obs.fallback_baseline = logical(safe_field_local(out, 'fallback_used', false));
obs.boundary_baseline = safe_field_local(out, 'boundary_flag', safe_field_local(score_pack.policy, 'boundary_flag', ''));
obs.score_direction = cfg12.score_direction;
obs.whitening_info = score_pack.whitening_info;
obs.cache_lookup_info = score_pack.cache_lookup_info;
obs.num_candidates = height(score_pack.candidate_table);
end

function [grid_cfg_coarse, base_refine_cfg] = make_step12_search_configs_local(coarseAz, coarseEl, context)
grid_cfg_coarse = build_pair2d_search_grids(coarseAz, coarseEl, context.coarse_search_cfg);
full_grid_cfg = build_pair2d_search_grids(coarseAz, coarseEl, context.full_search_cfg);
base_refine_cfg = context.base_refine_cfg;
base_refine_cfg.az_global_bounds = full_grid_cfg.az_bounds;
base_refine_cfg.el_global_bounds = full_grid_cfg.el_bounds;
end

function score_pack = build_step12_candidate_score_pack_local(Y, W, geom, context, grid_cfg_coarse)
Z_raw = W' * Y;
[candidate_table, G_grid_raw, az_grid, el_values, cache_lookup_info] = build_candidate_table_and_gcache_local(W, geom, context, grid_cfg_coarse);
B = size(W, 2);
[Z_use, G_flat_use, winfo] = apply_beamspace_whitening(Z_raw, reshape(G_grid_raw, B, []), W, context.search_opts.whitening_mode, ...
    'eps_reg', max(context.search_opts.reg, 1e-12));
G_use_grid = reshape(G_flat_use, size(G_grid_raw));
Rz = Z_use * Z_use';
score = score_candidate_table_from_grids_local(Z_use, Rz, G_use_grid, candidate_table, context.search_opts.reg, false);
candidate_table.score = score;
candidate_ids = make_candidate_ids_local(candidate_table);
candidate_table.candidate_id = candidate_ids(:);
top_candidates = candidate_struct_from_table_local(candidate_table, score, min(context.C05_policy_cfg.topK_max, height(candidate_table)));
policy = evaluate_step11_policy_from_top_candidates_local(top_candidates, grid_cfg_coarse, context, G_use_grid, Rz);

score_pack = struct();
score_pack.Z_raw = Z_raw;
score_pack.Z_use = Z_use;
score_pack.Rz = Rz;
score_pack.G_grid_raw = G_grid_raw;
score_pack.G_use_grid = G_use_grid;
score_pack.az_grid = az_grid;
score_pack.el_values = el_values;
score_pack.candidate_table = candidate_table;
score_pack.candidate_ids = candidate_ids;
score_pack.score = score;
score_pack.top_candidates = top_candidates;
score_pack.policy = policy;
score_pack.whitening_info = winfo;
score_pack.cache_lookup_info = cache_lookup_info;
end

function [candidate_table, G_grid, az_grid, el_values, lookup_info] = build_candidate_table_and_gcache_local(W, geom, context, grid_cfg)
az_grid = grid_cfg.az_grid(:).';
el_center_grid = grid_cfg.el_center_grid(:).';
el_sep_deg_list = grid_cfg.el_sep_deg_list(:).';
[~, ~, ~, el_info] = make_el_pair_list_degree_based(el_center_grid, el_sep_deg_list, grid_cfg.search_orientations, grid_cfg.el_bounds);
valid_rows = el_info.rows([el_info.rows.valid]);
if isempty(valid_rows)
    error('step12:NoValidElRows', 'No valid Step11.7 coarse elevation rows.');
end
el_values = unique(round([[valid_rows.el1], [valid_rows.el2]] * 1e10) / 1e10);
manifold_opts = context.manifold_opts;
manifold_opts.actual_center_az_deg = geom.actual_center_az_deg;
[G_grid, lookup_info] = lookup_step11_6_beamspace_cache(context.cache, az_grid, el_values, ...
    'CenterAzDeg', geom.actual_center_az_deg, 'InputAzMode', 'global', 'ErrorOnMiss', false);
if lookup_info.cache_miss_count > 0
    grid = precompute_beamspace_azel_grid(W, geom.x_actual, geom.y_actual, geom.z_actual, az_grid, el_values, context.lambda, ...
        'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);
    G_grid = grid.G_grid;
    lookup_info.fallback_used = true;
else
    lookup_info.fallback_used = false;
end

candidate_rows = repmat(make_candidate_row_struct_local(), 0, 1);
candidate_index = 0;
for iRow = 1:numel(valid_rows)
    row = valid_rows(iRow);
    iEl1 = find(abs(el_values - row.el1) < 1e-10, 1);
    iEl2 = find(abs(el_values - row.el2) < 1e-10, 1);
    for iAz1 = 1:(numel(az_grid) - 1)
        for iAz2 = (iAz1 + 1):numel(az_grid)
            candidate_index = candidate_index + 1;
            c = make_candidate_row_struct_local();
            c.candidate_index = candidate_index;
            c.az1 = az_grid(iAz1);
            c.az2 = az_grid(iAz2);
            c.el1 = row.el1;
            c.el2 = row.el2;
            c.el_center = row.el_center;
            c.el_sep = row.el_sep_deg;
            c.orientation = row.orientation;
            c.iAz1 = iAz1;
            c.iAz2 = iAz2;
            c.iElCenter = row.i_el_center;
            c.iElSep = row.i_el_sep;
            c.iEl1 = iEl1;
            c.iEl2 = iEl2;
            candidate_rows(end + 1, 1) = c; %#ok<AGROW>
        end
    end
end
candidate_table = struct2table(candidate_rows);
end

function row = make_candidate_row_struct_local()
row = struct('candidate_index', NaN, 'az1', NaN, 'az2', NaN, 'el1', NaN, 'el2', NaN, ...
    'el_center', NaN, 'el_sep', NaN, 'orientation', NaN, 'iAz1', NaN, 'iAz2', NaN, ...
    'iElCenter', NaN, 'iElSep', NaN, 'iEl1', NaN, 'iEl2', NaN, 'score', NaN, 'candidate_id', '');
end

function score = score_candidate_table_from_grids_local(Z_use, Rz, G_use_grid, candidate_table, reg, use_quantized_rz)
N = height(candidate_table);
score = nan(N, 1);
B = size(G_use_grid, 1);
for idx = 1:N
    g1 = G_use_grid(:, candidate_table.iAz1(idx), candidate_table.iEl1(idx));
    g2 = G_use_grid(:, candidate_table.iAz2(idx), candidate_table.iEl2(idx));
    G = [g1, g2];
    if use_quantized_rz
        GHG = G' * G + reg * eye(2);
        P_left = G / GHG;
        score(idx) = real(trace((P_left * G') * Rz));
    else
        score(idx) = beamspace_dml_score(Z_use, G, 'reg', reg);
    end
    if ~isfinite(score(idx))
        score(idx) = -Inf;
    end
end
if B < 1
    score(:) = -Inf;
end
end

function policy = evaluate_step11_policy_from_top_candidates_local(top_candidates, grid_cfg_coarse, context, G_use_grid, Rz)
coarse_debug = struct();
coarse_debug.num_pairs = numel(top_candidates);
coarse_debug.cond_best_GHG = NaN;
coarse_debug.max_score = NaN;
if ~isempty(top_candidates)
    best = top_candidates(1);
    G_best = [G_use_grid(:, best.iAz1, best.iEl1), G_use_grid(:, best.iAz2, best.iEl2)];
    coarse_debug.cond_best_GHG = cond(G_best' * G_best + context.search_opts.reg * eye(2));
    coarse_debug.max_score = best.score;
end
try
    features = compute_likelihood_landscape_features_v2(top_candidates, coarse_debug, grid_cfg_coarse, context.search_opts, context.C05_policy_cfg);
    policy = select_adaptive_topk_window_policy_v2(features, context.base_refine_cfg, context.C05_policy_cfg);
catch
    policy = struct('policy_name', 'POLICY_EVAL_FAILED', 'adaptive_topK', NaN, 'confidence', 'low', ...
        'boundary_flag', 'policy_eval_failed');
end
end

function [trial_tbl, topk_tbl, score_gap_tbl] = run_step12_quantization_trials_local(obs, modes, cfg12)
trial_rows = repmat(make_trial_row_template_local(), 0, 1);
topk_rows = repmat(make_topk_row_template_local(), 0, 1);
gap_rows = repmat(make_score_gap_row_template_local(), 0, 1);
for iObs = 1:numel(obs)
    base = obs(iObs);
    for iMode = 1:numel(modes)
        mode = modes(iMode);
        score_out = run_step11_ml_score_adapter_local(base, mode, cfg12);
        metrics = compare_score_ranking_local(base, score_out, mode, cfg12);
        trial_rows(end + 1, 1) = metrics.trial_row; %#ok<AGROW>
        for kIdx = 1:numel(metrics.topk_rows)
            topk_rows(end + 1, 1) = metrics.topk_rows(kIdx); %#ok<AGROW>
        end
        gap_rows(end + 1, 1) = metrics.score_gap_row; %#ok<AGROW>
    end
end
trial_tbl = struct2table(trial_rows);
topk_tbl = struct2table(topk_rows);
score_gap_tbl = struct2table(gap_rows);
end

function row = make_trial_row_template_local()
row = struct('trial_index', NaN, 'scenario_name', '', 'quant_mode', '', 'candidate_count', NaN, ...
    'topK_default', NaN, 'top1_same_flag', false, 'topK_order_same_flag', false, ...
    'topK_set_same_flag', false, 'topK_jaccard', NaN, 'topK_miss_count', NaN, ...
    'topK_miss_rate', NaN, 'selected_candidate_same_flag', false, 'score_rank_spearman', NaN, ...
    'score_rank_kendall_if_easy', NaN, 'score_gap_top1_top2_baseline', NaN, ...
    'score_gap_top1_top2_quant', NaN, 'score_gap_norm_baseline', NaN, ...
    'score_gap_norm_quant', NaN, 'score_gap_abs_error', NaN, 'score_gap_rel_error', NaN, ...
    'score_margin_bin', '', 'argmax_changed_flag', false, 'score_gap_sign_flip_flag', false, ...
    'reliable_margin_flag', false, 'reliable_top1_same_flag', false, 'reliable_topK_same_flag', false, ...
    'candidate_score_max_abs_diff', NaN, 'candidate_score_p95_abs_diff', NaN, ...
    'candidate_score_rel_l2_error', NaN, 'same_policy_flag', false, 'same_estimate_flag', false, ...
    'same_confidence_flag', false, 'same_fallback_flag', false, 'boundary_state_same_flag', false, ...
    'false_high_rate_if_available', NaN, 'boundary_missed_rate_if_available', NaN, ...
    'az_rmse_gap_if_available', NaN, 'el_rmse_gap_if_available', NaN, ...
    'W_scale', NaN, 'Gcache_scale', NaN, 'Z_scale', NaN, 'Rz_scale', NaN, 'score_scale', NaN, ...
    'W_clip_rate', NaN, 'Gcache_clip_rate', NaN, 'Z_clip_rate', NaN, 'Rz_clip_rate', NaN, ...
    'score_clip_rate', NaN, 'max_clip_rate', NaN, 'max_overflow_rate', NaN, ...
    'W_relative_error', NaN, 'Gcache_relative_error', NaN, 'Z_relative_error', NaN, ...
    'Rz_relative_error', NaN, 'score_relative_error', NaN);
end

function row = make_topk_row_template_local()
row = struct('trial_index', NaN, 'scenario_name', '', 'quant_mode', '', 'K', NaN, ...
    'K_actual', NaN, 'topK_order_same_flag', false, 'topK_set_same_flag', false, ...
    'topK_jaccard', NaN, 'topK_miss_count', NaN, 'topK_miss_rate', NaN, ...
    'reliable_margin_flag', false, 'reliable_topK_same_flag', false);
end

function row = make_score_gap_row_template_local()
row = struct('trial_index', NaN, 'scenario_name', '', 'quant_mode', '', ...
    'score_gap_top1_top2_baseline', NaN, 'score_gap_top1_top2_quant', NaN, ...
    'score_gap_same_baseline_pair_quant', NaN, 'score_gap_norm_baseline', NaN, ...
    'score_gap_norm_quant', NaN, 'score_gap_abs_error', NaN, 'score_gap_rel_error', NaN, ...
    'score_gap_sign_flip_flag', false, 'score_margin_bin', '');
end

function score_out = run_step11_ml_score_adapter_local(obs, mode, cfg12)
score_out = struct();
score_out.mode_name = mode.name;
score_out.score_direction = cfg12.score_direction;
qdiag = make_qdiag_template_local();
context = obs.context;
W_use = obs.W;
Y_use = obs.Y;
G_raw = obs.G_grid_raw;

if mode.is_float_reference
    W_use = single(W_use);
    Y_use = single(Y_use);
    G_raw = single(G_raw);
end

if isfinite(mode.W_bits)
    [W_use, qdiag.W] = quantize_complex_block_float_local(W_use, mode.W_bits, 'W');
    grid = precompute_beamspace_azel_grid(W_use, obs.geom.x_actual, obs.geom.y_actual, obs.geom.z_actual, ...
        obs.az_grid, obs.el_values, context.lambda, 'PhaseFactor', context.phase_factor, 'PhaseSign', context.phase_sign);
    G_raw = grid.G_grid;
end

if isfinite(mode.Gcache_bits)
    [G_raw, qdiag.Gcache] = quantize_complex_block_float_local(G_raw, mode.Gcache_bits, 'G_cache');
end

Z_raw = W_use' * Y_use;
if mode.is_float_reference
    Z_raw = single(Z_raw);
end

B = size(W_use, 2);
[Z_use, G_flat_use, ~] = apply_beamspace_whitening(Z_raw, reshape(G_raw, B, []), W_use, context.search_opts.whitening_mode, ...
    'eps_reg', max(context.search_opts.reg, 1e-12));
G_use_grid = reshape(G_flat_use, size(G_raw));

if mode.is_float_reference
    Z_use = single(Z_use);
    G_use_grid = single(G_use_grid);
end

if isfinite(mode.Z_bits)
    [Z_use, qdiag.Z] = quantize_complex_block_float_local(Z_use, mode.Z_bits, 'Z');
end

Rz = Z_use * Z_use';
if mode.is_float_reference
    Rz = single(Rz);
end
if isfinite(mode.Rz_bits)
    [Rz, qdiag.Rz] = quantize_complex_block_float_local(Rz, mode.Rz_bits, 'Rz');
end

score = score_candidate_table_from_grids_local(Z_use, Rz, G_use_grid, obs.candidate_table, context.search_opts.reg, isfinite(mode.Rz_bits));
score_pre_score_quant = score;
if mode.is_float_reference || mode.score_float
    score = double(single(score));
end
if isfinite(mode.score_bits)
    [score, qdiag.score] = quantize_real_block_float_local(score, mode.score_bits, 'score');
else
    qdiag.score.relative_error = relative_error_local(score, score_pre_score_quant);
end

top_candidates = candidate_struct_from_table_local(obs.candidate_table, score, min(context.C05_policy_cfg.topK_max, height(obs.candidate_table)));
policy = evaluate_step11_policy_from_top_candidates_local(top_candidates, obs.grid_cfg_coarse, context, G_use_grid, Rz);

score_out.score = double(score(:));
score_out.Z_use = Z_use;
score_out.Rz = Rz;
score_out.G_use_grid = G_use_grid;
score_out.top_candidates = top_candidates;
score_out.policy = policy;
score_out.qdiag = qdiag;
score_out.estimate = top_candidate_estimate_local(obs.candidate_table, score);
end

function qdiag = make_qdiag_template_local()
empty = struct('name', '', 'bits', NaN, 'scale', NaN, 'clip_rate', 0, 'overflow_rate', 0, 'relative_error', 0, 'max_abs', NaN);
qdiag = struct('W', empty, 'Gcache', empty, 'Z', empty, 'Rz', empty, 'score', empty);
qdiag.W.name = 'W';
qdiag.Gcache.name = 'G_cache';
qdiag.Z.name = 'Z';
qdiag.Rz.name = 'Rz';
qdiag.score.name = 'score';
end

function [xq, diag] = quantize_complex_block_float_local(x, bits, name)
if ~isfinite(bits)
    xq = x;
    diag = struct('name', name, 'bits', NaN, 'scale', NaN, 'clip_rate', 0, 'overflow_rate', 0, 'relative_error', 0, 'max_abs', max(abs(x(:))));
    return;
end
max_int = 2^(bits - 1) - 1;
min_int = -2^(bits - 1);
components = [real(x(:)); imag(x(:))];
max_abs = max(abs(components));
if isempty(max_abs) || max_abs == 0 || ~isfinite(max_abs)
    scale = 1;
else
    scale = max_abs / max_int;
end
q = round(components / scale);
clip_mask = q > max_int | q < min_int;
q_clip = min(max(q, min_int), max_int);
components_q = q_clip * scale;
n = numel(x);
xq = reshape(complex(components_q(1:n), components_q(n + 1:end)), size(x));
diag = struct('name', name, 'bits', bits, 'scale', scale, 'clip_rate', mean(double(clip_mask)), ...
    'overflow_rate', mean(double(clip_mask)), 'relative_error', relative_error_local(xq, x), 'max_abs', max_abs);
end

function [xq, diag] = quantize_real_block_float_local(x, bits, name)
if ~isfinite(bits)
    xq = x;
    diag = struct('name', name, 'bits', NaN, 'scale', NaN, 'clip_rate', 0, 'overflow_rate', 0, 'relative_error', 0, 'max_abs', max(abs(x(:))));
    return;
end
max_int = 2^(bits - 1) - 1;
min_int = -2^(bits - 1);
xv = real(x(:));
finite_mask = isfinite(xv);
max_abs = max(abs(xv(finite_mask)));
if isempty(max_abs) || max_abs == 0 || ~isfinite(max_abs)
    scale = 1;
else
    scale = max_abs / max_int;
end
q = round(xv / scale);
clip_mask = q > max_int | q < min_int;
q_clip = min(max(q, min_int), max_int);
xq = reshape(q_clip * scale, size(x));
xq(~finite_mask) = x(~finite_mask);
diag = struct('name', name, 'bits', bits, 'scale', scale, 'clip_rate', mean(double(clip_mask(finite_mask))), ...
    'overflow_rate', mean(double(clip_mask(finite_mask))), 'relative_error', relative_error_local(xq(finite_mask), x(finite_mask)), ...
    'max_abs', max_abs);
end

function [xq, diag] = quantize_complex_unit_local(x, bits)
[xq, diag] = quantize_complex_block_float_local(x, bits, 'unit_complex');
end

function metrics = compare_score_ranking_local(base, quant, mode, cfg12)
score_base = double(base.score_baseline(:));
score_quant = double(quant.score(:));
candidate_ids = base.candidate_ids(:);
K_default = min(cfg12.topK_default, numel(score_base));
top_base = extract_topk_local(score_base, candidate_ids, K_default, true);
top_quant = extract_topk_local(score_quant, candidate_ids, K_default, true);

top_metrics = compare_topk_ids_local(top_base.ids, top_quant.ids);
all_topk_rows = repmat(make_topk_row_template_local(), 0, 1);
for idx = 1:numel(cfg12.topK_list)
    K = min(cfg12.topK_list(idx), numel(score_base));
    tb = extract_topk_local(score_base, candidate_ids, K, true);
    tq = extract_topk_local(score_quant, candidate_ids, K, true);
    tm = compare_topk_ids_local(tb.ids, tq.ids);
    row = make_topk_row_template_local();
    row.trial_index = base.trial_index;
    row.scenario_name = base.scenario_name;
    row.quant_mode = mode.name;
    row.K = cfg12.topK_list(idx);
    row.K_actual = K;
    row.topK_order_same_flag = tm.order_same;
    row.topK_set_same_flag = tm.set_same;
    row.topK_jaccard = tm.jaccard;
    row.topK_miss_count = tm.miss_count;
    row.topK_miss_rate = tm.miss_rate;
    all_topk_rows(end + 1, 1) = row; %#ok<AGROW>
end

base_pair_gap = NaN;
quant_same_pair_gap = NaN;
if numel(top_base.indices) >= 2
    base_pair_gap = score_base(top_base.indices(1)) - score_base(top_base.indices(2));
    quant_same_pair_gap = score_quant(top_base.indices(1)) - score_quant(top_base.indices(2));
end
quant_top_gap = NaN;
if numel(top_quant.indices) >= 2
    quant_top_gap = score_quant(top_quant.indices(1)) - score_quant(top_quant.indices(2));
end
gap_norm_base = abs(base_pair_gap) / max(abs(score_base(top_base.indices(1))) + abs(score_base(top_base.indices(min(2, end)))) + eps, eps);
gap_norm_quant = abs(quant_top_gap) / max(abs(score_quant(top_quant.indices(1))) + abs(score_quant(top_quant.indices(min(2, end)))) + eps, eps);
gap_abs_error = abs(quant_same_pair_gap - base_pair_gap);
gap_rel_error = gap_abs_error / max(abs(base_pair_gap), eps);
reliable = gap_norm_base >= cfg12.reliable_margin_threshold;
margin_bin = margin_bin_local(gap_norm_base, cfg12);
score_gap_sign_flip = isfinite(base_pair_gap) && base_pair_gap > 0 && isfinite(quant_same_pair_gap) && quant_same_pair_gap <= 0;

abs_diff = abs(score_quant - score_base);
finite_diff = abs_diff(isfinite(abs_diff));
policy_quant = safe_field_local(quant.policy, 'policy_name', '');
confidence_quant = safe_field_local(quant.policy, 'confidence', '');
boundary_quant = safe_field_local(quant.policy, 'boundary_flag', '');
estimate_base = top_candidate_estimate_local(base.candidate_table, score_base);
estimate_quant = quant.estimate;
[az_rmse_base, el_rmse_base] = pair_rmse_to_truth_local(estimate_base.az_hat, estimate_base.el_hat, base.truth);
[az_rmse_quant, el_rmse_quant] = pair_rmse_to_truth_local(estimate_quant.az_hat, estimate_quant.el_hat, base.truth);

row = make_trial_row_template_local();
row.trial_index = base.trial_index;
row.scenario_name = base.scenario_name;
row.quant_mode = mode.name;
row.candidate_count = numel(score_base);
row.topK_default = K_default;
row.top1_same_flag = top_metrics.order_same && K_default >= 1 && strcmp(top_base.ids{1}, top_quant.ids{1});
row.topK_order_same_flag = top_metrics.order_same;
row.topK_set_same_flag = top_metrics.set_same;
row.topK_jaccard = top_metrics.jaccard;
row.topK_miss_count = top_metrics.miss_count;
row.topK_miss_rate = top_metrics.miss_rate;
row.selected_candidate_same_flag = row.top1_same_flag;
row.score_rank_spearman = rank_spearman_local(score_base, score_quant);
row.score_rank_kendall_if_easy = rank_kendall_if_easy_local(score_base, score_quant, cfg12.max_kendall_n);
row.score_gap_top1_top2_baseline = base_pair_gap;
row.score_gap_top1_top2_quant = quant_top_gap;
row.score_gap_norm_baseline = gap_norm_base;
row.score_gap_norm_quant = gap_norm_quant;
row.score_gap_abs_error = gap_abs_error;
row.score_gap_rel_error = gap_rel_error;
row.score_margin_bin = margin_bin;
row.argmax_changed_flag = ~row.top1_same_flag;
row.score_gap_sign_flip_flag = score_gap_sign_flip;
row.reliable_margin_flag = reliable;
row.reliable_top1_same_flag = reliable && row.top1_same_flag;
row.reliable_topK_same_flag = reliable && row.topK_set_same_flag;
row.candidate_score_max_abs_diff = max_or_nan_local(finite_diff);
row.candidate_score_p95_abs_diff = percentile_local(finite_diff, 95);
row.candidate_score_rel_l2_error = relative_error_local(score_quant(isfinite(score_base) & isfinite(score_quant)), score_base(isfinite(score_base) & isfinite(score_quant)));
row.same_policy_flag = strcmp(base.policy_baseline, policy_quant);
row.same_estimate_flag = row.selected_candidate_same_flag;
row.same_confidence_flag = strcmp(base.confidence_baseline, confidence_quant);
row.same_fallback_flag = true;
row.boundary_state_same_flag = strcmp(base.boundary_baseline, boundary_quant);
row.az_rmse_gap_if_available = az_rmse_quant - az_rmse_base;
row.el_rmse_gap_if_available = el_rmse_quant - el_rmse_base;
row.W_scale = quant.qdiag.W.scale;
row.Gcache_scale = quant.qdiag.Gcache.scale;
row.Z_scale = quant.qdiag.Z.scale;
row.Rz_scale = quant.qdiag.Rz.scale;
row.score_scale = quant.qdiag.score.scale;
row.W_clip_rate = quant.qdiag.W.clip_rate;
row.Gcache_clip_rate = quant.qdiag.Gcache.clip_rate;
row.Z_clip_rate = quant.qdiag.Z.clip_rate;
row.Rz_clip_rate = quant.qdiag.Rz.clip_rate;
row.score_clip_rate = quant.qdiag.score.clip_rate;
row.max_clip_rate = max([row.W_clip_rate, row.Gcache_clip_rate, row.Z_clip_rate, row.Rz_clip_rate, row.score_clip_rate]);
row.max_overflow_rate = max([quant.qdiag.W.overflow_rate, quant.qdiag.Gcache.overflow_rate, quant.qdiag.Z.overflow_rate, ...
    quant.qdiag.Rz.overflow_rate, quant.qdiag.score.overflow_rate]);
row.W_relative_error = quant.qdiag.W.relative_error;
row.Gcache_relative_error = quant.qdiag.Gcache.relative_error;
row.Z_relative_error = quant.qdiag.Z.relative_error;
row.Rz_relative_error = quant.qdiag.Rz.relative_error;
row.score_relative_error = quant.qdiag.score.relative_error;

for idx = 1:numel(all_topk_rows)
    all_topk_rows(idx).reliable_margin_flag = reliable;
    all_topk_rows(idx).reliable_topK_same_flag = reliable && all_topk_rows(idx).topK_set_same_flag;
end

gap_row = make_score_gap_row_template_local();
gap_row.trial_index = base.trial_index;
gap_row.scenario_name = base.scenario_name;
gap_row.quant_mode = mode.name;
gap_row.score_gap_top1_top2_baseline = base_pair_gap;
gap_row.score_gap_top1_top2_quant = quant_top_gap;
gap_row.score_gap_same_baseline_pair_quant = quant_same_pair_gap;
gap_row.score_gap_norm_baseline = gap_norm_base;
gap_row.score_gap_norm_quant = gap_norm_quant;
gap_row.score_gap_abs_error = gap_abs_error;
gap_row.score_gap_rel_error = gap_rel_error;
gap_row.score_gap_sign_flip_flag = score_gap_sign_flip;
gap_row.score_margin_bin = margin_bin;

metrics = struct();
metrics.trial_row = row;
metrics.topk_rows = all_topk_rows;
metrics.score_gap_row = gap_row;
end

function topk = extract_topk_local(score, candidate_ids, K, score_higher_is_better)
score = score(:);
K = min(max(1, floor(K)), numel(score));
if score_higher_is_better
    sort_score = -score;
else
    sort_score = score;
end
idx = (1:numel(score)).';
finite_mask = isfinite(sort_score);
sort_matrix = [sort_score(:), idx];
sort_matrix(~finite_mask, 1) = Inf;
[~, order] = sortrows(sort_matrix, [1, 2]);
order = order(1:K);
topk.indices = order(:);
topk.ids = candidate_ids(order);
topk.scores = score(order);
end

function ids = make_candidate_ids_local(candidate_table)
ids = cell(height(candidate_table), 1);
for idx = 1:height(candidate_table)
    pair = [candidate_table.az1(idx), candidate_table.el1(idx); candidate_table.az2(idx), candidate_table.el2(idx)];
    pair = sortrows(round(pair * 1e6) / 1e6, [1, 2]);
    ids{idx} = sprintf('p_%+.6f_%+.6f__%+.6f_%+.6f__sep_%+.6f', ...
        pair(1, 1), pair(1, 2), pair(2, 1), pair(2, 2), candidate_table.el_sep(idx));
end
end

function top_candidates = candidate_struct_from_table_local(candidate_table, score, K)
top = extract_topk_local(score, make_candidate_ids_local(candidate_table), K, true);
top_candidates = repmat(make_step11_candidate_template_local(), numel(top.indices), 1);
for ii = 1:numel(top.indices)
    idx = top.indices(ii);
    c = make_step11_candidate_template_local();
    c.az_hat = [candidate_table.az1(idx), candidate_table.az2(idx)];
    c.el_hat = [candidate_table.el1(idx), candidate_table.el2(idx)];
    c.el_center_hat = candidate_table.el_center(idx);
    c.el_sep_hat = candidate_table.el_sep(idx);
    c.orientation_hat = candidate_table.orientation(idx);
    c.score = score(idx);
    c.iAz1 = candidate_table.iAz1(idx);
    c.iAz2 = candidate_table.iAz2(idx);
    c.iElCenter = candidate_table.iElCenter(idx);
    c.iElSep = candidate_table.iElSep(idx);
    c.iEl1 = candidate_table.iEl1(idx);
    c.iEl2 = candidate_table.iEl2(idx);
    c.el1_value = candidate_table.el1(idx);
    c.el2_value = candidate_table.el2(idx);
    top_candidates(ii) = c;
end
end

function c = make_step11_candidate_template_local()
c = struct('az_hat', [NaN, NaN], 'el_hat', [NaN, NaN], 'el_center_hat', NaN, ...
    'el_sep_hat', NaN, 'orientation_hat', NaN, 'score', -Inf, 'iAz1', NaN, ...
    'iAz2', NaN, 'iElCenter', NaN, 'iElSep', NaN, 'iEl1', NaN, 'iEl2', NaN, ...
    'el1_value', NaN, 'el2_value', NaN);
end

function est = top_candidate_estimate_local(candidate_table, score)
top = extract_topk_local(score(:), make_candidate_ids_local(candidate_table), 1, true);
idx = top.indices(1);
est = struct();
est.az_hat = [candidate_table.az1(idx), candidate_table.az2(idx)];
est.el_hat = [candidate_table.el1(idx), candidate_table.el2(idx)];
est.candidate_id = top.ids{1};
end

function tm = compare_topk_ids_local(base_ids, quant_ids)
base_ids = base_ids(:);
quant_ids = quant_ids(:);
K = numel(base_ids);
same_count = numel(intersect(base_ids, quant_ids));
tm = struct();
tm.order_same = numel(base_ids) == numel(quant_ids) && all(strcmp(base_ids, quant_ids));
tm.set_same = same_count == K && K == numel(quant_ids);
tm.jaccard = same_count / max(numel(union(base_ids, quant_ids)), 1);
tm.miss_count = K - same_count;
tm.miss_rate = tm.miss_count / max(K, 1);
end

function summary_tbl = build_step12_summary_table_local(trial_tbl, modes, cfg12)
rows = repmat(make_summary_row_template_local(), 0, 1);
for iMode = 1:numel(modes)
    mode = modes(iMode);
    mask = strcmp(trial_tbl.quant_mode, mode.name);
    T = trial_tbl(mask, :);
    row = make_summary_row_template_local();
    row.quant_mode = mode.name;
    row.is_fixed_candidate = mode.is_fixed_candidate;
    row.recommendation_candidate_flag = mode.is_recommendation_candidate;
    row.num_trials = height(T);
    row.reliable_trial_count = nnz(T.reliable_margin_flag);
    row.overall_top1_preservation_rate = mean_or_nan_local(double(T.top1_same_flag));
    row.overall_topK_set_preservation_rate = mean_or_nan_local(double(T.topK_set_same_flag));
    row.overall_topK_miss_rate = mean_or_nan_local(T.topK_miss_rate);
    reliable_mask = T.reliable_margin_flag;
    row.reliable_top1_preservation_rate = mean_or_nan_local(double(T.top1_same_flag(reliable_mask)));
    row.reliable_topK_set_preservation_rate = mean_or_nan_local(double(T.topK_set_same_flag(reliable_mask)));
    row.reliable_topK_miss_rate = mean_or_nan_local(T.topK_miss_rate(reliable_mask));
    row.argmax_changed_rate_on_reliable_margin = mean_or_nan_local(double(T.argmax_changed_flag(reliable_mask)));
    row.reliable_score_gap_sign_flip_rate = mean_or_nan_local(double(T.score_gap_sign_flip_flag(reliable_mask)));
    row.mean_score_rank_spearman = mean_or_nan_local(T.score_rank_spearman);
    row.min_score_rank_spearman = min_or_nan_local(T.score_rank_spearman);
    row.max_candidate_score_rel_l2_error = max_or_nan_local(T.candidate_score_rel_l2_error);
    row.max_score_gap_rel_error = max_or_nan_local(T.score_gap_rel_error);
    row.same_policy_rate = mean_or_nan_local(double(T.same_policy_flag));
    row.same_estimate_rate = mean_or_nan_local(double(T.same_estimate_flag));
    row.same_confidence_rate = mean_or_nan_local(double(T.same_confidence_flag));
    row.same_fallback_rate = mean_or_nan_local(double(T.same_fallback_flag));
    row.boundary_state_same_rate = mean_or_nan_local(double(T.boundary_state_same_flag));
    row.max_clip_rate = max_or_nan_local(T.max_clip_rate);
    row.max_overflow_rate = max_or_nan_local(T.max_overflow_rate);
    row.ranking_pass_flag = row.reliable_top1_preservation_rate >= 0.999 && ...
        row.reliable_score_gap_sign_flip_rate == 0 && row.argmax_changed_rate_on_reliable_margin <= 0.001;
    row.topK_pass_flag = row.reliable_topK_set_preservation_rate >= 0.995 && ...
        row.overall_topK_set_preservation_rate >= 0.980 && row.reliable_topK_miss_rate <= 0.005;
    row.fixed_point_pass_flag = mode.is_fixed_candidate && row.ranking_pass_flag && row.topK_pass_flag;
    if row.reliable_trial_count == 0
        row.ranking_pass_flag = false;
        row.topK_pass_flag = false;
        row.fixed_point_pass_flag = false;
    end
    row.mode_storage_cost_bits = mode.storage_component_bits;
    rows(end + 1, 1) = row; %#ok<AGROW>
end
summary_tbl = struct2table(rows);
end

function row = make_summary_row_template_local()
row = struct('quant_mode', '', 'is_fixed_candidate', false, 'recommendation_candidate_flag', false, ...
    'num_trials', 0, 'reliable_trial_count', 0, 'overall_top1_preservation_rate', NaN, ...
    'overall_topK_set_preservation_rate', NaN, 'overall_topK_miss_rate', NaN, ...
    'reliable_top1_preservation_rate', NaN, 'reliable_topK_set_preservation_rate', NaN, ...
    'reliable_topK_miss_rate', NaN, 'argmax_changed_rate_on_reliable_margin', NaN, ...
    'reliable_score_gap_sign_flip_rate', NaN, 'mean_score_rank_spearman', NaN, ...
    'min_score_rank_spearman', NaN, 'max_candidate_score_rel_l2_error', NaN, ...
    'max_score_gap_rel_error', NaN, 'same_policy_rate', NaN, 'same_estimate_rate', NaN, ...
    'same_confidence_rate', NaN, 'same_fallback_rate', NaN, 'boundary_state_same_rate', NaN, ...
    'max_clip_rate', NaN, 'max_overflow_rate', NaN, 'ranking_pass_flag', false, ...
    'topK_pass_flag', false, 'fixed_point_pass_flag', false, 'mode_storage_cost_bits', NaN);
end

function best_info = select_best_fixed_point_mode_local(summary_tbl, modes)
best_info = struct('mode_name', 'not_recommended', 'recommended_fixed_point_format', 'not_recommended', ...
    'ranking_pass_flag', false, 'topK_pass_flag', false, 'fixed_point_pass_flag', false, ...
    'blocker_if_any', 'ml_score_ranking_or_topK_not_closed', 'component_bits', 16, ...
    'proceed_to_rtl_score_core_flag', 0, 'proceed_to_full_fpga_backend_flag', 0, ...
    'reliable_top1_preservation', NaN, 'reliable_topK_preservation', NaN, ...
    'overall_topK_preservation', NaN, 'argmax_changed_reliable', NaN, 'score_gap_flip_reliable', NaN);
if isempty(summary_tbl) || height(summary_tbl) == 0
    return;
end
mask = logical(summary_tbl.fixed_point_pass_flag) & logical(summary_tbl.recommendation_candidate_flag);
if ~any(mask)
    fixed_mask = logical(summary_tbl.is_fixed_candidate);
    if any(fixed_mask)
        [~, idx] = max(summary_tbl.reliable_topK_set_preservation_rate(fixed_mask));
        fixed_indices = find(fixed_mask);
        best_row = summary_tbl(fixed_indices(idx), :);
        best_info.mode_name = char(best_row.quant_mode{1});
        best_info.reliable_top1_preservation = best_row.reliable_top1_preservation_rate(1);
        best_info.reliable_topK_preservation = best_row.reliable_topK_set_preservation_rate(1);
        best_info.overall_topK_preservation = best_row.overall_topK_set_preservation_rate(1);
        best_info.argmax_changed_reliable = best_row.argmax_changed_rate_on_reliable_margin(1);
        best_info.score_gap_flip_reliable = best_row.reliable_score_gap_sign_flip_rate(1);
    end
    return;
end
pass_indices = find(mask);
cost = summary_tbl.mode_storage_cost_bits(mask);
[~, rel_order] = sort(cost, 'ascend');
best_idx = pass_indices(rel_order(1));
best_row = summary_tbl(best_idx, :);
best_info.mode_name = char(best_row.quant_mode{1});
best_info.recommended_fixed_point_format = best_info.mode_name;
best_info.ranking_pass_flag = logical(best_row.ranking_pass_flag(1));
best_info.topK_pass_flag = logical(best_row.topK_pass_flag(1));
best_info.fixed_point_pass_flag = best_info.ranking_pass_flag && best_info.topK_pass_flag;
best_info.blocker_if_any = 'none';
best_info.component_bits = mode_bits_by_name_local(modes, best_info.mode_name);
best_info.proceed_to_rtl_score_core_flag = double(best_info.fixed_point_pass_flag);
best_info.proceed_to_full_fpga_backend_flag = 0;
best_info.reliable_top1_preservation = best_row.reliable_top1_preservation_rate(1);
best_info.reliable_topK_preservation = best_row.reliable_topK_set_preservation_rate(1);
best_info.overall_topK_preservation = best_row.overall_topK_set_preservation_rate(1);
best_info.argmax_changed_reliable = best_row.argmax_changed_rate_on_reliable_margin(1);
best_info.score_gap_flip_reliable = best_row.reliable_score_gap_sign_flip_rate(1);
end

function bits = mode_bits_by_name_local(modes, mode_name)
bits = 16;
for idx = 1:numel(modes)
    if strcmp(modes(idx).name, mode_name)
        bits = modes(idx).storage_component_bits;
        return;
    end
end
end

function storage_tbl = build_step12_storage_estimate_local(obs, best_info, cfg12)
bits = best_info.component_bits;
if ~(isfinite(bits) && bits > 0)
    bits = cfg12.default_component_bits;
end
num_candidates = max(obs.num_candidates, 1);
B = size(obs.W, 2);
topK = min(cfg12.topK_default, num_candidates);
rows = repmat(make_storage_row_template_local(), 0, 1);
rows(end + 1, 1) = make_storage_row_local('W', numel(obs.W), bits, B, 2 * B * bits, 'beamforming projection matrix W');
rows(end + 1, 1) = make_storage_row_local('G_cache', numel(obs.context.cache.G_grid), bits, 2 * B, 4 * B * bits, 'Step11.6 canonical beamspace G cache');
rows(end + 1, 1) = make_storage_row_local('Z_buffer', numel(obs.Z_use), bits, B, 2 * B * bits, 'beamspace snapshot buffer after Step11 whitening');
rows(end + 1, 1) = make_storage_row_local('Rz_buffer', numel(obs.Rz), bits, B * B, 2 * B * B * bits, 'Step11 score covariance uses unnormalized Z*Z''');
rows(end + 1, 1) = make_storage_row_local('score_buffer', num_candidates, bits, 0, 2 * bits, 'real score values stored with conservative complex-slot accounting');
rows(end + 1, 1) = make_storage_row_local('topK_buffer', topK, bits, 0, 4 * bits, 'topK candidate id plus score metadata estimate');
rows(end + 1, 1) = make_storage_row_local('candidate_table_minimal', num_candidates, bits, 0, 8 * bits, 'az/el/sep/orientation/index metadata estimate');
storage_tbl = struct2table(rows);
end

function row = make_storage_row_template_local()
row = struct('object_name', '', 'num_complex', NaN, 'component_bits', NaN, 'bits_per_complex', NaN, ...
    'total_bits', NaN, 'total_MB', NaN, 'BRAM36_equivalent', NaN, 'URAM288_equivalent', NaN, ...
    'read_complex_per_candidate', NaN, 'read_bits_per_candidate', NaN, 'comment', '');
end

function row = make_storage_row_local(name, num_complex, component_bits, read_complex, read_bits_per_candidate, comment)
bits_per_complex = 2 * component_bits;
total_bits = num_complex * bits_per_complex;
row = make_storage_row_template_local();
row.object_name = name;
row.num_complex = num_complex;
row.component_bits = component_bits;
row.bits_per_complex = bits_per_complex;
row.total_bits = total_bits;
row.total_MB = total_bits / 8 / 1024 / 1024;
row.BRAM36_equivalent = ceil(total_bits / 36864);
row.URAM288_equivalent = ceil(total_bits / 294912);
row.read_complex_per_candidate = read_complex;
row.read_bits_per_candidate = read_bits_per_candidate;
row.comment = comment;
end

function bandwidth_tbl = build_step12_bandwidth_estimate_local(obs, best_info, cfg12)
bits = best_info.component_bits;
if ~(isfinite(bits) && bits > 0)
    bits = cfg12.default_component_bits;
end
B = size(obs.W, 2);
num_candidates_coarse = max(obs.num_candidates, 1);
num_candidates_fine_typ = max(round(num_candidates_coarse * 0.7), 1);
num_candidates_worst = max(round(num_candidates_coarse * 1.5), num_candidates_coarse);
stage_names = {'coarse_stage', 'fine_stage_typical_if_available', 'worst_case'};
stage_counts = [num_candidates_coarse, num_candidates_fine_typ, num_candidates_worst];
lanes = [1, 4, 8];
rows = repmat(make_bandwidth_row_template_local(), 0, 1);
for iStage = 1:numel(stage_names)
    for iLane = 1:numel(lanes)
        rows(end + 1, 1) = make_bandwidth_row_local(stage_names{iStage}, stage_counts(iStage), cfg12.topK_default, B, bits, lanes(iLane)); %#ok<AGROW>
    end
end
bandwidth_tbl = struct2table(rows);
end

function row = make_bandwidth_row_template_local()
row = struct('stage_name', '', 'num_candidates', NaN, 'topK', NaN, 'G_vectors_per_candidate', NaN, ...
    'G_complex_per_vector', NaN, 'Rz_dim', NaN, 'complex_read_per_candidate', NaN, ...
    'bits_read_per_candidate', NaN, 'estimated_complex_mac_per_candidate', NaN, ...
    'score_lanes', NaN, 'II_assumed', NaN, 'cycles_score_map', NaN, 'cycles_topK', NaN, ...
    'cycles_total_est', NaN, 'throughput_candidate_per_cycle', NaN, 'comment', '');
end

function row = make_bandwidth_row_local(stage_name, num_candidates, topK, B, bits, lanes)
II = 1;
complex_read = 2 * B + B * B;
bits_read = complex_read * 2 * bits;
macs = 2 * B * B + 6 * B;
cycles_score = ceil(num_candidates / lanes) * II;
cycles_topK = ceil(num_candidates * max(log2(topK + 1), 1) / max(lanes, 1));
row = make_bandwidth_row_template_local();
row.stage_name = stage_name;
row.num_candidates = num_candidates;
row.topK = topK;
row.G_vectors_per_candidate = 2;
row.G_complex_per_vector = B;
row.Rz_dim = B;
row.complex_read_per_candidate = complex_read;
row.bits_read_per_candidate = bits_read;
row.estimated_complex_mac_per_candidate = macs;
row.score_lanes = lanes;
row.II_assumed = II;
row.cycles_score_map = cycles_score;
row.cycles_topK = cycles_topK;
row.cycles_total_est = cycles_score + cycles_topK;
row.throughput_candidate_per_cycle = lanes / II;
row.comment = 'score core estimate for Step11 controlled pair2d DML candidate scoring';
end

function keypoints_tbl = build_step12_keypoints_local(summary_tbl, storage_tbl, bandwidth_tbl, adapter_info, best_info, cfg12)
total_MB = sum(storage_tbl.total_MB);
total_BRAM = sum(storage_tbl.BRAM36_equivalent);
total_URAM = sum(storage_tbl.URAM288_equivalent);
formal_trial_count = 0;
if ~cfg12.quick_mode_flag && height(summary_tbl) > 0
    formal_trial_count = max(summary_tbl.num_trials);
end
smoke_ranking_pass_flag = 0;
smoke_topK_pass_flag = 0;
smoke_fixed_point_pass_flag = 0;
smoke_recommended_fixed_point_format = 'not_recommended';
proceed_to_rtl_score_core_smoke_flag = 0;
ranking_pass_flag = best_info.ranking_pass_flag;
topK_pass_flag = best_info.topK_pass_flag;
fixed_point_pass_flag = best_info.fixed_point_pass_flag;
recommended_fixed_point_format = best_info.recommended_fixed_point_format;
blocker_if_any = best_info.blocker_if_any;
proceed_to_rtl_score_core_flag = best_info.proceed_to_rtl_score_core_flag;
if cfg12.quick_mode_flag
    smoke_ranking_pass_flag = best_info.ranking_pass_flag;
    smoke_topK_pass_flag = best_info.topK_pass_flag;
    smoke_fixed_point_pass_flag = best_info.fixed_point_pass_flag;
    smoke_recommended_fixed_point_format = best_info.recommended_fixed_point_format;
    proceed_to_rtl_score_core_smoke_flag = double(smoke_fixed_point_pass_flag);
    ranking_pass_flag = false;
    topK_pass_flag = false;
    fixed_point_pass_flag = false;
    recommended_fixed_point_format = 'not_recommended_until_formal_validation';
    blocker_if_any = 'formal_validation_not_run';
    proceed_to_rtl_score_core_flag = 0;
end
pairs = { ...
    'step11_adapter_found_flag', adapter_info.step11_adapter_found_flag; ...
    'uses_step89_results_flag', 0; ...
    'formal_trial_count', formal_trial_count; ...
    'quick_mode_flag', cfg12.quick_mode_flag; ...
    'smoke_ranking_pass_flag', smoke_ranking_pass_flag; ...
    'smoke_topK_pass_flag', smoke_topK_pass_flag; ...
    'smoke_fixed_point_pass_flag', smoke_fixed_point_pass_flag; ...
    'smoke_recommended_fixed_point_format', smoke_recommended_fixed_point_format; ...
    'score_direction', cfg12.score_direction; ...
    'score_direction_inferred_flag', cfg12.score_direction_inferred_flag; ...
    'topK_default', cfg12.topK_default; ...
    'reliable_margin_threshold', cfg12.reliable_margin_threshold; ...
    'best_fixed_point_mode', best_info.mode_name; ...
    'best_fixed_point_reliable_top1_preservation', best_info.reliable_top1_preservation; ...
    'best_fixed_point_reliable_topK_preservation', best_info.reliable_topK_preservation; ...
    'best_fixed_point_overall_topK_preservation', best_info.overall_topK_preservation; ...
    'best_fixed_point_argmax_changed_reliable', best_info.argmax_changed_reliable; ...
    'best_fixed_point_score_gap_flip_reliable', best_info.score_gap_flip_reliable; ...
    'ranking_pass_flag', ranking_pass_flag; ...
    'topK_pass_flag', topK_pass_flag; ...
    'fixed_point_pass_flag', fixed_point_pass_flag; ...
    'recommended_fixed_point_format', recommended_fixed_point_format; ...
    'blocker_if_any', blocker_if_any; ...
    'proceed_to_rtl_score_core_flag', proceed_to_rtl_score_core_flag; ...
    'proceed_to_rtl_score_core_smoke_flag', proceed_to_rtl_score_core_smoke_flag; ...
    'proceed_to_full_fpga_backend_flag', best_info.proceed_to_full_fpga_backend_flag; ...
    'cache_memory_MB_total_est', total_MB; ...
    'BRAM36_total_est', total_BRAM; ...
    'URAM288_total_est', total_URAM};
keypoints_tbl = key_value_table_local(pairs);
end

function worst_tbl = build_step12_worst_cases_local(trial_tbl)
rows = repmat(make_worst_row_template_local(), 0, 1);
rows(end + 1, 1) = worst_from_max_local(trial_tbl, 'topK_miss_count', 'max_topK_miss_count');
changed = trial_tbl(trial_tbl.argmax_changed_flag, :);
rows(end + 1, 1) = worst_from_max_local(changed, 'score_gap_norm_baseline', 'argmax_changed_largest_baseline_gap');
rows(end + 1, 1) = worst_from_max_local(trial_tbl, 'score_gap_rel_error', 'max_score_gap_rel_error');
policy_changed = trial_tbl(~trial_tbl.same_policy_flag, :);
rows(end + 1, 1) = worst_from_max_local(policy_changed, 'same_policy_flag', 'policy_changed_sample');
rows(end + 1, 1) = worst_from_max_local(trial_tbl, 'max_clip_rate', 'max_clip_or_overflow_sample');
worst_tbl = struct2table(rows);
end

function row = make_worst_row_template_local()
row = struct('case_type', '', 'trial_index', NaN, 'scenario_name', '', 'quant_mode', '', ...
    'metric_name', '', 'metric_value', NaN, 'topK_miss_count', NaN, 'argmax_changed_flag', false, ...
    'score_gap_norm_baseline', NaN, 'score_gap_rel_error', NaN, 'max_clip_rate', NaN, 'note', '');
end

function row = worst_from_max_local(T, metric_name, case_type)
row = make_worst_row_template_local();
row.case_type = case_type;
row.metric_name = metric_name;
if isempty(T) || height(T) == 0 || ~ismember(metric_name, T.Properties.VariableNames)
    row.note = 'no matching sample';
    return;
end
values = T.(metric_name);
if islogical(values)
    values = double(values);
end
[value, idx] = max_or_nan_with_index_local(values);
if ~isfinite(value)
    row.note = 'metric is not finite';
    return;
end
row.trial_index = T.trial_index(idx);
row.scenario_name = char(T.scenario_name{idx});
row.quant_mode = char(T.quant_mode{idx});
row.metric_value = value;
row.topK_miss_count = T.topK_miss_count(idx);
row.argmax_changed_flag = T.argmax_changed_flag(idx);
row.score_gap_norm_baseline = T.score_gap_norm_baseline(idx);
row.score_gap_rel_error = T.score_gap_rel_error(idx);
row.max_clip_rate = T.max_clip_rate(idx);
row.note = 'see trial CSV for full fields';
end

function recommendation_tbl = build_step12_recommendations_local(keypoints_tbl)
fixed_pass = logical(str2double(get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag')));
quick_mode = logical(str2double(get_keypoint_value_local(keypoints_tbl, 'quick_mode_flag')));
smoke_pass = logical(str2double(get_keypoint_value_local(keypoints_tbl, 'smoke_fixed_point_pass_flag')));
if quick_mode && smoke_pass
    recommendation = 'quick_smoke_passed_run_formal_validation_before_rtl';
    rationale = 'quick smoke passed the adapter and metric chain, but formal fixed_point_pass_flag remains zero until formal validation runs';
elseif fixed_pass
    recommendation = 'proceed_to_rtl_score_core_prototype_only';
    rationale = 'ranking and topK preservation passed for the recommended fixed-point score-core mode';
else
    recommendation = 'do_not_proceed_to_rtl_score_core_until_score_ranking_or_topK_closes';
    rationale = get_keypoint_value_local(keypoints_tbl, 'blocker_if_any');
end
recommendation_tbl = table({recommendation}, {rationale}, ...
    {get_keypoint_value_local(keypoints_tbl, 'recommended_fixed_point_format')}, ...
    str2double(get_keypoint_value_local(keypoints_tbl, 'proceed_to_rtl_score_core_flag')), ...
    str2double(get_keypoint_value_local(keypoints_tbl, 'proceed_to_rtl_score_core_smoke_flag')), ...
    str2double(get_keypoint_value_local(keypoints_tbl, 'proceed_to_full_fpga_backend_flag')), ...
    'VariableNames', {'recommendation', 'rationale', 'recommended_fixed_point_format', ...
    'proceed_to_rtl_score_core_flag', 'proceed_to_rtl_score_core_smoke_flag', 'proceed_to_full_fpga_backend_flag'});
end

function [trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, worst_tbl, recommendation_tbl] = build_step12_blocker_outputs_local(cfg12, adapter_info)
trial_tbl = struct2table(make_trial_row_template_local(), 'AsArray', true);
trial_tbl(1, :) = [];
summary_tbl = struct2table(make_summary_row_template_local(), 'AsArray', true);
summary_tbl(1, :) = [];
score_gap_tbl = struct2table(make_score_gap_row_template_local(), 'AsArray', true);
score_gap_tbl(1, :) = [];
topk_tbl = struct2table(make_topk_row_template_local(), 'AsArray', true);
topk_tbl(1, :) = [];
storage_tbl = struct2table(make_storage_row_template_local(), 'AsArray', true);
storage_tbl(1, :) = [];
bandwidth_tbl = struct2table(make_bandwidth_row_template_local(), 'AsArray', true);
bandwidth_tbl(1, :) = [];
worst_tbl = struct2table(make_worst_row_template_local(), 'AsArray', true);
worst_tbl(1, :) = [];
best_info = struct('mode_name', 'not_recommended', 'recommended_fixed_point_format', 'not_recommended', ...
    'ranking_pass_flag', false, 'topK_pass_flag', false, 'fixed_point_pass_flag', false, ...
    'blocker_if_any', 'step11_score_function_not_exposed', 'component_bits', 16, ...
    'proceed_to_rtl_score_core_flag', 0, 'proceed_to_full_fpga_backend_flag', 0, ...
    'reliable_top1_preservation', NaN, 'reliable_topK_preservation', NaN, ...
    'overall_topK_preservation', NaN, 'argmax_changed_reliable', NaN, 'score_gap_flip_reliable', NaN);
if isfield(adapter_info, 'blocker_if_any') && ~isempty(adapter_info.blocker_if_any)
    best_info.blocker_if_any = adapter_info.blocker_if_any;
end
storage_placeholder = make_storage_row_local('adapter_not_available', 0, 16, 0, 0, 'Step11 score adapter not available; no storage estimate generated');
storage_tbl = struct2table(storage_placeholder, 'AsArray', true);
bandwidth_placeholder = make_bandwidth_row_local('adapter_not_available', 0, cfg12.topK_default, 0, 16, 1);
bandwidth_placeholder.comment = 'Step11 score adapter not available; no bandwidth estimate generated';
bandwidth_tbl = struct2table(bandwidth_placeholder, 'AsArray', true);
keypoints_tbl = build_step12_keypoints_local(summary_tbl, storage_tbl, bandwidth_tbl, adapter_info, best_info, cfg12);
recommendation_tbl = build_step12_recommendations_local(keypoints_tbl);
end

function write_step12_tables_local(cfg12, trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, worst_tbl, recommendation_tbl)
writetable(trial_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_trial.csv'));
writetable(summary_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_summary.csv'));
writetable(keypoints_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_keypoints.csv'), 'WriteVariableNames', false);
writetable(score_gap_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_score_gap.csv'));
writetable(topk_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_topk.csv'));
writetable(storage_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_storage_estimate.csv'));
writetable(bandwidth_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_bandwidth_estimate.csv'));
writetable(worst_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_worst_cases.csv'));
writetable(recommendation_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_recommendations.csv'));
end

function adapter_info_light = make_adapter_info_light_local(adapter_info)
adapter_info_light = adapter_info;
if isfield(adapter_info_light, 'context_metadata')
    adapter_info_light = rmfield(adapter_info_light, 'context_metadata');
end
if isfield(adapter_info, 'context_metadata')
    cm = adapter_info.context_metadata;
    keep = {'route_name','W_method','B','N_elements','cache_type','cache_source', ...
        'cache_memory_MB','C05_config_id','C05_config_name','lambda','created_by'};
    context_metadata_light = struct();
    for idx = 1:numel(keep)
        if isfield(cm, keep{idx})
            context_metadata_light.(keep{idx}) = cm.(keep{idx});
        end
    end
    adapter_info_light.context_metadata_light = context_metadata_light;
end
adapter_info_light.light_note = 'Full obs/context/G_cache/candidate_table objects are intentionally excluded from the default light MAT.';
end

function manifest_path = write_step12_mat_manifest_local(cfg12, mat_light_path, mat_full_path)
manifest_path = fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_mat_manifest.md');
fid = fopen(manifest_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('step12:ManifestOpenFailed', 'Could not open manifest: %s', manifest_path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Step12 MAT Manifest\n\n');
fprintf(fid, '- Full MAT can be regenerated by running `setenv(''STEP12_SAVE_FULL_MAT'',''1'')` before `run_step12_beamspace_ml_fpga_boundary`.\n');
fprintf(fid, '- Full MAT is not tracked by Git by default because it is reproducible and can exceed GitHub size-warning thresholds.\n');
fprintf(fid, '- CSV, PNG, README, and the Chinese record document are the Git-tracked evidence artifacts.\n');
fprintf(fid, '- Quick smoke test is not formal validation; check `quick_mode_flag`, `smoke_fixed_point_pass_flag`, and formal `fixed_point_pass_flag` in keypoints.\n\n');
fprintf(fid, '## Current Run\n\n');
fprintf(fid, '- quick_mode_flag: %d\n', cfg12.quick_mode_flag);
fprintf(fid, '- save_full_mat_flag: %d\n', cfg12.save_full_mat_flag);
fprintf(fid, '- light MAT: `%s`\n', mat_light_path);
if cfg12.save_full_mat_flag
    fprintf(fid, '- full MAT: `%s`\n', mat_full_path);
else
    fprintf(fid, '- full MAT: not generated in this run\n');
end
clear cleanup;
end

function plot_paths = plot_step12_results_local(trial_tbl, summary_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, cfg12)
plot_paths = {};
plot_paths{end + 1} = plot_bar_from_summary_local(summary_tbl, 'overall_topK_set_preservation_rate', ...
    'TopK set preservation', fullfile(cfg12.result_dir, 'topK_preservation_by_quant_mode.png'));
plot_paths{end + 1} = plot_bar_from_summary_local(summary_tbl, 'reliable_top1_preservation_rate', ...
    'Reliable top1 preservation', fullfile(cfg12.result_dir, 'ranking_consistency_by_quant_mode.png'));
plot_paths{end + 1} = plot_scatter_gap_error_local(score_gap_tbl, fullfile(cfg12.result_dir, 'score_gap_error_by_quant_mode.png'));
plot_paths{end + 1} = plot_argmax_vs_gap_local(trial_tbl, fullfile(cfg12.result_dir, 'argmax_change_vs_score_gap.png'));
plot_paths{end + 1} = plot_storage_local(storage_tbl, fullfile(cfg12.result_dir, 'cache_storage_by_object.png'));
plot_paths{end + 1} = plot_bandwidth_local(bandwidth_tbl, fullfile(cfg12.result_dir, 'cache_bandwidth_by_parallel_lanes.png'));
plot_paths{end + 1} = plot_recommended_modes_local(summary_tbl, fullfile(cfg12.result_dir, 'fixed_point_recommended_modes.png'));
end

function path_out = plot_bar_from_summary_local(summary_tbl, field_name, title_text, path_out)
fig = figure('Visible', 'off');
if isempty(summary_tbl) || height(summary_tbl) == 0
    bar(0);
    title([title_text, ' (no data)']);
else
    values = summary_tbl.(field_name);
    bar(values);
    title(title_text);
    ylabel(field_name, 'Interpreter', 'none');
    xticks(1:height(summary_tbl));
    xticklabels(summary_tbl.quant_mode);
    xtickangle(35);
    ylim([0, max(1, max(values) * 1.05)]);
    grid on;
end
saveas(fig, path_out);
close(fig);
end

function path_out = plot_scatter_gap_error_local(score_gap_tbl, path_out)
fig = figure('Visible', 'off');
if isempty(score_gap_tbl) || height(score_gap_tbl) == 0
    plot(0, 0, '.');
    title('Score gap error (no data)');
else
    scatter(score_gap_tbl.score_gap_norm_baseline, score_gap_tbl.score_gap_rel_error, 18, 'filled');
    set(gca, 'XScale', 'log', 'YScale', 'log');
    xlabel('baseline normalized top1-top2 gap');
    ylabel('relative error of baseline-pair gap');
    title('Score gap error by quant mode');
    grid on;
end
saveas(fig, path_out);
close(fig);
end

function path_out = plot_argmax_vs_gap_local(trial_tbl, path_out)
fig = figure('Visible', 'off');
if isempty(trial_tbl) || height(trial_tbl) == 0
    plot(0, 0, '.');
    title('Argmax change vs score gap (no data)');
else
    scatter(trial_tbl.score_gap_norm_baseline, double(trial_tbl.argmax_changed_flag), 18, 'filled');
    set(gca, 'XScale', 'log');
    xlabel('baseline normalized top1-top2 gap');
    ylabel('argmax changed');
    title('Argmax change vs score gap');
    yticks([0, 1]);
    grid on;
end
saveas(fig, path_out);
close(fig);
end

function path_out = plot_storage_local(storage_tbl, path_out)
fig = figure('Visible', 'off');
if isempty(storage_tbl) || height(storage_tbl) == 0
    bar(0);
    title('Storage estimate (no data)');
else
    bar(storage_tbl.total_MB);
    ylabel('MB');
    title('Cache and buffer storage by object');
    xticks(1:height(storage_tbl));
    xticklabels(storage_tbl.object_name);
    xtickangle(35);
    grid on;
end
saveas(fig, path_out);
close(fig);
end

function path_out = plot_bandwidth_local(bandwidth_tbl, path_out)
fig = figure('Visible', 'off');
if isempty(bandwidth_tbl) || height(bandwidth_tbl) == 0
    bar(0);
    title('Bandwidth estimate (no data)');
else
    lanes = unique(bandwidth_tbl.score_lanes);
    values = nan(numel(lanes), 1);
    for idx = 1:numel(lanes)
        values(idx) = mean(bandwidth_tbl.throughput_candidate_per_cycle(bandwidth_tbl.score_lanes == lanes(idx)));
    end
    bar(lanes, values);
    xlabel('score lanes');
    ylabel('candidate / cycle');
    title('Estimated score throughput by parallel lanes');
    grid on;
end
saveas(fig, path_out);
close(fig);
end

function path_out = plot_recommended_modes_local(summary_tbl, path_out)
fig = figure('Visible', 'off');
if isempty(summary_tbl) || height(summary_tbl) == 0
    bar(0);
    title('Fixed-point recommended modes (no data)');
else
    values = double(summary_tbl.fixed_point_pass_flag) + 0.15 * double(summary_tbl.recommendation_candidate_flag);
    bar(values);
    ylabel('pass flag + recommendation marker');
    title('Fixed-point recommended modes');
    xticks(1:height(summary_tbl));
    xticklabels(summary_tbl.quant_mode);
    xtickangle(35);
    grid on;
end
saveas(fig, path_out);
close(fig);
end

function doc_path = write_step12_record_doc_local(cfg12, adapter_info, summary_tbl, keypoints_tbl, storage_tbl, bandwidth_tbl, worst_tbl)
doc_path = fullfile(cfg12.step_dir, '第12步_波束级ML_FPGA可行性边界验证记录.md');
fid = fopen(doc_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('step12:DocOpenFailed', 'Could not open doc: %s', doc_path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# 第12步 波束级ML FPGA可行性边界验证记录\n\n');
fprintf(fid, '## 本轮目的\n\n');
fprintf(fid, '第12步用于第11.x波束级ML的FPGA feasibility boundary validation，重点验证有限字长下ML score ranking consistency和fixed-point topK preservation。\n\n');
fprintf(fid, '本步骤不是完整FPGA RTL，不是bit-true HDL仿真，也不是完整纯FPGA backend通过声明。\n\n');
fprintf(fid, '## 第11.x adapter来源\n\n');
fprintf(fid, '- final入口：`%s`\n', adapter_info.entry_function);
fprintf(fid, '- score函数：`%s`\n', adapter_info.score_function);
fprintf(fid, '- candidate范围：%s\n', adapter_info.candidate_scope);
fprintf(fid, '- adapter found flag：%d\n', adapter_info.step11_adapter_found_flag);
fprintf(fid, '- blocker：`%s`\n\n', get_keypoint_value_local(keypoints_tbl, 'blocker_if_any'));
fprintf(fid, '## quantization modes\n\n');
fprintf(fid, '包含 double_baseline、float32_all、W/G_cache/Z/Rz单对象整数模式、combined_int16/int18/int24以及mixed_Z16_G24系列。float32_all仅作诊断参考，不参与fixed-point pass候选。\n\n');
fprintf(fid, '## score ranking / topK pass/fail标准\n\n');
fprintf(fid, '正式fixed-point pass/fail只由ML score ranking consistency和topK preservation决定。policy是工程风险诊断，正式fixed-point pass/fail由ML score ranking consistency和topK preservation决定。\n\n');
fprintf(fid, '- ranking_pass_flag：reliable_top1_preservation_rate >= 0.999，reliable_score_gap_sign_flip_rate == 0，argmax_changed_rate_on_reliable_margin <= 0.001。\n');
fprintf(fid, '- topK_pass_flag：reliable_topK_set_preservation_rate >= 0.995，overall_topK_set_preservation_rate >= 0.980，reliable_topK_miss_rate <= 0.005。\n');
fprintf(fid, '- fixed_point_pass_flag = ranking_pass_flag AND topK_pass_flag。\n\n');
fprintf(fid, '## 总体结果表\n\n');
write_markdown_table_from_table_local(fid, summary_tbl, 12);
fprintf(fid, '\n## cache storage估算\n\n');
write_markdown_table_from_table_local(fid, storage_tbl, 12);
fprintf(fid, '\n## bandwidth / score lane估算\n\n');
write_markdown_table_from_table_local(fid, bandwidth_tbl, 12);
fprintf(fid, '\n## worst cases总结\n\n');
write_markdown_table_from_table_local(fid, worst_tbl, 12);
fprintf(fid, '\n## 最终判断\n\n');
fprintf(fid, '- quick_mode_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'quick_mode_flag'));
fprintf(fid, '- smoke_fixed_point_pass_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'smoke_fixed_point_pass_flag'));
fprintf(fid, '- smoke_recommended_fixed_point_format：`%s`\n', get_keypoint_value_local(keypoints_tbl, 'smoke_recommended_fixed_point_format'));
fprintf(fid, '- fixed_point_pass_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag'));
fprintf(fid, '- recommended_fixed_point_format：`%s`\n', get_keypoint_value_local(keypoints_tbl, 'recommended_fixed_point_format'));
fprintf(fid, '- proceed_to_rtl_score_core_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'proceed_to_rtl_score_core_flag'));
fprintf(fid, '- proceed_to_rtl_score_core_smoke_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'proceed_to_rtl_score_core_smoke_flag'));
fprintf(fid, '- proceed_to_full_fpga_backend_flag：%s\n\n', get_keypoint_value_local(keypoints_tbl, 'proceed_to_full_fpga_backend_flag'));
if cfg12.quick_mode_flag
    fprintf(fid, '本次为 quick smoke test。smoke_fixed_point_pass_flag = %s 仅说明 Step12 adapter、量化流程、score ranking/topK 统计和结果输出链路打通；formal fixed_point_pass_flag 仍为 %s。下一步应先运行 formal validation，再决定是否进入 RTL score core prototype。\n\n', ...
        get_keypoint_value_local(keypoints_tbl, 'smoke_fixed_point_pass_flag'), get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag'));
end
fprintf(fid, '## 下一步建议\n\n');
if cfg12.quick_mode_flag
    fprintf(fid, 'quick mode 下不建议直接进入 RTL score core prototype。请先运行 formal validation，并检查正式 fixed_point_pass_flag、recommended_fixed_point_format 与 worst cases。\n');
else
    fprintf(fid, '若 formal fixed_point_pass_flag 为 1，下一步只建议进入 RTL score core prototype；仍需独立完成 bit-true HDL 仿真、接口时序、cache 访问调度和板级验证。\n');
end
end

function write_markdown_table_from_table_local(fid, T, max_rows)
if isempty(T) || height(T) == 0
    fprintf(fid, '_No rows._\n');
    return;
end
max_rows = min(max_rows, height(T));
vars = T.Properties.VariableNames;
fprintf(fid, '| %s |\n', strjoin(vars, ' | '));
fprintf(fid, '| %s |\n', strjoin(repmat({'---'}, 1, numel(vars)), ' | '));
for i = 1:max_rows
    parts = cell(1, numel(vars));
    for j = 1:numel(vars)
        parts{j} = markdown_value_local(T.(vars{j})(i));
    end
    fprintf(fid, '| %s |\n', strjoin(parts, ' | '));
end
if height(T) > max_rows
    fprintf(fid, '\n_Only first %d rows shown; see CSV for full table._\n', max_rows);
end
end

function s = markdown_value_local(v)
if iscell(v)
    v = v{1};
end
if isstring(v)
    s = char(v);
elseif ischar(v)
    s = v;
elseif islogical(v)
    s = sprintf('%d', v);
elseif isnumeric(v)
    if isfinite(v)
        s = sprintf('%.6g', v);
    else
        s = 'NaN';
    end
else
    s = '?';
end
s = strrep(s, '|', '/');
end

function T = key_value_table_local(pairs)
key = pairs(:, 1);
value = cell(size(key));
for idx = 1:numel(key)
    v = pairs{idx, 2};
    if islogical(v)
        value{idx} = sprintf('%d', v);
    elseif isnumeric(v)
        if isscalar(v)
            value{idx} = sprintf('%.12g', v);
        else
            value{idx} = mat2str(v);
        end
    elseif isstring(v)
        value{idx} = char(v);
    elseif ischar(v)
        value{idx} = v;
    else
        value{idx} = '?';
    end
end
T = table(key, value, 'VariableNames', {'key', 'value'});
end

function value = get_keypoint_value_local(keypoints_tbl, key)
value = '';
if isempty(keypoints_tbl) || height(keypoints_tbl) == 0
    return;
end
idx = find(strcmp(keypoints_tbl.key, key), 1);
if ~isempty(idx)
    value = keypoints_tbl.value{idx};
end
end

function log_lines = append_log_local(log_lines, fmt, varargin)
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
if isempty(varargin)
    line = fmt;
else
    line = sprintf(fmt, varargin{:});
end
log_lines{end + 1, 1} = sprintf('[%s] %s', timestamp, line);
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('step12:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{idx});
end
clear cleanup;
end

function value = safe_field_local(s, field, fallback)
value = fallback;
if isstruct(s) && isfield(s, field)
    value = s.(field);
end
if isstring(value)
    value = char(value);
end
end

function v = finite_or_zero_local(v)
if ~(isscalar(v) && isfinite(v))
    v = 0;
end
end

function e = relative_error_local(a, b)
a = a(:);
b = b(:);
mask = isfinite(real(a)) & isfinite(real(b)) & isfinite(imag(a)) & isfinite(imag(b));
if ~any(mask)
    e = NaN;
else
    e = norm(double(a(mask)) - double(b(mask))) / max(norm(double(b(mask))), eps);
end
end

function v = mean_or_nan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function v = min_or_nan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = min(x);
end
end

function v = max_or_nan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = max(x);
end
end

function [v, idx] = max_or_nan_with_index_local(x)
mask = isfinite(x);
if ~any(mask)
    v = NaN;
    idx = 1;
else
    x2 = x;
    x2(~mask) = -Inf;
    [v, idx] = max(x2);
end
end

function p = percentile_local(x, pct)
x = sort(x(isfinite(x)));
if isempty(x)
    p = NaN;
    return;
end
idx = max(1, min(numel(x), ceil(numel(x) * pct / 100)));
p = x(idx);
end

function rho = rank_spearman_local(a, b)
ra = ordinal_rank_desc_local(a);
rb = ordinal_rank_desc_local(b);
mask = isfinite(ra) & isfinite(rb);
if nnz(mask) < 2 || std(ra(mask)) == 0 || std(rb(mask)) == 0
    rho = NaN;
else
    C = corrcoef(ra(mask), rb(mask));
    rho = C(1, 2);
end
end

function tau = rank_kendall_if_easy_local(a, b, max_n)
n = numel(a);
if n > max_n
    tau = NaN;
    return;
end
ra = ordinal_rank_desc_local(a);
rb = ordinal_rank_desc_local(b);
num = 0;
den = 0;
for i = 1:(n - 1)
    for j = (i + 1):n
        sa = sign(ra(i) - ra(j));
        sb = sign(rb(i) - rb(j));
        if sa ~= 0 && sb ~= 0
            num = num + sa * sb;
            den = den + 1;
        end
    end
end
if den == 0
    tau = NaN;
else
    tau = num / den;
end
end

function r = ordinal_rank_desc_local(score)
score = score(:);
[~, order] = sortrows([-score, (1:numel(score)).']);
r = nan(size(score));
r(order) = (1:numel(score)).';
end

function bin = margin_bin_local(gap_norm, cfg12)
if gap_norm >= cfg12.reliable_margin_threshold
    bin = 'reliable';
elseif gap_norm >= cfg12.weak_margin_threshold
    bin = 'weak_margin';
else
    bin = 'boundary_like';
end
end

function [az_rmse, el_rmse] = pair_rmse_to_truth_local(az_hat, el_hat, truth)
az_rmse = NaN;
el_rmse = NaN;
if ~isstruct(truth) || ~isfield(truth, 'az_true') || ~isfield(truth, 'el_true')
    return;
end
az_true = truth.az_true(:).';
el_true = truth.el_true(:).';
if numel(az_hat) ~= 2 || numel(el_hat) ~= 2 || numel(az_true) ~= 2 || numel(el_true) ~= 2
    return;
end
err_same = (az_hat(:).' - az_true).^2 + (el_hat(:).' - el_true).^2;
err_swap = (az_hat(:).' - fliplr(az_true)).^2 + (el_hat(:).' - fliplr(el_true)).^2;
if sum(err_swap) < sum(err_same)
    az_true = fliplr(az_true);
    el_true = fliplr(el_true);
end
az_rmse = sqrt(mean((az_hat(:).' - az_true).^2));
el_rmse = sqrt(mean((el_hat(:).' - el_true).^2));
end
