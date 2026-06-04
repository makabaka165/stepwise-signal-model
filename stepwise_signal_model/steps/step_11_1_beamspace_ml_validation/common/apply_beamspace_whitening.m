function [Z_out, G_out, winfo] = apply_beamspace_whitening(Z, G, W, mode, varargin)
%APPLY_BEAMSPACE_WHITENING Whiten beamspace snapshots and manifolds.

if nargin < 4
    error('apply_beamspace_whitening:NotEnoughInputs', 'Z, G, W, and mode are required.');
end
if ndims(Z) ~= 2 || ndims(G) ~= 2 || ndims(W) ~= 2
    error('apply_beamspace_whitening:InvalidDims', 'Z, G, and W must be matrices.');
end
if size(Z, 1) ~= size(W, 2)
    error('apply_beamspace_whitening:ZBeamDimMismatch', 'size(Z,1) must equal size(W,2).');
end
if size(G, 1) ~= size(W, 2)
    error('apply_beamspace_whitening:GBeamDimMismatch', 'size(G,1) must equal size(W,2).');
end

eps_reg = parse_eps_local(varargin{:});
mode = lower(char(mode));

winfo = struct();
winfo.mode = mode;
winfo.eps_reg = eps_reg;
winfo.cond_Cb = NaN;
winfo.min_eig_Cb = NaN;

switch mode
    case 'none'
        Z_out = Z;
        G_out = G;
        winfo.whitened = false;
    case 'white'
        Cb = W' * W;
        Cb = 0.5 * (Cb + Cb');
        [V, D] = eig(Cb);
        dval = real(diag(D));
        dval_clip = max(dval, eps_reg);
        Cinvhalf = V * diag(1 ./ sqrt(dval_clip)) * V';
        Z_out = Cinvhalf * Z;
        G_out = Cinvhalf * G;
        winfo.whitened = true;
        winfo.cond_Cb = cond(Cb + eps_reg * eye(size(Cb)));
        winfo.min_eig_Cb = min(dval);
    otherwise
        error('apply_beamspace_whitening:UnknownMode', 'Unknown whitening mode: %s', mode);
end
end

function eps_reg = parse_eps_local(varargin)
eps_reg = 1e-10;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('apply_beamspace_whitening:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'eps_reg'
            eps_reg = value;
        otherwise
            error('apply_beamspace_whitening:UnknownOption', 'Unknown option: %s', name);
    end
end
if ~(isscalar(eps_reg) && isfinite(eps_reg) && eps_reg > 0)
    error('apply_beamspace_whitening:InvalidEpsReg', 'eps_reg must be a positive finite scalar.');
end
end
