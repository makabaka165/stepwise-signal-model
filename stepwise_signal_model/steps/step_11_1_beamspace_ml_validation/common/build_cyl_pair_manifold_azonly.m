function A_pair = build_cyl_pair_manifold_azonly(x, y, z, az_pair_deg, el0_deg, lambda, varargin)
%BUILD_CYL_PAIR_MANIFOLD_AZONLY Build a two-azimuth cylindrical manifold.

if nargin < 6
    error('build_cyl_pair_manifold_azonly:NotEnoughInputs', 'Six inputs are required.');
end
if numel(az_pair_deg) ~= 2 || any(~isfinite(az_pair_deg(:)))
    error('build_cyl_pair_manifold_azonly:InvalidAzPair', 'az_pair_deg must contain two finite azimuths.');
end

az_pair_deg = az_pair_deg(:).';
a1 = build_cyl_steering_vec(x, y, z, az_pair_deg(1), el0_deg, lambda, varargin{:});
a2 = build_cyl_steering_vec(x, y, z, az_pair_deg(2), el0_deg, lambda, varargin{:});
A_pair = [a1, a2];

if ~isequal(size(A_pair), [numel(x(:)), 2])
    error('build_cyl_pair_manifold_azonly:ShapeMismatch', 'A_pair must be N_elem x 2.');
end
end
