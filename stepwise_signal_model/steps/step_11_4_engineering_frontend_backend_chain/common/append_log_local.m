function log_lines = append_log_local(log_lines, varargin)
%APPEND_LOG_LOCAL Append a timestamped log line.

if nargin < 1 || isempty(log_lines)
    log_lines = {};
end
if isempty(varargin)
    text = '';
else
    text = sprintf(varargin{:});
end
stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
log_lines{end + 1, 1} = sprintf('[%s] %s', stamp, text);
end
