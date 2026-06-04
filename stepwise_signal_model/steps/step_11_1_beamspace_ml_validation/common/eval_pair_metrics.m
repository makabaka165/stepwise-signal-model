function metrics = eval_pair_metrics(theta_hat, theta_true, search_bounds, tol_deg)
%EVAL_PAIR_METRICS Evaluate two-target angle-estimation metrics.

if nargin ~= 4
    error('eval_pair_metrics:InvalidInputCount', 'Four inputs are required.');
end
if numel(theta_true) ~= 2 || any(~isfinite(theta_true(:)))
    error('eval_pair_metrics:InvalidThetaTrue', 'theta_true must contain two finite angles.');
end
if numel(search_bounds) ~= 2 || any(~isfinite(search_bounds(:)))
    error('eval_pair_metrics:InvalidBounds', 'search_bounds must contain two finite values.');
end
if ~(isscalar(tol_deg) && isfinite(tol_deg) && tol_deg >= 0)
    error('eval_pair_metrics:InvalidTol', 'tol_deg must be a non-negative finite scalar.');
end

theta_hat = theta_hat(:).';
theta_true = theta_true(:).';
search_bounds = sort(search_bounds(:).');

raw_success = (numel(theta_hat) == 2) && all(isfinite(theta_hat));

metrics = struct();
metrics.raw_success = raw_success;
metrics.tol_success = false;
metrics.rmse_deg = NaN;
metrics.center_error_deg = NaN;
metrics.sep_error_deg = NaN;
metrics.boundary_hit = false;

if ~raw_success
    return;
end

theta_hat_sorted = sort(theta_hat);
theta_true_sorted = sort(theta_true);
err = theta_hat_sorted - theta_true_sorted;

metrics.tol_success = max(abs(err)) <= tol_deg;
metrics.rmse_deg = sqrt(mean(err.^2));
metrics.center_error_deg = mean(theta_hat_sorted) - mean(theta_true_sorted);
metrics.sep_error_deg = diff(theta_hat_sorted) - diff(theta_true_sorted);
metrics.boundary_hit = any(abs(theta_hat_sorted - search_bounds(1)) <= 0.01) || ...
    any(abs(theta_hat_sorted - search_bounds(2)) <= 0.01);
end
