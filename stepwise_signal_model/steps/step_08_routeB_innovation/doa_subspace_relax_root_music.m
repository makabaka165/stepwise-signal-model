function [doa_value, debug_info] = doa_subspace_relax_root_music( ...
    y, K, lambda, d, Lc, init_theta, max_outer_iter, angle_tol_stop_deg, min_sep_guard)
% Subspace-domain RELAX refinement on top of Route B Root-MUSIC initialization.

    if nargin < 5 || isempty(Lc)
        Lc = 2;
    end
    if nargin < 6
        init_theta = [];
    end
    if nargin < 7 || isempty(max_outer_iter)
        max_outer_iter = 6;
    end
    if nargin < 8 || isempty(angle_tol_stop_deg)
        angle_tol_stop_deg = 1e-3;
    end
    if nargin < 9 || isempty(min_sep_guard)
        min_sep_guard = 0.05;
    end

    if Lc ~= 2
        error('doa_subspace_relax_root_music: only Lc=2 is supported.');
    end

    [N, ~] = size(y);
    doa_value = nan(1, Lc);

    if isempty(init_theta)
        init_theta = doa_root_music_array(y, K, lambda, d, Lc);
    end
    init_theta = sort(init_theta(:).');

    if any(~isfinite(init_theta)) || numel(init_theta) ~= Lc
        debug_info = fill_debug_init_failed(init_theta, Lc);
        return;
    end

    theta_est = init_theta;
    theta_trace = nan(max_outer_iter, Lc);
    angle_update_trace = nan(max_outer_iter, 1);
    guard_applied_any = false;
    last_residual_power = NaN;

    posN = (0:N-1).';

    for outer = 1:max_outer_iter
        theta_prev = theta_est;

        for target_idx = 1:Lc
            other_idx = 3 - target_idx;

            A = build_steering_matrix(theta_est, posN, d, lambda);
            if rank(A) < Lc
                continue;
            end

            pinvA = pinv(A);
            cancel_matrix = A(:, other_idx) * pinvA(other_idx, :);
            y_residual = y - cancel_matrix * y;
            last_residual_power = mean(abs(y_residual(:)).^2);

            [theta_single, ~] = doa_root_music_array(y_residual, K, lambda, d, 1);
            if isfinite(theta_single(1))
                theta_est(target_idx) = theta_single(1);
            end
        end

        theta_est = sort(theta_est);
        if (theta_est(2) - theta_est(1)) < min_sep_guard
            theta_mid = mean(theta_est);
            theta_est = [theta_mid - min_sep_guard/2, theta_mid + min_sep_guard/2];
            guard_applied_any = true;
        end

        theta_trace(outer, :) = theta_est;
        angle_update_trace(outer) = max(abs(theta_est - theta_prev));

        if angle_update_trace(outer) < angle_tol_stop_deg
            break;
        end
    end

    outer_iter_used = outer;

    A_final = build_steering_matrix(theta_est, posN, d, lambda);
    if rank(A_final) == Lc
        pinvA_final = pinv(A_final);
        y_full_residual = y - A_final * (pinvA_final * y);
        final_residual_power = mean(abs(y_full_residual(:)).^2);
    else
        final_residual_power = last_residual_power;
    end

    doa_value = theta_est;
    debug_info.outer_iter_used = outer_iter_used;
    debug_info.theta_trace = theta_trace(1:outer_iter_used, :);
    debug_info.angle_update_trace = angle_update_trace(1:outer_iter_used);
    debug_info.init_theta = init_theta;
    debug_info.init_failed = false;
    debug_info.guard_applied = guard_applied_any;
    debug_info.final_residual_power = final_residual_power;
end

function A = build_steering_matrix(theta_est, posN, d, lambda)
    Lc = numel(theta_est);
    A = zeros(numel(posN), Lc);
    for kk = 1:Lc
        A(:, kk) = exp(-1j * 2*pi * posN * d * sind(theta_est(kk)) / lambda);
    end
end

function debug_info = fill_debug_init_failed(init_theta, Lc)
    debug_info.outer_iter_used = 0;
    debug_info.theta_trace = nan(0, Lc);
    debug_info.angle_update_trace = nan(0, 1);
    debug_info.init_theta = init_theta;
    debug_info.init_failed = true;
    debug_info.guard_applied = false;
    debug_info.final_residual_power = NaN;
end
