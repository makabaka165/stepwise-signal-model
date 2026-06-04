function A_pair = build_cyl_pair_manifold_el_separated(x, y, z, az_pair_deg, el_pair_deg, lambda, varargin)
%BUILD_CYL_PAIR_MANIFOLD_EL_SEPARATED Build a two-target cylindrical manifold with separate elevations.

if nargin < 6
    error('build_cyl_pair_manifold_el_separated:NotEnoughInputs', 'Six inputs are required.');
end
if numel(az_pair_deg) ~= 2 || any(~isfinite(az_pair_deg(:)))
    error('build_cyl_pair_manifold_el_separated:InvalidAzPair', 'az_pair_deg must contain two finite azimuths.');
end
if numel(el_pair_deg) ~= 2 || any(~isfinite(el_pair_deg(:)))
    error('build_cyl_pair_manifold_el_separated:InvalidElPair', 'el_pair_deg must contain two finite elevations.');
end

az_pair_deg = az_pair_deg(:).';
el_pair_deg = el_pair_deg(:).';
a1 = build_cyl_steering_vec(x, y, z, az_pair_deg(1), el_pair_deg(1), lambda, varargin{:});
a2 = build_cyl_steering_vec(x, y, z, az_pair_deg(2), el_pair_deg(2), lambda, varargin{:});
A_pair = [a1, a2];

if ~isequal(size(A_pair), [numel(x(:)), 2])
    error('build_cyl_pair_manifold_el_separated:ShapeMismatch', 'A_pair must be N_elem x 2.');
end
end
