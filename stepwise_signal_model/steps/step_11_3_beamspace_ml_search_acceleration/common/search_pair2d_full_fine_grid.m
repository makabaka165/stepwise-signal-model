function [est, debug] = search_pair2d_full_fine_grid(Z, W, x, y, z, lambda, grid_cfg, manifold_opts, search_opts)
%SEARCH_PAIR2D_FULL_FINE_GRID Full controlled pair2d search wrapper.

[est, ~, debug0] = search_pair2d_degree_grid_precomputed(Z, W, x, y, z, lambda, ...
    grid_cfg, manifold_opts, search_opts);
debug = debug0;
debug.search_mode = 'full_fine_degree_grid';
debug.grid_cfg = grid_cfg;
debug.num_pairs = debug0.num_pairs;
debug.max_score = debug0.max_score;
debug.cond_best_GHG = debug0.cond_best_GHG;
debug.rank_best_G = debug0.rank_best_G;
end
