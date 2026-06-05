function metrics = compare_search_outputs(est_test, est_full, truth_metrics_test, truth_metrics_full, varargin)
%COMPARE_SEARCH_OUTPUTS Compare a test search output with the full fine-grid baseline.

opts = parse_opts_local(varargin{:});

[az_test, el_test] = sorted_pair_local(est_test);
[az_full, el_full] = sorted_pair_local(est_full);
az_diff = az_test - az_full;
el_diff = el_test - el_full;

score_test = extract_score_local(est_test);
score_full = extract_score_local(est_full);

metrics = struct();
metrics.same_as_full_grid = all(abs(az_diff) <= opts.az_match_tol_deg) && all(abs(el_diff) <= opts.el_match_tol_deg);
metrics.az_diff_vs_full = max(abs(az_diff));
metrics.el_diff_vs_full = max(abs(el_diff));
metrics.score_gap_vs_full = score_full - score_test;
metrics.test_el_sep_hat = extract_el_sep_local(est_test);
metrics.full_el_sep_hat = extract_el_sep_local(est_full);
metrics.el_sep_diff_vs_full = abs(metrics.test_el_sep_hat - metrics.full_el_sep_hat);
metrics.test_joint_success = logical(truth_metrics_test.joint_pair_tol_success);
metrics.full_joint_success = logical(truth_metrics_full.joint_pair_tol_success);
metrics.test_rmse = hypot(truth_metrics_test.az_rmse_deg, truth_metrics_test.el_rmse_deg);
metrics.full_rmse = hypot(truth_metrics_full.az_rmse_deg, truth_metrics_full.el_rmse_deg);
metrics.test_worse_than_full = (~metrics.test_joint_success && metrics.full_joint_success) || ...
    (metrics.test_rmse > metrics.full_rmse + opts.rmse_worse_tol_deg);
metrics.full_success_test_fail = metrics.full_joint_success && ~metrics.test_joint_success;
metrics.test_success_full_fail = metrics.test_joint_success && ~metrics.full_joint_success;
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.az_match_tol_deg = 0.04;
opts.el_match_tol_deg = 0.06;
opts.rmse_worse_tol_deg = 1e-9;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('compare_search_outputs:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'azmatchtoldeg'
            opts.az_match_tol_deg = value;
        case 'elmatchtoldeg'
            opts.el_match_tol_deg = value;
        case 'rmseworsetoldeg'
            opts.rmse_worse_tol_deg = value;
        otherwise
            error('compare_search_outputs:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function [az_sorted, el_sorted] = sorted_pair_local(est)
az = est.az_hat(:).';
el = est.el_hat(:).';
[az_sorted, order] = sort(az);
el_sorted = el(order);
end

function score = extract_score_local(est)
if isfield(est, 'score')
    score = est.score;
elseif isfield(est, 'max_score')
    score = est.max_score;
else
    score = NaN;
end
end

function el_sep = extract_el_sep_local(est)
if isfield(est, 'el_sep_hat')
    el_sep = est.el_sep_hat;
elseif isfield(est, 'el_hat') && numel(est.el_hat) == 2
    el_sep = abs(diff(est.el_hat(:).'));
else
    el_sep = NaN;
end
end
