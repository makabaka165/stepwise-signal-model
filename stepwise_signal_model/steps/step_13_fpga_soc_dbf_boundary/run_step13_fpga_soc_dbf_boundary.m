% Step13 FPGA/SoC DBF boundary quick/smoke validation.
%
% This script validates the DBF boundary Z = W^H Y and estimates resource /
% interface quantities. It does not run the Step11.7 full backend, does not
% perform formal ML-score closure, and does not require Fixed-Point Designer.

clearvars;
close all;
clc;

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(scriptDir));
resultsDir = fullfile(scriptDir, 'results_step13_fpga_soc_dbf_boundary');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

quickMode = true;
quickEnv = getenv('STEP13_QUICK_MODE');
if ~isempty(quickEnv)
    quickMode = ~strcmp(quickEnv, '0');
end

rng(13);

cfg = local_default_cfg(quickMode);
[W, Y] = local_make_synthetic_inputs(cfg);
Z_ref = W' * Y;
Rz_ref = Z_ref * Z_ref';
beamPowerRef = sum(abs(Z_ref).^2, 2);

modes = local_quant_modes();
trialRows = cell(numel(modes), 18);
summaryRows = cell(numel(modes), 10);

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
    topK = min(cfg.topK, cfg.B_output_beams);
    topKPreservation = numel(intersect(rankRef(1:topK), rankQ(1:topK))) / topK;
    rzRel = norm(Rzq(:) - Rz_ref(:), 2) / max(norm(Rz_ref(:), 2), eps);

    passFlag = relZ <= cfg.pass_z_rel_l2_error && ...
        powerRel <= cfg.pass_power_rel_error && ...
        topBeamSame == 1 && ...
        qmeta.clip_rate <= cfg.pass_clip_rate;

    trialRows(im, :) = {mode.name, mode.w_bits, mode.y_bits, mode.z_bits, ...
        qmeta.scale_w, qmeta.scale_y, qmeta.scale_z, relZ, maxAbsZ, powerRel, ...
        topKPreservation, topBeamSame, rzRel, qmeta.clip_rate, qmeta.overflow_rate, ...
        true, isequal(size(Rzq), size(Rz_ref)), passFlag};

    summaryRows(im, :) = {mode.name, relZ, powerRel, topKPreservation, topBeamSame, ...
        rzRel, qmeta.clip_rate, qmeta.overflow_rate, qmeta.scale_w, passFlag};
end

trialTbl = cell2table(trialRows, 'VariableNames', { ...
    'quant_mode', 'W_bits', 'Y_bits', 'Z_bits', 'scale_w', 'scale_y', 'scale_z', ...
    'Z_rel_l2_error', 'Z_max_abs_error', 'beam_power_rel_error', ...
    'beam_power_rank_preservation', 'top_beam_same_rate', 'Z_cov_Rz_rel_error', ...
    'clip_rate', 'overflow_rate', 'same_backend_input_shape', 'Rz_shape_same', ...
    'cpu_soc_ml_ready_flag'});

summaryTbl = cell2table(summaryRows, 'VariableNames', { ...
    'quant_mode', 'Z_rel_l2_error', 'beam_power_rel_error', ...
    'beam_power_rank_preservation', 'top_beam_same_rate', 'Z_cov_Rz_rel_error', ...
    'clip_rate', 'overflow_rate', 'scale_w', 'dbf_smoke_pass_flag'});

resourceTbl = local_resource_estimate(cfg);
partitionTbl = local_partition_table();
interfaceTbl = local_interface_table();
recommendTbl = local_recommendations(summaryTbl);
keypointsTbl = local_keypoints(summaryTbl, resourceTbl, cfg);

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
disp(summaryTbl(:, {'quant_mode', 'Z_rel_l2_error', 'beam_power_rel_error', ...
    'top_beam_same_rate', 'dbf_smoke_pass_flag'}));

function cfg = local_default_cfg(quickMode)
cfg.quickMode = quickMode;
if quickMode
    cfg.N_input_channels = 24;
    cfg.B_output_beams = 9;
    cfg.L_snapshots = 16;
else
    cfg.N_input_channels = 64;
    cfg.B_output_beams = 33;
    cfg.L_snapshots = 64;
end
cfg.topK = 3;
cfg.pass_z_rel_l2_error = 2.5e-2;
cfg.pass_power_rel_error = 5.0e-2;
cfg.pass_clip_rate = 1e-3;
end

function [W, Y] = local_make_synthetic_inputs(cfg)
n = (0:cfg.N_input_channels-1).';
beamAngles = linspace(-0.35, 0.35, cfg.B_output_beams);
W = zeros(cfg.N_input_channels, cfg.B_output_beams);
for ib = 1:cfg.B_output_beams
    W(:, ib) = exp(1j * pi * n * sin(beamAngles(ib))) / sqrt(cfg.N_input_channels);
end

sourceAngles = [-0.12, 0.08];
sourceAmp = [1.0, 0.72];
S = zeros(numel(sourceAngles), cfg.L_snapshots);
for is = 1:numel(sourceAngles)
    phase = exp(1j * 2 * pi * (0:cfg.L_snapshots-1) * (0.07 * is));
    S(is, :) = sourceAmp(is) * phase;
end
A = zeros(cfg.N_input_channels, numel(sourceAngles));
for is = 1:numel(sourceAngles)
    A(:, is) = exp(1j * pi * n * sin(sourceAngles(is)));
end
noise = 0.02 * (randn(cfg.N_input_channels, cfg.L_snapshots) + ...
    1j * randn(cfg.N_input_channels, cfg.L_snapshots));
Y = A * S + noise;
Y = Y / max(abs(Y(:)));
end

function modes = local_quant_modes()
modes = struct('name', {}, 'w_bits', {}, 'y_bits', {}, 'z_bits', {});
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

function tbl = local_resource_estimate(cfg)
arch = {'one_complex_mac_lane'; 'beam_parallel_B_lanes'; 'full_BxN_parallel'};
lanes = [1; cfg.B_output_beams; cfg.B_output_beams * cfg.N_input_channels];
complexMult = lanes;
macPerSnapshot = repmat(cfg.B_output_beams * cfg.N_input_channels, 3, 1);
wBits = cfg.N_input_channels * cfg.B_output_beams * 2 * 18;
yBw = cfg.N_input_channels * 2 * 16;
zBw = cfg.B_output_beams * 2 * 24;
latency = ceil(macPerSnapshot ./ lanes) + 4;
throughput = lanes ./ max(macPerSnapshot, 1);
dsp = 3 * complexMult;
bram = ceil(wBits / (36 * 1024)) + ones(3, 1);
uram = zeros(3, 1);
tbl = table(arch, repmat(cfg.N_input_channels, 3, 1), ...
    repmat(cfg.B_output_beams, 3, 1), repmat(cfg.L_snapshots, 3, 1), ...
    complexMult, macPerSnapshot, repmat(wBits, 3, 1), repmat(yBw, 3, 1), ...
    repmat(zBw, 3, 1), repmat(24, 3, 1), latency, throughput, bram, uram, dsp, ...
    'VariableNames', {'architecture', 'N_input_channels', 'B_output_beams', ...
    'L_snapshots', 'complex_multipliers_per_beam', 'complex_mac_count_per_snapshot', ...
    'W_storage_bits', 'Y_input_bandwidth', 'Z_output_bandwidth', 'accumulator_width', ...
    'latency_estimate', 'throughput_estimate', 'BRAM_rough_estimate', ...
    'URAM_rough_estimate', 'DSP_rough_estimate'});
end

function tbl = local_partition_table()
side = {'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'CPU_SoC'; 'CPU_SoC'; 'CPU_SoC'; 'CPU_SoC'};
module = {'W storage/read'; 'complex MAC pipeline'; 'scale_round_saturate'; ...
    'Z output interface'; 'Rz construction/read'; 'G_cache management'; ...
    '2D beamspace ML/topK/C05'; 'confidence_boundary_fallback_log'};
responsibility = {'store or stream DBF weights'; 'compute Z = W^H Y'; ...
    'fixed-point scale, rounding, saturation'; 'emit beamspace tensor Z'; ...
    'construct or consume Rz = Z Z^H'; 'manage cache for ML search'; ...
    'execute ranking and policy'; 'system interpretation and output'};
tbl = table(side, module, responsibility);
end

function tbl = local_interface_table()
field = {'frame_id'; 'detect_id'; 'N_input_channels'; 'B_output_beams'; ...
    'L_snapshots'; 'W_format'; 'Y_format'; 'Z_format'; 'scale_w'; 'scale_y'; ...
    'scale_z'; 'clip_rate'; 'overflow_rate'; 'Z_payload'; 'valid_flag'};
owner = {'SoC'; 'SoC'; 'SoC'; 'SoC'; 'SoC'; 'SoC'; 'SoC'; 'FPGA'; ...
    'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'; 'FPGA'};
meaning = {'radar frame index'; 'detection index'; 'array/subarray channels'; ...
    'DBF beams'; 'snapshot count'; 'DBF weight quantization'; ...
    'input sample quantization'; 'beamspace output quantization'; ...
    'W scale'; 'Y scale'; 'Z scale'; 'saturation clip ratio'; ...
    'overflow indicator ratio'; 'complex beamspace data'; 'Z output valid'};
tbl = table(field, owner, meaning);
end

function tbl = local_recommendations(summaryTbl)
preferred = {'mixed_W18_Y16_Z24'; 'mixed_W24_Y16_Z24'; 'beam_parallel_B_lanes'};
reason = {
    'Initial Step13 DBF candidate: modest W width, Y16 input, Z24 output';
    'Higher-margin Step13 DBF candidate for W-sensitive scenes';
    'Recommended future RTL DBF prototype architecture'
};
tbl = table(preferred, reason);
end

function tbl = local_keypoints(summaryTbl, resourceTbl, cfg)
modeNames = summaryTbl.quant_mode;
passFlags = summaryTbl.dbf_smoke_pass_flag;
candidateMask = strcmp(modeNames, 'mixed_W18_Y16_Z24') | ...
    strcmp(modeNames, 'mixed_W24_Y16_Z24');
candidatePass = all(passFlags(candidateMask));
metric = {'quick_mode'; 'dbf_candidate_pass_flag'; 'recommended_modes'; ...
    'recommended_rtl_architecture'; 'step11_7_backend_default_changed'; ...
    'formal_result_claimed'; 'N_input_channels'; 'B_output_beams'};
value = {string(cfg.quickMode); string(candidatePass); ...
    'mixed_W18_Y16_Z24; mixed_W24_Y16_Z24'; 'beam_parallel_B_lanes'; ...
    'false'; 'false'; string(cfg.N_input_channels); string(cfg.B_output_beams)};
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
