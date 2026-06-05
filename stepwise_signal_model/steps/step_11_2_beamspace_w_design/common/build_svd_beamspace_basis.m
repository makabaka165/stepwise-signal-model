function [W_svd, svd_info] = build_svd_beamspace_basis(A_patch, B)
%BUILD_SVD_BEAMSPACE_BASIS Build the local manifold SVD upper-bound basis.

if nargin < 2
    error('build_svd_beamspace_basis:NotEnoughInputs', 'A_patch and B are required.');
end
if ~(isscalar(B) && isfinite(B) && B > 0 && B == floor(B))
    error('build_svd_beamspace_basis:InvalidB', 'B must be a positive integer.');
end

[U, S, ~] = svd(A_patch, 'econ');
B_eff = min(B, size(U, 2));
W_svd = U(:, 1:B_eff);
s = diag(S);
energy = s.^2;
energy_cumsum = cumsum(energy) / max(sum(energy), eps);

svd_info = struct();
svd_info.singular_values = s;
svd_info.energy_cumsum = energy_cumsum;
svd_info.energy_retained_B = energy_cumsum(B_eff);
svd_info.B = B_eff;
svd_info.requested_B = B;
svd_info.note = 'SVD is an information-retention upper bound, not a direct engineering beam.';
end

