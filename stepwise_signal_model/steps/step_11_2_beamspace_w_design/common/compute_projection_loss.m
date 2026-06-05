function [loss, debug] = compute_projection_loss(W, A_patch, varargin)
%COMPUTE_PROJECTION_LOSS Compute normalized projection residual.

if nargin < 2
    error('compute_projection_loss:NotEnoughInputs', 'W and A_patch are required.');
end
reg = parse_reg_local(varargin{:});
if size(W, 1) ~= size(A_patch, 1)
    error('compute_projection_loss:ShapeMismatch', 'size(W,1) must match size(A_patch,1).');
end
if isempty(W) || isempty(A_patch)
    error('compute_projection_loss:EmptyInput', 'W and A_patch must be non-empty.');
end

B = size(W, 2);
WHW = W' * W;
PWA = W * ((WHW + reg * eye(B)) \ (W' * A_patch));
den = norm(A_patch, 'fro');
if ~(isfinite(den) && den > 0)
    error('compute_projection_loss:ZeroDictionaryNorm', 'A_patch norm must be positive.');
end
loss = norm(A_patch - PWA, 'fro') / den;

debug = struct();
debug.cond_WHW = cond(WHW + reg * eye(B));
debug.B = B;
debug.N_patch = size(A_patch, 2);
debug.reg = reg;
debug.projected_energy_ratio = max(0, 1 - loss.^2);
end

function reg = parse_reg_local(varargin)
reg = 1e-10;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('compute_projection_loss:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'reg'
            reg = value;
        otherwise
            error('compute_projection_loss:UnknownOption', 'Unknown option: %s', name);
    end
end
if ~(isscalar(reg) && isfinite(reg) && reg > 0)
    error('compute_projection_loss:InvalidReg', 'Reg must be positive finite scalar.');
end
end

