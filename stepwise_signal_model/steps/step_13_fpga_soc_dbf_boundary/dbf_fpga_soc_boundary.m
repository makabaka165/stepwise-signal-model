function out = dbf_fpga_soc_boundary(varargin)
%DBF_FPGA_SOC_BOUNDARY Short entry point for Step13 DBF boundary validation.
%   This wrapper intentionally delegates to the script entry point so the
%   step can be run either as a function or from the MATLAB command window.

if nargin > 0
    warning('Step13:UnusedArgs', ...
        'dbf_fpga_soc_boundary ignores input arguments in the current smoke framework.');
end

run_step13_fpga_soc_dbf_boundary;

if nargout > 0
    out = struct();
    out.status = 'completed';
    out.results_dir = fullfile(fileparts(mfilename('fullpath')), ...
        'results_step13_fpga_soc_dbf_boundary');
end
end
