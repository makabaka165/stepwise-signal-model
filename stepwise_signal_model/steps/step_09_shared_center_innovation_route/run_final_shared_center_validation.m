% Final shared-center enhanced DOA validation.
% Runs the Step 09 demo and performs interface-level smoke checks.

clc
clear

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
addpath(fullfile(script_dir, 'main'));

run(fullfile(script_dir, 'run_final_shared_center_demo.m'));

required_files = {
    fullfile(script_dir, 'README.md')
    fullfile(script_dir, 'main', 'shared_center_enhanced_doa.m')
    fullfile(script_dir, 'main', 'shared_center_select_subarray.m')
    fullfile(script_dir, 'main', 'build_y_work_from_frontend.m')
    fullfile(script_dir, 'main', 'local_cylindrical_music_test.m')
    fullfile(script_dir, 'main', 'coherent_rank1_refocus_fallback.m')
    fullfile(script_dir, 'main', 'local_2d_pair_refinement.m')
    fullfile(script_dir, 'main', 'confidence_boundary_rejector.m')
    fullfile(script_dir, 'results', 'final_keypoints.csv')
    fullfile(script_dir, 'results', 'final_summary.csv')
    fullfile(script_dir, 'results', 'final_route_flowchart.png')
    fullfile(script_dir, 'results', 'final_frontend_interface.png')
    fullfile(script_dir, 'results', 'final_scenario_examples.png')
    };

missing = {};
for i = 1:numel(required_files)
    if ~exist(required_files{i}, 'file')
        missing{end + 1, 1} = required_files{i}; %#ok<SAGROW>
    end
end
assert(isempty(missing), 'Validation missing required files.');

cfg = struct('Q_work_columns', 65);
array_geom = make_validation_array_geom_local();
selected = shared_center_select_subarray(0.7, array_geom, cfg);
assert(numel(selected.selectedWorkColumns) == 65, 'shared-center selection must return 65 columns.');

raw_cube = complex(randn(192, 32, 4), randn(192, 32, 4));
frontend_out = struct('rangeIdx', 1, 'dopplerIdx', 1, 'coarseAz', 0.7, ...
    'coarseEl', 0, 'frontend_state', 'single_peak_in_scope');
Y_work = build_y_work_from_frontend(raw_cube, frontend_out, selected, cfg);
assert(isequal(size(Y_work), [65, 32, 4]), 'Y_work shape must be 65 x 32 x Np.');

reject_frontend = frontend_out;
reject_frontend.frontend_state = 'two_separated_peaks_out_of_scope';
out = shared_center_enhanced_doa(reject_frontend, raw_cube, array_geom, cfg);
assert(strcmp(out.status, 'rejected'), 'Out-of-scope frontend state must be rejected.');

report = table(["required_files"; "subarray_selection"; "Y_work_shape"; "frontend_reject"], ...
    ["pass"; "pass"; "pass"; "pass"], ...
    'VariableNames', {'check_name', 'status'});
writetable(report, fullfile(script_dir, 'results', 'final_validation_report.csv'));

disp('Final shared-center validation passed.');

function array_geom = make_validation_array_geom_local()
    Naz = 192;
    Nel = 32;
    radius = 14;
    dz = 0.45;
    phiCol = (0:Naz - 1) / Naz * 360;
    zRow = (0:Nel - 1) * dz;
    X = zeros(Naz, Nel);
    Y = zeros(Naz, Nel);
    Z = zeros(Naz, Nel);
    for k = 1:Naz
        X(k, :) = radius * cosd(phiCol(k));
        Y(k, :) = radius * sind(phiCol(k));
        Z(k, :) = zRow;
    end
    array_geom = struct('phiCol', phiCol, 'X', X, 'Y', Y, 'Z', Z, ...
        'lambda', 1, 'Naz', Naz, 'Nel', Nel);
end
