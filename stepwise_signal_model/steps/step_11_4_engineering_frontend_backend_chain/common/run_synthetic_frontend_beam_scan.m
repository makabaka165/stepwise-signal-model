function scan_out = run_synthetic_frontend_beam_scan(Y, frontend_beam_pool)
%RUN_SYNTHETIC_FRONTEND_BEAM_SCAN Compute frontend beam-energy observations.

if nargin < 2
    error('run_synthetic_frontend_beam_scan:NotEnoughInputs', ...
        'Y and frontend_beam_pool are required.');
end
if ~isnumeric(Y) || ndims(Y) ~= 2 || isempty(Y) || any(~isfinite(Y(:)))
    error('run_synthetic_frontend_beam_scan:InvalidY', 'Y must be a finite numeric 2D matrix.');
end
if ~isstruct(frontend_beam_pool) || ~isfield(frontend_beam_pool, 'W')
    error('run_synthetic_frontend_beam_scan:InvalidPool', 'frontend_beam_pool.W is required.');
end
W_pool = frontend_beam_pool.W;
if size(W_pool, 1) ~= size(Y, 1)
    error('run_synthetic_frontend_beam_scan:DimensionMismatch', ...
        'size(frontend_beam_pool.W,1) must equal size(Y,1).');
end

beam_response = W_pool' * Y;
beam_energy_col = mean(abs(beam_response).^2, 2);
max_energy = max(beam_energy_col);
if ~(isfinite(max_energy) && max_energy > 0)
    error('run_synthetic_frontend_beam_scan:ZeroEnergy', 'Beam energy maximum must be positive.');
end
beam_energy_norm_col = beam_energy_col / max_energy;
[beam_energy_grid, beam_energy_norm_grid] = make_energy_grids_local(frontend_beam_pool, ...
    beam_energy_col, beam_energy_norm_col);

scan_out = struct();
scan_out.beam_response = beam_response;
scan_out.beam_energy_col = beam_energy_col;
scan_out.beam_energy_norm_col = beam_energy_norm_col;
scan_out.beam_energy_grid = beam_energy_grid;
scan_out.beam_energy_norm_grid = beam_energy_norm_grid;
scan_out.az_grid = frontend_beam_pool.az_grid;
scan_out.el_grid = frontend_beam_pool.el_grid;
scan_out.az_col = frontend_beam_pool.az_col(:);
scan_out.el_col = frontend_beam_pool.el_col(:);
scan_out.max_energy = max_energy;
scan_out.num_beams = numel(beam_energy_col);
scan_out.source = 'synthetic_frontend_beam_scan';
end

function [energy_grid, energy_norm_grid] = make_energy_grids_local(frontend_beam_pool, energy_col, energy_norm_col)
az_grid = frontend_beam_pool.az_grid(:).';
el_grid = frontend_beam_pool.el_grid(:).';
energy_grid = nan(numel(el_grid), numel(az_grid));
energy_norm_grid = nan(numel(el_grid), numel(az_grid));
for col = 1:numel(energy_col)
    [~, iAz] = min(abs(az_grid - frontend_beam_pool.az_col(col)));
    [~, iEl] = min(abs(el_grid - frontend_beam_pool.el_col(col)));
    energy_grid(iEl, iAz) = energy_col(col);
    energy_norm_grid(iEl, iAz) = energy_norm_col(col);
end
end
