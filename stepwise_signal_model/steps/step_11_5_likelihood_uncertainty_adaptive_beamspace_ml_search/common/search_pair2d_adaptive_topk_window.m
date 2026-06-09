function [est_adaptive, debug_adaptive] = search_pair2d_adaptive_topk_window(Z, W, x, y, z, lambda, ...
    grid_cfg_coarse, base_refine_cfg, manifold_opts, search_opts, policy_cfg)
%SEARCH_PAIR2D_ADAPTIVE_TOPK_WINDOW Step11.5 adaptive topK-window wrapper.
%
% This function preserves the Step11.3 controlled pair2d beamspace DML
% score. It first obtains topK_max coarse candidates, computes
% likelihood-landscape uncertainty features, chooses a deterministic
% topK/window policy, then calls Step11.3 local refinement on the retained
% prefix of the coarse candidates.

if nargin < 11 || isempty(policy_cfg)
    policy_cfg = struct();
end
policy_cfg = fill_policy_defaults_local(policy_cfg);

debug_adaptive = make_debug_template_local(policy_cfg);
topK_max = policy_cfg.topK_max;

[top_candidates, coarse_debug] = search_pair2d_coarse_grid_topk(Z, W, x, y, z, lambda, ...
    grid_cfg_coarse, manifold_opts, search_opts, topK_max);
features = compute_likelihood_landscape_features(top_candidates, coarse_debug, grid_cfg_coarse, search_opts, ...
    'TopKMax', topK_max, 'Tau', policy_cfg.tau);
policy = select_adaptive_topk_window_policy(features, base_refine_cfg, policy_cfg);
adaptive_topK = min(policy.adaptive_topK, numel(top_candidates));
selected_candidates = top_candidates(1:adaptive_topK);

adaptive_refine_cfg = base_refine_cfg;
adaptive_refine_cfg.local_az_half_width = policy.adaptive_local_az_half_width;
adaptive_refine_cfg.local_el_center_half_width = policy.adaptive_local_el_center_half_width;
if ~isfield(adaptive_refine_cfg, 'fine_el_sep_deg_list') && isfield(base_refine_cfg, 'el_sep_deg_list')
    adaptive_refine_cfg.fine_el_sep_deg_list = base_refine_cfg.el_sep_deg_list;
end

debug_adaptive.features = features;
debug_adaptive.policy = policy;
debug_adaptive.coarse_debug = coarse_debug;
debug_adaptive.top_candidates = top_candidates;
debug_adaptive.selected_candidates = selected_candidates;
debug_adaptive.adaptive_refine_cfg = adaptive_refine_cfg;
debug_adaptive.num_pairs_coarse = coarse_debug.num_pairs;
debug_adaptive.topK_max = topK_max;
debug_adaptive.adaptive_topK = adaptive_topK;
debug_adaptive.confidence = policy.confidence;
debug_adaptive.boundary_flag = policy.boundary_flag;

try
    [est_adaptive, refine_debug] = search_pair2d_local_refine_from_topk(Z, W, x, y, z, lambda, ...
        selected_candidates, adaptive_refine_cfg, manifold_opts, search_opts);
    est_adaptive.max_score = refine_debug.max_score;
    est_adaptive.score = refine_debug.max_score;
    debug_adaptive.refine_debug = refine_debug;
    debug_adaptive.num_pairs_refine = refine_debug.num_pairs;
    debug_adaptive.num_pairs_total = coarse_debug.num_pairs + refine_debug.num_pairs;
    debug_adaptive.num_pairs = debug_adaptive.num_pairs_total;
    debug_adaptive.max_score = refine_debug.max_score;
    debug_adaptive.cond_best_GHG = refine_debug.cond_best_GHG;
    debug_adaptive.rank_best_G = refine_debug.rank_best_G;
catch ME
    est_adaptive = make_failed_est_local();
    debug_adaptive.refine_debug = struct();
    debug_adaptive.num_pairs_refine = 0;
    debug_adaptive.num_pairs_total = coarse_debug.num_pairs;
    debug_adaptive.num_pairs = debug_adaptive.num_pairs_total;
    debug_adaptive.failure_reason = 'adaptive_failure_no_candidate_rows';
    debug_adaptive.failure_detail = ME.message;
    debug_adaptive.confidence = 'low';
    if isempty(debug_adaptive.boundary_flag)
        debug_adaptive.boundary_flag = 'adaptive_failure_no_candidate_rows';
    end
end
end

function policy_cfg = fill_policy_defaults_local(policy_cfg)
if ~isfield(policy_cfg, 'topK_max')
    policy_cfg.topK_max = 7;
end
if ~isfield(policy_cfg, 'tau')
    policy_cfg.tau = 0.02;
end
end

function debug_adaptive = make_debug_template_local(policy_cfg)
debug_adaptive = struct();
debug_adaptive.search_mode = 'likelihood_uncertainty_adaptive_topk_window';
debug_adaptive.features = struct();
debug_adaptive.policy = struct();
debug_adaptive.coarse_debug = struct();
debug_adaptive.refine_debug = struct();
debug_adaptive.num_pairs_coarse = NaN;
debug_adaptive.num_pairs_refine = NaN;
debug_adaptive.num_pairs_total = NaN;
debug_adaptive.num_pairs = NaN;
debug_adaptive.topK_max = policy_cfg.topK_max;
debug_adaptive.adaptive_topK = NaN;
debug_adaptive.confidence = '';
debug_adaptive.boundary_flag = '';
debug_adaptive.failure_reason = '';
debug_adaptive.failure_detail = '';
debug_adaptive.top_candidates = [];
debug_adaptive.selected_candidates = [];
debug_adaptive.max_score = NaN;
debug_adaptive.cond_best_GHG = NaN;
debug_adaptive.rank_best_G = NaN;
end

function est = make_failed_est_local()
est = struct();
est.az_hat = [NaN, NaN];
est.el_hat = [NaN, NaN];
est.el_center_hat = NaN;
est.el_sep_hat = NaN;
est.orientation_hat = NaN;
est.max_score = NaN;
est.score = NaN;
end
