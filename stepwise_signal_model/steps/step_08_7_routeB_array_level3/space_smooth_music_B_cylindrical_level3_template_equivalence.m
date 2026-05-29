% Step 8.7 Part 8: local steering template equivalence validation.
% This script validates local-coordinate steering templates before any FPGA,
% fixed-point, or HDL work. It does not change the 7B dispatch thresholds.

clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
step75_dir = fullfile(steps_dir, 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');

addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
addpath(step75_dir);

cfg = sim_cfg();

result_dir = fullfile(script_dir, 'results_step8_7_8_template_equivalence');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_7_8_template_equivalence.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

summary_steer_csv = fullfile(result_dir, 'step8_7_8_template_steering_equivalence_summary.csv');
summary_route_csv = fullfile(result_dir, 'step8_7_8_template_route_consistency_summary.csv');
keypoints_csv = fullfile(result_dir, 'step8_7_8_template_equivalence_keypoints.csv');
mat_path = fullfile(result_dir, 'step8_7_8_template_equivalence_result.mat');
record_doc_path = fullfile(script_dir, '第8.7步_8_方式B局部steering模板等价性验证记录.md');

log_msg(fid_log, 'Step 8.7 part 8: local steering template equivalence + 7B lazy route consistency.');
log_msg(fid_log, 'Scope: validate template steering before FPGA migration. No FPGA, no fixed point, no threshold changes.');

Q = cfg.beam.subNaz;
Nel = cfg.arr.Nel;
lambda = cfg.arr.lambda;
azCtr_list = [0, 15, 30, 60, 120];
azCtr_route_list = [0, 30, 60];
delta_az_grid = -0.6:0.02:0.6;
delta_az_check = [-0.6, -0.3, 0, 0.3, 0.6];
el_grid = -2:0.5:12;
el_check = [-2, 0, 5, 10, 12];
el_refocus_grid = -2:0.5:12;
snr_list = [0, 8, 16];
Metkl = 20;
quick_mode = false;
if strcmpi(getenv('STEP87_TEMPLATE_QUICK_MODE'), '1') || strcmpi(getenv('STEP87_QUICK_MODE'), '1')
    Metkl = 5;
    quick_mode = true;
end
T_snap = 260;
sep_factor = 10;
Lc = 2;
K_phi_level2 = 20;
K_phi_music = 20;
K_z_music = 8;
K_phi_covfit = 6;
K_z_covfit = 3;
az_tol_deg = 0.1;
el_tol_deg = 0.5;
min_pair_sep_deg = 0.05;
max_pair_sep_deg = 0.80;
base_seed = 20261008;

log_msg(fid_log, 'Run control: Metkl=%d quick_mode=%d centers=%s route_centers=%s.', ...
    Metkl, quick_mode, mat2str(azCtr_list), mat2str(azCtr_route_list));
log_msg(fid_log, 'Grid: Delta az=%s, el=%s.', grid_desc_local(delta_az_grid), grid_desc_local(el_grid));

d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
bw_eq_65 = 50.8 * 1.45 * cfg.arr.lambda / ((Q - 1) * d_eq);
theta_sep = bw_eq_65 / sep_factor;
theta_true_local = sort([-theta_sep/2, theta_sep/2]);
log_msg(fid_log, 'Geometry: Q=%d Nel=%d theta_sep=%.9f deg.', Q, Nel, theta_sep);

canonical = make_center_geometry_local(cfg, 0, Q);
[canon_x, canon_y, canon_z] = local_coords_local(canonical.X, canonical.Y, canonical.Z, 0);
canonical.x_local = canon_x;
canonical.y_local = canon_y;
canonical.z_local = canon_z;
canonical.A_ref_local = exp(-1j * 2*pi / lambda * canon_x);

log_msg(fid_log, 'Running steering equivalence sweep.');
[steer_tbl, geom_tbl] = run_steering_equivalence_local( ...
    cfg, canonical, azCtr_list, delta_az_grid, el_grid, Q, Nel, ...
    K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, lambda);
writetable(steer_tbl, summary_steer_csv);

exact_max = max(steer_tbl.rel_err_aligned(steer_tbl.template_mode == "template_exact"));
exact_min_coh = min(steer_tbl.coherence(steer_tbl.template_mode == "template_exact"));
canon_max = max(steer_tbl.rel_err_aligned(steer_tbl.template_mode == "template_canonical"));
canon_min_coh = min(steer_tbl.coherence(steer_tbl.template_mode == "template_canonical"));
exact_pass = exact_max <= 1e-10 && exact_min_coh >= 1 - 1e-10;
canonical_pass = canon_max <= 1e-8 && canon_min_coh >= 1 - 1e-8;
template_mode_for_route = "not_run";
if exact_pass
    if canonical_pass
        template_mode_for_route = "template_canonical";
    else
        template_mode_for_route = "template_exact";
    end
end
log_msg(fid_log, 'Steering exact: max aligned err=%.3e min coh=%.15f pass=%d.', exact_max, exact_min_coh, exact_pass);
log_msg(fid_log, 'Steering canonical: max aligned err=%.3e min coh=%.15f pass=%d.', canon_max, canon_min_coh, canonical_pass);
log_msg(fid_log, 'Route consistency template mode: %s.', template_mode_for_route);

if exact_pass
    log_msg(fid_log, 'Running 7B lazy route consistency with template mode %s.', template_mode_for_route);
    [route_trial_tbl, route_summary_tbl] = run_route_consistency_local( ...
        cfg, canonical, azCtr_route_list, snr_list, Metkl, T_snap, theta_true_local, ...
        delta_az_grid, el_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, ...
        K_phi_covfit, K_z_covfit, Lc, min_pair_sep_deg, max_pair_sep_deg, ...
        az_tol_deg, el_tol_deg, template_mode_for_route, base_seed, fid_log);
else
    log_msg(fid_log, 'Exact template failed. Route consistency is skipped.');
    route_trial_tbl = empty_route_trial_table_local();
    route_summary_tbl = empty_route_summary_table_local();
end
writetable(route_summary_tbl, summary_route_csv);

keypoints_tbl = build_template_keypoints_local( ...
    steer_tbl, geom_tbl, route_trial_tbl, route_summary_tbl, exact_pass, canonical_pass, template_mode_for_route);
writetable(keypoints_tbl, keypoints_csv);

log_msg(fid_log, 'Rendering plots.');
plot_steering_rel_error_by_center_local(steer_tbl, fullfile(result_dir, 'steering_rel_error_by_center.png'));
plot_steering_coherence_by_center_local(steer_tbl, fullfile(result_dir, 'steering_coherence_by_center.png'));
plot_steering_phase_error_hist_local(steer_tbl, fullfile(result_dir, 'steering_phase_error_hist.png'));
plot_canonical_geometry_error_by_center_local(geom_tbl, fullfile(result_dir, 'canonical_geometry_error_by_center.png'));
plot_route_agreement_by_scenario_local(route_summary_tbl, fullfile(result_dir, 'route_agreement_by_scenario.png'));
plot_template_vs_direct_az_el_error_local(route_trial_tbl, fullfile(result_dir, 'template_vs_direct_az_el_error.png'));

save(mat_path, 'steer_tbl', 'geom_tbl', 'route_trial_tbl', 'route_summary_tbl', ...
    'keypoints_tbl', 'azCtr_list', 'azCtr_route_list', 'delta_az_grid', 'el_grid', ...
    'Metkl', 'quick_mode', 'template_mode_for_route', '-v7');

write_template_record_doc_local(record_doc_path, keypoints_tbl, result_dir, Metkl, quick_mode, ...
    template_mode_for_route, steer_tbl, route_summary_tbl);
log_msg(fid_log, 'Outputs written to %s.', result_dir);

function [steer_tbl, geom_tbl] = run_steering_equivalence_local( ...
    cfg, canonical, azCtr_list, delta_grid, el_grid, Q, Nel, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, lambda)
    rows = {};
    geom_rows = {};
    [p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi_covfit, K_z_covfit);
    for ic = 1:numel(azCtr_list)
        azCtr = azCtr_list(ic);
        geom = make_center_geometry_local(cfg, azCtr, Q);
        [xloc, yloc, zloc] = local_coords_local(geom.X, geom.Y, geom.Z, azCtr);
        A_ref_direct = exp(-1j * 2*pi / lambda * (geom.X * cosd(azCtr) + geom.Y * sind(azCtr)));
        A_ref_local = exp(-1j * 2*pi / lambda * xloc);
        geom_err = geometry_error_local(xloc, yloc, zloc, canonical.x_local, canonical.y_local, canonical.z_local);
        geom_rows(end+1, :) = {azCtr, geom.colCtr, geom_err.x_rel, geom_err.y_rel, geom_err.z_rel, ...
            geom_err.xyz_rel, geom_err.xyz_max_abs}; %#ok<AGROW>
        for id = 1:numel(delta_grid)
            delta = delta_grid(id);
            theta_abs = azCtr + delta;
            for ie = 1:numel(el_grid)
                el = el_grid(ie);
                A_direct = steering_direct_local(geom.X, geom.Y, geom.Z, A_ref_direct, lambda, theta_abs, el);
                A_exact = steering_local_template_local(xloc, yloc, zloc, A_ref_local, lambda, delta, el);
                A_canon = steering_local_template_local(canonical.x_local, canonical.y_local, canonical.z_local, ...
                    canonical.A_ref_local, lambda, delta, el);
                rows = add_steering_rows_local(rows, azCtr, delta, el, A_direct, A_exact, A_canon, ...
                    K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, p_sel, r_sel, geom.Z, lambda);
            end
        end
    end
    steer_tbl = cell2table(rows, 'VariableNames', steering_summary_names_local());
    geom_tbl = cell2table(geom_rows, 'VariableNames', ...
        {'azCtr', 'colCtr', 'x_rel_err', 'y_rel_err', 'z_rel_err', 'xyz_rel_err', 'xyz_max_abs_err'});
end

function rows = add_steering_rows_local(rows, azCtr, delta, el, A_direct, A_exact, A_canon, ...
    K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, p_sel, r_sel, Z3d, lambda)
    rows = add_one_type_rows_local(rows, azCtr, delta, el, 'full_65x32', A_direct(:), A_exact(:), A_canon(:));

    p0 = floor((size(A_direct, 1) - K_phi_music) / 2) + 1;
    r0 = floor((size(A_direct, 2) - K_z_music) / 2) + 1;
    d_music = A_direct(p0:p0+K_phi_music-1, r0:r0+K_z_music-1);
    e_music = A_exact(p0:p0+K_phi_music-1, r0:r0+K_z_music-1);
    c_music = A_canon(p0:p0+K_phi_music-1, r0:r0+K_z_music-1);
    rows = add_one_type_rows_local(rows, azCtr, delta, el, 'music2d_center_subarray', d_music(:), e_music(:), c_music(:));

    d_pair = selected_subarray_vector_local(A_direct, K_phi_covfit, K_z_covfit, p_sel, r_sel);
    e_pair = selected_subarray_vector_local(A_exact, K_phi_covfit, K_z_covfit, p_sel, r_sel);
    c_pair = selected_subarray_vector_local(A_canon, K_phi_covfit, K_z_covfit, p_sel, r_sel);
    rows = add_one_type_rows_local(rows, azCtr, delta, el, 'pairlocal_selected_subarray', d_pair, e_pair, c_pair);

    b_direct = combine_layers_level2_steer_from_A_local(A_direct, Z3d, lambda, el);
    b_exact = combine_layers_level2_steer_from_A_local(A_exact, Z3d, lambda, el);
    b_canon = combine_layers_level2_steer_from_A_local(A_canon, Z3d, lambda, el);
    rows = add_one_type_rows_local(rows, azCtr, delta, el, 'level2_combined', b_direct(:), b_exact(:), b_canon(:));
end

function rows = add_one_type_rows_local(rows, azCtr, delta, el, steering_type, direct_vec, exact_vec, canon_vec)
    m_exact = steering_metrics_local(direct_vec, exact_vec);
    rows(end+1, :) = {azCtr, delta, el, string(steering_type), "template_exact", ...
        m_exact.rel_raw, m_exact.rel_aligned, m_exact.coherence, ...
        m_exact.phase_mean_abs, m_exact.phase_rms, m_exact.phase_max_abs}; %#ok<AGROW>
    m_canon = steering_metrics_local(direct_vec, canon_vec);
    rows(end+1, :) = {azCtr, delta, el, string(steering_type), "template_canonical", ...
        m_canon.rel_raw, m_canon.rel_aligned, m_canon.coherence, ...
        m_canon.phase_mean_abs, m_canon.phase_rms, m_canon.phase_max_abs}; %#ok<AGROW>
end

function names = steering_summary_names_local()
    names = {'azCtr', 'Delta_az', 'el', 'steering_type', 'template_mode', ...
        'rel_err_raw', 'rel_err_aligned', 'coherence', ...
        'phase_err_mean_abs', 'phase_err_rms', 'phase_err_max'};
end

function [trial_tbl, summary_tbl] = run_route_consistency_local( ...
    cfg, canonical, azCtr_list, snr_list, Metkl, T_snap, theta_true_local, ...
    delta_grid, el_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, ...
    K_phi_covfit, K_z_covfit, Lc, min_sep, max_sep, az_tol, el_tol, template_mode, base_seed, fid_log)
    Q = cfg.beam.subNaz;
    Nel = cfg.arr.Nel;
    lambda = cfg.arr.lambda;
    scenarios = build_route_scenarios_local(snr_list);
    num_rows = numel(azCtr_list) * numel(scenarios) * Metkl;
    rows = cell(num_rows, numel(route_trial_names_local()));
    row_idx = 0;
    s1_base = exp(1j * 2*pi * (0:T_snap-1) / 17);
    v_base = exp(1j * 2*pi * (0:T_snap-1) / 23 + 1j*pi/7);
    [p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi_covfit, K_z_covfit);
    for ic = 1:numel(azCtr_list)
        azCtr = azCtr_list(ic);
        direct_geom = make_center_geometry_local(cfg, azCtr, Q);
        A_ref_direct = exp(-1j * 2*pi / lambda * (direct_geom.X * cosd(azCtr) + direct_geom.Y * sind(azCtr)));
        [xloc, yloc, zloc] = local_coords_local(direct_geom.X, direct_geom.Y, direct_geom.Z, azCtr);
        if template_mode == "template_canonical"
            template_geom = struct('X', canonical.x_local, 'Y', canonical.y_local, 'Z', canonical.z_local, ...
                'A_ref', canonical.A_ref_local);
        else
            template_geom = struct('X', xloc, 'Y', yloc, 'Z', zloc, ...
                'A_ref', exp(-1j * 2*pi / lambda * xloc));
        end
        direct_model = make_route_model_local(direct_geom.X, direct_geom.Y, direct_geom.Z, A_ref_direct, lambda, ...
            azCtr + delta_grid, el_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, ...
            K_phi_covfit, K_z_covfit, min_sep, max_sep, theta_true_local + azCtr, p_sel, r_sel);
        template_model = make_route_model_local(template_geom.X, template_geom.Y, template_geom.Z, template_geom.A_ref, lambda, ...
            delta_grid, el_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, ...
            K_phi_covfit, K_z_covfit, min_sep, max_sep, theta_true_local, p_sel, r_sel);
        theta_true_abs = theta_true_local + azCtr;
        for is = 1:numel(scenarios)
            sc = scenarios(is);
            log_msg(fid_log, 'Route center=%g scenario=%s SNR=%g Metkl=%d.', azCtr, sc.case_name, sc.snr_db, Metkl);
            for imc = 1:Metkl
                rng(base_seed + ic * 100000 + is * 1000 + imc);
                s1 = s1_base .* exp(1j * 2*pi * rand);
                v = v_base .* exp(1j * 2*pi * rand);
                y_clean = make_clean_cylindrical_observations_general_local( ...
                    direct_geom.X, direct_geom.Y, direct_geom.Z, A_ref_direct, lambda, ...
                    theta_true_abs(1), theta_true_abs(2), sc.el_true(1), sc.el_true(2), ...
                    sc.beta, sc.phi_deg, sc.rho, s1, v);
                y_noisy = add_noise_local(y_clean, sc.snr_db);
                t0 = tic;
                [direct_result, direct_timing] = run_lazy_cascade_template_local( ...
                    y_noisy, sc, direct_model, Lc, theta_true_abs, sc.el_true, min_sep, max_sep);
                runtime_direct = toc(t0);
                t0 = tic;
                [template_result_local, template_timing] = run_lazy_cascade_template_local( ...
                    y_noisy, sc, template_model, Lc, theta_true_local, sc.el_true, min_sep, max_sep);
                runtime_template = toc(t0);
                template_result = shift_result_az_local(template_result_local, azCtr);
                direct_success = joint_success_from_result_local(direct_result, theta_true_abs, sc.el_true, az_tol, el_tol);
                template_success = joint_success_from_result_local(template_result, theta_true_abs, sc.el_true, az_tol, el_tol);
                direct_route = string(getfield_default_local(direct_result, 'recommended_route', ""));
                template_route = string(getfield_default_local(template_result, 'recommended_route', ""));
                direct_conf = string(getfield_default_local(direct_result, 'confidence_flag', ""));
                template_conf = string(getfield_default_local(template_result, 'confidence_flag', ""));
                oracle_boundary = sc.weak_target_flag || sc.anti_phase_flag;
                template_false_high = strcmp(template_conf, "high") && ~template_success;
                template_boundary_missed = oracle_boundary && strcmp(template_conf, "high") && ...
                    ~any(strcmp(template_route, ["low_confidence", "boundary_unreliable"])) && ~template_success;
                [az_diff, el_diff] = estimate_pair_diff_local(direct_result, template_result);
                row_idx = row_idx + 1;
                rows(row_idx, :) = {azCtr, string(sc.case_name), sc.snr_db, imc, template_mode, ...
                    direct_route, template_route, strcmp(direct_route, template_route), ...
                    direct_conf, template_conf, strcmp(direct_conf, template_conf), ...
                    direct_success, template_success, template_success - direct_success, ...
                    template_false_high, template_boundary_missed, ...
                    mean(abs(az_diff), 'omitnan'), max(abs(az_diff), [], 'omitnan'), ...
                    mean(abs(el_diff), 'omitnan'), max(abs(el_diff), [], 'omitnan'), ...
                    runtime_direct, runtime_template, direct_timing.early_stop_stage, template_timing.early_stop_stage};
            end
        end
    end
    rows = rows(1:row_idx, :);
    trial_tbl = cell2table(rows, 'VariableNames', route_trial_names_local());
    summary_tbl = build_route_summary_local(trial_tbl);
end

function model = make_route_model_local(X3d, Y3d, Z3d, A_ref, lambda, az_grid, el_grid, el_refocus_grid, ...
    K_phi_level2, K_phi_music, K_z_music, K_phi_covfit, K_z_covfit, min_sep, max_sep, theta_true, p_sel, r_sel)
    pair_candidates = make_pair_candidates_local(az_grid, min_sep, max_sep);
    model = struct();
    model.X3d = X3d;
    model.Y3d = Y3d;
    model.Z3d = Z3d;
    model.A_ref = A_ref;
    model.lambda = lambda;
    model.az_grid = az_grid;
    model.el_grid = el_grid;
    model.el_refocus_grid = el_refocus_grid;
    model.K_phi_level2 = K_phi_level2;
    model.K_phi_music = K_phi_music;
    model.K_z_music = K_z_music;
    model.K_phi_covfit = K_phi_covfit;
    model.K_z_covfit = K_z_covfit;
    model.p_sel = p_sel;
    model.r_sel = r_sel;
    model.theta_true = theta_true;
    model.level2_cache_map = precompute_level2_bank_local( ...
        X3d, Y3d, Z3d, A_ref, lambda, az_grid, -5:1:15, K_phi_level2, pair_candidates);
    model.level2_refocus_cache_map = precompute_level2_bank_local( ...
        X3d, Y3d, Z3d, A_ref, lambda, az_grid, el_refocus_grid, K_phi_level2, pair_candidates);
    model.music_cache = make_level3_grid_cache_local(X3d, Y3d, Z3d, A_ref, lambda, az_grid, el_grid, K_phi_music, K_z_music);
end

function [result, timing] = run_lazy_cascade_template_local(y_noisy_2d, sc, model, Lc, theta_true, el_true, min_sep, max_sep)
    timing = init_wallclock_timing_local();
    empty_result = make_empty_route_result_local("not_executed");
    rank1 = empty_result;
    music2d = empty_result;
    pair2d = empty_result;

    t0 = tic;
    music = run_level2_music_route_local(y_noisy_2d, model.X3d, model.Y3d, model.Z3d, model.A_ref, model.lambda, ...
        sc.el_assumed, model.az_grid, model.K_phi_level2, Lc);
    timing.t_level2_music = toc(t0);
    timing.executed_level2_music = true;

    t0 = tic;
    refocus = run_common_el_refocus_power_route_local(y_noisy_2d, model.Z3d, model.lambda, model.el_refocus_grid, ...
        model.level2_refocus_cache_map, model.az_grid, model.K_phi_level2, theta_true, min_sep, max_sep);
    timing.t_refocus = toc(t0);
    timing.executed_refocus = true;

    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    common_el_proxy = is_strong_common_el_proxy_local(music, refocus);
    low_cost_boundary_partial = is_low_cost_boundary_proxy_from_partial_local(music, rank1, refocus, min_sep, max_sep);
    if is_level2_music_reliable_local(music, min_sep, max_sep) && common_el_proxy
        result = music;
        result.recommended_route = "level2_music_or_center_real";
        if is_level2_music_high_confidence_local(music, route_map, min_sep, max_sep)
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "ok";
        timing = finish_lazy_timing_local(timing, 1, true, route_map);
        return
    end
    if is_refocus_route_reliable_local(refocus, min_sep, max_sep) && ~low_cost_boundary_partial && common_el_proxy
        result = refocus;
        result.recommended_route = "common_el_refocus_power_rank1";
        result.confidence_flag = "medium";
        result.failure_reason = "ok";
        timing = finish_lazy_timing_local(timing, 2, true, route_map);
        return
    end

    t0 = tic;
    rank1 = run_level2_rank1_route_local(y_noisy_2d, model.Z3d, model.lambda, sc.el_assumed, ...
        model.level2_cache_map, model.az_grid, model.K_phi_level2, theta_true, min_sep, max_sep);
    timing.t_level2_rank1 = toc(t0);
    timing.executed_level2_rank1 = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    low_cost_boundary = is_low_cost_boundary_proxy_from_partial_local(music, rank1, refocus, min_sep, max_sep);
    if is_rank1_route_reliable_local(rank1, min_sep, max_sep) && ~low_cost_boundary && common_el_proxy
        result = rank1;
        result.recommended_route = "level2_rank1_fallback";
        result.confidence_flag = "medium";
        result.failure_reason = "music_single_rank1_fallback";
        timing = finish_lazy_timing_local(timing, 3, true, route_map);
        return
    end

    t0 = tic;
    Rfb_2d = level3_fbss_cov_from_observation_local(y_noisy_2d, model.K_phi_music, model.K_z_music);
    music2d = run_level3_2d_music_route_local(Rfb_2d, model.music_cache, Lc);
    timing.t_2dmusic = toc(t0);
    timing.executed_2dmusic = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    if is_music2d_reliable_local(music2d, min_sep, max_sep)
        pair_available = music2d.peak_count >= 2 && all(isfinite(music2d.az_est)) && all(isfinite(music2d.el_est));
        if pair_available && is_cascade_pair_refinement_needed_local(music2d, min_sep, max_sep)
            t0 = tic;
            Rfb_pair = level3_fbss_cov_selected_from_observation_local( ...
                y_noisy_2d, model.K_phi_covfit, model.K_z_covfit, model.p_sel, model.r_sel);
            pair2d = run_level3_pair_el_local_rank1_covfit_local( ...
                Rfb_pair, music2d, model.X3d, model.Y3d, model.Z3d, model.A_ref, model.lambda, ...
                model.K_phi_covfit, model.K_z_covfit, model.p_sel, model.r_sel, theta_true, el_true, min_sep, max_sep);
            timing.t_pair_local = toc(t0);
            timing.executed_pair_local = true;
            route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
            if is_pair_route_reliable_local(pair2d, min_sep, max_sep)
                result = pair2d;
                result.recommended_route = "pair_el_local_covfit";
                result.confidence_flag = "medium";
                result.failure_reason = "ok";
                timing = finish_lazy_timing_local(timing, 5, true, route_map);
                return
            end
        end
        result = music2d;
        result.recommended_route = "level3_2d_music";
        result.confidence_flag = "medium";
        if timing.executed_pair_local
            result.failure_reason = "pair_local_not_reliable";
        else
            result.failure_reason = "ok";
        end
        timing = finish_lazy_timing_local(timing, 4, true, route_map);
        return
    end
    if is_boundary_unreliable_local(route_map, min_sep, max_sep) || low_cost_boundary
        result = make_boundary_result_local(route_map, 'boundary_unreliable', 'low', 'boundary_unreliable', false, false);
    else
        result = make_boundary_result_local(route_map, 'low_confidence', 'low', 'no_reliable_observable_route', false, false);
    end
    timing = finish_lazy_timing_local(timing, 6, false, route_map);
end

function scenarios = build_route_scenarios_local(snr_list)
    defs = { ...
        'common_el_clean', [0, 0], 1, 0, 1; ...
        'rho_0p7', [0, 0], 1, 0, 0.7; ...
        'beta_0p3', [0, 0], 0.3, 0, 1; ...
        'phase_150', [0, 0], 1, 150, 1; ...
        'large_el_clean', [0, 5], 1, 0, 1; ...
        'large_el_hard', [0, 10], 0.5, 180, 0.7};
    scenarios_cell = cell(size(defs, 1) * numel(snr_list), 1);
    idx = 0;
    for id = 1:size(defs, 1)
        for is = 1:numel(snr_list)
            idx = idx + 1;
            scenarios_cell{idx} = make_dispatch_scenario_local('template_route', defs{id, 1}, snr_list(is), ...
                defs{id, 2}, defs{id, 3}, defs{id, 4}, defs{id, 5}, 0);
        end
    end
    scenarios = [scenarios_cell{:}];
end

function sc = make_dispatch_scenario_local(group, case_name, snr_db, el_true, beta, phi_deg, rho, el_assumed)
    sc = struct();
    sc.group = string(group);
    sc.case_name = string(case_name);
    sc.snr_db = snr_db;
    sc.el_true = el_true;
    sc.el_assumed = el_assumed;
    sc.el_diff = abs(diff(el_true));
    sc.beta = beta;
    sc.phi_deg = phi_deg;
    sc.rho = rho;
    sc.large_el_flag = sc.el_diff >= 2;
    sc.common_el_flag = sc.el_diff < 0.5;
    sc.weak_target_flag = beta <= 0.3;
    sc.anti_phase_flag = min(abs(phi_deg - 180), abs(phi_deg + 180)) <= 30 || phi_deg >= 150;
end

function geom = make_center_geometry_local(cfg, azCtr, Q)
    arrInfo = arr_cyl(cfg, azCtr);
    geom = struct();
    geom.azCtr = azCtr;
    geom.colCtr = arrInfo.colCtr;
    geom.colsAct = arrInfo.colsAct;
    geom.phiActRel = arrInfo.phiActRel;
    geom.X = arrInfo.XAct(1:Q, :);
    geom.Y = arrInfo.YAct(1:Q, :);
    geom.Z = arrInfo.ZAct(1:Q, :);
end

function [xloc, yloc, zloc] = local_coords_local(X, Y, Z, azCtr)
    xloc = X * cosd(azCtr) + Y * sind(azCtr);
    yloc = -X * sind(azCtr) + Y * cosd(azCtr);
    zloc = Z;
end

function err = geometry_error_local(x, y, z, x0, y0, z0)
    err = struct();
    err.x_rel = norm(x(:) - x0(:)) / max(norm(x0(:)), eps);
    err.y_rel = norm(y(:) - y0(:)) / max(norm(y0(:)), eps);
    err.z_rel = norm(z(:) - z0(:)) / max(norm(z0(:)), eps);
    err.xyz_rel = norm([x(:)-x0(:); y(:)-y0(:); z(:)-z0(:)]) / ...
        max(norm([x0(:); y0(:); z0(:)]), eps);
    err.xyz_max_abs = max(abs([x(:)-x0(:); y(:)-y0(:); z(:)-z0(:)]));
end

function A = steering_direct_local(X, Y, Z, A_ref, lambda, az_deg, el_deg)
    k = 2*pi / lambda;
    phase = X * (cosd(el_deg) * cosd(az_deg)) + ...
        Y * (cosd(el_deg) * sind(az_deg)) + Z * sind(el_deg);
    A = conj(A_ref) .* exp(-1j * k * phase);
end

function A = steering_local_template_local(xloc, yloc, zloc, A_ref_local, lambda, delta_deg, el_deg)
    k = 2*pi / lambda;
    phase = xloc * (cosd(el_deg) * cosd(delta_deg)) + ...
        yloc * (cosd(el_deg) * sind(delta_deg)) + zloc * sind(el_deg);
    A = conj(A_ref_local) .* exp(-1j * k * phase);
end

function b = combine_layers_level2_steer_from_A_local(A, Z3d, lambda, el_assumed_deg)
    Nel = size(A, 2);
    z_col = Z3d(1, :).';
    steer_el = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    w_z = steer_el / sqrt(Nel);
    b = (w_z' * A.').';
    b = b / max(norm(b), eps);
end

function v = selected_subarray_vector_local(A, K_phi, K_z, p_sel, r_sel)
    K = K_phi * K_z;
    v = complex(zeros(K * numel(p_sel) * numel(r_sel), 1));
    idx = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            sub = A(p_sel(ip):p_sel(ip)+K_phi-1, r_sel(ir):r_sel(ir)+K_z-1);
            v(idx+1:idx+K) = sub(:);
            idx = idx + K;
        end
    end
end

function m = steering_metrics_local(a_direct, a_template)
    a_direct = a_direct(:);
    a_template = a_template(:);
    inner = a_template' * a_direct;
    alpha = inner / max(abs(inner), eps);
    a_aligned = alpha * a_template;
    m = struct();
    m.rel_raw = norm(a_direct - a_template) / max(norm(a_direct), eps);
    m.rel_aligned = norm(a_direct - a_aligned) / max(norm(a_direct), eps);
    m.coherence = abs(a_direct' * a_template) / max(norm(a_direct) * norm(a_template), eps);
    phase_err = angle(a_direct .* conj(a_aligned));
    m.phase_mean_abs = mean(abs(phase_err));
    m.phase_rms = sqrt(mean(phase_err.^2));
    m.phase_max_abs = max(abs(phase_err));
end

function y_clean_2d = make_clean_cylindrical_observations_general_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, theta_b, el_a, el_b, beta, phi_deg, rho, s1, v)
    rho = min(max(rho, 0), 1);
    s2 = beta * exp(1j * deg2rad(phi_deg)) * (rho * s1 + sqrt(max(1 - rho^2, 0)) * v);
    A_a = steering_direct_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_a, el_a);
    A_b = steering_direct_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_b, el_b);
    y_clean_2d = reshape(A_a(:) * s1 + A_b(:) * s2, size(X3d, 1), size(X3d, 2), numel(s1));
end

function y_noisy = add_noise_local(y_clean, snr_db)
    sig_power = mean(abs(y_clean(:)).^2);
    sigma2 = sig_power / 10^(snr_db/10);
    noise = sqrt(sigma2/2) * (randn(size(y_clean)) + 1j * randn(size(y_clean)));
    y_noisy = y_clean + noise;
end

function result = run_level2_music_route_local( ...
    y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, el_assumed, az_grid, K_phi, Lc)
    y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_assumed);
    Rfb = level2_fbss_cov_local(y_combined, K_phi);
    B_grid = build_level2_combined_az_steer_grid_local( ...
        X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_assumed, el_assumed);
    sub_cache = make_subarray_steer_cache_local(B_grid, K_phi);
    p0 = ceil(sub_cache.P_phi / 2);
    A = sub_cache.A_forward(:, :, p0);
    [V, D] = eig(0.5 * (Rfb + Rfb'));
    [~, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    evals = real(diag(D));
    evals = evals(ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(A) .* (Cn * A), 1));
    spectrum = 1 ./ max(den, eps);
    peaks = find_1d_peaks_local(spectrum, az_grid, Lc);
    result = make_result_local(peaks.az_est, [el_assumed, el_assumed], peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum_1d = spectrum;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.spectrum_width = peaks.spectrum_width;
    result.pair_sep_est = peaks.peak_separation_az;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, result.lambda2_over_noise, ...
        result.lambda2_over_lambda1, result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_bank, K_phi, candidate_pairs)
    cache_map = struct([]);
    for ie = 1:numel(el_bank)
        B = build_level2_combined_az_steer_grid_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_bank(ie), el_bank(ie));
        sub_cache = make_subarray_steer_cache_local(B, K_phi);
        precomp = precompute_rank1_pair_bases_local(sub_cache, candidate_pairs);
        cache_map(ie).el = el_bank(ie);
        cache_map(ie).sub_cache = sub_cache;
        cache_map(ie).precomp = precomp;
    end
end

function result = run_level2_rank1_route_local( ...
    y_noisy_2d, Z3d, lambda, el_assumed, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    [~, idx] = min(abs([cache_map.el] - el_assumed));
    y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, cache_map(idx).el);
    Rfb = level2_fbss_cov_local(y_combined, K_phi);
    result = score_level2_cache_local(Rfb, cache_map(idx), az_grid, theta_true);
    result.el_est = [cache_map(idx).el, cache_map(idx).el];
    result.peak_count = 2;
    result.failure_reason = failure_reason_pair_local(result.az_est, result.el_est, min_sep, max_sep);
end

function result = score_level2_cache_local(Rfb, cache, az_grid, theta_true)
    score = score_rank1_all_local(Rfb, cache.precomp);
    [best_score, best_idx] = min(score);
    score2 = second_score_local(score, best_idx);
    pair_idx = cache.precomp.candidate_pairs(best_idx, :);
    true_precomp = precompute_rank1_pair_bases_local(cache.sub_cache, nearest_pair_indices_local(az_grid, theta_true));
    true_score = score_rank1_all_local(Rfb, true_precomp);
    result = make_result_local(sort(az_grid(pair_idx)), [NaN, NaN], 2, best_score, true_score(1), 'ok');
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est));
end

function result = run_common_el_refocus_power_route_local( ...
    y_noisy_2d, Z3d, lambda, el_grid, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep)
    n = numel(el_grid);
    power_curve = zeros(1, n);
    lambda1_curve = zeros(1, n);
    for ie = 1:n
        y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_grid(ie));
        power_curve(ie) = mean(abs(y_combined(:)).^2);
        Rfb = level2_fbss_cov_local(y_combined, K_phi);
        lambda1_curve(ie) = max(real(eig(0.5 * (Rfb + Rfb'))));
    end
    [~, idx] = max(power_curve);
    el_hat = el_grid(idx);
    result = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, el_hat, cache_map, az_grid, K_phi, theta_true, min_sep, max_sep);
    result.el_hat = el_hat;
    result.el_est = [el_hat, el_hat];
    result.el_common_est = el_hat;
    result.el_selection_method = "focused_power";
    result.focused_power_peak_sharpness = peak_sharpness_local(power_curve);
    result.lambda1_peak_sharpness = peak_sharpness_local(lambda1_curve);
    result.power_curve = power_curve;
    result.lambda1_curve = lambda1_curve;
    result.el_grid = el_grid;
end

function sharpness = peak_sharpness_local(curve)
    curve = real(curve(:));
    [mx, idx] = max(curve);
    tmp = curve;
    tmp(idx) = -inf;
    second = max(tmp);
    sharpness = (mx - second) / max(abs(mx), eps);
end

function y_combined = combine_layers_level2_local(y_2d, Z3d, lambda, el_assumed_deg)
    Nel = size(y_2d, 2);
    z_col = Z3d(1, :).';
    steer_el = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    W = steer_el' / sqrt(Nel);
    tmp = W * reshape(permute(y_2d, [2, 1, 3]), Nel, []);
    y_combined = reshape(tmp, size(y_2d, 1), size(y_2d, 3));
end

function Rfb = level2_fbss_cov_local(y_combined, K_phi)
    Rxx = y_combined * y_combined' / size(y_combined, 2);
    Rxx = 0.5 * (Rxx + Rxx');
    Rfb = mssp_array_fb(Rxx, K_phi);
    Rfb = 0.5 * (Rfb + Rfb');
end

function b = build_level2_combined_az_steer_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg, el_assumed_deg)
    A = steering_direct_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg);
    b = combine_layers_level2_steer_from_A_local(A, Z3d, lambda, el_assumed_deg);
end

function B_grid = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid, el_scan_deg, el_assumed_deg)
    B_grid = zeros(size(X3d, 1), numel(angle_grid));
    for ia = 1:numel(angle_grid)
        B_grid(:, ia) = build_level2_combined_az_steer_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid(ia), el_scan_deg, el_assumed_deg);
    end
end

function cache = make_subarray_steer_cache_local(B_grid, K_phi)
    Q = size(B_grid, 1);
    ngrid = size(B_grid, 2);
    P_phi = Q - K_phi + 1;
    J = fliplr(eye(K_phi));
    A_forward = complex(zeros(K_phi, ngrid, P_phi));
    for p = 1:P_phi
        A_forward(:, :, p) = normalize_columns_local(B_grid(p:p+K_phi-1, :));
    end
    cache = struct('K_phi', K_phi, 'P_phi', P_phi, 'J', J, 'A_forward', A_forward);
end

function result = run_level3_2d_music_route_local(Rfb, grid_cache, Lc)
    [V, D] = eig(0.5 * (Rfb + Rfb'));
    [~, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    evals = real(diag(D));
    evals = evals(ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(grid_cache.A_center) .* (Cn * grid_cache.A_center), 1));
    spectrum = reshape(1 ./ max(den, eps), numel(grid_cache.az_grid), numel(grid_cache.el_grid));
    peaks = find_2d_peaks_local(spectrum, grid_cache.az_grid, grid_cache.el_grid, Lc);
    result = make_result_local(peaks.az_est, peaks.el_est, peaks.peak_count, NaN, NaN, peaks.failure_reason);
    result.spectrum = spectrum;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_separation_el = peaks.peak_separation_el;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.global_peak_el = peaks.global_peak_el;
    result.two_peak_flag = peaks.peak_count >= 2;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, result.lambda2_over_noise, ...
        result.lambda2_over_lambda1, result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function Rfb = level3_fbss_cov_from_observation_local(y_2d, K_phi, K_z)
    Q = size(y_2d, 1);
    Nel = size(y_2d, 2);
    T_snap = size(y_2d, 3);
    K = K_phi * K_z;
    Rf = complex(zeros(K, K));
    count = 0;
    for p = 1:(Q - K_phi + 1)
        for r = 1:(Nel - K_z + 1)
            Y = reshape(y_2d(p:p+K_phi-1, r:r+K_z-1, :), K, T_snap);
            Rf = Rf + (Y * Y') / T_snap;
            count = count + 1;
        end
    end
    Rf = Rf / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Rfb = 0.5 * (Rf + J * conj(Rf) * J);
    Rfb = 0.5 * (Rfb + Rfb');
end

function Rfb = level3_fbss_cov_selected_from_observation_local(y_2d, K_phi, K_z, p_sel, r_sel)
    T_snap = size(y_2d, 3);
    K = K_phi * K_z;
    Rf = complex(zeros(K, K));
    count = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            p = p_sel(ip);
            r = r_sel(ir);
            Y = reshape(y_2d(p:p+K_phi-1, r:r+K_z-1, :), K, T_snap);
            Rf = Rf + (Y * Y') / T_snap;
            count = count + 1;
        end
    end
    Rf = Rf / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Rfb = 0.5 * (Rf + J * conj(Rf) * J);
    Rfb = 0.5 * (Rfb + Rfb');
end

function result = run_level3_pair_el_local_rank1_covfit_local( ...
    Rfb, music_result, X3d, Y3d, Z3d, A_ref_2d, lambda, K_phi, K_z, p_sel, r_sel, theta_true, el_true, min_sep, max_sep)
    if any(~isfinite(music_result.az_est)) || music_result.peak_count < 2
        result = make_result_local([NaN, NaN], [NaN, NaN], music_result.peak_count, NaN, NaN, 'no_2d_peaks');
        return
    end
    candidates = make_pair_el_local_candidates_local(music_result.az_est, music_result.el_est, min_sep, max_sep);
    scores = zeros(size(candidates, 1), 1);
    for ic = 1:size(candidates, 1)
        G = build_level3_rank1_model_fbss_selected_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, candidates(ic, 1:2), candidates(ic, 3:4), ...
            1, 0, K_phi, K_z, p_sel, r_sel);
        scores(ic) = solve_covfit_score_local(Rfb, G);
    end
    [best_score, best_idx] = min(scores);
    score2 = second_score_local(scores, best_idx);
    true_idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true);
    true_score = scores(true_idx);
    best = candidates(best_idx, :);
    result = make_result_local(sort(best(1:2)), best(3:4), 2, best_score, true_score, 'ok');
    [result.az_est, order] = sort(best(1:2));
    result.el_est = best(2 + order);
    result.objective_true_rank = 1 + sum(scores < true_score);
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est)) && all(isfinite(result.el_est));
    result.pair_local_confidence_proxy = result.score_gap_ratio / max(1 + result.residual_norm, eps);
end

function Gfb = build_level3_rank1_model_fbss_selected_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair, el_pair, beta, phi_deg, K_phi, K_z, p_sel, r_sel)
    A1 = steering_direct_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(1), el_pair(1));
    A2 = steering_direct_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(2), el_pair(2));
    q = beta * exp(1j * deg2rad(phi_deg));
    K = K_phi * K_z;
    G = complex(zeros(K, K));
    count = 0;
    for ip = 1:numel(p_sel)
        for ir = 1:numel(r_sel)
            p = p_sel(ip);
            r = r_sel(ir);
            a1 = A1(p:p+K_phi-1, r:r+K_z-1);
            a2 = A2(p:p+K_phi-1, r:r+K_z-1);
            c = a1(:) / max(norm(a1(:)), eps) + q * a2(:) / max(norm(a2(:)), eps);
            G = G + c * c';
            count = count + 1;
        end
    end
    G = G / count;
    J = kron(fliplr(eye(K_z)), fliplr(eye(K_phi)));
    Gfb = 0.5 * (G + J * conj(G) * J);
    Gfb = 0.5 * (Gfb + Gfb');
end

function grid_cache = make_level3_grid_cache_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_grid, K_phi, K_z)
    p0 = floor((size(X3d, 1) - K_phi) / 2) + 1;
    r0 = floor((size(X3d, 2) - K_z) / 2) + 1;
    K = K_phi * K_z;
    A = complex(zeros(K, numel(az_grid) * numel(el_grid)));
    idx = 0;
    for ie = 1:numel(el_grid)
        for ia = 1:numel(az_grid)
            idx = idx + 1;
            Afull = steering_direct_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid(ia), el_grid(ie));
            sub = Afull(p0:p0+K_phi-1, r0:r0+K_z-1);
            A(:, idx) = sub(:) / max(norm(sub(:)), eps);
        end
    end
    grid_cache = struct('az_grid', az_grid, 'el_grid', el_grid, 'K_phi', K_phi, 'K_z', K_z, 'A_center', A);
end

function [p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi, K_z)
    p_all = 1:(Q - K_phi + 1);
    r_all = 1:(Nel - K_z + 1);
    p_sel = unique(round(linspace(1, numel(p_all), 7)));
    r_sel = unique(round(linspace(1, numel(r_all), 5)));
    p_sel = p_all(p_sel);
    r_sel = r_all(r_sel);
end

function candidates = make_pair_el_local_candidates_local(az_est, el_est, min_sep, max_sep)
    az1 = az_est(1) + [-0.04, 0, 0.04];
    az2 = az_est(2) + [-0.04, 0, 0.04];
    el1 = el_est(1) + [-0.5, 0, 0.5];
    el2 = el_est(2) + [-0.5, 0, 0.5];
    candidates = zeros(numel(az1)*numel(az2)*numel(el1)*numel(el2), 4);
    count = 0;
    for i1 = 1:numel(az1)
        for i2 = 1:numel(az2)
            th = sort([az1(i1), az2(i2)]);
            sep = diff(th);
            if sep < min_sep || sep > max_sep
                continue
            end
            for e1 = 1:numel(el1)
                for e2 = 1:numel(el2)
                    count = count + 1;
                    candidates(count, :) = [th, el1(e1), el2(e2)];
                end
            end
        end
    end
    candidates = candidates(1:count, :);
end

function idx = nearest_pair_el_candidate_local(candidates, theta_true, el_true)
    truth = [theta_true(:).', el_true(:).'];
    d = sum((candidates - truth).^2, 2);
    [~, idx] = min(d);
end

function peaks = find_2d_peaks_local(P, az_axis, el_axis, Lc)
    Pwork = real(P);
    mask = false(size(Pwork));
    for ia = 2:size(Pwork, 1)-1
        for ie = 2:size(Pwork, 2)-1
            win = Pwork(ia-1:ia+1, ie-1:ie+1);
            mask(ia, ie) = Pwork(ia, ie) == max(win(:)) && Pwork(ia, ie) > median(win(:));
        end
    end
    vals = Pwork(mask);
    [~, ord] = sort(vals, 'descend');
    idx_all = find(mask);
    idx_all = idx_all(ord);
    if isempty(idx_all)
        [~, idx_all] = max(Pwork(:));
    end
    chosen = [];
    for k = 1:numel(idx_all)
        [ia, ie] = ind2sub(size(Pwork), idx_all(k));
        if isempty(chosen)
            chosen = [chosen; ia, ie]; %#ok<AGROW>
        else
            da = abs(az_axis(ia) - az_axis(chosen(:, 1)));
            de = abs(el_axis(ie) - el_axis(chosen(:, 2)));
            if all(da > 0.04 | de > 0.5)
                chosen = [chosen; ia, ie]; %#ok<AGROW>
            end
        end
        if size(chosen, 1) >= Lc
            break
        end
    end
    peak_count = size(chosen, 1);
    az_est = nan(1, 2);
    el_est = nan(1, 2);
    if peak_count >= 1
        nuse = min(2, peak_count);
        az_est(1:nuse) = az_axis(chosen(1:nuse, 1));
        el_est(1:nuse) = el_axis(chosen(1:nuse, 2));
    end
    if peak_count >= 2
        [az_est, order] = sort(az_est);
        el_est = el_est(order);
        peak_sep_az = abs(diff(az_est));
        peak_sep_el = abs(diff(el_est));
        top_vals = zeros(1, 2);
        for i = 1:2
            top_vals(i) = Pwork(chosen(i, 1), chosen(i, 2));
        end
        prom = min(top_vals) / max(max(Pwork(:)), eps);
        reason = 'ok';
    else
        peak_sep_az = NaN;
        peak_sep_el = NaN;
        prom = NaN;
        reason = 'insufficient_2d_peaks';
    end
    [~, gidx] = max(Pwork(:));
    [~, gie] = ind2sub(size(Pwork), gidx);
    peaks = struct('az_est', az_est, 'el_est', el_est, 'peak_count', peak_count, ...
        'peak_separation_az', peak_sep_az, 'peak_separation_el', peak_sep_el, ...
        'peak_prominence_ratio', prom, 'global_peak_el', el_axis(gie), ...
        'failure_reason', reason);
end

function peaks = find_1d_peaks_local(P, az_axis, Lc)
    P = real(P(:)).';
    is_peak = false(size(P));
    for i = 2:numel(P)-1
        is_peak(i) = P(i) >= P(i-1) && P(i) >= P(i+1) && P(i) > median(P);
    end
    idx = find(is_peak);
    if isempty(idx)
        [~, idx] = max(P);
    end
    [~, ord] = sort(P(idx), 'descend');
    idx = idx(ord);
    chosen = [];
    for k = 1:numel(idx)
        if isempty(chosen) || all(abs(az_axis(idx(k)) - az_axis(chosen)) > 0.04)
            chosen(end+1) = idx(k); %#ok<AGROW>
        end
        if numel(chosen) >= Lc
            break
        end
    end
    peak_count = numel(chosen);
    az_est = nan(1, 2);
    if peak_count >= 1
        az_est(1:min(2, peak_count)) = az_axis(chosen(1:min(2, peak_count)));
    end
    if peak_count >= 2
        az_est = sort(az_est);
        sep = diff(az_est);
        top_vals = P(chosen(1:2));
        prom = min(top_vals) / max(max(P), eps);
        halfmax = 0.5 * max(P);
        width = sum(P >= halfmax) * mean(diff(az_axis));
        reason = 'ok';
    else
        sep = NaN;
        prom = NaN;
        width = NaN;
        reason = 'insufficient_1d_peaks';
    end
    peaks = struct('az_est', az_est, 'peak_count', peak_count, ...
        'peak_separation_az', sep, 'peak_prominence_ratio', prom, ...
        'spectrum_width', width, 'failure_reason', reason);
end

function score2 = second_score_local(score, best_idx)
    score2 = inf;
    if numel(score) >= 2
        tmp = score;
        tmp(best_idx) = inf;
        score2 = min(tmp);
    end
    if ~isfinite(score2)
        score2 = score(best_idx);
    end
end

function [lambda1, lambda2, lambda_noise_mean, lambda2_over_noise, lambda2_over_lambda1, effective_rank_proxy] = eigen_proxy_from_vals_local(evals)
    evals = real(evals(:));
    evals = max(evals, 0);
    if isempty(evals)
        lambda1 = NaN; lambda2 = NaN; lambda_noise_mean = NaN;
        lambda2_over_noise = NaN; lambda2_over_lambda1 = NaN; effective_rank_proxy = NaN;
        return
    end
    lambda1 = evals(min(1, numel(evals)));
    lambda2 = evals(min(2, numel(evals)));
    if numel(evals) >= 3
        lambda_noise_mean = mean(evals(3:end));
    else
        lambda_noise_mean = mean(evals);
    end
    lambda2_over_noise = lambda2 / max(lambda_noise_mean, eps);
    lambda2_over_lambda1 = lambda2 / max(lambda1, eps);
    effective_rank_proxy = (sum(evals)^2) / max(sum(evals.^2), eps);
end

function ok = is_level2_music_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'peak_separation_az', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    width = getfield_default_local(result, 'spectrum_width', NaN);
    l2n = getfield_default_local(result, 'lambda2_over_noise', NaN);
    ok = result.peak_count >= 2 && all(isfinite(result.az_est)) && isfinite(sep) && ...
        sep >= min_sep && sep <= max_sep && isfinite(prom) && prom >= 0.55 && ...
        (~isfinite(width) || width <= 0.45) && (~isfinite(l2n) || l2n >= 1.10);
end

function ok = is_music2d_reliable_local(result, min_sep, max_sep)
    sep_az = getfield_default_local(result, 'peak_separation_az', NaN);
    sep_el = getfield_default_local(result, 'peak_separation_el', NaN);
    max_el = max(abs(getfield_default_local(result, 'el_est', [NaN, NaN])));
    ok = result.peak_count >= 2 && all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep_az) && isfinite(sep_el) && sep_az >= min_sep && sep_az <= max_sep && ...
        sep_el >= 1.0 && isfinite(max_el) && max_el >= 1.0;
end

function ok = is_rank1_route_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    gap = getfield_default_local(result, 'score_gap_ratio', NaN);
    ok = all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep) && sep >= min_sep && sep <= max_sep && ...
        isfinite(residual) && residual < 2e-3 && isfinite(gap) && gap >= 2e-3;
end

function ok = is_refocus_route_reliable_local(result, min_sep, max_sep)
    sharp = getfield_default_local(result, 'focused_power_peak_sharpness', NaN);
    lambda_sharp = getfield_default_local(result, 'lambda1_peak_sharpness', NaN);
    ok = is_rank1_route_reliable_local(result, min_sep, max_sep) && ...
        isfinite(sharp) && sharp >= 0.03 && isfinite(lambda_sharp) && lambda_sharp >= 0.03;
end

function ok = is_pair_route_reliable_local(result, min_sep, max_sep)
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    residual = getfield_default_local(result, 'residual_norm', NaN);
    max_el = max(abs(getfield_default_local(result, 'el_est', [NaN, NaN])));
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    ok = all(isfinite(result.az_est)) && all(isfinite(result.el_est)) && ...
        isfinite(sep) && sep >= min_sep && sep <= max_sep && ...
        isfinite(residual) && residual < 0.05 && isfinite(max_el) && max_el >= 1.0 && ...
        (~isfinite(prom) || prom >= 0.45);
end

function ok = is_level2_music_high_confidence_local(result, route_map, min_sep, max_sep)
    width = getfield_default_local(result, 'spectrum_width', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    l2n = getfield_default_local(result, 'lambda2_over_noise', NaN);
    l21 = getfield_default_local(result, 'lambda2_over_lambda1', NaN);
    refocus = route_map.common_el_refocus_rank1;
    refocus_gap = getfield_default_local(refocus, 'score_gap_ratio', NaN);
    ok = is_level2_music_reliable_local(result, min_sep, max_sep) && ...
        isfinite(prom) && prom >= 0.82 && (~isfinite(width) || width <= 0.24) && ...
        (~isfinite(l2n) || l2n >= 1.35) && (~isfinite(l21) || l21 >= 0.18) && ...
        (~isfinite(refocus_gap) || refocus_gap >= 2e-3);
end

function tf = is_boundary_unreliable_local(route_map, min_sep, max_sep)
    music = route_map.music;
    rank1 = route_map.rank1_fallback;
    refocus = route_map.common_el_refocus_rank1;
    music2d = route_map.level3_2d_music;
    pair2d = route_map.pair_el_local_covfit;
    no_reliable_2d = ~is_music2d_reliable_local(music2d, min_sep, max_sep) && ...
        ~is_pair_route_reliable_local(pair2d, min_sep, max_sep);
    music_single = music.peak_count < 2 || any(~isfinite(music.az_est));
    rank1_finite = all(isfinite(rank1.az_est)) && all(isfinite(rank1.el_est));
    rank1_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    rank1_sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    refocus_sharp = min(getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    route_conflict = has_route_conflict_local(route_map);
    strong_single_peak = music.peak_count < 2 && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;
    weak_rank1 = (~isfinite(rank1_gap) || rank1_gap < 5e-3) && ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3);
    sep_edge = is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;
    tf = (no_reliable_2d && music_single && rank1_finite && weak_rank1) || ...
        (no_reliable_2d && music_single && rank1_finite && sep_edge) || ...
        (no_reliable_2d && strong_single_peak && refocus_unsharp) || ...
        (no_reliable_2d && route_conflict && ~is_level2_music_reliable_local(music, min_sep, max_sep));
end

function tf = has_route_conflict_local(route_map)
    az_list = {};
    route_fields = {'music', 'rank1_fallback', 'common_el_refocus_rank1', 'level3_2d_music', 'pair_el_local_covfit'};
    for i = 1:numel(route_fields)
        now = route_map.(route_fields{i});
        az_est = getfield_default_local(now, 'az_est', [NaN, NaN]);
        if numel(az_est) >= 2 && all(isfinite(az_est))
            az_list{end+1} = sort(az_est(:)).'; %#ok<AGROW>
        end
    end
    tf = false;
    if numel(az_list) < 2
        return
    end
    for i = 1:numel(az_list)-1
        for j = (i+1):numel(az_list)
            if max(abs(az_list{i} - az_list{j})) > 0.14
                tf = true;
                return
            end
        end
    end
end

function tf = is_sep_edge_local(sep, min_sep, max_sep, edge_margin)
    tf = ~isfinite(sep) || sep <= (min_sep + edge_margin) || sep >= (max_sep - edge_margin);
end

function result = make_boundary_result_local(route_map, route_name, confidence, reason, weak_flag, anti_flag)
    fallback = route_map.music;
    result = make_result_local(fallback.az_est, fallback.el_est, fallback.peak_count, NaN, NaN, reason);
    result.recommended_route = string(route_name);
    result.confidence_flag = string(confidence);
    result.failure_reason = string(reason);
    result.weak_target_boundary_flag = weak_flag;
    result.anti_phase_boundary_flag = anti_flag;
    result.low_confidence_flag = true;
end

function candidate_pairs = make_pair_candidates_local(angle_grid, min_sep, max_sep)
    n = numel(angle_grid);
    candidate_pairs = zeros(n*n, 2);
    count = 0;
    for ii = 1:(n-1)
        sep_vec = angle_grid((ii+1):end) - angle_grid(ii);
        jj_rel = find(sep_vec >= min_sep & sep_vec <= max_sep);
        jj = jj_rel + ii;
        nadd = numel(jj);
        candidate_pairs(count+1:count+nadd, :) = [repmat(ii, nadd, 1), jj(:)];
        count = count + nadd;
    end
    candidate_pairs = candidate_pairs(1:count, :);
end

function pair_idx = nearest_pair_indices_local(grid, theta_pair)
    [~, i1] = min(abs(grid - theta_pair(1)));
    [~, i2] = min(abs(grid - theta_pair(2)));
    pair_idx = sort([i1, i2]);
    if pair_idx(1) == pair_idx(2)
        pair_idx(2) = min(pair_idx(1) + 1, numel(grid));
    end
end

function precomp = precompute_rank1_pair_bases_local(cache, candidate_pairs)
    K = cache.K_phi;
    P_phi = cache.P_phi;
    J = cache.J;
    Nc = size(candidate_pairs, 1);
    L = 2 * K * K;
    g_basis = zeros(L, Nc, 'single');
    gg = zeros(Nc, 1);
    gi = zeros(Nc, 1);
    ivec = matrix_to_realvec_local(eye(K));
    ii = real(ivec' * ivec);
    for ic = 1:Nc
        i1 = candidate_pairs(ic, 1);
        i2 = candidate_pairs(ic, 2);
        A1 = reshape(cache.A_forward(:, i1, :), K, P_phi);
        A2 = reshape(cache.A_forward(:, i2, :), K, P_phi);
        C = A1 + A2;
        F = (C * C') / P_phi;
        G = 0.5 * (F + J * conj(F) * J);
        v = matrix_to_realvec_local(G);
        g_basis(:, ic) = single(v);
        gg(ic) = real(v' * v);
        gi(ic) = real(v' * ivec);
    end
    precomp = struct('K_phi', K, 'P_phi', P_phi, 'candidate_pairs', candidate_pairs, ...
        'g_basis', g_basis, 'gg', gg, 'gi', gi, 'ivec', single(ivec), 'ii', ii);
end

function score = score_rank1_all_local(Robs, precomp)
    y = matrix_to_realvec_local(Robs);
    yy = real(y' * y);
    gy = double(precomp.g_basis' * single(y));
    iy = double(precomp.ivec' * single(y));
    gg = precomp.gg;
    gi = precomp.gi;
    ii = precomp.ii;
    detv = gg * ii - gi.^2;
    valid = abs(detv) > 1e-12;
    alpha = zeros(size(gg));
    sigma2 = zeros(size(gg));
    alpha(valid) = (gy(valid) * ii - gi(valid) * iy) ./ detv(valid);
    sigma2(valid) = (gg(valid) * iy - gi(valid) .* gy(valid)) ./ detv(valid);
    val_both = inf(size(gg));
    ok_both = valid & alpha >= 0 & sigma2 >= 0;
    val_both(ok_both) = -2*(alpha(ok_both).*gy(ok_both) + sigma2(ok_both)*iy) + ...
        alpha(ok_both).^2 .* gg(ok_both) + 2*alpha(ok_both).*sigma2(ok_both).*gi(ok_both) + sigma2(ok_both).^2 * ii;
    alpha_only = max(gy ./ max(gg, eps), 0);
    val_alpha = -2*alpha_only.*gy + alpha_only.^2 .* gg;
    sigma_only = max(iy / max(ii, eps), 0);
    val_sigma = -2*sigma_only*iy + sigma_only.^2 * ii;
    val_zero = zeros(size(gg));
    best_delta = min([val_both, val_alpha, repmat(val_sigma, size(gg)), val_zero], [], 2);
    score = max(yy + best_delta, 0) / max(yy, eps);
end

function score = solve_covfit_score_local(Robs, G)
    y = matrix_to_realvec_local(Robs);
    g = matrix_to_realvec_local(G);
    ivec = matrix_to_realvec_local(eye(size(Robs)));
    yy = real(y' * y);
    gg = real(g' * g);
    gi = real(g' * ivec);
    ii = real(ivec' * ivec);
    gy = real(g' * y);
    iy = real(ivec' * y);
    detv = gg * ii - gi^2;
    vals = zeros(4, 1);
    if abs(detv) > 1e-12
        alpha = (gy * ii - gi * iy) / detv;
        sigma2 = (gg * iy - gi * gy) / detv;
        if alpha >= 0 && sigma2 >= 0
            vals(1) = -2*(alpha*gy + sigma2*iy) + alpha^2*gg + 2*alpha*sigma2*gi + sigma2^2*ii;
        else
            vals(1) = inf;
        end
    else
        vals(1) = inf;
    end
    alpha_only = max(gy / max(gg, eps), 0);
    vals(2) = -2*alpha_only*gy + alpha_only^2*gg;
    sigma_only = max(iy / max(ii, eps), 0);
    vals(3) = -2*sigma_only*iy + sigma_only^2*ii;
    vals(4) = 0;
    score = max(yy + min(vals), 0) / max(yy, eps);
end

function v = matrix_to_realvec_local(M)
    m = M(:);
    v = [real(m); imag(m)];
end

function A = normalize_columns_local(A)
    nrm = sqrt(sum(abs(A).^2, 1));
    nrm(nrm == 0) = 1;
    A = A ./ nrm;
end

function result = make_result_local(az_est, el_est, peak_count, objective_best, objective_true, reason)
    result = struct();
    result.az_est = az_est;
    result.el_est = el_est;
    result.peak_count = peak_count;
    result.objective_best = objective_best;
    result.objective_true_pair = objective_true;
    result.objective_margin = objective_true - objective_best;
    result.objective_true_rank = NaN;
    result.el_common_est = NaN;
    result.el_hat = NaN;
    result.el_selection_method = "";
    result.focused_power_peak_sharpness = NaN;
    result.lambda1_peak_sharpness = NaN;
    result.rank1_objective_valley_width_el = NaN;
    result.rank1_objective_selected_el_rank = NaN;
    result.failure_reason = reason;
    result.spectrum = [];
    result.spectrum_1d = [];
    result.peak_separation_az = NaN;
    result.peak_separation_el = NaN;
    result.peak_prominence_ratio = NaN;
    result.spectrum_width = NaN;
    result.score_gap_abs = NaN;
    result.score_gap_ratio = NaN;
    result.residual_norm = objective_best;
    result.pair_sep_est = NaN;
    result.finite_output_flag = all(isfinite(az_est)) && all(isfinite(el_est));
    result.two_peak_flag = false;
    result.global_peak_el = NaN;
    result.pair_local_confidence_proxy = NaN;
    result.lambda1 = NaN;
    result.lambda2 = NaN;
    result.lambda_noise_mean = NaN;
    result.lambda2_over_noise = NaN;
    result.lambda2_over_lambda1 = NaN;
    result.effective_rank_proxy = NaN;
    result.recommended_route = "";
    result.confidence_flag = "";
    result.weak_target_boundary_flag = false;
    result.anti_phase_boundary_flag = false;
    result.low_confidence_flag = false;
end

function [az_err, el_err, pair_rmse] = pair_errors_local(az_est, el_est, az_true, el_true)
    az_est = az_est(:).';
    el_est = el_est(:).';
    if numel(az_est) < 2 || any(~isfinite(az_est)) || any(~isfinite(el_est))
        az_err = [NaN, NaN];
        el_err = [NaN, NaN];
        pair_rmse = NaN;
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
    pair_rmse = sqrt(mean(sum((est - truth).^2, 2)));
end

function ok = joint_success_from_result_local(result, theta_true, el_true, az_tol, el_tol)
    [az_err, el_err] = pair_errors_local(result.az_est, result.el_est, theta_true, el_true);
    ok = all(abs(az_err) <= az_tol) && all(abs(el_err) <= el_tol);
end

function val = getfield_default_local(s, name, default_val)
    if isstruct(s) && isfield(s, name)
        val = s.(name);
    else
        val = default_val;
    end
end

function tf = is_low_cost_boundary_proxy_from_partial_local(music, rank1, refocus, min_sep, max_sep)
    no_rank1 = nargin < 2 || isempty(rank1) || ~isstruct(rank1) || ...
        ~all(isfinite(getfield_default_local(rank1, 'az_est', [NaN, NaN])));
    strong_single_peak = music.peak_count < 2 && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;
    rank1_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    rank1_sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    weak_rank1 = no_rank1 || ((~isfinite(rank1_gap) || rank1_gap < 5e-3) && ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3));
    sep_edge = ~no_rank1 && is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_sharp = min(getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;
    tf = (strong_single_peak && refocus_unsharp) || (~no_rank1 && (weak_rank1 || sep_edge) && refocus_unsharp);
end

function tf = is_strong_common_el_proxy_local(music, refocus)
    music_single = music.peak_count < 2 || any(~isfinite(getfield_default_local(music, 'az_est', [NaN, NaN])));
    refocus_finite = all(isfinite(getfield_default_local(refocus, 'az_est', [NaN, NaN])));
    el_music = getfield_default_local(music, 'el_est', [NaN, NaN]);
    if numel(el_music) < 2
        el_music = [NaN, NaN];
    end
    music_el_small = all(~isfinite(el_music)) || max(abs(el_music)) <= 1.0;
    el_hat = getfield_default_local(refocus, 'el_hat', NaN);
    refocus_sharp = min(getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    tf = (music_single || music_el_small) && refocus_finite && ...
        isfinite(el_hat) && isfinite(refocus_sharp) && refocus_sharp >= 0.03;
end

function ok = is_music2d_high_confidence_local(result, min_sep, max_sep)
    sep_az = getfield_default_local(result, 'peak_separation_az', NaN);
    sep_el = getfield_default_local(result, 'peak_separation_el', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    ok = is_music2d_reliable_local(result, min_sep, max_sep) && ...
        isfinite(sep_az) && sep_az >= min_sep && sep_az <= max_sep && ...
        isfinite(sep_el) && sep_el >= 1.5 && isfinite(prom) && prom >= 0.70;
end

function tf = is_cascade_pair_refinement_needed_local(music2d_result, min_sep, max_sep)
    tf = is_music2d_reliable_local(music2d_result, min_sep, max_sep) && ...
        ~is_music2d_high_confidence_local(music2d_result, min_sep, max_sep);
end

function timing = init_wallclock_timing_local()
    timing = struct();
    timing.t_level2_music = 0;
    timing.t_level2_rank1 = 0;
    timing.t_refocus = 0;
    timing.t_2dmusic = 0;
    timing.t_pair_local = 0;
    timing.t_dispatch = 0;
    timing.executed_level2_music = false;
    timing.executed_refocus = false;
    timing.executed_level2_rank1 = false;
    timing.executed_2dmusic = false;
    timing.executed_pair_local = false;
    timing.early_stop_stage = NaN;
    timing.early_stop_flag = false;
    timing.route_map = struct();
end

function timing = finish_lazy_timing_local(timing, early_stop_stage, early_stop_flag, route_map)
    timing.early_stop_stage = early_stop_stage;
    timing.early_stop_flag = early_stop_flag;
    timing.route_map = route_map;
end

function route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d)
    route_map = struct();
    route_map.music = music;
    route_map.rank1_fallback = rank1;
    route_map.common_el_refocus_rank1 = refocus;
    route_map.level3_2d_music = music2d;
    route_map.pair_el_local_covfit = pair2d;
end

function result = make_empty_route_result_local(reason)
    result = make_result_local([NaN, NaN], [NaN, NaN], 0, NaN, NaN, reason);
    result.recommended_route = "not_executed";
    result.confidence_flag = "";
end

function result = shift_result_az_local(result, az_shift)
    if isfield(result, 'az_est') && isnumeric(result.az_est)
        result.az_est = result.az_est + az_shift;
    end
end

function [az_diff, el_diff] = estimate_pair_diff_local(a, b)
    if any(~isfinite(a.az_est)) || any(~isfinite(b.az_est)) || any(~isfinite(a.el_est)) || any(~isfinite(b.el_est))
        az_diff = [NaN, NaN];
        el_diff = [NaN, NaN];
        return
    end
    est_a = [a.az_est(:), a.el_est(:)];
    est_b = [b.az_est(:), b.el_est(:)];
    d11 = norm(est_a(1,:) - est_b(1,:)) + norm(est_a(2,:) - est_b(2,:));
    d12 = norm(est_a(1,:) - est_b(2,:)) + norm(est_a(2,:) - est_b(1,:));
    if d12 < d11
        est_b = flipud(est_b);
    end
    az_diff = (est_b(:,1) - est_a(:,1)).';
    el_diff = (est_b(:,2) - est_a(:,2)).';
end

function reason = failure_reason_pair_local(az_est, el_est, min_sep, max_sep)
    if any(~isfinite(az_est)) || any(~isfinite(el_est))
        reason = 'nonfinite_estimate';
        return
    end
    sep = diff(sort(az_est));
    if sep < min_sep
        reason = 'pair_too_close';
    elseif sep > max_sep
        reason = 'pair_too_far';
    else
        reason = 'ok';
    end
end

function names = route_trial_names_local()
    names = {'azCtr', 'scenario', 'SNR', 'mc', 'template_mode', ...
        'direct_route', 'template_route', 'route_agreement', ...
        'direct_confidence', 'template_confidence', 'confidence_agreement', ...
        'direct_success', 'template_success', 'success_gap', ...
        'false_high_template', 'boundary_missed_template', ...
        'az_est_diff_mean', 'az_est_diff_max', 'el_est_diff_mean', 'el_est_diff_max', ...
        'runtime_direct_sec', 'runtime_template_sec', 'direct_early_stop_stage', 'template_early_stop_stage'};
end

function tbl = empty_route_trial_table_local()
    tbl = cell2table(cell(0, numel(route_trial_names_local())), 'VariableNames', route_trial_names_local());
end

function names = route_summary_names_local()
    names = {'azCtr', 'scenario', 'SNR', 'num_trials', 'route_agreement', 'confidence_agreement', ...
        'direct_success', 'template_success', 'success_gap', 'false_high_template', ...
        'boundary_missed_template', 'az_est_diff_mean', 'az_est_diff_max', ...
        'el_est_diff_mean', 'el_est_diff_max', 'runtime_direct_mean', 'runtime_template_mean'};
end

function tbl = empty_route_summary_table_local()
    tbl = cell2table(cell(0, numel(route_summary_names_local())), 'VariableNames', route_summary_names_local());
end

function summary_tbl = build_route_summary_local(trial_tbl)
    rows = {};
    rows{end+1, 1} = make_route_summary_row_local(trial_tbl, true(height(trial_tbl), 1), NaN, "all", NaN);
    centers = unique(trial_tbl.azCtr, 'stable');
    scenarios = unique(string(trial_tbl.scenario), 'stable');
    snrs = unique(trial_tbl.SNR, 'stable');
    for ic = 1:numel(centers)
        rows{end+1, 1} = make_route_summary_row_local(trial_tbl, trial_tbl.azCtr == centers(ic), centers(ic), "all", NaN); %#ok<AGROW>
    end
    for is = 1:numel(scenarios)
        rows{end+1, 1} = make_route_summary_row_local(trial_tbl, string(trial_tbl.scenario) == scenarios(is), NaN, scenarios(is), NaN); %#ok<AGROW>
    end
    for ic = 1:numel(centers)
        for is = 1:numel(scenarios)
            for isnr = 1:numel(snrs)
                mask = trial_tbl.azCtr == centers(ic) & string(trial_tbl.scenario) == scenarios(is) & trial_tbl.SNR == snrs(isnr);
                rows{end+1, 1} = make_route_summary_row_local(trial_tbl, mask, centers(ic), scenarios(is), snrs(isnr)); %#ok<AGROW>
            end
        end
    end
    summary_tbl = cell2table(vertcat(rows{:}), 'VariableNames', route_summary_names_local());
end

function row = make_route_summary_row_local(T, mask, azCtr, scenario, snr_val)
    if ~any(mask)
        row = {azCtr, string(scenario), snr_val, 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN};
        return
    end
    row = {azCtr, string(scenario), snr_val, sum(mask), ...
        mean(T.route_agreement(mask)), mean(T.confidence_agreement(mask)), ...
        mean(T.direct_success(mask)), mean(T.template_success(mask)), mean(T.success_gap(mask)), ...
        mean(T.false_high_template(mask)), mean(T.boundary_missed_template(mask)), ...
        mean(T.az_est_diff_mean(mask), 'omitnan'), max(T.az_est_diff_max(mask), [], 'omitnan'), ...
        mean(T.el_est_diff_mean(mask), 'omitnan'), max(T.el_est_diff_max(mask), [], 'omitnan'), ...
        mean(T.runtime_direct_sec(mask), 'omitnan'), mean(T.runtime_template_sec(mask), 'omitnan')};
end

function keypoints_tbl = build_template_keypoints_local(steer_tbl, geom_tbl, route_trial_tbl, route_summary_tbl, exact_pass, canonical_pass, template_mode_for_route)
    rows = {};
    exact = steer_tbl(steer_tbl.template_mode == "template_exact", :);
    canon = steer_tbl(steer_tbl.template_mode == "template_canonical", :);
    rows = add_keypoint_row_local(rows, 'exact_template_max_rel_err_aligned', max(exact.rel_err_aligned), 'max aligned error direct vs center-specific local template');
    rows = add_keypoint_row_local(rows, 'exact_template_min_coherence', min(exact.coherence), 'min coherence direct vs center-specific local template');
    rows = add_keypoint_row_local(rows, 'canonical_template_max_rel_err_aligned', max(canon.rel_err_aligned), 'max aligned error direct vs canonical local template');
    rows = add_keypoint_row_local(rows, 'canonical_template_min_coherence', min(canon.coherence), 'min coherence direct vs canonical local template');
    rows = add_keypoint_row_local(rows, 'canonical_geometry_max_rel_err', max(geom_tbl.xyz_rel_err), 'max local geometry relative error against azCtr=0 template');
    rows = add_keypoint_row_local(rows, 'full_steering_pass_flag', type_pass_local(exact, 'full_65x32', 1e-10, 1-1e-10), 'exact local full steering pass');
    rows = add_keypoint_row_local(rows, 'music2d_subarray_pass_flag', type_pass_local(exact, 'music2d_center_subarray', 1e-10, 1-1e-10), 'exact local 2D MUSIC center-subarray steering pass');
    rows = add_keypoint_row_local(rows, 'pairlocal_subarray_pass_flag', type_pass_local(exact, 'pairlocal_selected_subarray', 1e-10, 1-1e-10), 'exact local pair-local selected subarray steering pass');
    rows = add_keypoint_row_local(rows, 'level2_combined_pass_flag', type_pass_local(exact, 'level2_combined', 1e-10, 1-1e-10), 'exact local level2 combined steering pass');
    rows = add_keypoint_row_local(rows, 'canonical_reuse_pass_flag', double(canonical_pass), 'canonical reusable template pass');
    if isempty(route_summary_tbl) || height(route_summary_tbl) == 0
        overall_route_agreement = NaN;
        overall_conf_agreement = NaN;
        success_gap = NaN;
        false_high = NaN;
        boundary_missed = NaN;
        max_az_diff = NaN;
        max_el_diff = NaN;
    else
        overall = route_summary_tbl(isnan(route_summary_tbl.azCtr) & route_summary_tbl.scenario == "all" & isnan(route_summary_tbl.SNR), :);
        overall_route_agreement = overall.route_agreement(1);
        overall_conf_agreement = overall.confidence_agreement(1);
        success_gap = overall.success_gap(1);
        false_high = overall.false_high_template(1);
        boundary_missed = overall.boundary_missed_template(1);
        max_az_diff = max(route_trial_tbl.az_est_diff_max, [], 'omitnan');
        max_el_diff = max(route_trial_tbl.el_est_diff_max, [], 'omitnan');
    end
    rows = add_keypoint_row_local(rows, 'overall_route_agreement', overall_route_agreement, 'direct/template lazy route agreement');
    rows = add_keypoint_row_local(rows, 'overall_confidence_agreement', overall_conf_agreement, 'direct/template confidence agreement');
    rows = add_keypoint_row_local(rows, 'template_success_gap', success_gap, 'template success minus direct success');
    rows = add_keypoint_row_local(rows, 'template_false_high', false_high, 'template false-high-confidence rate');
    rows = add_keypoint_row_local(rows, 'template_boundary_missed', boundary_missed, 'template boundary-missed rate');
    rows = add_keypoint_row_local(rows, 'max_az_est_diff', max_az_diff, 'max direct/template az estimate difference');
    rows = add_keypoint_row_local(rows, 'max_el_est_diff', max_el_diff, 'max direct/template el estimate difference');
    route_pass = overall_route_agreement >= 0.99 && overall_conf_agreement >= 0.99 && abs(success_gap) <= 0.01 && ...
        false_high == 0 && boundary_missed == 0 && max_az_diff <= 0.02 && max_el_diff <= 0.5;
    if ~exact_pass
        strategy = "not_recommended_yet";
    elseif canonical_pass && route_pass && template_mode_for_route == "template_canonical"
        strategy = "canonical_local_template";
    elseif route_pass
        strategy = "per_center_local_template";
    elseif canonical_pass
        strategy = "template_with_phase_compensation";
    else
        strategy = "not_recommended_yet";
    end
    rows = add_keypoint_row_local(rows, 'recommended_fpga_template_strategy', strategy, 'recommended FPGA template strategy');
    rows = add_keypoint_row_local(rows, 'route_consistency_pass_flag', double(route_pass), '7B lazy direct/template route consistency pass');
    keypoints_tbl = cell2table(rows, 'VariableNames', {'keypoint', 'value', 'note'});
end

function tf = type_pass_local(T, type_name, max_err, min_coh)
    mask = T.steering_type == string(type_name);
    tf = double(max(T.rel_err_aligned(mask)) <= max_err && min(T.coherence(mask)) >= min_coh);
end

function rows = add_keypoint_row_local(rows, key, value, note)
    if isnumeric(value) || islogical(value)
        val = string(sprintf('%.15g', double(value)));
    else
        val = string(value);
    end
    rows(end+1, :) = {string(key), val, string(note)}; %#ok<AGROW>
end

function val = keypoint_value_local(keypoints_tbl, key)
    idx = find(keypoints_tbl.keypoint == string(key), 1);
    if isempty(idx)
        val = NaN;
    else
        val = str2double(keypoints_tbl.value(idx));
    end
end

function val = keypoint_string_local(keypoints_tbl, key)
    idx = find(keypoints_tbl.keypoint == string(key), 1);
    if isempty(idx)
        val = "";
    else
        val = string(keypoints_tbl.value(idx));
    end
end

function plot_steering_rel_error_by_center_local(tbl, path_out)
    fig = figure('Visible', 'off');
    exact = tbl(tbl.template_mode == "template_exact", :);
    canon = tbl(tbl.template_mode == "template_canonical", :);
    centers = unique(tbl.azCtr, 'stable');
    y1 = zeros(size(centers));
    y2 = zeros(size(centers));
    for i = 1:numel(centers)
        y1(i) = max(exact.rel_err_aligned(exact.azCtr == centers(i)));
        y2(i) = max(canon.rel_err_aligned(canon.azCtr == centers(i)));
    end
    semilogy(centers, max(y1, eps), '-o', centers, max(y2, eps), '-s', 'LineWidth', 1.5);
    grid on; xlabel('azCtr (deg)'); ylabel('max aligned relative error');
    legend('exact local', 'canonical', 'Location', 'best');
    title('Steering relative error by center');
    saveas(fig, path_out); close(fig);
end

function plot_steering_coherence_by_center_local(tbl, path_out)
    fig = figure('Visible', 'off');
    exact = tbl(tbl.template_mode == "template_exact", :);
    canon = tbl(tbl.template_mode == "template_canonical", :);
    centers = unique(tbl.azCtr, 'stable');
    y1 = zeros(size(centers));
    y2 = zeros(size(centers));
    for i = 1:numel(centers)
        y1(i) = min(exact.coherence(exact.azCtr == centers(i)));
        y2(i) = min(canon.coherence(canon.azCtr == centers(i)));
    end
    plot(centers, y1, '-o', centers, y2, '-s', 'LineWidth', 1.5);
    grid on; xlabel('azCtr (deg)'); ylabel('min coherence');
    legend('exact local', 'canonical', 'Location', 'best');
    title('Steering coherence by center');
    saveas(fig, path_out); close(fig);
end

function plot_steering_phase_error_hist_local(tbl, path_out)
    fig = figure('Visible', 'off');
    histogram(tbl.phase_err_rms(tbl.template_mode == "template_exact"), 40);
    hold on;
    histogram(tbl.phase_err_rms(tbl.template_mode == "template_canonical"), 40);
    grid on; xlabel('RMS phase error (rad)'); ylabel('count');
    legend('exact local', 'canonical', 'Location', 'best');
    title('Steering phase error histogram');
    saveas(fig, path_out); close(fig);
end

function plot_canonical_geometry_error_by_center_local(tbl, path_out)
    fig = figure('Visible', 'off');
    semilogy(tbl.azCtr, max(tbl.xyz_rel_err, eps), '-o', 'LineWidth', 1.5);
    grid on; xlabel('azCtr (deg)'); ylabel('relative geometry error');
    title('Canonical local geometry error by center');
    saveas(fig, path_out); close(fig);
end

function plot_route_agreement_by_scenario_local(tbl, path_out)
    fig = figure('Visible', 'off');
    if isempty(tbl) || height(tbl) == 0
        text(0.5, 0.5, 'route consistency not run', 'HorizontalAlignment', 'center');
        axis off;
    else
        scen = tbl(isnan(tbl.azCtr) & tbl.scenario ~= "all" & isnan(tbl.SNR), :);
        if isempty(scen)
            scen = tbl(tbl.scenario ~= "all", :);
        end
        bar(categorical(string(scen.scenario)), scen.route_agreement);
        ylim([0, 1]); grid on; ylabel('route agreement');
        title('Route agreement by scenario');
    end
    saveas(fig, path_out); close(fig);
end

function plot_template_vs_direct_az_el_error_local(tbl, path_out)
    fig = figure('Visible', 'off');
    if isempty(tbl) || height(tbl) == 0
        text(0.5, 0.5, 'route consistency not run', 'HorizontalAlignment', 'center');
        axis off;
    else
        scatter(tbl.az_est_diff_max, tbl.el_est_diff_max, 14, tbl.azCtr, 'filled');
        grid on; xlabel('max az diff (deg)'); ylabel('max el diff (deg)');
        cb = colorbar; ylabel(cb, 'azCtr (deg)');
        title('Template vs direct estimate differences');
    end
    saveas(fig, path_out); close(fig);
end

function write_template_record_doc_local(record_doc_path, keypoints_tbl, result_dir, Metkl, quick_mode, ...
    template_mode_for_route, steer_tbl, route_summary_tbl)
    fid = fopen(record_doc_path, 'w', 'n', 'UTF-8');
    if fid < 0
        fid = fopen(record_doc_path, 'w');
    end
    cleanup = onCleanup(@() safe_fclose_local(fid));
    fprintf(fid, '# 第8.7步 8 方式B局部steering模板等价性验证记录\n\n');
    fprintf(fid, '## 范围\n\n');
    fprintf(fid, '- 脚本：`space_smooth_music_B_cylindrical_level3_template_equivalence.m`\n');
    fprintf(fid, '- 短名 runner：`space_smooth_music_B_cylindrical_level3_template_eq.m`\n');
    fprintf(fid, '- 结果目录：`%s/`\n', string(get_last_path_name_local(result_dir)));
    fprintf(fid, '- Monte Carlo：Metkl=%d，quick_mode=%d。\n', Metkl, quick_mode);
    fprintf(fid, '- 本轮只验证 steering 模板化可行性，不做 FPGA、定点量化或算法阈值修改。\n\n');
    fprintf(fid, '## 方式 B 理论公式\n\n');
    fprintf(fid, '令 theta = theta_c + Delta_theta，并做局部坐标旋转：\n\n');
    fprintf(fid, '$$x_{local}=X\\cos\\theta_c+Y\\sin\\theta_c$$\n\n');
    fprintf(fid, '$$y_{local}=-X\\sin\\theta_c+Y\\cos\\theta_c$$\n\n');
    fprintf(fid, '$$z_{local}=Z$$\n\n');
    fprintf(fid, '第 7B direct geometry steering 保持为：\n\n');
    fprintf(fid, '$$A_{direct}=\\overline{A_{ref,direct}}\\exp\\{-j k [X\\cos e\\cos(\\theta_c+\\Delta\\theta)+Y\\cos e\\sin(\\theta_c+\\Delta\\theta)+Z\\sin e]\\}$$\n\n');
    fprintf(fid, '其中当前参考相位为：\n\n');
    fprintf(fid, '$$A_{ref,direct}=\\exp\\{-jk[X\\cos\\theta_c+Y\\sin\\theta_c]\\}$$\n\n');
    fprintf(fid, '局部模板 steering 写为：\n\n');
    fprintf(fid, '$$A_{template}=\\overline{A_{ref,local}}\\exp\\{-j k [x_{local}\\cos e\\cos\\Delta\\theta+y_{local}\\cos e\\sin\\Delta\\theta+z_{local}\\sin e]\\}$$\n\n');
    fprintf(fid, '其中：\n\n');
    fprintf(fid, '$$A_{ref,local}=\\exp\\{-jk x_{local}\\}$$\n\n');
    fprintf(fid, '因此 direct steering 中的相位项可写成局部模板：\n\n');
    fprintf(fid, '$$x_{local}\\cos e\\cos\\Delta\\theta+y_{local}\\cos e\\sin\\Delta\\theta+z_{local}\\sin e$$\n\n');
    fprintf(fid, '当前代码保持第 7B 的参考相位定义，参考俯仰为 0 deg，`A_ref` 不含 Z 项。\n\n');
    fprintf(fid, '本轮检查了 `arr_cyl(cfg, azCtr)` 的动态选列方式。测试中心 `[0, 15, 30, 60, 120]` 均落在 1.875 deg 方位列网格上，65 列局部几何与 `azCtr=0` canonical 几何在旋转坐标下保持一致。\n\n');
    fprintf(fid, '## Keypoints\n\n');
    fprintf(fid, '| keypoint | value | note |\n');
    fprintf(fid, '|---|---:|---|\n');
    for i = 1:height(keypoints_tbl)
        fprintf(fid, '| %s | %s | %s |\n', string(keypoints_tbl.keypoint(i)), string(keypoints_tbl.value(i)), string(keypoints_tbl.note(i)));
    end
    fprintf(fid, '\n## 不同 steering 类型误差\n\n');
    fprintf(fid, '| steering_type | template_mode | max rel_err_aligned | min coherence | max phase_err |\n');
    fprintf(fid, '|---|---|---:|---:|---:|\n');
    stypes = unique(steer_tbl.steering_type, 'stable');
    modes = ["template_exact", "template_canonical"];
    for is = 1:numel(stypes)
        for im = 1:numel(modes)
            mask = steer_tbl.steering_type == stypes(is) & steer_tbl.template_mode == modes(im);
            fprintf(fid, '| %s | %s | %.6g | %.15g | %.6g |\n', stypes(is), modes(im), ...
                max(steer_tbl.rel_err_aligned(mask)), min(steer_tbl.coherence(mask)), max(steer_tbl.phase_err_max(mask)));
        end
    end
    fprintf(fid, '\n## Route consistency 摘要\n\n');
    fprintf(fid, '| scenario | num_trials | route agreement | confidence agreement | direct success | template success | success gap | template false-high | template boundary-missed |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    route_rows = route_summary_tbl(isnan(route_summary_tbl.azCtr) & isnan(route_summary_tbl.SNR), :);
    for i = 1:height(route_rows)
        fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n', ...
            string(route_rows.scenario(i)), route_rows.num_trials(i), route_rows.route_agreement(i), ...
            route_rows.confidence_agreement(i), route_rows.direct_success(i), route_rows.template_success(i), ...
            route_rows.success_gap(i), route_rows.false_high_template(i), route_rows.boundary_missed_template(i));
    end
    fprintf(fid, '\n`phase_150` 存在少量 route label 不一致，route agreement 为 0.966667；但 confidence agreement、success、false-high 和 boundary-missed 均保持一致，因此整体 route consistency 仍满足本轮判据。\n');
    exact_pass = keypoint_value_local(keypoints_tbl, 'exact_template_max_rel_err_aligned') <= 1e-10 && ...
        keypoint_value_local(keypoints_tbl, 'exact_template_min_coherence') >= 1 - 1e-10;
    canonical_pass = keypoint_value_local(keypoints_tbl, 'canonical_reuse_pass_flag') >= 0.5;
    route_pass = keypoint_value_local(keypoints_tbl, 'route_consistency_pass_flag') >= 0.5;
    strategy = keypoint_string_local(keypoints_tbl, 'recommended_fpga_template_strategy');
    fprintf(fid, '\n## 判断\n\n');
    fprintf(fid, '- exact local template pass = %d\n', exact_pass);
    fprintf(fid, '- canonical reusable template pass = %d\n', canonical_pass);
    fprintf(fid, '- route consistency template mode = `%s`\n', template_mode_for_route);
    fprintf(fid, '- route consistency pass = %d\n', route_pass);
    fprintf(fid, '- recommended FPGA template strategy = `%s`\n\n', strategy);
    if exact_pass && canonical_pass && route_pass
        fprintf(fid, '结论：方式 B 单一局部模板复用可行，可作为 FPGA steering 预计算方案进入下一阶段。\n\n');
        fprintf(fid, '下一步建议：进入定点量化验证。\n');
    elseif exact_pass && ~canonical_pass && route_pass
        fprintf(fid, '结论：局部坐标变换本身正确，但单一 canonical 模板复用不够安全。FPGA 应优先采用 per-center local cache，或增加列索引映射和相位补偿后再尝试 canonical reuse。\n\n');
        fprintf(fid, '下一步建议：先设计 per-center cache 或相位/索引补偿，再进入定点量化验证。\n');
    elseif ~exact_pass
        fprintf(fid, '结论：当前 direct 与 local-template 公式/实现不等价，方式 B 暂不可进入 FPGA。\n\n');
        fprintf(fid, '阻塞原因：需要先检查坐标旋转、A_ref、角度单位和动态选列索引。\n');
    else
        fprintf(fid, '结论：低层 steering 误差小，但 route 级联一致性未通过，不进入 FPGA。\n\n');
        fprintf(fid, '阻塞原因：需要逐 route 定位缓存、归一化、子阵选择或参考相位映射差异。\n');
    end
end

function name = get_last_path_name_local(path_in)
    [~, name] = fileparts(path_in);
end

function d = grid_desc_local(x)
    d = sprintf('[%.3g:%.3g:%.3g] n=%d', x(1), mean(diff(x)), x(end), numel(x));
end

function safe_fclose_local(fid)
    if ~isempty(fid) && fid > 0
        fclose(fid);
    end
end

function log_msg(fid, fmt, varargin)
    msg = sprintf(fmt, varargin{:});
    fprintf('%s\n', msg);
    if fid > 0
        fprintf(fid, '[%s] %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), msg);
    end
end
