function [est_ctf, debug] = search_pair2d_coarse_to_fine(Z, W, x, y, z, lambda, cfg)
%SEARCH_PAIR2D_COARSE_TO_FINE Run coarse topK search followed by local fine refinement.

if nargin < 7
    error('search_pair2d_coarse_to_fine:NotEnoughInputs', 'Z, W, x, y, z, lambda, and cfg are required.');
end
required = {'coarse_grid_cfg','refine_cfg','manifold_opts','search_opts','topK'};
for idx = 1:numel(required)
    if ~isfield(cfg, required{idx})
        error('search_pair2d_coarse_to_fine:MissingCfgField', 'cfg.%s is required.', required{idx});
    end
end

[top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, x, y, z, lambda, ...
    cfg.coarse_grid_cfg, cfg.manifold_opts, cfg.search_opts, cfg.topK);
[est_refined, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, x, y, z, lambda, ...
    top_candidates, cfg.refine_cfg, cfg.manifold_opts, cfg.search_opts);

est_ctf = est_refined;
debug = struct();
debug.search_mode = 'degree_based_coarse_to_fine';
debug.coarse_num_pairs = coarse_debug.num_pairs;
debug.refine_num_pairs = refine_debug.num_pairs;
debug.total_num_pairs = coarse_debug.num_pairs + refine_debug.num_pairs;
debug.num_pairs = debug.total_num_pairs;
debug.topK = cfg.topK;
debug.max_score = refine_debug.max_score;
debug.cond_best_GHG = refine_debug.cond_best_GHG;
debug.rank_best_G = refine_debug.rank_best_G;
debug.top_candidates = top_candidates;
debug.coarse_debug = coarse_debug;
debug.refine_debug = refine_debug;
end
