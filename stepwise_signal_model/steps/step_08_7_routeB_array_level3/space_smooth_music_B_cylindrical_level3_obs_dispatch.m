clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
long_script = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level3_observable_dispatch_demo.m');
tmp_script = fullfile(script_dir, 'step8_7_6_obs_dispatch_exec_tmp.m');
copyfile(long_script, tmp_script, 'f');
cleanup_tmp = onCleanup(@() delete_if_exists_local(tmp_script));
run(tmp_script);

function delete_if_exists_local(path_in)
    if exist(path_in, 'file')
        delete(path_in);
    end
end
