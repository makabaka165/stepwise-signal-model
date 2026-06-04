clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
step_dir = fileparts(script_dir);
steps_dir = fileparts(step_dir);
project_dir = fileparts(steps_dir);
common_dir = fullfile(step_dir, 'common');
result_dir = fullfile(step_dir, 'results_step11_1_cyl_coherence_stress');

addpath(common_dir);
addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_lines = {};
log_lines = append_log_local(log_lines, 'Step11.1 Stage5 starts');
log_lines = append_log_local(log_lines, 'Script: %s', mfilename('fullpath'));
log_lines = append_log_local(log_lines, 'Result directory: %s', result_dir);

cfg = sim_cfg();
arrInfo = arr_cyl(cfg, cfg.beam.azSectorCenter);
x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
N_elem = numel(x);
expected_N_elem = cfg.beam.subNaz * cfg.arr.Nel;
if N_elem ~= expected_N_elem
    error('run_stage5:NelemMismatch', 'Expected N_elem=%d, got %d.', expected_N_elem, N_elem);
end

lambda = cfg.arr.lambda;
phase_factor = cfg.beam.spatialPhaseFactor;
phase_sign = 1;

base_seed = 20260615;
L = 64;
Metkl = 3;
az_center_true = cfg.beam.azSectorCenter;
el_center_nominal = cfg.beam.elSectorCenter;
beam_layouts = struct( ...
    'name', {'az5_el5', 'az5_el3'}, ...
    'az_count', {5, 5}, ...
    'el_count', {5, 3});
model_mode_list = {'pair2d', 'common_el_restricted'};
whitening_mode_list = {'none', 'white'};
rho_list = [0, 0.9, 0.99, 1.0];
phase_deg_list = [0, 5, 30, 150];
beta_list = [1.0, 0.7, 0.3];
az_sep_list = [0.83, 1.27];
el_sep_list = [0.00, 0.37, 0.67];
snr_list = [20, 30];
el_center_offset = 0.31;
center_bias_cases = [ ...
    0.0, 0.0; ...
    0.2, 0.0];
az_search_half_width = 1.5;
el_search_half_width = 1.2;
az_beam_span = 2.2;
el_beam_span = 1.6;
az_grid_step_deg = 0.08;
el_grid_step_deg = 0.12;
az_tol_deg = 0.15;
el_tol_deg = 0.20;
el_sep_tol_deg = 0.25;
reg = 1e-10;
el_sep_index_list = [0, 1, 2];
search_orientations = [1, -1];

log_lines = append_log_local(log_lines, 'cfg.arr: Naz=%d, Nel=%d, fc=%.6g, lambda=%.12g, R=%.6g, dz=%.6g', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.fc, cfg.arr.lambda, cfg.arr.R, cfg.arr.dz);
log_lines = append_log_local(log_lines, 'cfg.beam.subNaz=%d, arrInfo.nAct=%d, expected_N_elem=%d', ...
    cfg.beam.subNaz, arrInfo.nAct, expected_N_elem);
log_lines = append_log_local(log_lines, 'phase_factor=%.6g, phase_sign=%+.0f', phase_factor, phase_sign);
log_lines = append_log_local(log_lines, 'base_seed=%d, L=%d, Metkl=%d', base_seed, L, Metkl);
log_lines = append_log_local(log_lines, 'rho_list=%s, phase_deg_list=%s, beta_list=%s', ...
    mat2str(rho_list), mat2str(phase_deg_list), mat2str(beta_list));
log_lines = append_log_local(log_lines, 'az_sep_list=%s, el_sep_list=%s, snr_list=%s', ...
    mat2str(az_sep_list), mat2str(el_sep_list), mat2str(snr_list));
log_lines = append_log_local(log_lines, 'el_center_offset=%.3f, center_bias_cases=%s', ...
    el_center_offset, mat2str(center_bias_cases));
log_lines = append_log_local(log_lines, 'beam_layouts=%s, model_mode_list=%s, whitening_mode_list=%s', ...
    strjoin({beam_layouts.name}, ','), strjoin(model_mode_list, ','), strjoin(whitening_mode_list, ','));
log_lines = append_log_local(log_lines, ...
    'az_search_half_width=%.3f, el_search_half_width=%.3f, az_beam_span=%.3f, el_beam_span=%.3f', ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span);
log_lines = append_log_local(log_lines, ...
    'az_grid_step_deg=%.3f, el_grid_step_deg=%.3f, el_sep_index_list=%s, search_orientations=%s', ...
    az_grid_step_deg, el_grid_step_deg, mat2str(el_sep_index_list), mat2str(search_orientations));
log_lines = append_log_local(log_lines, 'az_tol_deg=%.3f, el_tol_deg=%.3f, el_sep_tol_deg=%.3f, reg=%.3g', ...
    az_tol_deg, el_tol_deg, el_sep_tol_deg, reg);
log_lines = append_log_local(log_lines, ...
    'should_run_case rules: pair2d+white full grid; common_el_restricted only white full grid; pair2d+none only rho in [0,1] and phase in [0,30].');

cache = build_beam_grid_cache_local(x, y, z, center_bias_cases, beam_layouts, ...
    az_center_true, el_center_nominal, lambda, phase_factor, phase_sign, ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span, ...
    az_grid_step_deg, el_grid_step_deg);
log_lines = append_log_local(log_lines, 'Precomputed %d beam/grid cache entries.', numel(cache));

total_rows = count_trial_rows_local(rho_list, phase_deg_list, beta_list, az_sep_list, el_sep_list, ...
    snr_list, center_bias_cases, beam_layouts, model_mode_list, whitening_mode_list, Metkl);
trial_rows = repmat(make_trial_row_template_local(), total_rows, 1);
row_idx = 0;

tic;
for iRho = 1:numel(rho_list)
    rho = rho_list(iRho);
    for iPhase = 1:numel(phase_deg_list)
        phase_deg = phase_deg_list(iPhase);
        for iBeta = 1:numel(beta_list)
            beta = beta_list(iBeta);
            for iSnr = 1:numel(snr_list)
                snr_db = snr_list(iSnr);

                for iAzSep = 1:numel(az_sep_list)
                    az_sep = az_sep_list(iAzSep);
                    az_true = [az_center_true - az_sep/2, az_center_true + az_sep/2];
                    for iElSep = 1:numel(el_sep_list)
                        el_sep = el_sep_list(iElSep);
                        el_center_true = el_center_nominal + el_center_offset;
                        el_true = [el_center_true - el_sep/2, el_center_true + el_sep/2];

                        for trial_id = 1:Metkl
                            seed_now = base_seed + 1000000*iRho + 100000*iPhase + 10000*iBeta + ...
                                1000*iSnr + 100*iAzSep + 10*iElSep + trial_id;
                            [Y, truth] = make_cyl_pair2d_correlated_snapshots(x, y, z, az_true, el_true, lambda, L, snr_db, ...
                                'PhaseFactor', phase_factor, 'PhaseSign', phase_sign, 'Rho', rho, ...
                                'PhaseDeg', phase_deg, 'AmplitudeRatio', beta, 'Seed', seed_now, ...
                                'NormalizeSourcePower', true);
                            if ~isequal(size(Y), [N_elem, L])
                                error('run_stage5:YShapeMismatch', 'Y must be N_elem x L.');
                            end

                            for iCache = 1:numel(cache)
                                W = cache(iCache).W;
                                grid = cache(iCache).grid;
                                Z = W' * Y;
                                if ~isequal(size(Z), [cache(iCache).beam_count, L])
                                    error('run_stage5:ZShapeMismatch', 'Z must be beam_count x L.');
                                end

                                A_truth = build_cyl_pair_manifold_el_separated(x, y, z, az_true, el_true, lambda, ...
                                    'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
                                G_truth = W' * A_truth;

                                for iWhite = 1:numel(whitening_mode_list)
                                    whitening_mode = whitening_mode_list{iWhite};
                                    pair2d_needed = should_run_case_local('pair2d', whitening_mode, rho, phase_deg);
                                    common_needed = should_run_case_local('common_el_restricted', whitening_mode, rho, phase_deg);
                                    common_for_margin_needed = pair2d_needed && strcmp(whitening_mode, 'white');

                                    search_cfg = struct();
                                    search_cfg.whitening_mode = whitening_mode;
                                    search_cfg.reg = reg;
                                    search_cfg.el_sep_index_list = el_sep_index_list;
                                    search_cfg.search_orientations = search_orientations;
                                    search_cfg.keep_score_cube = false;

                                    est_pair = [];
                                    debug_pair = [];
                                    metrics_pair = [];
                                    if pair2d_needed
                                        [est_pair, ~, debug_pair] = search_pair_grid_el_separation_precomputed(Z, W, grid, search_cfg);
                                        metrics_pair = eval_el_separation_pair_metrics(est_pair, az_true, el_true, ...
                                            cache(iCache).az_bounds, cache(iCache).el_bounds, az_tol_deg, el_tol_deg, el_sep_tol_deg);
                                    end

                                    est_common_pair = [];
                                    debug_common = [];
                                    metrics_common = [];
                                    if common_needed || common_for_margin_needed
                                        [est_common, ~, debug_common] = search_pair_grid_common_el_precomputed(Z, W, grid, search_cfg);
                                        est_common_pair = struct();
                                        est_common_pair.az_hat = est_common.az_hat;
                                        est_common_pair.el_hat = [est_common.el_hat, est_common.el_hat];
                                        metrics_common = eval_el_separation_pair_metrics(est_common_pair, az_true, el_true, ...
                                            cache(iCache).az_bounds, cache(iCache).el_bounds, az_tol_deg, el_tol_deg, el_sep_tol_deg);
                                    end

                                    [~, G_truth_use] = apply_beamspace_whitening(Z, G_truth, W, whitening_mode, 'eps_reg', reg);
                                    g1 = G_truth_use(:, 1);
                                    g2 = G_truth_use(:, 2);
                                    manifold_corr_truth = abs(g1' * g2) / max(norm(g1) * norm(g2), eps);

                                    if pair2d_needed
                                        score_margin = NaN;
                                        common_max_score = NaN;
                                        if ~isempty(debug_common)
                                            score_margin = debug_pair.max_score - debug_common.max_score;
                                            common_max_score = debug_common.max_score;
                                        end
                                        false_high_like = ~metrics_pair.joint_pair_tol_success && ...
                                            isfinite(score_margin) && score_margin > 0 && ~metrics_pair.boundary_hit;
                                        row_idx = row_idx + 1;
                                        trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, 'pair2d', whitening_mode, ...
                                            cache(iCache), rho, phase_deg, beta, truth.source_corr_empirical, az_sep, el_sep, snr_db, ...
                                            est_pair, az_true, el_true, metrics_pair, manifold_corr_truth, debug_pair, ...
                                            score_margin, common_max_score, false_high_like, N_elem, L, phase_factor, phase_sign);
                                    end

                                    if common_needed
                                        row_idx = row_idx + 1;
                                        trial_rows(row_idx) = make_trial_row_local(row_idx, trial_id, 'common_el_restricted', whitening_mode, ...
                                            cache(iCache), rho, phase_deg, beta, truth.source_corr_empirical, az_sep, el_sep, snr_db, ...
                                            est_common_pair, az_true, el_true, metrics_common, manifold_corr_truth, debug_common, ...
                                            NaN, NaN, false, N_elem, L, phase_factor, phase_sign);
                                    end
                                end
                            end
                        end
                    end
                end

                log_lines = append_log_local(log_lines, ...
                    'Completed rho=%.2f, phase=%.1f deg, beta=%.2f, snr=%.1f dB, rows=%d/%d, elapsed %.2f s', ...
                    rho, phase_deg, beta, snr_db, row_idx, total_rows, toc);
            end
        end
    end
end

if row_idx ~= total_rows
    error('run_stage5:RowCountMismatch', 'Expected %d rows, got %d.', total_rows, row_idx);
end

trial_table = struct2table(trial_rows);
if isempty(trial_table)
    error('run_stage5:EmptyTrialTable', 'trial_table is empty.');
end

summary_table = build_summary_table_local(trial_table);
if isempty(summary_table)
    error('run_stage5:EmptySummaryTable', 'summary_table is empty.');
end

[keypoint_rows, keypoints] = summarize_coherence_stress_keypoints(summary_table);
keypoint_table = struct2table(keypoint_rows);
if isempty(keypoint_table)
    error('run_stage5:EmptyKeypointTable', 'keypoint_table is empty.');
end

trial_csv = fullfile(result_dir, 'step11_1_cyl_coherence_stress_trial.csv');
summary_csv = fullfile(result_dir, 'step11_1_cyl_coherence_stress_summary.csv');
keypoints_csv = fullfile(result_dir, 'step11_1_cyl_coherence_stress_keypoints.csv');
mat_path = fullfile(result_dir, 'step11_1_cyl_coherence_stress_result.mat');
log_path = fullfile(result_dir, 'step11_1_cyl_coherence_stress.log');

writetable(trial_table, trial_csv);
writetable(summary_table, summary_csv);
writetable(keypoint_table, keypoints_csv);
plot_paths = make_plots_local(summary_table, result_dir);

params = struct();
params.base_seed = base_seed;
params.L = L;
params.Metkl = Metkl;
params.az_center_true = az_center_true;
params.el_center_nominal = el_center_nominal;
params.el_center_offset = el_center_offset;
params.beam_layouts = beam_layouts;
params.model_mode_list = model_mode_list;
params.whitening_mode_list = whitening_mode_list;
params.rho_list = rho_list;
params.phase_deg_list = phase_deg_list;
params.beta_list = beta_list;
params.az_sep_list = az_sep_list;
params.el_sep_list = el_sep_list;
params.snr_list = snr_list;
params.center_bias_cases = center_bias_cases;
params.az_search_half_width = az_search_half_width;
params.el_search_half_width = el_search_half_width;
params.az_beam_span = az_beam_span;
params.el_beam_span = el_beam_span;
params.az_grid_step_deg = az_grid_step_deg;
params.el_grid_step_deg = el_grid_step_deg;
params.el_sep_index_list = el_sep_index_list;
params.search_orientations = search_orientations;
params.az_tol_deg = az_tol_deg;
params.el_tol_deg = el_tol_deg;
params.el_sep_tol_deg = el_sep_tol_deg;
params.reg = reg;
params.N_elem = N_elem;
params.phase_factor = phase_factor;
params.phase_sign = phase_sign;
params.lambda = lambda;

save(mat_path, 'params', 'trial_table', 'summary_table', 'keypoint_table', 'keypoints', 'plot_paths');

log_lines = append_log_local(log_lines, 'Wrote trial CSV: %s', trial_csv);
log_lines = append_log_local(log_lines, 'Wrote summary CSV: %s', summary_csv);
log_lines = append_log_local(log_lines, 'Wrote keypoints CSV: %s', keypoints_csv);
log_lines = append_log_local(log_lines, 'Wrote result MAT: %s', mat_path);
for iPlot = 1:numel(plot_paths)
    log_lines = append_log_local(log_lines, 'Wrote plot: %s', plot_paths{iPlot});
end
log_lines = append_log_local(log_lines, 'Keypoints:');
metric_names = fieldnames(keypoints);
for iMetric = 1:numel(metric_names)
    name = metric_names{iMetric};
    value = keypoints.(name);
    if isnumeric(value) || islogical(value)
        log_lines = append_log_local(log_lines, '  %s = %.12g', name, double(value));
    else
        log_lines = append_log_local(log_lines, '  %s = %s', name, char(value));
    end
end
log_lines = append_log_local(log_lines, 'coherence_stress_pass_flag=%d', keypoints.coherence_stress_pass_flag);
log_lines = append_log_local(log_lines, 'recommended_next_step=%s', keypoints.recommended_next_step);
write_log_local(log_path, log_lines);
fprintf('Log written: %s\n', log_path);

function cache = build_beam_grid_cache_local(x, y, z, center_bias_cases, beam_layouts, ...
    az_center_true, el_center_nominal, lambda, phase_factor, phase_sign, ...
    az_search_half_width, el_search_half_width, az_beam_span, el_beam_span, ...
    az_grid_step_deg, el_grid_step_deg)
template = struct();
template.az_center_bias_deg = NaN;
template.el_center_bias_deg = NaN;
template.az_beam_c = NaN;
template.el_beam_c = NaN;
template.az_bounds = [NaN, NaN];
template.el_bounds = [NaN, NaN];
template.beam_layout_name = '';
template.beam_az_count = NaN;
template.beam_el_count = NaN;
template.beam_count = NaN;
template.W = [];
template.beam_info = struct();
template.grid = struct();

cache = repmat(template, size(center_bias_cases, 1) * numel(beam_layouts), 1);
idx = 0;
for iBias = 1:size(center_bias_cases, 1)
    az_center_bias = center_bias_cases(iBias, 1);
    el_center_bias = center_bias_cases(iBias, 2);
    az_beam_c = az_center_true + az_center_bias;
    el_beam_c = el_center_nominal + el_center_bias;
    az_bounds = [az_beam_c - az_search_half_width, az_beam_c + az_search_half_width];
    el_bounds = [el_beam_c - el_search_half_width, el_beam_c + el_search_half_width];
    az_grid = az_bounds(1):az_grid_step_deg:az_bounds(2);
    el_grid = el_bounds(1):el_grid_step_deg:el_bounds(2);

    for iLayout = 1:numel(beam_layouts)
        layout = beam_layouts(iLayout);
        beam_az = linspace(az_beam_c - az_beam_span, az_beam_c + az_beam_span, layout.az_count);
        beam_el = linspace(el_beam_c - el_beam_span, el_beam_c + el_beam_span, layout.el_count);
        [W, beam_info] = build_cyl_azel_beam_transform(x, y, z, beam_az, beam_el, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);
        grid = precompute_beamspace_azel_grid(W, x, y, z, az_grid, el_grid, lambda, ...
            'PhaseFactor', phase_factor, 'PhaseSign', phase_sign);

        idx = idx + 1;
        cache(idx).az_center_bias_deg = az_center_bias;
        cache(idx).el_center_bias_deg = el_center_bias;
        cache(idx).az_beam_c = az_beam_c;
        cache(idx).el_beam_c = el_beam_c;
        cache(idx).az_bounds = az_bounds;
        cache(idx).el_bounds = el_bounds;
        cache(idx).beam_layout_name = layout.name;
        cache(idx).beam_az_count = layout.az_count;
        cache(idx).beam_el_count = layout.el_count;
        cache(idx).beam_count = layout.az_count * layout.el_count;
        cache(idx).W = W;
        cache(idx).beam_info = beam_info;
        cache(idx).grid = grid;
    end
end
end

function total_rows = count_trial_rows_local(rho_list, phase_deg_list, beta_list, az_sep_list, el_sep_list, ...
    snr_list, center_bias_cases, beam_layouts, model_mode_list, whitening_mode_list, Metkl)
total_rows = 0;
for iRho = 1:numel(rho_list)
    rho = rho_list(iRho);
    for iPhase = 1:numel(phase_deg_list)
        phase_deg = phase_deg_list(iPhase);
        for iBeta = 1:numel(beta_list)
            for iAzSep = 1:numel(az_sep_list)
                for iElSep = 1:numel(el_sep_list)
                    for iSnr = 1:numel(snr_list)
                        for iBias = 1:size(center_bias_cases, 1) %#ok<NASGU>
                            for iLayout = 1:numel(beam_layouts) %#ok<NASGU>
                                for iModel = 1:numel(model_mode_list)
                                    for iWhite = 1:numel(whitening_mode_list)
                                        if should_run_case_local(model_mode_list{iModel}, whitening_mode_list{iWhite}, rho, phase_deg)
                                            total_rows = total_rows + Metkl;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
end

function tf = should_run_case_local(model_mode, whitening_mode, rho, phase_deg)
model_mode = lower(char(model_mode));
whitening_mode = lower(char(whitening_mode));
switch model_mode
    case 'pair2d'
        if strcmp(whitening_mode, 'white')
            tf = true;
        elseif strcmp(whitening_mode, 'none')
            tf = (abs(rho - 0) < 1e-12 || abs(rho - 1.0) < 1e-12) && ...
                (abs(phase_deg - 0) < 1e-12 || abs(phase_deg - 30) < 1e-12);
        else
            tf = false;
        end
    case 'common_el_restricted'
        tf = strcmp(whitening_mode, 'white');
    otherwise
        tf = false;
end
end

function row = make_trial_row_template_local()
row = struct();
fields = {'trial_global_id','trial_id','model_mode','whitening_mode','beam_layout_name','beam_az_count', ...
    'beam_el_count','beam_count','rho','phase_deg','beta','source_corr_empirical','az_center_bias_deg', ...
    'el_center_bias_deg','az_sep_deg','el_sep_deg','snr_db','az_hat_1','az_hat_2','el_hat_1','el_hat_2', ...
    'az_true_1','az_true_2','el_true_1','el_true_2','raw_success','az_tol_success','el_pair_tol_success', ...
    'joint_pair_tol_success','az_rmse_deg','el_rmse_deg','az_center_error_deg','az_sep_error_deg', ...
    'el_center_error_deg','el_sep_error_deg','abs_el_sep_error_deg','estimated_el_sep_deg','true_el_sep_deg', ...
    'false_el_split','boundary_hit','manifold_corr_truth','cond_WHW','cond_best_GHG','max_score','num_pairs', ...
    'tie_count','score_margin_pair_minus_common','common_max_score_for_margin','false_high_like','N_elem','L', ...
    'phase_factor','phase_sign'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.model_mode = '';
row.whitening_mode = '';
row.beam_layout_name = '';
bool_fields = {'raw_success','az_tol_success','el_pair_tol_success','joint_pair_tol_success', ...
    'false_el_split','boundary_hit','false_high_like'};
for idx = 1:numel(bool_fields)
    row.(bool_fields{idx}) = false;
end
end

function row = make_trial_row_local(trial_global_id, trial_id, model_mode, whitening_mode, cache_entry, ...
    rho, phase_deg, beta, source_corr_empirical, az_sep, el_sep, snr_db, est, az_true, el_true, metrics, ...
    manifold_corr_truth, debug, score_margin, common_max_score, false_high_like, N_elem, L, phase_factor, phase_sign)
row = make_trial_row_template_local();
row.trial_global_id = trial_global_id;
row.trial_id = trial_id;
row.model_mode = model_mode;
row.whitening_mode = whitening_mode;
row.beam_layout_name = cache_entry.beam_layout_name;
row.beam_az_count = cache_entry.beam_az_count;
row.beam_el_count = cache_entry.beam_el_count;
row.beam_count = cache_entry.beam_count;
row.rho = rho;
row.phase_deg = phase_deg;
row.beta = beta;
row.source_corr_empirical = source_corr_empirical;
row.az_center_bias_deg = cache_entry.az_center_bias_deg;
row.el_center_bias_deg = cache_entry.el_center_bias_deg;
row.az_sep_deg = az_sep;
row.el_sep_deg = el_sep;
row.snr_db = snr_db;
row.az_hat_1 = est.az_hat(1);
row.az_hat_2 = est.az_hat(2);
row.el_hat_1 = est.el_hat(1);
row.el_hat_2 = est.el_hat(2);
row.az_true_1 = az_true(1);
row.az_true_2 = az_true(2);
row.el_true_1 = el_true(1);
row.el_true_2 = el_true(2);
row.raw_success = metrics.raw_success;
row.az_tol_success = metrics.az_tol_success;
row.el_pair_tol_success = metrics.el_pair_tol_success;
row.joint_pair_tol_success = metrics.joint_pair_tol_success;
row.az_rmse_deg = metrics.az_rmse_deg;
row.el_rmse_deg = metrics.el_rmse_deg;
row.az_center_error_deg = metrics.az_center_error_deg;
row.az_sep_error_deg = metrics.az_sep_error_deg;
row.el_center_error_deg = metrics.el_center_error_deg;
row.el_sep_error_deg = metrics.el_sep_error_deg;
row.abs_el_sep_error_deg = metrics.abs_el_sep_error_deg;
row.estimated_el_sep_deg = metrics.estimated_el_sep_deg;
row.true_el_sep_deg = metrics.true_el_sep_deg;
row.false_el_split = metrics.false_el_split;
row.boundary_hit = metrics.boundary_hit;
row.manifold_corr_truth = manifold_corr_truth;
row.cond_WHW = debug.cond_WHW;
row.cond_best_GHG = debug.cond_best_GHG;
row.max_score = debug.max_score;
row.num_pairs = debug.num_pairs;
row.tie_count = debug.tie_count;
row.score_margin_pair_minus_common = score_margin;
row.common_max_score_for_margin = common_max_score;
row.false_high_like = false_high_like;
row.N_elem = N_elem;
row.L = L;
row.phase_factor = phase_factor;
row.phase_sign = phase_sign;
end

function summary_table = build_summary_table_local(trial_table)
group_fields = {'model_mode','whitening_mode','beam_layout_name','beam_count','rho','phase_deg','beta', ...
    'az_center_bias_deg','el_center_bias_deg','az_sep_deg','el_sep_deg','snr_db'};
groups = unique(trial_table(:, group_fields), 'rows');
rows = repmat(make_summary_row_template_local(), height(groups), 1);
for iGroup = 1:height(groups)
    mask = true(height(trial_table), 1);
    for iField = 1:numel(group_fields)
        field = group_fields{iField};
        mask = mask & match_value_local(trial_table.(field), groups.(field)(iGroup));
    end
    sub = trial_table(mask, :);
    rows(iGroup).model_mode = char_value_local(groups.model_mode(iGroup));
    rows(iGroup).whitening_mode = char_value_local(groups.whitening_mode(iGroup));
    rows(iGroup).beam_layout_name = char_value_local(groups.beam_layout_name(iGroup));
    rows(iGroup).beam_count = groups.beam_count(iGroup);
    rows(iGroup).rho = groups.rho(iGroup);
    rows(iGroup).phase_deg = groups.phase_deg(iGroup);
    rows(iGroup).beta = groups.beta(iGroup);
    rows(iGroup).az_center_bias_deg = groups.az_center_bias_deg(iGroup);
    rows(iGroup).el_center_bias_deg = groups.el_center_bias_deg(iGroup);
    rows(iGroup).az_sep_deg = groups.az_sep_deg(iGroup);
    rows(iGroup).el_sep_deg = groups.el_sep_deg(iGroup);
    rows(iGroup).snr_db = groups.snr_db(iGroup);
    rows(iGroup).raw_success_rate = mean(double(sub.raw_success));
    rows(iGroup).az_tol_success_rate = mean(double(sub.az_tol_success));
    rows(iGroup).el_pair_tol_success_rate = mean(double(sub.el_pair_tol_success));
    rows(iGroup).joint_pair_tol_success_rate = mean(double(sub.joint_pair_tol_success));
    rows(iGroup).mean_az_rmse_deg = mean_omitnan_local(sub.az_rmse_deg);
    rows(iGroup).mean_el_rmse_deg = mean_omitnan_local(sub.el_rmse_deg);
    rows(iGroup).mean_abs_el_sep_error_deg = mean_omitnan_local(sub.abs_el_sep_error_deg);
    rows(iGroup).false_el_split_rate = mean(double(sub.false_el_split));
    rows(iGroup).boundary_hit_rate = mean(double(sub.boundary_hit));
    rows(iGroup).mean_source_corr_empirical = mean_omitnan_local(sub.source_corr_empirical);
    rows(iGroup).mean_manifold_corr_truth = mean_omitnan_local(sub.manifold_corr_truth);
    rows(iGroup).mean_cond_WHW = mean_omitnan_local(sub.cond_WHW);
    rows(iGroup).mean_cond_best_GHG = mean_omitnan_local(sub.cond_best_GHG);
    rows(iGroup).mean_max_score = mean_omitnan_local(sub.max_score);
    rows(iGroup).mean_num_pairs = mean_omitnan_local(sub.num_pairs);
    rows(iGroup).mean_tie_count = mean_omitnan_local(sub.tie_count);
    rows(iGroup).mean_score_margin_pair_minus_common = mean_omitnan_local(sub.score_margin_pair_minus_common);
    rows(iGroup).false_high_like_rate = mean(double(sub.false_high_like));
end

summary_table = struct2table(rows);
summary_table = add_pair2d_common_gap_local(summary_table);
summary_table = add_whitening_gain_local(summary_table);
summary_table = add_aggregate_success_local(summary_table);
end

function row = make_summary_row_template_local()
row = struct();
fields = {'model_mode','whitening_mode','beam_layout_name','beam_count','rho','phase_deg','beta', ...
    'az_center_bias_deg','el_center_bias_deg','az_sep_deg','el_sep_deg','snr_db','raw_success_rate', ...
    'az_tol_success_rate','el_pair_tol_success_rate','joint_pair_tol_success_rate','mean_az_rmse_deg', ...
    'mean_el_rmse_deg','mean_abs_el_sep_error_deg','false_el_split_rate','boundary_hit_rate', ...
    'mean_source_corr_empirical','mean_manifold_corr_truth','mean_cond_WHW','mean_cond_best_GHG', ...
    'mean_max_score','mean_num_pairs','mean_tie_count','mean_score_margin_pair_minus_common', ...
    'false_high_like_rate','pair2d_minus_common_joint_success_gap','whitening_gain_pair2d', ...
    'rho_aggregate_joint_success_rate','phase_aggregate_joint_success_rate','beta_aggregate_joint_success_rate'};
for idx = 1:numel(fields)
    row.(fields{idx}) = NaN;
end
row.model_mode = '';
row.whitening_mode = '';
row.beam_layout_name = '';
end

function summary_table = add_pair2d_common_gap_local(summary_table)
summary_table.pair2d_minus_common_joint_success_gap(:) = NaN;
for idx = 1:height(summary_table)
    if ~strcmp(char_value_local(summary_table.model_mode(idx)), 'pair2d') || ...
            ~strcmp(char_value_local(summary_table.whitening_mode(idx)), 'white')
        continue;
    end
    mask = same_base_summary_mask_local(summary_table, idx) & ...
        string_match_local(summary_table.model_mode, 'common_el_restricted') & ...
        string_match_local(summary_table.whitening_mode, 'white');
    if any(mask)
        summary_table.pair2d_minus_common_joint_success_gap(idx) = ...
            summary_table.joint_pair_tol_success_rate(idx) - mean_omitnan_local(summary_table.joint_pair_tol_success_rate(mask));
    end
end
end

function summary_table = add_whitening_gain_local(summary_table)
summary_table.whitening_gain_pair2d(:) = NaN;
for idx = 1:height(summary_table)
    if ~strcmp(char_value_local(summary_table.model_mode(idx)), 'pair2d')
        continue;
    end
    if strcmp(char_value_local(summary_table.whitening_mode(idx)), 'white')
        other_white = 'none';
        sign_now = 1;
    elseif strcmp(char_value_local(summary_table.whitening_mode(idx)), 'none')
        other_white = 'white';
        sign_now = -1;
    else
        continue;
    end
    mask = same_base_summary_mask_local(summary_table, idx) & ...
        string_match_local(summary_table.model_mode, 'pair2d') & ...
        string_match_local(summary_table.whitening_mode, other_white);
    if any(mask)
        summary_table.whitening_gain_pair2d(idx) = sign_now * ...
            (summary_table.joint_pair_tol_success_rate(idx) - mean_omitnan_local(summary_table.joint_pair_tol_success_rate(mask)));
    end
end
end

function summary_table = add_aggregate_success_local(summary_table)
summary_table.rho_aggregate_joint_success_rate(:) = NaN;
summary_table.phase_aggregate_joint_success_rate(:) = NaN;
summary_table.beta_aggregate_joint_success_rate(:) = NaN;
for idx = 1:height(summary_table)
    base_mask = string_match_local(summary_table.model_mode, char_value_local(summary_table.model_mode(idx))) & ...
        string_match_local(summary_table.whitening_mode, char_value_local(summary_table.whitening_mode(idx))) & ...
        abs(summary_table.az_center_bias_deg - summary_table.az_center_bias_deg(idx)) < 1e-12 & ...
        abs(summary_table.el_center_bias_deg - summary_table.el_center_bias_deg(idx)) < 1e-12 & ...
        abs(summary_table.snr_db - summary_table.snr_db(idx)) < 1e-12;
    rho_mask = base_mask & abs(summary_table.rho - summary_table.rho(idx)) < 1e-12;
    phase_mask = base_mask & abs(summary_table.phase_deg - summary_table.phase_deg(idx)) < 1e-12;
    beta_mask = base_mask & abs(summary_table.beta - summary_table.beta(idx)) < 1e-12;
    summary_table.rho_aggregate_joint_success_rate(idx) = mean_omitnan_local(summary_table.joint_pair_tol_success_rate(rho_mask));
    summary_table.phase_aggregate_joint_success_rate(idx) = mean_omitnan_local(summary_table.joint_pair_tol_success_rate(phase_mask));
    summary_table.beta_aggregate_joint_success_rate(idx) = mean_omitnan_local(summary_table.joint_pair_tol_success_rate(beta_mask));
end
end

function mask = same_base_summary_mask_local(summary_table, idx)
mask = string_match_local(summary_table.beam_layout_name, char_value_local(summary_table.beam_layout_name(idx))) & ...
    abs(summary_table.beam_count - summary_table.beam_count(idx)) < 1e-12 & ...
    abs(summary_table.rho - summary_table.rho(idx)) < 1e-12 & ...
    abs(summary_table.phase_deg - summary_table.phase_deg(idx)) < 1e-12 & ...
    abs(summary_table.beta - summary_table.beta(idx)) < 1e-12 & ...
    abs(summary_table.az_center_bias_deg - summary_table.az_center_bias_deg(idx)) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg - summary_table.el_center_bias_deg(idx)) < 1e-12 & ...
    abs(summary_table.az_sep_deg - summary_table.az_sep_deg(idx)) < 1e-12 & ...
    abs(summary_table.el_sep_deg - summary_table.el_sep_deg(idx)) < 1e-12 & ...
    abs(summary_table.snr_db - summary_table.snr_db(idx)) < 1e-12;
end

function plot_paths = make_plots_local(summary_table, result_dir)
plot_paths = {};
plot_paths{end + 1} = plot_success_vs_rho_local(summary_table, result_dir);
plot_paths{end + 1} = plot_success_heatmap_phase_rho_local(summary_table, result_dir);
plot_paths{end + 1} = plot_beta_sensitivity_local(summary_table, result_dir);
plot_paths{end + 1} = plot_pair2d_common_gap_local(summary_table, result_dir);
plot_paths{end + 1} = plot_boundary_hit_rate_local(summary_table, result_dir);
plot_paths{end + 1} = plot_false_split_true_sep0_local(summary_table, result_dir);
plot_paths{end + 1} = plot_whitening_gain_local(summary_table, result_dir);
plot_paths{end + 1} = plot_manifold_corr_local(summary_table, result_dir);
end

function sub = select_main_plot_subset_local(summary_table)
sub = summary_table(string_match_local(summary_table.model_mode, 'pair2d') & ...
    string_match_local(summary_table.whitening_mode, 'white') & ...
    abs(summary_table.az_center_bias_deg) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg) < 1e-12 & ...
    abs(summary_table.snr_db - 30) < 1e-12, :);
end

function out_path = plot_success_vs_rho_local(summary_table, result_dir)
sub = select_main_plot_subset_local(summary_table);
rho_vals = unique(sub.rho);
layouts = unique(cellstr_local(sub.beam_layout_name), 'stable');
fig = figure('Visible', 'off');
hold on;
for iLayout = 1:numel(layouts)
    vals = nan(size(rho_vals));
    for iRho = 1:numel(rho_vals)
        mask = string_match_local(sub.beam_layout_name, layouts{iLayout}) & abs(sub.rho - rho_vals(iRho)) < 1e-12;
        vals(iRho) = mean_omitnan_local(sub.joint_pair_tol_success_rate(mask));
    end
    plot(rho_vals, vals, '-o', 'LineWidth', 1.5);
end
hold off;
grid on;
xlabel('rho');
ylabel('pair2d white joint success');
title('Coherence stress success vs rho');
legend(layouts, 'Location', 'best');
out_path = fullfile(result_dir, 'cyl_coherence_success_vs_rho.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_success_heatmap_phase_rho_local(summary_table, result_dir)
sub = select_main_plot_subset_local(summary_table);
rho_vals = unique(sub.rho);
phase_vals = unique(sub.phase_deg);
Zplot = nan(numel(phase_vals), numel(rho_vals));
for iPhase = 1:numel(phase_vals)
    for iRho = 1:numel(rho_vals)
        mask = abs(sub.phase_deg - phase_vals(iPhase)) < 1e-12 & abs(sub.rho - rho_vals(iRho)) < 1e-12;
        Zplot(iPhase, iRho) = mean_omitnan_local(sub.joint_pair_tol_success_rate(mask));
    end
end
fig = figure('Visible', 'off');
imagesc(rho_vals, phase_vals, Zplot);
set(gca, 'YDir', 'normal');
colorbar;
caxis([0, 1]);
xlabel('rho');
ylabel('phase (deg)');
title('Pair2d white success heatmap');
out_path = fullfile(result_dir, 'cyl_coherence_success_heatmap_phase_rho.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_beta_sensitivity_local(summary_table, result_dir)
sub = select_main_plot_subset_local(summary_table);
beta_vals = unique(sub.beta);
vals = nan(size(beta_vals));
for iBeta = 1:numel(beta_vals)
    vals(iBeta) = mean_omitnan_local(sub.joint_pair_tol_success_rate(abs(sub.beta - beta_vals(iBeta)) < 1e-12));
end
fig = figure('Visible', 'off');
bar(beta_vals, vals);
grid on;
xlabel('beta');
ylabel('pair2d white joint success');
title('Weak target beta sensitivity');
out_path = fullfile(result_dir, 'cyl_coherence_beta_sensitivity.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_pair2d_common_gap_local(summary_table, result_dir)
sub = select_main_plot_subset_local(summary_table);
rho_vals = unique(sub.rho);
vals = nan(size(rho_vals));
for iRho = 1:numel(rho_vals)
    vals(iRho) = mean_omitnan_local(sub.pair2d_minus_common_joint_success_gap(abs(sub.rho - rho_vals(iRho)) < 1e-12));
end
fig = figure('Visible', 'off');
bar(rho_vals, vals);
grid on;
xlabel('rho');
ylabel('pair2d - common joint success');
title('Pair2d vs common-el success gap');
out_path = fullfile(result_dir, 'cyl_coherence_pair2d_vs_common_gap.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_boundary_hit_rate_local(summary_table, result_dir)
sub = select_main_plot_subset_local(summary_table);
rho_vals = unique(sub.rho);
vals = nan(size(rho_vals));
for iRho = 1:numel(rho_vals)
    vals(iRho) = max_omitnan_local(sub.boundary_hit_rate(abs(sub.rho - rho_vals(iRho)) < 1e-12));
end
fig = figure('Visible', 'off');
bar(rho_vals, vals);
grid on;
xlabel('rho');
ylabel('max boundary hit rate');
title('Boundary hit risk vs rho');
out_path = fullfile(result_dir, 'cyl_coherence_boundary_hit_rate.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_false_split_true_sep0_local(summary_table, result_dir)
sub = select_main_plot_subset_local(summary_table);
sub = sub(abs(sub.el_sep_deg) < 1e-12, :);
rho_vals = unique(sub.rho);
vals = nan(size(rho_vals));
for iRho = 1:numel(rho_vals)
    vals(iRho) = max_omitnan_local(sub.false_el_split_rate(abs(sub.rho - rho_vals(iRho)) < 1e-12));
end
fig = figure('Visible', 'off');
bar(rho_vals, vals);
grid on;
xlabel('rho');
ylabel('max false split rate');
title('False elevation split when true sep=0');
out_path = fullfile(result_dir, 'cyl_coherence_false_split_true_sep0.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_whitening_gain_local(summary_table, result_dir)
sub = summary_table(string_match_local(summary_table.model_mode, 'pair2d') & ...
    string_match_local(summary_table.whitening_mode, 'white') & ...
    abs(summary_table.az_center_bias_deg) < 1e-12 & ...
    abs(summary_table.el_center_bias_deg) < 1e-12 & ...
    abs(summary_table.snr_db - 30) < 1e-12, :);
rho_vals = unique(sub.rho);
vals = nan(size(rho_vals));
for iRho = 1:numel(rho_vals)
    vals(iRho) = mean_omitnan_local(sub.whitening_gain_pair2d(abs(sub.rho - rho_vals(iRho)) < 1e-12));
end
fig = figure('Visible', 'off');
bar(rho_vals, vals);
grid on;
xlabel('rho');
ylabel('white - none joint success');
title('Pair2d whitening gain');
out_path = fullfile(result_dir, 'cyl_coherence_whitening_gain.png');
saveas(fig, out_path);
close(fig);
end

function out_path = plot_manifold_corr_local(summary_table, result_dir)
sub = select_main_plot_subset_local(summary_table);
rho_vals = unique(sub.rho);
vals = nan(size(rho_vals));
for iRho = 1:numel(rho_vals)
    vals(iRho) = mean_omitnan_local(sub.mean_manifold_corr_truth(abs(sub.rho - rho_vals(iRho)) < 1e-12));
end
fig = figure('Visible', 'off');
bar(rho_vals, vals);
grid on;
xlabel('rho');
ylabel('mean truth manifold corr');
title('Beamspace truth manifold correlation');
out_path = fullfile(result_dir, 'cyl_coherence_manifold_corr.png');
saveas(fig, out_path);
close(fig);
end

function mask = match_value_local(values, target)
if iscell(values) || ischar(target) || isstring(target)
    mask = string_match_local(values, char_value_local(target));
else
    mask = abs(values - target) < 1e-12;
end
end

function mask = string_match_local(values, target)
if iscell(values)
    mask = strcmp(values, target);
elseif isstring(values)
    mask = strcmp(values, string(target));
else
    mask = strcmp(cellstr(values), target);
end
end

function out = cellstr_local(values)
if iscell(values)
    out = values;
elseif isstring(values)
    out = cellstr(values);
else
    out = cellstr(values);
end
end

function value = char_value_local(value_in)
if iscell(value_in)
    value = value_in{1};
elseif isstring(value_in)
    value = char(value_in);
else
    value = char(value_in);
end
end

function v = mean_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = mean(x);
end
end

function v = max_omitnan_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = max(x);
end
end

function write_log_local(log_path, log_lines)
fid = fopen(log_path, 'w');
if fid < 0
    error('run_stage5:LogOpenFailed', 'Could not open log file: %s', log_path);
end
cleanup = onCleanup(@() fclose(fid));
for iLine = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{iLine});
end
clear cleanup;
end
