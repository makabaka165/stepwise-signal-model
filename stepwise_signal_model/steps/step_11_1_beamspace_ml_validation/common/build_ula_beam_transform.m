function [W, info] = build_ula_beam_transform(array_num, d, lambda, beam_angles_deg, varargin)
%BUILD_ULA_BEAM_TRANSFORM Build a ULA beamspace transform matrix.

if nargin < 4
    error('build_ula_beam_transform:NotEnoughInputs', 'Four inputs are required.');
end
if ~(isscalar(array_num) && array_num > 0 && array_num == floor(array_num))
    error('build_ula_beam_transform:InvalidArrayNum', 'array_num must be a positive integer scalar.');
end
if ~(isscalar(d) && isfinite(d) && d > 0)
    error('build_ula_beam_transform:InvalidSpacing', 'd must be a positive finite scalar.');
end
if ~(isscalar(lambda) && isfinite(lambda) && lambda > 0)
    error('build_ula_beam_transform:InvalidLambda', 'lambda must be a positive finite scalar.');
end

beam_angles_deg = beam_angles_deg(:).';
if isempty(beam_angles_deg) || any(~isfinite(beam_angles_deg))
    error('build_ula_beam_transform:InvalidBeamAngles', 'beam_angles_deg must be a finite non-empty vector.');
end

position = d * (0:array_num-1).';
A = exp(-1j * 2*pi/lambda * position * sind(beam_angles_deg));

[win, window_name, window_fallback] = make_window_local(array_num);
win = win(:);
win_norm = norm(win);
if ~(isfinite(win_norm) && win_norm > 0)
    error('build_ula_beam_transform:InvalidWindow', 'Window norm must be positive and finite.');
end
win = win / win_norm;

W = diag(win) * A;

expected_shape = [array_num, numel(beam_angles_deg)];
if ~isequal(size(W), expected_shape)
    error('build_ula_beam_transform:ShapeMismatch', ...
        'W shape mismatch. Expected [%d %d], got [%d %d].', ...
        expected_shape(1), expected_shape(2), size(W, 1), size(W, 2));
end

info = struct();
info.array_num = array_num;
info.beam_angles_deg = beam_angles_deg;
info.beam_count = numel(beam_angles_deg);
info.d = d;
info.lambda = lambda;
info.windowName = window_name;
info.windowFallback = window_fallback;
info.W_shape = size(W);

if ~isempty(varargin)
    info.extraArgs = varargin;
end
end

function [win, window_name, window_fallback] = make_window_local(array_num)
window_fallback = '';

if exist('taylorwin', 'file') == 2
    try
        win = taylorwin(array_num, 25, -40);
        window_name = 'taylorwin';
        return;
    catch err
        window_fallback = ['taylorwin_error:' err.identifier];
    end
else
    window_fallback = 'taylorwin_not_found';
end

if exist('hann', 'file') == 2
    try
        win = hann(array_num);
        window_name = 'hann';
        if isempty(window_fallback)
            window_fallback = 'hann_used';
        else
            window_fallback = [window_fallback ';hann_used'];
        end
        return;
    catch err
        if isempty(window_fallback)
            window_fallback = ['hann_error:' err.identifier];
        else
            window_fallback = [window_fallback ';hann_error:' err.identifier];
        end
    end
end

if array_num == 1
    win = 1;
else
    n = (0:array_num-1).';
    win = 0.5 - 0.5*cos(2*pi*n/(array_num-1));
end
window_name = 'manual_hann';
if isempty(window_fallback)
    window_fallback = 'manual_hann_used';
else
    window_fallback = [window_fallback ';manual_hann_used'];
end

if ~any(win)
    win = ones(array_num, 1);
    window_name = 'ones';
    window_fallback = [window_fallback ';ones_used'];
end
end
