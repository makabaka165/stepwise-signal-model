function run_step14_2_custom_ip_validation()
%RUN_STEP14_2_CUSTOM_IP_VALIDATION Step14.2 MATLAB aggregation and compare entry.
% This script does not invoke Vivado. Run vivado/package_*.ps1 and
% vivado/validate_*.ps1 first, then rerun this MATLAB entry point.

step14Dir = fileparts(mfilename('fullpath'));
matlabVectorDir = fullfile(step14Dir, 'matlab_vectors');
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
axisCompareDir = fullfile(outRoot, 'axis_compare');
pkgDir = fullfile(outRoot, 'ip_package');
xsimDir = fullfile(outRoot, 'ip_xsim');
synthDir = fullfile(outRoot, 'ip_synth');
cmpDir = fullfile(outRoot, 'ip_compare');
if ~exist(cmpDir, 'dir')
    mkdir(cmpDir);
end

addpath(matlabVectorDir);

step14_1_keypoints = readMaybe(fullfile(axisCompareDir, 'step14_1_axis_keypoints.csv'));
if ~isTrueMetric(step14_1_keypoints, 'step14_1_axis_system_pass_flag') || ...
        ~isTrueMetric(step14_1_keypoints, 'proceed_to_custom_ip_packaging_flag')
    writeBlockedKeypoints(cmpDir, 'step14_1_axis_system_not_ready', step14_1_keypoints);
    fprintf('Step14.2 blocked: Step14.1 keypoints are not ready for packaging.\n');
    return;
end

packageSummaryPath = fullfile(pkgDir, 'step14_2_ip_package_summary.csv');
catalogSummaryPath = fullfile(pkgDir, 'step14_2_ip_catalog_summary.csv');
xsimSummaryPath = fullfile(xsimDir, 'step14_2_packaged_ip_xsim_summary.csv');
synthSummaryPath = fullfile(synthDir, 'step14_2_packaged_ip_ooc_synthesis_summary.csv');
packagedOutputPath = fullfile(xsimDir, 'step14_2_packaged_ip_output.csv');
packagedTbSummaryPath = fullfile(xsimDir, 'step14_2_packaged_ip_tb_summary.csv');

if ~exist(packageSummaryPath, 'file') || ~exist(catalogSummaryPath, 'file') || ...
        ~exist(xsimSummaryPath, 'file') || ~exist(synthSummaryPath, 'file')
    writeBlockedKeypoints(cmpDir, 'run_vivado_package_and_validation_then_rerun_matlab', step14_1_keypoints);
    fprintf('Step14.2 blocked: run Vivado package/validation wrappers, then rerun MATLAB.\n');
    return;
end

if exist(packagedOutputPath, 'file') && exist(packagedTbSummaryPath, 'file')
    compare_step14_2_packaged_ip_outputs();
else
    writeCompareUnavailable(cmpDir, 'packaged_ip_output_or_tb_summary_missing');
end

packageSummary = readKeyValueCsv(packageSummaryPath);
catalogSummary = readKeyValueCsv(catalogSummaryPath);
xsimSummary = readKeyValueCsv(xsimSummaryPath);
synthSummary = readKeyValueCsv(synthSummaryPath);
compareSummary = readMaybe(fullfile(cmpDir, 'step14_2_packaged_ip_compare_summary.csv'));

ipPackagePass = isTrueMetric(packageSummary, 'ip_package_integrity_pass_flag');
sAxisPass = isTrueMetric(packageSummary, 's_axis_y_recognized_flag');
mAxisPass = isTrueMetric(packageSummary, 'm_axis_z_recognized_flag');
clockPass = isTrueMetric(packageSummary, 'axis_clock_association_pass_flag');
resetPass = isTrueMetric(packageSummary, 'reset_polarity_pass_flag');
absolutePathPass = isTrueMetric(packageSummary, 'absolute_path_scan_pass_flag');
catalogPass = isTrueMetric(catalogSummary, 'ip_catalog_registration_pass_flag');
createIpPass = isTrueMetric(catalogSummary, 'create_ip_pass_flag');
generateTargetPass = isTrueMetric(catalogSummary, 'generate_target_pass_flag');
xsimPass = isTrueMetric(xsimSummary, 'packaged_ip_xsim_pass_flag');
comparePass = isTrueMetric(compareSummary, 'packaged_ip_compare_pass_flag');
synthPass = strcmpi(getMetric(synthSummary, 'packaged_ip_ooc_synthesis_status', 'fail'), 'pass');
wMemoryPass = isTrueMetric(synthSummary, 'w_memory_inferred_flag');
timingPass = isTrueMetric(synthSummary, 'timing_200MHz_met_flag');

step14_2_pass = ipPackagePass && sAxisPass && mAxisPass && clockPass && ...
    resetPass && absolutePathPass && catalogPass && createIpPass && ...
    generateTargetPass && xsimPass && comparePass && synthPass && wMemoryPass;
proceedReferenceBd = step14_2_pass && timingPass;
customIpPackaged = ipPackagePass && catalogPass;

blocker = firstBlocker(packageSummary, catalogSummary, xsimSummary, synthSummary, compareSummary, step14_2_pass);

keypoints = {
    'step14_1_axis_system_pass_flag', boolStr(isTrueMetric(step14_1_keypoints, 'step14_1_axis_system_pass_flag'));
    'ip_vlnv', 'user.org:radar:dbf_axis:1.0';
    'component_xml_created', getMetric(packageSummary, 'component_xml_created', 'false');
    'ip_package_integrity_pass_flag', boolStr(ipPackagePass);
    's_axis_y_recognized_flag', boolStr(sAxisPass);
    'm_axis_z_recognized_flag', boolStr(mAxisPass);
    'axis_clock_association_pass_flag', boolStr(clockPass);
    'reset_polarity_pass_flag', boolStr(resetPass);
    'packaged_w_mem_file_count', getMetric(packageSummary, 'packaged_w_mem_file_count', '0');
    'absolute_path_scan_pass_flag', boolStr(absolutePathPass);
    'ip_catalog_registration_pass_flag', boolStr(catalogPass);
    'create_ip_pass_flag', boolStr(createIpPass);
    'generate_target_pass_flag', boolStr(generateTargetPass);
    'packaged_ip_xsim_pass_flag', boolStr(xsimPass);
    'packaged_ip_output_match_flag', getMetric(compareSummary, 'packaged_ip_output_match_flag', 'false');
    'packaged_ip_ooc_synthesis_status', getMetric(synthSummary, 'packaged_ip_ooc_synthesis_status', 'fail');
    'w_memory_inferred_flag', boolStr(wMemoryPass);
    'packaged_ip_LUT', getMetric(synthSummary, 'LUT', '0');
    'packaged_ip_FF', getMetric(synthSummary, 'FF', '0');
    'packaged_ip_DSP', getMetric(synthSummary, 'DSP', '0');
    'packaged_ip_BRAM18', getMetric(synthSummary, 'BRAM18', '0');
    'packaged_ip_BRAM36', getMetric(synthSummary, 'BRAM36', '0');
    'packaged_ip_URAM', getMetric(synthSummary, 'URAM', '0');
    'packaged_ip_distributed_RAM', getMetric(synthSummary, 'distributed_RAM', '0');
    'packaged_ip_WNS_ns', getMetric(synthSummary, 'WNS_ns', 'NA');
    'timing_200MHz_met_flag', boolStr(timingPass);
    'step14_2_custom_ip_pass_flag', boolStr(step14_2_pass);
    'proceed_to_reference_bd_design_flag', boolStr(proceedReferenceBd);
    'proceed_to_target_board_dma_flag', 'false';
    'proceed_to_board_validation_flag', 'false';
    'proceed_to_full_fpga_backend_flag', 'false';
    'custom_ip_packaged_flag', boolStr(customIpPackaged);
    'formal_result_claimed', 'false';
    'block_design_created_flag', 'false';
    'bitstream_generated_flag', 'false';
    'blocker_if_any', blocker;
};
writeKeyValueCsv(fullfile(cmpDir, 'step14_2_custom_ip_keypoints.csv'), keypoints);

fprintf('Step14.2 custom IP status: %s\n', ternary(step14_2_pass, 'pass', 'fail'));

end

function writeBlockedKeypoints(cmpDir, blocker, step14_1_keypoints)
if ~exist(cmpDir, 'dir')
    mkdir(cmpDir);
end
keypoints = {
    'step14_1_axis_system_pass_flag', boolStr(isTrueMetric(step14_1_keypoints, 'step14_1_axis_system_pass_flag'));
    'ip_vlnv', 'user.org:radar:dbf_axis:1.0';
    'component_xml_created', 'false';
    'ip_package_integrity_pass_flag', 'false';
    's_axis_y_recognized_flag', 'false';
    'm_axis_z_recognized_flag', 'false';
    'axis_clock_association_pass_flag', 'false';
    'reset_polarity_pass_flag', 'false';
    'packaged_w_mem_file_count', '0';
    'absolute_path_scan_pass_flag', 'false';
    'ip_catalog_registration_pass_flag', 'false';
    'create_ip_pass_flag', 'false';
    'generate_target_pass_flag', 'false';
    'packaged_ip_xsim_pass_flag', 'false';
    'packaged_ip_output_match_flag', 'false';
    'packaged_ip_ooc_synthesis_status', 'not_run';
    'w_memory_inferred_flag', 'false';
    'packaged_ip_LUT', '0';
    'packaged_ip_FF', '0';
    'packaged_ip_DSP', '0';
    'packaged_ip_BRAM18', '0';
    'packaged_ip_BRAM36', '0';
    'packaged_ip_URAM', '0';
    'packaged_ip_distributed_RAM', '0';
    'packaged_ip_WNS_ns', 'NA';
    'timing_200MHz_met_flag', 'false';
    'step14_2_custom_ip_pass_flag', 'false';
    'proceed_to_reference_bd_design_flag', 'false';
    'proceed_to_target_board_dma_flag', 'false';
    'proceed_to_board_validation_flag', 'false';
    'proceed_to_full_fpga_backend_flag', 'false';
    'custom_ip_packaged_flag', 'false';
    'formal_result_claimed', 'false';
    'block_design_created_flag', 'false';
    'bitstream_generated_flag', 'false';
    'blocker_if_any', blocker;
};
writeKeyValueCsv(fullfile(cmpDir, 'step14_2_custom_ip_keypoints.csv'), keypoints);
writeCompareUnavailable(cmpDir, blocker);
end

function writeCompareUnavailable(cmpDir, blocker)
pairs = {
    'comparison_status', 'blocked';
    'expected_rows', '14';
    'actual_rows', '0';
    'matched_rows', '0';
    'missing_count', '14';
    'duplicate_count', '0';
    'tdata_mismatch_count', '0';
    'z_value_mismatch_count', '0';
    'flag_mismatch_count', '0';
    'tlast_mismatch_count', '0';
    'beam_order_mismatch_count', '0';
    'packaged_ip_output_match_flag', 'false';
    'packaged_ip_tb_pass_flag', 'false';
    'packaged_ip_compare_pass_flag', 'false';
    'formal_result_claimed', 'false';
    'blocker_if_any', blocker;
};
writeKeyValueCsv(fullfile(cmpDir, 'step14_2_packaged_ip_compare_summary.csv'), pairs);
end

function blocker = firstBlocker(packageSummary, catalogSummary, xsimSummary, synthSummary, compareSummary, stepPass)
if stepPass
    blocker = '';
    return;
end
keys = {'blocker_if_any', 'blocker'};
maps = {packageSummary, catalogSummary, xsimSummary, synthSummary, compareSummary};
for m = 1:numel(maps)
    for k = 1:numel(keys)
        val = getMetric(maps{m}, keys{k}, '');
        if ~isempty(val) && ~strcmpi(val, 'none')
            blocker = val;
            return;
        end
    end
end
blocker = 'step14_2_validation_failed';
end

function meta = readMaybe(filePath)
if exist(filePath, 'file')
    meta = readKeyValueCsv(filePath);
else
    meta = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
end

function meta = readKeyValueCsv(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('Step14.2:FileOpen', 'Cannot open %s.', filePath);
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

function val = getMetric(meta, key, defaultVal)
if isKey(meta, key)
    val = meta(key);
else
    val = defaultVal;
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
    error('Step14.2:FileOpen', 'Cannot open %s for writing.', filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,value\n');
for k = 1:size(pairs, 1)
    fprintf(fid, '%s,%s\n', pairs{k,1}, pairs{k,2});
end
end
