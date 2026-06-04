function metrics = eval_full4d_pair_metrics(est, az_true, el_true, az_bounds, el_bounds, az_tol_deg, el_tol_deg)
%EVAL_FULL4D_PAIR_METRICS Evaluate two-target az/el estimates by az ordering.

if nargin ~= 7
    error('eval_full4d_pair_metrics:InvalidInputCount', 'Seven inputs are required.');
end
if ~isstruct(est) || ~isfield(est, 'az_hat') || ~isfield(est, 'el_hat')
    error('eval_full4d_pair_metrics:InvalidEst', 'est must contain az_hat and el_hat.');
end
if numel(az_true) ~= 2 || any(~isfinite(az_true(:)))
    error('eval_full4d_pair_metrics:InvalidAzTrue', 'az_true must contain two finite values.');
end
if numel(el_true) ~= 2 || any(~isfinite(el_true(:)))
    error('eval_full4d_pair_metrics:InvalidElTrue', 'el_true must contain two finite values.');
end

az_hat = est.az_hat(:).';
el_hat = est.el_hat(:).';
az_true = az_true(:).';
el_true = el_true(:).';
az_bounds = sort(az_bounds(:).');
el_bounds = sort(el_bounds(:).');

raw_success = numel(az_hat) == 2 && numel(el_hat) == 2 && all(isfinite(az_hat)) && all(isfinite(el_hat));

metrics = struct();
metrics.raw_success = raw_success;
metrics.az_tol_success = false;
metrics.el_tol_success = false;
metrics.joint_tol_success = false;
metrics.az_rmse_deg = NaN;
metrics.el_rmse_deg = NaN;
metrics.az_center_error_deg = NaN;
metrics.az_sep_error_deg = NaN;
metrics.abs_az_sep_error_deg = NaN;
metrics.el_center_error_deg = NaN;
metrics.el_sep_error_deg = NaN;
metrics.abs_el_sep_error_deg = NaN;
metrics.estimated_el_sep_deg = NaN;
metrics.true_el_sep_deg = abs(diff(el_true));
metrics.boundary_hit = false;

if ~raw_success
    return;
end

[az_hat_sorted, est_order] = sort(az_hat);
el_hat_sorted = el_hat(est_order);
[az_true_sorted, true_order] = sort(az_true);
el_true_sorted = el_true(true_order);

az_err = az_hat_sorted - az_true_sorted;
el_err = el_hat_sorted - el_true_sorted;
estimated_el_sep = abs(diff(el_hat_sorted));
true_el_sep = abs(diff(el_true_sorted));

metrics.az_tol_success = max(abs(az_err)) <= az_tol_deg;
metrics.el_tol_success = max(abs(el_err)) <= el_tol_deg;
metrics.joint_tol_success = metrics.az_tol_success && metrics.el_tol_success;
metrics.az_rmse_deg = sqrt(mean(az_err.^2));
metrics.el_rmse_deg = sqrt(mean(el_err.^2));
metrics.az_center_error_deg = mean(az_hat_sorted) - mean(az_true_sorted);
metrics.az_sep_error_deg = diff(az_hat_sorted) - diff(az_true_sorted);
metrics.abs_az_sep_error_deg = abs(metrics.az_sep_error_deg);
metrics.el_center_error_deg = mean(el_hat_sorted) - mean(el_true_sorted);
metrics.el_sep_error_deg = estimated_el_sep - true_el_sep;
metrics.abs_el_sep_error_deg = abs(metrics.el_sep_error_deg);
metrics.estimated_el_sep_deg = estimated_el_sep;
metrics.true_el_sep_deg = true_el_sep;
metrics.boundary_hit = any(abs(az_hat_sorted - az_bounds(1)) <= 0.02) || ...
    any(abs(az_hat_sorted - az_bounds(2)) <= 0.02) || ...
    any(abs(el_hat_sorted - el_bounds(1)) <= 0.05) || ...
    any(abs(el_hat_sorted - el_bounds(2)) <= 0.05);
end
