function ok = is_valid_doa_success(doa_est, target_theta, tol_deg)
    if any(~isfinite(doa_est))
        ok = false;
        return;
    end

    doa_est = sort(doa_est(:).');
    target_theta = sort(target_theta(:).');

    if numel(doa_est) ~= numel(target_theta)
        ok = false;
        return;
    end

    err = abs(doa_est - target_theta);
    ok = all(err <= tol_deg);
end
