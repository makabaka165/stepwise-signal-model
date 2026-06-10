function [input, truth, input_meta] = build_step11_7_frontend_like_input(context, scenario, center_az, trial_id, varargin)
%BUILD_STEP11_7_FRONTEND_LIKE_INPUT Build synthetic local input for Step11.7.
%
% This helper mimics the local Y_work and frontend coarse-center fields.  It
% never uses truth to decide backend policy; truth is returned separately for
% final evaluation metrics only.

opts = parse_opts_local(varargin{:});
geom = build_step11_6_canonical_geometry(context.cfg, center_az);
scenario = normalize_scenario_local(scenario);
el_center_true = context.el_center_nominal + context.el_center_offset;
az_true = geom.actual_center_az_deg + [-scenario.az_sep_deg / 2, scenario.az_sep_deg / 2];
if scenario.el_sep_deg == 0
    el_true = [el_center_true, el_center_true];
    true_orientation = 0;
elseif opts.alternate_true_orientation && mod(trial_id, 2) == 0
    el_true = el_center_true + [scenario.el_sep_deg / 2, -scenario.el_sep_deg / 2];
    true_orientation = -1;
else
    el_true = el_center_true + [-scenario.el_sep_deg / 2, scenario.el_sep_deg / 2];
    true_orientation = 1;
end

seed_now = opts.seed;
if ~isfinite(seed_now)
    seed_now = context.base_seed + 100000 * opts.center_index + 1000 * opts.scenario_index + trial_id + opts.seed_offset;
end

[Y, snapshot_truth] = make_cyl_pair2d_correlated_snapshots(geom.x_actual, geom.y_actual, geom.z_actual, ...
    az_true, el_true, context.lambda, opts.L, scenario.snr_db, ...
    'PhaseFactor', context.phase_factor, 'PhaseSign', context.phase_sign, ...
    'Rho', scenario.rho, 'PhaseDeg', scenario.phase_deg, ...
    'AmplitudeRatio', scenario.beta, 'Seed', seed_now, 'NormalizeSourcePower', true);

if strcmp(opts.reshape_mode, 'array_65x32xT')
    Y_work = reshape(Y, context.cfg.beam.subNaz, context.cfg.arr.Nel, []);
else
    Y_work = Y;
end

input = struct();
input.Y_work = Y_work;
input.frontend_state = opts.frontend_state;
input.coarseAz = geom.actual_center_az_deg + opts.az_center_bias_deg;
input.coarseEl = context.el_center_nominal + opts.el_center_bias_deg;
input.rangeIdx = opts.rangeIdx;
input.dopplerIdx = opts.dopplerIdx;
input.selectedCenterColumn = geom.selected_center_column;
input.selectedCenterAz = geom.actual_center_az_deg;
input.method_tag = opts.method_tag;

truth = struct();
truth.az_true = az_true;
truth.el_true = el_true;
truth.true_orientation = true_orientation;
truth.seed = seed_now;
truth.scenario = scenario;
truth.source_corr_empirical = snapshot_truth.source_corr_empirical;
truth.center_az_requested = center_az;
truth.actual_center_az = geom.actual_center_az_deg;
truth.selected_center_column = geom.selected_center_column;

input_meta = struct();
input_meta.geom = geom;
input_meta.input_shape = shape_text_local(size(Y_work));
input_meta.reshape_mode = opts.reshape_mode;
input_meta.az_center_bias_deg = opts.az_center_bias_deg;
input_meta.el_center_bias_deg = opts.el_center_bias_deg;
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.frontend_state = 'controlled_pair2d_candidate';
opts.az_center_bias_deg = 0;
opts.el_center_bias_deg = 0;
opts.reshape_mode = 'matrix_N_by_L';
opts.L = 64;
opts.seed = NaN;
opts.seed_offset = 0;
opts.center_index = 1;
opts.scenario_index = 1;
opts.alternate_true_orientation = true;
opts.rangeIdx = 1;
opts.dopplerIdx = 1;
opts.method_tag = 'step11_7_frontend_like_synthetic_input';
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_step11_7_frontend_like_input:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'frontendstate'
            opts.frontend_state = char(value);
        case 'azcenterbiasdeg'
            opts.az_center_bias_deg = value;
        case 'elcenterbiasdeg'
            opts.el_center_bias_deg = value;
        case 'reshapemode'
            opts.reshape_mode = char(value);
        case 'l'
            opts.L = value;
        case 'seed'
            opts.seed = value;
        case 'seedoffset'
            opts.seed_offset = value;
        case 'centerindex'
            opts.center_index = value;
        case 'scenarioindex'
            opts.scenario_index = value;
        case 'alternatetrueorientation'
            opts.alternate_true_orientation = logical(value);
        case 'rangeidx'
            opts.rangeIdx = value;
        case 'doppleridx'
            opts.dopplerIdx = value;
        case 'methodtag'
            opts.method_tag = char(value);
        otherwise
            error('build_step11_7_frontend_like_input:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function scenario = normalize_scenario_local(scenario)
if istable(scenario)
    names = scenario.Properties.VariableNames;
    s = struct();
    for idx = 1:numel(names)
        value = scenario.(names{idx});
        if iscell(value)
            value = value{1};
        elseif isstring(value)
            value = char(value);
        end
        s.(names{idx}) = value;
    end
    scenario = s;
end
if isfield(scenario, 'scenario_name') && isstring(scenario.scenario_name)
    scenario.scenario_name = char(scenario.scenario_name);
end
end

function text = shape_text_local(sz)
parts = cell(1, numel(sz));
for idx = 1:numel(sz)
    parts{idx} = sprintf('%d', sz(idx));
end
text = strjoin(parts, 'x');
end
