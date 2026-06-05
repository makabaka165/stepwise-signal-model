function [W_rand, idx_rand] = build_random_w_from_pool(W_pool, B, seed)
%BUILD_RANDOM_W_FROM_POOL Build a random sanity-baseline W from pool columns.

if nargin < 3
    seed = [];
end
if ~(isscalar(B) && isfinite(B) && B > 0 && B == floor(B))
    error('build_random_w_from_pool:InvalidB', 'B must be a positive integer.');
end
if B > size(W_pool, 2)
    error('build_random_w_from_pool:TooManyBeams', 'B cannot exceed pool size.');
end
if ~isempty(seed)
    rng(seed, 'twister');
end
idx_rand = sort(randperm(size(W_pool, 2), B));
W_rand = W_pool(:, idx_rand);
end

