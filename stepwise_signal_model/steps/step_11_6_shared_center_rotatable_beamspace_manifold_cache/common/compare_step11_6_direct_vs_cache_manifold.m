function trial_table = compare_step11_6_direct_vs_cache_manifold(W, cfg, cache, center_az_list, delta_az_grid, el_values, lambda, manifold_opts)
%COMPARE_STEP11_6_DIRECT_VS_CACHE_MANIFOLD Compare direct global and canonical cached manifolds.
%
% This function verifies the Step11.6 rotation-equivalence claim numerically
% for both element-domain steering vectors and beamspace G=W'*a.

if nargin < 8 || isempty(manifold_opts)
    manifold_opts = struct();
end
manifold_opts = fill_opts_local(manifold_opts);

rows = repmat(make_row_template_local(), numel(center_az_list) * numel(delta_az_grid) * numel(el_values), 1);
row_idx = 0;
geom0 = build_step11_6_canonical_geometry(cfg, 0);

for iCenter = 1:numel(center_az_list)
    geom = build_step11_6_canonical_geometry(cfg, center_az_list(iCenter));
    for iDelta = 1:numel(delta_az_grid)
        delta_az = delta_az_grid(iDelta);
        global_az = geom.actual_center_az_deg + delta_az;
        for iEl = 1:numel(el_values)
            el = el_values(iEl);
            a_direct = build_cyl_steering_vec(geom.x_actual, geom.y_actual, geom.z_actual, global_az, el, lambda, ...
                'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);
            a_cache = build_cyl_steering_vec(geom0.x_canonical, geom0.y_canonical, geom0.z_canonical, delta_az, el, lambda, ...
                'PhaseFactor', manifold_opts.phase_factor, 'PhaseSign', manifold_opts.phase_sign);
            G_direct = W' * a_direct;
            [G_lookup, lookup_info] = lookup_step11_6_beamspace_cache(cache, global_az, el, ...
                'CenterAzDeg', geom.actual_center_az_deg, 'InputAzMode', 'global', 'ErrorOnMiss', false);
            if lookup_info.cache_miss_count > 0
                G_cache = NaN(size(G_direct));
            else
                G_cache = G_lookup(:, 1, 1);
            end

            row_idx = row_idx + 1;
            rows(row_idx) = make_row_local(center_az_list(iCenter), geom, delta_az, el, ...
                a_direct, a_cache, G_direct, G_cache, lookup_info.cache_miss_count);
        end
    end
end

rows = rows(1:row_idx);
trial_table = struct2table(rows);
end

function opts = fill_opts_local(opts)
if ~isfield(opts, 'phase_factor')
    opts.phase_factor = 1;
end
if ~isfield(opts, 'phase_sign')
    opts.phase_sign = 1;
end
end

function row = make_row_template_local()
row = struct();
row.requested_center_az = NaN;
row.actual_center_az = NaN;
row.selected_center_column = NaN;
row.delta_az = NaN;
row.el = NaN;
row.max_abs_a_error = NaN;
row.rel_a_error = NaN;
row.max_abs_G_error = NaN;
row.rel_G_error = NaN;
row.phase_aligned_rel_a_error = NaN;
row.phase_aligned_rel_G_error = NaN;
row.cache_miss_count = NaN;
row.pass_flag = false;
end

function row = make_row_local(requested_center, geom, delta_az, el, a_direct, a_cache, G_direct, G_cache, cache_miss_count)
row = make_row_template_local();
row.requested_center_az = requested_center;
row.actual_center_az = geom.actual_center_az_deg;
row.selected_center_column = geom.selected_center_column;
row.delta_az = delta_az;
row.el = el;
if cache_miss_count > 0 || any(~isfinite(G_cache(:)))
    row.cache_miss_count = cache_miss_count;
    row.pass_flag = false;
    return;
end
row.max_abs_a_error = max(abs(a_direct - a_cache));
row.rel_a_error = norm(a_direct - a_cache) / max(norm(a_direct), eps);
row.max_abs_G_error = max(abs(G_direct - G_cache));
row.rel_G_error = norm(G_direct - G_cache) / max(norm(G_direct), eps);
row.phase_aligned_rel_a_error = phase_aligned_error_local(a_direct, a_cache);
row.phase_aligned_rel_G_error = phase_aligned_error_local(G_direct, G_cache);
row.cache_miss_count = cache_miss_count;
row.pass_flag = row.rel_a_error <= 1e-8 && row.rel_G_error <= 1e-8 && cache_miss_count == 0;
end

function e = phase_aligned_error_local(x, y)
alpha = (y' * x) / max(y' * y, eps);
e = norm(x - alpha * y) / max(norm(x), eps);
e = real(e);
end
