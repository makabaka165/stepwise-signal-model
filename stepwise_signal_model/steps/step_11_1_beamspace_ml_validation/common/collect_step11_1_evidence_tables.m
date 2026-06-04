function evidence = collect_step11_1_evidence_tables(step_dir)
%COLLECT_STEP11_1_EVIDENCE_TABLES Collect Step11.1 Stage1-Stage6 keypoints.

if nargin ~= 1
    error('collect_step11_1_evidence_tables:InvalidInputCount', 'step_dir is required.');
end
if ~exist(step_dir, 'dir')
    error('collect_step11_1_evidence_tables:MissingStepDir', 'step_dir does not exist: %s', step_dir);
end

stage_defs = make_stage_defs_local(step_dir);
missing_files = {};
status_rows = repmat(make_status_row_template_local(), numel(stage_defs), 1);
key_metric_rows = repmat(make_key_metric_row_template_local(), 0, 1);

evidence = struct();
for idx = 1:numel(stage_defs)
    def = stage_defs(idx);
    field_name = sprintf('stage%d_keypoints', def.stage_id);
    if exist(def.keypoints_path, 'file') == 2
        tbl = readtable(def.keypoints_path, 'TextType', 'string');
        evidence.(field_name) = tbl;
        [pass_flag, recommended_next_step] = extract_pass_and_next_local(tbl, def.pass_metric);
        key_metrics_text = build_key_metrics_text_local(tbl, def.key_metrics);
        status = 'complete';
        key_metric_rows = append_key_metric_rows_local(key_metric_rows, def, tbl);
    else
        tbl = table();
        evidence.(field_name) = tbl;
        missing_files{end + 1, 1} = def.keypoints_path; %#ok<AGROW>
        pass_flag = NaN;
        recommended_next_step = 'missing_keypoints';
        key_metrics_text = 'missing keypoints file';
        status = 'missing';
    end

    status_rows(idx).stage = def.stage_name;
    status_rows(idx).goal = def.goal;
    status_rows(idx).key_pass_flag = def.pass_metric;
    status_rows(idx).pass_flag_value = pass_flag;
    status_rows(idx).key_metrics = key_metrics_text;
    status_rows(idx).conclusion = def.conclusion;
    status_rows(idx).limitation = def.limitation;
    status_rows(idx).recommended_next_step = recommended_next_step;
    status_rows(idx).status = status;
    status_rows(idx).keypoints_path = def.keypoints_path;
end

evidence.stage_defs = stage_defs;
evidence.stage_status_table = struct2table(status_rows);
if isempty(key_metric_rows)
    evidence.final_key_metrics_table = struct2table(make_key_metric_row_template_local());
    evidence.final_key_metrics_table(1, :) = [];
else
    evidence.final_key_metrics_table = struct2table(key_metric_rows);
end
evidence.missing_files = missing_files;
evidence.final_recommendation = build_final_recommendation_local(evidence.stage_status_table, missing_files);
evidence.collected_at = datestr(now);
evidence.step_dir = step_dir;
end

function stage_defs = make_stage_defs_local(step_dir)
template = struct('stage_id', NaN, 'stage_name', '', 'goal', '', 'pass_metric', '', ...
    'keypoints_path', '', 'key_metrics', {{}}, 'conclusion', '', 'limitation', '');
stage_defs = repmat(template, 6, 1);
stage_defs(1) = make_stage_def_local(1, 'Stage1 ULA prior ablation', ...
    'Check whether ULA beamspace ML depends on left/right partition prior.', ...
    'prior_dependency_flag', fullfile(step_dir, 'results_step11_1_ula_prior_ablation', 'step11_1_ula_prior_ablation_keypoints.csv'), ...
    {'prior_dependency_flag'}, ...
    'ULA beamspace ML is not obviously dependent on the left/right partition prior.', ...
    'ULA-only ablation; not a cylindrical-array final result.');
stage_defs(2) = make_stage_def_local(2, 'Stage2 cylindrical az-only beamspace ML', ...
    'Validate the fixed-elevation cylindrical az-only beamspace ML loop.', ...
    'cyl_azonly_pass_flag', fullfile(step_dir, 'results_step11_1_cyl_azonly_beamspace_ml', 'step11_1_cyl_azonly_keypoints.csv'), ...
    {'cyl_azonly_pass_flag'}, ...
    'Cylindrical fixed-el az-only beamspace ML passes.', ...
    'Az-only with fixed el0; not a complete 2D pair estimator.');
stage_defs(3) = make_stage_def_local(3, 'Stage3 cylindrical common-el 2D beamspace ML', ...
    'Validate cylindrical 2D beamspace ML under a common-elevation assumption.', ...
    'cyl_common_el_2d_pass_flag', fullfile(step_dir, 'results_step11_1_cyl_common_el_2d_beamspace_ml', 'step11_1_cyl_common_el_2d_keypoints.csv'), ...
    {'cyl_common_el_2d_pass_flag'}, ...
    'Common-el 2D beamspace ML passes as a baseline route.', ...
    'Shared-elevation assumption limits separated-elevation cases.');
stage_defs(4) = make_stage_def_local(4, 'Stage4 controlled el-separated pair2d beamspace ML', ...
    'Validate the controlled el-separated pair parameterization.', ...
    'cyl_el_separation_pass_flag', fullfile(step_dir, 'results_step11_1_cyl_el_separation_beamspace_ml', 'step11_1_cyl_el_separation_keypoints.csv'), ...
    {'cyl_el_separation_pass_flag','best_sep_joint_success_bias0_snr30','sep_minus_common_joint_success_gap_bias0_snr30'}, ...
    'Controlled pair2d improves separated-elevation cases over common-el.', ...
    'Controlled pair2d is not full unconstrained 4D.');
stage_defs(5) = make_stage_def_local(5, 'Stage5 coherence stress', ...
    'Stress controlled pair2d under correlated and strongly correlated sources.', ...
    'coherence_stress_pass_flag', fullfile(step_dir, 'results_step11_1_cyl_coherence_stress', 'step11_1_cyl_coherence_stress_keypoints.csv'), ...
    {'coherence_stress_pass_flag','pass_rate_moderate_coherence','pass_rate_strong_coherence','worst_case_joint_success_pair2d_white','max_false_high_like_rate'}, ...
    'Coherence stress passes in aggregate and exposes boundary cases.', ...
    'Strong-coherence worst cases still exist; confidence boundary is not complete.');
stage_defs(6) = make_stage_def_local(6, 'Stage6 full4d upper-bound comparison', ...
    'Compare common-el, controlled pair2d, and local full4d beamspace ML.', ...
    'full4d_pass_flag', fullfile(step_dir, 'results_step11_1_full4d_beamspace_ml_comparison', 'step11_1_full4d_comparison_keypoints.csv'), ...
    {'full4d_pass_flag','best_full4d_joint_success','best_pair2d_joint_success','full4d_minus_pair2d_success_gap','complexity_ratio_full4d_over_pair2d','full4d_recommended_role'}, ...
    'Full4d is an upper-bound comparison; controlled pair2d remains sufficient in tested cases.', ...
    'Full4d has higher complexity and is not the default main algorithm.');
end

function def = make_stage_def_local(stage_id, stage_name, goal, pass_metric, keypoints_path, key_metrics, conclusion, limitation)
def = struct();
def.stage_id = stage_id;
def.stage_name = stage_name;
def.goal = goal;
def.pass_metric = pass_metric;
def.keypoints_path = keypoints_path;
def.key_metrics = key_metrics;
def.conclusion = conclusion;
def.limitation = limitation;
end

function row = make_status_row_template_local()
row = struct();
row.stage = '';
row.goal = '';
row.key_pass_flag = '';
row.pass_flag_value = NaN;
row.key_metrics = '';
row.conclusion = '';
row.limitation = '';
row.recommended_next_step = '';
row.status = '';
row.keypoints_path = '';
end

function row = make_key_metric_row_template_local()
row = struct();
row.stage = '';
row.metric = '';
row.metric_value = NaN;
row.metric_text = '';
end

function rows = append_key_metric_rows_local(rows, def, tbl)
for idx = 1:numel(def.key_metrics)
    metric = def.key_metrics{idx};
    [metric_value, metric_text] = get_metric_local(tbl, metric);
    row = make_key_metric_row_template_local();
    row.stage = def.stage_name;
    row.metric = metric;
    row.metric_value = metric_value;
    row.metric_text = metric_text;
    rows(end + 1, 1) = row; %#ok<AGROW>
end
end

function [pass_flag, recommended_next_step] = extract_pass_and_next_local(tbl, pass_metric)
[pass_flag, ~] = get_metric_local(tbl, pass_metric);
[~, recommended_next_step] = get_metric_local(tbl, 'recommended_next_step');
if isempty(recommended_next_step)
    recommended_next_step = '';
end
end

function text = build_key_metrics_text_local(tbl, metric_names)
parts = cell(1, numel(metric_names));
for idx = 1:numel(metric_names)
    metric = metric_names{idx};
    [value, metric_text] = get_metric_local(tbl, metric);
    if ~isempty(metric_text)
        parts{idx} = sprintf('%s=%s', metric, metric_text);
    elseif isfinite(value)
        parts{idx} = sprintf('%s=%.12g', metric, value);
    else
        parts{idx} = sprintf('%s=NaN', metric);
    end
end
text = strjoin(parts, '; ');
end

function [metric_value, metric_text] = get_metric_local(tbl, metric_name)
metric_value = NaN;
metric_text = '';
if isempty(tbl) || ~ismember('metric', tbl.Properties.VariableNames)
    return;
end
mask = strcmp(string(tbl.metric), string(metric_name));
if ~any(mask)
    return;
end
idx = find(mask, 1, 'first');
if ismember('metric_value', tbl.Properties.VariableNames)
    metric_value = tbl.metric_value(idx);
end
if ismember('metric_text', tbl.Properties.VariableNames)
    metric_text = safe_text_local(tbl.metric_text(idx));
end
end

function text = safe_text_local(value)
if iscell(value)
    value = value{1};
end
if isstring(value)
    if ismissing(value)
        text = '';
    else
        text = char(value);
    end
elseif ischar(value)
    text = value;
else
    value_str = string(value);
    if ismissing(value_str)
        text = '';
    else
        text = char(value_str);
    end
end
end

function final_recommendation = build_final_recommendation_local(stage_status_table, missing_files)
if ~isempty(missing_files)
    final_recommendation = 'complete_missing_stage_outputs_before_final_writeup';
    return;
end
stage5_pass = stage_status_table.pass_flag_value(strcmp(stage_status_table.key_pass_flag, 'coherence_stress_pass_flag'));
stage6_pass = stage_status_table.pass_flag_value(strcmp(stage_status_table.key_pass_flag, 'full4d_pass_flag'));
if ~isempty(stage5_pass) && ~isempty(stage6_pass) && stage5_pass == 1 && stage6_pass == 1
    final_recommendation = 'use_controlled_pair2d_beamspace_ml_as_main_thesis_route_with_full4d_upper_bound';
else
    final_recommendation = 'document_limitations_before_final_route_claim';
end
end
