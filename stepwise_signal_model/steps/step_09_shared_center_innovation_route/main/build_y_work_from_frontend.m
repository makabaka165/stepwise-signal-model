function Y_work = build_y_work_from_frontend(raw_cube, frontend_out, selected, cfg)
%BUILD_Y_WORK_FROM_FRONTEND Extract the shared-center work tensor.
%
% Default output shape is Q x Nel x Np. Doppler de-rotation is intentionally
% off by default; it remains only an optional engineering field.

if nargin < 4
    cfg = struct();
end
mode = getfield_default_local(cfg, 'derotation_mode', 'none');
cols = selected.selectedWorkColumns;
Q = numel(cols);
Nel = selected.Nel;
if isempty(Nel)
    Nel = size(raw_cube, 2);
end

rangeIdx = getfield_default_local(frontend_out, 'rangeIdx', 1);
dopplerIdx = getfield_default_local(frontend_out, 'dopplerIdx', 1);

switch ndims(raw_cube)
    case 2
        Y_work = raw_cube(cols, :);
        Y_work = reshape(Y_work, Q, size(Y_work, 2), 1);
    case 3
        Y_work = raw_cube(cols, :, :);
        Y_work = reshape(Y_work, Q, size(Y_work, 2), size(Y_work, 3));
    case 4
        Y_work = raw_cube(cols, :, rangeIdx, dopplerIdx);
        Y_work = reshape(Y_work, Q, size(raw_cube, 2), 1);
    case 5
        Y_work = raw_cube(cols, :, rangeIdx, dopplerIdx, :);
        Y_work = reshape(Y_work, Q, size(raw_cube, 2), size(raw_cube, 5));
    otherwise
        error('build_y_work_from_frontend:UnsupportedCube', ...
            'raw_cube must be [Naz x Nel], [Naz x Nel x Np], [Naz x Nel x range x doppler], or [Naz x Nel x range x doppler x Np].');
end

if size(Y_work, 2) ~= Nel
    error('build_y_work_from_frontend:GeometryMismatch', ...
        'Selected geometry Nel=%d does not match raw_cube second dimension=%d.', Nel, size(Y_work, 2));
end

if ~strcmpi(char(mode), 'none')
    Y_work = apply_optional_derotation_local(Y_work, frontend_out, cfg, mode);
end
end

function Y = apply_optional_derotation_local(Y, frontend_out, cfg, mode)
    Np = size(Y, 3);
    if Np <= 1
        return
    end
    fd = getfield_default_local(cfg, 'dopplerHz', []);
    if isempty(fd) && isfield(cfg, 'fdAxis')
        dopplerIdx = getfield_default_local(frontend_out, 'dopplerIdx', 1);
        fd = cfg.fdAxis(dopplerIdx);
    end
    if isempty(fd)
        return
    end
    prf = getfield_default_local(cfg, 'prf', 1);
    n = reshape(0:Np - 1, 1, 1, []);
    switch lower(char(mode))
        case {'derotation_minus', 'minus'}
            phase = exp(-1j * 2 * pi * fd / prf * n);
        case {'derotation_plus', 'plus'}
            phase = exp(1j * 2 * pi * fd / prf * n);
        otherwise
            phase = ones(1, 1, Np);
    end
    Y = Y .* phase;
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end
