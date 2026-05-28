clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
long_script = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level3_cascade_dispatch_runtime.m');
tmp_script = fullfile(script_dir, 'step8_7_7_cascade_runtime_exec_tmp.m');
copyfile(long_script, tmp_script, 'f');
cleanup_tmp = onCleanup(@() delete_if_exists_local(tmp_script));
run(tmp_script);

function delete_if_exists_local(path_in)
    if exist(path_in, 'file')
        delete(path_in);
    end
end
