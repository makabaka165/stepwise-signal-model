function metrics = compute_w_condition_metrics(W)
%COMPUTE_W_CONDITION_METRICS Compute rank and condition metrics for W.

if nargin < 1 || isempty(W)
    error('compute_w_condition_metrics:EmptyW', 'W must be non-empty.');
end
[N_elem, B] = size(W);
s = svd(W, 'econ');
C = W' * W;
eig_WHW = real(eig(0.5 * (C + C')));
eig_WHW = max(eig_WHW, 0);
energy = s.^2;
if sum(energy) > 0
    p = energy / sum(energy);
    effective_rank = exp(-sum(p(p > 0) .* log(p(p > 0))));
else
    effective_rank = 0;
end

metrics = struct();
metrics.B = B;
metrics.N_elem = N_elem;
metrics.cond_WHW = cond(W' * W + 1e-10 * eye(B));
metrics.rank_W = rank(W, 1e-8);
metrics.min_sv = min(s);
metrics.max_sv = max(s);
metrics.effective_rank = effective_rank;
metrics.min_eig_WHW = min(eig_WHW);
metrics.max_eig_WHW = max(eig_WHW);
end
