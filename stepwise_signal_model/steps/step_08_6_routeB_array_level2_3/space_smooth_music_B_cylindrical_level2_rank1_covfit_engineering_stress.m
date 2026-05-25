% Entry wrapper for the requested Step 08.6 level-2 engineering stress script.
% The implementation file uses a shorter MATLAB-valid name because the requested
% filename exceeds MATLAB namelengthmax when local helper functions are present.

script_dir = fileparts(mfilename('fullpath'));
run(fullfile(script_dir, 'space_smooth_music_B_cylindrical_level2_rank1_engstress.m'));
