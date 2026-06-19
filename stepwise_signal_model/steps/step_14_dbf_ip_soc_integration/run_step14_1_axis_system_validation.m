function run_step14_1_axis_system_validation()
%RUN_STEP14_1_AXIS_SYSTEM_VALIDATION Step14.1 vector and compare entry point.

step14Dir = fileparts(mfilename('fullpath'));
matlabVectorDir = fullfile(step14Dir, 'matlab_vectors');
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
vecDir = fullfile(outRoot, 'axis_vectors');
simDir = fullfile(outRoot, 'axis_sim');

addpath(matlabVectorDir);

fprintf('Step14.1: generating AXI4-Stream vectors from Step13.4 full-N golden files...\n');
generate_step14_1_axis_vectors();

requiredVectors = {
    fullfile(vecDir, 'step14_1_y_axis_tdata.mem');
    fullfile(vecDir, 'step14_1_z_axis_expected.mem');
    fullfile(vecDir, 'step14_1_axis_vector_metadata.csv');
    fullfile(vecDir, 'step14_1_axis_vector_manifest.csv');
};
for k = 1:numel(requiredVectors)
    if ~exist(requiredVectors{k}, 'file')
        error('Step14.1:MissingVector', 'Required vector output missing: %s', requiredVectors{k});
    end
end

axisOutput = fullfile(simDir, 'step14_1_axis_output.csv');
tbSummary = fullfile(simDir, 'step14_1_axis_tb_summary.csv');
if exist(axisOutput, 'file') && exist(tbSummary, 'file')
    fprintf('Step14.1: simulation outputs found; running MATLAB compare...\n');
    compare_step14_1_axis_outputs();
else
    xsimSummary = fullfile(simDir, 'step14_1_axis_xsim_summary.csv');
    if exist(xsimSummary, 'file')
        fprintf('Step14.1: XSim summary found but scoreboard CSV is missing; writing blocked keypoints.\n');
        write_step14_1_blocked_keypoints(step14Dir, 'xsim_unavailable_or_sim_output_missing');
    end
    fprintf('Step14.1 vectors generated.\n');
    fprintf('Run XSim wrapper, then rerun compare.\n');
    fprintf('PowerShell: powershell -ExecutionPolicy Bypass -File sim/run_xsim_step14_1_axis.ps1\n');
    fprintf('CMD: sim\\run_xsim_step14_1_axis.bat\n');
end

end

function write_step14_1_blocked_keypoints(step14Dir, blocker)
outRoot = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration');
cmpDir = fullfile(outRoot, 'axis_compare');
if ~exist(cmpDir, 'dir')
    mkdir(cmpDir);
end

summaryPairs = {
    'comparison_status', 'blocked';
    'blocker', blocker;
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
    'axis_output_match_flag', 'false';
    'axis_tb_pass_flag', 'false';
    'step14_1_axis_system_pass_flag', 'false';
    'formal_result_claimed', 'false';
    'dma_validation_flag', 'false';
    'ps_validation_flag', 'false';
    'board_validation_flag', 'false';
};
write_pairs(fullfile(cmpDir, 'step14_1_axis_compare_summary.csv'), summaryPairs);

keypoints = {
    'step14_1_axis_system_pass_flag', 'false';
    'proceed_to_custom_ip_packaging_flag', 'false';
    'proceed_to_dma_reference_design_flag', 'false';
    'proceed_to_board_validation_flag', 'false';
    'proceed_to_full_fpga_backend_flag', 'false';
    'formal_result_claimed', 'false';
    'dma_validation_flag', 'false';
    'ps_validation_flag', 'false';
    'board_validation_flag', 'false';
    'custom_ip_packaged_flag', 'false';
    'blocker', blocker;
};
write_pairs(fullfile(cmpDir, 'step14_1_axis_keypoints.csv'), keypoints);
end

function write_pairs(filePath, pairs)
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
