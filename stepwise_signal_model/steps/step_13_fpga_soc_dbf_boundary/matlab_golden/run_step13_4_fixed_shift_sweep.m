% Run Step13.4 full-data fixed Z24 shift engineering sweep.

clearvars;
clc;

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
step13_4_common('sweep');
