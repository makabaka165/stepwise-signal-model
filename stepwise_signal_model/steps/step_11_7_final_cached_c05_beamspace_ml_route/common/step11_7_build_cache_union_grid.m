function [delta_grid, el_grid] = step11_7_build_cache_union_grid(cfg, policy_cfg, full_search_cfg, coarse_search_cfg, base_refine_cfg)
%STEP11_7_BUILD_CACHE_UNION_GRID Build exact cache grid for final route.
%
% The grid covers normal center use, +-0.20 deg frontend prior bias, and
% C05 local refine window scales.  It is still exact lookup only; no
% interpolation is introduced.

az_bias_values = [-0.20, 0, 0.20];
el_bias_values = [-0.20, 0, 0.20];
delta_values = [];
coarse_centers_delta = unique(round(az_bias_values * 1e10) / 1e10);
coarse_grid_offsets = -coarse_search_cfg.az_half_width:coarse_search_cfg.az_step:coarse_search_cfg.az_half_width;
for idx = 1:numel(coarse_centers_delta)
    delta_values = [delta_values, coarse_centers_delta(idx) + coarse_grid_offsets]; %#ok<AGROW>
end
delta_values = [delta_values, -1.8:base_refine_cfg.fine_az_step:1.8]; %#ok<AGROW>
az_widths = unique(round([base_refine_cfg.local_az_half_width, ...
    base_refine_cfg.local_az_half_width * policy_cfg.easy_window_scale, ...
    base_refine_cfg.local_az_half_width * policy_cfg.boundary_window_scale] * 1e10) / 1e10);
coarse_delta = unique(round(delta_values * 1e10) / 1e10);
for iBase = 1:numel(coarse_delta)
    for iWidth = 1:numel(az_widths)
        bounds = clamp_bounds_local(coarse_delta(iBase) + [-az_widths(iWidth), az_widths(iWidth)], [-1.95, 1.95]);
        delta_values = [delta_values, make_axis_local(bounds(1), bounds(2), base_refine_cfg.fine_az_step)]; %#ok<AGROW>
    end
end
delta_grid = unique(round(delta_values * 1e10) / 1e10);

el_center_nominal = cfg.beam.elSectorCenter;
el_center_candidates = [];
for bias = el_bias_values
    el_center_candidates = [el_center_candidates, el_center_nominal + bias + ...
        (-coarse_search_cfg.el_half_width:coarse_search_cfg.el_step:coarse_search_cfg.el_half_width)]; %#ok<AGROW>
end
el_values = pair_el_values_local(el_center_candidates, coarse_search_cfg.el_sep_deg_list, ...
    [el_center_nominal - 1.5, el_center_nominal + 1.5]);
el_widths = unique(round([base_refine_cfg.local_el_center_half_width, ...
    base_refine_cfg.local_el_center_half_width * policy_cfg.easy_window_scale, ...
    base_refine_cfg.local_el_center_half_width * policy_cfg.boundary_window_scale] * 1e10) / 1e10);
coarse_el_centers = unique(round(el_center_candidates * 1e10) / 1e10);
for iBase = 1:numel(coarse_el_centers)
    for iWidth = 1:numel(el_widths)
        bounds = clamp_bounds_local(coarse_el_centers(iBase) + [-el_widths(iWidth), el_widths(iWidth)], ...
            [el_center_nominal - 1.5, el_center_nominal + 1.5]);
        centers_now = make_axis_local(bounds(1), bounds(2), base_refine_cfg.fine_el_step);
        el_values = [el_values, pair_el_values_local(centers_now, base_refine_cfg.fine_el_sep_deg_list, ...
            [el_center_nominal - 1.5, el_center_nominal + 1.5])]; %#ok<AGROW>
    end
end
el_grid = unique(round(el_values * 1e10) / 1e10);
el_grid = el_grid(el_grid >= cfg.beam.elBeamMinDeg & el_grid <= cfg.beam.elBeamMaxDeg);
end

function values = pair_el_values_local(el_center_grid, el_sep_deg_list, el_bounds)
[~, ~, valid_mask, info] = make_el_pair_list_degree_based(el_center_grid, el_sep_deg_list, [1, -1], el_bounds);
rows = info.rows(valid_mask);
if isempty(rows)
    values = [];
else
    values = unique(round([[rows.el1], [rows.el2]] * 1e10) / 1e10);
end
end

function bounds = clamp_bounds_local(bounds, global_bounds)
global_bounds = sort(global_bounds(:).');
bounds = sort(bounds(:).');
bounds(1) = max(bounds(1), global_bounds(1));
bounds(2) = min(bounds(2), global_bounds(2));
end

function axis = make_axis_local(lo, hi, step)
axis = lo:step:hi;
if isempty(axis) || abs(axis(end) - hi) > 1e-9
    axis = [axis, hi];
end
axis = unique(round(axis * 1e10) / 1e10);
end
