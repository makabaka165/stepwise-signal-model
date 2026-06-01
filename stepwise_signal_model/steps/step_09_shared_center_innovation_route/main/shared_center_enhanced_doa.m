function out = shared_center_enhanced_doa(frontend_out, raw_cube, array_geom, cfg)
%SHARED_CENTER_ENHANCED_DOA Final shared-center enhanced DOA entry point.
%
% The routine follows the final thesis route:
% frontend state -> shared-center 65-column subarray -> Y_work -> local
% cylindrical MUSIC -> coherent rank-1 fallback -> local 2-D refinement ->
% conservative confidence/boundary rejection.

if nargin < 4
    cfg = struct();
end
cfg = normalize_cfg_local(cfg);

state = getfield_default_local(frontend_out, 'frontend_state', '');
if ~strcmp(char(state), 'single_peak_in_scope')
    out = make_reject_output_local(frontend_out, state);
    return
end

cfg.coarseEl = getfield_default_local(frontend_out, 'coarseEl', cfg.coarseEl);
cfg.frontend_unresolved_cluster = getfield_default_local( ...
    frontend_out, 'unresolved_cluster_flag', cfg.frontend_unresolved_cluster);
cfg.need_2d_refinement = getfield_default_local( ...
    frontend_out, 'need_2d_refinement', cfg.need_2d_refinement);
cfg.boundary_unreliable_flag = getfield_default_local( ...
    frontend_out, 'boundary_unreliable_flag', cfg.boundary_unreliable_flag);

selected = shared_center_select_subarray(frontend_out.coarseAz, array_geom, cfg);
Y_work = build_y_work_from_frontend(raw_cube, frontend_out, selected, cfg);

music_info = local_cylindrical_music_test(Y_work, selected, array_geom, cfg);
if music_info.is_two_peak_resolvable && music_info.confidence_ok && ~music_info.need_2d_refinement
    out = make_route_output_local('music_two_peak', 'success', 'high', ...
        music_info.az_est, music_info.el_est, frontend_out, selected, Y_work, ...
        music_info, struct(), struct(), cfg);
    return
end

coherent_info = coherent_rank1_refocus_fallback(Y_work, selected, array_geom, music_info, cfg);
if coherent_info.valid && coherent_info.confidence_ok
    out = make_route_output_local('common_el_rank1_refocus', 'success', 'medium', ...
        coherent_info.az_est, coherent_info.el_est, frontend_out, selected, Y_work, ...
        music_info, coherent_info, struct(), cfg);
    return
end

pair2d_info = struct('valid', false, 'confidence_ok', false, ...
    'az_est', [], 'el_est', [], 'reason', 'not_evaluated');
if music_info.need_2d_refinement
    pair2d_info = local_2d_pair_refinement(Y_work, selected, array_geom, cfg);
    if pair2d_info.valid && pair2d_info.confidence_ok
        out = make_route_output_local('local_2d_pair_refinement', 'success', 'medium', ...
            pair2d_info.az_est, pair2d_info.el_est, frontend_out, selected, Y_work, ...
            music_info, coherent_info, pair2d_info, cfg);
        return
    end
end

out = confidence_boundary_rejector(music_info, coherent_info, pair2d_info, cfg);
out.frontend_state = char(state);
out.selected = selected;
out.selectedCenterColumn = selected.selectedCenterColumn;
out.selectedWorkColumns = selected.selectedWorkColumns;
out.Y_work_shape = size(Y_work);
out.derotation_mode = cfg.derotation_mode;
out.music_info = music_info;
out.coherent_info = coherent_info;
out.pair2d_info = pair2d_info;
end

function cfg = normalize_cfg_local(cfg)
    cfg = set_default_local(cfg, 'Q_work_columns', 65);
    cfg = set_default_local(cfg, 'Q', cfg.Q_work_columns);
    cfg = set_default_local(cfg, 'num_sources', 2);
    cfg = set_default_local(cfg, 'coarseEl', 0);
    cfg = set_default_local(cfg, 'derotation_mode', 'none');
    cfg = set_default_local(cfg, 'frontend_unresolved_cluster', true);
    cfg = set_default_local(cfg, 'need_2d_refinement', false);
    cfg = set_default_local(cfg, 'boundary_unreliable_flag', false);
end

function cfg = set_default_local(cfg, name, value)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = value;
    end
end

function out = make_reject_output_local(frontend_out, state)
    out = struct();
    out.method = 'shared-center MUSIC enhanced DOA';
    out.status = 'rejected';
    out.route_name = 'frontend_reject';
    out.confidence = 'low';
    out.az_est = [];
    out.el_est = [];
    out.frontend_state = char(state);
    out.reject_reason = frontend_reject_reason_local(state);
    out.frontend_out = frontend_out;
    out.selectedWorkColumns = [];
    out.Y_work_shape = [];
    out.derotation_mode = 'none';
end

function reason = frontend_reject_reason_local(state)
    state = char(state);
    switch state
        case 'two_separated_peaks_out_of_scope'
            reason = 'front-end resolved two separated coarse peaks; route is out of current scope';
        case 'weak_secondary_low_confidence'
            reason = 'weak secondary candidate is kept as low confidence, not forced into pair solving';
        case 'near_antiphase_boundary'
            reason = 'near anti-phase boundary is protected as boundary_unreliable';
        otherwise
            reason = sprintf('frontend_state=%s is not single_peak_in_scope', state);
    end
end

function out = make_route_output_local(route_name, status, confidence, az_est, el_est, ...
    frontend_out, selected, Y_work, music_info, coherent_info, pair2d_info, cfg)

    out = struct();
    out.method = 'shared-center MUSIC enhanced DOA';
    out.status = status;
    out.route_name = route_name;
    out.confidence = confidence;
    out.az_est = az_est(:).';
    out.el_est = el_est(:).';
    out.frontend_state = char(frontend_out.frontend_state);
    out.reject_reason = '';
    out.frontend_out = frontend_out;
    out.selected = selected;
    out.selectedCenterColumn = selected.selectedCenterColumn;
    out.selectedWorkColumns = selected.selectedWorkColumns;
    out.Y_work_shape = size(Y_work);
    out.derotation_mode = cfg.derotation_mode;
    out.music_info = music_info;
    out.coherent_info = coherent_info;
    out.pair2d_info = pair2d_info;
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end
