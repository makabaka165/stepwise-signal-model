function log_lines = append_log_local(log_lines, fmt, varargin)
%APPEND_LOG_LOCAL Append a formatted timestamped log line.

if nargin < 2
    error('append_log_local:NotEnoughInputs', 'log_lines and fmt are required.');
end
if isempty(log_lines)
    log_lines = {};
end
line = sprintf(fmt, varargin{:});
stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
log_lines{end + 1, 1} = sprintf('[%s] %s', stamp, line);
fprintf('%s\n', log_lines{end});
end

