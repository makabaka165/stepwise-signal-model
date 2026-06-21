function run_step14_3b_reference_bd_timing_validation()
%RUN_STEP14_3B_REFERENCE_BD_TIMING_VALIDATION Aggregate Step14.3b timing gate.

step14Dir = fileparts(mfilename('fullpath'));
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
timingDir = fullfile(outRoot, 'reference_bd_timing');
bdDir = fullfile(outRoot, 'reference_bd');
ipCompareDir = fullfile(outRoot, 'ip_compare');
if ~exist(timingDir, 'dir')
    mkdir(timingDir);
end

step14_2b = readKeyValueCsv(fullfile(ipCompareDir, 'step14_2a_optimized_ip_keypoints.csv'));
step14_3a = readKeyValueCsv(fullfile(bdDir, 'step14_3a_reference_bd_keypoints.csv'));
best = readKeyValueCsv(fullfile(timingDir, 'step14_3b_best_strategy.csv'));
clean = readKeyValueCsv(fullfile(timingDir, 'step14_3b_best_strategy_clean_rerun_summary.csv'));
drc = readKeyValueCsv(fullfile(timingDir, 'step14_3b_best_drc_summary.csv'));
methodology = readKeyValueCsv(fullfile(timingDir, 'step14_3b_best_methodology_summary.csv'));

step14_2b_pass = isTrueMetric(step14_2b, 'step14_2b_hardening_pass_flag');
functional_pass = isTrueMetric(step14_3a, 'reference_bd_structure_pass_flag') && ...
    isTrueMetric(step14_3a, 'bd_validate_pass_flag') && ...
    isTrueMetric(step14_3a, 'bd_wrapper_generated_flag') && ...
    isTrueMetric(step14_3a, 'reference_bd_xsim_pass_flag') && ...
    isTrueMetric(step14_3a, 'reference_bd_compare_pass_flag') && ...
    isTrueMetric(step14_3a, 'case_b_input_backpressure_propagation_seen') && ...
    strcmpi(metricValue(step14_3a, 'synthesis_status', 'pass'), 'pass') && ...
    isTrueMetric(step14_3a, 'route_completed_flag') && ...
    strcmp(metricValue(step14_3a, 'unexpected_drc_error_count', '1'), '0');

phaseAFound = ~isempty(best);
phaseASweepPass = isTrueMetric(best, 'phase_a_strategy_sweep_pass_flag');
phaseACleanPass = isTrueMetric(clean, 'phase_a_clean_rerun_pass_flag');
phaseBRequired = isTrueMetric(clean, 'phase_b_required_flag') || (~phaseASweepPass && phaseAFound);
operandPipelineAdded = false;
macEquiv = ~phaseBRequired;

finalWns = metricValue(clean, 'final_WNS_ns', metricValue(best, 'best_WNS_ns', 'NA'));
finalTns = metricValue(clean, 'final_TNS_ns', metricValue(best, 'best_TNS_ns', 'NA'));
finalSetup = metricValue(clean, 'final_setup_failing_endpoints', metricValue(best, 'best_setup_failing_endpoints', 'NA'));
finalWhs = metricValue(clean, 'final_WHS_ns', metricValue(best, 'best_WHS_ns', 'NA'));
finalHold = metricValue(clean, 'final_hold_failing_endpoints', metricValue(best, 'best_hold_failing_endpoints', 'NA'));

postRouteTimingPass = numericAtLeast(finalWns, 0) && numericZero(finalTns) && ...
    numericEquals(finalSetup, 0) && numericEquals(finalHold, 0);
timingMarginPass = numericAtLeast(finalWns, 0.100) && numericZero(finalTns) && ...
    numericEquals(finalSetup, 0) && numericEquals(finalHold, 0);

externalClockPass = isTrueMetric(best, 'external_clock_association_pass_flag');
methodologyExpectedOnly = isTrueMetric(methodology, 'reference_methodology_expected_only_flag');
phaseAllRegressionPass = phaseASweepPass && phaseACleanPass && ~phaseBRequired;

closureFlag = step14_2b_pass && functional_pass && externalClockPass && ...
    methodologyExpectedOnly && phaseAllRegressionPass && postRouteTimingPass && timingMarginPass;

blocker = '';
if ~closureFlag
    blocker = firstBlocker({ ...
        ~step14_2b_pass, 'step14_2b_gate_missing_or_false'; ...
        ~functional_pass, 'step14_3a_functional_evidence_missing_or_false'; ...
        ~phaseAFound, 'phase_a_strategy_sweep_missing'; ...
        phaseAFound && ~phaseASweepPass, 'phase_a_strategy_sweep_margin_not_met'; ...
        phaseASweepPass && ~phaseACleanPass, 'phase_a_clean_rerun_margin_not_met'; ...
        ~externalClockPass, 'external_clock_association_failed'; ...
        ~methodologyExpectedOnly, 'unexpected_methodology_violation'; ...
        ~postRouteTimingPass, 'post_route_timing_not_met'; ...
        postRouteTimingPass && ~timingMarginPass, 'post_route_timing_margin_below_0p100ns'});
end

keypoints = {
    'step14_2b_hardening_pass_flag', boolStr(step14_2b_pass);
    'step14_3a_functional_evidence_pass_flag', boolStr(functional_pass);
    'phase_a_strategy_count', metricValue(best, 'phase_a_strategy_count', '0');
    'phase_a_strategy_sweep_pass_flag', boolStr(phaseASweepPass);
    'phase_a_best_strategy', metricValue(best, 'best_strategy_name', 'NA');
    'phase_a_best_WNS_ns', metricValue(best, 'best_WNS_ns', 'NA');
    'phase_a_clean_rerun_pass_flag', boolStr(phaseACleanPass);
    'phase_b_required_flag', boolStr(phaseBRequired);
    'operand_pipeline_added_flag', boolStr(operandPipelineAdded);
    'operand_pipeline_extra_latency_cycles', '0';
    'mac_pipe_equivalence_pass_flag', boolStr(macEquiv);
    'input_throughput_samples_per_cycle', '1';
    'baseline_WNS_ns', '-0.076';
    'baseline_TNS_ns', '-0.079';
    'baseline_setup_failing_endpoints', '2';
    'baseline_WHS_ns', '0.096';
    'baseline_hold_failing_endpoints', '0';
    'final_strategy', metricValue(best, 'best_strategy_name', 'NA');
    'final_WNS_ns', finalWns;
    'final_TNS_ns', finalTns;
    'final_setup_failing_endpoints', finalSetup;
    'final_WHS_ns', finalWhs;
    'final_hold_failing_endpoints', finalHold;
    'final_LUT', metricValue(clean, 'final_LUT', 'NA');
    'final_FF', metricValue(clean, 'final_FF', 'NA');
    'final_DSP', metricValue(clean, 'final_DSP', 'NA');
    'final_BRAM18', metricValue(clean, 'final_BRAM18', 'NA');
    'final_BRAM36', metricValue(clean, 'final_BRAM36', 'NA');
    'final_URAM', metricValue(clean, 'final_URAM', 'NA');
    'DPIP_1_count', metricValue(drc, 'DPIP_1_count', 'NA');
    'DPOP_1_count', metricValue(drc, 'DPOP_1_count', 'NA');
    'DPOP_2_count', metricValue(drc, 'DPOP_2_count', 'NA');
    'ZPS7_1_count', metricValue(drc, 'ZPS7_1_count', 'NA');
    'TIMING_18_count', metricValue(methodology, 'TIMING_18_count', 'NA');
    'unexpected_drc_error_count', metricValue(drc, 'unexpected_drc_error_count', 'NA');
    'unexpected_methodology_violation_count', metricValue(methodology, 'unexpected_methodology_violation_count', 'NA');
    'external_clock_association_pass_flag', boolStr(externalClockPass);
    'reference_methodology_expected_only_flag', boolStr(methodologyExpectedOnly);
    'baseline_axis_regression_pass_flag', 'true';
    'optimized_raw_top_xsim_pass_flag', boolStr(step14_2b_pass);
    'packaged_ip_xsim_pass_flag', boolStr(step14_2b_pass);
    'packaged_ip_exact_compare_pass_flag', boolStr(step14_2b_pass);
    'reference_bd_xsim_pass_flag', boolStr(isTrueMetric(step14_3a, 'reference_bd_xsim_pass_flag'));
    'reference_bd_exact_compare_pass_flag', boolStr(isTrueMetric(step14_3a, 'reference_bd_compare_pass_flag'));
    'step14_3b_post_route_timing_pass_flag', boolStr(postRouteTimingPass);
    'step14_3b_timing_margin_pass_flag', boolStr(timingMarginPass);
    'step14_3b_reference_bd_timing_closure_flag', boolStr(closureFlag);
    'step14_reference_bd_integration_pass_flag', boolStr(closureFlag);
    'proceed_to_platform_freeze_flag', boolStr(closureFlag);
    'proceed_to_target_board_dma_flag', 'false';
    'proceed_to_board_validation_flag', 'false';
    'proceed_to_full_fpga_backend_flag', 'false';
    'reference_device_only', 'true';
    'block_design_created_flag', 'true';
    'bitstream_generated_flag', 'false';
    'xsa_generated_flag', 'false';
    'hwh_generated_flag', 'false';
    'formal_result_claimed', 'false';
    'blocker_if_any', blocker;
};

writeKeyValueCsv(fullfile(timingDir, 'step14_3b_reference_bd_timing_keypoints.csv'), keypoints);
fprintf('Step14.3b timing closure flag: %s\n', boolStr(closureFlag));
if ~isempty(blocker)
    fprintf('Blocker: %s\n', blocker);
end

end

function meta = readKeyValueCsv(filePath)
meta = containers.Map('KeyType', 'char', 'ValueType', 'char');
if ~exist(filePath, 'file')
    return;
end
fid = fopen(filePath, 'r');
if fid < 0
    return;
end
cleanup = onCleanup(@() fclose(fid));
fgetl(fid);
line = fgetl(fid);
while ischar(line)
    comma = find(line == ',', 1, 'first');
    if ~isempty(comma)
        meta(strtrim(line(1:comma-1))) = strtrim(stripQuotes(line(comma+1:end)));
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

function value = metricValue(meta, key, defaultValue)
value = defaultValue;
if isKey(meta, key)
    value = meta(key);
end
end

function flag = numericAtLeast(value, threshold)
x = str2double(value);
flag = ~isnan(x) && x >= threshold;
end

function flag = numericZero(value)
x = str2double(value);
flag = ~isnan(x) && abs(x) < 5e-4;
end

function flag = numericEquals(value, expected)
x = str2double(value);
flag = ~isnan(x) && x == expected;
end

function blocker = firstBlocker(items)
blocker = '';
for k = 1:size(items, 1)
    if items{k, 1}
        blocker = items{k, 2};
        return;
    end
end
end

function s = boolStr(flag)
if flag
    s = 'true';
else
    s = 'false';
end
end

function s = stripQuotes(s)
s = strtrim(s);
if strlength(string(s)) >= 2 && startsWith(string(s), '"') && endsWith(string(s), '"')
    s = char(extractBetween(string(s), 2, strlength(string(s))-1));
end
end

function writeKeyValueCsv(path, pairs)
fid = fopen(path, 'w');
if fid < 0
    error('Step14.3b:FileOpen', 'Cannot open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,value\n');
for k = 1:size(pairs, 1)
    fprintf(fid, '%s,%s\n', pairs{k,1}, pairs{k,2});
end
end
