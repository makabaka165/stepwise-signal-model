% Step13.4 FPGA DBF engineering boundary closure entry point.
%
% This script runs the MATLAB-side fixed-shift sweep, generates full-N RTL
% golden vectors when the sweep finds a passing shift, and refreshes closure
% keypoints from any existing full-N XSim compare and OOC synthesis results.
% It does not run Vivado and does not call the Step11.7 full backend.

clearvars;
clc;

scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, 'matlab_golden'));

step13_4_common('run_all');
