function [Y, truth] = make_cyl_pair2d_correlated_snapshots(x, y, z, az_pair_deg, el_pair_deg, lambda, L, snr_db, varargin)
%MAKE_CYL_PAIR2D_CORRELATED_SNAPSHOTS Generate two-source correlated cylindrical snapshots.

if nargin < 8
    error('make_cyl_pair2d_correlated_snapshots:NotEnoughInputs', ...
        'x, y, z, az_pair_deg, el_pair_deg, lambda, L, and snr_db are required.');
end
opts = parse_options_local(varargin{:});
if ~isempty(opts.seed)
    rng(opts.seed, 'twister');
end
if ~(isscalar(L) && isfinite(L) && L > 0 && L == floor(L))
    error('make_cyl_pair2d_correlated_snapshots:InvalidL', 'L must be a positive integer.');
end
if ~(isscalar(snr_db) && isfinite(snr_db))
    error('make_cyl_pair2d_correlated_snapshots:InvalidSnr', 'snr_db must be a finite scalar.');
end

A_true = build_cyl_pair_manifold_el_separated(x, y, z, az_pair_deg, el_pair_deg, lambda, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);

s1 = exp(1j * 2*pi * rand(1, L));
u2 = exp(1j * 2*pi * rand(1, L));
rho = opts.rho;
phi_rad = opts.phase_deg * pi / 180;
uncorr_weight = sqrt(max(1 - rho^2, 0));

if opts.normalize_source_power
    s1 = s1 / rms_abs_local(s1);
    raw_s2 = rho * exp(1j * phi_rad) * s1 + uncorr_weight * u2;
    raw_s2 = raw_s2 / rms_abs_local(raw_s2);
    s2 = opts.beta * raw_s2;
else
    s2 = opts.beta * (rho * exp(1j * phi_rad) * s1 + uncorr_weight * u2);
end

Y_clean = A_true * [s1; s2];
noise_power = mean(abs(Y_clean(:)).^2) / 10^(snr_db/10);
noise = sqrt(noise_power/2) * (randn(size(Y_clean)) + 1j*randn(size(Y_clean)));
Y = Y_clean + noise;

corr_den = max(norm(s1) * norm(s2), eps);
source_corr_empirical = abs((s1 * s2') / corr_den);

truth = struct();
truth.az_pair_deg = az_pair_deg(:).';
truth.el_pair_deg = el_pair_deg(:).';
truth.el_center_deg = mean(truth.el_pair_deg);
truth.el_sep_deg = abs(diff(truth.el_pair_deg));
truth.rho = rho;
truth.phase_deg = opts.phase_deg;
truth.beta = opts.beta;
truth.snr_db = snr_db;
truth.source_corr_empirical = source_corr_empirical;
truth.noise_power = noise_power;
truth.Y_shape = size(Y);
truth.normalize_source_power = opts.normalize_source_power;
end

function opts = parse_options_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.rho = 0.0;
opts.phase_deg = 0.0;
opts.beta = 0.8;
opts.seed = [];
opts.normalize_source_power = true;
if isempty(varargin)
    validate_opts_local(opts);
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('make_cyl_pair2d_correlated_snapshots:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'rho'
            opts.rho = value;
        case 'phasedeg'
            opts.phase_deg = value;
        case 'amplituderatio'
            opts.beta = value;
        case 'seed'
            opts.seed = value;
        case 'normalizesourcepower'
            opts.normalize_source_power = logical(value);
        otherwise
            error('make_cyl_pair2d_correlated_snapshots:UnknownOption', 'Unknown option: %s', name);
    end
end
validate_opts_local(opts);
end

function validate_opts_local(opts)
if ~(isscalar(opts.phase_factor) && isfinite(opts.phase_factor))
    error('make_cyl_pair2d_correlated_snapshots:InvalidPhaseFactor', 'PhaseFactor must be finite scalar.');
end
if ~(isscalar(opts.phase_sign) && isfinite(opts.phase_sign) && (opts.phase_sign == 1 || opts.phase_sign == -1))
    error('make_cyl_pair2d_correlated_snapshots:InvalidPhaseSign', 'PhaseSign must be +1 or -1.');
end
if ~(isscalar(opts.rho) && isfinite(opts.rho) && opts.rho >= 0 && opts.rho <= 1)
    error('make_cyl_pair2d_correlated_snapshots:InvalidRho', 'Rho must be in [0, 1].');
end
if ~(isscalar(opts.phase_deg) && isfinite(opts.phase_deg))
    error('make_cyl_pair2d_correlated_snapshots:InvalidPhaseDeg', 'PhaseDeg must be finite scalar.');
end
if ~(isscalar(opts.beta) && isfinite(opts.beta) && opts.beta > 0)
    error('make_cyl_pair2d_correlated_snapshots:InvalidBeta', 'AmplitudeRatio must be positive finite scalar.');
end
if ~isempty(opts.seed) && ~(isscalar(opts.seed) && isfinite(opts.seed))
    error('make_cyl_pair2d_correlated_snapshots:InvalidSeed', 'Seed must be empty or a finite scalar.');
end
end

function v = rms_abs_local(x)
v = sqrt(mean(abs(x(:)).^2));
if ~(isfinite(v) && v > 0)
    error('make_cyl_pair2d_correlated_snapshots:ZeroRms', 'Source RMS must be positive.');
end
end
