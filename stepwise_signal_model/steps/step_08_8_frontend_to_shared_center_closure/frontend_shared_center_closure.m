% Step 8.8 short runner.
% Runs the frontend-to-shared-center closure validation main script.

script_dir = fileparts(mfilename('fullpath'));
run(fullfile(script_dir, 'space_smooth_music_B_frontend_shared_center_closure.m'));
