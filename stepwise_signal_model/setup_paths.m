% 将分步信号模型根目录、核心模块和示例步骤加入 MATLAB 路径。
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(genpath(fullfile(rootDir, 'core')));
addpath(genpath(fullfile(rootDir, 'steps')));
clear rootDir;
