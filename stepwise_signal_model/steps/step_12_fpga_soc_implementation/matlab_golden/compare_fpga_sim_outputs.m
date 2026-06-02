% Compare Step12 FPGA simulation outputs against MATLAB golden CSV files.
% Usage:
%   compare_fpga_sim_outputs
% Optional simulator CSV files should be placed in test_vectors_small/ with
% names ending in _sim.csv and matching the golden table columns.

script_dir = fileparts(mfilename('fullpath'));
vec_dir = fullfile(script_dir, 'test_vectors_small');

if ~exist(vec_dir, 'dir')
    error('Missing vector directory. Run generate_fpga_test_vectors first.');
end

checks = {
    'column_selector_expected.csv', 'column_selector_sim.csv';
    'y_work_packer_expected.csv', 'y_work_packer_sim.csv';
    'projection_score_expected.csv', 'projection_score_sim.csv'
};

all_pass = true;
for i = 1:size(checks, 1)
    golden_path = fullfile(vec_dir, checks{i, 1});
    sim_path = fullfile(vec_dir, checks{i, 2});
    if ~exist(golden_path, 'file')
        error('Missing golden file: %s', golden_path);
    end
    if ~exist(sim_path, 'file')
        fprintf('SKIP %s: simulator output not found\n', checks{i, 2});
        continue;
    end

    golden_tbl = readtable(golden_path);
    sim_tbl = readtable(sim_path);
    pass = isequal(golden_tbl, sim_tbl);
    fprintf('%s: %s\n', checks{i, 2}, ternary_local(pass, 'PASS', 'FAIL'));
    all_pass = all_pass && pass;
end

if all_pass
    fprintf('PASS Step12 MATLAB golden comparison\n');
else
    fprintf('FAIL Step12 MATLAB golden comparison\n');
end

function out = ternary_local(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
