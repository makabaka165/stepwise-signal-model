function [trial_table, summary_table] = evaluate_step11_5_stage3_repeat_seed_metkl_recheck(W, scenarios, cfg_eval, policy_cfg, varargin)
%EVALUATE_STEP11_5_STAGE3_REPEAT_SEED_METKL_RECHECK Recheck C05 with larger Metkl and repeated seeds.
%
% This is not a policy scan. It fixes Stage2 selected C05 and repeats the
% same full/fixed/adaptive comparison with a larger trial count and multiple
% deterministic seed groups.

if nargin < 4
    error('evaluate_step11_5_stage3_repeat_seed_metkl_recheck:NotEnoughInputs', ...
        'W, scenarios, cfg_eval, and policy_cfg are required.');
end
opts = parse_opts_local(cfg_eval, varargin{:});

[trial_table, summary_table] = evaluate_step11_5_stage3_alternative_split_recheck(W, scenarios, cfg_eval, policy_cfg, ...
    'RunLabel', 'repeat_seed_metkl_recheck', ...
    'Metkl', opts.Metkl, ...
    'SeedOffsets', opts.seed_offsets, ...
    'SplitSchemes', {'repeat_all'});
end

function opts = parse_opts_local(cfg_eval, varargin)
opts = struct();
if isfield(cfg_eval, 'Metkl') && isfinite(cfg_eval.Metkl)
    opts.Metkl = max(20, 2 * cfg_eval.Metkl);
else
    opts.Metkl = 20;
end
if isfield(cfg_eval, 'seed_offset') && isfinite(cfg_eval.seed_offset)
    base_offset = cfg_eval.seed_offset;
else
    base_offset = 250000;
end
opts.seed_offsets = base_offset + [0, 100000, 200000];
if mod(numel(varargin), 2) ~= 0
    error('evaluate_step11_5_stage3_repeat_seed_metkl_recheck:InvalidNameValue', ...
        'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'metkl'
            opts.Metkl = value;
        case 'seedoffsets'
            opts.seed_offsets = value;
        otherwise
            error('evaluate_step11_5_stage3_repeat_seed_metkl_recheck:UnknownOption', ...
                'Unknown option: %s.', name);
    end
end
end
