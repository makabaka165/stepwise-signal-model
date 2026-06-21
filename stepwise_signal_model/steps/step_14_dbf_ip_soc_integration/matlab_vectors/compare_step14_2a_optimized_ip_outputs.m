function compare_step14_2a_optimized_ip_outputs()
%COMPARE_STEP14_2A_OPTIMIZED_IP_OUTPUTS Compare optimized packaged IP XSim output.

scriptDir = fileparts(mfilename('fullpath'));
step14Dir = fileparts(scriptDir);
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
vecDir = fullfile(outRoot, 'axis_vectors');
xsimDir = fullfile(outRoot, 'ip_xsim');
cmpDir = fullfile(outRoot, 'ip_compare');
if ~exist(cmpDir, 'dir')
    mkdir(cmpDir);
end

expectedPath = fullfile(vecDir, 'step14_1_z_axis_expected.csv');
actualPath = fullfile(xsimDir, 'step14_2_packaged_ip_output.csv');
tbSummaryPath = fullfile(xsimDir, 'step14_2_packaged_ip_tb_summary.csv');

mustExist(expectedPath);
mustExist(actualPath);
mustExist(tbSummaryPath);

[summaryPairs, outputMatch, tbPass, comparePass] = compareTables(expectedPath, actualPath, tbSummaryPath); %#ok<ASGLU>
writeKeyValueCsv(fullfile(cmpDir, 'step14_2a_optimized_ip_compare_summary.csv'), summaryPairs);
fprintf('Step14.2a optimized IP compare status: %s\n', ternary(comparePass, 'pass', 'fail'));

end

function [summaryPairs, outputMatch, tbPass, comparePass] = compareTables(expectedPath, actualPath, tbSummaryPath)
expected = readtable(expectedPath);
actual = readtable(actualPath);
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
    if ~strcmp(lower(stringValue(expected.tdata_hex(k))), lower(stringValue(actual.tdata_hex(hit))))
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
tbPass = isTrueMetric(tbSummary, 'packaged_ip_tb_pass_flag');
outputMatch = expectedRows == 14 && actualRows == 14 && matchedRows == 14 && ...
    missingCount == 0 && duplicateCount == 0 && tdataMismatchCount == 0 && ...
    zValueMismatchCount == 0 && flagMismatchCount == 0 && tlastMismatchCount == 0 && ...
    beamOrderMismatchCount == 0;
comparePass = outputMatch && tbPass;

summaryPairs = {
    'comparison_status', ternary(comparePass, 'pass', 'fail');
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
    'packaged_ip_output_match_flag', boolStr(outputMatch);
    'packaged_ip_tb_pass_flag', boolStr(tbPass);
    'packaged_ip_compare_pass_flag', boolStr(comparePass);
    'formal_result_claimed', 'false';
};
end

function mustExist(filePath)
if ~exist(filePath, 'file')
    error('Step14.2a:MissingInput', 'Required file is missing: %s', filePath);
end
end

function meta = readKeyValueCsv(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('Step14.2a:FileOpen', 'Cannot open %s.', filePath);
end
cleanup = onCleanup(@() fclose(fid));
fgetl(fid);
meta = containers.Map('KeyType', 'char', 'ValueType', 'char');
line = fgetl(fid);
while ischar(line)
    comma = find(line == ',', 1, 'first');
    if ~isempty(comma)
        meta(strtrim(line(1:comma-1))) = strtrim(line(comma+1:end));
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

function writeKeyValueCsv(path, pairs)
fid = fopen(path, 'w');
if fid < 0
    error('Step14.2a:FileOpen', 'Cannot open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,value\n');
for k = 1:size(pairs, 1)
    fprintf(fid, '%s,%s\n', pairs{k,1}, pairs{k,2});
end
end
