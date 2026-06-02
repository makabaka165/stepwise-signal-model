% Generate small FPGA/SoC Step12 golden vectors.
% This script writes CSV files only; it does not save large MAT files.

script_dir = fileparts(mfilename('fullpath'));
out_dir = fullfile(script_dir, 'test_vectors_small');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% shared_center_column_selector
NAZ = 192;
Q = 65;
centers = [0; 1; 96; 191];
selector_rows = [];
for c_idx = 1:numel(centers)
    center_col = centers(c_idx);
    for k = 0:(Q - 1)
        selected_col = mod(center_col + k - floor(Q / 2), NAZ);
        selector_rows = [selector_rows; center_col, k, selected_col]; %#ok<AGROW>
    end
end
selector_tbl = array2table(selector_rows, ...
    'VariableNames', {'center_col', 'local_index', 'selected_col'});
writetable(selector_tbl, fullfile(out_dir, 'column_selector_expected.csv'));

%% y_work_packer
selected_cols = [1, 3, 5];
packer_inputs = [
    1, 0, 11, -11;
    2, 1, 22, -22;
    3, 2, 33, -33;
    5, 3, 55, -55
];
packer_rows = [];
for n = 1:size(packer_inputs, 1)
    col = packer_inputs(n, 1);
    layer = packer_inputs(n, 2);
    sample_i = packer_inputs(n, 3);
    sample_q = packer_inputs(n, 4);
    match_idx = find(selected_cols == col, 1, 'first');
    if isempty(match_idx)
        out_valid = 0;
        local_idx = -1;
    else
        out_valid = 1;
        local_idx = match_idx - 1;
    end
    packer_rows = [packer_rows; col, layer, sample_i, sample_q, out_valid, local_idx]; %#ok<AGROW>
end
packer_tbl = array2table(packer_rows, ...
    'VariableNames', {'column_index', 'layer_index', 'sample_i', 'sample_q', 'out_valid', 'local_col_index'});
writetable(packer_tbl, fullfile(out_dir, 'y_work_packer_expected.csv'));

%% projection_score_core
proj_inputs = [
    1, 2, 3, 4;
    2, -1, 5, 1;
    -3, 1, 2, -2
];
score_i = 0;
score_q = 0;
proj_rows = [];
for n = 1:size(proj_inputs, 1)
    yi = proj_inputs(n, 1);
    yq = proj_inputs(n, 2);
    si = proj_inputs(n, 3);
    sq = proj_inputs(n, 4);
    prod_i = yi * si + yq * sq;
    prod_q = yq * si - yi * sq;
    score_i = score_i + prod_i;
    score_q = score_q + prod_q;
    proj_rows = [proj_rows; yi, yq, si, sq, prod_i, prod_q, score_i, score_q]; %#ok<AGROW>
end
proj_tbl = array2table(proj_rows, ...
    'VariableNames', {'y_i', 'y_q', 'steering_i', 'steering_q', 'prod_i', 'prod_q', 'score_i', 'score_q'});
writetable(proj_tbl, fullfile(out_dir, 'projection_score_expected.csv'));

fprintf('Generated Step12 golden vectors in %s\n', out_dir);
