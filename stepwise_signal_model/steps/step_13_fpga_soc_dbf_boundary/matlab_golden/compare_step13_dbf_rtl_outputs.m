% Compare Step13 RTL smoke outputs against MATLAB golden CSVs.
%
% Step13.3 compares both the raw accumulator and the Z24 shift/round/saturate
% datapath. Missing simulation output is reported as unavailable rather than
% a pass. This script does not claim formal closure.

clearvars;
clc;

scriptDir = fileparts(mfilename('fullpath'));
stepDir = fileparts(scriptDir);
resultsRoot = fullfile(stepDir, 'results_step13_fpga_soc_dbf_boundary');
summaryPath = fullfile(resultsRoot, 'rtl_sim', 'step13_dbf_rtl_compare_summary.csv');
if ~exist(fileparts(summaryPath), 'dir')
    mkdir(fileparts(summaryPath));
end

accGoldenRelPath = fullfile('results_step13_fpga_soc_dbf_boundary', ...
    'rtl_golden', 'step13_dbf_rtl_golden_accum.csv');
accSimRelPath = fullfile('results_step13_fpga_soc_dbf_boundary', ...
    'rtl_sim', 'dbf_core_accum_output.csv');
z24GoldenRelPath = fullfile('results_step13_fpga_soc_dbf_boundary', ...
    'rtl_golden', 'step13_dbf_rtl_golden_z24.csv');
z24SimRelPath = fullfile('results_step13_fpga_soc_dbf_boundary', ...
    'rtl_sim', 'dbf_core_z24_output.csv');

accGoldenPath = fullfile(stepDir, accGoldenRelPath);
accSimPath = fullfile(stepDir, accSimRelPath);
z24GoldenPath = fullfile(stepDir, z24GoldenRelPath);
z24SimPath = fullfile(stepDir, z24SimRelPath);

if ~exist(accGoldenPath, 'file')
    note = sprintf('missing accumulator golden file: %s', local_slash_path(accGoldenRelPath));
    local_write_summary(summaryPath, 'unavailable', 0, 0, 0, 0, 0, false, ...
        0, 0, 0, 0, 0, false, note);
    error('Step13:MissingRtlGolden', 'Missing MATLAB golden file: %s', accGoldenPath);
end
if ~exist(z24GoldenPath, 'file')
    note = sprintf('missing Z24 golden file: %s', local_slash_path(z24GoldenRelPath));
    local_write_summary(summaryPath, 'unavailable', 0, 0, 0, 0, 0, false, ...
        0, 0, 0, 0, 0, false, note);
    error('Step13:MissingZ24Golden', 'Missing MATLAB Z24 golden file: %s', z24GoldenPath);
end

accGoldenTbl = readtable(accGoldenPath);
z24GoldenTbl = readtable(z24GoldenPath);

if ~exist(accSimPath, 'file')
    note = sprintf('missing accumulator simulation file: %s', local_slash_path(accSimRelPath));
    local_write_summary(summaryPath, 'unavailable', height(accGoldenTbl), 0, 0, ...
        height(accGoldenTbl), 0, false, height(z24GoldenTbl), 0, 0, ...
        height(z24GoldenTbl), 0, false, note);
    fprintf('Step13 RTL compare unavailable: missing simulation file %s\n', ...
        local_slash_path(accSimRelPath));
    return;
end
if ~exist(z24SimPath, 'file')
    note = sprintf('missing Z24 simulation file: %s', local_slash_path(z24SimRelPath));
    local_write_summary(summaryPath, 'unavailable', height(accGoldenTbl), ...
        height(readtable(accSimPath)), 0, height(accGoldenTbl), 0, false, ...
        height(z24GoldenTbl), 0, 0, height(z24GoldenTbl), 0, false, note);
    fprintf('Step13 RTL compare unavailable: missing simulation file %s\n', ...
        local_slash_path(z24SimRelPath));
    return;
end

accSimTbl = readtable(accSimPath);
z24SimTbl = readtable(z24SimPath);

[accMatchedRows, accMissingCount, accMismatchCount] = local_compare_accum(accGoldenTbl, accSimTbl);
[z24MatchedRows, z24MissingCount, z24MismatchCount] = local_compare_z24(z24GoldenTbl, z24SimTbl);

accPassFlag = accMissingCount == 0 && accMismatchCount == 0 && ...
    accMatchedRows == height(accGoldenTbl);
z24PassFlag = z24MissingCount == 0 && z24MismatchCount == 0 && ...
    z24MatchedRows == height(z24GoldenTbl);
passFlag = accPassFlag && z24PassFlag;

if passFlag
    status = 'pass';
    note = 'RTL raw accumulator and Z24 output match MATLAB golden exactly';
else
    status = 'fail';
    note = 'RTL raw accumulator or Z24 output mismatch or missing rows';
end

local_write_summary(summaryPath, status, height(accGoldenTbl), height(accSimTbl), ...
    accMatchedRows, accMissingCount, accMismatchCount, accPassFlag, ...
    height(z24GoldenTbl), height(z24SimTbl), z24MatchedRows, z24MissingCount, ...
    z24MismatchCount, z24PassFlag, note);

fprintf('Step13 RTL compare status=%s acc_match=%s z24_match=%s acc_missing=%d acc_mismatch=%d z24_missing=%d z24_mismatch=%d\n', ...
    status, local_bool_text(accPassFlag), local_bool_text(z24PassFlag), ...
    accMissingCount, accMismatchCount, z24MissingCount, z24MismatchCount);
if ~passFlag
    error('Step13:RtlCompareMismatch', 'RTL compare failed.');
end

function [matchedRows, missingCount, mismatchCount] = local_compare_accum(goldenTbl, simTbl)
missingCount = 0;
mismatchCount = 0;
matchedRows = 0;
for i = 1:height(goldenTbl)
    b = goldenTbl.b_index(i);
    l = goldenTbl.l_index(i);
    idx = find(simTbl.b_index == b & simTbl.l_index == l, 1);
    if isempty(idx)
        missingCount = missingCount + 1;
        continue;
    end
    matchedRows = matchedRows + 1;
    if simTbl.acc_re(idx) ~= goldenTbl.acc_re(i) || ...
            simTbl.acc_im(idx) ~= goldenTbl.acc_im(i)
        mismatchCount = mismatchCount + 1;
    end
end
end

function [matchedRows, missingCount, mismatchCount] = local_compare_z24(goldenTbl, simTbl)
missingCount = 0;
mismatchCount = 0;
matchedRows = 0;
for i = 1:height(goldenTbl)
    b = goldenTbl.b_index(i);
    l = goldenTbl.l_index(i);
    idx = find(simTbl.b_index == b & simTbl.l_index == l, 1);
    if isempty(idx)
        missingCount = missingCount + 1;
        continue;
    end
    matchedRows = matchedRows + 1;
    mismatch = simTbl.z_re(idx) ~= goldenTbl.z_re(i) || ...
        simTbl.z_im(idx) ~= goldenTbl.z_im(i) || ...
        simTbl.clip_re(idx) ~= goldenTbl.clip_re(i) || ...
        simTbl.clip_im(idx) ~= goldenTbl.clip_im(i) || ...
        simTbl.overflow_re(idx) ~= goldenTbl.overflow_re(i) || ...
        simTbl.overflow_im(idx) ~= goldenTbl.overflow_im(i);
    if mismatch
        mismatchCount = mismatchCount + 1;
    end
end
end

function local_write_summary(pathName, status, accGoldenRows, accSimRows, ...
    accMatchedRows, accMissingCount, accMismatchCount, accPassFlag, ...
    z24GoldenRows, z24SimRows, z24MatchedRows, z24MissingCount, ...
    z24MismatchCount, z24PassFlag, note)
metric = {'comparison_status'; ...
    'accumulator_golden_rows'; 'accumulator_sim_rows'; ...
    'accumulator_matched_rows'; 'accumulator_missing_count'; ...
    'accumulator_mismatch_count'; 'accumulator_match_flag'; ...
    'golden_rows'; 'sim_rows'; 'matched_rows'; 'missing_count'; ...
    'mismatch_count'; ...
    'z24_golden_rows'; 'z24_sim_rows'; 'z24_matched_rows'; ...
    'z24_missing_count'; 'z24_mismatch_count'; 'z24_match_flag'; ...
    'formal_result_claimed'; 'note'};
value = {status; sprintf('%d', accGoldenRows); sprintf('%d', accSimRows); ...
    sprintf('%d', accMatchedRows); sprintf('%d', accMissingCount); ...
    sprintf('%d', accMismatchCount); local_bool_text(accPassFlag); ...
    sprintf('%d', accGoldenRows); sprintf('%d', accSimRows); ...
    sprintf('%d', accMatchedRows); sprintf('%d', accMissingCount); ...
    sprintf('%d', accMismatchCount); sprintf('%d', z24GoldenRows); ...
    sprintf('%d', z24SimRows); sprintf('%d', z24MatchedRows); ...
    sprintf('%d', z24MissingCount); sprintf('%d', z24MismatchCount); ...
    local_bool_text(z24PassFlag); 'false'; note};
tbl = table(metric, value);
writetable(tbl, pathName);
end

function text = local_bool_text(value)
if value
    text = 'true';
else
    text = 'false';
end
end

function text = local_slash_path(pathText)
text = strrep(pathText, '\', '/');
end
