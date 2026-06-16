% Generate compact MATLAB golden vectors for the Step13.2 DBF RTL smoke.
%
% Scope: raw accumulator validation for Z = W^H Y only. This script does not
% call the Step11.7 full backend and does not implement Rz, G_cache, 2D ML
% search, topK, C05, confidence, or fallback logic.

clearvars;
clc;

scriptDir = fileparts(mfilename('fullpath'));
stepDir = fileparts(scriptDir);
repoRoot = fileparts(fileparts(stepDir));
resultsDir = fullfile(stepDir, 'results_step13_fpga_soc_dbf_boundary', 'rtl_golden');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

local_add_required_paths(repoRoot);

inputSourceRequested = lower(strtrim(getenv('STEP13_INPUT_SOURCE')));
if isempty(inputSourceRequested)
    inputSourceRequested = 'step11_light';
end
if strcmp(inputSourceRequested, 'auto')
    inputSourceRequested = 'step11_light';
end
if ~any(strcmp(inputSourceRequested, {'step11_light', 'synthetic'}))
    error('Step13:InvalidRtlGoldenInputSource', ...
        'STEP13_INPUT_SOURCE for RTL golden must be step11_light or synthetic.');
end

quantMode = strtrim(getenv('STEP13_RTL_GOLDEN_MODE'));
if isempty(quantMode)
    quantMode = 'mixed_W18_Y16_Z24';
end
[W_BITS, Y_BITS, Z_BITS] = local_parse_quant_mode(quantMode);

requestedNLimit = local_getenv_int('STEP13_RTL_GOLDEN_N_LIMIT', 64);
requestedBLimit = local_getenv_int('STEP13_RTL_GOLDEN_B_LIMIT', 7);
requestedLLimit = local_getenv_int('STEP13_RTL_GOLDEN_L_LIMIT', 4);

switch inputSourceRequested
    case 'step11_light'
        inputInfo = local_make_step11_light_input(repoRoot, resultsDir, max(16, requestedLLimit));
    case 'synthetic'
        inputInfo = local_make_synthetic_input(max(64, requestedNLimit), ...
            max(7, requestedBLimit), max(16, requestedLLimit));
end

fullN = size(inputInfo.Y, 1);
fullB = size(inputInfo.W, 2);
fullL = size(inputInfo.Y, 2);
goldenN = min(requestedNLimit, fullN);
goldenB = min(requestedBLimit, fullB);
goldenL = min(requestedLLimit, fullL);

if goldenN <= 0 || goldenB <= 0 || goldenL <= 0
    error('Step13:InvalidRtlGoldenLimits', 'Golden N/B/L limits must be positive.');
end

[WqFull, scaleW, clipW] = local_quant_complex_int(inputInfo.W, W_BITS);
[YqFull, scaleY, clipY] = local_quant_complex_int(inputInfo.Y, Y_BITS);
Wq = WqFull(1:goldenN, 1:goldenB);
Yq = YqFull(1:goldenN, 1:goldenL);

[accRe, accIm] = local_accumulate_conj_w_y(Wq, Yq);
ACC_BITS = W_BITS + Y_BITS + ceil(log2(goldenN)) + 2;
full_ACC_BITS = W_BITS + Y_BITS + ceil(log2(fullN)) + 2;

manifestPath = fullfile(resultsDir, 'step13_dbf_rtl_golden_manifest.csv');
metadataPath = fullfile(resultsDir, 'step13_dbf_rtl_golden_metadata.csv');
wPath = fullfile(resultsDir, 'step13_dbf_rtl_golden_w_int.csv');
yPath = fullfile(resultsDir, 'step13_dbf_rtl_golden_y_int.csv');
accPath = fullfile(resultsDir, 'step13_dbf_rtl_golden_accum.csv');
vhPath = fullfile(resultsDir, 'step13_dbf_rtl_golden_vectors.vh');

local_write_manifest(manifestPath, resultsDir);
local_write_metadata(metadataPath, inputSourceRequested, inputInfo, quantMode, ...
    fullN, fullB, fullL, goldenN, goldenB, goldenL, W_BITS, Y_BITS, ...
    Z_BITS, ACC_BITS, full_ACC_BITS, scaleW, scaleY, max(clipW, clipY));
local_write_w_csv(wPath, Wq);
local_write_y_csv(yPath, Yq);
local_write_accum_csv(accPath, accRe, accIm);
local_write_vectors_vh(vhPath, Wq, Yq, accRe, accIm, W_BITS, Y_BITS, ACC_BITS);

fprintf('Step13.2 RTL golden generated in: %s\n', resultsDir);
fprintf('input_source_used=%s fallback_reason=%s W_method=%s\n', ...
    inputInfo.input_source_used, inputInfo.fallback_reason, inputInfo.W_method);
fprintf('full_N=%d full_B=%d full_L=%d golden_N=%d golden_B=%d golden_L=%d quant_mode=%s\n', ...
    fullN, fullB, fullL, goldenN, goldenB, goldenL, quantMode);
fprintf('W_BITS=%d Y_BITS=%d ACC_BITS=%d full_ACC_BITS=%d scale_w=%.17g scale_y=%.17g\n', ...
    W_BITS, Y_BITS, ACC_BITS, full_ACC_BITS, scaleW, scaleY);

function local_add_required_paths(repoRoot)
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot, 'core')));
addpath(fullfile(repoRoot, 'steps', 'step_11_1_beamspace_ml_validation', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_2_beamspace_w_design', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_3_beamspace_ml_search_acceleration', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_6_shared_center_rotatable_beamspace_manifold_cache', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_7_final_cached_c05_beamspace_ml_route', 'common'));
end

function value = local_getenv_int(name, defaultValue)
raw = strtrim(getenv(name));
if isempty(raw)
    value = defaultValue;
    return;
end
value = str2double(raw);
if ~isfinite(value) || value <= 0 || floor(value) ~= value
    error('Step13:InvalidEnvInteger', '%s must be a positive integer.', name);
end
end

function [wBits, yBits, zBits] = local_parse_quant_mode(modeName)
tokens = regexp(modeName, 'W(\d+)_Y(\d+)_Z(\d+)', 'tokens', 'once');
if isempty(tokens)
    error('Step13:InvalidQuantMode', ...
        'STEP13_RTL_GOLDEN_MODE must contain W<num>_Y<num>_Z<num>, got %s.', modeName);
end
wBits = str2double(tokens{1});
yBits = str2double(tokens{2});
zBits = str2double(tokens{3});
end

function inputInfo = local_make_step11_light_input(repoRoot, resultsDir, L)
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
context.L_default = L;
context.base_seed = 20260609;
context.result_dir = resultsDir;

scenario = struct();
scenario.scenario_name = 'step13_2_rtl_golden_step11_light';
scenario.az_sep_deg = 1.27;
scenario.el_sep_deg = 0.37;
scenario.snr_db = 30;
scenario.rho = 0;
scenario.phase_deg = 0;
scenario.beta = 0.67;

[input, ~, ~] = build_step11_7_frontend_like_input(context, scenario, centerAz, 1, ...
    'L', L, 'Seed', context.base_seed + 1302, ...
    'ReshapeMode', 'matrix_N_by_L', 'FrontendState', 'controlled_pair2d_candidate', ...
    'MethodTag', 'step13_2_rtl_golden');

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

inputInfo = local_make_input_info(W, Y, 'step11_light', '', true, false, WMethod);
end

function inputInfo = local_make_synthetic_input(N, B, L)
rng(132);
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

inputInfo = local_make_input_info(W, Y, 'synthetic', '', false, false, 'synthetic_DBF_W');
end

function inputInfo = local_make_input_info(W, Y, used, fallbackReason, adapterFound, fullBackendCalled, WMethod)
inputInfo = struct();
inputInfo.W = W;
inputInfo.Y = Y;
inputInfo.input_source_used = used;
inputInfo.fallback_reason = fallbackReason;
inputInfo.step11_adapter_found_flag = logical(adapterFound);
inputInfo.step11_7_full_backend_called = logical(fullBackendCalled);
inputInfo.W_method = WMethod;
end

function [xq, scale, clipRate] = local_quant_complex_int(x, bits)
maxInt = 2^(bits - 1) - 1;
minInt = -2^(bits - 1);
peak = max([max(abs(real(x(:)))), max(abs(imag(x(:)))), eps]);
scale = maxInt / peak;
ri = round(real(x) * scale);
ii = round(imag(x) * scale);
clipMask = ri > maxInt | ri < minInt | ii > maxInt | ii < minInt;
ri = min(max(ri, minInt), maxInt);
ii = min(max(ii, minInt), maxInt);
xq = complex(ri, ii);
clipRate = nnz(clipMask) / numel(x);
end

function [accRe, accIm] = local_accumulate_conj_w_y(Wq, Yq)
N = size(Wq, 1);
B = size(Wq, 2);
L = size(Yq, 2);
accRe = zeros(B, L);
accIm = zeros(B, L);
for b = 1:B
    wr = real(Wq(:, b));
    wi = imag(Wq(:, b));
    for l = 1:L
        yr = real(Yq(:, l));
        yi = imag(Yq(:, l));
        accRe(b, l) = sum(wr .* yr + wi .* yi);
        accIm(b, l) = sum(wr .* yi - wi .* yr);
    end
end
end

function local_write_manifest(pathName, resultsDir)
file_name = { ...
    'step13_dbf_rtl_golden_metadata.csv'; ...
    'step13_dbf_rtl_golden_w_int.csv'; ...
    'step13_dbf_rtl_golden_y_int.csv'; ...
    'step13_dbf_rtl_golden_accum.csv'; ...
    'step13_dbf_rtl_golden_vectors.vh'};
role = { ...
    'key value metadata'; ...
    'quantized W integer slice'; ...
    'quantized Y integer slice'; ...
    'raw integer accumulator golden'; ...
    'Verilog include for RTL testbench'};
directory = repmat({resultsDir}, numel(file_name), 1);
tbl = table(file_name, role, directory);
writetable(tbl, pathName);
end

function local_write_metadata(pathName, inputSourceRequested, inputInfo, quantMode, ...
    fullN, fullB, fullL, goldenN, goldenB, goldenL, W_BITS, Y_BITS, Z_BITS, ...
    ACC_BITS, full_ACC_BITS, scaleW, scaleY, clipRate)
metric = { ...
    'input_source_requested'; 'input_source_used'; 'fallback_reason'; 'W_method'; ...
    'full_N_input_channels'; 'full_B_output_beams'; 'full_L_snapshots'; ...
    'golden_N_limit'; 'golden_B_limit'; 'golden_L_limit'; 'quant_mode'; ...
    'W_bits'; 'Y_bits'; 'Z_bits'; 'ACC_bits'; 'full_ACC_bits'; ...
    'scale_w'; 'scale_y'; 'clip_rate'; 'step11_adapter_found_flag'; ...
    'step11_7_full_backend_called'; 'formal_result_claimed'; ...
    'rtl_scope'; 'not_implemented_in_step13_2'};
value = { ...
    inputSourceRequested; inputInfo.input_source_used; inputInfo.fallback_reason; ...
    inputInfo.W_method; sprintf('%d', fullN); sprintf('%d', fullB); sprintf('%d', fullL); ...
    sprintf('%d', goldenN); sprintf('%d', goldenB); sprintf('%d', goldenL); quantMode; ...
    sprintf('%d', W_BITS); sprintf('%d', Y_BITS); sprintf('%d', Z_BITS); ...
    sprintf('%d', ACC_BITS); sprintf('%d', full_ACC_BITS); sprintf('%.17g', scaleW); ...
    sprintf('%.17g', scaleY); sprintf('%.17g', clipRate); ...
    local_bool_text(inputInfo.step11_adapter_found_flag); ...
    local_bool_text(inputInfo.step11_7_full_backend_called); 'false'; ...
    'raw accumulator for Z = W^H Y'; ...
    'Rz; G_cache; 2D ML search; topK; C05; confidence; fallback'};
tbl = table(metric, value);
writetable(tbl, pathName);
end

function local_write_w_csv(pathName, Wq)
N = size(Wq, 1);
B = size(Wq, 2);
n_index = zeros(N * B, 1);
b_index = zeros(N * B, 1);
w_re = zeros(N * B, 1);
w_im = zeros(N * B, 1);
row = 0;
for b = 1:B
    for n = 1:N
        row = row + 1;
        n_index(row) = n - 1;
        b_index(row) = b - 1;
        w_re(row) = real(Wq(n, b));
        w_im(row) = imag(Wq(n, b));
    end
end
tbl = table(n_index, b_index, w_re, w_im);
writetable(tbl, pathName);
end

function local_write_y_csv(pathName, Yq)
N = size(Yq, 1);
L = size(Yq, 2);
n_index = zeros(N * L, 1);
l_index = zeros(N * L, 1);
y_re = zeros(N * L, 1);
y_im = zeros(N * L, 1);
row = 0;
for l = 1:L
    for n = 1:N
        row = row + 1;
        n_index(row) = n - 1;
        l_index(row) = l - 1;
        y_re(row) = real(Yq(n, l));
        y_im(row) = imag(Yq(n, l));
    end
end
tbl = table(n_index, l_index, y_re, y_im);
writetable(tbl, pathName);
end

function local_write_accum_csv(pathName, accRe, accIm)
B = size(accRe, 1);
L = size(accRe, 2);
b_index = zeros(B * L, 1);
l_index = zeros(B * L, 1);
acc_re = zeros(B * L, 1);
acc_im = zeros(B * L, 1);
row = 0;
for l = 1:L
    for b = 1:B
        row = row + 1;
        b_index(row) = b - 1;
        l_index(row) = l - 1;
        acc_re(row) = accRe(b, l);
        acc_im(row) = accIm(b, l);
    end
end
tbl = table(b_index, l_index, acc_re, acc_im);
writetable(tbl, pathName);
end

function local_write_vectors_vh(pathName, Wq, Yq, accRe, accIm, W_BITS, Y_BITS, ACC_BITS)
N = size(Wq, 1);
B = size(Wq, 2);
L = size(Yq, 2);
fid = fopen(pathName, 'w');
if fid < 0
    error('Step13:CannotWriteGoldenVh', 'Cannot open %s for writing.', pathName);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, '`ifndef STEP13_DBF_RTL_GOLDEN_VH\n');
fprintf(fid, '`define STEP13_DBF_RTL_GOLDEN_VH\n\n');
fprintf(fid, 'localparam integer STEP13_GOLDEN_N = %d;\n', N);
fprintf(fid, 'localparam integer STEP13_GOLDEN_B = %d;\n', B);
fprintf(fid, 'localparam integer STEP13_GOLDEN_L = %d;\n', L);
fprintf(fid, 'localparam integer STEP13_GOLDEN_W_BITS = %d;\n', W_BITS);
fprintf(fid, 'localparam integer STEP13_GOLDEN_Y_BITS = %d;\n', Y_BITS);
fprintf(fid, 'localparam integer STEP13_GOLDEN_ACC_BITS = %d;\n\n', ACC_BITS);
fprintf(fid, 'reg signed [STEP13_GOLDEN_W_BITS-1:0] step13_golden_w_re [0:STEP13_GOLDEN_N*STEP13_GOLDEN_B-1];\n');
fprintf(fid, 'reg signed [STEP13_GOLDEN_W_BITS-1:0] step13_golden_w_im [0:STEP13_GOLDEN_N*STEP13_GOLDEN_B-1];\n');
fprintf(fid, 'reg signed [STEP13_GOLDEN_Y_BITS-1:0] step13_golden_y_re [0:STEP13_GOLDEN_N*STEP13_GOLDEN_L-1];\n');
fprintf(fid, 'reg signed [STEP13_GOLDEN_Y_BITS-1:0] step13_golden_y_im [0:STEP13_GOLDEN_N*STEP13_GOLDEN_L-1];\n');
fprintf(fid, 'reg signed [STEP13_GOLDEN_ACC_BITS-1:0] step13_golden_acc_re [0:STEP13_GOLDEN_B*STEP13_GOLDEN_L-1];\n');
fprintf(fid, 'reg signed [STEP13_GOLDEN_ACC_BITS-1:0] step13_golden_acc_im [0:STEP13_GOLDEN_B*STEP13_GOLDEN_L-1];\n\n');
fprintf(fid, 'initial begin\n');
for b = 1:B
    for n = 1:N
        idx = (b - 1) * N + (n - 1);
        fprintf(fid, '  step13_golden_w_re[%d] = %s;\n', idx, local_verilog_signed_literal(W_BITS, real(Wq(n, b))));
        fprintf(fid, '  step13_golden_w_im[%d] = %s;\n', idx, local_verilog_signed_literal(W_BITS, imag(Wq(n, b))));
    end
end
for l = 1:L
    for n = 1:N
        idx = (l - 1) * N + (n - 1);
        fprintf(fid, '  step13_golden_y_re[%d] = %s;\n', idx, local_verilog_signed_literal(Y_BITS, real(Yq(n, l))));
        fprintf(fid, '  step13_golden_y_im[%d] = %s;\n', idx, local_verilog_signed_literal(Y_BITS, imag(Yq(n, l))));
    end
end
for l = 1:L
    for b = 1:B
        idx = (l - 1) * B + (b - 1);
        fprintf(fid, '  step13_golden_acc_re[%d] = %s;\n', idx, local_verilog_signed_literal(ACC_BITS, accRe(b, l)));
        fprintf(fid, '  step13_golden_acc_im[%d] = %s;\n', idx, local_verilog_signed_literal(ACC_BITS, accIm(b, l)));
    end
end
fprintf(fid, 'end\n\n');
fprintf(fid, '`endif\n');
end

function text = local_verilog_signed_literal(bits, value)
value = round(value);
uintValue = mod(value, 2^bits);
hexDigits = ceil(bits / 4);
text = sprintf('%d''sh%s', bits, dec2hex(uintValue, hexDigits));
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
