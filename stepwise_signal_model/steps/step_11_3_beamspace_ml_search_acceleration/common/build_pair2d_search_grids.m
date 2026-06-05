function grid_cfg = build_pair2d_search_grids(az_center, el_center, search_cfg)
%BUILD_PAIR2D_SEARCH_GRIDS Build controlled pair2d az/el search grid config.

required = {'az_half_width','el_half_width','az_step','el_step','el_sep_index_list','search_orientations'};
for idx = 1:numel(required)
    if ~isfield(search_cfg, required{idx})
        error('build_pair2d_search_grids:MissingField', 'search_cfg.%s is required.', required{idx});
    end
end
az_bounds = az_center + [-search_cfg.az_half_width, search_cfg.az_half_width];
el_bounds = el_center + [-search_cfg.el_half_width, search_cfg.el_half_width];
az_grid = unique(round((az_bounds(1):search_cfg.az_step:az_bounds(2)) * 1e10) / 1e10);
el_grid = unique(round((el_bounds(1):search_cfg.el_step:el_bounds(2)) * 1e10) / 1e10);

N_az = numel(az_grid);
N_el = numel(el_grid);
num_oriented_sep = 0;
for iSep = 1:numel(search_cfg.el_sep_index_list)
    sep_idx = search_cfg.el_sep_index_list(iSep);
    if sep_idx == 0
        num_oriented_sep = num_oriented_sep + 1;
    else
        num_oriented_sep = num_oriented_sep + numel(search_cfg.search_orientations);
    end
end

grid_cfg = struct();
grid_cfg.az_grid = az_grid;
grid_cfg.el_grid = el_grid;
grid_cfg.az_step = search_cfg.az_step;
grid_cfg.el_step = search_cfg.el_step;
grid_cfg.el_sep_index_list = search_cfg.el_sep_index_list;
grid_cfg.search_orientations = search_cfg.search_orientations;
grid_cfg.az_bounds = az_bounds;
grid_cfg.el_bounds = el_bounds;
grid_cfg.estimated_num_candidates = nchoosek(N_az, 2) * N_el * num_oriented_sep;
grid_cfg.az_center = az_center;
grid_cfg.el_center = el_center;
end

