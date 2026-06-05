function [W, w_info] = build_recommended_w_from_step11_2(step112_dir, cfg, arrInfo, varargin)
%BUILD_RECOMMENDED_W_FROM_STEP11_2 Build Step11.2 greedy_combined_B7 W.

if nargin < 3
    error('build_recommended_w_from_step11_2:NotEnoughInputs', 'step112_dir, cfg, and arrInfo are required.');
end
opts = parse_opts_local(varargin{:});
common112_dir = fullfile(step112_dir, 'common');
if exist(common112_dir, 'dir') ~= 7
    error('build_recommended_w_from_step11_2:MissingCommonDir', 'Missing Step11.2 common dir: %s', common112_dir);
end
addpath(common112_dir);

x = arrInfo.xActVec;
y = arrInfo.yActVec;
z = arrInfo.zActVec;
lambda = cfg.arr.lambda;
az_c = cfg.beam.azSectorCenter;
el_c = cfg.beam.elSectorCenter;

[W_pool, pool_info] = build_existing_2d_beam_pool(x, y, z, az_c, el_c, lambda, cfg, ...
    'Mode', 'legacy_or_fallback', 'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, ...
    'AzPoolOffsets', -2.4:0.4:2.4, 'ElPoolOffsets', -1.6:0.4:1.6);
[A_patch, ~] = build_local_patch_dictionary(x, y, z, az_c + (-1.5:0.15:1.5), el_c + (-1.0:0.15:1.0), lambda, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign);
pair_set = build_pair_set_local(az_c, el_c + 0.31, [0.83, 1.27], [0, 0.37, 0.67], [1, -1]);

[selected_idx, W, history] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, opts.B, ...
    'Criterion', opts.criterion, 'Alpha', 1, 'Beta', 1, 'Gamma', 0.05, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Reg', opts.reg);
metrics = collect_w_design_metrics(sprintf('step11_2_%s_B%d', opts.criterion, opts.B), opts.B, W, A_patch, pair_set, ...
    x, y, z, lambda, 'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Reg', opts.reg);

w_info = struct();
w_info.B = opts.B;
w_info.criterion = opts.criterion;
w_info.selected_idx = selected_idx;
w_info.selection_history = history;
w_info.projection_loss = metrics.projection_loss;
w_info.max_corr = metrics.max_corr;
w_info.cond_WHW = metrics.cond_WHW;
w_info.pool_info = pool_info;
w_info.note = 'Step11.2 recommended greedy_combined_B7 W reconstructed locally';
end

function opts = parse_opts_local(varargin)
opts = struct();
opts.B = 7;
opts.criterion = 'combined';
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.reg = 1e-10;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('build_recommended_w_from_step11_2:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'b'
            opts.B = value;
        case 'criterion'
            opts.criterion = char(value);
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'reg'
            opts.reg = value;
        otherwise
            error('build_recommended_w_from_step11_2:UnknownOption', 'Unknown option: %s', name);
    end
end
end

function pair_set = build_pair_set_local(az_c, el_c, az_sep_list, el_sep_list, orientation_list)
pair_set = zeros(numel(az_sep_list) * numel(el_sep_list) * numel(orientation_list), 4);
idx = 0;
for iAz = 1:numel(az_sep_list)
    az_sep = az_sep_list(iAz);
    az_pair = az_c + [-az_sep/2, az_sep/2];
    for iEl = 1:numel(el_sep_list)
        el_sep = el_sep_list(iEl);
        for iOri = 1:numel(orientation_list)
            orientation = orientation_list(iOri);
            if el_sep == 0 && orientation == -1
                continue;
            end
            idx = idx + 1;
            if orientation == 1
                el_pair = el_c + [-el_sep/2, el_sep/2];
            else
                el_pair = el_c + [el_sep/2, -el_sep/2];
            end
            pair_set(idx, :) = [az_pair(1), el_pair(1), az_pair(2), el_pair(2)];
        end
    end
end
pair_set = pair_set(1:idx, :);
end

