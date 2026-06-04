function metrics = eval_el_separation_pair_metrics(est, az_true, el_true_pair, az_bounds, el_bounds, az_tol_deg, el_tol_deg, el_sep_tol_deg)
%EVAL_EL_SEPARATION_PAIR_METRICS Evaluate az/el pair estimates ordered by azimuth.

if nargin ~= 8
    error('eval_el_separation_pair_metrics:InvalidInputCount', 'Eight inputs are required.');
end
if ~isstruct(est) || ~isfield(est, 'az_hat') || ~isfield(est, 'el_hat')
    error('eval_el_separation_pair_metrics:InvalidEst', 'est must contain az_hat and el_hat.');
end
if numel(az_true) ~= 2 || any(~isfinite(az_true(:)))
    error('eval_el_separation_pair_metrics:InvalidAzTrue', 'az_true must contain two finite values.');
end
if numel(el_true_pair) ~= 2 || any(~isfinite(el_true_pair(:)))
    error('eval_el_separation_pair_metrics:InvalidElTrue', 'el_true_pair must contain two finite values.');
end

az_hat = est.az_hat(:).';
el_hat = est.el_hat(:).';
az_true = az_true(:).';
el_true_pair = el_true_pair(:).';
az_bounds = sort(az_bounds(:).');
el_bounds = sort(el_bounds(:).');

raw_success = numel(az_hat) == 2 && numel(el_hat) == 2 && all(isfinite(az_hat)) && all(isfinite(el_hat));

metrics = struct();
metrics.raw_success = raw_success;
metrics.az_tol_success = false;
metrics.el_pair_tol_success = false;
metrics.joint_pair_tol_success = false;
metrics.az_rmse_deg = NaN;
metrics.el_rmse_deg = NaN;
metrics.az_center_error_deg = NaN;
metrics.az_sep_error_deg = NaN;
metrics.el_center_error_deg = NaN;
metrics.el_sep_error_deg = NaN;
metrics.abs_el_sep_error_deg = NaN;
metrics.estimated_el_sep_deg = NaN;
metrics.true_el_sep_deg = abs(diff(el_true_pair));
metrics.false_el_split = false;
metrics.boundary_hit = false;

if ~raw_success
    return;
end

[az_hat_sorted, est_order] = sort(az_hat);
el_hat_sorted = el_hat(est_order);
[az_true_sorted, true_order] = sort(az_true);
el_true_sorted = el_true_pair(true_order);

az_err = az_hat_sorted - az_true_sorted;
el_err = el_hat_sorted - el_true_sorted;
estimated_el_sep = abs(diff(el_hat_sorted));
true_el_sep = abs(diff(el_true_sorted));

metrics.az_tol_success = max(abs(az_err)) <= az_tol_deg;
metrics.el_pair_tol_success = max(abs(el_err)) <= el_tol_deg;
metrics.joint_pair_tol_success = metrics.az_tol_success && metrics.el_pair_tol_success;
metrics.az_rmse_deg = sqrt(mean(az_err.^2));
metrics.el_rmse_deg = sqrt(mean(el_err.^2));
metrics.az_center_error_deg = mean(az_hat_sorted) - mean(az_true_sorted);
metrics.az_sep_error_deg = diff(az_hat_sorted) - diff(az_true_sorted);
metrics.el_center_error_deg = mean(el_hat_sorted) - mean(el_true_sorted);
metrics.el_sep_error_deg = estimated_el_sep - true_el_sep;
metrics.abs_el_sep_error_deg = abs(metrics.el_sep_error_deg);
metrics.estimated_el_sep_deg = estimated_el_sep;
metrics.true_el_sep_deg = true_el_sep;
metrics.false_el_split = true_el_sep <= 0.05 && estimated_el_sep > el_sep_tol_deg;
metrics.boundary_hit = any(abs(az_hat_sorted - az_bounds(1)) <= 0.02) || ...
    any(abs(az_hat_sorted - az_bounds(2)) <= 0.02) || ...
    any(abs(el_hat_sorted - el_bounds(1)) <= 0.05) || ...
    any(abs(el_hat_sorted - el_bounds(2)) <= 0.05);
end
