function policy = select_adaptive_topk_window_policy_v2(features, base_refine_cfg, policy_cfg)
%SELECT_ADAPTIVE_TOPK_WINDOW_POLICY_V2 Select Stage2 calibrated policy.
%
% NORMAL is equivalent to Step11.3 fixed topK3. SCORE_AMBIGUOUS only
% increases topK, BOUNDARY is the only policy that expands the refine
% window, and ILL_CONDITIONED only lowers confidence.

if nargin < 3 || isempty(policy_cfg)
    policy_cfg = struct();
end
policy_cfg = fill_policy_defaults_local(policy_cfg);
if nargin < 2
    error('select_adaptive_topk_window_policy_v2:NotEnoughInputs', ...
        'features, base_refine_cfg, and policy_cfg are required.');
end

boundary_risk = scalar_field_local(features, 'boundary_risk', 1);
cond_risk = scalar_field_local(features, 'cond_risk', 1);
gap_13 = scalar_field_local(features, 'gap_13', 0);
U_confidence = scalar_field_local(features, 'U_confidence', 1);
topK_available = max(1, floor(scalar_field_local(features, 'topK_available', policy_cfg.topK_max)));
topK_max = max(1, floor(scalar_field_local(features, 'topK_max', policy_cfg.topK_max)));

if cond_risk >= policy_cfg.cond_threshold
    policy_name = 'ILL_CONDITIONED';
    adaptive_topK = 3;
    az_window_scale = 1.00;
    el_window_scale = 1.00;
    confidence = 'low';
    boundary_flag = 'ill_conditioned_pair_manifold';
    reason_text = 'cond_risk >= cond_threshold';
elseif boundary_risk == 1
    policy_name = 'BOUNDARY';
    adaptive_topK = policy_cfg.boundary_topK;
    az_window_scale = min(policy_cfg.boundary_window_scale, 1.25);
    el_window_scale = min(policy_cfg.boundary_window_scale, 1.25);
    confidence = 'medium_low';
    boundary_flag = 'boundary_protected_search';
    reason_text = 'boundary_risk == 1';
elseif gap_13 < policy_cfg.ambiguous_gap_threshold
    policy_name = 'SCORE_AMBIGUOUS';
    adaptive_topK = policy_cfg.ambiguous_topK;
    az_window_scale = 1.00;
    el_window_scale = 1.00;
    confidence = 'medium_low';
    boundary_flag = '';
    reason_text = 'gap_13 < ambiguous_gap_threshold';
elseif gap_13 >= policy_cfg.easy_gap_threshold
    policy_name = 'EASY';
    adaptive_topK = policy_cfg.easy_topK;
    az_window_scale = policy_cfg.easy_window_scale;
    el_window_scale = policy_cfg.easy_window_scale;
    if U_confidence < 0.55
        confidence = 'high';
    else
        confidence = 'medium';
    end
    boundary_flag = '';
    reason_text = 'gap_13 >= easy_gap_threshold';
else
    policy_name = 'NORMAL';
    adaptive_topK = 3;
    az_window_scale = 1.00;
    el_window_scale = 1.00;
    if U_confidence < 0.75
        confidence = 'medium';
    else
        confidence = 'medium_low';
    end
    boundary_flag = '';
    reason_text = 'default fixed topK3-equivalent normal search';
end

adaptive_topK = min([max(1, floor(adaptive_topK)), topK_max, topK_available]);

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
policy.U_search = scalar_field_local(features, 'U_search', NaN);
policy.U_confidence = U_confidence;
policy.gap_13 = gap_13;
policy.cond_risk = cond_risk;
policy.boundary_risk = boundary_risk;
policy.config_id = policy_cfg.config_id;
policy.config_name = policy_cfg.config_name;
end

function policy_cfg = fill_policy_defaults_local(policy_cfg)
defaults = struct();
defaults.config_id = 0;
defaults.config_name = 'unnamed_v2_policy';
defaults.topK_max = 7;
defaults.gap_scale = 0.003;
defaults.easy_gap_threshold = Inf;
defaults.easy_topK = 3;
defaults.easy_window_scale = 1.0;
defaults.ambiguous_gap_threshold = -Inf;
defaults.ambiguous_topK = 3;
defaults.boundary_topK = 3;
defaults.boundary_window_scale = 1.0;
defaults.cond_threshold = 0.85;
names = fieldnames(defaults);
for idx = 1:numel(names)
    if ~isfield(policy_cfg, names{idx})
        policy_cfg.(names{idx}) = defaults.(names{idx});
    end
end
end

function value = scalar_field_local(s, field_name, fallback)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = fallback;
end
if ~(isscalar(value) && isfinite(value))
    value = fallback;
end
end
