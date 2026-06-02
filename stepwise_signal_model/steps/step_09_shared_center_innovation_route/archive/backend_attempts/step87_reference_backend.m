function out = step87_reference_backend(Y_work, frontend_out, selected, array_geom, cfg)
%STEP87_REFERENCE_BACKEND Functionized Step 8.7 lazy cascade backend.
%
% This file is a minimal Step 09 adapter around the verified Step 8.7 Part
% 7B lazy cascade logic. It keeps the historical route thresholds and route
% order, but maps Step 09's Y_work/selected interface into the local 8.7
% array-domain backend. Source basis:
% space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m.

if nargin < 5
    cfg = struct();
end
cfg = defaults_local(cfg, frontend_out, selected, array_geom);

out = make_blocked_output_local('not_run');
try
    if cfg.boundary_unreliable_flag
        out = make_standard_output_local( ...
            make_boundary_result_local(make_empty_route_map_local(), ...
            'boundary_unreliable', 'low', 'frontend_boundary_unreliable'), cfg, struct());
        return
    end

    X3d = selected.XWork;
    Y3d = selected.YWork;
    Z3d = selected.ZWork;
    if isempty(X3d) || isempty(Y3d) || isempty(Z3d)
        out = make_blocked_output_local('selected_geometry_missing');
        return
    end

    center_az = selected.selectedCenterAz;
    A_ref_2d = exp(-1j * 2*pi / cfg.lambda * ...
        (X3d * cosd(center_az) + Y3d * sind(center_az)));
    Y_step87 = adapt_step09_y_work_to_step87_local(Y_work, A_ref_2d);

    backend_cache = get_backend_cache_local(X3d, Y3d, Z3d, ...
        A_ref_2d, cfg, center_az);

    [result, timing] = run_lazy_cascade_local(Y_step87, X3d, Y3d, Z3d, ...
        A_ref_2d, cfg.lambda, cfg.coarseEl, backend_cache.az_grid, ...
        backend_cache.el_refocus_grid, ...
        cfg.K_phi_level2, cfg.K_phi_music, cfg.K_z_music, ...
        cfg.K_phi_covfit, cfg.K_z_covfit, cfg.Lc, ...
        backend_cache.level2_cache_map, ...
        backend_cache.level2_refocus_cache_map, backend_cache.music_cache, ...
        backend_cache.p_sel, backend_cache.r_sel, ...
        cfg.min_pair_sep_deg, cfg.max_pair_sep_deg, cfg);

    out = make_standard_output_local(result, cfg, timing);
catch ME
    out = make_blocked_output_local(['step87_backend_error:', ME.identifier]);
    out.debug_info.error_message = ME.message;
end
end

function cfg = defaults_local(cfg, frontend_out, selected, array_geom)
    cfg = set_default_local(cfg, 'lambda', getfield_default_local(array_geom, 'lambda', 1));
    cfg = set_default_local(cfg, 'coarseEl', getfield_default_local(frontend_out, 'coarseEl', 0));
    cfg = set_default_local(cfg, 'boundary_unreliable_flag', ...
        getfield_default_local(frontend_out, 'boundary_unreliable_flag', false));
    cfg = set_default_local(cfg, 'min_pair_sep_deg', 0.05);
    cfg = set_default_local(cfg, 'max_pair_sep_deg', 0.80);
    cfg = set_default_local(cfg, 'step87_az_half_span_deg', 0.6);
    cfg = set_default_local(cfg, 'step87_az_step_deg', 0.02);
    cfg = set_default_local(cfg, 'step87_el_grid', -2:0.5:12);
    cfg = set_default_local(cfg, 'step87_el_refocus_grid', -2:0.5:12);
    cfg = set_default_local(cfg, 'step87_el_bank', -5:1:15);
    cfg = set_default_local(cfg, 'K_phi_level2', min(20, selected.Q - 1));
    cfg = set_default_local(cfg, 'K_phi_music', min(20, selected.Q - 1));
    cfg = set_default_local(cfg, 'K_z_music', min(8, selected.Nel - 1));
    cfg = set_default_local(cfg, 'K_phi_covfit', min(6, selected.Q - 1));
    cfg = set_default_local(cfg, 'K_z_covfit', min(3, selected.Nel - 1));
    cfg = set_default_local(cfg, 'Lc', 2);
    cfg = set_default_local(cfg, 'common_el_gate_mode', 'current_common_el_proxy');
    cfg = set_default_local(cfg, 'rank1_refocus_pair_agree_tol_deg', 0.12);
    cfg.K_phi_level2 = max(2, cfg.K_phi_level2);
    cfg.K_phi_music = max(2, cfg.K_phi_music);
    cfg.K_z_music = max(2, cfg.K_z_music);
    cfg.K_phi_covfit = max(2, cfg.K_phi_covfit);
    cfg.K_z_covfit = max(2, cfg.K_z_covfit);
    allowed_gate_modes = {'current_common_el_proxy', ...
        'rank1_reliable_without_common_el_proxy', ...
        'rank1_refocus_consensus_gate'};
    if ~ismember(char(cfg.common_el_gate_mode), allowed_gate_modes)
        error('step87_reference_backend:InvalidCommonElGateMode', ...
            'cfg.common_el_gate_mode must be one of the supported gate modes.');
    end
end

function Y_step87 = adapt_step09_y_work_to_step87_local(Y_work, A_ref_2d)
    % Step 8.7 calibrated the lazy cascade on center-referenced observations
    % conj(A_ref) .* exp(-j*k*phase). Step 09 supplies raw local array data
    % exp(+j*k*phase), so the backend bridge must map the reference frame.
    Y_step87 = conj(A_ref_2d) .* conj(Y_work);
end

function backend_cache = get_backend_cache_local(X3d, Y3d, Z3d, A_ref_2d, cfg, center_az)
    persistent cache_key cache_value

    az_grid = (center_az - cfg.step87_az_half_span_deg): ...
        cfg.step87_az_step_deg:(center_az + cfg.step87_az_half_span_deg);
    geom_sig = geometry_signature_local(X3d, Y3d, Z3d, A_ref_2d);
    cache_now = sprintf(['center=%.12g|lambda=%.12g|min=%.12g|max=%.12g|' ...
        'az=%s|el=%s|eref=%s|ebank=%s|k=%s|shape=%s|geom=%s'], ...
        center_az, cfg.lambda, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg, ...
        mat2str(az_grid, 12), mat2str(cfg.step87_el_grid, 12), ...
        mat2str(cfg.step87_el_refocus_grid, 12), mat2str(cfg.step87_el_bank, 12), ...
        mat2str([cfg.K_phi_level2, cfg.K_phi_music, cfg.K_z_music, ...
        cfg.K_phi_covfit, cfg.K_z_covfit, cfg.Lc], 12), ...
        mat2str(size(X3d), 12), mat2str(geom_sig, 12));

    if ~isempty(cache_value) && strcmp(cache_key, cache_now)
        backend_cache = cache_value;
        return
    end

    level2_pair_candidates = make_pair_candidates_local( ...
        az_grid, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg);
    level2_cache_map = precompute_level2_bank_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg.lambda, az_grid, cfg.step87_el_bank, ...
        cfg.K_phi_level2, level2_pair_candidates);
    level2_refocus_cache_map = precompute_level2_bank_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg.lambda, az_grid, ...
        cfg.step87_el_refocus_grid, cfg.K_phi_level2, level2_pair_candidates);
    music_cache = make_level3_grid_cache_local( ...
        X3d, Y3d, Z3d, A_ref_2d, cfg.lambda, az_grid, cfg.step87_el_grid, ...
        cfg.K_phi_music, cfg.K_z_music);
    [p_sel, r_sel] = make_selected_2d_subarray_positions_local( ...
        size(X3d, 1), size(X3d, 2), cfg.K_phi_covfit, cfg.K_z_covfit);

    backend_cache = struct();
    backend_cache.az_grid = az_grid;
    backend_cache.el_refocus_grid = cfg.step87_el_refocus_grid;
    backend_cache.level2_cache_map = level2_cache_map;
    backend_cache.level2_refocus_cache_map = level2_refocus_cache_map;
    backend_cache.music_cache = music_cache;
    backend_cache.p_sel = p_sel;
    backend_cache.r_sel = r_sel;

    cache_key = cache_now;
    cache_value = backend_cache;
end

function sig = geometry_signature_local(X3d, Y3d, Z3d, A_ref_2d)
    sig = [sum(real(X3d(:))), sum(real(Y3d(:))), sum(real(Z3d(:))), ...
        norm(X3d(:)), norm(Y3d(:)), norm(Z3d(:)), ...
        sum(real(A_ref_2d(:))), sum(imag(A_ref_2d(:)))];
end

function out = make_standard_output_local(result, cfg, timing)
    step87_route = string(getfield_default_local(result, 'recommended_route', 'low_confidence'));
    conf = char(getfield_default_local(result, 'confidence_flag', 'low'));
    if isempty(conf)
        conf = 'low';
    end
    route_name = map_route_name_local(step87_route);
    rejected = strcmp(conf, 'low') || any(strcmp(route_name, ...
        {'low_confidence', 'boundary_unreliable'}));
    out = struct();
    out.method = 'shared-center MUSIC enhanced DOA';
    out.backend_mode = 'step87_reference';
    out.status = ternary_local(rejected, 'rejected', 'success');
    out.route_name = route_name;
    out.confidence = conf;
    if rejected
        out.az_est = [];
        out.el_est = [];
    else
        out.az_est = getfield_default_local(result, 'az_est', []);
        out.el_est = getfield_default_local(result, 'el_est', []);
        out.az_est = out.az_est(:).';
        out.el_est = out.el_est(:).';
    end
    out.reject_reason = char(getfield_default_local(result, 'failure_reason', ''));
    out.backend_callable = true;
    out.blocker_if_any = 'none';
    out.debug_info = build_debug_info_local(result, cfg, timing);
end

function debug_info = build_debug_info_local(result, cfg, timing)
    route_map = getfield_default_local(timing, 'route_map', make_empty_route_map_local());
    music = route_map.music;
    rank1 = route_map.rank1_fallback;
    refocus = route_map.common_el_refocus_rank1;

    common_el_proxy_flag = is_strong_common_el_proxy_local(music, refocus);
    low_cost_boundary_flag = is_low_cost_boundary_proxy_from_partial_local( ...
        music, rank1, refocus, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg);
    boundary_unreliable_flag = is_boundary_unreliable_local( ...
        route_map, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg);

    debug_info = struct();
    debug_info.step87_route = string(getfield_default_local(result, 'recommended_route', ''));
    debug_info.raw_result = result;
    debug_info.timing = timing;
    debug_info.coarseEl_used = cfg.coarseEl;

    debug_info.music_peak_count = getfield_default_local(music, 'peak_count', NaN);
    debug_info.music_peak_sep_deg = getfield_default_local(music, 'peak_separation_az', NaN);
    debug_info.music_peak2_ratio = getfield_default_local(music, 'peak_prominence_ratio', NaN);
    debug_info.music_reliable_flag = is_level2_music_reliable_local( ...
        music, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg);
    debug_info.music_failure_reason = string(getfield_default_local(music, 'failure_reason', 'not_available'));

    debug_info.refocus_best_az_pair = pair_or_nan_local(getfield_default_local(refocus, 'az_est', [NaN, NaN]));
    debug_info.refocus_score = getfield_default_local(refocus, 'objective_best', NaN);
    debug_info.refocus_score_gap = getfield_default_local(refocus, 'score_gap_ratio', NaN);
    debug_info.refocus_peak_sharpness = min( ...
        getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    debug_info.refocus_route_reliable = is_refocus_route_reliable_local( ...
        refocus, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg);
    debug_info.common_el_proxy_flag = common_el_proxy_flag;
    debug_info.common_el_proxy_failure_reason = common_el_proxy_failure_reason_local(music, refocus);
    debug_info.refocus_topk_candidates = getfield_default_local(refocus, 'topk_candidates', struct([]));
    [debug_info.refocus_topk_az_pairs, debug_info.refocus_topk_scores, ...
        debug_info.refocus_topk_score_gap] = topk_candidate_arrays_local( ...
        debug_info.refocus_topk_candidates);
    debug_info.refocus_power_topk_el = getfield_default_local(refocus, 'refocus_power_topk_el', struct([]));

    debug_info.rank1_best_az_pair = pair_or_nan_local(getfield_default_local(rank1, 'az_est', [NaN, NaN]));
    debug_info.rank1_score = getfield_default_local(rank1, 'objective_best', NaN);
    debug_info.rank1_score_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    debug_info.rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    debug_info.rank1_route_reliable = is_rank1_route_reliable_local( ...
        rank1, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg);
    debug_info.rank1_failure_reason = rank1_failure_reason_local( ...
        rank1, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg);
    debug_info.rank1_topk_candidates = getfield_default_local(rank1, 'topk_candidates', struct([]));
    [debug_info.rank1_topk_az_pairs, debug_info.rank1_topk_scores, ...
        debug_info.rank1_topk_score_gap] = topk_candidate_arrays_local( ...
        debug_info.rank1_topk_candidates);

    debug_info.low_cost_boundary_flag = low_cost_boundary_flag;
    debug_info.boundary_unreliable_flag = boundary_unreliable_flag;
    debug_info.common_el_gate_mode = string(cfg.common_el_gate_mode);
    debug_info.rank1_refocus_pair_agree_tol_deg = cfg.rank1_refocus_pair_agree_tol_deg;
    debug_info.rank1_refocus_pair_error_deg = pair_error_swap_invariant_local( ...
        getfield_default_local(rank1, 'az_est', [NaN, NaN]), ...
        getfield_default_local(refocus, 'az_est', [NaN, NaN]));
    debug_info.rank1_without_common_el_gate_pass = rank1_without_common_el_gate_pass_local( ...
        rank1, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg, low_cost_boundary_flag);
    debug_info.rank1_refocus_consensus_gate_pass = rank1_refocus_consensus_gate_pass_local( ...
        rank1, refocus, cfg.min_pair_sep_deg, cfg.max_pair_sep_deg, ...
        low_cost_boundary_flag, cfg.rank1_refocus_pair_agree_tol_deg);
    debug_info.selected_common_el_gate_pass = selected_common_el_gate_pass_local( ...
        string(cfg.common_el_gate_mode), common_el_proxy_flag, rank1, refocus, ...
        cfg.min_pair_sep_deg, cfg.max_pair_sep_deg, low_cost_boundary_flag, ...
        cfg.rank1_refocus_pair_agree_tol_deg);
    debug_info.final_step87_route = string(getfield_default_local(result, 'recommended_route', ''));
    debug_info.final_confidence_flag = string(getfield_default_local(result, 'confidence_flag', ''));
    debug_info.final_failure_reason = string(getfield_default_local(result, 'failure_reason', ''));
end

function pair = pair_or_nan_local(value)
    pair = [NaN, NaN];
    if isnumeric(value) && numel(value) >= 2
        pair = value(1:2);
        pair = pair(:).';
    end
end

function [az_pairs, scores, gaps] = topk_candidate_arrays_local(candidates)
    az_pairs = zeros(0, 2);
    scores = [];
    gaps = [];
    if ~isstruct(candidates) || isempty(candidates)
        return
    end
    n = numel(candidates);
    az_pairs = NaN(n, 2);
    scores = NaN(n, 1);
    gaps = NaN(n, 1);
    for i = 1:n
        az_pairs(i, :) = pair_or_nan_local(getfield_default_local(candidates(i), 'az_pair', [NaN, NaN]));
        scores(i) = getfield_default_local(candidates(i), 'score', NaN);
        gaps(i) = getfield_default_local(candidates(i), 'score_gap_ratio', NaN);
    end
end

function reason = common_el_proxy_failure_reason_local(music, refocus)
    if is_strong_common_el_proxy_local(music, refocus)
        reason = "ok";
        return
    end
    el_music = getfield_default_local(music, 'el_est', [NaN, NaN]);
    el_assumed = mean(el_music(isfinite(el_music)), 'omitnan');
    if ~isfinite(el_assumed)
        el_assumed = 0;
    end
    el_hat = getfield_default_local(refocus, 'el_hat', NaN);
    refocus_sharp = min(getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    if ~isfinite(el_hat)
        reason = "refocus_el_nonfinite";
    elseif abs(el_hat - el_assumed) > 0.75
        reason = "common_el_proxy_el_mismatch";
    elseif ~isfinite(refocus_sharp)
        reason = "refocus_sharpness_nonfinite";
    elseif refocus_sharp < 0.075
        reason = "refocus_sharpness_below_proxy_gate";
    else
        reason = "common_el_proxy_failed";
    end
end

function reason = rank1_failure_reason_local(rank1, min_sep, max_sep)
    if is_rank1_route_reliable_local(rank1, min_sep, max_sep)
        reason = "ok";
        return
    end
    az_est = getfield_default_local(rank1, 'az_est', [NaN, NaN]);
    el_est = getfield_default_local(rank1, 'el_est', [NaN, NaN]);
    sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    residual = getfield_default_local(rank1, 'residual_norm', NaN);
    gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    if any(~isfinite(az_est)) || any(~isfinite(el_est))
        reason = "nonfinite_pair";
    elseif ~isfinite(sep)
        reason = "pair_sep_nonfinite";
    elseif sep < min_sep
        reason = "pair_sep_too_small";
    elseif sep > max_sep
        reason = "pair_sep_too_large";
    elseif ~isfinite(residual)
        reason = "rank1_residual_nonfinite";
    elseif residual >= 2e-3
        reason = "rank1_residual_too_high";
    elseif ~isfinite(gap)
        reason = "rank1_score_gap_nonfinite";
    elseif gap < 2e-3
        reason = "rank1_score_gap_too_small";
    else
        reason = string(getfield_default_local(rank1, 'failure_reason', 'rank1_unreliable'));
    end
end

function route_name = map_route_name_local(step87_route)
    switch char(step87_route)
        case 'level2_music_or_center_real'
            route_name = 'music_two_peak';
        case {'common_el_refocus_power_rank1', 'level2_rank1_fallback'}
            route_name = 'common_el_rank1_refocus';
        case {'level3_2d_music', 'pair_el_local_covfit'}
            route_name = 'local_2d_pair_refinement';
        case 'boundary_unreliable'
            route_name = 'boundary_unreliable';
        otherwise
            route_name = 'low_confidence';
    end
end

function out = make_blocked_output_local(reason)
    out = struct();
    out.method = 'shared-center MUSIC enhanced DOA';
    out.status = 'blocked';
    out.route_name = 'step87_reference_not_functionalized';
    out.confidence = 'low';
    out.az_est = [];
    out.el_est = [];
    out.reject_reason = char(reason);
    out.backend_mode = 'step87_reference';
    out.backend_callable = false;
    out.blocker_if_any = 'step87_reference_not_functionalized';
    out.debug_info = struct('failure_reason', char(reason));
end

function [result, timing] = run_lazy_cascade_local( ...
    y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, el_assumed, ...
    az_grid, el_refocus_grid, K_phi_level2, K_phi_music, K_z_music, ...
    K_phi_covfit, K_z_covfit, Lc, level2_cache_map, ...
    level2_refocus_cache_map, music_cache, p_sel, r_sel, min_sep, max_sep, cfg)

    timing = init_timing_local();
    t_all = tic;
    empty_result = make_empty_route_result_local("not_executed");
    music = empty_result;
    rank1 = empty_result;
    refocus = empty_result;
    music2d = empty_result;
    pair2d = empty_result;

    t0 = tic;
    music = run_level2_music_route_local( ...
        y_noisy_2d, X3d, Y3d, Z3d, A_ref_2d, lambda, el_assumed, ...
        az_grid, K_phi_level2, Lc);
    timing.t_level2_music = toc(t0);
    timing.executed_level2_music = true;

    t0 = tic;
    refocus = run_common_el_refocus_power_route_local( ...
        y_noisy_2d, Z3d, lambda, el_refocus_grid, level2_refocus_cache_map, ...
        az_grid, K_phi_level2, min_sep, max_sep);
    timing.t_refocus = toc(t0);
    timing.executed_refocus = true;

    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    common_el_proxy = is_strong_common_el_proxy_local(music, refocus);
    low_cost_boundary_partial = is_low_cost_boundary_proxy_from_partial_local( ...
        music, rank1, refocus, min_sep, max_sep);

    if is_level2_music_reliable_local(music, min_sep, max_sep) && ...
            current_common_el_proxy_gate_pass_local(string(cfg.common_el_gate_mode), common_el_proxy)
        result = music;
        result.recommended_route = "level2_music_or_center_real";
        if is_level2_music_high_confidence_local(music, route_map, min_sep, max_sep)
            result.confidence_flag = "high";
        else
            result.confidence_flag = "medium";
        end
        result.failure_reason = "ok";
        timing = finish_timing_local(timing, t_all, 1, true, route_map);
        return
    end

    if is_refocus_route_reliable_local(refocus, min_sep, max_sep) && ...
            ~low_cost_boundary_partial && ...
            current_common_el_proxy_gate_pass_local(string(cfg.common_el_gate_mode), common_el_proxy)
        result = refocus;
        result.recommended_route = "common_el_refocus_power_rank1";
        result.confidence_flag = "medium";
        result.failure_reason = "ok";
        timing = finish_timing_local(timing, t_all, 2, true, route_map);
        return
    end

    t0 = tic;
    rank1 = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, el_assumed, level2_cache_map, ...
        az_grid, K_phi_level2, min_sep, max_sep);
    timing.t_level2_rank1 = toc(t0);
    timing.executed_level2_rank1 = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
    low_cost_boundary = is_low_cost_boundary_proxy_from_partial_local( ...
        music, rank1, refocus, min_sep, max_sep);

    if is_rank1_route_reliable_local(rank1, min_sep, max_sep) && ...
            selected_common_el_gate_pass_local(string(cfg.common_el_gate_mode), ...
            common_el_proxy, rank1, refocus, min_sep, max_sep, low_cost_boundary, ...
            cfg.rank1_refocus_pair_agree_tol_deg)
        result = rank1;
        result.recommended_route = selected_rank1_route_name_local(string(cfg.common_el_gate_mode));
        result.confidence_flag = "medium";
        result.failure_reason = selected_rank1_failure_reason_local(string(cfg.common_el_gate_mode));
        timing = finish_timing_local(timing, t_all, 3, true, route_map);
        return
    end

    t0 = tic;
    Rfb_2d = level3_fbss_cov_from_observation_local(y_noisy_2d, K_phi_music, K_z_music);
    music2d = run_level3_2d_music_route_local(Rfb_2d, music_cache, Lc);
    timing.t_2dmusic = toc(t0);
    timing.executed_2dmusic = true;
    route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);

    if is_music2d_reliable_local(music2d, min_sep, max_sep)
        pair_available = music2d.peak_count >= 2 && all(isfinite(music2d.az_est)) && ...
            all(isfinite(music2d.el_est));
        if pair_available && is_cascade_pair_refinement_needed_local(music2d, min_sep, max_sep)
            t0 = tic;
            Rfb_pair = level3_fbss_cov_selected_from_observation_local( ...
                y_noisy_2d, K_phi_covfit, K_z_covfit, p_sel, r_sel);
            pair2d = run_level3_pair_el_local_rank1_covfit_local( ...
                Rfb_pair, music2d, X3d, Y3d, Z3d, A_ref_2d, lambda, ...
                K_phi_covfit, K_z_covfit, p_sel, r_sel, min_sep, max_sep);
            timing.t_pair_local = toc(t0);
            timing.executed_pair_local = true;
            route_map = make_route_map_local(music, rank1, refocus, music2d, pair2d);
            if is_pair_route_reliable_local(pair2d, min_sep, max_sep)
                result = pair2d;
                result.recommended_route = "pair_el_local_covfit";
                result.confidence_flag = "medium";
                result.failure_reason = "ok";
                timing = finish_timing_local(timing, t_all, 5, true, route_map);
                return
            end
        end
        result = music2d;
        result.recommended_route = "level3_2d_music";
        result.confidence_flag = "medium";
        result.failure_reason = ternary_local(timing.executed_pair_local, ...
            "pair_local_not_reliable", "ok");
        timing = finish_timing_local(timing, t_all, 4, true, route_map);
        return
    end

    if is_boundary_unreliable_local(route_map, min_sep, max_sep) || low_cost_boundary
        result = make_boundary_result_local(route_map, ...
            'boundary_unreliable', 'low', 'boundary_unreliable');
    else
        result = make_boundary_result_local(route_map, ...
            'low_confidence', 'low', 'no_reliable_observable_route');
    end
    timing = finish_timing_local(timing, t_all, 6, false, route_map);
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
    [evals, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(A) .* (Cn * A), 1));
    spectrum = 1 ./ max(den, eps);
    peaks = find_1d_peaks_local(spectrum, az_grid, Lc);
    result = make_result_local(peaks.az_est, el_assumed * ones(1, Lc), ...
        peaks.peak_count, NaN, peaks.failure_reason);
    result.spectrum_1d = spectrum;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.spectrum_width = peaks.spectrum_width;
    result.pair_sep_est = peaks.peak_separation_az;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, ...
        result.lambda2_over_noise, result.lambda2_over_lambda1, ...
        result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function result = run_level2_rank1_route_local( ...
    y_noisy_2d, Z3d, lambda, el_assumed, cache_map, az_grid, K_phi, min_sep, max_sep)
    [~, idx] = min(abs([cache_map.el] - el_assumed));
    y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, cache_map(idx).el);
    Rfb = level2_fbss_cov_local(y_combined, K_phi);
    result = score_level2_cache_local(Rfb, cache_map(idx), az_grid);
    result.el_est = [cache_map(idx).el, cache_map(idx).el];
    result.peak_count = 2;
    result.failure_reason = failure_reason_pair_local(result.az_est, result.el_est, min_sep, max_sep);
end

function result = run_common_el_refocus_power_route_local( ...
    y_noisy_2d, Z3d, lambda, el_grid, cache_map, az_grid, K_phi, min_sep, max_sep)
    n = numel(el_grid);
    power_curve = zeros(1, n);
    lambda1_curve = zeros(1, n);
    Rfb_curve = cell(1, n);
    for ie = 1:n
        y_combined = combine_layers_level2_local(y_noisy_2d, Z3d, lambda, el_grid(ie));
        power_curve(ie) = mean(abs(y_combined(:)).^2);
        Rfb = level2_fbss_cov_local(y_combined, K_phi);
        Rfb_curve{ie} = Rfb;
        lambda1_curve(ie) = max(real(eig(0.5 * (Rfb + Rfb'))));
    end
    [~, idx] = max(power_curve);
    el_hat = el_grid(idx);
    result = run_level2_rank1_route_local( ...
        y_noisy_2d, Z3d, lambda, el_hat, cache_map, az_grid, K_phi, min_sep, max_sep);
    result.el_hat = el_hat;
    result.el_est = [el_hat, el_hat];
    result.el_common_est = el_hat;
    result.el_selection_method = "focused_power";
    result.focused_power_peak_sharpness = peak_sharpness_local(power_curve);
    result.lambda1_peak_sharpness = peak_sharpness_local(lambda1_curve);
    result.refocus_power_topk_el = topk_el_local(power_curve, el_grid, 5);
    result.topk_candidates = make_refocus_topk_candidates_local( ...
        Rfb_curve, cache_map, el_grid, az_grid, result.refocus_power_topk_el);
end

function result = score_level2_cache_local(Rfb, cache, az_grid)
    score = score_rank1_all_local(Rfb, cache.precomp);
    [best_score, best_idx] = min(score);
    score2 = second_score_local(score, best_idx);
    pair_idx = cache.precomp.candidate_pairs(best_idx, :);
    result = make_result_local(sort(az_grid(pair_idx)), [NaN, NaN], 2, ...
        best_score, 'ok');
    result.topk_candidates = make_rank1_topk_candidates_local(score, ...
        cache.precomp.candidate_pairs, az_grid, 5);
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est));
end

function Rfb = level2_fbss_cov_local(y_combined, K_phi)
    Rxx = y_combined * y_combined' / max(size(y_combined, 2), 1);
    Rxx = 0.5 * (Rxx + Rxx');
    Rfb = mssp_array_fb_local(Rxx, K_phi);
    Rfb = 0.5 * (Rfb + Rfb');
end

function y_combined = combine_layers_level2_local(y_2d, Z3d, lambda, el_assumed_deg)
    Nel = size(y_2d, 2);
    z_col = Z3d(1, :).';
    steer_el = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    W = steer_el' / sqrt(Nel);
    tmp = W * reshape(permute(y_2d, [2, 1, 3]), Nel, []);
    y_combined = reshape(tmp, size(y_2d, 1), size(y_2d, 3));
end

function b = build_level2_combined_az_steer_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg, el_assumed_deg)
    Nel = size(X3d, 2);
    a_norm = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_scan_deg);
    z_col = Z3d(1, :).';
    a_z = exp(-1j * 2*pi / lambda * z_col * sind(el_assumed_deg));
    w_z = a_z / sqrt(Nel);
    b = (w_z' * a_norm.').';
    b = b / max(norm(b), eps);
end

function B_grid = build_level2_combined_az_steer_grid_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid, el_scan_deg, el_assumed_deg)
    B_grid = zeros(size(X3d, 1), numel(angle_grid));
    for ia = 1:numel(angle_grid)
        B_grid(:, ia) = build_level2_combined_az_steer_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, angle_grid(ia), el_scan_deg, el_assumed_deg);
    end
end

function cache_map = precompute_level2_bank_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid, el_bank, K_phi, candidate_pairs)
    cache_map = repmat(struct('el', NaN, 'sub_cache', [], 'precomp', []), numel(el_bank), 1);
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
    [evals, ord] = sort(real(diag(D)), 'descend');
    V = V(:, ord);
    En = V(:, Lc+1:end);
    Cn = En * En';
    den = real(sum(conj(grid_cache.A_center) .* (Cn * grid_cache.A_center), 1));
    P = reshape(1 ./ max(den, eps), numel(grid_cache.az_grid), numel(grid_cache.el_grid));
    peaks = find_2d_peaks_local(P, grid_cache.az_grid, grid_cache.el_grid, Lc);
    result = make_result_local(peaks.az_est, peaks.el_est, peaks.peak_count, NaN, peaks.failure_reason);
    result.spectrum = P;
    result.peak_separation_az = peaks.peak_separation_az;
    result.peak_separation_el = peaks.peak_separation_el;
    result.peak_prominence_ratio = peaks.peak_prominence_ratio;
    result.global_peak_el = peaks.global_peak_el;
    result.two_peak_flag = peaks.two_peak_flag;
    [result.lambda1, result.lambda2, result.lambda_noise_mean, ...
        result.lambda2_over_noise, result.lambda2_over_lambda1, ...
        result.effective_rank_proxy] = eigen_proxy_from_vals_local(evals);
end

function Rfb = level3_fbss_cov_from_observation_local(y_2d, K_phi, K_z)
    [Q, Nel, T_snap] = size(y_2d);
    P_phi = Q - K_phi + 1;
    P_z = Nel - K_z + 1;
    K = K_phi * K_z;
    Rf = complex(zeros(K, K));
    for p = 1:P_phi
        for r = 1:P_z
            Y = reshape(y_2d(p:p+K_phi-1, r:r+K_z-1, :), K, T_snap);
            Rf = Rf + (Y * Y') / T_snap;
        end
    end
    Rf = Rf / (P_phi * P_z);
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
    Rfb, music_result, X3d, Y3d, Z3d, A_ref_2d, lambda, K_phi, K_z, p_sel, r_sel, min_sep, max_sep)
    if any(~isfinite(music_result.az_est)) || music_result.peak_count < 2
        result = make_result_local([NaN, NaN], [NaN, NaN], music_result.peak_count, NaN, 'no_2d_peaks');
        return
    end
    candidates = make_pair_el_local_candidates_local(music_result.az_est, music_result.el_est, min_sep, max_sep);
    if isempty(candidates)
        result = make_result_local([NaN, NaN], [NaN, NaN], music_result.peak_count, NaN, 'no_pair_candidates');
        return
    end
    scores = zeros(size(candidates, 1), 1);
    for ic = 1:size(candidates, 1)
        G = build_level3_rank1_model_fbss_selected_local( ...
            X3d, Y3d, Z3d, A_ref_2d, lambda, candidates(ic, 1:2), ...
            candidates(ic, 3:4), 1, 0, K_phi, K_z, p_sel, r_sel);
        scores(ic) = solve_covfit_score_local(Rfb, G);
    end
    [best_score, best_idx] = min(scores);
    score2 = second_score_local(scores, best_idx);
    best = candidates(best_idx, :);
    [az_est, order] = sort(best(1:2));
    el_est = best(2 + order);
    result = make_result_local(az_est, el_est, 2, best_score, 'ok');
    result.score_gap_abs = score2 - best_score;
    result.score_gap_ratio = (score2 - best_score) / max(best_score, eps);
    result.residual_norm = best_score;
    result.pair_sep_est = diff(sort(result.az_est));
    result.finite_output_flag = all(isfinite(result.az_est)) && all(isfinite(result.el_est));
    result.pair_local_confidence_proxy = result.score_gap_ratio / max(1 + result.residual_norm, eps);
end

function Gfb = build_level3_rank1_model_fbss_selected_local( ...
    X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair, el_pair, beta, phi_deg, K_phi, K_z, p_sel, r_sel)
    A1 = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(1), el_pair(1));
    A2 = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, theta_pair(2), el_pair(2));
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
            Afull = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_grid(ia), el_grid(ie));
            sub = Afull(p0:p0+K_phi-1, r0:r0+K_z-1);
            A(:, idx) = sub(:) / max(norm(sub(:)), eps);
        end
    end
    grid_cache = struct('az_grid', az_grid, 'el_grid', el_grid, ...
        'K_phi', K_phi, 'K_z', K_z, 'A_center', A);
end

function [p_sel, r_sel] = make_selected_2d_subarray_positions_local(Q, Nel, K_phi, K_z)
    p_all = 1:(Q - K_phi + 1);
    r_all = 1:(Nel - K_z + 1);
    p_sel = p_all(unique(round(linspace(1, numel(p_all), min(7, numel(p_all))))));
    r_sel = r_all(unique(round(linspace(1, numel(r_all), min(5, numel(r_all))))));
end

function A = steering_2d_full_local(X3d, Y3d, Z3d, A_ref_2d, lambda, az_deg, el_deg)
    k = 2*pi / lambda;
    phase = X3d * (cosd(el_deg) * cosd(az_deg)) + ...
        Y3d * (cosd(el_deg) * sind(az_deg)) + Z3d * sind(el_deg);
    A = conj(A_ref_2d) .* exp(-1j * k * phase);
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

function peaks = find_1d_peaks_local(P, az_axis, Lc)
    Pwork = real(P(:)).';
    idx = [];
    for ii = 2:numel(Pwork)-1
        if Pwork(ii) >= Pwork(ii-1) && Pwork(ii) >= Pwork(ii+1) && Pwork(ii) > median(Pwork)
            idx(end+1) = ii; %#ok<AGROW>
        end
    end
    if isempty(idx)
        [~, imax] = max(Pwork);
        idx = imax;
    end
    [~, ord] = sort(Pwork(idx), 'descend');
    idx = idx(ord);
    peak_count = numel(idx);
    az_est = nan(1, Lc);
    if peak_count >= Lc
        az_est = sort(az_axis(idx(1:Lc)));
        reason = 'ok';
    else
        reason = 'peak_count_lt_2';
    end
    peak_vals = Pwork(idx);
    if numel(peak_vals) >= 2
        peak_prominence_ratio = peak_vals(2) / max(peak_vals(1), eps);
    else
        peak_prominence_ratio = 0;
    end
    if numel(az_est) >= 2 && all(isfinite(az_est))
        peak_separation_az = diff(sort(az_est));
    else
        peak_separation_az = NaN;
    end
    mask = Pwork >= 0.5 * max(Pwork);
    if any(mask)
        spectrum_width = az_axis(find(mask, 1, 'last')) - az_axis(find(mask, 1, 'first'));
    else
        spectrum_width = NaN;
    end
    peaks = struct('az_est', az_est, 'peak_count', peak_count, ...
        'failure_reason', reason, 'peak_separation_az', peak_separation_az, ...
        'peak_prominence_ratio', peak_prominence_ratio, 'spectrum_width', spectrum_width);
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
    idx = find(mask);
    vals = Pwork(idx);
    [~, ord] = sort(vals, 'descend');
    idx = idx(ord);
    peak_count = numel(idx);
    az_est = nan(1, Lc);
    el_est = nan(1, Lc);
    if peak_count >= Lc
        [ia, ie] = ind2sub(size(Pwork), idx(1:Lc));
        az_est = az_axis(ia);
        el_est = el_axis(ie);
        [az_est, order] = sort(az_est);
        el_est = el_est(order);
        reason = 'ok';
    else
        reason = 'peak_count_lt_2';
    end
    peak_vals = vals(:).';
    if numel(peak_vals) >= 2
        peak_prominence_ratio = peak_vals(2) / max(peak_vals(1), eps);
    else
        peak_prominence_ratio = 0;
    end
    if numel(az_est) >= 2 && all(isfinite(az_est))
        peak_separation_az = diff(sort(az_est));
        peak_separation_el = abs(diff(el_est));
        two_peak_flag = true;
    else
        peak_separation_az = NaN;
        peak_separation_el = NaN;
        two_peak_flag = false;
    end
    if isempty(idx)
        global_peak_el = NaN;
    else
        [~, ie0] = ind2sub(size(Pwork), idx(1));
        global_peak_el = el_axis(ie0);
    end
    peaks = struct('az_est', az_est, 'el_est', el_est, 'peak_count', peak_count, ...
        'failure_reason', reason, 'peak_separation_az', peak_separation_az, ...
        'peak_separation_el', peak_separation_el, 'peak_prominence_ratio', peak_prominence_ratio, ...
        'global_peak_el', global_peak_el, 'two_peak_flag', two_peak_flag);
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

function ok = is_music2d_high_confidence_local(result, min_sep, max_sep)
    sep_az = getfield_default_local(result, 'peak_separation_az', NaN);
    sep_el = getfield_default_local(result, 'peak_separation_el', NaN);
    prom = getfield_default_local(result, 'peak_prominence_ratio', NaN);
    ok = is_music2d_reliable_local(result, min_sep, max_sep) && ...
        isfinite(prom) && prom >= 0.75 && isfinite(sep_el) && sep_el >= 2.5 && ...
        ~is_sep_edge_local(sep_az, min_sep, max_sep, 0.02);
end

function tf = is_cascade_pair_refinement_needed_local(music2d_result, min_sep, max_sep)
    tf = is_music2d_reliable_local(music2d_result, min_sep, max_sep) && ...
        ~is_music2d_high_confidence_local(music2d_result, min_sep, max_sep);
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
    strong_single_peak = music.peak_count < 2 && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;
    weak_rank1 = (~isfinite(rank1_gap) || rank1_gap < 5e-3) && ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3);
    sep_edge = is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;
    route_conflict = has_route_conflict_local(route_map);
    tf = (no_reliable_2d && music_single && rank1_finite && weak_rank1) || ...
        (no_reliable_2d && music_single && rank1_finite && sep_edge) || ...
        (no_reliable_2d && strong_single_peak && refocus_unsharp) || ...
        (no_reliable_2d && route_conflict && ~is_level2_music_reliable_local(music, min_sep, max_sep));
end

function tf = is_low_cost_boundary_proxy_from_partial_local(music, rank1, refocus, min_sep, max_sep)
    music_single = music.peak_count < 2 || any(~isfinite(music.az_est));
    strong_single_peak = music_single && ...
        getfield_default_local(music, 'peak_prominence_ratio', 0) < 0.45 && ...
        getfield_default_local(music, 'spectrum_width', inf) <= 0.22;
    rank1_gap = getfield_default_local(rank1, 'score_gap_ratio', NaN);
    rank1_residual = getfield_default_local(rank1, 'residual_norm', NaN);
    rank1_sep = getfield_default_local(rank1, 'pair_sep_est', NaN);
    weak_rank1 = (~isfinite(rank1_gap) || rank1_gap < 5e-3) || ...
        (~isfinite(rank1_residual) || rank1_residual > 1e-3);
    sep_edge = is_sep_edge_local(rank1_sep, min_sep, max_sep, 0.015);
    refocus_sharp = min(getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    refocus_unsharp = ~isfinite(refocus_sharp) || refocus_sharp < 0.05;
    refocus_rank1_conflict = false;
    if all(isfinite(getfield_default_local(refocus, 'az_est', [NaN, NaN]))) && ...
            all(isfinite(getfield_default_local(rank1, 'az_est', [NaN, NaN])))
        refocus_rank1_conflict = max(abs(sort(refocus.az_est) - sort(rank1.az_est))) > 0.14;
    end
    tf = (music_single && refocus_unsharp && weak_rank1) || ...
        (strong_single_peak && refocus_unsharp) || ...
        (music_single && sep_edge && weak_rank1) || ...
        (refocus_rank1_conflict && ~is_refocus_route_reliable_local(refocus, min_sep, max_sep));
end

function tf = is_strong_common_el_proxy_local(music, refocus)
    el_music = getfield_default_local(music, 'el_est', [NaN, NaN]);
    el_assumed = mean(el_music(isfinite(el_music)), 'omitnan');
    if ~isfinite(el_assumed)
        el_assumed = 0;
    end
    el_hat = getfield_default_local(refocus, 'el_hat', NaN);
    refocus_sharp = min(getfield_default_local(refocus, 'focused_power_peak_sharpness', NaN), ...
        getfield_default_local(refocus, 'lambda1_peak_sharpness', NaN));
    tf = isfinite(el_hat) && isfinite(refocus_sharp) && ...
        abs(el_hat - el_assumed) <= 0.75 && refocus_sharp >= 0.075;
end

function tf = current_common_el_proxy_gate_pass_local(mode, common_el_proxy)
    switch char(mode)
        case {'current_common_el_proxy', ...
                'rank1_reliable_without_common_el_proxy', ...
                'rank1_refocus_consensus_gate'}
            tf = common_el_proxy;
        otherwise
            tf = false;
    end
end

function tf = selected_common_el_gate_pass_local(mode, common_el_proxy, rank1, refocus, ...
    min_sep, max_sep, low_cost_boundary, agree_tol_deg)
    switch char(mode)
        case 'current_common_el_proxy'
            tf = common_el_proxy && ~low_cost_boundary;
        case 'rank1_reliable_without_common_el_proxy'
            tf = rank1_without_common_el_gate_pass_local(rank1, min_sep, max_sep, low_cost_boundary);
        case 'rank1_refocus_consensus_gate'
            tf = rank1_refocus_consensus_gate_pass_local(rank1, refocus, ...
                min_sep, max_sep, low_cost_boundary, agree_tol_deg);
        otherwise
            tf = false;
    end
end

function tf = rank1_without_common_el_gate_pass_local(rank1, min_sep, max_sep, low_cost_boundary)
    tf = is_rank1_route_reliable_local(rank1, min_sep, max_sep) && ...
        pair_finite_and_sep_valid_local(rank1, min_sep, max_sep) && ...
        ~low_cost_boundary;
end

function tf = rank1_refocus_consensus_gate_pass_local(rank1, refocus, min_sep, ...
    max_sep, low_cost_boundary, agree_tol_deg)
    pair_err = pair_error_swap_invariant_local( ...
        getfield_default_local(rank1, 'az_est', [NaN, NaN]), ...
        getfield_default_local(refocus, 'az_est', [NaN, NaN]));
    tf = is_rank1_route_reliable_local(rank1, min_sep, max_sep) && ...
        is_refocus_route_reliable_local(refocus, min_sep, max_sep) && ...
        pair_finite_and_sep_valid_local(rank1, min_sep, max_sep) && ...
        pair_finite_and_sep_valid_local(refocus, min_sep, max_sep) && ...
        ~low_cost_boundary && isfinite(pair_err) && pair_err <= agree_tol_deg;
end

function tf = pair_finite_and_sep_valid_local(result, min_sep, max_sep)
    az_est = getfield_default_local(result, 'az_est', [NaN, NaN]);
    el_est = getfield_default_local(result, 'el_est', [NaN, NaN]);
    sep = getfield_default_local(result, 'pair_sep_est', NaN);
    if ~isfinite(sep) && numel(az_est) >= 2 && all(isfinite(az_est(1:2)))
        sep = abs(diff(sort(az_est(1:2))));
    end
    tf = numel(az_est) >= 2 && numel(el_est) >= 2 && ...
        all(isfinite(az_est(1:2))) && all(isfinite(el_est(1:2))) && ...
        isfinite(sep) && sep >= min_sep && sep <= max_sep;
end

function err = pair_error_swap_invariant_local(pair_a, pair_b)
    err = NaN;
    if numel(pair_a) < 2 || numel(pair_b) < 2
        return
    end
    pair_a = pair_a(1:2);
    pair_b = pair_b(1:2);
    if any(~isfinite(pair_a)) || any(~isfinite(pair_b))
        return
    end
    direct = mean(abs(wrap180_local(pair_a(:).' - pair_b(:).')));
    swapped = mean(abs(wrap180_local(pair_a(:).' - fliplr(pair_b(:).'))));
    err = min(direct, swapped);
end

function route_name = selected_rank1_route_name_local(mode)
    switch char(mode)
        case 'rank1_refocus_consensus_gate'
            route_name = "common_el_refocus_power_rank1";
        otherwise
            route_name = "level2_rank1_fallback";
    end
end

function reason = selected_rank1_failure_reason_local(mode)
    switch char(mode)
        case 'rank1_refocus_consensus_gate'
            reason = "rank1_refocus_consensus_gate";
        case 'rank1_reliable_without_common_el_proxy'
            reason = "rank1_without_common_el_proxy";
        otherwise
            reason = "music_single_rank1_fallback";
    end
end

function tf = has_route_conflict_local(route_map)
    az_list = {};
    route_fields = {'music', 'rank1_fallback', 'common_el_refocus_rank1', ...
        'level3_2d_music', 'pair_el_local_covfit'};
    for i = 1:numel(route_fields)
        now = route_map.(route_fields{i});
        az_est = getfield_default_local(now, 'az_est', [NaN, NaN]);
        if numel(az_est) >= 2 && all(isfinite(az_est))
            az_list{end+1} = sort(az_est(:)).'; %#ok<AGROW>
        end
    end
    tf = false;
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

function result = make_boundary_result_local(route_map, route_name, confidence, reason)
    fallback = route_map.music;
    result = make_result_local(fallback.az_est, fallback.el_est, fallback.peak_count, NaN, reason);
    result.recommended_route = string(route_name);
    result.confidence_flag = string(confidence);
    result.failure_reason = string(reason);
    result.low_confidence_flag = true;
end

function route_map = make_empty_route_map_local()
    empty_result = make_empty_route_result_local("not_executed");
    route_map = make_route_map_local(empty_result, empty_result, empty_result, empty_result, empty_result);
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
    result = make_result_local([NaN, NaN], [NaN, NaN], 0, NaN, reason);
    result.recommended_route = "";
    result.confidence_flag = "";
    result.failure_reason = reason;
end

function result = make_result_local(az_est, el_est, peak_count, objective_best, reason)
    result = struct();
    result.az_est = az_est;
    result.el_est = el_est;
    result.peak_count = peak_count;
    result.objective_best = objective_best;
    result.objective_true_pair = NaN;
    result.objective_margin = NaN;
    result.objective_true_rank = NaN;
    result.el_common_est = NaN;
    result.el_hat = NaN;
    result.el_selection_method = "";
    result.focused_power_peak_sharpness = NaN;
    result.lambda1_peak_sharpness = NaN;
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
    result.topk_candidates = struct([]);
    result.refocus_power_topk_el = [];
    result.recommended_route = "";
    result.confidence_flag = "";
    result.low_confidence_flag = false;
end

function topk = make_rank1_topk_candidates_local(score, candidate_pairs, az_grid, k)
    score = score(:);
    if isempty(score)
        topk = struct([]);
        return
    end
    [scores_sorted, ord] = sort(score, 'ascend');
    n = min(k, numel(scores_sorted));
    topk = repmat(struct('rank', NaN, 'score', NaN, 'score_gap_ratio', NaN, ...
        'az_pair', [NaN, NaN], 'pair_sep_deg', NaN), n, 1);
    best = scores_sorted(1);
    for i = 1:n
        idx = ord(i);
        pair_idx = candidate_pairs(idx, :);
        az_pair = sort(az_grid(pair_idx));
        topk(i).rank = i;
        topk(i).score = scores_sorted(i);
        topk(i).score_gap_ratio = (scores_sorted(i) - best) / max(best, eps);
        topk(i).az_pair = az_pair(:).';
        topk(i).pair_sep_deg = diff(az_pair);
    end
end

function topk_el = topk_el_local(curve, el_grid, k)
    curve = curve(:);
    if isempty(curve)
        topk_el = struct([]);
        return
    end
    [scores_sorted, ord] = sort(curve, 'descend');
    n = min(k, numel(scores_sorted));
    topk_el = repmat(struct('rank', NaN, 'el', NaN, 'score', NaN, 'score_gap_ratio', NaN), n, 1);
    best = scores_sorted(1);
    for i = 1:n
        topk_el(i).rank = i;
        topk_el(i).el = el_grid(ord(i));
        topk_el(i).score = scores_sorted(i);
        topk_el(i).score_gap_ratio = (best - scores_sorted(i)) / max(best, eps);
    end
end

function topk = make_refocus_topk_candidates_local( ...
    Rfb_curve, cache_map, el_grid, az_grid, power_topk_el)
    if ~isstruct(power_topk_el) || isempty(power_topk_el)
        topk = struct([]);
        return
    end
    n = numel(power_topk_el);
    topk = repmat(struct('rank', NaN, 'score', NaN, 'score_gap_ratio', NaN, ...
        'az_pair', [NaN, NaN], 'pair_sep_deg', NaN, 'el_hat', NaN), n, 1);
    for i = 1:n
        rank_i = getfield_default_local(power_topk_el(i), 'rank', i);
        el_hat = getfield_default_local(power_topk_el(i), 'el', NaN);
        ie = find(abs(el_grid - el_hat) <= 1e-12, 1, 'first');
        if isempty(ie)
            continue
        end
        Rfb = Rfb_curve{ie};
        cand = score_level2_cache_local(Rfb, cache_map(ie), az_grid);
        topk(i).rank = rank_i;
        topk(i).score = getfield_default_local(cand, 'residual_norm', NaN);
        topk(i).score_gap_ratio = getfield_default_local(cand, 'score_gap_ratio', NaN);
        topk(i).az_pair = pair_or_nan_local(getfield_default_local(cand, 'az_est', [NaN, NaN]));
        topk(i).pair_sep_deg = getfield_default_local(cand, 'pair_sep_est', NaN);
        topk(i).el_hat = el_hat;
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
            vals(1) = -2*(alpha*gy + sigma2*iy) + alpha^2*gg + ...
                2*alpha*sigma2*gi + sigma2^2*ii;
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

function [lambda1, lambda2, lambda_noise_mean, lambda2_over_noise, lambda2_over_lambda1, effective_rank_proxy] = eigen_proxy_from_vals_local(evals)
    evals = real(evals(:));
    evals = max(evals, 0);
    if isempty(evals)
        lambda1 = NaN;
        lambda2 = NaN;
        lambda_noise_mean = NaN;
        lambda2_over_noise = NaN;
        lambda2_over_lambda1 = NaN;
        effective_rank_proxy = NaN;
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

function sharpness = peak_sharpness_local(curve)
    curve = real(curve(:));
    [mx, idx] = max(curve);
    tmp = curve;
    tmp(idx) = -inf;
    second = max(tmp);
    sharpness = (mx - second) / max(abs(mx), eps);
end

function reason = failure_reason_pair_local(az_est, el_est, min_sep, max_sep)
    if any(~isfinite(az_est)) || any(~isfinite(el_est))
        reason = 'nonfinite_pair';
    elseif abs(diff(sort(az_est))) < min_sep
        reason = 'pair_sep_too_small';
    elseif abs(diff(sort(az_est))) > max_sep
        reason = 'pair_sep_too_large';
    else
        reason = 'ok';
    end
end

function Rfbss = mssp_array_fb_local(Rxx, K)
    N = size(Rxx, 1);
    P = N - K + 1;
    Rf = zeros(K, K);
    for p = 1:P
        idx = p:p+K-1;
        Rf = Rf + Rxx(idx, idx);
    end
    Rf = Rf / P;
    J = fliplr(eye(K));
    Rfbss = 0.5 * (Rf + J * conj(Rf) * J);
    Rfbss = 0.5 * (Rfbss + Rfbss');
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

function score2 = second_score_local(score, best_idx)
    if isempty(score)
        score2 = NaN;
        return
    end
    mask = true(size(score));
    mask(best_idx) = false;
    if any(mask)
        score2 = min(score(mask));
    else
        score2 = score(best_idx);
    end
end

function timing = init_timing_local()
    timing = struct();
    timing.t_level2_music = 0;
    timing.t_level2_rank1 = 0;
    timing.t_refocus = 0;
    timing.t_2dmusic = 0;
    timing.t_pair_local = 0;
    timing.t_total = 0;
    timing.executed_level2_music = false;
    timing.executed_refocus = false;
    timing.executed_level2_rank1 = false;
    timing.executed_2dmusic = false;
    timing.executed_pair_local = false;
    timing.executed_stage_count = 0;
    timing.early_stop_stage = NaN;
    timing.early_stop_flag = false;
    timing.route_map = struct();
end

function timing = finish_timing_local(timing, t_all, early_stop_stage, early_stop_flag, route_map)
    timing.t_total = toc(t_all);
    timing.executed_stage_count = double(timing.executed_level2_music) + ...
        double(timing.executed_refocus) + double(timing.executed_level2_rank1) + ...
        double(timing.executed_2dmusic) + double(timing.executed_pair_local);
    timing.early_stop_stage = early_stop_stage;
    timing.early_stop_flag = early_stop_flag;
    timing.route_map = route_map;
end

function val = getfield_default_local(s, name, default_val)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        val = s.(name);
    else
        val = default_val;
    end
end

function cfg = set_default_local(cfg, name, value)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = value;
    end
end

function out = ternary_local(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function x = wrap180_local(x)
    x = mod(x + 180, 360) - 180;
end
