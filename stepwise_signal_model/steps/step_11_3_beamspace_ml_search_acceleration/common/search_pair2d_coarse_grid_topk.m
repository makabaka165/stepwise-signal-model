function [top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, x, y, z, lambda, grid_cfg_coarse, manifold_opts, search_opts, topK)
%SEARCH_PAIR2D_COARSE_GRID_TOPK Coarse controlled pair2d search with topK retention.

if nargin < 10
    error('search_pair2d_coarse_grid_topk:NotEnoughInputs', ...
        'Z, W, x, y, z, lambda, grid_cfg_coarse, manifold_opts, search_opts, and topK are required.');
end
if ~(isscalar(topK) && isfinite(topK) && topK >= 1)
    error('search_pair2d_coarse_grid_topk:InvalidTopK', 'topK must be a positive scalar.');
end
topK = floor(topK);
[~, score_info, debug0] = search_pair2d_degree_grid_precomputed(Z, W, x, y, z, lambda, ...
    grid_cfg_coarse, manifold_opts, search_opts, 'ReturnTopK', true, 'TopK', topK);
top_candidates = score_info.top_candidates;
score_gap = 0;
if numel(top_candidates) >= 2
    score_gap = top_candidates(1).score - top_candidates(end).score;
end

coarse_debug = struct();
coarse_debug.search_mode = 'coarse_degree_grid_topk';
coarse_debug.whitening_mode = lower(char(search_opts.whitening_mode));
coarse_debug.num_pairs = debug0.num_pairs;
coarse_debug.topK_requested = topK;
coarse_debug.topK_returned = numel(top_candidates);
coarse_debug.finite_slice_count = NaN;
coarse_debug.max_score = top_candidates(1).score;
coarse_debug.score_gap_top1_topK = score_gap;
coarse_debug.best_i_az1 = debug0.best_i_az1;
coarse_debug.best_i_az2 = debug0.best_i_az2;
coarse_debug.best_i_el_center = debug0.best_i_el_center;
coarse_debug.best_el_sep_deg = debug0.best_el_sep_deg;
coarse_debug.best_orientation = debug0.best_orientation;
coarse_debug.cond_best_GHG = debug0.cond_best_GHG;
coarse_debug.rank_best_G = debug0.rank_best_G;
coarse_debug.cond_WHW = debug0.cond_WHW;
coarse_debug.whitening_info = debug0.whitening_info;
coarse_debug.grid_cfg = grid_cfg_coarse;
end
