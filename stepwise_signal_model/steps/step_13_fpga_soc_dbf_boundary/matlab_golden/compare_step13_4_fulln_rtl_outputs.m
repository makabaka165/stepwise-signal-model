% Compare Step13.4 full-N XSim output against MATLAB golden files.

clearvars;
clc;

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
step13_4_common('compare_fulln');
