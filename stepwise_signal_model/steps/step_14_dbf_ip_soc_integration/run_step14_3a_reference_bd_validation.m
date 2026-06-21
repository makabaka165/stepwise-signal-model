function run_step14_3a_reference_bd_validation()
%RUN_STEP14_3A_REFERENCE_BD_VALIDATION Summarize Step14.3a Reference BD gate.

step14Dir = fileparts(mfilename('fullpath'));
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
bdDir = fullfile(outRoot, 'reference_bd');
ipCompareDir = fullfile(outRoot, 'ip_compare');
if ~exist(bdDir, 'dir')
    mkdir(bdDir);
end

step14_2b = readKeyValueCsv(fullfile(ipCompareDir, 'step14_2a_optimized_ip_keypoints.csv'));
step14_2b_hardening_pass = isTrueMetric(step14_2b, 'step14_2b_hardening_pass_flag');
step14_2b_reference_gate = isTrueMetric(step14_2b, 'proceed_to_reference_bd_design_flag');

structurePath = fullfile(bdDir, 'step14_3a_bd_structure_summary.csv');
xsimPath = fullfile(bdDir, 'step14_3a_bd_xsim_summary.csv');
synthPath = fullfile(bdDir, 'step14_3a_bd_synth_summary.csv');
implPath = fullfile(bdDir, 'step14_3a_bd_implementation_summary.csv');
drcPath = fullfile(bdDir, 'step14_3a_bd_drc_summary.csv');
comparePath = fullfile(bdDir, 'step14_3a_reference_bd_compare_summary.csv');

requiredVivadoOutputs = {structurePath, xsimPath, synthPath, implPath, drcPath, ...
    fullfile(bdDir, 'step14_3a_reference_bd_output.csv'), ...
    fullfile(bdDir, 'step14_3a_reference_bd_stress_output.csv'), ...
    fullfile(bdDir, 'step14_3a_reference_bd_tb_summary.csv')};

blocker = '';
if any(~cellfun(@(p) exist(p, 'file') == 2, requiredVivadoOutputs))
    blocker = 'run_reference_bd_vivado_flow_then_rerun_matlab';
else
    addpath(fullfile(step14Dir, 'matlab_vectors'));
    compare_step14_3a_reference_bd_outputs();
end

structure = readKeyValueCsv(structurePath);
xsim = readKeyValueCsv(xsimPath);
synth = readKeyValueCsv(synthPath);
impl = readKeyValueCsv(implPath);
drc = readKeyValueCsv(drcPath);
compare = readKeyValueCsv(comparePath);
tb = readKeyValueCsv(fullfile(bdDir, 'step14_3a_reference_bd_tb_summary.csv'));

reference_bd_structure_pass = isTrueMetric(structure, 'reference_bd_structure_pass_flag');
bd_validate_pass = isTrueMetric(structure, 'bd_validate_pass_flag');
bd_wrapper_generated = isTrueMetric(structure, 'bd_wrapper_generated_flag');
reference_bd_xsim_pass = isTrueMetric(xsim, 'reference_bd_xsim_pass_flag');
reference_bd_compare_pass = isTrueMetric(compare, 'reference_bd_compare_pass_flag');
case_b_backpressure_seen = isTrueMetric(tb, 'case_b_input_backpressure_propagation_seen');
synthesisPass = strcmpi(metricValue(synth, 'synthesis_status', 'not_run'), 'pass');
routeCompleted = isTrueMetric(impl, 'route_completed_flag');
timingMet = isTrueMetric(impl, 'post_route_timing_200MHz_met_flag');
unexpectedDrc = str2double(metricValue(drc, 'unexpected_drc_error_count', 'NaN'));
unexpectedDrcOk = ~isnan(unexpectedDrc) && unexpectedDrc == 0;

step14_3a_pass = step14_2b_hardening_pass && step14_2b_reference_gate && ...
    reference_bd_structure_pass && bd_validate_pass && bd_wrapper_generated && ...
    reference_bd_xsim_pass && reference_bd_compare_pass && ...
    case_b_backpressure_seen && synthesisPass && routeCompleted && timingMet && ...
    unexpectedDrcOk;

if ~step14_3a_pass && isempty(blocker)
    blocker = firstBlocker(structure, xsim, synth, impl, drc, compare);
end

keypoints = {
    'step14_2b_hardening_pass_flag', boolStr(step14_2b_hardening_pass);
    'proceed_to_reference_bd_design_flag_from_step14_2b', boolStr(step14_2b_reference_gate);
    'custom_ip_vlnv', metricValue(structure, 'ip_vlnv', 'user.org:radar:dbf_axis:1.0');
    'fpga_part', metricValue(structure, 'fpga_part', 'NA');
    'fpga_part_source', metricValue(structure, 'fpga_part_source', 'NA');
    'reference_device_only', 'true';
    'clock_MHz', metricValue(structure, 'clock_MHz', 'NA');
    'clock_period_ns', metricValue(impl, 'clock_period_ns', 'NA');
    'bd_name', metricValue(structure, 'bd_name', 'dbf_reference_bd');
    'wrapper_top', metricValue(structure, 'wrapper_top', 'dbf_reference_bd_wrapper');
    'reference_bd_created_flag', boolStr(reference_bd_structure_pass);
    'reference_bd_structure_pass_flag', boolStr(reference_bd_structure_pass);
    'bd_validate_pass_flag', boolStr(bd_validate_pass);
    'bd_wrapper_generated_flag', boolStr(bd_wrapper_generated);
    'input_fifo_depth', '64';
    'input_fifo_tdata_bits', '32';
    'output_fifo_depth', '16';
    'output_fifo_tdata_bits', '64';
    'common_clock_flag', 'true';
    'reset_active_low_flag', 'true';
    'reference_bd_xsim_pass_flag', boolStr(reference_bd_xsim_pass);
    'case_a_pass_flag', boolStr(isTrueMetric(compare, 'case_a_output_match_flag'));
    'case_b_pass_flag', boolStr(isTrueMetric(compare, 'case_b_output_match_flag'));
    'reference_bd_compare_pass_flag', boolStr(reference_bd_compare_pass);
    'case_b_input_backpressure_propagation_seen', boolStr(case_b_backpressure_seen);
    'reference_bd_output_match_flag', boolStr(isTrueMetric(compare, 'reference_bd_compare_pass_flag'));
    'synthesis_status', metricValue(synth, 'synthesis_status', 'not_run');
    'implementation_status', metricValue(impl, 'implementation_status', 'not_run');
    'route_completed_flag', boolStr(routeCompleted);
    'post_route_timing_200MHz_met_flag', boolStr(timingMet);
    'unexpected_drc_error_count', metricValue(drc, 'unexpected_drc_error_count', 'NA');
    'reference_expected_drc_only_flag', metricValue(drc, 'reference_expected_drc_only_flag', 'NA');
    'post_route_LUT', metricValue(impl, 'LUT', 'NA');
    'post_route_FF', metricValue(impl, 'FF', 'NA');
    'post_route_DSP', metricValue(impl, 'DSP', 'NA');
    'post_route_BRAM18', metricValue(impl, 'BRAM18', 'NA');
    'post_route_BRAM36', metricValue(impl, 'BRAM36', 'NA');
    'post_route_URAM', '0';
    'post_route_WNS_ns', metricValue(impl, 'WNS_ns', 'NA');
    'post_route_TNS_ns', metricValue(impl, 'TNS_ns', 'NA');
    'post_route_failing_endpoints', metricValue(impl, 'failing_endpoints', 'NA');
    'post_route_WHS_ns', metricValue(impl, 'WHS_ns', 'NA');
    'post_route_hold_failing_endpoints', metricValue(impl, 'hold_failing_endpoints', 'NA');
    'step14_3a_reference_bd_pass_flag', boolStr(step14_3a_pass);
    'proceed_to_platform_freeze_flag', boolStr(step14_3a_pass);
    'proceed_to_target_board_dma_flag', 'false';
    'proceed_to_board_validation_flag', 'false';
    'proceed_to_full_fpga_backend_flag', 'false';
    'ps_cell_count', '0';
    'dma_cell_count', '0';
    'block_design_created_flag', boolStr(reference_bd_structure_pass);
    'formal_result_claimed', 'false';
    'bitstream_generated_flag', 'false';
    'xsa_generated_flag', 'false';
    'hwh_generated_flag', 'false';
    'blocker_if_any', blocker;
};

writeKeyValueCsv(fullfile(bdDir, 'step14_3a_reference_bd_keypoints.csv'), keypoints);
fprintf('Step14.3a Reference BD pass flag: %s\n', boolStr(step14_3a_pass));
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

function value = metricValue(meta, key, defaultValue)
value = defaultValue;
if isKey(meta, key)
    value = meta(key);
end
end

function blocker = firstBlocker(varargin)
blocker = '';
for k = 1:nargin
    meta = varargin{k};
    if isKey(meta, 'blocker_if_any')
        val = strtrim(meta('blocker_if_any'));
        if ~isempty(val)
            blocker = val;
            return;
        end
    end
end
blocker = 'step14_3a_reference_bd_gate_failed';
end

function s = boolStr(flag)
if flag
    s = 'true';
else
    s = 'false';
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
