function compare_step14_3a_reference_bd_outputs()
%COMPARE_STEP14_3A_REFERENCE_BD_OUTPUTS Compare Reference BD XSim outputs.

scriptDir = fileparts(mfilename('fullpath'));
step14Dir = fileparts(scriptDir);
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
vecDir = fullfile(outRoot, 'axis_vectors');
bdDir = fullfile(outRoot, 'reference_bd');

expectedPath = fullfile(vecDir, 'step14_1_z_axis_expected.csv');
caseAPath = fullfile(bdDir, 'step14_3a_reference_bd_output.csv');
caseBPath = fullfile(bdDir, 'step14_3a_reference_bd_stress_output.csv');
tbSummaryPath = fullfile(bdDir, 'step14_3a_reference_bd_tb_summary.csv');

mustExist(expectedPath);
mustExist(caseAPath);
mustExist(caseBPath);
mustExist(tbSummaryPath);

expectedBase = readtable(expectedPath);
caseAActual = readtable(caseAPath);
caseBActual = readtable(caseBPath);
tbSummary = readKeyValueCsv(tbSummaryPath);

caseAExpected = expectedBase;
caseBExpected = buildCaseBExpected(expectedBase);

caseA = compareOne(caseAExpected, caseAActual, 14, 2);
caseB = compareOne(caseBExpected, caseBActual, 28, 4);
tbPass = isTrueMetric(tbSummary, 'reference_bd_tb_pass_flag');

referenceBdComparePass = caseA.outputMatch && caseB.outputMatch && tbPass;

summaryPairs = {
    'comparison_status', ternary(referenceBdComparePass, 'pass', 'fail');
    'case_a_expected_rows', num2str(caseA.expectedRows);
    'case_a_actual_rows', num2str(caseA.actualRows);
    'case_a_matched_rows', num2str(caseA.matchedRows);
    'case_b_expected_rows', num2str(caseB.expectedRows);
    'case_b_actual_rows', num2str(caseB.actualRows);
    'case_b_matched_rows', num2str(caseB.matchedRows);
    'missing_count', num2str(caseA.missingCount + caseB.missingCount);
    'duplicate_count', num2str(caseA.duplicateCount + caseB.duplicateCount);
    'tdata_mismatch_count', num2str(caseA.tdataMismatchCount + caseB.tdataMismatchCount);
    'z_value_mismatch_count', num2str(caseA.zValueMismatchCount + caseB.zValueMismatchCount);
    'flag_mismatch_count', num2str(caseA.flagMismatchCount + caseB.flagMismatchCount);
    'tlast_mismatch_count', num2str(caseA.tlastMismatchCount + caseB.tlastMismatchCount);
    'beam_order_mismatch_count', num2str(caseA.beamOrderMismatchCount + caseB.beamOrderMismatchCount);
    'case_a_output_match_flag', boolStr(caseA.outputMatch);
    'case_b_output_match_flag', boolStr(caseB.outputMatch);
    'reference_bd_tb_pass_flag', boolStr(tbPass);
    'reference_bd_compare_pass_flag', boolStr(referenceBdComparePass);
    'formal_result_claimed', 'false';
    'dma_validation_flag', 'false';
    'ps_validation_flag', 'false';
    'board_validation_flag', 'false';
};

writeKeyValueCsv(fullfile(bdDir, 'step14_3a_reference_bd_compare_summary.csv'), summaryPairs);
fprintf('Step14.3a Reference BD compare status: %s\n', ternary(referenceBdComparePass, 'pass', 'fail'));

end

function expected = buildCaseBExpected(expectedBase)
expected = expectedBase([], :);
for frame = 0:3
    src = expectedBase(expectedBase.frame_index == mod(frame, 2), :);
    src.frame_index(:) = frame;
    expected = [expected; src]; %#ok<AGROW>
end
end

function result = compareOne(expected, actual, requiredRows, expectedFrames)
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

if actualRows == requiredRows
    for k = 1:actualRows
        expFrame = floor((k-1) / 7);
        expBeam = mod(k-1, 7);
        if actual.frame_index(k) ~= expFrame || actual.beam_id(k) ~= expBeam
            beamOrderMismatchCount = beamOrderMismatchCount + 1;
        end
    end
else
    beamOrderMismatchCount = beamOrderMismatchCount + abs(actualRows - requiredRows);
end

outputMatch = expectedRows == requiredRows && actualRows == requiredRows && ...
    matchedRows == requiredRows && missingCount == 0 && duplicateCount == 0 && ...
    tdataMismatchCount == 0 && zValueMismatchCount == 0 && flagMismatchCount == 0 && ...
    tlastMismatchCount == 0 && beamOrderMismatchCount == 0 && ...
    max(actual.frame_index) == expectedFrames - 1;

result = struct( ...
    'expectedRows', expectedRows, ...
    'actualRows', actualRows, ...
    'matchedRows', matchedRows, ...
    'missingCount', missingCount, ...
    'duplicateCount', duplicateCount, ...
    'tdataMismatchCount', tdataMismatchCount, ...
    'zValueMismatchCount', zValueMismatchCount, ...
    'flagMismatchCount', flagMismatchCount, ...
    'tlastMismatchCount', tlastMismatchCount, ...
    'beamOrderMismatchCount', beamOrderMismatchCount, ...
    'outputMatch', outputMatch);
end

function mustExist(filePath)
if ~exist(filePath, 'file')
    error('Step14.3a:MissingInput', 'Required file is missing: %s', filePath);
end
end

function meta = readKeyValueCsv(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('Step14.3a:FileOpen', 'Cannot open %s.', filePath);
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
    error('Step14.3a:FileOpen', 'Cannot open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,value\n');
for k = 1:size(pairs, 1)
    fprintf(fid, '%s,%s\n', pairs{k,1}, pairs{k,2});
end
end
