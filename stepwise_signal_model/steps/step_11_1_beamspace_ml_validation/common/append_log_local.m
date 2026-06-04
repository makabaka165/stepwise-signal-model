function log_lines = append_log_local(log_lines, fmt, varargin)
%APPEND_LOG_LOCAL Print and append a formatted log line.

if nargin < 2
    error('append_log_local:NotEnoughInputs', 'log_lines and fmt are required.');
end
if isempty(log_lines)
    log_lines = {};
end
if ~iscell(log_lines)
    error('append_log_local:InvalidLogLines', 'log_lines must be a cell array.');
end

line = sprintf(fmt, varargin{:});
fprintf('%s\n', line);
log_lines{end + 1, 1} = line;
end
