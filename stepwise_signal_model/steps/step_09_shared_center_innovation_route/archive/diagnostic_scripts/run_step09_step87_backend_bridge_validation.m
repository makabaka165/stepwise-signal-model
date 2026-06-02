% Step09 -> Step87 backend bridge validation.
% Purpose: verify whether the verified Step 8.7 cascade backend can run under
% the Step 09 input/output contract.
% Run mode: quick bridge validation only.
% Output directory: results_step09_step87_backend_bridge/.
% Main algorithm change: none; this is a backend diagnostic.

clc
clear

archive_script_dir = fileparts(mfilename('fullpath'));
if isempty(archive_script_dir)
    archive_script_dir = pwd;
end
script_dir = fullfile(archive_script_dir, '..', '..');
addpath(fullfile(script_dir, 'main'));
addpath(fullfile(script_dir, 'archive', 'backend_attempts'));

result_dir = fullfile(script_dir, 'archive', 'diagnostic_results', 'results_step09_step87_backend_bridge');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

array_geom = make_array_geom_local();
scenarios = build_bridge_scenarios_local();
base_cfg = make_base_cfg_local();
rows = cell(numel(scenarios) * 10, 1);
irow = 0;
rng_seed_base = 903701;
step87_backend_callable = 1;

for isc = 1:numel(scenarios)
    sc = scenarios(isc);
    for imc = 1:10
        trial_index = irow + 1;
        rng_seed = rng_seed_base + trial_index;
        [raw_cube, frontend_out, truth, cfg] = synthesize_bridge_trial_local(array_geom, sc, base_cfg, rng_seed);
        cfg.backend_mode = 'step09_light';
        t0 = tic;
        out_light = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
        runtime_light_sec = toc(t0);

        cfg.backend_mode = 'step87_reference';
        t0 = tic;
        out_ref = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg);
        runtime_ref_sec = toc(t0);

        if strcmp(string(getfield_default_local(out_ref, 'status', '')), "blocked") || ...
                strcmp(string(getfield_default_local(out_ref, 'route_name', '')), "step87_reference_not_functionalized")
            step87_backend_callable = 0;
        end

        eval_light = evaluate_bridge_output_local(out_light, truth, sc);
        eval_ref = evaluate_bridge_output_local(out_ref, truth, sc);
        irow = irow + 1;
        rows{irow} = make_bridge_trial_row_local(trial_index, sc, truth, ...
            out_light, out_ref, eval_light, eval_ref, runtime_light_sec, runtime_ref_sec);
    end
end

trial_tbl = struct2table([rows{1:irow}]);
summary_tbl = summarize_bridge_trials_local(trial_tbl);
keypoints_tbl = bridge_keypoints_local(trial_tbl, summary_tbl, step87_backend_callable);

writetable(trial_tbl, fullfile(result_dir, 'step09_step87_backend_bridge_trials.csv'));
writetable(summary_tbl, fullfile(result_dir, 'step09_step87_backend_bridge_summary.csv'));
writetable(keypoints_tbl, fullfile(result_dir, 'step09_step87_backend_bridge_keypoints.csv'));
write_bridge_report_local(fullfile(result_dir, 'step09_step87_backend_bridge_report.md'), ...
    summary_tbl, keypoints_tbl);

disp(keypoints_tbl);

function scenarios = build_bridge_scenarios_local()
    template = make_bridge_scenario_local('template', NaN, 0, [], [], NaN, NaN, NaN, 'template', false, false, false);
    scenarios = repmat(template, 0, 1);
    scenarios(end+1) = make_bridge_scenario_local('single_target_sanity', 8, 1, 0, 0, 1, 1, 0, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
    scenarios(end+1) = make_bridge_scenario_local('close_coherent_pair', 8, 2, [-0.3, 0.3], [0, 0], 1, 1, 0, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
    scenarios(end+1) = make_bridge_scenario_local('medium_beta_pair', 8, 2, [-0.25, 0.25], [0, 0], 0.5, 1, 0, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
    scenarios(end+1) = make_bridge_scenario_local('weak_target_boundary', 8, 2, [-0.25, 0.25], [0, 0], 0.1, 1, 0, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
    scenarios(end+1) = make_bridge_scenario_local('near_antiphase_boundary', 8, 2, [-0.25, 0.25], [0, 0], 1, 1, 180, 'single_peak_in_scope', true, false, true); %#ok<AGROW>
    scenarios(end+1) = make_bridge_scenario_local('large_el_pair', 8, 2, [-0.28, 0.28], [0, 5], 0.9, 0.5, 0, 'single_peak_in_scope', true, true, false); %#ok<AGROW>
    scenarios(end+1) = make_bridge_scenario_local('two_separated_coarse_peaks', 8, 2, [-2, 2], [0, 0], 1, 0, 0, 'two_separated_peaks_out_of_scope', false, false, false); %#ok<AGROW>
    scenarios(end+1) = make_bridge_scenario_local('center_wraparound_case', 8, 2, wrap180_local([359.8, 0.2]), [0, 0], 1, 1, 0, 'single_peak_in_scope', true, false, false); %#ok<AGROW>
end

function sc = make_bridge_scenario_local(name, snr_db, target_count, az, el, beta, rho, phase_deg, frontend_state, unresolved, need2d, boundary)
    sc = struct('scenario_name', char(name), 'SNR_dB', snr_db, 'target_count', target_count, ...
        'az', az, 'el', el, 'beta', beta, 'rho', rho, 'phase_deg', phase_deg, ...
        'frontend_state', char(frontend_state), 'unresolved_cluster_flag', unresolved, ...
        'need_2d_refinement', need2d, 'boundary_unreliable_flag', boundary, ...
        'coarseAz', mean(az), 'coarseEl', mean(el));
end

function cfg = make_base_cfg_local()
    cfg = struct();
    cfg.lambda = 1;
    cfg.Naz = 192;
    cfg.Nel = 32;
    cfg.radius = 14;
    cfg.dz = 0.45;
    cfg.Np = 32;
    cfg.Q_work_columns = 65;
    cfg.derotation_mode = 'none';
    cfg.min_pair_sep_deg = 0.12;
    cfg.max_pair_sep_deg = 1.2;
    cfg.music_peak2_ratio_min = 0.32;
    cfg.music_2d_peak2_ratio_min = 0.18;
    cfg.coherent_min_projection_score = 0.45;
    cfg.coherent_min_score_margin = 0;
    cfg.coherent_music_peak2_ratio_min = 0.08;
    cfg.rank1_lambda2_over_lambda1_max = 0.35;
end

function array_geom = make_array_geom_local()
    cfg = make_base_cfg_local();
    phiCol = (0:cfg.Naz - 1) / cfg.Naz * 360;
    zRow = (0:cfg.Nel - 1) * cfg.dz;
    X = zeros(cfg.Naz, cfg.Nel);
    Y = zeros(cfg.Naz, cfg.Nel);
    Z = zeros(cfg.Naz, cfg.Nel);
    for k = 1:cfg.Naz
        X(k, :) = cfg.radius * cosd(phiCol(k));
        Y(k, :) = cfg.radius * sind(phiCol(k));
        Z(k, :) = zRow;
    end
    array_geom = struct('phiCol', phiCol, 'X', X, 'Y', Y, 'Z', Z, ...
        'lambda', cfg.lambda, 'Naz', cfg.Naz, 'Nel', cfg.Nel);
end

function [raw_cube, frontend_out, truth, cfg] = synthesize_bridge_trial_local(array_geom, sc, base_cfg, rng_seed)
    rng(rng_seed, 'twister');
    cfg = base_cfg;
    cfg.backend_mode = 'step09_light';
    raw_cube_clean = zeros(array_geom.Naz, array_geom.Nel, sc.target_count * 0 + cfg.Np);
    p = 0:cfg.Np-1;
    s1 = exp(1j * 2 * pi * 0.07 * p);
    signals = zeros(max(1, sc.target_count), cfg.Np);
    signals(1, :) = s1;
    if sc.target_count >= 2
        phase = exp(1j * deg2rad(sc.phase_deg));
        if sc.rho >= 1
            s2 = sc.beta * phase * s1;
        else
            v = exp(1j * (2 * pi * 0.19 * p + 2 * pi * rand()));
            s2 = sc.beta * phase * (sc.rho * s1 + sqrt(max(0, 1 - sc.rho^2)) * v);
        end
        signals(2, :) = s2;
    end
    for it = 1:sc.target_count
        a = steering_full_local(array_geom, sc.az(it), sc.el(it));
        for ip = 1:cfg.Np
            raw_cube_clean(:, :, ip) = raw_cube_clean(:, :, ip) + a * signals(it, ip);
        end
    end
    clean_power = mean(abs(raw_cube_clean(:)).^2);
    noise_power = clean_power / max(10^(sc.SNR_dB / 10), eps);
    noise = sqrt(noise_power / 2) * (randn(size(raw_cube_clean)) + 1j * randn(size(raw_cube_clean)));
    raw_cube = raw_cube_clean + noise;
    frontend_out = struct('rangeIdx', 1, 'dopplerIdx', 1, 'coarseAz', sc.coarseAz, 'coarseEl', sc.coarseEl, ...
        'frontend_state', sc.frontend_state, 'unresolved_cluster_flag', sc.unresolved_cluster_flag, ...
        'need_2d_refinement', sc.need_2d_refinement, 'boundary_unreliable_flag', sc.boundary_unreliable_flag);
    truth = struct('target_count', sc.target_count, 'az', sc.az, 'el', sc.el, 'SNR_dB', sc.SNR_dB, ...
        'rng_seed', rng_seed, 'noise_power', noise_power, 'clean_power', clean_power);
end

function a = steering_full_local(array_geom, az_deg, el_deg)
    kx = cosd(el_deg) * cosd(az_deg);
    ky = cosd(el_deg) * sind(az_deg);
    kz = sind(el_deg);
    phase = 2 * pi / array_geom.lambda * (array_geom.X * kx + array_geom.Y * ky + array_geom.Z * kz);
    a = exp(1j * phase);
end

function eval_info = evaluate_bridge_output_local(out, truth, sc)
    eval_info = struct();
    eval_info.success = false;
    eval_info.false_high = false;
    eval_info.boundary_missed = false;
    eval_info.low_confidence = strcmp(string(getfield_default_local(out, 'confidence', 'low')), 'low');
    eval_info.out_of_scope = any(strcmp(string(getfield_default_local(out, 'route_name', '')), ...
        ["frontend_reject", "boundary_unreliable"]));
    eval_info.az_error_mean = NaN;
    eval_info.el_error_mean = NaN;
    eval_info.az_error_max = NaN;
    eval_info.el_error_max = NaN;
    az_est = getfield_default_local(out, 'az_est', []);
    el_est = getfield_default_local(out, 'el_est', []);
    if truth.target_count == 1
        if numel(az_est) == 1 && ~eval_info.low_confidence
            eval_info.az_error_mean = abs(wrap180_local(az_est(1) - truth.az(1)));
            eval_info.el_error_mean = abs(el_est(1) - truth.el(1));
            eval_info.success = eval_info.az_error_mean <= 0.3 && eval_info.el_error_mean <= 0.5;
        end
        return
    end
    [az_mean, el_mean, az_max, el_max, pair_ok] = pair_error_local(az_est, el_est, truth.az, truth.el);
    eval_info.az_error_mean = az_mean;
    eval_info.el_error_mean = el_mean;
    eval_info.az_error_max = az_max;
    eval_info.el_error_max = el_max;
    switch string(sc.scenario_name)
        case {"close_coherent_pair", "medium_beta_pair"}
            eval_info.success = pair_ok && az_mean <= 0.25 && el_mean <= 0.5 && ~eval_info.low_confidence;
        case "large_el_pair"
            eval_info.success = pair_ok && az_mean <= 0.3 && el_mean <= 1.0 && ~eval_info.low_confidence;
        case "two_separated_coarse_peaks"
            eval_info.success = strcmp(string(getfield_default_local(out, 'status', '')), 'rejected');
            eval_info.out_of_scope = true;
        case "weak_target_boundary"
            eval_info.false_high = ~eval_info.low_confidence && ~strcmp(string(getfield_default_local(out, 'status', '')), 'rejected');
        case "near_antiphase_boundary"
            eval_info.false_high = ~eval_info.low_confidence && ~strcmp(string(getfield_default_local(out, 'status', '')), 'rejected');
            eval_info.boundary_missed = sc.boundary_unreliable_flag && ...
                ~any(strcmp(string(getfield_default_local(out, 'route_name', '')), ["boundary_unreliable", "low_confidence"])) && ...
                ~strcmp(string(getfield_default_local(out, 'status', '')), 'rejected');
        otherwise
            eval_info.success = pair_ok && ~eval_info.low_confidence;
    end
end

function [az_mean, el_mean, az_max, el_max, ok] = pair_error_local(az_est, el_est, az_true, el_true)
    az_mean = NaN;
    el_mean = NaN;
    az_max = NaN;
    el_max = NaN;
    ok = false;
    az_err = [NaN, NaN];
    el_err = [NaN, NaN];
    if numel(az_est) < 2 || numel(el_est) < 2
        return
    end
    est = [az_est(:), el_est(:)];
    truth = [az_true(:), el_true(:)];
    d11 = norm(est(1, :) - truth(1, :)) + norm(est(2, :) - truth(2, :));
    d12 = norm(est(1, :) - truth(2, :)) + norm(est(2, :) - truth(1, :));
    if d12 < d11
        truth = flipud(truth);
    end
    az_err = est(:, 1).' - truth(:, 1).';
    el_err = est(:, 2).' - truth(:, 2).';
    az_mean = mean(abs(az_err));
    el_mean = mean(abs(el_err));
    az_max = max(abs(az_err));
    el_max = max(abs(el_err));
    ok = all(isfinite(az_err)) && all(isfinite(el_err));
end

function row = make_bridge_trial_row_local(trial_index, sc, truth, out_light, out_ref, eval_light, eval_ref, runtime_light_sec, runtime_ref_sec)
    row = struct();
    row.trial_index = trial_index;
    row.scenario_name = string(sc.scenario_name);
    row.SNR_dB = sc.SNR_dB;
    row.backend_light_status = string(getfield_default_local(out_light, 'status', ''));
    row.backend_ref_status = string(getfield_default_local(out_ref, 'status', ''));
    row.backend_light_route = string(getfield_default_local(out_light, 'route_name', ''));
    row.backend_ref_route = string(getfield_default_local(out_ref, 'route_name', ''));
    row.backend_light_confidence = string(getfield_default_local(out_light, 'confidence', ''));
    row.backend_ref_confidence = string(getfield_default_local(out_ref, 'confidence', ''));
    row.backend_light_az_est = string(mat2str(getfield_default_local(out_light, 'az_est', []), 6));
    row.backend_ref_az_est = string(mat2str(getfield_default_local(out_ref, 'az_est', []), 6));
    row.backend_light_el_est = string(mat2str(getfield_default_local(out_light, 'el_est', []), 6));
    row.backend_ref_el_est = string(mat2str(getfield_default_local(out_ref, 'el_est', []), 6));
    row.backend_light_success = logical(eval_light.success);
    row.backend_ref_success = logical(eval_ref.success);
    row.backend_light_false_high = logical(eval_light.false_high);
    row.backend_ref_false_high = logical(eval_ref.false_high);
    row.backend_light_boundary_missed = logical(eval_light.boundary_missed);
    row.backend_ref_boundary_missed = logical(eval_ref.boundary_missed);
    row.backend_light_reject_reason = string(getfield_default_local(out_light, 'reject_reason', ''));
    row.backend_ref_reject_reason = string(getfield_default_local(out_ref, 'reject_reason', ''));
    row.backend_ref_blocker_if_any = string(getfield_default_local(out_ref, 'blocker_if_any', 'none'));
    row.runtime_light_sec = runtime_light_sec;
    row.runtime_ref_sec = runtime_ref_sec;
end

function summary_tbl = summarize_bridge_trials_local(T)
    scenarios = ["overall"; unique(string(T.scenario_name), 'stable')];
    rows = cell(numel(scenarios), 1);
    for i = 1:numel(scenarios)
        if scenarios(i) == "overall"
            mask = true(height(T), 1);
        else
            mask = string(T.scenario_name) == scenarios(i);
        end
        row = struct();
        row.scenario_name = scenarios(i);
        row.total_trials = sum(mask);
        row.light_success_rate = mean(double(T.backend_light_success(mask)));
        row.ref_success_rate = mean(double(T.backend_ref_success(mask)));
        row.success_gain_ref_minus_light = row.ref_success_rate - row.light_success_rate;
        row.light_false_high_rate = mean(double(T.backend_light_false_high(mask)));
        row.ref_false_high_rate = mean(double(T.backend_ref_false_high(mask)));
        row.light_boundary_missed_rate = mean(double(T.backend_light_boundary_missed(mask)));
        row.ref_boundary_missed_rate = mean(double(T.backend_ref_boundary_missed(mask)));
        row.ref_reject_rate = mean(string(T.backend_ref_status(mask)) == "rejected");
        row.light_route_distribution = distribution_string_local(T.backend_light_route(mask));
        row.ref_route_distribution = distribution_string_local(T.backend_ref_route(mask));
        rows{i} = row;
    end
    summary_tbl = struct2table([rows{:}]);
end

function keypoints_tbl = bridge_keypoints_local(T, S, step87_backend_callable)
    overall = S(string(S.scenario_name) == "overall", :);
    two_sep_ref_reject_rate = scenario_reject_rate_local(T, 'two_separated_coarse_peaks');
    rows = {};
    rows = add_kp_local(rows, 'step87_backend_callable', double(step87_backend_callable), 'bridge callable flag');
    rows = add_kp_local(rows, 'total_trials', height(T), 'bridge trial rows');
    rows = add_kp_local(rows, 'light_success_rate', overall.light_success_rate, 'step09_light');
    rows = add_kp_local(rows, 'ref_success_rate', overall.ref_success_rate, 'step87_reference');
    rows = add_kp_local(rows, 'success_gain_ref_minus_light', overall.success_gain_ref_minus_light, 'reference minus light success');
    rows = add_kp_local(rows, 'light_false_high_rate', overall.light_false_high_rate, 'step09_light');
    rows = add_kp_local(rows, 'ref_false_high_rate', overall.ref_false_high_rate, 'step87_reference');
    rows = add_kp_local(rows, 'light_boundary_missed_rate', overall.light_boundary_missed_rate, 'step09_light');
    rows = add_kp_local(rows, 'ref_boundary_missed_rate', overall.ref_boundary_missed_rate, 'step87_reference');
    rows = add_kp_local(rows, 'close_coherent_light_success', scenario_mean_local(T, 'close_coherent_pair', 'backend_light_success'), 'close coherent');
    rows = add_kp_local(rows, 'close_coherent_ref_success', scenario_mean_local(T, 'close_coherent_pair', 'backend_ref_success'), 'close coherent');
    rows = add_kp_local(rows, 'large_el_light_success', scenario_mean_local(T, 'large_el_pair', 'backend_light_success'), 'large elevation');
    rows = add_kp_local(rows, 'large_el_ref_success', scenario_mean_local(T, 'large_el_pair', 'backend_ref_success'), 'large elevation');
    rows = add_kp_local(rows, 'near_antiphase_ref_false_high', scenario_mean_local(T, 'near_antiphase_boundary', 'backend_ref_false_high'), 'near anti-phase');
    rows = add_kp_local(rows, 'weak_target_ref_false_high', scenario_mean_local(T, 'weak_target_boundary', 'backend_ref_false_high'), 'weak target');
    rows = add_kp_local(rows, 'two_separated_ref_reject_rate', two_sep_ref_reject_rate, 'out-of-scope reject rate');
    pass_flag = double(step87_backend_callable && ...
        overall.ref_false_high_rate <= overall.light_false_high_rate && ...
        overall.ref_boundary_missed_rate <= overall.light_boundary_missed_rate && ...
        scenario_mean_local(T, 'close_coherent_pair', 'backend_ref_success') >= scenario_mean_local(T, 'close_coherent_pair', 'backend_light_success') + 0.10 && ...
        scenario_mean_local(T, 'large_el_pair', 'backend_ref_success') >= scenario_mean_local(T, 'large_el_pair', 'backend_light_success') + 0.10 && ...
        two_sep_ref_reject_rate >= 0.99);
    blocker = 'none';
    if ~step87_backend_callable
        blocker = 'step87_reference_not_functionalized';
    elseif ~pass_flag
        blocker = 'bridge_threshold_failed';
    end
    rows = add_kp_local(rows, 'bridge_pass_flag', pass_flag, 'pass/fail');
    rows = add_kp_local(rows, 'blocker_if_any', blocker, 'bridge blocker');
    keypoints_tbl = struct2table([rows{:}]);
end

function write_bridge_report_local(report_path, S, K)
    fid = fopen(report_path, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# Step09 Step87 Backend Bridge\n\n');
    fprintf(fid, 'This bridge does not change the Step 09 thesis line. It only checks whether the verified Step 8.7 cascade can sit behind the Step 09 interface as a backend implementation.\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n|---|---:|---|\n');
    for i = 1:height(K)
        fprintf(fid, '| `%s` | %s | %s |\n', safe_string_local(K.keypoint(i)), safe_string_local(K.value(i)), safe_string_local(K.note(i)));
    end
    fprintf(fid, '\n## Summary\n\n');
    fprintf(fid, '| scenario_name | total_trials | light_success_rate | ref_success_rate | success_gain_ref_minus_light | light_false_high_rate | ref_false_high_rate | light_boundary_missed_rate | ref_boundary_missed_rate |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(S)
        fprintf(fid, '| `%s` | %d | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f |\n', ...
            S.scenario_name(i), S.total_trials(i), S.light_success_rate(i), ...
            S.ref_success_rate(i), S.success_gain_ref_minus_light(i), ...
            S.light_false_high_rate(i), S.ref_false_high_rate(i), ...
            S.light_boundary_missed_rate(i), S.ref_boundary_missed_rate(i));
    end
end

function rows = add_kp_local(rows, key, value, note)
    rows{end+1, 1} = struct('keypoint', safe_string_local(key), ...
        'value', safe_string_local(value), 'note', safe_string_local(note));
end

function s = safe_string_local(value)
    if isnumeric(value)
        if isscalar(value)
            if isnan(value)
                s = "NaN";
            else
                s = string(value);
            end
        else
            s = string(mat2str(value));
        end
    else
        s = string(value);
    end
    s(ismissing(s)) = "NaN";
end

function val = scenario_mean_local(T, scenario_name, col)
    mask = string(T.scenario_name) == string(scenario_name);
    if ~any(mask)
        val = NaN;
    else
        v = T.(col)(mask);
        if islogical(v)
            val = mean(double(v));
        else
            val = mean(double(v));
        end
    end
end

function val = scenario_reject_rate_local(T, scenario_name)
    mask = string(T.scenario_name) == string(scenario_name);
    if ~any(mask)
        val = NaN;
    else
        val = mean(string(T.backend_ref_status(mask)) == "rejected");
    end
end

function txt = distribution_string_local(vals)
    vals = string(vals);
    u = unique(vals, 'stable');
    parts = strings(numel(u), 1);
    for i = 1:numel(u)
        parts(i) = sprintf('%s:%.3f', u(i), mean(vals == u(i)));
    end
    txt = strjoin(parts, ';');
end

function val = getfield_default_local(s, name, default_val)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        val = s.(name);
    else
        val = default_val;
    end
end

function x = wrap180_local(x)
    x = mod(x + 180, 360) - 180;
end
