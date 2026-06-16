% Compare Step13.2 RTL accumulator smoke output against MATLAB golden CSV.
%
% This script compares raw integer accumulators only. Missing simulation
% output is reported as unavailable rather than a pass.

clearvars;
clc;

scriptDir = fileparts(mfilename('fullpath'));
stepDir = fileparts(scriptDir);
resultsRoot = fullfile(stepDir, 'results_step13_fpga_soc_dbf_boundary');
goldenRelPath = fullfile('results_step13_fpga_soc_dbf_boundary', 'rtl_golden', ...
    'step13_dbf_rtl_golden_accum.csv');
simRelPath = fullfile('results_step13_fpga_soc_dbf_boundary', 'rtl_sim', ...
    'dbf_core_accum_output.csv');
goldenPath = fullfile(stepDir, goldenRelPath);
simPath = fullfile(stepDir, simRelPath);
summaryPath = fullfile(resultsRoot, 'rtl_sim', 'step13_dbf_rtl_compare_summary.csv');
if ~exist(fileparts(summaryPath), 'dir')
    mkdir(fileparts(summaryPath));
end

if ~exist(goldenPath, 'file')
    local_write_summary(summaryPath, 'unavailable', 0, 0, 0, 0, 0, false, ...
        sprintf('missing golden file: %s', local_slash_path(goldenRelPath)));
    error('Step13:MissingRtlGolden', 'Missing MATLAB golden file: %s', goldenPath);
end

goldenTbl = readtable(goldenPath);

if ~exist(simPath, 'file')
    local_write_summary(summaryPath, 'unavailable', height(goldenTbl), 0, 0, ...
        height(goldenTbl), 0, false, ...
        sprintf('missing simulation file: %s', local_slash_path(simRelPath)));
    fprintf('Step13.2 RTL compare unavailable: missing simulation file %s\n', ...
        local_slash_path(simRelPath));
    return;
end

simTbl = readtable(simPath);

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
    if simTbl.acc_re(idx) ~= goldenTbl.acc_re(i) || simTbl.acc_im(idx) ~= goldenTbl.acc_im(i)
        mismatchCount = mismatchCount + 1;
    end
end

passFlag = missingCount == 0 && mismatchCount == 0 && matchedRows == height(goldenTbl);
if passFlag
    status = 'pass';
    note = 'RTL accumulator output matches MATLAB golden exactly';
else
    status = 'fail';
    note = 'RTL accumulator output mismatch or missing rows';
end

local_write_summary(summaryPath, status, height(goldenTbl), height(simTbl), ...
    matchedRows, missingCount, mismatchCount, passFlag, note);

fprintf('Step13.2 RTL compare status=%s matched_rows=%d missing=%d mismatch=%d\n', ...
    status, matchedRows, missingCount, mismatchCount);
if ~passFlag
    error('Step13:RtlCompareMismatch', 'RTL accumulator compare failed.');
end

function local_write_summary(pathName, status, goldenRows, simRows, matchedRows, ...
    missingCount, mismatchCount, passFlag, note)
metric = {'comparison_status'; 'golden_rows'; 'sim_rows'; 'matched_rows'; ...
    'missing_count'; 'mismatch_count'; 'accumulator_match_flag'; ...
    'formal_result_claimed'; 'note'};
value = {status; sprintf('%d', goldenRows); sprintf('%d', simRows); ...
    sprintf('%d', matchedRows); sprintf('%d', missingCount); ...
    sprintf('%d', mismatchCount); local_bool_text(passFlag); 'false'; note};
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
