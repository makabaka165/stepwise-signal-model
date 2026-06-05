function row = collect_w_design_metrics(method_name, B, W, A_patch, pair_set, x, y, z, lambda, varargin)
%COLLECT_W_DESIGN_METRICS Collect Stage1/Stage2 reusable W diagnostics.

opts = parse_options_local(varargin{:});
[projection_loss, projection_debug] = compute_projection_loss(W, A_patch, 'Reg', opts.reg);
corr_stats = compute_manifold_correlation_stats(W, pair_set, x, y, z, lambda, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Reg', opts.reg);
cond_metrics = compute_w_condition_metrics(W);

row = struct();
row.method_name = char(method_name);
row.B = B;
row.beam_count = size(W, 2);
row.projection_loss = projection_loss;
row.projected_energy_ratio = projection_debug.projected_energy_ratio;
row.mean_corr = corr_stats.mean_corr;
row.median_corr = corr_stats.median_corr;
row.p90_corr = corr_stats.p90_corr;
row.max_corr = corr_stats.max_corr;
row.min_corr = corr_stats.min_corr;
row.num_pairs = corr_stats.num_pairs;
row.cond_WHW = cond_metrics.cond_WHW;
row.rank_W = cond_metrics.rank_W;
row.min_sv = cond_metrics.min_sv;
row.max_sv = cond_metrics.max_sv;
row.effective_rank = cond_metrics.effective_rank;
row.mean_cond_GHG = corr_stats.mean_cond_GHG;
row.max_cond_GHG = corr_stats.max_cond_GHG;
end

function opts = parse_options_local(varargin)
opts = struct();
opts.phase_factor = 1;
opts.phase_sign = 1;
opts.reg = 1e-10;
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('collect_w_design_metrics:InvalidNameValue', 'Name-value options must be paired.');
end
for idx = 1:2:numel(varargin)
    name = lower(char(varargin{idx}));
    value = varargin{idx + 1};
    switch name
        case 'phasefactor'
            opts.phase_factor = value;
        case 'phasesign'
            opts.phase_sign = value;
        case 'reg'
            opts.reg = value;
        otherwise
            error('collect_w_design_metrics:UnknownOption', 'Unknown option: %s', name);
    end
end
end

