function A_pair = build_ula_pair_manifold(theta_pair_deg, array_num, d, lambda)
%BUILD_ULA_PAIR_MANIFOLD Build a two-target ULA steering manifold.

if nargin ~= 4
    error('build_ula_pair_manifold:InvalidInputCount', 'Four inputs are required.');
end
if numel(theta_pair_deg) ~= 2 || any(~isfinite(theta_pair_deg(:)))
    error('build_ula_pair_manifold:InvalidThetaPair', 'theta_pair_deg must contain two finite angles.');
end
if ~(isscalar(array_num) && array_num > 0 && array_num == floor(array_num))
    error('build_ula_pair_manifold:InvalidArrayNum', 'array_num must be a positive integer scalar.');
end
if ~(isscalar(d) && isfinite(d) && d > 0)
    error('build_ula_pair_manifold:InvalidSpacing', 'd must be a positive finite scalar.');
end
if ~(isscalar(lambda) && isfinite(lambda) && lambda > 0)
    error('build_ula_pair_manifold:InvalidLambda', 'lambda must be a positive finite scalar.');
end

theta_pair_deg = theta_pair_deg(:).';
position = d * (0:array_num-1).';
A_pair = exp(-1j * 2*pi/lambda * position * sind(theta_pair_deg));

if ~isequal(size(A_pair), [array_num, 2])
    error('build_ula_pair_manifold:ShapeMismatch', ...
        'A_pair must be array_num x 2. Got [%d %d].', size(A_pair, 1), size(A_pair, 2));
end
end
