% Step13.1 FPGA/SoC DBF boundary quick/smoke validation.
%
% This script validates only the DBF boundary Z = W^H Y. It supports a
% synthetic smoke source and a Step11-compatible light source. It does not
% run the Step11.7 full backend, does not execute ML score search/topK/C05,
% does not move G_cache to FPGA, and does not claim formal closure.

clearvars;
close all;
clc;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(scriptDir));
resultsDir = fullfile(scriptDir, 'results_step13_fpga_soc_dbf_boundary');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

local_add_required_paths(repoRoot);

quickMode = true;
quickEnv = getenv('STEP13_QUICK_MODE');
if ~isempty(quickEnv)
    quickMode = ~strcmp(quickEnv, '0');
end

inputSourceRequested = lower(strtrim(getenv('STEP13_INPUT_SOURCE')));
if isempty(inputSourceRequested)
    inputSourceRequested = 'auto';
end
validSources = {'synthetic', 'step11_light', 'auto'};
if ~any(strcmp(inputSourceRequested, validSources))
    error('Step13:InvalidInputSource', ...
        'STEP13_INPUT_SOURCE must be synthetic, step11_light, or auto.');
end

rng(13);
cfg = local_default_cfg(quickMode);
inputInfo = local_resolve_input_source(cfg, repoRoot, resultsDir, inputSourceRequested);

W = inputInfo.W;
Y = inputInfo.Y;
Z_ref = W' * Y;
Rz_ref = Z_ref * Z_ref';
beamPowerRef = sum(abs(Z_ref).^2, 2);

modes = local_quant_modes();
trialRows = cell(numel(modes), 35);
summaryRows = cell(numel(modes), 26);

for im = 1:numel(modes)
    mode = modes(im);
    [Zq, qmeta] = local_quantized_dbf(W, Y, mode);
    Rzq = Zq * Zq';
    beamPowerQ = sum(abs(Zq).^2, 2);

    relZ = norm(Zq(:) - Z_ref(:), 2) / max(norm(Z_ref(:), 2), eps);
    maxAbsZ = max(abs(Zq(:) - Z_ref(:)));
    powerRel = norm(beamPowerQ(:) - beamPowerRef(:), 2) / max(norm(beamPowerRef(:), 2), eps);
    [~, rankRef] = sort(beamPowerRef, 'descend');
    [~, rankQ] = sort(beamPowerQ, 'descend');
    topBeamSame = double(rankRef(1) == rankQ(1));
    topK = min(cfg.topK, inputInfo.B_output_beams);
    topKSetPreservation = numel(intersect(rankRef(1:topK), rankQ(1:topK))) / topK;
    rankPreservation = local_pairwise_rank_preservation(beamPowerRef, beamPowerQ);
    rzRel = norm(Rzq(:) - Rz_ref(:), 2) / max(norm(Rz_ref(:), 2), eps);
    sameBackendInputShape = isequal(size(Y), inputInfo.expected_Y_matrix_shape);
    rzShapeSame = isequal(size(Rzq), size(Rz_ref));
    cpuSocReady = sameBackendInputShape && rzShapeSame && ~inputInfo.step11_7_full_backend_called;

    passFlag = relZ <= cfg.pass_z_rel_l2_error && ...
        powerRel <= cfg.pass_power_rel_error && ...
        topBeamSame == 1 && ...
        topKSetPreservation >= cfg.pass_topk_set_preservation && ...
        rankPreservation >= cfg.pass_rank_preservation && ...
        rzRel <= cfg.pass_rz_rel_error && ...
        qmeta.clip_rate == 0 && ...
        qmeta.overflow_rate == 0 && ...
        sameBackendInputShape && rzShapeSame && cpuSocReady;

    trialRows(im, :) = { ...
        inputInfo.input_source_requested, inputInfo.input_source_used, inputInfo.fallback_reason, ...
        inputInfo.step11_adapter_found_flag, inputInfo.step11_7_full_backend_called, ...
        inputInfo.W_method, inputInfo.Y_work_shape, inputInfo.Y_matrix_shape, ...
        inputInfo.Z_shape, inputInfo.Rz_shape, inputInfo.N_input_channels, ...
        inputInfo.B_output_beams, inputInfo.L_snapshots, mode.name, mode.w_bits, mode.y_bits, ...
        mode.z_bits, qmeta.scale_w, qmeta.scale_y, qmeta.scale_z, relZ, maxAbsZ, ...
        powerRel, topBeamSame, topKSetPreservation, rankPreservation, rzRel, ...
        qmeta.clip_rate, qmeta.overflow_rate, sameBackendInputShape, rzShapeSame, ...
        cpuSocReady, passFlag, inputInfo.step11_context_builder_used, ...
        inputInfo.g_cache_context_created_for_software_reference_only};

    summaryRows(im, :) = { ...
        inputInfo.input_source_requested, inputInfo.input_source_used, inputInfo.fallback_reason, ...
        inputInfo.W_method, inputInfo.N_input_channels, inputInfo.B_output_beams, ...
        inputInfo.L_snapshots, mode.name, relZ, maxAbsZ, powerRel, topBeamSame, ...
        topKSetPreservation, rankPreservation, rzRel, qmeta.clip_rate, qmeta.overflow_rate, ...
        qmeta.scale_w, qmeta.scale_y, qmeta.scale_z, sameBackendInputShape, rzShapeSame, ...
        cpuSocReady, passFlag, inputInfo.step11_adapter_found_flag, ...
        inputInfo.step11_7_full_backend_called};
end

trialTbl = cell2table(trialRows, 'VariableNames', { ...
    'input_source_requested', 'input_source_used', 'fallback_reason', ...
    'step11_adapter_found_flag', 'step11_7_full_backend_called', 'W_method', ...
    'Y_work_shape', 'Y_matrix_shape', 'Z_shape', 'Rz_shape', ...
    'N_input_channels', 'B_output_beams', 'L_snapshots', 'quant_mode', ...
    'W_bits', 'Y_bits', 'Z_bits', 'scale_w', 'scale_y', 'scale_z', ...
    'Z_rel_l2_error', 'Z_max_abs_error', 'beam_power_rel_error', ...
    'top_beam_same_rate', 'topK_beam_set_preservation', ...
    'beam_power_rank_preservation', 'Z_cov_Rz_rel_error', 'clip_rate', ...
    'overflow_rate', 'same_backend_input_shape', 'Rz_shape_same', ...
    'cpu_soc_ml_ready_flag', 'dbf_smoke_pass_flag', 'step11_context_builder_used', ...
    'g_cache_context_created_for_software_reference_only'});

summaryTbl = cell2table(summaryRows, 'VariableNames', { ...
    'input_source_requested', 'input_source_used', 'fallback_reason', 'W_method', ...
    'N_input_channels', 'B_output_beams', 'L_snapshots', 'quant_mode', ...
    'Z_rel_l2_error', 'Z_max_abs_error', 'beam_power_rel_error', ...
    'top_beam_same_rate', 'topK_beam_set_preservation', ...
    'beam_power_rank_preservation', 'Z_cov_Rz_rel_error', 'clip_rate', ...
    'overflow_rate', 'scale_w', 'scale_y', 'scale_z', ...
    'same_backend_input_shape', 'Rz_shape_same', 'cpu_soc_ml_ready_flag', ...
    'dbf_smoke_pass_flag', 'step11_adapter_found_flag', ...
    'step11_7_full_backend_called'});

resourceTbl = local_resource_estimate(inputInfo);
partitionTbl = local_partition_table();
interfaceTbl = local_interface_table();
recommendTbl = local_recommendations(summaryTbl, resourceTbl);
keypointsTbl = local_keypoints(summaryTbl, resourceTbl, inputInfo);

writetable(trialTbl, fullfile(resultsDir, 'step13_dbf_fixed_point_trial.csv'));
writetable(summaryTbl, fullfile(resultsDir, 'step13_dbf_fixed_point_summary.csv'));
writetable(keypointsTbl, fullfile(resultsDir, 'step13_dbf_keypoints.csv'));
writetable(resourceTbl, fullfile(resultsDir, 'step13_dbf_resource_estimate.csv'));
writetable(partitionTbl, fullfile(resultsDir, 'step13_fpga_soc_partition.csv'));
writetable(interfaceTbl, fullfile(resultsDir, 'step13_interface_fields.csv'));
writetable(recommendTbl, fullfile(resultsDir, 'step13_recommendations.csv'));

local_plot_errors(summaryTbl, resultsDir);
local_plot_resources(resourceTbl, resultsDir);
local_plot_placeholder_diagrams(resultsDir);

fprintf('Step13 DBF quick/smoke completed. Results: %s\n', resultsDir);
fprintf('input_source_requested=%s input_source_used=%s fallback_reason=%s\n', ...
    inputInfo.input_source_requested, inputInfo.input_source_used, inputInfo.fallback_reason);
fprintf('N=%d B=%d L=%d W_method=%s\n', inputInfo.N_input_channels, ...
    inputInfo.B_output_beams, inputInfo.L_snapshots, inputInfo.W_method);
disp(summaryTbl(:, {'quant_mode', 'Z_rel_l2_error', 'beam_power_rel_error', ...
    'topK_beam_set_preservation', 'beam_power_rank_preservation', ...
    'Z_cov_Rz_rel_error', 'dbf_smoke_pass_flag'}));

function local_add_required_paths(repoRoot)
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot, 'core')));
addpath(fullfile(repoRoot, 'steps', 'step_11_1_beamspace_ml_validation', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_2_beamspace_w_design', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_3_beamspace_ml_search_acceleration', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_6_shared_center_rotatable_beamspace_manifold_cache', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_7_final_cached_c05_beamspace_ml_route', 'common'));
end

function cfg = local_default_cfg(quickMode)
cfg = struct();
cfg.quickMode = quickMode;
if quickMode
    cfg.synthetic_N_input_channels = 24;
    cfg.synthetic_B_output_beams = 9;
    cfg.synthetic_L_snapshots = 16;
    cfg.step11_L_snapshots = 16;
else
    cfg.synthetic_N_input_channels = 64;
    cfg.synthetic_B_output_beams = 33;
    cfg.synthetic_L_snapshots = 64;
    cfg.step11_L_snapshots = 64;
end
cfg.topK = 3;
cfg.pass_z_rel_l2_error = 1.0e-3;
cfg.pass_power_rel_error = 3.0e-3;
cfg.pass_topk_set_preservation = 0.999;
cfg.pass_rank_preservation = 0.999;
cfg.pass_rz_rel_error = 3.0e-3;
cfg.clock_Hz = 200e6;
end

function inputInfo = local_resolve_input_source(cfg, repoRoot, resultsDir, requested)
switch requested
    case 'synthetic'
        inputInfo = local_make_synthetic_input(cfg, requested, '', '');
    case 'step11_light'
        inputInfo = local_make_step11_light_input(cfg, repoRoot, resultsDir, requested, '');
    case 'auto'
        try
            inputInfo = local_make_step11_light_input(cfg, repoRoot, resultsDir, requested, '');
        catch err
            fallbackReason = sprintf('step11_light_failed: %s', local_one_line(err.message));
            inputInfo = local_make_synthetic_input(cfg, requested, fallbackReason, '');
        end
end
end

function inputInfo = local_make_synthetic_input(cfg, requested, fallbackReason, blockerReason)
N = cfg.synthetic_N_input_channels;
B = cfg.synthetic_B_output_beams;
L = cfg.synthetic_L_snapshots;
n = (0:N-1).';
beamAngles = linspace(-0.35, 0.35, B);
W = zeros(N, B);
for ib = 1:B
    W(:, ib) = exp(1j * pi * n * sin(beamAngles(ib))) / sqrt(N);
end

sourceAngles = [-0.12, 0.08];
sourceAmp = [1.0, 0.72];
S = zeros(numel(sourceAngles), L);
for is = 1:numel(sourceAngles)
    phase = exp(1j * 2 * pi * (0:L-1) * (0.07 * is));
    S(is, :) = sourceAmp(is) * phase;
end
A = zeros(N, numel(sourceAngles));
for is = 1:numel(sourceAngles)
    A(:, is) = exp(1j * pi * n * sin(sourceAngles(is)));
end
noise = 0.02 * (randn(N, L) + 1j * randn(N, L));
Y = A * S + noise;
Y = Y / max(abs(Y(:)));

inputInfo = local_make_input_info(W, Y, Y, requested, 'synthetic', fallbackReason, ...
    blockerReason, false, false, false, 'synthetic_DBF_W', false);
end

function inputInfo = local_make_step11_light_input(cfg13, repoRoot, resultsDir, requested, fallbackReason)
required = {'sim_cfg', 'build_step11_6_canonical_geometry', ...
    'build_recommended_w_from_step11_2', 'build_step11_7_frontend_like_input'};
missing = {};
for idx = 1:numel(required)
    if exist(required{idx}, 'file') ~= 2
        missing{end + 1} = required{idx}; %#ok<AGROW>
    end
end
if ~isempty(missing)
    error('Step13:MissingStep11Adapter', 'Missing Step11 adapter function(s): %s', strjoin(missing, ', '));
end

cfg = sim_cfg();
cfg.beam.azSectorCenter = 0;
cfg.beam.azSteer = 0;
phaseFactor = cfg.beam.spatialPhaseFactor;
phaseSign = 1;
reg = 1e-10;
centerAz = 0;
step11_2_dir = fullfile(repoRoot, 'steps', 'step_11_2_beamspace_w_design');

geom = build_step11_6_canonical_geometry(cfg, centerAz);
[W, wInfo] = build_recommended_w_from_step11_2(step11_2_dir, cfg, geom.canonical_arr, ...
    'B', 7, 'Criterion', 'combined', 'PhaseFactor', phaseFactor, ...
    'PhaseSign', phaseSign, 'Reg', reg);
WMethod = sprintf('greedy_%s_B%d', wInfo.criterion, wInfo.B);

context = struct();
context.cfg = cfg;
context.W = W;
context.W_method = WMethod;
context.w_info = wInfo;
context.lambda = cfg.arr.lambda;
context.phase_factor = phaseFactor;
context.phase_sign = phaseSign;
context.el_center_nominal = cfg.beam.elSectorCenter;
context.el_center_offset = 0.31;
context.L_default = cfg13.step11_L_snapshots;
context.base_seed = 20260609;
context.result_dir = resultsDir;

scenario = struct();
scenario.scenario_name = 'step13_step11_light_smoke';
scenario.az_sep_deg = 1.27;
scenario.el_sep_deg = 0.37;
scenario.snr_db = 30;
scenario.rho = 0;
scenario.phase_deg = 0;
scenario.beta = 0.67;

[input, ~, ~] = build_step11_7_frontend_like_input(context, scenario, centerAz, 1, ...
    'L', cfg13.step11_L_snapshots, 'Seed', context.base_seed + 1301, ...
    'ReshapeMode', 'matrix_N_by_L', 'FrontendState', 'controlled_pair2d_candidate', ...
    'MethodTag', 'step13_step11_light_dbf_smoke');

Y = input.Y_work;
if ~(ismatrix(Y) && size(Y, 1) == size(W, 1))
    sz = size(Y);
    if ndims(Y) == 3 && sz(1) == cfg.beam.subNaz && sz(2) == cfg.arr.Nel
        Y = reshape(Y, [], sz(3));
    else
        error('Step13:InvalidStep11YWork', 'Y_work shape %s does not match W rows %d.', ...
            local_shape_text(size(Y)), size(W, 1));
    end
end
Y = Y / max(abs(Y(:)));

inputInfo = local_make_input_info(W, Y, input.Y_work, requested, 'step11_light', ...
    fallbackReason, '', true, false, false, WMethod, false);
end

function inputInfo = local_make_input_info(W, Y, YWork, requested, used, fallbackReason, ...
    blockerReason, adapterFound, fullBackendCalled, contextBuilderUsed, WMethod, gCacheContextCreated)
Z = W' * Y;
Rz = Z * Z';
inputInfo = struct();
inputInfo.W = W;
inputInfo.Y = Y;
inputInfo.input_source_requested = requested;
inputInfo.input_source_used = used;
inputInfo.fallback_reason = fallbackReason;
inputInfo.blocker_reason = blockerReason;
inputInfo.step11_adapter_found_flag = logical(adapterFound);
inputInfo.step11_7_full_backend_called = logical(fullBackendCalled);
inputInfo.step11_context_builder_used = logical(contextBuilderUsed);
inputInfo.g_cache_context_created_for_software_reference_only = logical(gCacheContextCreated);
inputInfo.W_method = WMethod;
inputInfo.Y_work_shape = local_shape_text(size(YWork));
inputInfo.Y_matrix_shape = local_shape_text(size(Y));
inputInfo.Z_shape = local_shape_text(size(Z));
inputInfo.Rz_shape = local_shape_text(size(Rz));
inputInfo.expected_Y_matrix_shape = size(Y);
inputInfo.N_input_channels = size(Y, 1);
inputInfo.B_output_beams = size(W, 2);
inputInfo.L_snapshots = size(Y, 2);
end

function modes = local_quant_modes()
defs = {
    'double_baseline', 0, 0, 0;
    'float32_reference', 0, 0, 0;
    'W_int16_Y_int16', 16, 16, 32;
    'W_int18_Y_int16', 18, 16, 36;
    'W_int24_Y_int16', 24, 16, 40;
    'W_int18_Y_int18', 18, 18, 40;
    'W_int24_Y_int18', 24, 18, 42;
    'mixed_W18_Y16_Z24', 18, 16, 24;
    'mixed_W24_Y16_Z24', 24, 16, 24
};
modes = struct('name', {}, 'w_bits', {}, 'y_bits', {}, 'z_bits', {});
for i = 1:size(defs, 1)
    modes(i).name = defs{i, 1}; %#ok<AGROW>
    modes(i).w_bits = defs{i, 2};
    modes(i).y_bits = defs{i, 3};
    modes(i).z_bits = defs{i, 4};
end
end

function [Zq, meta] = local_quantized_dbf(W, Y, mode)
if strcmp(mode.name, 'double_baseline')
    Zq = W' * Y;
    meta = local_meta(1, 1, 1, 0, 0);
    return;
end
if strcmp(mode.name, 'float32_reference')
    Zq = double(single(W)' * single(Y));
    meta = local_meta(1, 1, 1, 0, 0);
    return;
end

[Wq, scaleW, clipW] = local_quant_complex(W, mode.w_bits);
[Yq, scaleY, clipY] = local_quant_complex(Y, mode.y_bits);
Zacc = Wq' * Yq;

if mode.z_bits > 0
    [Zq, scaleZ, clipZ] = local_quant_complex(Zacc, mode.z_bits);
else
    Zq = Zacc;
    scaleZ = 1;
    clipZ = 0;
end

meta = local_meta(scaleW, scaleY, scaleZ, max([clipW, clipY, clipZ]), 0);
end

function [xq, scale, clipRate] = local_quant_complex(x, bits)
if bits <= 0
    xq = x;
    scale = 1;
    clipRate = 0;
    return;
end
maxInt = 2^(bits - 1) - 1;
peak = max([max(abs(real(x(:)))), max(abs(imag(x(:)))), eps]);
scale = maxInt / peak;
ri = round(real(x) * scale);
ii = round(imag(x) * scale);
clipMask = ri > maxInt | ri < -maxInt | ii > maxInt | ii < -maxInt;
ri = min(max(ri, -maxInt), maxInt);
ii = min(max(ii, -maxInt), maxInt);
xq = (ri + 1j * ii) / scale;
clipRate = nnz(clipMask) / numel(x);
end

function meta = local_meta(scaleW, scaleY, scaleZ, clipRate, overflowRate)
meta.scale_w = scaleW;
meta.scale_y = scaleY;
meta.scale_z = scaleZ;
meta.clip_rate = clipRate;
meta.overflow_rate = overflowRate;
end

function rate = local_pairwise_rank_preservation(powerRef, powerQ)
n = numel(powerRef);
total = 0;
same = 0;
for i = 1:n
    for j = i+1:n
        sRef = sign(powerRef(i) - powerRef(j));
        sQ = sign(powerQ(i) - powerQ(j));
        total = total + 1;
        if sRef == sQ
            same = same + 1;
        end
    end
end
rate = same / max(total, 1);
end

function tbl = local_resource_estimate(inputInfo)
clockHz = 200e6;
N = inputInfo.N_input_channels;
B = inputInfo.B_output_beams;
L = inputInfo.L_snapshots;
wBits = 18;
yBits = 16;
zBits = 24;
accBits = 48;
arch = {'one_complex_mac_lane'; 'beam_parallel_B_lanes'; 'full_BxN_parallel'};
complexLanes = [1; B; B * N];
complexMacCount = repmat(B * N, 3, 1);
cyclesPerSnapshot = ceil(complexMacCount ./ complexLanes) + 4;
throughput = clockHz ./ cyclesPerSnapshot;
yInputBits = repmat(N * 2 * yBits, 3, 1);
zOutputBits = repmat(B * 2 * zBits, 3, 1);
wStorageBits = repmat(N * B * 2 * wBits, 3, 1);
yMBps = yInputBits .* throughput / 8 / 1e6;
zMBps = zOutputBits .* throughput / 8 / 1e6;
dsp = 3 * complexLanes;
bram36 = ceil(wStorageBits / (36 * 1024)) + ones(3, 1);
uram288 = ceil(wStorageBits / (288 * 1024)) .* double(wStorageBits > 2 * 36 * 1024);

tbl = table(arch, repmat(clockHz, 3, 1), cyclesPerSnapshot, throughput, ...
    yInputBits, zOutputBits, yMBps, zMBps, wStorageBits, repmat(accBits, 3, 1), ...
    complexMacCount, complexLanes, dsp, bram36, uram288, repmat(N, 3, 1), ...
    repmat(B, 3, 1), repmat(L, 3, 1), ...
    'VariableNames', {'architecture', 'clock_Hz', 'cycles_per_snapshot_est', ...
    'throughput_snapshots_per_sec_est', 'Y_input_bits_per_snapshot', ...
    'Z_output_bits_per_snapshot', 'Y_input_MBps_at_clock', 'Z_output_MBps_at_clock', ...
    'W_storage_bits', 'accumulator_width_est', 'complex_mac_count_per_snapshot', ...
    'complex_lanes', 'DSP_rough_estimate', 'BRAM36_rough_estimate', ...
    'URAM288_rough_estimate', 'N_input_channels', 'B_output_beams', 'L_snapshots'});
end

function tbl = local_partition_table()
side = {'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'CPU_SoC'; 'CPU_SoC'; 'CPU_SoC'; 'CPU_SoC'};
module = {'W storage/read'; 'complex MAC pipeline'; 'scale_round_saturate'; ...
    'Z output interface'; 'Rz construction/read'; 'G_cache management'; ...
    '2D beamspace ML/topK/C05'; 'confidence_boundary_fallback_log'};
responsibility = {'store or stream DBF weights'; 'compute Z = W^H Y'; ...
    'fixed-point scale, rounding, saturation'; 'emit beamspace tensor Z'; ...
    'construct or consume Rz = Z Z^H'; 'software-side cache for ML search'; ...
    'execute ranking and policy'; 'system interpretation and output'};
tbl = table(side, module, responsibility);
end

function tbl = local_interface_table()
field = {'frame_id'; 'detect_id'; 'input_source_used'; 'N_input_channels'; ...
    'B_output_beams'; 'L_snapshots'; 'W_method'; 'W_format'; 'Y_format'; ...
    'Z_format'; 'scale_w'; 'scale_y'; 'scale_z'; 'clip_rate'; ...
    'overflow_rate'; 'Z_payload'; 'valid_flag'};
owner = {'SoC'; 'SoC'; 'SoC'; 'SoC'; 'SoC'; 'SoC'; 'SoC'; 'SoC'; ...
    'SoC'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'};
meaning = {'radar frame index'; 'detection index'; 'synthetic or Step11-compatible source'; ...
    'array/subarray channels'; 'DBF beams'; 'snapshot count'; 'DBF W source'; ...
    'DBF weight quantization'; 'input sample quantization'; 'beamspace output quantization'; ...
    'W scale'; 'Y scale'; 'Z scale'; 'saturation clip ratio'; 'overflow ratio'; ...
    'complex beamspace data'; 'Z output valid'};
tbl = table(field, owner, meaning);
end

function tbl = local_recommendations(summaryTbl, resourceTbl)
preferred = {'mixed_W18_Y16_Z24'; 'mixed_W24_Y16_Z24'; 'beam_parallel_B_lanes'};
reason = {
    'Step13.1 DBF candidate: W18/Y16/Z24 smoke target';
    'Higher-margin Step13.1 DBF candidate for W-sensitive scenes';
    'Recommended future RTL DBF prototype architecture, pending Step11-compatible smoke'
};
tbl = table(preferred, reason);
end

function tbl = local_keypoints(summaryTbl, resourceTbl, inputInfo)
modeNames = summaryTbl.quant_mode;
passFlags = summaryTbl.dbf_smoke_pass_flag;
candidateMask = strcmp(modeNames, 'mixed_W18_Y16_Z24') | ...
    strcmp(modeNames, 'mixed_W24_Y16_Z24');
candidatePass = all(passFlags(candidateMask));
metric = {'input_source_requested'; 'input_source_used'; 'fallback_reason'; ...
    'step11_adapter_found_flag'; 'step11_7_full_backend_called'; ...
    'step11_context_builder_used'; 'g_cache_context_created_for_software_reference_only'; ...
    'step11_7_backend_default_changed'; 'formal_result_claimed'; ...
    'dbf_step11_compatible_smoke_pass_flag'; 'recommended_modes'; ...
    'recommended_rtl_architecture'; 'N_input_channels'; 'B_output_beams'; ...
    'L_snapshots'; 'W_method'; 'beam_parallel_B_lanes_DSP_rough_estimate'; ...
    'beam_parallel_B_lanes_throughput_snapshots_per_sec_est'; ...
    'beam_parallel_B_lanes_Y_input_MBps_at_clock'; ...
    'beam_parallel_B_lanes_Z_output_MBps_at_clock'};
beamParallel = resourceTbl(strcmp(resourceTbl.architecture, 'beam_parallel_B_lanes'), :);
value = {inputInfo.input_source_requested; inputInfo.input_source_used; ...
    inputInfo.fallback_reason; local_bool_text(inputInfo.step11_adapter_found_flag); ...
    local_bool_text(inputInfo.step11_7_full_backend_called); ...
    local_bool_text(inputInfo.step11_context_builder_used); ...
    local_bool_text(inputInfo.g_cache_context_created_for_software_reference_only); ...
    'false'; 'false'; local_bool_text(candidatePass); ...
    'mixed_W18_Y16_Z24; mixed_W24_Y16_Z24'; 'beam_parallel_B_lanes'; ...
    sprintf('%d', inputInfo.N_input_channels); sprintf('%d', inputInfo.B_output_beams); ...
    sprintf('%d', inputInfo.L_snapshots); inputInfo.W_method; ...
    sprintf('%.0f', beamParallel.DSP_rough_estimate); ...
    sprintf('%.6g', beamParallel.throughput_snapshots_per_sec_est); ...
    sprintf('%.6g', beamParallel.Y_input_MBps_at_clock); ...
    sprintf('%.6g', beamParallel.Z_output_MBps_at_clock)};
tbl = table(metric, value);
end

function local_plot_errors(summaryTbl, resultsDir)
fig = figure('Visible', 'off');
bar(categorical(summaryTbl.quant_mode), summaryTbl.Z_rel_l2_error);
title('DBF Z relative L2 error by quantization mode');
ylabel('relative L2 error');
xtickangle(35);
grid on;
saveas(fig, fullfile(resultsDir, 'dbf_z_error_by_quant_mode.png'));
close(fig);

fig = figure('Visible', 'off');
bar(categorical(summaryTbl.quant_mode), summaryTbl.beam_power_rel_error);
title('DBF beam power relative error by quantization mode');
ylabel('relative error');
xtickangle(35);
grid on;
saveas(fig, fullfile(resultsDir, 'dbf_beam_power_error_by_quant_mode.png'));
close(fig);
end

function local_plot_resources(resourceTbl, resultsDir)
fig = figure('Visible', 'off');
bar(categorical(resourceTbl.architecture), resourceTbl.DSP_rough_estimate);
title('Rough DSP estimate by DBF architecture');
ylabel('DSP rough estimate');
xtickangle(20);
grid on;
saveas(fig, fullfile(resultsDir, 'dbf_resource_estimate.png'));
close(fig);
end

function local_plot_placeholder_diagrams(resultsDir)
fig = figure('Visible', 'off');
axis off;
text(0.05, 0.75, 'FPGA: DBF Z = W^H Y', 'FontSize', 12);
text(0.05, 0.50, 'Interface: Z + scale/clip metadata', 'FontSize', 12);
text(0.05, 0.25, 'CPU/SoC: Rz, G cache, 2D ML, topK, C05, confidence', 'FontSize', 12);
saveas(fig, fullfile(resultsDir, 'fpga_soc_partition_diagram.png'));
close(fig);

fig = figure('Visible', 'off');
axis off;
text(0.05, 0.80, 'Y stream', 'FontSize', 12);
text(0.25, 0.80, 'W read', 'FontSize', 12);
text(0.45, 0.80, 'complex MAC lanes', 'FontSize', 12);
text(0.68, 0.80, 'round/saturate', 'FontSize', 12);
text(0.86, 0.80, 'Z output', 'FontSize', 12);
saveas(fig, fullfile(resultsDir, 'dbf_pipeline_diagram.png'));
close(fig);
end

function text = local_shape_text(sz)
parts = cell(1, numel(sz));
for idx = 1:numel(sz)
    parts{idx} = sprintf('%d', sz(idx));
end
text = strjoin(parts, 'x');
end

function text = local_bool_text(value)
if value
    text = 'true';
else
    text = 'false';
end
end

function text = local_one_line(text)
text = regexprep(char(text), '\s+', ' ');
end
