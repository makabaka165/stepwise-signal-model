% Step 8.8B short runner.
% Runs the Y_work Doppler de-rotation interface validation script.

script_dir = fileparts(mfilename('fullpath'));
run(fullfile(script_dir, 'space_smooth_music_B_frontend_ywork_derotation_validation.m'));
