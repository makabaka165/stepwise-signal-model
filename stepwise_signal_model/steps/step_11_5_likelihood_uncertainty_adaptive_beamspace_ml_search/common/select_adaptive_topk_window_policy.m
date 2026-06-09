function policy = select_adaptive_topk_window_policy(features, base_refine_cfg, policy_cfg)
%SELECT_ADAPTIVE_TOPK_WINDOW_POLICY Select deterministic Step11.5 policy.
%
% policy = select_adaptive_topk_window_policy(features, base_refine_cfg,
% policy_cfg) maps likelihood-landscape uncertainty features to EASY,
% NORMAL, HARD, or UNSAFE settings. It does not use target truth values.

if nargin < 2
    error('select_adaptive_topk_window_policy:NotEnoughInputs', ...
        'features and base_refine_cfg are required.');
end
if nargin < 3 || isempty(policy_cfg)
    policy_cfg = struct();
end
policy_cfg = fill_defaults_local(policy_cfg);

U = get_field_local(features, 'U', NaN);
boundary_risk = get_field_local(features, 'boundary_risk', 1);
cond_risk = get_field_local(features, 'cond_risk', 1);
topK_available = max(1, floor(get_field_local(features, 'topK_available', policy_cfg.topK_max)));
topK_max = max(1, floor(get_field_local(features, 'topK_max', policy_cfg.topK_max)));

if U >= 0.80 || cond_risk >= 0.85
    policy_name = 'UNSAFE';
    adaptive_topK = 7;
    az_window_scale = 2.00;
    el_window_scale = 2.00;
    confidence = 'low';
    boundary_flag = 'search_uncertain_or_ill_conditioned';
    reason_text = 'U >= 0.80 or cond_risk >= 0.85';
elseif U < 0.30 && boundary_risk == 0 && cond_risk < 0.55
    policy_name = 'EASY';
    adaptive_topK = 1;
    az_window_scale = 0.75;
    el_window_scale = 0.75;
    confidence = 'high';
    boundary_flag = '';
    reason_text = 'U < 0.30, boundary_risk == 0, cond_risk < 0.55';
elseif U < 0.55 && boundary_risk == 0
    policy_name = 'NORMAL';
    adaptive_topK = 3;
    az_window_scale = 1.00;
    el_window_scale = 1.00;
    confidence = 'medium';
    boundary_flag = '';
    reason_text = '0.30 <= U < 0.55 and boundary_risk == 0';
else
    policy_name = 'HARD';
    adaptive_topK = 5;
    az_window_scale = 1.50;
    el_window_scale = 1.50;
    confidence = 'medium_low';
    boundary_flag = '';
    reason_text = '0.55 <= U < 0.80 or boundary_risk == 1';
end

adaptive_topK = min([adaptive_topK, topK_max, topK_available]);

policy = struct();
policy.policy_name = policy_name;
policy.adaptive_topK = adaptive_topK;
policy.az_window_scale = az_window_scale;
policy.el_window_scale = el_window_scale;
policy.adaptive_local_az_half_width = base_refine_cfg.local_az_half_width * az_window_scale;
policy.adaptive_local_el_center_half_width = base_refine_cfg.local_el_center_half_width * el_window_scale;
policy.confidence = confidence;
policy.boundary_flag = boundary_flag;
policy.reason_text = reason_text;
policy.U = U;
policy.boundary_risk = boundary_risk;
policy.cond_risk = cond_risk;
end

function policy_cfg = fill_defaults_local(policy_cfg)
if ~isfield(policy_cfg, 'topK_max')
    policy_cfg.topK_max = 7;
end
end

function value = get_field_local(s, field_name, fallback)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = fallback;
end
if ~(isscalar(value) && isfinite(value))
    value = fallback;
end
end
