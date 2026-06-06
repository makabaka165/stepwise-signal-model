function coarse_est = estimate_coarse_angle_from_frontend_beams(scan_out, method, varargin)
%ESTIMATE_COARSE_ANGLE_FROM_FRONTEND_BEAMS Estimate coarse angle from beam energy.

if nargin < 2
    error('estimate_coarse_angle_from_frontend_beams:NotEnoughInputs', ...
        'scan_out and method are required.');
end
opts = parse_opts_local(varargin{:});
[energy, az_grid, el_grid] = validate_scan_local(scan_out);
[AZ, EL] = meshgrid(az_grid, el_grid);
method = lower(char(method));

switch method
    case 'peak'
        [~, max_idx] = max(energy(:));
        selected_mask = false(size(energy));
        selected_mask(max_idx) = true;
    case 'centroid_top9'
        selected_mask = make_topk_mask_local(energy, min(opts.topK, numel(energy)));
    case 'centroid_threshold'
        selected_mask = energy >= opts.threshold_rel * max(energy(:));
    otherwise
        error('estimate_coarse_angle_from_frontend_beams:UnknownMethod', ...
            'Unknown method: %s', method);
end
if ~any(selected_mask(:))
    error('estimate_coarse_angle_from_frontend_beams:EmptySelection', ...
        'No frontend beams selected for method %s.', method);
end

weights = energy(selected_mask);
weights = weights / sum(weights);
coarse_az = sum(AZ(selected_mask) .* weights);
coarse_el = sum(EL(selected_mask) .* weights);

coarse_est = struct();
coarse_est.method = method;
coarse_est.coarse_az_deg = coarse_az;
coarse_est.coarse_el_deg = coarse_el;
coarse_est.selected_beam_count = nnz(selected_mask);
coarse_est.selected_energy_sum = sum(energy(selected_mask));
coarse_est.used_truth_for_center = false;
coarse_est.selected_mask = selected_mask;
end

function opts = parse_opts_local(varargin)
opts = struct('topK', 9, 'threshold_rel', 0.5);
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('estimate_coarse_angle_from_frontend_beams:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'topk'
            opts.topK = value;
        case 'thresholdrel'
            opts.threshold_rel = value;
        otherwise
            error('estimate_coarse_angle_from_frontend_beams:UnknownOption', ...
                'Unknown option: %s', name);
    end
end
end

function [energy, az_grid, el_grid] = validate_scan_local(scan_out)
required = {'beam_energy_norm_grid','az_grid','el_grid'};
for idx = 1:numel(required)
    if ~isfield(scan_out, required{idx})
        error('estimate_coarse_angle_from_frontend_beams:MissingScanField', ...
            'scan_out.%s is required.', required{idx});
    end
end
energy = scan_out.beam_energy_norm_grid;
az_grid = scan_out.az_grid(:).';
el_grid = scan_out.el_grid(:).';
if ~isnumeric(energy) || any(~isfinite(energy(:)))
    error('estimate_coarse_angle_from_frontend_beams:InvalidEnergy', ...
        'scan_out.beam_energy_norm_grid must be finite numeric.');
end
if ~isequal(size(energy), [numel(el_grid), numel(az_grid)])
    error('estimate_coarse_angle_from_frontend_beams:EnergyGridMismatch', ...
        'Energy grid size must be numel(el_grid) x numel(az_grid).');
end
end

function mask = make_topk_mask_local(energy, topK)
topK = max(1, floor(topK));
[~, order] = sort(energy(:), 'descend');
mask = false(size(energy));
mask(order(1:topK)) = true;
end
