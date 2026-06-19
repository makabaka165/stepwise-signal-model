function generate_step14_1_axis_vectors()
%GENERATE_STEP14_1_AXIS_VECTORS Build Step14.1 AXIS smoke vectors from Step13.
%
% This script reads only the frozen Step13.4 full-N golden CSV files and writes
% Step14.1 AXI4-Stream replay, W ROM, expected Z, metadata, and manifest files.
% It does not modify Step13 files and does not synthesize replacement data.

scriptDir = fileparts(mfilename('fullpath'));
step14Dir = fileparts(scriptDir);
repoStepDir = fileparts(step14Dir);
step13Dir = fullfile(repoStepDir, 'step_13_fpga_soc_dbf_boundary');
step13FullnDir = fullfile(step13Dir, 'results_step13_fpga_soc_dbf_boundary', 'rtl_fulln');

outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
vecDir = fullfile(outRoot, 'axis_vectors');
if ~exist(vecDir, 'dir')
    mkdir(vecDir);
end

metadataPath = fullfile(step13FullnDir, 'step13_4_fulln_metadata.csv');
wPath = fullfile(step13FullnDir, 'step13_4_fulln_w_int.csv');
yPath = fullfile(step13FullnDir, 'step13_4_fulln_y_int.csv');
zPath = fullfile(step13FullnDir, 'step13_4_fulln_z24.csv');

mustExist(metadataPath);
mustExist(wPath);
mustExist(yPath);
mustExist(zPath);

meta = readKeyValueCsv(metadataPath);
expectMeta(meta, 'W_method', 'greedy_combined_B7');
expectMeta(meta, 'N', '2080');
expectMeta(meta, 'B', '7');
expectMeta(meta, 'L', '2');
expectMeta(meta, 'W_bits', '18');
expectMeta(meta, 'Y_bits', '16');
expectMeta(meta, 'ACC_bits', '48');
expectMeta(meta, 'Z_bits', '24');
expectMeta(meta, 'engineering_Z_shift_bits', '20');
expectMeta(meta, 'formal_result_claimed', 'false');

N = 2080;
B = 7;
L = 2;
W_BITS = 18;
Y_BITS = 16;
Z_BITS = 24;

wTbl = readtable(wPath);
yTbl = readtable(yPath);
zTbl = readtable(zPath);

validateTableColumns(wTbl, {'n_index','b_index','w_re','w_im'}, wPath);
validateTableColumns(yTbl, {'n_index','l_index','y_re','y_im'}, yPath);
validateTableColumns(zTbl, {'b_index','l_index','z_re','z_im','clip_re','clip_im','overflow_re','overflow_im'}, zPath);

manifestRows = {};

% W ROM files: one real and one imag file per beam, fixed-width 18-bit hex.
for beam = 0:(B-1)
    beamRows = wTbl(wTbl.b_index == beam, :);
    if height(beamRows) ~= N
        error('Step14.1:BadWRows', 'Expected %d W rows for beam %d, got %d.', N, beam, height(beamRows));
    end
    beamRows = sortrows(beamRows, 'n_index');
    if any(beamRows.n_index(:) ~= (0:(N-1))')
        error('Step14.1:BadWIndex', 'W n_index is not contiguous for beam %d.', beam);
    end

    reName = sprintf('step14_1_w_re_b%d.mem', beam);
    imName = sprintf('step14_1_w_im_b%d.mem', beam);
    writeHexVector(fullfile(vecDir, reName), beamRows.w_re, W_BITS, 5);
    writeHexVector(fullfile(vecDir, imName), beamRows.w_im, W_BITS, 5);
    manifestRows(end+1,:) = {reName, relVecPath(reName), N, sprintf('W real ROM beam %d, signed W18 twos-complement hex', beam)}; %#ok<AGROW>
    manifestRows(end+1,:) = {imName, relVecPath(imName), N, sprintf('W imag ROM beam %d, signed W18 twos-complement hex', beam)}; %#ok<AGROW>
end

% Y AXIS input mem and helper CSV.
yMemName = 'step14_1_y_axis_tdata.mem';
yCsvName = 'step14_1_y_axis_input.csv';
yMem = fopen(fullfile(vecDir, yMemName), 'w');
if yMem < 0
    error('Step14.1:FileOpen', 'Cannot open Y mem for writing.');
end
yCsv = fopen(fullfile(vecDir, yCsvName), 'w');
if yCsv < 0
    fclose(yMem);
    error('Step14.1:FileOpen', 'Cannot open Y CSV for writing.');
end
fprintf(yCsv, 'frame_index,element_index,y_re,y_im,tdata_hex,expected_tlast\n');
for frame = 0:(L-1)
    frameRows = yTbl(yTbl.l_index == frame, :);
    if height(frameRows) ~= N
        error('Step14.1:BadYRows', 'Expected %d Y rows for frame %d, got %d.', N, frame, height(frameRows));
    end
    frameRows = sortrows(frameRows, 'n_index');
    if any(frameRows.n_index(:) ~= (0:(N-1))')
        error('Step14.1:BadYIndex', 'Y n_index is not contiguous for frame %d.', frame);
    end
    for n = 0:(N-1)
        yRe = frameRows.y_re(n+1);
        yIm = frameRows.y_im(n+1);
        word = bitor(twosUnsigned(yRe, Y_BITS), bitshift(twosUnsigned(yIm, Y_BITS), 16));
        hexWord = lower(dec2hex(word, 8));
        expectedLast = double(n == (N-1));
        fprintf(yMem, '%s\n', hexWord);
        fprintf(yCsv, '%d,%d,%d,%d,%s,%d\n', frame, n, yRe, yIm, hexWord, expectedLast);
    end
end
fclose(yMem);
fclose(yCsv);
manifestRows(end+1,:) = {yMemName, relVecPath(yMemName), N*L, 'AXI4-Stream Y tdata replay, 32-bit hex'}; %#ok<AGROW>
manifestRows(end+1,:) = {yCsvName, relVecPath(yCsvName), N*L, 'Decoded Y AXIS input helper CSV'}; %#ok<AGROW>

% Z expected mem and helper CSV.
zMemName = 'step14_1_z_axis_expected.mem';
zCsvName = 'step14_1_z_axis_expected.csv';
zMem = fopen(fullfile(vecDir, zMemName), 'w');
if zMem < 0
    error('Step14.1:FileOpen', 'Cannot open Z mem for writing.');
end
zCsv = fopen(fullfile(vecDir, zCsvName), 'w');
if zCsv < 0
    fclose(zMem);
    error('Step14.1:FileOpen', 'Cannot open Z CSV for writing.');
end
fprintf(zCsv, 'frame_index,beam_id,z_re,z_im,clip_re,clip_im,overflow_re,overflow_im,tdata_hex,expected_tlast\n');
for frame = 0:(L-1)
    for beam = 0:(B-1)
        row = zTbl(zTbl.l_index == frame & zTbl.b_index == beam, :);
        if height(row) ~= 1
            error('Step14.1:BadZRows', 'Expected exactly one Z row for frame %d beam %d, got %d.', frame, beam, height(row));
        end
        zRe = row.z_re(1);
        zIm = row.z_im(1);
        clipRe = row.clip_re(1);
        clipIm = row.clip_im(1);
        overflowRe = row.overflow_re(1);
        overflowIm = row.overflow_im(1);
        word = packZAxisWord(zRe, zIm, clipRe, clipIm, overflowRe, overflowIm, beam);
        hexWord = lower(uint64ToHex(word, 16));
        expectedLast = double(beam == (B-1));
        fprintf(zMem, '%s\n', hexWord);
        fprintf(zCsv, '%d,%d,%d,%d,%d,%d,%d,%d,%s,%d\n', frame, beam, zRe, zIm, clipRe, clipIm, overflowRe, overflowIm, hexWord, expectedLast);
    end
end
fclose(zMem);
fclose(zCsv);
manifestRows(end+1,:) = {zMemName, relVecPath(zMemName), B*L, 'Expected AXI4-Stream Z tdata, 64-bit hex'}; %#ok<AGROW>
manifestRows(end+1,:) = {zCsvName, relVecPath(zCsvName), B*L, 'Decoded expected Z AXIS output helper CSV'}; %#ok<AGROW>

% Step14.1 metadata and manifest.
metadataName = 'step14_1_axis_vector_metadata.csv';
metadataOut = fullfile(vecDir, metadataName);
metadataPairs = {
    'source_step', 'Step13.4';
    'source_commit', '1637556';
    'input_source', 'step11_light';
    'W_method', 'greedy_combined_B7';
    'N_input_channels', '2080';
    'B_output_beams', '7';
    'L_frames', '2';
    'W_bits', '18';
    'Y_bits', '16';
    'ACC_bits', '48';
    'Z_bits', '24';
    'engineering_Z_shift_bits', '20';
    'y_axis_data_width', '32';
    'z_axis_data_width', '64';
    'formal_result_claimed', 'false';
    'dma_validation_flag', 'false';
    'ps_validation_flag', 'false';
    'board_validation_flag', 'false';
    'custom_ip_packaged_flag', 'false';
    'source_metadata_relative_path', '../step_13_fpga_soc_dbf_boundary/results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_metadata.csv';
};
writeKeyValueCsv(metadataOut, metadataPairs);
manifestRows(end+1,:) = {metadataName, relVecPath(metadataName), size(metadataPairs, 1), 'Step14.1 vector metadata'}; %#ok<AGROW>

manifestName = 'step14_1_axis_vector_manifest.csv';
manifestPath = fullfile(vecDir, manifestName);
fid = fopen(manifestPath, 'w');
if fid < 0
    error('Step14.1:FileOpen', 'Cannot open manifest for writing.');
end
fprintf(fid, 'file_name,relative_path,rows,description\n');
for k = 1:size(manifestRows, 1)
    fprintf(fid, '%s,%s,%d,"%s"\n', manifestRows{k,1}, manifestRows{k,2}, manifestRows{k,3}, manifestRows{k,4});
end
fclose(fid);

fprintf('Step14.1 AXIS vectors written to %s\n', vecDir);

end

function mustExist(filePath)
if ~exist(filePath, 'file')
    error('Step14.1:MissingInput', 'Required Step13 input is missing: %s', filePath);
end
end

function meta = readKeyValueCsv(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('Step14.1:FileOpen', 'Cannot open metadata: %s', filePath);
end
cleanup = onCleanup(@() fclose(fid));
header = fgetl(fid); %#ok<NASGU>
meta = containers.Map('KeyType', 'char', 'ValueType', 'char');
line = fgetl(fid);
while ischar(line)
    if ~isempty(strtrim(line))
        parts = splitCsvLine(line);
        if numel(parts) >= 2
            meta(strtrim(parts{1})) = stripQuotes(strtrim(parts{2}));
        end
    end
    line = fgetl(fid);
end
end

function parts = splitCsvLine(line)
parts = {};
current = '';
inQuote = false;
for idx = 1:numel(line)
    ch = line(idx);
    if ch == '"'
        inQuote = ~inQuote;
        current = [current ch]; %#ok<AGROW>
    elseif ch == ',' && ~inQuote
        parts{end+1} = current; %#ok<AGROW>
        current = '';
    else
        current = [current ch]; %#ok<AGROW>
    end
end
parts{end+1} = current;
end

function s = stripQuotes(s)
if numel(s) >= 2 && s(1) == '"' && s(end) == '"'
    s = s(2:end-1);
end
end

function expectMeta(meta, key, expected)
if ~isKey(meta, key)
    error('Step14.1:MissingMetadata', 'Missing Step13 metadata key: %s', key);
end
actual = meta(key);
if ~strcmp(actual, expected)
    error('Step14.1:MetadataMismatch', 'Step13 metadata %s expected %s but got %s.', key, expected, actual);
end
end

function validateTableColumns(tbl, cols, filePath)
names = tbl.Properties.VariableNames;
for k = 1:numel(cols)
    if ~any(strcmp(names, cols{k}))
        error('Step14.1:MissingColumn', 'Missing column %s in %s.', cols{k}, filePath);
    end
end
end

function writeHexVector(filePath, values, bits, hexWidth)
fid = fopen(filePath, 'w');
if fid < 0
    error('Step14.1:FileOpen', 'Cannot open %s for writing.', filePath);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(values)
    word = twosUnsigned(values(k), bits);
    fprintf(fid, '%s\n', lower(dec2hex(word, hexWidth)));
end
end

function word = twosUnsigned(value, bits)
value = double(value);
limit = 2^bits;
minVal = -2^(bits-1);
maxVal = 2^(bits-1) - 1;
if value < minVal || value > maxVal
    error('Step14.1:RangeError', 'Value %g is outside signed %d-bit range.', value, bits);
end
if value < 0
    word = uint64(limit + value);
else
    word = uint64(value);
end
end

function word = packZAxisWord(zRe, zIm, clipRe, clipIm, overflowRe, overflowIm, beam)
word = uint64(0);
word = bitor(word, twosUnsigned(zRe, 24));
word = bitor(word, bitshift(twosUnsigned(zIm, 24), 24));
word = bitor(word, bitshift(uint64(clipRe ~= 0), 48));
word = bitor(word, bitshift(uint64(clipIm ~= 0), 49));
word = bitor(word, bitshift(uint64(overflowRe ~= 0), 50));
word = bitor(word, bitshift(uint64(overflowIm ~= 0), 51));
word = bitor(word, bitshift(uint64(beam), 52));
end

function hex = uint64ToHex(word, width)
hi = bitshift(word, -32);
lo = bitand(word, uint64(2^32 - 1));
hex = sprintf('%08x%08x', double(hi), double(lo));
if nargin > 1 && numel(hex) < width
    hex = [repmat('0', 1, width - numel(hex)) hex];
end
end

function p = relVecPath(fileName)
p = ['results_step14_dbf_ip_soc_integration/axis_vectors/' fileName];
end

function writeKeyValueCsv(filePath, pairs)
fid = fopen(filePath, 'w');
if fid < 0
    error('Step14.1:FileOpen', 'Cannot open %s for writing.', filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,value\n');
for k = 1:size(pairs, 1)
    fprintf(fid, '%s,%s\n', pairs{k,1}, pairs{k,2});
end
end
