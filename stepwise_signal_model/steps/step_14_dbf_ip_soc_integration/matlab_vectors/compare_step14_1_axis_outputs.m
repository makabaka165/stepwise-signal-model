function compare_step14_1_axis_outputs()
%COMPARE_STEP14_1_AXIS_OUTPUTS Compare Step14.1 XSim AXIS output to golden CSV.

scriptDir = fileparts(mfilename('fullpath'));
step14Dir = fileparts(scriptDir);
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
vecDir = fullfile(outRoot, 'axis_vectors');
simDir = fullfile(outRoot, 'axis_sim');
cmpDir = fullfile(outRoot, 'axis_compare');
if ~exist(cmpDir, 'dir')
    mkdir(cmpDir);
end

expectedPath = fullfile(vecDir, 'step14_1_z_axis_expected.csv');
actualPath = fullfile(simDir, 'step14_1_axis_output.csv');
tbSummaryPath = fullfile(simDir, 'step14_1_axis_tb_summary.csv');

mustExist(expectedPath);
mustExist(actualPath);
mustExist(tbSummaryPath);

expected = readtable(expectedPath);
actual = readtable(actualPath);
validateColumns(expected, {'frame_index','beam_id','z_re','z_im','clip_re','clip_im','overflow_re','overflow_im','tdata_hex','expected_tlast'}, expectedPath);
validateColumns(actual, {'frame_index','beam_id','tdata_hex','z_re','z_im','clip_re','clip_im','overflow_re','overflow_im','tlast'}, actualPath);

expectedRows = height(expected);
actualRows = height(actual);
matchedRows = 0;
missingCount = 0;
duplicateCount = 0;
tdataMismatchCount = 0;
zValueMismatchCount = 0;
flagMismatchCount = 0;
tlastMismatchCount = 0;
beamOrderMismatchCount = 0;

actualUsed = false(actualRows, 1);
for k = 1:expectedRows
    frame = expected.frame_index(k);
    beam = expected.beam_id(k);
    hits = find(actual.frame_index == frame & actual.beam_id == beam);
    if isempty(hits)
        missingCount = missingCount + 1;
        continue;
    end
    if numel(hits) > 1
        duplicateCount = duplicateCount + numel(hits) - 1;
    end
    hit = hits(1);
    actualUsed(hit) = true;
    matchedRows = matchedRows + 1;
    expHex = lower(stringValue(expected.tdata_hex(k)));
    actHex = lower(stringValue(actual.tdata_hex(hit)));
    if ~strcmp(expHex, actHex)
        tdataMismatchCount = tdataMismatchCount + 1;
    end
    if expected.z_re(k) ~= actual.z_re(hit) || expected.z_im(k) ~= actual.z_im(hit)
        zValueMismatchCount = zValueMismatchCount + 1;
    end
    if expected.clip_re(k) ~= actual.clip_re(hit) || expected.clip_im(k) ~= actual.clip_im(hit) || ...
            expected.overflow_re(k) ~= actual.overflow_re(hit) || expected.overflow_im(k) ~= actual.overflow_im(hit)
        flagMismatchCount = flagMismatchCount + 1;
    end
    if expected.expected_tlast(k) ~= actual.tlast(hit)
        tlastMismatchCount = tlastMismatchCount + 1;
    end
end
duplicateCount = duplicateCount + sum(~actualUsed);

if actualRows == expectedRows
    for k = 1:actualRows
        expFrame = floor((k-1) / 7);
        expBeam = mod(k-1, 7);
        if actual.frame_index(k) ~= expFrame || actual.beam_id(k) ~= expBeam
            beamOrderMismatchCount = beamOrderMismatchCount + 1;
        end
    end
else
    beamOrderMismatchCount = abs(actualRows - expectedRows);
end

tbSummary = readKeyValueCsv(tbSummaryPath);
axisTbPassFlag = isTrueMetric(tbSummary, 'axis_tb_pass_flag');

axisOutputMatchFlag = expectedRows == 14 && actualRows == 14 && matchedRows == 14 && ...
    missingCount == 0 && duplicateCount == 0 && tdataMismatchCount == 0 && ...
    zValueMismatchCount == 0 && flagMismatchCount == 0 && tlastMismatchCount == 0 && ...
    beamOrderMismatchCount == 0;

stepPass = axisOutputMatchFlag && axisTbPassFlag;
comparisonStatus = ternary(stepPass, 'pass', 'fail');

summaryPairs = {
    'comparison_status', comparisonStatus;
    'expected_rows', num2str(expectedRows);
    'actual_rows', num2str(actualRows);
    'matched_rows', num2str(matchedRows);
    'missing_count', num2str(missingCount);
    'duplicate_count', num2str(duplicateCount);
    'tdata_mismatch_count', num2str(tdataMismatchCount);
    'z_value_mismatch_count', num2str(zValueMismatchCount);
    'flag_mismatch_count', num2str(flagMismatchCount);
    'tlast_mismatch_count', num2str(tlastMismatchCount);
    'beam_order_mismatch_count', num2str(beamOrderMismatchCount);
    'axis_output_match_flag', boolStr(axisOutputMatchFlag);
    'axis_tb_pass_flag', boolStr(axisTbPassFlag);
    'step14_1_axis_system_pass_flag', boolStr(stepPass);
    'formal_result_claimed', 'false';
    'dma_validation_flag', 'false';
    'ps_validation_flag', 'false';
    'board_validation_flag', 'false';
};
writeKeyValueCsv(fullfile(cmpDir, 'step14_1_axis_compare_summary.csv'), summaryPairs);

proceedToIp = stepPass;
keypoints = {
    'step14_1_axis_system_pass_flag', boolStr(stepPass);
    'proceed_to_custom_ip_packaging_flag', boolStr(proceedToIp);
    'proceed_to_dma_reference_design_flag', 'false';
    'proceed_to_board_validation_flag', 'false';
    'proceed_to_full_fpga_backend_flag', 'false';
    'formal_result_claimed', 'false';
    'dma_validation_flag', 'false';
    'ps_validation_flag', 'false';
    'board_validation_flag', 'false';
    'custom_ip_packaged_flag', 'false';
    'comparison_status', comparisonStatus;
};
writeKeyValueCsv(fullfile(cmpDir, 'step14_1_axis_keypoints.csv'), keypoints);

fprintf('Step14.1 AXIS compare status: %s\n', comparisonStatus);

end

function mustExist(filePath)
if ~exist(filePath, 'file')
    error('Step14.1:MissingInput', 'Required file is missing: %s', filePath);
end
end

function validateColumns(tbl, cols, filePath)
names = tbl.Properties.VariableNames;
for k = 1:numel(cols)
    if ~any(strcmp(names, cols{k}))
        error('Step14.1:MissingColumn', 'Missing column %s in %s.', cols{k}, filePath);
    end
end
end

function meta = readKeyValueCsv(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('Step14.1:FileOpen', 'Cannot open %s.', filePath);
end
cleanup = onCleanup(@() fclose(fid));
header = fgetl(fid); %#ok<NASGU>
meta = containers.Map('KeyType', 'char', 'ValueType', 'char');
line = fgetl(fid);
while ischar(line)
    if ~isempty(strtrim(line))
        comma = find(line == ',', 1, 'first');
        if ~isempty(comma)
            key = strtrim(line(1:comma-1));
            val = strtrim(line(comma+1:end));
            if numel(val) >= 2 && val(1) == '"' && val(end) == '"'
                val = val(2:end-1);
            end
            meta(key) = val;
        end
    end
    line = fgetl(fid);
end
end

function flag = isTrueMetric(meta, key)
flag = false;
if isKey(meta, key)
    val = lower(strtrim(meta(key)));
    flag = strcmp(val, 'true') || strcmp(val, '1') || strcmp(val, 'pass');
end
end

function s = stringValue(v)
if iscell(v)
    s = v{1};
elseif isstring(v)
    s = char(v);
elseif ischar(v)
    s = v;
else
    s = char(string(v));
end
end

function s = boolStr(flag)
if flag
    s = 'true';
else
    s = 'false';
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
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
