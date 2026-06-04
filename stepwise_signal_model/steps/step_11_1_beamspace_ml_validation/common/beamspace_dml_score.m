function [score, debug] = beamspace_dml_score(Z, G, varargin)
%BEAMSPACE_DML_SCORE Deterministic ML score in beamspace.

if nargin < 2
    error('beamspace_dml_score:NotEnoughInputs', 'Z and G are required.');
end
if ndims(Z) ~= 2 || ndims(G) ~= 2
    error('beamspace_dml_score:InvalidDims', 'Z and G must be two-dimensional matrices.');
end
if size(Z, 1) ~= size(G, 1)
    error('beamspace_dml_score:BeamDimMismatch', ...
        'size(Z,1) must equal size(G,1). Got %d and %d.', size(Z, 1), size(G, 1));
end

reg = parse_reg_local(varargin{:});
B = size(Z, 1);
L = size(Z, 2);
K = size(G, 2);

if K < 1
    error('beamspace_dml_score:EmptyManifold', 'G must have at least one column.');
end
if L < 1
    error('beamspace_dml_score:EmptySnapshots', 'Z must have at least one snapshot.');
end

GHG = G' * G + reg * eye(K);
P = G / GHG * G';
score = real(trace(P * (Z * Z')));

debug = struct();
debug.cond_GHG = cond(GHG);
debug.rank_G = rank(G);
debug.score = score;
debug.B = B;
debug.L = L;
debug.K = K;
end

function reg = parse_reg_local(varargin)
reg = 1e-10;
if isempty(varargin)
    return;
end
if numel(varargin) == 1 && isnumeric(varargin{1})
    reg = varargin{1};
    return;
end
for idx = 1:2:numel(varargin)
    if idx + 1 > numel(varargin)
        error('beamspace_dml_score:InvalidNameValue', 'Name-value options must be paired.');
    end
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'reg'
            reg = value;
        otherwise
            error('beamspace_dml_score:UnknownOption', 'Unknown option: %s', name);
    end
end
if ~(isscalar(reg) && isfinite(reg) && reg >= 0)
    error('beamspace_dml_score:InvalidReg', 'reg must be a non-negative finite scalar.');
end
end
