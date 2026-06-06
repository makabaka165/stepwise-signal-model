function cluster_indicator = compute_frontend_cluster_indicators(scan_out)
%COMPUTE_FRONTEND_CLUSTER_INDICATORS Compute observable beam-spread indicators.

[energy, az_grid, el_grid] = validate_scan_local(scan_out);
[AZ, EL] = meshgrid(az_grid, el_grid);
weights = energy(:);
weights = weights / sum(weights);
az_mean = sum(AZ(:) .* weights);
el_mean = sum(EL(:) .* weights);
az_spread = sqrt(sum(((AZ(:) - az_mean).^2) .* weights));
el_spread = sqrt(sum(((EL(:) - el_mean).^2) .* weights));
sorted_energy = sort(energy(:), 'descend');
top1 = sorted_energy(1);
top2 = sorted_energy(min(2, numel(sorted_energy)));

cluster_indicator = struct();
cluster_indicator.beam_spread_indicator = sqrt(az_spread^2 + el_spread^2);
cluster_indicator.az_spread_deg = az_spread;
cluster_indicator.el_spread_deg = el_spread;
cluster_indicator.local_peak_count = sum(energy(:) >= 0.5 * top1);
cluster_indicator.top1_top2_ratio = top1 / max(top2, eps);
cluster_indicator.cluster_score = min(1, cluster_indicator.beam_spread_indicator / 0.8);
cluster_indicator.used_truth = false;
end

function [energy, az_grid, el_grid] = validate_scan_local(scan_out)
required = {'beam_energy_norm_grid','az_grid','el_grid'};
for idx = 1:numel(required)
    if ~isfield(scan_out, required{idx})
        error('compute_frontend_cluster_indicators:MissingScanField', ...
            'scan_out.%s is required.', required{idx});
    end
end
energy = scan_out.beam_energy_norm_grid;
az_grid = scan_out.az_grid(:).';
el_grid = scan_out.el_grid(:).';
if ~isnumeric(energy) || any(~isfinite(energy(:))) || sum(energy(:)) <= 0
    error('compute_frontend_cluster_indicators:InvalidEnergy', ...
        'scan_out.beam_energy_norm_grid must be positive finite numeric.');
end
if ~isequal(size(energy), [numel(el_grid), numel(az_grid)])
    error('compute_frontend_cluster_indicators:EnergyGridMismatch', ...
        'Energy grid size must be numel(el_grid) x numel(az_grid).');
end
end
