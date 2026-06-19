% Generate Step13.4 full-N ACC48/Z24 RTL golden files.

clearvars;
clc;

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
step13_4_common('fulln_golden');
