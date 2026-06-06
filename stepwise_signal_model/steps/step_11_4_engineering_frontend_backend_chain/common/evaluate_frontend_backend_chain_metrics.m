function metrics = evaluate_frontend_backend_chain_metrics(est, debug, truth, backend_in, varargin)
%EVALUATE_FRONTEND_BACKEND_CHAIN_METRICS Evaluate backend output for Step11.4.

if nargin < 4
    error('evaluate_frontend_backend_chain_metrics:NotEnoughInputs', ...
        'est, debug, truth, and backend_in are required.');
end
opts = parse_opts_local(varargin{:});
validate_truth_local(truth);

pair_metrics = eval_el_separation_pair_metrics(est, truth.az_pair_deg, truth.el_pair_deg, ...
    backend_in.coarse_grid_cfg.az_bounds, backend_in.coarse_grid_cfg.el_bounds, ...
    opts.az_tol_deg, opts.el_tol_deg, opts.el_sep_tol_deg);
topK_miss = compute_topk_truth_proxy_miss_local(debug, truth, backend_in);

metrics = pair_metrics;
metrics.topK_miss = topK_miss;
metrics.num_pairs = get_debug_value_local(debug, 'num_pairs', NaN);
metrics.coarse_num_pairs = get_debug_value_local(debug, 'coarse_num_pairs', NaN);
metrics.refine_num_pairs = get_debug_value_local(debug, 'refine_num_pairs', NaN);
metrics.max_score = get_debug_value_local(debug, 'max_score', NaN);
metrics.success = metrics.joint_pair_tol_success;
end

function opts = parse_opts_local(varargin)
opts = struct('az_tol_deg', 0.15, 'el_tol_deg', 0.20, 'el_sep_tol_deg', 0.25);
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('evaluate_frontend_backend_chain_metrics:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'aztoldeg'
            opts.az_tol_deg = value;
        case 'eltoldeg'
            opts.el_tol_deg = value;
        case 'elseptoldeg'
            opts.el_sep_tol_deg = value;
        otherwise
            error('evaluate_frontend_backend_chain_metrics:UnknownOption', ...
                'Unknown option: %s', name);
    end
end
end

function validate_truth_local(truth)
required = {'az_pair_deg','el_pair_deg'};
for idx = 1:numel(required)
    if ~isfield(truth, required{idx})
        error('evaluate_frontend_backend_chain_metrics:MissingTruthField', ...
            'truth.%s is required.', required{idx});
    end
end
end

function topK_miss = compute_topk_truth_proxy_miss_local(debug, truth, backend_in)
topK_miss = true;
if ~isfield(debug, 'top_candidates') || isempty(debug.top_candidates)
    return;
end
az_true_sorted = sort(truth.az_pair_deg(:).');
el_center_true = mean(truth.el_pair_deg(:));
az_tol = backend_in.refine_cfg.local_az_half_width + backend_in.refine_cfg.fine_az_step / 2;
el_center_tol = backend_in.refine_cfg.local_el_center_half_width + backend_in.refine_cfg.fine_el_step / 2;
for idx = 1:numel(debug.top_candidates)
    cand = debug.top_candidates(idx);
    if ~isfield(cand, 'az_hat') || ~isfield(cand, 'el_center_hat')
        continue;
    end
    cand_az_sorted = sort(cand.az_hat(:).');
    if numel(cand_az_sorted) ~= 2
        continue;
    end
    az_ok = max(abs(cand_az_sorted - az_true_sorted)) <= az_tol;
    el_ok = abs(cand.el_center_hat - el_center_true) <= el_center_tol;
    if az_ok && el_ok
        topK_miss = false;
        return;
    end
end
end

function value = get_debug_value_local(debug, field, fallback)
if isfield(debug, field)
    value = debug.(field);
else
    value = fallback;
end
end
