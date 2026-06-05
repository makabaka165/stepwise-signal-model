function [est, debug] = search_pair2d_full_fine_grid(Z, W, x, y, z, lambda, grid_cfg, manifold_opts, search_opts)
%SEARCH_PAIR2D_FULL_FINE_GRID Full controlled pair2d search wrapper.

grid = precompute_beamspace_azel_grid(W, x, y, z, grid_cfg.az_grid, grid_cfg.el_grid, lambda, ...
    'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);
cfg = struct();
cfg.whitening_mode = search_opts.whitening_mode;
cfg.reg = search_opts.reg;
cfg.el_sep_index_list = grid_cfg.el_sep_index_list;
cfg.search_orientations = grid_cfg.search_orientations;
cfg.keep_score_cube = false;
[est, ~, debug0] = search_pair_grid_el_separation_precomputed(Z, W, grid, cfg);
debug = debug0;
debug.search_mode = 'full_fine_grid';
debug.grid_cfg = grid_cfg;
debug.num_pairs = debug0.num_pairs;
debug.max_score = debug0.max_score;
debug.cond_best_GHG = debug0.cond_best_GHG;
debug.rank_best_G = debug0.rank_best_G;
end

