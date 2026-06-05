function evidence = collect_step11_3_search_evidence(step_dir)
%COLLECT_STEP11_3_SEARCH_EVIDENCE Collect existing Step11.3 result evidence.

if nargin < 1 || isempty(step_dir)
    step_dir = fileparts(fileparts(mfilename('fullpath')));
end

stage1_dir = fullfile(step_dir, 'results_step11_3_stage1_coarse_to_fine_sanity');
stage2_dir = fullfile(step_dir, 'results_step11_3_stage2_topk_grid_sweep');
stage3_dir = fullfile(step_dir, 'results_step11_3_stage3_frontend_prior_bias_robustness');

missing_files = {};
[stage1_keypoints, missing_files] = read_keypoints_file_local( ...
    fullfile(stage1_dir, 'step11_3_stage1_keypoints.csv'), missing_files);
[stage1_summary, missing_files] = read_table_file_local( ...
    fullfile(stage1_dir, 'step11_3_stage1_summary.csv'), missing_files);
[stage2_keypoints, missing_files] = read_keypoints_file_local( ...
    fullfile(stage2_dir, 'step11_3_stage2_keypoints.csv'), missing_files);
[stage2_screening_summary, missing_files] = read_table_file_local( ...
    fullfile(stage2_dir, 'step11_3_stage2_screening_summary.csv'), missing_files);
[stage2_confirmation_summary, missing_files] = read_table_file_local( ...
    fullfile(stage2_dir, 'step11_3_stage2_confirmation_summary.csv'), missing_files);
[stage2_config_table, missing_files] = read_table_file_local( ...
    fullfile(stage2_dir, 'step11_3_stage2_config_table.csv'), missing_files);
[stage3_keypoints, missing_files] = read_keypoints_file_local( ...
    fullfile(stage3_dir, 'step11_3_stage3_keypoints.csv'), missing_files);
[stage3_summary, missing_files] = read_table_file_local( ...
    fullfile(stage3_dir, 'step11_3_stage3_summary.csv'), missing_files);

stage2_pass = read_keypoint_numeric_local(stage2_keypoints, 'search_acceleration_pass_flag', 0);
stage3_pass = read_keypoint_numeric_local(stage3_keypoints, 'frontend_prior_robustness_pass_flag', 0);
if stage2_pass == 1 && stage3_pass == 1
    final_recommendation = 'use_degree_based_coarse_to_fine_topK3_for_controlled_pair2d_beamspace_ml';
else
    final_recommendation = 'keep_full_fine_grid_or_continue_tuning_coarse_to_fine';
end

evidence = struct();
evidence.step_dir = step_dir;
evidence.stage1_keypoints = stage1_keypoints;
evidence.stage1_summary = stage1_summary;
evidence.stage2_keypoints = stage2_keypoints;
evidence.stage2_screening_summary = stage2_screening_summary;
evidence.stage2_confirmation_summary = stage2_confirmation_summary;
evidence.stage2_config_table = stage2_config_table;
evidence.stage3_keypoints = stage3_keypoints;
evidence.stage3_summary = stage3_summary;
evidence.final_recommendation = final_recommendation;
evidence.missing_files = missing_files(:);
evidence.final_stage_status_table = build_stage_status_table_local(evidence, stage2_pass, stage3_pass);
evidence.final_key_metrics_table = build_key_metrics_table_local(evidence);
evidence.final_recommendation_table = build_recommendation_table_local(evidence, stage2_pass, stage3_pass);
end

function [T, missing_files] = read_table_file_local(path_in, missing_files)
if exist(path_in, 'file') ~= 2
    missing_files{end + 1, 1} = path_in;
    T = table();
    return;
end
opts = detectImportOptions(path_in, 'TextType', 'string');
T = readtable(path_in, opts);
end

function [keypoints, missing_files] = read_keypoints_file_local(path_in, missing_files)
if exist(path_in, 'file') ~= 2
    missing_files{end + 1, 1} = path_in;
    keypoints = table(string.empty(0, 1), string.empty(0, 1), ...
        'VariableNames', {'keypoint','value'});
    return;
end
lines = readlines(path_in);
lines = lines(strlength(strtrim(lines)) > 0);
if isempty(lines)
    keypoints = table(string.empty(0, 1), string.empty(0, 1), ...
        'VariableNames', {'keypoint','value'});
    return;
end
if startsWith(lower(strtrim(lines(1))), "keypoint,")
    lines = lines(2:end);
end
keys = strings(numel(lines), 1);
values = strings(numel(lines), 1);
for idx = 1:numel(lines)
    raw = char(lines(idx));
    comma_idx = find(raw == ',', 1);
    if isempty(comma_idx)
        keys(idx) = string(strtrim(raw));
        values(idx) = "";
    else
        keys(idx) = string(strtrim(raw(1:comma_idx - 1)));
        values(idx) = string(strip_outer_quotes_local(strtrim(raw(comma_idx + 1:end))));
    end
end
keypoints = table(keys, values, 'VariableNames', {'keypoint','value'});
end

function T = build_stage_status_table_local(evidence, stage2_pass, stage3_pass)
stage1_pass = read_keypoint_numeric_local(evidence.stage1_keypoints, 'search_acceleration_pass_flag', NaN);
stage1_success = read_keypoint_numeric_local(evidence.stage1_keypoints, 'coarse_to_fine_success', NaN);
stage1_miss = read_keypoint_numeric_local(evidence.stage1_keypoints, 'topK_miss_rate', NaN);
stage1_reduction = read_keypoint_numeric_local(evidence.stage1_keypoints, 'complexity_reduction_ratio', NaN);
stage2_success = read_keypoint_numeric_local(evidence.stage2_keypoints, 'coarse_to_fine_success', NaN);
stage2_miss = read_keypoint_numeric_local(evidence.stage2_keypoints, 'topK_miss_rate', NaN);
stage2_reduction = read_keypoint_numeric_local(evidence.stage2_keypoints, 'complexity_reduction_ratio', NaN);
stage3_success = read_keypoint_numeric_local(evidence.stage3_keypoints, 'zero_bias_success', NaN);
stage3_miss = read_keypoint_numeric_local(evidence.stage3_keypoints, 'max_bias_topK_miss_rate', NaN);

T = table( ...
    ["Stage1"; "Stage2"; "Stage3"], ...
    ["degree-based sanity check"; "two-phase topK/grid sweep"; "frontend-prior bias robustness"], ...
    ["degree-based el_sep fixes success/topK miss but default window is not enough acceleration"; ...
     "screening plus confirmation finds the passing topK3 coarse-to-fine config"; ...
     "recommended Stage2 config remains robust under nominal +/-0.2 deg bias cases"], ...
    [stage1_success; stage2_success; stage3_success], ...
    [stage1_miss; stage2_miss; stage3_miss], ...
    [stage1_reduction; stage2_reduction; NaN], ...
    [stage1_pass; stage2_pass; stage3_pass], ...
    'VariableNames', {'stage','goal','interpretation','success_metric','topK_miss_rate','complexity_reduction_ratio','pass_flag'});
end

function T = build_key_metrics_table_local(evidence)
metrics = { ...
    'recommended_config_name', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_config_name', 'missing'); ...
    'recommended_topK', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_topK', 'missing'); ...
    'recommended_coarse_az_step', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_coarse_az_step', 'missing'); ...
    'recommended_coarse_el_step', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_coarse_el_step', 'missing'); ...
    'recommended_fine_az_step', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_fine_az_step', 'missing'); ...
    'recommended_fine_el_step', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_fine_el_step', 'missing'); ...
    'recommended_coarse_el_sep_list', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_coarse_el_sep_list_text', 'missing'); ...
    'recommended_fine_el_sep_list', read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_fine_el_sep_list_text', 'missing'); ...
    'full_fine_success', read_keypoint_text_local(evidence.stage2_keypoints, 'full_fine_success', 'missing'); ...
    'coarse_to_fine_success', read_keypoint_text_local(evidence.stage2_keypoints, 'coarse_to_fine_success', 'missing'); ...
    'full_fine_rmse', read_keypoint_text_local(evidence.stage2_keypoints, 'full_fine_rmse', 'missing'); ...
    'coarse_to_fine_rmse', read_keypoint_text_local(evidence.stage2_keypoints, 'coarse_to_fine_rmse', 'missing'); ...
    'full_fine_mean_num_pairs', read_keypoint_text_local(evidence.stage2_keypoints, 'full_fine_mean_num_pairs', 'missing'); ...
    'coarse_to_fine_mean_num_pairs', read_keypoint_text_local(evidence.stage2_keypoints, 'coarse_to_fine_mean_num_pairs', 'missing'); ...
    'complexity_reduction_ratio', read_keypoint_text_local(evidence.stage2_keypoints, 'complexity_reduction_ratio', 'missing'); ...
    'full_grid_match_rate', read_keypoint_text_local(evidence.stage2_keypoints, 'full_grid_match_rate', 'missing'); ...
    'topK_miss_rate', read_keypoint_text_local(evidence.stage2_keypoints, 'topK_miss_rate', 'missing'); ...
    'boundary_hit_rate', read_keypoint_text_local(evidence.stage2_keypoints, 'boundary_hit_rate', 'missing'); ...
    'frontend_prior_robustness_pass_flag', read_keypoint_text_local(evidence.stage3_keypoints, 'frontend_prior_robustness_pass_flag', 'missing'); ...
    'max_bias_success_drop', read_keypoint_text_local(evidence.stage3_keypoints, 'max_bias_success_drop', 'missing'); ...
    'max_bias_topK_miss_rate', read_keypoint_text_local(evidence.stage3_keypoints, 'max_bias_topK_miss_rate', 'missing'); ...
    'max_bias_boundary_hit_rate', read_keypoint_text_local(evidence.stage3_keypoints, 'max_bias_boundary_hit_rate', 'missing'); ...
    'valid_bias_range_text', read_keypoint_text_local(evidence.stage3_keypoints, 'valid_bias_range_text', 'missing')};
T = cell2table(metrics, 'VariableNames', {'metric','value'});
end

function T = build_recommendation_table_local(evidence, stage2_pass, stage3_pass)
T = table( ...
    string(evidence.final_recommendation), ...
    "degree_based_coarse_to_fine", ...
    string(read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_topK', '3')), ...
    string(read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_coarse_az_step', '0.16')), ...
    string(read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_coarse_el_step', '0.24')), ...
    string(read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_fine_az_step', '0.08')), ...
    string(read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_fine_el_step', '0.12')), ...
    string(read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_coarse_el_sep_list_text', '[0,0.36,0.72]')), ...
    string(read_keypoint_text_local(evidence.stage2_keypoints, 'recommended_fine_el_sep_list_text', '[0,0.24,0.36,0.48,0.60,0.72]')), ...
    "greedy_combined_B7", ...
    stage2_pass, stage3_pass, ...
    'VariableNames', {'final_recommendation','recommended_search','recommended_topK', ...
    'recommended_coarse_az_step','recommended_coarse_el_step','recommended_fine_az_step', ...
    'recommended_fine_el_step','recommended_coarse_el_sep_list','recommended_fine_el_sep_list', ...
    'recommended_W','stage2_pass_flag','stage3_pass_flag'});
end

function value = read_keypoint_numeric_local(T, key, fallback)
if isempty(T)
    value = fallback;
    return;
end
mask = strcmp(T.keypoint, string(key));
if ~any(mask)
    value = fallback;
    return;
end
value = str2double(T.value(find(mask, 1)));
if ~isfinite(value)
    value = fallback;
end
end

function value = read_keypoint_text_local(T, key, fallback)
if isempty(T)
    value = fallback;
    return;
end
mask = strcmp(T.keypoint, string(key));
if ~any(mask)
    value = fallback;
    return;
end
value = char(T.value(find(mask, 1)));
if isempty(value)
    value = fallback;
end
end

function value = strip_outer_quotes_local(value)
if numel(value) >= 2 && value(1) == '"' && value(end) == '"'
    value = value(2:end - 1);
end
value = strrep(value, '""', '"');
end
