function run_step14_2a_timing_memory_optimization()
%RUN_STEP14_2A_TIMING_MEMORY_OPTIMIZATION Aggregate Step14.2a validation results.
% This entry reads existing Vivado/XSim artifacts and does not invoke Vivado.

step14Dir = fileparts(mfilename('fullpath'));
matlabVectorDir = fullfile(step14Dir, 'matlab_vectors');
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
axisCompareDir = fullfile(outRoot, 'axis_compare');
axisSimDir = fullfile(outRoot, 'axis_sim');
splitDir = fullfile(outRoot, 'axis_vectors', 'w_split');
optSimDir = fullfile(outRoot, 'axis_opt_sim');
hardeningDir = fullfile(outRoot, 'hardening');
pkgDir = fullfile(outRoot, 'ip_package');
xsimDir = fullfile(outRoot, 'ip_xsim');
synthDir = fullfile(outRoot, 'ip_synth');
cmpDir = fullfile(outRoot, 'ip_compare');
if ~exist(cmpDir, 'dir')
    mkdir(cmpDir);
end

addpath(matlabVectorDir);

step14_1 = readMaybe(fullfile(axisCompareDir, 'step14_1_axis_keypoints.csv'));
baselineTbSummary = readMaybe(fullfile(axisSimDir, 'step14_1_axis_tb_summary.csv'));
splitSummary = readMaybe(fullfile(splitDir, 'step14_2a_w_split_summary.csv'));
optRawSummary = readMaybe(fullfile(optSimDir, 'step14_2a_opt_axis_tb_summary.csv'));
wProviderSummary = readMaybe(fullfile(hardeningDir, 'step14_2b_w_provider_boundary_summary.csv'));
quantizerSummary = readMaybe(fullfile(hardeningDir, 'step14_2b_quantizer_equiv_summary.csv'));
packageSummary = readMaybe(fullfile(pkgDir, 'step14_2_ip_package_summary.csv'));
catalogSummary = readMaybe(fullfile(pkgDir, 'step14_2_ip_catalog_summary.csv'));
xsimSummary = readMaybe(fullfile(xsimDir, 'step14_2_packaged_ip_xsim_summary.csv'));
packagedTbSummary = readMaybe(fullfile(xsimDir, 'step14_2_packaged_ip_tb_summary.csv'));
oocSummary = readMaybe(fullfile(synthDir, 'step14_2a_optimized_ip_ooc_summary.csv'));
drcSummary = readMaybe(fullfile(synthDir, 'step14_2a_drc_warning_summary.csv'));
resourceSummary = readMaybe(fullfile(synthDir, 'step14_2a_resource_comparison.csv'));

packagedOutputPath = fullfile(xsimDir, 'step14_2_packaged_ip_output.csv');
packagedTbSummaryPath = fullfile(xsimDir, 'step14_2_packaged_ip_tb_summary.csv');
if exist(packagedOutputPath, 'file') && exist(packagedTbSummaryPath, 'file')
    compare_step14_2a_optimized_ip_outputs();
else
    writeCompareBlocked(cmpDir, 'packaged_ip_output_or_tb_summary_missing');
end
compareSummary = readMaybe(fullfile(cmpDir, 'step14_2a_optimized_ip_compare_summary.csv'));

step14_1_pass = isTrueMetric(step14_1, 'step14_1_axis_system_pass_flag');
baselineStatusBusyPass = isTrueMetric(baselineTbSummary, 'status_busy_semantics_pass');
wSplitPass = isTrueMetric(splitSummary, 'w_split_vector_pass_flag');
optRawPass = isTrueMetric(optRawSummary, 'optimized_raw_top_xsim_pass_flag');
optStatusBusyPass = isTrueMetric(optRawSummary, 'status_busy_semantics_pass');
wProviderBoundaryPass = isTrueMetric(wProviderSummary, 'w_provider_boundary_pass');
quantizerEquivPass = isTrueMetric(quantizerSummary, 'quantizer_pipe_equivalence_pass');
packagePass = isTrueMetric(packageSummary, 'ip_package_integrity_pass_flag');
packageContentPass = isTrueMetric(packageSummary, 'package_content_integrity_pass_flag');
packageNonemptyPass = isTrueMetric(packageSummary, 'package_nonempty_file_check_pass_flag');
packageHashPass = isTrueMetric(packageSummary, 'package_source_packaged_hash_match_flag');
catalogPass = isTrueMetric(catalogSummary, 'ip_catalog_registration_pass_flag');
createPass = isTrueMetric(catalogSummary, 'create_ip_pass_flag');
generatePass = isTrueMetric(catalogSummary, 'generate_target_pass_flag');
packagedXsimPass = isTrueMetric(xsimSummary, 'packaged_ip_xsim_pass_flag');
packagedStatusBusyPass = isTrueMetric(packagedTbSummary, 'status_busy_semantics_pass');
packagedOutputMatch = isTrueMetric(compareSummary, 'packaged_ip_output_match_flag');
packagedComparePass = isTrueMetric(compareSummary, 'packaged_ip_compare_pass_flag');
drcParserConsistencyPass = isTrueMetric(drcSummary, 'drc_parser_consistency_pass_flag');
synthPass = strcmpi(getMetric(oocSummary, 'packaged_ip_ooc_synthesis_status', 'fail'), 'pass');
wMemoryInferred = isTrueMetric(oocSummary, 'w_memory_inferred_flag');
wMemoryResourcePass = isTrueMetric(oocSummary, 'w_memory_resource_optimization_pass_flag');
timingPass = isTrueMetric(oocSummary, 'timing_200MHz_met_flag');
timingAdvertisedPass = isTrueMetric(oocSummary, 'timing_validates_advertised_clock_flag');
customIpPackaged = packagePass && catalogPass;
statusBusySemanticsPass = baselineStatusBusyPass && optStatusBusyPass && packagedStatusBusyPass;
baselineAxisRegressionPass = step14_1_pass && baselineStatusBusyPass;
packagedIpExactComparePass = packagedOutputMatch && packagedComparePass;

step14_2_packaging_functional_pass = packagePass && catalogPass && createPass && ...
    generatePass && packagedXsimPass && packagedComparePass && synthPass && wMemoryInferred;

step14_2a_pass = step14_1_pass && wSplitPass && optRawPass && packagePass && ...
    catalogPass && createPass && generatePass && packagedXsimPass && ...
    packagedOutputMatch && synthPass && wMemoryInferred && ...
    wMemoryResourcePass && timingPass && timingAdvertisedPass;

step14_2b_hardening_pass = statusBusySemanticsPass && wProviderBoundaryPass && ...
    quantizerEquivPass && drcParserConsistencyPass && packageContentPass && ...
    baselineAxisRegressionPass && optRawPass && packagedXsimPass && ...
    packagedIpExactComparePass && timingPass;

blocker = getMetric(oocSummary, 'blocker_if_any', '');
if isempty(blocker) && ~wMemoryResourcePass
    blocker = 'w_rom_bram36_equivalent_above_16';
end
if isempty(blocker) && ~timingPass
    blocker = 'timing_200MHz_not_met';
end
if isempty(blocker) && ~step14_2a_pass
    blocker = 'step14_2a_validation_failed';
end
if isempty(blocker) && ~step14_2b_hardening_pass
    blocker = 'step14_2b_hardening_validation_failed';
end

timingFollowup = 'none';
if ~timingPass
    timingFollowup = 'keep_advertised_200MHz_and_continue_RTL_timing_closure_before_reference_BD';
end

keypoints = {
    'step14_1_axis_system_pass_flag', boolStr(step14_1_pass);
    'step14_2_packaging_functional_pass_flag', boolStr(step14_2_packaging_functional_pass);
    'status_busy_semantics_pass', boolStr(statusBusySemanticsPass);
    'baseline_status_busy_semantics_pass', boolStr(baselineStatusBusyPass);
    'optimized_status_busy_semantics_pass', boolStr(optStatusBusyPass);
    'packaged_status_busy_semantics_pass', boolStr(packagedStatusBusyPass);
    'baseline_axis_regression_pass', boolStr(baselineAxisRegressionPass);
    'w_split_vector_pass_flag', boolStr(wSplitPass);
    'w_split_reconstruction_match_flag', getMetric(splitSummary, 'w_split_reconstruction_match_flag', 'false');
    'w_provider_boundary_pass', boolStr(wProviderBoundaryPass);
    'quantizer_pipe_equivalence_pass', boolStr(quantizerEquivPass);
    'optimized_raw_top_xsim_pass_flag', boolStr(optRawPass);
    'packaged_ip_xsim_pass_flag', boolStr(packagedXsimPass);
    'packaged_ip_output_match_flag', boolStr(packagedOutputMatch);
    'packaged_ip_exact_compare_pass', boolStr(packagedIpExactComparePass);
    'expected_rows', getMetric(compareSummary, 'expected_rows', '0');
    'actual_rows', getMetric(compareSummary, 'actual_rows', '0');
    'matched_rows', getMetric(compareSummary, 'matched_rows', '0');
    'old_BRAM36_equiv', '28';
    'new_BRAM18', getMetric(oocSummary, 'BRAM18', '0');
    'new_BRAM36', getMetric(oocSummary, 'BRAM36', '0');
    'new_BRAM36_equiv', getMetric(oocSummary, 'BRAM36_equiv', getMetric(resourceSummary, 'new_BRAM36_equiv', '0'));
    'w_memory_inferred_flag', boolStr(wMemoryInferred);
    'w_memory_resource_optimization_pass_flag', boolStr(wMemoryResourcePass);
    'old_WNS_ns', '-8.586';
    'new_WNS_ns', getMetric(oocSummary, 'WNS_ns', 'NA');
    'new_TNS_ns', getMetric(oocSummary, 'TNS_ns', 'NA');
    'new_failing_endpoints', getMetric(oocSummary, 'failing_endpoints', '0');
    'timing_200MHz_met_flag', boolStr(timingPass);
    'advertised_aclk_Hz', '200000000';
    'advertised_clock_MHz', '200';
    'timing_validates_advertised_clock_flag', boolStr(timingAdvertisedPass);
    'old_DSP', '28';
    'new_DSP', getMetric(oocSummary, 'DSP', '0');
    'old_LUT', '3594';
    'new_LUT', getMetric(oocSummary, 'LUT', '0');
    'old_FF', '1810';
    'new_FF', getMetric(oocSummary, 'FF', '0');
    'DPIP_1_count', getMetric(drcSummary, 'DPIP_1_count', '0');
    'DPOP_1_count', getMetric(drcSummary, 'DPOP_1_count', '0');
    'DPOP_2_count', getMetric(drcSummary, 'DPOP_2_count', '0');
    'ZPS7_1_count', getMetric(drcSummary, 'ZPS7_1_count', '0');
    'drc_parser_consistency_pass_flag', boolStr(drcParserConsistencyPass);
    'package_content_integrity_pass_flag', boolStr(packageContentPass);
    'package_nonempty_file_check_pass_flag', boolStr(packageNonemptyPass);
    'package_source_packaged_hash_match_flag', boolStr(packageHashPass);
    'source_base_commit', getMetric(packageSummary, 'source_base_commit', 'unavailable');
    'source_worktree_dirty', getMetric(packageSummary, 'source_worktree_dirty', 'true');
    'step14_2a_optimization_pass_flag', boolStr(step14_2a_pass);
    'step14_2b_hardening_pass_flag', boolStr(step14_2b_hardening_pass);
    'proceed_to_reference_bd_design_flag', boolStr(step14_2b_hardening_pass);
    'proceed_to_target_board_dma_flag', 'false';
    'proceed_to_board_validation_flag', 'false';
    'proceed_to_full_fpga_backend_flag', 'false';
    'custom_ip_packaged_flag', boolStr(customIpPackaged);
    'formal_result_claimed', 'false';
    'block_design_created_flag', 'false';
    'bitstream_generated_flag', 'false';
    'xsa_generated_flag', 'false';
    'hwh_generated_flag', 'false';
    'timing_blocker_or_followup', timingFollowup;
    'blocker_if_any', blocker;
};
writeKeyValueCsv(fullfile(cmpDir, 'step14_2a_optimized_ip_keypoints.csv'), keypoints);

fprintf('Step14.2a optimization status: %s\n', ternary(step14_2a_pass, 'pass', 'fail'));

end

function writeCompareBlocked(cmpDir, blocker)
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
writeKeyValueCsv(fullfile(cmpDir, 'step14_2a_optimized_ip_compare_summary.csv'), pairs);
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
    error('Step14.2a:FileOpen', 'Cannot open %s for writing.', filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,value\n');
for k = 1:size(pairs, 1)
    fprintf(fid, '%s,%s\n', pairs{k,1}, pairs{k,2});
end
end
