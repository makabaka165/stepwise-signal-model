function [Y, truth] = make_cyl_common_el_snapshots(x, y, z, az_pair_deg, el_common_deg, lambda, L, snr_db, source_mode, varargin)
%MAKE_CYL_COMMON_EL_SNAPSHOTS Generate cylindrical snapshots with common elevation.

if nargin < 9
    error('make_cyl_common_el_snapshots:NotEnoughInputs', 'Nine inputs are required.');
end
opts = parse_options_local(varargin{:});
if ~isempty(opts.seed)
    rng(opts.seed, 'twister');
end
if ~(isscalar(L) && isfinite(L) && L > 0 && L == floor(L))
    error('make_cyl_common_el_snapshots:InvalidL', 'L must be a positive integer.');
end
if ~(isscalar(snr_db) && isfinite(snr_db))
    error('make_cyl_common_el_snapshots:InvalidSnr', 'snr_db must be a finite scalar.');
end

A_true = build_cyl_pair_manifold_common_el(x, y, z, az_pair_deg, el_common_deg, lambda, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);

source_mode = lower(char(source_mode));
s1 = exp(1j * 2*pi * rand(1, L));
switch source_mode
    case 'noncoherent'
        s2 = opts.beta * exp(1j * 2*pi * rand(1, L));
    case 'coherent'
        s2 = opts.beta * exp(1j * opts.coherent_phase_deg * pi / 180) * s1;
    otherwise
        error('make_cyl_common_el_snapshots:UnknownSourceMode', 'Unknown source_mode: %s', source_mode);
end

Y_clean = A_true * [s1; s2];
noise_power = mean(abs(Y_clean(:)).^2) / 10^(snr_db/10);
noise = sqrt(noise_power/2) * (randn(size(Y_clean)) + 1j*randn(size(Y_clean)));
Y = Y_clean + noise;

truth = struct();
truth.az_pair_deg = az_pair_deg(:).';
truth.el_common_deg = el_common_deg;
truth.source_mode = source_mode;
truth.snr_db = snr_db;
truth.beta = opts.beta;
truth.coherent_phase_deg = opts.coherent_phase_deg;
truth.noise_power = noise_power;
truth.Y_shape = size(Y);
end

function opts = parse_options_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.beta = 0.8;
opts.coherent_phase_deg = 10;
opts.seed = [];
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('make_cyl_common_el_snapshots:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'amplituderatio'
            opts.beta = value;
        case 'coherentphasedeg'
            opts.coherent_phase_deg = value;
        case 'seed'
            opts.seed = value;
        otherwise
            error('make_cyl_common_el_snapshots:UnknownOption', 'Unknown option: %s', name);
    end
end
if ~(isscalar(opts.beta) && isfinite(opts.beta) && opts.beta > 0)
    error('make_cyl_common_el_snapshots:InvalidBeta', 'AmplitudeRatio must be a positive finite scalar.');
end
if ~(isscalar(opts.coherent_phase_deg) && isfinite(opts.coherent_phase_deg))
    error('make_cyl_common_el_snapshots:InvalidCoherentPhase', 'CoherentPhaseDeg must be a finite scalar.');
end
if ~isempty(opts.seed) && ~(isscalar(opts.seed) && isfinite(opts.seed))
    error('make_cyl_common_el_snapshots:InvalidSeed', 'Seed must be empty or a finite scalar.');
end
end
