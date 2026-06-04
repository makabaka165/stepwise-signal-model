function metrics = eval_common_el_pair_metrics(est, az_true, el_true, az_bounds, el_bounds, az_tol_deg, el_tol_deg)
%EVAL_COMMON_EL_PAIR_METRICS Evaluate az-pair plus common-el estimates.

if nargin ~= 7
    error('eval_common_el_pair_metrics:InvalidInputCount', 'Seven inputs are required.');
end
if ~isstruct(est) || ~isfield(est, 'az_hat') || ~isfield(est, 'el_hat')
    error('eval_common_el_pair_metrics:InvalidEst', 'est must contain az_hat and el_hat.');
end
if numel(az_true) ~= 2 || any(~isfinite(az_true(:)))
    error('eval_common_el_pair_metrics:InvalidAzTrue', 'az_true must contain two finite azimuths.');
end
if ~(isscalar(el_true) && isfinite(el_true))
    error('eval_common_el_pair_metrics:InvalidElTrue', 'el_true must be a finite scalar.');
end
if numel(az_bounds) ~= 2 || any(~isfinite(az_bounds(:))) || numel(el_bounds) ~= 2 || any(~isfinite(el_bounds(:)))
    error('eval_common_el_pair_metrics:InvalidBounds', 'az_bounds and el_bounds must contain two finite values.');
end
if ~(isscalar(az_tol_deg) && isfinite(az_tol_deg) && az_tol_deg >= 0)
    error('eval_common_el_pair_metrics:InvalidAzTol', 'az_tol_deg must be non-negative and finite.');
end
if ~(isscalar(el_tol_deg) && isfinite(el_tol_deg) && el_tol_deg >= 0)
    error('eval_common_el_pair_metrics:InvalidElTol', 'el_tol_deg must be non-negative and finite.');
end

az_hat = est.az_hat(:).';
el_hat = est.el_hat;
az_true = az_true(:).';
az_bounds = sort(az_bounds(:).');
el_bounds = sort(el_bounds(:).');

raw_success = numel(az_hat) == 2 && all(isfinite(az_hat)) && isfinite(el_hat);

metrics = struct();
metrics.raw_success = raw_success;
metrics.az_tol_success = false;
metrics.el_tol_success = false;
metrics.joint_tol_success = false;
metrics.az_rmse_deg = NaN;
metrics.az_center_error_deg = NaN;
metrics.az_sep_error_deg = NaN;
metrics.el_error_deg = NaN;
metrics.abs_el_error_deg = NaN;
metrics.boundary_hit = false;

if ~raw_success
    return;
end

az_hat_sorted = sort(az_hat);
az_true_sorted = sort(az_true);
az_err = az_hat_sorted - az_true_sorted;
el_err = el_hat - el_true;

metrics.az_tol_success = max(abs(az_err)) <= az_tol_deg;
metrics.el_tol_success = abs(el_err) <= el_tol_deg;
metrics.joint_tol_success = metrics.az_tol_success && metrics.el_tol_success;
metrics.az_rmse_deg = sqrt(mean(az_err.^2));
metrics.az_center_error_deg = mean(az_hat_sorted) - mean(az_true_sorted);
metrics.az_sep_error_deg = diff(az_hat_sorted) - diff(az_true_sorted);
metrics.el_error_deg = el_err;
metrics.abs_el_error_deg = abs(el_err);
metrics.boundary_hit = any(abs(az_hat_sorted - az_bounds(1)) <= 0.02) || ...
    any(abs(az_hat_sorted - az_bounds(2)) <= 0.02) || ...
    abs(el_hat - el_bounds(1)) <= 0.05 || abs(el_hat - el_bounds(2)) <= 0.05;
end
