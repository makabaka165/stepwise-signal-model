function out = confidence_boundary_rejector(music_info, coherent_info, pair2d_info, cfg)
%CONFIDENCE_BOUNDARY_REJECTOR Conservative final rejector.

if nargin < 4
    cfg = struct();
end
boundary_flag = getfield_default_local(cfg, 'boundary_unreliable_flag', false);

out = struct();
out.method = 'shared-center MUSIC enhanced DOA';
out.status = 'rejected';
out.route_name = 'low_confidence';
out.confidence = 'low';
out.az_est = [];
out.el_est = [];
out.reject_reason = 'insufficient consistent evidence';

if boundary_flag || getfield_default_local(music_info, 'boundary_unreliable', false)
    out.route_name = 'boundary_unreliable';
    out.reject_reason = 'boundary evidence has higher priority than success';
    return
end

if getfield_default_local(music_info, 'need_2d_refinement', false) && ...
        ~getfield_default_local(pair2d_info, 'valid', false)
    out.route_name = 'low_confidence';
    out.reject_reason = '2-D refinement was requested but did not pass confidence checks';
    return
end

music_reason = getfield_default_local(music_info, 'reason', '');
coherent_reason = getfield_default_local(coherent_info, 'reason', '');
pair2d_reason = getfield_default_local(pair2d_info, 'reason', '');
out.reject_reason = strjoin_nonempty_local({music_reason, coherent_reason, pair2d_reason}, '; ');
if isempty(out.reject_reason)
    out.reject_reason = 'no reliable MUSIC, coherent, or 2-D route';
end
end

function txt = strjoin_nonempty_local(parts, sep)
    keep = false(size(parts));
    for i = 1:numel(parts)
        keep(i) = ~isempty(parts{i});
    end
    parts = parts(keep);
    if isempty(parts)
        txt = '';
    else
        txt = parts{1};
        for i = 2:numel(parts)
            txt = [txt, sep, parts{i}]; %#ok<AGROW>
        end
    end
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end
