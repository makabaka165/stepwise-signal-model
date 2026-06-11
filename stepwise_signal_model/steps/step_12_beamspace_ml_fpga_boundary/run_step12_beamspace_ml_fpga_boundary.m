clc
clear
close all

cfg12 = make_step12_cfg_local();
[cfg12, log_lines] = init_step12_paths_local(cfg12);
adapter_info = inspect_step11_adapter_local(cfg12);
modes = filter_step12_modes_local(build_step12_quant_modes_local(), cfg12);

log_lines = append_log_local(log_lines, 'Step12 starts');
log_lines = append_log_local(log_lines, 'Quick mode: %d', cfg12.quick_mode_flag);
log_lines = append_log_local(log_lines, 'Chunked run: %d', cfg12.chunked_run_flag);
log_lines = append_log_local(log_lines, 'Aggregate only: %d', cfg12.aggregate_only_flag);
log_lines = append_log_local(log_lines, 'Mode set: %s', cfg12.mode_set);
log_lines = append_log_local(log_lines, 'Score engine: %s', cfg12.score_engine);
log_lines = append_log_local(log_lines, 'Step11 adapter found: %d', adapter_info.step11_adapter_found_flag);

if cfg12.aggregate_only_flag
    [trial_tbl, topk_tbl, score_gap_tbl, profile_tbl, aggregate_info] = load_step12_chunk_partials_local(cfg12, modes);
    summary_tbl = build_step12_summary_table_local(trial_tbl, modes, cfg12);
    mode_selection_tbl = build_step12_mode_selection_table_from_trial_local(summary_tbl, modes, trial_tbl, cfg12);
    score_gap_bins_tbl = build_step12_score_gap_bins_local(trial_tbl, modes, cfg12);
    best_info = select_best_fixed_point_mode_local(summary_tbl, modes, mode_selection_tbl, cfg12);
    storage_tbl = build_step12_storage_estimate_from_trial_local(trial_tbl, best_info, cfg12);
    bandwidth_tbl = build_step12_bandwidth_estimate_from_trial_local(trial_tbl, best_info, cfg12);
    cfg12.formal_plan_total_obs = aggregate_info.formal_plan_total_obs;
    cfg12.formal_plan_completed_obs = aggregate_info.formal_plan_completed_obs;
    cfg12.formal_plan_complete_flag = aggregate_info.formal_plan_complete_flag;
    cfg12.chunks_detected = aggregate_info.chunks_detected;
    cfg12.chunks_completed = aggregate_info.chunks_completed;
    keypoints_tbl = build_step12_keypoints_local(summary_tbl, storage_tbl, bandwidth_tbl, adapter_info, best_info, mode_selection_tbl, score_gap_bins_tbl, cfg12);
    worst_tbl = build_step12_worst_cases_local(trial_tbl);
    recommendation_tbl = build_step12_recommendations_local(keypoints_tbl);
    profile_summary_tbl = build_step12_profile_summary_local(profile_tbl, cfg12);
    plot_paths = plot_step12_results_local(trial_tbl, summary_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, cfg12);
    write_step12_tables_local(cfg12, trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, ...
        storage_tbl, bandwidth_tbl, worst_tbl, recommendation_tbl, mode_selection_tbl, score_gap_bins_tbl, profile_tbl, profile_summary_tbl);
    golden_manifest_path = export_step12_golden_vectors_local(repmat(make_empty_obs_local(), 0, 1), trial_tbl, keypoints_tbl, modes, cfg12);
    doc_path = write_step12_record_doc_clean_local(cfg12, adapter_info, summary_tbl, keypoints_tbl, storage_tbl, bandwidth_tbl, ...
        worst_tbl, mode_selection_tbl, score_gap_bins_tbl, recommendation_tbl, golden_manifest_path, profile_summary_tbl);
    adapter_info_light = make_adapter_info_light_local(adapter_info);
    mat_light_path = fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_result_light.mat');
    save(mat_light_path, 'cfg12', 'adapter_info_light', 'modes', 'summary_tbl', ...
        'keypoints_tbl', 'score_gap_tbl', 'topk_tbl', 'score_gap_bins_tbl', 'storage_tbl', ...
        'bandwidth_tbl', 'mode_selection_tbl', 'worst_tbl', 'recommendation_tbl', ...
        'profile_tbl', 'profile_summary_tbl', 'plot_paths', 'doc_path', 'golden_manifest_path');
    manifest_path = write_step12_mat_manifest_local(cfg12, mat_light_path, '');
    log_lines = append_log_local(log_lines, 'Aggregate-only loaded trial rows: %d', height(trial_tbl));
    log_lines = append_log_local(log_lines, 'Wrote aggregate light MAT: %s', mat_light_path);
    log_lines = append_log_local(log_lines, 'Wrote MAT manifest: %s', manifest_path);
    log_lines = append_log_local(log_lines, 'Wrote record doc: %s', doc_path);
    write_log_local(fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary.log'), log_lines);
    fprintf('Step12 aggregate-only validation complete.\n');
    fprintf('Result directory: %s\n', cfg12.result_dir);
    return;
end

obs = repmat(make_empty_obs_local(), 0, 1);
load_profile_tbl = make_profile_table_empty_local();
adapter_error = [];
if adapter_info.step11_adapter_found_flag
    try
        [obs, adapter_info, load_profile_tbl] = load_or_run_step11_ml_observations_local(cfg12, adapter_info, modes);
        if isfield(adapter_info, 'formal_plan_total_obs')
            cfg12.formal_plan_total_obs = adapter_info.formal_plan_total_obs;
        end
        if isfield(adapter_info, 'formal_plan_completed_obs')
            cfg12.formal_plan_completed_obs = adapter_info.formal_plan_completed_obs;
        end
        if isfield(adapter_info, 'formal_plan_complete_flag')
            cfg12.formal_plan_complete_flag = adapter_info.formal_plan_complete_flag;
        end
        if isfield(adapter_info, 'formal_plan_planned_obs')
            cfg12.formal_plan_planned_obs = adapter_info.formal_plan_planned_obs;
        end
        if isfield(adapter_info, 'completed_obs_before')
            cfg12.chunk_completed_obs_before = adapter_info.completed_obs_before;
        end
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
        bandwidth_tbl, worst_tbl, recommendation_tbl, mode_selection_tbl, score_gap_bins_tbl] = build_step12_blocker_outputs_local(cfg12, adapter_info, modes);
    profile_tbl = load_profile_tbl;
    profile_summary_tbl = build_step12_profile_summary_local(profile_tbl, cfg12);
    plot_paths = plot_step12_results_local(trial_tbl, summary_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, cfg12);
else
    [trial_tbl, topk_tbl, score_gap_tbl, quant_profile_tbl] = run_step12_quantization_trials_local(obs, modes, cfg12);
    profile_tbl = concat_tables_local(load_profile_tbl, quant_profile_tbl);
    summary_tbl = build_step12_summary_table_local(trial_tbl, modes, cfg12);
    mode_selection_tbl = build_step12_mode_selection_table_local(summary_tbl, modes, obs(1), cfg12);
    score_gap_bins_tbl = build_step12_score_gap_bins_local(trial_tbl, modes, cfg12);
    best_info = select_best_fixed_point_mode_local(summary_tbl, modes, mode_selection_tbl, cfg12);
    storage_tbl = build_step12_storage_estimate_local(obs(1), best_info, cfg12);
    bandwidth_tbl = build_step12_bandwidth_estimate_local(obs(1), best_info, cfg12);
    keypoints_tbl = build_step12_keypoints_local(summary_tbl, storage_tbl, bandwidth_tbl, adapter_info, best_info, mode_selection_tbl, score_gap_bins_tbl, cfg12);
    worst_tbl = build_step12_worst_cases_local(trial_tbl);
    recommendation_tbl = build_step12_recommendations_local(keypoints_tbl);
    profile_summary_tbl = build_step12_profile_summary_local(profile_tbl, cfg12);
    plot_paths = plot_step12_results_local(trial_tbl, summary_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, cfg12);
end

write_step12_tables_local(cfg12, trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, ...
    storage_tbl, bandwidth_tbl, worst_tbl, recommendation_tbl, mode_selection_tbl, score_gap_bins_tbl, profile_tbl, profile_summary_tbl);
golden_manifest_path = export_step12_golden_vectors_local(obs, trial_tbl, keypoints_tbl, modes, cfg12);
doc_path = write_step12_record_doc_clean_local(cfg12, adapter_info, summary_tbl, keypoints_tbl, storage_tbl, bandwidth_tbl, ...
    worst_tbl, mode_selection_tbl, score_gap_bins_tbl, recommendation_tbl, golden_manifest_path, profile_summary_tbl);
adapter_info_light = make_adapter_info_light_local(adapter_info);
mat_light_path = fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_result_light.mat');
save(mat_light_path, 'cfg12', 'adapter_info_light', 'modes', 'summary_tbl', ...
    'keypoints_tbl', 'score_gap_tbl', 'topk_tbl', 'score_gap_bins_tbl', 'storage_tbl', ...
    'bandwidth_tbl', 'mode_selection_tbl', 'worst_tbl', 'recommendation_tbl', ...
    'profile_tbl', 'profile_summary_tbl', 'plot_paths', 'doc_path', 'golden_manifest_path');
mat_full_path = '';
if cfg12.save_full_mat_flag
    mat_full_path = fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_result_full.mat');
    save(mat_full_path, 'cfg12', 'adapter_info', 'modes', 'obs', 'trial_tbl', 'summary_tbl', ...
        'keypoints_tbl', 'score_gap_tbl', 'topk_tbl', 'score_gap_bins_tbl', 'storage_tbl', ...
        'bandwidth_tbl', 'mode_selection_tbl', 'worst_tbl', 'recommendation_tbl', ...
        'profile_tbl', 'profile_summary_tbl', 'plot_paths', 'doc_path', 'golden_manifest_path', '-v7.3');
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
cfg12.export_golden_vectors_flag = strcmp(getenv('STEP12_EXPORT_GOLDEN_VECTORS'), '1');
cfg12.golden_vector_limit = parse_env_scalar_local('STEP12_GOLDEN_VECTOR_LIMIT', 256);
cfg12.run_tag = strtrim(getenv('STEP12_RUN_TAG'));
cfg12.min_formal_obs = parse_env_scalar_local('STEP12_MIN_FORMAL_OBS', 300);
cfg12.run_step11_full_backend_diagnostic_flag = cfg12.quick_mode_flag || strcmp(getenv('STEP12_RUN_FULL_STEP11_BACKEND'), '1');
cfg12.enable_static_quant_cache_flag = ~strcmp(getenv('STEP12_DISABLE_STATIC_QUANT_CACHE'), '1');
cfg12.chunk_id = parse_env_scalar_local('STEP12_CHUNK_ID', NaN);
cfg12.total_chunks = parse_env_scalar_local('STEP12_TOTAL_CHUNKS', NaN);
cfg12.max_obs_per_run = parse_env_scalar_local('STEP12_MAX_OBS_PER_RUN', Inf);
cfg12.resume_from_partials_flag = strcmp(getenv('STEP12_RESUME_FROM_PARTIALS'), '1');
cfg12.aggregate_only_flag = strcmp(getenv('STEP12_AGGREGATE_ONLY'), '1');
cfg12.profile_enable_flag = strcmp(getenv('STEP12_PROFILE_ENABLE'), '1');
cfg12.profile_top_n = max(1, floor(parse_env_scalar_local('STEP12_PROFILE_TOP_N', 20)));
cfg12.score_engine = strtrim(getenv('STEP12_SCORE_ENGINE'));
if isempty(cfg12.score_engine)
    cfg12.score_engine = 'loop_reference';
end
cfg12.mode_set = strtrim(getenv('STEP12_MODE_SET'));
cfg12.chunked_run_flag = cfg12.aggregate_only_flag || isfinite(cfg12.chunk_id) || isfinite(cfg12.total_chunks);
if cfg12.chunked_run_flag
    if cfg12.aggregate_only_flag
        if isfinite(cfg12.total_chunks)
            cfg12.total_chunks = floor(cfg12.total_chunks);
        end
    elseif ~(isfinite(cfg12.chunk_id) && isfinite(cfg12.total_chunks))
        error('step12:ChunkConfigMissing', 'STEP12_CHUNK_ID and STEP12_TOTAL_CHUNKS must both be set for chunked runs.');
    else
        cfg12.chunk_id = floor(cfg12.chunk_id);
        cfg12.total_chunks = floor(cfg12.total_chunks);
    end
    if ~cfg12.aggregate_only_flag && (cfg12.chunk_id < 1 || cfg12.total_chunks < 1 || cfg12.chunk_id > cfg12.total_chunks)
        error('step12:InvalidChunkConfig', 'Chunk id must be in [1, total_chunks]. Got %d of %d.', cfg12.chunk_id, cfg12.total_chunks);
    end
end
if cfg12.quick_mode_flag
    cfg12.center_az_list = 0;
    cfg12.scenario_limit = 2;
    cfg12.trials_per_scenario = 1;
    cfg12.formal_trials_per_scenario = NaN;
    if isempty(cfg12.mode_set)
        cfg12.mode_set = 'full_diagnostic';
    end
else
    cfg12.center_az_list = parse_env_numeric_list_local('STEP12_FORMAL_CENTER_AZ_LIST', [0, 4, 8, 15]);
    cfg12.scenario_limit = parse_env_scalar_local('STEP12_FORMAL_SCENARIO_LIMIT', Inf);
    formal_trials = parse_env_scalar_local('STEP12_FORMAL_TRIALS_PER_SCENARIO', 30);
    cfg12.formal_trials_per_scenario = max(1, floor(formal_trials));
    cfg12.trials_per_scenario = cfg12.formal_trials_per_scenario;
    cfg12.min_formal_obs = max(1, floor(cfg12.min_formal_obs));
    if isempty(cfg12.mode_set)
        cfg12.mode_set = 'formal_core';
    end
end
cfg12.golden_vector_limit = max(1, floor(cfg12.golden_vector_limit));
cfg12.max_obs_per_run = floor(cfg12.max_obs_per_run);
cfg12.rng_seed = 20260611;
cfg12.formal_trial_count = 0;
cfg12.formal_plan_total_obs = 0;
cfg12.formal_plan_completed_obs = 0;
cfg12.formal_plan_complete_flag = 0;
cfg12.formal_min_obs_satisfied_flag = 0;
cfg12.formal_plan_planned_obs = 0;
cfg12.chunk_completed_obs_before = 0;
cfg12.chunks_detected = 0;
cfg12.chunks_completed = 0;
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
cfg12.result_root_dir = fullfile(step_dir, cfg12.result_dir_name);
if isempty(cfg12.run_tag)
    cfg12.result_dir = cfg12.result_root_dir;
else
    cfg12.result_dir = fullfile(cfg12.result_root_dir, cfg12.run_tag);
end
if cfg12.aggregate_only_flag
    cfg12.run_result_dir = cfg12.result_dir;
    cfg12.chunk_root_dir = fullfile(cfg12.run_result_dir, 'chunks');
    cfg12.aggregate_dir = fullfile(cfg12.run_result_dir, 'aggregate');
    cfg12.result_dir = cfg12.aggregate_dir;
elseif cfg12.chunked_run_flag && ~cfg12.aggregate_only_flag
    cfg12.run_result_dir = cfg12.result_dir;
    cfg12.chunk_root_dir = fullfile(cfg12.run_result_dir, 'chunks');
    cfg12.chunk_dir = fullfile(cfg12.chunk_root_dir, sprintf('chunk_%03d', cfg12.chunk_id));
    cfg12.result_dir = cfg12.chunk_dir;
else
    cfg12.run_result_dir = cfg12.result_dir;
    cfg12.chunk_root_dir = fullfile(cfg12.run_result_dir, 'chunks');
    cfg12.chunk_dir = '';
end
if exist(cfg12.result_dir, 'dir') ~= 7
    mkdir(cfg12.result_dir);
end
if cfg12.chunked_run_flag && exist(cfg12.chunk_root_dir, 'dir') ~= 7
    mkdir(cfg12.chunk_root_dir);
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
log_lines = append_log_local(log_lines, 'Run tag: %s', cfg12.run_tag);
if cfg12.chunked_run_flag && ~cfg12.aggregate_only_flag
    log_lines = append_log_local(log_lines, 'Chunk: %d / %d', cfg12.chunk_id, cfg12.total_chunks);
elseif cfg12.aggregate_only_flag
    log_lines = append_log_local(log_lines, 'Aggregate-only chunk root: %s', cfg12.chunk_root_dir);
end
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

function modes_out = filter_step12_modes_local(modes, cfg12)
mode_set = char(cfg12.mode_set);
switch mode_set
    case 'full_diagnostic'
        keep = {modes.name};
    case 'formal_core'
        keep = {'double_baseline', 'float32_all', 'combined_int14', 'combined_int16', ...
            'combined_int18', 'combined_int24', 'mixed_Z16_G24_Rz24', 'W_int18_G24_Z16'};
    case 'recommendation_only'
        keep = {'double_baseline', 'combined_int16', 'combined_int18', ...
            'combined_int24', 'mixed_Z16_G24_Rz24'};
    otherwise
        warning('step12:UnknownModeSet', 'Unknown STEP12_MODE_SET=%s; using formal_core.', mode_set);
        keep = {'double_baseline', 'float32_all', 'combined_int14', 'combined_int16', ...
            'combined_int18', 'combined_int24', 'mixed_Z16_G24_Rz24', 'W_int18_G24_Z16'};
end
mask = false(size(modes));
for idx = 1:numel(modes)
    mask(idx) = any(strcmp(modes(idx).name, keep));
end
modes_out = modes(mask);
if isempty(modes_out)
    error('step12:EmptyModeSet', 'STEP12_MODE_SET=%s did not select any quantization modes.', mode_set);
end
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

function [obs, adapter_info, profile_tbl] = load_or_run_step11_ml_observations_local(cfg12, adapter_info, modes)
rng(cfg12.rng_seed, 'twister');
[context, context_metadata] = build_step11_7_runtime_context(cfg12.project_dir, cfg12.result_dir, 'DefaultCenterAz', 0);
plan_tbl = build_step12_observation_plan_local(cfg12);
plan_tbl = apply_step12_chunk_plan_local(plan_tbl, cfg12);
required_modes = {modes.name};
[completed_ids, partial_counts] = completed_obs_ids_from_partials_local(cfg12, required_modes);
plan_tbl.completed_flag = ismember(plan_tbl.obs_id, completed_ids);
writetable(plan_tbl, fullfile(cfg12.result_dir, 'step12_observation_plan.csv'));
if cfg12.resume_from_partials_flag
    run_tbl = plan_tbl(plan_tbl.planned_flag & ~plan_tbl.completed_flag, :);
else
    run_tbl = plan_tbl(plan_tbl.planned_flag, :);
end
if isfinite(cfg12.max_obs_per_run)
    run_tbl = run_tbl(1:min(height(run_tbl), cfg12.max_obs_per_run), :);
end
obs = repmat(make_empty_obs_local(), 0, 1);
profile_rows = repmat(make_profile_row_template_local(), 0, 1);
scenarios_all = build_step12_scenarios_local();
for iPlan = 1:height(run_tbl)
            plan = table_row_to_struct_local(run_tbl(iPlan, :));
            scenario = scenarios_all(plan.scenario_index);
            center_az = plan.center_az;
            iCenter = plan.center_index;
            iScenario = plan.scenario_index;
            iTrial = plan.trial_id;
            t_stage = tic;
            [input, truth, input_meta] = build_step11_7_frontend_like_input(context, scenario, center_az, iTrial, ...
                'FrontendState', 'controlled_pair2d_candidate', 'L', context.L_default, ...
                'CenterIndex', iCenter, 'ScenarioIndex', iScenario);
            profile_rows(end + 1, 1) = make_profile_row_local(plan, '', 'build_step11_input', toc(t_stage), NaN, cfg12.topK_default, NaN, 'Step11.7 frontend-like input builder'); %#ok<AGROW>
            if cfg12.run_step11_full_backend_diagnostic_flag
                t_stage = tic;
                backend_opts = struct('use_cache', true, 'run_direct_reference', false, 'allow_cache_fallback', true, 'runtime_timing', false);
                out = step11_7_final_cached_c05_beamspace_ml_backend(input, context, backend_opts);
                profile_rows(end + 1, 1) = make_profile_row_local(plan, '', 'run_step11_backend', toc(t_stage), NaN, cfg12.topK_default, NaN, 'Full Step11.7 backend diagnostic path'); %#ok<AGROW>
            else
                out = make_step12_backend_stub_local(input);
                profile_rows(end + 1, 1) = make_profile_row_local(plan, '', 'run_step11_backend', 0, NaN, cfg12.topK_default, NaN, 'Skipped full Step11.7 backend; using Step12 score-core adapter'); %#ok<AGROW>
            end
            t_stage = tic;
            obs_now = build_step12_observation_local(plan.obs_global_index, scenario, iCenter, iScenario, iTrial, ...
                input, truth, input_meta, out, context, context_metadata, cfg12);
            obs_now.obs_id = plan.obs_id;
            obs_now.obs_global_index = plan.obs_global_index;
            obs_now.chunk_id = plan.chunk_id_assigned;
            obs_now.total_chunks = cfg12.total_chunks;
            obs_now.run_tag = cfg12.run_tag;
            obs(end + 1, 1) = obs_now; %#ok<AGROW>
            profile_rows(end + 1, 1) = make_profile_row_local(plan, '', 'build_candidate_score_pack', toc(t_stage), obs_now.num_candidates, cfg12.topK_default, NaN, 'Build W/Y/Z/Rz/G_cache candidate score pack'); %#ok<AGROW>
end
adapter_info.context_metadata = context_metadata;
adapter_info.cache_memory_MB_reference = context.cache.cache_memory_MB;
adapter_info.observation_count = numel(obs);
adapter_info.formal_plan_total_obs = height(plan_tbl);
adapter_info.formal_plan_planned_obs = nnz(plan_tbl.planned_flag);
adapter_info.completed_obs_before = numel(completed_ids);
adapter_info.partial_trial_rows_before = partial_counts.trial_rows;
cfg12.formal_plan_total_obs = height(plan_tbl);
cfg12.formal_plan_completed_obs = numel(unique([completed_ids; cellstr(run_tbl.obs_id)]));
profile_tbl = struct2table(profile_rows);
if isempty(profile_rows)
    profile_tbl = make_profile_table_empty_local();
end
end

function scenarios = build_step12_scenarios_local()
scenarios = [ ...
    make_scenario_local('easy_noncoherent', 0.00, 0, 1.0, 1.27, 0.67, 30, 'easy'); ...
    make_scenario_local('strong_coherent', 0.99, 5, 1.0, 1.27, 0.37, 30, 'coherent'); ...
    make_scenario_local('hard_phase', 0.99, 150, 1.0, 0.83, 0.37, 30, 'hard_phase'); ...
    make_scenario_local('weak_secondary', 0.99, 150, 0.3, 0.83, 0.37, 30, 'weak_secondary'); ...
    make_scenario_local('low_snr_hard', 1.00, 150, 0.3, 0.83, 0.37, 20, 'low_snr'); ...
    make_scenario_local('near_tie_close_sep', 0.98, 90, 0.95, 0.41, 0.19, 28, 'near_tie'); ...
    make_scenario_local('medium_beta_coherent', 0.95, 45, 0.6, 0.83, 0.37, 26, 'medium_beta'); ...
    make_scenario_local('large_el_pair', 0.70, 20, 1.0, 1.27, 1.09, 30, 'large_el_pair'); ...
    make_scenario_local('cache_boundary_center', 0.90, 120, 0.8, 1.05, 0.67, 24, 'cache_boundary'); ...
    make_scenario_local('low_margin_score_gap', 0.995, 175, 0.85, 0.41, 0.19, 22, 'low_margin')];
end

function row = make_scenario_local(name, rho, phase_deg, beta, az_sep_deg, el_sep_deg, snr_db, difficulty)
row = struct('scenario_name', name, 'rho', rho, 'phase_deg', phase_deg, 'beta', beta, ...
    'az_sep_deg', az_sep_deg, 'el_sep_deg', el_sep_deg, 'snr_db', snr_db, ...
    'expected_difficulty_label', difficulty);
end

function plan_tbl = build_step12_observation_plan_local(cfg12)
scenarios = build_step12_scenarios_local();
if isfinite(cfg12.scenario_limit)
    scenario_count = min(cfg12.scenario_limit, numel(scenarios));
else
    scenario_count = numel(scenarios);
end
rows = repmat(make_plan_row_template_local(), 0, 1);
global_idx = 0;
if cfg12.chunked_run_flag
    total_chunks = cfg12.total_chunks;
else
    total_chunks = 1;
end
for iCenter = 1:numel(cfg12.center_az_list)
    center_az = cfg12.center_az_list(iCenter);
    for iScenario = 1:scenario_count
        scenario = scenarios(iScenario);
        for iTrial = 1:cfg12.trials_per_scenario
            global_idx = global_idx + 1;
            row = make_plan_row_template_local();
            row.obs_global_index = global_idx;
            row.obs_id = make_obs_id_local(center_az, scenario.scenario_name, iTrial);
            row.chunk_id_assigned = mod(global_idx - 1, total_chunks) + 1;
            row.total_chunks = total_chunks;
            row.run_tag = cfg12.run_tag;
            row.center_index = iCenter;
            row.center_az = center_az;
            row.scenario_name = scenario.scenario_name;
            row.scenario_index = iScenario;
            row.trial_id = iTrial;
            row.planned_flag = true;
            row.completed_flag = false;
            rows(end + 1, 1) = row; %#ok<AGROW>
        end
    end
end
plan_tbl = struct2table(rows);
end

function row = make_plan_row_template_local()
row = struct('obs_global_index', NaN, 'obs_id', '', 'chunk_id_assigned', NaN, ...
    'total_chunks', NaN, 'run_tag', '', 'center_index', NaN, 'center_az', NaN, 'scenario_name', '', 'scenario_index', NaN, ...
    'trial_id', NaN, 'planned_flag', false, 'completed_flag', false);
end

function plan_tbl = apply_step12_chunk_plan_local(plan_tbl, cfg12)
if cfg12.chunked_run_flag
    plan_tbl.planned_flag = plan_tbl.chunk_id_assigned == cfg12.chunk_id;
else
    plan_tbl.planned_flag = true(height(plan_tbl), 1);
end
end

function obs_id = make_obs_id_local(center_az, scenario_name, trial_id)
safe_name = regexprep(char(scenario_name), '[^A-Za-z0-9_]+', '_');
obs_id = sprintf('c%+06.2f_%s_t%04d', center_az, safe_name, trial_id);
obs_id = strrep(obs_id, '+', 'p');
obs_id = strrep(obs_id, '-', 'm');
obs_id = strrep(obs_id, '.', 'p');
end

function s = table_row_to_struct_local(T)
s = struct();
vars = T.Properties.VariableNames;
for idx = 1:numel(vars)
    v = T.(vars{idx});
    if iscell(v)
        v = v{1};
    elseif ischar(v)
        v = strtrim(v(1, :));
    elseif isstring(v)
        v = char(v(1));
    else
        v = v(1);
    end
    s.(vars{idx}) = v;
end
end

function [completed_ids, counts] = completed_obs_ids_from_partials_local(cfg12, required_modes)
completed_ids = {};
counts = struct('trial_rows', 0, 'topk_rows', 0, 'score_gap_rows', 0);
if ~(cfg12.chunked_run_flag && cfg12.resume_from_partials_flag)
    return;
end
trial_path = fullfile(cfg12.result_dir, 'step12_chunk_trial.csv');
if exist(trial_path, 'file') ~= 2
    return;
end
T = readtable(trial_path, 'TextType', 'char');
counts.trial_rows = height(T);
if ~ismember('obs_id', T.Properties.VariableNames) || ~ismember('quant_mode', T.Properties.VariableNames)
    return;
end
ids = unique(T.obs_id);
done = false(numel(ids), 1);
for idx = 1:numel(ids)
    modes_here = unique(T.quant_mode(strcmp(T.obs_id, ids{idx})));
    done(idx) = all(ismember(required_modes(:), modes_here(:)));
end
completed_ids = ids(done);
end

function row = make_profile_row_template_local()
row = struct('obs_id', '', 'chunk_id', NaN, 'total_chunks', NaN, 'run_tag', '', ...
    'scenario_name', '', 'center_az', NaN, 'trial_id', NaN, 'quant_mode', '', ...
    'stage_name', '', 'elapsed_sec', NaN, 'num_candidates', NaN, 'num_topK', NaN, ...
    'score_lanes_assumed', NaN, 'comment', '');
end

function row = make_profile_row_local(plan, quant_mode, stage_name, elapsed_sec, num_candidates, num_topK, score_lanes, comment)
row = make_profile_row_template_local();
row.obs_id = char(plan.obs_id);
row.chunk_id = plan.chunk_id_assigned;
row.total_chunks = safe_plan_total_chunks_local(plan);
row.run_tag = char(plan.run_tag);
row.scenario_name = char(plan.scenario_name);
row.center_az = plan.center_az;
row.trial_id = plan.trial_id;
row.quant_mode = char(quant_mode);
row.stage_name = char(stage_name);
row.elapsed_sec = elapsed_sec;
row.num_candidates = num_candidates;
row.num_topK = num_topK;
row.score_lanes_assumed = score_lanes;
row.comment = char(comment);
end

function row = make_profile_row_from_obs_local(obs, quant_mode, stage_name, elapsed_sec, num_candidates, num_topK, score_lanes, comment)
row = make_profile_row_template_local();
row.obs_id = char(obs.obs_id);
row.chunk_id = obs.chunk_id;
row.total_chunks = obs.total_chunks;
row.run_tag = char(obs.run_tag);
row.scenario_name = char(obs.scenario_name);
row.center_az = obs.center_az;
row.trial_id = obs.trial_id;
row.quant_mode = char(quant_mode);
row.stage_name = char(stage_name);
row.elapsed_sec = elapsed_sec;
row.num_candidates = num_candidates;
row.num_topK = numTopKOrNan_local(num_topK);
row.score_lanes_assumed = score_lanes;
row.comment = char(comment);
end

function n = numTopKOrNan_local(n)
if isempty(n)
    n = NaN;
end
end

function n = safe_plan_total_chunks_local(plan)
if isfield(plan, 'total_chunks')
    n = plan.total_chunks;
else
    n = NaN;
end
end

function T = make_profile_table_empty_local()
T = struct2table(make_profile_row_template_local(), 'AsArray', true);
T(1, :) = [];
end

function T = concat_tables_local(varargin)
T = table();
for idx = 1:nargin
    Ti = varargin{idx};
    if isempty(Ti) || ~istable(Ti) || height(Ti) == 0
        continue;
    end
    if isempty(T) || width(T) == 0
        T = Ti;
    else
        T = [T; Ti]; %#ok<AGROW>
    end
end
if isempty(T) || width(T) == 0
    T = table();
end
end

function out = make_step12_backend_stub_local(input)
out = struct();
out.status = 'step12_score_core_adapter_only';
out.method_name = 'step12_nonintrusive_score_core_adapter';
out.confidence = '';
out.boundary_flag = '';
out.fallback_used = false;
out.used_cache = true;
out.cache_miss_count = 0;
out.selectedCenterColumn = safe_input_field_local(input, 'selectedCenterColumn', NaN);
out.selectedCenterAz = safe_input_field_local(input, 'selectedCenterAz', NaN);
out.error_message = 'Step12 formal mode does not run the full Step11.7 backend unless STEP12_RUN_FULL_STEP11_BACKEND=1.';
out.debug = struct('step12_adapter_only_flag', true);
end

function obs = make_empty_obs_local()
obs = struct();
obs.trial_index = NaN;
obs.obs_id = '';
obs.obs_global_index = NaN;
obs.chunk_id = NaN;
obs.total_chunks = NaN;
obs.run_tag = '';
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
obs.confidence_baseline = nonempty_or_fallback_local(safe_field_local(out, 'confidence', ''), ...
    safe_field_local(score_pack.policy, 'confidence', ''));
obs.fallback_baseline = logical(safe_field_local(out, 'fallback_used', false));
obs.boundary_baseline = nonempty_or_fallback_local(safe_field_local(out, 'boundary_flag', ''), ...
    safe_field_local(score_pack.policy, 'boundary_flag', ''));
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
if B < 1
    score(:) = -Inf;
    return;
end
if isempty(Rz)
    Rz = Z_use * Z_use';
end

% Vectorized Step11 DML identity:
% beamspace_dml_score(Z,G)=real(trace((G/(G'*G+reg*I))*G'*(Z*Z'))).
% For pair2d candidates K=2, this evaluates the same objective without
% changing the Step11 backend or score definition.
nAz = size(G_use_grid, 2);
idx1 = candidate_table.iAz1 + (candidate_table.iEl1 - 1) * nAz;
idx2 = candidate_table.iAz2 + (candidate_table.iEl2 - 1) * nAz;
G_flat = reshape(G_use_grid, B, []);
G1 = G_flat(:, idx1);
G2 = G_flat(:, idx2);

a = sum(conj(G1) .* G1, 1) + reg;
d = sum(conj(G2) .* G2, 1) + reg;
b = sum(conj(G1) .* G2, 1);
RzG1 = Rz * G1;
RzG2 = Rz * G2;
k11 = sum(conj(G1) .* RzG1, 1);
k22 = sum(conj(G2) .* RzG2, 1);
k12 = sum(conj(G1) .* RzG2, 1);
k21 = sum(conj(G2) .* RzG1, 1);
detH = a .* d - b .* conj(b);
small = abs(detH) <= eps(max(abs(detH)));
detH(small) = NaN;
score = real((d .* k11 + a .* k22 - b .* k21 - conj(b) .* k12) ./ detH).';
score(~isfinite(score)) = -Inf;
if use_quantized_rz
    score = double(score);
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

function [trial_tbl, topk_tbl, score_gap_tbl, profile_tbl] = run_step12_quantization_trials_local(obs, modes, cfg12)
trial_rows = repmat(make_trial_row_template_local(), 0, 1);
topk_rows = repmat(make_topk_row_template_local(), 0, 1);
gap_rows = repmat(make_score_gap_row_template_local(), 0, 1);
profile_rows = repmat(make_profile_row_template_local(), 0, 1);
for iObs = 1:numel(obs)
    base = obs(iObs);
    for iMode = 1:numel(modes)
        mode = modes(iMode);
        t_stage = tic;
        score_out = run_step11_ml_score_adapter_local(base, mode, cfg12);
        profile_rows(end + 1, 1) = make_profile_row_from_obs_local(base, mode.name, 'score_recompute', toc(t_stage), base.num_candidates, cfg12.topK_default, NaN, 'Step12 quantized score recompute'); %#ok<AGROW>
        t_stage = tic;
        metrics = compare_score_ranking_local(base, score_out, mode, cfg12);
        profile_rows(end + 1, 1) = make_profile_row_from_obs_local(base, mode.name, 'ranking_compare', toc(t_stage), base.num_candidates, cfg12.topK_default, NaN, 'ranking and topK comparison'); %#ok<AGROW>
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
profile_tbl = struct2table(profile_rows);
if ~cfg12.profile_enable_flag
    profile_tbl = make_profile_table_empty_local();
elseif isempty(profile_rows)
    profile_tbl = make_profile_table_empty_local();
end
end

function row = make_trial_row_template_local()
row = struct('trial_index', NaN, 'obs_id', '', 'obs_global_index', NaN, 'chunk_id', NaN, ...
    'total_chunks', NaN, 'run_tag', '', 'scenario_name', '', 'center_az', NaN, ...
    'trial_id', NaN, 'quant_mode', '', 'candidate_count', NaN, ...
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
row = struct('trial_index', NaN, 'obs_id', '', 'obs_global_index', NaN, 'chunk_id', NaN, ...
    'total_chunks', NaN, 'run_tag', '', 'scenario_name', '', 'center_az', NaN, ...
    'trial_id', NaN, 'quant_mode', '', 'K', NaN, ...
    'K_actual', NaN, 'topK_order_same_flag', false, 'topK_set_same_flag', false, ...
    'topK_jaccard', NaN, 'topK_miss_count', NaN, 'topK_miss_rate', NaN, ...
    'reliable_margin_flag', false, 'reliable_topK_same_flag', false);
end

function row = make_score_gap_row_template_local()
row = struct('trial_index', NaN, 'obs_id', '', 'obs_global_index', NaN, 'chunk_id', NaN, ...
    'total_chunks', NaN, 'run_tag', '', 'scenario_name', '', 'center_az', NaN, ...
    'trial_id', NaN, 'quant_mode', '', ...
    'score_gap_top1_top2_baseline', NaN, 'score_gap_top1_top2_quant', NaN, ...
    'score_gap_same_baseline_pair_quant', NaN, 'score_gap_norm_baseline', NaN, ...
    'score_gap_norm_quant', NaN, 'score_gap_abs_error', NaN, 'score_gap_rel_error', NaN, ...
    'score_gap_sign_flip_flag', false, 'score_margin_bin', '');
end

function score_out = run_step11_ml_score_adapter_local(obs, mode, cfg12)
score_out = struct();
score_out.mode_name = mode.name;
score_out.score_direction = cfg12.score_direction;
context = obs.context;
Y_use = obs.Y;
if mode.is_float_reference
    Y_use = single(Y_use);
end
static_pack = get_step12_static_quant_pack_local(obs, mode, cfg12);
qdiag = static_pack.qdiag;
W_use = static_pack.W_use;
G_use_grid = static_pack.G_use_grid;

Z_raw = W_use' * Y_use;
if mode.is_float_reference
    Z_raw = single(Z_raw);
end

Z_use = static_pack.Cwhiten * Z_raw;

if mode.is_float_reference
    Z_use = single(Z_use);
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

function static_pack = get_step12_static_quant_pack_local(obs, mode, cfg12)
persistent cache_map
if isempty(cache_map) || ~isa(cache_map, 'containers.Map')
    cache_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = static_quant_cache_key_local(obs, mode);
if cfg12.enable_static_quant_cache_flag && isKey(cache_map, key)
    static_pack = cache_map(key);
    return;
end

qdiag = make_qdiag_template_local();
context = obs.context;
W_use = obs.W;
G_raw = obs.G_grid_raw;
if mode.is_float_reference
    W_use = single(W_use);
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

B = size(W_use, 2);
I = eye(B);
[I_white, G_flat_use, ~] = apply_beamspace_whitening(I, reshape(G_raw, B, []), W_use, context.search_opts.whitening_mode, ...
    'eps_reg', max(context.search_opts.reg, 1e-12));
G_use_grid = reshape(G_flat_use, size(G_raw));
if mode.is_float_reference
    I_white = single(I_white);
    G_use_grid = single(G_use_grid);
end

static_pack = struct();
static_pack.W_use = W_use;
static_pack.G_use_grid = G_use_grid;
static_pack.Cwhiten = I_white;
static_pack.qdiag = qdiag;
if cfg12.enable_static_quant_cache_flag
    cache_map(key) = static_pack;
end
end

function key = static_quant_cache_key_local(obs, mode)
key = sprintf('center_%+.10f_mode_%s_W_%s_G_%s_float_%d', obs.center_az, mode.name, ...
    bit_key_local(mode.W_bits), bit_key_local(mode.Gcache_bits), mode.is_float_reference);
end

function text = bit_key_local(bits)
if isfinite(bits)
    text = sprintf('%d', bits);
else
    text = 'none';
end
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
    row.obs_id = base.obs_id;
    row.obs_global_index = base.obs_global_index;
    row.chunk_id = base.chunk_id;
    row.total_chunks = base.total_chunks;
    row.run_tag = base.run_tag;
    row.scenario_name = base.scenario_name;
    row.center_az = base.center_az;
    row.trial_id = base.trial_id;
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
row.obs_id = base.obs_id;
row.obs_global_index = base.obs_global_index;
row.chunk_id = base.chunk_id;
row.total_chunks = base.total_chunks;
row.run_tag = base.run_tag;
row.scenario_name = base.scenario_name;
row.center_az = base.center_az;
row.trial_id = base.trial_id;
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
gap_row.obs_id = base.obs_id;
gap_row.obs_global_index = base.obs_global_index;
gap_row.chunk_id = base.chunk_id;
gap_row.total_chunks = base.total_chunks;
gap_row.run_tag = base.run_tag;
gap_row.scenario_name = base.scenario_name;
gap_row.center_az = base.center_az;
gap_row.trial_id = base.trial_id;
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
    formal_count_ok = (~cfg12.quick_mode_flag) && row.num_trials >= cfg12.min_formal_obs;
    row.fixed_point_pass_flag = mode.is_fixed_candidate && row.ranking_pass_flag && row.topK_pass_flag && formal_count_ok;
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

function mode_selection_tbl = build_step12_mode_selection_table_local(summary_tbl, modes, obs, cfg12)
template = make_mode_selection_row_template_local();
rows = repmat(template, 0, 1);
if isempty(summary_tbl) || height(summary_tbl) == 0
    mode_selection_tbl = struct2table(rows);
    return;
end
for idx = 1:height(summary_tbl)
    mode_name = char(summary_tbl.quant_mode{idx});
    mode = mode_by_name_local(modes, mode_name);
    bits = mode.storage_component_bits;
    if ~(isfinite(bits) && bits > 0)
        bits = cfg12.default_component_bits;
    end
    estimate = estimate_storage_totals_for_bits_local(obs, bits, cfg12);
    row = template;
    row.quant_mode = mode_name;
    row.is_fixed_candidate = logical(summary_tbl.is_fixed_candidate(idx));
    row.is_recommendation_candidate = logical(summary_tbl.recommendation_candidate_flag(idx));
    row.component_bits = bits;
    row.formal_trial_count = double(summary_tbl.num_trials(idx)) * double(~cfg12.quick_mode_flag);
    row.ranking_pass_flag = logical(summary_tbl.ranking_pass_flag(idx));
    row.topK_pass_flag = logical(summary_tbl.topK_pass_flag(idx));
    row.fixed_point_pass_flag = logical(summary_tbl.fixed_point_pass_flag(idx));
    row.reliable_top1_preservation_rate = summary_tbl.reliable_top1_preservation_rate(idx);
    row.reliable_topK_set_preservation_rate = summary_tbl.reliable_topK_set_preservation_rate(idx);
    row.overall_topK_set_preservation_rate = summary_tbl.overall_topK_set_preservation_rate(idx);
    row.reliable_topK_miss_rate = summary_tbl.reliable_topK_miss_rate(idx);
    row.argmax_changed_rate_on_reliable_margin = summary_tbl.argmax_changed_rate_on_reliable_margin(idx);
    row.reliable_score_gap_sign_flip_rate = summary_tbl.reliable_score_gap_sign_flip_rate(idx);
    row.max_candidate_score_rel_l2_error = summary_tbl.max_candidate_score_rel_l2_error(idx);
    row.max_score_gap_rel_error = summary_tbl.max_score_gap_rel_error(idx);
    row.max_clip_rate = summary_tbl.max_clip_rate(idx);
    row.max_overflow_rate = summary_tbl.max_overflow_rate(idx);
    row.estimated_total_MB = estimate.total_MB;
    row.estimated_BRAM36 = estimate.BRAM36;
    row.estimated_URAM288 = estimate.URAM288;
    row.engineering_rank = NaN;
    row.selection_reason = selection_reason_for_row_local(row, cfg12);
    rows(end + 1, 1) = row; %#ok<AGROW>
end

mode_selection_tbl = struct2table(rows);
pass_mask = logical(mode_selection_tbl.fixed_point_pass_flag) & logical(mode_selection_tbl.is_fixed_candidate);
if any(pass_mask)
    pass_idx = find(pass_mask);
    [~, order] = sortrows([mode_selection_tbl.estimated_total_MB(pass_idx), ...
        mode_selection_tbl.component_bits(pass_idx), pass_idx(:)], [1, 2, 3]);
    for rank = 1:numel(order)
        mode_selection_tbl.engineering_rank(pass_idx(order(rank))) = rank;
    end
end
end

function row = make_mode_selection_row_template_local()
row = struct('quant_mode', '', 'is_fixed_candidate', false, 'is_recommendation_candidate', false, ...
    'component_bits', NaN, 'formal_trial_count', 0, 'ranking_pass_flag', false, ...
    'topK_pass_flag', false, 'fixed_point_pass_flag', false, ...
    'reliable_top1_preservation_rate', NaN, 'reliable_topK_set_preservation_rate', NaN, ...
    'overall_topK_set_preservation_rate', NaN, 'reliable_topK_miss_rate', NaN, ...
    'argmax_changed_rate_on_reliable_margin', NaN, 'reliable_score_gap_sign_flip_rate', NaN, ...
    'max_candidate_score_rel_l2_error', NaN, 'max_score_gap_rel_error', NaN, ...
    'max_clip_rate', NaN, 'max_overflow_rate', NaN, 'estimated_total_MB', NaN, ...
    'estimated_BRAM36', NaN, 'estimated_URAM288', NaN, 'engineering_rank', NaN, ...
    'selection_reason', '');
end

function reason = selection_reason_for_row_local(row, cfg12)
if ~row.is_fixed_candidate
    reason = 'not_fixed_candidate';
elseif cfg12.quick_mode_flag
    reason = 'quick_mode_not_formal';
elseif row.formal_trial_count < cfg12.min_formal_obs
    reason = 'formal_trial_count_below_minimum';
elseif ~row.ranking_pass_flag
    reason = 'ranking_not_closed';
elseif ~row.topK_pass_flag
    reason = 'topK_not_closed';
elseif row.fixed_point_pass_flag
    reason = 'formal_ranking_topK_passed';
else
    reason = 'not_recommendation_candidate_or_not_closed';
end
end

function estimate = estimate_storage_totals_for_bits_local(obs, bits, cfg12)
if isempty(obs) || ~isstruct(obs) || isempty(obs.W)
    estimate = struct('total_MB', NaN, 'BRAM36', NaN, 'URAM288', NaN);
    return;
end
num_candidates = max(obs.num_candidates, 1);
B = size(obs.W, 2);
topK = min(cfg12.topK_default, num_candidates);
num_complex = [numel(obs.W), numel(obs.context.cache.G_grid), numel(obs.Z_use), ...
    numel(obs.Rz), num_candidates, topK, num_candidates];
total_bits = sum(num_complex) * 2 * bits;
estimate = struct();
estimate.total_MB = total_bits / 8 / 1024 / 1024;
estimate.BRAM36 = ceil(total_bits / 36864);
estimate.URAM288 = ceil(total_bits / 294912);
end

function score_gap_bins_tbl = build_step12_score_gap_bins_local(trial_tbl, modes, cfg12)
template = make_gap_bin_row_template_local();
rows = repmat(template, 0, 1);
if isempty(trial_tbl) || height(trial_tbl) == 0
    score_gap_bins_tbl = struct2table(rows);
    return;
end
bin_names = {'gap_bin_very_weak', 'gap_bin_weak', 'gap_bin_transition', 'gap_bin_reliable'};
for iMode = 1:numel(modes)
    mode_name = modes(iMode).name;
    Tm = trial_tbl(strcmp(trial_tbl.quant_mode, mode_name), :);
    for iBin = 1:numel(bin_names)
        mask = gap_bin_mask_local(Tm.score_gap_norm_baseline, bin_names{iBin});
        Tb = Tm(mask, :);
        row = template;
        row.quant_mode = mode_name;
        row.gap_bin = bin_names{iBin};
        row.num_trials = height(Tb);
        row.top1_preservation_rate = mean_or_nan_local(double(Tb.top1_same_flag));
        row.topK_set_preservation_rate = mean_or_nan_local(double(Tb.topK_set_same_flag));
        row.topK_miss_rate = mean_or_nan_local(Tb.topK_miss_rate);
        row.argmax_changed_rate = mean_or_nan_local(double(Tb.argmax_changed_flag));
        row.score_gap_sign_flip_rate = mean_or_nan_local(double(Tb.score_gap_sign_flip_flag));
        row.mean_score_gap_rel_error = mean_or_nan_local(Tb.score_gap_rel_error);
        row.p95_score_gap_rel_error = percentile_local(Tb.score_gap_rel_error, 95);
        row.max_score_gap_rel_error = max_or_nan_local(Tb.score_gap_rel_error);
        row.same_policy_rate = mean_or_nan_local(double(Tb.same_policy_flag));
        row.same_confidence_rate = mean_or_nan_local(double(Tb.same_confidence_flag));
        row.same_boundary_rate = mean_or_nan_local(double(Tb.boundary_state_same_flag));
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end
score_gap_bins_tbl = struct2table(rows);
end

function row = make_gap_bin_row_template_local()
row = struct('quant_mode', '', 'gap_bin', '', 'num_trials', 0, ...
    'top1_preservation_rate', NaN, 'topK_set_preservation_rate', NaN, ...
    'topK_miss_rate', NaN, 'argmax_changed_rate', NaN, ...
    'score_gap_sign_flip_rate', NaN, 'mean_score_gap_rel_error', NaN, ...
    'p95_score_gap_rel_error', NaN, 'max_score_gap_rel_error', NaN, ...
    'same_policy_rate', NaN, 'same_confidence_rate', NaN, 'same_boundary_rate', NaN);
end

function mask = gap_bin_mask_local(gap_norm, bin_name)
switch bin_name
    case 'gap_bin_very_weak'
        mask = gap_norm < 1e-5;
    case 'gap_bin_weak'
        mask = gap_norm >= 1e-5 & gap_norm < 1e-4;
    case 'gap_bin_transition'
        mask = gap_norm >= 1e-4 & gap_norm < 1e-3;
    case 'gap_bin_reliable'
        mask = gap_norm >= 1e-3;
    otherwise
        mask = false(size(gap_norm));
end
end

function best_info = select_best_fixed_point_mode_local(summary_tbl, modes, mode_selection_tbl, cfg12)
best_info = struct('mode_name', 'not_recommended', 'recommended_fixed_point_format', 'not_recommended', ...
    'ranking_pass_flag', false, 'topK_pass_flag', false, 'fixed_point_pass_flag', false, ...
    'blocker_if_any', 'ml_score_ranking_or_topK_not_closed', 'component_bits', 16, ...
    'proceed_to_rtl_score_core_flag', 0, 'proceed_to_full_fpga_backend_flag', 0, ...
    'reliable_top1_preservation', NaN, 'reliable_topK_preservation', NaN, ...
    'overall_topK_preservation', NaN, 'argmax_changed_reliable', NaN, 'score_gap_flip_reliable', NaN, ...
    'minimum_passing_mode', 'none', 'engineering_recommended_fixed_point_format', 'not_recommended', ...
    'mode_selection_reason', 'no_passing_fixed_candidate');
if isempty(summary_tbl) || height(summary_tbl) == 0
    return;
end
if cfg12.quick_mode_flag
    best_info = select_smoke_fixed_point_mode_local(best_info, summary_tbl, modes);
    return;
end
formal_trial_count = max(summary_tbl.num_trials);
if formal_trial_count < cfg12.min_formal_obs
    best_info.blocker_if_any = 'formal_trial_count_below_minimum';
    best_info.mode_selection_reason = 'formal_trial_count_below_minimum';
    best_info = best_available_metric_row_local(best_info, summary_tbl);
    return;
end
pass_mask = logical(mode_selection_tbl.fixed_point_pass_flag) & logical(mode_selection_tbl.is_fixed_candidate);
if ~any(pass_mask)
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
pass_indices = find(pass_mask);
[~, min_order] = sortrows([mode_selection_tbl.estimated_total_MB(pass_indices), ...
    mode_selection_tbl.component_bits(pass_indices), pass_indices(:)], [1, 2, 3]);
minimum_idx = pass_indices(min_order(1));
best_info.minimum_passing_mode = char(mode_selection_tbl.quant_mode{minimum_idx});

preferred = {'combined_int16', 'combined_int18', 'mixed_Z16_G24_Rz24', 'combined_int24'};
best_mode = '';
for idx = 1:numel(preferred)
    hit = find(strcmp(mode_selection_tbl.quant_mode, preferred{idx}) & pass_mask, 1);
    if ~isempty(hit)
        best_mode = preferred{idx};
        break;
    end
end
if isempty(best_mode)
    best_mode = best_info.minimum_passing_mode;
end
best_idx = find(strcmp(summary_tbl.quant_mode, best_mode), 1);
best_row = summary_tbl(best_idx, :);
best_info.mode_name = char(best_row.quant_mode{1});
best_info.recommended_fixed_point_format = best_info.mode_name;
best_info.engineering_recommended_fixed_point_format = best_info.mode_name;
best_info.ranking_pass_flag = logical(best_row.ranking_pass_flag(1));
best_info.topK_pass_flag = logical(best_row.topK_pass_flag(1));
best_info.fixed_point_pass_flag = best_info.ranking_pass_flag && best_info.topK_pass_flag && formal_trial_count >= cfg12.min_formal_obs;
best_info.blocker_if_any = 'none';
best_info.component_bits = mode_bits_by_name_local(modes, best_info.mode_name);
best_info.proceed_to_rtl_score_core_flag = double(best_info.fixed_point_pass_flag);
best_info.proceed_to_full_fpga_backend_flag = 0;
best_info.reliable_top1_preservation = best_row.reliable_top1_preservation_rate(1);
best_info.reliable_topK_preservation = best_row.reliable_topK_set_preservation_rate(1);
best_info.overall_topK_preservation = best_row.overall_topK_set_preservation_rate(1);
best_info.argmax_changed_reliable = best_row.argmax_changed_rate_on_reliable_margin(1);
best_info.score_gap_flip_reliable = best_row.reliable_score_gap_sign_flip_rate(1);
if strcmp(best_info.minimum_passing_mode, best_info.engineering_recommended_fixed_point_format)
    best_info.mode_selection_reason = 'minimum_passing_fixed_candidate_selected';
else
    best_info.mode_selection_reason = sprintf('minimum_passing_mode_%s_but_engineering_priority_selected_%s', ...
        best_info.minimum_passing_mode, best_info.engineering_recommended_fixed_point_format);
end
end

function best_info = select_smoke_fixed_point_mode_local(best_info, summary_tbl, modes)
mask = logical(summary_tbl.is_fixed_candidate) & logical(summary_tbl.recommendation_candidate_flag) & ...
    logical(summary_tbl.ranking_pass_flag) & logical(summary_tbl.topK_pass_flag);
if any(mask)
    indices = find(mask);
    cost = summary_tbl.mode_storage_cost_bits(mask);
    [~, order] = sort(cost, 'ascend');
    idx = indices(order(1));
    row = summary_tbl(idx, :);
    best_info.mode_name = char(row.quant_mode{1});
    best_info.recommended_fixed_point_format = best_info.mode_name;
    best_info.engineering_recommended_fixed_point_format = best_info.mode_name;
    best_info.ranking_pass_flag = logical(row.ranking_pass_flag(1));
    best_info.topK_pass_flag = logical(row.topK_pass_flag(1));
    best_info.fixed_point_pass_flag = best_info.ranking_pass_flag && best_info.topK_pass_flag;
    best_info.blocker_if_any = 'none';
    best_info.component_bits = mode_bits_by_name_local(modes, best_info.mode_name);
    best_info.reliable_top1_preservation = row.reliable_top1_preservation_rate(1);
    best_info.reliable_topK_preservation = row.reliable_topK_set_preservation_rate(1);
    best_info.overall_topK_preservation = row.overall_topK_set_preservation_rate(1);
    best_info.argmax_changed_reliable = row.argmax_changed_rate_on_reliable_margin(1);
    best_info.score_gap_flip_reliable = row.reliable_score_gap_sign_flip_rate(1);
    best_info.mode_selection_reason = 'quick_smoke_metric_chain_passed';
else
    best_info = best_available_metric_row_local(best_info, summary_tbl);
    best_info.mode_selection_reason = 'quick_smoke_metric_chain_not_closed';
end
end

function best_info = best_available_metric_row_local(best_info, summary_tbl)
fixed_mask = logical(summary_tbl.is_fixed_candidate);
if ~any(fixed_mask)
    return;
end
score = summary_tbl.reliable_topK_set_preservation_rate;
score(~fixed_mask) = -Inf;
[~, idx] = max(score);
best_row = summary_tbl(idx, :);
best_info.mode_name = char(best_row.quant_mode{1});
best_info.reliable_top1_preservation = best_row.reliable_top1_preservation_rate(1);
best_info.reliable_topK_preservation = best_row.reliable_topK_set_preservation_rate(1);
best_info.overall_topK_preservation = best_row.overall_topK_set_preservation_rate(1);
best_info.argmax_changed_reliable = best_row.argmax_changed_rate_on_reliable_margin(1);
best_info.score_gap_flip_reliable = best_row.reliable_score_gap_sign_flip_rate(1);
end

function mode = mode_by_name_local(modes, mode_name)
mode = modes(1);
for idx = 1:numel(modes)
    if strcmp(modes(idx).name, mode_name)
        mode = modes(idx);
        return;
    end
end
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

function mode_selection_tbl = build_step12_mode_selection_table_from_trial_local(summary_tbl, modes, trial_tbl, cfg12)
obs_proxy = make_obs_proxy_from_trial_local(trial_tbl, cfg12);
mode_selection_tbl = build_step12_mode_selection_table_local(summary_tbl, modes, obs_proxy, cfg12);
end

function storage_tbl = build_step12_storage_estimate_from_trial_local(trial_tbl, best_info, cfg12)
obs_proxy = make_obs_proxy_from_trial_local(trial_tbl, cfg12);
storage_tbl = build_step12_storage_estimate_local(obs_proxy, best_info, cfg12);
end

function bandwidth_tbl = build_step12_bandwidth_estimate_from_trial_local(trial_tbl, best_info, cfg12)
obs_proxy = make_obs_proxy_from_trial_local(trial_tbl, cfg12);
bandwidth_tbl = build_step12_bandwidth_estimate_local(obs_proxy, best_info, cfg12);
end

function obs_proxy = make_obs_proxy_from_trial_local(trial_tbl, cfg12)
obs_proxy = make_empty_obs_local();
B = 7;
num_candidates = 1;
if ~isempty(trial_tbl) && height(trial_tbl) > 0
    if ismember('candidate_count', trial_tbl.Properties.VariableNames)
        num_candidates = max(1, round(max_or_nan_local(trial_tbl.candidate_count)));
    end
end
obs_proxy.W = complex(zeros(12, B));
obs_proxy.Z_use = complex(zeros(B, 16));
obs_proxy.Rz = complex(zeros(B, B));
obs_proxy.num_candidates = num_candidates;
obs_proxy.context = struct();
obs_proxy.context.cache = struct();
obs_proxy.context.cache.G_grid = complex(zeros(B, max(2, ceil(sqrt(num_candidates))), 8));
obs_proxy.context.C05_policy_cfg = struct('topK_max', cfg12.topK_default);
end

function [trial_tbl, topk_tbl, score_gap_tbl, profile_tbl, aggregate_info] = load_step12_chunk_partials_local(cfg12, modes)
chunk_dirs = dir(fullfile(cfg12.chunk_root_dir, 'chunk_*'));
chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
trial_tbl = read_and_concat_chunk_tables_local(chunk_dirs, 'step12_chunk_trial.csv');
topk_tbl = read_and_concat_chunk_tables_local(chunk_dirs, 'step12_chunk_topk.csv');
score_gap_tbl = read_and_concat_chunk_tables_local(chunk_dirs, 'step12_chunk_score_gap.csv');
profile_tbl = read_and_concat_chunk_tables_local(chunk_dirs, 'step12_chunk_profile.csv');
trial_tbl = ensure_table_template_local(trial_tbl, make_trial_row_template_local());
topk_tbl = ensure_table_template_local(topk_tbl, make_topk_row_template_local());
score_gap_tbl = ensure_table_template_local(score_gap_tbl, make_score_gap_row_template_local());
profile_tbl = ensure_table_template_local(profile_tbl, make_profile_row_template_local());
trial_tbl = coerce_table_types_from_template_local(trial_tbl, make_trial_row_template_local());
topk_tbl = coerce_table_types_from_template_local(topk_tbl, make_topk_row_template_local());
score_gap_tbl = coerce_table_types_from_template_local(score_gap_tbl, make_score_gap_row_template_local());
profile_tbl = coerce_table_types_from_template_local(profile_tbl, make_profile_row_template_local());
trial_tbl = unique_table_rows_local(trial_tbl, {'obs_id', 'quant_mode'});
topk_tbl = unique_table_rows_local(topk_tbl, {'obs_id', 'quant_mode', 'K'});
score_gap_tbl = unique_table_rows_local(score_gap_tbl, {'obs_id', 'quant_mode'});
profile_tbl = unique_table_rows_local(profile_tbl, {'obs_id', 'quant_mode', 'stage_name'});

plan_tbl = build_step12_observation_plan_local(cfg12);
completed_ids = completed_obs_ids_from_trial_table_local(trial_tbl, {modes.name});
plan_tbl.completed_flag = ismember(plan_tbl.obs_id, completed_ids);
writetable(plan_tbl, fullfile(cfg12.result_dir, 'step12_observation_plan.csv'));

aggregate_info = struct();
aggregate_info.formal_plan_total_obs = height(plan_tbl);
aggregate_info.formal_plan_completed_obs = numel(completed_ids);
aggregate_info.formal_plan_complete_flag = double(aggregate_info.formal_plan_completed_obs >= aggregate_info.formal_plan_total_obs && aggregate_info.formal_plan_total_obs > 0);
aggregate_info.chunks_detected = numel(chunk_dirs);
aggregate_info.chunks_completed = count_completed_chunks_local(chunk_dirs, {modes.name});
end

function T = read_and_concat_chunk_tables_local(chunk_dirs, file_name)
T = table();
for idx = 1:numel(chunk_dirs)
    p = fullfile(chunk_dirs(idx).folder, chunk_dirs(idx).name, file_name);
    if exist(p, 'file') ~= 2
        continue;
    end
    Ti = readtable(p, 'TextType', 'char');
    T = concat_tables_local(T, Ti);
end
end

function T = ensure_table_template_local(T, row_template)
if isempty(T) || ~istable(T) || width(T) == 0
    T = struct2table(row_template, 'AsArray', true);
    T(1, :) = [];
end
end

function T = coerce_table_types_from_template_local(T, row_template)
vars = fieldnames(row_template);
for idx = 1:numel(vars)
    name = vars{idx};
    if ~ismember(name, T.Properties.VariableNames)
        continue;
    end
    target = row_template.(name);
    if islogical(target)
        T.(name) = to_logical_column_local(T.(name));
    elseif isnumeric(target)
        T.(name) = to_numeric_column_local(T.(name));
    elseif ischar(target)
        T.(name) = to_cellstr_column_local(T.(name));
    end
end
end

function y = to_numeric_column_local(x)
if isnumeric(x)
    y = double(x);
elseif islogical(x)
    y = double(x);
elseif iscell(x)
    y = nan(numel(x), 1);
    for i = 1:numel(x)
        y(i) = scalar_to_double_local(x{i});
    end
elseif isstring(x)
    y = str2double(x);
elseif ischar(x)
    y = str2double(cellstr(x));
else
    y = nan(numel(x), 1);
end
y = y(:);
end

function y = to_logical_column_local(x)
if islogical(x)
    y = x(:);
elseif isnumeric(x)
    y = x(:) ~= 0;
elseif iscell(x)
    y = false(numel(x), 1);
    for i = 1:numel(x)
        y(i) = scalar_to_logical_local(x{i});
    end
elseif isstring(x)
    y = false(numel(x), 1);
    for i = 1:numel(x)
        y(i) = scalar_to_logical_local(x(i));
    end
elseif ischar(x)
    parts = cellstr(x);
    y = false(numel(parts), 1);
    for i = 1:numel(parts)
        y(i) = scalar_to_logical_local(parts{i});
    end
else
    y = false(numel(x), 1);
end
y = y(:);
end

function y = to_cellstr_column_local(x)
if iscell(x)
    y = cell(size(x));
    for i = 1:numel(x)
        y{i} = scalar_to_char_local(x{i});
    end
    y = y(:);
elseif isstring(x)
    y = cellstr(x(:));
elseif ischar(x)
    y = cellstr(x);
else
    y = cell(numel(x), 1);
    for i = 1:numel(x)
        y{i} = scalar_to_char_local(x(i));
    end
end
end

function v = scalar_to_double_local(x)
if isnumeric(x) || islogical(x)
    if isempty(x)
        v = NaN;
    else
        v = double(x(1));
    end
elseif isstring(x) || ischar(x)
    v = str2double(char(x));
else
    v = NaN;
end
end

function v = scalar_to_logical_local(x)
if isnumeric(x) || islogical(x)
    v = ~isempty(x) && double(x(1)) ~= 0;
else
    s = lower(strtrim(char(x)));
    v = any(strcmp(s, {'1','true','t','yes'}));
end
end

function s = scalar_to_char_local(x)
if ischar(x)
    s = x;
elseif isstring(x)
    s = char(x);
elseif isnumeric(x) || islogical(x)
    s = num2str(x);
else
    s = '';
end
end

function completed_ids = completed_obs_ids_from_trial_table_local(trial_tbl, required_modes)
completed_ids = {};
if isempty(trial_tbl) || height(trial_tbl) == 0 || ...
        ~all(ismember({'obs_id','quant_mode'}, trial_tbl.Properties.VariableNames))
    return;
end
ids = unique(trial_tbl.obs_id);
done = false(numel(ids), 1);
for idx = 1:numel(ids)
    modes_here = unique(trial_tbl.quant_mode(strcmp(trial_tbl.obs_id, ids{idx})));
    done(idx) = all(ismember(required_modes(:), modes_here(:)));
end
completed_ids = ids(done);
end

function n = count_completed_chunks_local(chunk_dirs, required_modes)
n = 0;
for idx = 1:numel(chunk_dirs)
    p = fullfile(chunk_dirs(idx).folder, chunk_dirs(idx).name, 'step12_chunk_trial.csv');
    if exist(p, 'file') ~= 2
        continue;
    end
    T = readtable(p, 'TextType', 'char');
    ids = completed_obs_ids_from_trial_table_local(T, required_modes);
    if ~isempty(ids)
        n = n + 1;
    end
end
end

function profile_summary_tbl = build_step12_profile_summary_local(profile_tbl, cfg12)
template = make_profile_summary_row_template_local();
rows = repmat(template, 0, 1);
if isempty(profile_tbl) || ~istable(profile_tbl) || height(profile_tbl) == 0 || ...
        ~ismember('stage_name', profile_tbl.Properties.VariableNames)
    profile_summary_tbl = struct2table(rows);
    return;
end
stages = unique(profile_tbl.stage_name);
for idx = 1:numel(stages)
    mask = strcmp(profile_tbl.stage_name, stages{idx});
    elapsed = profile_tbl.elapsed_sec(mask);
    row = template;
    row.stage_name = stages{idx};
    row.total_elapsed_sec = sum(elapsed(isfinite(elapsed)));
    row.mean_elapsed_sec = mean_or_nan_local(elapsed);
    row.p95_elapsed_sec = percentile_local(elapsed, 95);
    row.max_elapsed_sec = max_or_nan_local(elapsed);
    row.num_calls = nnz(mask);
    rows(end + 1, 1) = row; %#ok<AGROW>
end
profile_summary_tbl = struct2table(rows);
if height(profile_summary_tbl) > 0
    [~, order] = sort(profile_summary_tbl.total_elapsed_sec, 'descend');
    profile_summary_tbl = profile_summary_tbl(order, :);
    if isfield(cfg12, 'profile_top_n') && height(profile_summary_tbl) > cfg12.profile_top_n
        profile_summary_tbl = profile_summary_tbl(1:cfg12.profile_top_n, :);
    end
end
end

function row = make_profile_summary_row_template_local()
row = struct('stage_name', '', 'total_elapsed_sec', NaN, 'mean_elapsed_sec', NaN, ...
    'p95_elapsed_sec', NaN, 'max_elapsed_sec', NaN, 'num_calls', 0);
end

function T = make_profile_summary_table_empty_local()
T = struct2table(make_profile_summary_row_template_local(), 'AsArray', true);
T(1, :) = [];
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

function keypoints_tbl = build_step12_keypoints_local(summary_tbl, storage_tbl, bandwidth_tbl, adapter_info, best_info, mode_selection_tbl, score_gap_bins_tbl, cfg12)
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
minimum_passing_mode = best_info.minimum_passing_mode;
engineering_recommended_fixed_point_format = best_info.engineering_recommended_fixed_point_format;
mode_selection_reason = best_info.mode_selection_reason;
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
    minimum_passing_mode = 'none';
    engineering_recommended_fixed_point_format = 'not_recommended_until_formal_validation';
    mode_selection_reason = 'formal_validation_not_run';
end
if ~cfg12.quick_mode_flag && formal_trial_count < cfg12.min_formal_obs
    ranking_pass_flag = false;
    topK_pass_flag = false;
    fixed_point_pass_flag = false;
    recommended_fixed_point_format = 'not_recommended';
    blocker_if_any = 'formal_trial_count_below_minimum';
    proceed_to_rtl_score_core_flag = 0;
    minimum_passing_mode = 'none';
    engineering_recommended_fixed_point_format = 'not_recommended';
    mode_selection_reason = 'formal_trial_count_below_minimum';
end
cfg12.formal_min_obs_satisfied_flag = double(~cfg12.quick_mode_flag && formal_trial_count >= cfg12.min_formal_obs);
combined = combined_int16_status_local(summary_tbl, cfg12);
gap_flags = gap_stress_flags_local(score_gap_bins_tbl, best_info);
pairs = { ...
    'step11_adapter_found_flag', adapter_info.step11_adapter_found_flag; ...
    'uses_step89_results_flag', 0; ...
    'formal_trial_count', formal_trial_count; ...
    'min_formal_obs', cfg12.min_formal_obs; ...
    'quick_mode_flag', cfg12.quick_mode_flag; ...
    'chunked_run_flag', cfg12.chunked_run_flag; ...
    'formal_plan_total_obs', cfg12.formal_plan_total_obs; ...
    'formal_plan_completed_obs', cfg12.formal_plan_completed_obs; ...
    'formal_plan_complete_flag', cfg12.formal_plan_complete_flag; ...
    'formal_min_obs_satisfied_flag', cfg12.formal_min_obs_satisfied_flag; ...
    'chunks_detected', cfg12.chunks_detected; ...
    'chunks_completed', cfg12.chunks_completed; ...
    'run_tag', cfg12.run_tag; ...
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
    'combined_int16_formal_pass_flag', combined.formal_pass_flag; ...
    'combined_int16_reliable_top1_preservation', combined.reliable_top1_preservation; ...
    'combined_int16_reliable_topK_preservation', combined.reliable_topK_preservation; ...
    'combined_int16_overall_topK_preservation', combined.overall_topK_preservation; ...
    'combined_int16_argmax_changed_reliable', combined.argmax_changed_reliable; ...
    'combined_int16_score_gap_flip_reliable', combined.score_gap_flip_reliable; ...
    'combined_int16_blocker_if_any', combined.blocker_if_any; ...
    'minimum_passing_mode', minimum_passing_mode; ...
    'engineering_recommended_fixed_point_format', engineering_recommended_fixed_point_format; ...
    'mode_selection_reason', mode_selection_reason; ...
    'ranking_pass_flag', ranking_pass_flag; ...
    'topK_pass_flag', topK_pass_flag; ...
    'fixed_point_pass_flag', fixed_point_pass_flag; ...
    'recommended_fixed_point_format', recommended_fixed_point_format; ...
    'blocker_if_any', blocker_if_any; ...
    'proceed_to_rtl_score_core_flag', proceed_to_rtl_score_core_flag; ...
    'proceed_to_rtl_score_core_smoke_flag', proceed_to_rtl_score_core_smoke_flag; ...
    'proceed_to_full_fpga_backend_flag', best_info.proceed_to_full_fpga_backend_flag; ...
    'reliable_margin_instability_flag', gap_flags.reliable_margin_instability_flag; ...
    'failures_limited_to_low_margin_cases', gap_flags.failures_limited_to_low_margin_cases; ...
    'worst_gap_bin_for_recommended_mode', gap_flags.worst_gap_bin_for_recommended_mode; ...
    'cache_memory_MB_total_est', total_MB; ...
    'BRAM36_total_est', total_BRAM; ...
    'URAM288_total_est', total_URAM};
keypoints_tbl = key_value_table_local(pairs);
end

function combined = combined_int16_status_local(summary_tbl, cfg12)
combined = struct('formal_pass_flag', false, 'reliable_top1_preservation', NaN, ...
    'reliable_topK_preservation', NaN, 'overall_topK_preservation', NaN, ...
    'argmax_changed_reliable', NaN, 'score_gap_flip_reliable', NaN, ...
    'blocker_if_any', 'combined_int16_not_evaluated');
if isempty(summary_tbl) || height(summary_tbl) == 0
    return;
end
idx = find(strcmp(summary_tbl.quant_mode, 'combined_int16'), 1);
if isempty(idx)
    return;
end
row = summary_tbl(idx, :);
combined.formal_pass_flag = logical(row.fixed_point_pass_flag(1)) && ~cfg12.quick_mode_flag && row.num_trials(1) >= cfg12.min_formal_obs;
combined.reliable_top1_preservation = row.reliable_top1_preservation_rate(1);
combined.reliable_topK_preservation = row.reliable_topK_set_preservation_rate(1);
combined.overall_topK_preservation = row.overall_topK_set_preservation_rate(1);
combined.argmax_changed_reliable = row.argmax_changed_rate_on_reliable_margin(1);
combined.score_gap_flip_reliable = row.reliable_score_gap_sign_flip_rate(1);
if combined.formal_pass_flag
    combined.blocker_if_any = 'none';
elseif cfg12.quick_mode_flag
    combined.blocker_if_any = 'formal_validation_not_run';
elseif row.num_trials(1) < cfg12.min_formal_obs
    combined.blocker_if_any = 'formal_trial_count_below_minimum';
elseif isfinite(row.reliable_score_gap_sign_flip_rate(1)) && row.reliable_score_gap_sign_flip_rate(1) > 0
    combined.blocker_if_any = 'score_gap_sign_flip';
elseif isfinite(row.argmax_changed_rate_on_reliable_margin(1)) && row.argmax_changed_rate_on_reliable_margin(1) > 0.001
    combined.blocker_if_any = 'reliable_argmax_changed';
elseif isfinite(row.reliable_topK_miss_rate(1)) && row.reliable_topK_miss_rate(1) > 0.005
    combined.blocker_if_any = 'reliable_topK_miss';
elseif ~logical(row.ranking_pass_flag(1))
    combined.blocker_if_any = 'ranking_not_closed';
elseif ~logical(row.topK_pass_flag(1))
    combined.blocker_if_any = 'topK_not_closed';
else
    combined.blocker_if_any = 'ml_score_ranking_or_topK_not_closed';
end
end

function flags = gap_stress_flags_local(score_gap_bins_tbl, best_info)
flags = struct('reliable_margin_instability_flag', 0, 'failures_limited_to_low_margin_cases', 0, ...
    'worst_gap_bin_for_recommended_mode', 'not_available');
if isempty(score_gap_bins_tbl) || height(score_gap_bins_tbl) == 0
    return;
end
mode_name = best_info.engineering_recommended_fixed_point_format;
if isempty(mode_name) || strcmp(mode_name, 'not_recommended')
    mode_name = best_info.mode_name;
end
T = score_gap_bins_tbl(strcmp(score_gap_bins_tbl.quant_mode, mode_name), :);
if isempty(T) || height(T) == 0
    return;
end
rel = T(strcmp(T.gap_bin, 'gap_bin_reliable'), :);
if ~isempty(rel) && height(rel) > 0
    flags.reliable_margin_instability_flag = double((finite_or_zero_metric_local(rel.argmax_changed_rate(1)) > 0) || ...
        (finite_or_zero_metric_local(rel.topK_miss_rate(1)) > 0) || ...
        (finite_or_zero_metric_local(rel.score_gap_sign_flip_rate(1)) > 0));
end
failure_bins = T((finite_or_zero_metric_local(T.argmax_changed_rate) > 0) | ...
    (finite_or_zero_metric_local(T.topK_miss_rate) > 0) | ...
    (finite_or_zero_metric_local(T.score_gap_sign_flip_rate) > 0), :);
if ~isempty(failure_bins) && height(failure_bins) > 0
    low_names = {'gap_bin_very_weak', 'gap_bin_weak'};
    flags.failures_limited_to_low_margin_cases = double(all(ismember(failure_bins.gap_bin, low_names)));
end
[~, idx] = max_or_nan_with_index_local(T.max_score_gap_rel_error);
if idx <= height(T)
    flags.worst_gap_bin_for_recommended_mode = char(T.gap_bin{idx});
end
end

function y = finite_or_zero_metric_local(x)
y = x;
y(~isfinite(y)) = 0;
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

function [trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, worst_tbl, recommendation_tbl, mode_selection_tbl, score_gap_bins_tbl] = build_step12_blocker_outputs_local(cfg12, adapter_info, modes)
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
mode_selection_tbl = struct2table(make_mode_selection_row_template_local(), 'AsArray', true);
mode_selection_tbl(1, :) = [];
score_gap_bins_tbl = struct2table(make_gap_bin_row_template_local(), 'AsArray', true);
score_gap_bins_tbl(1, :) = [];
best_info = struct('mode_name', 'not_recommended', 'recommended_fixed_point_format', 'not_recommended', ...
    'ranking_pass_flag', false, 'topK_pass_flag', false, 'fixed_point_pass_flag', false, ...
    'blocker_if_any', 'step11_score_function_not_exposed', 'component_bits', 16, ...
    'proceed_to_rtl_score_core_flag', 0, 'proceed_to_full_fpga_backend_flag', 0, ...
    'reliable_top1_preservation', NaN, 'reliable_topK_preservation', NaN, ...
    'overall_topK_preservation', NaN, 'argmax_changed_reliable', NaN, 'score_gap_flip_reliable', NaN, ...
    'minimum_passing_mode', 'none', 'engineering_recommended_fixed_point_format', 'not_recommended', ...
    'mode_selection_reason', 'step11_adapter_not_available');
if isfield(adapter_info, 'blocker_if_any') && ~isempty(adapter_info.blocker_if_any)
    best_info.blocker_if_any = adapter_info.blocker_if_any;
end
storage_placeholder = make_storage_row_local('adapter_not_available', 0, 16, 0, 0, 'Step11 score adapter not available; no storage estimate generated');
storage_tbl = struct2table(storage_placeholder, 'AsArray', true);
bandwidth_placeholder = make_bandwidth_row_local('adapter_not_available', 0, cfg12.topK_default, 0, 16, 1);
bandwidth_placeholder.comment = 'Step11 score adapter not available; no bandwidth estimate generated';
bandwidth_tbl = struct2table(bandwidth_placeholder, 'AsArray', true);
keypoints_tbl = build_step12_keypoints_local(summary_tbl, storage_tbl, bandwidth_tbl, adapter_info, best_info, mode_selection_tbl, score_gap_bins_tbl, cfg12);
recommendation_tbl = build_step12_recommendations_local(keypoints_tbl);
end

function write_step12_tables_local(cfg12, trial_tbl, summary_tbl, keypoints_tbl, score_gap_tbl, topk_tbl, storage_tbl, bandwidth_tbl, worst_tbl, recommendation_tbl, mode_selection_tbl, score_gap_bins_tbl, profile_tbl, profile_summary_tbl)
if nargin < 13
    profile_tbl = make_profile_table_empty_local();
end
if nargin < 14
    profile_summary_tbl = make_profile_summary_table_empty_local();
end
if cfg12.chunked_run_flag && ~cfg12.aggregate_only_flag
    append_or_write_table_local(trial_tbl, fullfile(cfg12.result_dir, 'step12_chunk_trial.csv'), {'obs_id','quant_mode'});
    append_or_write_table_local(topk_tbl, fullfile(cfg12.result_dir, 'step12_chunk_topk.csv'), {'obs_id','quant_mode','K'});
    append_or_write_table_local(score_gap_tbl, fullfile(cfg12.result_dir, 'step12_chunk_score_gap.csv'), {'obs_id','quant_mode'});
    append_or_write_table_local(score_gap_bins_tbl, fullfile(cfg12.result_dir, 'step12_chunk_score_gap_bins_partial.csv'), {'quant_mode','gap_bin'});
    append_or_write_table_local(profile_tbl, fullfile(cfg12.result_dir, 'step12_chunk_profile.csv'), {'obs_id','quant_mode','stage_name'});
    writetable(summary_tbl, fullfile(cfg12.result_dir, 'step12_chunk_summary.csv'));
    writetable(keypoints_tbl, fullfile(cfg12.result_dir, 'step12_chunk_keypoints.csv'), 'WriteVariableNames', false);
    writetable(storage_tbl, fullfile(cfg12.result_dir, 'step12_chunk_storage_estimate.csv'));
    writetable(bandwidth_tbl, fullfile(cfg12.result_dir, 'step12_chunk_bandwidth_estimate.csv'));
    writetable(worst_tbl, fullfile(cfg12.result_dir, 'step12_chunk_worst_cases.csv'));
    writetable(recommendation_tbl, fullfile(cfg12.result_dir, 'step12_chunk_recommendations.csv'));
    writetable(mode_selection_tbl, fullfile(cfg12.result_dir, 'step12_chunk_mode_selection.csv'));
    writetable(profile_summary_tbl, fullfile(cfg12.result_dir, 'step12_profile_summary.csv'));
    write_step12_chunk_manifest_local(cfg12, trial_tbl, profile_tbl);
    return;
end
writetable(trial_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_trial.csv'));
writetable(summary_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_summary.csv'));
writetable(keypoints_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_keypoints.csv'), 'WriteVariableNames', false);
writetable(score_gap_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_score_gap.csv'));
writetable(topk_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_topk.csv'));
writetable(storage_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_storage_estimate.csv'));
writetable(bandwidth_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_bandwidth_estimate.csv'));
writetable(worst_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_worst_cases.csv'));
writetable(recommendation_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_recommendations.csv'));
writetable(mode_selection_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_mode_selection.csv'));
writetable(score_gap_bins_tbl, fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_score_gap_bins.csv'));
writetable(profile_tbl, fullfile(cfg12.result_dir, 'step12_profile.csv'));
writetable(profile_summary_tbl, fullfile(cfg12.result_dir, 'step12_profile_summary.csv'));
end

function append_or_write_table_local(Tnew, path_out, key_vars)
if exist(path_out, 'file') == 2
    Told = readtable(path_out, 'TextType', 'char');
    T = concat_tables_local(Told, Tnew);
else
    T = Tnew;
end
if nargin >= 3 && ~isempty(key_vars) && ~isempty(T) && istable(T) && height(T) > 0
    T = unique_table_rows_local(T, key_vars);
end
writetable(T, path_out);
end

function T = unique_table_rows_local(T, key_vars)
if isempty(T) || height(T) == 0
    return;
end
valid = key_vars(ismember(key_vars, T.Properties.VariableNames));
if isempty(valid)
    return;
end
keys = cell(height(T), 1);
for i = 1:height(T)
    parts = cell(1, numel(valid));
    for j = 1:numel(valid)
        parts{j} = table_cell_as_char_local(T.(valid{j})(i));
    end
    keys{i} = strjoin(parts, '||');
end
[~, ia] = unique(keys, 'stable');
T = T(sort(ia), :);
end

function s = table_cell_as_char_local(v)
if iscell(v)
    v = v{1};
end
if isstring(v)
    s = char(v);
elseif ischar(v)
    s = v;
elseif isnumeric(v) || islogical(v)
    s = mat2str(v);
else
    s = '?';
end
end

function write_step12_chunk_manifest_local(cfg12, trial_tbl, profile_tbl)
trial_path = fullfile(cfg12.result_dir, 'step12_chunk_trial.csv');
if exist(trial_path, 'file') == 2
    Tall = readtable(trial_path, 'TextType', 'char');
else
    Tall = trial_tbl;
end
required_modes = {};
if ~isempty(Tall) && height(Tall) > 0 && ismember('quant_mode', Tall.Properties.VariableNames)
    required_modes = unique(Tall.quant_mode);
end
obs_done = {};
if ~isempty(Tall) && height(Tall) > 0 && ismember('obs_id', Tall.Properties.VariableNames)
    obs_done = unique(Tall.obs_id);
end
new_obs = {};
if ~isempty(trial_tbl) && height(trial_tbl) > 0 && ismember('obs_id', trial_tbl.Properties.VariableNames)
    new_obs = unique(trial_tbl.obs_id);
end
elapsed_sec = NaN;
if ~isempty(profile_tbl) && height(profile_tbl) > 0 && ismember('elapsed_sec', profile_tbl.Properties.VariableNames)
    elapsed_sec = sum(profile_tbl.elapsed_sec(isfinite(profile_tbl.elapsed_sec)));
end
manifest = key_value_table_local({ ...
    'chunk_id', cfg12.chunk_id; ...
    'total_chunks', cfg12.total_chunks; ...
    'run_tag', cfg12.run_tag; ...
    'planned_obs', cfg12.formal_plan_planned_obs; ...
    'completed_obs_before', cfg12.chunk_completed_obs_before; ...
    'completed_obs_after', numel(obs_done); ...
    'new_obs_this_run', numel(new_obs); ...
    'mode_set', cfg12.mode_set; ...
    'modes_observed', strjoin(required_modes(:).', ','); ...
    'run_start_time', datestr(now - elapsed_sec / 86400, 'yyyy-mm-dd HH:MM:SS'); ...
    'run_end_time', datestr(now, 'yyyy-mm-dd HH:MM:SS'); ...
    'elapsed_sec', elapsed_sec; ...
    'status', 'partial_chunk_written'});
writetable(manifest, fullfile(cfg12.result_dir, 'step12_chunk_manifest.csv'), 'WriteVariableNames', false);
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

function golden_manifest_path = export_step12_golden_vectors_local(obs, trial_tbl, keypoints_tbl, modes, cfg12)
golden_manifest_path = '';
if isempty(obs) || isempty(trial_tbl) || height(trial_tbl) == 0
    return;
end
fixed_pass = logical(str2double(get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag')));
if cfg12.quick_mode_flag || ~cfg12.export_golden_vectors_flag || ~fixed_pass
    return;
end
recommended_mode = get_keypoint_value_local(keypoints_tbl, 'engineering_recommended_fixed_point_format');
if isempty(recommended_mode) || strcmp(recommended_mode, 'not_recommended')
    recommended_mode = get_keypoint_value_local(keypoints_tbl, 'recommended_fixed_point_format');
end
if isempty(recommended_mode) || strcmp(recommended_mode, 'not_recommended')
    return;
end

golden_dir = fullfile(cfg12.result_dir, 'golden_vectors');
if exist(golden_dir, 'dir') ~= 7
    mkdir(golden_dir);
end
case_specs = select_golden_case_specs_local(trial_tbl, recommended_mode);
if ~strcmp(recommended_mode, 'combined_int16')
    extra = select_single_case_spec_local(trial_tbl, 'combined_int16', 'combined_int16_worst_case', 'score_gap_rel_error', true);
    if ~isempty(extra)
        case_specs(end + 1) = extra; %#ok<AGROW>
    end
end
if isempty(case_specs)
    return;
end

manifest_rows = {};
case_count = 0;
for iCase = 1:numel(case_specs)
    spec = case_specs(iCase);
    obs_idx = find([obs.trial_index] == spec.trial_index, 1);
    if isempty(obs_idx)
        continue;
    end
    mode = mode_by_name_local(modes, spec.quant_mode);
    quant = run_step11_ml_score_adapter_local(obs(obs_idx), mode, cfg12);
    case_count = case_count + 1;
    case_name = sprintf('case_%04d', case_count);
    case_dir = fullfile(golden_dir, case_name);
    if exist(case_dir, 'dir') ~= 7
        mkdir(case_dir);
    end
    subset = select_golden_candidate_subset_local(obs(obs_idx), quant, cfg12);
    write_golden_case_local(case_dir, case_name, spec, obs(obs_idx), quant, subset, cfg12);
    manifest_rows(end + 1, :) = {case_name, spec.case_role, spec.quant_mode, spec.trial_index, ...
        spec.scenario_name, numel(subset), case_dir}; %#ok<AGROW>
end

golden_manifest_path = fullfile(cfg12.result_dir, 'step12_ml_fpga_boundary_golden_vector_manifest.md');
fid = fopen(golden_manifest_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('step12:GoldenManifestOpenFailed', 'Could not open golden vector manifest: %s', golden_manifest_path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Step12 Golden Vector Manifest\n\n');
fprintf(fid, '- Golden vectors are compact RTL score-core testbench evidence, not a full FPGA backend validation.\n');
fprintf(fid, '- They cover the Step11 beamspace ML score core for the formal recommended fixed-point mode.\n');
fprintf(fid, '- Full candidate streams are not exported by default and `golden_vectors_full/` is ignored by Git.\n');
fprintf(fid, '- recommended fixed-point format: `%s`\n', recommended_mode);
fprintf(fid, '- case count: %d\n\n', case_count);
fprintf(fid, '| case | role | mode | trial | scenario | subset_candidates | path |\n');
fprintf(fid, '| --- | --- | --- | --- | --- | --- | --- |\n');
for idx = 1:size(manifest_rows, 1)
    fprintf(fid, '| %s | %s | %s | %.0f | %s | %.0f | `%s` |\n', manifest_rows{idx, :});
end
clear cleanup;
end

function specs = select_golden_case_specs_local(trial_tbl, mode_name)
specs = repmat(make_golden_case_spec_local(), 0, 1);
specs = append_spec_from_filter_local(specs, trial_tbl, mode_name, 'best_reliable_case', ...
    'candidate_score_rel_l2_error', false, @(T) T.reliable_margin_flag & ~T.argmax_changed_flag & T.topK_set_same_flag);
specs = append_spec_from_filter_local(specs, trial_tbl, mode_name, 'worst_score_gap_rel_error_case', ...
    'score_gap_rel_error', true, @(T) true(height(T), 1));
specs = append_spec_from_filter_local(specs, trial_tbl, mode_name, 'smallest_reliable_margin_case', ...
    'score_gap_norm_baseline', false, @(T) T.reliable_margin_flag);
specs = append_spec_from_filter_local(specs, trial_tbl, mode_name, 'topK_boundary_case', ...
    'topK_jaccard', false, @(T) true(height(T), 1));
end

function spec = select_single_case_spec_local(trial_tbl, mode_name, role, metric_name, largest)
specs = append_spec_from_filter_local(repmat(make_golden_case_spec_local(), 0, 1), ...
    trial_tbl, mode_name, role, metric_name, largest, @(T) true(height(T), 1));
if isempty(specs)
    spec = [];
else
    spec = specs(1);
end
end

function specs = append_spec_from_filter_local(specs, trial_tbl, mode_name, role, metric_name, largest, filter_fn)
T = trial_tbl(strcmp(trial_tbl.quant_mode, mode_name), :);
if isempty(T) || height(T) == 0 || ~ismember(metric_name, T.Properties.VariableNames)
    return;
end
mask = filter_fn(T);
T = T(mask, :);
if isempty(T) || height(T) == 0
    return;
end
values = T.(metric_name);
if largest
    [value, idx] = max_or_nan_with_index_local(values);
else
    finite_mask = isfinite(values);
    if ~any(finite_mask)
        return;
    end
    values2 = values;
    values2(~finite_mask) = Inf;
    [value, idx] = min(values2);
end
if ~isfinite(value)
    return;
end
spec = make_golden_case_spec_local();
spec.case_role = role;
spec.quant_mode = mode_name;
spec.trial_index = T.trial_index(idx);
spec.scenario_name = char(T.scenario_name{idx});
spec.metric_name = metric_name;
spec.metric_value = value;
specs(end + 1, 1) = spec;
end

function spec = make_golden_case_spec_local()
spec = struct('case_role', '', 'quant_mode', '', 'trial_index', NaN, ...
    'scenario_name', '', 'metric_name', '', 'metric_value', NaN);
end

function subset = select_golden_candidate_subset_local(obs, quant, cfg12)
K = min(cfg12.topK_default, numel(obs.score_baseline));
base_top = extract_topk_local(obs.score_baseline, obs.candidate_ids, K, true);
fixed_top = extract_topk_local(quant.score, obs.candidate_ids, K, true);
[~, baseline_order] = sort(obs.score_baseline, 'descend');
challenger_n = min(numel(baseline_order), max(2 * K, 32));
score_diff = abs(double(quant.score(:)) - double(obs.score_baseline(:)));
[~, diff_order] = sort(score_diff, 'descend');
diff_n = min(numel(diff_order), max(K, 32));
subset = unique([base_top.indices(:); fixed_top.indices(:); baseline_order(1:challenger_n); diff_order(1:diff_n)], 'stable');
subset = subset(1:min(numel(subset), cfg12.golden_vector_limit));
end

function write_golden_case_local(case_dir, case_name, spec, obs, quant, subset, cfg12)
manifest = key_value_table_local({ ...
    'case_name', case_name; ...
    'case_role', spec.case_role; ...
    'quant_mode', spec.quant_mode; ...
    'trial_index', spec.trial_index; ...
    'scenario_name', spec.scenario_name; ...
    'metric_name', spec.metric_name; ...
    'metric_value', spec.metric_value; ...
    'score_core_only_flag', 1; ...
    'full_fpga_backend_validation_flag', 0; ...
    'golden_vector_limit', cfg12.golden_vector_limit});
writetable(manifest, fullfile(case_dir, 'case_manifest.csv'), 'WriteVariableNames', false);

candidate_vars = intersect(obs.candidate_table.Properties.VariableNames, ...
    {'candidate_index','candidate_id','az1','az2','el1','el2','el_center','el_sep','orientation','iAz1','iAz2','iEl1','iEl2'}, 'stable');
candidate_min = obs.candidate_table(subset, candidate_vars);
writetable(candidate_min, fullfile(case_dir, 'candidate_table_minimal.csv'));

K = min(cfg12.topK_default, numel(obs.score_baseline));
base_top = topk_table_for_export_local(obs.score_baseline, obs.candidate_ids, K, 'baseline');
fixed_top = topk_table_for_export_local(quant.score, obs.candidate_ids, K, 'fixed');
writetable(base_top, fullfile(case_dir, 'score_baseline_topK.csv'));
writetable(fixed_top, fullfile(case_dir, 'score_fixed_topK.csv'));
writetable(base_top(:, {'rank','candidate_index','candidate_id','score'}), fullfile(case_dir, 'expected_topK.csv'));
writetable(qdiag_to_table_local(quant.qdiag), fullfile(case_dir, 'scale_metadata.csv'));
writetable(complex_matrix_to_table_local(quant.Rz, 'Rz'), fullfile(case_dir, 'Rz_q.csv'));
writetable(gpair_subset_to_table_local(obs, quant, subset), fullfile(case_dir, 'G_pair_subset_q.csv'));
writetable(score_subset_to_table_local(obs, quant, subset), fullfile(case_dir, 'score_expected_subset.csv'));
end

function T = topk_table_for_export_local(score, candidate_ids, K, label)
top = extract_topk_local(score, candidate_ids, K, true);
rank = (1:numel(top.indices)).';
candidate_index = top.indices(:);
candidate_id = top.ids(:);
score = top.scores(:);
score_source = repmat({label}, numel(rank), 1);
T = table(rank, candidate_index, candidate_id, score, score_source);
end

function T = qdiag_to_table_local(qdiag)
names = {'W','Gcache','Z','Rz','score'};
rows = cell(numel(names), 7);
for idx = 1:numel(names)
    q = qdiag.(names{idx});
    rows(idx, :) = {q.name, q.bits, q.scale, q.clip_rate, q.overflow_rate, q.relative_error, q.max_abs};
end
T = cell2table(rows, 'VariableNames', {'object_name','bits','scale','clip_rate','overflow_rate','relative_error','max_abs'});
end

function T = complex_matrix_to_table_local(X, object_name)
[rr, cc] = ndgrid(1:size(X, 1), 1:size(X, 2));
object = repmat({object_name}, numel(X), 1);
row = rr(:);
col = cc(:);
real_value = real(X(:));
imag_value = imag(X(:));
T = table(object, row, col, real_value, imag_value);
end

function T = gpair_subset_to_table_local(obs, quant, subset)
rows = {};
B = size(quant.G_use_grid, 1);
for sIdx = 1:numel(subset)
    cidx = subset(sIdx);
    for slot = 1:2
        if slot == 1
            g = quant.G_use_grid(:, obs.candidate_table.iAz1(cidx), obs.candidate_table.iEl1(cidx));
        else
            g = quant.G_use_grid(:, obs.candidate_table.iAz2(cidx), obs.candidate_table.iEl2(cidx));
        end
        for b = 1:B
            rows(end + 1, :) = {obs.candidate_table.candidate_index(cidx), slot, b, real(g(b)), imag(g(b))}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'candidate_index','vector_slot','beam_index','real_value','imag_value'});
end

function T = score_subset_to_table_local(obs, quant, subset)
candidate_index = obs.candidate_table.candidate_index(subset);
candidate_id = obs.candidate_ids(subset);
score_baseline = obs.score_baseline(subset);
score_fixed = quant.score(subset);
score_abs_diff = abs(score_fixed - score_baseline);
score_rel_diff = score_abs_diff ./ max(abs(score_baseline), eps);
T = table(candidate_index, candidate_id, score_baseline, score_fixed, score_abs_diff, score_rel_diff);
end

function doc_path = write_step12_record_doc_clean_local(cfg12, adapter_info, summary_tbl, keypoints_tbl, storage_tbl, bandwidth_tbl, worst_tbl, mode_selection_tbl, score_gap_bins_tbl, recommendation_tbl, golden_manifest_path, profile_summary_tbl)
doc_path = fullfile(cfg12.step_dir, '第12步_波束级ML_FPGA可行性边界验证记录.md');
fid = fopen(doc_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('step12:DocOpenFailed', 'Could not open doc: %s', doc_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# 第12步 波束级ML FPGA可行性边界验证记录\n\n');
fprintf(fid, '## 本轮目的\n\n');
fprintf(fid, '本轮围绕第11.x beamspace ML 后端，验证有限字长对 score ranking consistency、topK preservation、score gap stability 以及 cache/storage/bandwidth 的影响。\n\n');
fprintf(fid, '本步骤不是完整 FPGA RTL，不是 bit-true HDL 仿真，不是完整 FPGA backend 或下板验证结论，也不复用 Step8.9 的结果或 pass/fail 标准。\n\n');

fprintf(fid, '## 第11.x Adapter 来源\n\n');
fprintf(fid, '- final 入口: `%s`\n', adapter_info.entry_function);
fprintf(fid, '- score 函数: `%s`\n', adapter_info.score_function);
fprintf(fid, '- candidate 范围: %s\n', adapter_info.candidate_scope);
fprintf(fid, '- adapter found flag: %d\n', adapter_info.step11_adapter_found_flag);
fprintf(fid, '- uses_step89_results_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'uses_step89_results_flag'));
fprintf(fid, '- blocker: `%s`\n\n', get_keypoint_value_local(keypoints_tbl, 'blocker_if_any'));

fprintf(fid, '## Formal / Chunk 状态\n\n');
fprintf(fid, '- run_tag: `%s`\n', cfg12.run_tag);
fprintf(fid, '- quick_mode_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'quick_mode_flag'));
fprintf(fid, '- chunked_run_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'chunked_run_flag'));
fprintf(fid, '- formal_trial_count: %s\n', get_keypoint_value_local(keypoints_tbl, 'formal_trial_count'));
fprintf(fid, '- min_formal_obs: %s\n', get_keypoint_value_local(keypoints_tbl, 'min_formal_obs'));
fprintf(fid, '- formal_plan_total_obs: %s\n', get_keypoint_value_local(keypoints_tbl, 'formal_plan_total_obs'));
fprintf(fid, '- formal_plan_completed_obs: %s\n', get_keypoint_value_local(keypoints_tbl, 'formal_plan_completed_obs'));
fprintf(fid, '- formal_plan_complete_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'formal_plan_complete_flag'));
fprintf(fid, '- formal_min_obs_satisfied_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'formal_min_obs_satisfied_flag'));
fprintf(fid, '- chunks_detected: %s\n', get_keypoint_value_local(keypoints_tbl, 'chunks_detected'));
fprintf(fid, '- chunks_completed: %s\n\n', get_keypoint_value_local(keypoints_tbl, 'chunks_completed'));

if cfg12.quick_mode_flag
    fprintf(fid, '本次为 quick smoke test。smoke_fixed_point_pass_flag 仅说明 adapter、量化流程、score ranking/topK 统计和输出链路打通；formal fixed_point_pass_flag 仍为 0。\n\n');
elseif startsWith(cfg12.run_tag, 'pilot') || contains(cfg12.run_tag, 'chunk_pilot')
    fprintf(fid, '本次为 pilot/chunk pilot，用于验证 formal chunk/resume/aggregate 流程和字段完整性，不作为 formal_tps30 的正式 FPGA 可行性结论。\n\n');
end

fprintf(fid, '## Chunked Formal Validation\n\n');
fprintf(fid, 'formal_tps30 曾受交互窗口限制，本轮新增 chunked formal validation、checkpoint/resume、aggregate-only、formal_core mode set 和 profiling 输出。aggregate-only 只读取 chunk partial CSV，不重新运行 Step11 observation 或 score recomputation。\n\n');
fprintf(fid, '正式 proceed_to_rtl_score_core_flag 只能在非 quick、满足 min formal obs、uses_step89_results_flag=0 且 ranking/topK formal gate 通过时置 1。\n\n');

fprintf(fid, '## Quantization Modes\n\n');
fprintf(fid, 'mode_set 为 `%s`。formal_core 至少包含 double_baseline、float32_all、combined_int14、combined_int16、combined_int18、combined_int24、mixed_Z16_G24_Rz24 和 W_int18_G24_Z16。float32_all 仅为诊断参考，不作为 fixed-point pass candidate。\n\n', cfg12.mode_set);

fprintf(fid, '## Score Ranking / TopK Pass-Fail 标准\n\n');
fprintf(fid, '正式 fixed-point pass/fail 只由 ML score ranking consistency 和 topK preservation 决定。policy/confidence/fallback/boundary 仅作为工程风险诊断。\n\n');
fprintf(fid, '- ranking_pass_flag: reliable_top1_preservation_rate >= 0.999, reliable_score_gap_sign_flip_rate == 0, argmax_changed_rate_on_reliable_margin <= 0.001。\n');
fprintf(fid, '- topK_pass_flag: reliable_topK_set_preservation_rate >= 0.995, overall_topK_set_preservation_rate >= 0.980, reliable_topK_miss_rate <= 0.005。\n');
fprintf(fid, '- formal fixed_point_pass_flag 还要求 quick_mode_flag=0 且 formal_trial_count >= min_formal_obs。\n\n');

fprintf(fid, '## 总体结果表\n\n');
write_markdown_table_from_table_local(fid, summary_tbl, 16);

fprintf(fid, '\n## Mode Selection\n\n');
write_markdown_table_from_table_local(fid, mode_selection_tbl, 16);

fprintf(fid, '\n## combined_int16 状态\n\n');
fprintf(fid, '- combined_int16_formal_pass_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_formal_pass_flag'));
fprintf(fid, '- combined_int16_blocker_if_any: `%s`\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_blocker_if_any'));
fprintf(fid, '- combined_int16_reliable_top1_preservation: %s\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_reliable_top1_preservation'));
fprintf(fid, '- combined_int16_reliable_topK_preservation: %s\n\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_reliable_topK_preservation'));

fprintf(fid, '## Score Gap Stress Bins\n\n');
write_markdown_table_from_table_local(fid, score_gap_bins_tbl, 20);
fprintf(fid, '\n- reliable_margin_instability_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'reliable_margin_instability_flag'));
fprintf(fid, '- failures_limited_to_low_margin_cases: %s\n', get_keypoint_value_local(keypoints_tbl, 'failures_limited_to_low_margin_cases'));
fprintf(fid, '- worst_gap_bin_for_recommended_mode: `%s`\n\n', get_keypoint_value_local(keypoints_tbl, 'worst_gap_bin_for_recommended_mode'));

fprintf(fid, '## Cache Storage 估算\n\n');
write_markdown_table_from_table_local(fid, storage_tbl, 12);

fprintf(fid, '\n## Bandwidth / Score Lane 估算\n\n');
write_markdown_table_from_table_local(fid, bandwidth_tbl, 12);

fprintf(fid, '\n## Profiling 摘要\n\n');
write_markdown_table_from_table_local(fid, profile_summary_tbl, 12);

fprintf(fid, '\n## Worst Cases 总结\n\n');
write_markdown_table_from_table_local(fid, worst_tbl, 12);

fprintf(fid, '\n## Recommendation\n\n');
write_markdown_table_from_table_local(fid, recommendation_tbl, 8);

fprintf(fid, '\n## Golden Vectors\n\n');
if ~isempty(golden_manifest_path)
    fprintf(fid, '- exported: 1\n');
    fprintf(fid, '- manifest: `%s`\n', golden_manifest_path);
else
    fprintf(fid, '- exported: 0\n');
    fprintf(fid, '- reason: 需要 formal fixed-point pass 且 STEP12_EXPORT_GOLDEN_VECTORS=1。\n');
end

fprintf(fid, '\n## 最终判断\n\n');
fprintf(fid, '- minimum_passing_mode: `%s`\n', get_keypoint_value_local(keypoints_tbl, 'minimum_passing_mode'));
fprintf(fid, '- engineering_recommended_fixed_point_format: `%s`\n', get_keypoint_value_local(keypoints_tbl, 'engineering_recommended_fixed_point_format'));
fprintf(fid, '- fixed_point_pass_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag'));
fprintf(fid, '- blocker_if_any: `%s`\n', get_keypoint_value_local(keypoints_tbl, 'blocker_if_any'));
fprintf(fid, '- proceed_to_rtl_score_core_flag: %s\n', get_keypoint_value_local(keypoints_tbl, 'proceed_to_rtl_score_core_flag'));
fprintf(fid, '- proceed_to_full_fpga_backend_flag: %s\n\n', get_keypoint_value_local(keypoints_tbl, 'proceed_to_full_fpga_backend_flag'));

fprintf(fid, '## 下一步建议\n\n');
if cfg12.quick_mode_flag
    fprintf(fid, '先运行 formal validation，再决定是否进入 RTL score core prototype。\n');
elseif startsWith(cfg12.run_tag, 'pilot') || contains(cfg12.run_tag, 'chunk_pilot')
    fprintf(fid, '本次仅证明 chunk/resume/aggregate 路径可用。下一步继续按 formal_tps30 chunk plan 运行更多 chunks，并在 aggregate 后检查 formal_trial_count 是否达到 STEP12_MIN_FORMAL_OBS。\n');
elseif str2double(get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag')) == 1
    fprintf(fid, 'formal ranking/topK gate 已对工程推荐 fixed-point mode 关闭。下一步只建议进入 RTL score core prototype；这仍不代表完整 FPGA backend 通过。\n');
else
    fprintf(fid, '不建议进入 RTL score core prototype。应继续运行 formal chunks 或针对 blocker 调整有限字长方案。\n');
end

clear cleanup;
end

function doc_path = write_step12_record_doc_v2_local(cfg12, adapter_info, summary_tbl, keypoints_tbl, storage_tbl, bandwidth_tbl, worst_tbl, mode_selection_tbl, score_gap_bins_tbl, recommendation_tbl, golden_manifest_path)
doc_path = fullfile(cfg12.step_dir, '第12步_波束级ML_FPGA可行性边界验证记录.md');
fid = fopen(doc_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('step12:DocOpenFailed', 'Could not open doc: %s', doc_path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# 第12步 波束级ML FPGA可行性边界验证记录\n\n');
fprintf(fid, '## 本轮目的\n\n');
fprintf(fid, '本轮围绕第11.x beamspace ML 后端，验证有限字长对 score ranking consistency、topK preservation、score gap stability 以及 cache/storage/bandwidth 的影响。\n\n');
fprintf(fid, '本步骤不是完整 FPGA RTL、不是 bit-true HDL 仿真、不是完整 FPGA backend 或下板验证结论，也不复用 Step8.9 的结果或 pass/fail 标准。\n\n');
fprintf(fid, '## 第11.x adapter 来源\n\n');
fprintf(fid, '- final 入口：`%s`\n', adapter_info.entry_function);
fprintf(fid, '- score 函数：`%s`\n', adapter_info.score_function);
fprintf(fid, '- candidate 范围：%s\n', adapter_info.candidate_scope);
fprintf(fid, '- adapter found flag：%d\n', adapter_info.step11_adapter_found_flag);
fprintf(fid, '- uses_step89_results_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'uses_step89_results_flag'));
fprintf(fid, '- blocker：`%s`\n\n', get_keypoint_value_local(keypoints_tbl, 'blocker_if_any'));

fprintf(fid, '## Formal / Quick 状态\n\n');
fprintf(fid, '- run_tag：`%s`\n', cfg12.run_tag);
fprintf(fid, '- quick_mode_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'quick_mode_flag'));
fprintf(fid, '- formal_trial_count：%s\n', get_keypoint_value_local(keypoints_tbl, 'formal_trial_count'));
fprintf(fid, '- min_formal_obs：%s\n', get_keypoint_value_local(keypoints_tbl, 'min_formal_obs'));
fprintf(fid, '- reliable_margin_threshold：%s\n\n', get_keypoint_value_local(keypoints_tbl, 'reliable_margin_threshold'));
if strcmp(cfg12.run_tag, 'pilot_min_fast_path') || strcmp(cfg12.run_tag, 'pilot_min_path')
    fprintf(fid, '运行备注：本轮是较小的 formal-path pilot，用于验证 Step12 formal 输出链路。用户请求的 `pilot_tps10` 在当前交互执行窗口内超时，`formal_tps30` 未完成，因此本记录不构成正式 FPGA 可行性结论。\n\n');
end

fprintf(fid, '## Quantization Modes\n\n');
fprintf(fid, '包含 double baseline、float32 diagnostic、W/G_cache/Z/Rz 单对象整数模式、combined_int16/int18/int24、mixed_Z16_G24_Rz24 等。float32_all 仅作诊断参考，不参与 fixed-point pass candidate。\n\n');

fprintf(fid, '## Score Ranking / TopK Pass-Fail 标准\n\n');
fprintf(fid, '正式 fixed-point pass/fail 只由 ML score ranking consistency 和 topK preservation 决定。policy/confidence/fallback/boundary 仅作为工程风险诊断。\n\n');
fprintf(fid, '- ranking_pass_flag：reliable_top1_preservation_rate >= 0.999，reliable_score_gap_sign_flip_rate == 0，argmax_changed_rate_on_reliable_margin <= 0.001。\n');
fprintf(fid, '- topK_pass_flag：reliable_topK_set_preservation_rate >= 0.995，overall_topK_set_preservation_rate >= 0.980，reliable_topK_miss_rate <= 0.005。\n');
fprintf(fid, '- formal fixed_point_pass_flag 还要求 quick_mode_flag=0 且 formal_trial_count >= min_formal_obs。\n\n');

fprintf(fid, '## 总体结果表\n\n');
write_markdown_table_from_table_local(fid, summary_tbl, 16);
fprintf(fid, '\n## Mode Selection\n\n');
write_markdown_table_from_table_local(fid, mode_selection_tbl, 16);
fprintf(fid, '\n## combined_int16 状态\n\n');
fprintf(fid, '- combined_int16_formal_pass_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_formal_pass_flag'));
fprintf(fid, '- combined_int16_blocker_if_any：`%s`\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_blocker_if_any'));
fprintf(fid, '- combined_int16_reliable_top1_preservation：%s\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_reliable_top1_preservation'));
fprintf(fid, '- combined_int16_reliable_topK_preservation：%s\n\n', get_keypoint_value_local(keypoints_tbl, 'combined_int16_reliable_topK_preservation'));

fprintf(fid, '## Score Gap Stress Bins\n\n');
write_markdown_table_from_table_local(fid, score_gap_bins_tbl, 20);
fprintf(fid, '\n- reliable_margin_instability_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'reliable_margin_instability_flag'));
fprintf(fid, '- failures_limited_to_low_margin_cases：%s\n', get_keypoint_value_local(keypoints_tbl, 'failures_limited_to_low_margin_cases'));
fprintf(fid, '- worst_gap_bin_for_recommended_mode：`%s`\n\n', get_keypoint_value_local(keypoints_tbl, 'worst_gap_bin_for_recommended_mode'));

fprintf(fid, '## Cache Storage 估算\n\n');
write_markdown_table_from_table_local(fid, storage_tbl, 12);
fprintf(fid, '\n## Bandwidth / Score Lane 估算\n\n');
write_markdown_table_from_table_local(fid, bandwidth_tbl, 12);
fprintf(fid, '\n## Worst Cases 总结\n\n');
write_markdown_table_from_table_local(fid, worst_tbl, 12);
fprintf(fid, '\n## Recommendation\n\n');
write_markdown_table_from_table_local(fid, recommendation_tbl, 8);

fprintf(fid, '\n## Golden Vectors\n\n');
if ~isempty(golden_manifest_path)
    fprintf(fid, '- exported：1\n');
    fprintf(fid, '- manifest：`%s`\n', golden_manifest_path);
else
    fprintf(fid, '- exported：0\n');
    fprintf(fid, '- reason：需要 formal fixed-point pass 且 `STEP12_EXPORT_GOLDEN_VECTORS=1`。\n');
end

fprintf(fid, '\n## 最终判断\n\n');
fprintf(fid, '- minimum_passing_mode：`%s`\n', get_keypoint_value_local(keypoints_tbl, 'minimum_passing_mode'));
fprintf(fid, '- engineering_recommended_fixed_point_format：`%s`\n', get_keypoint_value_local(keypoints_tbl, 'engineering_recommended_fixed_point_format'));
fprintf(fid, '- fixed_point_pass_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag'));
fprintf(fid, '- blocker_if_any：`%s`\n', get_keypoint_value_local(keypoints_tbl, 'blocker_if_any'));
fprintf(fid, '- proceed_to_rtl_score_core_flag：%s\n', get_keypoint_value_local(keypoints_tbl, 'proceed_to_rtl_score_core_flag'));
fprintf(fid, '- proceed_to_full_fpga_backend_flag：%s\n\n', get_keypoint_value_local(keypoints_tbl, 'proceed_to_full_fpga_backend_flag'));

fprintf(fid, '## 下一步建议\n\n');
if cfg12.quick_mode_flag
    fprintf(fid, '本次为 quick smoke test。smoke_fixed_point_pass_flag 只说明 adapter、量化流程、score ranking/topK 统计和输出链路打通；formal fixed_point_pass_flag 仍为 0。下一步应先运行 formal validation，再决定是否进入 RTL score core prototype。\n');
elseif startsWith(cfg12.run_tag, 'pilot')
    fprintf(fid, '本次为 pilot formal-path run，用于检查运行时间、结果字段和 mode selection 链路；不作为论文正式结论。若字段稳定，下一步运行 formal_tps30。\n');
elseif str2double(get_keypoint_value_local(keypoints_tbl, 'fixed_point_pass_flag')) == 1
    fprintf(fid, 'formal ranking/topK 已对工程推荐 fixed-point mode 关闭。下一步只建议进入 RTL score core prototype；这仍不代表完整 FPGA backend 通过。\n');
else
    fprintf(fid, '不建议进入 RTL score core prototype。应先针对 blocker 继续扩大 formal 样本或调整 score-core 有限字长方案。\n');
end
clear cleanup;
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

function value = safe_input_field_local(input, field, fallback)
value = fallback;
if isstruct(input) && isfield(input, field)
    value = input.(field);
end
end

function value = nonempty_or_fallback_local(value, fallback)
if isstring(value)
    value = char(value);
end
if isempty(value)
    value = fallback;
end
end

function value = parse_env_scalar_local(name, default_value)
raw = strtrim(getenv(name));
if isempty(raw)
    value = default_value;
    return;
end
value = str2double(raw);
if isnan(value)
    value = default_value;
end
end

function values = parse_env_numeric_list_local(name, default_values)
raw = strtrim(getenv(name));
if isempty(raw)
    values = default_values;
    return;
end
parts = regexp(raw, '[,;\s]+', 'split');
values = [];
for idx = 1:numel(parts)
    if isempty(parts{idx})
        continue;
    end
    v = str2double(parts{idx});
    if isfinite(v)
        values(end + 1) = v; %#ok<AGROW>
    end
end
if isempty(values)
    values = default_values;
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
