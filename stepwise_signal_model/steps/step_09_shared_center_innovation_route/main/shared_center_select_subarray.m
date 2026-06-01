function selected = shared_center_select_subarray(coarseAz, array_geom, cfg)
%SHARED_CENTER_SELECT_SUBARRAY Select the shared-center local cylinder.
%
% selectedCenterColumn = argmin_k |wrap180(phiCol(k) - coarseAz)|
% selectedWorkColumns = selectedCenterColumn + [-32, ..., 0, ..., +32]

if nargin < 3
    cfg = struct();
end
if isnumeric(cfg)
    Q = cfg;
else
    Q = getfield_default_local(cfg, 'Q_work_columns', getfield_default_local(cfg, 'Q', 65));
end

phiCol = get_phi_col_local(array_geom);
Naz = numel(phiCol);
if Q > Naz
    Q = Naz;
end
if mod(Q, 2) ~= 1
    error('shared_center_select_subarray:QMustBeOdd', ...
        'Q_work_columns must be odd so that one physical center column exists.');
end

[~, centerCol] = min(abs(wrap180_local(phiCol - coarseAz)));
halfSpan = (Q - 1) / 2;
offsets = -halfSpan:halfSpan;
cols = mod(centerCol - 1 + offsets, Naz) + 1;

selected = struct();
selected.coarseAz = coarseAz;
selected.selectedCenterColumn = centerCol;
selected.selectedCenterAz = phiCol(centerCol);
selected.centerAz = phiCol(centerCol);
selected.selectedWorkColumns = cols(:).';
selected.Q = Q;
selected.phiCol = phiCol;
selected.phiWork = phiCol(cols);
selected.phiWorkRel = wrap180_local(selected.phiWork - selected.selectedCenterAz);

if isfield(array_geom, 'X') && isfield(array_geom, 'Y') && isfield(array_geom, 'Z')
    selected.XWork = array_geom.X(cols, :);
    selected.YWork = array_geom.Y(cols, :);
    selected.ZWork = array_geom.Z(cols, :);
    selected.Nel = size(selected.XWork, 2);
else
    selected.XWork = [];
    selected.YWork = [];
    selected.ZWork = [];
    selected.Nel = getfield_default_local(array_geom, 'Nel', []);
end

if ~isempty(selected.Nel)
    [cc, rr] = ndgrid(cols, 1:selected.Nel);
    selected.workLinearIndices = sub2ind([Naz, selected.Nel], cc(:), rr(:));
else
    selected.workLinearIndices = [];
end
end

function phiCol = get_phi_col_local(array_geom)
    if isfield(array_geom, 'phiCol') && ~isempty(array_geom.phiCol)
        phiCol = array_geom.phiCol(:).';
    elseif isfield(array_geom, 'Naz') && ~isempty(array_geom.Naz)
        phiCol = (0:array_geom.Naz - 1) / array_geom.Naz * 360;
    elseif isfield(array_geom, 'X') && ~isempty(array_geom.X)
        Naz = size(array_geom.X, 1);
        phiCol = (0:Naz - 1) / Naz * 360;
    else
        error('shared_center_select_subarray:MissingGeometry', ...
            'array_geom must provide phiCol, Naz, or X/Y/Z coordinates.');
    end
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end

function ang = wrap180_local(ang)
    ang = mod(ang + 180, 360) - 180;
end
