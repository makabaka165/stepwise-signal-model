clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

src = fullfile(script_dir, 'space_smooth_music_B_cylindrical_level3_template_equivalence.m');
tmp = fullfile(script_dir, 'step8_7_8_template_equivalence_exec_tmp.m');
copyfile(src, tmp, 'f');
cleanup_tmp = onCleanup(@() delete_tmp_file_local(tmp));
run(tmp);

function delete_tmp_file_local(path_in)
    if exist(path_in, 'file')
        delete(path_in);
    end
end
